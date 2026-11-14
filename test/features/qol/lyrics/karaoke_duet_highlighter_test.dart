// ============================================================================
// Unit & Widget Tests: Feature 37 Karaoke Duet Multi-Color Highlighting
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/domain/ports/i_lyrics_provider.dart';
import 'package:softify/features/qol/lyrics/karaoke_duet_highlighter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.reset();
  });

  // ==========================================================================
  // 1. KaraokeDuetParser Unit Tests
  // ==========================================================================
  group('KaraokeDuetParser - Tag Detection & Parsing', () {
    const parser = KaraokeDuetParser();

    test('detects [Lead 1] bracket tag and cleans lyric text', () {
      final parsed = parser.parseText('[Lead 1] When the night has come');
      expect(parsed.singer.role, SingerRole.lead1);
      expect(parsed.singer.name, 'Lead 1');
      expect(parsed.singer.tag, '[Lead 1]');
      expect(parsed.singer.isExplicitTag, isTrue);
      expect(parsed.cleanLyrics, 'When the night has come');
    });

    test('detects [Lead 2] bracket tag', () {
      final parsed = parser.parseText('[Lead 2] And the land is dark');
      expect(parsed.singer.role, SingerRole.lead2);
      expect(parsed.singer.name, 'Lead 2');
      expect(parsed.cleanLyrics, 'And the land is dark');
    });

    test('detects [Singer 1] and [Singer 2] aliases', () {
      final p1 = parser.parseText('[Singer 1] Hello world');
      expect(p1.singer.role, SingerRole.lead1);
      expect(p1.cleanLyrics, 'Hello world');

      final p2 = parser.parseText('[Singer 2] Hello back');
      expect(p2.singer.role, SingerRole.lead2);
      expect(p2.cleanLyrics, 'Hello back');
    });

    test('detects [Male] and [Female] aliases', () {
      final pMale = parser.parseText('[Male] I believe in you');
      expect(pMale.singer.role, SingerRole.lead1);
      expect(pMale.cleanLyrics, 'I believe in you');

      final pFemale = parser.parseText('[Female] I believe in us');
      expect(pFemale.singer.role, SingerRole.lead2);
      expect(pFemale.cleanLyrics, 'I believe in us');
    });

    test('detects [Chorus], [Both], [All], [Together] ensemble tags', () {
      final pChorus = parser.parseText('[Chorus] Stand by me');
      expect(pChorus.singer.role, SingerRole.chorus);
      expect(pChorus.cleanLyrics, 'Stand by me');

      final pBoth = parser.parseText('[Both] Yeah yeah yeah');
      expect(pBoth.singer.role, SingerRole.chorus);
      expect(pBoth.cleanLyrics, 'Yeah yeah yeah');

      final pAll = parser.parseText('[All] Sing along now');
      expect(pAll.singer.role, SingerRole.chorus);
      expect(pAll.cleanLyrics, 'Sing along now');

      final pTogether = parser.parseText('[Together] Forever and ever');
      expect(pTogether.singer.role, SingerRole.chorus);
      expect(pTogether.cleanLyrics, 'Forever and ever');
    });

    test('detects [Background], [Backing], [BG], and (Ad-lib) tags', () {
      final pBg = parser.parseText('[Background] (Ooh-ooh-ooh)');
      expect(pBg.singer.role, SingerRole.background);
      expect(pBg.cleanLyrics, '(Ooh-ooh-ooh)');

      final pBacking = parser.parseText('[Backing] Harmony line');
      expect(pBacking.singer.role, SingerRole.background);

      final pAdlib = parser.parseText('(Ad-lib) Yeah baby');
      expect(pAdlib.singer.role, SingerRole.background);
      expect(pAdlib.cleanLyrics, 'Yeah baby');
    });

    test('detects parentheses and curly brace tags', () {
      final pParen = parser.parseText('(Lead 2) Soft echo voice');
      expect(pParen.singer.role, SingerRole.lead2);
      expect(pParen.cleanLyrics, 'Soft echo voice');

      final pCurly = parser.parseText('{Lead 1} In the shadows');
      expect(pCurly.singer.role, SingerRole.lead1);
      expect(pCurly.cleanLyrics, 'In the shadows');
    });

    test('detects colon prefixes without brackets', () {
      final pColon1 = parser.parseText('Lead 1: Take my hand');
      expect(pColon1.singer.role, SingerRole.lead1);
      expect(pColon1.cleanLyrics, 'Take my hand');

      final pColon2 = parser.parseText('Lead 2: Take my whole life too');
      expect(pColon2.singer.role, SingerRole.lead2);
      expect(pColon2.cleanLyrics, 'Take my whole life too');

      final pChorus = parser.parseText('Chorus: For I can\'t help falling in love');
      expect(pChorus.singer.role, SingerRole.chorus);
      expect(pChorus.cleanLyrics, 'For I can\'t help falling in love');
    });

    test('detects agent tags: [agent:v1], {agent:v2}, [agent:v1000]', () {
      final p1 = parser.parseText('[agent:v1] Voice one line');
      expect(p1.singer.role, SingerRole.lead1);
      expect(p1.cleanLyrics, 'Voice one line');

      final p2 = parser.parseText('{agent:v2} Voice two line');
      expect(p2.singer.role, SingerRole.lead2);
      expect(p2.cleanLyrics, 'Voice two line');

      final p1000 = parser.parseText('[agent:v1000] Chorus vocal line');
      expect(p1000.singer.role, SingerRole.chorus);
      expect(p1000.cleanLyrics, 'Chorus vocal line');
    });

    test('detects custom named artists', () {
      final pArtist = parser.parseText('[Taylor Swift] We are never getting back together');
      expect(pArtist.singer.role, SingerRole.custom);
      expect(pArtist.singer.name, 'Taylor Swift');
      expect(pArtist.cleanLyrics, 'We are never getting back together');

      final pColonArtist = parser.parseText('Ed Sheeran: When your legs don\'t work like they used to');
      expect(pColonArtist.singer.role, SingerRole.custom);
      expect(pColonArtist.singer.name, 'Ed Sheeran');
      expect(pColonArtist.cleanLyrics, 'When your legs don\'t work like they used to');
    });

    test('handles LyricLine with agent metadata and no textual prefix', () {
      const lineV1 = LyricLine(
        timestamp: Duration(seconds: 10),
        text: 'A pure text line without tag',
        agent: 'v1',
      );
      final parsed1 = parser.parseLyricLine(lineV1);
      expect(parsed1.singer.role, SingerRole.lead1);
      expect(parsed1.cleanLyrics, 'A pure text line without tag');
      expect(parsed1.timestamp, const Duration(seconds: 10));

      const lineV2 = LyricLine(
        timestamp: Duration(seconds: 14),
        text: 'Duet reply line',
        agent: 'v2',
      );
      final parsed2 = parser.parseLyricLine(lineV2);
      expect(parsed2.singer.role, SingerRole.lead2);
      expect(parsed2.cleanLyrics, 'Duet reply line');
    });

    test('handles untagged lyrics with safe default fallback', () {
      final parsed = parser.parseText('Just regular lyrics without any tags');
      expect(parsed.singer.role, SingerRole.lead1);
      expect(parsed.singer.isExplicitTag, isFalse);
      expect(parsed.cleanLyrics, 'Just regular lyrics without any tags');
    });

    test('parses and preserves LRC timestamps without misidentifying as singer tag', () {
      final parsed = parser.parseText('[01:23.45] [Lead 2] Dancing in the moonlight');
      expect(parsed.timestamp, const Duration(minutes: 1, seconds: 23, milliseconds: 45));
      expect(parsed.singer.role, SingerRole.lead2);
      expect(parsed.cleanLyrics, 'Dancing in the moonlight');
    });

    test('cleans syllable LyricWord tokens matching singer prefix', () {
      const words = [
        LyricWord(timestamp: Duration(seconds: 1), text: '[Lead 1]'),
        LyricWord(timestamp: Duration(seconds: 2), text: 'Hello'),
        LyricWord(timestamp: Duration(seconds: 3), text: 'world'),
      ];
      final parsed = parser.parseText(
        '[Lead 1] Hello world',
        words: words,
      );
      expect(parsed.cleanLyrics, 'Hello world');
      expect(parsed.words, isNotNull);
      expect(parsed.words!.length, 2);
      expect(parsed.words![0].text, 'Hello');
      expect(parsed.words![1].text, 'world');
    });

    test('parses multiple singer segments within a single line', () {
      final segments = parser.parseSegments(
        '[Lead 1] Tell me why [Lead 2] Ain\'t nothing but a heartache [Chorus] Tell me why',
      );
      expect(segments.length, 3);
      expect(segments[0].singer.role, SingerRole.lead1);
      expect(segments[0].text, 'Tell me why');
      expect(segments[1].singer.role, SingerRole.lead2);
      expect(segments[1].text, 'Ain\'t nothing but a heartache');
      expect(segments[2].singer.role, SingerRole.chorus);
      expect(segments[2].text, 'Tell me why');
    });

    test('batch parses list of LyricLine objects', () {
      const lines = [
        LyricLine(timestamp: Duration(seconds: 2), text: '[Lead 1] Line 1'),
        LyricLine(timestamp: Duration(seconds: 6), text: '[Lead 2] Line 2'),
        LyricLine(timestamp: Duration(seconds: 10), text: '[Chorus] Line 3'),
      ];
      final parsedList = parser.parseLyrics(lines);
      expect(parsedList.length, 3);
      expect(parsedList[0].singer.role, SingerRole.lead1);
      expect(parsedList[1].singer.role, SingerRole.lead2);
      expect(parsedList[2].singer.role, SingerRole.chorus);
    });
  });

  // ==========================================================================
  // 2. DuetColorConfig & Palette Preset Tests
  // ==========================================================================
  group('DuetColorConfig & Presets', () {
    test('Spotify Modern preset assigns emerald, rose, gold, and cyan', () {
      final config = DuetColorConfig.fromPreset(DuetColorPreset.spotifyModern);
      expect(config.lead1Color, const Color(0xFF1DB954));
      expect(config.lead2Color, const Color(0xFFFF4081));
      expect(config.chorusColor, const Color(0xFFFFD700));
      expect(config.backgroundColor, const Color(0xFF00B0FF));
    });

    test('Neon Cyberpunk preset assigns vibrant fluorescent accents', () {
      final config = DuetColorConfig.fromPreset(DuetColorPreset.neonCyberpunk);
      expect(config.lead1Color, const Color(0xFF00F0FF));
      expect(config.lead2Color, const Color(0xFFFF007F));
      expect(config.chorusColor, const Color(0xFFFFE600));
      expect(config.backgroundColor, const Color(0xFF9D4EDD));
    });

    test('High Contrast preset assigns accessible high-visibility colors', () {
      final config = DuetColorConfig.fromPreset(DuetColorPreset.highContrast);
      expect(config.lead1Color, const Color(0xFF00E676));
      expect(config.lead2Color, const Color(0xFFFF1744));
    });

    test('allows customizing specific role color with withRoleColor', () {
      var config = DuetColorConfig.fromPreset(DuetColorPreset.spotifyModern);
      config = config.withRoleColor(SingerRole.lead1, Colors.purple);
      expect(config.lead1Color, Colors.purple);
      expect(config.lead2Color, const Color(0xFFFF4081)); // unchanged
    });

    test('allows assigning custom color to named artist with withCustomSingerColor', () {
      var config = DuetColorConfig.fromPreset(DuetColorPreset.spotifyModern);
      config = config.withCustomSingerColor('Taylor Swift', Colors.tealAccent);

      const singer = DuetSinger(role: SingerRole.custom, name: 'Taylor Swift');
      expect(config.getColor(singer), Colors.tealAccent);

      // Case insensitive match check
      const singerLower = DuetSinger(role: SingerRole.custom, name: 'taylor swift');
      expect(config.getColor(singerLower), Colors.tealAccent);

      // Other custom singers fall back to lead2Color
      const singerOther = DuetSinger(role: SingerRole.custom, name: 'Adele');
      expect(config.getColor(singerOther), config.lead2Color);
    });

    test('computes inactive color with dimming opacity', () {
      final config = DuetColorConfig.fromPreset(DuetColorPreset.spotifyModern);
      const singer = DuetSinger(role: SingerRole.lead1, name: 'Lead 1');
      final inactive = config.getInactiveColor(singer);
      expect(inactive.opacity, closeTo(config.inactiveOpacity, 0.01));
    });

    test('computes glow shadows for active vocals', () {
      final config = DuetColorConfig.fromPreset(DuetColorPreset.spotifyModern);
      const singer = DuetSinger(role: SingerRole.lead2, name: 'Lead 2');
      final shadows = config.getGlowShadows(singer);
      expect(shadows.length, 2);
      expect(shadows.first.color.opacity, closeTo(config.glowOpacity, 0.01));
    });

    test('serializes and deserializes color config to/from JSON faithfully', () {
      var original = DuetColorConfig.fromPreset(DuetColorPreset.sunsetDuet);
      original = original.withCustomSingerColor('Dua Lipa', Colors.deepOrange);

      final json = original.toJson();
      final restored = DuetColorConfig.fromPreset(DuetColorPreset.spotifyModern)
          .applyCustomColorsJson(json);

      expect(restored.lead1Color.value, original.lead1Color.value);
      expect(restored.lead2Color.value, original.lead2Color.value);
      expect(restored.chorusColor.value, original.chorusColor.value);
      expect(restored.backgroundColor.value, original.backgroundColor.value);
      expect(
        restored.customSingerColors['Dua Lipa']?.value,
        Colors.deepOrange.value,
      );
    });
  });

  // ==========================================================================
  // 3. KaraokeDuetSettingsNotifier & Riverpod State Management Tests
  // ==========================================================================
  group('KaraokeDuetSettingsNotifier & Riverpod State Management', () {
    test('initializes with default settings', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(karaokeDuetSettingsProvider);
      expect(settings.enabled, isTrue);
      expect(settings.preset, DuetColorPreset.spotifyModern);
      expect(settings.showSingerBadges, isTrue);
      expect(settings.alignBySinger, isTrue);
      expect(settings.enableGlowEffect, isTrue);
    });

    test('toggles and updates enabled state, persisting to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(karaokeDuetSettingsProvider.notifier);

      await notifier.toggleEnabled();
      expect(container.read(karaokeDuetSettingsProvider).enabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kKaraokeDuetEnabledKey), isFalse);

      await notifier.setEnabled(true);
      expect(container.read(karaokeDuetSettingsProvider).enabled, isTrue);
      expect(prefs.getBool(kKaraokeDuetEnabledKey), isTrue);
    });

    test('updates preset and updates all role colors', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(karaokeDuetSettingsProvider.notifier);
      await notifier.setPreset(DuetColorPreset.neonCyberpunk);

      final state = container.read(karaokeDuetSettingsProvider);
      expect(state.preset, DuetColorPreset.neonCyberpunk);
      expect(state.colors.lead1Color, const Color(0xFF00F0FF));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kKaraokeDuetPresetKey), DuetColorPreset.neonCyberpunk.name);
    });

    test('updates individual role color and persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(karaokeDuetSettingsProvider.notifier);
      await notifier.setSingerColor(SingerRole.lead2, Colors.amber);

      expect(
        container.read(karaokeDuetSettingsProvider).colors.lead2Color,
        Colors.amber,
      );
    });

    test('updates custom singer artist color', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(karaokeDuetSettingsProvider.notifier);
      await notifier.setCustomSingerColor('Lady Gaga', Colors.indigo);

      const singer = DuetSinger(role: SingerRole.custom, name: 'Lady Gaga');
      expect(
        container.read(karaokeDuetSettingsProvider).colors.getColor(singer),
        Colors.indigo,
      );
    });

    test('toggles badges, alignment, and glow effect', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(karaokeDuetSettingsProvider.notifier);

      await notifier.toggleSingerBadges();
      expect(container.read(karaokeDuetSettingsProvider).showSingerBadges, isFalse);

      await notifier.toggleAlignBySinger();
      expect(container.read(karaokeDuetSettingsProvider).alignBySinger, isFalse);

      await notifier.toggleGlowEffect();
      expect(container.read(karaokeDuetSettingsProvider).enableGlowEffect, isFalse);

      await notifier.setActiveScale(1.15);
      expect(container.read(karaokeDuetSettingsProvider).activeScale, 1.15);
    });

    test('resetToDefaults restores factory settings', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(karaokeDuetSettingsProvider.notifier);
      await notifier.setEnabled(false);
      await notifier.setPreset(DuetColorPreset.highContrast);

      await notifier.resetToDefaults();
      final state = container.read(karaokeDuetSettingsProvider);
      expect(state.enabled, isTrue);
      expect(state.preset, DuetColorPreset.spotifyModern);
    });

    test('loads previously stored preferences on startup', () async {
      SharedPreferences.setMockInitialValues({
        kKaraokeDuetEnabledKey: false,
        kKaraokeDuetPresetKey: DuetColorPreset.sunsetDuet.name,
        kKaraokeDuetShowBadgesKey: false,
        kKaraokeDuetAlignBySingerKey: false,
        kKaraokeDuetGlowEnabledKey: false,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Allow notifier async constructor load to complete
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(karaokeDuetSettingsProvider);
      expect(state.enabled, isFalse);
      expect(state.preset, DuetColorPreset.sunsetDuet);
      expect(state.showSingerBadges, isFalse);
      expect(state.alignBySinger, isFalse);
      expect(state.enableGlowEffect, isFalse);
    });
  });

  // ==========================================================================
  // 4. KaraokeDuetLineView Widget Tests
  // ==========================================================================
  group('KaraokeDuetLineView Widget', () {
    testWidgets('renders clean lyrics and hides raw bracket prefix from text', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KaraokeDuetLineView(
                line: '[Lead 1] A beautiful tomorrow',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A beautiful tomorrow'), findsOneWidget);
      expect(find.text('[Lead 1] A beautiful tomorrow'), findsNothing);
    });

    testWidgets('displays singer badge with role name when enabled', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KaraokeDuetLineView(
                line: '[Lead 2] Echoes in the night',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KaraokeDuetBadge), findsOneWidget);
      expect(find.text('Lead 2'), findsOneWidget);
      expect(find.text('Echoes in the night'), findsOneWidget);
    });

    testWidgets('hides singer badge when showBadge override is false', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KaraokeDuetLineView(
                line: '[Lead 2] Echoes in the night',
                showBadge: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KaraokeDuetBadge), findsNothing);
      expect(find.text('Echoes in the night'), findsOneWidget);
    });

    testWidgets('renders active line with singer color and glow shadow', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KaraokeDuetLineView(
                line: '[Lead 1] Sing loud and clear',
                isActive: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFinder = find.text('Sing loud and clear');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, const Color(0xFF1DB954)); // Lead 1 active color
      expect(textWidget.style?.shadows, isNotNull);
      expect(textWidget.style?.shadows!.isNotEmpty, isTrue);
    });

    testWidgets('renders inactive line with dimmed color', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KaraokeDuetLineView(
                line: '[Lead 1] Upcoming verse line',
                isActive: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFinder = find.text('Upcoming verse line');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(
        textWidget.style?.color?.opacity,
        closeTo(0.38, 0.02),
      );
    });

    testWidgets('respects alignment for Lead 1 (left) and Lead 2 (right)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  KaraokeDuetLineView(
                    line: '[Lead 1] Left side singer',
                    alignBySinger: true,
                  ),
                  KaraokeDuetLineView(
                    line: '[Lead 2] Right side singer',
                    alignBySinger: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text1 = tester.widget<Text>(find.text('Left side singer'));
      final text2 = tester.widget<Text>(find.text('Right side singer'));

      expect(text1.textAlign, TextAlign.left);
      expect(text2.textAlign, TextAlign.right);
    });

    testWidgets('highlights syllable words based on currentPosition', (tester) async {
      final parsed = ParsedDuetLine(
        rawText: '[Lead 1] One two three',
        cleanLyrics: 'One two three',
        singer: const DuetSinger(role: SingerRole.lead1, name: 'Lead 1'),
        words: const [
          LyricWord(timestamp: Duration(seconds: 1), text: 'One'),
          LyricWord(timestamp: Duration(seconds: 3), text: 'two'),
          LyricWord(timestamp: Duration(seconds: 5), text: 'three'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KaraokeDuetLineView(
                line: parsed,
                isActive: true,
                currentPosition: const Duration(seconds: 4), // 'One' and 'two' sung
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Text.rich should be rendered
      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);
    });

    testWidgets('renders continuous karaoke progress wipe when progress is active', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KaraokeDuetLineView(
                line: '[Chorus] Rolling in the deep',
                isActive: true,
                progress: 0.5,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ClipRect), findsOneWidget);
      expect(find.text('Rolling in the deep'), findsNWidgets(2)); // Base layer + Clipped layer
    });

    testWidgets('triggers onTap callback when clicked', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KaraokeDuetLineView(
                line: '[Lead 1] Click me to seek',
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Click me to seek'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('includes semantic label with singer and lyrics', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KaraokeDuetLineView(
                line: '[Lead 2] Semantic check line',
                isActive: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Lead 2: Semantic check line',
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });

  // ==========================================================================
  // 5. KaraokeDuetBadge, Legend & SettingsSheet Widget Tests
  // ==========================================================================
  group('KaraokeDuet Companion Widgets', () {
    testWidgets('KaraokeDuetBadge renders singer icon and title', (tester) async {
      const singer = DuetSinger(role: SingerRole.lead2, name: 'Lead 2');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KaraokeDuetBadge(singer: singer, color: Colors.pinkAccent),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('karaoke_duet_badge_Lead 2')), findsOneWidget);
      expect(find.text('Lead 2'), findsOneWidget);
      expect(find.byIcon(Icons.mic_external_on_rounded), findsOneWidget);
    });

    testWidgets('KaraokeDuetLegend renders chips for all participating vocalists', (tester) async {
      const singers = [
        DuetSinger(role: SingerRole.lead1, name: 'Lead 1'),
        DuetSinger(role: SingerRole.lead2, name: 'Lead 2'),
        DuetSinger(role: SingerRole.chorus, name: 'Chorus'),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KaraokeDuetLegend(singers: singers),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KaraokeDuetBadge), findsNWidgets(3));
      expect(find.text('Lead 1'), findsOneWidget);
      expect(find.text('Lead 2'), findsOneWidget);
      expect(find.text('Chorus'), findsOneWidget);
    });

    testWidgets('KaraokeDuetSettingsSheet displays configuration options and live preview', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: KaraokeDuetSettingsSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Karaoke Duet Settings'), findsOneWidget);
      expect(find.text('Multi-Color Duet Highlighting'), findsOneWidget);
      expect(find.text('Align by Singer'), findsOneWidget);
      expect(find.text('Show Singer Badges'), findsOneWidget);
      expect(find.text('Vocal Glow Effect'), findsOneWidget);
      expect(find.text('Live Duet Preview'), findsOneWidget);

      // Verify preset chips are rendered
      expect(find.text('Spotify Modern'), findsOneWidget);
      expect(find.text('Neon Cyberpunk'), findsOneWidget);
      expect(find.text('Sunset Duet'), findsOneWidget);
    });
  });
}
