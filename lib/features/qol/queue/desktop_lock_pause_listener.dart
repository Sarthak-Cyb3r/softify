// ============================================================================
// Softify Quality of Life (QoL) - Feature 15: Auto-Pause on Desktop Lock / Sleep
// ============================================================================
//
// Monitors Linux desktop session events via freedesktop & systemd D-Bus signals:
// 1. ScreenSaver lock / unlock:
//    - org.freedesktop.ScreenSaver -> ActiveChanged(bool)
//    - org.gnome.ScreenSaver -> ActiveChanged(bool)
// 2. systemd-logind session lock / unlock:
//    - org.freedesktop.login1.Session -> Lock(), Unlock()
// 3. systemd-logind power management sleep / resume:
//    - org.freedesktop.login1.Manager -> PrepareForSleep(bool)
// 4. UPower power management sleep / resume:
//    - org.freedesktop.UPower -> Sleeping(), Resuming()
//
// Automatically pauses playback when the screen is locked or the computer sleeps,
// preventing battery drain and unwanted music playback while away.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Constants & Persistence Keys
// ============================================================================

/// SharedPreferences key for auto-pause on lock / sleep preference.
const String kDesktopAutoPauseOnLockPrefKey =
    'softify_auto_pause_on_desktop_lock';

/// SharedPreferences key for optional auto-resume on unlock preference.
const String kDesktopAutoResumeOnUnlockPrefKey =
    'softify_auto_resume_on_desktop_unlock';

/// Well-known D-Bus interface and signal names for Linux desktop sessions.
const String kDBusScreenSaverInterface = 'org.freedesktop.ScreenSaver';
const String kDBusGnomeScreenSaverInterface = 'org.gnome.ScreenSaver';
const String kDBusLogin1ManagerInterface = 'org.freedesktop.login1.Manager';
const String kDBusLogin1SessionInterface = 'org.freedesktop.login1.Session';
const String kDBusUPowerInterface = 'org.freedesktop.UPower';

const String kDBusSignalActiveChanged = 'ActiveChanged';
const String kDBusSignalPrepareForSleep = 'PrepareForSleep';
const String kDBusSignalLock = 'Lock';
const String kDBusSignalUnlock = 'Unlock';
const String kDBusSignalSleeping = 'Sleeping';
const String kDBusSignalResuming = 'Resuming';

// ============================================================================
// Enums & Models
// ============================================================================

/// Types of desktop session events detected by the listener.
enum DesktopSessionEventType {
  /// The desktop screen was locked or screensaver activated.
  lock('Screen Locked', 'Desktop session locked or screensaver active'),

  /// The desktop screen was unlocked or screensaver deactivated.
  unlock('Screen Unlocked', 'Desktop session unlocked'),

  /// The operating system is entering suspend/sleep/hibernate.
  sleep('System Suspending', 'Computer preparing to sleep or suspend'),

  /// The operating system resumed from suspend/sleep.
  resume('System Resumed', 'Computer woke up from sleep or suspend');

  final String displayName;
  final String description;
  const DesktopSessionEventType(this.displayName, this.description);

  bool get isLockOrSleep =>
      this == DesktopSessionEventType.lock ||
      this == DesktopSessionEventType.sleep;

  bool get isUnlockOrResume =>
      this == DesktopSessionEventType.unlock ||
      this == DesktopSessionEventType.resume;
}

/// The specific reason an auto-pause was triggered.
enum DesktopLockPauseReason {
  /// Paused because desktop screen saver or lock screen activated.
  screenLocked(
    'Screen Locked',
    'Audio paused due to desktop session screen lock',
  ),

  /// Paused because computer entered sleep, suspend, or hibernate.
  powerSleep(
    'System Sleep',
    'Audio paused due to operating system power suspend',
  ),

  /// Paused because systemd-logind emitted session Lock signal.
  sessionLocked(
    'Session Locked',
    'Audio paused due to logind session lock event',
  ),

  /// Paused programmatically via testing harness or manual simulation.
  manualSimulation(
    'Manual Simulation',
    'Audio paused via simulated session lock event',
  );

  final String label;
  final String description;
  const DesktopLockPauseReason(this.label, this.description);
}

/// Event model capturing a single session lock or power transition.
@immutable
class DesktopSessionEvent {
  /// The nature of the session event.
  final DesktopSessionEventType type;

  /// Timestamp when the event was observed.
  final DateTime timestamp;

  /// D-Bus interface, process name, or test harness that originated the event.
  final String source;

  /// Optional contextual metadata or raw D-Bus payload values.
  final Map<String, dynamic> metadata;

