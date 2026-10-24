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
import '../widgets/shared/shared_components.dart';
import '../widgets/shimmer_skeleton.dart';
import '../widgets/track_options_bottom_sheet.dart';
import '../../data/services/spotify_api_service.dart';
import '../../features/podcasts/presentation/podcast_page.dart';
import '../../features/youtube/presentation/youtube_page.dart';
import 'artist_discography_screen.dart';

enum SearchResultFilter {
  all('All'),
  tracks('Songs'),
  downloaded('Downloaded');

  final String label;
  const SearchResultFilter(this.label);
}

class _SpotifyCategory {
  final String title;
  final Color color;
  final IconData icon;

  const _SpotifyCategory(this.title, this.color, this.icon);
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  SearchResultFilter _activeFilter = SearchResultFilter.all;

  static const List<_SpotifyCategory> _spotifyBrowseCategories = [
    _SpotifyCategory('Hip-Hop', Color(0xFFBA5D07), Icons.graphic_eq_rounded),
    _SpotifyCategory('Pop', Color(0xFF8D67AB), Icons.star_rounded),
    _SpotifyCategory('Rock', Color(0xFFE91429), Icons.electric_bolt_rounded),
    _SpotifyCategory('Indie', Color(0xFF608108), Icons.park_rounded),
    _SpotifyCategory('R&B', Color(0xFFD84000), Icons.favorite_rounded),
    _SpotifyCategory('Electronic', Color(0xFF1E3264), Icons.headphones_rounded),
    _SpotifyCategory('Chill & Lo-Fi', Color(0xFF477D95), Icons.coffee_rounded),
    _SpotifyCategory('Podcasts', Color(0xFF27856A), Icons.podcasts_rounded),
    _SpotifyCategory('YouTube Audio', Color(0xFFE61B23), Icons.play_circle_fill_rounded),
    _SpotifyCategory('Jazz', Color(0xFF7D4B32), Icons.piano_rounded),
    _SpotifyCategory('Mood', Color(0xFFE1118C), Icons.wb_sunny_rounded),
    _SpotifyCategory('Discover', Color(0xFF503750), Icons.explore_rounded),
  ];

  static const List<String> _quickCategories = [
    'Electronic',
    'R&B',
    'Synthwave',
    'Pop',
    'Rock',
    'Lo-Fi',
    'Acoustic',
    'Hip-Hop',
    'Jazz',
  ];

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

    // Deduplicate search results by ID or title+artist key
    final rawResults = searchState.combinedResults;
    final seenTrackKeys = <String>{};
    final results = <Track>[];
    for (final track in rawResults) {
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

    final filteredResults = results.where((track) {
      switch (_activeFilter) {
        case SearchResultFilter.all:
          return true;
        case SearchResultFilter.tracks:
          return true;
        case SearchResultFilter.downloaded:
          return downloadedTrackIds.contains(track.id);
      }
    }).toList();

    final queryText = _searchController.text.trim();
    final artistDiscoAsync = queryText.isNotEmpty
        ? ref.watch(artistDiscographySearchProvider(queryText))
        : const AsyncValue<ArtistDiscography?>.data(null);
    final artistDisco = artistDiscoAsync.valueOrNull;
    final hasArtistBanner = artistDisco != null && artistDisco.allTracks.isNotEmpty;
    final int bannerOffset = hasArtistBanner ? 1 : 0;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: tokens.isGlass ? Colors.transparent : tokens.background,
      appBar: AppBar(
        backgroundColor:
            tokens.isGlass ? Colors.transparent : tokens.background,
        elevation: 0,
        title: Text(
          'Search',
          style: TextStyle(
            fontFamily: AppTheme.fontPageTitle,
            fontSize: isDesktop ? 28 : 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: tokens.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Input Field
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
                        hintText: 'What do you want to listen to?',
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
                      hintText: 'What do you want to listen to?',
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                        borderSide: BorderSide(
                          color: tokens.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
          ),

          // Quick Category Chips when search bar is idle
          if (_searchController.text.trim().isEmpty)
            _buildQuickCategoryChips(tokens),

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
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                                            child: Text(
                                              'Songs',
                                              style: TextStyle(
                                                fontFamily: AppTheme.fontPageTitle,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: tokens.textPrimary,
                                              ),
                                            ),
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

  Widget _buildQuickCategoryChips(AppTokens tokens) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _quickCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = _quickCategories[index];
            final isSelected =
                _searchController.text.trim().toLowerCase() == category.toLowerCase();
            return AppFilterChip(
              label: category,
              isSelected: isSelected,
              onTap: () {
                _searchController.text = category;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: category.length),
                );
                ref
                    .read(searchNotifierProvider.notifier)
                    .executeSearch(category);
                setState(() {});
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(AppTokens tokens) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
      children: [
        Text(
          'Browse all',
          style: TextStyle(
            fontFamily: AppTheme.fontPageTitle,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: _spotifyBrowseCategories.length,
          itemBuilder: (context, index) {
            final category = _spotifyBrowseCategories[index];
            return BouncingScaleButton(
              scaleFactor: 0.96,
              minTouchTarget: 0,
              onTap: () {
                if (category.title == 'Podcasts') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PodcastPage(),
                    ),
                  );
                  return;
                }
                if (category.title == 'YouTube Audio') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const YoutubePage(),
                    ),
                  );
                  return;
                }
                _searchController.text = category.title;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: category.title.length),
                );
                ref
                    .read(searchNotifierProvider.notifier)
                    .executeSearch(category.title);
                setState(() {});
              },
              child: tokens.isGlass
                  ? AppSurface(
                      withBlur: true,
                      borderRadius: BorderRadius.circular(tokens.radiusCard),
                      border: Border.all(color: tokens.glassBorder, width: 1.0),
                      boxShadow: tokens.cardShadow,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              category.color.withValues(alpha: 0.50),
                              category.color.withValues(alpha: 0.18),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(tokens.radiusCard),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // Top-Left Category Title
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                category.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontUi,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            // Bottom-Right Slanted Graphic Card (Spotify Signature)
                            Positioned(
                              right: -10,
                              bottom: -6,
                              child: Transform.rotate(
                                angle: 0.42,
                                child: Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(-2, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      category.icon,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: category.color,
                        borderRadius: BorderRadius.circular(tokens.radiusCard),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1.0,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          // Top-Left Category Title
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              category.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          // Bottom-Right Slanted Graphic Card (Spotify Signature)
                          Positioned(
                            right: -10,
                            bottom: -6,
                            child: Transform.rotate(
                              angle: 0.42,
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(-2, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    category.icon,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            );
          },
        ),
      ],
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
