import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/entities/track.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/theme/app_tokens.dart';
import '../../presentation/widgets/bouncing_scale_button.dart';

// ============================================================================
// SharedPreferences Persistence Layer & Constants
// ============================================================================

/// SharedPreferences persistent storage key for offline-only mode.
const String kOfflineOnlyModePrefKey = 'softify_offline_only_mode';

/// Contract for persistent storage compatible with SharedPreferences semantics.
abstract class OfflineModePrefsStorage {
  /// Reads a boolean value by key. Returns null if key is unset.
  Future<bool?> getBool(String key);

  /// Stores a boolean value by key.
  Future<bool> setBool(String key, bool value);
}

/// Durable disk-backed key-value store providing SharedPreferences persistence
/// without external native plugin compilation hazards.
///
/// Stores preference pairs in `shared_preferences.json` inside the application
/// support directory, accompanied by an in-memory cache for synchronous reads.
class SharedPreferencesStore implements OfflineModePrefsStorage {
  static final SharedPreferencesStore _instance = SharedPreferencesStore._internal();
  factory SharedPreferencesStore() => _instance;
  SharedPreferencesStore._internal();

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;

  /// Loads persisted key-values from disk into memory.
  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File(p.join(dir.path, 'shared_preferences.json'));
      if (await _cacheFile!.exists()) {
        final content = await _cacheFile!.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _memoryCache = Map<String, dynamic>.from(decoded);
          }
        }
      }
    } catch (_) {
      // Fallback to in-memory store if disk access fails
    } finally {
      _isLoaded = true;
    }
  }

  @override
  Future<bool?> getBool(String key) async {
    if (!_isLoaded) await init();
    final val = _memoryCache[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return null;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    try {
      if (_cacheFile != null) {
        if (!await _cacheFile!.parent.exists()) {
          await _cacheFile!.parent.create(recursive: true);
        }
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Synchronously checks in-memory cache for a boolean value.
  bool? getBoolSync(String key) {
    final val = _memoryCache[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return null;
  }
}

// ============================================================================
// Riverpod Provider & StateNotifier
// ============================================================================

/// Global offline-only mode Riverpod StateNotifier.
///
/// Manages toggle state, handles dual persistence (SharedPreferences file store
/// + SQLite AppDatabase settings table), and coordinates synchronous state lookups.
class OfflineModeNotifier extends StateNotifier<bool> {
  final Ref? _ref;
  final OfflineModePrefsStorage _storage;

  /// Global synchronous mirror for low-latency non-reactive callers.
  static bool _globalOffline = false;

  /// Synchronously returns true if global offline-only mode is active.
  static bool get isOffline => _globalOffline;

  /// Visible for testing to reset global static state between test runs.
  @visibleForTesting
  static void resetForTesting() {
    _globalOffline = false;
    cachedDownloadedTrackIds.clear();
    customStorage = null;
  }

  /// Cached track IDs currently downloaded offline.
  static Set<String> cachedDownloadedTrackIds = <String>{};

  /// Optional custom storage backend for dependency injection and tests.
  static OfflineModePrefsStorage? customStorage;

  OfflineModeNotifier([this._ref, OfflineModePrefsStorage? storage])
      : _storage = storage ?? customStorage ?? SharedPreferencesStore(),
        super(_globalOffline) {
    _loadPersistedState();
  }

  /// Asynchronously loads initial offline mode preference.
  Future<void> _loadPersistedState() async {
    try {
      // 1. SharedPreferences lookup
      final prefValue = await _storage.getBool(kOfflineOnlyModePrefKey);
      if (prefValue != null) {
        _globalOffline = prefValue;
        if (mounted) state = prefValue;
        return;
      }

      // 2. Drift AppDatabase settings table fallback
      final db = _safeGetDb();
      if (db != null) {
        final row = await (db.select(db.settings)
              ..where((t) => t.key.equals('offline_only_mode')))
            .getSingleOrNull();
        if (row != null) {
          final isEnabled = row.value.trim().toLowerCase() == 'true';
          _globalOffline = isEnabled;
          if (mounted) state = isEnabled;
          await _storage.setBool(kOfflineOnlyModePrefKey, isEnabled);
        }
      }
    } catch (_) {
      // Graceful fallback to default (false)
    }
  }

  /// Enables or disables offline-only mode, persisting the change to disk and database.
  Future<void> setOfflineMode(bool enabled) async {
    if (state == enabled && _globalOffline == enabled) return;
    _globalOffline = enabled;
    if (mounted) state = enabled;

    // 1. Persist to SharedPreferences store
    try {
      await _storage.setBool(kOfflineOnlyModePrefKey, enabled);
    } catch (_) {}

    // 2. Persist to Drift database settings
    try {
      final db = _safeGetDb();
      if (db != null) {
        await db.into(db.settings).insertOnConflictUpdate(
              SettingRow(
                key: 'offline_only_mode',
                value: enabled.toString(),
              ),
            );
      }
    } catch (_) {}
  }

  /// Toggles the offline-only mode state.
  Future<void> toggle() => setOfflineMode(!state);

  /// Activates offline-only mode.
  Future<void> enable() => setOfflineMode(true);

  /// Deactivates offline-only mode.
  Future<void> disable() => setOfflineMode(false);

  /// Safely extracts AppDatabase from ref if initialized.
  AppDatabase? _safeGetDb() {
    if (_ref == null) return null;
    try {
      return _ref.read(databaseProvider);
    } catch (_) {
      return null;
    }
  }
}

/// Global Riverpod StateNotifierProvider managing Offline-Only mode.
/// Defaults to `false` and persists state to SharedPreferences and SQLite settings.
final isOfflineOnlyModeProvider =
    StateNotifierProvider<OfflineModeNotifier, bool>((ref) {
  // Synchronize completed download IDs when available
  ref.listen<AsyncValue<List<DownloadItem>>>(downloadsStreamProvider, (_, next) {
    final downloads = next.valueOrNull;
    if (downloads != null) {
      OfflineModeNotifier.cachedDownloadedTrackIds = downloads
          .where((d) => d.isCompleted)
          .map((d) => d.trackId)
          .toSet();
    }
  });

  return OfflineModeNotifier(ref);
});

// ============================================================================
// Offline Track Filtering Helpers
// ============================================================================

/// Determines whether a track is available offline (either stored locally on the
/// device filesystem or fully downloaded in local storage).
bool isTrackOffline(Track track, [Set<String>? downloadedTrackIds]) {
  // 1. Local device track by ID or sourceId scheme
  if (track.id.startsWith('local_') ||
      track.sourceId.startsWith('local_') ||
      track.sourceId.startsWith('/') ||
      track.sourceId.startsWith('file://')) {
    return true;
  }

  // 2. Absolute/relative file on disk check (non-network URI)
  if (track.sourceId.isNotEmpty &&
      !track.sourceId.startsWith('http://') &&
      !track.sourceId.startsWith('https://')) {
    try {
      if (File(track.sourceId).existsSync()) {
        return true;
      }
    } catch (_) {}
  }

  // 3. Downloaded track check via IDs set
  final completedSet = downloadedTrackIds ?? OfflineModeNotifier.cachedDownloadedTrackIds;
  if (completedSet.contains(track.id) || completedSet.contains(track.sourceId)) {
    return true;
  }

  return false;
}

/// Checks if a track is a local on-device music track.
bool isLocalDeviceTrack(Track track) {
  if (track.id.startsWith('local_') ||
      track.sourceId.startsWith('local_') ||
      track.sourceId.startsWith('/') ||
      track.sourceId.startsWith('file://')) {
    return true;
  }
  if (track.sourceId.isNotEmpty &&
      !track.sourceId.startsWith('http://') &&
      !track.sourceId.startsWith('https://')) {
    try {
      return File(track.sourceId).existsSync();
    } catch (_) {}
  }
  return false;
}

/// Filters a list of tracks, returning ONLY local device tracks or downloaded
/// tracks when offline-only mode is active.
///
/// If offline mode is disabled, the original [tracks] list is returned unchanged.
///
/// Parameters:
/// - [tracks]: The input list of tracks to filter.
/// - [isOfflineMode]: Explicit offline override. If omitted, checks [Ref] or [OfflineModeNotifier.isOffline].
/// - [downloadedTrackIds]: Explicit set of completed download IDs. If omitted, uses cached IDs or [downloadsStreamProvider].
/// - [widgetRef]: Optional [WidgetRef] from build context to query providers.
/// - [ref]: Optional [Ref] from a provider or controller.
List<Track> filterOfflineTracks(
  List<Track> tracks, {
  bool? isOfflineMode,
  Set<String>? downloadedTrackIds,
  WidgetRef? widgetRef,
  Ref? ref,
}) {
  final bool active = isOfflineMode ??
      (widgetRef != null
          ? widgetRef.read(isOfflineOnlyModeProvider)
          : (ref != null
              ? ref.read(isOfflineOnlyModeProvider)
              : OfflineModeNotifier.isOffline));

  if (!active) {
    return tracks;
  }

  final Set<String> completedIds = downloadedTrackIds ??
      (widgetRef != null
          ? (widgetRef.read(downloadsStreamProvider).valueOrNull
                  ?.where((d) => d.isCompleted)
                  .map((d) => d.trackId)
                  .toSet() ??
              OfflineModeNotifier.cachedDownloadedTrackIds)
          : (ref != null
              ? (ref.read(downloadsStreamProvider).valueOrNull
                      ?.where((d) => d.isCompleted)
                      .map((d) => d.trackId)
                      .toSet() ??
                  OfflineModeNotifier.cachedDownloadedTrackIds)
              : OfflineModeNotifier.cachedDownloadedTrackIds));

  return tracks.where((track) => isTrackOffline(track, completedIds)).toList();
}

/// Convenient Riverpod family provider to reactively filter any track list
/// based on active offline mode and completed downloads stream.
final filteredOfflineTracksProvider =
    Provider.family<List<Track>, List<Track>>((ref, tracks) {
  final isOffline = ref.watch(isOfflineOnlyModeProvider);
  if (!isOffline) return tracks;

  final downloads = ref.watch(downloadsStreamProvider).valueOrNull ?? [];
  final completedIds =
      downloads.where((d) => d.isCompleted).map((d) => d.trackId).toSet();

  return filterOfflineTracks(
    tracks,
    isOfflineMode: true,
    downloadedTrackIds: completedIds,
  );
});

/// Extension on [List<Track>] providing fluent offline filtering.
extension OfflineTrackFilterExtension on List<Track> {
  /// Returns only offline-ready tracks if offline mode is active.
  List<Track> filterOfflineOnly({
    bool? isOfflineMode,
    Set<String>? downloadedTrackIds,
    WidgetRef? widgetRef,
    Ref? ref,
  }) =>
      filterOfflineTracks(
        this,
        isOfflineMode: isOfflineMode,
        downloadedTrackIds: downloadedTrackIds,
        widgetRef: widgetRef,
        ref: ref,
      );
}

// ============================================================================
// OfflineModeSwitchTile (for Settings Screen)
// ============================================================================

/// Settings screen switch tile enabling or disabling Global Offline-Only Mode.
///
/// Features:
/// - Follows Softify design tokens and Material 3 Expressive guidelines.
/// - Shows active/inactive cloud-off icon with accent color highlight.
/// - Triggers subtle haptic feedback on state toggles.
/// - Automatically updates [isOfflineOnlyModeProvider] and triggers persistence.
class OfflineModeSwitchTile extends ConsumerWidget {
  /// Custom tile padding.
  final EdgeInsetsGeometry? contentPadding;

  /// Whether to render in dense mode.
  final bool dense;

  /// Custom leading icon widget.
  final Widget? leading;

  /// Primary tile title. Defaults to 'Offline Mode'.
  final String titleText;

  /// Subtitle explanatory description.
  final String? subtitleText;

  /// Optional custom callback invoked whenever state is toggled.
  final ValueChanged<bool>? onToggle;

  const OfflineModeSwitchTile({
    super.key,
    this.contentPadding,
    this.dense = false,
    this.leading,
    this.titleText = 'Offline Mode',
    this.subtitleText =
        'Only play downloaded songs and local music files. Disables all online streaming and network requests.',
    this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final isOffline = ref.watch(isOfflineOnlyModeProvider);

    return SwitchListTile(
      contentPadding: contentPadding,
      dense: dense,
      activeColor: tokens.accent,
      secondary: leading ??
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOffline
                  ? tokens.accent.withValues(alpha: 0.16)
                  : tokens.surfaceHighlight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
              color: isOffline ? tokens.accent : tokens.textSecondary,
              size: 22,
            ),
          ),
      title: Text(
        titleText,
        style: TextStyle(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: dense ? 14 : 15,
        ),
      ),
      subtitle: subtitleText != null
          ? Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                subtitleText!,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: dense ? 12 : 13,
                  height: 1.3,
                ),
              ),
            )
          : null,
      value: isOffline,
      onChanged: (val) {
        HapticFeedback.selectionClick();
        ref.read(isOfflineOnlyModeProvider.notifier).setOfflineMode(val);
        onToggle?.call(val);
      },
    );
  }
}

