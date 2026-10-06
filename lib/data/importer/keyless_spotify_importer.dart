import 'dart:convert';
import 'dart:io';

import '../../domain/entities/spotify_import.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_catalog_repository.dart';
import '../../domain/ports/i_spotify_importer.dart';

class KeylessSpotifyImporter implements ISpotifyImporter {
  final HttpClient _httpClient;
  final ICatalogRepository? _catalog;

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  KeylessSpotifyImporter({
    HttpClient? httpClient,
    ICatalogRepository? catalog,
  })  : _httpClient = httpClient ?? HttpClient(),
        _catalog = catalog;

  @override
  String? extractPlaylistId(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    // Pattern 1: spotify:playlist:37i9dQZF1DXcBWIGoYBM5M
    final uriMatch = RegExp(r'spotify:playlist:([a-zA-Z0-9]+)').firstMatch(clean);
    if (uriMatch != null) return uriMatch.group(1);

    // Pattern 2: https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M or embed/playlist
    final urlMatch = RegExp(r'open\.spotify\.com/(?:embed/)?playlist/([a-zA-Z0-9]+)').firstMatch(clean);
    if (urlMatch != null) return urlMatch.group(1);

    // Pattern 3: Direct 22-character Spotify base62 ID
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(clean)) {
      return clean;
    }

