import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/metrolist_dimensions.dart';
import '../bouncing_scale_button.dart';
import 'app_network_image.dart';
import 'app_surface.dart';

/// Content-first square media card for albums, playlists, and shelves.
class MediaCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;
  final IconData placeholderIcon;
  final double width;
  final bool isPlaying;

  const MediaCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.onTap,
    this.onPlayTap,
    this.placeholderIcon = Icons.album_rounded,
    this.width = MetrolistDimensions.gridThumbnailHeight,
    this.isPlaying = false,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cardBg = _isHovered ? tokens.cardHover : tokens.card;

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1:1 Square Artwork Container with Play Button
        AspectRatio(
          aspectRatio: 1.0,
          child: Stack(
            children: [
              // Image with rounded inner radius (Metrolist 3dp)
              Positioned.fill(
                child: AppNetworkImage(
                  imageUrl: widget.imageUrl,
                  borderRadius: BorderRadius.circular(
                    tokens.isGlass ? 14.0 : MetrolistDimensions.thumbnailCornerRadius,
                  ),
                  fit: BoxFit.cover,
                  fallbackIcon: widget.placeholderIcon,
                ),
              ),

              // Play Pill Button on hover or playing
              Positioned(
                right: 8.0,
                bottom: 8.0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: (_isHovered || widget.isPlaying) ? 1.0 : 0.0,
                  child: Container(
                    width: 40.0,
                    height: 40.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.isGlass
                          ? tokens.accentCyan
                          : tokens.accent,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 8.0,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 22.0,
                      icon: Icon(
                        widget.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black,
                      ),
                      onPressed: widget.onPlayTap ?? widget.onTap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spaceSm),

        // Card Title
        Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 14.0,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),

        // Card Subtitle (min 12px)
        if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2.0),
          Text(
            widget.subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 12.0, // Strict 12px floor
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      label: '${widget.title}, ${widget.subtitle ?? ""}',
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: BouncingScaleButton(
          onTap: widget.onTap ?? widget.onPlayTap,
          scaleDown: 0.98,
          child: tokens.isGlass
              ? AppSurface(
                  width: widget.width,
                  padding: EdgeInsets.all(tokens.spaceSm + 2.0),
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                  withBlur: true,
                  border: Border.all(
                    color: _isHovered
                        ? tokens.accentCyan.withValues(alpha: 0.60)
                        : tokens.glassBorder,
                    width: 1.0,
                  ),
                  boxShadow: tokens.cardShadow,
                  child: cardContent,
                )
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: widget.width,
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: _isHovered ? cardBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: cardContent,
                ),
        ),
      ),
    );
  }


}
