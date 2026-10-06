import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import '../theme/app_tokens.dart';

class QueueBottomSheet extends ConsumerWidget {
  const QueueBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final queueAsync = ref.watch(queueProvider);
    final currentTrack = ref.watch(currentTrackProvider).value;
    final audioHandler = ref.watch(audioHandlerProvider);

    final queue = queueAsync.value ?? [];
    final currentIndex = audioHandler.currentIndex;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusXl)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(tokens.radiusFull),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Play Queue',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: tokens.textPrimary,
                  ),
                ),
                if (queue.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      audioHandler.clearQueue();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: tokens.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),

          // Queue Content
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: Text(
                      'Queue is empty',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      // Now Playing Section
                      if (currentTrack != null) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Text(
                              'Now Playing',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: tokens.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.surfaceHighlight.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(tokens.radiusMd),
                            ),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(tokens.radiusSm),
                                child: currentTrack.coverUrl != null
                                    ? Image.network(
                                        currentTrack.coverUrl!,
                                        width: 44,
                                        height: 44,
                                        cacheWidth: 132,
                                        cacheHeight: 132,
                                        gaplessPlayback: true,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _fallbackCover(tokens),
                                      )
                                    : _fallbackCover(tokens),
                              ),
                              title: Text(
                                currentTrack.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                currentTrack.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Icon(
                                Icons.graphic_eq_rounded,
                                color: tokens.accent,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Up Next Section Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Text(
                            'Up Next (Drag to reorder)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                      // Reorderable Queue Items
                      SliverReorderableList(
                        itemCount: queue.length,
                        onReorderItem: (oldIndex, newIndex) {
                          audioHandler.reorderQueue(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final track = queue[index];
                          final isCurrent = index == currentIndex;

                          return Material(
                            key: ValueKey('${track.id}_$index'),
                            color: isCurrent
                                ? tokens.surfaceHighlight.withValues(alpha: 0.4)
                                : Colors.transparent,
                            child: ListTile(
                              onTap: () {
                                audioHandler.skipToQueueItem(index);
                              },
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(tokens.radiusSm),
                                child: track.coverUrl != null
                                    ? Image.network(
                                        track.coverUrl!,
                                        width: 40,
                                        height: 40,
                                        cacheWidth: 120,
                                        cacheHeight: 120,
                                        gaplessPlayback: true,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _fallbackCover(tokens),
                                      )
                                    : _fallbackCover(tokens),
                              ),
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent
                                      ? tokens.accent
                                      : tokens.textPrimary,
                                  fontWeight: isCurrent
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: tokens.textMuted,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      audioHandler.removeQueueItemAt(index);
                                    },
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: tokens.textMuted,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 36),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackCover(AppTokens tokens) {
    return Container(
      width: 40,
      height: 40,
      color: tokens.surfaceHighlight,
      child: Icon(
        Icons.music_note_rounded,
        color: tokens.textMuted,
        size: 20,
      ),
    );
  }
}
