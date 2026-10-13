import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Floating toast and snackbar notification adhering to #2A2A2A surface.
class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    Widget? icon,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final tokens = context.tokens;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 8.0,
        backgroundColor: tokens.surfaceElevated,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusCard),
        ),
        margin: EdgeInsets.all(tokens.spaceMd),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon,
              SizedBox(width: tokens.spaceSm + 2.0),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        action: action,
      ),
    );
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
  }) {
    show(
      context,
      message: message,
      icon: const Icon(
        Icons.check_circle_rounded,
        size: 18.0,
        color: AppTheme.accent,
      ),
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
  }) {
    show(
      context,
      message: message,
      icon: const Icon(
        Icons.error_rounded,
        size: 18.0,
        color: AppTheme.error,
      ),
    );
  }
}
