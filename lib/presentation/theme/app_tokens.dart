import 'package:flutter/material.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  // Colors
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHighlight;
  final Color glass;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;

  // Spacing (4/8pt Grid)
  final double spaceXs; // 4
  final double spaceSm; // 8
  final double spaceMd; // 16
  final double spaceLg; // 24
  final double spaceXl; // 32
  final double spaceXxl; // 48

  // Radii
  final double radiusSm; // 8
  final double radiusMd; // 14
  final double radiusLg; // 20
  final double radiusXl; // 28
  final double radiusFull; // 999

  // Motion
  final Duration motionQuick; // 150ms
  final Duration motionStandard; // 250ms
  final Duration motionSmooth; // 350ms
  final Duration motionCinematic; // 500ms
  final Curve curveDecel;
  final Curve curveSpring;

  const AppTokens({
    this.background = const Color(0xFF121316),
    this.surface = const Color(0xFF121316),
    this.surfaceElevated = const Color(0xFF1F1F23),
    this.surfaceHighlight = const Color(0xFF292A2D),
    this.glass = const Color(0xCC141414),
    this.accent = const Color(0xFF4EDEA3),
    this.textPrimary = const Color(0xFFFFFFFF),
    this.textSecondary = const Color(0xFFBBCABF),
    this.textMuted = const Color(0xFF86948A),
    this.divider = const Color(0xFF292A2D),
    this.spaceXs = 4.0,
    this.spaceSm = 8.0,
    this.spaceMd = 16.0,
    this.spaceLg = 24.0,
    this.spaceXl = 32.0,
    this.spaceXxl = 48.0,
    this.radiusSm = 8.0,
    this.radiusMd = 14.0,
    this.radiusLg = 20.0,
    this.radiusXl = 28.0,
    this.radiusFull = 999.0,
    this.motionQuick = const Duration(milliseconds: 150),
    this.motionStandard = const Duration(milliseconds: 250),
    this.motionSmooth = const Duration(milliseconds: 350),
    this.motionCinematic = const Duration(milliseconds: 500),
    this.curveDecel = Curves.fastOutSlowIn,
    this.curveSpring = Curves.easeOutCubic,
  });

  @override
  AppTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceHighlight,
    Color? glass,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? spaceXxl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusFull,
    Duration? motionQuick,
    Duration? motionStandard,
    Duration? motionSmooth,
    Duration? motionCinematic,
    Curve? curveDecel,
    Curve? curveSpring,
  }) {
    return AppTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      glass: glass ?? this.glass,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      spaceXxl: spaceXxl ?? this.spaceXxl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusFull: radiusFull ?? this.radiusFull,
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
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceHighlight: Color.lerp(surfaceHighlight, other.surfaceHighlight, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      spaceXs: spaceXs,
      spaceSm: spaceSm,
      spaceMd: spaceMd,
      spaceLg: spaceLg,
      spaceXl: spaceXl,
      spaceXxl: spaceXxl,
      radiusSm: radiusSm,
      radiusMd: radiusMd,
      radiusLg: radiusLg,
      radiusXl: radiusXl,
      radiusFull: radiusFull,
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
      Theme.of(this).extension<AppTokens>() ?? const AppTokens();
}
