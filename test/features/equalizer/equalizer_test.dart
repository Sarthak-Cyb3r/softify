import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/data/player/softify_audio_player.dart';
import 'package:softify/domain/entities/equalizer_preset.dart';
import 'package:softify/domain/ports/i_download_repository.dart';
import 'package:softify/domain/ports/i_library_repository.dart';
import 'package:softify/domain/ports/i_stream_resolver.dart';
import 'package:softify/presentation/providers/equalizer_providers.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/screens/equalizer_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:softify/presentation/widgets/equalizer_curve_visualizer.dart';

class TestMockAudioPlayer implements ISoftifyAudioPlayer {
  bool equalizerEnabled = true;
  List<double> bandGains = [0.0, 0.0, 0.0, 0.0, 0.0];
  double bassBoost = 0.0;
  double loudnessGain = 0.0;

  final BehaviorSubject<PlayerState> _playerStateSubject =
      BehaviorSubject<PlayerState>.seeded(PlayerState(false, ProcessingState.idle));
  final PublishSubject<PlaybackEvent> _playbackEventSubject =
      PublishSubject<PlaybackEvent>();
  final BehaviorSubject<Duration> _positionSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration> _bufferedPositionSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration?> _durationSubject =
      BehaviorSubject<Duration?>.seeded(null);
  final BehaviorSubject<double> _volumeSubject =
      BehaviorSubject<double>.seeded(1.0);

  @override
  Stream<PlayerState> get playerStateStream => _playerStateSubject.stream;
  @override
  Stream<PlaybackEvent> get playbackEventStream => _playbackEventSubject.stream;
  @override
  Stream<Duration> get positionStream => _positionSubject.stream;
  @override
  Stream<Duration> get bufferedPositionStream => _bufferedPositionSubject.stream;
  @override
  Stream<Duration?> get durationStream => _durationSubject.stream;
  @override
  Stream<double> get volumeStream => _volumeSubject.stream;

  @override
  bool get playing => false;
  @override
  ProcessingState get processingState => ProcessingState.idle;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get bufferedPosition => Duration.zero;
  @override
  double get speed => 1.0;
  @override
  double get volume => 1.0;
  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setEqualizerEnabled(bool enabled) async => equalizerEnabled = enabled;

  @override
  Future<void> setEqualizerBands(List<double> gains) async => bandGains = List.from(gains);

  @override
  Future<void> setBassBoost(double boost) async => bassBoost = boost;

  @override
  Future<void> setLoudnessEnhancerGain(double gain) async => loudnessGain = gain;

  @override
  Future<List<double>> getBandFrequencies() async => const [60.0, 230.0, 910.0, 3600.0, 14000.0];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStreamResolver implements IStreamResolver {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLibraryRepo implements ILibraryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDownloadRepo implements IDownloadRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Equalizer Domain & State', () {
    test('Default presets exist and have 5 bands', () {
      expect(EqualizerPreset.defaultPresets.isNotEmpty, isTrue);
      for (final p in EqualizerPreset.defaultPresets) {
        expect(p.gains.length, equals(5));
      }
      final rock = EqualizerPreset.defaultPresets.firstWhere((p) => p.name == 'Rock');
      expect(rock.gains[0], greaterThan(0)); // Boosted bass
    });

    test('EqualizerNotifier updates state, audio handler, and database', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final mockPlayer = TestMockAudioPlayer();
      final audioHandler = SoftifyAudioHandler(
        player: mockPlayer,
        streamResolver: FakeStreamResolver(),
        libraryRepo: FakeLibraryRepo(),
        downloadRepo: FakeDownloadRepo(),
        enableAudioSession: false,
        autoRestoreState: false,
      );

      final notifier = EqualizerNotifier(db: db, audioHandler: audioHandler);
      await Future.delayed(const Duration(milliseconds: 10));

      // Test preset selection
      await notifier.selectPreset('Rock');
      expect(notifier.state.currentPreset, equals('Rock'));
      expect(notifier.state.bandGains, equals([4.5, 2.5, -1.0, 2.5, 4.5]));
      expect(mockPlayer.bandGains, equals([4.5, 2.5, -1.0, 2.5, 4.5]));

      // Test manual slider change switches to Custom
      await notifier.setBandGain(0, 1.2);
      expect(notifier.state.currentPreset, equals('Custom'));
      expect(notifier.state.bandGains[0], equals(1.2));
      expect(mockPlayer.bandGains[0], equals(1.2));

      // Test Bass Boost & Loudness Enhancer
      await notifier.setBassBoost(0.8);
      expect(notifier.state.bassBoost, equals(0.8));
      expect(mockPlayer.bassBoost, equals(0.8));

      await notifier.setLoudnessGain(0.5);
      expect(notifier.state.loudnessGain, equals(0.5));
      expect(mockPlayer.loudnessGain, equals(0.5));

      // Test A/B Audition bypass
      await notifier.setBypass(true);
      expect(notifier.state.isBypassed, isTrue);
      expect(mockPlayer.equalizerEnabled, isFalse);

      await notifier.setBypass(false);
      expect(notifier.state.isBypassed, isFalse);
      expect(mockPlayer.equalizerEnabled, isTrue);

      // Test Reset to Flat
      await notifier.resetToFlat();
      expect(notifier.state.currentPreset, equals('Flat'));
      expect(notifier.state.bandGains, equals([0.0, 0.0, 0.0, 0.0, 0.0]));
      expect(notifier.state.bassBoost, equals(0.0));
      expect(notifier.state.loudnessGain, equals(0.0));

      await db.close();
    });
  });

  group('Equalizer UI Widgets', () {
    testWidgets('EqualizerCurveVisualizer renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EqualizerCurveVisualizer(
              bandGains: [4.5, 2.0, -1.0, 2.0, 4.0],
              bandFrequencies: [60.0, 230.0, 910.0, 3600.0, 14000.0],
              bassBoost: 0.5,
              isEnabled: true,
              isBypassed: false,
            ),
          ),
        ),
      );

      expect(find.byType(EqualizerCurveVisualizer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('EqualizerScreen renders all cards, presets, and sliders', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(NativeDatabase.memory());
      final mockPlayer = TestMockAudioPlayer();
      final audioHandler = SoftifyAudioHandler(
        player: mockPlayer,
        streamResolver: FakeStreamResolver(),
        libraryRepo: FakeLibraryRepo(),
        downloadRepo: FakeDownloadRepo(),
        enableAudioSession: false,
        autoRestoreState: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            audioHandlerProvider.overrideWithValue(audioHandler),
          ],
          child: const MaterialApp(
            home: EqualizerScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Equalizer'), findsOneWidget);
      expect(find.text('Frequency Bands'), findsOneWidget);
      expect(find.text('Audio Enhancers'), findsOneWidget);
      expect(find.text('Bass Boost'), findsOneWidget);
      expect(find.text('Loudness Maximizer'), findsOneWidget);
      expect(find.text('Hold to A/B Audition Original Sound'), findsOneWidget);
      expect(find.text('Flat'), findsOneWidget);
      expect(find.text('Bass Booster'), findsOneWidget);

      await db.close();
    });
  });
}
