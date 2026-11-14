// ============================================================================
// Softify Quality of Life (QoL) Feature 36: Lyrics Live Sync Offset Adjuster (±5s)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';

// ============================================================================
// Constants & Configuration
// ============================================================================

/// Minimum lyrics synchronization offset in milliseconds (-5 seconds).
const int kMinLyricsSyncOffsetMs = -5000;

/// Maximum lyrics synchronization offset in milliseconds (+5 seconds).
const int kMaxLyricsSyncOffsetMs = 5000;

/// Fine-grained slider adjustment step size in milliseconds.
const int kLyricsSyncOffsetStepMs = 50;

/// Quick nudge button step size in milliseconds (±100ms).
const int kLyricsSyncOffsetNudgeStepMs = 100;

/// Neutral default synchronization offset (perfect sync).
const int kDefaultLyricsSyncOffsetMs = 0;

/// SharedPreferences storage key prefix for per-track lyrics sync offset.
const String kLyricsSyncOffsetPrefix = 'lyrics_sync_offset_';

/// Global default fallback storage key for general lyrics sync offset.
const String kLyricsSyncGlobalOffsetKey = 'lyrics_sync_offset_global';

// ============================================================================
// Math & Formatting Helpers
// ============================================================================

/// Clamps [offsetMs] within [-5000ms, +5000ms] and rounds to nearest [kLyricsSyncOffsetStepMs] (50ms).
int clampAndSnapLyricsOffset(int offsetMs) {
  final clamped = offsetMs.clamp(kMinLyricsSyncOffsetMs, kMaxLyricsSyncOffsetMs);
  final snapped = (clamped / kLyricsSyncOffsetStepMs).round() * kLyricsSyncOffsetStepMs;
  return snapped.clamp(kMinLyricsSyncOffsetMs, kMaxLyricsSyncOffsetMs);
}

/// Formats millisecond offset to human-readable string (e.g., "0 ms", "+250 ms", "-400 ms").
String formatLyricsSyncOffset(int offsetMs) {
  if (offsetMs == 0) return '0 ms';
  final sign = offsetMs > 0 ? '+' : '';
  return '$sign$offsetMs ms';
}

/// Formats millisecond offset to seconds string (e.g., "0.00s", "+0.25s", "-1.50s").
String formatLyricsSyncOffsetSeconds(int offsetMs) {
  if (offsetMs == 0) return '0.00s';
  final seconds = offsetMs / 1000.0;
  final sign = offsetMs > 0 ? '+' : '';
  return '$sign${seconds.toStringAsFixed(2)}s';
}

/// Returns a descriptive status label for lyrics sync relative timing.
String formatLyricsSyncStatusDescription(int offsetMs) {
  if (offsetMs == 0) return 'In Sync';
  if (offsetMs > 0) return 'Lyrics Delayed (+${offsetMs}ms)';
  return 'Lyrics Earlier (${offsetMs}ms)';
}

// ============================================================================
// SharedPreferences Persistence Layer (Zero-Dependency & Mockable)
// ============================================================================

