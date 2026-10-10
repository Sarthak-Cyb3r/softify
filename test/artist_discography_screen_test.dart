import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/data/services/spotify_api_service.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/screens/artist_discography_screen.dart';

class _FakeAudioHandler extends Fake implements SoftifyAudioHandler {
  @override
  void setTrackSource(String source) {}

  @override
  Future<void> playTrack(Track track, {List<Track>? queue, int? startIndex}) async {}

  @override
  Duration get position => Duration.zero;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTrack1 = Track(
    id: 'disco_t1',
    sourceId: 'src_t1',
    title: 'Tum Hi Ho',
    artist: 'Arijit Singh',
    duration: Duration(seconds: 262),
  );

  const testTrack2 = Track(
    id: 'disco_t2',
    sourceId: 'src_t2',
    title: 'Channa Mereya',
    artist: 'Arijit Singh',
    duration: Duration(seconds: 289),
  );

  const testAlbum = SpotifyAlbumRef(
    id: 'alb_1',
    uri: 'spotify:album:alb1',
    name: 'Aashiqui 2',
    artist: 'Arijit Singh',
  );

  const testDisco = ArtistDiscography(
    artistName: 'Arijit Singh',
    artistUri: 'spotify:artist:arijit',
    allTracks: [testTrack1, testTrack2],
    albums: [testAlbum],
  );

  testWidgets('ArtistDiscographyScreen renders artist info, albums, and tracks correctly', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(_FakeAudioHandler()),
          isTrackLikedProvider(testTrack1.id).overrideWith((ref) => Stream.value(false)),
          isTrackLikedProvider(testTrack2.id).overrideWith((ref) => Stream.value(false)),
        ],
        child: const MaterialApp(
          home: ArtistDiscographyScreen(disco: testDisco),
        ),
      ),
    );

    await tester.pump();

    // Verify Artist name & complete discography tag
    expect(find.text('Arijit Singh'), findsWidgets);
    expect(find.text('COMPLETE DISCOGRAPHY'), findsOneWidget);
    expect(find.text('Play All'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);

    // Verify Albums section
    expect(find.text('Albums & Releases'), findsOneWidget);
    expect(find.text('Aashiqui 2'), findsOneWidget);

    // Verify All Songs
    expect(find.text('All Songs'), findsOneWidget);
    expect(find.text('Tum Hi Ho'), findsOneWidget);
    expect(find.text('Channa Mereya'), findsOneWidget);
  });
}
