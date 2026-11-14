import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'bouncing_scale_button.dart';

/// Pixel-perfect clone of Metrolist's NavigationTitle.kt component.
/// Displays category title, optional uppercase label (e.g. "START RADIO FROM A SONG"),
/// optional play-all pill button, and optional navigation arrow.
class MetrolistNavigationTitle extends StatelessWidget {
  final String title;
  final String? label;
  final Widget? thumbnail;
  final VoidCallback? onClick;
  final VoidCallback? onPlayAllClick;
  final EdgeInsetsGeometry padding;

  const MetrolistNavigationTitle({
    super.key,
    required this.title,
    this.label,
    this.thumbnail,
    this.onClick,
    this.onPlayAllClick,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (thumbnail != null) ...[
            thumbnail!,
            const SizedBox(width: 12.0),
          ],
          Expanded(
            child: InkWell(
              onTap: onClick,
              borderRadius: BorderRadius.circular(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null) ...[
                    Text(
                      label!.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                  ],
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontPageTitle,
                      fontSize: 22.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onPlayAllClick != null) ...[
            const SizedBox(width: 8.0),
            BouncingScaleButton(
              scaleFactor: 0.94,
              onTap: onPlayAllClick!,
              child: Container(
                height: 26.0,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: tokens.accent.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Play all',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    color: tokens.accent,
                  ),
                ),
              ),
            ),
          ],
          if (onClick != null) ...[
            const SizedBox(width: 4.0),
            IconButton(
              icon: Icon(
                Icons.arrow_forward_rounded,
                color: tokens.accent,
                size: 20.0,
              ),
              onPressed: onClick,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
            ),
          ],
        ],
      ),
    );
  }
}
