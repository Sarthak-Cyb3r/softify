import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 4);

  // Test Invidious / Piped instance list
  print('Fetching public Piped instance list...');
  List<String> instances = [];
  try {
    final req = await client.getUrl(Uri.parse('https://piped-instances.kavin.rocks'));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as List<dynamic>;
    for (final inst in json) {
      final api = inst['api_url'] as String?;
      if (api != null && api.startsWith('https://')) {
        instances.add(api);
      }
    }
  } catch (e) {
    print('Failed to fetch from kavin.rocks: $e');
  }

  // Backup static instances
  instances.addAll([
    'https://pipedapi.kavin.rocks',
    'https://api.piped.privacydev.net',
    'https://pipedapi.tokhmi.xyz',
    'https://pa.il.ax',
    'https://pipedapi.drgns.space',
    'https://pipedapi.leptons.xyz',
    'https://piped-api.lunar.icu',
    'https://pipedapi.r4fo.com',
  ]);
  instances = instances.toSet().toList();

  print('Testing ${instances.length} instances against video 4NRXx6U8ABQ (Blinding Lights)...');

  for (final inst in instances) {
    try {
      final sw = Stopwatch()..start();
      final uri = Uri.parse('$inst/streams/4NRXx6U8ABQ');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      final res = await req.close().timeout(const Duration(seconds: 5));
      sw.stop();

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final audioStreams = (json['audioStreams'] as List<dynamic>?) ?? [];
        if (audioStreams.isNotEmpty) {
          final m4a = audioStreams.where((s) => (s['format'] ?? s['mimeType'] ?? '').toString().contains('m4a')).toList();
          print('  ✅ $inst: SUCCESS in ${sw.elapsedMilliseconds}ms (${audioStreams.length} audio, ${m4a.length} m4a)');
          continue;
        }
      }
      print('  ⚠️ $inst: HTTP ${res.statusCode}');
    } catch (e) {
      print('  ❌ $inst: $e');
    }
  }

  client.close();
}
