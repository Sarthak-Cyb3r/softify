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
                Color(0xFF140F30),
                Color(0xFF090818),
                Color(0xFF060512),
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
                    color: Color(0xFF090818),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF130E2E),
                        Color(0xFF090818),
                        Color(0xFF050410),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // 1. Dynamic Artwork Aura (Top-Left / Header region)
                      Positioned(
                        top: -100,
                        left: -80,
                        width: 480,
                        height: 480,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                color.withValues(alpha: 0.50),
                                color.withValues(alpha: 0.22),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // 2. Electric Cyan Aurora Beam (Bottom-Right / Floating Dock region)
                      Positioned(
                        bottom: -90,
                        right: -80,
                        width: 460,
                        height: 460,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF00D2FF).withValues(alpha: 0.38),
                                const Color(0xFF7C5CFF).withValues(alpha: 0.16),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // 3. Aurora Violet Ambient Node (Top-Right / Actions region)
                      Positioned(
                        top: 40,
                        right: -100,
                        width: 420,
                        height: 420,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF7C5CFF).withValues(alpha: 0.35),
                                const Color(0xFF4338CA).withValues(alpha: 0.14),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.50, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // 4. Radiant Rose / Magenta Mid-body Glow (Center-Left)
                      Positioned(
                        top: 320,
                        left: -80,
                        width: 360,
                        height: 360,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFFF2E93).withValues(alpha: 0.28),
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
