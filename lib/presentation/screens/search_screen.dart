import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/search_intent.dart';
import '../../domain/entities/track.dart';
import '../providers/autocomplete_providers.dart';
import '../providers/player_providers.dart';
import '../providers/search_providers.dart';
import '../theme/app_tokens.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/shimmer_skeleton.dart';
import '../widgets/track_options_bottom_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

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
    final results = searchState.combinedResults;

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
          // Big Minimal Search Input Field
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
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 0.8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                  borderSide: BorderSide(
                    color: tokens.accent.withValues(alpha: 0.6),
                    width: 1.0,
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
                    : results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  size: 56,
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'Search songs, artists, or albums'
                                      : 'No tracks found for "${_searchController.text}"',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final track = results[index];
                              return _buildSearchResultTile(
                                  tokens, track, index, audioHandler);
                            },
                          ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              ClipRRect(
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
                      durationFormatted.isNotEmpty
                          ? '${track.artist} • $durationFormatted'
                          : track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Download Button
              BouncingScaleButton(
                scaleFactor: 0.88,
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
}
