import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player/softify_audio_handler.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';

/// Configurable volume step percentage for mouse wheel adjustments.
///
/// Typical preset values:
/// - `0.01` (1% per notch)
/// - `0.02` (2% per notch)
/// - `0.05` (5% per notch, default)
/// - `0.10` (10% per notch)
final volumeScrollStepProvider = StateProvider<double>((ref) => 0.05);

/// Commonly used volume step presets for mouse wheel volume adjustment.
abstract final class VolumeScrollSteps {
  /// 1% volume change per scroll notch.
  static const double onePercent = 0.01;

  /// 2% volume change per scroll notch.
  static const double twoPercent = 0.02;

  /// 5% volume change per scroll notch (standard default).
  static const double fivePercent = 0.05;

  /// 10% volume change per scroll notch.
  static const double tenPercent = 0.10;
}

/// A desktop Quality-of-Life wrapper widget that listens to mouse wheel scroll events
/// over the bottom player bar to smoothly adjust playback volume and display a
/// lightweight, frosted glass floating HUD volume indicator.
///
/// Features:
/// - Listens for [PointerScrollEvent] signals over the player bar.
/// - Increases volume on wheel up (`dy < 0`) and decreases volume on wheel down (`dy > 0`).
/// - Adjusts volume smoothly in configurable increments (e.g. 1% or 5%) via [volumeScrollStepProvider].
/// - Displays a modern, non-blocking floating HUD volume pill directly above the player bar.
/// - Passthrough translucent hit testing ensures buttons, sliders, and controls underneath
///   remain fully responsive to clicks and drags.
/// - Automatically fades out and cleans up the HUD toast after a brief duration.
class DesktopVolumeScrollListener extends ConsumerStatefulWidget {
  const DesktopVolumeScrollListener({
    super.key,
    required this.child,
    this.enabled = true,
    this.step,
    this.showFloatingHud = true,
    this.invertScroll = false,
    this.onVolumeChanged,
    this.hudDismissDuration = const Duration(milliseconds: 1400),
  });

  /// The child widget to wrap (such as the persistent desktop bottom player bar).
  final Widget child;

  /// Whether mouse wheel volume scrolling is enabled.
  final bool enabled;

  /// Optional override for the volume step size per notch (e.g. 0.01 for 1% or 0.05 for 5%).
  /// If null, the active value in [volumeScrollStepProvider] is used.
  final double? step;

  /// Whether to display the floating HUD overlay toast when adjusting volume via scroll wheel.
  final bool showFloatingHud;

  /// Whether to invert the scroll direction (default: false, wheel up increases volume).
  final bool invertScroll;

  /// Optional callback invoked whenever volume changes via scroll wheel.
  final ValueChanged<double>? onVolumeChanged;

  /// How long the floating HUD indicator stays visible after the last scroll event.
  final Duration hudDismissDuration;

  @override
  ConsumerState<DesktopVolumeScrollListener> createState() =>
      _DesktopVolumeScrollListenerState();
}

