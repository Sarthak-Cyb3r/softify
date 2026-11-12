// ============================================================================
// Softify Quality of Life (QoL) - Feature 32: Discord RPC Privacy Masking Options
// ============================================================================
//
// Provides granular privacy controls for Discord Rich Presence integration on
// desktop platforms (Linux, macOS, Windows).
//
// Supported Privacy Modes:
//  - Full Detail: Shows track title, artist name, album, and playback elapsed time.
//  - Hide Title: Shows artist name only; song title is hidden for privacy.
//  - Generic: Displays "Listening to Music" with no track or artist metadata.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/track.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/shared/app_surface.dart';

// ============================================================================
// Constants & SharedPreferences Keys
// ============================================================================

/// Storage key for persisting the active Discord RPC privacy mode.
const String kDiscordRpcPrivacyModeKey = 'softify_discord_rpc_privacy_mode';

/// Storage key for enabling/disabling Discord RPC broadcasting.
const String kDiscordRpcEnabledKey = 'softify_discord_rpc_enabled';

/// Storage key for whether elapsed/remaining playback timestamps are broadcast.
const String kDiscordRpcShowTimestampsKey = 'softify_discord_rpc_show_timestamps';

/// Storage key for custom generic status text.
const String kDiscordRpcGenericTextKey = 'softify_discord_rpc_generic_text';

/// Standard default placeholder string when generic privacy mode is active.
const String kDefaultGenericStatusText = 'Listening to Music';

/// Standard placeholder string when title is masked but artist is shown.
const String kMaskedSongTitleText = 'Listening to music';

/// Default client id used by Softify for Discord Rich Presence IPC.
const String kDefaultDiscordClientId = '1225849845771767909';

// ============================================================================
// SharedPreferences Persistence Engine
// ============================================================================

/// Self-contained SharedPreferences persistence store compatible with standard API.
///
/// Handles mock values for test harnesses and falls back to in-memory storage
/// when filesystem access is unavailable.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  SharedPreferences._(this._store, this._file);

  /// Synchronously accessible cached singleton instance if resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects mock initial values for testing environments.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets singleton instance for test teardown.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Resolves or initializes the SharedPreferences singleton instance.
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
      file = await _resolveStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            decoded.forEach((key, value) {
              if (value != null) {
                store[key] = value as Object;
              }
            });
          }
        }
      }
    } catch (_) {
      // In-memory fallback if file system access fails
    }

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  static Future<File?> _resolveStorageFile() async {
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
    final file = _file;
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_store);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  bool containsKey(String key) => _store.containsKey(key);

  String? getString(String key) {
    final val = _store[key];
    return val is String ? val : null;
  }

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  bool? getBool(String key) {
    final val = _store[key];
    return val is bool ? val : null;
  }

  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  Future<bool> remove(String key) async {
    _store.remove(key);
    await _persist();
    return true;
  }

  Future<bool> clear() async {
    _store.clear();
    await _persist();
    return true;
  }
}

// ============================================================================
// Enum: DiscordPrivacyMode
// ============================================================================

/// Privacy display modes for Discord Rich Presence broadcasting.
enum DiscordPrivacyMode {
  /// Full Detail: Reveals track title, artist name, album name, and playback progress.
  fullDetail(
    id: 'full_detail',
    label: 'Full Detail',
    subtitle: 'Show track title, artist, and playback progress',
    description:
        'Broadcasting full information to friends. Shows exact song title, artist, album, and duration.',
    icon: Icons.visibility_rounded,
  ),

  /// Hide Title: Reveals the artist name while concealing the specific track title.
  hideTitle(
    id: 'hide_title',
    label: 'Hide Title',
    subtitle: 'Show artist only; keep song title private',
    description:
        'Conceals the specific track title and album, but shares which artist you are enjoying.',
    icon: Icons.person_rounded,
  ),

  /// Generic: Replaces song and artist entirely with "Listening to Music".
  generic(
    id: 'generic',
    label: 'Generic',
    subtitle: 'Show "Listening to Music" without song or artist details',
    description:
        'Maximum privacy. Displays a generic "Listening to Music" presence with zero song or artist metadata.',
    icon: Icons.music_note_rounded,
  );

  final String id;
  final String label;
  final String subtitle;
  final String description;
  final IconData icon;

