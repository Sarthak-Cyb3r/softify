import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/remote_config_repository.dart';
import '../../data/search/linear_search_reranker.dart';
import '../../data/search/text_normalizer.dart';
import '../../domain/entities/search_candidate.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_catalog_repository.dart';
import '../../domain/ports/i_event_logger.dart';
import '../../domain/ports/i_fts_repository.dart';
import '../../domain/ports/i_library_repository.dart';
import '../../domain/ports/i_remote_config.dart';
import '../../domain/ports/i_search_reranker.dart';
import '../../data/services/spotify_api_service.dart';
import 'player_providers.dart';

class SearchState {
  final String query;
  final List<Track> localResults;
  final List<Track> networkResults;
  final bool isLocalLoading;
  final bool isNetworkLoading;
  final String? errorMessage;
  final int searchStartTimeMs;
  final List<SearchCandidate> candidates;

  const SearchState({
    this.query = '',
    this.localResults = const [],
    this.networkResults = const [],
    this.isLocalLoading = false,
    this.isNetworkLoading = false,
    this.errorMessage,
    this.searchStartTimeMs = 0,
    this.candidates = const [],
  });

  /// Merges local results (<100ms) with network results.
  /// Local items always appear at the top. Network items are appended below
  /// without duplicates and without shifting existing local items.
  List<Track> get combinedResults {
    if (localResults.isEmpty) return networkResults;
    if (networkResults.isEmpty) return localResults;

    final seenIds = <String>{for (final t in localResults) t.id};
    final merged = List<Track>.from(localResults);

    for (final netTrack in networkResults) {
      if (seenIds.contains(netTrack.id)) continue;
      final isDup = merged.any(
        (locTrack) => TextNormalizer.isSameSongCluster(a: locTrack, b: netTrack),
      );
      if (!isDup) {
        merged.add(netTrack);
      }
    }
    return merged;
  }

  bool get isLoading => isLocalLoading || isNetworkLoading;
  bool get isEmpty => query.trim().isEmpty;

