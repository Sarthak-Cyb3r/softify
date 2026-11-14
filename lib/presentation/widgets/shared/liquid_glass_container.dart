import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ui_style_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';

/// Reusable Liquid Glass component reverse-engineered from SimpMusic / Apple design.
///
/// Features:
/// 1. Bounded lens refraction bevel (stays under minDimension / 4 to prevent medial seams).
/// 2. Directional 45° rim highlight (Kyant Highlight.Default style, directional lighting).
/// 3. Luminance-adaptive darkening scrim ("đục đen", prevents white washout on bright album art).
/// 4. Interactive liquid touch physics (spring damped bulge + pointer-following radial spotlight).
/// 5. Non-consuming pointer tracking so child gesture handlers continue functioning cleanly.
class LiquidGlassContainer extends ConsumerStatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final bool interactive;
  final double pressedScale;
  final double blurScale;
  final double minScrim;
  final double maxScrim;
  final double? customLuminance;
  final Color? tintColor;
  final bool withHighlight;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Clip clipBehavior;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.interactive = true,
    this.pressedScale = 1.08,
    this.blurScale = 1.0,
    this.minScrim = 0.12,
    this.maxScrim = 0.50,
    this.customLuminance,
    this.tintColor,
    this.withHighlight = true,
    this.onTap,
    this.onLongPress,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  ConsumerState<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends ConsumerState<LiquidGlassContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressCurve;
  Offset _touchPosition = Offset.zero;
  bool _isPointerDown = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _pressCurve = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.interactive) return;
    _isPointerDown = true;
    _touchPosition = event.localPosition;
    _pressController.forward();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!widget.interactive || !_isPointerDown) return;
    setState(() {
      _touchPosition = event.localPosition;
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!widget.interactive) return;
    _isPointerDown = false;
    _pressController.reverse();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!widget.interactive) return;
    _isPointerDown = false;
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isLiquidActive = ref.watch(isLiquidGlassActiveProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dynamicSeed = ref.watch(dynamicThemeColorProvider);
    final seedLuminance = dynamicSeed.computeLuminance();
    final effectiveLuminance = widget.customLuminance ??
        (tokens.isGlass ? seedLuminance : (isDark ? 0.25 : 0.75));

    final defaultRadius = widget.shape == BoxShape.circle
        ? BorderRadius.circular(9999)
        : (widget.borderRadius ?? BorderRadius.circular(tokens.radiusCard));

    // Fallback: If Liquid Glass is disabled or reduced, render standard clean flat/translucent surface
    if (!isLiquidActive) {
      Widget flat = Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: (widget.tintColor ?? (tokens.isGlass ? tokens.glassSurface : tokens.card))
              .withValues(alpha: tokens.isGlass ? 0.80 : 1.0),
          borderRadius: widget.shape == BoxShape.circle ? null : defaultRadius,
          shape: widget.shape,
          border: Border.all(
            color: tokens.isGlass ? tokens.glassBorder : Colors.transparent,
            width: 1.0,
          ),
          boxShadow: tokens.isGlass ? tokens.cardShadow : null,
        ),
        clipBehavior: widget.clipBehavior,
        child: widget.child,
      );

      if (widget.onTap != null || widget.onLongPress != null) {
        flat = GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          behavior: HitTestBehavior.opaque,
          child: flat,
        );
      }
      return flat;
    }

    // Liquid Glass Active Pipeline
    // Calculate dynamic blur from luminance curve
    final l = (effectiveLuminance * 2.0 - 1.0);
    final signedL = l.sign * (l * l);
    final baseBlur = signedL > 0.0
        ? (8.0 + (16.0 - 8.0) * signedL)
        : (8.0 + (2.0 - 8.0) * -signedL);

    final isConstrainedDesktop = Platform.isLinux || Platform.isWindows;

    return AnimatedBuilder(
      animation: _pressCurve,
      builder: (context, child) {
        final press = widget.interactive ? _pressCurve.value : 0.0;
        final scale = 1.0 + (widget.pressedScale - 1.0) * press;
        final effectiveBlur =
            (baseBlur * widget.blurScale + 2.0 * press).clamp(4.0, 24.0);

        Widget glassBody = CustomPaint(
          painter: _LiquidGlassPainter(
            pressProgress: press,
            touchPosition: _touchPosition,
            luminance: effectiveLuminance,
            minScrim: widget.minScrim,
            maxScrim: widget.maxScrim,
            isDark: isDark,
            borderRadius: defaultRadius,
            shape: widget.shape,
            withHighlight: widget.withHighlight,
            tintColor: widget.tintColor,
          ),
          child: Container(
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            child: widget.child,
          ),
        );

        if (!isConstrainedDesktop) {
          glassBody = BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: effectiveBlur,
              sigmaY: effectiveBlur,
            ),
            child: glassBody,
          );
        }

        Widget clippedSurface;
        if (widget.shape == BoxShape.circle) {
          clippedSurface = ClipOval(
            clipBehavior: widget.clipBehavior,
            child: glassBody,
          );
        } else {
          clippedSurface = ClipRRect(
            borderRadius: defaultRadius,
            clipBehavior: widget.clipBehavior,
            child: glassBody,
          );
        }

        Widget content = RepaintBoundary(
          child: Container(
            width: widget.width,
            height: widget.height,
            margin: widget.margin,
            decoration: BoxDecoration(
              shape: widget.shape,
              borderRadius: widget.shape == BoxShape.circle ? null : defaultRadius,
              boxShadow: tokens.cardShadow,
            ),
            child: clippedSurface,
          ),
        );

        if (widget.interactive) {
          content = Transform.scale(
            scale: scale,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              child: content,
            ),
          );
        }

        if (widget.onTap != null || widget.onLongPress != null) {
          content = GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            behavior: HitTestBehavior.opaque,
            child: content,
          );
        }

        return content;
      },
    );
  }
}

