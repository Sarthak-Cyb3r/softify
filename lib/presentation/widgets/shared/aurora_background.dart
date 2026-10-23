import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../providers/player_providers.dart';
import '../../providers/ui_style_provider.dart';

/// Background container that provides solid dark background for Classic
/// and a luminous dynamic aurora mesh gradient for Aurora Glass.
class AuroraBackground extends ConsumerWidget {
  final Widget child;

  const AuroraBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    if (!tokens.isGlass) {
      return Container(
        color: tokens.background,
        child: child,
      );
    }

    final reduceEffects = ref.watch(shouldReduceEffectsProvider);
    final currentTrack = ref.watch(currentTrackProvider).value;
    final paletteAsync =
        ref.watch(auroraPaletteProvider(currentTrack?.coverUrl));

    final accentColor = paletteAsync.value ?? const Color(0xFF7C5CFF);

    if (reduceEffects) {
      // Lightweight static gradient for battery saver and low-end hardware
      return RepaintBoundary(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF14122B),
                Color(0xFF0B0B1A),
                Color(0xFF080814),
              ],
            ),
          ),
          child: child,
        ),
      );
    }

    // Dynamic animated aurora mesh
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: const Color(0xFF7C5CFF),
        end: accentColor,
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, dynamicColor, _) {
        final color = dynamicColor ?? const Color(0xFF7C5CFF);

        return Stack(
          children: [
            // RepaintBoundary ensures the background gradients are cached as a GPU texture
            // and do not repaint when the foreground child scrolls or updates
            Positioned.fill(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0B0B1A),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF14122B),
                        Color(0xFF0B0B1A),
                        Color(0xFF070712),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Dynamic Artwork Aura (Top-Left)
                      Positioned(
                        top: -120,
                        left: -80,
                        width: 420,
                        height: 420,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                color.withValues(alpha: 0.25),
                                color.withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Cyan Aurora Glow (Bottom-Right)
                      Positioned(
                        bottom: -100,
                        right: -100,
                        width: 440,
                        height: 440,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF4FD1FF).withValues(alpha: 0.18),
                                const Color(0xFF7C5CFF).withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Rose Subtle Mid-glow
                      Positioned(
                        top: 260,
                        right: -60,
                        width: 300,
                        height: 300,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFFF7AC6).withValues(alpha: 0.10),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Foreground Content
            Positioned.fill(
              child: child,
            ),
          ],
        );
      },
    );
  }
}
