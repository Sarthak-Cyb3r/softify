import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/spotify_import.dart';
import '../../domain/entities/track.dart';
import '../search/text_normalizer.dart';
import 'spotify_auth_service.dart';

class SpotifySearchResult {
  final List<Track> tracks;
  final List<SpotifyArtistRef> artists;
  final List<SpotifyAlbumRef> albums;
  final List<String> topResultTitles;

  const SpotifySearchResult({
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
    this.topResultTitles = const [],
  });
}

class SpotifyArtistRef {
  final String id;
  final String uri;
  final String name;
  final String? imageUrl;

  const SpotifyArtistRef({
    required this.id,
    required this.uri,
    required this.name,
    this.imageUrl,
  });
}

class SpotifyAlbumRef {
  final String id;
  final String uri;
  final String name;
  final String? artist;
  final String? coverUrl;

  const SpotifyAlbumRef({
    required this.id,
    required this.uri,
    required this.name,
    this.artist,
    this.coverUrl,
  });
}

class ArtistDiscography {
  final String artistName;
  final String artistUri;
  final String? avatarUrl;
  final List<Track> allTracks;
  final List<SpotifyAlbumRef> albums;

  const ArtistDiscography({
    required this.artistName,
    required this.artistUri,
    this.avatarUrl,
    required this.allTracks,
    this.albums = const [],
  });
}

/// Reverse engineered client for Spotify Web Player's Pathfinder & GraphQL Engine.
///
/// Supports keyless anonymous access token resolution with seamless fallback to
/// authenticated user PKCE OAuth tokens via [SpotifyAuthService].
class SpotifyApiService {
  final http.Client _client;
  final SpotifyAuthService? _authService;

  static const String _tokenEndpoint = 'https://open.spotify.com/embed/api/token';
  static const String _pathfinderEndpoint =
      'https://api-partner.spotify.com/pathfinder/v1/query';

  static const String _defaultUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  // Live extracted Pathfinder Sha256 Query Hashes
  static const String _shaSearchDesktop =
      'eef7cc54888d91bdd6802623477873caa3948ae173a0c34fd86827b267e94c03';
  static const String _shaSearchSuggestions =
      'f244254b94c0e824d458ac216e0f8406a73f2f69a9ff52831a2f78fa774ff6ce';
  static const String _shaRecommendedTracks =
      'c77098ee9d6ee8ad3eb844938722db60570d040b49f41f5ec6e7be9160a7c86b';
  static const String _shaArtistRelated =
      '3d031d6cb22a2aa7c8d203d49b49df731f58b1e2799cc38d9876d58771aa66f3';
  static const String _shaArtistOverview =
      '9f8134ef565e78621f1e1793555bd6633c5ac144ae0f89604ed3ae3f80b3c8e6';
  static const String _shaGetAlbum =
      '11c9cad9cb24c4f9e25ef9456f68621cfd6006a90f679e729c1d2f2fd70dfe16';
  static const String _shaGetTrack =
      'a8ef9e9f02b836feb0da3003c31dbb30decc6f4b473ef89ca88c882386d668de';

  String? _anonToken;
  DateTime? _anonTokenExpiresAt;

  final Map<String, SpotifySearchResult> _searchCache = {};
  final Map<String, ArtistDiscography> _discographyCache = {};

  SpotifyApiService({
    http.Client? client,
    SpotifyAuthService? authService,
  })  : _client = client ?? http.Client(),
        _authService = authService;

