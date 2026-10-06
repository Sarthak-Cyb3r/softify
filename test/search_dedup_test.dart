import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/catalog/keyless_youtube_catalog.dart';

void main() {
  test('KeylessYouTubeCatalog search Tum Hi Ho returns single pristine Aashiqui 2 track', () async {
    final catalog = KeylessYouTubeCatalog();
    final results = await catalog.search('Tum Hi Ho', limit: 20);

    // Verify exactly ONE "Tum Hi Ho"
    final tumHiHoTracks = results.where((t) => t.title.toLowerCase() == 'tum hi ho').toList();
    expect(tumHiHoTracks.length, 1, reason: 'There must be only ONE "Tum Hi Ho" track, not duplicates!');
    
    final mainTrack = tumHiHoTracks.first;
    expect(mainTrack.id.startsWith('saavn_'), isTrue);
    expect(mainTrack.artist.contains('Arijit Singh'), isTrue);
    expect(mainTrack.album, 'Aashiqui 2');
    expect(mainTrack.duration.inSeconds, 262); // 4:22
  });
}
