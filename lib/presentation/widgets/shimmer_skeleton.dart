import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Lightweight 60fps shimmer skeleton for loading cards and lists.
/// Wrapped in a [RepaintBoundary] to ensure zero frame drops on mid-range devices.
class ShimmerSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isCircle;

  const ShimmerSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.isCircle = false,
  });

  const ShimmerSkeleton.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null,
        isCircle = true;

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final shape = widget.isCircle ? BoxShape.circle : BoxShape.rectangle;
    final effectiveRadius = widget.isCircle
        ? null
        : (widget.borderRadius ?? BorderRadius.circular(tokens.radiusSm));

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: tokens.surfaceHighlight,
          shape: shape,
          borderRadius: effectiveRadius,
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: shape,
              borderRadius: effectiveRadius,
              gradient: LinearGradient(
                begin: Alignment(-2.0 + (progress * 4.0), -0.3),
                end: Alignment(0.0 + (progress * 4.0), 0.3),
                colors: [
                  tokens.surfaceElevated,
                  tokens.surfaceHighlight,
                  tokens.surfaceElevated,
                ],
                stops: const [0.1, 0.5, 0.9],
              ),
            ),
          );
        },
      ),
    );
  }
}
