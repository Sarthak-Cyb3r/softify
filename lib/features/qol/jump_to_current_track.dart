import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/bouncing_scale_button.dart';

/// A floating mini pill button designed for long playlists, queues, and track listings.
///
/// Automatically monitors the viewport of [scrollController] and appears when the
/// currently playing track (specified by [currentTrackIndex]) is scrolled out of view.
/// Tapping the button smoothly animates the scroll view directly to the track item.
class JumpToCurrentTrackFab extends StatefulWidget {
  /// The [ScrollController] attached to the scrollable playlist or queue.
  final ScrollController scrollController;

  /// Zero-based index of the currently active/playing track in the list.
  /// If null or negative (< 0), the pill button remains hidden.
  final int? currentTrackIndex;

  /// The estimated or fixed vertical extent of each track tile.
  /// Defaults to 64.0 logical pixels (standard height of TrackRow/ListTile).
  final double itemExtent;

  /// Vertical offset preceding the first list item (e.g. app bar, header, or padding).
  /// Defaults to 0.0.
  final double leadingOffset;

  /// Optional custom callback to calculate the vertical offset for an item at [index].
  /// Takes precedence over [leadingOffset] + (index * [itemExtent]) if provided.
  final double Function(int index)? customOffsetBuilder;

  /// Text displayed inside the pill button.
  /// Defaults to 'Jump to playing track'.
  final String label;

  /// Custom leading icon widget. Defaults to a music note icon in [AppTokens.accent].
  final Widget? icon;

  /// Whether to display a directional indicator (up/down arrow) reflecting whether
  /// the active track is scrolled above or below the current viewport.
  /// Defaults to true.
  final bool showDirectionalIndicator;

  /// Target alignment of the track within the viewport upon completion of the jump:
  /// - 0.5: Centers the track vertically in the viewport (recommended).
  /// - 0.0: Aligns the track to the top edge of the viewport.
  /// - 1.0: Aligns the track to the bottom edge of the viewport.
  /// Defaults to 0.5.
  final double targetAlignment;

  /// Duration of the scroll animation.
  /// Defaults to 400 milliseconds.
  final Duration animationDuration;

  /// Interpolation curve of the scroll animation.
  /// Defaults to [Curves.easeInOutCubic].
  final Curve animationCurve;

  /// Edge margin in logical pixels around the visible viewport.
  /// The track is deemed "in view" only when comfortably inside this threshold.
  /// Defaults to 24.0.
  final double visibilityBuffer;

  /// Optional callback invoked after triggering the jump scroll.
  final VoidCallback? onJump;

  /// Custom internal padding for the pill button.
  final EdgeInsetsGeometry? padding;

  /// Custom outer margin or inset.
  final EdgeInsetsGeometry? margin;

  /// Custom surface background color override. If null, adopts the active theme's surface.
  final Color? backgroundColor;

  /// Custom text and icon foreground color override.
  final Color? foregroundColor;

