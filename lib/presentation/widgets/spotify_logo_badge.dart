import 'package:flutter/material.dart';

/// Pixel-perfect, scalable official Spotify green logo badge with signature curved sound arcs.
class SpotifyLogoBadge extends StatelessWidget {
  final double size;
  final Color badgeColor;
  final Color arcColor;
  final bool hasShadow;

  const SpotifyLogoBadge({
    super.key,
    this.size = 20.0,
    this.badgeColor = const Color(0xFF1DB954),
    this.arcColor = Colors.black,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: badgeColor,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: size * 0.2,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size, size),
          painter: _SpotifyLogoPainter(arcColor: arcColor),
        ),
      ),
    );
  }
}

class _SpotifyLogoPainter extends CustomPainter {
  final Color arcColor;

  const _SpotifyLogoPainter({required this.arcColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top arc
    final topPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.11;

    final topPath = Path()
      ..moveTo(w * 0.26, h * 0.40)
      ..quadraticBezierTo(w * 0.52, h * 0.27, w * 0.77, h * 0.38);
    canvas.drawPath(topPath, topPaint);

    // Middle arc
    final midPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.10;

    final midPath = Path()
      ..moveTo(w * 0.30, h * 0.55)
      ..quadraticBezierTo(w * 0.52, h * 0.44, w * 0.73, h * 0.54);
    canvas.drawPath(midPath, midPaint);

    // Bottom arc
    final botPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.09;

    final botPath = Path()
      ..moveTo(w * 0.34, h * 0.70)
      ..quadraticBezierTo(w * 0.52, h * 0.61, w * 0.69, h * 0.69);
    canvas.drawPath(botPath, botPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotifyLogoPainter oldDelegate) =>
      oldDelegate.arcColor != arcColor;
}