class _DesktopVolumeScrollListenerState
    extends ConsumerState<DesktopVolumeScrollListener>
    with SingleTickerProviderStateMixin {
  final GlobalKey _rootKey = GlobalKey();
  final ValueNotifier<double> _volumeNotifier = ValueNotifier<double>(1.0);

  late final AnimationController _hudAnimController;
  late final Animation<double> _hudAnimation;

  OverlayEntry? _overlayEntry;
  Timer? _dismissTimer;
  bool _isHudVisible = false;
  bool _isFallbackHudActive = false;

  double _currentVolume = 1.0;
  double _accumulatedDelta = 0.0;
  DateTime? _lastScrollTime;

  @override
  void initState() {
    super.initState();

    _hudAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _hudAnimation = CurvedAnimation(
      parent: _hudAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _removeOverlay();
    _hudAnimController.dispose();
    _volumeNotifier.dispose();
    super.dispose();
  }

  /// Removes the active overlay entry if currently mounted.
  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  /// Handles incoming pointer signals, filtering for vertical mouse wheel scroll events.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final dy = event.scrollDelta.dy;
    if (dy == 0) return;

    final now = DateTime.now();
    final isNewGesture = _lastScrollTime == null ||
        now.difference(_lastScrollTime!).inMilliseconds > 250;
    _lastScrollTime = now;

    if (isNewGesture) {
      _accumulatedDelta = 0.0;
    }

    _accumulatedDelta += dy;

    // Standard logical scroll notch on Linux/Windows/macOS is ~20px.
    const double notchThreshold = 20.0;
    int steps = 0;

    if (isNewGesture && _accumulatedDelta.abs() < notchThreshold) {
      // Immediate response on the very first notch of a new scroll gesture
      steps = dy < 0 ? 1 : -1;
      _accumulatedDelta = 0.0;
    } else if (_accumulatedDelta.abs() >= notchThreshold) {
      final int count = (_accumulatedDelta.abs() / notchThreshold).floor();
      final sign = _accumulatedDelta < 0 ? 1 : -1;
      _accumulatedDelta -=
          (_accumulatedDelta > 0 ? 1.0 : -1.0) * (count * notchThreshold);
      steps = sign * count;
    }

    if (widget.invertScroll) {
      steps = -steps;
    }

    if (steps != 0) {
      _applyVolumeStep(steps);
    }
  }

  /// Calculates and applies the volume delta to the audio handler.
  void _applyVolumeStep(int steps) {
    final double stepSize =
        widget.step ?? ref.read(volumeScrollStepProvider);

    // Prefer current local volume when HUD is active so rapid successive ticks
    // don't read stale stream states before asynchronous propagation.
    double baseVol;
    if (_isHudVisible) {
      baseVol = _currentVolume;
    } else {
      try {
        baseVol = ref.read(volumeStreamProvider).value ?? 1.0;
      } catch (_) {
        try {
          baseVol = ref.read(audioHandlerProvider).volume;
        } catch (_) {
          baseVol = _currentVolume;
        }
      }
    }

    final targetVol = (baseVol + (steps * stepSize)).clamp(0.0, 1.0);
    // Round to 4 decimal places to prevent IEEE-754 precision drift
    final roundedVol = (targetVol * 10000).round() / 10000.0;

    _currentVolume = roundedVol;
    _volumeNotifier.value = roundedVol;

    // Dispatch target volume to SoftifyAudioHandler
    try {
      final SoftifyAudioHandler audioHandler = ref.read(audioHandlerProvider);
      audioHandler.setVolume(roundedVol);
    } catch (e) {
      debugPrint('[DesktopVolumeScrollListener] setVolume error: $e');
    }

    widget.onVolumeChanged?.call(roundedVol);

    if (widget.showFloatingHud) {
      _triggerFloatingHud(roundedVol);
    }
  }

  /// Shows or updates the floating HUD overlay indicator.
  void _triggerFloatingHud(double volume) {
    _isHudVisible = true;
    _dismissTimer?.cancel();

    if (_overlayEntry == null) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null) {
        _overlayEntry = OverlayEntry(
          builder: (overlayContext) {
            return _FloatingVolumeHudOverlay(
              anchorKey: _rootKey,
              volumeNotifier: _volumeNotifier,
              animation: _hudAnimation,
            );
          },
        );
        overlay.insert(_overlayEntry!);
      } else {
        // Fallback to inline Stack overlay if no global Navigator overlay is available
        if (!_isFallbackHudActive && mounted) {
          setState(() {
            _isFallbackHudActive = true;
          });
        }
      }
    }

    _hudAnimController.forward();

    _dismissTimer = Timer(widget.hudDismissDuration, () {
      if (!mounted) return;
      _hudAnimController.reverse().then((_) {
        if (mounted) {
          _removeOverlay();
          _isHudVisible = false;
          if (_isFallbackHudActive) {
            setState(() {
              _isFallbackHudActive = false;
            });
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep local volume in sync with external volume changes (e.g. keyboard shortcuts/sliders)
    ref.listen<AsyncValue<double>>(volumeStreamProvider, (_, next) {
      final vol = next.value;
      if (vol != null && !_isHudVisible) {
        _currentVolume = vol;
        _volumeNotifier.value = vol;
      }
    });

    final childWidget = Listener(
      key: _rootKey,
      behavior: HitTestBehavior.translucent,
      onPointerSignal: widget.enabled ? _onPointerSignal : null,
      child: widget.child,
    );

    if (_isFallbackHudActive) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          childWidget,
          Positioned(
            top: -56,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _hudAnimation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.90, end: 1.0)
                      .animate(_hudAnimation),
                  child: ValueListenableBuilder<double>(
                    valueListenable: _volumeNotifier,
                    builder: (context, vol, _) {
                      return _VolumeToastCard(volume: vol);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return childWidget;
  }
}

/// Floating HUD Overlay Layer positioned above the anchor widget.
class _FloatingVolumeHudOverlay extends StatelessWidget {
  const _FloatingVolumeHudOverlay({
    required this.anchorKey,
    required this.volumeNotifier,
    required this.animation,
  });

  final GlobalKey anchorKey;
  final ValueNotifier<double> volumeNotifier;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    const hudWidth = 240.0;
    const hudHeight = 48.0;

    double? left;
    double? top;
    double? bottom;

    final renderBox =
        anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize && renderBox.attached) {
      final globalPos = renderBox.localToGlobal(Offset.zero);
      final boxSize = renderBox.size;

      // Horizontally center above the anchor widget
      left = (globalPos.dx + (boxSize.width - hudWidth) / 2).clamp(
        16.0,
        (screenSize.width - hudWidth - 16.0).clamp(16.0, double.infinity),
      );

      // Float 14px above the anchor widget's top edge
      final computedTop = globalPos.dy - hudHeight - 14.0;
      if (computedTop >= 16.0) {
        top = computedTop;
      } else {
        bottom = 106.0;
      }
    } else {
      left = (screenSize.width - hudWidth) / 2;
      bottom = 106.0;
    }

    return Positioned(
      left: left,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.90, end: 1.0).animate(animation),
            child: ValueListenableBuilder<double>(
              valueListenable: volumeNotifier,
              builder: (context, vol, _) {
                return _VolumeToastCard(volume: vol);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight, frosted glass volume indicator pill displaying volume icon,
/// progress bar, and tabular percentage.
class _VolumeToastCard extends StatelessWidget {
  const _VolumeToastCard({
    required this.volume,
  });

  final double volume;

  IconData _iconForVolume(double vol) {
    if (vol <= 0.0001) {
      return Icons.volume_off_rounded;
    } else if (vol < 0.25) {
      return Icons.volume_mute_rounded;
    } else if (vol < 0.65) {
      return Icons.volume_down_rounded;
    } else {
      return Icons.volume_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final percent = (volume * 100).round();
    final isMuted = volume <= 0.0001;

    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 240,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  _iconForVolume(volume),
                  size: 20,
                  color: isMuted ? tokens.textSecondary : tokens.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 5,
                      child: Stack(
                        children: [
                          Container(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          FractionallySizedBox(
                            widthFactor: volume.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isMuted
                                    ? tokens.textSecondary
                                    : tokens.accent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 42,
                  child: Text(
                    '$percent%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
