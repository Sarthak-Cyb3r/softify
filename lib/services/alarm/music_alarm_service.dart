import 'dart:async';
import 'dart:math' as math;

/// Days of week constants matching [DateTime.monday] through [DateTime.sunday].
class AlarmDay {
  static const int monday = DateTime.monday; // 1
  static const int tuesday = DateTime.tuesday; // 2
  static const int wednesday = DateTime.wednesday; // 3
  static const int thursday = DateTime.thursday; // 4
  static const int friday = DateTime.friday; // 5
  static const int saturday = DateTime.saturday; // 6
  static const int sunday = DateTime.sunday; // 7

  static const List<int> allDays = [1, 2, 3, 4, 5, 6, 7];
  static const List<int> weekdays = [1, 2, 3, 4, 5];
  static const List<int> weekends = [6, 7];
}

/// Curve type used for gentle audio volume ramping.
enum VolumeRampCurve {
  linear,
  sCurve, // Smoothstep S-curve: t * t * (3 - 2 * t)
}

/// Represents an individual music alarm configuration.
/// Reverse-engineered from Metrolist (MusicAlarmEntry.kt).
class MusicAlarm {
  final String id;
  final int hour; // 0 - 23
  final int minute; // 0 - 59
  final List<int> daysOfWeek; // 1 (Mon) - 7 (Sun). Empty list means one-off alarm.
  final String? playlistId;
  final String? playlistTitle;
  final bool randomSong;
  final int volume; // Target volume: 0 - 100
  final int fadeDurationSeconds; // Gentle fade-in duration: 0 - 300s
  final int snoozeMinutes; // Snooze duration: e.g. 5, 10 mins
  final bool enabled;
  final String? label;

  const MusicAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.daysOfWeek = const [],
    this.playlistId,
    this.playlistTitle,
    this.randomSong = true,
    this.volume = 80,
    this.fadeDurationSeconds = 30,
    this.snoozeMinutes = 10,
    this.enabled = true,
    this.label,
  });

  bool get isRecurring => daysOfWeek.isNotEmpty;

  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  DateTime calculateNextTrigger([DateTime? fromTime]) {
    return MusicAlarmService.calculateNextTrigger(hour, minute, daysOfWeek, fromTime);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'daysOfWeek': daysOfWeek,
      'playlistId': playlistId,
      'playlistTitle': playlistTitle,
      'randomSong': randomSong,
      'volume': volume,
      'fadeDurationSeconds': fadeDurationSeconds,
      'snoozeMinutes': snoozeMinutes,
      'enabled': enabled,
      'label': label,
    };
  }

  factory MusicAlarm.fromJson(Map<String, dynamic> json) {
    return MusicAlarm(
      id: json['id'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
      playlistId: json['playlistId'] as String?,
      playlistTitle: json['playlistTitle'] as String?,
      randomSong: json['randomSong'] as bool? ?? true,
      volume: json['volume'] as int? ?? 80,
      fadeDurationSeconds: json['fadeDurationSeconds'] as int? ?? 30,
      snoozeMinutes: json['snoozeMinutes'] as int? ?? 10,
      enabled: json['enabled'] as bool? ?? true,
      label: json['label'] as String?,
    );
  }

  MusicAlarm copyWith({
    String? id,
    int? hour,
    int? minute,
    List<int>? daysOfWeek,
    String? playlistId,
    String? playlistTitle,
    bool? randomSong,
    int? volume,
    int? fadeDurationSeconds,
    int? snoozeMinutes,
    bool? enabled,
    String? label,
  }) {
    return MusicAlarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      playlistId: playlistId ?? this.playlistId,
      playlistTitle: playlistTitle ?? this.playlistTitle,
      randomSong: randomSong ?? this.randomSong,
      volume: volume ?? this.volume,
      fadeDurationSeconds: fadeDurationSeconds ?? this.fadeDurationSeconds,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
    );
  }
}

