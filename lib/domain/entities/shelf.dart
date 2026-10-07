import 'track.dart';

class Shelf {
  final String id;
  final String title;
  final String? subtitle;
  final String rule;
  final List<Track> tracks;

  const Shelf({
    required this.id,
    required this.title,
    this.subtitle,
    required this.rule,
    required this.tracks,
  });

  Shelf copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? rule,
    List<Track>? tracks,
  }) {
    return Shelf(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      rule: rule ?? this.rule,
      tracks: tracks ?? this.tracks,
    );
  }
}
