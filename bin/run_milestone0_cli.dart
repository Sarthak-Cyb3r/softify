import 'dart:io';

import 'package:softify/data/catalog/keyless_youtube_catalog.dart';
import 'package:softify/data/corpus/milestone0_test_corpus.dart';
import 'package:softify/data/resolvers/piped_stream_resolver.dart';
import 'package:softify/data/verification/milestone0_runner.dart';

void main() async {
  stdout.writeln('====================================================');
  stdout.writeln(' SOFTIFY — MILESTONE 0 SPIKE VERIFICATION HARNESS   ');
  stdout.writeln('====================================================');
  stdout.writeln('Corpus Size: ${Milestone0TestCorpus.tracks.length} diverse tracks\n');

  final catalog = KeylessYouTubeCatalog();
  final resolver = PipedStreamResolver();
  final runner = Milestone0Runner(catalog: catalog, resolver: resolver);

  int total = Milestone0TestCorpus.tracks.length;
  int passed = 0;
  int completed = 0;
  final List<double> ttfaList = [];

  stdout.writeln('Starting Search -> Resolve -> Verification Pipeline...\n');

  await for (final res in runner.runCorpusTests()) {
    completed++;
    final status = res.overallPass ? '✅ PASS' : '❌ FAIL';
    final query = res.corpusTrack.query;

    if (res.overallPass) {
      passed++;
      final ttfaMs = res.ttfaLatency?.inMilliseconds ?? 0;
      ttfaList.add(ttfaMs.toDouble());
      final bitrateKbps = (res.measuredBitrateBps ?? 0) / 1000;
      stdout.writeln(
        '[$completed/$total] $status: "$query" -> ${res.matchedTrack?.title} | TTFA: ${ttfaMs}ms | Bitrate: ${bitrateKbps.toStringAsFixed(1)}kbps',
      );
    } else {
      stdout.writeln(
        '[$completed/$total] $status: "$query" -> Error: ${res.errorMessage ?? "Match accuracy failed"}',
      );
    }
  }

  // Tagging test
  stdout.writeln('\nRunning M4A MP4 Container Atom Tagging Test...');
  final tempDir = Directory.systemTemp;
  final taggingPassed = await Milestone0Runner.runTaggingTest(tempDir);
  stdout.writeln('M4A Atom Tagging Test: ${taggingPassed ? "✅ PASS" : "❌ FAIL"}');

  final successRate = (passed / total) * 100;
  final avgTtfa = ttfaList.isNotEmpty
      ? ttfaList.reduce((a, b) => a + b) / ttfaList.length
      : 0.0;
  final gatePassed = successRate >= 90.0 && taggingPassed;

  stdout.writeln('\n====================================================');
  stdout.writeln('              MILESTONE 0 REPORT                    ');
  stdout.writeln('====================================================');
  stdout.writeln('Total Tracks Tested : $total');
  stdout.writeln('Passed Tracks       : $passed');
  stdout.writeln('Success Rate        : ${successRate.toStringAsFixed(1)}% (Gate requires ≥ 90.0%)');
  stdout.writeln('Average TTFA        : ${avgTtfa.toStringAsFixed(0)} ms');
  stdout.writeln('Tagging Validation  : ${taggingPassed ? "PASSED" : "FAILED"}');
  stdout.writeln('Final Gate Status   : ${gatePassed ? "🎯 GATE PASSED" : "🛑 GATE FAILED"}');
  stdout.writeln('====================================================\n');

  exit(gatePassed ? 0 : 1);
}
