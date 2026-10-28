import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/autocomplete_providers.dart';
import '../providers/player_providers.dart';
import '../providers/search_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/artist_cd_artwork.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/metrolist_navigation_title.dart';
import '../widgets/shared/shared_components.dart';
import '../widgets/shimmer_skeleton.dart';
import '../widgets/track_options_bottom_sheet.dart';
import '../../data/services/spotify_api_service.dart';
import '../widgets/acoustic_recognition_sheet.dart';
import 'artist_discography_screen.dart';
import '../../features/youtube/presentation/youtube_page.dart';
import '../../features/podcasts/presentation/podcast_page.dart';

enum SearchResultFilter {
  all('All'),
  tracks('Songs'),
  artists('Artists'),
  albums('Albums'),
  downloaded('Downloaded');

  final String label;
  const SearchResultFilter(this.label);
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  SearchResultFilter _activeFilter = SearchResultFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {
      _activeFilter = SearchResultFilter.all;
    });
    ref.read(searchNotifierProvider.notifier).setQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final audioHandler = ref.watch(audioHandlerProvider);
    final searchState = ref.watch(searchNotifierProvider);

    // Deduplicate search results by ID or title+artist key, strictly excluding any YouTube tracks
    final rawResults = searchState.combinedResults;
    final seenTrackKeys = <String>{};
    final results = <Track>[];
    for (final track in rawResults) {
      if (track.isYoutube ||
          track.id.startsWith('yt_') ||
          track.sourceId.startsWith('yt_') ||
          track.album == 'YouTube') {
        continue;
      }
      final key = track.id.isNotEmpty
          ? track.id
          : '${track.title.toLowerCase().trim()}_${track.artist.toLowerCase().trim()}';
      if (seenTrackKeys.add(key)) {
        results.add(track);
      }
    }

    final downloadedItems = ref.watch(downloadsStreamProvider).value ?? [];
    final downloadedTrackIds = downloadedItems
        .where((d) => d.isCompleted)
        .map((d) => d.trackId)
        .toSet();

    final queryText = _searchController.text.trim();
    final filteredResults = results.where((track) {
      switch (_activeFilter) {
        case SearchResultFilter.all:
          return true;
        case SearchResultFilter.tracks:
          return true;
        case SearchResultFilter.artists:
          return track.artist.toLowerCase().contains(queryText.toLowerCase());
        case SearchResultFilter.albums:
          return track.album?.isNotEmpty == true;
        case SearchResultFilter.downloaded:
          return downloadedTrackIds.contains(track.id);
      }
    }).toList();

    final artistDiscoAsync = queryText.isNotEmpty
        ? ref.watch(artistDiscographySearchProvider(queryText))
        : const AsyncValue<ArtistDiscography?>.data(null);
    final artistDisco = artistDiscoAsync.valueOrNull;
    final hasArtistBanner = artistDisco != null && artistDisco.allTracks.isNotEmpty;
    final int bannerOffset = hasArtistBanner ? 1 : 0;

    return Scaffold(
      backgroundColor: tokens.isGlass ? Colors.transparent : tokens.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: tokens.accent,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Identify Music',
        onPressed: () => AcousticRecognitionSheet.show(context),
        child: const Icon(
          Icons.graphic_eq_rounded,
          color: Colors.black,
          size: 26,
        ),
      ),
      appBar: null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Metrolist M3 Expressive Pill Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: tokens.isGlass
                ? AppSurface(
                    withBlur: true,
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    border: Border.all(color: tokens.glassBorder, width: 1.0),
                    boxShadow: tokens.cardShadow,
                    color: Colors.white.withValues(alpha: 0.12),
                    child: TextField(
                      controller: _searchController,
                      cursorColor: tokens.accentCyan,
                      onChanged: _onQueryChanged,
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          ref.read(searchNotifierProvider.notifier).executeSearch(val.trim());
                        }
                      },
                      style: const TextStyle(
                        fontFamily: AppTheme.fontUi,
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        hintText: 'Search songs, albums, artists...',
                        hintStyle: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          color: tokens.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: tokens.accentCyan,
                          size: 22,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: tokens.textSecondary,
                                  size: 18,
                                ),
                                splashRadius: 20,
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(searchNotifierProvider.notifier).setQuery('');
                                  setState(() {});
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  )
                : TextField(
                    controller: _searchController,
                    cursorColor: tokens.accent,
                    onChanged: _onQueryChanged,
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        ref.read(searchNotifierProvider.notifier).executeSearch(val.trim());
                      }
                    },
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      color: tokens.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: tokens.surfaceElevated,
                      hintText: 'Search songs, albums, artists...',
                      hintStyle: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        color: tokens.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: tokens.textSecondary,
                        size: 22,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: tokens.textSecondary,
                                size: 18,
                              ),
                              splashRadius: 20,
                              onPressed: () {
                                _searchController.clear();
                                ref.read(searchNotifierProvider.notifier).setQuery('');
                                setState(() {});
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.graphic_eq_rounded,
                              color: tokens.accent,
                              size: 20,
                            ),
                            tooltip: 'Identify Music',
                            splashRadius: 20,
                            onPressed: () => AcousticRecognitionSheet.show(context),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28.0),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28.0),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28.0),
                        borderSide: BorderSide(
                          color: tokens.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
          ),


          // Autocomplete suggestion chips & Intent routing badge
          if (_searchController.text.trim().isNotEmpty)
            Consumer(
              builder: (context, ref, _) {
                final query = _searchController.text.trim();
                final suggestionsAsync =
                    ref.watch(autocompleteSuggestionsProvider(query));

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Suggestions horizontal row
                    suggestionsAsync.maybeWhen(
                      data: (suggestions) {
                        if (suggestions.isEmpty) return const SizedBox.shrink();
                        return SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: suggestions.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final suggestion = suggestions[index];
                              return ActionChip(
                                label: Text(
                                  suggestion,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                backgroundColor: tokens.surfaceElevated,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 0.8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(tokens.radiusFull),
                                ),
                                onPressed: () {
                                  _searchController.text = suggestion;
                                  _searchController.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(offset: suggestion.length),
                                  );
                                  ref
                                      .read(searchNotifierProvider.notifier)
                                      .executeSearch(suggestion);
                                  setState(() {});
                                },
                              );
                            },
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 6),
                  ],
                );
              },
            ),
          // Quality & Offline Filter Chips
          if (results.isNotEmpty)
            _buildFilterChips(tokens),

          // Search Results / Loading / Empty States
          Expanded(
            child: searchState.isLoading && results.isEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                    itemCount: 8,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          ShimmerSkeleton(
                            width: 50,
                            height: 50,
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShimmerSkeleton(
                                  width: double.infinity,
                                  height: 14,
                                  borderRadius:
                                      BorderRadius.circular(tokens.radiusSm),
                                ),
                                const SizedBox(height: 6),
                                ShimmerSkeleton(
                                  width: 120,
                                  height: 10,
                                  borderRadius:
                                      BorderRadius.circular(tokens.radiusSm),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : searchState.errorMessage != null && results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            searchState.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFE91429)),
                          ),
                        ),
                      )
                    : (results.isEmpty && !hasArtistBanner)
                        ? (_searchController.text.trim().isEmpty
                            ? _buildEmptySearchState(tokens)
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off_rounded,
                                      size: 52,
                                      color: tokens.textMuted.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No tracks found for "${_searchController.text.trim()}"',
                                      style: TextStyle(
                                        color: tokens.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Try searching by song name, artist, or album',
                                      style: TextStyle(
                                        color: tokens.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                        : (filteredResults.isEmpty && results.isNotEmpty)
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.filter_list_off_rounded,
                                      size: 48,
                                      color: tokens.textMuted.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No tracks match "${_activeFilter.label}"',
                                      style: TextStyle(
                                        color: tokens.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    BouncingScaleButton(
                                      scaleFactor: 0.94,
                                      onTap: () => setState(() => _activeFilter = SearchResultFilter.all),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: tokens.surfaceElevated,
                                          borderRadius: BorderRadius.circular(tokens.radiusFull),
                                          border: Border.all(
                                            color: tokens.accent.withValues(alpha: 0.4),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          'Reset to All Results',
                                          style: TextStyle(
                                            color: tokens.accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                                itemCount: (filteredResults.isEmpty && hasArtistBanner)
                                    ? 1 + artistDisco.allTracks.length
                                    : filteredResults.length + bannerOffset,
                                itemBuilder: (context, index) {
                                  if (hasArtistBanner && index == 0) {
                                    return _buildArtistDiscographyBanner(
                                      tokens,
                                      artistDisco,
                                      audioHandler,
                                    );
                                  }
                                  final effectiveList =
                                      (filteredResults.isEmpty && hasArtistBanner)
                                          ? artistDisco.allTracks
                                          : filteredResults;
                                  final trackIndex = index - bannerOffset;
                                  final track = effectiveList[trackIndex];
                                  if (trackIndex == 0 && _searchController.text.trim().isNotEmpty) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildTopResultCard(tokens, track, audioHandler),
                                        if (effectiveList.length > 1) ...[
                                          const MetrolistNavigationTitle(
                                            title: 'Songs',
                                            padding: EdgeInsets.only(top: 8, bottom: 4),
                                          ),
                                        ],
                                      ],
                                    );
                                  }
                                  return _buildSearchResultTile(
                                      tokens, track, trackIndex, audioHandler);
                                },
                              ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildFilterChips(AppTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: SearchResultFilter.values.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppFilterChip(
                label: filter.label,
                isSelected: _activeFilter == filter,
                onTap: () => setState(() => _activeFilter = filter),
                icon: filter == SearchResultFilter.downloaded
                    ? const Icon(Icons.download_done_rounded, size: 14)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }


  Widget _buildEmptySearchState(AppTokens tokens) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        _buildBannerCard(
          title: 'YouTube Player',
          subtitle: 'Search & stream YouTube videos with picture-in-picture',
          icon: Icons.smart_display_rounded,
          iconColor: const Color(0xFFFF2E2E),
          tokens: tokens,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const YoutubePage()),
            );
          },
        ),
        const SizedBox(height: 14),
        _buildBannerCard(
          title: 'Podcasts',
          subtitle: 'Explore audio shows, talks, and serialized episodes',
          icon: Icons.podcasts_rounded,
          iconColor: tokens.accent,
          tokens: tokens,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PodcastPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBannerCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required AppTokens tokens,
    required VoidCallback onTap,
  }) {
    return BouncingScaleButton(
      scaleFactor: 0.97,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
          boxShadow: tokens.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 28,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: tokens.textSecondary.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopResultCard(AppTokens tokens, Track track, dynamic audioHandler) {
    return tokens.isGlass
        ? AppSurface(
            withBlur: true,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 14),
            borderRadius: BorderRadius.circular(tokens.radiusCard),
            border: Border.all(color: tokens.glassBorder, width: 1.0),
            boxShadow: tokens.cardShadow,
            child: _buildTopResultCardBody(tokens, track, audioHandler),
          )
        : Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(tokens.radiusCard),
            ),
            child: _buildTopResultCardBody(tokens, track, audioHandler),
          );
  }

  Widget _buildTopResultCardBody(AppTokens tokens, Track track, dynamic audioHandler) {
    return Stack(
      children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                child: AppNetworkImage(
                  imageUrl: track.coverUrl,
                  width: 76,
                  height: 76,
                  cacheWidth: 228,
                  cacheHeight: 228,
                  fit: BoxFit.cover,
                  placeholderIcon: Icons.music_note_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOP RESULT',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontPageTitle,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 12,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tokens.surfaceElevated,
                            borderRadius: BorderRadius.circular(tokens.radiusPill),
                          ),
                          child: Text(
                            'Song',
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        if (track.isLyricsMatch) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (tokens.isGlass ? tokens.accentCyan : tokens.accent).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(tokens.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic_none_rounded,
                                  size: 11,
                                  color: tokens.isGlass ? tokens.accentCyan : tokens.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Lyrics match',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontUi,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.isGlass ? tokens.accentCyan : tokens.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Semantics(
              label: 'Play ${track.title}',
              button: true,
              child: BouncingScaleButton(
                onTap: () {
                  audioHandler.setTrackSource('search');
                  audioHandler.playTrack(track);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
  }

  Widget _buildSearchResultTile(
      AppTokens tokens, Track track, int index, dynamic audioHandler) {
    final currentTrack = ref.watch(currentTrackProvider).value;
    final isPlaying = ref.watch(isPlayingProvider);
    final isCurrentTrack = currentTrack?.id == track.id;

    final isLikedAsync = ref.watch(isTrackLikedProvider(track.id));
    final isLiked = isLikedAsync.value ?? track.isLiked;

    final isDownloadedAsync = ref.watch(isTrackDownloadedProvider(track.id));
    final isDownloaded = isDownloadedAsync.value ?? false;

    return TrackRow(
      track: track,
      index: index + 1,
      isPlaying: isCurrentTrack && isPlaying,
      isSelected: isCurrentTrack,
      showArtwork: true,
      showIndex: false,
      showDuration: true,
      showLikeButton: true,
      showOptionsButton: true,
      onTap: () {
        ref.read(searchNotifierProvider.notifier).onTrackClicked(track, index);
        final currentQuery = _searchController.text.trim();
        if (currentQuery.isNotEmpty) {
          ref
              .read(autocompleteRepositoryProvider)
              .recordSuccessfulQuery(currentQuery);
        }
        audioHandler.setTrackSource('search');
        audioHandler.playTrack(track);
      },
      onPlayTap: () {
        audioHandler.setTrackSource('search');
        audioHandler.playTrack(track);
      },
      onLikeTap: () {
        HapticFeedback.selectionClick();
        ref
            .read(libraryRepositoryProvider)
            .setLiked(track.id, !isLiked, track: track);
      },
      onOptionsTap: () {
        TrackOptionsBottomSheet.show(context, track: track);
      },
      trailing: isDownloaded
          ? const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(
                Icons.download_done_rounded,
                size: 16,
                color: AppTheme.accent,
              ),
            )
          : null,
    );
  }


  Widget _buildArtistDiscographyBanner(
    AppTokens tokens,
    ArtistDiscography disco,
    dynamic audioHandler,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
      ),
      child: Column(
        children: [
          // Row 1: CD Artwork + Artist Metadata
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ArtistDiscographyScreen(disco: disco),
                ),
              );
            },
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            child: Row(
              children: [
                ArtistCdArtwork(
                  artistImageUrl: disco.avatarUrl,
                  size: 72,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              disco.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.fontPageTitle,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppTheme.accent,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${disco.albums.length} Albums • ${disco.allTracks.length} Songs',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12,
                          color: tokens.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Verified Artist Discography',
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Row 2: Dual Action Pills (Play All & Shuffle)
          Row(
            children: [
              Expanded(
                child: AppPillButton(
                  label: 'Play All',
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  variant: AppPillButtonVariant.primary,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    if (disco.allTracks.isNotEmpty) {
                      audioHandler.setTrackSource('artist_discography');
                      audioHandler.playTrack(
                        disco.allTracks.first,
                        queue: disco.allTracks,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppPillButton(
                  label: 'Shuffle',
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  variant: AppPillButtonVariant.secondary,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    if (disco.allTracks.isNotEmpty) {
                      final shuffled = List<Track>.from(disco.allTracks)..shuffle();
                      audioHandler.setTrackSource('artist_discography');
                      audioHandler.playTrack(
                        shuffled.first,
                        queue: shuffled,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
