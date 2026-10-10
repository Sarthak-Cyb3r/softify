import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/search_intent.dart';
import '../../domain/entities/track.dart';
import '../providers/autocomplete_providers.dart';
import '../providers/player_providers.dart';
import '../providers/search_providers.dart';
import '../theme/app_tokens.dart';
import '../widgets/artist_cd_artwork.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/shimmer_skeleton.dart';
import '../widgets/track_options_bottom_sheet.dart';
import '../../data/services/spotify_api_service.dart';
import 'artist_discography_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

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
    setState(() {});
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

    final queryText = _searchController.text.trim();
    final artistDiscoAsync = queryText.isNotEmpty
        ? ref.watch(artistDiscographySearchProvider(queryText))
        : const AsyncValue<ArtistDiscography?>.data(null);
    final artistDisco = artistDiscoAsync.valueOrNull;
    final hasArtistBanner = artistDisco != null && artistDisco.allTracks.isNotEmpty;
    final int bannerOffset = hasArtistBanner ? 1 : 0;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(
          'Search',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: tokens.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Big Minimal Search Input Field with Subtle Focus Ring
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              cursorColor: tokens.accent,
              onChanged: _onQueryChanged,
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  ref.read(searchNotifierProvider.notifier).executeSearch(val.trim());
                }
              },
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: tokens.surfaceElevated,
                hintText: 'What do you want to listen to?',
                hintStyle: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: tokens.accent.withValues(alpha: 0.85),
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
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                  borderSide: BorderSide(
                    color: tokens.surfaceHighlight.withValues(alpha: 0.7),
                    width: 0.8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                  borderSide: BorderSide(
                    color: tokens.surfaceHighlight.withValues(alpha: 0.7),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                  borderSide: BorderSide(
                    color: tokens.accent.withValues(alpha: 0.75),
                    width: 1.2,
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
                final intent = ref.watch(intentRouterProvider).resolve(query);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Intent Badge
                    if (intent is MoodOrGenreIntent ||
                        intent is SimilarToIntent ||
                        intent is ArtistIntent)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: tokens.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(tokens.radiusFull),
                            border: Border.all(
                              color: tokens.accent.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                intent is MoodOrGenreIntent
                                    ? Icons.auto_awesome_rounded
                                    : intent is SimilarToIntent
                                        ? Icons.grain_rounded
                                        : Icons.person_rounded,
                                color: tokens.accent,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                intent is MoodOrGenreIntent
                                    ? 'Mix: ${intent.tags.join(" • ")}'
                                    : intent is SimilarToIntent
                                        ? 'Similar to: ${intent.seedTrackTitle}'
                                        : 'Artist: ${(intent as ArtistIntent).artistName}',
                                style: TextStyle(
                                  color: tokens.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                            itemCount: (results.isEmpty && hasArtistBanner)
                                ? 1 + artistDisco.allTracks.length
                                : results.length + bannerOffset,
                            itemBuilder: (context, index) {
                              if (hasArtistBanner && index == 0) {
                                return _buildArtistDiscographyBanner(
                                  tokens,
                                  artistDisco,
                                  audioHandler,
                                );
                              }
                              final effectiveList =
                                  (results.isEmpty && hasArtistBanner)
                                      ? artistDisco.allTracks
                                      : results;
                              final trackIndex = index - bannerOffset;
                              final track = effectiveList[trackIndex];
                              return _buildSearchResultTile(
                                  tokens, track, trackIndex, audioHandler);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCategoryChips(AppTokens tokens) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _quickCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = _quickCategories[index];
            return BouncingScaleButton(
              scaleFactor: 0.94,
              minTouchTarget: 0,
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                  border: Border.all(
                    color: tokens.surfaceHighlight.withValues(alpha: 0.8),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tag_rounded,
                      size: 13,
                      color: tokens.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
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
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.accent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Browse Categories',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.6,
          ),
          itemCount: _quickCategories.length,
          itemBuilder: (context, index) {
            final category = _quickCategories[index];
            return BouncingScaleButton(
              scaleFactor: 0.95,
              minTouchTarget: 0,
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusLg),
                  border: Border.all(
                    color: tokens.surfaceHighlight.withValues(alpha: 0.8),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: tokens.surfaceHighlight,
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 16,
                          color: tokens.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: tokens.textPrimary,
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

  Widget _buildSearchResultTile(
      AppTokens tokens, Track track, int index, dynamic audioHandler) {
    final isLikedAsync = ref.watch(isTrackLikedProvider(track.id));
    final isLiked = isLikedAsync.value ?? track.isLiked;

    final isDownloadedAsync = ref.watch(isTrackDownloadedProvider(track.id));
    final isDownloaded = isDownloadedAsync.value ?? false;

    final durationFormatted = _formatSeconds(track.duration.inSeconds);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            hoverColor: tokens.surfaceHighlight.withValues(alpha: 0.35),
            splashColor: tokens.accent.withValues(alpha: 0.08),
            highlightColor: tokens.surfaceHighlight.withValues(alpha: 0.2),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(
                        color: tokens.surfaceHighlight.withValues(alpha: 0.8),
                        width: 0.8,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      child: track.coverUrl != null
                          ? Image.network(
                              track.coverUrl!,
                              width: 48,
                              height: 48,
                              cacheWidth: 144,
                              cacheHeight: 144,
                              gaplessPlayback: true,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _fallbackCover(tokens),
                            )
                          : _fallbackCover(tokens),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (durationFormatted.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tokens.surfaceHighlight.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.04),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        durationFormatted,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.textMuted,
                        ),
                      ),
                    ),
                  ],
                  // Download Button
                  BouncingScaleButton(
                    scaleFactor: 0.88,
                    minTouchTarget: 0,
                    onTap: () async {
                      if (!isDownloaded) {
                        HapticFeedback.lightImpact();
                        await ref
                            .read(downloadRepositoryProvider)
                            .queueDownload(track);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Downloading "${track.title}"...'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: tokens.surfaceElevated,
                            ),
                          );
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        isDownloaded
                            ? Icons.download_done_rounded
                            : Icons.download_for_offline_outlined,
                        color: isDownloaded
                            ? tokens.accent
                            : tokens.textSecondary.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                  ),
                  // Like Button
                  BouncingScaleButton(
                    scaleFactor: 0.88,
                    minTouchTarget: 0,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(libraryRepositoryProvider)
                          .setLiked(track.id, !isLiked, track: track);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isLiked
                            ? tokens.accent
                            : tokens.textSecondary.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                  ),
                  // More Options
                  BouncingScaleButton(
                    scaleFactor: 0.88,
                    minTouchTarget: 0,
                    onTap: () {
                      TrackOptionsBottomSheet.show(context, track: track);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: tokens.textSecondary.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '';
    final m = totalSeconds ~/ 60;
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _fallbackCover(AppTokens tokens) {
    return Container(
      width: 48,
      height: 48,
      color: tokens.surfaceHighlight,
      child: Icon(
        Icons.music_note_rounded,
        color: tokens.textMuted,
        size: 22,
      ),
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
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        border: Border.all(
          color: tokens.accent.withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: tokens.accent.withValues(alpha: 0.06),
            blurRadius: 28,
          ),
        ],
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
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            child: Row(
              children: [
                ArtistCdArtwork(
                  artistImageUrl: disco.avatarUrl,
                  size: 78,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.verified_rounded,
                            color: tokens.accent,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${disco.albums.length} Albums • ${disco.allTracks.length} Studio Masters',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tokens.accent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Canonical Master Discography',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: tokens.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: tokens.textMuted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Row 2: Dual Action Pills (Play All & Shuffle)
          Row(
            children: [
              Expanded(
                child: BouncingScaleButton(
                  scaleFactor: 0.96,
                  minTouchTarget: 0,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (disco.allTracks.isNotEmpty) {
                      audioHandler.setTrackSource('artist_discography');
                      audioHandler.playTrack(
                        disco.allTracks.first,
                        queue: disco.allTracks,
                      );
                    }
                  },
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: tokens.accent,
                      borderRadius: BorderRadius.circular(tokens.radiusFull),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.accent.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Play All',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BouncingScaleButton(
                  scaleFactor: 0.96,
                  minTouchTarget: 0,
                  onTap: () {
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
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: tokens.surfaceHighlight,
                      borderRadius: BorderRadius.circular(tokens.radiusFull),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shuffle_rounded,
                          color: tokens.textPrimary,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Shuffle',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 3: Smart Deduplication Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: tokens.surfaceHighlight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(tokens.radiusFull),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_fix_high_rounded,
                  color: tokens.accent,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  'Deduplicated Studio Masters • Bit-perfect FLAC 320k',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
