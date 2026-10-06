import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import '../providers/player_providers.dart';
import '../theme/app_tokens.dart';
import 'bouncing_scale_button.dart';

class LyricsView extends ConsumerStatefulWidget {
  final Track track;
  final VoidCallback? onClose;

  const LyricsView({
    super.key,
    required this.track,
    this.onClose,
  });

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index, int totalLines) {
    if (_userIsScrolling || !_scrollController.hasClients || index < 0) return;

    const itemHeight = 56.0;
    final targetOffset = (index * itemHeight) - 150.0;
    final clamped = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  int _findActiveLineIndex(List<LyricLine> lines, Duration currentPosition) {
    if (lines.isEmpty) return -1;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (currentPosition >= lines[i].timestamp) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lyricsAsync = ref.watch(trackLyricsProvider(widget.track));
    final positionAsync = ref.watch(positionStreamProvider);
    final currentPos = positionAsync.value ?? Duration.zero;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE6141414),
            borderRadius: BorderRadius.circular(tokens.radiusXl),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              // Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.lyrics_rounded, color: tokens.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lyrics',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            '${widget.track.title} • ${widget.track.artist}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onClose != null)
                      BouncingScaleButton(
                        scaleFactor: 0.9,
                        onTap: widget.onClose!,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: tokens.textSecondary,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),

              // Content
              Expanded(
                child: lyricsAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: tokens.accent,
                      strokeWidth: 2.5,
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      'Failed to load lyrics: $err',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  ),
                  data: (lyrics) {
                    if (lyrics == null ||
                        (!lyrics.isSynced &&
                            (lyrics.plainLyrics == null ||
                                lyrics.plainLyrics!.isEmpty))) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.music_off_rounded,
                              color: tokens.textMuted,
                              size: 44,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No lyrics available for this track',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // If not synced, display plain lyrics
                    if (!lyrics.isSynced) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          lyrics.plainLyrics ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.8,
                            color: tokens.textPrimary,
                          ),
                        ),
                      );
                    }

                    // Synced karaoke scrolling lyrics
                    final lines = lyrics.lines;
                    final activeIndex = _findActiveLineIndex(lines, currentPos);

                    if (activeIndex != _lastActiveIndex) {
                      _lastActiveIndex = activeIndex;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToIndex(activeIndex, lines.length);
                      });
                    }

                    return NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollStartNotification &&
                            notification.dragDetails != null) {
                          _userIsScrolling = true;
                        } else if (notification is ScrollEndNotification) {
                          Future.delayed(const Duration(seconds: 3), () {
                            if (mounted) _userIsScrolling = false;
                          });
                        }
                        return false;
                      },
                      child: RepaintBoundary(
                        child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 60,
                        ),
                        itemCount: lines.length,
                        itemBuilder: (context, index) {
                          final line = lines[index];
                          final isActive = index == activeIndex;

                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref.read(audioHandlerProvider).seek(line.timestamp);
                            },
                            borderRadius: BorderRadius.circular(tokens.radiusSm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  fontSize: isActive ? 22 : 16,
                                  fontWeight:
                                      isActive ? FontWeight.w700 : FontWeight.w400,
                                  color: isActive
                                      ? tokens.accent
                                      : tokens.textPrimary.withValues(alpha: 0.28),
                                  height: 1.4,
                                  letterSpacing: isActive ? -0.3 : 0.0,
                                ),
                                child: Text(line.text),
                              ),
                            ),
                          );
                        },
                      ),
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
  }
}
