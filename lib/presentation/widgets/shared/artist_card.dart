import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../bouncing_scale_button.dart';
import 'app_network_image.dart';
import 'app_surface.dart';

/// Content-first circular portrait artist card for search, home shelves, and library.
class ArtistCard extends StatefulWidget {
  final String name;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;
  final double width;
  final bool isPlaying;

  const ArtistCard({
    super.key,
    required this.name,
    this.subtitle = 'Artist',
    this.imageUrl,
    this.onTap,
    this.onPlayTap,
    this.width = 160.0,
    this.isPlaying = false,
  });

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cardBg = _isHovered ? tokens.cardHover : tokens.card;

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular 1:1 Avatar with play button
        AspectRatio(
          aspectRatio: 1.0,
          child: Stack(
            children: [
              // Strictly Circular Avatar
              Positioned.fill(
                child: AppNetworkImage(
                  imageUrl: widget.imageUrl,
                  isCircular: true,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.person_rounded,
                ),
              ),

              // Play Button on hover or playing
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
                      color: tokens.isGlass ? tokens.accentCyan : AppTheme.accent,
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

        // Artist Name
        Text(
          widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 14.0,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),

        // Subtitle
        if (widget.subtitle != null) ...[
          const SizedBox(height: 2.0),
          Text(
            widget.subtitle!,
            maxLines: 1,
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
      label: 'Artist: ${widget.name}',
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
                  padding: EdgeInsets.all(tokens.spaceSm + 2.0),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                    border: Border.all(
                      color: _isHovered
                          ? const Color(0x33FFFFFF)
                          : tokens.divider,
                      width: 1.0,
                    ),
                  ),
                  child: cardContent,
                ),
        ),
      ),
    );
  }


}
