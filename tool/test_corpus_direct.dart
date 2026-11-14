import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final queries = [
    'The Weeknd Blinding Lights',
    'Dua Lipa Levitating',
    'Ed Sheeran Shape of You',
    'Harry Styles As It Was',
    'Beach House Space Song',
  ];

  print('Starting Corpus Verification Spike...');
  int passed = 0;

  for (final q in queries) {
    final sw = Stopwatch()..start();
    try {
      final searchResults = await yt.search.search(q);
      if (searchResults.isEmpty) throw Exception('Search empty');
      final video = searchResults.first;

      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final audioStreams = manifest.audioOnly.where((s) => s.container.name == 'mp4').toList();
      final chosen = audioStreams.isNotEmpty ? audioStreams.first : manifest.audioOnly.first;

      // Verify HTTP fetch with headers
      final client = HttpClient();
      final req = await client.getUrl(chosen.url);
      req.headers.set('User-Agent', 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
      req.headers.set('Range', 'bytes=0-1024');
      final res = await req.close();
      final ok = res.statusCode == 200 || res.statusCode == 206;
      final chunk = ok ? await res.take(1).first : [];
      client.close();

      sw.stop();
      if (ok && chunk.isNotEmpty) {
        passed++;
        print('✅ PASS: "$q" -> "${video.title}" | itag ${chosen.tag} (${chosen.bitrate.kiloBitsPerSecond.round()} kbps) | TTFA: ${sw.elapsedMilliseconds}ms');
      } else {
        print('❌ FAIL HTTP status: ${res.statusCode} for "$q"');
      }
    } catch (e) {
      sw.stop();
      print('❌ ERROR for "$q": $e (${sw.elapsedMilliseconds}ms)');
    }
  }

  print('\nSummary: $passed / ${queries.length} passed (${(passed / queries.length) * 100}%)');
  yt.close();
}
