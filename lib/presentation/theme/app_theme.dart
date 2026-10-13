import 'dart:io';
import 'package:flutter/material.dart';

import 'app_tokens.dart';

export 'app_tokens.dart';

class AppTheme {
  // Canonical Linux Desktop Colors (UNCHANGED)
  static const Color background = Color(0xFF121316);
  static const Color surface = Color(0xFF121316);
  static const Color surfaceElevated = Color(0xFF1F1F23);
  static const Color surfaceHighlight = Color(0xFF292A2D);
  static const Color surfaceContainerHighest = Color(0xFF343538);
  static const Color primary = Color(0xFF4EDEA3); // Emerald Mint
  static const Color primaryLight = Color(0xFF6FFBBE);
  static const Color primaryContainer = Color(0xFF10B981);
  static const Color textPrimary = Color(0xFFE3E2E6);
  static const Color textSecondary = Color(0xFFBBCABF);
  static const Color textMuted = Color(0xFF86948A);
  static const Color error = Color(0xFFFFB4AB);

  // Google Stitch Mobile Revamp Colors
  static const Color stitchBackground = Color(0xFF0D1417);
  static const Color stitchSurface = Color(0xFF0D1417);
  static const Color stitchSurfaceContainerLow = Color(0xFF161D1F);
  static const Color stitchSurfaceContainer = Color(0xFF1E2629);
  static const Color stitchSurfaceContainerHigh = Color(0xFF262E31);
  static const Color stitchSurfaceContainerHighest = Color(0xFF333A3D);
  static const Color stitchAmber = Color(0xFFF59E0B); // Warm Amber
  static const Color stitchAmberLight = Color(0xFFFBBF24);
  static const Color stitchAmberSubtle = Color(0x1FF59E0B);
  static const Color stitchTextPrimary = Color(0xFFF1F5F9);
  static const Color stitchTextSecondary = Color(0xFFCBD5E1);
  static const Color stitchTextMuted = Color(0xFF94A3B8);

  static ThemeData get darkTheme =>
      Platform.isLinux ? linuxDarkTheme : mobileDarkTheme;

  static ThemeData get linuxDarkTheme {
    const tokens = AppTokens.linuxTokens;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      extensions: const [tokens],
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryLight,
        surface: surface,
        error: error,
        onPrimary: Colors.black,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: textPrimary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: textPrimary,
        inactiveTrackColor: Color(0x33FFFFFF),
        thumbColor: textPrimary,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
        trackHeight: 2.5,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get mobileDarkTheme {
    const tokens = AppTokens.mobileStitchTokens;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: stitchBackground,
      extensions: const [tokens],
      colorScheme: const ColorScheme.dark(
        primary: stitchAmber,
        secondary: stitchAmberLight,
        surface: stitchSurface,
        error: error,
        onPrimary: Color(0xFF080F11),
        onSurface: stitchTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: stitchTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: stitchTextPrimary, size: 22),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: stitchAmber,
        unselectedItemColor: stitchTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: stitchAmber,
        inactiveTrackColor: Color(0x26FFFFFF),
        thumbColor: stitchAmber,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
        trackHeight: 2.5,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: stitchTextPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        displayMedium: TextStyle(
          color: stitchTextPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: stitchTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          color: stitchTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: stitchTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: stitchTextSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: stitchTextMuted,
          fontSize: 11,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
