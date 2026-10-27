import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animated Waveform / Squiggly playback seek slider modeled after Android 13/14+ M3
/// with Softify's studio glassmorphism and glow touch.
///
/// Features:
/// - Continuous sinusoidal wave oscillation while audio is playing.
/// - Smooth animated flattening transition (`easeOutCubic`) when audio is paused.
/// - Tapered wave dampening near the scrubber thumb to prevent visual clipping.
/// - Integrated drag gestures with haptic feedback and glowing thumb.
class WavySlider extends StatefulWidget {
  final double value;
  final double max;
  final bool isPlaying;
  final bool enabled;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final double waveAmplitude;
  final double wavelength;
  final double trackHeight;
  final double thumbRadius;

  const WavySlider({
    super.key,
    required this.value,
    required this.max,
    this.isPlaying = true,
    this.enabled = true,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x33FFFFFF),
    this.thumbColor = Colors.white,
    this.waveAmplitude = 3.5,
    this.wavelength = 24.0,
    this.trackHeight = 3.5,
    this.thumbRadius = 6.0,
  });

  @override
  State<WavySlider> createState() => _WavySliderState();
}

class _WavySliderState extends State<WavySlider>
    with TickerProviderStateMixin {
  late AnimationController _phaseController;
  late AnimationController _amplitudeController;
  late Animation<double> _amplitudeAnimation;

  double? _dragValue;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Phase controller continuously shifts the wave horizontally while playing
    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Amplitude controller smoothly flattens or elevates the wave when play state toggles
    _amplitudeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _amplitudeAnimation = CurvedAnimation(
      parent: _amplitudeController,
      curve: Curves.easeOutCubic,
    );

    if (widget.isPlaying && widget.enabled) {
      _phaseController.repeat();
      _amplitudeController.value = 1.0;
    } else {
      _amplitudeController.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(covariant WavySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying || widget.enabled != oldWidget.enabled) {
      if (widget.isPlaying && widget.enabled) {
        if (!_phaseController.isAnimating) {
          _phaseController.repeat();
        }
        _amplitudeController.forward();
      } else {
        _amplitudeController.reverse().then((_) {
          if (!mounted) return;
          if (!widget.isPlaying) {
            _phaseController.stop();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _phaseController.dispose();
    _amplitudeController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details, BoxConstraints constraints) {
    if (!widget.enabled || widget.max <= 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isDragging = true;
      _updateDragValue(details.localPosition.dx, constraints.maxWidth);
    });
    widget.onChangeStart?.call(_dragValue!);
  }

  void _handleDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!widget.enabled || !_isDragging || widget.max <= 0) return;
    final oldValue = _dragValue;
    setState(() {
      _updateDragValue(details.localPosition.dx, constraints.maxWidth);
    });
    if (oldValue != null && _dragValue != null) {
      if ((_dragValue! ~/ 10) != (oldValue ~/ 10)) {
        HapticFeedback.selectionClick();
      }
    }
    widget.onChanged?.call(_dragValue!);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    HapticFeedback.mediumImpact();
    final finalValue = _dragValue ?? widget.value;
    setState(() {
      _isDragging = false;
      _dragValue = null;
    });
    widget.onChangeEnd?.call(finalValue);
  }

  void _updateDragValue(double localX, double width) {
    if (width <= 0) return;
    final ratio = (localX / width).clamp(0.0, 1.0);
    _dragValue = ratio * widget.max;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveValue = _dragValue ?? widget.value;
    final progress = widget.max > 0 ? (effectiveValue / widget.max).clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _handleDragStart(d, constraints),
          onHorizontalDragUpdate: (d) => _handleDragUpdate(d, constraints),
          onHorizontalDragEnd: _handleDragEnd,
          onHorizontalDragCancel: () {
            setState(() {
              _isDragging = false;
              _dragValue = null;
            });
          },
          onTapDown: (d) {
            if (!widget.enabled || widget.max <= 0) return;
            HapticFeedback.lightImpact();
            _updateDragValue(d.localPosition.dx, constraints.maxWidth);
            widget.onChangeStart?.call(_dragValue!);
            widget.onChanged?.call(_dragValue!);
            widget.onChangeEnd?.call(_dragValue!);
            setState(() {
              _dragValue = null;
            });
          },
          child: SizedBox(
            height: 36,
            width: constraints.maxWidth,
            child: AnimatedBuilder(
              animation: Listenable.merge([_phaseController, _amplitudeAnimation]),
              builder: (context, child) {
                return CustomPaint(
                  painter: _WavySliderPainter(
                    progress: progress,
                    phase: _phaseController.value * 2.0 * math.pi,
                    amplitude: widget.waveAmplitude * _amplitudeAnimation.value,
                    wavelength: widget.wavelength,
                    trackHeight: widget.trackHeight,
                    thumbRadius: _isDragging ? widget.thumbRadius * 1.3 : widget.thumbRadius,
                    activeColor: widget.activeColor,
                    inactiveColor: widget.inactiveColor,
                    thumbColor: widget.thumbColor,
                    isDragging: _isDragging,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _WavySliderPainter extends CustomPainter {
  final double progress;
  final double phase;
  final double amplitude;
  final double wavelength;
  final double trackHeight;
  final double thumbRadius;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final bool isDragging;

  _WavySliderPainter({
    required this.progress,
    required this.phase,
    required this.amplitude,
    required this.wavelength,
    required this.trackHeight,
    required this.thumbRadius,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2.0;
    final totalWidth = size.width;
    final activeWidth = (totalWidth * progress).clamp(0.0, totalWidth);

    // 1. Inactive Track (Unplayed future audio - flat line)
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (activeWidth < totalWidth) {
      canvas.drawLine(
        Offset(activeWidth, centerY),
        Offset(totalWidth, centerY),
        inactivePaint,
      );
    }

    // 2. Active Track (Played audio - sinusoidal wave or flat when paused)
    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (activeWidth > 0) {
      if (amplitude <= 0.05) {
        // Fast path: flat line when paused or amplitude zero
        canvas.drawLine(
          Offset(0, centerY),
          Offset(activeWidth, centerY),
          activePaint,
        );
      } else {
        // Wave path with taper near the thumb
        final wavePath = Path();
        wavePath.moveTo(0, centerY);

        const step = 2.0;
        final k = (2.0 * math.pi) / wavelength;
        final taperZone = math.min(32.0, activeWidth * 0.4);

        for (double x = 0; x <= activeWidth; x += step) {
          // Taper down wave amplitude smoothly as x approaches activeWidth
          double taper = 1.0;
          final distFromEnd = activeWidth - x;
          if (distFromEnd < taperZone && taperZone > 0) {
            taper = (distFromEnd / taperZone).clamp(0.0, 1.0);
          }

          final y = centerY + amplitude * taper * math.sin(x * k - phase);
          wavePath.lineTo(x, y);
        }

        // Ensure path connects directly to thumb center
        wavePath.lineTo(activeWidth, centerY);
        canvas.drawPath(wavePath, activePaint);
      }
    }

    // 3. Thumb with Glow and Shadow
    if (activeWidth >= 0 && activeWidth <= totalWidth) {
      final thumbCenter = Offset(activeWidth, centerY);

      // Outer soft glow bloom
      if (isDragging || amplitude > 0.5) {
        final glowPaint = Paint()
          ..color = activeColor.withValues(alpha: isDragging ? 0.45 : 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(thumbCenter, thumbRadius * 1.6, glowPaint);
      }

      // Drop shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(thumbCenter + const Offset(0, 1.5), thumbRadius, shadowPaint);

      // Solid thumb body
      final thumbPaint = Paint()
        ..color = thumbColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(thumbCenter, thumbRadius, thumbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavySliderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.thumbColor != thumbColor;
  }
}
