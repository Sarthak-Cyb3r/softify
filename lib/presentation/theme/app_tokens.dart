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
    this.background = const Color(0xFF121212),
    this.sidebar = const Color(0xFF000000),
    this.surface = const Color(0xFF121212),
    this.surfaceElevated = const Color(0xFF2A2A2A),
    this.surfaceHighlight = const Color(0xFF282828),
    this.card = const Color(0xFF181818),
    this.cardHover = const Color(0xFF282828),
    this.glass = const Color(0xCC181818),
    this.glassSurface = const Color(0x1AFFFFFF),
    this.glassBorder = const Color(0x1FFFFFFF),
    this.accent = const Color(0xFF1DB954),
    this.accentViolet = const Color(0xFF7C5CFF),
    this.accentCyan = const Color(0xFF4FD1FF),
    this.accentRose = const Color(0xFFFF7AC6),
    this.textPrimary = const Color(0xFFFFFFFF),
    this.textSecondary = const Color(0xFFB3B3B3),
    this.textMuted = const Color(0xFF6A6A6A),
    this.divider = const Color(0xFF282828),
    this.error = const Color(0xFFF15E6C),
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

  /// Aurora Glass Token Spec (Deep Midnight Frosted Glassmorphism)
  static const AppTokens auroraTokens = AppTokens(
    style: UiStyle.auroraGlass,
    isGlass: true,
    background: Color(0xFF0B0B1A), // Deep midnight #0B0B1A
    sidebar: Color(0xFF0B0B1A),
    surface: Color(0xFF14122B),
    surfaceElevated: Color(0xFF1B163B),
    surfaceHighlight: Color(0xFF261F4D),
    card: Color(0x22FFFFFF), // 13.5% translucent white glass
    cardHover: Color(0x35FFFFFF), // 21% white glass hover
    glass: Color(0x24FFFFFF), // 14% translucent white
    glassSurface: Color(0x22FFFFFF), // 13.5% white glass surface
    glassBorder: Color(0x3DFFFFFF), // 24% specular white border
    accent: Color(0xFF7C5CFF), // Aurora violet
    accentViolet: Color(0xFF7C5CFF),
    accentCyan: Color(0xFF4FD1FF), // Cyan #4FD1FF
    accentRose: Color(0xFFFF7AC6), // Rose #FF7AC6
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFC4C2E2), // Soft silvery lilac, meets WCAG AA 4.5:1+
    textMuted: Color(0xFF7E7B9D),
    divider: Color(0x2EFFFFFF),
    error: Color(0xFFFF5C7A),
    spaceXs: 4.0,
    spaceSm: 8.0,
    spaceMd: 16.0,
    spaceLg: 24.0,
    spaceXl: 32.0,
    spaceXxl: 48.0,
    radiusSm: 10.0,
    radiusCard: 22.0, // 20-28 glass card radius
    radiusMd: 18.0,
    radiusLg: 24.0,
    radiusXl: 28.0,
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
        color: Color(0x40000000),
        blurRadius: 22,
        spreadRadius: -2,
        offset: Offset(0, 8),
      ),
      BoxShadow(
        color: Color(0x1F7C5CFF), // Radiant aurora violet ambient bloom
        blurRadius: 26,
        spreadRadius: -4,
        offset: Offset(0, 4),
      ),
    ],
  );

  /// Aliases for platform symmetry
  static const AppTokens linuxTokens = standardTokens;
  static const AppTokens mobileStitchTokens = standardTokens;

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
