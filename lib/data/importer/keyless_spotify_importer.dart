import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/spotify_import.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_catalog_repository.dart';
import '../../domain/ports/i_spotify_importer.dart';
import '../services/spotify_auth_service.dart';

class KeylessSpotifyImporter implements ISpotifyImporter {
  final http.Client _client;
  final ICatalogRepository? _catalog;
  final SpotifyAuthService? _authService;

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static const String _tokenEndpoint =
      'https://open.spotify.com/embed/api/token';
  static const String _apiBase = 'https://api.spotify.com/v1';
  static const int _pageSize = 100;
  static const int _maxTracks = 10000;
  static const int _maxRetries = 3;

  /// Longest pause the retry loop is ever allowed to take.
  static const int _maxBackoffSeconds = 5;

  /// Hard ceiling for the whole Web API pass.
  static const Duration _fetchDeadline = Duration(seconds: 60);

  static const String _pathfinderUrl =
      'https://api-partner.spotify.com/pathfinder/v1/query';
  static const String _playlistSha256 =
      'a65e12194ed5fc443a1cdebed5fabe33ca5b07b987185d63c72483867ad13cb4';

  String? _accessToken;
  DateTime? _tokenExpiresAt;
  String? _sessionToken;
  DateTime? _sessionTokenExpiresAt;

  KeylessSpotifyImporter({
    http.Client? client,
    ICatalogRepository? catalog,
    SpotifyAuthService? authService,
  })  : _client = client ?? http.Client(),
        _catalog = catalog,
        _authService = authService;

  @override
  String? extractPlaylistId(String input) {
    return parseSpotifyEntity(input)?.id;
  }

  @override
  SpotifyEntityRef? parseSpotifyEntity(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    // 1. Spotify URI: spotify:(playlist|album|track):([a-zA-Z0-9]+)
    final uriMatch =
        RegExp(r'spotify:(playlist|album|track):([a-zA-Z0-9]+)').firstMatch(clean);
    if (uriMatch != null) {
      final typeStr = uriMatch.group(1);
      final id = uriMatch.group(2)!;
      final type = typeStr == 'album'
          ? SpotifyEntityType.album
          : (typeStr == 'track' ? SpotifyEntityType.track : SpotifyEntityType.playlist);
      return SpotifyEntityRef(id: id, type: type);
    }

    // 2. Open Spotify web URL with locale/intl, embed, or user prefixes
    final urlMatch =
        RegExp(r'open\.spotify\.com/(?:.+/)?(playlist|album|track)/([a-zA-Z0-9]+)')
            .firstMatch(clean);
    if (urlMatch != null) {
      final typeStr = urlMatch.group(1);
      final id = urlMatch.group(2)!;
      final type = typeStr == 'album'
          ? SpotifyEntityType.album
          : (typeStr == 'track' ? SpotifyEntityType.track : SpotifyEntityType.playlist);
      return SpotifyEntityRef(id: id, type: type);
    }

    // 3. Direct 22-character Spotify base62 ID (default to playlist)
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(clean)) {
      return SpotifyEntityRef(id: clean, type: SpotifyEntityType.playlist);
    }

