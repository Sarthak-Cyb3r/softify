import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../bouncing_scale_button.dart';
import 'app_surface.dart';

/// Pill filter chip for categorization (e.g. "All", "Music", "Podcasts", "Downloaded").
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? icon;
  final double height;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.height = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final textColor = isSelected
        ? Colors.black
        : tokens.textPrimary;

    final chipContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconTheme(
            data: IconThemeData(
              size: 16.0,
              color: textColor,
            ),
            child: icon!,
          ),
          SizedBox(width: tokens.spaceXs + 2.0),
        ],
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 13.0,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );

    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: BouncingScaleButton(
        onTap: onTap,
        scaleDown: 0.95,
        child: tokens.isGlass
            ? AppSurface(
                height: height,
                withBlur: true,
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spaceMd,
                  vertical: 0.0,
                ),
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : tokens.glassBorder,
                  width: 1.0,
                ),
                boxShadow: null,
                child: chipContent,
              )
            : Container(
                height: height,
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spaceMd,
                  vertical: 0.0,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? tokens.accent : tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  border: isSelected
                      ? null
                      : Border.all(color: tokens.divider, width: 1.0),
                ),
                child: chipContent,
              ),
      ),
    );
  }
}
