import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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

/// 6-Tab mobile bottom navigation bar adhering to Stitch mobile design:
/// - Classic: Solid #121212 chrome with white active highlights
/// - Aurora Glass: Frosted glassmorphism with cyan/violet aurora highlights
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
    final isGlass = tokens.isGlass;

    return AppSurface(
      height: 60,
      borderRadius: BorderRadius.zero,
      withBlur: true,
      blurSigma: 14.0,
      color: isGlass ? tokens.glassSurface : const Color(0xFF121212),
      border: Border(
        top: BorderSide(
          color: isGlass ? tokens.glassBorder : const Color(0x1AFFFFFF),
          width: isGlass ? 1.0 : 0.5,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;
              final activeColor = isGlass ? tokens.accentCyan : Colors.white;
              final inactiveColor =
                  isGlass ? const Color(0xFF8E8BAE) : const Color(0xFFB3B3B3);

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
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            size: 24,
                            color: isSelected ? activeColor : inactiveColor,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? activeColor : inactiveColor,
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