  DesktopSessionEvent({
    required this.type,
    DateTime? timestamp,
    this.source = 'org.freedesktop.ScreenSaver',
    Map<String, dynamic>? metadata,
  })  : timestamp = timestamp ?? DateTime.now(),
        metadata = metadata ?? const {};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopSessionEvent &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          source == other.source &&
          timestamp.millisecondsSinceEpoch ==
              other.timestamp.millisecondsSinceEpoch;

  @override
  int get hashCode => Object.hash(type, source, timestamp.millisecondsSinceEpoch);

  @override
  String toString() =>
      'DesktopSessionEvent(type: ${type.name}, source: $source, time: $timestamp)';
}

/// Immutable state snapshot of desktop session lock pause status.
@immutable
class DesktopLockPauseState {
  /// Whether auto-pause on lock/sleep is enabled by user preference.
  final bool autoPauseOnLock;

  /// Whether auto-resume on unlock is enabled by user preference.
  final bool autoResumeOnUnlock;

  /// Whether the desktop screen is currently locked.
  final bool isLocked;

  /// Whether the system is currently sleeping or suspended.
  final bool isSleeping;

  /// Whether audio was actively playing immediately prior to auto-pause.
  final bool wasPlayingBeforePause;

  /// The root cause of the most recent auto-pause action.
  final DesktopLockPauseReason? lastPauseReason;

  /// Timestamp of the most recent session event or auto-pause.
  final DateTime? lastEventTime;

  /// Total count of times playback was automatically paused on lock/sleep.
  final int pauseTriggerCount;

  /// Whether the native D-Bus listener is actively monitoring.
  final bool isListening;

  /// Most recent error message (if D-Bus connection failed), null if healthy.
  final String? lastError;

  const DesktopLockPauseState({
    this.autoPauseOnLock = true,
    this.autoResumeOnUnlock = false,
    this.isLocked = false,
    this.isSleeping = false,
    this.wasPlayingBeforePause = false,
    this.lastPauseReason,
    this.lastEventTime,
    this.pauseTriggerCount = 0,
    this.isListening = false,
    this.lastError,
  });

  /// True if desktop is either locked or sleeping.
  bool get isSuspendedOrLocked => isLocked || isSleeping;

  DesktopLockPauseState copyWith({
    bool? autoPauseOnLock,
    bool? autoResumeOnUnlock,
    bool? isLocked,
    bool? isSleeping,
    bool? wasPlayingBeforePause,
    DesktopLockPauseReason? lastPauseReason,
    DateTime? lastEventTime,
    int? pauseTriggerCount,
    bool? isListening,
    String? lastError,
    bool clearLastError = false,
  }) {
    return DesktopLockPauseState(
      autoPauseOnLock: autoPauseOnLock ?? this.autoPauseOnLock,
      autoResumeOnUnlock: autoResumeOnUnlock ?? this.autoResumeOnUnlock,
      isLocked: isLocked ?? this.isLocked,
      isSleeping: isSleeping ?? this.isSleeping,
      wasPlayingBeforePause:
          wasPlayingBeforePause ?? this.wasPlayingBeforePause,
      lastPauseReason: lastPauseReason ?? this.lastPauseReason,
      lastEventTime: lastEventTime ?? this.lastEventTime,
      pauseTriggerCount: pauseTriggerCount ?? this.pauseTriggerCount,
      isListening: isListening ?? this.isListening,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopLockPauseState &&
          runtimeType == other.runtimeType &&
          autoPauseOnLock == other.autoPauseOnLock &&
          autoResumeOnUnlock == other.autoResumeOnUnlock &&
          isLocked == other.isLocked &&
          isSleeping == other.isSleeping &&
          wasPlayingBeforePause == other.wasPlayingBeforePause &&
          lastPauseReason == other.lastPauseReason &&
          pauseTriggerCount == other.pauseTriggerCount &&
          isListening == other.isListening &&
          lastError == other.lastError;

  @override
  int get hashCode => Object.hash(
        autoPauseOnLock,
        autoResumeOnUnlock,
        isLocked,
        isSleeping,
        wasPlayingBeforePause,
        lastPauseReason,
        pauseTriggerCount,
        isListening,
        lastError,
      );

  @override
  String toString() =>
      'DesktopLockPauseState(autoPause: $autoPauseOnLock, locked: $isLocked, sleeping: $isSleeping, pauseCount: $pauseTriggerCount, listening: $isListening)';
}

// ============================================================================
// Self-Contained SharedPreferences Layer
// ============================================================================

/// Self-contained, crash-safe SharedPreferences engine for desktop lock settings.
/// Matches standard `package:shared_preferences` interface without external plugin coupling.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _storageFile;

  SharedPreferences._(this._store, this._storageFile);

  /// Synchronously accessible cached singleton instance if resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects initial values for test suites.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance for clean test isolation.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Asynchronously loads or initializes preferences storage.
  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) return _instance!;
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
      final dir = Directory.systemTemp;
      file = File('${dir.path}/softify_desktop_lock_prefs.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (value != null) store[key.toString()] = value as Object;
            });
          }
        }
      }
    } catch (_) {
      // Fallback to in-memory store on filesystem restriction
    }

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  bool? getBool(String key) {
    final v = _store[key];
    return v is bool ? v : null;
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

  Future<void> _persist() async {
    if (_storageFile == null) return;
    try {
      await _storageFile!.writeAsString(jsonEncode(_store));
    } catch (_) {}
  }
}

