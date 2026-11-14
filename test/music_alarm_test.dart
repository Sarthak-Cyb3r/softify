import 'package:flutter_test/flutter_test.dart';
import 'package:softify/services/alarm/music_alarm_service.dart';

void main() {
  group('MusicAlarm Model & JSON Serialization', () {
    test('serializes to and from JSON faithfully matching Metrolist MusicAlarmEntry schema', () {
      const alarm = MusicAlarm(
        id: 'alarm_101',
        hour: 7,
        minute: 45,
        daysOfWeek: [AlarmDay.monday, AlarmDay.wednesday, AlarmDay.friday],
        playlistId: 'playlist_chill_vibes',
        playlistTitle: 'Morning Coffee Acoustic',
        randomSong: true,
        volume: 85,
        fadeDurationSeconds: 45,
        snoozeMinutes: 9,
        enabled: true,
        label: 'Gym Morning',
      );

      final json = alarm.toJson();
      expect(json['id'], equals('alarm_101'));
      expect(json['hour'], equals(7));
      expect(json['minute'], equals(45));
      expect(json['daysOfWeek'], equals([1, 3, 5]));
      expect(json['playlistId'], equals('playlist_chill_vibes'));
      expect(json['volume'], equals(85));
      expect(json['fadeDurationSeconds'], equals(45));
      expect(json['snoozeMinutes'], equals(9));
      expect(json['enabled'], isTrue);
      expect(json['label'], equals('Gym Morning'));

      final reconstructed = MusicAlarm.fromJson(json);
      expect(reconstructed.id, equals(alarm.id));
      expect(reconstructed.hour, equals(alarm.hour));
      expect(reconstructed.minute, equals(alarm.minute));
      expect(reconstructed.daysOfWeek, equals([1, 3, 5]));
      expect(reconstructed.playlistTitle, equals(alarm.playlistTitle));
      expect(reconstructed.volume, equals(alarm.volume));
      expect(reconstructed.fadeDurationSeconds, equals(alarm.fadeDurationSeconds));
      expect(reconstructed.snoozeMinutes, equals(alarm.snoozeMinutes));
      expect(reconstructed.enabled, equals(alarm.enabled));
      expect(reconstructed.label, equals(alarm.label));
      expect(reconstructed.isRecurring, isTrue);
      expect(reconstructed.formattedTime, equals('07:45'));
    });

    test('copyWith updates fields without mutating unchanged values', () {
      const original = MusicAlarm(
        id: 'alarm_copy',
        hour: 6,
        minute: 30,
        volume: 70,
      );

      final updated = original.copyWith(
        hour: 8,
        volume: 90,
        enabled: false,
      );

      expect(updated.id, equals('alarm_copy'));
      expect(updated.hour, equals(8));
      expect(updated.minute, equals(60 - 30));
      expect(updated.volume, equals(90));
      expect(updated.enabled, isFalse);
    });
  });

  group('calculateNextTrigger Precision Scheduling', () {
    test('schedules same-day future alarm correctly when alarm time is ahead of fromTime', () {
      // 2026-10-27 at 06:15:00
      final fromTime = DateTime(2026, 10, 27, 6, 15, 0);

      // Alarm set for 08:30 (one-time, no days specified)
      final trigger = MusicAlarmService.calculateNextTrigger(8, 30, null, fromTime);

      expect(trigger.year, equals(2026));
      expect(trigger.month, equals(10));
      expect(trigger.day, equals(27)); // Today
      expect(trigger.hour, equals(8));
      expect(trigger.minute, equals(30));
    });

    test('schedules next-day alarm when alarm time has already passed today', () {
      // 2026-10-27 at 10:45:00
      final fromTime = DateTime(2026, 10, 27, 10, 45, 0);

      // Alarm set for 07:00 (already passed today)
      final trigger = MusicAlarmService.calculateNextTrigger(7, 0, null, fromTime);

      expect(trigger.year, equals(2026));
      expect(trigger.month, equals(10));
      expect(trigger.day, equals(28)); // Tomorrow
      expect(trigger.hour, equals(7));
      expect(trigger.minute, equals(0));
    });

    test('schedules correctly for recurring weekdays', () {
      // Monday 2026-10-26 at 06:00:00 (Weekday 1)
      final mondayEarly = DateTime(2026, 10, 26, 6, 0, 0);
      const weekdays = AlarmDay.weekdays; // [1, 2, 3, 4, 5]

      // Early Monday before 07:30 -> Should trigger Monday 07:30
      final triggerMon = MusicAlarmService.calculateNextTrigger(7, 30, weekdays, mondayEarly);
      expect(triggerMon.weekday, equals(DateTime.monday));
      expect(triggerMon.day, equals(26));
      expect(triggerMon.hour, equals(7));
      expect(triggerMon.minute, equals(30));

      // Late Monday after 07:30 -> Should trigger Tuesday 07:30
      final mondayLate = DateTime(2026, 10, 26, 9, 0, 0);
      final triggerTue = MusicAlarmService.calculateNextTrigger(7, 30, weekdays, mondayLate);
      expect(triggerTue.weekday, equals(DateTime.tuesday));
      expect(triggerTue.day, equals(27));
      expect(triggerTue.hour, equals(7));
      expect(triggerTue.minute, equals(30));

      // Friday afternoon after 07:30 (2026-10-30 14:00) -> Should skip weekend and trigger Monday 07:30 (2026-11-02)
      final fridayLate = DateTime(2026, 10, 30, 14, 0, 0);
      final triggerNextMon = MusicAlarmService.calculateNextTrigger(7, 30, weekdays, fridayLate);
      expect(triggerNextMon.weekday, equals(DateTime.monday));
      expect(triggerNextMon.month, equals(11));
      expect(triggerNextMon.day, equals(2));
      expect(triggerNextMon.hour, equals(7));
      expect(triggerNextMon.minute, equals(30));
    });

    test('schedules correctly for recurring weekends', () {
      // Wednesday 2026-10-28 12:00 -> Weekends are [6, 7] (Sat, Sun)
      final wednesday = DateTime(2026, 10, 28, 12, 0, 0);
      const weekends = AlarmDay.weekends;

      final triggerSat = MusicAlarmService.calculateNextTrigger(9, 0, weekends, wednesday);
      expect(triggerSat.weekday, equals(DateTime.saturday));
      expect(triggerSat.day, equals(31)); // 2026-10-31 is Saturday
      expect(triggerSat.hour, equals(9));
      expect(triggerSat.minute, equals(0));
    });
  });

  group('Volume Ramping Mathematics & Controller', () {
    test('linear ramping produces proportional volume progression', () {
      // Start 0.0, Target 80% (0.8)
      expect(
        VolumeRampController.calculateRampedVolume(
          progress: 0.0,
          targetVolume: 80,
          curve: VolumeRampCurve.linear,
        ),
        closeTo(0.0, 0.001),
      );

      expect(
        VolumeRampController.calculateRampedVolume(
          progress: 0.5,
          targetVolume: 80,
          curve: VolumeRampCurve.linear,
        ),
        closeTo(0.40, 0.001),
      );

      expect(
        VolumeRampController.calculateRampedVolume(
          progress: 1.0,
          targetVolume: 80,
          curve: VolumeRampCurve.linear,
        ),
        closeTo(0.80, 0.001),
      );
    });

    test('S-curve (smoothstep) ramping provides gentle wake-up curve', () {
      // At t=0.0 -> 0.0
      expect(
        VolumeRampController.calculateRampedVolume(
          progress: 0.0,
          targetVolume: 100,
          curve: VolumeRampCurve.sCurve,
        ),
        closeTo(0.0, 0.001),
      );

      // At t=0.2 -> S-curve gives 0.2^2 * (3 - 2*0.2) = 0.04 * 2.6 = 0.104
      // Slower, gentler ramp-in than linear 0.2
      final sAt20 = VolumeRampController.calculateRampedVolume(
        progress: 0.2,
        targetVolume: 100,
        curve: VolumeRampCurve.sCurve,
      );
      expect(sAt20, closeTo(0.104, 0.001));
      expect(sAt20, lessThan(0.20));

      // At t=0.5 -> exactly midpoint 0.50
      expect(
        VolumeRampController.calculateRampedVolume(
          progress: 0.5,
          targetVolume: 100,
          curve: VolumeRampCurve.sCurve,
        ),
        closeTo(0.50, 0.001),
      );

      // At t=0.8 -> S-curve gives 0.8^2 * (3 - 2*0.8) = 0.64 * 1.4 = 0.896
      // Soft arrival at top
      final sAt80 = VolumeRampController.calculateRampedVolume(
        progress: 0.8,
        targetVolume: 100,
        curve: VolumeRampCurve.sCurve,
      );
      expect(sAt80, closeTo(0.896, 0.001));
      expect(sAt80, greaterThan(0.80));

      // At t=1.0 -> exactly target 1.0
      expect(
        VolumeRampController.calculateRampedVolume(
          progress: 1.0,
          targetVolume: 100,
          curve: VolumeRampCurve.sCurve,
        ),
        closeTo(1.0, 0.001),
      );
    });

    test('clamping guards against out-of-range progress values', () {
      expect(
        VolumeRampController.calculateRampedVolume(
          progress: -0.5,
          targetVolume: 50,
        ),
        closeTo(0.0, 0.001),
      );

      expect(
        VolumeRampController.calculateRampedVolume(
          progress: 1.5,
          targetVolume: 50,
        ),
        closeTo(0.50, 0.001),
      );
    });

    test('VolumeRampController executes step-by-step ramp smoothly', () async {
      final controller = VolumeRampController();
      final recordedVolumes = <double>[];

      final stream = controller.startRamp(
        duration: const Duration(milliseconds: 100),
        targetVolume: 100,
        curve: VolumeRampCurve.linear,
        stepInterval: const Duration(milliseconds: 25),
      );

      stream.listen(recordedVolumes.add);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(recordedVolumes.isNotEmpty, isTrue);
      expect(recordedVolumes.first, closeTo(0.0, 0.01));
      expect(recordedVolumes.last, closeTo(1.0, 0.01));

      controller.dispose();
    });
  });

  group('MusicAlarmService Full Lifecycle', () {
    late MusicAlarmService service;
    MusicAlarm? triggeredAlarm;
    final volumeUpdates = <double>[];
    bool audioStopped = false;

    setUp(() {
      triggeredAlarm = null;
      volumeUpdates.clear();
      audioStopped = false;

      service = MusicAlarmService(
        onTriggerAudio: (alarm) async {
          triggeredAlarm = alarm;
        },
        onSetVolume: (vol) async {
          volumeUpdates.add(vol);
        },
        onStopAudio: () async {
          audioStopped = true;
        },
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('triggerAlarm rings and starts gentle volume ramping', () async {
      const testAlarm = MusicAlarm(
        id: 'test_lifecycle',
        hour: 8,
        minute: 0,
        volume: 80,
        fadeDurationSeconds: 1, // 1 sec for fast test
      );

      await service.triggerAlarm(testAlarm);

      expect(service.state, equals(AlarmState.ringing));
      expect(service.activeAlarm?.id, equals('test_lifecycle'));
      expect(triggeredAlarm?.id, equals('test_lifecycle'));
      expect(service.currentVolume, closeTo(0.0, 0.01));

      // Wait a fraction of the fade duration
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(volumeUpdates.isNotEmpty, isTrue);
      expect(service.currentVolume, greaterThan(0.0));
    });

    test('snooze pauses audio and updates alarm state', () async {
      const testAlarm = MusicAlarm(
        id: 'test_snooze',
        hour: 8,
        minute: 0,
        snoozeMinutes: 5,
      );

      await service.triggerAlarm(testAlarm);
      expect(service.state, equals(AlarmState.ringing));

      await service.snooze(7); // Custom 7 mins
      expect(service.state, equals(AlarmState.snoozed));
      expect(audioStopped, isTrue);
      expect(service.nextTriggerTime, isNotNull);
      expect(
        service.nextTriggerTime!.difference(DateTime.now()).inMinutes,
        inInclusiveRange(6, 7),
      );
    });

    test('dismiss stops audio, resets volume, and disables one-time alarms', () async {
      const oneTimeAlarm = MusicAlarm(
        id: 'one_time',
        hour: 9,
        minute: 0,
        daysOfWeek: [], // One-off
        enabled: true,
      );

      service.addAlarm(oneTimeAlarm);
      await service.triggerAlarm(oneTimeAlarm);
      expect(service.state, equals(AlarmState.ringing));

      await service.dismiss();
      expect(service.state, equals(AlarmState.idle));
      expect(audioStopped, isTrue);
      expect(service.currentVolume, equals(0.0));
      expect(service.activeAlarm, isNull);

      // Verify one-time alarm was automatically disabled
      final updated = service.getAlarmById('one_time');
      expect(updated?.enabled, isFalse);
    });
  });
}