    return null;
  }

  @override
  Future<SpotifyImportPlaylist> fetchPlaylist(
    String urlOrId, {
    void Function(int loaded)? onProgress,
  }) async {
    var cleanInput = urlOrId.trim();
    if (cleanInput.isEmpty) {
      throw FormatException('Invalid Spotify URL or ID: "$urlOrId"');
    }

    // Resolve short links like spotify.link by following redirection
    if (cleanInput.contains('spotify.link')) {
      try {
        final headResp = await _client.get(
          Uri.parse(cleanInput),
          headers: {'User-Agent': _defaultUserAgent},
        ).timeout(const Duration(seconds: 6));
        if (headResp.request?.url != null) {
          cleanInput = headResp.request!.url.toString();
        }
      } catch (_) {}
    }

    final entity = parseSpotifyEntity(cleanInput);
    if (entity == null) {
      throw FormatException('Invalid Spotify playlist, album, or track URL: "$urlOrId"');
    }

    // Album support: fetch all album tracks keylessly
    if (entity.type == SpotifyEntityType.album) {
      return _fetchAlbumViaEmbed(entity.id);
    }

    // Track support: fetch single track keylessly
    if (entity.type == SpotifyEntityType.track) {
      return _fetchTrackViaEmbed(entity.id);
    }

    // Playlist support: primary Next.js embed page
    SpotifyImportPlaylist playlist;
    try {
      playlist = await _fetchViaEmbed(entity.id);
    } catch (_) {
      // Secondary fallback: Web player page scraper
      final webResult = await _fetchViaWebPlayer(entity.id);
      if (webResult != null && webResult.tracks.isNotEmpty) {
        playlist = webResult;
      } else {
        playlist = await _fetchViaOEmbed(entity.id);
      }
    }

    // For playlists:
    // 1. Try Pathfinder GraphQL pagination first (primary high-capacity engine: supports 10,000+ tracks)
    String? token;
    try {
      token = await _getBestAvailableToken();
    } catch (_) {}

    if (token != null && token.isNotEmpty) {
      try {
        final pathfinderTracks = await _fetchViaPathfinder(
          entity.id,
          token: token,
          fallbackCover: playlist.coverUrl,
          onProgress: onProgress,
        ).timeout(_fetchDeadline);

        if (pathfinderTracks != null && pathfinderTracks.isNotEmpty) {
          if (pathfinderTracks.length >= playlist.tracks.length) {
            return playlist.copyWith(tracks: pathfinderTracks);
          }
        }
      } catch (_) {
        // Fall back to Web API pagination
      }
    }

    // 2. Fall back to Web API pagination (/items and /tracks)
    List<SpotifyTrackItem>? fullTracks;
    String? notice;
    try {
      fullTracks = await _fetchAllTracks(
        entity.id,
        coverUrl: playlist.coverUrl,
        authToken: token,
        onProgress: onProgress,
      ).timeout(_fetchDeadline);
    } on FormatException catch (e) {
      notice = e.message;
      fullTracks = null;
    } catch (_) {
      notice = playlist.tracks.length >= 100
          ? 'Spotify returned the first ${playlist.tracks.length} tracks.'
          : null;
      fullTracks = null;
    }

    if (fullTracks != null && fullTracks.isNotEmpty) {
      return playlist.copyWith(tracks: fullTracks);
    }
    return notice == null ? playlist : playlist.copyWith(notice: notice);
  }

  Future<SpotifyImportPlaylist> _fetchViaEmbed(String playlistId) async {
    final embedUri = Uri.parse('https://open.spotify.com/embed/playlist/$playlistId');
    final response = await _client
        .get(embedUri, headers: {'User-Agent': _defaultUserAgent})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to load Spotify playlist (HTTP ${response.statusCode})',
        uri: embedUri,
      );
    }

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">([^<]+)<\/script>').firstMatch(body);
    if (nextDataMatch != null) {
      final jsonStr = nextDataMatch.group(1)!;
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final state = parsed['props']?['pageProps']?['state'] as Map<String, dynamic>?;

      // Extract high-trust session token from embed payload
      final session = state?['settings']?['session'] as Map<String, dynamic>?;
      if (session != null) {
        final sToken = session['accessToken'] as String?;
        final expiresMs =
            (session['accessTokenExpirationTimestampMs'] as num?)?.toInt() ?? 0;
        if (sToken != null && sToken.isNotEmpty) {
          _sessionToken = sToken;
          _sessionTokenExpiresAt = expiresMs > 0
              ? DateTime.fromMillisecondsSinceEpoch(expiresMs)
              : DateTime.now().add(const Duration(minutes: 30));
        }
      }

      final entity = state?['data']?['entity'];

      if (entity != null) {
        final name = (entity['name'] ?? entity['title'] ?? 'Imported Spotify Playlist') as String;
        final description = entity['subtitle'] as String?;

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

    return _fetchViaOEmbed(playlistId);
  }

  Future<SpotifyImportPlaylist?> _fetchViaWebPlayer(String playlistId) async {
    try {
      final uri = Uri.parse('https://open.spotify.com/playlist/$playlistId');
      final response = await _client.get(uri, headers: {
        'User-Agent': _defaultUserAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      final html = utf8.decode(response.bodyBytes, allowMalformed: true);

      final scripts = RegExp(r'<script[^>]*>(.*?)</script>', dotAll: true).allMatches(html);
      for (final m in scripts) {
        final content = m.group(1)?.trim();
        if (content == null || content.length < 200) continue;
        try {
          final decoded = utf8.decode(base64.decode(content), allowMalformed: true);
          final json = jsonDecode(decoded) as Map<String, dynamic>;
          final entities = json['entities']?['items'] as Map<String, dynamic>?;
          final playlistObj = entities?['spotify:playlist:$playlistId'] ?? entities?.values.firstOrNull;
          if (playlistObj is Map<String, dynamic>) {
            final name = (playlistObj['name'] as String?) ?? 'Imported Spotify Playlist';
            final desc = playlistObj['description'] as String?;
            String? cover;
            final images = playlistObj['images'] as List<dynamic>?;
            if (images != null && images.isNotEmpty && images.first is Map) {
              cover = (images.first as Map)['url'] as String?;
            }
            final contentMap = playlistObj['content'] as Map<String, dynamic>?;
            final items = contentMap?['items'] as List<dynamic>?;
            if (items != null && items.isNotEmpty) {
              final tracks = <SpotifyTrackItem>[];
              for (final it in items) {
                final trackData = it['itemV2']?['data'];
                if (trackData is Map<String, dynamic>) {
                  final uri = (trackData['uri'] as String?) ?? '';
                  final title = (trackData['name'] as String?) ?? 'Unknown Title';
                  final artistsList = trackData['artists']?['items'] as List<dynamic>?;
                  final artistNames = artistsList
                          ?.map((a) => a['profile']?['name'] as String?)
                          .whereType<String>()
                          .join(', ') ??
                      'Unknown Artist';
                  final durationMs = (trackData['duration']?['totalMilliseconds'] as num?)?.toInt() ?? 0;
                  String? trackCover;
                  final albumArt = trackData['albumOfTrack']?['coverArt']?['sources'] as List<dynamic>?;
                  if (albumArt != null && albumArt.isNotEmpty) {
                    trackCover = albumArt.first['url'] as String?;
                  }
                  tracks.add(SpotifyTrackItem(
                    spotifyUri: uri,
                    title: title,
                    artist: artistNames.isEmpty ? 'Unknown Artist' : artistNames,
                    duration: Duration(milliseconds: durationMs),
                    coverUrl: trackCover ?? cover,
                  ));
                }
              }
              if (tracks.isNotEmpty) {
                return SpotifyImportPlaylist(
                  id: playlistId,
                  name: name,
                  description: desc,
                  coverUrl: cover,
                  tracks: tracks,
                );
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  Future<SpotifyImportPlaylist> _fetchAlbumViaEmbed(String albumId) async {
    final embedUri = Uri.parse('https://open.spotify.com/embed/album/$albumId');
    final response = await _client
        .get(embedUri, headers: {'User-Agent': _defaultUserAgent})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to load Spotify album (HTTP ${response.statusCode})',
        uri: embedUri,
      );
    }

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">([^<]+)<\/script>').firstMatch(body);
    if (nextDataMatch == null) {
      throw const FormatException('Could not extract album metadata from Spotify.');
    }

    final jsonStr = nextDataMatch.group(1)!;
    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    final entity = parsed['props']?['pageProps']?['state']?['data']?['entity'];
    if (entity == null) {
      throw const FormatException('Empty Spotify album data received.');
    }

    final title = (entity['name'] ?? entity['title'] ?? 'Spotify Album') as String;
    final artist = (entity['subtitle'] as String?) ?? 'Various Artists';
    String? coverUrl;
    final visualImages = entity['visualIdentity']?['image'] as List<dynamic>?;
    if (visualImages != null && visualImages.isNotEmpty) {
      coverUrl = visualImages.last['url'] as String?;
    }

    final rawTracks = (entity['trackList'] as List<dynamic>?) ?? [];
    final List<SpotifyTrackItem> tracks = [];
    for (final t in rawTracks) {
      final uri = (t['uri'] as String?) ?? '';
      final trackTitle = (t['title'] as String?) ?? 'Unknown Title';
      final trackArtist = (t['subtitle'] as String?) ?? artist;
      final durationMs = (t['duration'] as num?)?.toInt() ?? 0;

      tracks.add(
        SpotifyTrackItem(
          spotifyUri: uri,
          title: trackTitle,
          artist: trackArtist,
          duration: Duration(milliseconds: durationMs),
          coverUrl: coverUrl,
        ),
      );
    }

    return SpotifyImportPlaylist(
      id: albumId,
      name: '$title (Album)',
      description: 'Album by $artist',
      coverUrl: coverUrl,
      tracks: tracks,
    );
  }

  Future<SpotifyImportPlaylist> _fetchTrackViaEmbed(String trackId) async {
    final embedUri = Uri.parse('https://open.spotify.com/embed/track/$trackId');
    final response = await _client
        .get(embedUri, headers: {'User-Agent': _defaultUserAgent})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to load Spotify track (HTTP ${response.statusCode})',
        uri: embedUri,
      );
    }

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">([^<]+)<\/script>').firstMatch(body);
    if (nextDataMatch == null) {
      throw const FormatException('Could not extract track data from Spotify.');
    }

    final jsonStr = nextDataMatch.group(1)!;
    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    final entity = parsed['props']?['pageProps']?['state']?['data']?['entity'];
    if (entity == null) {
      throw const FormatException('Empty Spotify track data received.');
    }

    final title = (entity['name'] ?? entity['title'] ?? 'Spotify Track') as String;
    String artist = 'Unknown Artist';
    final artistsList = entity['artists'] as List<dynamic>?;
    if (artistsList != null && artistsList.isNotEmpty) {
      artist = artistsList.map((a) => a['name'] as String? ?? '').where((n) => n.isNotEmpty).join(', ');
    } else if (entity['subtitle'] != null) {
      artist = entity['subtitle'] as String;
    }

    String? coverUrl;
    final visual = entity['visualIdentity'];
    if (visual is List && visual.isNotEmpty) {
      coverUrl = visual.first['url'] as String?;
    } else if (visual is Map && visual['image'] is List) {
      coverUrl = (visual['image'] as List).last['url'] as String?;
    }

    final durationMs = (entity['duration'] as num?)?.toInt() ?? 0;

    final track = SpotifyTrackItem(
      spotifyUri: (entity['uri'] as String?) ?? 'spotify:track:$trackId',
      title: title,
      artist: artist,
      duration: Duration(milliseconds: durationMs),
      coverUrl: coverUrl,
    );

    return SpotifyImportPlaylist(
      id: trackId,
      name: title,
      description: 'Single track by $artist',
      coverUrl: coverUrl,
      tracks: [track],
    );
  }

  Future<SpotifyImportPlaylist> _fetchViaOEmbed(String playlistId) async {
    final oEmbedUri = Uri.parse(
      'https://open.spotify.com/oembed?url=https://open.spotify.com/playlist/$playlistId',
    );
    final response = await _client
        .get(oEmbedUri, headers: {'User-Agent': _defaultUserAgent})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Could not parse Spotify playlist: $playlistId');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true)) as Map<String, dynamic>;
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

  Future<String> _getAccessToken({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _accessToken != null &&
        _tokenExpiresAt != null &&
        now.isBefore(_tokenExpiresAt!.subtract(const Duration(seconds: 60)))) {
      return _accessToken!;
    }

    final response = await _client
        .get(
          Uri.parse(_tokenEndpoint),
          headers: {'User-Agent': _defaultUserAgent, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to obtain Spotify session token (HTTP ${response.statusCode})',
        uri: Uri.parse(_tokenEndpoint),
      );
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true)) as Map<String, dynamic>;
    final token = (json['accessToken'] as String?) ?? '';
    if (token.isEmpty) {
      throw const HttpException('Spotify session token was empty');
    }

    final expiresAtMs = (json['accessTokenExpirationTimestampMs'] as num?)?.toInt() ?? 0;
    _accessToken = token;
    _tokenExpiresAt = expiresAtMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
        : now.add(const Duration(minutes: 20));
    return token;
  }

  Future<String?> _getBestAvailableToken() async {
    // 1. User OAuth token if logged in
    try {
      final userToken = await _authService?.getValidAccessToken();
      if (userToken != null && userToken.isNotEmpty) {
        return userToken;
      }
    } catch (_) {}

    // 2. High-trust session token extracted from embed page payload
    final now = DateTime.now();
    if (_sessionToken != null &&
        _sessionTokenExpiresAt != null &&
        now.isBefore(_sessionTokenExpiresAt!.subtract(const Duration(seconds: 30)))) {
      return _sessionToken;
    }

    // 3. Fallback to embed/api/token
    try {
      return await _getAccessToken();
    } catch (_) {
      return _sessionToken;
    }
  }

  Future<List<SpotifyTrackItem>?> _fetchViaPathfinder(
    String playlistId, {
    required String token,
    String? fallbackCover,
    void Function(int loaded)? onProgress,
  }) async {
    final tracks = <SpotifyTrackItem>[];
    var offset = 0;
    const limit = 100;
    int? totalCount;

    var currentToken = token;
    var tokenRefreshed = false;

    while (tracks.length < _maxTracks) {
      final variables = jsonEncode({
        'uri': 'spotify:playlist:$playlistId',
        'offset': offset,
        'limit': limit,
        'enableWatchFeedEntrypoint': false,
      });
      final extensions = jsonEncode({
        'persistedQuery': {
          'version': 1,
          'sha256Hash': _playlistSha256,
        },
      });

      final uri = Uri.parse(_pathfinderUrl).replace(queryParameters: {
        'operationName': 'fetchPlaylist',
        'variables': variables,
        'extensions': extensions,
      });

      var response = await _getWithRetry(uri, currentToken);
      if (response.statusCode == 401 && !tokenRefreshed) {
        tokenRefreshed = true;
        try {
          currentToken = await _getAccessToken(forceRefresh: true);
          response = await _getWithRetry(uri, currentToken);
        } catch (_) {}
      }
      if (response.statusCode != 200) {
        break;
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true))
          as Map<String, dynamic>;
      final playlistV2 = json['data']?['playlistV2'] as Map<String, dynamic>?;
      if (playlistV2 == null) break;

      final content = playlistV2['content'] as Map<String, dynamic>?;
      if (content == null) break;

      totalCount ??= (content['totalCount'] as num?)?.toInt();
      final items = (content['items'] as List<dynamic>?) ?? [];
      if (items.isEmpty) break;

      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final track = _mapPathfinderItem(item, fallbackCover);
        if (track != null) {
          tracks.add(track);
        }
      }

      onProgress?.call(tracks.length);

      offset += items.length;
      if (totalCount != null && offset >= totalCount) break;
      if (items.length < limit) break;
    }

    return tracks.isNotEmpty ? tracks : null;
  }

  SpotifyTrackItem? _mapPathfinderItem(
    Map<String, dynamic> item,
    String? fallbackCover,
  ) {
    // 1. Primary extraction from itemV2
    final itemV2Data = item['itemV2']?['data'];
    if (itemV2Data is Map<String, dynamic>) {
      final name = itemV2Data['name'] as String?;
      if (name != null && name.isNotEmpty) {
        final uri = (itemV2Data['uri'] as String?) ?? '';
        final durationMs =
            (itemV2Data['trackDuration']?['totalMilliseconds'] as num?)?.toInt() ?? 0;

        final artistItems =
            (itemV2Data['artists']?['items'] as List<dynamic>?) ?? [];
        final artistNames = artistItems
            .map((a) {
              if (a is! Map<String, dynamic>) return '';
              final profile = a['profile'];
              if (profile is Map<String, dynamic>) {
                return (profile['name'] as String?) ?? '';
              }
              return (a['name'] as String?) ?? '';
            })
            .where((n) => n.isNotEmpty)
            .join(', ');

        String? cover = fallbackCover;
        final coverSources =
            itemV2Data['albumOfTrack']?['coverArt']?['sources'] as List<dynamic>?;
        if (coverSources != null && coverSources.isNotEmpty) {
          final first = coverSources.first;
          if (first is Map<String, dynamic>) {
            cover = first['url'] as String? ?? cover;
          }
        }

        return SpotifyTrackItem(
          spotifyUri: uri,
          title: name,
          artist: artistNames.isEmpty ? 'Unknown Artist' : artistNames,
          duration: Duration(milliseconds: durationMs),
          coverUrl: cover,
        );
      }
    }

    // 2. Fallback extraction from itemV3
    final itemV3Data = item['itemV3']?['data'];
    if (itemV3Data is Map<String, dynamic>) {
      final idTrait = itemV3Data['identityTrait'] as Map<String, dynamic>?;
      final name = idTrait?['name'] as String?;
      if (name != null && name.isNotEmpty) {
        final uri = (itemV3Data['uri'] as String?) ?? '';
        final durSeconds =
            (itemV3Data['consumptionExperienceTrait']?['duration']?['seconds'] as num?)?.toInt() ?? 0;

        final contributors =
            (idTrait?['contributors']?['items'] as List<dynamic>?) ?? [];
        final artistNames = contributors
            .map((c) => (c['name'] as String?) ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ');

        String? cover = fallbackCover;
        final visTrait = itemV3Data['visualIdentityTrait'];
        if (visTrait is Map<String, dynamic>) {
          final squareCover =
              visTrait['squareCoverImage']?['image']?['data']?['sources'] as List<dynamic>?;
          if (squareCover != null && squareCover.isNotEmpty && squareCover.first is Map) {
            cover = (squareCover.first as Map)['url'] as String? ?? cover;
          }
        }

        return SpotifyTrackItem(
          spotifyUri: uri,
          title: name,
          artist: artistNames.isEmpty ? 'Unknown Artist' : artistNames,
          duration: Duration(seconds: durSeconds),
          coverUrl: cover,
        );
      }
    }

    return null;
  }

  Future<List<SpotifyTrackItem>> _fetchAllTracks(
    String playlistId, {
    String? coverUrl,
    String? authToken,
    void Function(int loaded)? onProgress,
  }) async {
    var token = authToken ?? await _getAccessToken();
    final tracks = <SpotifyTrackItem>[];
    var offset = 0;
    var tokenRefreshed = false;

    while (tracks.length < _maxTracks) {
      var uri = Uri.parse(
        '$_apiBase/playlists/$playlistId/items?offset=$offset&limit=$_pageSize',
      );

      var response = await _getWithRetry(uri, token);

      if (response.statusCode == 404) {
        uri = Uri.parse(
          '$_apiBase/playlists/$playlistId/tracks?offset=$offset&limit=$_pageSize',
        );
        response = await _getWithRetry(uri, token);
      }

      if (response.statusCode == 401 && !tokenRefreshed) {
        tokenRefreshed = true;
        token = await _getAccessToken(forceRefresh: true);
        response = await _getWithRetry(uri, token);
      }

      if (response.statusCode == 404 || response.statusCode == 403) {
        throw HttpException(
          'Playlist tracks unavailable (HTTP ${response.statusCode})',
          uri: uri,
        );
      }
      if (response.statusCode == 429) {
        throw const FormatException(
          'Spotify\u2019s API quota for this device is exhausted, so only the '
          'first 100 tracks could be imported. Try again later for the full '
          'playlist.',
        );
      }
      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to load playlist tracks (HTTP ${response.statusCode})',
          uri: uri,
        );
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true)) as Map<String, dynamic>;
      final items = (json['items'] as List<dynamic>?) ?? const [];
      final hasNext = json['next'] != null;

      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final track = item['track'] ?? item['item'];
        if (track is! Map<String, dynamic>) continue;
        tracks.add(_mapApiTrack(track, coverUrl));
      }

      onProgress?.call(tracks.length);

      if (items.isEmpty || !hasNext) break;
      offset += items.length;
    }

    return tracks;
  }

  Future<http.Response> _getWithRetry(Uri uri, String token) async {
    const retryable = {500, 502, 503, 504};
    for (var attempt = 0;; attempt++) {
      http.Response response;
      try {
        response = await _client.get(uri, headers: {
          'User-Agent': _defaultUserAgent,
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 10));
      } on Exception {
        if (attempt >= _maxRetries) rethrow;
        response = http.Response('', 503);
      }

      if (response.statusCode == 429) {
        if (attempt >= 1) return response;
        final retryAfter =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 0;
        if (retryAfter > _maxBackoffSeconds) return response;
        await Future<void>.delayed(Duration(
          seconds: retryAfter > 0 ? retryAfter : 1,
        ));
        continue;
      }

      if (!retryable.contains(response.statusCode) ||
          attempt >= _maxRetries) {
        return response;
      }
      final backoff = 1 << attempt;
      await Future<void>.delayed(Duration(
        seconds: backoff > _maxBackoffSeconds ? _maxBackoffSeconds : backoff,
      ));
    }
  }

  SpotifyTrackItem _mapApiTrack(Map<String, dynamic> track, String? fallbackCover) {
    final artists = ((track['artists'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((a) => (a['name'] as String?) ?? '')
        .where((name) => name.isNotEmpty)
        .join(', ');

    String? cover = fallbackCover;
    final album = track['album'];
    if (album is Map<String, dynamic>) {
      final images = album['images'];
      if (images is List && images.isNotEmpty && images.first is Map) {
        final url = (images.first as Map<String, dynamic>)['url'];
        if (url is String && url.isNotEmpty) cover = url;
      }
    }

    return SpotifyTrackItem(
      spotifyUri: (track['uri'] as String?) ?? '',
      title: (track['name'] as String?) ?? 'Unknown Title',
      artist: artists.isEmpty ? 'Unknown Artist' : artists,
      duration: Duration(milliseconds: (track['duration_ms'] as num?)?.toInt() ?? 0),
      coverUrl: cover,
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
