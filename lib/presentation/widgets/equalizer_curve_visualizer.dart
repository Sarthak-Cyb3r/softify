// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EqualizerCurveVisualizer extends StatelessWidget {
  final List<double> bandGains;
  final List<double> bandFrequencies;
  final double bassBoost;
  final bool isEnabled;
  final bool isBypassed;
  final double minDecibels;
  final double maxDecibels;

  const EqualizerCurveVisualizer({
    super.key,
    required this.bandGains,
    required this.bandFrequencies,
    required this.bassBoost,
    required this.isEnabled,
    required this.isBypassed,
    this.minDecibels = -12.0,
    this.maxDecibels = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isEnabled && !isBypassed)
              ? AppTheme.primary.withOpacity(0.25)
              : AppTheme.surfaceHighlight,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _SplineCurvePainter(
              bandGains: bandGains,
              bandFrequencies: bandFrequencies,
              bassBoost: bassBoost,
              isActive: isEnabled && !isBypassed,
              minDb: minDecibels,
              maxDb: maxDecibels,
            ),
          ),
          if (isBypassed)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 1),
                ),
                child: const Text(
                  'A/B BYPASS ACTIVE',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SplineCurvePainter extends CustomPainter {
  final List<double> bandGains;
  final List<double> bandFrequencies;
  final double bassBoost;
  final bool isActive;
  final double minDb;
  final double maxDb;

  _SplineCurvePainter({
    required this.bandGains,
    required this.bandFrequencies,
    required this.bassBoost,
    required this.isActive,
    required this.minDb,
    required this.maxDb,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double graphWidth = size.width;
    final double graphHeight = size.height - 24; // Leave room for bottom frequency labels

    // 1. Draw horizontal grid lines (-10dB, -5dB, 0dB, +5dB, +10dB)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final zeroLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const dbGrid = [-10.0, -5.0, 0.0, 5.0, 10.0];
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final db in dbGrid) {
      final y = _dbToY(db, graphHeight);
      final isZero = db == 0.0;
      canvas.drawLine(
        Offset(0, y),
        Offset(graphWidth, y),
        isZero ? zeroLinePaint : gridPaint,
      );

      // Label
      textPainter.text = TextSpan(
        text: '${db > 0 ? '+' : ''}${db.toInt()}dB',
        style: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 9,
          fontWeight: isZero ? FontWeight.w600 : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - 11));
    }

    if (bandGains.isEmpty) return;

    // 2. Map anchor points across the canvas
    // 5 bands distributed evenly across width
    final List<Offset> points = [];
    final int count = bandGains.length;

    // Left boundary extrapolation (20 Hz sub-bass)
    final double subBassBoost = isActive ? (bassBoost * 5.0) : 0.0;
    final double firstBandEffective = isActive ? (bandGains[0] + subBassBoost) : 0.0;
    points.add(Offset(0, _dbToY(firstBandEffective * 0.9, graphHeight)));

    for (int i = 0; i < count; i++) {
      final double x = (graphWidth / (count + 1)) * (i + 1);
      double extraBass = 0.0;
      if (isActive) {
        if (i == 0) extraBass = bassBoost * 5.0;
        if (i == 1) extraBass = bassBoost * 2.5;
      }
      final double db = isActive ? (bandGains[i] + extraBass) : 0.0;
      final double y = _dbToY(db, graphHeight);
      points.add(Offset(x, y));
    }

    // Right boundary extrapolation (20 kHz air)
    final double lastBandVal = isActive ? bandGains.last : 0.0;
    points.add(Offset(graphWidth, _dbToY(lastBandVal * 0.8, graphHeight)));

    // 3. Generate smooth Catmull-Rom spline path
    final path = Path();
    path.moveTo(points.first.x, points.first.y);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      final cp1x = p1.x + (p2.x - p0.x) / 6;
      final cp1y = p1.y + (p2.y - p0.y) / 6;
      final cp2x = p2.x - (p3.x - p1.x) / 6;
      final cp2y = p2.y - (p3.y - p1.y) / 6;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
    }

    // 4. Fill gradient below curve
    final fillPath = Path.from(path)
      ..lineTo(graphWidth, graphHeight)
      ..lineTo(0, graphHeight)
      ..close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isActive
          ? [
              AppTheme.primary.withOpacity(0.35),
              AppTheme.primary.withOpacity(0.08),
              Colors.transparent,
            ]
          : [
              Colors.white.withOpacity(0.08),
              Colors.transparent,
            ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, graphWidth, graphHeight))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 5. Stroke glowing curve
    final glowPaint = Paint()
      ..color = isActive ? AppTheme.primary.withOpacity(0.4) : Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, glowPaint);

    final strokePaint = Paint()
      ..color = isActive ? AppTheme.primary : AppTheme.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // 6. Draw glowing nodes at each band
    for (int i = 0; i < count; i++) {
      final nodePos = points[i + 1];

      // Outer Halo
      if (isActive) {
        final haloPaint = Paint()
          ..color = AppTheme.primary.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(nodePos, 8.0, haloPaint);
      }

      // Inner Core
      final nodeCorePaint = Paint()
        ..color = isActive ? Colors.white : AppTheme.textMuted
        ..style = PaintingStyle.fill;
      canvas.drawCircle(nodePos, 4.0, nodeCorePaint);

      final nodeBorderPaint = Paint()
        ..color = isActive ? AppTheme.primary : AppTheme.surfaceHighlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(nodePos, 4.0, nodeBorderPaint);

      // Bottom Frequency Label
      final freqLabel = _formatFreq(
        i < bandFrequencies.length ? bandFrequencies[i] : 0.0,
      );
      textPainter.text = TextSpan(
        text: freqLabel,
        style: TextStyle(
          color: isActive ? AppTheme.textSecondary : AppTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(nodePos.x - textPainter.width / 2, size.height - 14),
      );
    }
  }

  double _dbToY(double db, double height) {
    final clamped = db.clamp(minDb, maxDb);
    // Inverted: maxDb is at top (0), minDb is at bottom (height)
    return height - ((clamped - minDb) / (maxDb - minDb)) * height;
  }

  String _formatFreq(double hz) {
    if (hz >= 1000) {
      final khz = hz / 1000;
      return khz == khz.roundToDouble()
          ? '${khz.toInt()}kHz'
          : '${khz.toStringAsFixed(1)}kHz';
    }
    return '${hz.round()}Hz';
  }

  @override
  bool shouldRepaint(covariant _SplineCurvePainter oldDelegate) {
    return oldDelegate.bandGains != bandGains ||
        oldDelegate.bassBoost != bassBoost ||
        oldDelegate.isActive != isActive ||
        oldDelegate.bandFrequencies != bandFrequencies;
  }
}

extension on Offset {
  double get x => dx;
  double get y => dy;
}