/// Controller responsible for smooth volume ramping and audio fade-in.
class VolumeRampController {
  Timer? _timer;
  bool _isRamping = false;
  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();

  bool get isRamping => _isRamping;
  Stream<double> get volumeStream => _volumeController.stream;

  /// Pure mathematical evaluation of the ramping curve at normalized [progress] (0.0 to 1.0).
  static double calculateRampedVolume({
    required double progress,
    required double targetVolume,
    double startVolume = 0.0,
    VolumeRampCurve curve = VolumeRampCurve.sCurve,
  }) {
    final t = progress.clamp(0.0, 1.0);
    final normTarget = targetVolume > 1.0 ? (targetVolume / 100.0) : targetVolume;
    final normStart = startVolume > 1.0 ? (startVolume / 100.0) : startVolume;

    double factor;
    switch (curve) {
      case VolumeRampCurve.linear:
        factor = t;
        break;
      case VolumeRampCurve.sCurve:
        // Smoothstep: 3t^2 - 2t^3
        factor = t * t * (3.0 - 2.0 * t);
        break;
    }

    return normStart + (normTarget - normStart) * factor;
  }

  /// Starts periodic volume ramping over [duration], emitting values to [volumeStream].
  Stream<double> startRamp({
    required Duration duration,
    required double targetVolume,
    double startVolume = 0.0,
    VolumeRampCurve curve = VolumeRampCurve.sCurve,
    Duration stepInterval = const Duration(milliseconds: 100),
  }) {
    stop();

    final normTarget = targetVolume > 1.0 ? (targetVolume / 100.0) : targetVolume;
    final normStart = startVolume > 1.0 ? (startVolume / 100.0) : startVolume;

    _isRamping = true;

    scheduleMicrotask(() {
      if (!_volumeController.isClosed && _isRamping) {
        _volumeController.add(normStart);
      }
    });

    if (duration.inMilliseconds <= 0) {
      scheduleMicrotask(() {
        if (!_volumeController.isClosed) {
          _volumeController.add(normTarget);
        }
      });
      _isRamping = false;
      return _volumeController.stream;
    }

    final totalSteps = math.max(1, duration.inMilliseconds ~/ stepInterval.inMilliseconds);
    int currentStep = 0;

    _timer = Timer.periodic(stepInterval, (timer) {
      currentStep++;
      final progress = (currentStep / totalSteps).clamp(0.0, 1.0);
      final currentVol = calculateRampedVolume(
        progress: progress,
        targetVolume: normTarget,
        startVolume: normStart,
        curve: curve,
      );

      _volumeController.add(currentVol);

      if (progress >= 1.0 || currentStep >= totalSteps) {
        stop();
      }
    });

    return _volumeController.stream;
  }

  void stop() {
    _isRamping = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _volumeController.close();
  }
}

enum AlarmState {
  idle,
  scheduled,
  ringing,
  snoozed,
}

/// Music Alarm Clock and Scheduler service.
/// Reverse-engineered from Metrolist (MusicAlarmScheduler.kt, MusicAlarmStore.kt).
class MusicAlarmService {
  final List<MusicAlarm> _alarms = [];
  AlarmState _state = AlarmState.idle;
  MusicAlarm? _activeAlarm;
  DateTime? _nextTriggerTime;
  double _currentVolume = 0.0;

  final StreamController<AlarmState> _stateController =
      StreamController<AlarmState>.broadcast();
  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();

  final VolumeRampController _rampController = VolumeRampController();
  StreamSubscription<double>? _rampSubscription;
  Timer? _alarmSchedulerTimer;
  Timer? _snoozeTimer;

  // External audio playback and volume delegates
  final Future<void> Function(MusicAlarm alarm)? onTriggerAudio;
  final Future<void> Function(double volume)? onSetVolume;
  final Future<void> Function()? onStopAudio;

