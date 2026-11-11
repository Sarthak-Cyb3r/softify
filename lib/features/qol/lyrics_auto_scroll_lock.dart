import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/bouncing_scale_button.dart';

/// StateNotifier that manages whether lyrics auto-scrolling is temporarily locked/paused.
///
/// When a user manually scrolls or touches the lyrics view, auto-scrolling locks
/// so the view doesn't abruptly jump back while they are reading.
/// It can automatically resume after an optional timeout or immediately when
/// the user taps the "Resume Auto-Scroll" overlay pill button.
class LyricsAutoScrollLockNotifier extends StateNotifier<bool> {
  Timer? _autoResumeTimer;

  LyricsAutoScrollLockNotifier({bool initialLocked = false}) : super(initialLocked);

  /// Whether auto-scroll is currently locked/paused.
  bool get isLocked => state;

  /// Locks auto-scroll. If [autoResumeAfter] is provided, an automatic timer
  /// will call [resume] when the duration expires.
  void lock({Duration? autoResumeAfter}) {
    _autoResumeTimer?.cancel();
    _autoResumeTimer = null;
    state = true;

    if (autoResumeAfter != null) {
      _autoResumeTimer = Timer(autoResumeAfter, () {
        if (mounted) {
          resume();
        }
      });
    }
  }

  /// Convenience handler to invoke on manual scroll interactions.
  /// Locks auto-scroll and schedules an automatic resume after [autoResumeAfter].
  void userScrolled({Duration autoResumeAfter = const Duration(seconds: 5)}) {
    lock(autoResumeAfter: autoResumeAfter);
  }

  /// Unlocks lyrics auto-scrolling and cancels any pending auto-resume timer.
  void resume() {
    _autoResumeTimer?.cancel();
    _autoResumeTimer = null;
    if (state) {
      state = false;
    }
  }

  /// Alias for [resume].
  void unlock() => resume();

  /// Toggles the locked state.
  void toggle() {
    if (state) {
      resume();
    } else {
      lock();
    }
  }

  @override
  void dispose() {
    _autoResumeTimer?.cancel();
    super.dispose();
  }
}

/// Global Riverpod provider tracking whether lyrics auto-scroll is temporarily locked.
final lyricsAutoScrollLockProvider =
    StateNotifierProvider<LyricsAutoScrollLockNotifier, bool>((ref) {
  return LyricsAutoScrollLockNotifier();
});

/// Parameterized family provider for per-track or scoped scroll lock state.
final scopedLyricsAutoScrollLockProvider =
    StateNotifierProvider.family<LyricsAutoScrollLockNotifier, bool, String>(
        (ref, scopeId) {
  return LyricsAutoScrollLockNotifier();
});

/// A floating pill button overlay that appears when lyrics auto-scroll is locked.
///
/// Tapping the button calls `resume()` on the provider to unlock auto-scroll and
/// invokes the [onSnapToActive] callback so the lyrics view immediately snaps back
/// to the currently active lyric line.
///
/// Can be used as a standalone widget inside a [Stack] or wrapped around a [child] widget.
class LyricsScrollLockOverlay extends ConsumerWidget {
  /// Callback triggered when the resume button is tapped to snap back to the active lyric line.
  final VoidCallback? onSnapToActive;

  /// Optional child to wrap inside a Stack. If null, renders only the overlay pill.
  final Widget? child;

  /// Alignment of the floating pill button (defaults to [Alignment.bottomCenter]).
  final Alignment alignment;

  /// Margin around the floating pill button.
  final EdgeInsetsGeometry margin;

  /// Text displayed inside the pill button.
  final String label;

  /// Icon displayed alongside the label.
  final IconData icon;

  /// Custom accent color override. If null, falls back to AppTokens accent colors.
  final Color? accentColor;

  /// Optional override for locked state. If provided, overrides provider value.
  final bool? isLocked;

  /// The provider to listen to and control (defaults to [lyricsAutoScrollLockProvider]).
  final StateNotifierProvider<LyricsAutoScrollLockNotifier, bool>? provider;

  /// Animation duration for entrance and exit transitions.
  final Duration animationDuration;

  const LyricsScrollLockOverlay({
    super.key,
    this.onSnapToActive,
    this.child,
    this.alignment = Alignment.bottomCenter,
    this.margin = const EdgeInsets.only(bottom: 24.0),
    this.label = 'Resume Auto-Scroll',
    this.icon = Icons.vertical_align_center_rounded,
    this.accentColor,
    this.isLocked,
    this.provider,
    this.animationDuration = const Duration(milliseconds: 250),
  });

  void _handleResume(WidgetRef ref) {
    HapticFeedback.lightImpact();
    final notifier = provider != null
        ? ref.read(provider!.notifier)
        : ref.read(lyricsAutoScrollLockProvider.notifier);
    notifier.resume();
    onSnapToActive?.call();
  }

  Widget _buildPill(
    BuildContext context,
    WidgetRef ref,
    AppTokens tokens,
    bool locked,
  ) {
    final effectiveAccent = accentColor ??
        (tokens.isGlass ? tokens.accentCyan : tokens.accent);

    return Align(
      alignment: alignment,
      child: Padding(
        padding: margin,
        child: IgnorePointer(
          ignoring: !locked,
          child: AnimatedSlide(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            offset: locked ? Offset.zero : const Offset(0.0, 0.45),
            child: AnimatedOpacity(
              duration: animationDuration,
              curve: Curves.easeOutCubic,
              opacity: locked ? 1.0 : 0.0,
              child: BouncingScaleButton(
                scaleFactor: 0.94,
                onTap: () => _handleResume(ref),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spaceMd,
                    vertical: tokens.spaceSm + 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: effectiveAccent,
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    boxShadow: [
                      BoxShadow(
                        color: effectiveAccent.withValues(alpha: 0.38),
                        blurRadius: 18.0,
                        offset: const Offset(0.0, 5.0),
                      ),
                    ],
                    border: tokens.isGlass
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1.0,
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: Colors.black,
                        size: 16.0,
                      ),
                      SizedBox(width: tokens.spaceSm),
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontUi,
                          color: Colors.black,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final bool locked = isLocked ??
        (provider != null
            ? ref.watch(provider!)
            : ref.watch(lyricsAutoScrollLockProvider));

    if (child != null) {
      return Stack(
        alignment: alignment,
        children: [
          child!,
          _buildPill(context, ref, tokens, locked),
        ],
      );
    }

    return _buildPill(context, ref, tokens, locked);
  }
}

/// Helper NotificationListener widget to automatically pause lyrics auto-scroll
/// whenever user scrolls through a lyrics view.
class LyricsAutoScrollLockListener extends ConsumerWidget {
  final Widget child;
  final Duration autoResumeAfter;
  final StateNotifierProvider<LyricsAutoScrollLockNotifier, bool>? provider;

  const LyricsAutoScrollLockListener({
    super.key,
    required this.child,
    this.autoResumeAfter = const Duration(seconds: 5),
    this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction != ScrollDirection.idle) {
          final notifier = provider != null
              ? ref.read(provider!.notifier)
              : ref.read(lyricsAutoScrollLockProvider.notifier);
          notifier.userScrolled(autoResumeAfter: autoResumeAfter);
        }
        return false;
      },
      child: child,
    );
  }
}
