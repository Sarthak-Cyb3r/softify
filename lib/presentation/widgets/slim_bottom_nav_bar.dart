import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/metrolist_dimensions.dart';
import 'bouncing_scale_button.dart';
import 'shared/app_surface.dart';

class SlimNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const SlimNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Metrolist Material 3 Expressive Navigation Bar:
/// - Pure Black AMOLED base with subtle top hairline
/// - Animated active tonal pill capsule behind selected icon
/// - Clean hierarchical typography
/// - Support for long-press actions (e.g. Shazam on Search tab)
class SlimBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int>? onLongPress;
  final List<SlimNavItem> items;
  final bool isSlim;

  const SlimBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onLongPress,
    required this.items,
    this.isSlim = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final navHeight = isSlim
        ? MetrolistDimensions.slimNavBarHeight
        : MetrolistDimensions.navigationBarHeight;

    final border = Border(
      top: BorderSide(
        color: tokens.cardHover.withValues(alpha: 0.35),
        width: 0.8,
      ),
    );

    Widget navContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == currentIndex;

            return Expanded(
              child: Semantics(
                selected: isSelected,
                button: true,
                label: item.label,
                child: GestureDetector(
                  onLongPress: onLongPress != null ? () => onLongPress!(index) : null,
                  behavior: HitTestBehavior.opaque,
                  child: BouncingScaleButton(
                    onTap: () => onTap(index),
                    scaleDown: 0.95,
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Metrolist M3 / Liquid Glass Active Pill Capsule
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: isSelected ? 64 : 44,
                            height: 32,
                            child: isSelected && tokens.isGlass
                                ? LiquidGlassContainer(
                                    width: 64,
                                    height: 32,
                                    borderRadius: BorderRadius.circular(16),
                                    interactive: false,
                                    tintColor: tokens.accent.withValues(alpha: 0.35),
                                    child: Center(
                                      child: Icon(
                                        item.activeIcon,
                                        size: 22,
                                        color: tokens.accent,
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? tokens.accent.withValues(alpha: 0.22)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isSelected ? item.activeIcon : item.icon,
                                        size: 22,
                                        color: isSelected
                                            ? tokens.accent
                                            : tokens.textSecondary,
                                      ),
                                    ),
                                  ),
                          ),
                          if (!isSlim) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );

    if (tokens.isGlass) {
      return AppSurface(
        height: navHeight,
        borderRadius: BorderRadius.zero,
        border: border,
        withBlur: true,
        blurSigma: 20.0,
        color: tokens.background.withValues(alpha: 0.85),
        child: navContent,
      );
    }

    return Container(
      height: navHeight,
      decoration: BoxDecoration(
        color: tokens.background,
        border: border,
      ),
      child: navContent,
    );
  }
}
