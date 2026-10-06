import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BouncingScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final Duration duration;
  final double minTouchTarget;

  const BouncingScaleButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    double? scaleFactor,
    double scaleDown = 0.97,
    this.duration = const Duration(milliseconds: 140),
    this.minTouchTarget = 48.0,
  }) : scaleDown = scaleFactor ?? scaleDown;

  @override
  State<BouncingScaleButton> createState() => _BouncingScaleButtonState();
}

class _BouncingScaleButtonState extends State<BouncingScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.forward();
    HapticFeedback.selectionClick();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: reduceMotion ? null : _onTapDown,
      onTapUp: reduceMotion ? null : _onTapUp,
      onTapCancel: reduceMotion ? null : _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: widget.child,
    );

    if (!reduceMotion) {
      content = ScaleTransition(
        scale: _scaleAnimation,
        child: content,
      );
    }

    if (widget.minTouchTarget > 0) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minTouchTarget,
          minHeight: widget.minTouchTarget,
        ),
        child: Center(child: content),
      );
    }

    return content;
  }
}
