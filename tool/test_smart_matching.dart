import 'package:youtube_explode_dart/youtube_explode_dart.dart';

int scoreCandidate({
  required String targetTitle,
  required String targetArtist,
  required Duration targetDuration,
  required Video candidate,
}) {
  int score = 0;
  final candTitle = candidate.title.toLowerCase();
  final candAuthor = candidate.author.toLowerCase();
  final candDuration = candidate.duration ?? Duration.zero;

  // 1. Topic channel (studio master audio)
  if (candAuthor.endsWith('- topic')) {
    score += 80;
  }

  // 2. Official Record Label / VEVO
  const officialLabels = [
    'vevo',
    't-series',
    'tseries',
    'sony music',
    'zee music',
    'yrf',
    'tips official',
    'saregama',
    'speed records',
    'white hill',
    'universal music',
    'warner music',
    'atlantic records',
    'def jam',
    'interscope',
    'columbia records',
  ];
  if (officialLabels.any((label) => candAuthor.contains(label))) {
    score += 50;
  }

  // 3. Artist channel match
  final cleanArtist = targetArtist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  if (cleanArtist.isNotEmpty && candAuthor.contains(cleanArtist)) {
    score += 35;
  }

  // 4. Negative junk keywords
  const negativeKeywords = [
    'reaction',
    'review',
    'teaser',
    'trailer',
    'cover',
    'karaoke',
    'instrumental',
    'slowed',
    'reverb',
    'bass boosted',
    'status',
    'short',
    'shorts',
    'ringtone',
    'tutorial',
    'behind the scenes',
    'making of',
    'interview',
    'full movie',
    'parody',
    'dance performance',
  ];
  final targetHasCover = targetTitle.toLowerCase().contains('cover');
  final targetHasRemix = targetTitle.toLowerCase().contains('remix');

  for (final neg in negativeKeywords) {
    if (candTitle.contains(neg)) {
      if (neg == 'cover' && targetHasCover) continue;
      score -= 100;
    }
  }

  if (!targetHasRemix && candTitle.contains('remix')) {
    score -= 60;
  }

  // 5. Title keywords
  final cleanTitle = targetTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
  if (cleanTitle.isNotEmpty && candTitle.contains(cleanTitle)) {
    score += 25;
  }
  if (candTitle.contains('official audio') || candTitle.contains('official music video') || candTitle.contains('official video')) {
    score += 20;
  }

  // 6. Duration proximity
  if (targetDuration > Duration.zero && candDuration > Duration.zero) {
    final diff = (targetDuration.inSeconds - candDuration.inSeconds).abs();
    if (diff <= 5) {
      score += 40;
    } else if (diff <= 15) {
      score += 20;
    } else if (diff <= 30) {
      score += 10;
    } else if (diff > 60) {
      score -= 60;
    }
  }

  return score;
}

void main() async {
  final yt = YoutubeExplode();

  final testCases = [
    {
      'title': 'Kesariya',
      'artist': 'Arijit Singh, Pritam & Amitabh Bhattacharya',
      'duration': const Duration(seconds: 268),
    },
    {
      'title': 'Blinding Lights',
      'artist': 'The Weeknd',
      'duration': const Duration(seconds: 200),
    },
    {
      'title': 'Pehle Bhi Main',
      'artist': 'Vishal Mishra & Raj Shekhar',
      'duration': const Duration(seconds: 250),
    },
    {
      'title': 'Shape of You',
      'artist': 'Ed Sheeran',
      'duration': const Duration(seconds: 233),
    },
  ];

  for (final tc in testCases) {
    final title = tc['title'] as String;
    final artist = tc['artist'] as String;
    final duration = tc['duration'] as Duration;

    print('\n=============================================');
    print('Searching: "$title" by "$artist" (${duration.inSeconds}s)');
    final query = '$title $artist';
    final results = await yt.search.search(query);

    final scored = results.take(8).map((v) {
      final s = scoreCandidate(
        targetTitle: title,
        targetArtist: artist,
        targetDuration: duration,
        candidate: v,
      );
      return {'video': v, 'score': s};
    }).toList();

    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    for (int i = 0; i < scored.length; i++) {
      final v = scored[i]['video'] as Video;
      final s = scored[i]['score'] as int;
      print(' [Score: $s] ${v.title} | Channel: "${v.author}" | Duration: ${v.duration?.inSeconds}s | ID: ${v.id.value}');
    }

    final top = scored.first['video'] as Video;
    print('👉 SELECTED: "${top.title}" by "${top.author}" (${top.id.value})');
  }

  yt.close();
}
