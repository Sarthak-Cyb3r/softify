import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';

/// Direction for double-tap seek gesture.
enum _SeekSide {
  none,
  rewind,
  forward,
}

/// A responsive, high-performance overlay widget that wraps player artwork or
/// player view to provide YouTube-style double-tap seeking (±10s).
///
/// Features:
/// - Detects double taps on the left half (-10s) and right half (+10s).
/// - Accumulates consecutive taps while active (-20s, -30s, +20s, +30s, etc.).
/// - Displays animated curved ripple wave and frosted AMOLED indicator badge.
/// - Fluid 3-chevron cascading pulse wave animation.
/// - Connects to [audioHandlerProvider] to trigger smooth audio seeking.
/// - Seamlessly preserves single-tap passthrough (e.g. for toggling controls/views).
class DoubleTapSeekOverlay extends ConsumerStatefulWidget {
  const DoubleTapSeekOverlay({
    super.key,
    required this.child,
    this.onTap,
    this.onSeek,
    this.seekDuration = const Duration(seconds: 10),
    this.enabled = true,
    this.borderRadius,
    this.showRipple = true,
    this.showBadge = true,
    this.hitTestBehavior = HitTestBehavior.opaque,
  });

  /// The child widget to wrap (such as player artwork, canvas, or player screen).
  final Widget child;

  /// Optional single-tap callback (e.g. toggles player controls, lyrics, turntable).
  final VoidCallback? onTap;

  /// Optional callback invoked whenever a seek occurs.
  final void Function(Duration targetPosition, int accumulatedSeconds)? onSeek;

  /// Duration to seek per double tap (default: 10 seconds).
  final Duration seekDuration;

  /// Whether double tap to seek is active.
  final bool enabled;

  /// Optional border radius used to clip the animated seek ripple to match artwork curves.
  final BorderRadius? borderRadius;

  /// Whether to display the animated side ripple effect.
  final bool showRipple;

  /// Whether to display the center badge indicator ("-10s" / "+10s").
  final bool showBadge;

  /// Hit test behavior for the gesture detector.
  final HitTestBehavior hitTestBehavior;

  @override
  ConsumerState<DoubleTapSeekOverlay> createState() => _DoubleTapSeekOverlayState();
}