/// Custom painter executing multi-stage optical rendering:
/// 1. Luminance-adaptive darkening scrim ("đục đen")
/// 2. Bounded lens refraction bevel (no medial axis seam)
/// 3. Directional 45° rim highlight (Kyant Highlight.Default)
/// 4. Pointer-following radial spotlight (BlendMode.plus)
class _LiquidGlassPainter extends CustomPainter {
  final double pressProgress;
  final Offset touchPosition;
  final double luminance;
  final double minScrim;
  final double maxScrim;
  final bool isDark;
  final BorderRadius borderRadius;
  final BoxShape shape;
  final bool withHighlight;
  final Color? tintColor;

  _LiquidGlassPainter({
    required this.pressProgress,
    required this.touchPosition,
    required this.luminance,
    required this.minScrim,
    required this.maxScrim,
    required this.isDark,
    required this.borderRadius,
    required this.shape,
    required this.withHighlight,
    this.tintColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = shape == BoxShape.circle
        ? RRect.fromRectXY(rect, size.width / 2.0, size.height / 2.0)
        : borderRadius.toRRect(rect);
    final minDim = size.shortestSide;

    // 1. Luminance-adaptive darkening scrim ("đục đen")
    final darken = (minScrim +
            (maxScrim - minScrim) *
                ((luminance - 0.3) / 0.5).clamp(0.0, 1.0))
        .clamp(0.06, 0.18);

    final scrimColor = (isDark ? Colors.black : Colors.white)
        .withValues(alpha: darken);
    final scrimPaint = Paint()
      ..color = scrimColor
      ..style = PaintingStyle.fill;

    if (shape == BoxShape.circle) {
      canvas.drawCircle(rect.center, minDim / 2.0, scrimPaint);
    } else {
      canvas.drawRRect(rrect, scrimPaint);
    }

    // Optional subtle accent/brand tint
    if (tintColor != null) {
      final tintPaint = Paint()
        ..color = tintColor!.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      if (shape == BoxShape.circle) {
        canvas.drawCircle(rect.center, minDim / 2.0, tintPaint);
      } else {
        canvas.drawRRect(rrect, tintPaint);
      }
    }

    // 2. Optical Specular Surface Gradient (Smooth, no square inner cuts)
    final specularGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: 0.12 + 0.04 * pressProgress),
        Colors.white.withValues(alpha: 0.02),
        Colors.transparent,
      ],
      stops: const [0.0, 0.40, 1.0],
    );

    final specularPaint = Paint()
      ..shader = specularGradient.createShader(rect)
      ..style = PaintingStyle.fill;

    if (shape == BoxShape.circle) {
      canvas.drawCircle(rect.center, minDim / 2.0, specularPaint);
    } else {
      canvas.drawRRect(rrect, specularPaint);
    }

    // 3. Directional 45° Rim Highlight (Kyant Highlight.Default)
    if (withHighlight) {
      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x73FFFFFF), // 45% white at top-left
            Color(0x26FFFFFF), // 15% white at mid
            Color(0x0AFFFFFF), // 4% white at bottom-right
          ],
          stops: [0.0, 0.45, 1.0],
        ).createShader(rect);

      if (shape == BoxShape.circle) {
        canvas.drawCircle(rect.center, (minDim / 2.0) - 0.5, rimPaint);
      } else {
        canvas.drawRRect(rrect.deflate(0.5), rimPaint);
      }
    }

    // 4. Interactive Radial Touch Spotlight
    if (pressProgress > 0.001) {
      final center = touchPosition == Offset.zero ? rect.center : touchPosition;
      final spotRadius = minDim * 1.25;

      final radialPaint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: Alignment(
            ((center.dx / size.width) * 2.0 - 1.0).clamp(-1.0, 1.0),
            ((center.dy / size.height) * 2.0 - 1.0).clamp(-1.0, 1.0),
          ),
          radius: spotRadius / minDim,
          colors: [
            Colors.white.withValues(alpha: 0.18 * pressProgress),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: spotRadius));

      canvas.save();
      if (shape == BoxShape.circle) {
        canvas.clipPath(Path()..addOval(rect));
      } else {
        canvas.clipRRect(rrect);
      }
      canvas.drawRect(rect, radialPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassPainter oldDelegate) {
    return oldDelegate.pressProgress != pressProgress ||
        oldDelegate.touchPosition != touchPosition ||
        oldDelegate.luminance != luminance ||
        oldDelegate.isDark != isDark ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.shape != shape ||
        oldDelegate.withHighlight != withHighlight ||
        oldDelegate.tintColor != tintColor;
  }
}

/// Convenience circular Liquid Glass Icon Button matching SimpMusic's LiquidGlassIconButton.
class LiquidGlassIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final Color? tintColor;
  final bool interactive;

  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44.0,
    this.tooltip,
    this.tintColor,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = LiquidGlassContainer(
      width: size,
      height: size,
      shape: BoxShape.circle,
      interactive: interactive,
      pressedScale: 1.12,
      tintColor: tintColor,
      onTap: onTap,
      child: Center(child: icon),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
