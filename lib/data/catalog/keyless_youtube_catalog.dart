import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_catalog_repository.dart';
import '../resolvers/youtube_innertube_service.dart';
import '../search/text_normalizer.dart';
import '../services/spotify_api_service.dart';

enum SoftifyTrackVibe {
  party,
  romantic,
  sad,
  hiphop,
  rock,
  punjabiParty,
  punjabiRomantic,
  chillAcoustic,
  general,
}

class KeylessYouTubeCatalog implements ICatalogRepository {
  final YoutubeExplode _yt;
  final YoutubeInnertubeService _innertubeService;
  final List<String> _instances;
  final HttpClient _httpClient;
  final SpotifyApiService _spotifyApi;

  final Map<String, List<Track>> _searchCache = {};
  final Map<String, List<Track>> _genreCandidatePoolCache = {};
  final List<String> _recentlyServedTrackIds = [];
  List<Track>? _trendingCache;
  DateTime? _trendingCacheTime;
  static const Duration _trendingTtl = Duration(hours: 2);

  KeylessYouTubeCatalog({
    YoutubeExplode? yt,
    YoutubeInnertubeService? innertubeService,
    List<String>? instances,
    HttpClient? httpClient,
    SpotifyApiService? spotifyApi,
  })  : _yt = yt ?? YoutubeExplode(),
        _innertubeService = innertubeService ?? YoutubeInnertubeService(),
        _instances = instances ??
            [
              'https://pipedapi.ducks.party',
              'https://api.piped.private.coffee',
            ],
        _httpClient = httpClient ??
            (HttpClient()
              ..idleTimeout = const Duration(seconds: 45)
              ..maxConnectionsPerHost = 8),
        _spotifyApi = spotifyApi ?? SpotifyApiService();

  void _cacheResult(Map<String, List<Track>> cache, String key, List<Track> tracks) {
    if (cache.length >= 60) {
      cache.remove(cache.keys.first);
    }
    cache[key] = tracks;
  }

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final cacheKey = '${cleanQuery}_$limit';
    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    // 1. Primary: Reverse Engineered Spotify Pathfinder Search (Official catalog, canonical tracks & art)
    try {
      final spotifyRes = await _spotifyApi.search(cleanQuery, limit: limit).catchError((_) => const SpotifySearchResult());
      if (spotifyRes.tracks.isNotEmpty) {
        final filtered = spotifyRes.tracks.where((t) => !t.isYoutube).toList();
        if (filtered.isNotEmpty) {
          final deduped = _deduplicateTracks(filtered, limit: limit, query: cleanQuery);
          _cacheResult(_searchCache, cacheKey, deduped);
          return deduped;
        }
      }
    } catch (_) {
      // Fall through to query sanitization
    }

    // 2. Spotify Sanitized Query Fallback (strip noise words and retry Spotify)
    try {
      final sanitized = cleanQuery
          .replaceAll(RegExp(r'\b(song|songs|track|music|audio|full|mp3)\b', caseSensitive: false), '')
          .trim();
      if (sanitized.isNotEmpty && sanitized != cleanQuery) {
        final spotifyRes = await _spotifyApi.search(sanitized, limit: limit).catchError((_) => const SpotifySearchResult());
        if (spotifyRes.tracks.isNotEmpty) {
          final filtered = spotifyRes.tracks.where((t) => !t.isYoutube).toList();
          if (filtered.isNotEmpty) {
            final deduped = _deduplicateTracks(filtered, limit: limit, query: sanitized);
            _cacheResult(_searchCache, cacheKey, deduped);
            return deduped;
          }
        }
      }
    } catch (_) {}

    // 3. Fallback: YouTube Music API (WEB_REMIX official tracks & topic releases)
    try {
      final ytmTracks = await _innertubeService.searchMusicTrackEntities(cleanQuery, limit: limit);
      if (ytmTracks.isNotEmpty) {
        final deduped = _deduplicateTracks(ytmTracks, limit: limit, query: cleanQuery);
        _cacheResult(_searchCache, cacheKey, deduped);
        return deduped;
      }
    } catch (_) {}

