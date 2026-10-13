import 'package:flutter/material.dart';

import 'app_tokens.dart';

export 'app_tokens.dart';

class AppTheme {
  // Canonical Content-First Token Palette
  static const Color background = Color(0xFF121212);
  static const Color sidebar = Color(0xFF000000);
  static const Color surface = Color(0xFF121212);
  static const Color card = Color(0xFF181818);
  static const Color cardHover = Color(0xFF282828);
  static const Color surfaceElevated = Color(0xFF2A2A2A);
  static const Color surfaceHighlight = Color(0xFF282828);
  static const Color surfaceContainerHighest = Color(0xFF2A2A2A);
  
  // Single Accent & Destructive
  static const Color accent = Color(0xFF2EE66B); // ONE accent green
  static const Color primary = Color(0xFF2EE66B);
  static const Color primaryLight = Color(0xFF5CF08F);
  static const Color primaryContainer = Color(0xFF2EE66B);
  static const Color error = Color(0xFFF15E6C);

  // Typography Contrast
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF6A6A6A);

  // Bundled OFL Font Families
  static const String fontUi = 'Manrope';
  static const String fontPageTitle = 'BricolageGrotesque';
  static const String fontDisplay = 'BricolageGrotesque';
  static const String fontEditorial = 'InstrumentSerif';

  // Backward-compatibility aliases
  static const Color stitchBackground = background;
  static const Color stitchSurface = surface;
  static const Color stitchSurfaceContainerLow = card;
  static const Color stitchSurfaceContainer = cardHover;
  static const Color stitchSurfaceContainerHigh = surfaceElevated;
  static const Color stitchSurfaceContainerHighest = surfaceElevated;
  static const Color stitchAmber = accent;
  static const Color stitchAmberLight = primaryLight;
  static const Color stitchAmberSubtle = Color(0x1F2EE66B);
  static const Color stitchTextPrimary = textPrimary;
  static const Color stitchTextSecondary = textSecondary;
  static const Color stitchTextMuted = textMuted;

  /// Single Unified Dark ThemeData for Linux, Android & iOS
  static ThemeData get darkTheme => unifiedDarkTheme;
  static ThemeData get linuxDarkTheme => unifiedDarkTheme;
  static ThemeData get mobileDarkTheme => unifiedDarkTheme;

  static ThemeData get unifiedDarkTheme {
    const tokens = AppTokens.standardTokens;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      fontFamily: fontUi,
      extensions: const [tokens],
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.black,
        primaryContainer: accent,
        onPrimaryContainer: Colors.black,
        secondary: textSecondary,
        onSecondary: Colors.black,
        surface: card,
        onSurface: textPrimary,
        error: error,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontPageTitle,
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: sidebar,
        selectedItemColor: textPrimary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: fontUi,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontUi,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: Color(0x33FFFFFF),
        thumbColor: accent,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
        trackHeight: 3.0,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceElevated,
        modalBackgroundColor: surfaceElevated,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: card,
        selectedColor: accent,
        disabledColor: card,
        labelStyle: TextStyle(
          fontFamily: fontUi,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: fontUi,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        shape: StadiumBorder(),
        side: BorderSide.none,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: fontPageTitle,
          color: textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        displayMedium: TextStyle(
          fontFamily: fontPageTitle,
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        displaySmall: TextStyle(
          fontFamily: fontPageTitle,
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineLarge: TextStyle(
          fontFamily: fontUi,
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontUi,
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          fontFamily: fontUi,
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontFamily: fontUi,
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          fontFamily: fontUi,
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          fontFamily: fontUi,
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontUi,
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontUi,
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          fontFamily: fontUi,
          color: textMuted,
          fontSize: 12, // Strict 12px floor
          fontWeight: FontWeight.w400,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        labelLarge: TextStyle(
          fontFamily: fontUi,
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          fontFamily: fontUi,
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          fontFamily: fontUi,
          color: textMuted,
          fontSize: 12, // Strict 12px floor
          fontWeight: FontWeight.w500,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Page Title typography with Bricolage Grotesque
  static TextStyle pageTitle({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double letterSpacing = -0.4,
  }) {
    return TextStyle(
      fontFamily: fontPageTitle,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Editorial typography with Instrument Serif (Italic) for lyrics & Wrapped
  static TextStyle editorial({
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textPrimary,
    FontStyle fontStyle = FontStyle.italic,
    double height = 1.3,
  }) {
    return TextStyle(
      fontFamily: fontEditorial,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
    );
  }

  /// Monospaced tabular numeral helper using Manrope with tabular figures (no monospace fonts)
  static TextStyle tabularTimestamp({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color color = textMuted,
  }) {
    return TextStyle(
      fontFamily: fontUi,
      fontSize: fontSize < 12 ? 12 : fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
