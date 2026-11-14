import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'shared/app_network_image.dart';

/// Interactive, authentic analog Vinyl Turntable display widget with 33⅓ RPM rotation,
/// micro-groove specular sheen highlights, center album art label, and physical tonearm inertia.
class VinylTurntableView extends StatefulWidget {
  final String? coverUrl;
  final bool isPlaying;
  final Color ambientColor;
  final VoidCallback? onTap;
  final bool showTonearm;
  final double? size;

  const VinylTurntableView({
    super.key,
    required this.coverUrl,
    required this.isPlaying,
    this.ambientColor = const Color(0xFFED5564),
    this.onTap,
    this.showTonearm = true,
    this.size,
  });

  @override
  State<VinylTurntableView> createState() => _VinylTurntableViewState();
}

class _VinylTurntableViewState extends State<VinylTurntableView>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _tonearmAnimation;
  late AnimationController _tonearmController;

  // Angular velocity state for continuous smooth rotation with inertia
  double _currentAngle = 0.0;
  DateTime _lastFrameTime = DateTime.now();
  double _currentSpeedMultiplier = 0.0; // 0.0 (stopped) to 1.0 (33⅓ RPM)

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);

    _tonearmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _tonearmAnimation = CurvedAnimation(
      parent: _tonearmController,
      curve: Curves.easeOutBack,
    );

    if (widget.isPlaying) {
      _currentSpeedMultiplier = 1.0;
      _tonearmController.value = 1.0;
      _rotationController.repeat();
    } else {
      _currentSpeedMultiplier = 0.0;
      _tonearmController.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(covariant VinylTurntableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _tonearmController.forward();
        if (!_rotationController.isAnimating) {
          _lastFrameTime = DateTime.now();
          _rotationController.repeat();
        }
      } else {
        _tonearmController.reverse();
      }
    }
  }

  void _onTick() {
    final now = DateTime.now();
    final dt = now.difference(_lastFrameTime).inMicroseconds / 1000000.0;
    _lastFrameTime = now;

    // Target speed: 1.0 when playing, 0.0 when paused
    final targetSpeed = widget.isPlaying ? 1.0 : 0.0;
    const accelRate = 2.5; // reaches 33⅓ RPM in ~400ms
    const decelRate = 1.25; // decelerates to rest in ~800ms

    if (_currentSpeedMultiplier < targetSpeed) {
      _currentSpeedMultiplier = math.min(1.0, _currentSpeedMultiplier + accelRate * dt);
    } else if (_currentSpeedMultiplier > targetSpeed) {
      _currentSpeedMultiplier = math.max(0.0, _currentSpeedMultiplier - decelRate * dt);
    }

    if (_currentSpeedMultiplier > 0.001) {
      // 33⅓ RPM = 33.333 / 60 rev/sec = ~0.5555 rev/sec = ~3.4906 rad/sec
      const standardOmega = 2 * math.pi * (33.333 / 60.0);
      setState(() {
        _currentAngle = (_currentAngle + standardOmega * _currentSpeedMultiplier * dt) % (2 * math.pi);
      });
    } else if (!widget.isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.removeListener(_onTick);
    _rotationController.dispose();
    _tonearmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = widget.size ??
            math.min(constraints.maxWidth, constraints.maxHeight);
        final diameter = math.max(120.0, availableSize);

        return Center(
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 1. Ambient Glow Halo behind the turntable disc
                  Container(
                    width: diameter * 0.88,
                    height: diameter * 0.88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.ambientColor.withValues(alpha: widget.isPlaying ? 0.38 : 0.20),
                          blurRadius: 44,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                  ),

                  // 2. Rotating Vinyl Record (Grooves + Specular Sheen + Center Label)
                  Transform.rotate(
                    angle: _currentAngle,
                    child: SizedBox(
                      width: diameter * 0.94,
                      height: diameter * 0.94,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Custom Painted Vinyl Base with Concentric Grooves & Sheen
                          CustomPaint(
                            size: Size(diameter * 0.94, diameter * 0.94),
                            painter: _VinylDiscPainter(),
                          ),

                          // Center Artwork Label (38% of disc diameter)
                          SizedBox(
                            width: diameter * 0.36,
                            height: diameter * 0.36,
                            child: ClipOval(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E24),
                                  border: Border.all(
                                    color: const Color(0xFF2E2E36),
                                    width: 1.5,
                                  ),
                                ),
                                child: AppNetworkImage(
                                  imageUrl: widget.coverUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 400,
                                  cacheHeight: 400,
                                  placeholderIcon: Icons.album_rounded,
                                ),
                              ),
                            ),
                          ),

                          // Brass Spindle Ring and Center Hole Pin
                          Container(
                            width: diameter * 0.065,
                            height: diameter * 0.065,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [
                                  Color(0xFFE5C07B), // Brass gold
                                  Color(0xFF9E782F),
                                  Color(0xFF3A2B10),
                                ],
                                stops: [0.0, 0.65, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: diameter * 0.026,
                                height: diameter * 0.026,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF0C0C0E),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Physical Analog Tonearm (Top Right Pivot)
                  if (widget.showTonearm)
                    Positioned(
                      top: -diameter * 0.02,
                      right: diameter * 0.01,
                      child: AnimatedBuilder(
                        animation: _tonearmAnimation,
                        builder: (context, _) {
                          // Angle interpolates between rest (8°) and playing groove (26°)
                          final tonearmAngle = 0.12 + (_tonearmAnimation.value * 0.34);
                          return Transform.rotate(
                            angle: tonearmAngle,
                            alignment: const Alignment(0.7, -0.7),
                            child: CustomPaint(
                              size: Size(diameter * 0.35, diameter * 0.55),
                              painter: _TonearmPainter(),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter rendering dark vinyl disc micro-grooves and dual radial sheen highlights.
class _VinylDiscPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer vinyl body
    final basePaint = Paint()
      ..color = const Color(0xFF101013)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    // Subtle outer vinyl rim highlight
    final rimPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 1.0, rimPaint);

    final bevelPaint = Paint()
      ..color = const Color(0x1A000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius - 3.0, bevelPaint);

    // High-density concentric micro-grooves
    final innerGrooveRadius = radius * 0.40;
    const grooveStep = 2.8;
    int grooveIndex = 0;

    for (double r = innerGrooveRadius; r < radius - 6.0; r += grooveStep) {
      grooveIndex++;
      // Subtle variations in groove depth and reflectivity
      final double grooveAlpha = (grooveIndex % 3 == 0)
          ? 0.08
          : (grooveIndex % 2 == 0 ? 0.04 : 0.02);

      final groovePaint = Paint()
        ..color = Colors.white.withValues(alpha: grooveAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75;

      canvas.drawCircle(center, r, groovePaint);
    }

    // Radial Specular Light Sheen (Two opposing 40° reflective fan wedges)
    final sheenPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.09),
          Colors.white.withValues(alpha: 0.02),
          Colors.transparent,
        ],
        stops: const [0.35, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    // Wedge 1 at 45°
    final path1 = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius - 3.0),
        math.pi / 4 - 0.35,
        0.70,
        false,
      )
      ..close();
    canvas.drawPath(path1, sheenPaint);

    // Wedge 2 at 225°
    final path2 = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius - 3.0),
        5 * math.pi / 4 - 0.35,
        0.70,
        false,
      )
      ..close();
    canvas.drawPath(path2, sheenPaint);

    // Center runout groove boundary
    final runoutPaint = Paint()
      ..color = const Color(0xFF1E1E22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, innerGrooveRadius, runoutPaint);
  }

  @override
  bool shouldRepaint(covariant _VinylDiscPainter oldDelegate) => false;
}

/// Custom painter rendering the metallic pivot base, tonearm wand, counterweight, and cartridge.
class _TonearmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width * 0.75, size.height * 0.12);

    // 1. Pivot Gimbal Base & Counterweight
    final baseGimbalPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFE0E0E0),
          Color(0xFF888890),
          Color(0xFF333338),
        ],
      ).createShader(Rect.fromCircle(center: pivot, radius: 14))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pivot, 12, baseGimbalPaint);

    final counterweightPaint = Paint()
      ..color = const Color(0xFF222226)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pivot.dx + 4, pivot.dy - 6), 6, counterweightPaint);

    // 2. Metallic S-curved Tonearm Wand
    final armPath = Path();
    armPath.moveTo(pivot.dx, pivot.dy);
    // Smooth S-bend leading towards the cartridge needle
    final target = Offset(size.width * 0.20, size.height * 0.88);
    armPath.cubicTo(
      pivot.dx - 12,
      size.height * 0.40,
      target.dx + 28,
      size.height * 0.65,
      target.dx,
      target.dy,
    );

    // Arm shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(armPath.shift(const Offset(3, 5)), shadowPaint);

    // Chrome arm line
    final chromeArmPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFEEEEEE),
          Color(0xFFCCCCCC),
          Color(0xFF888888),
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromPoints(pivot, target))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(armPath, chromeArmPaint);

    // 3. Headshell & Cartridge Needle
    final headshellCenter = target;
    final headshellRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: headshellCenter, width: 14, height: 22),
      const Radius.circular(3),
    );

    final headshellPaint = Paint()
      ..color = const Color(0xFF18181C)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(headshellRect, headshellPaint);

    // Gold cartridge accent line
    final goldLinePaint = Paint()
      ..color = const Color(0xFFE5C07B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(headshellCenter.dx - 4, headshellCenter.dy + 8),
      Offset(headshellCenter.dx + 4, headshellCenter.dy + 8),
      goldLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TonearmPainter oldDelegate) => false;
}
