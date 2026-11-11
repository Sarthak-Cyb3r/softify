import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/lyrics_font_size_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.reset();
  });

  group('LyricsFontSizeScaleNotifier & Provider', () {
    test('defaults to 1.0x scale', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final scale = container.read(lyricsFontSizeScaleProvider);
      expect(scale, 1.0);
    });

    test('updates scale and clamps to [0.8, 1.6]', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lyricsFontSizeScaleProvider.notifier);

      await notifier.setScale(1.25);
      expect(container.read(lyricsFontSizeScaleProvider), 1.25);

      // Clamping below 0.8
      await notifier.setScale(0.5);
      expect(container.read(lyricsFontSizeScaleProvider), 0.8);

      // Clamping above 1.6
      await notifier.setScale(2.5);
      expect(container.read(lyricsFontSizeScaleProvider), 1.6);
    });

    test('step increase and decrease work properly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lyricsFontSizeScaleProvider.notifier);

      await notifier.increase(0.1);
      expect(container.read(lyricsFontSizeScaleProvider), 1.1);

      await notifier.decrease(0.15);
      expect(container.read(lyricsFontSizeScaleProvider), 0.95);

      await notifier.reset();
      expect(container.read(lyricsFontSizeScaleProvider), 1.0);
    });

    test('persists font size scale to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lyricsFontSizeScaleProvider.notifier);
      await notifier.setScale(1.4);

      expect(prefs.getDouble(kLyricsFontSizeScalePrefKey), 1.4);

      // New container loads persisted value
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      // Let notifier load
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container2.read(lyricsFontSizeScaleProvider), 1.4);
    });
  });

  group('LyricsLineHeightScaleNotifier & Provider', () {
    test('defaults to 1.0x line height scale', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final scale = container.read(lyricsLineHeightScaleProvider);
      expect(scale, 1.0);
    });

    test('updates scale and clamps to [0.8, 2.0]', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lyricsLineHeightScaleProvider.notifier);

      await notifier.setScale(1.3);
      expect(container.read(lyricsLineHeightScaleProvider), 1.3);

      await notifier.setScale(0.2);
      expect(container.read(lyricsLineHeightScaleProvider), 0.8);

      await notifier.setScale(3.5);
      expect(container.read(lyricsLineHeightScaleProvider), 2.0);
    });

    test('persists line spacing scale to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lyricsLineHeightScaleProvider.notifier);
      await notifier.setScale(1.5);

      expect(prefs.getDouble(kLyricsLineHeightScalePrefKey), 1.5);

      // Second container reads saved value
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container2.read(lyricsLineHeightScaleProvider), 1.5);
    });
  });

  group('LyricsTypographyScale Provider', () {
    test('combines font size and line height scales', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var typo = container.read(lyricsTypographyScaleProvider);
      expect(typo.isDefault, isTrue);
      expect(typo.scaleFontSize(20), 20.0);
      expect(typo.scaleLineHeight(1.5), 1.5);

      await container.read(lyricsFontSizeScaleProvider.notifier).setScale(1.2);
      await container.read(lyricsLineHeightScaleProvider.notifier).setScale(1.5);

      typo = container.read(lyricsTypographyScaleProvider);
      expect(typo.isDefault, isFalse);
      expect(typo.scaleFontSize(20), 24.0);
      expect(typo.scaleLineHeight(1.5), 2.25);
    });
  });

  group('LyricsFontScaleButton Widget', () {
    testWidgets('renders button and responds to tap', (tester) async {
      var sheetShown = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LyricsFontScaleButton(
                onTap: () {
                  sheetShown = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LyricsFontScaleButton), findsOneWidget);
      expect(find.byIcon(Icons.format_size_rounded), findsOneWidget);

      await tester.tap(find.byType(LyricsFontScaleButton));
      await tester.pumpAndSettle();

      expect(sheetShown, isTrue);
    });

    testWidgets('shows indicator badge when customized', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: LyricsFontScaleButton(),
            ),
          ),
        ),
      );

      // At default, no accent badge dot
      expect(find.byType(LyricsFontScaleButton), findsOneWidget);

      // Customize scale
      await container.read(lyricsFontSizeScaleProvider.notifier).setScale(1.2);
      await tester.pumpAndSettle();

      // Button now indicates customized state
      final button = tester.widget<LyricsFontScaleButton>(find.byType(LyricsFontScaleButton));
      expect(button.showBadge, isTrue);
    });
  });

  group('LyricsFontScaleSheet Widget', () {
    testWidgets('displays preview text and adjusts font size via slider', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: LyricsFontScaleSheet(),
            ),
          ),
        ),
      );

      // Preview text is visible
      expect(find.text('Lyrics Typography'), findsOneWidget);
      expect(find.text('LIVE PREVIEW'), findsOneWidget);
      expect(find.text('I hear the music through the night'), findsOneWidget);
      expect(find.text('Every beat is singing your name'), findsOneWidget);
      expect(find.text('Lost in melodies that never fade away'), findsOneWidget);

      // Tap preset 'Large' (1.25x)
      final largePreset = find.text('Large');
      expect(largePreset, findsOneWidget);
      await tester.tap(largePreset);
      await tester.pumpAndSettle();

      expect(container.read(lyricsFontSizeScaleProvider), 1.25);

      // Tap Reset button
      final resetButton = find.text('Reset');
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(container.read(lyricsFontSizeScaleProvider), 1.0);
    });
  });
}
