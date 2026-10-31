import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/entities/track.dart';

/// Metadata for a track's Apple Music animated / motion cover artwork.
class AnimatedArtwork {
  final String trackId;
  final String? videoUrl;
  final String? previewImageUrl;
  final bool hasAnimatedArtwork;
  final int width;
  final int height;
  final String? albumName;
  final String? artistName;

  const AnimatedArtwork({
    required this.trackId,
    this.videoUrl,
    this.previewImageUrl,
    this.hasAnimatedArtwork = false,
    this.width = 800,
    this.height = 800,
    this.albumName,
    this.artistName,
  });

  static const AnimatedArtwork empty = AnimatedArtwork(
    trackId: '',
    hasAnimatedArtwork: false,
  );

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'videoUrl': videoUrl,
        'previewImageUrl': previewImageUrl,
        'hasAnimatedArtwork': hasAnimatedArtwork,
        'width': width,
        'height': height,
        'albumName': albumName,
        'artistName': artistName,
      };

  factory AnimatedArtwork.fromJson(Map<String, dynamic> json) =>
      AnimatedArtwork(
        trackId: json['trackId'] as String? ?? '',
        videoUrl: json['videoUrl'] as String?,
        previewImageUrl: json['previewImageUrl'] as String?,
        hasAnimatedArtwork: json['hasAnimatedArtwork'] as bool? ?? false,
        width: (json['width'] as num?)?.toInt() ?? 800,
        height: (json['height'] as num?)?.toInt() ?? 800,
        albumName: json['albumName'] as String?,
        artistName: json['artistName'] as String?,
      );
}

/// Reverse-Engineered Apple Music Animated Artwork Service.
/// Scrapes public web token, resolves motion album covers via Apple Music catalog API,
/// selects optimal H.264 renditions from HLS master playlists, and caches metadata.
class AnimatedArtworkService {
  static final AnimatedArtworkService instance =
      AnimatedArtworkService._internal();

  AnimatedArtworkService._internal();

