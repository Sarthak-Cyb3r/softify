// ============================================================================
// Feature 41: Full-Screen Clock & Art Screensaver
// Softify Desktop & Mobile Ambient Mode
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/widgets/shared/app_network_image.dart';

// ============================================================================
// SharedPreferences Persistence Layer (Zero-Dependency & Self-Contained)
// ============================================================================

/// SharedPreferences storage keys for ambient screensaver settings.
const String kScreensaverTimeoutMinutesPrefKey = 'ambient_screensaver_timeout_minutes';
const String kScreensaver24HourPrefKey = 'ambient_screensaver_24_hour';
const String kScreensaverShowArtworkPrefKey = 'ambient_screensaver_show_artwork';
const String kScreensaverShowProgressPrefKey = 'ambient_screensaver_show_progress';
const String kScreensaverOnlyPlayingPrefKey = 'ambient_screensaver_only_playing';

/// Self-contained, durable SharedPreferences engine matching the standard
/// `package:shared_preferences` API interface without requiring external native compilation plugins.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  SharedPreferences._(this._store, this._file);

  /// Synchronously accessible cached singleton instance if already resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects mock values for testing environments.
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
      await file.writeAsString(jsonEncode(_store));
    } catch (_) {
      // Silent error handling for storage fallback
    }
  }

  int? getInt(String key) {
    final val = _store[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  Future<bool> setInt(String key, int value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  bool? getBool(String key) {
    final val = _store[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  String? getString(String key) {
    final val = _store[key];
    return val?.toString();
  }

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  bool containsKey(String key) => _store.containsKey(key);

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
// Pure Formatting Utilities
// ============================================================================

/// Formats a [DateTime] into a clean time string (12-hour or 24-hour).
String formatScreensaverTime(
  DateTime time, {
  bool use24Hour = false,
  bool includeSeconds = false,
}) {
  final hourVal = use24Hour
      ? time.hour
      : (time.hour % 12 == 0 ? 12 : time.hour % 12);
  final hourStr = use24Hour
      ? hourVal.toString().padLeft(2, '0')
      : hourVal.toString();
  final minuteStr = time.minute.toString().padLeft(2, '0');
  final secondStr = time.second.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';

  if (use24Hour) {
    return includeSeconds
        ? '$hourStr:$minuteStr:$secondStr'
        : '$hourStr:$minuteStr';
  } else {
    final base = includeSeconds
        ? '$hourStr:$minuteStr:$secondStr'
        : '$hourStr:$minuteStr';
    return '$base $period';
  }
}

/// Formats a [DateTime] into a clean date string (e.g., "Thursday, November 12").
String formatScreensaverDate(DateTime time) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  final weekday = weekdays[(time.weekday - 1).clamp(0, 6)];
  final month = months[(time.month - 1).clamp(0, 11)];
  return '$weekday, $month ${time.day}';
}

/// Formats a [Duration] into `mm:ss` or `hh:mm:ss`.
String formatTrackDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

// ============================================================================
// Model: ScreensaverTimeout Enum
// ============================================================================

/// Inactivity idle duration before the full-screen ambient screensaver activates.
enum ScreensaverTimeout {
  off(0, 'Off'),
  oneMinute(1, '1 Minute'),
  threeMinutes(3, '3 Minutes'),
  fiveMinutes(5, '5 Minutes');

  final int minutes;
  final String label;

  const ScreensaverTimeout(this.minutes, this.label);

  /// Converts the timeout into a [Duration], or null if disabled.
  Duration? get duration => minutes > 0 ? Duration(minutes: minutes) : null;

  /// Whether the screensaver auto-activation is enabled.
  bool get isEnabled => minutes > 0;

  /// Resolves the enum value from minutes count.
  static ScreensaverTimeout fromMinutes(int? minutes) {
    switch (minutes) {
      case 1:
        return ScreensaverTimeout.oneMinute;
      case 3:
        return ScreensaverTimeout.threeMinutes;
      case 5:
        return ScreensaverTimeout.fiveMinutes;
      default:
        return ScreensaverTimeout.off;
    }
  }
}

// ============================================================================
// Model: AmbientScreensaverConfig
// ============================================================================

/// Immutable user configuration for the ambient clock & art screensaver.
@immutable
class AmbientScreensaverConfig {
  final ScreensaverTimeout timeout;
  final Duration? customInactivityDuration;
  final bool use24HourFormat;
  final bool showArtwork;
  final bool showProgressBar;
  final bool onlyWhenPlaying;

  const AmbientScreensaverConfig({
    this.timeout = ScreensaverTimeout.threeMinutes,
    this.customInactivityDuration,
    this.use24HourFormat = false,
    this.showArtwork = true,
    this.showProgressBar = true,
    this.onlyWhenPlaying = false,
  });

  /// The effective idle duration before triggering screensaver.
  Duration get effectiveInactivityDuration =>
      customInactivityDuration ?? timeout.duration ?? Duration.zero;

  AmbientScreensaverConfig copyWith({
    ScreensaverTimeout? timeout,
    Duration? customInactivityDuration,
    bool clearCustomDuration = false,
    bool? use24HourFormat,
    bool? showArtwork,
    bool? showProgressBar,
    bool? onlyWhenPlaying,
  }) {
    return AmbientScreensaverConfig(
      timeout: timeout ?? this.timeout,
      customInactivityDuration: clearCustomDuration
          ? null
          : (customInactivityDuration ?? this.customInactivityDuration),
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      showArtwork: showArtwork ?? this.showArtwork,
      showProgressBar: showProgressBar ?? this.showProgressBar,
      onlyWhenPlaying: onlyWhenPlaying ?? this.onlyWhenPlaying,
    );
  }

  Map<String, dynamic> toMap() => {
        'timeout_minutes': timeout.minutes,
        'use_24_hour': use24HourFormat,
        'show_artwork': showArtwork,
        'show_progress': showProgressBar,
        'only_playing': onlyWhenPlaying,
      };

  factory AmbientScreensaverConfig.fromMap(Map<String, dynamic> map) {
    return AmbientScreensaverConfig(
      timeout: ScreensaverTimeout.fromMinutes(map['timeout_minutes'] as int?),
      use24HourFormat: map['use_24_hour'] as bool? ?? false,
      showArtwork: map['show_artwork'] as bool? ?? true,
      showProgressBar: map['show_progress'] as bool? ?? true,
      onlyWhenPlaying: map['only_playing'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmbientScreensaverConfig &&
          runtimeType == other.runtimeType &&
          timeout == other.timeout &&
          customInactivityDuration == other.customInactivityDuration &&
          use24HourFormat == other.use24HourFormat &&
          showArtwork == other.showArtwork &&
          showProgressBar == other.showProgressBar &&
          onlyWhenPlaying == other.onlyWhenPlaying;

  @override
  int get hashCode => Object.hash(
        timeout,
        customInactivityDuration,
        use24HourFormat,
        showArtwork,
        showProgressBar,
        onlyWhenPlaying,
      );
}

// ============================================================================
// Model: AmbientScreensaverState
// ============================================================================

/// Reactive state tracking screensaver display and activity status.
@immutable
class AmbientScreensaverState {
  final bool isActive;
  final DateTime lastInteractionTime;
  final DateTime? activatedAt;
  final AmbientScreensaverConfig config;

  const AmbientScreensaverState({
    this.isActive = false,
    required this.lastInteractionTime,
    this.activatedAt,
    this.config = const AmbientScreensaverConfig(),
  });

  AmbientScreensaverState copyWith({
    bool? isActive,
    DateTime? lastInteractionTime,
    DateTime? activatedAt,
    bool clearActivatedAt = false,
    AmbientScreensaverConfig? config,
  }) {
    return AmbientScreensaverState(
      isActive: isActive ?? this.isActive,
      lastInteractionTime: lastInteractionTime ?? this.lastInteractionTime,
      activatedAt:
          clearActivatedAt ? null : (activatedAt ?? this.activatedAt),
      config: config ?? this.config,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmbientScreensaverState &&
          runtimeType == other.runtimeType &&
          isActive == other.isActive &&
          lastInteractionTime == other.lastInteractionTime &&
          activatedAt == other.activatedAt &&
          config == other.config;

  @override
  int get hashCode => Object.hash(
        isActive,
        lastInteractionTime,
        activatedAt,
        config,
      );
}

// ============================================================================
// StateNotifier: AmbientScreensaverNotifier
// ============================================================================

/// Manages inactivity timer, user interaction detection, and screensaver overlay state.
class AmbientScreensaverNotifier extends StateNotifier<AmbientScreensaverState> {
  final Ref? _ref;
  Timer? _idleTimer;

  AmbientScreensaverNotifier(
    this._ref, [
    AmbientScreensaverConfig initialConfig = const AmbientScreensaverConfig(),
  ]) : super(AmbientScreensaverState(
          lastInteractionTime: DateTime.now(),
          config: initialConfig,
        )) {
    _initPreferences();
  }

  Future<void> _initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeoutMin = prefs.getInt(kScreensaverTimeoutMinutesPrefKey);
      final use24h = prefs.getBool(kScreensaver24HourPrefKey);
      final showArt = prefs.getBool(kScreensaverShowArtworkPrefKey);
      final showProg = prefs.getBool(kScreensaverShowProgressPrefKey);
      final onlyPlay = prefs.getBool(kScreensaverOnlyPlayingPrefKey);

      final newConfig = state.config.copyWith(
        timeout: timeoutMin != null
            ? ScreensaverTimeout.fromMinutes(timeoutMin)
            : state.config.timeout,
        use24HourFormat: use24h ?? state.config.use24HourFormat,
        showArtwork: showArt ?? state.config.showArtwork,
        showProgressBar: showProg ?? state.config.showProgressBar,
        onlyWhenPlaying: onlyPlay ?? state.config.onlyWhenPlaying,
      );

      if (mounted) {
        state = state.copyWith(config: newConfig);
        _scheduleIdleTimer();
      }
    } catch (_) {
      _scheduleIdleTimer();
    }
  }

  /// Records an interaction event (mouse hover/move/press or keyboard tap).
  ///
  /// If the screensaver is currently active, immediately dismisses it.
  /// Then reschedules the inactivity timer.
  void recordInteraction() {
    final now = DateTime.now();

    // Check debounce if screensaver was just activated within 150ms
    if (state.isActive) {
      if (state.activatedAt != null &&
          now.difference(state.activatedAt!).inMilliseconds < 150) {
        return;
      }
      dismissScreensaver();
      return;
    }

    state = state.copyWith(lastInteractionTime: now);
    _scheduleIdleTimer();
  }

  /// Schedules or resets the countdown timer for user inactivity.
  void _scheduleIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;

    if (!state.config.timeout.isEnabled &&
        state.config.customInactivityDuration == null) {
      return;
    }

    final duration = state.config.effectiveInactivityDuration;
    if (duration <= Duration.zero) return;

    _idleTimer = Timer(duration, () {
      if (mounted && !state.isActive) {
        activateScreensaver();
      }
    });
  }

  /// Activates full-screen screensaver display.
  void activateScreensaver() {
    if (state.isActive) return;

    // Check onlyWhenPlaying gate if configured
    if (state.config.onlyWhenPlaying && _ref != null) {
      try {
        final isPlaying = _ref.read(isPlayingProvider);
        if (!isPlaying) {
          _scheduleIdleTimer();
          return;
        }
      } catch (_) {}
    }

    _idleTimer?.cancel();
    _idleTimer = null;
    state = state.copyWith(
      isActive: true,
      activatedAt: DateTime.now(),
    );
  }

  /// Forces the screensaver on regardless of playing state or timeout.
  void forceActivate() {
    _idleTimer?.cancel();
    _idleTimer = null;
    state = state.copyWith(
      isActive: true,
      activatedAt: DateTime.now(),
    );
  }

  /// Dismisses active screensaver and resumes inactivity monitoring.
  void dismissScreensaver() {
    if (!state.isActive) return;

    state = state.copyWith(
      isActive: false,
      clearActivatedAt: true,
      lastInteractionTime: DateTime.now(),
    );
    _scheduleIdleTimer();
  }

  /// Toggles the screensaver overlay.
  void toggleActive() {
    if (state.isActive) {
      dismissScreensaver();
    } else {
      forceActivate();
    }
  }

  /// Updates inactivity idle timeout setting and persists to storage.
  Future<void> setTimeout(ScreensaverTimeout timeout) async {
    state = state.copyWith(
      config: state.config.copyWith(
        timeout: timeout,
        clearCustomDuration: true,
      ),
    );
    _scheduleIdleTimer();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kScreensaverTimeoutMinutesPrefKey, timeout.minutes);
    } catch (_) {}
  }

  /// Sets an arbitrary custom inactivity duration (primarily for tests).
  void setCustomDuration(Duration? duration) {
    state = state.copyWith(
      config: state.config.copyWith(
        customInactivityDuration: duration,
        clearCustomDuration: duration == null,
      ),
    );
    _scheduleIdleTimer();
  }

  /// Toggles 24-hour vs 12-hour clock format.
  Future<void> setUse24HourFormat(bool value) async {
    state = state.copyWith(
      config: state.config.copyWith(use24HourFormat: value),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kScreensaver24HourPrefKey, value);
    } catch (_) {}
  }

  /// Toggles floating artwork display.
  Future<void> setShowArtwork(bool value) async {
    state = state.copyWith(
      config: state.config.copyWith(showArtwork: value),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kScreensaverShowArtworkPrefKey, value);
    } catch (_) {}
  }

  /// Toggles progress bar display.
  Future<void> setShowProgressBar(bool value) async {
    state = state.copyWith(
      config: state.config.copyWith(showProgressBar: value),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kScreensaverShowProgressPrefKey, value);
    } catch (_) {}
  }

  /// Toggles "only activate when playing" constraint.
  Future<void> setOnlyWhenPlaying(bool value) async {
    state = state.copyWith(
      config: state.config.copyWith(onlyWhenPlaying: value),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kScreensaverOnlyPlayingPrefKey, value);
    } catch (_) {}
  }

  /// Resets configuration to factory defaults.
  Future<void> resetToDefaults() async {
    const defaultConfig = AmbientScreensaverConfig();
    state = state.copyWith(config: defaultConfig);
    _scheduleIdleTimer();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kScreensaverTimeoutMinutesPrefKey);
      await prefs.remove(kScreensaver24HourPrefKey);
      await prefs.remove(kScreensaverShowArtworkPrefKey);
      await prefs.remove(kScreensaverShowProgressPrefKey);
      await prefs.remove(kScreensaverOnlyPlayingPrefKey);
    } catch (_) {}
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _idleTimer = null;
    super.dispose();
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Primary Riverpod state provider managing ambient screensaver state.
final ambientScreensaverProvider =
    StateNotifierProvider<AmbientScreensaverNotifier, AmbientScreensaverState>(
  (ref) => AmbientScreensaverNotifier(ref),
);

