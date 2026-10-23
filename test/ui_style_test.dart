import 'package:audio_service/audio_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/audio_repeat_mode.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/providers/ui_style_provider.dart';
import 'package:softify/presentation/screens/settings_screen.dart';
import 'package:softify/presentation/theme/app_theme.dart';
import 'package:softify/presentation/widgets/shared/app_surface.dart';

class _FakeAudioHandler extends Fake implements SoftifyAudioHandler {
  @override
  Stream<double> get volumeStream => Stream.value(1.0);
  @override
  double get volume => 1.0;
  @override
  final BehaviorSubject<PlaybackState> playbackState =
      BehaviorSubject<PlaybackState>.seeded(PlaybackState(playing: false));
  @override
  Stream<AudioRepeatMode> get repeatModeStream =>
      Stream.value(AudioRepeatMode.off);
  @override
  Stream<bool> get shuffleModeStream => Stream.value(false);
  @override
  Stream<bool> get autoPlayStream => Stream.value(true);
  @override
  Stream<Duration?> get sleepTimerRemainingStream => Stream.value(null);
  @override
  Stream<bool> get sleepEndOfTrackStream => Stream.value(false);
  @override
  Stream<Track?> get currentTrackStream => Stream.value(null);
  @override
  Stream<List<Track>> get tracksQueueStream => Stream.value([]);
  @override
  Stream<Duration> get positionStream => Stream.value(Duration.zero);
  @override
  Stream<Duration?> get durationStream => Stream.value(null);
  @override
  double get speed => 1.0;
  @override
  Stream<double> get speedStream => Stream.value(1.0);
  @override
  Future<List<double>> getBandFrequencies() async => const [];
  @override
  Future<void> setEqualizerEnabled(bool enabled) async {}
  @override
  Future<void> setEqualizerBands(List<double> gains) async {}
  @override
  Future<void> setCrossfadeSeconds(int seconds) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UiStyle & AppTokens Design Token System', () {
    test('Tokens correctly differentiate Classic and Aurora Glass', () {
      const classic = AppTokens.standardTokens;
      const aurora = AppTokens.auroraTokens;

      expect(classic.style, equals(UiStyle.classic));
      expect(classic.isGlass, isFalse);
      expect(classic.background, equals(const Color(0xFF121212)));
      expect(classic.accent, equals(const Color(0xFF1DB954))); // Spotify green

      expect(aurora.style, equals(UiStyle.auroraGlass));
      expect(aurora.isGlass, isTrue);
      expect(aurora.background, equals(const Color(0xFF0B0B1A))); // Midnight
      expect(aurora.accent, equals(const Color(0xFF7C5CFF))); // Aurora violet
      expect(aurora.accentCyan, equals(const Color(0xFF4FD1FF)));
      expect(aurora.accentRose, equals(const Color(0xFFFF7AC6)));
      expect(aurora.radiusCard, equals(22.0)); // 20-28 glass radius
    });

    test('ThemeData generated for each style adheres to ColorScheme contracts', () {
      final classicTheme = AppTheme.themeFor(UiStyle.classic);
      final auroraTheme = AppTheme.themeFor(UiStyle.auroraGlass);

      expect(classicTheme.colorScheme.primary, equals(const Color(0xFF1DB954)));
      expect(classicTheme.scaffoldBackgroundColor, equals(const Color(0xFF121212)));

      expect(auroraTheme.colorScheme.primary, equals(const Color(0xFF7C5CFF)));
      expect(auroraTheme.colorScheme.secondary, equals(const Color(0xFF4FD1FF)));
      expect(auroraTheme.colorScheme.tertiary, equals(const Color(0xFFFF7AC6)));
      expect(auroraTheme.scaffoldBackgroundColor, equals(const Color(0xFF0B0B1A)));
    });