    return [];
  }


  List<Track> _deduplicateTracks(
    List<Track> rawTracks, {
    int limit = 20,
    String? query,
  }) {
    // Score all tracks first so the canonical original / most popular track is on top,
    // using catalog's native rank as a deterministic tie-breaker.
    final scored = [
      for (int i = 0; i < rawTracks.length; i++)
        (
          track: rawTracks[i],
          index: i,
          score: TextNormalizer.scoreTrackOriginality(rawTracks[i], query: query),
        )
    ];

    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.index.compareTo(b.index);
    });

    final sorted = scored.map((s) => s.track).toList();
    final List<Track> deduplicated = [];

    for (final track in sorted) {
      final existingIdx = deduplicated.indexWhere((existing) =>
          TextNormalizer.isSameSongCluster(a: existing, b: track));

      if (existingIdx == -1) {
        deduplicated.add(track);
      } else if (track.isLyricsMatch && !deduplicated[existingIdx].isLyricsMatch) {
        deduplicated[existingIdx] = deduplicated[existingIdx].copyWith(isLyricsMatch: true);
      }

      if (deduplicated.length >= limit) break;
    }

    return deduplicated;
  }


  String _decodeHtml(String raw) {
    return raw
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  String _cleanTitle(String rawTitle) {
    return _decodeHtml(rawTitle)
        .replaceAll(RegExp(r'\s*[\(\[]\s*official\s*(video|audio|music video|lyric video|lyrics)?\s*[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\|\s*4K|\s*\|\s*HD|\s*\|\s*full song', caseSensitive: false), '')
        .trim();
  }

  @override
  Future<List<Track>> getTrendingTracks({int limit = 30}) async {
    if (_trendingCache != null &&
        _trendingCache!.isNotEmpty &&
        _trendingCacheTime != null &&
        DateTime.now().difference(_trendingCacheTime!) < _trendingTtl) {
      return _trendingCache!;
    }

    // 1. Primary: Spotify Pathfinder Trending & Top Charts
    try {
      final tracks = await _spotifyApi.getTrendingTracks(limit: limit);
      if (tracks.isNotEmpty) {
        _trendingCache = tracks;
        _trendingCacheTime = DateTime.now();
        return tracks;
      }
    } catch (_) {}

    // 2. Secondary: Spotify Search for Top India hits
    try {
      final sRes = await _spotifyApi.search('Top Songs India', limit: limit);
      if (sRes.tracks.isNotEmpty) {
        _trendingCache = sRes.tracks;
        _trendingCacheTime = DateTime.now();
        return sRes.tracks;
      }
    } catch (_) {}

    return [];
  }

  static const Map<String, String> _spotifyChartQueries = {
    'hindi': 'Hot Hits Hindi',
    'punjabi': 'Punjabi 101',
    'international': 'Today\'s Top Hits',
    'love': 'Bollywood Romantic Hits',
    'trending': 'Top 50 India',
  };

  Future<List<Track>> getTopChart(String chartType, {int limit = 30}) async {
    final typeKey = chartType.trim().toLowerCase();
    final query = _spotifyChartQueries[typeKey] ?? '$chartType Top Hits';
    try {
      final res = await _spotifyApi.search(query, limit: limit);
      if (res.tracks.isNotEmpty) {
        return res.tracks;
      }
    } catch (_) {}

    return getTrendingTracks(limit: limit);
  }

  @override
  Future<List<String>> getSearchSuggestions(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    // 1. Primary: Reverse engineered Spotify Search Suggestions
    try {
      final spotifySuggestions = await _spotifyApi.getSearchSuggestions(clean);
      if (spotifySuggestions.isNotEmpty) return spotifySuggestions;
    } catch (_) {}

    // 2. Secondary: YouTube Music API Search Suggestions (strictly musical artist/track queries)
    try {
      final ytmSuggestions = await _innertubeService.getMusicSearchSuggestions(clean);
      if (ytmSuggestions.isNotEmpty) return ytmSuggestions;
    } catch (_) {}

    try {
      final uri = Uri.parse(
        'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${Uri.encodeComponent(clean)}',
      );
      final request =
          await _httpClient.getUrl(uri).timeout(const Duration(seconds: 4));
      final response =
          await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as List<dynamic>;
        if (json.length >= 2 && json[1] is List) {
          final list = (json[1] as List).map((e) => e.toString()).toList();
          return list;
        }
      }
    } catch (_) {}

    for (final instance in _instances) {
      try {
        final uri = Uri.parse(
          '$instance/suggestions?query=${Uri.encodeComponent(clean)}',
        );
        final request =
            await _httpClient.getUrl(uri).timeout(const Duration(seconds: 3));
        final response =
            await request.close().timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final list =
              (jsonDecode(body) as List).map((e) => e.toString()).toList();
          return list;
        }
      } catch (_) {}
    }

    return [];
  }

  @override
  Future<List<Track>> getArtistTracks(String artist, {int limit = 25}) async {
    // 1. Primary: Reverse engineered Spotify Artist Top Tracks
    try {
      String? artistUri;
      final clean = artist.trim();
      if (clean.startsWith('spotify:artist:') || RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(clean)) {
        artistUri = clean;
      } else {
        // Query Spotify search to resolve genuine artist URI
        final searchRes = await _spotifyApi.search(clean, limit: 5);
        final match = searchRes.artists.firstWhere(
          (a) => TextNormalizer.matchesArtist(a.name, clean),
          orElse: () => searchRes.artists.isNotEmpty ? searchRes.artists.first : const SpotifyArtistRef(id: '', uri: '', name: ''),
        );
        if (match.uri.isNotEmpty) {
          artistUri = match.uri;
        }
      }

      if (artistUri != null && artistUri.isNotEmpty) {
        final spotifyTracks = await _spotifyApi.getArtistTopTracks(artistUri);
        final filtered = spotifyTracks.where((t) => TextNormalizer.matchesArtist(t.artist, artist)).toList();
        if (filtered.isNotEmpty) return filtered.take(limit).toList();
      }
    } catch (_) {}

    // 2. Secondary: Spotify Search fallback with strict artist match filtering
    try {
      final sRes = await _spotifyApi.search('$artist songs', limit: limit * 2);
      final filtered = sRes.tracks.where((t) => TextNormalizer.matchesArtist(t.artist, artist)).toList();
      if (filtered.isNotEmpty) return filtered.take(limit).toList();
      if (sRes.tracks.isNotEmpty) return sRes.tracks.take(limit).toList();
    } catch (_) {}

    return [];
  }

  static Set<String> _extractNumberTokens(String s) {
    final tokens = RegExp(r'\b(?:\d+|ii|iii|iv|v|vi|vii|viii|ix|x)\b', caseSensitive: false)
        .allMatches(s)
        .map((m) => m.group(0)!.toLowerCase())
        .toSet();
    const romanMap = {
      'i': '1',
      'ii': '2',
      'iii': '3',
      'iv': '4',
      'v': '5',
      'vi': '6',
      'vii': '7',
      'viii': '8',
      'ix': '9',
      'x': '10',
    };
    return tokens.map((t) => romanMap[t] ?? t).toSet();
  }

  static String _cleanAlbumTitleForMatch(String s) {
    var cleaned = s.replaceAll(
      RegExp(
        r'[\(\[](?:original motion picture soundtrack|soundtrack|deluxe edition|deluxe|bonus track version|edition|ep|single|ost|remixes)[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*-\s*(?:ep|single|deluxe|soundtrack).*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').toLowerCase();
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static double _calculateAlbumMatchScore(
    String targetAlbum,
    String candidateAlbum, {
    String? targetArtist,
    String? candidateArtist,
  }) {
    final targetNums = _extractNumberTokens(targetAlbum);
    final candNums = _extractNumberTokens(candidateAlbum);

    // Strict number parity: if target has numbers, candidate MUST have the exact same numbers.
    // Prevents "Student of the Year 2" from matching "Student of the Year 1", and vice versa.
    if (targetNums.length != candNums.length || !targetNums.containsAll(candNums)) {
      return -1.0;
    }

    final normTarget = _cleanAlbumTitleForMatch(targetAlbum);
    final normCand = _cleanAlbumTitleForMatch(candidateAlbum);

    if (normTarget.isEmpty || normCand.isEmpty) return 0.0;
    if (normTarget == normCand) return 1.0;
    if (normCand.startsWith(normTarget) || normTarget.startsWith(normCand)) return 0.9;

    final tWords = normTarget.split(' ').where((w) => w.isNotEmpty).toSet();
    final cWords = normCand.split(' ').where((w) => w.isNotEmpty).toSet();
    if (tWords.isEmpty || cWords.isEmpty) return 0.0;

    final intersection = tWords.intersection(cWords);
    final union = tWords.union(cWords);
    var score = intersection.length / union.length;

    // Boost score if artist tokens match
    if (targetArtist != null &&
        candidateArtist != null &&
        targetArtist.isNotEmpty &&
        candidateArtist.isNotEmpty) {
      if (TextNormalizer.matchesArtist(candidateArtist, targetArtist)) {
        score += 0.15;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  @override
  Future<List<Track>> getAlbumTracks(
    String album,
    String artist, {
    int limit = 25,
  }) async {
    // 1. Primary: Reverse engineered Spotify Album Tracks with strict album scoring
    try {
      var sRes = await _spotifyApi.search('$album $artist', limit: 5);
      if (sRes.albums.isEmpty) {
        sRes = await _spotifyApi.search(album, limit: 5);
      }
      if (sRes.albums.isNotEmpty) {
        SpotifyAlbumRef? bestAlbum;
        double bestScore = 0.65;
        for (final cand in sRes.albums) {
          final score = _calculateAlbumMatchScore(
            album,
            cand.name,
            targetArtist: artist,
            candidateArtist: cand.artist,
          );
          if (score > bestScore) {
            bestScore = score;
            bestAlbum = cand;
          }
        }
        if (bestAlbum != null) {
          final spotifyTracks = await _spotifyApi.getAlbumTracks(bestAlbum.id);
          if (spotifyTracks.isNotEmpty) return spotifyTracks.take(limit).toList();
        }
      }
    } catch (_) {}

    // 2. Secondary: Spotify search fallback
    try {
      final sResTracks = await _spotifyApi.search('$album $artist', limit: limit);
      if (sResTracks.tracks.isNotEmpty) return sResTracks.tracks.take(limit).toList();
    } catch (_) {}

    return [];
  }

  @override
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) async {
    final poolKey = '${track.id}_${track.sourceId}';

    // 1. Retrieve or harvest a rich candidate pool strictly in the same genre & vibe
    List<Track> candidatePool = _genreCandidatePoolCache[poolKey] ?? [];
    if (candidatePool.isEmpty) {
      final harvested = await _harvestGenreCandidates(track);
      if (harvested.isNotEmpty) {
        candidatePool = harvested;
        _cacheResult(_genreCandidatePoolCache, poolKey, candidatePool);
      }
    }

    // If candidatePool is empty, fall back to artist catalog search to ensure autoplay continuity
    if (candidatePool.isEmpty) {
      try {
        final artistTracks = await search(track.artist, limit: 20);
        candidatePool = artistTracks.where((t) => t.id != track.id).toList();
      } catch (_) {}
    }

    if (candidatePool.isEmpty) return [];

    // 2. Filter for Artist Diversity (prevent same band/artist repetition)
    final cleanSeedTitle = _cleanTitle(track.title).toLowerCase();
    final seedArtistTokens = _extractArtistTokens(track.artist);
    final seenIds = <String>{track.id, track.sourceId};
    final seenArtists = <String>{};
    final seedVibe = _classifyTrackVibe(track, null);
    int seedArtistCount = 0;

    final List<Track> diverseCandidates = [];

    for (final cand in candidatePool) {
      if (cand.id.startsWith('podcast_') ||
          cand.sourceId.startsWith('podcast_')) {
        continue;
      }
      if (seenIds.contains(cand.id) || seenIds.contains(cand.sourceId)) {
        continue;
      }
      if (_isJunkOrMashup(cand)) {
        continue;
      }
      if (!_isVibeCompatible(cand, seedVibe)) {
        continue;
      }
      final candTitle = _cleanTitle(cand.title).toLowerCase();
      if (candTitle == cleanSeedTitle) {
        continue;
      }

      final candArtistTokens = _extractArtistTokens(cand.artist);
      final isSeedArtist = candArtistTokens.any((cat) => seedArtistTokens
          .any((sat) => cat.contains(sat) || sat.contains(cat)));

      if (isSeedArtist) {
        // Enforce max 1 track by the seed band/artist to avoid repetitive artists
        if (seedArtistCount >= 1) {
          continue;
        }
        seedArtistCount++;
      } else {
        // Enforce max 1 track per any other artist to eliminate band clustering
        final alreadySeen = candArtistTokens.any((cat) =>
            seenArtists.any((seen) => seen.contains(cat) || cat.contains(seen)));
        if (alreadySeen) {
          continue;
        }
      }

      for (final cat in candArtistTokens) {
        seenArtists.add(cat);
      }
      seenIds.add(cand.id);
      seenIds.add(cand.sourceId);
      diverseCandidates.add(cand);
    }

    // If strict vibe check eliminated all candidates, fallback to candidatePool to prevent autoplay halt
    if (diverseCandidates.isEmpty && candidatePool.isNotEmpty) {
      for (final cand in candidatePool) {
        if (!cand.id.startsWith('podcast_') &&
            !cand.sourceId.startsWith('podcast_') &&
            cand.id != track.id &&
            cand.sourceId != track.sourceId) {
          diverseCandidates.add(cand);
        }
      }
    }

    // 3. Dynamic session rotation & anti-repetition queue generation
    // Spotify's track radio order has highest affinity near the top.
    // We maintain high-affinity anchors while rotating discovery candidates across listens.
    final List<Track> selected = [];
    final random = Random();

    // Tracks not recently served to the user take precedence for novelty
    final freshPool = diverseCandidates
        .where((c) =>
            !_recentlyServedTrackIds.contains(c.id) &&
            !_recentlyServedTrackIds.contains(c.sourceId))
        .toList();
    final previouslyServedPool = diverseCandidates
        .where((c) =>
            _recentlyServedTrackIds.contains(c.id) ||
            _recentlyServedTrackIds.contains(c.sourceId))
        .toList();

    // 3a. Top Anchor: Take high-affinity track near front of Spotify's model
    // with dynamic jitter across top-3 to ensure repeated plays rotate anchors
    if (freshPool.isNotEmpty) {
      final anchorWindow = min(3, freshPool.length);
      final anchorIndex = random.nextInt(anchorWindow);
      selected.add(freshPool.removeAt(anchorIndex));
    } else if (diverseCandidates.isNotEmpty) {
      final anchorWindow = min(3, diverseCandidates.length);
      final anchorCandidate = diverseCandidates[random.nextInt(anchorWindow)];
      selected.add(anchorCandidate);
      previouslyServedPool.remove(anchorCandidate);
    }

    // 3b. Sample remaining slots dynamically from fresh candidates first
    freshPool.shuffle(random);
    while (selected.length < limit && freshPool.isNotEmpty) {
      selected.add(freshPool.removeAt(0));
    }

    // 3c. If fresh pool was smaller than limit, fill remaining slots from previously served pool
    if (selected.length < limit && previouslyServedPool.isNotEmpty) {
      previouslyServedPool.shuffle(random);
      while (selected.length < limit && previouslyServedPool.isNotEmpty) {
        selected.add(previouslyServedPool.removeAt(0));
      }
    }

    // If strict 1-per-artist filtering yielded fewer than limit, relax filter to fill limit
    // but STRICTLY using candidates from the same genre pool and strictly compatible vibe!
    if (selected.length < limit) {
      for (final cand in candidatePool) {
        if (!cand.isYoutube &&
            !cand.id.startsWith('yt_') &&
            !cand.id.startsWith('podcast_') &&
            !cand.sourceId.startsWith('podcast_') &&
            !seenIds.contains(cand.id) &&
            !seenIds.contains(cand.sourceId) &&
            !_isJunkOrMashup(cand) &&
            _isVibeCompatible(cand, seedVibe) &&
            _cleanTitle(cand.title).toLowerCase() != cleanSeedTitle) {
          seenIds.add(cand.id);
          seenIds.add(cand.sourceId);
          selected.add(cand);
          if (selected.length >= limit) break;
        }
      }
    }

    // Record selected tracks in session history for anti-repetition rotation
    for (final s in selected) {
      _recentlyServedTrackIds.add(s.id);
      _recentlyServedTrackIds.add(s.sourceId);
    }
    // Prune history if it grows too large (keep last 120 track IDs)
    if (_recentlyServedTrackIds.length > 120) {
      _recentlyServedTrackIds.removeRange(0, _recentlyServedTrackIds.length - 120);
    }

    final finalTracks = selected.take(limit).toList();

    // Resolve authentic album covers from Spotify (guarantees real album art instead of radio banners)
    return await _spotifyApi.resolveAuthenticCovers(finalTracks);
  }

  static final _indianArtists = <String>{
    'arijit', 'pritam', 'mithoon', 'atif aslam', 'shreya ghoshal', 'kumar sanu',
    'alka yagnik', 'sonu nigam', 'udit narayan', 'lata mangeshkar', 'kishore kumar',
    'mohit chauhan', 'jubin nautiyal', 'neha kakkar', 'badshah', 'yo yo honey singh',
    'ap dhillon', 'diljit', 'sidhu moose', 'karan aujla', 'shubh', 'guru randhawa',
    'b praak', 'jasleen royal', 'armaan malik', 'amaal mallik', 'himesh reshammiya',
    'vishal-shekhar', 'sachin-jigar', 'shankar-ehsaan-loy', 'ar rahman', 'a.r. rahman',
    'ankit tiwari', 'jeet gannguli', 'meet bros', 'darshan raval', 'vishal mishra'
  };

  bool _isIndianTrack(Track track, String? genre) {
    final combined = '${track.title} ${track.artist} ${track.album ?? ''} ${genre ?? ''}'.toLowerCase();
    if (combined.contains('bollywood') ||
        combined.contains('hindi') ||
        combined.contains('punjabi') ||
        combined.contains('tamil') ||
        combined.contains('telugu') ||
        combined.contains('bengali') ||
        combined.contains('malayalam') ||
        combined.contains('marathi') ||
        combined.contains('kannada') ||
        combined.contains('bhojpuri') ||
        combined.contains('indian pop') ||
        combined.contains('devotional') ||
        combined.contains('aashiqui')) {
      return true;
    }
    for (final ia in _indianArtists) {
      if (combined.contains(ia)) return true;
    }
    return false;
  }

  SoftifyTrackVibe _classifyTrackVibe(Track track, String? genre) {
    final combined = '${track.title} ${track.artist} ${track.album ?? ''} ${genre ?? ''}'.toLowerCase();
    final isPunjabi = combined.contains('punjabi') ||
        combined.contains('ap dhillon') ||
        combined.contains('diljit') ||
        combined.contains('sidhu moose') ||
        combined.contains('karan aujla') ||
        combined.contains('shubh') ||
        combined.contains('b praak') ||
        combined.contains('harrdy sandhu') ||
        combined.contains('jassi gill') ||
        combined.contains('amrit maan');

    // 1. Party / Dance Bangers
    const partyKeywords = [
      'party', 'dance', 'club', 'daaru', 'daru', 'sharabi', 'peeyo', 'chull',
      'kala chashma', 'badtameez dil', 'tauba tauba', 'nachde', 'nachdi', 'thumka',
      'bhangra', 'dhol', 'bass', 'beat', 'disco', 'saturday', 'hookah', 'char botal',
      'high heels', 'swag', 'sheila ki jawani', 'munni badnaam', 'chikni chameli',
      'ankh marey', 'aankh marey', 'garmi', 'makhna', 'ghungroo', 'nashe si',
      'subah hone na de', 'desi girl', 'dilliwaali girlfriend', 'gallan goodiyaan',
      'london thumakda', 'sauda khara', 'coca cola', 'lut gaye', 'balam pichkari',
      'sooraj dooba', 'dhan te nan', 'tamma tamma', 'sweety tera drama',
      'chote chote peg', 'morni banke', 'kamariya', 'cheez badi', 'dil chori',
      'bom diggy', 'slow motion', 'gali gali', 'zingaat', 'badshah', 'honey singh',
      'tony kakkar', 'high rated gabru', 'edm', 'techno', 'house', 'rave',
      'banger', 'bounce', 'groove', 'pump', 'levitating', 'uptown funk',
      'dont start now', 'blinding lights', 'titanium', 'dynamite', 'butter',
      'calvin harris', 'david guetta', 'dua lipa', 'tiësto', 'tiesto',
      'chainsmokers', 'avicii', 'marshmello', 'alok', 'skrillex'
    ];

    // 2. Romantic / Love / Melodies
    const romanticKeywords = [
      'romantic', 'love', 'ishq', 'mohabbat', 'pyaar', 'pyar', 'tum hi ho',
      'kesariya', 'apna bana le', 'hawaayein', 'raataan lambiyan', 'gehraiyaan',
      'pal pal', 'pehli nazar', 'saibo', 'tere sang', 'humsafar', 'samjhawan',
      'jeena jeena', 'mast magan', 'sun saathiya', 'rabba', 'deewani', 'sanam',
      'aashiqui', 'soulful', 'acoustic', 'unplugged', 'ballad', 'piano love',
      'serenade', 'tum se hi', 'tere hawaale', 'tu jaane na', 'tere bin',
      'main rang sharbaton', 'hasi', 'muskurane', 'sona', 'zaalima',
      'jaan ban gaye', 'pal', 'kaun tujhe', 'darasal', 'subhanallah',
      'khairiyat', 'tujh me rab', 'surili akhiyon', 'raabta', 'filhall',
      'sakhiyaan', 'sakhiyan',
      'sweet', 'in love', 'forever', 'wedding', 'crush', 'fall in love',
      'ed sheeran', 'bruno mars'
    ];

    // 3. Sad / Heartbreak
    const sadKeywords = [
      'sad', 'heartbreak', 'breakup', 'channa mereya', 'bekhayali',
      'tujhe kitna chahne', 'judai', 'judaai', 'dard', 'tanhai', 'tanha',
      'rona', 'aansu', 'alvida', 'bhula dena', 'humraah', 'agar tum saath ho',
      'phir le aya', 'hamari adhuri', 'dua', 'rooth na jaana', 'tune jo na kaha',
      'kyon', 'kabira', 'jag ghoomeya', 'lonely', 'cry', 'crying', 'hurt',
      'pain', 'tears', 'someone you loved', 'drivers license', 'easy on me',
      'all of me', 'stay with me', 'lewis capaldi', 'adele', 'olivia rodrigo',
      'billie eilish'
    ];

    // 4. Hip-Hop / Rap
    const hiphopKeywords = [
      'rap', 'hip hop', 'hip-hop', 'desi hip hop', 'gully', 'divine', 'emiway',
      'seedhe maut', 'raftaar', 'krsna', 'mc stan', 'apna time aayega',
      'machayenge', 'eminem', 'drake', 'travis scott', 'kendrick lamar', 'kanye',
      'post malone', 'metro boomin', '21 savage', 'lil baby', 'cardi b', 'nicki minaj', 'j. cole'
    ];

    // 5. Rock / Alternative
    const rockKeywords = [
      'rock', 'metal', 'punk', 'grunge', 'indie rock', 'ac/dc', 'queen',
      'nirvana', 'linkin park', 'green day', 'foo fighters', 'red hot chili peppers',
      'arctic monkeys', 'radiohead', 'the killers', 'metallica'
    ];

    if (isPunjabi) {
      for (final pk in partyKeywords) {
        if (combined.contains(pk)) return SoftifyTrackVibe.punjabiParty;
      }
      for (final rk in romanticKeywords) {
        if (combined.contains(rk)) return SoftifyTrackVibe.punjabiRomantic;
      }
      for (final sk in sadKeywords) {
        if (combined.contains(sk)) return SoftifyTrackVibe.punjabiRomantic;
      }
      return SoftifyTrackVibe.punjabiParty;
    }

    for (final pk in partyKeywords) {
      if (combined.contains(pk)) return SoftifyTrackVibe.party;
    }
    for (final sk in sadKeywords) {
      if (combined.contains(sk)) return SoftifyTrackVibe.sad;
    }
    for (final rk in romanticKeywords) {
      if (combined.contains(rk)) return SoftifyTrackVibe.romantic;
    }
    for (final hk in hiphopKeywords) {
      if (combined.contains(hk)) return SoftifyTrackVibe.hiphop;
    }
    for (final rk in rockKeywords) {
      if (combined.contains(rk)) return SoftifyTrackVibe.rock;
    }

    if (genre != null) {
      final g = genre.toLowerCase();
      if (g.contains('dance') || g.contains('electronic')) return SoftifyTrackVibe.party;
      if (g.contains('hip-hop') || g.contains('rap')) return SoftifyTrackVibe.hiphop;
      if (g.contains('rock') || g.contains('alternative') || g.contains('metal')) return SoftifyTrackVibe.rock;
      if (g.contains('r&b') || g.contains('soul')) return SoftifyTrackVibe.romantic;
    }

    return SoftifyTrackVibe.general;
  }

  bool _isVibeCompatible(Track candidate, SoftifyTrackVibe seedVibe) {
    final candVibe = _classifyTrackVibe(candidate, null);
    final text = '${candidate.title} ${candidate.album ?? ''}'.toLowerCase();

    if (seedVibe == SoftifyTrackVibe.party || seedVibe == SoftifyTrackVibe.punjabiParty) {
      // ZERO romantic or sad songs allowed in party queue!
      if (candVibe == SoftifyTrackVibe.romantic ||
          candVibe == SoftifyTrackVibe.sad ||
          candVibe == SoftifyTrackVibe.punjabiRomantic) {
        return false;
      }
      const romanticOrSadDisqualifiers = [
        'romantic', 'love songs', 'love ballad', 'dard', 'judaai', 'judai',
        'tanhai', 'alvida', 'sad song', 'breakup', 'heartbreak', 'tum hi ho',
        'kesariya', 'apna bana le', 'channa mereya', 'bekhayali', 'someone you loved',
        'drivers license', 'ballad', 'acoustic love', 'piano love', 'lullaby',
        'slowed', 'acoustic', 'sakhiyaan', 'sakhiyan'
      ];
      for (final dis in romanticOrSadDisqualifiers) {
        if (text.contains(dis)) return false;
      }
    } else if (seedVibe == SoftifyTrackVibe.romantic || seedVibe == SoftifyTrackVibe.punjabiRomantic) {
      // ZERO party or dance club bangers allowed in romantic queue!
      if (candVibe == SoftifyTrackVibe.party || candVibe == SoftifyTrackVibe.punjabiParty) {
        return false;
      }
      const partyDisqualifiers = [
        'party', 'dance club', 'daaru', 'daru', 'sharabi', 'peeyo', 'chull',
        'kala chashma', 'badtameez dil', 'tauba tauba', 'thumka', 'bhangra',
        'disco beat', 'saturday night', 'char botal', 'sheila ki jawani',
        'chikni chameli', 'ankh marey', 'garmi', 'ghungroo', 'banger',
        'edm', 'techno', 'rave', 'dance floor'
      ];
      for (final dis in partyDisqualifiers) {
        if (text.contains(dis)) return false;
      }
    } else if (seedVibe == SoftifyTrackVibe.sad) {
      // ZERO party bangers allowed in sad queue!
      if (candVibe == SoftifyTrackVibe.party || candVibe == SoftifyTrackVibe.punjabiParty) {
        return false;
      }
    } else if (seedVibe == SoftifyTrackVibe.hiphop) {
      if (candVibe == SoftifyTrackVibe.romantic || candVibe == SoftifyTrackVibe.sad) {
        return false;
      }
    } else if (seedVibe == SoftifyTrackVibe.rock) {
      if (candVibe == SoftifyTrackVibe.party) {
        return false;
      }
    }

    return true;
  }

  Future<List<Track>> _harvestGenreCandidates(Track track) async {
    final List<Track> pool = [];
    final seenIds = <String>{track.id, track.sourceId};
    final genre = await _detectTrackGenre(track);
    final isIndian = _isIndianTrack(track, genre);
    final vibe = _classifyTrackVibe(track, genre);

    // 0. Primary: Reverse Engineered Spotify Recommendation Engine
    // (Track Radio via inspiredby-mix, SEO recommendations, Artist Radio)
    try {
      String? spotifyId;
      String? spotifyArtistId;
      if (track.sourceId.startsWith('spotify_')) {
        spotifyId = track.sourceId.replaceFirst('spotify_', '');
      } else if (track.id.startsWith('spotify_')) {
        spotifyId = track.id.replaceFirst('spotify_', '');
      } else {
        final sRes = await _spotifyApi.search('${track.title} ${track.artist}', limit: 3);
        if (sRes.tracks.isNotEmpty) {
          spotifyId = sRes.tracks.first.id.replaceFirst('spotify_', '');
        }
        if (sRes.artists.isNotEmpty) {
          spotifyArtistId = sRes.artists.first.id;
        }
      }

      if (spotifyId != null && spotifyId.isNotEmpty) {
        // A. Primary: Spotify Track Radio (50 tracks directly trained on this seed song)
        final radioTracks = await _spotifyApi.getTrackRadio(spotifyId);
        for (final rec in radioTracks) {
          if (!seenIds.contains(rec.id) &&
              !seenIds.contains(rec.sourceId) &&
              !_isJunkOrMashup(rec) &&
              _isVibeCompatible(rec, vibe)) {
            if (isIndian || !_isIndianTrack(rec, null)) {
              seenIds.add(rec.id);
              seenIds.add(rec.sourceId);
              pool.add(rec);
            }
          }
        }

        // B. Secondary: Spotify Pathfinder algorithmic recommendations
        final recs = await _spotifyApi.getRecommendedTracks(spotifyId);
        for (final rec in recs) {
          if (!seenIds.contains(rec.id) &&
              !seenIds.contains(rec.sourceId) &&
              !_isJunkOrMashup(rec) &&
              _isVibeCompatible(rec, vibe)) {
            if (isIndian || !_isIndianTrack(rec, null)) {
              seenIds.add(rec.id);
              seenIds.add(rec.sourceId);
              pool.add(rec);
            }
          }
        }

        // C. Tertiary: Enrich with Spotify Related Artists to ensure deep artist diversity
        if (spotifyArtistId == null && track.artist.isNotEmpty) {
          final aRes = await _spotifyApi.search(track.artist, limit: 1);
          if (aRes.artists.isNotEmpty) {
            spotifyArtistId = aRes.artists.first.id;
          }
        }

        if (spotifyArtistId != null) {
          try {
            final relatedArtists = await _spotifyApi.getRelatedArtists(spotifyArtistId);
            final cleanSeedArtist = track.artist.toLowerCase();
            final topRelated = relatedArtists
                .where((a) =>
                    !cleanSeedArtist.contains(a.name.toLowerCase()) &&
                    !a.name.toLowerCase().contains(cleanSeedArtist))
                .take(3)
                .toList();

            for (final relArtist in topRelated) {
              if (pool.length >= 80) break;
              final relRadio = await _spotifyApi.getArtistRadio(relArtist.id);
              for (final rec in relRadio) {
                if (!seenIds.contains(rec.id) &&
                    !seenIds.contains(rec.sourceId) &&
                    !_isJunkOrMashup(rec) &&
                    _isVibeCompatible(rec, vibe)) {
                  if (isIndian || !_isIndianTrack(rec, null)) {
                    seenIds.add(rec.id);
                    seenIds.add(rec.sourceId);
                    pool.add(rec);
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // If Spotify returned a healthy candidate pool (>= 20 tracks), return immediately!
    // Zero hard-coded playlists or external keyword pollution needed!
    if (pool.length >= 20) {
      return pool;
    }

    if (!isIndian) {
      // STRICT ENGLISH / INTERNATIONAL QUEUE:
      // Harvest exclusively from Spotify catalog
      final List<String> queries = [];
      switch (vibe) {
        case SoftifyTrackVibe.party:
        case SoftifyTrackVibe.punjabiParty:
          queries.addAll(['Dance Pop Hits', 'Club Dance Hits', 'High Energy Dance Hits']);
          break;
        case SoftifyTrackVibe.romantic:
        case SoftifyTrackVibe.punjabiRomantic:
          queries.addAll(['Romantic Love Songs Pop', 'Acoustic Love Pop', 'Soulful Pop Ballads']);
          break;
        case SoftifyTrackVibe.sad:
          queries.addAll(['Sad Pop Ballads', 'Heartbreak Pop Hits', 'Melancholy Pop Ballads']);
          break;
        case SoftifyTrackVibe.hiphop:
          queries.addAll(['Hip-Hop Rap Top Hits', 'Rap Caviar Hits', 'Top Hip Hop Banger']);
          break;
        case SoftifyTrackVibe.rock:
          queries.addAll(['Rock Classics', 'Modern Rock Essentials', 'Alternative Rock Hits']);
          break;
        case SoftifyTrackVibe.chillAcoustic:
          queries.addAll(['Acoustic Pop Hits', 'Chill Pop Vibes']);
          break;
        case SoftifyTrackVibe.general:
          final gq = (genre != null && genre.isNotEmpty) ? '$genre Hits' : 'Top Pop Hits';
          queries.add(gq);
          break;
      }

      for (final q in queries) {
        try {
          final sRes = await _spotifyApi.search(q, limit: 30);
          for (final it in sRes.tracks) {
            if (!seenIds.contains(it.id) &&
                !seenIds.contains(it.sourceId) &&
                !_isJunkOrMashup(it) &&
                !_isIndianTrack(it, null) &&
                _isVibeCompatible(it, vibe)) {
              seenIds.add(it.id);
              seenIds.add(it.sourceId);
              pool.add(it);
            }
          }
        } catch (_) {}
        if (pool.length >= 25) break;
      }

      return pool;
    }

    // STRICT INDIAN / REGIONAL QUEUE:
    final List<String> searchQueries = [];

    switch (vibe) {
      case SoftifyTrackVibe.punjabiParty:
        searchQueries.addAll(['Punjabi Party Hits', 'Punjabi Dance Club']);
        break;

      case SoftifyTrackVibe.punjabiRomantic:
        searchQueries.addAll(['Punjabi Romantic Songs', 'Punjabi Love Hits']);
        break;

      case SoftifyTrackVibe.party:
        searchQueries.addAll(['Bollywood Party Hits', 'Bollywood Dance Bangers']);
        break;

      case SoftifyTrackVibe.romantic:
        searchQueries.addAll(['Bollywood Romantic Melodies', 'Arijit Singh Romantic Hits']);
        break;

      case SoftifyTrackVibe.sad:
        searchQueries.addAll(['Bollywood Sad Songs', 'Arijit Singh Sad Melodies']);
        break;

      case SoftifyTrackVibe.hiphop:
        searchQueries.addAll(['Desi Hip Hop Hits', 'Divine Raftaar Seedhe Maut']);
        break;

      default:
        searchQueries.addAll(['Bollywood Top Hits', 'Bollywood Romantic Hits']);
        break;
    }

    for (final sq in searchQueries) {
      try {
        final sRes = await _spotifyApi.search(sq, limit: 30);
        _addValidTracks(pool, sRes.tracks, seenIds, targetVibe: vibe);
      } catch (_) {}
      if (pool.length >= 25) break;
    }

    return pool;
  }

  void _addValidTracks(
    List<Track> pool,
    List<Track> candidates,
    Set<String> seenIds, {
    SoftifyTrackVibe? targetVibe,
  }) {
    for (final t in candidates) {
      if (!seenIds.contains(t.id) &&
          !seenIds.contains(t.sourceId) &&
          !_isJunkOrMashup(t) &&
          (targetVibe == null || _isVibeCompatible(t, targetVibe))) {
        seenIds.add(t.id);
        seenIds.add(t.sourceId);
        pool.add(t);
      }
    }
  }

  static final _junkTitleRegex = RegExp(
    r'\b(mashup|remix|lofi|lo-fi|dj|reverb|slowed|bass boosted|cover|unplugged|reprise|status|instrumental|dialogue|karaoke|teaser|trailer|parody|tribute|club mix|party mix|non stop|tik tok|tiktok)\b',
    caseSensitive: false,
  );

  static final _junkAlbumRegex = RegExp(
    r'\b(mashup|remix|lofi|lo-fi|reverb|slowed|bass boosted|cover|karaoke|parody|tribute)\b',
    caseSensitive: false,
  );

  static final _junkYearRegex = RegExp(
    r'\b(top\s*hits?\s*202\d|music\s*hits?\s*202\d|hits?\s*202\d|best\s*of\s*202\d|bhoomi\s*202\d|world\s*music\s*day\s*202\d|^202\d$)\b',
    caseSensitive: false,
  );

  bool _isJunkOrMashup(Track t) {
    if (_junkTitleRegex.hasMatch(t.title)) return true;
    if (_junkYearRegex.hasMatch(t.title)) return true;
    if (t.album != null && (_junkAlbumRegex.hasMatch(t.album!) || _junkYearRegex.hasMatch(t.album!))) return true;
    if (_junkTitleRegex.hasMatch(t.artist)) return true;
    return false;
  }

  Future<String?> _detectTrackGenre(Track track) async {
    return null;
  }


  List<String> _extractArtistTokens(String artist) {
    final normalized = _decodeHtml(artist)
        .toLowerCase()
        .replaceAll(
          RegExp(r'\s*(feat\.?|ft\.?|featuring)\s*.*$', caseSensitive: false),
          '',
        )
        .trim();
    final parts = normalized
        .split(RegExp(r'[,&+/]|\bwith\b|\bx\b', caseSensitive: false))
        .map((p) => p.trim())
        .where((p) => p.length >= 2)
        .toList();
    if (parts.isEmpty && normalized.isNotEmpty) {
      return [normalized];
    }
    return parts;
  }

  void close() {
    _yt.close();
    _innertubeService.close();
  }
}