  const JumpToCurrentTrackFab({
    super.key,
    required this.scrollController,
    required this.currentTrackIndex,
    this.itemExtent = 64.0,
    this.leadingOffset = 0.0,
    this.customOffsetBuilder,
    this.label = 'Jump to playing track',
    this.icon,
    this.showDirectionalIndicator = true,
    this.targetAlignment = 0.5,
    this.animationDuration = const Duration(milliseconds: 400),
    this.animationCurve = Curves.easeInOutCubic,
    this.visibilityBuffer = 24.0,
    this.onJump,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<JumpToCurrentTrackFab> createState() => _JumpToCurrentTrackFabState();
}

class _JumpToCurrentTrackFabState extends State<JumpToCurrentTrackFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isVisible = false;
  bool _isAbove = false;
  bool _isJumping = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    widget.scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkVisibility();
    });
  }

  @override
  void didUpdateWidget(covariant JumpToCurrentTrackFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }

    if (oldWidget.currentTrackIndex != widget.currentTrackIndex ||
        oldWidget.itemExtent != widget.itemExtent ||
        oldWidget.leadingOffset != widget.leadingOffset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkVisibility();
      });
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _animController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isJumping) {
      _checkVisibility();
    }
  }

  bool _computeIsOutOfView() {
    if (!widget.scrollController.hasClients) return false;
    final position = widget.scrollController.position;
    if (!position.hasContentDimensions) return false;
    if (position.maxScrollExtent <= 0) return false;

    final index = widget.currentTrackIndex;
    if (index == null || index < 0) return false;

    final double itemTop = widget.customOffsetBuilder != null
        ? widget.customOffsetBuilder!(index)
        : widget.leadingOffset + (index * widget.itemExtent);
    final double itemBottom = itemTop + widget.itemExtent;

    final double viewportStart = position.pixels;
    final double viewportEnd = position.pixels + position.viewportDimension;

    final bool isAbove = itemBottom <= (viewportStart + widget.visibilityBuffer);
    final bool isBelow = itemTop >= (viewportEnd - widget.visibilityBuffer);

    return isAbove || isBelow;
  }

  bool _computeIsAbove() {
    if (!widget.scrollController.hasClients) return false;
    final position = widget.scrollController.position;
    if (!position.hasContentDimensions) return false;

    final index = widget.currentTrackIndex;
    if (index == null || index < 0) return false;

    final double itemTop = widget.customOffsetBuilder != null
        ? widget.customOffsetBuilder!(index)
        : widget.leadingOffset + (index * widget.itemExtent);
    final double itemBottom = itemTop + widget.itemExtent;

    final double viewportStart = position.pixels;
    return itemBottom <= (viewportStart + widget.visibilityBuffer);
  }

  void _checkVisibility() {
    if (!mounted) return;
    final shouldBeVisible = _computeIsOutOfView();
    final isAbove = _computeIsAbove();

    if (shouldBeVisible != _isVisible || isAbove != _isAbove) {
      setState(() {
        _isVisible = shouldBeVisible;
        _isAbove = isAbove;
      });

      if (shouldBeVisible) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  Future<void> _jumpToTrack() async {
    if (!widget.scrollController.hasClients ||
        widget.currentTrackIndex == null ||
        _isJumping) {
      return;
    }

    final position = widget.scrollController.position;
    if (!position.hasContentDimensions) return;

    HapticFeedback.lightImpact();
    _isJumping = true;

    try {
      final index = widget.currentTrackIndex!;
      final double itemTop = widget.customOffsetBuilder != null
          ? widget.customOffsetBuilder!(index)
          : widget.leadingOffset + (index * widget.itemExtent);

      final double targetOffset = (itemTop -
              (position.viewportDimension - widget.itemExtent) *
                  widget.targetAlignment)
          .clamp(position.minScrollExtent, position.maxScrollExtent);

      widget.onJump?.call();

      await widget.scrollController.animateTo(
        targetOffset,
        duration: widget.animationDuration,
        curve: widget.animationCurve,
      );
    } finally {
      if (mounted) {
        _isJumping = false;
        _checkVisibility();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isGlass = tokens.isGlass;

    final effectiveBgColor = widget.backgroundColor ??
        (isGlass
            ? tokens.glassSurface.withValues(alpha: 0.90)
            : tokens.surfaceElevated);

    final effectiveFgColor = widget.foregroundColor ?? tokens.textPrimary;
    final accentColor = tokens.accent;

    final pillWidget = Semantics(
      button: true,
      label: widget.label,
      child: BouncingScaleButton(
        onTap: _jumpToTrack,
        scaleDown: 0.95,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              padding: widget.padding ??
                  EdgeInsets.symmetric(
                    horizontal: tokens.spaceMd,
                    vertical: 8.0,
                  ),
              decoration: BoxDecoration(
                color: effectiveBgColor,
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                border: Border.all(
                  color: isGlass
                      ? tokens.glassBorder
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16.0,
                    offset: const Offset(0, 4),
                    spreadRadius: 1.0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.icon ??
                      Icon(
                        Icons.music_note_rounded,
                        size: 16.0,
                        color: accentColor,
                      ),
                  SizedBox(width: tokens.spaceSm),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: effectiveFgColor,
                    ),
                  ),
                  if (widget.showDirectionalIndicator) ...[
                    const SizedBox(width: 6.0),
                    AnimatedRotation(
                      turns: _isAbove ? 0.0 : 0.5,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        size: 14.0,
                        color: accentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        if (_animController.value == 0.0 && !_isVisible) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          ignoring: !_isVisible,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.margin != null
          ? Padding(padding: widget.margin!, child: pillWidget)
          : pillWidget,
    );
  }
}

/// A Riverpod-aware convenience wrapper around [JumpToCurrentTrackFab].
///
/// Automatically tracks the active playing track via [audioHandlerProvider]
/// or maps the current track in the given [tracks] list to its corresponding index.
class JumpToCurrentTrackConsumerFab extends ConsumerWidget {
  final ScrollController scrollController;
  final List<Track>? tracks;
  final int? fallbackIndex;
  final double itemExtent;
  final double leadingOffset;
  final double Function(int index)? customOffsetBuilder;
  final String label;
  final Widget? icon;
  final bool showDirectionalIndicator;
  final double targetAlignment;
  final Duration animationDuration;
  final Curve animationCurve;
  final double visibilityBuffer;
  final VoidCallback? onJump;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const JumpToCurrentTrackConsumerFab({
    super.key,
    required this.scrollController,
    this.tracks,
    this.fallbackIndex,
    this.itemExtent = 64.0,
    this.leadingOffset = 0.0,
    this.customOffsetBuilder,
    this.label = 'Jump to playing track',
    this.icon,
    this.showDirectionalIndicator = true,
    this.targetAlignment = 0.5,
    this.animationDuration = const Duration(milliseconds: 400),
    this.animationCurve = Curves.easeInOutCubic,
    this.visibilityBuffer = 24.0,
    this.onJump,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int? resolvedIndex;

    if (tracks != null) {
      final currentTrack = ref.watch(currentTrackProvider).value;
      if (currentTrack != null) {
        final idx = tracks!.indexWhere((t) => t.id == currentTrack.id);
        if (idx != -1) {
          resolvedIndex = idx;
        }
      }
    } else {
      final audioHandler = ref.watch(audioHandlerProvider);
      resolvedIndex = audioHandler.currentIndex;
    }

    resolvedIndex ??= fallbackIndex;

    return JumpToCurrentTrackFab(
      scrollController: scrollController,
      currentTrackIndex: resolvedIndex,
      itemExtent: itemExtent,
      leadingOffset: leadingOffset,
      customOffsetBuilder: customOffsetBuilder,
      label: label,
      icon: icon,
      showDirectionalIndicator: showDirectionalIndicator,
      targetAlignment: targetAlignment,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      visibilityBuffer: visibilityBuffer,
      onJump: onJump,
      padding: padding,
      margin: margin,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
  }
}
