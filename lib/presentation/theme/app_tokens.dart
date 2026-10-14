import 'package:flutter/material.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  // Surface Colors
  final Color background;
  final Color sidebar;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHighlight;
  final Color card;
  final Color cardHover;
  final Color glass;
  final Color accent;
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
  final double radiusSm; // 8
  final double radiusCard; // 8
  final double radiusMd; // 14
  final double radiusLg; // 20
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

  const AppTokens({
    this.background = const Color(0xFF121212),
    this.sidebar = const Color(0xFF000000),
    this.surface = const Color(0xFF121212),
    this.surfaceElevated = const Color(0xFF2A2A2A),
    this.surfaceHighlight = const Color(0xFF282828),
    this.card = const Color(0xFF181818),
    this.cardHover = const Color(0xFF282828),
    this.glass = const Color(0xCC181818),
    this.accent = const Color(0xFF1DB954),
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
  });

  /// Canonical Unified Token Spec (Content-First)
  static const AppTokens standardTokens = AppTokens();

  /// Aliases for platform symmetry
  static const AppTokens linuxTokens = standardTokens;
  static const AppTokens mobileStitchTokens = standardTokens;

  @override
  AppTokens copyWith({
    Color? background,
    Color? sidebar,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceHighlight,
    Color? card,
    Color? cardHover,
    Color? glass,
    Color? accent,
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
  }) {
    return AppTokens(
      background: background ?? this.background,
      sidebar: sidebar ?? this.sidebar,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      card: card ?? this.card,
      cardHover: cardHover ?? this.cardHover,
      glass: glass ?? this.glass,
      accent: accent ?? this.accent,
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
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      background: Color.lerp(background, other.background, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceHighlight: Color.lerp(surfaceHighlight, other.surfaceHighlight, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardHover: Color.lerp(cardHover, other.cardHover, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
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
      radiusSm: radiusSm,
      radiusCard: radiusCard,
      radiusMd: radiusMd,
      radiusLg: radiusLg,
      radiusXl: radiusXl,
      radiusFull: radiusFull,
      radiusPill: radiusPill,
      motionQuick: motionQuick,
      motionStandard: motionStandard,
      motionSmooth: motionSmooth,
      motionCinematic: motionCinematic,
      curveDecel: other.curveDecel,
      curveSpring: other.curveSpring,
    );
  }
}

extension AppTokensBuildContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.standardTokens;
}
