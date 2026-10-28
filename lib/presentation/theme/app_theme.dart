import 'package:flutter/material.dart';

import 'app_tokens.dart';

export 'app_tokens.dart';

class AppTheme {
  // Canonical Metrolist Material 3 Expressive & AMOLED Token Palette
  static const Color background = Color(0xFF000000);
  static const Color sidebar = Color(0xFF000000);
  static const Color surface = Color(0xFF0B0C0E);
  static const Color card = Color(0xFF16171B);
  static const Color cardHover = Color(0xFF22242A);
  static const Color surfaceElevated = Color(0xFF1E2025);
  static const Color surfaceHighlight = Color(0xFF25272E);
  static const Color surfaceContainerHighest = Color(0xFF2A2C34);
  
  // Metrolist Signature Coral Red / Rose Accent
  static const Color accent = Color(0xFFED5564); // Metrolist Primary Brand
  static const Color primary = Color(0xFFED5564);
  static const Color primaryLight = Color(0xFFFF8592);
  static const Color primaryContainer = Color(0xFF3E181D);
  static const Color error = Color(0xFFFF5449);

  // Typography Contrast
  static const Color textPrimary = Color(0xFFE6E1E5);
  static const Color textSecondary = Color(0xFF938F99);
  static const Color textMuted = Color(0xFF5F5D66);

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
  static const Color stitchAmberSubtle = Color(0x1FED5564);
  static const Color stitchTextPrimary = textPrimary;
  static const Color stitchTextSecondary = textSecondary;
  static const Color stitchTextMuted = textMuted;

  /// Retrieves the ThemeData corresponding to the active [UiStyle].
  static ThemeData themeFor(UiStyle style) {
    switch (style) {
      case UiStyle.classic:
        return unifiedDarkTheme;
      case UiStyle.auroraGlass:
        return auroraDarkTheme;
    }
  }

  /// Single Unified Dark ThemeData for Linux, Android & iOS (Classic)
  static ThemeData get darkTheme => unifiedDarkTheme;
  static ThemeData get linuxDarkTheme => unifiedDarkTheme;
  static ThemeData get mobileDarkTheme => unifiedDarkTheme;

  /// Builds dynamic Metrolist ThemeData matching Material You Monet TonalSpot.
  static ThemeData buildMetrolistTheme({
    Color? seedColor,
    bool pureBlack = false,
  }) {
    final effectiveSeed = seedColor ?? accent;
    final scheme = ColorScheme.fromSeed(
      seedColor: effectiveSeed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    final finalScheme = pureBlack
        ? scheme.copyWith(
            surface: Colors.black,
          )
        : scheme;

    final dynamicTokens = AppTokens.fromColorScheme(finalScheme, pureBlack: pureBlack);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: pureBlack ? Colors.black : finalScheme.surface,
      fontFamily: fontUi,
      extensions: [dynamicTokens],
      colorScheme: finalScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontPageTitle,
          color: finalScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: finalScheme.onSurface, size: 22),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pureBlack ? Colors.black : finalScheme.surface,
        indicatorColor: finalScheme.primaryContainer,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: finalScheme.onPrimaryContainer, size: 24);
          }
          return IconThemeData(color: finalScheme.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: finalScheme.onSurface,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: finalScheme.onSurfaceVariant,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: pureBlack ? Colors.black : finalScheme.surface,
        selectedItemColor: finalScheme.primary,
        unselectedItemColor: finalScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontFamily: fontUi,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontUi,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: finalScheme.primary,
        inactiveTrackColor: finalScheme.surfaceContainerHighest,
        thumbColor: finalScheme.primary,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        trackHeight: 6.0,
      ),
      cardTheme: CardThemeData(
        color: finalScheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: finalScheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: finalScheme.surfaceContainerHigh,
        modalBackgroundColor: finalScheme.surfaceContainerHigh,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return finalScheme.onPrimary;
          }
          return finalScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return finalScheme.primary;
          }
          return finalScheme.surfaceContainerHighest;
        }),
      ),
    );
  }

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
          side: const BorderSide(color: Color(0x14FFFFFF), width: 1.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: const BorderSide(color: Color(0x1FFFFFFF), width: 1.0),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceElevated,
        modalBackgroundColor: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
          side: BorderSide(color: Color(0x1FFFFFFF), width: 1.0),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x1FFFFFFF),
        thickness: 1.0,
        space: 1.0,
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

  /// Aurora Glass Dark ThemeData (Minimalist Editorial Frosted Glass)
  static ThemeData get auroraDarkTheme {
    const tokens = AppTokens.auroraTokens;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: tokens.background,
      fontFamily: fontUi,
      extensions: const [tokens],
      colorScheme: ColorScheme.dark(
        primary: tokens.accent,
        onPrimary: Colors.black,
        primaryContainer: tokens.surfaceElevated,
        onPrimaryContainer: tokens.textPrimary,
        secondary: tokens.accentCyan,
        onSecondary: Colors.black,
        tertiary: tokens.accentRose,
        onTertiary: Colors.white,
        surface: tokens.surface,
        onSurface: tokens.textPrimary,
        error: tokens.error,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontPageTitle,
          color: tokens.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: tokens.textPrimary, size: 22),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.background,
        selectedItemColor: tokens.accentCyan,
        unselectedItemColor: tokens.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontFamily: fontUi,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontUi,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: tokens.accentCyan,
        inactiveTrackColor: const Color(0x1FFFFFFF),
        thumbColor: tokens.accentCyan,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        trackHeight: 2.5,
      ),
      cardTheme: CardThemeData(
        color: tokens.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          side: BorderSide(color: tokens.glassBorder, width: 1.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceElevated,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          side: const BorderSide(color: Color(0x2EFFFFFF), width: 1.0),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        modalBackgroundColor: tokens.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusXl)),
          side: const BorderSide(color: Color(0x2EFFFFFF), width: 1.0),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.glassSurface,
        selectedColor: tokens.accentViolet,
        disabledColor: tokens.glassSurface,
        labelStyle: TextStyle(
          fontFamily: fontUi,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontUi,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusFull),
          side: const BorderSide(color: Color(0x2EFFFFFF), width: 1.0),
        ),
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
        size: 22,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x26FFFFFF),
        thickness: 0.8,
        space: 1,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: fontDisplay,
          color: tokens.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontFamily: fontDisplay,
          color: tokens.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        displaySmall: TextStyle(
          fontFamily: fontDisplay,
          color: tokens.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontUi,
          color: tokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontFamily: fontUi,
          color: tokens.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontFamily: fontUi,
          color: tokens.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        titleSmall: TextStyle(
          fontFamily: fontUi,
          color: tokens.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontUi,
          color: tokens.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontUi,
          color: tokens.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          fontFamily: fontUi,
          color: tokens.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          fontFamily: fontUi,
          color: tokens.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          fontFamily: fontUi,
          color: tokens.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          fontFamily: fontUi,
          color: tokens.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
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
