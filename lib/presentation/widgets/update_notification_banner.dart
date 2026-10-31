import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Floating in-app update notification banner.
/// Informs the user when the app has updated and offers a 1-tap "Read Changelog" action.
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
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
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
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  Future<void> _handleReadChangelog() async {
    if (_isDismissing) return;
    _isDismissing = true;
    await _controller.reverse();
    if (mounted) {
      widget.onReadChangelog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FractionalTranslation(
          translation: Offset(0.0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 640),
          decoration: BoxDecoration(
            color: tokens.isGlass ? const Color(0xE6141D18) : const Color(0xFF141916),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0x4D4EDEA3),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Sparkle Icon Badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0x2B4EDEA3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0x554EDEA3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF4EDEA3),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Text Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Softify Updated to v${widget.version}! 🎉',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Explore Apple Music player, motion covers & more.',
                            style: TextStyle(
                              color: Color(0xFFA5B2AA),
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4EDEA3),
                            foregroundColor: const Color(0xFF07120C),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 34),
                            elevation: 0,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _handleReadChangelog,
                          child: const Text(
                            'Read Changelog',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF8B9890),
                            size: 18,
                          ),
                          tooltip: 'Dismiss',
                          onPressed: _handleDismiss,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
