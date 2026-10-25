import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../providers/ui_style_provider.dart';

/// Versatile surface widget that renders authentic solid surfaces in Classic style
/// and high-performance frosted glassmorphism in Aurora Glass style.
///
/// To preserve 60fps on low-to-mid tier devices (e.g. Moto G34 5G):
/// - [withBlur] should ONLY be true for static top-level chrome (MiniPlayer, NavBar, Sheets).
/// - [withBlur] must be false for scrolling list tiles, grid cards, and chips.
/// - When [shouldReduceEffectsProvider] is true, blur is seamlessly bypassed for solid fills.
class AppSurface extends ConsumerWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Border? border;
  final Color? color;
  final List<BoxShadow>? boxShadow;
  final bool withBlur;
  final double blurSigma;
  final Clip clipBehavior;

  const AppSurface({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border,
    this.color,
    this.boxShadow,
    this.withBlur = true,
    this.blurSigma = 16.0,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final radius = borderRadius ?? BorderRadius.circular(tokens.radiusCard);
    final reduceEffects = ref.watch(shouldReduceEffectsProvider);

    if (!tokens.isGlass) {
      // Classic Solid Theme
      return Container(
        width: width,
        height: height,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? tokens.card,
          borderRadius: radius,
          border: border,
          boxShadow: boxShadow,
        ),
        clipBehavior: clipBehavior,
        child: child,
      );
    }

    // Aurora Glass Theme
    final effectiveBorder = border ??
        Border.all(
          color: tokens.glassBorder,
          width: 1.0,
        );

    final effectiveShadow = boxShadow ?? tokens.cardShadow;

    // Use BackdropFilter when hardware allows (bypass on Linux/Windows where Skia readback causes GPU compositor stalls)
    final isConstrainedDesktop = Platform.isLinux || Platform.isWindows;
    final canBlur = withBlur && !reduceEffects && !isConstrainedDesktop;

    if (canBlur) {
      return RepaintBoundary(
        child: Container(
          width: width,
          height: height,
          margin: margin,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: effectiveShadow,
          ),
          child: ClipRRect(
            borderRadius: radius,
            clipBehavior: clipBehavior,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma.clamp(8.0, 24.0),
                sigmaY: blurSigma.clamp(8.0, 24.0),
              ),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (color ?? Colors.white).withValues(alpha: 0.18),
                      (color ?? Colors.white).withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: radius,
                  border: effectiveBorder,
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    // Specular Translucent Fill when blur is reduced/bypassed
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (color ?? Colors.white).withValues(alpha: 0.20),
            (color ?? Colors.white).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: radius,
        border: effectiveBorder,
        boxShadow: effectiveShadow,
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Tappable card wrapper around [AppSurface].
class AppGlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Border? border;
  final Color? color;
  final List<BoxShadow>? boxShadow;
  final bool withBlur;
  final double blurSigma;

  const AppGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border,
    this.color,
    this.boxShadow,
    this.withBlur = true,
    this.blurSigma = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = borderRadius ?? BorderRadius.circular(tokens.radiusCard);

    Widget content = AppSurface(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      borderRadius: radius,
      border: border,
      color: color,
      boxShadow: boxShadow,
      withBlur: withBlur,
      blurSigma: blurSigma,
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius,
          splashColor: tokens.isGlass
              ? tokens.accentCyan.withValues(alpha: 0.15)
              : tokens.accent.withValues(alpha: 0.12),
          highlightColor: tokens.isGlass
              ? tokens.accentViolet.withValues(alpha: 0.10)
              : tokens.surfaceElevated.withValues(alpha: 0.20),
          child: content,
        ),
      );
    }

    return content;
  }
}