    test('WCAG AA Contrast verification for Aurora Glass text tokens', () {
      const aurora = AppTokens.auroraTokens;

      double luminance(Color c) => c.computeLuminance();
      double contrastRatio(Color fg, Color bg) {
        final l1 = luminance(fg);
        final l2 = luminance(bg);
        final lighter = l1 > l2 ? l1 : l2;
        final darker = l1 > l2 ? l2 : l1;
        return (lighter + 0.05) / (darker + 0.05);
      }

      // Text primary against midnight background must be >= 7.0 (AAA)
      final primaryRatio = contrastRatio(aurora.textPrimary, aurora.background);
      expect(primaryRatio, greaterThanOrEqualTo(7.0));

      // Text secondary (silvery lavender) against midnight background must be >= 4.5 (AA)
      final secondaryRatio = contrastRatio(aurora.textSecondary, aurora.background);
      expect(secondaryRatio, greaterThanOrEqualTo(4.5));
    });
  });

  group('UiStyle & ReduceEffects Database Persistence', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('UiStyleNotifier persists style selection to Drift SQLite', () async {
      final notifier = UiStyleNotifier(db);
      expect(notifier.state, equals(UiStyle.classic));

      await notifier.setStyle(UiStyle.auroraGlass);
      expect(notifier.state, equals(UiStyle.auroraGlass));

      // Verify row in database
      final row = await (db.select(db.settings)
            ..where((t) => t.key.equals('ui_style')))
          .getSingle();
      expect(row.value, equals('auroraGlass'));

      // New instance loading from same DB should restore auroraGlass
      final restored = UiStyleNotifier(db);
      // Wait for async load
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(restored.state, equals(UiStyle.auroraGlass));
    });

    test('ReduceEffectsNotifier persists mode selection to Drift SQLite', () async {
      final notifier = ReduceEffectsNotifier(db);
      expect(notifier.state, equals(ReduceEffectsMode.auto));

      await notifier.setMode(ReduceEffectsMode.on);
      expect(notifier.state, equals(ReduceEffectsMode.on));

      final row = await (db.select(db.settings)
            ..where((t) => t.key.equals('reduce_effects')))
          .getSingle();
      expect(row.value, equals('on'));

      final restored = ReduceEffectsNotifier(db);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(restored.state, equals(ReduceEffectsMode.on));
    });
  });

  group('AppSurface & Glassmorphism Rendering Performance', () {
    testWidgets('AppSurface renders solid surface in Classic theme', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.themeFor(UiStyle.classic),
            home: const Scaffold(
              body: AppSurface(
                withBlur: true,
                child: Text('Content'),
              ),
            ),
          ),
        ),
      );

      // In Classic mode, BackdropFilter should NEVER be rendered
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('AppSurface respects shouldReduceEffects toggle in Aurora Glass', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db.close());

      // Reduce effects ON: Blur must be bypassed even with withBlur=true
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            uiStyleProvider.overrideWith((ref) {
              final n = UiStyleNotifier(db);
              n.state = UiStyle.auroraGlass;
              return n;
            }),
            reduceEffectsProvider.overrideWith((ref) {
              final n = ReduceEffectsNotifier(db);
              n.state = ReduceEffectsMode.on;
              return n;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.themeFor(UiStyle.auroraGlass),
            home: const Scaffold(
              body: AppSurface(
                withBlur: true,
                child: Text('Reduced Glass'),
              ),
            ),
          ),
        ),
      );

      // BackdropFilter bypassed for 60fps performance on low-end
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Reduced Glass'), findsOneWidget);
    });
  });

  group('Settings Screen Appearance Selector UI', () {
    testWidgets('Settings screen displays UI Style and Reduce effects controls', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            audioHandlerProvider.overrideWithValue(_FakeAudioHandler()),
          ],
          child: MaterialApp(
            theme: AppTheme.themeFor(UiStyle.classic),
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Appearance section exists
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('UI Style'), findsOneWidget);
      expect(find.text('Classic'), findsWidgets);
      expect(find.text('Aurora Glass'), findsWidgets);
      expect(find.text('Reduce effects'), findsOneWidget);

      // Tap on Aurora Glass preview card
      await tester.tap(find.text('Aurora Glass').first);
      await tester.pumpAndSettle();

      // Cleanly unmount widget tree before closing db
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
      await db.close();
    });
  });
}
