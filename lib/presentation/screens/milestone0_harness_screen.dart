import 'dart:io';
import 'package:flutter/material.dart';

import '../../data/catalog/keyless_youtube_catalog.dart';
import '../../data/corpus/milestone0_test_corpus.dart';
import '../../data/resolvers/hybrid_stream_resolver.dart';
import '../../data/verification/milestone0_runner.dart';
import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/entities/track.dart';

class Milestone0HarnessScreen extends StatefulWidget {
  const Milestone0HarnessScreen({super.key});

  @override
  State<Milestone0HarnessScreen> createState() => _Milestone0HarnessScreenState();
}

class _Milestone0HarnessScreenState extends State<Milestone0HarnessScreen> {
  final KeylessYouTubeCatalog _catalog = KeylessYouTubeCatalog();
  late HybridStreamResolver _resolver;

  final TextEditingController _searchController = TextEditingController();
  List<Track> _searchResults = [];
  bool _isSearching = false;

  // Corpus Testing State
  bool _isRunningCorpus = false;
  final List<TrackVerificationResult> _corpusResults = [];
  int _completedTests = 0;
  bool? _gatePassed;

  // Single Track Live Test State
  bool _isResolving = false;
  String? _resolverLog;

  // M4A Tagging Test State
  String? _taggingTestResult;
  bool _isTaggingTesting = false;