  MusicAlarmService({
    this.onTriggerAudio,
    this.onSetVolume,
    this.onStopAudio,
    List<MusicAlarm>? initialAlarms,
  }) {
    if (initialAlarms != null) {
      _alarms.addAll(initialAlarms);
      scheduleNextOccurrence();
    }
  }

  AlarmState get state => _state;
  Stream<AlarmState> get stateStream => _stateController.stream;
  double get currentVolume => _currentVolume;
  Stream<double> get volumeStream => _volumeController.stream;
  MusicAlarm? get activeAlarm => _activeAlarm;
  DateTime? get nextTriggerTime => _nextTriggerTime;
  List<MusicAlarm> get alarms => List.unmodifiable(_alarms);

  void _setState(AlarmState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  void _setVolumeInternal(double vol) {
    _currentVolume = vol;
    if (!_volumeController.isClosed) {
      _volumeController.add(vol);
    }
    onSetVolume?.call(vol);
  }

  /// Calculates the next occurrence of an alarm given [hour], [minute], and optional [daysOfWeek].
  ///
  /// - If [daysOfWeek] is null or empty, treats as a one-time alarm (today if future, else tomorrow).
  /// - If [daysOfWeek] contains days (1=Mon ... 7=Sun), finds the next matching day strictly in the future.
  static DateTime calculateNextTrigger(
    int hour,
    int minute, [
    List<int>? daysOfWeek,
    DateTime? fromTime,
  ]) {
    final from = fromTime ?? DateTime.now();
    final cleanDays = daysOfWeek?.where((d) => d >= 1 && d <= 7).toSet() ?? <int>{};

    // Case 1: One-time alarm
    if (cleanDays.isEmpty) {
      final candidateToday = DateTime(from.year, from.month, from.day, hour, minute);
      if (candidateToday.isAfter(from)) {
        return candidateToday;
      } else {
        return candidateToday.add(const Duration(days: 1));
      }
    }

    // Case 2: Recurring days of week (1=Monday ... 7=Sunday)
    for (int offset = 0; offset <= 7; offset++) {
      final candidate = DateTime(
        from.year,
        from.month,
        from.day + offset,
        hour,
        minute,
      );

      if (cleanDays.contains(candidate.weekday)) {
        if (offset == 0) {
          if (candidate.isAfter(from)) {
            return candidate;
          }
        } else {
          return candidate;
        }
      }
    }

    // Fallback exactly one week ahead
    return DateTime(from.year, from.month, from.day + 7, hour, minute);
  }

  /// Adds a new alarm and recalculates scheduling.
  void addAlarm(MusicAlarm alarm) {
    _alarms.removeWhere((a) => a.id == alarm.id);
    _alarms.add(alarm);
    scheduleNextOccurrence();
  }

  /// Removes an alarm by id.
  void removeAlarm(String id) {
    _alarms.removeWhere((a) => a.id == id);
    if (_activeAlarm?.id == id) {
      dismiss();
    } else {
      scheduleNextOccurrence();
    }
  }

  /// Updates an existing alarm.
  void updateAlarm(MusicAlarm alarm) {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index >= 0) {
      _alarms[index] = alarm;
      scheduleNextOccurrence();
    } else {
      addAlarm(alarm);
    }
  }

