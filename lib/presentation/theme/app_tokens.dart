import 'package:flutter/material.dart';

import 'ui_style.dart';

export 'ui_style.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  // Style Identifier
  final UiStyle style;
  final bool isGlass;

  // Surface Colors
  final Color background;
  final Color sidebar;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHighlight;
  final Color card;
  final Color cardHover;
  final Color glass;
  final Color glassSurface;
  final Color glassBorder;
  final Color accent;
  final Color accentViolet;
  final Color accentCyan;
  final Color accentRose;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;
  final Color error;

  // Spacing (4/8pt Grid)
  final double spaceXs; // 4
  final double spaceSm; // 8
  final double spaceMd; // 16
  final double spaceLg; // 24
  final double spaceXl; // 32
  final double spaceXxl; // 48

  // Radii
  final double radiusSm; // 8 / 10
  final double radiusCard; // 8 / 20
  final double radiusMd; // 14 / 18
  final double radiusLg; // 20 / 24
  final double radiusXl; // 28
  final double radiusFull; // 999
  final double radiusPill; // 999

  // Motion
  final Duration motionQuick; // 150ms
  final Duration motionStandard; // 250ms
  final Duration motionSmooth; // 350ms
  final Duration motionCinematic; // 500ms
  final Curve curveDecel;
  final Curve curveSpring;

  // Soft Elevation Shadows
  final List<BoxShadow> cardShadow;

  const AppTokens({
    this.style = UiStyle.classic,
    this.isGlass = false,
    this.background = const Color(0xFF000000),
    this.sidebar = const Color(0xFF000000),
    this.surface = const Color(0xFF0B0C0E),
    this.surfaceElevated = const Color(0xFF1E2025),
    this.surfaceHighlight = const Color(0xFF25272E),
    this.card = const Color(0xFF16171B),
    this.cardHover = const Color(0xFF22242A),
    this.glass = const Color(0xCC16171B),
    this.glassSurface = const Color(0x1AFFFFFF),
    this.glassBorder = const Color(0x1FFFFFFF),
    this.accent = const Color(0xFFED5564), // Metrolist Coral Red
    this.accentViolet = const Color(0xFFB388FF),
    this.accentCyan = const Color(0xFF60A5FA),
    this.accentRose = const Color(0xFFED5564),
    this.textPrimary = const Color(0xFFE6E1E5),
    this.textSecondary = const Color(0xFF938F99),
    this.textMuted = const Color(0xFF5F5D66),
    this.divider = const Color(0x1FFFFFFF),
    this.error = const Color(0xFFFF5449),
    this.spaceXs = 4.0,
    this.spaceSm = 8.0,
    this.spaceMd = 16.0,
    this.spaceLg = 24.0,
    this.spaceXl = 32.0,
    this.spaceXxl = 48.0,
    this.radiusSm = 8.0,
    this.radiusCard = 8.0,
    this.radiusMd = 14.0,
    this.radiusLg = 20.0,
    this.radiusXl = 28.0,
    this.radiusFull = 999.0,
    this.radiusPill = 999.0,
    this.motionQuick = const Duration(milliseconds: 150),
    this.motionStandard = const Duration(milliseconds: 250),
    this.motionSmooth = const Duration(milliseconds: 350),
    this.motionCinematic = const Duration(milliseconds: 500),
    this.curveDecel = Curves.fastOutSlowIn,
    this.curveSpring = Curves.easeOutCubic,
    this.cardShadow = const [],
  });

  /// Canonical Classic Spotify-Inspired Token Spec (Default)
  static const AppTokens standardTokens = AppTokens();

  /// Aurora Glass Token Spec (Minimalist Editorial Frosted Glass)
  static const AppTokens auroraTokens = AppTokens(
    style: UiStyle.auroraGlass,
    isGlass: true,
    background: Color(0xFF0E0E11), // Deep warm obsidian charcoal
    sidebar: Color(0xFF0E0E11),
    surface: Color(0xFF16161A), // Quiet graphite surface
    surfaceElevated: Color(0xFF1C1C22),
    surfaceHighlight: Color(0xFF24242B),
    card: Color(0x0FFFFFFF), // 6.2% translucent white glass
    cardHover: Color(0x18FFFFFF), // 9.5% white glass hover
    glass: Color(0x0DFFFFFF), // 5% translucent white
    glassSurface: Color(0x12FFFFFF), // 7% translucent white surface
    glassBorder: Color(0x1AFFFFFF), // 10% crisp hairline border
    accent: Color(0xFFED5564), // Metrolist Coral Red
    accentViolet: Color(0xFFB388FF),
    accentCyan: Color(0xFF60A5FA),
    accentRose: Color(0xFFED5564),
    textPrimary: Color(0xFFF4F4F6),
    textSecondary: Color(0xFFA1A1AA), // Neutral zinc, meets WCAG AA & AAA
    textMuted: Color(0xFF71717A),
    divider: Color(0x14FFFFFF),
    error: Color(0xFFF87171),
    spaceXs: 4.0,
    spaceSm: 8.0,
    spaceMd: 16.0,
    spaceLg: 24.0,
    spaceXl: 32.0,
    spaceXxl: 48.0,
    radiusSm: 8.0,
    radiusCard: 14.0, // Architectural crisp card radius
    radiusMd: 12.0,
    radiusLg: 16.0,
    radiusXl: 20.0,
    radiusFull: 999.0,
    radiusPill: 999.0,
    motionQuick: Duration(milliseconds: 150),
    motionStandard: Duration(milliseconds: 250),
    motionSmooth: Duration(milliseconds: 300),
    motionCinematic: Duration(milliseconds: 300),
    curveDecel: Curves.easeOutCubic,
    curveSpring: Curves.easeOutCubic,
    cardShadow: [
      BoxShadow(
        color: Color(0x33000000),
        blurRadius: 16,
        spreadRadius: -2,
        offset: Offset(0, 4),
      ),
    ],
  );

  /// Aliases for platform symmetry
  static const AppTokens linuxTokens = standardTokens;
  static const AppTokens mobileStitchTokens = standardTokens;

  /// Generates dynamic tokens from a Material 3 [ColorScheme] (artwork-derived Monet palette).
  factory AppTokens.fromColorScheme(
    ColorScheme scheme, {
    UiStyle style = UiStyle.classic,
    bool pureBlack = false,
  }) {
    final bg = pureBlack ? Colors.black : scheme.surface;
    final surf = pureBlack ? Colors.black : scheme.surface;
    return AppTokens(
      style: style,
      isGlass: false,
      background: bg,
      sidebar: bg,
      surface: surf,
      surfaceElevated: scheme.surfaceContainerHigh,
      surfaceHighlight: scheme.surfaceContainerHighest,
      card: scheme.surfaceContainer,
      cardHover: scheme.surfaceContainerHigh,
      glass: scheme.surfaceContainer.withValues(alpha: 0.85),
      glassSurface: scheme.surfaceContainer.withValues(alpha: 0.5),
      glassBorder: scheme.outlineVariant.withValues(alpha: 0.25),
      accent: scheme.primary,
      accentRose: scheme.primary,
      accentCyan: scheme.tertiary,
      accentViolet: scheme.secondary,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      textMuted: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      divider: scheme.outlineVariant.withValues(alpha: 0.2),
      error: scheme.error,
      radiusSm: 8.0,
      radiusCard: 12.0,
      radiusMd: 16.0,
      radiusLg: 20.0,
      radiusXl: 28.0,
      radiusFull: 999.0,
      radiusPill: 999.0,
    );
  }

  @override
  AppTokens copyWith({
    UiStyle? style,
    bool? isGlass,
    Color? background,
    Color? sidebar,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceHighlight,
    Color? card,
    Color? cardHover,
    Color? glass,
    Color? glassSurface,
    Color? glassBorder,
    Color? accent,
    Color? accentViolet,
    Color? accentCyan,
    Color? accentRose,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    Color? error,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? spaceXxl,
    double? radiusSm,
    double? radiusCard,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusFull,
    double? radiusPill,
    Duration? motionQuick,
    Duration? motionStandard,
    Duration? motionSmooth,
    Duration? motionCinematic,
    Curve? curveDecel,
    Curve? curveSpring,
    List<BoxShadow>? cardShadow,
  }) {
    return AppTokens(
      style: style ?? this.style,
      isGlass: isGlass ?? this.isGlass,
      background: background ?? this.background,
      sidebar: sidebar ?? this.sidebar,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      card: card ?? this.card,
      cardHover: cardHover ?? this.cardHover,
      glass: glass ?? this.glass,
      glassSurface: glassSurface ?? this.glassSurface,
      glassBorder: glassBorder ?? this.glassBorder,
      accent: accent ?? this.accent,
      accentViolet: accentViolet ?? this.accentViolet,
      accentCyan: accentCyan ?? this.accentCyan,
      accentRose: accentRose ?? this.accentRose,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      error: error ?? this.error,
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      spaceXxl: spaceXxl ?? this.spaceXxl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusFull: radiusFull ?? this.radiusFull,
      radiusPill: radiusPill ?? this.radiusPill,
      motionQuick: motionQuick ?? this.motionQuick,
      motionStandard: motionStandard ?? this.motionStandard,
      motionSmooth: motionSmooth ?? this.motionSmooth,
      motionCinematic: motionCinematic ?? this.motionCinematic,
      curveDecel: curveDecel ?? this.curveDecel,
      curveSpring: curveSpring ?? this.curveSpring,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      style: t < 0.5 ? style : other.style,
      isGlass: t < 0.5 ? isGlass : other.isGlass,
      background: Color.lerp(background, other.background, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceHighlight: Color.lerp(surfaceHighlight, other.surfaceHighlight, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardHover: Color.lerp(cardHover, other.cardHover, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentViolet: Color.lerp(accentViolet, other.accentViolet, t)!,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t)!,
      accentRose: Color.lerp(accentRose, other.accentRose, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      error: Color.lerp(error, other.error, t)!,
      spaceXs: spaceXs,
      spaceSm: spaceSm,
      spaceMd: spaceMd,
      spaceLg: spaceLg,
      spaceXl: spaceXl,
      spaceXxl: spaceXxl,
      radiusSm: radiusSm + (other.radiusSm - radiusSm) * t,
      radiusCard: radiusCard + (other.radiusCard - radiusCard) * t,
      radiusMd: radiusMd + (other.radiusMd - radiusMd) * t,
      radiusLg: radiusLg + (other.radiusLg - radiusLg) * t,
      radiusXl: radiusXl + (other.radiusXl - radiusXl) * t,
      radiusFull: radiusFull,
      radiusPill: radiusPill,
      motionQuick: motionQuick,
      motionStandard: motionStandard,
      motionSmooth: motionSmooth,
      motionCinematic: motionCinematic,
      curveDecel: other.curveDecel,
      curveSpring: other.curveSpring,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

extension AppTokensBuildContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.standardTokens;
  bool get isGlass => tokens.isGlass;
}
