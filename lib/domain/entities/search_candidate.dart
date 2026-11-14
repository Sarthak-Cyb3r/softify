import 'track.dart';

class SearchCandidate {
  final Track track;
  final String source; // 'local_fts' | 'network' | 'history'
  final Map<String, double> features;
  double score;

  SearchCandidate({
    required this.track,
    required this.source,
    required this.features,
    this.score = 0.0,
  });

  SearchCandidate copyWith({
    Track? track,
    String? source,
    Map<String, double>? features,
    double? score,
  }) {
    return SearchCandidate(
      track: track ?? this.track,
      source: source ?? this.source,
      features: features ?? this.features,
      score: score ?? this.score,
    );
  }
}
