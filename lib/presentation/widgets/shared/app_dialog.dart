import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'app_pill_button.dart';

/// Content-first dialog modal adhering to elevated #2A2A2A surface and 8px radius.
class AppDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final String? message;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final List<Widget>? customActions;

  const AppDialog({
    super.key,
    required this.title,
    this.content,
    this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.customActions,
  });

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Dialog(
      backgroundColor: tokens.surfaceElevated,
      elevation: 16.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
      ),
      insetPadding: EdgeInsets.all(tokens.spaceLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440.0),
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Title (Bricolage Grotesque)
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTheme.fontPageTitle,
                  fontSize: 20.0,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: tokens.spaceSm),

              // Message or custom content
              if (message != null)
                Text(
                  message!,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              if (content != null) content!,

              SizedBox(height: tokens.spaceLg),

              // Action buttons (Pills)
              if (customActions != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: customActions!,
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cancelText != null) ...[
                      AppPillButton(
                        label: cancelText!,
                        variant: AppPillButtonVariant.ghost,
                        height: 36.0,
                        onPressed: onCancel ?? () => Navigator.of(context).pop(),
                      ),
                      SizedBox(width: tokens.spaceSm),
                    ],
                    if (confirmText != null)
                      AppPillButton(
                        label: confirmText!,
                        variant: isDestructive
                            ? AppPillButtonVariant.destructive
                            : AppPillButtonVariant.primary,
                        height: 36.0,
                        onPressed: onConfirm,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