  /// Toggles an alarm on or off.
  void toggleAlarm(String id, bool enabled) {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _alarms[index] = _alarms[index].copyWith(enabled: enabled);
      scheduleNextOccurrence();
    }
  }

  MusicAlarm? getAlarmById(String id) {
    try {
      return _alarms.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Evaluates all enabled alarms and schedules the earliest upcoming occurrence.
  void scheduleNextOccurrence([DateTime? fromTime]) {
    _alarmSchedulerTimer?.cancel();
    _alarmSchedulerTimer = null;

    final now = fromTime ?? DateTime.now();
    final enabledAlarms = _alarms.where((a) => a.enabled).toList();

    if (enabledAlarms.isEmpty) {
      _nextTriggerTime = null;
      if (_state == AlarmState.scheduled) {
        _setState(AlarmState.idle);
      }
      return;
    }

    MusicAlarm? earliestAlarm;
    DateTime? earliestTrigger;

    for (final alarm in enabledAlarms) {
      final trigger = alarm.calculateNextTrigger(now);
      if (earliestTrigger == null || trigger.isBefore(earliestTrigger)) {
        earliestTrigger = trigger;
        earliestAlarm = alarm;
      }
    }

    if (earliestAlarm != null && earliestTrigger != null) {
      _nextTriggerTime = earliestTrigger;
      _setState(AlarmState.scheduled);

      final delay = earliestTrigger.difference(now);
      if (delay.isNegative || delay.inMilliseconds == 0) {
        triggerAlarm(earliestAlarm);
      } else {
        _alarmSchedulerTimer = Timer(delay, () {
          triggerAlarm(earliestAlarm!);
        });
      }
    }
  }

  /// Triggers alarm ringing with smooth volume ramping.
  Future<void> triggerAlarm(MusicAlarm alarm) async {
    _alarmSchedulerTimer?.cancel();
    _snoozeTimer?.cancel();
    _rampSubscription?.cancel();

    _activeAlarm = alarm;
    _setState(AlarmState.ringing);

    // Initial audio setup at 0.0 volume
    _setVolumeInternal(0.0);
    if (onTriggerAudio != null) {
      await onTriggerAudio!(alarm);
    }

    // Begin smooth volume ramping (linear or S-curve over fadeDurationSeconds)
    final fadeDuration = Duration(seconds: alarm.fadeDurationSeconds);
    final targetVolume = alarm.volume / 100.0;

    _rampSubscription = _rampController
        .startRamp(
          duration: fadeDuration,
          targetVolume: targetVolume,
          startVolume: 0.0,
          curve: VolumeRampCurve.sCurve,
          stepInterval: const Duration(milliseconds: 100),
        )
        .listen((vol) {
      _setVolumeInternal(vol);
    });
  }

  /// Snoozes the currently ringing alarm for [customMinutes] or the alarm's default snooze duration.
  Future<void> snooze([int? customMinutes]) async {
    if (_state != AlarmState.ringing && _state != AlarmState.snoozed) {
      return;
    }

    _rampController.stop();
    _rampSubscription?.cancel();
    _snoozeTimer?.cancel();

    if (onStopAudio != null) {
      await onStopAudio!();
    }

    final minutes = customMinutes ?? _activeAlarm?.snoozeMinutes ?? 10;
    final now = DateTime.now();
    _nextTriggerTime = now.add(Duration(minutes: minutes));
    _setState(AlarmState.snoozed);

    _snoozeTimer = Timer(Duration(minutes: minutes), () {
      if (_activeAlarm != null) {
        triggerAlarm(_activeAlarm!);
      }
    });
  }

  /// Dismisses the alarm, stops volume ramping, and updates recurring/one-time states.
  Future<void> dismiss() async {
    _rampController.stop();
    _rampSubscription?.cancel();
    _snoozeTimer?.cancel();
    _alarmSchedulerTimer?.cancel();

    if (onStopAudio != null) {
      await onStopAudio!();
    }

    if (_activeAlarm != null) {
      // If it was a one-time alarm, disable it automatically
      if (!_activeAlarm!.isRecurring) {
        final index = _alarms.indexWhere((a) => a.id == _activeAlarm!.id);
        if (index >= 0) {
          _alarms[index] = _alarms[index].copyWith(enabled: false);
        }
      }
    }

    _activeAlarm = null;
    _setVolumeInternal(0.0);
    _setState(AlarmState.idle);

    // Schedule next upcoming enabled alarm
    scheduleNextOccurrence();
  }

  void dispose() {
    _alarmSchedulerTimer?.cancel();
    _snoozeTimer?.cancel();
    _rampSubscription?.cancel();
    _rampController.dispose();
    _stateController.close();
    _volumeController.close();
  }
}