/// Self-contained, durable SharedPreferences engine matching the standard
/// `package:shared_preferences` API interface.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _preferenceStore;
  final File? _storageFile;

  SharedPreferences._(this._preferenceStore, this._storageFile);

  /// Synchronously accessible cached singleton instance if resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects mock key-value pairs for unit and widget test harnesses.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance and mocks.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Resolves or initializes the SharedPreferences singleton.
  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    if (_mockInitialValues != null) {
      _instance = SharedPreferences._(
        Map<String, Object>.from(_mockInitialValues!),
        null,
      );
      return _instance!;
    }

    final store = <String, Object>{};
    File? file;
    try {
      file = _resolveStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (value != null) {
                store[key.toString()] = value as Object;
              }
            });
          }
        }
      }
    } catch (_) {
      // Graceful fallback to memory store
    }

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  static File? _resolveStorageFile() {
    try {
      final userHome = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['LOCALAPPDATA'];
      if (userHome != null && userHome.isNotEmpty) {
        final dir = Directory('$userHome/.softify');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('${dir.path}/shared_preferences.json');
      }
      return File('.softify_shared_preferences.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist() async {
    final file = _storageFile;
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_preferenceStore);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  int? getInt(String key) {
    final val = _preferenceStore[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  Future<bool> setInt(String key, int value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  String? getString(String key) {
    final val = _preferenceStore[key];
    return val?.toString();
  }

  Future<bool> setString(String key, String value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  bool containsKey(String key) => _preferenceStore.containsKey(key);

  Future<bool> remove(String key) async {
    final existed = _preferenceStore.remove(key);
    await _persist();
    return existed != null;
  }

  Future<bool> clear() async {
    _preferenceStore.clear();
    await _persist();
    return true;
  }

  Set<String> getKeys() => Set<String>.from(_preferenceStore.keys);
}

// ============================================================================
// Storage Layer: LyricsSyncOffsetStorage
// ============================================================================

/// Storage repository providing typed persistence for per-track lyrics offsets.
class LyricsSyncOffsetStorage {
  final SharedPreferences? _prefs;

  LyricsSyncOffsetStorage([this._prefs]);

  Future<SharedPreferences> _resolvePrefs() async {
    if (_prefs != null) return _prefs!;
    return await SharedPreferences.getInstance();
  }

  /// Builds a storage key for track-specific offset.
  static String keyForTrack(String trackId) => '$kLyricsSyncOffsetPrefix$trackId';

  /// Loads the persisted offset in milliseconds for [trackId]. Returns null if not set.
  Future<int?> getOffset(String trackId) async {
    final prefs = await _resolvePrefs();
    return prefs.getInt(keyForTrack(trackId));
  }

  /// Persists [offsetMs] for [trackId].
  Future<void> saveOffset(String trackId, int offsetMs) async {
    final prefs = await _resolvePrefs();
    final snapped = clampAndSnapLyricsOffset(offsetMs);
    await prefs.setInt(keyForTrack(trackId), snapped);
  }

  /// Removes the custom per-track offset for [trackId].
  Future<void> removeOffset(String trackId) async {
    final prefs = await _resolvePrefs();
    await prefs.remove(keyForTrack(trackId));
  }

  /// Returns all stored track offset mappings.
  Future<Map<String, int>> getAllOffsets() async {
    final prefs = await _resolvePrefs();
    final keys = prefs.getKeys().where((k) => k.startsWith(kLyricsSyncOffsetPrefix));
    final map = <String, int>{};
    for (final key in keys) {
      final trackId = key.substring(kLyricsSyncOffsetPrefix.length);
      final val = prefs.getInt(key);
      if (val != null) {
        map[trackId] = val;
      }
    }
    return map;
  }

  /// Clears all stored lyrics sync offsets.
  Future<void> clearAll() async {
    final prefs = await _resolvePrefs();
    final keys = prefs.getKeys().where((k) => k.startsWith(kLyricsSyncOffsetPrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

// ============================================================================
// State Model: LyricsSyncOffsetState
// ============================================================================

/// Immutable state representing current lyrics sync offset configuration.
@immutable
class LyricsSyncOffsetState {
  /// Current synchronization offset in milliseconds (-5000ms to +5000ms).
  final int offsetMs;

  /// Active track identifier if bound to a specific track.
  final String? trackId;

  /// Whether the current track has a persisted custom offset.
  final bool isPersisted;

  /// Whether an asynchronous disk load operation is currently underway.
  final bool isLoading;

  const LyricsSyncOffsetState({
    this.offsetMs = kDefaultLyricsSyncOffsetMs,
    this.trackId,
    this.isPersisted = false,
    this.isLoading = false,
  });

  /// Offset as a standard [Duration].
  Duration get offsetDuration => Duration(milliseconds: offsetMs);

  /// True when lyrics are strictly in sync with no offset applied (0 ms).
  bool get isInSync => offsetMs == 0;

  /// True when lyrics are delayed (offset > 0 ms).
  bool get isDelayed => offsetMs > 0;

  /// True when lyrics are shifted earlier (offset < 0 ms).
  bool get isEarlier => offsetMs < 0;

  /// Offset converted into fractional seconds.
  double get offsetSeconds => offsetMs / 1000.0;

  /// User-facing formatted offset (e.g., "+200 ms", "-150 ms", "0 ms").
  String get formattedOffset => formatLyricsSyncOffset(offsetMs);

  /// User-facing formatted seconds (e.g., "+0.20s", "-0.15s", "0.00s").
  String get formattedSeconds => formatLyricsSyncOffsetSeconds(offsetMs);

  /// Descriptive status text.
  String get statusText => formatLyricsSyncStatusDescription(offsetMs);

  LyricsSyncOffsetState copyWith({
    int? offsetMs,
    String? trackId,
    bool? isPersisted,
    bool? isLoading,
  }) {
    return LyricsSyncOffsetState(
      offsetMs: offsetMs ?? this.offsetMs,
      trackId: trackId ?? this.trackId,
      isPersisted: isPersisted ?? this.isPersisted,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsSyncOffsetState &&
          runtimeType == other.runtimeType &&
          offsetMs == other.offsetMs &&
          trackId == other.trackId &&
          isPersisted == other.isPersisted &&
          isLoading == other.isLoading;

  @override
  int get hashCode => Object.hash(offsetMs, trackId, isPersisted, isLoading);

  @override
  String toString() =>
      'LyricsSyncOffsetState(offsetMs: $offsetMs, trackId: $trackId, isPersisted: $isPersisted, isLoading: $isLoading)';
}

// ============================================================================
// Controller: LyricsSyncOffsetController
// ============================================================================

/// Riverpod StateNotifier managing live lyrics sync offset adjustments,
/// per-track persistence, step snapping, nudging, and resets.
class LyricsSyncOffsetController extends StateNotifier<LyricsSyncOffsetState> {
  final Ref? _ref;
  final LyricsSyncOffsetStorage _storage;

  LyricsSyncOffsetController({
    Ref? ref,
    LyricsSyncOffsetStorage? storage,
    String? initialTrackId,
    int initialOffsetMs = kDefaultLyricsSyncOffsetMs,
  })  : _ref = ref,
        _storage = storage ?? LyricsSyncOffsetStorage(),
        super(LyricsSyncOffsetState(
          offsetMs: clampAndSnapLyricsOffset(initialOffsetMs),
          trackId: initialTrackId,
        )) {
    if (initialTrackId != null) {
      loadForTrack(initialTrackId);
    }
  }

  /// Current duration offset helper.
  Duration get currentDurationOffset => state.offsetDuration;

  /// Current millisecond offset helper.
  int get currentOffsetMs => state.offsetMs;

  /// Loads persisted offset for [trackId]. If no saved offset exists, resets to 0 ms.
  Future<void> loadForTrack(String trackId) async {
    state = state.copyWith(isLoading: true, trackId: trackId);
    try {
      final savedOffset = await _storage.getOffset(trackId);
      if (!mounted) return;

      if (savedOffset != null) {
        state = state.copyWith(
          offsetMs: clampAndSnapLyricsOffset(savedOffset),
          trackId: trackId,
          isPersisted: true,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          offsetMs: kDefaultLyricsSyncOffsetMs,
          trackId: trackId,
          isPersisted: false,
          isLoading: false,
        );
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Sets track context. If [trackId] is null, untracks and retains current offset.
  Future<void> setTrackId(String? trackId) async {
    if (trackId == null) {
      state = state.copyWith(trackId: null, isPersisted: false);
      return;
    }
    if (state.trackId == trackId) return;
    await loadForTrack(trackId);
  }

  /// Sets sync offset in milliseconds, automatically snapping to 50ms steps and
  /// clamping between -5000ms and +5000ms.
  ///
  /// If [persist] is true and a [trackId] is active, the value is saved to disk.
  Future<void> setOffset(int newOffsetMs, {bool persist = true}) async {
    final clamped = clampAndSnapLyricsOffset(newOffsetMs);
    final activeTrackId = state.trackId;

    state = state.copyWith(
      offsetMs: clamped,
      isPersisted: persist && activeTrackId != null && clamped != 0,
    );

    if (persist && activeTrackId != null) {
      if (clamped == 0) {
        await _storage.removeOffset(activeTrackId);
      } else {
        await _storage.saveOffset(activeTrackId, clamped);
      }
    }
  }

  /// Nudges lyrics offset earlier (negative delta), advancing lyrics relative to vocals.
  /// Defaults to -100ms.
  Future<void> nudgeEarlier([int deltaMs = kLyricsSyncOffsetNudgeStepMs]) async {
    final target = state.offsetMs - deltaMs.abs();
    await setOffset(target);
  }

  /// Nudges lyrics offset later (positive delta), delaying lyrics relative to vocals.
  /// Defaults to +100ms.
  Future<void> nudgeLater([int deltaMs = kLyricsSyncOffsetNudgeStepMs]) async {
    final target = state.offsetMs + deltaMs.abs();
    await setOffset(target);
  }

  /// Resets sync offset to 0 ms and clears any custom per-track persisted offset.
  Future<void> reset() async {
    final activeTrackId = state.trackId;
    state = state.copyWith(
      offsetMs: kDefaultLyricsSyncOffsetMs,
      isPersisted: false,
    );

    if (activeTrackId != null) {
      await _storage.removeOffset(activeTrackId);
    }
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Storage repository provider for lyrics sync offset persistence.
final lyricsSyncOffsetStorageProvider = Provider<LyricsSyncOffsetStorage>((ref) {
  return LyricsSyncOffsetStorage();
});

/// Primary Riverpod StateNotifierProvider managing active lyrics sync offset.
/// Automatically synchronizes track identity with [currentTrackProvider] when available.
final lyricsSyncOffsetProvider =
    StateNotifierProvider<LyricsSyncOffsetController, LyricsSyncOffsetState>((ref) {
  final storage = ref.watch(lyricsSyncOffsetStorageProvider);
  final controller = LyricsSyncOffsetController(ref: ref, storage: storage);

  // Automatically listen to current playing track changes
  try {
    ref.listen<AsyncValue<Track?>>(currentTrackProvider, (previous, next) {
      final currentTrack = next.valueOrNull;
      if (currentTrack != null) {
        controller.setTrackId(currentTrack.id);
      }
    });
  } catch (_) {
    // Graceful fallback for isolated test harnesses
  }

  return controller;
});

/// Family provider yielding an independent [LyricsSyncOffsetController] scoped to [trackId].
final lyricsSyncOffsetForTrackProvider = StateNotifierProvider.family<
    LyricsSyncOffsetController, LyricsSyncOffsetState, String>((ref, trackId) {
  final storage = ref.watch(lyricsSyncOffsetStorageProvider);
  return LyricsSyncOffsetController(
    ref: ref,
    storage: storage,
    initialTrackId: trackId,
  );
});

/// Computed helper provider exposing the current sync offset as a [Duration].
final currentLyricsOffsetDurationProvider = Provider<Duration>((ref) {
  return ref.watch(lyricsSyncOffsetProvider).offsetDuration;
});

/// Computed helper provider exposing the current sync offset in integer milliseconds.
final currentLyricsOffsetMsProvider = Provider<int>((ref) {
  return ref.watch(lyricsSyncOffsetProvider).offsetMs;
});

// ============================================================================
// UI Component: LyricsSyncOffsetSlider
// ============================================================================

/// Production-grade Material 3 lyrics sync offset slider with per-track persistence,
/// live real-time scrubbing (-5000ms to +5000ms in 50ms increments),
/// ±100ms quick nudge buttons, and instant reset capability.
class LyricsSyncOffsetSlider extends ConsumerWidget {
  /// Optional track identifier to scope this slider specifically to one track.
  /// If omitted, the global active [lyricsSyncOffsetProvider] is consumed.
  final String? trackId;

  /// Optional callback invoked whenever the offset changes.
  final ValueChanged<int>? onOffsetChanged;

  /// Whether to render the header section with status badge and title.
  final bool showHeader;

  /// Whether to display the ±100ms nudge buttons and reset action.
  final bool showNudgeButtons;

  /// Whether to display the reset action button.
  final bool showResetButton;

  /// Whether to display preset jump chips (e.g. -500ms, 0ms, +500ms).
  final bool showPresets;

  /// Whether to render in a compact horizontal bar layout.
  final bool isCompact;

  /// Optional outer padding.
  final EdgeInsetsGeometry? padding;

  /// Custom title for header.
  final String? title;

  const LyricsSyncOffsetSlider({
    super.key,
    this.trackId,
    this.onOffsetChanged,
    this.showHeader = true,
    this.showNudgeButtons = true,
    this.showResetButton = true,
    this.showPresets = true,
    this.isCompact = false,
    this.padding,
    this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = trackId != null
        ? ref.watch(lyricsSyncOffsetForTrackProvider(trackId!))
        : ref.watch(lyricsSyncOffsetProvider);

    final notifier = trackId != null
        ? ref.read(lyricsSyncOffsetForTrackProvider(trackId!).notifier)
        : ref.read(lyricsSyncOffsetProvider.notifier);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isCompact) {
      return _buildCompactLayout(context, state, notifier, theme, isDark);
    }

    return _buildExpandedCard(context, state, notifier, theme, isDark);
  }

  Widget _buildCompactLayout(
    BuildContext context,
    LyricsSyncOffsetState state,
    LyricsSyncOffsetController notifier,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.card : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : theme.dividerColor,
        ),
      ),
      child: Row(
        children: [
          // Nudge Earlier (-100ms)
          _buildNudgeIconButton(
            context: context,
            key: const Key('lyrics_offset_nudge_earlier'),
            tooltip: 'Nudge lyrics 100ms earlier (-100ms)',
            icon: Icons.fast_rewind_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              notifier.nudgeEarlier();
              onOffsetChanged?.call(notifier.currentOffsetMs);
            },
          ),
          const SizedBox(width: 8),

          // Slider
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '-5s',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      state.formattedOffset,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _statusColor(state.offsetMs, theme),
                      ),
                    ),
                    Text(
                      '+5s',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: _sliderThemeData(context, theme),
                  child: Slider(
                    key: const Key('lyrics_sync_offset_slider_widget'),
                    value: state.offsetMs.toDouble(),
                    min: kMinLyricsSyncOffsetMs.toDouble(),
                    max: kMaxLyricsSyncOffsetMs.toDouble(),
                    divisions: 200, // 10000ms / 50ms = 200 steps
                    onChanged: (val) {
                      final snapped = clampAndSnapLyricsOffset(val.round());
                      notifier.setOffset(snapped);
                      onOffsetChanged?.call(snapped);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Nudge Later (+100ms)
          _buildNudgeIconButton(
            context: context,
            key: const Key('lyrics_offset_nudge_later'),
            tooltip: 'Nudge lyrics 100ms later (+100ms)',
            icon: Icons.fast_forward_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              notifier.nudgeLater();
              onOffsetChanged?.call(notifier.currentOffsetMs);
            },
          ),

          if (showResetButton) ...[
            const SizedBox(width: 4),
            _buildResetIconButton(
              context: context,
              key: const Key('lyrics_offset_reset'),
              enabled: state.offsetMs != 0,
              onPressed: () {
                HapticFeedback.mediumImpact();
                notifier.reset();
                onOffsetChanged?.call(0);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandedCard(
    BuildContext context,
    LyricsSyncOffsetState state,
    LyricsSyncOffsetController notifier,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.card : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : theme.dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          if (showHeader) ...[
            _buildHeader(context, state, theme),
            const SizedBox(height: 12),
          ],

          // Offset Value Display & Descriptive Subtitle
          _buildOffsetReadout(context, state, theme),
          const SizedBox(height: 14),

          // Live Offset Slider
          SliderTheme(
            data: _sliderThemeData(context, theme),
            child: Slider(
              key: const Key('lyrics_sync_offset_slider_widget'),
              value: state.offsetMs.toDouble(),
              min: kMinLyricsSyncOffsetMs.toDouble(),
              max: kMaxLyricsSyncOffsetMs.toDouble(),
              divisions: 200, // 200 divisions of 50ms = 10,000ms range
              label: state.formattedOffset,
              onChanged: (val) {
                final snapped = clampAndSnapLyricsOffset(val.round());
                notifier.setOffset(snapped);
                onOffsetChanged?.call(snapped);
              },
            ),
          ),

          // Boundary Labels (-5.0s, 0s, +5.0s)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '-5.0s (Advance)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '0s (Default)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '+5.0s (Delay)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Controls: Nudge Buttons & Reset
          if (showNudgeButtons || showResetButton) ...[
            _buildControlsRow(context, state, notifier, theme),
            const SizedBox(height: 12),
          ],

          // Preset Chips Row
          if (showPresets) ...[
            _buildPresetChips(context, state, notifier, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    LyricsSyncOffsetState state,
    ThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sync_rounded,
                size: 20,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title ?? 'Lyrics Sync Offset',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),

        // Status pill / Persisted badge
        _buildStatusBadge(context, state, theme),
      ],
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    LyricsSyncOffsetState state,
    ThemeData theme,
  ) {
    final color = _statusColor(state.offsetMs, theme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state.isInSync
                ? Icons.check_circle_rounded
                : state.isEarlier
                    ? Icons.fast_rewind_rounded
                    : Icons.fast_forward_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            state.isInSync ? 'Synced' : state.formattedOffset,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (state.isPersisted) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.bookmark_added_rounded,
              size: 13,
              color: color,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOffsetReadout(
    BuildContext context,
    LyricsSyncOffsetState state,
    ThemeData theme,
  ) {
    final color = _statusColor(state.offsetMs, theme);

    return Center(
      child: Column(
        children: [
          Text(
            state.formattedOffset,
            key: const Key('lyrics_offset_readout_text'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            state.statusText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsRow(
    BuildContext context,
    LyricsSyncOffsetState state,
    LyricsSyncOffsetController notifier,
    ThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // -100ms Nudge Button
        Expanded(
          child: BouncingScaleButton(
            child: OutlinedButton.icon(
              key: const Key('lyrics_offset_nudge_earlier'),
              onPressed: () {
                HapticFeedback.lightImpact();
                notifier.nudgeEarlier();
                onOffsetChanged?.call(notifier.currentOffsetMs);
              },
              icon: const Icon(Icons.remove_rounded, size: 16),
              label: const Text('-100ms'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: BorderSide(color: Colors.white.withOpacity(0.12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Reset Button
        if (showResetButton) ...[
          Expanded(
            child: BouncingScaleButton(
              child: FilledButton.tonalIcon(
                key: const Key('lyrics_offset_reset'),
                onPressed: state.offsetMs == 0
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        notifier.reset();
                        onOffsetChanged?.call(0);
                      },
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Reset'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.surfaceHighlight,
                  foregroundColor: AppTheme.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],

        // +100ms Nudge Button
        Expanded(
          child: BouncingScaleButton(
            child: OutlinedButton.icon(
              key: const Key('lyrics_offset_nudge_later'),
              onPressed: () {
                HapticFeedback.lightImpact();
                notifier.nudgeLater();
                onOffsetChanged?.call(notifier.currentOffsetMs);
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('+100ms'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: BorderSide(color: Colors.white.withOpacity(0.12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChips(
    BuildContext context,
    LyricsSyncOffsetState state,
    LyricsSyncOffsetController notifier,
    ThemeData theme,
  ) {
    const presets = [-1000, -500, 0, 500, 1000];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: presets.map((preset) {
          final isSelected = state.offsetMs == preset;
          final label = preset == 0 ? '0s' : '${preset > 0 ? '+' : ''}${preset / 1000}s';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              key: Key('lyrics_offset_preset_$preset'),
              selected: isSelected,
              label: Text(label),
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              backgroundColor: AppTheme.surfaceHighlight.withOpacity(0.6),
              selectedColor: AppTheme.accent,
              checkmarkColor: Colors.white,
              showCheckmark: false,
              side: BorderSide(
                color: isSelected
                    ? AppTheme.accent
                    : Colors.white.withOpacity(0.08),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              onSelected: (_) {
                HapticFeedback.lightImpact();
                notifier.setOffset(preset);
                onOffsetChanged?.call(preset);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNudgeIconButton({
    required BuildContext context,
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      color: AppTheme.textPrimary,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.surfaceHighlight,
        padding: const EdgeInsets.all(8),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildResetIconButton({
    required BuildContext context,
    required Key key,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: 'Reset offset to 0 ms',
      icon: const Icon(Icons.restart_alt_rounded, size: 20),
      color: enabled ? AppTheme.accent : AppTheme.textMuted,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.surfaceHighlight,
        padding: const EdgeInsets.all(8),
      ),
      onPressed: enabled ? onPressed : null,
    );
  }

  Color _statusColor(int offsetMs, ThemeData theme) {
    if (offsetMs == 0) return const Color(0xFF1DB954); // Emerald sync
    if (offsetMs > 0) return const Color(0xFFFF9800); // Amber delay
    return const Color(0xFF03A9F4); // Cyan advance
  }

  SliderThemeData _sliderThemeData(BuildContext context, ThemeData theme) {
    return SliderTheme.of(context).copyWith(
      activeTrackColor: AppTheme.accent,
      inactiveTrackColor: Colors.white.withOpacity(0.12),
      thumbColor: Colors.white,
      overlayColor: AppTheme.accent.withOpacity(0.24),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      trackHeight: 4,
      valueIndicatorColor: AppTheme.surfaceElevated,
      valueIndicatorTextStyle: const TextStyle(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }
}

// ============================================================================
// Modal Dialog & Bottom Sheet Helpers
// ============================================================================

/// Presents the [LyricsSyncOffsetSlider] inside a modern Material 3 bottom sheet.
Future<void> showLyricsSyncOffsetModalSheet(
  BuildContext context, {
  String? trackId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LyricsSyncOffsetSlider(
              trackId: trackId,
            ),
          ),
        ),
      );
    },
  );
}

/// Presents the [LyricsSyncOffsetSlider] inside a centered Material 3 dialog.
Future<void> showLyricsSyncOffsetDialog(
  BuildContext context, {
  String? trackId,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: LyricsSyncOffsetSlider(
            trackId: trackId,
          ),
        ),
      );
    },
  );
}
