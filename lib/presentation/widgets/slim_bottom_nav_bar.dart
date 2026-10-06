import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
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

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radiusFull),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusFull),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xE0121212),
                borderRadius: BorderRadius.circular(tokens.radiusFull),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;

                  return Expanded(
                    child: BouncingScaleButton(
                      onTap: () => onTap(index),
                      scaleFactor: 0.94,
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        child: AnimatedContainer(
                          duration: tokens.motionStandard,
                          curve: tokens.curveDecel,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(tokens.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: 22,
                                color: isSelected
                                    ? tokens.textPrimary
                                    : tokens.textSecondary.withValues(alpha: 0.7),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