// ============================================================================
// OfflineModeBanner (for Home / Search / Library Screens)
// ============================================================================

/// A prominent, non-intrusive banner displayed at the top of Home, Search, and
/// Library screens when Offline-Only Mode is active.
///
/// Features:
/// - Smooth animated expand/collapse and fade transition when mode changes.
/// - Apple Music / Liquid Glass inspired translucent container with accent glow.
/// - Clear badge icon (`Icons.wifi_off_rounded`) informing user that network streaming is paused.
/// - 1-tap "Go Online" action button to immediately resume full online functionality.
/// - Fully responsive across mobile, tablet, and desktop viewports.
class OfflineModeBanner extends ConsumerWidget {
  /// Margins around the banner. Defaults to `EdgeInsets.symmetric(horizontal: 16, vertical: 8)`.
  final EdgeInsetsGeometry margin;

  /// Custom text title for the banner. Defaults to 'Offline Mode Active'.
  final String title;

  /// Custom description message. Defaults to 'Showing only downloaded & local songs.'
  final String message;

  /// Whether to display the "Go Online" action pill button.
  final bool showActionButton;

  /// Text for the action button. Defaults to 'Go Online'.
  final String actionLabel;

  /// Optional callback when "Go Online" is pressed. If omitted, turns offline mode off.
  final VoidCallback? onDisable;

