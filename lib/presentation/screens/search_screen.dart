import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
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
  Timer? _debounceTimer;
  List<Track> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    setState(() {});
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _executeSearch(query.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final results = await catalog.search(query, limit: 25);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Search error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final audioHandler = ref.watch(audioHandlerProvider);

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
                _debounceTimer?.cancel();
                if (val.trim().isNotEmpty) {
                  _executeSearch(val.trim());
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
                          _onQueryChanged('');
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

          // Search Results / Loading / Empty States
          Expanded(
            child: _isLoading
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
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFE91429)),
                          ),
                        ),
                      )
                    : _searchResults.isEmpty
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
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final track = _searchResults[index];
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
