import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    print('1. Searching for The Weeknd Blinding Lights...');
    final results = await yt.search.search('The Weeknd Blinding Lights');
    final top = results.first;
    print('Found: ${top.title} (${top.id.value})');

    print('\n2. Calling getManifest with default client...');
    final manifest = await yt.videos.streamsClient.getManifest(top.id);
    print('Manifest retrieved! Audio streams count: ${manifest.audioOnly.length}');
    for (final s in manifest.audioOnly) {
      print('  Stream: itag ${s.tag}, bitrate ${s.bitrate.kiloBitsPerSecond.round()} kbps, container ${s.container.name}, codec ${s.audioCodec}');
    }

    final chosen = manifest.audioOnly.where((s) => s.container.name == 'mp4').firstOrNull ?? manifest.audioOnly.first;
    print('STREAM_URL: ${chosen.url}');
    print('\n3. Testing HTTP request to stream URL with Android User-Agent and Range header:');
    final client = HttpClient();
    final req = await client.getUrl(chosen.url);
    req.headers.set('User-Agent', 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
    req.headers.set('Range', 'bytes=0-1024');
    final res = await req.close();
    print('HTTP status code: ${res.statusCode}');
    print('Response headers content-range: ${res.headers.value(HttpHeaders.contentRangeHeader)}');
    print('Response headers content-length: ${res.headers.value(HttpHeaders.contentLengthHeader)}');
    if (res.statusCode == 200 || res.statusCode == 206) {
      final chunk = await res.take(1).first;
      print('🎉🎉🎉 SUCCESS! Audio chunk received: ${chunk.length} bytes!');
    }
    client.close();
  } catch (e, st) {
    print('❌ Error: $e\n$st');
  } finally {
    yt.close();
  }
}
