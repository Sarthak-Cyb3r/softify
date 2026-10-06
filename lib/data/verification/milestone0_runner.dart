import 'dart:async';
import 'dart:io';

import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_catalog_repository.dart';
import '../../domain/ports/i_stream_resolver.dart';
import '../corpus/milestone0_test_corpus.dart';
import '../tagging/m4a_atom_tagger.dart';

class TrackVerificationResult {
  final TestCorpusTrack corpusTrack;
  final Track? matchedTrack;
  final bool searchSuccess;
  final bool matchAccuracySuccess;
  final bool resolutionSuccess;
  final int? measuredBitrateBps;
  final Duration? ttfaLatency;
  final String? providerName;
  final String? errorMessage;

  const TrackVerificationResult({
    required this.corpusTrack,
    this.matchedTrack,
    required this.searchSuccess,
    required this.matchAccuracySuccess,
    required this.resolutionSuccess,
    this.measuredBitrateBps,
    this.ttfaLatency,
    this.providerName,
    this.errorMessage,
  });

  bool get overallPass =>
      searchSuccess && matchAccuracySuccess && resolutionSuccess;
}

class Milestone0Report {
  final int totalTracks;
  final int passedTracks;
  final double successRatePercentage;
  final double averageTtfaMs;
  final bool passGateSatisfied; // Requires >= 90% success
  final List<TrackVerificationResult> results;

  const Milestone0Report({
    required this.totalTracks,
    required this.passedTracks,
    required this.successRatePercentage,
    required this.averageTtfaMs,
    required this.passGateSatisfied,
    required this.results,
  });
}

class Milestone0Runner {
  final ICatalogRepository catalog;
  final IStreamResolver resolver;

  Milestone0Runner({
    required this.catalog,
    required this.resolver,
  });

  /// Executes the 20+ track test corpus and streams progress updates.
  Stream<TrackVerificationResult> runCorpusTests() async* {
    for (final corpusTrack in Milestone0TestCorpus.tracks) {
      final stopwatch = Stopwatch()..start();
      Track? matchedTrack;
      bool searchSuccess = false;
      bool matchAccuracySuccess = false;
      bool resolutionSuccess = false;
      int? measuredBitrate;
      Duration? ttfa;
      String? providerName;
      String? errorMessage;

      try {
        // Step 1: Search
        final results = await catalog.search(corpusTrack.query, limit: 5);
        if (results.isNotEmpty) {
          searchSuccess = true;
          matchedTrack = results.first;

          // Step 2: Measure top-result match accuracy
          final titleLower = matchedTrack.title.toLowerCase();
          final artistLower = matchedTrack.artist.toLowerCase();
          final expectedTitleLower = corpusTrack.expectedTitleKeyword.toLowerCase();
          final expectedArtistLower = corpusTrack.expectedArtistKeyword.toLowerCase();

          if (titleLower.contains(expectedTitleLower) ||
              artistLower.contains(expectedArtistLower)) {
            matchAccuracySuccess = true;
          }

          // Step 3: Resolve JIT Stream URL & measure TTFA
          final resolveStopwatch = Stopwatch()..start();
          final streamInfo = await resolver.resolve(
            matchedTrack,
            quality: AudioQualityPreset.standard,
            forceFresh: true,
          );
          resolveStopwatch.stop();

          ttfa = resolveStopwatch.elapsed;
          measuredBitrate = streamInfo.bitrate;
          providerName = streamInfo.providerName;
          resolutionSuccess = true;
        } else {
          errorMessage = 'Search returned 0 results';
        }
      } catch (e) {
        errorMessage = e.toString();
      } finally {
        stopwatch.stop();
      }

      yield TrackVerificationResult(
        corpusTrack: corpusTrack,
        matchedTrack: matchedTrack,
        searchSuccess: searchSuccess,
        matchAccuracySuccess: matchAccuracySuccess,
        resolutionSuccess: resolutionSuccess,
        measuredBitrateBps: measuredBitrate,
        ttfaLatency: ttfa,
        providerName: providerName,
        errorMessage: errorMessage,
      );
    }
  }

  /// Runs the M4A MP4 container atom tagging validation test.
  static Future<bool> runTaggingTest(Directory tempDir) async {
    try {
      final testFile = File('${tempDir.path}/test_sample.m4a');
      // Create minimal valid MP4 file container
      final minimalMp4Header = [
        0x00, 0x00, 0x00, 0x1C, // 28 bytes
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        0x4D, 0x34, 0x41, 0x20, // 'M4A '
        0x00, 0x00, 0x00, 0x00, // minor version 0
        0x4D, 0x34, 0x41, 0x20, // compatible brands: 'M4A '
        0x6D, 0x70, 0x34, 0x32, // 'mp42'
        0x69, 0x73, 0x6F, 0x6D, // 'isom'
        0x00, 0x00, 0x00, 0x08, // 8 bytes
        0x6D, 0x6F, 0x6F, 0x76, // 'moov' (empty moov box)
      ];
      await testFile.writeAsBytes(minimalMp4Header);

      // Verify file size check
      final sizeVerified = await M4aAtomTagger.verifyFileSize(testFile, minimalMp4Header.length);
      if (!sizeVerified) return false;

      // Tag the file
      await M4aAtomTagger.writeMetadata(
        testFile,
        const M4aMetadata(
          title: 'Blinding Lights',
          artist: 'The Weeknd',
          album: 'After Hours',
        ),
      );

      // Verify tagged file exists and has expanded with metadata boxes
      final taggedBytes = await testFile.readAsBytes();
      final taggedString = String.fromCharCodes(taggedBytes);
      final hasTitle = taggedString.contains('Blinding Lights');
      final hasArtist = taggedString.contains('The Weeknd');

      await testFile.delete();
      return hasTitle && hasArtist;
    } catch (e, st) {
      // ignore: avoid_print
      print('TAGGING ERROR: $e\n$st');
      return false;
    }
  }
}