// ============================================================================
// Riverpod State Notifiers
// ============================================================================

/// Riverpod StateNotifier managing the user's autoPauseOnLock preference.
///
/// Defaults to true so that music is safely paused when leaving the desktop.
/// Automatically persists toggled state to [SharedPreferences].
class AutoPauseOnLockNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  AutoPauseOnLockNotifier([this._prefs, bool defaultValue = true])
      : super(defaultValue) {
    _loadPreference();
  }

  /// Synchronous boolean accessor.
  bool get isEnabled => state;

  Future<void> _loadPreference() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final saved = prefs.getBool(kDesktopAutoPauseOnLockPrefKey);
      if (saved != null) {
        state = saved;
      }
    } catch (_) {}
  }

  /// Sets whether auto-pause on lock/sleep is enabled and persists to storage.
  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(kDesktopAutoPauseOnLockPrefKey, enabled);
    } catch (_) {}
  }

  /// Toggles preference between true and false.
  Future<void> toggle() async {
    await setEnabled(!state);
  }

  /// Testing helper to set mock state synchronously.
  @visibleForTesting
  void setMockValue(bool value) {
    state = value;
  }
}

/// Provider exposing the auto-pause on lock preference boolean.
final autoPauseOnLockProvider =
    StateNotifierProvider<AutoPauseOnLockNotifier, bool>((ref) {
  return AutoPauseOnLockNotifier();
});

/// Riverpod StateNotifier managing the overall [DesktopLockPauseState].
class DesktopLockPauseController extends StateNotifier<DesktopLockPauseState> {
  final SharedPreferences? _prefs;

  DesktopLockPauseController([
    this._prefs,
    DesktopLockPauseState initialState = const DesktopLockPauseState(),
  ]) : super(initialState) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final autoPause = prefs.getBool(kDesktopAutoPauseOnLockPrefKey);
      final autoResume = prefs.getBool(kDesktopAutoResumeOnUnlockPrefKey);

      state = state.copyWith(
        autoPauseOnLock: autoPause ?? state.autoPauseOnLock,
        autoResumeOnUnlock: autoResume ?? state.autoResumeOnUnlock,
      );
    } catch (_) {}
  }

  /// Updates the autoPauseOnLock preference and persists it.
  Future<void> setAutoPauseOnLock(bool enabled) async {
    if (state.autoPauseOnLock == enabled) return;
    state = state.copyWith(autoPauseOnLock: enabled);
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(kDesktopAutoPauseOnLockPrefKey, enabled);
    } catch (_) {}
  }

  /// Toggles auto-pause on lock preference.
  Future<void> toggleAutoPauseOnLock() async {
    await setAutoPauseOnLock(!state.autoPauseOnLock);
  }

  /// Updates the autoResumeOnUnlock preference and persists it.
  Future<void> setAutoResumeOnUnlock(bool enabled) async {
    if (state.autoResumeOnUnlock == enabled) return;
    state = state.copyWith(autoResumeOnUnlock: enabled);
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(kDesktopAutoResumeOnUnlockPrefKey, enabled);
    } catch (_) {}
  }

  /// Applies a newly observed session event to reactive state.
  void updateSessionEvent(DesktopSessionEvent event) {
    switch (event.type) {
      case DesktopSessionEventType.lock:
        state = state.copyWith(
          isLocked: true,
          lastEventTime: event.timestamp,
        );
        break;
      case DesktopSessionEventType.unlock:
        state = state.copyWith(
          isLocked: false,
          lastEventTime: event.timestamp,
        );
        break;
      case DesktopSessionEventType.sleep:
        state = state.copyWith(
          isSleeping: true,
          lastEventTime: event.timestamp,
        );
        break;
      case DesktopSessionEventType.resume:
        state = state.copyWith(
          isSleeping: false,
          lastEventTime: event.timestamp,
        );
        break;
    }
  }

  /// Records an executed auto-pause action.
  void recordPauseTriggered({
    required DesktopLockPauseReason reason,
    required bool wasPlaying,
  }) {
    state = state.copyWith(
      wasPlayingBeforePause: wasPlaying,
      lastPauseReason: reason,
      lastEventTime: DateTime.now(),
      pauseTriggerCount: state.pauseTriggerCount + 1,
    );
  }

  /// Clears wasPlayingBeforePause flag after resume or manual restart.
  void recordPlaybackResumed() {
    state = state.copyWith(
      wasPlayingBeforePause: false,
      lastEventTime: DateTime.now(),
    );
  }

  /// Updates whether the D-Bus listener is actively connected.
  void setListening(bool isListening, {String? error}) {
    state = state.copyWith(
      isListening: isListening,
      lastError: error,
    );
  }

  /// Resets pause counts and error flags.
  void resetCounters() {
    state = state.copyWith(
      pauseTriggerCount: 0,
      clearLastError: true,
      wasPlayingBeforePause: false,
    );
  }
}

