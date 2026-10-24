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

    final accentColor = paletteAsync.value ?? const Color(0xFF34D399);

    if (reduceEffects) {
      // Lightweight static gradient for battery saver and low-end hardware
      return RepaintBoundary(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF141418),
                Color(0xFF0E0E11),
                Color(0xFF09090B),
              ],
            ),
          ),
          child: child,
        ),
      );
    }

    // Dynamic animated minimalist ambient aura
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: const Color(0xFF34D399),
        end: accentColor,
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, dynamicColor, _) {
        final color = dynamicColor ?? const Color(0xFF34D399);

        return Stack(
          children: [
            // RepaintBoundary ensures the background gradients are cached as a GPU texture
            // and do not repaint when the foreground child scrolls or updates
            Positioned.fill(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0E0E11),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF131317),
                        Color(0xFF0E0E11),
                        Color(0xFF08080A),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // 1. Dynamic Artwork Aura (Atmospheric top-left ambient light)
                      Positioned(
                        top: -120,
                        left: -60,
                        width: 520,
                        height: 520,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                color.withValues(alpha: 0.14),
                                color.withValues(alpha: 0.04),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.50, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // 2. Soft Warm Secondary Studio Ambient Light (Bottom-Right dock region)
                      Positioned(
                        bottom: -100,
                        right: -80,
                        width: 440,
                        height: 440,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.04),
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