  static const String _homeUrl = 'https://music.apple.com/us/browse';
  static const String _baseUrl = 'https://music.apple.com';
  static const String _catalogApiUrl =
      'https://amp-api-edge.music.apple.com/v1/catalog/us/search';

  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:152.0) Gecko/20100101 Firefox/152.0';

  final Map<String, AnimatedArtwork> _memoryCache = {};
  Directory? _cacheDir;
  String? _cachedToken;
  DateTime? _tokenExpiry;
  Completer<String>? _tokenCompleter;

  /// Initializes the local animated artwork cache directory.
  Future<void> initialize() async {
    try {
      final baseCacheDir = await getTemporaryDirectory();
      _cacheDir =
          Directory(p.join(baseCacheDir.path, 'softify_animated_artwork'));
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
    } catch (_) {}
  }

  /// Scrapes public Apple Music web player bearer token without account requirements.
  Future<String> _getWebToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken!;
    }

    if (_tokenCompleter != null) {
      return _tokenCompleter!.future;
    }

    _tokenCompleter = Completer<String>();

    try {
      final homeResp = await http.get(
        Uri.parse(_homeUrl),
        headers: {'User-Agent': _userAgent},
      );

      if (homeResp.statusCode != 200) {
        throw Exception('Failed to load Apple Music home: ${homeResp.statusCode}');
      }

      final indexMatch =
          RegExp(r'/assets/index~[^\"]+\.js').firstMatch(homeResp.body);
      if (indexMatch == null) {
        throw Exception('Apple Music web bundle index not found');
      }

      final bundleUrl = '$_baseUrl${indexMatch.group(0)}';
      final bundleResp = await http.get(
        Uri.parse(bundleUrl),
        headers: {'User-Agent': _userAgent},
      );

      if (bundleResp.statusCode != 200) {
        throw Exception('Failed to load bundle: ${bundleResp.statusCode}');
      }

      final jwtMatches = RegExp(
        r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
      ).allMatches(bundleResp.body);

      String? selectedToken;
      for (final match in jwtMatches) {
        final token = match.group(0);
        if (token == null) continue;
        try {
          final parts = token.split('.');
          if (parts.length < 2) continue;
          final normalized = base64Url.normalize(parts[1]);
          final payload = utf8.decode(base64Url.decode(normalized));
          if (payload.contains('"iss":"AMPWebPlay"')) {
            selectedToken = token;
            break;
          }
        } catch (_) {}
      }

      selectedToken ??= jwtMatches.isNotEmpty ? jwtMatches.first.group(0) : null;
      if (selectedToken == null) {
        throw Exception('No valid bearer JWT found in Apple Music bundle');
      }

      _cachedToken = selectedToken;
      // Tokens usually live for months; refresh conservatively after 24 hours
      _tokenExpiry = DateTime.now().add(const Duration(hours: 24));
      _tokenCompleter!.complete(selectedToken);
      return selectedToken;
    } catch (e) {
      _cachedToken = null;
      _tokenCompleter?.completeError(e);
      rethrow;
    } finally {
      _tokenCompleter = null;
    }
  }

  void _clearToken() {
    _cachedToken = null;
    _tokenExpiry = null;
  }

  /// Cleans track/artist titles for Apple Music search query.
  String _cleanForSearch(String text) {
    var cleaned = text;
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\((feat\.|ft\.|official|audio|video|lyric|remastered|mono|stereo)[^\)]*\)',
        caseSensitive: false,
      ),
      ' ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\[(feat\.|ft\.|official|audio|video|lyric|remastered|mono|stereo|mv)[^\]]*\]',
        caseSensitive: false,
      ),
      ' ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[\-_/\\|]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Resolves the animated artwork for a track.
  Future<AnimatedArtwork> resolveAnimatedArtwork(Track track) async {
    if (track.id.isEmpty) return AnimatedArtwork.empty;

    // 1. Memory Cache
    if (_memoryCache.containsKey(track.id)) {
      return _memoryCache[track.id]!;
    }

    // 2. Disk Cache
    if (_cacheDir == null) {
      await initialize();
    }
    if (_cacheDir != null) {
      try {
        final cacheFile = File(p.join(_cacheDir!.path, '${track.id}.json'));
        if (await cacheFile.exists()) {
          final content = await cacheFile.readAsString();
          final data = json.decode(content) as Map<String, dynamic>;
          final cached = AnimatedArtwork.fromJson(data);
          _memoryCache[track.id] = cached;
          return cached;
        }
      } catch (_) {}
    }

    // 3. Network Resolution
    try {
      final resolved = await _fetchAnimatedArtworkFromApple(track);
      if (resolved != null && resolved.hasAnimatedArtwork) {
        _memoryCache[track.id] = resolved;
        if (_cacheDir != null) {
          try {
            final cacheFile =
                File(p.join(_cacheDir!.path, '${track.id}.json'));
            await cacheFile.writeAsString(json.encode(resolved.toJson()));
          } catch (_) {}
        }
        return resolved;
      }
    } catch (_) {}

    // Fallback: empty marker so we avoid spamming network for non-existent artworks
    final emptyArtwork = AnimatedArtwork(
      trackId: track.id,
      hasAnimatedArtwork: false,
    );
    _memoryCache[track.id] = emptyArtwork;
    return emptyArtwork;
  }

  Future<AnimatedArtwork?> _fetchAnimatedArtworkFromApple(Track track) async {
    final artistClean = _cleanForSearch(track.artist);
    final titleClean = _cleanForSearch(track.title);
    final albumClean =
        track.album != null ? _cleanForSearch(track.album!) : null;

    final token = await _getWebToken();

    final headers = {
      'Authorization': 'Bearer $token',
      'Origin': _baseUrl,
      'Referer': '$_baseUrl/',
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    };

    // Tier 1: Search by album name if valid
    if (albumClean != null &&
        albumClean.isNotEmpty &&
        albumClean.toLowerCase() != 'album') {
      try {
        final query = '$albumClean $artistClean'.trim();
        final uri = Uri.parse(_catalogApiUrl).replace(
          queryParameters: {
            'term': query,
            'types': 'albums',
            'fields[albums]': 'name,artistName,url,artwork,editorialVideo',
            'format[resources]': 'map',
            'extend': 'editorialVideo',
            'l': 'en-US',
            'limit': '5',
            'platform': 'web',
          },
        );

        var resp = await http.get(uri, headers: headers);
        if (resp.statusCode == 401) {
          _clearToken();
          final freshToken = await _getWebToken();
          headers['Authorization'] = 'Bearer $freshToken';
          resp = await http.get(uri, headers: headers);
        }

        if (resp.statusCode == 200) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          final resources =
              data['resources']?['albums'] as Map<String, dynamic>?;
          if (resources != null && resources.isNotEmpty) {
            for (final entry in resources.values) {
              final attrs = entry['attributes'] as Map<String, dynamic>?;
              if (attrs == null) continue;
              final edVideo =
                  attrs['editorialVideo'] as Map<String, dynamic>?;
              if (edVideo != null) {
                final match = await _processEditorialVideo(
                  track.id,
                  edVideo,
                  attrs['name'] as String?,
                  attrs['artistName'] as String?,
                );
                if (match != null) return match;
              }
            }
          }
        }
      } catch (_) {}
    }

    // Tier 2: Search songs with parent album editorialVideo
    try {
      final query = '$titleClean $artistClean'.trim();
      final uri = Uri.parse(_catalogApiUrl).replace(
        queryParameters: {
          'term': query,
          'types': 'songs',
          'extend': 'editorialVideo',
          'format[resources]': 'map',
          'l': 'en-US',
          'limit': '5',
          'platform': 'web',
        },
      );

      var resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 401) {
        _clearToken();
        final freshToken = await _getWebToken();
        headers['Authorization'] = 'Bearer $freshToken';
        resp = await http.get(uri, headers: headers);
      }

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final songs = data['resources']?['songs'] as Map<String, dynamic>?;
        final albums = data['resources']?['albums'] as Map<String, dynamic>?;

        if (songs != null && albums != null) {
          for (final song in songs.values) {
            final songAttrs = song['attributes'] as Map<String, dynamic>?;
            final albumRel = song['relationships']?['albums']?['data'] as List?;
            final albumId = albumRel?.isNotEmpty == true
                ? albumRel!.first['id'] as String?
                : null;
            if (albumId != null && albums.containsKey(albumId)) {
              final albumObj = albums[albumId] as Map<String, dynamic>;
              final albumAttrs = albumObj['attributes'] as Map<String, dynamic>?;
              final edVideo =
                  albumAttrs?['editorialVideo'] as Map<String, dynamic>?;
              if (edVideo != null) {
                final match = await _processEditorialVideo(
                  track.id,
                  edVideo,
                  albumAttrs?['name'] as String?,
                  songAttrs?['artistName'] as String? ??
                      albumAttrs?['artistName'] as String?,
                );
                if (match != null) return match;
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<AnimatedArtwork?> _processEditorialVideo(
    String trackId,
    Map<String, dynamic> edVideo,
    String? albumName,
    String? artistName,
  ) async {
    // Select preferred rendition per SimpMusic reverse-engineering:
    // motionDetailSquare -> motionDetailTall -> motionSquareVideo1x1 -> motionTallVideo3x4
    final rendition = edVideo['motionDetailSquare'] ??
        edVideo['motionDetailTall'] ??
        edVideo['motionSquareVideo1x1'] ??
        edVideo['motionTallVideo3x4'];

    if (rendition is! Map<String, dynamic>) return null;

    final masterUrl = rendition['video'] as String?;
    if (masterUrl == null || !masterUrl.contains('.m3u8')) return null;

    // Format preview still frame URL
    String? previewUrl;
    final previewFrame = rendition['previewFrame'] as Map<String, dynamic>?;
    if (previewFrame != null) {
      final rawUrl = previewFrame['url'] as String?;
      if (rawUrl != null) {
        previewUrl = rawUrl
            .replaceAll('{w}', '800')
            .replaceAll('{h}', '800')
            .replaceAll('{c}', '')
            .replaceAll('{f}', 'jpg');
      }
    }

    // Resolve optimal HLS rendition from master playlist
    final optimalVideoUrl = await _resolveOptimalHlsRendition(masterUrl);

    return AnimatedArtwork(
      trackId: trackId,
      videoUrl: optimalVideoUrl ?? masterUrl,
      previewImageUrl: previewUrl,
      hasAnimatedArtwork: true,
      width: 800,
      height: 800,
      albumName: albumName,
      artistName: artistName,
    );
  }

  /// Parses master .m3u8 playlist and selects the optimal H.264 (avc1) stream.
  Future<String?> _resolveOptimalHlsRendition(String masterUrl) async {
    try {
      final resp = await http.get(Uri.parse(masterUrl));
      if (resp.statusCode != 200) return null;

      final playlistText = resp.body;
      final lines = playlistText.split('\n');

      final variants = <_HlsVariant>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('#EXT-X-STREAM-INF:')) {
          final resMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
          final codecMatch = RegExp(r'CODECS="([^"]+)"').firstMatch(line);
          final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);

          final nextLine = (i + 1 < lines.length) ? lines[i + 1].trim() : '';
          if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
            var uri = nextLine;
            if (!uri.startsWith('http')) {
              uri = Uri.parse(masterUrl).resolve(uri).toString();
            }

            final width = resMatch != null
                ? int.tryParse(resMatch.group(1) ?? '') ?? 0
                : 0;
            final height = resMatch != null
                ? int.tryParse(resMatch.group(2) ?? '') ?? 0
                : 0;
            final bandwidth = bwMatch != null
                ? int.tryParse(bwMatch.group(1) ?? '') ?? 0
                : 0;
            final codecs = codecMatch?.group(1) ?? '';

            variants.add(
              _HlsVariant(
                uri: uri,
                width: width,
                height: height,
                bandwidth: bandwidth,
                codecs: codecs,
              ),
            );
          }
        }
      }

      if (variants.isEmpty) return null;

      // Filter for H.264 (avc1) to avoid heavy HEVC 10-bit software decoding
      final h264List =
          variants.where((v) => v.codecs.startsWith('avc1')).toList();
      final pool = h264List.isNotEmpty ? h264List : variants;

      // Pick rendition at or above 720px width (or maximum available if below)
      final wideEnough = pool.where((v) => v.width >= 720).toList();
      int targetWidth;
      if (wideEnough.isNotEmpty) {
        targetWidth =
            wideEnough.map((v) => v.width).reduce((a, b) => a < b ? a : b);
      } else {
        targetWidth =
            pool.map((v) => v.width).reduce((a, b) => a > b ? a : b);
      }

      final candidates = pool.where((v) => v.width == targetWidth).toList();
      candidates.sort((a, b) => a.bandwidth.compareTo(b.bandwidth));
      return candidates.first.uri;
    } catch (_) {
      return null;
    }
  }

  /// Clears in-memory and disk cache.
  Future<void> clearCache() async {
    _memoryCache.clear();
    try {
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
    } catch (_) {}
  }
}

class _HlsVariant {
  final String uri;
  final int width;
  final int height;
  final int bandwidth;
  final String codecs;

  _HlsVariant({
    required this.uri,
    required this.width,
    required this.height,
    required this.bandwidth,
    required this.codecs,
  });
}
