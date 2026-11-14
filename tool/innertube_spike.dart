import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();

  final clientsToTest = [
    {
      'name': 'IOS',
      'clientName': 'IOS',
      'clientVersion': '19.45.4',
      'userAgent': 'com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)',
    },
    {
      'name': 'TV_EMBEDDED',
      'clientName': 'TV_HTML5_EMBEDDED',
      'clientVersion': '2.0',
      'userAgent': 'Mozilla/5.0 (SMART-TV; Linux; Tizen 5.0) AppleWebKit/538.1',
    },
    {
      'name': 'WEB_EMBEDDED',
      'clientName': 'WEB_EMBEDDED_PLAYER',
      'clientVersion': '1.20240901.01.00',
      'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
    {
      'name': 'ANDROID_VR',
      'clientName': 'ANDROID_VR',
      'clientVersion': '1.56.21',
      'userAgent': 'com.google.android.apps.youtube.vr/1.56.21 (Linux; U; Android 10)',
    },
    {
      'name': 'ANDROID_TESTSUITE',
      'clientName': 'ANDROID_TESTSUITE',
      'clientVersion': '1.9',
      'userAgent': 'com.google.android.youtube/1.9 (Linux; U; Android 11)',
    },
  ];

  for (final c in clientsToTest) {
    print('Testing client: ${c['name']}...');
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player');
    final req = await client.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('User-Agent', c['userAgent']!);

    final payload = {
      'context': {
        'client': {
          'clientName': c['clientName'],
          'clientVersion': c['clientVersion'],
          'hl': 'en',
        }
      },
      'videoId': '4NRXx6U8ABQ',
    };
    req.write(jsonEncode(payload));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;

    final status = json['playabilityStatus']?['status'];
    final streamingData = json['streamingData'];
    if (streamingData != null) {
      final formats = (streamingData['adaptiveFormats'] as List<dynamic>?) ?? [];
      final audioFormats = formats.where((f) => (f['mimeType'] as String? ?? '').contains('audio')).toList();
      print('  🎉 SUCCESS! Playable! Audio formats count: ${audioFormats.length}');
      for (final af in audioFormats.take(3)) {
        final itag = af['itag'];
        final mime = af['mimeType'];
        final bitrate = (af['bitrate'] as num?)?.toInt() ?? 0;
        final hasUrl = af.containsKey('url');
        print('     -> itag: $itag | mime: $mime | bitrate: ${bitrate ~/ 1000}kbps | direct URL: $hasUrl');
      }
      break;
    } else {
      print('  ❌ Status: $status (${json['playabilityStatus']?['reason']})');
    }
  }

  client.close();
}
