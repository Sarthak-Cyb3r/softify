import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Lightweight, 60fps kinetic animated equalizer wave indicator with 4 oscillating bars.
/// Used in queue, mini player, and now-playing track rows across mobile and desktop.
class AnimatedMusicWaveIndicator extends StatefulWidget {
  final bool isPlaying;
  final Color? color;
  final double size;
  final int barCount;

  const AnimatedMusicWaveIndicator({
    super.key,
    required this.isPlaying,
    this.color,
    this.size = 18.0,
    this.barCount = 4,
  });

  @override
  State<AnimatedMusicWaveIndicator> createState() =>
      _AnimatedMusicWaveIndicatorState();
}

class _AnimatedMusicWaveIndicatorState extends State<AnimatedMusicWaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedMusicWaveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }
      } else {
        _controller.stop();
        _controller.animateTo(0.2,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic);
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
    final effectiveColor = widget.color ?? context.tokens.accent;

    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _MusicWavePainter(
          animationValue: _controller,
          isPlaying: widget.isPlaying,
          color: effectiveColor,
          barCount: widget.barCount,
        ),
      ),
    );
  }
}

class _MusicWavePainter extends CustomPainter {
  final Animation<double> animationValue;
  final bool isPlaying;
  final Color color;
  final int barCount;

  _MusicWavePainter({
    required this.animationValue,
    required this.isPlaying,
    required this.color,
    required this.barCount,
  }) : super(repaint: animationValue);

  static const List<double> _phaseMultipliers = [0.9, 1.4, 0.7, 1.2, 0.8];
  static const List<double> _baseOffsets = [0.15, 0.45, 0.05, 0.65, 0.25];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final count = barCount.clamp(3, 5);
    final totalSpacing = size.width * 0.35;
    final gap = totalSpacing / (count - 1);
    final barWidth = (size.width - totalSpacing) / count;

    final t = isPlaying ? animationValue.value : 0.25;

    for (int i = 0; i < count; i++) {
      final phase = _baseOffsets[i % _baseOffsets.length];
      final speed = _phaseMultipliers[i % _phaseMultipliers.length];

      // Oscillate between min 0.18 and max 0.95
      double heightRatio;
      if (isPlaying) {
        final localT = (t * speed + phase) % 1.0;
        final wave = (localT < 0.5) ? (localT * 2.0) : ((1.0 - localT) * 2.0);
        heightRatio = 0.20 + (wave * 0.75);
      } else {
        heightRatio = 0.25;
      }

      final barHeight = (size.height * heightRatio).clamp(size.height * 0.18, size.height);
      final x = i * (barWidth + gap);
      final y = size.height - barHeight;

      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MusicWavePainter oldDelegate) {
    return oldDelegate.isPlaying != isPlaying ||
        oldDelegate.color != color ||
        oldDelegate.barCount != barCount;
  }
}
