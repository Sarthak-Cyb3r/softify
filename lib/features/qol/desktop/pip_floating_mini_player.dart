// ============================================================================
// Softify Quality of Life (QoL): Frameless Floating PiP Mini-Player
// Desktop Always-on-Top Picture-in-Picture Mini-Player with Frameless Glass Window
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/shared/app_network_image.dart';

// ============================================================================
// Storage Keys & SharedPreferences Abstraction
// ============================================================================

const String kPipMiniPlayerEnabledPrefKey = 'softify_pip_mini_player_enabled';
const String kPipAlwaysOnTopPrefKey = 'softify_pip_always_on_top';
const String kPipPositionXPrefKey = 'softify_pip_pos_x';
const String kPipPositionYPrefKey = 'softify_pip_pos_y';
const String kPipSizeModePrefKey = 'softify_pip_size_mode';
const String kPipOpacityPrefKey = 'softify_pip_opacity';
const String kPipLockedPrefKey = 'softify_pip_locked';

/// Self-contained durable SharedPreferences engine compatible with standard
/// shared_preferences API without requiring external native platform compilation plugins.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  SharedPreferences._(this._store, this._file);

  /// Injects mock values for headless test environments.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance.
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
      final dir = await getApplicationSupportDirectory();
      final targetDir = Directory(dir.path);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      return File(p.join(dir.path, 'shared_preferences.json'));
    } catch (_) {
      try {
        final home = Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            Platform.environment['LOCALAPPDATA'];
        if (home != null && home.isNotEmpty) {
          final dir = Directory(p.join(home, '.softify'));
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          return File(p.join(dir.path, 'shared_preferences.json'));
        }
      } catch (_) {}
      return File('.softify_shared_preferences.json');
    }
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(_store), flush: true);
    } catch (_) {
      // Silent error suppression
    }
  }

  bool? getBool(String key) {
    final value = _store[key];
    return value is bool ? value : null;
  }

  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  String? getString(String key) {
    final value = _store[key];
    return value is String ? value : null;
  }

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  double? getDouble(String key) {
    final value = _store[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }

  Future<bool> setDouble(String key, double value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  int? getInt(String key) {
    final value = _store[key];
    if (value is int) return value;
    if (value is double) return value.toInt();
    return null;
  }

  Future<bool> setInt(String key, int value) async {
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
// PiP Window Layout & Display Modes
// ============================================================================

/// Display sizing modes for the floating PiP mini-player window.
enum PipMiniPlayerSize {
  /// Ultra-compact bar layout: Artwork + Title/Artist + Compact transport buttons.
  compact(Size(300, 84)),

  /// Standard PiP layout: Artwork + Title/Artist/Like + Seek scrubber + Transport buttons.
  standard(Size(340, 134)),

  /// Expanded layout: Larger artwork, full metadata, scrubber, transport buttons & quick actions.
  expanded(Size(380, 172));

  final Size defaultDimensions;
  const PipMiniPlayerSize(this.defaultDimensions);

  double get width => defaultDimensions.width;
  double get height => defaultDimensions.height;
}

// ============================================================================
// State Model: PipMiniPlayerState
// ============================================================================

/// Immutable state describing the active floating Picture-in-Picture window.
@immutable
class PipMiniPlayerState {
  /// Whether the floating mini-player is visible.
  final bool isEnabled;

  /// Whether the window is pinned into Always-on-Top mode.
  final bool isAlwaysOnTop;

  /// Current top-left screen position coordinates.
  final Offset position;

  /// Active sizing mode (compact, standard, or expanded).
  final PipMiniPlayerSize sizeMode;

  /// Acrylic background opacity (clamped between 0.4 and 1.0).
  final double opacity;

  /// Whether window dragging is locked to prevent accidental repositioning.
  final bool isLocked;

  /// Whether mouse pointer is hovering over the window.
  final bool isHovered;

  const PipMiniPlayerState({
    this.isEnabled = false,
    this.isAlwaysOnTop = false,
    this.position = const Offset(28, 64),
    this.sizeMode = PipMiniPlayerSize.standard,
    this.opacity = 0.95,
    this.isLocked = false,
    this.isHovered = false,
  });

  /// Current window size based on active [sizeMode].
  Size get currentSize => sizeMode.defaultDimensions;

  PipMiniPlayerState copyWith({
    bool? isEnabled,
    bool? isAlwaysOnTop,
    Offset? position,
    PipMiniPlayerSize? sizeMode,
    double? opacity,
    bool? isLocked,
    bool? isHovered,
  }) {
    return PipMiniPlayerState(
      isEnabled: isEnabled ?? this.isEnabled,
      isAlwaysOnTop: isAlwaysOnTop ?? this.isAlwaysOnTop,
      position: position ?? this.position,
      sizeMode: sizeMode ?? this.sizeMode,
      opacity: opacity ?? this.opacity,
      isLocked: isLocked ?? this.isLocked,
      isHovered: isHovered ?? this.isHovered,
    );
  }

  /// Clamps the window position within specified container or screen bounds.
  Offset clampPosition(Size containerSize) {
    final winWidth = sizeMode.width;
    final winHeight = sizeMode.height;

    final maxX = math.max(0.0, containerSize.width - winWidth);
    final maxY = math.max(0.0, containerSize.height - winHeight);

    final clampedX = position.dx.clamp(0.0, maxX);
    final clampedY = position.dy.clamp(0.0, maxY);

    return Offset(clampedX, clampedY);
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'isAlwaysOnTop': isAlwaysOnTop,
      'posX': position.dx,
      'posY': position.dy,
      'sizeMode': sizeMode.name,
      'opacity': opacity,
      'isLocked': isLocked,
    };
  }

  factory PipMiniPlayerState.fromMap(Map<String, dynamic> map) {
    final sizeStr = map['sizeMode'] as String?;
    final mode = PipMiniPlayerSize.values.firstWhere(
      (m) => m.name == sizeStr,
      orElse: () => PipMiniPlayerSize.standard,
    );

    final posX = (map['posX'] as num?)?.toDouble() ?? 28.0;
    final posY = (map['posY'] as num?)?.toDouble() ?? 64.0;
    final op = (map['opacity'] as num?)?.toDouble() ?? 0.95;

    return PipMiniPlayerState(
      isEnabled: map['isEnabled'] as bool? ?? false,
      isAlwaysOnTop: map['isAlwaysOnTop'] as bool? ?? false,
      position: Offset(posX, posY),
      sizeMode: mode,
      opacity: op.clamp(0.4, 1.0),
      isLocked: map['isLocked'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PipMiniPlayerState &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          isAlwaysOnTop == other.isAlwaysOnTop &&
          position == other.position &&
          sizeMode == other.sizeMode &&
          opacity == other.opacity &&
          isLocked == other.isLocked &&
          isHovered == other.isHovered;

  @override
  int get hashCode => Object.hash(
        isEnabled,
        isAlwaysOnTop,
        position,
        sizeMode,
        opacity,
        isLocked,
        isHovered,
      );
}

// ============================================================================
// StateNotifier Controller: PipMiniPlayerNotifier
// ============================================================================

/// Controller managing the state, window dragging, sizing, and persistence
/// of the floating Picture-in-Picture mini-player.
class PipMiniPlayerNotifier extends StateNotifier<PipMiniPlayerState> {
  SharedPreferences? _prefs;

  PipMiniPlayerNotifier([PipMiniPlayerState? initialState])
      : super(initialState ?? const PipMiniPlayerState()) {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final isEnabled = _prefs?.getBool(kPipMiniPlayerEnabledPrefKey);
      final isAlwaysOnTop = _prefs?.getBool(kPipAlwaysOnTopPrefKey);
      final posX = _prefs?.getDouble(kPipPositionXPrefKey);
      final posY = _prefs?.getDouble(kPipPositionYPrefKey);
      final sizeName = _prefs?.getString(kPipSizeModePrefKey);
      final opacity = _prefs?.getDouble(kPipOpacityPrefKey);
      final isLocked = _prefs?.getBool(kPipLockedPrefKey);

      PipMiniPlayerSize? mode;
      if (sizeName != null) {
        mode = PipMiniPlayerSize.values.firstWhere(
          (m) => m.name == sizeName,
          orElse: () => PipMiniPlayerSize.standard,
        );
      }

      state = state.copyWith(
        isEnabled: isEnabled ?? state.isEnabled,
        isAlwaysOnTop: isAlwaysOnTop ?? state.isAlwaysOnTop,
        position: (posX != null && posY != null) ? Offset(posX, posY) : state.position,
        sizeMode: mode ?? state.sizeMode,
        opacity: opacity ?? state.opacity,
        isLocked: isLocked ?? state.isLocked,
      );
    } catch (_) {}
  }

  Future<void> _saveToPreferences() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool(kPipMiniPlayerEnabledPrefKey, state.isEnabled);
      await _prefs?.setBool(kPipAlwaysOnTopPrefKey, state.isAlwaysOnTop);
      await _prefs?.setDouble(kPipPositionXPrefKey, state.position.dx);
      await _prefs?.setDouble(kPipPositionYPrefKey, state.position.dy);
      await _prefs?.setString(kPipSizeModePrefKey, state.sizeMode.name);
      await _prefs?.setDouble(kPipOpacityPrefKey, state.opacity);
      await _prefs?.setBool(kPipLockedPrefKey, state.isLocked);
    } catch (_) {}
  }

  /// Opens and reveals the floating mini-player window.
  void show({Offset? position}) {
    state = state.copyWith(
      isEnabled: true,
      position: position ?? state.position,
    );
    _saveToPreferences();
  }

  /// Dismisses and hides the floating mini-player window.
  void hide() {
    state = state.copyWith(isEnabled: false);
    _saveToPreferences();
  }

  /// Toggles the floating mini-player between visible and hidden.
  void toggle() {
    if (state.isEnabled) {
      hide();
    } else {
      show();
    }
  }

  /// Sets Always-on-Top PiP mode.
  void setAlwaysOnTop(bool alwaysOnTop) {
    state = state.copyWith(isAlwaysOnTop: alwaysOnTop);
    _saveToPreferences();
  }

  /// Toggles Always-on-Top mode on or off.
  void toggleAlwaysOnTop() {
    setAlwaysOnTop(!state.isAlwaysOnTop);
  }

  /// Updates window position by either an absolute offset or incremental delta.
  void updatePosition(
    Offset positionOrDelta, {
    bool isDelta = false,
    Size? containerSize,
  }) {
    if (state.isLocked) return;

    Offset newPos = isDelta ? state.position + positionOrDelta : positionOrDelta;

    if (containerSize != null) {
      final winWidth = state.sizeMode.width;
      final winHeight = state.sizeMode.height;
      final maxX = math.max(0.0, containerSize.width - winWidth);
      final maxY = math.max(0.0, containerSize.height - winHeight);
      newPos = Offset(newPos.dx.clamp(0.0, maxX), newPos.dy.clamp(0.0, maxY));
    }

    state = state.copyWith(position: newPos);
    _saveToPreferences();
  }

  /// Changes the PiP sizing mode.
  void setSizeMode(PipMiniPlayerSize mode) {
    state = state.copyWith(sizeMode: mode);
    _saveToPreferences();
  }

  /// Cycles through compact -> standard -> expanded layout modes.
  void cycleSizeMode() {
    final nextIndex = (state.sizeMode.index + 1) % PipMiniPlayerSize.values.length;
    setSizeMode(PipMiniPlayerSize.values[nextIndex]);
  }

  /// Adjusts frosted glass background opacity (clamped 0.4 to 1.0).
  void setOpacity(double opacity) {
    final clamped = opacity.clamp(0.4, 1.0);
    state = state.copyWith(opacity: clamped);
    _saveToPreferences();
  }

  /// Locks or unlocks window position dragging.
  void setLocked(bool locked) {
    state = state.copyWith(isLocked: locked);
    _saveToPreferences();
  }

  /// Toggles dragging lock.
  void toggleLocked() {
    setLocked(!state.isLocked);
  }

  /// Updates hover status.
  void setHovered(bool hovered) {
    if (state.isHovered != hovered) {
      state = state.copyWith(isHovered: hovered);
    }
  }

  /// Resets window position to default top-left quadrant coordinates.
  void resetPosition() {
    state = state.copyWith(position: const Offset(28, 64));
    _saveToPreferences();
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Primary provider managing the floating PiP mini-player controller.
final pipMiniPlayerControllerProvider =
    StateNotifierProvider<PipMiniPlayerNotifier, PipMiniPlayerState>((ref) {
  return PipMiniPlayerNotifier();
});

/// Pure state provider for the floating PiP mini-player.
final pipMiniPlayerStateProvider = Provider<PipMiniPlayerState>((ref) {
  return ref.watch(pipMiniPlayerControllerProvider);
});

/// Convenience boolean provider indicating whether the PiP mini-player is active.
final isPipActiveProvider = Provider<bool>((ref) {
  return ref.watch(pipMiniPlayerControllerProvider).isEnabled;
});

/// Convenience boolean provider indicating whether Always-on-Top mode is engaged.
final isPipAlwaysOnTopProvider = Provider<bool>((ref) {
  return ref.watch(pipMiniPlayerControllerProvider).isAlwaysOnTop;
});

// ============================================================================
// Format Duration Helper
// ============================================================================

String _formatDuration(Duration? duration) {
  if (duration == null) return '0:00';
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

// ============================================================================
// Widget: CompactFloatingMiniPlayer
// ============================================================================

/// Compact floating mini-player widget featuring album art thumbnail,
/// track title, artist, seek slider, and compact playback buttons.
///
/// Designed specifically for Picture-in-Picture floating windows and
/// persistent desktop mini-player shells.
class CompactFloatingMiniPlayer extends ConsumerStatefulWidget {
  /// Optional track override for testing and preview harnesses.
  final Track? trackOverride;

  /// Optional playing state override.
  final bool? isPlayingOverride;

  /// Optional position override.
  final Duration? positionOverride;

  /// Optional total duration override.
  final Duration? durationOverride;

  /// Optional explicit sizing mode.
  final PipMiniPlayerSize? sizeMode;

  /// Callback when play/pause button is tapped.
  final VoidCallback? onPlayPause;

  /// Callback when skip previous is tapped.
  final VoidCallback? onSkipPrevious;

  /// Callback when skip next is tapped.
  final VoidCallback? onSkipNext;

  /// Callback when seek slider changes.
  final ValueChanged<Duration>? onSeek;

  /// Callback when like/favorite is toggled.
  final ValueChanged<bool>? onToggleLike;

  const CompactFloatingMiniPlayer({
    super.key,
    this.trackOverride,
    this.isPlayingOverride,
    this.positionOverride,
    this.durationOverride,
    this.sizeMode,
    this.onPlayPause,
    this.onSkipPrevious,
    this.onSkipNext,
    this.onSeek,
    this.onToggleLike,
  });

  @override
  ConsumerState<CompactFloatingMiniPlayer> createState() =>
      _CompactFloatingMiniPlayerState();
}

class _CompactFloatingMiniPlayerState
    extends ConsumerState<CompactFloatingMiniPlayer> {
  double? _dragPositionSeconds;

  void _handlePlayPause(WidgetRef ref, bool isPlaying) {
    if (widget.onPlayPause != null) {
      widget.onPlayPause!();
      return;
    }
    try {
      final audioHandler = ref.read(audioHandlerProvider);
      if (isPlaying) {
        audioHandler.pause();
      } else {
        audioHandler.play();
      }
    } catch (_) {}
  }

  void _handleSkipPrevious(WidgetRef ref) {
    if (widget.onSkipPrevious != null) {
      widget.onSkipPrevious!();
      return;
    }
    try {
      ref.read(audioHandlerProvider).skipToPrevious();
    } catch (_) {}
  }

  void _handleSkipNext(WidgetRef ref) {
    if (widget.onSkipNext != null) {
      widget.onSkipNext!();
      return;
    }
    try {
      ref.read(audioHandlerProvider).skipToNext();
    } catch (_) {}
  }

  void _handleSeek(WidgetRef ref, Duration target) {
    if (widget.onSeek != null) {
      widget.onSeek!(target);
      return;
    }
    try {
      ref.read(audioHandlerProvider).seek(target);
    } catch (_) {}
  }

  void _handleToggleLike(WidgetRef ref, Track track, bool currentLiked) {
    final newLiked = !currentLiked;
    if (widget.onToggleLike != null) {
      widget.onToggleLike!(newLiked);
      return;
    }
    try {
      ref
          .read(libraryRepositoryProvider)
          .setLiked(track.id, newLiked, track: track.copyWith(isLiked: newLiked));
      ref.read(audioHandlerProvider).updateTrackLikedState(track.id, newLiked);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Resolve track, playback state, and stream timings
    Track? track = widget.trackOverride;
    bool isPlaying = widget.isPlayingOverride ?? false;
    Duration position = widget.positionOverride ?? Duration.zero;
    Duration? duration = widget.durationOverride;

    if (widget.trackOverride == null) {
      try {
        track = ref.watch(currentTrackProvider).value;
      } catch (_) {}
    }

    if (widget.isPlayingOverride == null) {
      try {
        isPlaying = ref.watch(isPlayingProvider);
      } catch (_) {}
    }

    if (widget.positionOverride == null) {
      try {
        position = ref.watch(positionStreamProvider).value ?? Duration.zero;
      } catch (_) {}
    }

    if (widget.durationOverride == null) {
      try {
        duration = ref.watch(durationStreamProvider).value ?? track?.duration;
      } catch (_) {
        duration = track?.duration;
      }
    }

    final mode = widget.sizeMode ??
        ref.watch(pipMiniPlayerStateProvider).sizeMode;

    final isCompact = mode == PipMiniPlayerSize.compact;
    final isExpanded = mode == PipMiniPlayerSize.expanded;

    final trackDuration = duration ?? track?.duration ?? Duration.zero;
    final totalSeconds = trackDuration.inSeconds.toDouble();
    final currentSeconds = _dragPositionSeconds ?? position.inSeconds.toDouble();

    final isLiked = track?.isLiked ?? false;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: isCompact ? 4 : 6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top Row: Album Art + Metadata + Compact Controls
          Row(
            children: [
              // 1. Album Art Thumbnail
              _buildArtworkThumbnail(context, tokens, track, isCompact, isExpanded),
              const SizedBox(width: 10),

              // 2. Track Title & Artist Metadata
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.title ?? 'No Track Playing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: isCompact ? 12.5 : 13.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track?.artist ?? 'Softify PiP Player',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: isCompact ? 11.0 : 12.0,
                        fontWeight: FontWeight.w400,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Like Button (Shown in Standard & Expanded modes)
              if (!isCompact && track != null) ...[
                IconButton(
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(28, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  iconSize: 18,
                  tooltip: isLiked ? 'Unlike' : 'Like',
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? tokens.accent : tokens.textSecondary,
                  ),
                  onPressed: () => _handleToggleLike(ref, track!, isLiked),
                ),
                const SizedBox(width: 4),
              ],

              // 3. Compact Transport Buttons
              _buildTransportButtons(
                context,
                ref,
                tokens,
                isPlaying: isPlaying,
                isCompact: isCompact,
              ),
            ],
          ),

          // Seek Slider & Timestamps (Rendered for Standard and Expanded modes)
          if (!isCompact) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                // Elapsed Time
                Text(
                  _formatDuration(
                    _dragPositionSeconds != null
                        ? Duration(seconds: _dragPositionSeconds!.toInt())
                        : position,
                  ),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: AppTheme.fontUi,
                    color: tokens.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Interactive Progress Slider
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
                      activeTrackColor: tokens.accent,
                      inactiveTrackColor: tokens.textMuted.withValues(alpha: 0.25),
                      thumbColor: tokens.accent,
                    ),
                    child: Slider(
                      value: totalSeconds > 0
                          ? currentSeconds.clamp(0.0, totalSeconds)
                          : 0.0,
                      min: 0.0,
                      max: totalSeconds > 0 ? totalSeconds : 1.0,
                      onChanged: (val) {
                        setState(() {
                          _dragPositionSeconds = val;
                        });
                      },
                      onChangeEnd: (val) {
                        _handleSeek(ref, Duration(seconds: val.toInt()));
                        setState(() {
                          _dragPositionSeconds = null;
                        });
                      },
                    ),
                  ),
                ),
                // Total Duration
                Text(
                  _formatDuration(trackDuration),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: AppTheme.fontUi,
                    color: tokens.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArtworkThumbnail(
    BuildContext context,
    AppTokens tokens,
    Track? track,
    bool isCompact,
    bool isExpanded,
  ) {
    final double artSize = isCompact ? 38.0 : (isExpanded ? 52.0 : 44.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: Container(
        width: artSize,
        height: artSize,
        decoration: BoxDecoration(
          color: tokens.card,
          border: Border.all(
            color: tokens.glassBorder.withValues(alpha: 0.3),
            width: 0.8,
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
        child: track?.coverUrl != null && track!.coverUrl!.isNotEmpty
            ? AppNetworkImage(
                imageUrl: track.coverUrl,
                width: artSize,
                height: artSize,
                fit: BoxFit.cover,
                fallbackIcon: Icons.music_note_rounded,
                backgroundColor: tokens.card,
              )
            : Center(
                child: Icon(
                  Icons.music_note_rounded,
                  size: artSize * 0.5,
                  color: tokens.accent.withValues(alpha: 0.8),
                ),
              ),
      ),
    );
  }

  Widget _buildTransportButtons(
    BuildContext context,
    WidgetRef ref,
    AppTokens tokens, {
    required bool isPlaying,
    required bool isCompact,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Skip Previous
        IconButton(
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size(isCompact ? 24 : 28, isCompact ? 24 : 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          iconSize: isCompact ? 18 : 20,
          tooltip: 'Previous Track',
          icon: const Icon(
            Icons.skip_previous_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => _handleSkipPrevious(ref),
        ),
        const SizedBox(width: 4),

        // Play / Pause Circle
        Container(
          width: isCompact ? 30 : 34,
          height: isCompact ? 30 : 34,
          decoration: BoxDecoration(
            color: tokens.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: tokens.accent.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            iconSize: isCompact ? 18 : 20,
            tooltip: isPlaying ? 'Pause' : 'Play',
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
            onPressed: () => _handlePlayPause(ref, isPlaying),
          ),
        ),
        const SizedBox(width: 4),

        // Skip Next
        IconButton(
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size(isCompact ? 24 : 28, isCompact ? 24 : 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          iconSize: isCompact ? 18 : 20,
          tooltip: 'Next Track',
          icon: const Icon(
            Icons.skip_next_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => _handleSkipNext(ref),
        ),
      ],
    );
  }
}

// Convenience alias matching feature requirements
typedef PipFloatingMiniPlayer = CompactFloatingMiniPlayer;

// ============================================================================
// Widget: FloatingMiniPlayerWindow
// ============================================================================

/// Frameless floating desktop window hosting the Picture-in-Picture mini-player.
///
/// Features:
/// - Frameless modern acrylic styling with rounded corners and backdrop blur.
/// - Integrated draggable header bar with custom mouse grab cursor.
/// - Always-on-Top toggle with luminous active status badge.
/// - Layout size mode cycler (Compact, Standard, Expanded).
/// - Position drag locking to prevent inadvertent movement.
/// - Window dismissal close button.
class FloatingMiniPlayerWindow extends ConsumerStatefulWidget {
  /// Custom child widget to display inside the window.
  /// Defaults to [CompactFloatingMiniPlayer].
  final Widget? child;

  /// Optional custom title displayed on the frameless header.
  final String title;

  /// Optional initial position override.
  final Offset? initialPosition;

  /// Callback when the close button is clicked.
  final VoidCallback? onClose;

  /// Callback when the Always-on-Top button is toggled.
  final ValueChanged<bool>? onToggleAlwaysOnTop;

  /// Callback when the window position moves.
  final ValueChanged<Offset>? onPositionChanged;

  const FloatingMiniPlayerWindow({
    super.key,
    this.child,
    this.title = 'PiP Mini-Player',
    this.initialPosition,
    this.onClose,
    this.onToggleAlwaysOnTop,
    this.onPositionChanged,
  });

  @override
  ConsumerState<FloatingMiniPlayerWindow> createState() =>
      _FloatingMiniPlayerWindowState();
}

class _FloatingMiniPlayerWindowState
    extends ConsumerState<FloatingMiniPlayerWindow> {
  bool _isDragging = false;

  void _handleClose(WidgetRef ref) {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    ref.read(pipMiniPlayerControllerProvider.notifier).hide();
  }

  void _handleTogglePin(WidgetRef ref, bool isAlwaysOnTop) {
    final nextState = !isAlwaysOnTop;
    if (widget.onToggleAlwaysOnTop != null) {
      widget.onToggleAlwaysOnTop!(nextState);
      return;
    }
    ref.read(pipMiniPlayerControllerProvider.notifier).setAlwaysOnTop(nextState);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final pipState = ref.watch(pipMiniPlayerStateProvider);
    final controller = ref.read(pipMiniPlayerControllerProvider.notifier);

    final size = pipState.currentSize;
    final isPinned = pipState.isAlwaysOnTop;
    final isLocked = pipState.isLocked;

    return MouseRegion(
      onEnter: (_) => controller.setHovered(true),
      onExit: (_) => controller.setHovered(false),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: tokens.surfaceElevated.withValues(alpha: pipState.opacity),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPinned
                  ? tokens.accent.withValues(alpha: 0.75)
                  : tokens.glassBorder.withValues(alpha: 0.45),
              width: isPinned ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 22,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              if (isPinned)
                BoxShadow(
                  color: tokens.accent.withValues(alpha: 0.15),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Frameless Draggable Header Bar
                  _buildHeaderBar(
                    context,
                    ref,
                    tokens,
                    pipState: pipState,
                    isPinned: isPinned,
                    isLocked: isLocked,
                  ),

                  // 2. Window Content Body
                  Expanded(
                    child: widget.child ?? const CompactFloatingMiniPlayer(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(
    BuildContext context,
    WidgetRef ref,
    AppTokens tokens, {
    required PipMiniPlayerState pipState,
    required bool isPinned,
    required bool isLocked,
  }) {
    final controller = ref.read(pipMiniPlayerControllerProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        if (!isLocked) {
          setState(() => _isDragging = true);
        }
      },
      onPanUpdate: (details) {
        if (!isLocked) {
          final parentSize = MediaQuery.maybeOf(context)?.size;
          controller.updatePosition(
            details.delta,
            isDelta: true,
            containerSize: parentSize,
          );
          if (widget.onPositionChanged != null) {
            widget.onPositionChanged!(pipState.position);
          }
        }
      },
      onPanEnd: (_) {
        if (_isDragging) {
          setState(() => _isDragging = false);
        }
      },
      child: MouseRegion(
        cursor: isLocked
            ? SystemMouseCursors.basic
            : (_isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: tokens.surfaceHighlight.withValues(alpha: 0.65),
            border: Border(
              bottom: BorderSide(
                color: tokens.glassBorder.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Drag Grip Handle Icon
              Icon(
                Icons.drag_indicator_rounded,
                size: 14,
                color: isLocked ? tokens.textMuted : tokens.textSecondary,
              ),
              const SizedBox(width: 4),

              // Title and Active PiP Badge
              Text(
                widget.title,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tokens.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),

              if (isPinned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ON TOP',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: tokens.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

              const Spacer(),

              // Lock Position Button
              IconButton(
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(20, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                iconSize: 13,
                tooltip: isLocked ? 'Unlock Position' : 'Lock Position',
                icon: Icon(
                  isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: isLocked ? tokens.accent : tokens.textMuted,
                ),
                onPressed: () => controller.toggleLocked(),
              ),
              const SizedBox(width: 4),

              // Size Mode Cycler Button
              IconButton(
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(20, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                iconSize: 13,
                tooltip: 'Cycle Size Mode (${pipState.sizeMode.name})',
                icon: Icon(
                  Icons.aspect_ratio_rounded,
                  color: tokens.textMuted,
                ),
                onPressed: () => controller.cycleSizeMode(),
              ),
              const SizedBox(width: 4),

              // Always-on-Top Pin Button
              IconButton(
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(20, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                iconSize: 13,
                tooltip: isPinned ? 'Unpin from Top' : 'Always on Top',
                icon: Icon(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: isPinned ? tokens.accent : tokens.textMuted,
                ),
                onPressed: () => _handleTogglePin(ref, isPinned),
              ),
              const SizedBox(width: 4),

              // Close Window Button
              IconButton(
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(20, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                iconSize: 13,
                tooltip: 'Close PiP Player',
                icon: Icon(
                  Icons.close_rounded,
                  color: tokens.textMuted,
                ),
                onPressed: () => _handleClose(ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Layout Wrapper Widget: FloatingMiniPlayerOverlay
// ============================================================================

/// Root or screen-level overlay widget that presents the [FloatingMiniPlayerWindow]
/// on top of the provided [child] whenever Picture-in-Picture mode is enabled.
///
/// Ensures touches outside the mini-player pass through freely to the main screen.
class FloatingMiniPlayerOverlay extends ConsumerWidget {
  final Widget child;

  const FloatingMiniPlayerOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipState = ref.watch(pipMiniPlayerStateProvider);

    if (!pipState.isEnabled) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        final clampedPos = pipState.clampPosition(containerSize);

        return Stack(
          children: [
            // Underlying application screen
            child,

            // Floating Mini-Player Window
            Positioned(
              left: clampedPos.dx,
              top: clampedPos.dy,
              child: const FloatingMiniPlayerWindow(),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// Action Button: PipToggleButton
// ============================================================================

/// Interactive toggle button for triggering Picture-in-Picture mini-player mode.
///
/// Can be placed in bottom desktop player bars, top navigation chrome, or menus.
class PipToggleButton extends ConsumerWidget {
  final double iconSize;
  final Color? activeColor;
  final Color? inactiveColor;
  final String tooltip;

  const PipToggleButton({
    super.key,
    this.iconSize = 20,
    this.activeColor,
    this.inactiveColor,
    this.tooltip = 'Picture-in-Picture Mode',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final isPipActive = ref.watch(isPipActiveProvider);
    final controller = ref.read(pipMiniPlayerControllerProvider.notifier);

    final resolvedActiveColor = activeColor ?? tokens.accent;
    final resolvedInactiveColor = inactiveColor ?? tokens.textSecondary;

    return IconButton(
      iconSize: iconSize,
      tooltip: tooltip,
      icon: Icon(
        isPipActive
            ? Icons.picture_in_picture_alt_rounded
            : Icons.picture_in_picture_rounded,
        color: isPipActive ? resolvedActiveColor : resolvedInactiveColor,
      ),
      onPressed: () => controller.toggle(),
    );
  }
}