  @override
  void initState() {
    super.initState();
    _resolver = HybridStreamResolver();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _resolverLog = null;
    });

    try {
      final results = await _catalog.search(query, limit: 10);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      setState(() {
        _resolverLog = 'Search error: $e';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _resolveSingleTrack(Track track) async {
    setState(() {
      _isResolving = true;
      _resolverLog = 'Resolving JIT stream for "${track.title}"...';
    });

    final sw = Stopwatch()..start();
    try {
      final info = await _resolver.resolve(
        track,
        quality: AudioQualityPreset.standard,
        forceFresh: true,
      );
      sw.stop();

      setState(() {
        _resolverLog = 'SUCCESS (${info.providerName})\n'
            'Container: ${info.container} (${info.codec})\n'
            'Bitrate: ${(info.bitrate / 1000).toStringAsFixed(1)} kbps\n'
            'TTFA Latency: ${sw.elapsedMilliseconds} ms\n'
            'Expires: ${info.expiresAt}';
      });
    } catch (e) {
      sw.stop();
      setState(() {
        _resolverLog = 'FAILED after ${sw.elapsedMilliseconds} ms:\n$e';
      });
    } finally {
      setState(() {
        _isResolving = false;
      });
    }
  }

  Future<void> _runCorpusGate() async {
    setState(() {
      _isRunningCorpus = true;
      _corpusResults.clear();
      _completedTests = 0;
      _gatePassed = null;
    });

    final runner = Milestone0Runner(catalog: _catalog, resolver: _resolver);

    await for (final result in runner.runCorpusTests()) {
      setState(() {
        _corpusResults.add(result);
        _completedTests++;
      });
    }

    final passedCount = _corpusResults.where((r) => r.overallPass).length;
    final rate = (passedCount / _corpusResults.length) * 100;

    setState(() {
      _isRunningCorpus = false;
      _gatePassed = rate >= 90.0;
    });
  }

  Future<void> _testM4aTagging() async {
    setState(() {
      _isTaggingTesting = true;
      _taggingTestResult = 'Running atom tagging test...';
    });

    try {
      final tempDir = Directory.systemTemp;
      final pass = await Milestone0Runner.runTaggingTest(tempDir);
      setState(() {
        _taggingTestResult = pass
            ? 'PASSED: M4A MP4 container atoms (©nam, ©ART, ©alb) successfully written and verified.'
            : 'FAILED: Tag verification mismatch.';
      });
    } catch (e) {
      setState(() {
        _taggingTestResult = 'FAILED: $e';
      });
    } finally {
      setState(() {
        _isTaggingTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Softify — Milestone 0 Debug Harness'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF181818),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGateBanner(),
            const SizedBox(height: 16),
            _buildCorpusSection(),
            const SizedBox(height: 24),
            _buildSearchSection(),
            const SizedBox(height: 24),
            _buildTaggingSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildGateBanner() {
    final color = _gatePassed == null
        ? Colors.grey.shade800
        : (_gatePassed! ? Colors.green.shade900 : Colors.red.shade900);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _gatePassed == null
                    ? Icons.help_outline
                    : (_gatePassed! ? Icons.check_circle : Icons.error),
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                _gatePassed == null
                    ? 'Milestone 0 Gate: Ready'
                    : (_gatePassed!
                        ? 'Milestone 0 Gate: PASSED (≥90%)'
                        : 'Milestone 0 Gate: FAILED (<90%)'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Validates Search → JIT Resolution → TTFA < 2.5s → M4A itag 140 Bitrates across 21 diverse tracks.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCorpusSection() {
    final total = Milestone0TestCorpus.tracks.length;
    final passed = _corpusResults.where((r) => r.overallPass).length;

    return Card(
      color: const Color(0xFF242424),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text(
                  '21-Track Validation Corpus',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ElevatedButton.icon(
                  onPressed: _isRunningCorpus ? null : _runCorpusGate,
                  icon: _isRunningCorpus
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_isRunningCorpus ? 'Running ($_completedTests/$total)' : 'Run Corpus'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            if (_corpusResults.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Passed: $passed / ${_corpusResults.length} (${((passed / _corpusResults.length) * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _corpusResults.length,
                itemBuilder: (context, index) {
                  final res = _corpusResults[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      res.overallPass ? Icons.check : Icons.close,
                      color: res.overallPass ? Colors.greenAccent : Colors.redAccent,
                      size: 20,
                    ),
                    title: Text(
                      res.corpusTrack.query,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: Text(
                      res.overallPass
                          ? 'TTFA: ${res.ttfaLatency?.inMilliseconds}ms | Bitrate: ${(res.measuredBitrateBps! / 1000).toStringAsFixed(0)}kbps'
                          : 'Error: ${res.errorMessage ?? "Accuracy mismatch"}',
                      style: TextStyle(
                        color: res.overallPass ? Colors.white54 : Colors.red.shade300,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Card(
      color: const Color(0xFF242424),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Search & JIT Resolver Test',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search track (e.g. Starboy, Bohemian Rhapsody)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF181818),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFF1DB954)),
                  onPressed: () => _performSearch(_searchController.text),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: _performSearch,
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
              ),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length.clamp(0, 5),
                itemBuilder: (context, index) {
                  final track = _searchResults[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: track.coverUrl != null
                        ? Image.network(track.coverUrl!, width: 44, height: 44, fit: BoxFit.cover)
                        : const Icon(Icons.music_note, color: Colors.white54),
                    title: Text(track.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Text(track.artist, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _isResolving ? null : () => _resolveSingleTrack(track),
                      child: const Text('Resolve JIT', style: TextStyle(fontSize: 11)),
                    ),
                  );
                },
              ),
            ],
            if (_resolverLog != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  _resolverLog!,
                  style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaggingSection() {
    return Card(
      color: const Color(0xFF242424),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'M4A MP4 Atom Tagging & File Verification',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tests writing MP4 metadata boxes (©nam, ©ART, ©alb) and checks byte verification.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isTaggingTesting ? null : _testM4aTagging,
              icon: _isTaggingTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.label),
              label: const Text('Run Tagging Verification Test'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700),
            ),
            if (_taggingTestResult != null) ...[
              const SizedBox(height: 8),
              Text(
                _taggingTestResult!,
                style: TextStyle(
                  color: _taggingTestResult!.startsWith('PASSED') ? Colors.greenAccent : Colors.amberAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
