import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/animated_artwork_provider.dart';
import '../theme/app_theme.dart';
import 'shared/app_network_image.dart';
import 'shared/app_surface.dart';

/// Presentation card for album artwork that seamlessly upgrades to Apple Music's
/// dynamic Animated Artwork (motion cover) when available, while preserving instant
/// static fallback, zero-layout-shift preview frames, and subtle ambient motion.
class AnimatedArtworkCard extends ConsumerStatefulWidget {
  final Track track;
  final bool isPlaying;
  final Color ambientColor;
  final double borderRadius;
  final double? size;
  final VoidCallback? onTap;
  final ValueChanged<DragEndDetails>? onVerticalDragEnd;

  const AnimatedArtworkCard({
    super.key,
    required this.track,
    this.isPlaying = false,
    this.ambientColor = const Color(0xFF141A16),
    this.borderRadius = 16.0,
    this.size,
    this.onTap,
    this.onVerticalDragEnd,
  });

  @override
  ConsumerState<AnimatedArtworkCard> createState() =>
      _AnimatedArtworkCardState();
}

class _AnimatedArtworkCardState extends ConsumerState<AnimatedArtworkCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _motionController;
  late Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );

    _breatheAnimation = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(
        parent: _motionController,
        curve: Curves.easeInOutSine,
      ),
    );

    if (widget.isPlaying) {
      _motionController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedArtworkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_motionController.isAnimating) {
          _motionController.repeat(reverse: true);
        }
      } else {
        _motionController.stop();
      }
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animatedArtworkAsync = ref.watch(animatedArtworkProvider(widget.track));
    final animatedArtwork = animatedArtworkAsync.valueOrNull;
    final hasAnimated = animatedArtwork != null &&
        animatedArtwork.hasAnimatedArtwork &&
        animatedArtwork.previewImageUrl != null;

    final tokens = context.tokens;

    return GestureDetector(
      onTap: widget.onTap,
      onVerticalDragEnd: widget.onVerticalDragEnd,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            constraints: widget.size != null
                ? BoxConstraints(
                    maxWidth: widget.size!,
                    maxHeight: widget.size!,
                  )
                : const BoxConstraints(maxWidth: 380, maxHeight: 380),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: (hasAnimated
                          ? widget.ambientColor
                          : Colors.black)
                      .withValues(alpha: hasAnimated ? 0.55 : 0.45),
                  blurRadius: hasAnimated ? 40 : 32,
                  spreadRadius: hasAnimated ? 4 : 2,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Base Static Cover Image (Loads instantly, zero layout shift)
                  AppNetworkImage(
                    imageUrl: widget.track.coverUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 800,
                    cacheHeight: 800,
                    placeholderIcon: Icons.music_note_rounded,
                  ),

                  // 2. Animated Motion Layer (Smoothly fades in over static cover)
                  if (hasAnimated)
                    AnimatedBuilder(
                      animation: _breatheAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: widget.isPlaying
                              ? _breatheAnimation.value
                              : 1.0,
                          alignment: Alignment.center,
                          child: child,
                        );
                      },
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, opacity, child) {
                          return Opacity(
                            opacity: opacity,
                            child: child,
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AppNetworkImage(
                              imageUrl: animatedArtwork.previewImageUrl,
                              fit: BoxFit.cover,
                              cacheWidth: 800,
                              cacheHeight: 800,
                              placeholderIcon: Icons.music_note_rounded,
                            ),

                            // Ambient Specular Sweep Shimmer
                            AnimatedBuilder(
                              animation: _motionController,
                              builder: (context, child) {
                                final shimmerOffset = _motionController.value;
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(
                                        -2.0 + shimmerOffset * 4.0,
                                        -1.0,
                                      ),
                                      end: Alignment(
                                        shimmerOffset * 4.0,
                                        1.0,
                                      ),
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.08),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Motion Artwork Badge
                  if (hasAnimated)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, val, child) {
                          return Opacity(
                            opacity: val,
                            child: child,
                          );
                        },
                        child: AppSurface(
                          withBlur: true,
                          blurSigma: 16.0,
                          borderRadius: BorderRadius.circular(tokens.radiusFull),
                          color: Colors.black.withValues(alpha: 0.50),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_motion_rounded,
                                color: tokens.isGlass
                                    ? tokens.accentCyan
                                    : tokens.accent,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'ANIMATED COVER',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
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
        ),
      ),
    );
  }
}