/// Provider exposing the complete [DesktopLockPauseState].
final desktopLockPauseControllerProvider =
    StateNotifierProvider<DesktopLockPauseController, DesktopLockPauseState>(
        (ref) {
  return DesktopLockPauseController();
});

// ============================================================================
// Desktop Session Lock & Power Sleep Listener
// ============================================================================

/// Listens for desktop session screen lock and power sleep events on Linux
/// via D-Bus session and system bus signals, automatically pausing playback
/// according to user configuration.
class DesktopLockPauseListener {
  final SoftifyAudioHandler? _audioHandler;
  final AutoPauseOnLockNotifier? _preferenceNotifier;
  final DesktopLockPauseController? _controller;

  // Custom dependency hooks for headless unit tests
  final Future<bool> Function()? _isPlayingQuery;
  final Future<void> Function()? _onPauseCallback;
  final Future<void> Function()? _onResumeCallback;
  final void Function(DesktopSessionEvent event)? _onEventTriggered;
  final void Function(String message)? _logger;

  // D-Bus connections
  DBusClient? _sessionBus;
  DBusClient? _systemBus;
  final bool _ownsSessionBus;
  final bool _ownsSystemBus;

  final List<StreamSubscription> _subscriptions = [];
  final StreamController<DesktopSessionEvent> _eventController =
      StreamController<DesktopSessionEvent>.broadcast();

  bool _isListening = false;
  bool _isDisposed = false;
  bool _wasPlayingBeforePause = false;
  int _pauseTriggerCount = 0;
  DesktopLockPauseState _internalState = const DesktopLockPauseState();

  DesktopLockPauseListener({
    SoftifyAudioHandler? audioHandler,
    AutoPauseOnLockNotifier? preferenceNotifier,
    DesktopLockPauseController? controller,
    DBusClient? sessionBus,
    DBusClient? systemBus,
    Future<bool> Function()? isPlayingQuery,
    Future<void> Function()? onPauseCallback,
    Future<void> Function()? onResumeCallback,
    void Function(DesktopSessionEvent event)? onEventTriggered,
    void Function(String message)? logger,
  })  : _audioHandler = audioHandler,
        _preferenceNotifier = preferenceNotifier,
        _controller = controller,
        _sessionBus = sessionBus,
        _systemBus = systemBus,
        _ownsSessionBus = sessionBus == null,
        _ownsSystemBus = systemBus == null,
        _isPlayingQuery = isPlayingQuery,
        _onPauseCallback = onPauseCallback,
        _onResumeCallback = onResumeCallback,
        _onEventTriggered = onEventTriggered,
        _logger = logger;

  /// Broadcast stream of all observed session lock and sleep events.
  Stream<DesktopSessionEvent> get eventStream => _eventController.stream;

  /// True if currently subscribed to D-Bus signal streams.
  bool get isListening => _isListening;

  /// True if disposed.
  bool get isDisposed => _isDisposed;

  /// Total count of times playback was paused on lock/sleep.
  int get pauseTriggerCount => _pauseTriggerCount;

  /// Whether playback was playing right before the last lock/sleep pause.
  bool get wasPlayingBeforePause => _wasPlayingBeforePause;

  /// Current state snapshot.
  DesktopLockPauseState get state => _controller?.state ?? _internalState;

  void _log(String msg) {
    if (_logger != null) {
      _logger!('[DesktopLockPauseListener] $msg');
    }
  }

  // --------------------------------------------------------------------------
  // Lifecycle & D-Bus Subscriptions
  // --------------------------------------------------------------------------

