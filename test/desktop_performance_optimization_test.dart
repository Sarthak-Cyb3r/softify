import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_service/audio_service.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/audio_repeat_mode.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/providers/settings_providers.dart';
import 'package:softify/presentation/providers/ui_style_provider.dart';
import 'package:softify/presentation/widgets/desktop_sidebar.dart';
import 'package:softify/presentation/widgets/desktop_player_bar.dart';
import 'package:softify/presentation/widgets/shared/app_surface.dart';
import 'package:softify/presentation/theme/app_theme.dart';

class _DummyHandler extends Fake implements SoftifyAudioHandler {
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
  double get speed => 1.0;

  @override
  Stream<double> get speedStream => Stream.value(1.0);
}

void main() {
  group('Desktop Performance Optimizations Tests', () {
    test('kAppVersion is bumped to 3.0.3', () {
      expect(kAppVersion, equals('3.0.3'));
    });

    test('isLowEndDeviceProvider detects desktop platforms for shader efficiency', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isConstrained = container.read(isLowEndDeviceProvider);
      // On linux test machine, it must evaluate to true
      expect(isConstrained, isTrue);

      final reduceEffects = container.read(shouldReduceEffectsProvider);
      expect(reduceEffects, isTrue);
    });

    testWidgets('DesktopSidebar renders with withBlur: false to eliminate GPU stalls',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.themeFor(UiStyle.auroraGlass),
            home: Scaffold(
              body: DesktopSidebar(
                currentIndex: 0,
                onSelectTab: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final appSurfaceFinder = find.descendant(
        of: find.byType(DesktopSidebar),
        matching: find.byType(AppSurface),
      );
      expect(appSurfaceFinder, findsOneWidget);

      final AppSurface surface = tester.widget(appSurfaceFinder);
      expect(surface.withBlur, isFalse,
          reason: 'Desktop sidebar must not run expensive BackdropFilter');
    });

    testWidgets('DesktopPlayerBar renders with withBlur: false',
        (tester) async {
      const testTrack = Track(
        id: 'test-track-1',
        sourceId: 'src-1',
        title: 'Neon Nights',
        artist: 'Linux Cyber Syndicate',
        duration: Duration(minutes: 4, seconds: 12),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(_DummyHandler()),
            currentTrackProvider.overrideWith((ref) => Stream.value(testTrack)),
            positionStreamProvider.overrideWith(
                (ref) => Stream.value(const Duration(minutes: 1, seconds: 30))),
            durationStreamProvider.overrideWith(
                (ref) => Stream.value(const Duration(minutes: 4, seconds: 12))),
            volumeStreamProvider.overrideWith((ref) => Stream.value(0.85)),
            isTrackLikedProvider(testTrack.id)
                .overrideWith((ref) => Stream.value(true)),
          ],
          child: MaterialApp(
            theme: AppTheme.themeFor(UiStyle.auroraGlass),
            home: const Scaffold(
              bottomNavigationBar: DesktopPlayerBar(),
            ),
          ),
        ),
      );

      await tester.pump();

      final appSurfaceFinder = find.descendant(
        of: find.byType(DesktopPlayerBar),
        matching: find.byType(AppSurface),
      );
      expect(appSurfaceFinder, findsOneWidget);

      final AppSurface surface = tester.widget(appSurfaceFinder);
      expect(surface.withBlur, isFalse,
          reason: 'Desktop player bar must not run expensive BackdropFilter');
    });
  });
}
