import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'app_pill_button.dart';

/// Clean empty and error state component for search, library, and playlists.
class EmptyErrorState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final bool isError;
  final Widget? customContent;

  const EmptyErrorState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onActionTap,
    this.isError = false,
    this.customContent,
  });

  const EmptyErrorState.empty({
    super.key,
    this.icon = Icons.music_off_rounded,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onActionTap,
    this.customContent,
  }) : isError = false;

  const EmptyErrorState.error({
    super.key,
    this.icon = Icons.error_outline_rounded,
    required this.title,
    required this.subtitle,
    this.actionLabel = 'Try Again',
    this.onActionTap,
    this.customContent,
  }) : isError = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final iconColor = isError ? tokens.error : tokens.textMuted;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 72.0,
              height: 72.0,
              decoration: BoxDecoration(
                color: tokens.card,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 32.0,
                  color: iconColor,
                ),
              ),
            ),
            SizedBox(height: tokens.spaceLg),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: tokens.spaceSm),

            // Subtitle
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320.0),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ),

            if (customContent != null) ...[
              SizedBox(height: tokens.spaceMd),
              customContent!,
            ],

            // Action button
            if (actionLabel != null && onActionTap != null) ...[
              SizedBox(height: tokens.spaceLg),
              AppPillButton(
                label: actionLabel!,
                onPressed: onActionTap,
                variant: isError
                    ? AppPillButtonVariant.destructive
                    : AppPillButtonVariant.primary,
                height: 40.0,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
