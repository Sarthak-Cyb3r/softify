// ============================================================================
// Feature 33: Quick Sound Mute on Middle-Click
// Softify Linux Desktop Music Player - Quality of Life (QoL)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Persistence Keys & Self-Contained SharedPreferences Layer
// ============================================================================

/// SharedPreferences storage keys for middle-click mute settings.
const String kMiddleClickMuteEnabledPrefKey = 'softify_middle_click_mute_enabled';
const String kMiddleClickMuteSavedVolumePrefKey =
    'softify_middle_click_saved_volume';
const String kMiddleClickMuteIsMutedPrefKey = 'softify_middle_click_is_muted';

/// Default volume restored if previous volume was non-positive or unrecorded.
const double kDefaultRestoredVolume = 0.7;

/// Self-contained, durable SharedPreferences engine matching standard
/// `package:shared_preferences` API interface without requiring external native plugins.
///
/// Persists key-value settings safely across app launches with fast in-memory
/// caching and mock injection capabilities for headless unit and widget tests.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _preferenceStore;
  final File? _storageFile;

  SharedPreferences._(this._preferenceStore, this._storageFile);

  /// Synchronously accessible cached singleton instance if resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects initial values for test suites and testing harnesses.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance for hermetic test isolation.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Asynchronously loads or initializes the shared preferences storage.
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
      // In-memory fallback if file system access fails
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
        return File('${dir.path}/middle_click_mute_prefs.json');
      }
      return File('.middle_click_mute_prefs.json');
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

  bool? getBool(String key) {
    final val = _preferenceStore[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  double? getDouble(String key) {
    final val = _preferenceStore[key];
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  Future<bool> setDouble(String key, double value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  Future<bool> clear() async {
    _preferenceStore.clear();
    await _persist();
    return true;
  }
}

// ============================================================================
// Pure Logic Helper: MiddleClickMuteHelper
// ============================================================================

/// Pure Dart testable helper encapsulating pointer signal evaluation,
/// volume math, and mute calculation logic.
abstract final class MiddleClickMuteHelper {
  /// Middle mouse button bitmask constant matching [kMiddleMouseButton] (value: 4).
  static const int middleMouseButton = kMiddleMouseButton;

  /// Determines whether incoming [PointerDownEvent] represents a middle mouse button click.
  ///
  /// Checks against bitmask `kMiddleMouseButton` (0x04) and numeric button code `4`.
  static bool isMiddleClick(PointerDownEvent event) {
    return event.buttons == kMiddleMouseButton ||
        (event.buttons & kMiddleMouseButton) != 0 ||
        event.buttons == 4;
  }

  /// Determines whether a pointer down event should trigger a mute toggle.
  static bool shouldToggleOnPointerDown(
    PointerDownEvent event, {
    bool enabled = true,
  }) {
    if (!enabled) return false;
    return isMiddleClick(event);
  }

  /// Calculates the restored volume when unmuting.
  ///
  /// If [previousVolume] is non-positive or NaN, defaults to [defaultVolume].
  static double calculateRestoreVolume(
    double previousVolume, {
    double defaultVolume = kDefaultRestoredVolume,
  }) {
    if (previousVolume <= 0.0 || previousVolume.isNaN) {
      return defaultVolume.clamp(0.0, 1.0);
    }
    return previousVolume.clamp(0.0, 1.0);
  }

  /// Calculates the muted volume level (always 0.0).
  static double calculateMuteVolume() => 0.0;

  /// Rounds and clamps volume to safe 4-decimal precision within [0.0, 1.0].
  static double sanitizeVolume(double volume) {
    if (volume.isNaN) return 0.0;
    final clamped = volume.clamp(0.0, 1.0);
    return (clamped * 10000).round() / 10000.0;
  }
}

// ============================================================================
// State: MiddleClickMuteState
// ============================================================================

/// Immutable state holding middle-click mute status, volume levels, and feature activation.
@immutable
class MiddleClickMuteState {
  /// Whether audio output is currently muted.
  final bool isMuted;

  /// Active playback volume level in range [0.0, 1.0].
  final double volume;

  /// Memory of previous non-zero volume level to restore when unmuted.
  final double previousVolume;

  /// Whether middle-click mute feature is enabled globally.
  final bool isEnabled;

  const MiddleClickMuteState({
    this.isMuted = false,
    this.volume = 1.0,
    this.previousVolume = kDefaultRestoredVolume,
    this.isEnabled = true,
  });

  MiddleClickMuteState copyWith({
    bool? isMuted,
    double? volume,
    double? previousVolume,
    bool? isEnabled,
  }) {
    return MiddleClickMuteState(
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
      previousVolume: previousVolume ?? this.previousVolume,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// Dynamic icon corresponding to volume and mute state:
  /// - `Icons.volume_off_rounded` when muted or volume is 0
  /// - `Icons.volume_mute_rounded` for low volume (0 < vol < 0.25)
  /// - `Icons.volume_down_rounded` for moderate volume (0.25 <= vol < 0.65)
  /// - `Icons.volume_up_rounded` for higher volume (vol >= 0.65)
  IconData get dynamicIcon {
    if (isMuted || volume <= 0.0001) {
      return Icons.volume_off_rounded;
    } else if (volume < 0.25) {
      return Icons.volume_mute_rounded;
    } else if (volume < 0.65) {
      return Icons.volume_down_rounded;
    } else {
      return Icons.volume_up_rounded;
    }
  }

  /// Integer percentage representation of current volume [0, 100].
  int get volumePercentage => (volume * 100).round();

  /// Integer percentage representation of previous restored volume [0, 100].
  int get previousVolumePercentage => (previousVolume * 100).round();

  /// Concise status label for HUD and screen readers.
  String get statusText =>
      isMuted || volume <= 0.0001 ? 'Muted' : 'Unmuted ($volumePercentage%)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiddleClickMuteState &&
          runtimeType == other.runtimeType &&
          isMuted == other.isMuted &&
          volume == other.volume &&
          previousVolume == other.previousVolume &&
          isEnabled == other.isEnabled;

  @override
  int get hashCode => Object.hash(isMuted, volume, previousVolume, isEnabled);

  @override
  String toString() =>
      'MiddleClickMuteState(isMuted: $isMuted, volume: $volume, previousVolume: $previousVolume, isEnabled: $isEnabled)';
}

// ============================================================================
// StateNotifier: MiddleClickMuteNotifier
// ============================================================================

/// StateNotifier that manages middle-click mute toggling, non-zero volume memory,
/// and SharedPreferences persistence.
class MiddleClickMuteNotifier extends StateNotifier<MiddleClickMuteState> {
  final SoftifyAudioHandler? _audioHandler;
  SharedPreferences? _preferences;
  StreamSubscription<double>? _volumeSubscription;

  MiddleClickMuteNotifier({
    SoftifyAudioHandler? audioHandler,
    SharedPreferences? preferences,
  })  : _audioHandler = audioHandler,
        _preferences = preferences,
        super(
          MiddleClickMuteState(
            isMuted: (audioHandler?.volume ?? 1.0) <= 0.0,
            volume: audioHandler?.volume ?? 1.0,
            previousVolume:
                (audioHandler?.volume != null && audioHandler!.volume > 0.0)
                    ? audioHandler.volume
                    : kDefaultRestoredVolume,
            isEnabled: true,
          ),
        ) {
    if (_audioHandler != null) {
      _volumeSubscription = _audioHandler.volumeStream.listen(
        onVolumeChangedFromExternal,
      );
    }
    _initPersistence();
  }

  @override
  void dispose() {
    _volumeSubscription?.cancel();
    super.dispose();
  }

  /// Initializes persisted preferences and loads stored volume memory.
  Future<void> _initPersistence() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      final prefs = _preferences!;

      final savedEnabled = prefs.getBool(kMiddleClickMuteEnabledPrefKey);
      final savedVolume = prefs.getDouble(kMiddleClickMuteSavedVolumePrefKey);
      final savedIsMuted = prefs.getBool(kMiddleClickMuteIsMutedPrefKey);

      final newEnabled = savedEnabled ?? state.isEnabled;
      final newPrevVol = savedVolume != null && savedVolume > 0.0
          ? savedVolume
          : state.previousVolume;
      final newIsMuted = savedIsMuted ?? state.isMuted;
      final newVol = newIsMuted ? 0.0 : (state.volume > 0.0 ? state.volume : newPrevVol);

      state = state.copyWith(
        isEnabled: newEnabled,
        previousVolume: newPrevVol,
        isMuted: newIsMuted,
        volume: newVol,
      );
    } catch (e) {
      debugPrint('[MiddleClickMuteNotifier] Error loading preferences: $e');
    }
  }

  /// Syncs state when external sources (sliders, media keys, audio handler) modify volume.
  void onVolumeChangedFromExternal(double newVolume) {
    final clamped = MiddleClickMuteHelper.sanitizeVolume(newVolume);
    if (clamped <= 0.0001) {
      if (!state.isMuted || state.volume != 0.0) {
        state = state.copyWith(
          isMuted: true,
          volume: 0.0,
        );
      }
    } else {
      if (state.isMuted ||
          state.volume != clamped ||
          state.previousVolume != clamped) {
        state = state.copyWith(
          isMuted: false,
          volume: clamped,
          previousVolume: clamped,
        );
        _persistVolume(clamped);
      }
    }
  }

  /// Toggles mute state instantly:
  /// - When unmuted: remembers current non-zero volume, then sets volume to 0.0.
  /// - When muted: restores previous non-zero volume level.
  Future<void> toggleMute() async {
    if (state.isMuted || state.volume <= 0.0001) {
      await unmute();
    } else {
      await mute();
    }
  }

  /// Mutes audio, storing current non-zero volume level.
  Future<void> mute() async {
    if (state.isMuted && state.volume <= 0.0001) return;

    final savedPrev = state.volume > 0.0001
        ? state.volume
        : (state.previousVolume > 0.0001
            ? state.previousVolume
            : kDefaultRestoredVolume);

    state = state.copyWith(
      isMuted: true,
      volume: 0.0,
      previousVolume: savedPrev,
    );

    try {
      await _audioHandler?.setVolume(0.0);
    } catch (e) {
      debugPrint('[MiddleClickMuteNotifier] Error muting volume: $e');
    }

    await _persistMuteState(true, savedPrev);
  }

  /// Restores audio playback to previous non-zero volume level.
  Future<void> unmute() async {
    if (!state.isMuted && state.volume > 0.0001) return;

    final restoreVol = MiddleClickMuteHelper.calculateRestoreVolume(
      state.previousVolume,
      defaultVolume: kDefaultRestoredVolume,
    );

    state = state.copyWith(
      isMuted: false,
      volume: restoreVol,
      previousVolume: restoreVol,
    );

    try {
      await _audioHandler?.setVolume(restoreVol);
    } catch (e) {
      debugPrint('[MiddleClickMuteNotifier] Error restoring volume: $e');
    }

    await _persistMuteState(false, restoreVol);
  }

  /// Explicitly sets volume to a given level [0.0 - 1.0].
  Future<void> setVolume(double newVolume) async {
    final clamped = MiddleClickMuteHelper.sanitizeVolume(newVolume);
    if (clamped <= 0.0001) {
      await mute();
    } else {
      state = state.copyWith(
        isMuted: false,
        volume: clamped,
        previousVolume: clamped,
      );
      try {
        await _audioHandler?.setVolume(clamped);
      } catch (e) {
        debugPrint('[MiddleClickMuteNotifier] Error setting volume: $e');
      }
      await _persistVolume(clamped);
    }
  }

  /// Enables or disables the middle-click mute feature.
  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(isEnabled: enabled);
    try {
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      await prefs.setBool(kMiddleClickMuteEnabledPrefKey, enabled);
    } catch (_) {}
  }

  /// Toggles whether middle-click mute is active.
  Future<void> toggleEnabled() async {
    await setEnabled(!state.isEnabled);
  }

  Future<void> _persistMuteState(bool isMuted, double savedVolume) async {
    try {
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      await prefs.setBool(kMiddleClickMuteIsMutedPrefKey, isMuted);
      await prefs.setDouble(kMiddleClickMuteSavedVolumePrefKey, savedVolume);
    } catch (_) {}
  }

  Future<void> _persistVolume(double volume) async {
    try {
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      await prefs.setBool(kMiddleClickMuteIsMutedPrefKey, false);
      await prefs.setDouble(kMiddleClickMuteSavedVolumePrefKey, volume);
    } catch (_) {}
  }

  /// Resets state for unit and widget testing isolation.
  void resetForTesting({
    double volume = 1.0,
    double previousVolume = kDefaultRestoredVolume,
    bool isMuted = false,
    bool isEnabled = true,
  }) {
    state = MiddleClickMuteState(
      volume: volume,
      previousVolume: previousVolume,
      isMuted: isMuted,
      isEnabled: isEnabled,
    );
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Centralized Riverpod provider tracking quick sound mute state on middle-click.
final middleClickMuteProvider =
    StateNotifierProvider<MiddleClickMuteNotifier, MiddleClickMuteState>((ref) {
  SoftifyAudioHandler? handler;
  try {
    handler = ref.watch(audioHandlerProvider);
  } catch (_) {
    // Allows testing MiddleClickMuteNotifier in isolation without full audio service
  }
  return MiddleClickMuteNotifier(audioHandler: handler);
});

/// Riverpod selector provider exposing whether middle-click mute is enabled.
final middleClickMuteEnabledProvider = Provider<bool>((ref) {
  return ref.watch(middleClickMuteProvider.select((state) => state.isEnabled));
});

// ============================================================================
// Widget: MiddleClickMuteListener
// ============================================================================

/// A desktop Quality-of-Life wrapper widget that captures middle mouse button clicks
/// (`PointerDownEvent` with `buttons == 4` / `kMiddleMouseButton`) over the desktop
/// player bar (or any child widget) to instantly toggle mute and restore previous volume.
///
/// Features:
/// - Captures middle click (`kMiddleMouseButton` / `buttons == 4`) without blocking left/right clicks.
/// - Saves non-zero volume before muting and cleanly restores it on next middle-click.
/// - Shows an optional frosted-glass floating HUD pill toast with dynamic volume icon and percentage.
/// - Translucent hit testing ensures child controls (buttons, sliders, timestamps) stay fully interactive.
class MiddleClickMuteListener extends ConsumerStatefulWidget {
  const MiddleClickMuteListener({
    super.key,
    required this.child,
    this.enabled = true,
    this.showFloatingHud = true,
    this.hudDismissDuration = const Duration(milliseconds: 1400),
    this.onMuteToggled,
    this.onVolumeChanged,
    this.onMiddleClick,
    this.behavior = HitTestBehavior.translucent,
  });

  /// The child widget to wrap (e.g. [DesktopPlayerBar]).
  final Widget child;

  /// Whether middle-click listening is enabled locally on this widget.
  final bool enabled;

  /// Whether to display a floating HUD pill toast when mute is toggled.
  final bool showFloatingHud;

  /// How long the floating HUD pill remains visible before fading out.
  final Duration hudDismissDuration;

  /// Optional callback invoked when mute state changes with boolean `isMuted`.
  final ValueChanged<bool>? onMuteToggled;

  /// Optional callback invoked when playback volume changes.
  final ValueChanged<double>? onVolumeChanged;

  /// Optional callback invoked whenever a middle mouse click is detected.
  final VoidCallback? onMiddleClick;

  /// Hit test behavior (defaults to [HitTestBehavior.translucent] to allow passthrough).
  final HitTestBehavior behavior;

  @override
  ConsumerState<MiddleClickMuteListener> createState() =>
      _MiddleClickMuteListenerState();
}

class _MiddleClickMuteListenerState extends ConsumerState<MiddleClickMuteListener>
    with SingleTickerProviderStateMixin {
  final GlobalKey _anchorKey = GlobalKey();
  final ValueNotifier<MiddleClickMuteState> _hudStateNotifier =
      ValueNotifier<MiddleClickMuteState>(const MiddleClickMuteState());

  late final AnimationController _hudAnimController;
  late final Animation<double> _hudAnimation;

  OverlayEntry? _overlayEntry;
  Timer? _dismissTimer;
  bool _isFallbackHudActive = false;

  @override
  void initState() {
    super.initState();

    _hudAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _hudAnimation = CurvedAnimation(
      parent: _hudAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _removeOverlay();
    _hudAnimController.dispose();
    _hudStateNotifier.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;

    final globalState = ref.read(middleClickMuteProvider);
    if (!globalState.isEnabled) return;

    if (!MiddleClickMuteHelper.isMiddleClick(event)) return;

    // Acknowledge middle click gesture
    widget.onMiddleClick?.call();

    // Toggle mute instantly
    final notifier = ref.read(middleClickMuteProvider.notifier);
    notifier.toggleMute();

    final updatedState = ref.read(middleClickMuteProvider);
    widget.onMuteToggled?.call(updatedState.isMuted);
    widget.onVolumeChanged?.call(updatedState.volume);

    if (widget.showFloatingHud) {
      _triggerFloatingHud(updatedState);
    }
  }

  void _triggerFloatingHud(MiddleClickMuteState state) {
    _hudStateNotifier.value = state;
    _dismissTimer?.cancel();

    if (_overlayEntry == null) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null) {
        _overlayEntry = OverlayEntry(
          builder: (overlayContext) {
            return _FloatingMiddleClickMuteHudOverlay(
              anchorKey: _anchorKey,
              stateNotifier: _hudStateNotifier,
              animation: _hudAnimation,
            );
          },
        );
        overlay.insert(_overlayEntry!);
      } else {
        // Fallback to inline Stack overlay if no Navigator overlay is present
        if (!_isFallbackHudActive && mounted) {
          setState(() {
            _isFallbackHudActive = true;
          });
        }
      }
    }

    _hudAnimController.forward();

    _dismissTimer = Timer(widget.hudDismissDuration, () {
      if (mounted) {
        _hudAnimController.reverse().then((_) {
          _removeOverlay();
          if (_isFallbackHudActive && mounted) {
            setState(() {
              _isFallbackHudActive = false;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = KeyedSubtree(
      key: _anchorKey,
      child: widget.child,
    );

    if (_isFallbackHudActive) {
      content = Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            bottom: 84,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _hudAnimation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.90, end: 1.0)
                      .animate(_hudAnimation),
                  child: ValueListenableBuilder<MiddleClickMuteState>(
                    valueListenable: _hudStateNotifier,
                    builder: (context, muteState, _) {
                      return MiddleClickMuteHudCard(state: muteState);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Listener(
      behavior: widget.behavior,
      onPointerDown: _handlePointerDown,
      child: content,
    );
  }
}

// ============================================================================
// HUD Overlay & Floating Card Widgets
// ============================================================================

/// Internal overlay positioning widget for the middle-click mute HUD toast.
class _FloatingMiddleClickMuteHudOverlay extends StatelessWidget {
  const _FloatingMiddleClickMuteHudOverlay({
    required this.anchorKey,
    required this.stateNotifier,
    required this.animation,
  });

  final GlobalKey anchorKey;
  final ValueNotifier<MiddleClickMuteState> stateNotifier;
  final Animation<double> animation;

  static const double hudWidth = 240.0;
  static const double hudHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final renderBox =
        anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.of(context).size;

    double? left;
    double? top;
    double? bottom;

    if (renderBox != null && renderBox.hasSize && renderBox.attached) {
      final globalPos = renderBox.localToGlobal(Offset.zero);
      final boxSize = renderBox.size;

      // Center horizontally above the anchor widget
      left = (globalPos.dx + (boxSize.width - hudWidth) / 2).clamp(
        16.0,
        (screenSize.width - hudWidth - 16.0).clamp(16.0, double.infinity),
      );

      // Float 14px above the anchor widget's top edge
      final computedTop = globalPos.dy - hudHeight - 14.0;
      if (computedTop >= 16.0) {
        top = computedTop;
      } else {
        bottom = 106.0;
      }
    } else {
      left = (screenSize.width - hudWidth) / 2;
      bottom = 106.0;
    }

    return Positioned(
      left: left,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.90, end: 1.0).animate(animation),
            child: ValueListenableBuilder<MiddleClickMuteState>(
              valueListenable: stateNotifier,
              builder: (context, muteState, _) {
                return MiddleClickMuteHudCard(state: muteState);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted-glass Material 3 HUD pill card displaying dynamic volume icon,
/// fill indicator, and status label.
class MiddleClickMuteHudCard extends StatelessWidget {
  const MiddleClickMuteHudCard({
    super.key,
    required this.state,
  });

  final MiddleClickMuteState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isMuted = state.isMuted || state.volume <= 0.0001;

    final Color iconColor = isMuted
        ? (tokens.textSecondary)
        : tokens.accent;

    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 240,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  state.dynamicIcon,
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isMuted
                      ? Text(
                          'Muted',
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            height: 5,
                            child: Stack(
                              children: [
                                Container(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                FractionallySizedBox(
                                  widthFactor: state.volume.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: tokens.accent,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 52,
                  child: Text(
                    isMuted ? '0%' : '${state.volumePercentage}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// UI Accessory: MiddleClickMuteButton
// ============================================================================

/// One-click button or desktop toolbar accessory that integrates with
/// [middleClickMuteProvider] to toggle mute state or inspect status.
class MiddleClickMuteButton extends ConsumerWidget {
  const MiddleClickMuteButton({
    super.key,
    this.iconSize = 18,
    this.color,
    this.mutedColor,
    this.padding,
    this.tooltip,
    this.onToggled,
  });

  final double iconSize;
  final Color? color;
  final Color? mutedColor;
  final EdgeInsetsGeometry? padding;
  final String? tooltip;
  final VoidCallback? onToggled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muteState = ref.watch(middleClickMuteProvider);
    final isMuted = muteState.isMuted || muteState.volume <= 0.0001;
    final tokens = context.tokens;

    final effectiveColor = isMuted
        ? (mutedColor ?? tokens.textMuted)
        : (color ?? tokens.textSecondary);

    final effectiveTooltip = tooltip ??
        (isMuted
            ? 'Unmute (Restores ${muteState.previousVolumePercentage}%) [Middle-Click]'
            : 'Mute [Middle-Click]');

    return IconButton(
      style: IconButton.styleFrom(
        minimumSize: const Size(28, 28),
        padding: padding ?? const EdgeInsets.all(4),
      ),
      iconSize: iconSize,
      tooltip: effectiveTooltip,
      icon: Icon(
        muteState.dynamicIcon,
        color: effectiveColor,
      ),
      onPressed: () {
        ref.read(middleClickMuteProvider.notifier).toggleMute();
        onToggled?.call();
      },
    );
  }
}
