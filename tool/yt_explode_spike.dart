import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    final searchResults = await yt.search.search('The Weeknd Blinding Lights');
    final video = searchResults.first;
    print('✅ Video: "${video.title}" (${video.id.value})');
    print('Testing getManifest with requireWatchPage: false, androidMusic and ios...');
    final manifest = await yt.videos.streamsClient.getManifest(
      video.id,
      ytClients: [
        YoutubeApiClient.ios,
        YoutubeApiClient.androidMusic,
        YoutubeApiClient.tv,
      ],
      requireWatchPage: false,
    );
    print('Manifest retrieved! Streams: ${manifest.audioOnly.length}');
    for (final s in manifest.audioOnly) {
      print('  -> Tag: ${s.tag}, Bitrate: ${s.bitrate.kiloBitsPerSecond} kbps, Container: ${s.container.name}, Codec: ${s.audioCodec}');
    }
    final chosen = manifest.audioOnly.first;
    final client = HttpClient();
    final req = await client.getUrl(chosen.url);
    final res = await req.close();
    print('Stream HTTP response status: ${res.statusCode}');
    print('Content-Length: ${res.headers.value(HttpHeaders.contentLengthHeader)}');
    final firstChunk = await res.take(1).first;
    print('✅ SUCCESS! Received ${firstChunk.length} audio bytes!');
    client.close();
  } catch (e, st) {
    print('❌ Error: $e\n$st');
  } finally {
    yt.close();
  }
}
