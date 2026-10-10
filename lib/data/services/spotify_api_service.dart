import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/track.dart';
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
        final track = _parseSpotifyTrack(item);
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

      // 4. Top Results
      final rawTop = searchV2['topResultsV2']?['itemsV2'] as List<dynamic>? ?? [];
      final List<String> topTitles = [];
      for (final raw in rawTop) {
        final item = raw['item']?['data'] as Map<String, dynamic>?;
        if (item == null) continue;
        final tName = (item['name'] as String?) ??
            (item['profile']?['name'] as String?) ??
            (item['title']?['transformedLabel'] as String?);
        if (tName != null && tName.isNotEmpty) {
          topTitles.add(tName);
        }
      }

      return SpotifySearchResult(
        tracks: tracks,
        artists: artists,
        albums: albums,
        topResultTitles: topTitles,
      );
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
  Future<ArtistDiscography?> getArtistCompleteDiscography(String artistUriOrId) async {
    final uri = _normalizeSpotifyArtistUri(artistUriOrId);
    if (uri.isEmpty) return null;

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

      // 3. Fetch tracks from the artist's releases (up to 10 releases)
      for (final relUri in releaseUrisToFetch) {
        try {
          final albumTracks = await getAlbumTracks(relUri);
          for (final t in albumTracks) {
            addTrack(t);
          }
        } catch (_) {}
      }

      return ArtistDiscography(
        artistName: artistName,
        artistUri: uri,
        avatarUrl: avatarUrl,
        allTracks: collectedTracks,
        albums: albumRefs,
      );
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
}
