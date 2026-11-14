import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../bouncing_scale_button.dart';

enum AppPillButtonVariant {
  primary,
  secondary,
  destructive,
  ghost,
}

/// Content-first pill button for key actions (Play, Shuffle, Import, Clear, etc.).
class AppPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppPillButtonVariant variant;
  final Widget? icon;
  final double height;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;

  const AppPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppPillButtonVariant.primary,
    this.icon,
    this.height = 40.0,
    this.isLoading = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isEnabled = onPressed != null && !isLoading;

    Color bgColor;
    Color fgColor;

    switch (variant) {
      case AppPillButtonVariant.primary:
        bgColor = isEnabled
            ? (tokens.isGlass ? Colors.white : tokens.accent)
            : (tokens.isGlass
                ? Colors.white.withValues(alpha: 0.4)
                : tokens.accent.withValues(alpha: 0.4));
        fgColor = Colors.black;
        break;
      case AppPillButtonVariant.secondary:
        bgColor = isEnabled
            ? (tokens.isGlass ? tokens.glassSurface : tokens.surfaceElevated)
            : tokens.card;
        fgColor = isEnabled ? tokens.textPrimary : tokens.textMuted;
        break;
      case AppPillButtonVariant.destructive:
        bgColor = isEnabled ? tokens.error : tokens.error.withValues(alpha: 0.4);
        fgColor = Colors.white;
        break;
      case AppPillButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = isEnabled ? tokens.textPrimary : tokens.textMuted;
        break;
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16.0,
            height: 16.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          SizedBox(width: tokens.spaceSm),
        ] else if (icon != null) ...[
          IconTheme(
            data: IconThemeData(size: 18.0, color: fgColor),
            child: icon!,
          ),
          SizedBox(width: tokens.spaceSm),
        ],
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 14.0,
            fontWeight: variant == AppPillButtonVariant.primary
                ? FontWeight.w700
                : FontWeight.w600,
            color: fgColor,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      child: BouncingScaleButton(
        onTap: isEnabled ? onPressed : null,
        scaleDown: 0.96,
        child: Container(
          height: height,
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: tokens.spaceLg,
                vertical: 0.0,
              ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            border: (tokens.isGlass && variant != AppPillButtonVariant.ghost)
                ? Border.all(
                    color: variant == AppPillButtonVariant.primary
                        ? Colors.white
                        : tokens.glassBorder,
                    width: 1.0,
                  )
                : (!tokens.isGlass && variant == AppPillButtonVariant.secondary)
                    ? Border.all(
                        color: tokens.divider,
                        width: 1.0,
                      )
                    : null,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}