  /// Begins listening for Linux desktop lock and power sleep D-Bus signals.
  ///
  /// On non-Linux platforms or environments without a running D-Bus daemon,
  /// catches errors gracefully and operates in programmatic simulation mode.
  Future<bool> startListening() async {
    if (_isDisposed || _isListening) return _isListening;

    final isLinuxDesktop = !kIsWeb && Platform.isLinux;

    if (!isLinuxDesktop && _sessionBus == null && _systemBus == null) {
      _log('Non-Linux platform detected; running in simulation-only mode');
      _setListeningState(true);
      return true;
    }

    try {
      // 1. Establish Session Bus connection for ScreenSaver signals
      if (_sessionBus == null) {
        try {
          _sessionBus = DBusClient.session();
        } catch (e) {
          _log('Failed to connect to D-Bus session bus: $e');
        }
      }

      // 2. Establish System Bus connection for systemd logind PrepareForSleep
      if (_systemBus == null) {
        try {
          _systemBus = DBusClient.system();
        } catch (e) {
          _log('Failed to connect to D-Bus system bus: $e');
        }
      }

      // 3. Subscribe to Session Bus ScreenSaver signals
      if (_sessionBus != null) {
        _subscribeToSessionBus();
      }

      // 4. Subscribe to System Bus logind and UPower signals
      if (_systemBus != null) {
        _subscribeToSystemBus();
      }

      _setListeningState(true);
      _log('Successfully subscribed to desktop lock & power sleep signals');
      return true;
    } catch (e) {
      _log('Error initializing D-Bus listeners: $e');
      _setListeningState(false, error: e.toString());
      return false;
    }
  }

  void _subscribeToSessionBus() {
    if (_sessionBus == null) return;

    try {
      // freedesktop ScreenSaver ActiveChanged
      final fdScreenSaverStream = DBusSignalStream(
        _sessionBus!,
        interface: kDBusScreenSaverInterface,
        name: kDBusSignalActiveChanged,
      );
      _subscriptions.add(fdScreenSaverStream.listen(
        _handleScreenSaverActiveChanged,
        onError: (err) => _log('ScreenSaver signal error: $err'),
      ));

      // GNOME ScreenSaver ActiveChanged
      final gnomeScreenSaverStream = DBusSignalStream(
        _sessionBus!,
        interface: kDBusGnomeScreenSaverInterface,
        name: kDBusSignalActiveChanged,
      );
      _subscriptions.add(gnomeScreenSaverStream.listen(
        _handleScreenSaverActiveChanged,
        onError: (err) => _log('GNOME ScreenSaver signal error: $err'),
      ));
    } catch (e) {
      _log('Error subscribing to session bus signals: $e');
    }
  }

  void _subscribeToSystemBus() {
    if (_systemBus == null) return;

    try {
      // systemd-logind PrepareForSleep (suspend / hibernate)
      final prepareForSleepStream = DBusSignalStream(
        _systemBus!,
        interface: kDBusLogin1ManagerInterface,
        name: kDBusSignalPrepareForSleep,
      );
      _subscriptions.add(prepareForSleepStream.listen(
        _handlePrepareForSleepSignal,
        onError: (err) => _log('PrepareForSleep signal error: $err'),
      ));

      // systemd-logind Session Lock
      final sessionLockStream = DBusSignalStream(
        _systemBus!,
        interface: kDBusLogin1SessionInterface,
        name: kDBusSignalLock,
      );
      _subscriptions.add(sessionLockStream.listen(
        (signal) => _dispatchSessionEvent(DesktopSessionEvent(
          type: DesktopSessionEventType.lock,
          source: kDBusLogin1SessionInterface,
        )),
        onError: (err) => _log('Session Lock signal error: $err'),
      ));

      // systemd-logind Session Unlock
      final sessionUnlockStream = DBusSignalStream(
        _systemBus!,
        interface: kDBusLogin1SessionInterface,
        name: kDBusSignalUnlock,
      );
      _subscriptions.add(sessionUnlockStream.listen(
        (signal) => _dispatchSessionEvent(DesktopSessionEvent(
          type: DesktopSessionEventType.unlock,
          source: kDBusLogin1SessionInterface,
        )),
        onError: (err) => _log('Session Unlock signal error: $err'),
      ));

      // UPower Sleeping
      final upowerSleepStream = DBusSignalStream(
        _systemBus!,
        interface: kDBusUPowerInterface,
        name: kDBusSignalSleeping,
      );
      _subscriptions.add(upowerSleepStream.listen(
        (signal) => _dispatchSessionEvent(DesktopSessionEvent(
          type: DesktopSessionEventType.sleep,
          source: kDBusUPowerInterface,
        )),
        onError: (err) => _log('UPower Sleeping signal error: $err'),
      ));

      // UPower Resuming
      final upowerResumeStream = DBusSignalStream(
        _systemBus!,
        interface: kDBusUPowerInterface,
        name: kDBusSignalResuming,
      );
      _subscriptions.add(upowerResumeStream.listen(
        (signal) => _dispatchSessionEvent(DesktopSessionEvent(
          type: DesktopSessionEventType.resume,
          source: kDBusUPowerInterface,
        )),
        onError: (err) => _log('UPower Resuming signal error: $err'),
      ));
    } catch (e) {
      _log('Error subscribing to system bus signals: $e');
    }
  }

