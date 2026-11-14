import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  // Today's Top Hits playlist ID
  const playlistId = '37i9dQZF1DXcBWIGoYBM5M';
  final embedUrl = Uri.parse('https://open.spotify.com/embed/playlist/$playlistId');

  try {
    print('Testing Spotify Embed URL: $embedUrl');
    final req = await client.getUrl(embedUrl);
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    final res = await req.close();
    print('Status: ${res.statusCode}');

    final body = await res.transform(utf8.decoder).join();
    print('Body length: ${body.length}');

    // Look for __NEXT_DATA__ or resource json
    final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">([^<]+)<\/script>').firstMatch(body);
    if (nextDataMatch != null) {
      print('Found __NEXT_DATA__!');
      final jsonStr = nextDataMatch.group(1)!;
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final entity = parsed['props']?['pageProps']?['state']?['data']?['entity'];
      print('Entity title: ${entity?['title'] ?? entity?['name']}');
      final trackList = entity?['trackList'] as List<dynamic>?;
      print('TrackList count: ${trackList?.length}');
      if (trackList != null && trackList.isNotEmpty) {
        for (final t in trackList.take(5)) {
          print('  - ${t['title']} by ${t['subtitle']} (${t['duration']}ms)');
        }
      }
    } else {
      print('__NEXT_DATA__ not found. Checking other script tags...');
      final sessionMatch = RegExp(r'<script id="session" data-testid="session" type="application/json">([^<]+)<\/script>').firstMatch(body);
      if (sessionMatch != null) {
        print('Found session script!');
      }
      final scriptMatches = RegExp(r'<script[^>]*>([\s\S]*?)<\/script>').allMatches(body);
      print('Total script tags: ${scriptMatches.length}');
      for (final m in scriptMatches) {
        final content = m.group(1) ?? '';
        if (content.contains('trackList') || content.contains('track')) {
          print('Found script with track info! Length: ${content.length}');
          if (content.length < 500) {
            print(content);
          }
        }
      }
    }
  } catch (e, st) {
    print('Error: $e\n$st');
  } finally {
    client.close();
  }
}
