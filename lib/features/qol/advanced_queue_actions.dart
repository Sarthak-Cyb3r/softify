import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/bouncing_scale_button.dart';

/// Advanced Queue Controller providing granular queue modifications:
/// - Play Next (inserts song immediately following current track)
/// - Clear Upcoming (wipes pending songs while current track continues playing)
/// - Shuffle Upcoming (shuffles upcoming tracks without disrupting current track or history)
/// - Reverse Upcoming (inverts upcoming tracks order)
class AdvancedQueueController {
  const AdvancedQueueController();

  /// Inserts [track] immediately after the currently playing song in the queue.
  static Future<void> playNext(WidgetRef ref, Track track) async {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.playNext(track);
  }

  /// Removes all upcoming songs while keeping currently playing song active.
  static Future<void> clearUpcomingQueue(WidgetRef ref) async {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.clearUpcomingQueue();
  }

  /// Shuffles upcoming tracks without touching the currently playing track.
  static Future<void> shuffleUpcomingOnly(WidgetRef ref) async {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.shuffleUpcomingOnly();
  }

  /// Reverses upcoming tracks without touching the currently playing track.
  static Future<void> reverseUpcomingOnly(WidgetRef ref) async {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.reverseUpcomingOnly();
  }

  /// Alias for [reverseUpcomingOnly].
  static Future<void> reverseUpcomingQueue(WidgetRef ref) =>
      reverseUpcomingOnly(ref);

  /// Helper to get upcoming tracks count from Riverpod state.
  static int getUpcomingCount(WidgetRef ref) {
    final queue = ref.read(queueProvider).value ?? const [];
    final audioHandler = ref.read(audioHandlerProvider);
    final currentIndex = audioHandler.currentIndex;
    if (currentIndex >= 0 && currentIndex < queue.length - 1) {
      return queue.length - (currentIndex + 1);
    } else if (currentIndex < 0) {
      return queue.length;
    }
    return 0;
  }

  /// Helper to get upcoming tracks list from Riverpod state.
  static List<Track> getUpcomingTracks(WidgetRef ref) {
    final queue = ref.read(queueProvider).value ?? const [];
    final audioHandler = ref.read(audioHandlerProvider);
    final currentIndex = audioHandler.currentIndex;
    if (currentIndex >= 0 && currentIndex < queue.length - 1) {
      return queue.sublist(currentIndex + 1);
    } else if (currentIndex < 0) {
      return List<Track>.from(queue);
    }
    return const [];
  }
}

/// Extension enabling instance-style access on [AdvancedQueueController].
extension AdvancedQueueControllerInstanceMethods on AdvancedQueueController {
  Future<void> playNext(WidgetRef ref, Track track) =>
      AdvancedQueueController.playNext(ref, track);

  Future<void> clearUpcomingQueue(WidgetRef ref) =>
      AdvancedQueueController.clearUpcomingQueue(ref);

  Future<void> shuffleUpcomingOnly(WidgetRef ref) =>
      AdvancedQueueController.shuffleUpcomingOnly(ref);

  Future<void> reverseUpcomingOnly(WidgetRef ref) =>
      AdvancedQueueController.reverseUpcomingOnly(ref);

  Future<void> reverseUpcomingQueue(WidgetRef ref) =>
      AdvancedQueueController.reverseUpcomingQueue(ref);

  int getUpcomingCount(WidgetRef ref) =>
      AdvancedQueueController.getUpcomingCount(ref);

  List<Track> getUpcomingTracks(WidgetRef ref) =>
      AdvancedQueueController.getUpcomingTracks(ref);
}

/// Riverpod provider for [AdvancedQueueController].
final advancedQueueControllerProvider =
    Provider<AdvancedQueueController>((ref) {
  return const AdvancedQueueController();
});

/// Quick action bar widget designed for the Queue bottom sheet.
/// Provides intuitive, tactile buttons for:
/// - Clear (removes upcoming tracks while preserving current song)
/// - Shuffle (shuffles upcoming tracks in-place)
/// - Reverse (reverses order of upcoming tracks)
class QueueQuickActionsBar extends ConsumerWidget {
  final VoidCallback? onClear;
  final VoidCallback? onShuffle;
  final VoidCallback? onReverse;
  final EdgeInsetsGeometry? padding;
  final bool showFeedback;

  const QueueQuickActionsBar({
    super.key,
    this.onClear,
    this.onShuffle,
    this.onReverse,
    this.padding,
    this.showFeedback = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final queueAsync = ref.watch(queueProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    final queue = queueAsync.value ?? const [];
    final currentIndex = audioHandler.currentIndex;

    final int upcomingCount =
        (currentIndex >= 0 && currentIndex < queue.length - 1)
            ? queue.length - (currentIndex + 1)
            : (currentIndex < 0 ? queue.length : 0);

    final bool canClear = upcomingCount > 0;
    final bool canShuffle = upcomingCount > 1;
    final bool canReverse = upcomingCount > 1;

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.playlist_remove_rounded,
              label: upcomingCount > 0 ? 'Clear ($upcomingCount)' : 'Clear',
              isEnabled: canClear,
              tokens: tokens,
              onTap: () async {
                if (onClear != null) {
                  onClear!();
                  return;
                }
                HapticFeedback.lightImpact();
                await AdvancedQueueController.clearUpcomingQueue(ref);
                if (context.mounted && showFeedback) {
                  _showFeedback(context, 'Cleared upcoming tracks');
                }
              },
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.shuffle_rounded,
              label: 'Shuffle',
              isEnabled: canShuffle,
              tokens: tokens,
              onTap: () async {
                if (onShuffle != null) {
                  onShuffle!();
                  return;
                }
                HapticFeedback.lightImpact();
                await AdvancedQueueController.shuffleUpcomingOnly(ref);
                if (context.mounted && showFeedback) {
                  _showFeedback(context, 'Shuffled upcoming tracks');
                }
              },
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.swap_vert_rounded,
              label: 'Reverse',
              isEnabled: canReverse,
              tokens: tokens,
              onTap: () async {
                if (onReverse != null) {
                  onReverse!();
                  return;
                }
                HapticFeedback.lightImpact();
                await AdvancedQueueController.reverseUpcomingOnly(ref);
                if (context.mounted && showFeedback) {
                  _showFeedback(context, 'Reversed upcoming tracks');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedback(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: AppTheme.fontUi,
            fontWeight: FontWeight.w600,
            fontSize: 13.0,
          ),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isEnabled;
  final AppTokens tokens;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isEnabled,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isEnabled
        ? tokens.textPrimary
        : tokens.textMuted.withValues(alpha: 0.5);

    final iconColor = isEnabled
        ? tokens.accent
        : tokens.textMuted.withValues(alpha: 0.4);

    final backgroundColor = isEnabled
        ? (tokens.isGlass
            ? tokens.glassSurface
            : tokens.surfaceHighlight.withValues(alpha: 0.7))
        : tokens.surfaceElevated.withValues(alpha: 0.2);

    final borderColor = isEnabled
        ? (tokens.isGlass
            ? tokens.glassBorder
            : Colors.white.withValues(alpha: 0.08))
        : Colors.white.withValues(alpha: 0.03);

    return BouncingScaleButton(
      onTap: isEnabled ? onTap : null,
      scaleDown: 0.96,
      minTouchTarget: 36.0,
      child: AnimatedContainer(
        duration: tokens.motionQuick,
        height: 36.0,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15.0,
              color: iconColor,
            ),
            const SizedBox(width: 5.0),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: foregroundColor,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
