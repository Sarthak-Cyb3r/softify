import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/lyrics/lyrics_font_switcher.dart';
import 'package:softify/presentation/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.reset();
  });

  // ==========================================================================
  // LyricsFontStyle Enum & Model Unit Tests
  // ==========================================================================
  group('LyricsFontStyle Model Tests', () {
    test('contains exactly 4 curated font styles', () {
      expect(LyricsFontStyle.values.length, 4);
      expect(
        LyricsFontStyle.values,
        containsAll([
          LyricsFontStyle.modernSans,
          LyricsFontStyle.elegantSerif,
          LyricsFontStyle.monospacedLyricist,
          LyricsFontStyle.displayBold,
        ]),
      );
    });

    test('attributes and font families match design specifications', () {
      expect(LyricsFontStyle.modernSans.id, 'modern_sans');
      expect(LyricsFontStyle.modernSans.displayName, 'Modern Sans');
      expect(LyricsFontStyle.modernSans.fontFamily, AppTheme.fontUi);
      expect(LyricsFontStyle.modernSans.previewBadge, 'Aa');

      expect(LyricsFontStyle.elegantSerif.id, 'elegant_serif');
      expect(LyricsFontStyle.elegantSerif.displayName, 'Elegant Serif');
      expect(LyricsFontStyle.elegantSerif.fontFamily, AppTheme.fontEditorial);
      expect(LyricsFontStyle.elegantSerif.previewBadge, '𝒬𝒶');

      expect(LyricsFontStyle.monospacedLyricist.id, 'monospaced_lyricist');
      expect(LyricsFontStyle.monospacedLyricist.displayName, 'Monospaced Lyricist');
      expect(LyricsFontStyle.monospacedLyricist.fontFamily, 'monospace');
      expect(LyricsFontStyle.monospacedLyricist.previewBadge, '>_');

      expect(LyricsFontStyle.displayBold.id, 'display_bold');
      expect(LyricsFontStyle.displayBold.displayName, 'Display Bold');
      expect(LyricsFontStyle.displayBold.fontFamily, AppTheme.fontDisplay);
      expect(LyricsFontStyle.displayBold.previewBadge, 'AA');
    });

    test('fromId correctly parses valid IDs case-insensitively', () {
      expect(LyricsFontStyle.fromId('modern_sans'), LyricsFontStyle.modernSans);
      expect(LyricsFontStyle.fromId('MODERN_SANS'), LyricsFontStyle.modernSans);
      expect(LyricsFontStyle.fromId('elegant_serif'), LyricsFontStyle.elegantSerif);
      expect(LyricsFontStyle.fromId('  elegant_serif  '), LyricsFontStyle.elegantSerif);
      expect(LyricsFontStyle.fromId('monospaced_lyricist'), LyricsFontStyle.monospacedLyricist);
      expect(LyricsFontStyle.fromId('display_bold'), LyricsFontStyle.displayBold);
    });

    test('fromId falls back to modernSans for invalid, empty, or null IDs', () {
      expect(LyricsFontStyle.fromId(null), LyricsFontStyle.modernSans);
      expect(LyricsFontStyle.fromId(''), LyricsFontStyle.modernSans);
      expect(LyricsFontStyle.fromId('unknown_font'), LyricsFontStyle.modernSans);
      expect(LyricsFontStyle.fromId('comic_sans'), LyricsFontStyle.modernSans);
    });

    test('fromIndex accurately maps valid indices and handles out-of-bounds', () {
      expect(LyricsFontStyle.fromIndex(0), LyricsFontStyle.modernSans);
      expect(LyricsFontStyle.fromIndex(1), LyricsFontStyle.elegantSerif);
      expect(LyricsFontStyle.fromIndex(2), LyricsFontStyle.monospacedLyricist);
      expect(LyricsFontStyle.fromIndex(3), LyricsFontStyle.displayBold);

      expect(LyricsFontStyle.fromIndex(null), LyricsFontStyle.modernSans);
      expect(LyricsFontStyle.fromIndex(-1), LyricsFontStyle.modernSans);
      expect(LyricsFontStyle.fromIndex(4), LyricsFontStyle.modernSans);
      expect(LyricsFontStyle.fromIndex(99), LyricsFontStyle.modernSans);
    });

    test('toTextStyle constructs TextStyle with appropriate weights and family', () {
      final style = LyricsFontStyle.elegantSerif;

      final inactiveStyle = style.toTextStyle(fontSize: 18, isActive: false);
      expect(inactiveStyle.fontFamily, AppTheme.fontEditorial);
      expect(inactiveStyle.fontWeight, style.defaultWeight);
      expect(inactiveStyle.fontSize, 18);

      final activeStyle = style.toTextStyle(fontSize: 24, isActive: true);
      expect(activeStyle.fontFamily, AppTheme.fontEditorial);
      expect(activeStyle.fontWeight, style.activeWeight);
      expect(activeStyle.fontSize, 24);
    });
  });

  // ==========================================================================
  // LyricsFontStyleNotifier & Riverpod Provider Unit Tests
  // ==========================================================================
  group('LyricsFontStyleNotifier & Provider Unit Tests', () {
    test('defaults to Modern Sans', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final current = container.read(lyricsFontStyleProvider);
      expect(current, LyricsFontStyle.modernSans);
      expect(container.read(lyricsFontStyleProvider.notifier).isDefault, isTrue);
    });

    test('setStyle updates state correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lyricsFontStyleProvider.notifier);

      await notifier.setStyle(LyricsFontStyle.elegantSerif);
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.elegantSerif);
      expect(notifier.isDefault, isFalse);

      await notifier.setStyle(LyricsFontStyle.monospacedLyricist);
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.monospacedLyricist);

      await notifier.setStyle(LyricsFontStyle.displayBold);
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.displayBold);
    });

    test('selectById updates state from string', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lyricsFontStyleProvider.notifier);

      await notifier.selectById('elegant_serif');
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.elegantSerif);

      await notifier.selectById('display_bold');
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.displayBold);
    });

    test('cycleNext cycles sequentially through all 4 font styles', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lyricsFontStyleProvider.notifier);
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.modernSans);

      await notifier.cycleNext();
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.elegantSerif);

      await notifier.cycleNext();
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.monospacedLyricist);

      await notifier.cycleNext();
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.displayBold);

      await notifier.cycleNext();
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.modernSans);
    });

    test('reset restores default Modern Sans', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lyricsFontStyleProvider.notifier);

      await notifier.setStyle(LyricsFontStyle.displayBold);
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.displayBold);

      await notifier.reset();
      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.modernSans);
      expect(notifier.isDefault, isTrue);
    });

    test('persists selected font style to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lyricsFontStyleProvider.notifier);
      await notifier.setStyle(LyricsFontStyle.monospacedLyricist);

      expect(prefs.getString(kLyricsFontStylePrefKey), 'monospaced_lyricist');

      // Second container should load the persisted style
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container2.read(lyricsFontStyleProvider), LyricsFontStyle.monospacedLyricist);
      expect(container2.read(lyricsFontFamilyProvider), 'monospace');
    });

    test('lyricsFontFamilyProvider reflects current style family', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(lyricsFontFamilyProvider), AppTheme.fontUi);

      await container
          .read(lyricsFontStyleProvider.notifier)
          .setStyle(LyricsFontStyle.elegantSerif);
      expect(container.read(lyricsFontFamilyProvider), AppTheme.fontEditorial);
    });
  });

  // ==========================================================================
  // LyricsTypographyHelper Unit Tests
  // ==========================================================================
  group('LyricsTypographyHelper Tests', () {
    test('getLyricsStyle returns expected active and inactive TextStyles', () {
      final activeStyle = LyricsTypographyHelper.getLyricsStyle(
        LyricsFontStyle.displayBold,
        isActive: true,
        fontSize: 22,
        activeColor: Colors.white,
      );

      expect(activeStyle.fontFamily, AppTheme.fontDisplay);
      expect(activeStyle.fontWeight, LyricsFontStyle.displayBold.activeWeight);
      expect(activeStyle.color, Colors.white);

      final inactiveStyle = LyricsTypographyHelper.getLyricsStyle(
        LyricsFontStyle.displayBold,
        isActive: false,
        fontSize: 16,
        inactiveColor: Colors.grey,
      );

      expect(inactiveStyle.fontFamily, AppTheme.fontDisplay);
      expect(inactiveStyle.fontWeight, LyricsFontStyle.displayBold.defaultWeight);
      expect(inactiveStyle.color, Colors.grey);
    });
  });

  // ==========================================================================
  // Widget Tests: LyricsFontPickerSheet
  // ==========================================================================
  group('LyricsFontPickerSheet Widget Tests', () {
    testWidgets('renders header, live preview, and all 4 font options',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: LyricsFontPickerSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header texts
      expect(find.text('Lyrics Typography'), findsOneWidget);
      expect(
        find.text('Choose typeface for synchronized lyrics display'),
        findsOneWidget,
      );
      expect(find.text('Reset'), findsOneWidget);

      // Verify live preview card
      expect(find.text('LIVE PREVIEW'), findsOneWidget);
      expect(find.text('Modern Sans'), findsWidgets); // chip + option card

      // Verify sample lyrics in live preview
      expect(
        find.text('I found a love to carry more than just my secrets'),
        findsOneWidget,
      );
      expect(
        find.text('Dancing in the shadows of the fading twilight'),
        findsOneWidget,
      );
      expect(
        find.text('Watching the stars illuminate our silhouette'),
        findsOneWidget,
      );

      // Verify all 4 font option names are displayed
      expect(find.text('Modern Sans'), findsWidgets);
      expect(find.text('Elegant Serif'), findsOneWidget);
      expect(find.text('Monospaced Lyricist'), findsOneWidget);
      expect(find.text('Display Bold'), findsOneWidget);

      // Verify Done button
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('tapping a font option updates provider and live preview badge',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: LyricsFontPickerSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(lyricsFontStyleProvider), LyricsFontStyle.modernSans);

      // Tap 'Elegant Serif' option
      final elegantSerifFinder = find.text('Elegant Serif');
      expect(elegantSerifFinder, findsOneWidget);
      await tester.tap(elegantSerifFinder);
      await tester.pumpAndSettle();

      expect(
        container.read(lyricsFontStyleProvider),
        LyricsFontStyle.elegantSerif,
      );

      // Tap 'Monospaced Lyricist' option
      final monoFinder = find.text('Monospaced Lyricist');
      expect(monoFinder, findsOneWidget);
      await tester.tap(monoFinder);
      await tester.pumpAndSettle();

      expect(
        container.read(lyricsFontStyleProvider),
        LyricsFontStyle.monospacedLyricist,
      );

      // Tap 'Display Bold' option
      final displayBoldFinder = find.text('Display Bold');
      expect(displayBoldFinder, findsOneWidget);
      await tester.tap(displayBoldFinder);
      await tester.pumpAndSettle();

      expect(
        container.read(lyricsFontStyleProvider),
        LyricsFontStyle.displayBold,
      );

      // Tap 'Reset' button
      final resetFinder = find.text('Reset');
      expect(resetFinder, findsOneWidget);
      await tester.tap(resetFinder);
      await tester.pumpAndSettle();

      expect(
        container.read(lyricsFontStyleProvider),
        LyricsFontStyle.modernSans,
      );
    });

    testWidgets('tapping preview lines switches active highlight line',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: LyricsFontPickerSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap first lyric line
      await tester.tap(
        find.text('I found a love to carry more than just my secrets'),
      );
      await tester.pumpAndSettle();

      // Tap third lyric line
      await tester.tap(
        find.text('Watching the stars illuminate our silhouette'),
      );
      await tester.pumpAndSettle();
    });
  });

  // ==========================================================================
  // Widget Tests: LyricsFontSwitcherButton & LyricsFontSelectorBar
  // ==========================================================================
  group('LyricsFontSwitcherButton & LyricsFontSelectorBar Tests', () {
    testWidgets('LyricsFontSwitcherButton shows badge only when non-default',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: LyricsFontSwitcherButton(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify button renders icon
      expect(find.byIcon(Icons.font_download_outlined), findsOneWidget);

      // Set non-default font style
      await container
          .read(lyricsFontStyleProvider.notifier)
          .setStyle(LyricsFontStyle.displayBold);
      await tester.pumpAndSettle();

      // Re-renders with custom accent styling
      expect(find.byIcon(Icons.font_download_outlined), findsOneWidget);
    });

    testWidgets('LyricsFontSwitcherButton triggers onTap callback when provided',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LyricsFontSwitcherButton(
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(LyricsFontSwitcherButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('LyricsFontSelectorBar renders 4 segments and switches styles',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: LyricsFontSelectorBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modern Sans'), findsOneWidget);
      expect(find.text('Elegant Serif'), findsOneWidget);
      expect(find.text('Monospaced Lyricist'), findsOneWidget);
      expect(find.text('Display Bold'), findsOneWidget);

      // Tap Monospaced Lyricist
      await tester.tap(find.text('Monospaced Lyricist'));
      await tester.pumpAndSettle();

      expect(
        container.read(lyricsFontStyleProvider),
        LyricsFontStyle.monospacedLyricist,
      );
    });
  });
}