  const OfflineModeBanner({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.title = 'Offline Mode Active',
    this.message = 'Showing only downloaded & local songs',
    this.showActionButton = true,
    this.actionLabel = 'Go Online',
    this.onDisable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineOnlyModeProvider);
    if (!isOffline) {
      return const SizedBox.shrink();
    }
    final tokens = context.tokens;

    return Padding(
      padding: margin,
      child: Container(
          decoration: BoxDecoration(
            color: tokens.card.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: tokens.accent.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.accent.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Icon Badge with subtle accent background
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  color: tokens.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title and message text
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: tokens.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'OFFLINE',
                            style: TextStyle(
                              color: tokens.accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // "Go Online" 1-tap action button
              if (showActionButton) ...[
                const SizedBox(width: 8),
                BouncingScaleButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (onDisable != null) {
                      onDisable!();
                    } else {
                      ref
                          .read(isOfflineOnlyModeProvider.notifier)
                          .setOfflineMode(false);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: tokens.accent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.accent.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
  }
}

/// A Sliver wrapper for [OfflineModeBanner] suitable for embedding as the first
/// child in a [CustomScrollView] (e.g., Home, Search, or Library screens).
class OfflineModeBannerSliver extends ConsumerWidget {
  /// Margins around the banner. Defaults to `EdgeInsets.fromLTRB(16, 8, 16, 8)`.
  final EdgeInsetsGeometry padding;

  /// Custom text title for the banner. Defaults to 'Offline Mode Active'.
  final String title;

  /// Custom description message. Defaults to 'Showing only downloaded & local songs.'
  final String message;

  /// Whether to display the "Go Online" action pill button.
  final bool showActionButton;

  /// Text for the action button. Defaults to 'Go Online'.
  final String actionLabel;

  /// Optional callback when "Go Online" is pressed.
  final VoidCallback? onDisable;

  const OfflineModeBannerSliver({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.title = 'Offline Mode Active',
    this.message = 'Showing only downloaded & local songs',
    this.showActionButton = true,
    this.actionLabel = 'Go Online',
    this.onDisable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineOnlyModeProvider);
    if (!isOffline) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: OfflineModeBanner(
        margin: padding,
        title: title,
        message: message,
        showActionButton: showActionButton,
        actionLabel: actionLabel,
        onDisable: onDisable,
      ),
    );
  }
}
