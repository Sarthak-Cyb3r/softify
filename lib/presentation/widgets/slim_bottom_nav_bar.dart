import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'bouncing_scale_button.dart';

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
class SlimBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<SlimNavItem> items;

  const SlimBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: tokens.background,
        border: Border(
          top: BorderSide(
            color: tokens.cardHover.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
      ),
      child: Center(
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
                          // Metrolist M3 Active Tonal Pill Capsule
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: isSelected ? 58 : 42,
                            height: 30,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tokens.accent.withValues(alpha: 0.22)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: 22,
                                color: isSelected ? tokens.accent : tokens.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
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
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
