// ============================================================================
// Unit & Widget Tests: Linux Single Instance UNIX Socket Guard
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/desktop/single_instance_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SingleInstanceAction inference', () {
    test('infers focus action on empty args', () {
      expect(SingleInstanceAction.inferFromArgs([]), SingleInstanceAction.focus);
    });

    test('infers focus action on explicit flags', () {
      expect(
        SingleInstanceAction.inferFromArgs(['--focus']),
        SingleInstanceAction.focus,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['-f']),
        SingleInstanceAction.focus,
      );
    });

    test('infers playPause action on playback flags', () {
      expect(
        SingleInstanceAction.inferFromArgs(['--play-pause']),
        SingleInstanceAction.playPause,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['-p']),
        SingleInstanceAction.playPause,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['--toggle-play']),
        SingleInstanceAction.playPause,
      );
    });

    test('infers next, previous, and stop actions', () {
      expect(
        SingleInstanceAction.inferFromArgs(['--next']),
        SingleInstanceAction.next,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['-n']),
        SingleInstanceAction.next,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['--prev']),
        SingleInstanceAction.previous,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['--previous']),
        SingleInstanceAction.previous,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['-b']),
        SingleInstanceAction.previous,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['--stop']),
        SingleInstanceAction.stop,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['-s']),
        SingleInstanceAction.stop,
      );
    });

    test('infers ping action on ping flag', () {
      expect(
        SingleInstanceAction.inferFromArgs(['--ping']),
        SingleInstanceAction.ping,
      );
    });

    test('infers open action on URLs and media files', () {
      expect(
        SingleInstanceAction.inferFromArgs(['https://example.com/audio/song.mp3']),
        SingleInstanceAction.open,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['/home/user/Music/track.flac']),
        SingleInstanceAction.open,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['album.m3u8']),
        SingleInstanceAction.open,
      );
      expect(
        SingleInstanceAction.inferFromArgs(['song.opus']),
        SingleInstanceAction.open,
      );
    });

    test('infers custom action on unclassified arguments', () {
      expect(
        SingleInstanceAction.inferFromArgs(['--unknown-flag', 'value']),
        SingleInstanceAction.custom,
      );
    });
  });

  group('SingleInstanceMessage & Response models', () {
    test('SingleInstanceMessage serializes and deserializes cleanly', () {
      final now = DateTime.now();
      final original = SingleInstanceMessage(
        id: 'msg_123',
        action: SingleInstanceAction.playPause,
        args: const ['--play-pause'],
        workingDirectory: '/home/user',
        senderPid: 4242,
        timestamp: now,
        metadata: const {'user': 'tester'},
      );

      final json = original.toJson();
      final reconstructed = SingleInstanceMessage.fromJson(json);

      expect(reconstructed.id, original.id);
      expect(reconstructed.action, original.action);
      expect(reconstructed.args, original.args);
      expect(reconstructed.workingDirectory, original.workingDirectory);
      expect(reconstructed.senderPid, original.senderPid);
      expect(reconstructed.metadata['user'], 'tester');
    });

    test('SingleInstanceMessage.fromCommandLine parses arguments properly', () {
      final msg = SingleInstanceMessage.fromCommandLine(
        ['--next'],
        workingDir: '/tmp',
        pid: 9999,
      );

      expect(msg.action, SingleInstanceAction.next);
      expect(msg.args, ['--next']);
      expect(msg.workingDirectory, '/tmp');
      expect(msg.senderPid, 9999);
      expect(msg.id, startsWith('msg_'));
    });

    test('SingleInstanceResponse serializes and deserializes correctly', () {
      const original = SingleInstanceResponse(
        success: true,
        message: 'All good',
        receiverPid: 1234,
        handledAction: SingleInstanceAction.focus,
        timestamp: _StaticTestDateTime(),
        data: {'count': 1},
      );

      final json = original.toJson();
      final parsed = SingleInstanceResponse.fromJson(json);

      expect(parsed.success, isTrue);
      expect(parsed.message, 'All good');
      expect(parsed.receiverPid, 1234);
      expect(parsed.handledAction, SingleInstanceAction.focus);
      expect(parsed.data['count'], 1);
    });
  });

  group('Socket Path Resolution', () {
    test('resolves default socket path from USER environment variable', () {
      final path = SingleInstanceGuard.resolveDefaultSocketPath(
        env: {'USER': 'musicfan'},
      );
      expect(path, '/tmp/softify-musicfan.sock');
    });

    test('falls back to LOGNAME or USERNAME if USER is missing', () {
      final pathLogname = SingleInstanceGuard.resolveDefaultSocketPath(
        env: {'LOGNAME': 'desktop_user'},
      );
      expect(pathLogname, '/tmp/softify-desktop_user.sock');

      final pathUsername = SingleInstanceGuard.resolveDefaultSocketPath(
        env: {'USERNAME': 'winuser'},
      );
      expect(pathUsername, '/tmp/softify-winuser.sock');
    });

    test('sanitizes special characters in username', () {
      final path = SingleInstanceGuard.resolveDefaultSocketPath(
        env: {'USER': 'jane.doe/admin:123@home'},
      );
      expect(path, '/tmp/softify-jane_doe_admin_123_home.sock');
    });

    test('falls back to user if all environment entries are empty', () {
      final path = SingleInstanceGuard.resolveDefaultSocketPath(
        env: {},
      );
      expect(path, '/tmp/softify-user.sock');
    });
  });

  group('SingleInstanceGuard Service Lifecycle', () {
    late String testSocketPath;

    setUp(() {
      testSocketPath =
          '/tmp/test_softify_${DateTime.now().microsecondsSinceEpoch}.sock';
    });

    tearDown(() {
      final f = File(testSocketPath);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    });

    test('binds as primary instance when no server is listening', () async {
      final guard = SingleInstanceGuard(
        config: SingleInstanceConfig(
          socketPath: testSocketPath,
          isSupportedPlatformOverride: true,
        ),
      );

      final result = await guard.initialize(args: ['--test']);

      expect(result.isPrimary, isTrue);
      expect(result.status, SingleInstanceStatus.primary);
      expect(guard.isPrimary, isTrue);
      expect(guard.state.socketPath, testSocketPath);
      expect(File(testSocketPath).existsSync(), isTrue);

      await guard.stop();
      expect(guard.state.status, SingleInstanceStatus.stopped);
      expect(File(testSocketPath).existsSync(), isFalse);
      await guard.dispose();
    });

    test('secondary instance forwards arguments and calls exitHandler', () async {
      final primaryGuard = SingleInstanceGuard(
        config: SingleInstanceConfig(
          socketPath: testSocketPath,
          isSupportedPlatformOverride: true,
        ),
      );

      final primaryResult = await primaryGuard.initialize();
      expect(primaryResult.isPrimary, isTrue);

      // Listen for forwarded message on primary instance
      final messageCompleter = Completer<SingleInstanceMessage>();
      final sub = primaryGuard.onMessage.listen((msg) {
        if (!messageCompleter.isCompleted) {
          messageCompleter.complete(msg);
        }
      });

      // Prepare secondary instance with custom exitHandler
      int? recordedExitCode;
      final secondaryGuard = SingleInstanceGuard(
        config: SingleInstanceConfig(
          socketPath: testSocketPath,
          isSupportedPlatformOverride: true,
          autoExitSecondary: true,
          exitHandler: (code) {
            recordedExitCode = code;
          },
        ),
      );

      final secondaryResult = await secondaryGuard.initialize(
        args: ['--play-pause', 'https://example.com/stream.mp3'],
      );

      expect(secondaryResult.isPrimary, isFalse);
      expect(secondaryResult.forwardedSuccessfully, isTrue);
      expect(secondaryGuard.state.status, SingleInstanceStatus.secondaryExited);
      expect(recordedExitCode, 0);

      // Verify primary received the forwarded arguments
      final receivedMsg = await messageCompleter.future.timeout(
        const Duration(seconds: 2),
      );

      expect(receivedMsg.args, ['--play-pause', 'https://example.com/stream.mp3']);
      expect(receivedMsg.action, SingleInstanceAction.playPause);
      expect(primaryGuard.state.receivedMessagesCount, 1);

      await sub.cancel();
      await secondaryGuard.dispose();
      await primaryGuard.dispose();
    });

    test('recovers from stale socket file and binds as primary', () async {
      // Create a stale dummy socket file that is not being listened to
      final staleFile = File(testSocketPath);
      staleFile.writeAsStringSync('stale_dummy_contents');
      expect(staleFile.existsSync(), isTrue);

      final guard = SingleInstanceGuard(
        config: SingleInstanceConfig(
          socketPath: testSocketPath,
          isSupportedPlatformOverride: true,
          autoCleanStaleSocket: true,
        ),
      );

      final result = await guard.initialize();

      expect(result.isPrimary, isTrue);
      expect(result.status, SingleInstanceStatus.primary);
      expect(guard.isPrimary, isTrue);

      await guard.dispose();
    });

    test('responds to IPC ping command from another client', () async {
      final primaryGuard = SingleInstanceGuard(
        config: SingleInstanceConfig(
          socketPath: testSocketPath,
          isSupportedPlatformOverride: true,
        ),
      );

      await primaryGuard.initialize();

      // Send ping probe
      final secondaryGuard = SingleInstanceGuard(
        config: SingleInstanceConfig(
          socketPath: testSocketPath,
          isSupportedPlatformOverride: true,
        ),
      );

      final pingResponse = await secondaryGuard.sendPing(
        socketPath: testSocketPath,
      );

      expect(pingResponse.success, isTrue);
      expect(pingResponse.receiverPid, isNotNull);

      await secondaryGuard.dispose();
      await primaryGuard.dispose();
    });
  });

  group('Riverpod Providers & SingleInstanceNotifier', () {
    late String testSocketPath;

    setUp(() {
      testSocketPath =
          '/tmp/test_riverpod_${DateTime.now().microsecondsSinceEpoch}.sock';
    });

    tearDown(() {
      final f = File(testSocketPath);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    });

    test('singleInstanceStateProvider updates correctly when primary starts',
        () async {
      final guard = SingleInstanceGuard(
        config: SingleInstanceConfig(
          socketPath: testSocketPath,
          isSupportedPlatformOverride: true,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          singleInstanceGuardProvider.overrideWithValue(guard),
        ],
      );

      try {
        expect(
          container.read(singleInstanceStateProvider).status,
          SingleInstanceStatus.idle,
        );

        final notifier = container.read(singleInstanceStateProvider.notifier);
        final result = await notifier.initialize();

        expect(result.isPrimary, isTrue);
        expect(
          container.read(singleInstanceStateProvider).status,
          SingleInstanceStatus.primary,
        );
        expect(container.read(isSingleInstancePrimaryProvider), isTrue);

        await notifier.stop();
        expect(
          container.read(singleInstanceStateProvider).status,
          SingleInstanceStatus.stopped,
        );
      } finally {
        await guard.dispose();
        container.dispose();
      }
    });
  });

  group('SingleInstance UI Widgets', () {
    testWidgets('SingleInstanceStatusCard displays status and socket path',
        (tester) async {
      final guard = SingleInstanceGuard(
        config: const SingleInstanceConfig(
          socketPath: '/tmp/softify-testuser.sock',
          isSupportedPlatformOverride: true,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          singleInstanceGuardProvider.overrideWithValue(guard),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleInstanceStatusCard(),
            ),
          ),
        ),
      );

      expect(find.text('Linux Single Instance Guard'), findsOneWidget);
      expect(
        find.text('UNIX domain socket command forwarder'),
        findsOneWidget,
      );
      expect(find.text('Clean Socket'), findsOneWidget);
      expect(find.text('Ping IPC'), findsOneWidget);

      container.dispose();
    });

    testWidgets('SingleInstanceGuardListener renders child properly',
        (tester) async {
      final guard = SingleInstanceGuard(
        config: const SingleInstanceConfig(
          isSupportedPlatformOverride: true,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          singleInstanceGuardProvider.overrideWithValue(guard),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleInstanceGuardListener(
                child: Text('Main Desktop Application Body'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Main Desktop Application Body'), findsOneWidget);

      container.dispose();
    });
  });
}

class _StaticTestDateTime implements DateTime {
  const _StaticTestDateTime();

  DateTime get _real => DateTime(2026, 11, 12, 12, 0, 0);

  @override
  bool isAfter(DateTime other) => _real.isAfter(other);
  @override
  bool isBefore(DateTime other) => _real.isBefore(other);
  @override
  bool isAtSameMomentAs(DateTime other) => _real.isAtSameMomentAs(other);
  @override
  int compareTo(DateTime other) => _real.compareTo(other);
  @override
  int get millisecondsSinceEpoch => _real.millisecondsSinceEpoch;
  @override
  int get microsecondsSinceEpoch => _real.microsecondsSinceEpoch;
  @override
  String get timeZoneName => _real.timeZoneName;
  @override
  Duration get timeZoneOffset => _real.timeZoneOffset;
  @override
  DateTime add(Duration duration) => _real.add(duration);
  @override
  DateTime subtract(Duration duration) => _real.subtract(duration);
  @override
  Duration difference(DateTime other) => _real.difference(other);
  @override
  String toIso8601String() => _real.toIso8601String();
  @override
  DateTime toLocal() => _real.toLocal();
  @override
  DateTime toUtc() => _real.toUtc();
  @override
  int get year => _real.year;
  @override
  int get month => _real.month;
  @override
  int get day => _real.day;
  @override
  int get hour => _real.hour;
  @override
  int get minute => _real.minute;
  @override
  int get second => _real.second;
  @override
  int get millisecond => _real.millisecond;
  @override
  int get microsecond => _real.microsecond;
  @override
  int get weekday => _real.weekday;
  @override
  bool get isUtc => _real.isUtc;
}
