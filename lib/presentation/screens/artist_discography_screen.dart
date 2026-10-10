import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/spotify_api_service.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../theme/app_tokens.dart';
import '../widgets/artist_cd_artwork.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/track_options_bottom_sheet.dart';
import 'album_detail_screen.dart';

class ArtistDiscographyScreen extends ConsumerStatefulWidget {
  final ArtistDiscography disco;

  const ArtistDiscographyScreen({
    super.key,
    required this.disco,
  });

  @override
  ConsumerState<ArtistDiscographyScreen> createState() =>
      _ArtistDiscographyScreenState();
}

class _ArtistDiscographyScreenState
    extends ConsumerState<ArtistDiscographyScreen> {
  final String _searchFilter = '';

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final audioHandler = ref.watch(audioHandlerProvider);

    final filteredTracks = _searchFilter.isEmpty
        ? widget.disco.allTracks
        : widget.disco.allTracks
            .where((t) =>
                t.title.toLowerCase().contains(_searchFilter.toLowerCase()) ||
                t.artist.toLowerCase().contains(_searchFilter.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: tokens.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar & Hero Discography Artwork
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: tokens.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: tokens.textPrimary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tokens.accent.withValues(alpha: 0.22),
                      tokens.surface,
                      tokens.background,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      // Dark CD Artwork with Artist Image
                      ArtistCdArtwork(
                        artistImageUrl: widget.disco.avatarUrl,
                        size: 92,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          widget.disco.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.accent.withValues(alpha: 0.18),
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                            ),
                            child: Text(
                              'COMPLETE DISCOGRAPHY',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: tokens.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.disco.albums.length} releases • ${widget.disco.allTracks.length} tracks',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Play All & Shuffle Action Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: BouncingScaleButton(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        if (widget.disco.allTracks.isNotEmpty) {
                          audioHandler.setTrackSource('artist_discography');
                          audioHandler.playTrack(
                            widget.disco.allTracks.first,
                            queue: widget.disco.allTracks,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          borderRadius:
                              BorderRadius.circular(tokens.radiusFull),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.accent.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                color: Colors.black, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Play All',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BouncingScaleButton(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        if (widget.disco.allTracks.isNotEmpty) {
                          final shuffled = List<Track>.from(widget.disco.allTracks)
                            ..shuffle();
                          audioHandler.setTrackSource('artist_discography');
                          audioHandler.playTrack(
                            shuffled.first,
                            queue: shuffled,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: tokens.surfaceElevated,
                          borderRadius:
                              BorderRadius.circular(tokens.radiusFull),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shuffle_rounded,
                                color: tokens.textPrimary, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'Shuffle',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Albums Section Header
          if (widget.disco.albums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    Text(
                      'Albums & Releases',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.disco.albums.length} items',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Horizontal Carousel of Albums
            SliverToBoxAdapter(
              child: SizedBox(
                height: 168,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.disco.albums.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, idx) {
                    final album = widget.disco.albums[idx];
                    return BouncingScaleButton(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AlbumDetailScreen(
                              albumName: album.name,
                              artistName: widget.disco.artistName,
                              coverUrl: album.coverUrl,
                              albumUriOrId: album.uri,
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 114,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusMd),
                              child: album.coverUrl != null
                                  ? Image.network(
                                      album.coverUrl!,
                                      width: 114,
                                      height: 114,
                                      fit: BoxFit.cover,
                                      cacheWidth: 228,
                                      cacheHeight: 228,
                                      errorBuilder: (_, __, ___) =>
                                          _fallbackAlbumCover(tokens),
                                    )
                                  : _fallbackAlbumCover(tokens),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              album.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Release',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // Tracks Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Text(
                    'All Songs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    child: Text(
                      '${filteredTracks.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tracklist
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = filteredTracks[index];
                  final isLikedAsync = ref.watch(isTrackLikedProvider(track.id));
                  final isLiked = isLikedAsync.value ?? track.isLiked;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.setTrackSource('artist_discography');
                        audioHandler.playTrack(
                          track,
                          queue: widget.disco.allTracks,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            // Track Index
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Artwork
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              child: track.coverUrl != null
                                  ? Image.network(
                                      track.coverUrl!,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      cacheWidth: 132,
                                      cacheHeight: 132,
                                      errorBuilder: (_, __, ___) =>
                                          _fallbackAlbumCover(tokens),
                                    )
                                  : _fallbackAlbumCover(tokens),
                            ),
                            const SizedBox(width: 12),
                            // Title & Artists
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Duration
                            Text(
                              _formatDuration(track.duration),
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.textMuted,
                              ),
                            ),
                            // Favorite Button
                            IconButton(
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_outline_rounded,
                                color: isLiked ? tokens.accent : tokens.textMuted,
                                size: 18,
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(libraryRepositoryProvider)
                                    .setLiked(track.id, !isLiked, track: track);
                              },
                            ),
                            // More Options
                            IconButton(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: tokens.textMuted,
                                size: 18,
                              ),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (_) =>
                                      TrackOptionsBottomSheet(track: track),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: filteredTracks.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAlbumCover(AppTokens tokens) {
    return Container(
      width: 44,
      height: 44,
      color: tokens.surfaceElevated,
      child: Icon(
        Icons.music_note_rounded,
        color: tokens.textMuted,
        size: 20,
      ),
    );
  }
}