class _DoubleTapSeekOverlayState extends ConsumerState<DoubleTapSeekOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _burstController;
  late final Animation<double> _burstAnimation;
  late final Animation<double> _badgeScaleAnimation;

  late final AnimationController _arrowController;

  Timer? _dismissTimer;

  _SeekSide _seekSide = _SeekSide.none;
  int _accumulatedSeconds = 0;
  Offset? _lastTapPosition;
  Size _widgetSize = Size.zero;
  Duration? _targetSeekPosition;
  bool _suppressNextSingleTap = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _burstAnimation = CurvedAnimation(
      parent: _burstController,
      curve: Curves.easeOutCubic,
    );
    _badgeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 60,
      ),
    ]).animate(_burstController);

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _fadeController.dispose();
    _burstController.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  void _startDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      _fadeController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _seekSide = _SeekSide.none;
          _accumulatedSeconds = 0;
          _targetSeekPosition = null;
          _suppressNextSingleTap = false;
        });
        _arrowController.stop();
        _arrowController.reset();
      });
    });
  }

  void _dismissImmediately() {
    _dismissTimer?.cancel();
    _fadeController.reset();
    _arrowController.stop();
    _arrowController.reset();
    setState(() {
      _seekSide = _SeekSide.none;
      _accumulatedSeconds = 0;
      _targetSeekPosition = null;
      _suppressNextSingleTap = false;
    });
  }

  Future<void> _performSeek(bool isForward) async {
    try {
      final audioHandler = ref.read(audioHandlerProvider);
      final currentPos = audioHandler.position;
      final totalDuration = audioHandler.currentTrack?.duration;

      final basePos = _targetSeekPosition ?? currentPos;
      final delta = widget.seekDuration;
      Duration target;

      if (isForward) {
        target = basePos + delta;
        if (totalDuration != null &&
            totalDuration > Duration.zero &&
            target > totalDuration) {
          target = totalDuration;
        }
      } else {
        target = basePos - delta;
        if (target < Duration.zero) {
          target = Duration.zero;
        }
      }

      _targetSeekPosition = target;
      HapticFeedback.lightImpact();

      widget.onSeek?.call(target, _accumulatedSeconds);
      await audioHandler.seek(target);
    } catch (e) {
      debugPrint('[DoubleTapSeekOverlay] Seek error: $e');
    }
  }

  void _startOrContinueSeek(bool isForward, Offset localPosition) {
    final side = isForward ? _SeekSide.forward : _SeekSide.rewind;

    setState(() {
      if (_seekSide == side) {
        _accumulatedSeconds += widget.seekDuration.inSeconds;
      } else {
        _seekSide = side;
        _accumulatedSeconds = widget.seekDuration.inSeconds;
        _targetSeekPosition = null;
      }
      _lastTapPosition = localPosition;
    });

    _performSeek(isForward);

    _fadeController.forward();
    _burstController.forward(from: 0.0);

    if (!_arrowController.isAnimating) {
      _arrowController.repeat();
    }

    _startDismissTimer();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;

    final width = _widgetSize.width > 0
        ? _widgetSize.width
        : MediaQuery.sizeOf(context).width;

    // Check if seek overlay is currently active
    if (_seekSide != _SeekSide.none) {
      final isTapForward = details.localPosition.dx >= width / 2;
      final isCurrentForward = _seekSide == _SeekSide.forward;

      if (isTapForward == isCurrentForward) {
        // Additional tap on the same side accumulates seek time!
        _suppressNextSingleTap = true;
        _startOrContinueSeek(isTapForward, details.localPosition);
      } else {
        // Tapped the other half while active -> dismiss previous overlay
        _dismissImmediately();
      }
    }
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;

    final width = _widgetSize.width > 0
        ? _widgetSize.width
        : MediaQuery.sizeOf(context).width;

    final isForward = details.localPosition.dx >= width / 2;
    _startOrContinueSeek(isForward, details.localPosition);
  }

  void _handleSingleTap() {
    if (_suppressNextSingleTap) {
      _suppressNextSingleTap = false;
      return;
    }
    if (_seekSide != _SeekSide.none) {
      return;
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return GestureDetector(
        behavior: widget.hitTestBehavior,
        onTap: widget.onTap,
        child: widget.child,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _widgetSize = Size(
          constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : constraints.maxWidth,
        );

        final isForward = _seekSide == _SeekSide.forward;

        return GestureDetector(
          behavior: widget.hitTestBehavior,
          onTapDown: _handleTapDown,
          onDoubleTapDown: _handleDoubleTapDown,
          onDoubleTap: () {}, // Required to activate onDoubleTapDown
          onTap: _handleSingleTap,
          child: ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
            clipBehavior: widget.borderRadius != null
                ? Clip.antiAlias
                : Clip.none,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                widget.child,
                if (_seekSide != _SeekSide.none)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _fadeAnimation,
                          _burstAnimation,
                          _arrowController,
                        ]),
                        builder: (context, _) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Stack(
                              children: [
                                if (widget.showRipple)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _SeekRipplePainter(
                                        progress: _burstAnimation.value,
                                        isForward: isForward,
                                        accentColor: AppTheme.accent,
                                        tapPosition: _lastTapPosition,
                                      ),
                                    ),
                                  ),
                                if (widget.showBadge)
                                  Positioned(
                                    left: isForward ? _widgetSize.width / 2 : 0,
                                    width: _widgetSize.width / 2,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: ScaleTransition(
                                        scale: _badgeScaleAnimation,
                                        child: _buildBadge(isForward),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(bool isForward) {
    final sign = isForward ? '+' : '-';
    final labelText = '$sign${_accumulatedSeconds}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedChevronRow(
            isForward: isForward,
            progress: _arrowController.value,
          ),
          const SizedBox(height: 4),
          Text(
            labelText,
            style: const TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A sequential 3-chevron wave pulse animation indicating seek direction.
class _AnimatedChevronRow extends StatelessWidget {
  const _AnimatedChevronRow({
    required this.isForward,
    required this.progress,
  });

  final bool isForward;
  final double progress;

  @override
  Widget build(BuildContext context) {
    double getOpacity(int index) {
      final targetIndex = isForward ? index : (2 - index);
      final start = targetIndex * 0.22;
      final end = start + 0.45;

      if (progress >= start && progress <= end) {
        final local = (progress - start) / 0.45;
        // Triangle pulse: 0.35 -> 1.0 -> 0.35
        return 0.35 + 0.65 * (1.0 - (local - 0.5).abs() * 2.0);
      }
      return 0.35;
    }

    final chevronIcon = isForward
        ? Icons.chevron_right_rounded
        : Icons.chevron_left_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final opacity = getOpacity(index).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.0),
          child: Opacity(
            opacity: opacity,
            child: Icon(
              chevronIcon,
              size: 24,
              color: Colors.white,
            ),
          ),
        );
      }),
    );
  }
}