  const DiscordPrivacyMode({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.description,
    required this.icon,
  });

  /// Resolves [DiscordPrivacyMode] from its persistent string identifier.
  static DiscordPrivacyMode fromId(String? id) {
    if (id == null) return DiscordPrivacyMode.fullDetail;
    return DiscordPrivacyMode.values.firstWhere(
      (m) => m.id == id,
      orElse: () => DiscordPrivacyMode.fullDetail,
    );
  }
}

// ============================================================================
// Model: MaskedDiscordPresence
// ============================================================================

/// Immutable model representing the masked Rich Presence activity data
/// ready to be serialized and dispatched to the Discord IPC socket.
@immutable
class MaskedDiscordPresence {
  /// Primary line in Discord presence (typically the song title or generic label).
  final String details;

  /// Secondary line in Discord presence (typically artist info or player name).
  final String? state;

  /// Discord asset key for the large application image.
  final String largeImageKey;

  /// Tooltip text for the large application asset.
  final String largeImageText;

  /// Discord asset key for the small playback badge (play / pause).
  final String smallImageKey;

  /// Tooltip text for the small playback badge.
  final String smallImageText;

  /// Whether playback duration timestamps (start / end) are included.
  final bool showTimestamps;

  /// Playback state.
  final bool isPlaying;

  /// Active privacy mode applied to create this masked presence.
  final DiscordPrivacyMode mode;

  /// Whether active Rich Presence should be visible or cleared.
  final bool isActive;

  const MaskedDiscordPresence({
    required this.details,
    this.state,
    this.largeImageKey = 'softify_logo',
    this.largeImageText = 'Softify Music',
    this.smallImageKey = 'play',
    this.smallImageText = 'Playing',
    this.showTimestamps = true,
    this.isPlaying = true,
    this.mode = DiscordPrivacyMode.fullDetail,
    this.isActive = true,
  });

  /// Factory for empty or idle presence when no music is playing or Discord RPC is disabled.
  factory MaskedDiscordPresence.idle({
    DiscordPrivacyMode mode = DiscordPrivacyMode.fullDetail,
  }) {
    return MaskedDiscordPresence(
      details: '',
      state: null,
      largeImageKey: 'softify_logo',
      largeImageText: 'Softify Music',
      smallImageKey: 'pause',
      smallImageText: 'Paused',
      showTimestamps: false,
      isPlaying: false,
      mode: mode,
      isActive: false,
    );
  }

  /// Builds a Discord IPC Opcode 1 (`SET_ACTIVITY`) payload dictionary.
  Map<String, dynamic> toActivityMap({
    required int pid,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
    int? currentEpochSec,
  }) {
    if (!isActive || !isPlaying) {
      return {
        'pid': pid,
        'activity': null,
      };
    }

    final now = currentEpochSec ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final startSec = now - position.inSeconds;
    final remainingSec = duration.inSeconds - position.inSeconds;
    final endSec = remainingSec > 0 ? now + remainingSec : null;

    final Map<String, dynamic> timestamps = {};
    if (showTimestamps) {
      timestamps['start'] = startSec;
      if (endSec != null) {
        timestamps['end'] = endSec;
      }
    }

    final activity = <String, dynamic>{
      'details': details,
      if (state != null && state!.isNotEmpty) 'state': state,
      if (showTimestamps && timestamps.isNotEmpty) 'timestamps': timestamps,
      'assets': {
        'large_image': largeImageKey,
        'large_text': largeImageText,
        'small_image': isPlaying ? 'play' : 'pause',
        'small_text': isPlaying ? 'Playing' : 'Paused',
      },
      'instance': false,
    };

    return {
      'pid': pid,
      'activity': activity,
    };
  }