  /// Stops listening and cancels active D-Bus signal subscriptions.
  Future<void> stopListening() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    if (_ownsSessionBus) {
      try {
        await _sessionBus?.close();
      } catch (_) {}
      _sessionBus = null;
    }

    if (_ownsSystemBus) {
      try {
        await _systemBus?.close();
      } catch (_) {}
      _systemBus = null;
    }

    _setListeningState(false);
    _log('Stopped desktop lock & sleep listener');
  }

  void _setListeningState(bool listening, {String? error}) {
    _isListening = listening;
    _internalState = _internalState.copyWith(
      isListening: listening,
      lastError: error,
    );
    _controller?.setListening(listening, error: error);
  }

  // --------------------------------------------------------------------------
  // D-Bus Signal Parsers
  // --------------------------------------------------------------------------

  /// Parses `ActiveChanged(bool active)` signals from freedesktop or GNOME screensaver.
  void _handleScreenSaverActiveChanged(DBusSignal signal) {
    final isLocked = _extractBooleanFromSignal(signal.values);
    final eventType = isLocked
        ? DesktopSessionEventType.lock
        : DesktopSessionEventType.unlock;

    _dispatchSessionEvent(DesktopSessionEvent(
      type: eventType,
      source: signal.interface,
      metadata: {'active': isLocked},
    ));
  }

  /// Parses `PrepareForSleep(bool start)` signals from systemd-logind.
  void _handlePrepareForSleepSignal(DBusSignal signal) {
    final isEnteringSleep = _extractBooleanFromSignal(signal.values);
    final eventType = isEnteringSleep
        ? DesktopSessionEventType.sleep
        : DesktopSessionEventType.resume;

    _dispatchSessionEvent(DesktopSessionEvent(
      type: eventType,
      source: signal.interface,
      metadata: {'start': isEnteringSleep},
    ));
  }

  /// Extracts boolean value safely from DBusValue collection.
  static bool _extractBooleanFromSignal(
    List<DBusValue> values, {
    bool defaultValue = false,
  }) {
    if (values.isEmpty) return defaultValue;
    final first = values.first;
    if (first is DBusBoolean) {
      return first.value;
    }
    try {
      return first.toNative() == true;
    } catch (_) {
      return defaultValue;
    }
  }

  // --------------------------------------------------------------------------
  // Event Dispatch & Auto-Pause Execution
  // --------------------------------------------------------------------------

  void _dispatchSessionEvent(DesktopSessionEvent event) {
    if (_isDisposed) return;
    _log('Received desktop session event: ${event.type.name} from ${event.source}');

    _eventController.add(event);
    _onEventTriggered?.call(event);
    _controller?.updateSessionEvent(event);

    _internalState = _internalState.copyWith(
      isLocked: event.type == DesktopSessionEventType.lock
          ? true
          : (event.type == DesktopSessionEventType.unlock ? false : null),
      isSleeping: event.type == DesktopSessionEventType.sleep
          ? true
          : (event.type == DesktopSessionEventType.resume ? false : null),
      lastEventTime: event.timestamp,
    );

    unawaited(handleSessionEvent(event));
  }

  /// Evaluates and handles a [DesktopSessionEvent] against auto-pause preference.
  Future<void> handleSessionEvent(DesktopSessionEvent event) async {
    final bool isAutoPauseEnabled = _checkIsAutoPauseEnabled();

    switch (event.type) {
      case DesktopSessionEventType.lock:
        if (isAutoPauseEnabled) {
          await _triggerAutoPause(DesktopLockPauseReason.screenLocked);
        }
        break;

      case DesktopSessionEventType.sleep:
        if (isAutoPauseEnabled) {
          await _triggerAutoPause(DesktopLockPauseReason.powerSleep);
        }
        break;

      case DesktopSessionEventType.unlock:
      case DesktopSessionEventType.resume:
        await _handleUnlockOrResume();
        break;
    }
  }

  bool _checkIsAutoPauseEnabled() {
    if (_preferenceNotifier != null) {
      return _preferenceNotifier!.isEnabled;
    }
    if (_controller != null) {
      return _controller!.state.autoPauseOnLock;
    }
    return _internalState.autoPauseOnLock;
  }

  bool _checkIsAutoResumeEnabled() {
    if (_controller != null) {
      return _controller!.state.autoResumeOnUnlock;
    }
    return _internalState.autoResumeOnUnlock;
  }

  /// Checks if playback is actively running.
  Future<bool> isAudioPlaying() async {
    if (_isPlayingQuery != null) {
      return await _isPlayingQuery!();
    }

    if (_audioHandler != null) {
      try {
        final playbackState = _audioHandler!.playbackState.valueOrNull ??
            _audioHandler!.playbackState.value;
        return playbackState.playing;
      } catch (_) {
        return false;
      }
    }

    return false;
  }

  Future<void> _triggerAutoPause(DesktopLockPauseReason reason) async {
    final playing = await isAudioPlaying();
    if (!playing) {
      _log('Session lock/sleep occurred, but playback is already paused');
      _wasPlayingBeforePause = false;
      return;
    }

    _log('Triggering auto-pause due to: ${reason.label}');
    _wasPlayingBeforePause = true;
    _pauseTriggerCount++;

    _internalState = _internalState.copyWith(
      wasPlayingBeforePause: true,
      lastPauseReason: reason,
      lastEventTime: DateTime.now(),
      pauseTriggerCount: _pauseTriggerCount,
    );
    _controller?.recordPauseTriggered(reason: reason, wasPlaying: true);

    if (_onPauseCallback != null) {
      await _onPauseCallback!();
    } else if (_audioHandler != null) {
      try {
        await _audioHandler!.pause();
      } catch (e) {
        _log('Error pausing audioHandler: $e');
      }
    }
  }

  Future<void> _handleUnlockOrResume() async {
    final shouldResume = _checkIsAutoResumeEnabled() && _wasPlayingBeforePause;

    if (shouldResume) {
      _log('Auto-resume enabled; resuming playback after desktop unlock');
      if (_onResumeCallback != null) {
        await _onResumeCallback!();
      } else if (_audioHandler != null) {
        try {
          await _audioHandler!.play();
        } catch (e) {
          _log('Error resuming audioHandler: $e');
        }
      }
      _controller?.recordPlaybackResumed();
    }

    _wasPlayingBeforePause = false;
    _internalState = _internalState.copyWith(wasPlayingBeforePause: false);
  }

  // --------------------------------------------------------------------------
  // Simulation Helpers (for Testing & Developer Tools)
  // --------------------------------------------------------------------------

  /// Simulates a screen lock event.
  Future<void> simulateLock({String source = 'manual_simulation'}) async {
    final event = DesktopSessionEvent(
      type: DesktopSessionEventType.lock,
      source: source,
    );
    _dispatchSessionEvent(event);
  }

  /// Simulates a screen unlock event.
  Future<void> simulateUnlock({String source = 'manual_simulation'}) async {
    final event = DesktopSessionEvent(
      type: DesktopSessionEventType.unlock,
      source: source,
    );
    _dispatchSessionEvent(event);
  }

  /// Simulates an operating system sleep/suspend event.
  Future<void> simulateSleep({String source = 'manual_simulation'}) async {
    final event = DesktopSessionEvent(
      type: DesktopSessionEventType.sleep,
      source: source,
    );
    _dispatchSessionEvent(event);
  }

  /// Simulates an operating system wake/resume event.
  Future<void> simulateResume({String source = 'manual_simulation'}) async {
    final event = DesktopSessionEvent(
      type: DesktopSessionEventType.resume,
      source: source,
    );
    _dispatchSessionEvent(event);
  }

  /// Dispatches an arbitrary simulated session event.
  Future<void> simulateEvent(DesktopSessionEvent event) async {
    _dispatchSessionEvent(event);
  }

  // --------------------------------------------------------------------------
  // Disposal
  // --------------------------------------------------------------------------

  /// Disposes active subscriptions, clients, and stream controllers.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    if (_ownsSessionBus) {
      try {
        _sessionBus?.close();
      } catch (_) {}
    }

    if (_ownsSystemBus) {
      try {
        _systemBus?.close();
      } catch (_) {}
    }

    _eventController.close();
  }
}

