import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/track_share_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTrackYt = Track(
    id: 'yt_dQw4w9WgXcQ',
    sourceId: 'yt_dQw4w9WgXcQ',
    title: 'Never Gonna Give You Up',
    artist: 'Rick Astley',
    album: 'Whenever You Need Somebody',
    duration: Duration(seconds: 213),
    coverUrl: 'https://example.com/cover.jpg',
  );

  const testTrackSpotify = Track(
    id: 'spotify_4cOdK2wGLETKBW3PvgPWqT',
    sourceId: 'spotify_4cOdK2wGLETKBW3PvgPWqT',
    title: 'Never Gonna Give You Up',
    artist: 'Rick Astley',
    album: 'Whenever You Need Somebody',
    duration: Duration(seconds: 213),
    coverUrl: 'https://example.com/cover.jpg',
  );

  group('TrackShareHelper URL and Info resolution', () {
    test('getTrackInfo formats as "Title" by Artist', () {
      final text = TrackShareHelper.getTrackInfo(testTrackYt);
      expect(text, equals('"Never Gonna Give You Up" by Rick Astley'));
    });

    test('getYoutubeLink resolves direct YouTube video URL', () {
      final link = TrackShareHelper.getYoutubeLink(testTrackYt);
      expect(link, equals('https://music.youtube.com/watch?v=dQw4w9WgXcQ'));
    });

    test('getYoutubeLink falls back to search URL when no id present', () {
      const fallbackTrack = Track(
        id: '',
        sourceId: '',
        title: 'Custom Title',
        artist: 'Custom Artist',
        duration: Duration.zero,
      );
      final link = TrackShareHelper.getYoutubeLink(fallbackTrack);
      expect(
        link,
        equals(
          'https://music.youtube.com/search?q=${Uri.encodeComponent('Custom Artist - Custom Title')}',
        ),
      );
    });

    test('getSpotifyLink extracts track id for spotify_ prefix', () {
      final link = TrackShareHelper.getSpotifyLink(testTrackSpotify);
      expect(
        link,
        equals('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT'),
      );
    });

    test('getSpotifyLink returns null for non-spotify track', () {
      final link = TrackShareHelper.getSpotifyLink(testTrackYt);
      expect(link, isNull);
    });

    test('getShareLink returns Spotify link when available, else YouTube', () {
      expect(
        TrackShareHelper.getShareLink(testTrackSpotify),
        equals('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT'),
      );
      expect(
        TrackShareHelper.getShareLink(testTrackYt),
        equals('https://music.youtube.com/watch?v=dQw4w9WgXcQ'),
      );
    });
  });

  group('TrackShareHelper Clipboard interactions', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            return null;
          }
          if (methodCall.method == 'Clipboard.getData') {
            return {'text': '"Never Gonna Give You Up" by Rick Astley'};
          }
          return null;
        },
      );
    });

    testWidgets('copyTrackInfoToClipboard copies info to clipboard',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => TrackShareHelper.copyTrackInfoToClipboard(
                  context,
                  testTrackYt,
                ),
                child: const Text('Copy Info'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy Info'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('Never Gonna Give You Up'),
        findsOneWidget,
      );
    });

    testWidgets('copyShareLink copies link to clipboard', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => TrackShareHelper.copyShareLink(
                  context,
                  testTrackYt,
                ),
                child: const Text('Copy Link'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy Link'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('copied to clipboard'),
        findsOneWidget,
      );
    });

    testWidgets('showShareModal presents options sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => TrackShareHelper.showShareModal(
                  context,
                  testTrackYt,
                ),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Copy Title & Artist'), findsOneWidget);
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('Share via System Intent'), findsOneWidget);
      expect(find.text('Never Gonna Give You Up'), findsOneWidget);
    });
  });
}