/// Convenience boolean provider indicating if screensaver is currently active.
final isAmbientScreensaverActiveProvider = Provider<bool>((ref) {
  return ref.watch(ambientScreensaverProvider).isActive;
});

/// Convenience provider yielding current screensaver configuration.
final ambientScreensaverConfigProvider =
    Provider<AmbientScreensaverConfig>((ref) {
  return ref.watch(ambientScreensaverProvider).config;
});

// ============================================================================
// Widget: AmbientClockScreensaverOverlay
// ============================================================================

/// Application wrapper widget that monitors mouse movements, pointer actions,
/// and keyboard presses.
///
/// When the user has been inactive for the configured timeout, it seamlessly
/// displays the [AmbientClockScreensaverView] full-screen overlay.
/// Moving the mouse or pressing any keyboard key immediately dismisses the screensaver.
class AmbientClockScreensaverOverlay extends ConsumerStatefulWidget {
  /// The underlying child widget tree (e.g. whole app or player screen).
  final Widget child;

  /// Whether inactivity tracking and screensaver overlay is enabled.
  final bool enabled;

  const AmbientClockScreensaverOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  ConsumerState<AmbientClockScreensaverOverlay> createState() =>
      _AmbientClockScreensaverOverlayState();
}

class _AmbientClockScreensaverOverlayState
    extends ConsumerState<AmbientClockScreensaverOverlay> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'AmbientScreensaverFocus');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleInteraction() {
    if (!widget.enabled) return;
    ref.read(ambientScreensaverProvider.notifier).recordInteraction();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _handleInteraction();
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final screensaverState = ref.watch(ambientScreensaverProvider);
    final isScreensaverActive = screensaverState.isActive && widget.enabled;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onHover: (_) => _handleInteraction(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _handleInteraction(),
          onPointerMove: (_) => _handleInteraction(),
          onPointerHover: (_) => _handleInteraction(),
          onPointerSignal: (_) => _handleInteraction(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main Application UI
              widget.child,

              // Full-screen Ambient Screensaver Overlay
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  reverseDuration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: isScreensaverActive
                      ? AmbientClockScreensaverView(
                          key: const ValueKey('AmbientClockScreensaverView'),
                          onDismiss: () {
                            ref
                                .read(ambientScreensaverProvider.notifier)
                                .dismissScreensaver();
                          },
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('AmbientScreensaverHidden'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Widget: AmbientClockScreensaverView
// ============================================================================

/// Minimalist, cinema-grade full-screen screensaver displaying a crisp digital
/// clock, floating album artwork, track details, and dynamic track progress.
class AmbientClockScreensaverView extends ConsumerStatefulWidget {
  /// Optional dismiss callback triggered on interaction or dismissal request.
  final VoidCallback? onDismiss;

  /// Optional track override for isolated previews and widget tests.
  final Track? trackOverride;

  /// Optional position override for testing.
  final Duration? positionOverride;

  /// Optional duration override for testing.
  final Duration? durationOverride;

  const AmbientClockScreensaverView({
    super.key,
    this.onDismiss,
    this.trackOverride,
    this.positionOverride,
    this.durationOverride,
  });

  @override
  ConsumerState<AmbientClockScreensaverView> createState() =>
      _AmbientClockScreensaverViewState();
}

class _AmbientClockScreensaverViewState
    extends ConsumerState<AmbientClockScreensaverView>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  Timer? _clockTicker;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Subtle 6-second floating & breathing oscillation animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // 1-second clock ticker for digital clock accuracy
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _floatController.dispose();
    super.dispose();
  }

  void _triggerWake() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    } else {
      ref.read(ambientScreensaverProvider.notifier).dismissScreensaver();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(ambientScreensaverConfigProvider);

    // Track resolution: override takes precedence, fallback to provider stream
    Track? track = widget.trackOverride;
    if (track == null) {
      try {
        track = ref.watch(currentTrackProvider).valueOrNull;
      } catch (_) {}
    }

    // Position & duration resolution
    Duration position = widget.positionOverride ?? Duration.zero;
    if (widget.positionOverride == null) {
      try {
        position = ref.watch(positionStreamProvider).valueOrNull ?? Duration.zero;
      } catch (_) {}
    }

    Duration duration = widget.durationOverride ??
        (track != null && track.duration > Duration.zero
            ? track.duration
            : Duration.zero);
    if (widget.durationOverride == null) {
      try {
        final streamDur = ref.watch(durationStreamProvider).valueOrNull;
        if (streamDur != null && streamDur > Duration.zero) {
          duration = streamDur;
        }
      } catch (_) {}
    }

    final hasTrack = track != null;

    return MouseRegion(
      cursor: SystemMouseCursors.none,
      onHover: (_) => _triggerWake(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _triggerWake,
        onPanDown: (_) => _triggerWake(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF030303),
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF0C0E14),
                Color(0xFF020203),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Centered Main Content
                Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32.0,
                        vertical: 24.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Digital Clock Header
                          _buildDigitalClock(config),

                          const SizedBox(height: 36.0),

                          // 2. Subtle Floating Artwork (if enabled and track exists)
                          if (config.showArtwork) ...[
                            _buildFloatingArtwork(track),
                            const SizedBox(height: 28.0),
                          ],

                          // 3. Track Metadata
                          if (hasTrack) ...[
                            _buildTrackMetadata(track),
                            const SizedBox(height: 20.0),
                          ],

                          // 4. Track Progress Bar (if enabled and track exists)
                          if (config.showProgressBar && hasTrack) ...[
                            _buildTrackProgress(position, duration),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // 5. Minimalist Wake Hint (Bottom Center)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: _buildWakeHint(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDigitalClock(AmbientScreensaverConfig config) {
    final timeStr = formatScreensaverTime(
      _currentTime,
      use24Hour: config.use24HourFormat,
    );
    final dateStr = formatScreensaverDate(_currentTime);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Large High-Contrast Digital Time
        Text(
          timeStr,
          style: const TextStyle(
            fontSize: 72.0,
            fontWeight: FontWeight.w200,
            letterSpacing: 2.0,
            color: Colors.white,
            fontFamily: AppTheme.fontDisplay,
            shadows: [
              Shadow(
                color: Colors.black87,
                blurRadius: 18.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6.0),

        // Date Display
        Text(
          dateStr,
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.2,
            color: Colors.white.withOpacity(0.70),
            fontFamily: AppTheme.fontUi,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingArtwork(Track? track) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        // Continuous sine-wave floating oscillation (±8 px)
        final progress = _floatController.value;
        final floatOffset = math.sin(progress * 2 * math.pi) * 8.0;
        final breatheScale = 1.0 + (math.cos(progress * 2 * math.pi) * 0.012);

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Transform.scale(
            scale: breatheScale,
            child: child,
          ),
        );
      },
      child: Container(
        width: 190.0,
        height: 190.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.7),
              blurRadius: 36.0,
              spreadRadius: 4.0,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.15),
              blurRadius: 48.0,
              spreadRadius: -4.0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: track?.coverUrl != null && track!.coverUrl!.isNotEmpty
              ? AppNetworkImage(
                  imageUrl: track.coverUrl,
                  width: 190.0,
                  height: 190.0,
                  fit: BoxFit.cover,
                  placeholder: _buildArtworkFallback(),
                  errorWidget: _buildArtworkFallback(),
                )
              : _buildArtworkFallback(),
        ),
      ),
    );
  }

  Widget _buildArtworkFallback() {
    return Container(
      color: const Color(0xFF15171C),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 72.0,
          color: Colors.white.withOpacity(0.35),
        ),
      ),
    );
  }

  Widget _buildTrackMetadata(Track track) {
    return SizedBox(
      width: 380.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track Title
          Text(
            track.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: Colors.white,
              fontFamily: AppTheme.fontUi,
            ),
          ),
          const SizedBox(height: 6.0),

          // Artist & Album
          Text(
            track.album != null && track.album!.isNotEmpty
                ? '${track.artist}  •  ${track.album}'
                : track.artist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.65),
              fontFamily: AppTheme.fontUi,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackProgress(Duration position, Duration duration) {
    final double progressRatio = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      width: 340.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimalist Progress Track
          Stack(
            children: [
              // Track Background
              Container(
                height: 4.0,
                width: 340.0,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999.0),
                ),
              ),
              // Active Progress Fill
              FractionallySizedBox(
                widthFactor: progressRatio,
                child: Container(
                  height: 4.0,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.accent,
                        Colors.white,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.6),
                        blurRadius: 8.0,
                        spreadRadius: 1.0,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),

          // Timestamps Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatTrackDuration(position),
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.55),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                formatTrackDuration(duration),
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.55),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWakeHint() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.mouse_outlined,
          size: 14.0,
          color: Colors.white.withOpacity(0.35),
        ),
        const SizedBox(width: 8.0),
        Text(
          'Move mouse or press any key to wake',
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
            color: Colors.white.withOpacity(0.35),
            fontFamily: AppTheme.fontUi,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Settings Widget: AmbientClockScreensaverTile
// ============================================================================

/// A Material 3 ListTile for embedding screensaver configuration into Settings.
class AmbientClockScreensaverTile extends ConsumerWidget {
  const AmbientClockScreensaverTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(ambientScreensaverConfigProvider);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: const Icon(
          Icons.nightlight_round,
          color: AppTheme.accent,
          size: 22.0,
        ),
      ),
      title: const Text(
        'Ambient Clock & Art Screensaver',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15.0,
        ),
      ),
      subtitle: Text(
        config.timeout.isEnabled
            ? 'Activates after ${config.timeout.label.toLowerCase()} of inactivity'
            : 'Turned off (never activates automatically)',
        style: TextStyle(
          fontSize: 13.0,
          color: Colors.white.withOpacity(0.6),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Preview Screensaver',
            icon: const Icon(Icons.fullscreen_rounded),
            onPressed: () {
              ref
                  .read(ambientScreensaverProvider.notifier)
                  .forceActivate();
            },
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white38,
          ),
        ],
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => const AmbientClockScreensaverSettingsDialog(),
        );
      },
    );
  }
}

