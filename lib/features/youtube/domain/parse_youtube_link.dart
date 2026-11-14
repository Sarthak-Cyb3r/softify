import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    show PlaylistId, VideoId;

sealed class ParsedYoutubeLink {
  const ParsedYoutubeLink();
}

class VideoLink extends ParsedYoutubeLink {
  final String videoId;
  final int? startSeconds;

  const VideoLink({required this.videoId, this.startSeconds});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoLink &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          startSeconds == other.startSeconds;

  @override
  int get hashCode => videoId.hashCode ^ startSeconds.hashCode;

  @override
  String toString() => 'VideoLink(videoId: $videoId, startSeconds: $startSeconds)';
}

class PlaylistLink extends ParsedYoutubeLink {
  final String playlistId;

  const PlaylistLink({required this.playlistId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistLink &&
          runtimeType == other.runtimeType &&
          playlistId == other.playlistId;

  @override
  int get hashCode => playlistId.hashCode;

  @override
  String toString() => 'PlaylistLink(playlistId: $playlistId)';
}

class VideoInPlaylist extends ParsedYoutubeLink {
  final String videoId;
  final String playlistId;
  final int? startSeconds;

  const VideoInPlaylist({
    required this.videoId,
    required this.playlistId,
    this.startSeconds,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoInPlaylist &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          playlistId == other.playlistId &&
          startSeconds == other.startSeconds;

  @override
  int get hashCode =>
      videoId.hashCode ^ playlistId.hashCode ^ startSeconds.hashCode;

  @override
  String toString() =>
      'VideoInPlaylist(videoId: $videoId, playlistId: $playlistId, startSeconds: $startSeconds)';
}

class InvalidLink extends ParsedYoutubeLink {
  final String reason;

  const InvalidLink([this.reason = 'Invalid YouTube link']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvalidLink &&
          runtimeType == other.runtimeType &&
          reason == other.reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'InvalidLink(reason: "$reason")';
}

/// Parses a YouTube URL or video ID into a typed [ParsedYoutubeLink].
ParsedYoutubeLink parseYoutubeLink(String raw) {
  final input = raw.trim();
  if (input.isEmpty) {
    return const InvalidLink('Link cannot be empty');
  }

  // 1. Direct 11-char Video ID match
  if (VideoId.validateVideoId(input)) {
    return VideoLink(videoId: input);
  }

  // 2. Normalize scheme if missing
  String urlString = input;
  if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
    urlString = 'https://$urlString';
  }

  final uri = Uri.tryParse(urlString);
  if (uri == null) {
    return const InvalidLink('Malformed URL format');
  }

  final host = uri.host.toLowerCase();
  final isYtHost = host == 'youtu.be' ||
      host.endsWith('.youtube.com') ||
      host == 'youtube.com';

  if (!isYtHost) {
    return const InvalidLink('Not a YouTube domain');
  }

  // 3. Extract timestamp parameter if present
  int? startSeconds;
  final rawTime = uri.queryParameters['t'] ??
      uri.queryParameters['start'] ??
      uri.queryParameters['time_continue'];
  if (rawTime != null) {
    startSeconds = parseTimestampSeconds(rawTime);
  }

  // 4. Extract playlist parameter if present
  String? playlistId;
  final rawList = uri.queryParameters['list'];
  if (rawList != null && rawList.trim().isNotEmpty) {
    if (PlaylistId.validatePlaylistId(rawList.trim())) {
      playlistId = rawList.trim();
    }
  }

  // 5. Extract video ID
  String? videoId;

  // 5a. youtu.be/<id>
  if (host == 'youtu.be') {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && VideoId.validateVideoId(segments.first)) {
      videoId = segments.first;
    }
  }

  // 5b. /shorts/<id>, /embed/<id>, /live/<id>
  if (videoId == null && uri.pathSegments.isNotEmpty) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2) {
      final prefix = segments[0].toLowerCase();
      if (prefix == 'shorts' || prefix == 'embed' || prefix == 'live') {
        final idCandidate = segments[1];
        if (VideoId.validateVideoId(idCandidate)) {
          videoId = idCandidate;
        }
      }
    }
  }

  // 5c. /watch?v=<id> or query param 'v'
  if (videoId == null) {
    final vParam = uri.queryParameters['v'];
    if (vParam != null && VideoId.validateVideoId(vParam.trim())) {
      videoId = vParam.trim();
    }
  }

  // 5d. Fallback to youtube_explode_dart VideoId parser
  if (videoId == null) {
    try {
      final parsed = VideoId.parseVideoId(urlString);
      if (parsed != null && VideoId.validateVideoId(parsed)) {
        videoId = parsed;
      }
    } catch (_) {}
  }

  // 6. Fallback to youtube_explode_dart PlaylistId parser if list not found yet
  if (playlistId == null && uri.path.contains('playlist')) {
    try {
      final parsedList = PlaylistId.parsePlaylistId(urlString);
      if (parsedList != null && PlaylistId.validatePlaylistId(parsedList)) {
        playlistId = parsedList;
      }
    } catch (_) {}
  }

  // 7. Determine result
  if (videoId != null && playlistId != null) {
    return VideoInPlaylist(
      videoId: videoId,
      playlistId: playlistId,
      startSeconds: startSeconds,
    );
  }

  if (videoId != null) {
    return VideoLink(
      videoId: videoId,
      startSeconds: startSeconds,
    );
  }

  if (playlistId != null) {
    return PlaylistLink(playlistId: playlistId);
  }

  return const InvalidLink('No YouTube video or playlist found in URL');
}

/// Parses timestamp strings like "90", "90s", "1m30s", "1h2m3s", "45m" into total seconds.
int? parseTimestampSeconds(String raw) {
  final trimmed = raw.trim().toLowerCase();
  if (trimmed.isEmpty) return null;

  // Pure integer or with 's' suffix (e.g. "90", "90s")
  final pureSecMatch = RegExp(r'^(\d+)s?$').firstMatch(trimmed);
  if (pureSecMatch != null) {
    return int.tryParse(pureSecMatch.group(1)!);
  }

  // Mixed format (e.g., 1h2m3s, 1h30s, 2m10s, 45m, 1h)
  final timeRegex = RegExp(r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$');
  final match = timeRegex.firstMatch(trimmed);
  if (match != null && match.group(0)!.isNotEmpty) {
    final h = int.tryParse(match.group(1) ?? '0') ?? 0;
    final m = int.tryParse(match.group(2) ?? '0') ?? 0;
    final s = int.tryParse(match.group(3) ?? '0') ?? 0;
    final total = (h * 3600) + (m * 60) + s;
    return total > 0 ? total : null;
  }

  return null;
}
