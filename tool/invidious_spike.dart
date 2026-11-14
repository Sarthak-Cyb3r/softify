import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 5);

  print('Fetching public Invidious instances from api.invidious.io...');
  List<String> instances = [];
  try {
    final req = await client.getUrl(Uri.parse('https://api.invidious.io/instances.json?sort_by=health'));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as List<dynamic>;
    for (final item in json) {
      final name = item[0] as String;
      final data = item[1] as Map<String, dynamic>;
      final api = data['api'] as bool? ?? false;
      final type = data['type'] as String? ?? '';
      final uri = data['uri'] as String? ?? '';
      if (api && type == 'https' && uri.isNotEmpty) {
        instances.add(uri);
      }
    }
  } catch (e) {
    print('Error fetching instances: $e');
  }

  // Backup static instances
  instances.addAll([
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://yewtu.be',
    'https://invidious.private.coffee',
    'https://iv.ggtyler.dev',
    'https://invidious.asir.dev',
    'https://yt.artemislena.eu',
  ]);
  instances = instances.toSet().toList();

  print('Found ${instances.length} Invidious instances. Testing video 4NRXx6U8ABQ...');

  for (final inst in instances.take(10)) {
    try {
      final sw = Stopwatch()..start();
      final uri = Uri.parse('$inst/api/v1/videos/4NRXx6U8ABQ');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 6));
      final res = await req.close().timeout(const Duration(seconds: 6));
      sw.stop();

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final formats = (json['adaptiveFormats'] as List<dynamic>?) ?? [];
        final audio = formats.where((f) => (f['type'] as String? ?? '').contains('audio')).toList();
        print('  🎉 $inst: SUCCESS in ${sw.elapsedMilliseconds}ms (${audio.length} audio streams)');
        for (final a in audio.take(3)) {
          final itag = a['itag'];
          final container = a['container'];
          final bitrate = (a['bitrate'] as num?)?.toInt() ?? 0;
          final url = a['url'] as String? ?? '';
          print('     -> itag: $itag | container: $container | bitrate: ${bitrate ~/ 1000}kbps | url valid: ${url.startsWith("http")}');
        }
        break;
      } else {
        print('  ⚠️ $inst: HTTP ${res.statusCode}');
      }
    } catch (e) {
      print('  ❌ $inst: $e');
    }
  }

  client.close();
}
