import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../../features/qol/advanced_queue_actions.dart';
import '../../features/qol/queue/save_queue_as_playlist.dart';
import '../../features/qol/queue/smart_bpm_shuffle.dart' hide SharedPreferences;
import '../providers/player_providers.dart';
import '../theme/app_tokens.dart';
import 'animated_music_wave_indicator.dart';
import 'shared/app_network_image.dart';
import 'shared/app_surface.dart';

class QueueBottomSheet extends ConsumerStatefulWidget {
  const QueueBottomSheet({super.key});

  @override
  ConsumerState<QueueBottomSheet> createState() => _QueueBottomSheetState();
}

class _QueueBottomSheetState extends ConsumerState<QueueBottomSheet> {
  bool _isSearchOpen = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final queueAsync = ref.watch(queueProvider);
    final currentTrack = ref.watch(currentTrackProvider).value;
    final audioHandler = ref.watch(audioHandlerProvider);

    final queue = queueAsync.value ?? [];
    final currentIndex = audioHandler.currentIndex;

    final upcomingTracks = (currentIndex >= 0 && currentIndex < queue.length - 1)
        ? queue.sublist(currentIndex + 1)
        : (currentIndex < 0 ? queue : <Track>[]);

    final totalRemainingMs = upcomingTracks.fold<int>(
      0,
      (sum, t) => sum + t.duration.inMilliseconds,
    );
    final remainingMinutes = totalRemainingMs ~/ 60000;
    final finishTime = DateTime.now().add(Duration(milliseconds: totalRemainingMs));
    final finishTimeStr =
        '${finishTime.hour > 12 ? finishTime.hour - 12 : (finishTime.hour == 0 ? 12 : finishTime.hour)}:${finishTime.minute.toString().padLeft(2, '0')} ${finishTime.hour >= 12 ? 'PM' : 'AM'}';

    final filteredQueue = _searchQuery.trim().isEmpty
        ? queue
        : queue.where((t) {
            final q = _searchQuery.toLowerCase();
            return t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q) ||
                (t.album?.toLowerCase().contains(q) ?? false);
          }).toList();

    return AppSurface(
      withBlur: true,
      color: tokens.isGlass ? tokens.glassSurface : tokens.surfaceElevated,
      borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusXl)),
      border: Border(
        top: BorderSide(
          color: tokens.isGlass
              ? tokens.glassBorder
              : Colors.white.withValues(alpha: 0.08),
          width: 1.0,
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

          // Header with rich QoL actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(
                  'Play Queue',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (upcomingTracks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                      border: Border.all(
                        color: tokens.accent.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$remainingMinutes min left • Ends at $finishTimeStr',
                      style: TextStyle(
                        color: tokens.accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),

                // Search in Queue Toggle
                IconButton(
                  icon: Icon(
                    _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                    color: _isSearchOpen ? tokens.accent : tokens.textSecondary,
                    size: 20,
                  ),
                  tooltip: _isSearchOpen ? 'Close Search' : 'Search Queue',
                  onPressed: () {
                    setState(() {
                      _isSearchOpen = !_isSearchOpen;
                      if (!_isSearchOpen) {
                        _searchController.clear();
                        _searchQuery = '';
                      }
                    });
                  },
                ),

                // DJ Smart BPM Shuffle
                IconButton(
                  icon: Icon(Icons.shuffle_on_rounded, color: tokens.accent, size: 20),
                  tooltip: 'DJ Smart BPM Shuffle',
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => const SmartShuffleSettingsModal(),
                    );
                  },
                ),

                // Save Queue as Playlist
                IconButton(
                  icon: Icon(Icons.playlist_add_check_rounded, color: tokens.textSecondary, size: 20),
                  tooltip: 'Save Queue as Playlist',
                  onPressed: queue.isNotEmpty
                      ? () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => SaveQueueDialog(
                              initialTracks: queue,
                              currentIndex: currentIndex,
                            ),
                          );
                        }
                      : null,
                ),

                // Clear Menu
                if (queue.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: tokens.textSecondary, size: 20),
                    tooltip: 'Queue Options',
                    onSelected: (val) {
                      if (val == 'clear_all') {
                        audioHandler.clearQueue();
                        Navigator.of(context).pop();
                      } else if (val == 'clear_upcoming') {
                        AdvancedQueueController.clearUpcomingQueue(ref);
                      } else if (val == 'shuffle_upcoming') {
                        AdvancedQueueController.shuffleUpcomingOnly(ref);
                      } else if (val == 'reverse_upcoming') {
                        AdvancedQueueController.reverseUpcomingOnly(ref);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'shuffle_upcoming',
                        child: Row(
                          children: [
                            Icon(Icons.shuffle_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Shuffle Upcoming'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reverse_upcoming',
                        child: Row(
                          children: [
                            Icon(Icons.swap_vert_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Reverse Upcoming'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'clear_upcoming',
                        child: Row(
                          children: [
                            Icon(Icons.cleaning_services_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Clear Upcoming Only'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'clear_all',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Clear Entire Queue', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // In-Queue Search TextField
          if (_isSearchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Filter queue by title or artist...',
                  hintStyle: TextStyle(color: tokens.textMuted, fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: tokens.accent),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: tokens.surfaceHighlight.withValues(alpha: 0.3),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                    borderSide: BorderSide(color: tokens.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                    borderSide: BorderSide(color: tokens.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                    borderSide: BorderSide(color: tokens.accent),
                  ),
                ),
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
                      // Now Playing Section (only if not filtering)
                      if (currentTrack != null && _searchQuery.isEmpty) ...[
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
                                child: AppNetworkImage(
                                  imageUrl: currentTrack.coverUrl,
                                  width: 44,
                                  height: 44,
                                  cacheWidth: 132,
                                  cacheHeight: 132,
                                  fit: BoxFit.cover,
                                  placeholderIcon: Icons.music_note_rounded,
                                ),
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
                              trailing: AnimatedMusicWaveIndicator(
                                isPlaying: ref.watch(isPlayingProvider),
                                color: tokens.accent,
                                size: 20,
                                barCount: 4,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Up Next Section Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'Filtered Results (${filteredQueue.length} tracks)'
                                : 'Up Next (Drag to reorder)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                      // Reorderable Queue Items or Filtered List
                      if (_searchQuery.isNotEmpty)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final track = filteredQueue[index];
                              final originalIndex = queue.indexOf(track);
                              final isCurrent = originalIndex == currentIndex;

                              return _buildQueueTile(
                                context,
                                tokens,
                                audioHandler,
                                track,
                                originalIndex >= 0 ? originalIndex : index,
                                isCurrent,
                              );
                            },
                            childCount: filteredQueue.length,
                          ),
                        )
                      else
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
                              child: _buildQueueTile(
                                context,
                                tokens,
                                audioHandler,
                                track,
                                index,
                                isCurrent,
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

  Widget _buildQueueTile(
    BuildContext context,
    AppTokens tokens,
    dynamic audioHandler,
    Track track,
    int index,
    bool isCurrent,
  ) {
    return ListTile(
      onTap: () {
        audioHandler.skipToQueueItem(index);
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: AppNetworkImage(
          imageUrl: track.coverUrl,
          width: 40,
          height: 40,
          cacheWidth: 120,
          cacheHeight: 120,
          fit: BoxFit.cover,
          placeholderIcon: Icons.music_note_rounded,
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? tokens.accent : tokens.textPrimary,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
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
            tooltip: 'Remove from queue',
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
    );
  }
}
