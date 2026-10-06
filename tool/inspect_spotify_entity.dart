import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  const playlistId = '37i9dQZF1DXcBWIGoYBM5M';
  final embedUrl = Uri.parse('https://open.spotify.com/embed/playlist/$playlistId');

  try {
    final req = await client.getUrl(embedUrl);
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();

    final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">([^<]+)<\/script>').firstMatch(body);
    if (nextDataMatch != null) {
      final jsonStr = nextDataMatch.group(1)!;
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final entity = parsed['props']?['pageProps']?['state']?['data']?['entity'];
      print('Entity keys: ${entity?.keys}');
      print('Playlist name: ${entity?['name'] ?? entity?['title']}');
      print('Playlist subtitle/desc: ${entity?['subtitle']}');
      print('Visual identity: ${entity?['visualIdentity']}');
      print('Cover art: ${entity?['coverArt'] ?? entity?['images']}');

      final trackList = (entity?['trackList'] as List<dynamic>?) ?? [];
      if (trackList.isNotEmpty) {
        final firstTrack = trackList.first as Map<String, dynamic>;
        print('\nFirst track keys: ${firstTrack.keys}');
        final encoder = const JsonEncoder.withIndent('  ');
        print(encoder.convert(firstTrack));
      }
    }
  } finally {
    client.close();
  }
}