  /// Retrieves a valid Spotify Bearer token (User PKCE token first, anon embed token second).
  Future<String> getValidToken({bool forceRefresh = false}) async {
    // 1. Check logged-in user PKCE token
    if (!forceRefresh) {
      try {
        final userToken = await _authService?.getValidAccessToken();
        if (userToken != null && userToken.isNotEmpty) {
          return userToken;
        }
      } catch (_) {}
    }

    // 2. Check cached anonymous token
    final now = DateTime.now();
    if (!forceRefresh &&
        _anonToken != null &&
        _anonTokenExpiresAt != null &&
        now.isBefore(_anonTokenExpiresAt!.subtract(const Duration(seconds: 45)))) {
      return _anonToken!;
    }

    // 3. Fetch fresh anonymous token from embed endpoint
    final resp = await _client.get(
      Uri.parse(_tokenEndpoint),
      headers: {
        'User-Agent': _defaultUserAgent,
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw HttpException('Failed to obtain Spotify token (HTTP ${resp.statusCode})');
    }

    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final token = (data['accessToken'] as String?) ?? '';
    if (token.isEmpty) {
      throw const HttpException('Empty Spotify access token received');
    }

    final expMs = (data['accessTokenExpirationTimestampMs'] as num?)?.toInt() ?? 0;
    _anonToken = token;
    _anonTokenExpiresAt = expMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(expMs)
        : now.add(const Duration(minutes: 25));

    return token;
  }

  /// Reverse Engineered Spotify Unified Search (`searchDesktop`).
  ///
  /// Searches tracks, artists, albums, and playlists via Spotify's production Pathfinder engine.
  Future<SpotifySearchResult> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return const SpotifySearchResult();

    final cacheKey = '${clean.toLowerCase()}_${limit}_$offset';
    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    // Fast-path: When user is authenticated via Spotify PKCE, query the official Spotify Web API
    // for direct, 100% accurate catalog data without anonymous rate limit risks.
    if (await _isUserLoggedIn()) {
      try {
        final webResult = await _searchWebApi(clean, limit: limit, offset: offset);
        if (webResult.tracks.isNotEmpty || webResult.artists.isNotEmpty) {
          if (_searchCache.length >= 60) _searchCache.remove(_searchCache.keys.first);
          _searchCache[cacheKey] = webResult;
          return webResult;
        }
      } catch (_) {}
    }

    try {
      final variables = {
        'searchTerm': clean,
        'offset': offset,
        'limit': limit,
        'numberOfTopResults': 5,
        'includeAudiobooks': false,
      };

      final data = await _executePathfinder(
        operationName: 'searchDesktop',
        sha256Hash: _shaSearchDesktop,
        variables: variables,
      );

      final searchV2 = data?['data']?['searchV2'] as Map<String, dynamic>?;
      if (searchV2 == null) return const SpotifySearchResult();

      // 1. Tracks
      final rawTracks = searchV2['tracksV2']?['items'] as List<dynamic>? ?? [];
      final List<Track> tracks = [];
      for (final raw in rawTracks) {
        final item = raw['item']?['data'] as Map<String, dynamic>?;
        if (item == null) continue;
        final matchedFields = (raw['matchedFields'] as List<dynamic>?)
            ?.map((e) => e.toString().toUpperCase())
            .toList() ?? [];
        final isLyricsMatch = matchedFields.contains('LYRICS') && !matchedFields.contains('NAME');
        final track = _parseSpotifyTrack(item, isLyricsMatch: isLyricsMatch);
        if (track != null) tracks.add(track);
      }

      // 2. Artists
      final rawArtists = searchV2['artists']?['items'] as List<dynamic>? ?? [];
      final List<SpotifyArtistRef> artists = [];
      for (final raw in rawArtists) {
        final dataMap = raw['data'] as Map<String, dynamic>?;
        if (dataMap == null) continue;
        final uri = (dataMap['uri'] as String?) ?? '';
        final name = (dataMap['profile']?['name'] as String?) ?? '';
        final id = uri.split(':').lastOrNull ?? '';
        String? img;
        final sources = dataMap['visuals']?['avatarImage']?['sources'] as List<dynamic>?;
        if (sources != null && sources.isNotEmpty) {
          img = sources.first['url'] as String?;
        }
        if (name.isNotEmpty) {
          artists.add(SpotifyArtistRef(id: id, uri: uri, name: name, imageUrl: img));
        }
      }

      // 3. Albums
      final rawAlbums = searchV2['albumsV2']?['items'] as List<dynamic>? ?? [];
      final List<SpotifyAlbumRef> albums = [];
      for (final raw in rawAlbums) {
        final dataMap = raw['data'] as Map<String, dynamic>?;
        if (dataMap == null) continue;
        final uri = (dataMap['uri'] as String?) ?? '';
        final name = (dataMap['name'] as String?) ?? '';
        final id = uri.split(':').lastOrNull ?? '';
        final artistList = dataMap['artists']?['items'] as List<dynamic>?;
        final artistName = artistList?.map((a) => a['profile']?['name'] as String?).whereType<String>().join(', ');
        String? cover;
        final sources = dataMap['coverArt']?['sources'] as List<dynamic>?;
        if (sources != null && sources.isNotEmpty) {
          cover = sources.first['url'] as String?;
        }
        if (name.isNotEmpty) {
          albums.add(SpotifyAlbumRef(id: id, uri: uri, name: name, artist: artistName, coverUrl: cover));
        }
      }

      // 4. Top Results & Top Track Prioritization
      final rawTop = searchV2['topResultsV2']?['itemsV2'] as List<dynamic>? ?? [];
      final List<String> topTitles = [];
      Track? topTrack;
      for (final raw in rawTop) {
        final item = raw['item']?['data'] as Map<String, dynamic>?;
        if (item == null) continue;
        final tName = (item['name'] as String?) ??
            (item['profile']?['name'] as String?) ??
            (item['title']?['transformedLabel'] as String?);
        if (tName != null && tName.isNotEmpty) {
          topTitles.add(tName);
        }
        if (topTrack == null && item['__typename'] == 'Track') {
          final topMatchedFields = (raw['matchedFields'] as List<dynamic>?)
              ?.map((e) => e.toString().toUpperCase())
              .toList() ?? [];
          final isLyricsMatch = topMatchedFields.contains('LYRICS') && !topMatchedFields.contains('NAME');
          topTrack = _parseSpotifyTrack(item, isLyricsMatch: isLyricsMatch);
        }
      }

      if (topTrack != null) {
        final existingIdx = tracks.indexWhere((t) => t.id == topTrack!.id);
        if (existingIdx > 0) {
          tracks.removeAt(existingIdx);
          tracks.insert(0, topTrack);
        } else if (existingIdx == -1) {
          tracks.insert(0, topTrack);
        }
      }

      final result = SpotifySearchResult(
        tracks: tracks,
        artists: artists,
        albums: albums,
        topResultTitles: topTitles,
      );
      if (_searchCache.length >= 60) {
        _searchCache.remove(_searchCache.keys.first);
      }
      _searchCache[cacheKey] = result;
      return result;
    } catch (_) {
      return const SpotifySearchResult();
    }
  }

  /// Reverse Engineered Spotify Real-Time Search Suggestions (`searchSuggestions`).
  Future<List<String>> getSearchSuggestions(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];

