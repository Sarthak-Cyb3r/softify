import 'package:flutter/material.dart';

import '../../../domain/entities/track.dart';
import '../../theme/app_theme.dart';
import '../../theme/metrolist_dimensions.dart';
import '../animated_music_wave_indicator.dart';
import 'app_network_image.dart';

/// Content-first 56px track data row for lists, queues, and search results.
class TrackRow extends StatefulWidget {
  final Track track;
  final int? index;
  final bool isPlaying;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onOptionsTap;
  final bool showArtwork;
  final bool showIndex;
  final bool showDuration;
  final bool showLikeButton;
  final bool showOptionsButton;
  final Widget? trailing;

  const TrackRow({
    super.key,
    required this.track,
    this.index,
    this.isPlaying = false,
    this.isSelected = false,
    this.onTap,
    this.onPlayTap,
    this.onLikeTap,
    this.onOptionsTap,
    this.showArtwork = true,
    this.showIndex = true,
    this.showDuration = true,
    this.showLikeButton = true,
    this.showOptionsButton = true,
    this.trailing,
  });

  @override
  State<TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<TrackRow> {
  bool _isHovered = false;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isHovered = _isHovered || widget.isSelected;
    final rowColor = isHovered ? tokens.cardHover : Colors.transparent;

    final semanticLabel =
        '${widget.track.title} by ${widget.track.artist}, duration ${_formatDuration(widget.track.duration)}';

    return Semantics(
      label: semanticLabel,
      button: true,
      selected: widget.isPlaying || widget.isSelected,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: widget.onTap ?? widget.onPlayTap,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          splashColor: Colors.transparent,
          highlightColor: tokens.cardHover.withValues(alpha: 0.4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: MetrolistDimensions.listItemHeight,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spaceSm,
              vertical: tokens.spaceXs,
            ),
            decoration: BoxDecoration(
              color: rowColor,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: (tokens.isGlass && isHovered)
                  ? Border.all(color: tokens.glassBorder, width: 0.8)
                  : null,
            ),
            child: Row(
              children: [
                // Track Index / Play Trigger / Wave Indicator
                if (widget.showIndex) _buildLeadingIndex(tokens),

                // Artwork (40x40 square with 4px radius)
                if (widget.showArtwork) ...[
                  _buildArtwork(tokens),
                  SizedBox(width: tokens.spaceMd),
                ],

                // Title & Artist Stack
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: (widget.isPlaying || widget.isSelected)
                              ? (tokens.isGlass
                                  ? tokens.accentCyan
                                  : tokens.accent)
                              : tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Row(
                        children: [
                          if (widget.track.isLyricsMatch) ...[
                            Flexible(
                              fit: FlexFit.loose,
                              child: Container(
                                margin: const EdgeInsets.only(right: 6.0),
                                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: (tokens.isGlass ? tokens.accentCyan : tokens.accent).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.mic_none_rounded,
                                      size: 11.0,
                                      color: tokens.isGlass ? tokens.accentCyan : tokens.accent,
                                    ),
                                    const SizedBox(width: 3.0),
                                    Flexible(
                                      child: Text(
                                        'Lyrics match',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontUi,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: tokens.isGlass ? tokens.accentCyan : tokens.accent,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              widget.track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 12.0, // Strict 12px min floor
                                fontWeight: FontWeight.w400,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Like Button
                if (widget.showLikeButton)
                  IconButton(
                    iconSize: 18.0,
                    splashRadius: 18.0,
                    tooltip: widget.track.isLiked ? 'Unlike' : 'Like',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(
                      widget.track.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: widget.track.isLiked
                          ? (tokens.isGlass
                              ? tokens.accentRose
                              : tokens.accent)
                          : tokens.textSecondary,
                    ),
                    onPressed: widget.onLikeTap,
                  ),

                // Duration Text (tabular numerals, 12px min)
                if (widget.showDuration) ...[
                  SizedBox(width: tokens.spaceSm),
                  Text(
                    _formatDuration(widget.track.duration),
                    style: AppTheme.tabularTimestamp(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400,
                      color: tokens.textMuted,
                    ),
                  ),
                ],

                // Overflow / Options Trigger
                if (widget.showOptionsButton)
                  IconButton(
                    iconSize: 18.0,
                    splashRadius: 18.0,
                    tooltip: 'More options',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isHovered ? tokens.textPrimary : tokens.textMuted,
                    ),
                    onPressed: widget.onOptionsTap,
                  ),

                // Custom trailing widget if provided
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIndex(AppTokens tokens) {
    final indexNum = widget.index != null ? '${widget.index}' : '';
    final isCurrent = widget.isPlaying || widget.isSelected;

    return SizedBox(
      width: 32.0,
      child: Center(
        child: isCurrent
            ? SizedBox(
                width: 14.0,
                height: 14.0,
                child: AnimatedMusicWaveIndicator(
                  isPlaying: widget.isPlaying,
                  color: tokens.isGlass ? tokens.accentCyan : tokens.accent,
                  barCount: 3,
                ),
              )
            : (_isHovered
                ? IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    iconSize: 18.0,
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      color: tokens.isGlass ? tokens.accentCyan : tokens.accent,
                    ),
                    onPressed: widget.onPlayTap ?? widget.onTap,
                  )
                : Text(
                    indexNum,
                    style: AppTheme.tabularTimestamp(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      color: tokens.textMuted,
                    ),
                  )),
      ),
    );
  }

  Widget _buildArtwork(AppTokens tokens) {
    return AppNetworkImage(
      imageUrl: widget.track.coverUrl,
      width: MetrolistDimensions.listThumbnailSize,
      height: MetrolistDimensions.listThumbnailSize,
      borderRadius: BorderRadius.circular(
        tokens.isGlass ? 8.0 : MetrolistDimensions.thumbnailCornerRadius,
      ),
      fit: BoxFit.cover,
      fallbackIcon: Icons.music_note_rounded,
      backgroundColor: tokens.card,
    );
  }
}
