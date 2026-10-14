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

/// 6-Tab mobile bottom navigation bar adhering to Stitch mobile design:
/// - Background: Chrome #000000 / elevated #181818
/// - Strict 12px font size floor with Manrope typography
/// - Active accent highlight and tactile bouncing touch targets
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
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(
          top: BorderSide(
            color: Color(0x1AFFFFFF),
            width: 0.5,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;
              const activeColor = Colors.white; // Authentic Spotify pure white
              const inactiveColor = Color(0xFFB3B3B3);

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
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
