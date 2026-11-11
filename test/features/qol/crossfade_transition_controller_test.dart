import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/crossfade_transition_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.reset();
  });

  group('CrossfadeDurationNotifier tests', () {
    test('default state is 0 (gapless)', () {
      final notifier = CrossfadeDurationNotifier();
      expect(notifier.state, kCrossfadeDefaultSeconds);
      expect(notifier.isGapless, isTrue);
      expect(notifier.formattedLabel, 'Gapless');
    });

    test('clamped to 0..12', () async {
      final notifier = CrossfadeDurationNotifier();
      await notifier.setCrossfadeDuration(5);
      expect(notifier.state, 5);
      expect(notifier.isGapless, isFalse);
      expect(notifier.formattedLabel, '5s');

      await notifier.setCrossfadeDuration(-3);
      expect(notifier.state, 0);
      expect(notifier.isGapless, isTrue);

      await notifier.setCrossfadeDuration(20);
      expect(notifier.state, 12);
      expect(notifier.formattedLabel, '12s');
    });

    test('persists to SharedPreferences and restores on init', () async {
      SharedPreferences.setMockInitialValues({
        kCrossfadeDurationPrefKey: 7,
      });

      final notifier = CrossfadeDurationNotifier();
      // Wait for async initialization
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state, 7);
      expect(notifier.isGapless, isFalse);
      expect(notifier.formattedLabel, '7s');

      await notifier.setCrossfadeDuration(3);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kCrossfadeDurationPrefKey), 3);
    });

    test('toggleGapless switches between 0 and active duration', () async {
      final notifier = CrossfadeDurationNotifier();
      await notifier.setCrossfadeDuration(6);
      expect(notifier.state, 6);

      // Toggle to Gapless
      await notifier.toggleGapless();
      expect(notifier.state, 0);
      expect(notifier.isGapless, isTrue);

      // Toggle back from Gapless restores previous (6s)
      await notifier.toggleGapless();
      expect(notifier.state, 6);

      // From 0 with no previous restores default (4s)
      final freshNotifier = CrossfadeDurationNotifier();
      await freshNotifier.toggleGapless(defaultWhenEnabling: 4);
      expect(freshNotifier.state, 4);
    });
  });

  group('CrossfadeDurationSlider widget tests', () {
    testWidgets('renders slider, gapless badge, and second indicators', (tester) async {
      SharedPreferences.setMockInitialValues({
        kCrossfadeDurationPrefKey: 0,
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CrossfadeDurationSlider(
                showHeader: true,
                showPresets: true,
                showSecondIndicators: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verified presence of header, Gapless label, indicators, and preset chips
      expect(find.text('Crossfade Duration'), findsOneWidget);
      expect(find.text('Gapless'), findsWidgets);
      expect(find.text('3s'), findsWidgets);
      expect(find.text('6s'), findsWidgets);
      expect(find.text('12s'), findsWidgets);
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  group('CrossfadeSettingsCard widget tests', () {
    testWidgets('renders card with title, subtitle, and toggle switch', (tester) async {
      SharedPreferences.setMockInitialValues({
        kCrossfadeDurationPrefKey: 0,
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CrossfadeSettingsCard(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Audio Crossfade'), findsOneWidget);
      expect(find.text('Gapless playback (no volume dip or overlap)'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(CrossfadeDurationSlider), findsOneWidget);
    });
  });
}