/// Provider creating and managing the desktop lock pause listener.
final desktopLockPauseListenerProvider =
    Provider<DesktopLockPauseListener>((ref) {
  SoftifyAudioHandler? handler;
  try {
    handler = ref.watch(audioHandlerProvider);
  } catch (_) {
    handler = null;
  }

  final prefNotifier = ref.watch(autoPauseOnLockProvider.notifier);
  final controller = ref.watch(desktopLockPauseControllerProvider.notifier);

  final listener = DesktopLockPauseListener(
    audioHandler: handler,
    preferenceNotifier: prefNotifier,
    controller: controller,
  );

  // Automatically start listening in background
  unawaited(listener.startListening());

  ref.onDispose(() {
    listener.dispose();
  });

  return listener;
});

// ============================================================================
// UI Component: DesktopLockPauseToggleTile
// ============================================================================

/// Material 3 Settings Tile widget allowing users to toggle auto-pause on lock/sleep.
///
/// Blends seamlessly with Softify's desktop aesthetic using [AppTokens] design tokens,
/// responsive states, animated toggles, and clear descriptive typography.
class DesktopLockPauseToggleTile extends ConsumerWidget {
  /// Outer margins around the tile container.
  final EdgeInsetsGeometry? margin;

  /// Internal padding inside the tile.
  final EdgeInsetsGeometry? padding;

