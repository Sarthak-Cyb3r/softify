import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'bouncing_scale_button.dart';

/// Smooth morphing play/pause button with bouncing micro-interaction and 60fps animation.
class PlayPauseMorphButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool showGlow;

  const PlayPauseMorphButton({
    super.key,
    required this.isPlaying,
    required this.onTap,
    this.size = 56.0,
    this.iconSize = 30.0,
    this.backgroundColor,
    this.iconColor,
    this.showGlow = false,
  });

  @override
  State<PlayPauseMorphButton> createState() => _PlayPauseMorphButtonState();
}

class _PlayPauseMorphButtonState extends State<PlayPauseMorphButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.isPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant PlayPauseMorphButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bg = widget.backgroundColor ?? tokens.textPrimary;
    final fg = widget.iconColor ?? tokens.background;

    return BouncingScaleButton(
      onTap: widget.onTap,
      scaleFactor: 0.95,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: widget.showGlow
              ? [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: _controller,
            size: widget.iconSize,
            color: fg,
          ),
        ),
      ),
    );
  }
}
