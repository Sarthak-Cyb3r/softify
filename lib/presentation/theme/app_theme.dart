import 'package:flutter/material.dart';

import 'app_tokens.dart';

export 'app_tokens.dart';

class AppTheme {
  static const Color background = Color(0xFF0A0A0A); // Cinematic near-black
  static const Color surface = Color(0xFF121212);
  static const Color surfaceElevated = Color(0xFF181818);
  static const Color surfaceHighlight = Color(0xFF222222);
  static const Color primary = Color(0xFF1DB954); // Restrained Accent Green
  static const Color primaryLight = Color(0xFF1ED760);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA3A3A3);
  static const Color textMuted = Color(0xFF525252);
  static const Color error = Color(0xFFE91429);

  static ThemeData get darkTheme {
    const tokens = AppTokens();

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
}