  /// Converts this presence into a privacy-masked [Track] instance
  /// that can be safely passed to legacy Discord RPC or MPRIS consumers.
  Track? toMaskedTrack(Track? original) {
    if (original == null) return null;

    switch (mode) {
      case DiscordPrivacyMode.fullDetail:
        return original;
      case DiscordPrivacyMode.hideTitle:
        return original.copyWith(
          title: details,
          album: null,
        );
      case DiscordPrivacyMode.generic:
        return original.copyWith(
          title: details,
          artist: state ?? 'Softify',
          album: null,
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaskedDiscordPresence &&
          runtimeType == other.runtimeType &&
          details == other.details &&
          state == other.state &&
          largeImageKey == other.largeImageKey &&
          largeImageText == other.largeImageText &&
          smallImageKey == other.smallImageKey &&
          smallImageText == other.smallImageText &&
          showTimestamps == other.showTimestamps &&
          isPlaying == other.isPlaying &&
          mode == other.mode &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(
        details,
        state,
        largeImageKey,
        largeImageText,
        smallImageKey,
        smallImageText,
        showTimestamps,
        isPlaying,
        mode,
        isActive,
      );

  @override
  String toString() =>
      'MaskedDiscordPresence(mode: ${mode.name}, details: "$details", state: "$state", isPlaying: $isPlaying, isActive: $isActive)';
}

// ============================================================================
// Pure Masking Engine: DiscordPrivacyMasker
// ============================================================================

/// Pure Dart utility responsible for transforming raw playback track metadata
/// into privacy-compliant Rich Presence activity data.
class DiscordPrivacyMasker {
  const DiscordPrivacyMasker._();

  /// Masks track details according to the requested [mode].
  ///
  /// Returns a [MaskedDiscordPresence] structure ready for dispatch.
  static MaskedDiscordPresence maskPresence({
    required Track? track,
    required bool isPlaying,
    DiscordPrivacyMode mode = DiscordPrivacyMode.fullDetail,
    bool showTimestamps = true,
    bool isRpcEnabled = true,
    String genericText = kDefaultGenericStatusText,
    Duration position = Duration.zero,
  }) {
    // If master RPC is disabled, or no track is available, return idle presence
    if (!isRpcEnabled || track == null) {
      return MaskedDiscordPresence.idle(mode: mode);
    }

    final safeGeneric = genericText.trim().isNotEmpty
        ? genericText.trim()
        : kDefaultGenericStatusText;

    switch (mode) {
      case DiscordPrivacyMode.fullDetail:
        final hasAlbum = track.album != null && track.album!.trim().isNotEmpty;
        final artistText = track.artist.trim().isNotEmpty
            ? 'by ${track.artist.trim()}'
            : 'Softify';
        return MaskedDiscordPresence(
          details: track.title.trim().isNotEmpty ? track.title.trim() : 'Unknown Track',
          state: artistText,
          largeImageKey: 'softify_logo',
          largeImageText: hasAlbum ? track.album!.trim() : 'Softify Music',
          smallImageKey: isPlaying ? 'play' : 'pause',
          smallImageText: isPlaying ? 'Playing' : 'Paused',
          showTimestamps: showTimestamps,
          isPlaying: isPlaying,
          mode: mode,
          isActive: true,
        );

      case DiscordPrivacyMode.hideTitle:
        final artistText = track.artist.trim().isNotEmpty
            ? 'by ${track.artist.trim()}'
            : 'Softify';
        return MaskedDiscordPresence(
          details: kMaskedSongTitleText,
          state: artistText,
          largeImageKey: 'softify_logo',
          largeImageText: 'Softify Music',
          smallImageKey: isPlaying ? 'play' : 'pause',
          smallImageText: isPlaying ? 'Playing' : 'Paused',
          showTimestamps: showTimestamps,
          isPlaying: isPlaying,
          mode: mode,
          isActive: true,
        );

      case DiscordPrivacyMode.generic:
        return MaskedDiscordPresence(
          details: safeGeneric,
          state: 'Softify',
          largeImageKey: 'softify_logo',
          largeImageText: 'Softify Music',
          smallImageKey: isPlaying ? 'play' : 'pause',
          smallImageText: isPlaying ? 'Playing' : 'Paused',
          showTimestamps: showTimestamps,
          isPlaying: isPlaying,
          mode: mode,
          isActive: true,
        );
    }
  }

  /// Transforms a [Track] into a privacy-masked equivalent.
  static Track? maskTrack(
    Track? track, {
    DiscordPrivacyMode mode = DiscordPrivacyMode.fullDetail,
    String genericText = kDefaultGenericStatusText,
  }) {
    if (track == null) return null;

    switch (mode) {
      case DiscordPrivacyMode.fullDetail:
        return track;
      case DiscordPrivacyMode.hideTitle:
        return track.copyWith(
          title: kMaskedSongTitleText,
          album: null,
        );
      case DiscordPrivacyMode.generic:
        return track.copyWith(
          title: genericText.trim().isNotEmpty
              ? genericText.trim()
              : kDefaultGenericStatusText,
          artist: 'Softify',
          album: null,
        );
    }
  }
}

// ============================================================================
// State Model: DiscordPrivacyState
// ============================================================================

/// Immutable state managing the Discord Rich Presence privacy configuration.
@immutable
class DiscordPrivacyState {
  /// Active privacy mode.
  final DiscordPrivacyMode mode;

  /// Master switch indicating whether Discord Rich Presence broadcasting is active.
  final bool isEnabled;

  /// Whether playback duration timestamps (start / end) are broadcast to Discord.
  final bool showTimestamps;

  /// Custom label applied when [DiscordPrivacyMode.generic] is active.
  final String genericText;

  const DiscordPrivacyState({
    this.mode = DiscordPrivacyMode.fullDetail,
    this.isEnabled = true,
    this.showTimestamps = true,
    this.genericText = kDefaultGenericStatusText,
  });

  DiscordPrivacyState copyWith({
    DiscordPrivacyMode? mode,
    bool? isEnabled,
    bool? showTimestamps,
    String? genericText,
  }) {
    return DiscordPrivacyState(
      mode: mode ?? this.mode,
      isEnabled: isEnabled ?? this.isEnabled,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      genericText: genericText ?? this.genericText,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.id,
        'isEnabled': isEnabled,
        'showTimestamps': showTimestamps,
        'genericText': genericText,
      };

  factory DiscordPrivacyState.fromJson(Map<String, dynamic> json) {
    return DiscordPrivacyState(
      mode: DiscordPrivacyMode.fromId(json['mode'] as String?),
      isEnabled: json['isEnabled'] as bool? ?? true,
      showTimestamps: json['showTimestamps'] as bool? ?? true,
      genericText: json['genericText'] as String? ?? kDefaultGenericStatusText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscordPrivacyState &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          isEnabled == other.isEnabled &&
          showTimestamps == other.showTimestamps &&
          genericText == other.genericText;

  @override
  int get hashCode => Object.hash(mode, isEnabled, showTimestamps, genericText);

  @override
  String toString() =>
      'DiscordPrivacyState(mode: ${mode.name}, enabled: $isEnabled, timestamps: $showTimestamps, genericText: "$genericText")';
}

// ============================================================================
// Controller: DiscordPrivacyController
// ============================================================================

/// Riverpod StateNotifier controlling Discord Rich Presence privacy modes,
/// disk persistence, and masking logic.
class DiscordPrivacyController extends StateNotifier<DiscordPrivacyState> {
  final SharedPreferences? _prefs;

  DiscordPrivacyController({
    DiscordPrivacyState? initialState,
    SharedPreferences? prefs,
  })  : _prefs = prefs,
        super(initialState ?? const DiscordPrivacyState()) {
    _loadFromPreferences();
  }

  /// Asynchronously loads persisted privacy preferences from disk.
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();

      final modeId = prefs.getString(kDiscordRpcPrivacyModeKey);
      final isEnabled = prefs.getBool(kDiscordRpcEnabledKey);
      final showTimestamps = prefs.getBool(kDiscordRpcShowTimestampsKey);
      final genericText = prefs.getString(kDiscordRpcGenericTextKey);

      state = state.copyWith(
        mode: modeId != null ? DiscordPrivacyMode.fromId(modeId) : state.mode,
        isEnabled: isEnabled ?? state.isEnabled,
        showTimestamps: showTimestamps ?? state.showTimestamps,
        genericText: genericText ?? state.genericText,
      );
    } catch (_) {
      // Keep defaults if reading preferences fails
    }
  }

  /// Persists current state properties to disk.
  Future<void> _saveToPreferences() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(kDiscordRpcPrivacyModeKey, state.mode.id);
      await prefs.setBool(kDiscordRpcEnabledKey, state.isEnabled);
      await prefs.setBool(kDiscordRpcShowTimestampsKey, state.showTimestamps);
      await prefs.setString(kDiscordRpcGenericTextKey, state.genericText);
    } catch (_) {
      // Non-fatal if persistence fails
    }
  }

  /// Sets the active Discord Rich Presence privacy mode.
  Future<void> setMode(DiscordPrivacyMode mode) async {
    if (state.mode == mode) return;
    state = state.copyWith(mode: mode);
    await _saveToPreferences();
  }

  /// Enables or disables Discord Rich Presence broadcasting globally.
  Future<void> setEnabled(bool isEnabled) async {
    if (state.isEnabled == isEnabled) return;
    state = state.copyWith(isEnabled: isEnabled);
    await _saveToPreferences();
  }

  /// Toggles master Discord Rich Presence broadcasting.
  Future<void> toggleEnabled() async {
    await setEnabled(!state.isEnabled);
  }

  /// Enables or disables broadcasting elapsed playback timestamps.
  Future<void> setShowTimestamps(bool showTimestamps) async {
    if (state.showTimestamps == showTimestamps) return;
    state = state.copyWith(showTimestamps: showTimestamps);
    await _saveToPreferences();
  }

  /// Toggles elapsed playback timestamps.
  Future<void> toggleShowTimestamps() async {
    await setShowTimestamps(!state.showTimestamps);
  }

  /// Sets custom generic status text.
  Future<void> setGenericText(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || clean == state.genericText) return;
    state = state.copyWith(genericText: clean);
    await _saveToPreferences();
  }

  /// Cycles to the next privacy mode: Full Detail -> Hide Title -> Generic -> Full Detail.
  Future<void> cycleNextMode() async {
    final values = DiscordPrivacyMode.values;
    final nextIndex = (values.indexOf(state.mode) + 1) % values.length;
    await setMode(values[nextIndex]);
  }

  /// Resets privacy configuration back to production defaults.
  Future<void> resetToDefaults() async {
    state = const DiscordPrivacyState();
    await _saveToPreferences();
  }

  /// Masks a track using the current controller state.
  MaskedDiscordPresence maskPresence({
    required Track? track,
    required bool isPlaying,
    Duration position = Duration.zero,
  }) {
    return DiscordPrivacyMasker.maskPresence(
      track: track,
      isPlaying: isPlaying,
      mode: state.mode,
      showTimestamps: state.showTimestamps,
      isRpcEnabled: state.isEnabled,
      genericText: state.genericText,
      position: position,
    );
  }

  /// Masks a track entity into its privacy-safe equivalent.
  Track? maskTrack(Track? track) {
    if (!state.isEnabled) return null;
    return DiscordPrivacyMasker.maskTrack(
      track,
      mode: state.mode,
      genericText: state.genericText,
    );
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Global StateNotifierProvider for [DiscordPrivacyController].
final discordPrivacyControllerProvider =
    StateNotifierProvider<DiscordPrivacyController, DiscordPrivacyState>((ref) {
  return DiscordPrivacyController();
});

/// Convenience provider returning the active [DiscordPrivacyMode].
final discordPrivacyModeProvider = Provider<DiscordPrivacyMode>((ref) {
  return ref.watch(discordPrivacyControllerProvider).mode;
});

/// Convenience provider returning whether Discord Rich Presence is enabled.
final isDiscordRpcEnabledProvider = Provider<bool>((ref) {
  return ref.watch(discordPrivacyControllerProvider).isEnabled;
});

/// Convenience provider returning whether elapsed timestamps are broadcast.
final discordRpcShowTimestampsProvider = Provider<bool>((ref) {
  return ref.watch(discordPrivacyControllerProvider).showTimestamps;
});

// ============================================================================
// UI Widget: DiscordPrivacySelectorTile
// ============================================================================

/// An expressive Material 3 Settings Tile for selecting Discord RPC Privacy Masking Options.
///
/// Features:
///  - Current mode indicator chip with contextual icon.
///  - Explanatory subtitle describing exactly what information is broadcast.
///  - Interactive selector bottom sheet with real-time Discord Rich Presence preview.
///  - Available as both an inline [ListTile] and a decorated [AppSurface] card.
class DiscordPrivacySelectorTile extends ConsumerWidget {
  /// Whether to render inside a decorated surface card container.
  final bool isCard;

  /// Whether to display the live Discord Rich Presence preview card inside the tile.
  final bool showPreview;

  /// Optional custom track to display in previews instead of demo track.
  final Track? customTrack;

  const DiscordPrivacySelectorTile({
    super.key,
    this.isCard = false,
    this.showPreview = false,
    this.customTrack,
  });

  /// Factory constructor rendering an elevated card with optional embedded preview.
  const DiscordPrivacySelectorTile.card({
    super.key,
    this.showPreview = true,
    this.customTrack,
  }) : isCard = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discordPrivacyControllerProvider);
    final tokens = context.tokens;

    final content = _buildTileContent(context, ref, state, tokens);

    if (!isCard) {
      return content;
    }

    return AppSurface(
      withBlur: false,
      color: tokens.card,
      borderRadius: BorderRadius.circular(tokens.radiusCard),
      padding: EdgeInsets.all(tokens.spaceMd),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          if (showPreview) ...[
            const SizedBox(height: 12),
            DiscordRichPresencePreviewCard(
              mode: state.mode,
              showTimestamps: state.showTimestamps,
              track: customTrack,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTileContent(
    BuildContext context,
    WidgetRef ref,
    DiscordPrivacyState state,
    AppTokens tokens,
  ) {
    final mode = state.mode;

    return ListTile(
      key: const Key('discord_privacy_tile'),
      contentPadding: isCard ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: state.isEnabled
              ? tokens.accent.withOpacity(0.18)
              : tokens.surfaceHighlight,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: state.isEnabled
                ? tokens.accent.withOpacity(0.4)
                : tokens.divider.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Icon(
          mode.icon,
          color: state.isEnabled ? tokens.accent : tokens.textSecondary,
          size: 22,
        ),
      ),
      title: const Text(
        'Discord Presence Privacy',
        style: TextStyle(
          fontFamily: AppTheme.fontUi,
          fontSize: 15.0,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          state.isEnabled
              ? mode.subtitle
              : 'Discord Rich Presence is disabled',
          style: TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 12.5,
            color: tokens.textSecondary,
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('discord_privacy_mode_chip'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: state.isEnabled
                  ? tokens.accent.withOpacity(0.15)
                  : tokens.surfaceElevated,
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              border: Border.all(
                color: state.isEnabled
                    ? tokens.accent.withOpacity(0.35)
                    : tokens.divider.withOpacity(0.2),
              ),
            ),
            child: Text(
              mode.label,
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: state.isEnabled ? tokens.accent : tokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: tokens.textMuted,
            size: 20,
          ),
        ],
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        showDiscordPrivacyModal(context, ref, customTrack: customTrack);
      },
    );
  }
}

// ============================================================================
// Modal Dialog & Sheet: showDiscordPrivacyModal
// ============================================================================

/// Displays the Discord Rich Presence Privacy Options modal bottom sheet.
Future<void> showDiscordPrivacyModal(
  BuildContext context,
  WidgetRef ref, {
  Track? customTrack,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) {
      return _DiscordPrivacyModalContent(
        customTrack: customTrack,
      );
    },
  );
}

class _DiscordPrivacyModalContent extends ConsumerWidget {
  final Track? customTrack;

  const _DiscordPrivacyModalContent({this.customTrack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discordPrivacyControllerProvider);
    final controller = ref.read(discordPrivacyControllerProvider.notifier);
    final tokens = context.tokens;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        border: Border.all(
          color: tokens.divider.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottom sheet drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: tokens.textMuted.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and Close Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.security_rounded,
                          color: tokens.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Discord Presence Privacy',
                        style: TextStyle(
                          fontFamily: AppTheme.fontPageTitle,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: tokens.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Choose what listening details are broadcast to friends on Discord.',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 13.0,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // Real-Time Discord Rich Presence Preview Card
              Text(
                'DISCORD STATUS PREVIEW',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              DiscordRichPresencePreviewCard(
                mode: state.mode,
                showTimestamps: state.showTimestamps,
                track: customTrack,
              ),
              const SizedBox(height: 20),

              // Privacy Mode Radio Options
              Text(
                'PRIVACY MODE',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 8),

              ...DiscordPrivacyMode.values.map((mode) {
                final isSelected = state.mode == mode;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: Key('discord_privacy_radio_${mode.id}'),
                      borderRadius: BorderRadius.circular(tokens.radiusCard),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        controller.setMode(mode);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tokens.accent.withOpacity(0.12)
                              : tokens.surfaceHighlight.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(tokens.radiusCard),
                          border: Border.all(
                            color: isSelected
                                ? tokens.accent.withOpacity(0.6)
                                : tokens.divider.withOpacity(0.2),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? tokens.accent.withOpacity(0.25)
                                    : tokens.surfaceElevated,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                mode.icon,
                                size: 18,
                                color: isSelected ? tokens.accent : tokens.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mode.label,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontUi,
                                      fontSize: 14.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      color: isSelected ? Colors.white : tokens.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    mode.description,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontUi,
                                      fontSize: 12.0,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Radio<DiscordPrivacyMode>(
                              value: mode,
                              groupValue: state.mode,
                              activeColor: tokens.accent,
                              onChanged: (newMode) {
                                if (newMode != null) {
                                  HapticFeedback.selectionClick();
                                  controller.setMode(newMode);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 10),

              // Extra Settings: Show Timestamps Toggle
              SwitchListTile(
                key: const Key('discord_privacy_switch_timestamps'),
                contentPadding: EdgeInsets.zero,
                activeColor: tokens.accent,
                title: const Text(
                  'Show Playback Elapsed Time',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  'Broadcast timeline progression (e.g. 02:15 elapsed)',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 12.0,
                    color: tokens.textSecondary,
                  ),
                ),
                value: state.showTimestamps,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  controller.setShowTimestamps(val);
                },
              ),

              // Extra Settings: Enable Discord Presence Master Switch
              SwitchListTile(
                key: const Key('discord_privacy_switch_enabled'),
                contentPadding: EdgeInsets.zero,
                activeColor: tokens.accent,
                title: const Text(
                  'Enable Discord Rich Presence',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  'Connect to local Discord desktop client on Linux/macOS/Windows',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 12.0,
                    color: tokens.textSecondary,
                  ),
                ),
                value: state.isEnabled,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  controller.setEnabled(val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// UI Component: DiscordRichPresencePreviewCard
// ============================================================================

/// Visual mockup representing the exact Rich Presence card visible to friends
/// in Discord's user popout card.
class DiscordRichPresencePreviewCard extends StatelessWidget {
  final DiscordPrivacyMode mode;
  final bool showTimestamps;
  final Track? track;
  final bool isPlaying;

  const DiscordRichPresencePreviewCard({
    super.key,
    required this.mode,
    this.showTimestamps = true,
    this.track,
    this.isPlaying = true,
  });

  static const _sampleDefaultTrack = Track(
    id: 'preview_sample_track',
    sourceId: 'preview_src_1',
    title: 'Bohemian Rhapsody',
    artist: 'Queen',
    album: 'A Night at the Opera',
    duration: Duration(minutes: 5, seconds: 55),
  );

  @override
  Widget build(BuildContext context) {
    final activeTrack = track ?? _sampleDefaultTrack;
    final presence = DiscordPrivacyMasker.maskPresence(
      track: activeTrack,
      isPlaying: isPlaying,
      mode: mode,
      showTimestamps: showTimestamps,
    );

    return Container(
      key: const Key('discord_privacy_preview_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F22), // Authentic Discord Dark Surface
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF2B2D31),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: PLAYING A GAME / LISTENING TO SOFTIFY
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF23A55A), // Discord Online / Playing Green
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LISTENING TO SOFTIFY',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFFB5BAC1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Body: Softify Album Art Avatar + Presence Details
          Row(
            children: [
              // Large App Avatar with Small Play Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2D31),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        color: Color(0xFFED5564),
                        size: 26,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1F22),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Color(0xFF23A55A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Text Lines
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: Details (Song Title or Generic)
                    Text(
                      presence.details,
                      key: const Key('discord_privacy_preview_details'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Line 2: State (Artist or Softify)
                    if (presence.state != null && presence.state!.isNotEmpty)
                      Text(
                        presence.state!,
                        key: const Key('discord_privacy_preview_state'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12.0,
                          color: Color(0xFFDBDEE1),
                        ),
                      ),

                    // Line 3: Elapsed Timestamps
                    if (showTimestamps) ...[
                      const SizedBox(height: 2),
                      const Text(
                        '02:14 elapsed',
                        key: Key('discord_privacy_preview_timestamps'),
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11.0,
                          color: Color(0xFF949BA4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