/// Custom painter for the animated curved ripple wave and expanding circular burst.
class _SeekRipplePainter extends CustomPainter {
  const _SeekRipplePainter({
    required this.progress,
    required this.isForward,
    required this.accentColor,
    this.tapPosition,
  });

  final double progress;
  final bool isForward;
  final Color accentColor;
  final Offset? tapPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final path = Path();

    if (isForward) {
      // Right half curved arc
      final arcDepth = (w * 0.45) * (0.6 + 0.4 * progress);
      final controlX = w - arcDepth;

      path.moveTo(w, 0);
      path.lineTo(w - arcDepth * 0.35, 0);
      path.quadraticBezierTo(controlX, h / 2, w - arcDepth * 0.35, h);
      path.lineTo(w, h);
      path.close();

      final gradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          accentColor.withValues(alpha: 0.0),
          accentColor.withValues(alpha: 0.12 * (1.0 - progress * 0.4)),
          accentColor.withValues(alpha: 0.24 * (1.0 - progress * 0.4)),
        ],
        stops: const [0.0, 0.4, 1.0],
      );

      final paint = Paint()
        ..shader =
            gradient.createShader(Rect.fromLTWH(controlX, 0, arcDepth, h))
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);
    } else {
      // Left half curved arc
      final arcDepth = (w * 0.45) * (0.6 + 0.4 * progress);
      final controlX = arcDepth;

      path.moveTo(0, 0);
      path.lineTo(arcDepth * 0.35, 0);
      path.quadraticBezierTo(controlX, h / 2, arcDepth * 0.35, h);
      path.lineTo(0, h);
      path.close();

      final gradient = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          accentColor.withValues(alpha: 0.0),
          accentColor.withValues(alpha: 0.12 * (1.0 - progress * 0.4)),
          accentColor.withValues(alpha: 0.24 * (1.0 - progress * 0.4)),
        ],
        stops: const [0.0, 0.4, 1.0],
      );

      final paint = Paint()
        ..shader =
            gradient.createShader(Rect.fromLTWH(0, 0, arcDepth, h))
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);
    }

    // Expanding radial circular burst from tap point
    final defaultCenter = Offset(
      isForward ? w * 0.75 : w * 0.25,
      h / 2,
    );
    final center = tapPosition ?? defaultCenter;
    final maxRadius = (h * 0.55).clamp(60.0, 320.0);
    final currentRadius = maxRadius * progress;
    final waveAlpha = (0.18 * (1.0 - progress)).clamp(0.0, 1.0);

    final burstPaint = Paint()
      ..color = Colors.white.withValues(alpha: waveAlpha)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, currentRadius, burstPaint);
  }

  @override
  bool shouldRepaint(covariant _SeekRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isForward != isForward ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.tapPosition != tapPosition;
  }
}