// ============================================================================
// Settings Dialog: AmbientClockScreensaverSettingsDialog
// ============================================================================

/// Dialog providing control over screensaver timeout, 24-hour format, artwork,
/// and preview trigger.
class AmbientClockScreensaverSettingsDialog extends ConsumerWidget {
  const AmbientClockScreensaverSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(ambientScreensaverConfigProvider);
    final notifier = ref.read(ambientScreensaverProvider.notifier);

    return AlertDialog(
      backgroundColor: const Color(0xFF14161C),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: const Icon(
              Icons.nightlight_round,
              color: AppTheme.accent,
              size: 22.0,
            ),
          ),
          const SizedBox(width: 12.0),
          const Expanded(
            child: Text(
              'Ambient Screensaver',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inactivity Timeout',
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8.0),

            // Inactivity Options (Off, 1 min, 3 min, 5 min)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: ScreensaverTimeout.values.map((timeout) {
                  final isSelected = config.timeout == timeout;
                  return RadioListTile<ScreensaverTimeout>(
                    value: timeout,
                    groupValue: config.timeout,
                    activeColor: AppTheme.accent,
                    dense: true,
                    title: Text(
                      timeout.label,
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                    onChanged: (newTimeout) {
                      if (newTimeout != null) {
                        notifier.setTimeout(newTimeout);
                      }
                    },
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16.0),
            const Text(
              'Display Preferences',
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8.0),

            // Switch Options
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppTheme.accent,
              title: const Text('24-Hour Digital Clock'),
              subtitle: const Text('Display military format (e.g. 21:45)'),
              value: config.use24HourFormat,
              onChanged: (val) => notifier.setUse24HourFormat(val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppTheme.accent,
              title: const Text('Floating Album Artwork'),
              subtitle: const Text('Show subtle floating cover art animation'),
              value: config.showArtwork,
              onChanged: (val) => notifier.setShowArtwork(val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppTheme.accent,
              title: const Text('Track Progress Bar'),
              subtitle: const Text('Show duration & elapsed progress'),
              value: config.showProgressBar,
              onChanged: (val) => notifier.setShowProgressBar(val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppTheme.accent,
              title: const Text('Only When Playing'),
              subtitle: const Text('Do not activate if playback is paused'),
              value: config.onlyWhenPlaying,
              onChanged: (val) => notifier.setOnlyWhenPlaying(val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.fullscreen_rounded, size: 18.0),
          label: const Text('Preview Now'),
          onPressed: () {
            Navigator.of(context).pop();
            notifier.forceActivate();
          },
        ),
      ],
    );
  }
}