  SearchState copyWith({
    String? query,
    List<Track>? localResults,
    List<Track>? networkResults,
    bool? isLocalLoading,
    bool? isNetworkLoading,
    String? errorMessage,
    int? searchStartTimeMs,
    List<SearchCandidate>? candidates,
  }) {
    return SearchState(
      query: query ?? this.query,
      localResults: localResults ?? this.localResults,
      networkResults: networkResults ?? this.networkResults,
      isLocalLoading: isLocalLoading ?? this.isLocalLoading,
      isNetworkLoading: isNetworkLoading ?? this.isNetworkLoading,
      errorMessage: errorMessage,
      searchStartTimeMs: searchStartTimeMs ?? this.searchStartTimeMs,
      candidates: candidates ?? this.candidates,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final ILibraryRepository _libraryRepo;
  final ICatalogRepository _catalogRepo;
  final IEventLogger _eventLogger;
  final IFtsRepository? _ftsRepo;
  final ISearchReranker _reranker;
  final IRemoteConfig? _remoteConfig;

  Timer? _debounceTimer;
  int _latestRequestId = 0;

  SearchNotifier({
    required ILibraryRepository libraryRepo,
    required ICatalogRepository catalogRepo,
    required IEventLogger eventLogger,
    IFtsRepository? ftsRepo,
    ISearchReranker? reranker,
    IRemoteConfig? remoteConfig,
  })  : _libraryRepo = libraryRepo,
        _catalogRepo = catalogRepo,
        _eventLogger = eventLogger,
        _ftsRepo = ftsRepo,
        _reranker = reranker ?? LinearSearchReranker(),
        _remoteConfig = remoteConfig,
        super(const SearchState());

  void setQuery(String newQuery) {
    _debounceTimer?.cancel();
    final trimmed = newQuery.trim();

    if (trimmed.isEmpty) {
      _latestRequestId++;
      state = const SearchState();
      return;
    }

    // 120ms debounce constraint (S1)
    _debounceTimer = Timer(const Duration(milliseconds: 120), () {
      executeSearch(trimmed);
    });
  }

  Future<void> executeSearch(String query) async {
    _debounceTimer?.cancel();
    final requestId = ++_latestRequestId;
    final startTime = DateTime.now().millisecondsSinceEpoch;

    state = SearchState(
      query: query,
      isLocalLoading: true,
      isNetworkLoading: true,
      searchStartTimeMs: startTime,
    );

    final aliases = _remoteConfig?.getSearchAliases() ??
        RemoteConfigRepository.defaultSearchAliases;
    final rankerWeights = _remoteConfig?.getSearchRankerWeights() ??
        RemoteConfigRepository.defaultRankerWeights;

    // 1. Local Search (<100ms budget) via FTS5 + Library LIKE
    try {
      final localTracks = await _libraryRepo.searchLocalTracks(query, limit: 15);
      final localTrackMap = {for (final t in localTracks) t.id: t};

      // Query FTS index if available
      if (_ftsRepo != null) {
        final ftsIds = await _ftsRepo.queryFts(query);
        for (final id in ftsIds) {
          if (!localTrackMap.containsKey(id)) {
            final t = await _libraryRepo.getTrackById(id);
            if (t != null) {
              localTrackMap[t.id] = t;
            }
          }
        }
      }

      final localCandidates = localTrackMap.values.map((track) {
        return SearchCandidate(
          track: track,
          source: 'local_fts',
          features: {
            'played_count': track.isLiked ? 2.0 : 1.0,
            'popularity_proxy': track.matchConfidence ?? 0.8,
          },
        );
      }).toList();

      final rerankedLocal = _reranker.rerank(
        query: query,
        candidates: localCandidates,
        weights: rankerWeights,
        deduplicate: true,
      );

      if (mounted && _latestRequestId == requestId) {
        state = state.copyWith(
          localResults: rerankedLocal.map((c) => c.track).toList(),
          isLocalLoading: false,
          candidates: rerankedLocal,
        );
      }
    } catch (_) {
      if (mounted && _latestRequestId == requestId) {
        state = state.copyWith(isLocalLoading: false);
      }
    }

    // 2. Remote Network Search with Alias Expansion
    try {
      final expandedQueries = TextNormalizer.expandAliases(query, aliases);
      final primaryQuery = query;

      final netTracks = await _catalogRepo.search(primaryQuery, limit: 25);
      final netTrackMap = {for (final t in netTracks) t.id: t};

      // If user typed a short alias with 0 results, query the first alias expansion
      if (netTracks.isEmpty && expandedQueries.length > 1) {
        final altQuery = expandedQueries.firstWhere((q) => q != primaryQuery);
        try {
          final altTracks = await _catalogRepo.search(altQuery, limit: 15);
          for (final t in altTracks) {
            netTrackMap.putIfAbsent(t.id, () => t);
          }
        } catch (_) {}
      }

      final networkCandidates = netTrackMap.values.map((track) {
        return SearchCandidate(
          track: track,
          source: 'network',
          features: {
            'popularity_proxy': track.matchConfidence ?? 0.5,
          },
        );
      }).toList();

      final rerankedNetwork = _reranker.rerank(
        query: query,
        candidates: networkCandidates,
        weights: rankerWeights,
        deduplicate: true,
      );

      if (mounted && _latestRequestId == requestId) {
        state = state.copyWith(
          networkResults: rerankedNetwork.map((c) => c.track).toList(),
          isNetworkLoading: false,
          candidates: [...state.candidates, ...rerankedNetwork],
        );
      }
    } catch (e) {
      if (mounted && _latestRequestId == requestId) {
        state = state.copyWith(
          isNetworkLoading: false,
          errorMessage: state.localResults.isEmpty ? 'Search error: $e' : null,
        );
      }
    }
  }

  void onTrackClicked(Track track, int position) {
    final msToClick = DateTime.now().millisecondsSinceEpoch - state.searchStartTimeMs;
    final resultIds = state.combinedResults.map((t) => t.id).toList();

    _eventLogger.logSearch(
      query: state.query,
      resultIds: resultIds,
      clickedId: track.id,
      clickedPosition: position,
      msToClick: msToClick > 0 ? msToClick : 0,
      rankerVersion: 'v2',
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final libraryRepo = ref.watch(libraryRepositoryProvider);
  final catalogRepo = ref.watch(catalogRepositoryProvider);
  final eventLogger = ref.watch(eventLoggerProvider);
  final ftsRepo = ref.watch(ftsRepositoryProvider);
  final reranker = ref.watch(searchRerankerProvider);
  final remoteConfig = ref.watch(remoteConfigProvider);

  return SearchNotifier(
    libraryRepo: libraryRepo,
    catalogRepo: catalogRepo,
    eventLogger: eventLogger,
    ftsRepo: ftsRepo,
    reranker: reranker,
    remoteConfig: remoteConfig,
  );
});

final artistDiscographySearchProvider =
    FutureProvider.family<ArtistDiscography?, String>((ref, query) async {
  final clean = query.trim();
  if (clean.length < 2) return null;

  final spotifyApi = ref.watch(spotifyApiServiceProvider);
  try {
    final searchResult = await spotifyApi.search(clean, limit: 5);
    if (searchResult.artists.isEmpty) return null;

    final topArtist = searchResult.artists.first;
    final normArtist = TextNormalizer.normalize(topArtist.name);
    final normQuery = TextNormalizer.normalize(clean);

    if (!normArtist.contains(normQuery) && !normQuery.contains(normArtist)) {
      return null;
    }

    return await spotifyApi.getArtistCompleteDiscography(topArtist.uri);
  } catch (_) {
    return null;
  }
});

