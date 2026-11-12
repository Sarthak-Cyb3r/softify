// ============================================================================
// Unit & Widget Tests: Desktop CLI Playback Controller Interface (Feature 35)
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/desktop/softify_cli_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test sample track
  const sampleTrack = Track(
    id: 'track-001',
    sourceId: 'src-001',
    title: 'Bohemian Rhapsody',
    artist: 'Queen',
    album: 'A Night at the Opera',
    duration: Duration(minutes: 5, seconds: 55),
  );

  group('CliCommandParser Tokenizer', () {
    test('splits basic whitespace-separated arguments', () {
      final tokens = CliCommandParser.tokenize('volume 80 --json');
      expect(tokens, ['volume', '80', '--json']);
    });

    test('handles single and double quoted arguments', () {
      final tokens = CliCommandParser.tokenize("seek '01:30' --format=\"json\"");
      expect(tokens, ['seek', '01:30', '--format="json"']);
    });

    test('handles escaped quotes and extra whitespace', () {
      final tokens = CliCommandParser.tokenize('   play    --pretty   ');
      expect(tokens, ['play', '--pretty']);
    });

    test('returns empty list for empty or whitespace-only input', () {
      expect(CliCommandParser.tokenize(''), isEmpty);
      expect(CliCommandParser.tokenize('   \t\n  '), isEmpty);
    });
  });

  group('CliCommandParser Command Recognition', () {
    test('parses play and aliases (resume, start)', () {
      expect(CliCommandParser.parse('play').type, CliCommandType.play);
      expect(CliCommandParser.parse('resume').type, CliCommandType.play);
      expect(CliCommandParser.parse('start').type, CliCommandType.play);
      expect(CliCommandParser.parse('PLAY').type, CliCommandType.play);
    });

    test('parses pause and aliases (stop)', () {
      expect(CliCommandParser.parse('pause').type, CliCommandType.pause);
      expect(CliCommandParser.parse('stop').type, CliCommandType.pause);
      expect(CliCommandParser.parse('PAUSE').type, CliCommandType.pause);
    });

    test('parses toggle and aliases (playpause, play-pause)', () {
      expect(CliCommandParser.parse('toggle').type, CliCommandType.toggle);
      expect(CliCommandParser.parse('playpause').type, CliCommandType.toggle);
      expect(CliCommandParser.parse('play-pause').type, CliCommandType.toggle);
    });

    test('parses next and aliases (skip, forward)', () {
      expect(CliCommandParser.parse('next').type, CliCommandType.next);
      expect(CliCommandParser.parse('skip').type, CliCommandType.next);
      expect(CliCommandParser.parse('forward').type, CliCommandType.next);
    });

    test('parses prev and aliases (previous, back)', () {
      expect(CliCommandParser.parse('prev').type, CliCommandType.prev);
      expect(CliCommandParser.parse('previous').type, CliCommandType.prev);
      expect(CliCommandParser.parse('back').type, CliCommandType.prev);
    });

    test('parses status and aliases (info, current, now-playing, np)', () {
      expect(CliCommandParser.parse('status').type, CliCommandType.status);
      expect(CliCommandParser.parse('info').type, CliCommandType.status);
      expect(CliCommandParser.parse('current').type, CliCommandType.status);
      expect(CliCommandParser.parse('now-playing').type, CliCommandType.status);
      expect(CliCommandParser.parse('np').type, CliCommandType.status);
    });

    test('parses volume with valid bounds 0-100', () {
      final cmd0 = CliCommandParser.parse('volume 0');
      expect(cmd0.type, CliCommandType.volume);
      expect(cmd0.targetVolume, 0);

      final cmd50 = CliCommandParser.parse('volume 50');
      expect(cmd50.type, CliCommandType.volume);
      expect(cmd50.targetVolume, 50);

      final cmd100 = CliCommandParser.parse('vol 100');
      expect(cmd100.type, CliCommandType.volume);
      expect(cmd100.targetVolume, 100);
    });

    test('parses volume query when no argument provided', () {
      final cmd = CliCommandParser.parse('volume');
      expect(cmd.type, CliCommandType.volume);
      expect(cmd.targetVolume, isNull);
      expect(cmd.relativeVolumeDelta, isNull);
      expect(cmd.hasError, isFalse);
    });

    test('parses relative volume adjustments (+5, -10)', () {
      final cmdPlus = CliCommandParser.parse('volume +5');
      expect(cmdPlus.type, CliCommandType.volume);
      expect(cmdPlus.relativeVolumeDelta, 5);

      final cmdMinus = CliCommandParser.parse('volume -10');
      expect(cmdMinus.type, CliCommandType.volume);
      expect(cmdMinus.relativeVolumeDelta, -10);
    });

    test('flags invalid volume input (< 0, > 100, non-numeric)', () {
      final cmdOver = CliCommandParser.parse('volume 150');
      expect(cmdOver.hasError, isTrue);
      expect(cmdOver.parseError, contains('between 0 and 100'));

      final cmdNaN = CliCommandParser.parse('volume loud');
      expect(cmdNaN.hasError, isTrue);
      expect(cmdNaN.parseError, contains('integer between 0 and 100'));
    });

    test('parses seek with seconds and mm:ss formats', () {
      final cmdSec = CliCommandParser.parse('seek 45');
      expect(cmdSec.type, CliCommandType.seek);
      expect(cmdSec.seekTarget, const Duration(seconds: 45));

      final cmdMmSs = CliCommandParser.parse('seek 02:15');
      expect(cmdMmSs.type, CliCommandType.seek);
      expect(cmdMmSs.seekTarget, const Duration(minutes: 2, seconds: 15));

      final cmdErr = CliCommandParser.parse('seek abc');
      expect(cmdErr.hasError, isTrue);
    });

    test('parses format flags (--json, -j, --human, --pretty)', () {
      final cmdJson = CliCommandParser.parse('status --json');
      expect(cmdJson.format, CliOutputFormat.json);

      final cmdJ = CliCommandParser.parse('status -j');
      expect(cmdJ.format, CliOutputFormat.json);

      final cmdHuman = CliCommandParser.parse('status --human');
      expect(cmdHuman.format, CliOutputFormat.human);

      final cmdPretty = CliCommandParser.parse('status --json --pretty');
      expect(cmdPretty.prettyJson, isTrue);
    });

    test('parses help and handles empty input', () {
      expect(CliCommandParser.parse('help').type, CliCommandType.help);
      expect(CliCommandParser.parse('--help').type, CliCommandType.help);
      expect(CliCommandParser.parse('-h').type, CliCommandType.help);
      expect(CliCommandParser.parse('').type, CliCommandType.help);
    });

    test('marks unknown commands with helpful error', () {
      final cmd = CliCommandParser.parse('foobar');
      expect(cmd.type, CliCommandType.unknown);
      expect(cmd.hasError, isTrue);
      expect(cmd.parseError, contains("Unknown command 'foobar'"));
    });
  });

  group('CliPlaybackStatus Model', () {
    test('computes status properties accurately', () {
      const status = CliPlaybackStatus(
        state: 'playing',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        position: Duration(minutes: 2, seconds: 30),
        duration: Duration(minutes: 5, seconds: 0),
        volume: 75,
      );

      expect(status.isPlaying, isTrue);
      expect(status.isPaused, isFalse);
      expect(status.isStopped, isFalse);
      expect(status.hasTrack, isTrue);
      expect(status.progressRatio, 0.5);
      expect(status.formattedPosition, '02:30');
      expect(status.formattedDuration, '05:00');
    });

    test('generates valid ASCII progress bar', () {
      const statusMid = CliPlaybackStatus(
        state: 'playing',
        position: Duration(seconds: 50),
        duration: Duration(seconds: 100),
      );
      final bar = statusMid.generateProgressBar(width: 12);
      expect(bar.startsWith('['), isTrue);
      expect(bar.endsWith(']'), isTrue);
      expect(bar.length, 12);
      expect(bar, contains('='));
    });

    test('serializes status to JSON map', () {
      const status = CliPlaybackStatus(
        state: 'playing',
        title: 'Song',
        artist: 'Artist',
        volume: 80,
      );
      final json = status.toJson();
      expect(json['state'], 'playing');
      expect(json['is_playing'], isTrue);
      expect(json['volume'], 80);
      expect(json['track']['title'], 'Song');
    });

    test('serializes status to human readable format', () {
      const status = CliPlaybackStatus(
        state: 'playing',
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        volume: 85,
      );
      final text = status.toHumanReadable();
      expect(text, contains('▶ Playing'));
      expect(text, contains('Track:    Song'));
      expect(text, contains('Artist:   Artist'));
      expect(text, contains('Volume:   85%'));
    });
  });

  group('CliResponse Serialization', () {
    test('success response serializes to JSON string', () {
      final res = CliResponse.success(
        command: 'play',
        message: 'Playback resumed',
        data: {'state': 'playing'},
      );

      final jsonStr = res.toJsonString();
      final decoded = jsonDecode(jsonStr);
      expect(decoded['success'], isTrue);
      expect(decoded['command'], 'play');
      expect(decoded['message'], 'Playback resumed');
      expect(decoded['exit_code'], 0);
      expect(decoded['data']['state'], 'playing');
    });

    test('error response serializes with failure exit code', () {
      final res = CliResponse.error(
        command: 'volume',
        message: 'Volume out of range',
        exitCode: 2,
      );

      final json = res.toJson();
      expect(json['success'], isFalse);
      expect(json['command'], 'volume');
      expect(json['exit_code'], 2);
    });

    test('human readable serialization formats symbols', () {
      final resSuccess = CliResponse.success(
        command: 'pause',
        message: 'Playback paused',
      );
      expect(resSuccess.toHumanReadable(), contains('✔ Playback paused'));

      final resErr = CliResponse.error(
        command: 'seek',
        message: 'Position missing',
      );
      expect(resErr.toHumanReadable(), contains('❌ Position missing'));
    });

    test('serialize method respects format parameter', () {
      final res = CliResponse.success(
        command: 'test',
        message: 'All good',
      );

      final jsonOut = res.serialize(CliOutputFormat.json);
      expect(jsonOut.startsWith('{'), isTrue);

      final humanOut = res.serialize(CliOutputFormat.human);
      expect(humanOut.contains('✔ All good'), isTrue);
    });
  });

  group('SoftifyCliService Execution & Playback Control', () {
    late MockCliPlaybackAdapter mockAdapter;
    late SoftifyCliService service;

    setUp(() {
      mockAdapter = MockCliPlaybackAdapter(
        state: 'paused',
        currentTrack: sampleTrack,
        volume: 60,
      );
      service = SoftifyCliService(adapter: mockAdapter);
    });

    test('executes play command and updates adapter state', () async {
      final res = await service.execute('play');
      expect(res.success, isTrue);
      expect(mockAdapter.callHistory, contains('play'));
      expect(mockAdapter.state, 'playing');
    });

    test('executes pause command and updates adapter state', () async {
      mockAdapter.state = 'playing';
      final res = await service.execute('pause');
      expect(res.success, isTrue);
      expect(mockAdapter.callHistory, contains('pause'));
      expect(mockAdapter.state, 'paused');
    });

    test('executes toggle command between playing and paused', () async {
      mockAdapter.state = 'paused';
      final res1 = await service.execute('toggle');
      expect(res1.success, isTrue);
      expect(mockAdapter.state, 'playing');

      final res2 = await service.execute('toggle');
      expect(res2.success, isTrue);
      expect(mockAdapter.state, 'paused');
    });

    test('executes next and prev skip commands', () async {
      final resNext = await service.execute('next');
      expect(resNext.success, isTrue);
      expect(mockAdapter.callHistory, contains('next'));

      final resPrev = await service.execute('prev');
      expect(resPrev.success, isTrue);
      expect(mockAdapter.callHistory, contains('previous'));
    });

    test('executes status query and returns full metadata', () async {
      final res = await service.execute('status');
      expect(res.success, isTrue);
      expect(res.data, isNotNull);
      expect(res.data!['track']['title'], 'Bohemian Rhapsody');
      expect(res.data!['volume'], 60);
    });

    test('executes volume set command with bounds checking', () async {
      final res = await service.execute('volume 85');
      expect(res.success, isTrue);
      expect(mockAdapter.volume, 85);
      expect(mockAdapter.callHistory, contains('setVolume(85)'));
    });

    test('executes volume query without mutation', () async {
      final res = await service.execute('volume');
      expect(res.success, isTrue);
      expect(res.data!['volume'], 60);
      expect(mockAdapter.volume, 60);
    });

    test('executes relative volume delta adjustments (+10, -5)', () async {
      final resPlus = await service.execute('volume +10');
      expect(resPlus.success, isTrue);
      expect(mockAdapter.volume, 70);

      final resMinus = await service.execute('volume -15');
      expect(resMinus.success, isTrue);
      expect(mockAdapter.volume, 55);
    });

    test('rejects invalid volume without modifying player volume', () async {
      final res = await service.execute('volume 250');
      expect(res.success, isFalse);
      expect(res.exitCode, 2);
      expect(mockAdapter.volume, 60);
    });

    test('executes seek command to duration position', () async {
      final res = await service.execute('seek 01:45');
      expect(res.success, isTrue);
      expect(mockAdapter.position, const Duration(minutes: 1, seconds: 45));
    });

    test('executes help command returning usage details', () async {
      final res = await service.execute('help');
      expect(res.success, isTrue);
      expect(res.command, 'help');
      expect(res.message, contains('Usage: softify-cli'));
    });

    test('handles unknown command with error exit code', () async {
      final res = await service.execute('unknowncommand');
      expect(res.success, isFalse);
      expect(res.exitCode, 2);
    });

    test('executeArgs dispatches parsed argument list', () async {
      final res = await service.executeArgs(['volume', '90', '--json']);
      expect(res.success, isTrue);
      expect(mockAdapter.volume, 90);
    });

    test('executeAndFormat returns serialized string immediately', () async {
      final jsonOutput = await service.executeAndFormat('status --json');
      final decoded = jsonDecode(jsonOutput);
      expect(decoded['success'], isTrue);
      expect(decoded['data']['volume'], 60);

      final humanOutput = await service.executeAndFormat('status --human');
      expect(humanOutput, contains('Bohemian Rhapsody'));
    });

    test('records command history and maintains capacity limit', () async {
      service.clearHistory();
      expect(service.history, isEmpty);

      await service.execute('play');
      await service.execute('pause');
      await service.execute('volume 75');

      expect(service.history.length, 3);
      expect(service.history.first.rawInput, 'volume 75');
    });

    test('gracefully handles adapter exceptions', () async {
      mockAdapter.shouldThrow = true;
      mockAdapter.throwMessage = 'Hardware audio interface disconnected';

      final res = await service.execute('play');
      expect(res.success, isFalse);
      expect(res.exitCode, 1);
      expect(res.message, contains('Hardware audio interface disconnected'));
    });
  });

  group('SoftifyCliService IPC Socket Lifecycle', () {
    test('can start and stop local loopback IPC server', () async {
      final mockAdapter = MockCliPlaybackAdapter();
      final service = SoftifyCliService(adapter: mockAdapter);

      expect(service.isIpcServerRunning, isFalse);

      final started = await service.startIpcServer(port: 0); // Port 0 allocates ephemeral free port
      expect(started, isTrue);
      expect(service.isIpcServerRunning, isTrue);
      expect(service.activeIpcPort, isNotNull);

      // Verify client can connect and send command
      final client = await Socket.connect(InternetAddress.loopbackIPv4, service.activeIpcPort!);
      client.writeln('volume 45 --json');
      await client.flush();

      final responseLine = await client
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first;

      final decoded = jsonDecode(responseLine);
      expect(decoded['success'], isTrue);
      expect(mockAdapter.volume, 45);

      await service.stopIpcServer();
      expect(service.isIpcServerRunning, isFalse);
    });
  });

  group('CliPrefsStorage Persistence', () {
    test('stores and reads string and int settings', () async {
      final store = CliSharedPreferencesStore();
      store.reset();

      await store.setString('cli_default_format', 'json');
      expect(await store.getString('cli_default_format'), 'json');

      await store.setInt('cli_port', 49152);
      expect(await store.getInt('cli_port'), 49152);

      await store.setBool('cli_active', true);
      expect(await store.getBool('cli_active'), isTrue);
    });
  });

  group('Riverpod Providers', () {
    test('softifyCliServiceProvider creates service instance', () {
      final mockAdapter = MockCliPlaybackAdapter();
      final container = ProviderContainer(
        overrides: [
          cliPlaybackAdapterProvider.overrideWithValue(mockAdapter),
        ],
      );

      try {
        final service = container.read(softifyCliServiceProvider);
        expect(service, isNotNull);
        expect(service.adapter, mockAdapter);

        final defaultFmt = container.read(cliDefaultOutputFormatProvider);
        expect(defaultFmt, CliOutputFormat.human);
      } finally {
        container.dispose();
      }
    });

    test('cliCommandHistoryNotifier records and clears history', () {
      final container = ProviderContainer();
      try {
        final notifier = container.read(cliCommandHistoryProvider.notifier);
        notifier.record(
          CliHistoryItem(
            rawInput: 'play',
            response: CliResponse.success(command: 'play', message: 'Ok'),
            executedAt: DateTime.now(),
          ),
        );

        final items = container.read(cliCommandHistoryProvider);
        expect(items.length, 1);
        expect(items.first.rawInput, 'play');

        notifier.clear();
        expect(container.read(cliCommandHistoryProvider), isEmpty);
      } finally {
        container.dispose();
      }
    });
  });

  group('SoftifyCliControlCard Widget', () {
    testWidgets('renders CLI header, badge, and quick action chips', (tester) async {
      final mockAdapter = MockCliPlaybackAdapter(
        state: 'playing',
        currentTrack: sampleTrack,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cliPlaybackAdapterProvider.overrideWithValue(mockAdapter),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SoftifyCliControlCard(),
            ),
          ),
        ),
      );

      expect(find.text('CLI Playback Controller'), findsOneWidget);
      expect(find.text('Feature 35'), findsOneWidget);
      expect(find.text('play'), findsOneWidget);
      expect(find.text('pause'), findsOneWidget);
      expect(find.text('status'), findsOneWidget);
      expect(find.text('volume 80'), findsOneWidget);
      expect(find.text('Terminal Sandbox'), findsOneWidget);
    });

    testWidgets('tapping quick chip executes command and displays terminal output',
        (tester) async {
      final mockAdapter = MockCliPlaybackAdapter(
        state: 'paused',
        currentTrack: sampleTrack,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cliPlaybackAdapterProvider.overrideWithValue(mockAdapter),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SoftifyCliControlCard(),
            ),
          ),
        ),
      );

      // Tap 'play' chip
      await tester.tap(find.text('play'));
      await tester.pumpAndSettle();

      expect(mockAdapter.callHistory, contains('play'));
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.textContaining('Playback resumed'), findsOneWidget);
    });

    testWidgets('toggling JSON switch updates default format provider',
        (tester) async {
      final mockAdapter = MockCliPlaybackAdapter();

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cliPlaybackAdapterProvider.overrideWithValue(mockAdapter),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const SoftifyCliControlCard();
                },
              ),
            ),
          ),
        ),
      );

      expect(capturedRef.read(cliDefaultOutputFormatProvider), CliOutputFormat.human);

      // Toggle JSON switch
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(capturedRef.read(cliDefaultOutputFormatProvider), CliOutputFormat.json);
    });
  });
}
