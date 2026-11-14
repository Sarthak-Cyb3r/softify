import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'bouncing_scale_button.dart';
import 'shared/app_network_image.dart';

/// Exact reverse-engineered Metrolist Speed Dial item (SpeedDialGridItem.kt):
/// - Square aspect ratio 1:1
/// - Corner radius: MetrolistDimensions.thumbnailCornerRadius (3.0) or squircle 12.0
/// - Multi-stop vertical gradient scrim for readability:
///   Top 40% scrim, transparent mid, 60% to 90% bottom scrim
/// - Bold white single-line title at bottom left with navigation chevron
class MetrolistSpeedDialItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? coverUrl;
  final bool isArtist;
  final bool isBrowsable;
  final bool isPinned;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MetrolistSpeedDialItem({
    super.key,
    required this.title,
    this.subtitle,
    this.coverUrl,
    this.isArtist = false,
    this.isBrowsable = true,
    this.isPinned = false,
    this.isActive = false,
    this.isPlaying = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = isArtist
        ? BorderRadius.circular(100)
        : BorderRadius.circular(10.0);

    return BouncingScaleButton(
      scaleFactor: 0.94,
      onTap: onTap,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Artwork Thumbnail
                if (coverUrl != null && coverUrl!.isNotEmpty)
                  AppNetworkImage(
                    imageUrl: coverUrl!,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.album_rounded,
                    backgroundColor: const Color(0xFF1E1F24),
                  )
                else
                  Container(
                    color: const Color(0xFF22242B),
                    child: const Center(
                      child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 32),
                    ),
                  ),

                // 2. Metrolist 4-stop Scrim Gradient
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.40),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.60),
                        Colors.black.withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.38, 0.72, 1.0],
                    ),
                  ),
                ),

                // 3. Pinned Indicator
                if (isPinned)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.push_pin_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),

                // 4. Playing Indicator Dot (if active)
                if (isActive)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                // 5. Title & Chevron at Bottom
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontUi,
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (isBrowsable)
                        const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reverse-engineered Metrolist Randomize item (RandomizeGridItem.kt):
/// Placed as the last slot of the first page of Speed Dial to shuffle/surprise
class MetrolistRandomizeGridItem extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const MetrolistRandomizeGridItem({
    super.key,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncingScaleButton(
      scaleFactor: 0.94,
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2026),
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  ),
                )
              else
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.casino_rounded,
                      color: AppTheme.accent,
                      size: 22,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Lucky Pick',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
