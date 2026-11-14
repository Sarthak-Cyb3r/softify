import 'dart:io';
import 'package:softify/data/catalog/keyless_youtube_catalog.dart';
import 'package:softify/data/resolvers/youtube_stream_resolver.dart';
import 'package:softify/data/verification/milestone0_runner.dart';

void main() async {
  print('Starting Full 21-Track Validation Corpus Runner...\n');
  final catalog = KeylessYouTubeCatalog();
  final resolver = YoutubeStreamResolver();
  final runner = Milestone0Runner(catalog: catalog, resolver: resolver);

  int total = 0;
  int passed = 0;
  final stopwatch = Stopwatch()..start();

  await for (final res in runner.runCorpusTests()) {
    total++;
    final icon = res.overallPass ? '✅' : '❌';
    if (res.overallPass) {
      passed++;
      print('$icon [$total] "${res.corpusTrack.query}" -> Matched: "${res.matchedTrack?.title}" | Bitrate: ${(res.measuredBitrateBps! / 1000).toStringAsFixed(0)} kbps | TTFA: ${res.ttfaLatency?.inMilliseconds} ms');
    } else {
      print('$icon [$total] "${res.corpusTrack.query}" -> FAILED: ${res.errorMessage}');
    }
  }

  stopwatch.stop();
  final passRate = (passed / total) * 100;
  print('\n----------------------------------------');
  print('Results: $passed / $total passed (${passRate.toStringAsFixed(1)}%)');
  print('Total elapsed time: ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s');
  print('Milestone 0 Gate Passed (>=90%): ${passRate >= 90.0 ? "YES 🎉" : "NO"}');
  print('----------------------------------------');

  catalog.close();
  resolver.close();
  exit(passRate >= 90.0 ? 0 : 1);
}