    try {
      final variables = {'query': clean};
      final data = await _executePathfinder(
        operationName: 'searchSuggestions',
        sha256Hash: _shaSearchSuggestions,
        variables: variables,
      );

      final items = data?['data']?['searchV2']?['topResultsV2']?['itemsV2'] as List<dynamic>? ?? [];
      final List<String> suggestions = [];
      for (final it in items) {
        final text = it['item']?['data']?['text'] as String?;
        if (text != null && text.trim().isNotEmpty && !suggestions.contains(text.trim())) {
          suggestions.add(text.trim());
        }
      }
      return suggestions;
    } catch (_) {
      return const [];
    }
  }

  /// Reverse Engineered Spotify Recommendation Engine (`internalLinkRecommenderTrack`).
  ///
  /// Takes a track URI (e.g. `spotify:track:56zZ48jdyY2oDXHVnwg5Di` or raw 22-char ID)
  /// and returns Spotify's algorithmic recommended tracks (`seoRecommendedTrack`).
  Future<List<Track>> getRecommendedTracks(String trackUriOrId) async {
    final uri = _normalizeSpotifyTrackUri(trackUriOrId);
    if (uri.isEmpty) return const [];

    try {
      final variables = {'uri': uri};
      final data = await _executePathfinder(
        operationName: 'internalLinkRecommenderTrack',
        sha256Hash: _shaRecommendedTracks,
        variables: variables,
      );

      final items = data?['data']?['seoRecommendedTrack']?['items'] as List<dynamic>? ?? [];
      final List<Track> tracks = [];
      for (final raw in items) {
        final item = raw['data'] as Map<String, dynamic>?;
        if (item == null) continue;
        final track = _parseSpotifyTrack(item);
        if (track != null) tracks.add(track);
      }
      return tracks;
    } catch (_) {
      return const [];
    }
  }

  /// Reverse Engineered Spotify Track Radio (`inspiredby-mix`).
  ///
  /// Takes a track URI or 22-character ID (e.g. `56zZ48jdyY2oDXHVnwg5Di`),
  /// resolves Spotify's dynamic Track Radio playlist (`spotify:playlist:37i9dQZF1...`),
  /// and returns up to 50 algorithmic recommendation tracks trained by Spotify.
  Future<List<Track>> getTrackRadio(String trackUriOrId) async {
    final cleanId = _extract22CharId(trackUriOrId);
    if (cleanId.isEmpty) return const [];

    try {
      final token = await getValidToken();
      final url = Uri.parse(
          'https://spclient.wg.spotify.com/inspiredby-mix/v2/seed_to_playlist/spotify:track:$cleanId');
      final resp = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'User-Agent': _defaultUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return const [];

      final match = RegExp(r'spotify:playlist:([a-zA-Z0-9]+)').firstMatch(resp.body);
      if (match == null) return const [];
      final playlistId = match.group(1)!;

      return await _fetchPlaylistTracks(playlistId);
    } catch (_) {
      return const [];
    }
  }

  /// Reverse Engineered Spotify Artist Radio (`inspiredby-mix`).
  Future<List<Track>> getArtistRadio(String artistUriOrId) async {
    final cleanId = _extract22CharId(artistUriOrId);
    if (cleanId.isEmpty) return const [];

    try {
      final token = await getValidToken();
      final url = Uri.parse(
          'https://spclient.wg.spotify.com/inspiredby-mix/v2/seed_to_playlist/spotify:artist:$cleanId');
      final resp = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'User-Agent': _defaultUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return const [];

      final match = RegExp(r'spotify:playlist:([a-zA-Z0-9]+)').firstMatch(resp.body);
      if (match == null) return const [];
      final playlistId = match.group(1)!;

      return await _fetchPlaylistTracks(playlistId);
    } catch (_) {
      return const [];
    }
  }

  /// Fetches global & regional trending tracks with verified Spotify metadata.
  Future<List<Track>> getTrendingTracks({int limit = 20}) async {
    try {
      final res = await search('Top 50 India', limit: limit);
      if (res.tracks.isNotEmpty) {
        return res.tracks;
      }
    } catch (_) {}
    try {
      final res = await search('Today\'s Top Hits', limit: limit);
      if (res.tracks.isNotEmpty) {
        return res.tracks;
      }
    } catch (_) {}
    try {
      final tracks = await _fetchPlaylistTracks('37i9dQZEVXbMDoHDwVN2tF');
      if (tracks.isNotEmpty) {
        return tracks.take(limit).toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Resolves canonical Spotify Track metadata for a track title & artist.
  Future<Track?> resolveCanonicalTrack(String title, String artist) async {
    final clean = '$title $artist'.trim();
    if (clean.isEmpty) return null;
    try {
      final res = await search(clean, limit: 5);
      for (final t in res.tracks) {
        if (TextNormalizer.matchesArtist(t.artist, artist)) {
          return t;
        }
      }
      return res.tracks.firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<List<Track>> _fetchPlaylistTracks(String playlistId) async {
    try {
      final embedUri = Uri.parse('https://open.spotify.com/embed/playlist/$playlistId');
      final resp = await _client.get(
        embedUri,
        headers: {'User-Agent': _defaultUserAgent},
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return const [];

      final body = utf8.decode(resp.bodyBytes, allowMalformed: true);
      final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">([^<]+)<\/script>').firstMatch(body);
      if (nextDataMatch == null) return const [];

      final parsed = jsonDecode(nextDataMatch.group(1)!) as Map<String, dynamic>;
      final state = parsed['props']?['pageProps']?['state'] as Map<String, dynamic>?;
      final entity = state?['data']?['entity'];
      if (entity == null) return const [];

      final rawTracks = (entity['trackList'] as List<dynamic>?) ?? [];
      final List<Track> tracks = [];

      for (final t in rawTracks) {
        final uri = (t['uri'] as String?) ?? '';
        final id = uri.split(':').lastOrNull ?? '';
        final title = (t['title'] as String?)?.trim() ?? '';
        final artist = (t['subtitle'] as String?)?.trim() ?? 'Unknown Artist';
        final durationMs = (t['duration'] as num?)?.toInt() ?? 0;

        if (title.isEmpty) continue;

        tracks.add(
          Track(
            id: id.isNotEmpty ? 'spotify_$id' : 'spotify_${title}_$artist',
            sourceId: id.isNotEmpty ? 'spotify_$id' : 'spotify_${title}_$artist',
            title: title,
            artist: artist,
            album: null,
            duration: Duration(milliseconds: durationMs),
            coverUrl: null,
          ),
        );
      }
      return tracks;
    } catch (_) {
      return const [];
    }
  }

  /// Reverse Engineered Spotify Related Artists (`queryArtistRelated`).
  Future<List<SpotifyArtistRef>> getRelatedArtists(String artistUriOrId) async {
    final uri = _normalizeSpotifyArtistUri(artistUriOrId);
    if (uri.isEmpty) return const [];

    try {
      final variables = {'uri': uri};
      final data = await _executePathfinder(
        operationName: 'queryArtistRelated',
        sha256Hash: _shaArtistRelated,
        variables: variables,
      );

      final items = data?['data']?['artistUnion']?['relatedContent']?['relatedArtists']?['items'] as List<dynamic>? ?? [];
      final List<SpotifyArtistRef> artists = [];
      for (final a in items) {
        final aUri = (a['uri'] as String?) ?? '';
        final name = (a['profile']?['name'] as String?) ?? '';
        final id = aUri.split(':').lastOrNull ?? '';
        String? img;
        final sources = a['visuals']?['avatarImage']?['sources'] as List<dynamic>?;
        if (sources != null && sources.isNotEmpty) {
          img = sources.first['url'] as String?;
        }
        if (name.isNotEmpty) {
          artists.add(SpotifyArtistRef(id: id, uri: aUri, name: name, imageUrl: img));
        }
      }
      return artists;
    } catch (_) {
      return const [];
    }
  }

  /// Reverse Engineered Spotify Artist Top Tracks (`queryArtistOverview`).
  Future<List<Track>> getArtistTopTracks(String artistUriOrId) async {
    final uri = _normalizeSpotifyArtistUri(artistUriOrId);
    if (uri.isEmpty) return const [];

    try {
      final variables = {'uri': uri};
      final data = await _executePathfinder(
        operationName: 'queryArtistOverview',
        sha256Hash: _shaArtistOverview,
        variables: variables,
      );

      final items = data?['data']?['artistUnion']?['discography']?['topTracks']?['items'] as List<dynamic>? ?? [];
      final List<Track> tracks = [];
      for (final t in items) {
        final trackData = t['track'] as Map<String, dynamic>?;
        if (trackData == null) continue;
        final track = _parseSpotifyTrack(trackData);
        if (track != null) tracks.add(track);
      }
      return tracks;
    } catch (_) {
      return const [];
    }
  }

  /// Reverse Engineered Spotify Album Tracks (`getAlbum`).
  Future<List<Track>> getAlbumTracks(String albumUriOrId) async {
    final uri = _normalizeSpotifyAlbumUri(albumUriOrId);
    if (uri.isEmpty) return const [];

    try {
      final variables = {'uri': uri, 'offset': 0, 'limit': 100};
      final data = await _executePathfinder(
        operationName: 'getAlbum',
        sha256Hash: _shaGetAlbum,
        variables: variables,
      );

      final albumUnion = data?['data']?['albumUnion'] as Map<String, dynamic>?;
      if (albumUnion == null) return const [];

      final albumName = (albumUnion['name'] as String?) ?? 'Unknown Album';
      String? cover;
      final coverSources = albumUnion['coverArt']?['sources'] as List<dynamic>?;
      if (coverSources != null && coverSources.isNotEmpty) {
        cover = coverSources.first['url'] as String?;
      }

      final items = albumUnion['tracksV2']?['items'] as List<dynamic>? ?? [];
      final List<Track> tracks = [];
      for (final it in items) {
        final t = it['track'] as Map<String, dynamic>?;
        if (t == null) continue;
        final track = _parseSpotifyTrack(t, fallbackAlbum: albumName, fallbackCover: cover);
        if (track != null) tracks.add(track);
      }
      return tracks;
    } catch (_) {
      return const [];
    }
  }

  /// Reverse Engineered Spotify Artist Discography & Complete Song Collection.
  /// Fetches artist's studio albums, singles, collaborations, and top tracks.
  Future<ArtistDiscography?> getArtistCompleteDiscography(
    String artistUriOrId, {
    bool fetchFullReleases = false,
  }) async {
    final uri = _normalizeSpotifyArtistUri(artistUriOrId);
    if (uri.isEmpty) return null;

    final cacheKey = '${uri}_$fetchFullReleases';
    if (_discographyCache.containsKey(cacheKey)) {
      return _discographyCache[cacheKey];
    }

    try {
      final variables = {'uri': uri};
      final data = await _executePathfinder(
        operationName: 'queryArtistOverview',
        sha256Hash: _shaArtistOverview,
        variables: variables,
      );

      final artistUnion = data?['data']?['artistUnion'] as Map<String, dynamic>?;
      if (artistUnion == null) return null;

      final artistName = (artistUnion['profile']?['name'] as String?) ?? 'Artist';
      String? avatarUrl;
      final avatarSources = artistUnion['visuals']?['avatarImage']?['sources'] as List<dynamic>?;
      if (avatarSources != null && avatarSources.isNotEmpty) {
        avatarUrl = avatarSources.first['url'] as String?;
      }

      final discography = artistUnion['discography'] as Map<String, dynamic>? ?? {};
      final topItems = discography['topTracks']?['items'] as List<dynamic>? ?? [];

      final List<Track> collectedTracks = [];
      final Set<String> seenNormalizedTitles = {};

      void addTrack(Track t) {
        if (!TextNormalizer.matchesArtist(t.artist, artistName)) return;
        final norm = t.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (norm.isNotEmpty && !seenNormalizedTitles.contains(norm)) {
          seenNormalizedTitles.add(norm);
          collectedTracks.add(t);
        }
      }

      // 1. Add top tracks
      for (final it in topItems) {
        final tData = it['track'] as Map<String, dynamic>?;
        if (tData != null) {
          final track = _parseSpotifyTrack(tData);
          if (track != null) addTrack(track);
        }
      }

      // 2. Collect Albums & Singles
      final List<SpotifyAlbumRef> albumRefs = [];
      final rawAlbumGroups = [
        discography['albums']?['items'] as List<dynamic>? ?? [],
        discography['singles']?['items'] as List<dynamic>? ?? [],
        discography['compilations']?['items'] as List<dynamic>? ?? [],
        discography['popularReleasesAlbums']?['items'] as List<dynamic>? ?? [],
      ];

      final List<String> releaseUrisToFetch = [];
      for (final group in rawAlbumGroups) {
        for (final item in group) {
          final releases = item['releases']?['items'] as List<dynamic>?;
          if (releases != null && releases.isNotEmpty) {
            for (final rel in releases) {
              final rUri = rel['uri'] as String? ?? '';
              final rName = rel['name'] as String? ?? '';
              final rId = rUri.split(':').lastOrNull ?? '';
              String? rCover;
              final rSources = rel['coverArt']?['sources'] as List<dynamic>?;
              if (rSources != null && rSources.isNotEmpty) {
                rCover = rSources.first['url'] as String?;
              }
              if (rUri.isNotEmpty) {
                albumRefs.add(SpotifyAlbumRef(
                  id: rId,
                  uri: rUri,
                  name: rName,
                  artist: artistName,
                  coverUrl: rCover,
                ));
                if (releaseUrisToFetch.length < 10) {
                  releaseUrisToFetch.add(rUri);
                }
              }
            }
          }
        }
      }

      // 3. Fetch tracks from releases (only if explicitly requested)
      if (fetchFullReleases && releaseUrisToFetch.isNotEmpty) {
        final albumFutures = releaseUrisToFetch
            .take(5)
            .map((u) => getAlbumTracks(u).catchError((_) => <Track>[]));
        final albumResults = await Future.wait(albumFutures);
        for (final albumTracks in albumResults) {
          for (final t in albumTracks) {
            addTrack(t);
          }
        }
      }

      if (avatarUrl == null || avatarUrl.isEmpty) {
        // Fallback 1: Header image from Spotify visuals
        final headerSources = artistUnion['visuals']?['headerImage']?['sources'] as List<dynamic>?;
        if (headerSources != null && headerSources.isNotEmpty) {
          avatarUrl = headerSources.first['url'] as String?;
        }
      }

      if (avatarUrl == null || avatarUrl.isEmpty) {
        // Fallback 2: Deezer instant keyless artist avatar lookup
        try {
          final encoded = Uri.encodeComponent(artistName);
          final res = await _client.get(
            Uri.parse('https://api.deezer.com/search/artist?q=$encoded&limit=1'),
            headers: {'User-Agent': _defaultUserAgent},
          ).timeout(const Duration(seconds: 3));
          if (res.statusCode == 200) {
            final parsed = jsonDecode(res.body) as Map<String, dynamic>;
            final dataList = parsed['data'] as List<dynamic>?;
            if (dataList != null && dataList.isNotEmpty) {
              final first = dataList.first as Map<String, dynamic>;
              avatarUrl = (first['picture_big'] ?? first['picture_medium']) as String?;
            }
          }
        } catch (_) {}
      }

      // Fallback 3: First available track cover
      avatarUrl ??= collectedTracks.firstOrNull?.coverUrl;

      final result = ArtistDiscography(
        artistName: artistName,
        artistUri: uri,
        avatarUrl: avatarUrl,
        allTracks: collectedTracks,
        albums: albumRefs,
      );
      if (_discographyCache.length >= 60) {
        _discographyCache.remove(_discographyCache.keys.first);
      }
      _discographyCache[cacheKey] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Reverse Engineered Canonical Track Lookup (`getTrack`).
  Future<Track?> getTrack(String trackUriOrId) async {
    final uri = _normalizeSpotifyTrackUri(trackUriOrId);
    if (uri.isEmpty) return null;

    try {
      final variables = {'uri': uri};
      final data = await _executePathfinder(
        operationName: 'getTrack',
        sha256Hash: _shaGetTrack,
        variables: variables,
      );

      final trackUnion = data?['data']?['trackUnion'] as Map<String, dynamic>?;
      if (trackUnion == null) return null;
      return _parseSpotifyTrack(trackUnion);
    } catch (_) {
      return null;
    }
  }

  final Map<String, String> _coverCache = {};

  /// Resolves authentic album covers for tracks lacking valid artwork,
  /// avoiding radio playlist placeholder banners.
  Future<List<Track>> resolveAuthenticCovers(List<Track> tracks) async {
    try {
      return await Future.wait(
        tracks.map((t) async {
          if (t.coverUrl != null &&
              !t.coverUrl!.contains('playlist') &&
              !t.coverUrl!.contains('mosaic') &&
              !t.coverUrl!.contains('radio')) {
            return t;
          }
          final sId = _extract22CharId(t.id.isNotEmpty ? t.id : t.sourceId);
          if (sId.isNotEmpty && RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(sId)) {
            if (_coverCache.containsKey(sId)) {
              return t.copyWith(coverUrl: _coverCache[sId]);
            }
            try {
              final full = await getTrack(sId).timeout(const Duration(milliseconds: 1500));
              if (full?.coverUrl != null) {
                _coverCache[sId] = full!.coverUrl!;
                return t.copyWith(
                  coverUrl: full.coverUrl,
                  album: full.album ?? t.album,
                );
              }
            } catch (_) {}
          }

          // Fallback: Spotify search for authentic high-res album cover
          if (t.title.isNotEmpty && t.artist.isNotEmpty) {
            try {
              final sRes = await search('${t.title} ${t.artist}', limit: 1).timeout(const Duration(milliseconds: 1500));
              if (sRes.tracks.isNotEmpty && sRes.tracks.first.coverUrl != null && sRes.tracks.first.coverUrl!.isNotEmpty) {
                return t.copyWith(
                  coverUrl: sRes.tracks.first.coverUrl,
                  album: sRes.tracks.first.album ?? t.album,
                );
              }
            } catch (_) {}
          }

          return t;
        }),
      );
    } catch (_) {
      return tracks;
    }
  }

  // --- Private Helpers ---

  Future<Map<String, dynamic>?> _executePathfinder({
    required String operationName,
    required String sha256Hash,
    required Map<String, dynamic> variables,
  }) async {
    var token = await getValidToken();

    Future<Map<String, dynamic>?> executeWithToken(String bearerToken) async {
      final url = Uri.parse(_pathfinderEndpoint).replace(queryParameters: {
        'operationName': operationName,
        'variables': jsonEncode(variables),
        'extensions': jsonEncode({
          'persistedQuery': {'version': 1, 'sha256Hash': sha256Hash}
        }),
      });

      final resp = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'User-Agent': _defaultUserAgent,
          'Accept': 'application/json',
          'app-platform': 'WebPlayer',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 401) {
        return null;
      }

      if (resp.statusCode != 200) {
        return null;
      }

      return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    }

    var result = await executeWithToken(token);
    if (result == null) {
      // 401 or token issue: force refresh token and retry once
      token = await getValidToken(forceRefresh: true);
      result = await executeWithToken(token);
    }

    return result;
  }

  Track? _parseSpotifyTrack(
    Map<String, dynamic> item, {
    String? fallbackAlbum,
    String? fallbackCover,
    bool isLyricsMatch = false,
    String? matchedLyricSnippet,
  }) {
    final title = (item['name'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;

    final uri = (item['uri'] as String?) ?? '';
    final id = uri.split(':').lastOrNull ?? '';

    // Artist list
    final artistsItems = (item['artists']?['items'] as List<dynamic>?) ??
        (item['firstArtist']?['items'] as List<dynamic>?);
    String artist = 'Unknown Artist';
    if (artistsItems != null && artistsItems.isNotEmpty) {
      final names = artistsItems
          .map((a) => a['profile']?['name'] as String?)
          .whereType<String>()
          .toList();
      if (names.isNotEmpty) artist = names.join(', ');
    }

    // Album & Artwork
    String? album = fallbackAlbum ?? (item['albumOfTrack']?['name'] as String?);
    String? cover = fallbackCover;
    final coverSources = item['albumOfTrack']?['coverArt']?['sources'] as List<dynamic>?;
    if (coverSources != null && coverSources.isNotEmpty) {
      cover = coverSources.first['url'] as String?;
    }

    // Duration
    final durationMs = (item['trackDuration']?['totalMilliseconds'] as num?)?.toInt() ??
        (item['duration']?['totalMilliseconds'] as num?)?.toInt() ??
        (item['duration'] as num?)?.toInt() ??
        0;

    return Track(
      id: id.isNotEmpty ? 'spotify_$id' : 'spotify_${title}_$artist',
      sourceId: id.isNotEmpty ? 'spotify_$id' : 'spotify_${title}_$artist',
      title: title,
      artist: artist,
      album: album,
      duration: Duration(milliseconds: durationMs),
      coverUrl: cover,
      isLyricsMatch: isLyricsMatch,
      matchedLyricSnippet: matchedLyricSnippet,
    );
  }

  String _normalizeSpotifyTrackUri(String input) {
    final clean = input.trim();
    if (clean.startsWith('spotify:track:')) return clean;
    if (clean.startsWith('spotify_')) return 'spotify:track:${clean.replaceFirst('spotify_', '')}';
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(clean)) return 'spotify:track:$clean';
    return clean;
  }

  String _normalizeSpotifyArtistUri(String input) {
    final clean = input.trim();
    if (clean.startsWith('spotify:artist:')) return clean;
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(clean)) return 'spotify:artist:$clean';
    return clean;
  }

  String _normalizeSpotifyAlbumUri(String input) {
    final clean = input.trim();
    if (clean.startsWith('spotify:album:')) return clean;
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(clean)) return 'spotify:album:$clean';
    return clean;
  }

  String _extract22CharId(String input) {
    final clean = input.trim();
    if (clean.startsWith('spotify:track:')) return clean.replaceFirst('spotify:track:', '');
    if (clean.startsWith('spotify:artist:')) return clean.replaceFirst('spotify:artist:', '');
    if (clean.startsWith('spotify:album:')) return clean.replaceFirst('spotify:album:', '');
    if (clean.startsWith('spotify_')) return clean.replaceFirst('spotify_', '');
    final match = RegExp(r'[a-zA-Z0-9]{22}').firstMatch(clean);
    if (match != null) return match.group(0)!;
    return clean;
  }

  // --- Authenticated Spotify Web API User Library & Data Extraction ---

  Future<bool> _isUserLoggedIn() async {
    try {
      return (await _authService?.isLoggedIn()) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves user's playlists directly via official Spotify Web API (`GET /v1/me/playlists`).
  Future<List<SpotifyUserPlaylistSummary>> getCurrentUserPlaylists({
    int limit = 50,
    int offset = 0,
    int maxPlaylists = 200,
  }) async {
    final List<SpotifyUserPlaylistSummary> playlists = [];
    int currentOffset = offset;

    try {
      final token = await getValidToken();

      while (playlists.length < maxPlaylists) {
        final url = Uri.parse('https://api.spotify.com/v1/me/playlists').replace(
          queryParameters: {
            'limit': limit.toString(),
            'offset': currentOffset.toString(),
          },
        );

        final resp = await _client.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'User-Agent': _defaultUserAgent,
          },
        ).timeout(const Duration(seconds: 12));

        if (resp.statusCode != 200) break;

        final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>? ?? [];
        if (items.isEmpty) break;

        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          final id = item['id'] as String? ?? '';
          final name = item['name'] as String? ?? 'Untitled Playlist';
          final desc = item['description'] as String?;
          final isPublic = item['public'] as bool? ?? true;
          final isCollab = item['collaborative'] as bool? ?? false;
          final snapshotId = item['snapshot_id'] as String?;
          final owner = item['owner'] as Map<String, dynamic>?;
          final ownerName =
              owner?['display_name'] as String? ?? owner?['id'] as String?;
          final tracksObj = item['tracks'] as Map<String, dynamic>?;
          final totalTracks = (tracksObj?['total'] as num?)?.toInt() ?? 0;

          String? coverUrl;
          final images = item['images'] as List<dynamic>?;
          if (images != null && images.isNotEmpty) {
            final firstImg = images.first as Map<String, dynamic>?;
            coverUrl = firstImg?['url'] as String?;
          }

          if (id.isNotEmpty) {
            playlists.add(
              SpotifyUserPlaylistSummary(
                id: id,
                name: name,
                description: desc,
                coverUrl: coverUrl,
                trackCount: totalTracks,
                ownerName: ownerName,
                isPublic: isPublic,
                isCollaborative: isCollab,
                snapshotId: snapshotId,
              ),
            );
          }
        }

        currentOffset += items.length;
        final next = json['next'] as String?;
        if (next == null || items.length < limit) break;
      }

      return playlists;
    } catch (_) {
      return playlists;
    }
  }

  /// Retrieves user's Liked / Saved Tracks directly from Spotify Web API (`GET /v1/me/tracks`).
  Future<SpotifyImportPlaylist> getCurrentUserLikedTracks({
    int limit = 50,
    int maxTracks = 5000,
    void Function(int loaded, int total)? onProgress,
  }) async {
    final List<SpotifyTrackItem> allTracks = [];
    int offset = 0;
    int total = 0;

    try {
      final token = await getValidToken();

      while (allTracks.length < maxTracks) {
        final url = Uri.parse('https://api.spotify.com/v1/me/tracks').replace(
          queryParameters: {
            'limit': limit.toString(),
            'offset': offset.toString(),
          },
        );

        final resp = await _client.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'User-Agent': _defaultUserAgent,
          },
        ).timeout(const Duration(seconds: 12));

        if (resp.statusCode != 200) break;

        final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        total = (json['total'] as num?)?.toInt() ?? total;
        final items = json['items'] as List<dynamic>? ?? [];
        if (items.isEmpty) break;

        for (final item in items) {
          final tMap = item['track'] as Map<String, dynamic>?;
          if (tMap == null) continue;
          final parsed = _parseWebApiTrack(tMap);
          if (parsed != null) allTracks.add(parsed);
        }

        offset += items.length;
        onProgress?.call(allTracks.length, total);

        final next = json['next'] as String?;
        if (next == null || items.length < limit) break;
      }

      return SpotifyImportPlaylist(
        id: 'me_liked_songs',
        name: 'Liked Songs (Spotify)',
        description: 'Imported from your Spotify Saved Tracks',
        coverUrl: 'https://misc.scdn.co/liked-songs/liked-songs-300.png',
        tracks: allTracks,
      );
    } catch (e) {
      return SpotifyImportPlaylist(
        id: 'me_liked_songs',
        name: 'Liked Songs',
        tracks: allTracks,
        notice: 'Failed to fetch some liked songs: $e',
      );
    }
  }

  /// Retrieves full playlist metadata and all tracks directly via Spotify Web API.
  Future<SpotifyImportPlaylist> getPlaylistWithTracksWebApi(
    String playlistId, {
    int maxTracks = 5000,
    void Function(int loaded, int total)? onProgress,
  }) async {
    final cleanId = _extract22CharId(playlistId);
    final List<SpotifyTrackItem> allTracks = [];
    int total = 0;
    String name = 'Imported Playlist';
    String? desc;
    String? coverUrl;

    try {
      final token = await getValidToken();

      // 1. Fetch playlist metadata
      final metaUrl = Uri.parse('https://api.spotify.com/v1/playlists/$cleanId');
      final metaResp = await _client.get(
        metaUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'User-Agent': _defaultUserAgent,
        },
      ).timeout(const Duration(seconds: 12));

      if (metaResp.statusCode == 200) {
        final metaJson = jsonDecode(utf8.decode(metaResp.bodyBytes)) as Map<String, dynamic>;
        name = metaJson['name'] as String? ?? 'Imported Playlist';
        desc = metaJson['description'] as String?;
        final images = metaJson['images'] as List<dynamic>?;
        if (images != null && images.isNotEmpty) {
          final firstImg = images.first as Map<String, dynamic>?;
          coverUrl = firstImg?['url'] as String?;
        }
        final tracksObj = metaJson['tracks'] as Map<String, dynamic>?;
        total = (tracksObj?['total'] as num?)?.toInt() ?? 0;
      }

      // 2. Paginate tracks
      int offset = 0;
      const int pageSize = 100;

      while (allTracks.length < maxTracks) {
        final tracksUrl =
            Uri.parse('https://api.spotify.com/v1/playlists/$cleanId/tracks').replace(
          queryParameters: {
            'limit': pageSize.toString(),
            'offset': offset.toString(),
          },
        );

        final tracksResp = await _client.get(
          tracksUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'User-Agent': _defaultUserAgent,
          },
        ).timeout(const Duration(seconds: 12));

        if (tracksResp.statusCode != 200) break;

        final tracksJson =
            jsonDecode(utf8.decode(tracksResp.bodyBytes)) as Map<String, dynamic>;
        total = (tracksJson['total'] as num?)?.toInt() ?? total;
        final items = tracksJson['items'] as List<dynamic>? ?? [];
        if (items.isEmpty) break;

        for (final item in items) {
          final tMap = item['track'] as Map<String, dynamic>?;
          if (tMap == null) continue;
          final parsed = _parseWebApiTrack(tMap);
          if (parsed != null) allTracks.add(parsed);
        }

        offset += items.length;
        onProgress?.call(allTracks.length, total);

        final next = tracksJson['next'] as String?;
        if (next == null || items.length < pageSize) break;
      }

      return SpotifyImportPlaylist(
        id: cleanId,
        name: name,
        description: desc,
        coverUrl: coverUrl,
        tracks: allTracks,
      );
    } catch (e) {
      return SpotifyImportPlaylist(
        id: cleanId,
        name: name,
        description: desc,
        coverUrl: coverUrl,
        tracks: allTracks,
        notice: 'Playlist tracks partially loaded: $e',
      );
    }
  }

  /// Official Spotify Web API search with authenticated Bearer token.
  Future<SpotifySearchResult> _searchWebApi(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final token = await getValidToken();
    final url = Uri.parse('https://api.spotify.com/v1/search').replace(queryParameters: {
      'q': query,
      'type': 'track,artist,album',
      'limit': limit.toString(),
      'offset': offset.toString(),
    });

    final resp = await _client.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'User-Agent': _defaultUserAgent,
      },
    ).timeout(const Duration(seconds: 8));

    if (resp.statusCode != 200) {
      return const SpotifySearchResult();
    }

    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

    // 1. Tracks
    final tracksJson = json['tracks']?['items'] as List<dynamic>? ?? [];
    final List<Track> tracks = [];
    for (final it in tracksJson) {
      if (it is! Map<String, dynamic>) continue;
      final t = _parseWebApiTrackEntity(it);
      if (t != null) tracks.add(t);
    }

    // 2. Artists
    final artistsJson = json['artists']?['items'] as List<dynamic>? ?? [];
    final List<SpotifyArtistRef> artists = [];
    for (final it in artistsJson) {
      if (it is! Map<String, dynamic>) continue;
      final id = it['id'] as String? ?? '';
      final uri = it['uri'] as String? ?? (id.isNotEmpty ? 'spotify:artist:$id' : '');
      final name = it['name'] as String? ?? '';
      String? img;
      final images = it['images'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        img = (images.first as Map<String, dynamic>?)?['url'] as String?;
      }
      if (name.isNotEmpty) {
        artists.add(SpotifyArtistRef(id: id, uri: uri, name: name, imageUrl: img));
      }
    }

    // 3. Albums
    final albumsJson = json['albums']?['items'] as List<dynamic>? ?? [];
    final List<SpotifyAlbumRef> albums = [];
    for (final it in albumsJson) {
      if (it is! Map<String, dynamic>) continue;
      final id = it['id'] as String? ?? '';
      final uri = it['uri'] as String? ?? (id.isNotEmpty ? 'spotify:album:$id' : '');
      final name = it['name'] as String? ?? '';
      final artistsList = it['artists'] as List<dynamic>?;
      final artistName = artistsList
          ?.map((a) => (a as Map<String, dynamic>?)?['name'] as String?)
          .whereType<String>()
          .join(', ');
      String? cover;
      final images = it['images'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        cover = (images.first as Map<String, dynamic>?)?['url'] as String?;
      }
      if (name.isNotEmpty) {
        albums.add(SpotifyAlbumRef(
            id: id, uri: uri, name: name, artist: artistName, coverUrl: cover));
      }
    }

    return SpotifySearchResult(
      tracks: tracks,
      artists: artists,
      albums: albums,
      topResultTitles: tracks.take(3).map((t) => t.title).toList(),
    );
  }

  SpotifyTrackItem? _parseWebApiTrack(Map<String, dynamic> trackMap) {
    final name = trackMap['name'] as String?;
    if (name == null || name.trim().isEmpty) return null;

    final uri = trackMap['uri'] as String? ?? '';
    final id = trackMap['id'] as String? ?? '';
    final cleanUri =
        uri.isNotEmpty ? uri : (id.isNotEmpty ? 'spotify:track:$id' : '');

    final artistsList = trackMap['artists'] as List<dynamic>?;
    final artist = artistsList
            ?.map((a) => (a as Map<String, dynamic>?)?['name'] as String?)
            .whereType<String>()
            .join(', ') ??
        'Unknown Artist';

    final durationMs = (trackMap['duration_ms'] as num?)?.toInt() ?? 0;
    final albumMap = trackMap['album'] as Map<String, dynamic>?;
    String? coverUrl;
    final images = albumMap?['images'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      final firstImg = images.first as Map<String, dynamic>?;
      coverUrl = firstImg?['url'] as String?;
    }

    return SpotifyTrackItem(
      spotifyUri: cleanUri,
      title: name.trim(),
      artist: artist.trim(),
      duration: Duration(milliseconds: durationMs),
      coverUrl: coverUrl,
    );
  }

  Track? _parseWebApiTrackEntity(Map<String, dynamic> item) {
    final title = (item['name'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;

    final id = item['id'] as String? ?? '';
    final artistsList = item['artists'] as List<dynamic>?;
    final artist = artistsList
            ?.map((a) => (a as Map<String, dynamic>?)?['name'] as String?)
            .whereType<String>()
            .join(', ') ??
        'Unknown Artist';

    final albumMap = item['album'] as Map<String, dynamic>?;
    final album = albumMap?['name'] as String?;
    String? cover;
    final images = albumMap?['images'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      cover = (images.first as Map<String, dynamic>?)?['url'] as String?;
    }

    final durationMs = (item['duration_ms'] as num?)?.toInt() ?? 0;

    return Track(
      id: id.isNotEmpty ? 'spotify_$id' : 'spotify_${title}_$artist',
      sourceId: id.isNotEmpty ? 'spotify_$id' : 'spotify_${title}_$artist',
      title: title,
      artist: artist,
      album: album,
      duration: Duration(milliseconds: durationMs),
      coverUrl: cover,
    );
  }
}