  /// Primary label displayed on the tile.
  final String title;

  /// Optional custom subtitle explaining the feature.
  final String? subtitle;

  /// Leading icon displayed alongside the text.
  final IconData icon;

  /// Accent color overriding standard theme token.
  final Color? activeColor;

  /// Whether to render an enclosing outline border.
  final bool showBorder;

  /// Whether to display a compact dense layout.
  final bool dense;

  /// Whether to show a live session status badge (e.g., "Active", "Locked").
  final bool showStatusBadge;

  /// Optional callback invoked when the toggle value changes.
  final ValueChanged<bool>? onToggled;

  const DesktopLockPauseToggleTile({
    super.key,
    this.margin,
    this.padding,
    this.title = 'Auto-Pause on Lock / Sleep',
    this.subtitle,
    this.icon = Icons.lock_clock_rounded,
    this.activeColor,
    this.showBorder = true,
    this.dense = false,
    this.showStatusBadge = false,
    this.onToggled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final isEnabled = ref.watch(autoPauseOnLockProvider);
    final lockState = ref.watch(desktopLockPauseControllerProvider);
    final accent = activeColor ?? tokens.accent;

    final String effectiveSubtitle = subtitle ??
        (isEnabled
            ? 'Music pauses automatically when your computer locks or goes to sleep'
            : 'Music continues playing even when the desktop is locked or sleeping');

    final bool isSessionInactive = lockState.isSuspendedOrLocked;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isEnabled
            ? accent.withValues(alpha: 0.08)
            : tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: showBorder
            ? Border.all(
                color: isEnabled
                    ? accent.withValues(alpha: 0.35)
                    : tokens.divider.withValues(alpha: 0.5),
                width: 1,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          onTap: () {
            HapticFeedback.selectionClick();
            final nextValue = !isEnabled;
            ref.read(autoPauseOnLockProvider.notifier).setEnabled(nextValue);
            ref
                .read(desktopLockPauseControllerProvider.notifier)
                .setAutoPauseOnLock(nextValue);
            onToggled?.call(nextValue);
          },
          child: Padding(
            padding: padding ??
                EdgeInsets.symmetric(
                  horizontal: tokens.spaceMd,
                  vertical: dense ? tokens.spaceSm : tokens.spaceMd,
                ),
            child: Row(
              children: [
                // Leading Icon in rounded container
                Container(
                  width: dense ? 36 : 42,
                  height: dense ? 36 : 42,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? accent.withValues(alpha: 0.18)
                        : tokens.surfaceHighlight,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Icon(
                    isSessionInactive
                        ? Icons.screen_lock_portrait_rounded
                        : icon,
                    color: isEnabled ? accent : tokens.textSecondary,
                    size: dense ? 19 : 22,
                  ),
                ),
                SizedBox(width: tokens.spaceMd),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: dense ? 13.5 : 14.5,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showStatusBadge) ...[
                            const SizedBox(width: 8),
                            _buildStatusBadge(
                              context,
                              tokens,
                              isSessionInactive: isSessionInactive,
                              pauseCount: lockState.pauseTriggerCount,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        effectiveSubtitle,
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: dense ? 11.5 : 12.5,
                          color: tokens.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.spaceSm),

                // Material 3 Switch
                Switch(
                  value: isEnabled,
                  activeColor: accent,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    ref
                        .read(autoPauseOnLockProvider.notifier)
                        .setEnabled(val);
                    ref
                        .read(desktopLockPauseControllerProvider.notifier)
                        .setAutoPauseOnLock(val);
                    onToggled?.call(val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    AppTokens tokens, {
    required bool isSessionInactive,
    required int pauseCount,
  }) {
    final badgeColor = isSessionInactive ? tokens.accentRose : tokens.accentCyan;
    final badgeLabel = isSessionInactive
        ? 'Locked'
        : (pauseCount > 0 ? '$pauseCount pauses' : 'Active');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Text(
        badgeLabel,
        style: TextStyle(
          fontFamily: AppTheme.fontUi,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: badgeColor,
        ),
      ),
    );
  }
}
