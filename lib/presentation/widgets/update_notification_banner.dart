import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'bouncing_scale_button.dart';

/// Premium floating in-app update notification banner.
/// Features Apple Music / Liquid Glass aesthetics, swipe-to-dismiss gesture,
/// responsive layout, and haptic-enabled quick actions.
class UpdateNotificationBanner extends StatefulWidget {
  final String version;
  final VoidCallback onReadChangelog;
  final VoidCallback onDismiss;

  const UpdateNotificationBanner({
    super.key,
    required this.version,
    required this.onReadChangelog,
    required this.onDismiss,
  });

  @override
  State<UpdateNotificationBanner> createState() => _UpdateNotificationBannerState();
}

class _UpdateNotificationBannerState extends State<UpdateNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _isDismissing = false;
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    HapticFeedback.lightImpact();
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  Future<void> _handleReadChangelog() async {
    if (_isDismissing) return;
    _isDismissing = true;
    HapticFeedback.mediumImpact();
    await _controller.reverse();
    if (mounted) {
      widget.onReadChangelog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = tokens.accent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0.0, _slideAnimation.value.dy * 80 + _dragOffsetY),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy < 0) {
            setState(() {
              _dragOffsetY += details.delta.dy;
            });
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffsetY < -20 || (details.primaryVelocity ?? 0) < -250) {
            _handleDismiss();
          } else {
            setState(() {
              _dragOffsetY = 0.0;
            });
          }
        },
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 580),
            decoration: BoxDecoration(
              color: tokens.isGlass
                  ? const Color(0xE8141C18)
                  : tokens.surfaceElevated.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: accent.withValues(alpha: 0.32),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      // Glowing Sparkle Icon Badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withValues(alpha: 0.28),
                              accent.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Version & Features text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Softify Updated to v${widget.version}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.35),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Living covers, Apple Music style & synced lyrics',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 11.5,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Quick Action Buttons
                      BouncingScaleButton(
                        scaleDown: 0.94,
                        minTouchTarget: 36,
                        onTap: _handleReadChangelog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                Color.lerp(accent, Colors.white, 0.15) ?? accent,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'What\'s New',
                                style: TextStyle(
                                  color: Color(0xFF09140E),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Color(0xFF09140E),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Dismiss Button
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: tokens.textMuted,
                            size: 16,
                          ),
                        ),
                        tooltip: 'Dismiss',
                        onPressed: _handleDismiss,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