    return null;
  }

  @override
  Future<SpotifyImportPlaylist> fetchPlaylist(String urlOrId) async {
    final playlistId = extractPlaylistId(urlOrId);
    if (playlistId == null) {
      throw FormatException('Invalid Spotify playlist URL or ID: "$urlOrId"');
    }

    final embedUri = Uri.parse('https://open.spotify.com/embed/playlist/$playlistId');
    final request = await _httpClient.getUrl(embedUri).timeout(const Duration(seconds: 10));
    request.headers.set('User-Agent', _defaultUserAgent);

    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException('Failed to load Spotify playlist (HTTP ${response.statusCode})', uri: embedUri);
    }

    final body = await response.transform(utf8.decoder).join();

    // Parse Next.js __NEXT_DATA__ script block
    final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">([^<]+)<\/script>').firstMatch(body);
    if (nextDataMatch != null) {
      final jsonStr = nextDataMatch.group(1)!;
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final entity = parsed['props']?['pageProps']?['state']?['data']?['entity'];

      if (entity != null) {
        final name = (entity['name'] ?? entity['title'] ?? 'Imported Spotify Playlist') as String;
        final description = entity['subtitle'] as String?;

        // Extract playlist cover image
        String? coverUrl;
        final coverArtSources = entity['coverArt']?['sources'] as List<dynamic>?;
        if (coverArtSources != null && coverArtSources.isNotEmpty) {
          coverUrl = coverArtSources.first['url'] as String?;
        } else {
          final visualImages = entity['visualIdentity']?['image'] as List<dynamic>?;
          if (visualImages != null && visualImages.isNotEmpty) {
            coverUrl = visualImages.last['url'] as String?;
          }
        }

        final rawTracks = (entity['trackList'] as List<dynamic>?) ?? [];
        final List<SpotifyTrackItem> tracks = [];

        for (final t in rawTracks) {
          final uri = (t['uri'] as String?) ?? '';
          final title = (t['title'] as String?) ?? 'Unknown Title';
          final artist = (t['subtitle'] as String?) ?? 'Unknown Artist';
          final durationMs = (t['duration'] as num?)?.toInt() ?? 0;

          tracks.add(
            SpotifyTrackItem(
              spotifyUri: uri,
              title: title,
              artist: artist,
              duration: Duration(milliseconds: durationMs),
              coverUrl: coverUrl,
            ),
          );
        }

        return SpotifyImportPlaylist(
          id: playlistId,
          name: name,
          description: description,
          coverUrl: coverUrl,
          tracks: tracks,
        );
      }
    }

    // Secondary Fallback: oEmbed metadata if embed HTML structure changes
    return _fetchViaOEmbed(playlistId);
  }

  Future<SpotifyImportPlaylist> _fetchViaOEmbed(String playlistId) async {
    final oEmbedUri = Uri.parse(
      'https://open.spotify.com/oembed?url=https://open.spotify.com/playlist/$playlistId',
    );
    final request = await _httpClient.getUrl(oEmbedUri).timeout(const Duration(seconds: 8));
    request.headers.set('User-Agent', _defaultUserAgent);
    final response = await request.close().timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Could not parse Spotify playlist: $playlistId');
    }

    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;

    final title = (json['title'] as String?) ?? 'Spotify Playlist';
    final thumbnail = json['thumbnail_url'] as String?;

    return SpotifyImportPlaylist(
      id: playlistId,
      name: title,
      description: 'Imported from Spotify',
      coverUrl: thumbnail,
      tracks: const [],
    );
  }

  @override
  Future<Track?> matchTrack(SpotifyTrackItem spotifyTrack) async {
    if (_catalog == null) return null;

    final query = '${spotifyTrack.title} ${spotifyTrack.artist}'.trim();
    final candidates = await _catalog.search(query, limit: 5);
    if (candidates.isEmpty) return null;

    Track? bestCandidate;
    double highestScore = -1.0;

    for (final candidate in candidates) {
      final score = _calculateMatchScore(spotifyTrack, candidate);
      if (score > highestScore) {
        highestScore = score;
        bestCandidate = candidate;
      }
    }

    if (bestCandidate != null && highestScore >= 0.50) {
      return bestCandidate.copyWith(matchConfidence: highestScore);
    }

    return null;
  }

  double _calculateMatchScore(SpotifyTrackItem target, Track candidate) {
    double score = 0.0;

    // 1. Title Similarity (0.0 to 0.45)
    final cleanTargetTitle = _normalizeString(target.title);
    final cleanCandTitle = _normalizeString(candidate.title);

    if (cleanCandTitle == cleanTargetTitle) {
      score += 0.45;
    } else if (cleanCandTitle.contains(cleanTargetTitle) || cleanTargetTitle.contains(cleanCandTitle)) {
      score += 0.35;
    } else {
      final targetWords = cleanTargetTitle.split(' ').where((w) => w.length > 2).toSet();
      final candWords = cleanCandTitle.split(' ').where((w) => w.length > 2).toSet();
      if (targetWords.isNotEmpty) {
        final common = targetWords.intersection(candWords).length;
        score += 0.45 * (common / targetWords.length);
      }
    }

    // 2. Artist Similarity (0.0 to 0.35)
    final cleanTargetArtist = _normalizeString(target.artist);
    final cleanCandArtist = _normalizeString(candidate.artist);

    if (cleanCandArtist == cleanTargetArtist) {
      score += 0.35;
    } else if (cleanCandArtist.contains(cleanTargetArtist) || cleanTargetArtist.contains(cleanCandArtist)) {
      score += 0.30;
    } else {
      final targetArtistWords = cleanTargetArtist.split(' ').where((w) => w.length > 2).toSet();
      final candArtistWords = cleanCandArtist.split(' ').where((w) => w.length > 2).toSet();
      if (targetArtistWords.isNotEmpty) {
        final common = targetArtistWords.intersection(candArtistWords).length;
        score += 0.35 * (common / targetArtistWords.length);
      }
    }

    // 3. Duration match (0.0 to 0.20)
    if (target.duration > Duration.zero && candidate.duration > Duration.zero) {
      final diff = (target.duration.inSeconds - candidate.duration.inSeconds).abs();
      if (diff <= 5) {
        score += 0.20;
      } else if (diff <= 15) {
        score += 0.15;
      } else if (diff <= 30) {
        score += 0.10;
      } else if (diff > 60) {
        score -= 0.15;
      }
    } else {
      // Default neutral duration score if candidate duration unknown
      score += 0.10;
    }

    return score.clamp(0.0, 1.0);
  }

  String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim();
  }
}
