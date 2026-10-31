import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import '../../data/database/app_database.dart';
import '../../data/lyrics/spotify_lyrics_synchronizer.dart';
import '../../services/lyrics/romanization_service.dart';
import '../providers/player_providers.dart';
import '../providers/settings_providers.dart';
import '../providers/ui_style_provider.dart';
import '../theme/app_theme.dart';
import 'bouncing_scale_button.dart';
import 'shared/app_surface.dart';

enum LyricFontSize {
  compact(17.0, 19.0, 'S'),
  normal(21.0, 23.0, 'M'),
  large(26.0, 28.0, 'L');

  final double inactiveSize;
  final double activeSize;
  final String label;

  const LyricFontSize(this.inactiveSize, this.activeSize, this.label);
}

class LyricsView extends ConsumerStatefulWidget {
  final Track track;
  final VoidCallback? onClose;
  final Color? ambientColor;
  final bool isFullScreen;
  final VoidCallback? onToggleFullscreen;

  const LyricsView({
    super.key,
    required this.track,
    this.onClose,
    this.ambientColor,
    this.isFullScreen = false,
    this.onToggleFullscreen,
  });

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};

  late final Ticker _ticker;
  late final ValueNotifier<Duration> _positionNotifier;
  Duration _lastPlayerPosition = Duration.zero;
  DateTime _lastPlayerReceipt = DateTime.now();
  bool _isPlaying = false;

  // Track-calibrated sync offset (persisted in Drift SQLite)
  int _syncOffsetMs = 0;
  LyricFontSize _lyricFontSize = LyricFontSize.normal;
  bool _romanizeLyrics = false;

  int _lastActiveIndex = -1;
  int _lastScrolledIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollTimer;
  double _filteredPositionMs = 0.0;
  DateTime _lastFrameTime = DateTime.now();

  Duration _calculateEffectivePosition(DateTime now) {
    if (!_isPlaying) {
      final pausedMs = _lastPlayerPosition.inMilliseconds + _syncOffsetMs;
      _filteredPositionMs = pausedMs.toDouble();
      return Duration(milliseconds: pausedMs < 0 ? 0 : pausedMs);
    }
    final elapsed = now.difference(_lastPlayerReceipt);
    final elapsedMs = elapsed.inMilliseconds < 0 ? 0 : elapsed.inMilliseconds;
    // High-precision extrapolation bounded by 10s safeguard to prevent unbound drift while buffering
    final safeElapsedMs = elapsedMs.clamp(0, 10000);
    final targetMs = _lastPlayerPosition.inMilliseconds +
        safeElapsedMs +
        _syncOffsetMs;

    final frameDt = now.difference(_lastFrameTime).inMilliseconds.clamp(1, 100);
    _lastFrameTime = now;

    // Discontinuity snap (>200ms jump e.g. seek, initial load, test playback injection)
    if ((targetMs - _filteredPositionMs).abs() > 200) {
      _filteredPositionMs = targetMs.toDouble();
    } else {
      // 150ms spring relaxation constant for smooth frame-clock sweep playhead
      final alpha = 1.0 - math.exp(-frameDt / 150.0);
      _filteredPositionMs += (targetMs - _filteredPositionMs) * alpha;
    }

    final clampedMs = (widget.track.duration.inMilliseconds > 0)
        ? _filteredPositionMs.round().clamp(0, widget.track.duration.inMilliseconds)
        : (_filteredPositionMs < 0 ? 0 : _filteredPositionMs.round());
    return Duration(milliseconds: clampedMs);
  }

  @override
  void initState() {
    super.initState();
    _positionNotifier = ValueNotifier<Duration>(Duration.zero);
    _loadSavedOffset();

    _ticker = createTicker((elapsed) {
      if (!_isPlaying) return;

      Duration rawPlayerPos;
      try {
        rawPlayerPos = ref.read(audioHandlerProvider).position;
      } catch (_) {
        rawPlayerPos = _lastPlayerPosition;
      }

      final now = DateTime.now();
      if (rawPlayerPos != _lastPlayerPosition && rawPlayerPos >= Duration.zero) {
        _lastPlayerPosition = rawPlayerPos;
        _lastPlayerReceipt = now;
      }

      final effectivePos = _calculateEffectivePosition(now);
      _positionNotifier.value = effectivePos;

      // Only trigger widget tree re-layout when active lyric line advances (Module 52427)
      final lyrics = ref.read(trackLyricsProvider(widget.track)).valueOrNull;
      if (lyrics != null && lyrics.isSynced && lyrics.lines.isNotEmpty) {
        final activeIdx = SpotifyLyricsSynchronizer.findActiveLineIndex(
          lyrics.lines,
          effectivePos,
        );
        if (activeIdx != _lastActiveIndex && mounted) {
          setState(() {
            _lastActiveIndex = activeIdx;
          });
          _scrollToActiveLine(activeIdx);
        }
      }
    });

    try {
      final audioHandler = ref.read(audioHandlerProvider);
      _isPlaying = audioHandler.playbackState.value.playing;
      _lastPlayerPosition = audioHandler.position;
      _lastPlayerReceipt = DateTime.now();
      _positionNotifier.value = _calculateEffectivePosition(_lastPlayerReceipt);
      if (_isPlaying) {
        _ticker.start();
      }
    } catch (_) {}
  }

  Future<void> _loadSavedOffset() async {
    try {
      final db = ref.read(databaseProvider);
      final key = 'lyrics_offset_${widget.track.id}';
      final row = await (db.select(db.settings)..where((t) => t.key.equals(key))).getSingleOrNull();
      if (row != null && mounted) {
        final val = int.tryParse(row.value);
        if (val != null) {
          setState(() {
            _syncOffsetMs = val;
          });
        }
      }

      final fontRow = await (db.select(db.settings)..where((t) => t.key.equals('lyrics_font_size'))).getSingleOrNull();
      if (fontRow != null && mounted) {
        final idx = int.tryParse(fontRow.value);
        if (idx != null && idx >= 0 && idx < LyricFontSize.values.length) {
          setState(() {
            _lyricFontSize = LyricFontSize.values[idx];
          });
        }
      }

      final romRow = await (db.select(db.settings)..where((t) => t.key.equals('lyrics_romanize'))).getSingleOrNull();
      if (romRow != null && mounted) {
        setState(() {
          _romanizeLyrics = romRow.value == 'true';
        });
      }
    } catch (_) {}
  }

  void _cycleFontSize() {
    HapticFeedback.selectionClick();
    final nextIdx = (_lyricFontSize.index + 1) % LyricFontSize.values.length;
    final nextSize = LyricFontSize.values[nextIdx];
    setState(() => _lyricFontSize = nextSize);
    try {
      final db = ref.read(databaseProvider);
      db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: 'lyrics_font_size', value: nextIdx.toString()),
      );
    } catch (_) {}
  }

  void _toggleRomanize() {
    HapticFeedback.selectionClick();
    ref.read(lyricsRomanizeProvider.notifier).toggle();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _positionNotifier.dispose();
    _userScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _lastActiveIndex = -1;
      _lastScrolledIndex = -1;
      _lastPlayerPosition = Duration.zero;
      _lastPlayerReceipt = DateTime.now();
      _positionNotifier.value = Duration.zero;
      _lineKeys.clear();
      _loadSavedOffset();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  GlobalKey _getKeyForIndex(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  void _scrollToActiveLine(int index, {bool force = false}) {
    if ((_userIsScrolling && !force) || !_scrollController.hasClients || index < 0) return;
    if (!force && index == _lastScrolledIndex) return;
    _lastScrolledIndex = index;

    final isAppleLyrics = ref.read(lyricsStyleProvider) == LyricsStyle.appleMusic;
    final scrollAlignment = isAppleLyrics ? 0.16 : 0.35;
    final scrollDuration = Duration(milliseconds: isAppleLyrics ? 380 : 320);

    void performScroll() {
      if (!mounted || (_userIsScrolling && !force) || !_scrollController.hasClients) return;
      final key = _lineKeys[index];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: scrollDuration,
          curve: Curves.easeOutCubic,
          alignment: scrollAlignment,
        );
      } else {
        // Line widget not laid out yet; retry on next post-frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final retryCtx = _lineKeys[index]?.currentContext;
          if (retryCtx != null) {
            Scrollable.ensureVisible(
              retryCtx,
              duration: scrollDuration,
              curve: Curves.easeOutCubic,
              alignment: scrollAlignment,
            );
          }
        });
      }
    }

    if (WidgetsBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks ||
        WidgetsBinding.instance.schedulerPhase ==
            SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => performScroll());
    } else {
      performScroll();
    }
  }

  int _findActiveLineIndex(List<LyricLine> lines, Duration currentPosition) {
    return SpotifyLyricsSynchronizer.findActiveLineIndex(lines, currentPosition);
  }

  void _onUserInteractedWithScroll() {
    _userIsScrolling = true;
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _userIsScrolling = false;
        });
        _scrollToActiveLine(_lastActiveIndex);
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    _romanizeLyrics = ref.watch(lyricsRomanizeProvider);
    final lyricsAsync = ref.watch(trackLyricsProvider(widget.track));
    final lyricsData = lyricsAsync.valueOrNull;

    Color activeAccent = widget.ambientColor ??
        (tokens.isGlass ? tokens.accentCyan : tokens.accent);
    Color backgroundColor =
        tokens.isGlass ? const Color(0xF20E0E11) : const Color(0xFF0D0E11);
    if (lyricsData?.colors != null) {
      if (lyricsData!.colors!.highlightText != null) {
        activeAccent = Color(lyricsData.colors!.highlightText!);
      }
      if (lyricsData.colors!.background != null) {
        backgroundColor = Color(lyricsData.colors!.background!);
      }
    }

    ref.listen(playbackStateStreamProvider, (prev, next) {
      final isPlayingNow = next.valueOrNull?.playing ?? false;
      if (isPlayingNow != _isPlaying) {
        setState(() {
          _isPlaying = isPlayingNow;
        });
        if (_isPlaying && !_ticker.isActive) {
          _ticker.start();
        } else if (!_isPlaying && _ticker.isActive) {
          _ticker.stop();
        }
      }
    });

    ref.listen(positionStreamProvider, (prev, next) {
      final streamPos = next.valueOrNull ?? Duration.zero;
      if (streamPos != _lastPlayerPosition) {
        _lastPlayerPosition = streamPos;
        _lastPlayerReceipt = DateTime.now();
        final effective = _calculateEffectivePosition(_lastPlayerReceipt);
        _positionNotifier.value = effective;

        final lyrics = ref.read(trackLyricsProvider(widget.track)).valueOrNull;
        if (lyrics != null && lyrics.isSynced && lyrics.lines.isNotEmpty) {
          final activeIdx = SpotifyLyricsSynchronizer.findActiveLineIndex(
            lyrics.lines,
            effective,
          );
          if (activeIdx != _lastActiveIndex && mounted) {
            setState(() {
              _lastActiveIndex = activeIdx;
            });
            _scrollToActiveLine(activeIdx);
          }
        }
      }
    });

    final effectivePos = _positionNotifier.value;

    return AppSurface(
      borderRadius: BorderRadius.circular(tokens.radiusXl),
      withBlur: true,
      color: tokens.isGlass ? Colors.white.withValues(alpha: 0.08) : backgroundColor,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radiusXl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              activeAccent.withValues(alpha: tokens.isGlass ? 0.22 : 0.12),
              tokens.isGlass ? Colors.transparent : backgroundColor,
            ],
            stops: const [0.0, 0.45],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 720;
            return Column(
              children: [
                // Minimal Header Bar
                _buildHeader(tokens, activeAccent),

                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),

                // Lyrics Content Area
                Expanded(
                  child: isDesktop
                      ? Row(
                          children: [
                            _buildLeftSidebar(tokens, activeAccent),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildLyricsHeaderSubStrip(activeAccent),
                                  Expanded(
                                    child: _buildLyricsContent(
                                      lyricsAsync,
                                      effectivePos,
                                      tokens,
                                      activeAccent,
                                      backgroundColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : _buildLyricsContent(
                          lyricsAsync,
                          effectivePos,
                          tokens,
                          activeAccent,
                          backgroundColor,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLyricsContent(
    AsyncValue<SyncedLyrics?> lyricsAsync,
    Duration effectivePos,
    AppTokens tokens,
    Color activeAccent,
    Color backgroundColor,
  ) {
    return lyricsAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: activeAccent,
                        strokeWidth: 2.5,
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: tokens.textMuted,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load lyrics',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    data: (lyrics) {
                      final isInstrumental = lyrics != null &&
                          lyrics.lines.length <= 1 &&
                          ((lyrics.plainLyrics != null &&
                              (lyrics.plainLyrics!.trim().toLowerCase() == '[instrumental]' ||
                               lyrics.plainLyrics!.trim() == '♪ Instrumental ♪')) ||
                           (lyrics.lines.isNotEmpty &&
                              (lyrics.lines.first.text.trim().toLowerCase() == '[instrumental]' ||
                               lyrics.lines.first.text.trim() == '♪ Instrumental ♪')));

                      if (isInstrumental) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: activeAccent.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: activeAccent.withValues(alpha: 0.25),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.graphic_eq_rounded,
                                  color: activeAccent,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                '♪ Instrumental Track ♪',
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enjoy the studio instrumentation',
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (lyrics == null ||
                          (!lyrics.isSynced &&
                              (lyrics.plainLyrics == null ||
                                  lyrics.plainLyrics!.trim().isEmpty))) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.music_off_rounded,
                                color: tokens.textMuted,
                                size: 44,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No lyrics available for this track',
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Unsynced plain lyrics sheet
                      if (!lyrics.isSynced) {
                        final rawLyrics = lyrics.plainLyrics ?? '';
                        final displayLyrics = _romanizeLyrics ? RomanizationService.romanize(rawLyrics) : rawLyrics;
                        return NotificationListener<UserScrollNotification>(
                          onNotification: (_) {
                            _onUserInteractedWithScroll();
                            return false;
                          },
                          child: SingleChildScrollView(
                            key: ValueKey('plain_lyrics_scroll_${widget.track.id}'),
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 32,
                            ),
                            child: Text(
                              displayLyrics,
                              style: TextStyle(
                                fontSize: _lyricFontSize.inactiveSize,
                                height: 1.8,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.95),
                                shadows: const [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 8,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        );
                      }

                      // Karaoke Synced Lyrics View
                      final lines = lyrics.lines;
                      final activeIndex = _lastActiveIndex >= 0 && _lastActiveIndex < lines.length
                          ? _lastActiveIndex
                          : _findActiveLineIndex(lines, effectivePos);

                      if (_lastActiveIndex == -1 && activeIndex >= 0) {
                        _lastActiveIndex = activeIndex;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToActiveLine(activeIndex);
                        });
                      }

                      return Stack(
                        children: [
                          NotificationListener<UserScrollNotification>(
                            onNotification: (notification) {
                              if (notification.direction !=
                                  ScrollDirection.idle) {
                                _onUserInteractedWithScroll();
                              }
                              return false;
                            },
                            child: SingleChildScrollView(
                              key: ValueKey('lyrics_scroll_${widget.track.id}'),
                              controller: _scrollController,
                              padding: EdgeInsets.only(
                                left: 20,
                                right: 20,
                                top: ref.watch(lyricsStyleProvider) == LyricsStyle.appleMusic ? 40 : 80,
                                bottom: ref.watch(lyricsStyleProvider) == LyricsStyle.appleMusic
                                    ? (MediaQuery.of(context).size.height * 0.65)
                                    : 80,
                              ),
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (int i = 0; i < lines.length; i++)
                                    _buildLyricLine(
                                      index: i,
                                      lines: lines,
                                      activeIndex: activeIndex,
                                      tokens: tokens,
                                      accentColor: activeAccent,
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Top Zero-Cost Gradient Fade Overlay (Eliminates GPU saveLayer)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 64,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      backgroundColor,
                                      backgroundColor.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Bottom Zero-Cost Gradient Fade Overlay (Eliminates GPU saveLayer)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 72,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      backgroundColor,
                                      backgroundColor.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Floating "Sync" Return Button
                          if (_userIsScrolling &&
                              activeIndex >= 0 &&
                              activeIndex < lines.length)
                            Positioned(
                              bottom: 24,
                              right: 24,
                              child: BouncingScaleButton(
                                scaleFactor: 0.92,
                                onTap: () {
                                  setState(() => _userIsScrolling = false);
                                  _scrollToActiveLine(activeIndex, force: true);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: activeAccent,
                                    borderRadius: BorderRadius.circular(
                                      tokens.radiusFull,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: activeAccent.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 18,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sync_rounded,
                                        color: Colors.black,
                                        size: 15,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Sync to Voice',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
  }

  Widget _buildLeftSidebar(AppTokens tokens, Color activeAccent) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFF121316),
        border: Border(
          right: BorderSide(
            color: Color(0xFF1F1F23),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album Artwork Showcase
          Center(
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF292A2D),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                image: widget.track.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(widget.track.coverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.track.coverUrl == null
                  ? Icon(
                      Icons.music_note_rounded,
                      size: 64,
                      color: activeAccent,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 18),

          // Track Title & Artist
          Text(
            widget.track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE3E2E6),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFFBBCABF),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeAccent,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Sync Live',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: AppTheme.fontUi,
                  fontWeight: FontWeight.w600,
                  color: activeAccent,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Keyboard Shortcut Tip Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF292A2D), width: 0.8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF292A2D),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SPACE',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: AppTheme.fontUi,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4EDEA3),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Play / Pause instant switch',
                    style: TextStyle(fontSize: 12, color: Color(0xFFBBCABF)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsHeaderSubStrip(Color activeAccent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF121316),
        border: Border(bottom: BorderSide(color: Color(0xFF1F1F23), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, size: 14, color: activeAccent),
              const SizedBox(width: 6),
              const Text(
                'Synced with audio',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: AppTheme.fontUi,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFBBCABF),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeAccent,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Continuous Track Sync',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF86948A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppTokens tokens, Color activeAccent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _EqualizerWave(
                color: activeAccent,
                isPlaying: _isPlaying,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: activeAccent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: activeAccent,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'LYRICS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: activeAccent,
                                    letterSpacing: 0.8,
                                    fontFamily: AppTheme.fontUi,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Interactive Font Size Scaler Badge
                          BouncingScaleButton(
                            scaleFactor: 0.92,
                            onTap: _cycleFontSize,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF222222),
                                borderRadius: BorderRadius.circular(tokens.radiusSm),
                                border: Border.all(
                                  color: const Color(0xFF1F1F1F),
                                  width: 0.9,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.format_size_rounded,
                                      color: activeAccent, size: 12),
                                  const SizedBox(width: 3),
                                  Text(
                                    _lyricFontSize.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: activeAccent,
                                      fontFamily: AppTheme.fontUi,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Interactive Romanize Transliteration Badge
                          Tooltip(
                            message: _romanizeLyrics
                                ? 'Romanized lyrics (English transliteration) ON'
                                : 'Romanize non-English lyrics to English alphabet',
                            child: BouncingScaleButton(
                              scaleFactor: 0.92,
                              onTap: _toggleRomanize,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: _romanizeLyrics
                                      ? activeAccent.withValues(alpha: 0.28)
                                      : const Color(0xFF222222),
                                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                                  border: Border.all(
                                    color: _romanizeLyrics
                                        ? activeAccent
                                        : const Color(0xFF1F1F1F),
                                    width: 0.9,
                                  ),
                                ),
                                child: Text(
                                  _romanizeLyrics ? 'ROM' : 'ORIG',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _romanizeLyrics
                                        ? activeAccent
                                        : tokens.textSecondary,
                                    fontFamily: AppTheme.fontUi,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.track.title} • ${widget.track.artist}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onToggleFullscreen != null) ...[
                BouncingScaleButton(
                  scaleFactor: 0.9,
                  onTap: widget.onToggleFullscreen!,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isFullScreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: tokens.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
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
        ],
      ),
    );
  }

  Widget _buildLyricLine({
    required int index,
    required List<LyricLine> lines,
    required int activeIndex,
    required AppTokens tokens,
    required Color accentColor,
  }) {
    final line = lines[index];
    final isActive = index == activeIndex;
    final distanceFromActive = (index - activeIndex).abs();

    final isMusicSymbol = line.text.trim() == '♪' ||
        line.text.trim().toLowerCase() == '[instrumental]';

    final displayText =
        _romanizeLyrics ? RomanizationService.romanize(line.text) : line.text;

    // Metrolist Duet Vocalist Positioning (RespectAgentPositioning):
    // v1: Left aligned, default singer
    // v2: Right aligned with soft cyan-blue tint, second singer
    // v1000 / chorus: Center aligned, collective chorus
    final agent = line.agent?.toLowerCase();
    final bool isDuetV2 = agent == 'v2';
    final bool isChorus = agent == 'v1000' || agent == 'chorus' || agent == 'all';
    final Alignment alignment = isChorus
        ? Alignment.center
        : (isDuetV2
            ? Alignment.centerRight
            : (agent == 'v1' ? Alignment.centerLeft : Alignment.center));
    final TextAlign textAlign = isChorus
        ? TextAlign.center
        : (isDuetV2
            ? TextAlign.right
            : (agent == 'v1' ? TextAlign.left : TextAlign.center));

    // Metrolist / Apple Music Solo Countdown:
    // When interlude gap before this line exceeds 5 seconds, show 3-dot countdown
    final Duration prevTimestamp =
        (index > 0) ? lines[index - 1].timestamp : Duration.zero;
    final bool hasLongInterlude =
        (line.timestamp - prevTimestamp).inMilliseconds >= 5000;

    // Depth-of-field opacity gradient
    final double lineOpacity = isActive
        ? 1.0
        : (0.40 - (distanceFromActive * 0.04)).clamp(0.20, 0.40);

    final lyricsStyle = ref.watch(lyricsStyleProvider);
    final isAppleLyrics = lyricsStyle == LyricsStyle.appleMusic;
    final reduceEffects = ref.watch(shouldReduceEffectsProvider);

    // Apple Music optical depth of field:
    // Distance formula from SimpMusic AppleMusicLyricsLines.kt:
    // Past lines carry +1 distance penalty so they recede faster:
    final int appleDistance = (index < activeIndex)
        ? ((activeIndex - index).abs() + 1)
        : (index - activeIndex);

    final double appleBlur = (activeIndex < 0 || isActive)
        ? 0.0
        : (28.0 * (appleDistance * 0.095)).clamp(0.0, 9.5);

    final double appleAlpha = activeIndex < 0
        ? 0.60
        : (isActive ? 1.0 : (1.0 - appleDistance * 0.25).clamp(0.25, 0.90));

    final double activeFontSize = isAppleLyrics ? 28.0 : (_lyricFontSize.activeSize * 1.15);
    final double inactiveFontSize = isAppleLyrics ? 28.0 : _lyricFontSize.inactiveSize;

    final lineWidget = Container(
      key: _getKeyForIndex(index),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            try {
              ref.read(audioHandlerProvider).seek(line.timestamp);
            } catch (_) {}
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            final quoteText = displayText;
            final shareString =
                '"$quoteText"\n— ${widget.track.artist} (${widget.track.title})\nShared via Softify 🎧';
            Clipboard.setData(ClipboardData(text: shareString));
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Lyric quote copied to clipboard',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1B1B1F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusLg),
                  side: BorderSide(
                    color: accentColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Align(
              alignment: alignment,
              child: isMusicSymbol
                  ? _buildInstrumentalIndicator(isActive, accentColor)
                  : (() {
                      final hasWordLevelTiming =
                          line.words != null && line.words!.isNotEmpty;
                      final rawDuration = (index + 1 < lines.length)
                          ? (lines[index + 1].timestamp - line.timestamp)
                          : const Duration(seconds: 4);
                      final effectiveDuration = rawDuration.inMilliseconds < 500
                          ? const Duration(milliseconds: 3000)
                          : rawDuration;

                      Widget lineContent = AnimatedSlide(
                        offset: isActive ? Offset.zero : (isAppleLyrics ? Offset.zero : const Offset(-0.02, 0)),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: AnimatedScale(
                          scale: isAppleLyrics ? 1.0 : (isActive ? 1.05 : 1.0),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          child: hasWordLevelTiming
                              ? _buildSyllableKaraokeLine(
                                  line: line,
                                  words: line.words!,
                                  isActive: isActive,
                                  lineOpacity: isAppleLyrics ? appleAlpha : lineOpacity,
                                  tokens: tokens,
                                  accentColor: accentColor,
                                  alignment: alignment,
                                  textAlign: textAlign,
                                  isDuetV2: isDuetV2,
                                  isAppleLyrics: isAppleLyrics,
                                )
                              : _SpicetifyProgressiveLyricsLine(
                                  displayText: displayText,
                                  lineStart: line.timestamp,
                                  lineDuration: effectiveDuration,
                                  positionNotifier: _positionNotifier,
                                  textAlign: textAlign,
                                  alignment: alignment,
                                  activeStyle: TextStyle(
                                    fontFamily: AppTheme.fontUi,
                                    fontSize: activeFontSize,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: isAppleLyrics ? 1.25 : 1.45,
                                    letterSpacing: isAppleLyrics ? -0.5 : -0.4,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 14,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  inactiveStyle: TextStyle(
                                    fontFamily: AppTheme.fontUi,
                                    fontSize: inactiveFontSize,
                                    fontWeight: isAppleLyrics ? FontWeight.w700 : FontWeight.w600,
                                    color: Colors.white.withValues(
                                      alpha: isAppleLyrics ? 0.90 : lineOpacity.clamp(0.25, 0.45),
                                    ),
                                    height: isAppleLyrics ? 1.25 : 1.45,
                                    letterSpacing: isAppleLyrics ? -0.5 : -0.4,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black45,
                                        blurRadius: 6,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      );

                      if (isAppleLyrics) {
                        if (appleBlur > 0.1 && !reduceEffects) {
                          lineContent = ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: appleBlur, sigmaY: appleBlur),
                            child: lineContent,
                          );
                        }
                        lineContent = Opacity(
                          opacity: appleAlpha,
                          child: lineContent,
                        );
                      }

                      return lineContent;
                    }()),
            ),
          ),
        ),
      ),
    );

    if (hasLongInterlude) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SoloCountdownIndicator(
            lineStart: line.timestamp,
            positionNotifier: _positionNotifier,
            accentColor: accentColor,
          ),
          lineWidget,
        ],
      );
    }

    return lineWidget;
  }

  Widget _buildSyllableKaraokeLine({
    required LyricLine line,
    required List<LyricWord> words,
    required bool isActive,
    required double lineOpacity,
    required AppTokens tokens,
    required Color accentColor,
    required Alignment alignment,
    required TextAlign textAlign,
    required bool isDuetV2,
    bool isAppleLyrics = false,
  }) {
    final displayText =
        _romanizeLyrics ? RomanizationService.romanize(line.text) : line.text;

    final double activeWordSize = isAppleLyrics ? 28.0 : (_lyricFontSize.activeSize * 1.18);
    final double inactiveLineSize = isAppleLyrics ? 28.0 : _lyricFontSize.inactiveSize;
    final Color inactiveWordColor = isAppleLyrics ? const Color(0xFF8E8E8E) : Colors.white.withValues(alpha: 0.38);

    if (!isActive) {
      return Text(
        displayText,
        textAlign: textAlign,
        style: TextStyle(
          fontFamily: AppTheme.fontUi,
          fontStyle: FontStyle.normal,
          fontSize: inactiveLineSize,
          fontWeight: isAppleLyrics ? FontWeight.w700 : FontWeight.w600,
          color: Colors.white.withValues(alpha: isAppleLyrics ? 0.90 : lineOpacity.clamp(0.25, 0.45)),
          height: isAppleLyrics ? 1.25 : 1.45,
          letterSpacing: isAppleLyrics ? -0.5 : -0.4,
          shadows: const [
            Shadow(
              color: Colors.black45,
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<Duration>(
      valueListenable: _positionNotifier,
      builder: (context, pos, _) {
        return Stack(
          alignment: alignment,
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.0,
                  child: Text(
                    displayText,
                    style: const TextStyle(fontSize: 0.01),
                  ),
                ),
              ),
            ),
            Wrap(
              alignment: textAlign == TextAlign.center
                  ? WrapAlignment.center
                  : (textAlign == TextAlign.right
                      ? WrapAlignment.end
                      : WrapAlignment.start),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (int w = 0; w < words.length; w++) ...[
                  () {
                    final word = words[w];
                    final wordText = _romanizeLyrics
                        ? RomanizationService.romanize(word.text)
                        : word.text;
                    final paddedText = (w < words.length - 1 && !wordText.endsWith(' '))
                        ? '$wordText '
                        : wordText;

                    final wordDuration = word.duration ??
                        (w + 1 < words.length
                            ? (words[w + 1].timestamp - word.timestamp)
                            : const Duration(milliseconds: 350));

                    final wordProgress = SpotifyLyricsSynchronizer.calculateWordProgress(
                      wordStart: word.timestamp,
                      wordDuration: wordDuration,
                      currentPosition: pos,
                    );

                    return _WordKaraokeSpanWidget(
                      text: paddedText,
                      progress: wordProgress,
                      isCurrentWord: wordProgress > 0.0 && wordProgress < 1.0,
                      activeStyle: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontStyle: FontStyle.normal,
                        fontSize: activeWordSize,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: isAppleLyrics ? 1.25 : 1.45,
                        letterSpacing: isAppleLyrics ? -0.5 : -0.4,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 14,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      inactiveStyle: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontStyle: FontStyle.normal,
                        fontSize: activeWordSize,
                        fontWeight: FontWeight.w700,
                        color: inactiveWordColor,
                        height: isAppleLyrics ? 1.25 : 1.45,
                        letterSpacing: isAppleLyrics ? -0.5 : -0.4,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    );
                  }(),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstrumentalIndicator(bool isActive, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note_rounded,
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.25),
            size: isActive ? 22 : 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Instrumental',
            style: TextStyle(
              fontSize: isActive ? 16 : 14,
              fontStyle: FontStyle.italic,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

class _EqualizerWave extends StatefulWidget {
  final Color color;
  final bool isPlaying;

  const _EqualizerWave({
    required this.color,
    required this.isPlaying,
  });

  @override
  State<_EqualizerWave> createState() => _EqualizerWaveState();
}

class _EqualizerWaveState extends State<_EqualizerWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _EqualizerWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(widget.isPlaying ? (8.0 + 8.0 * math.sin(t * math.pi)) : 6.0),
            const SizedBox(width: 2.5),
            _buildBar(widget.isPlaying ? (14.0 + 6.0 * math.cos(t * math.pi)) : 10.0),
            const SizedBox(width: 2.5),
            _buildBar(widget.isPlaying ? (6.0 + 10.0 * math.sin((t + 0.5) * math.pi).abs()) : 4.0),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.8,
      height: height.clamp(4.0, 18.0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// Metrolist & Apple Music signature 3-dot pulsing countdown indicator for solo instrumentals.
class _SoloCountdownIndicator extends StatelessWidget {
  final Duration lineStart;
  final ValueNotifier<Duration> positionNotifier;
  final Color accentColor;

  const _SoloCountdownIndicator({
    required this.lineStart,
    required this.positionNotifier,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: positionNotifier,
      builder: (context, pos, _) {
        final remainingMs = (lineStart - pos).inMilliseconds;
        // Countdown activates within 3.5 seconds before vocal onset
        if (remainingMs <= 0 || remainingMs > 3500) {
          return const SizedBox.shrink();
        }

        // 3 sequential dots pulsing down:
        // Dot 1: remaining <= 3000ms
        // Dot 2: remaining <= 2000ms
        // Dot 3: remaining <= 1000ms
        final d1 = remainingMs <= 3000;
        final d2 = remainingMs <= 2000;
        final d3 = remainingMs <= 1000;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDot(d1, accentColor),
              const SizedBox(width: 8),
              _buildDot(d2, accentColor),
              const SizedBox(width: 8),
              _buildDot(d3, accentColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDot(bool active, Color accent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      width: active ? 10 : 6,
      height: active ? 10 : 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.22),
        boxShadow: active
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.7),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Individual Word-to-Word progressive karaoke word widget with left-to-right wipe
/// and gentle spring scale while being actively sung.
class _WordKaraokeSpanWidget extends StatelessWidget {
  final String text;
  final double progress;
  final bool isCurrentWord;
  final TextStyle activeStyle;
  final TextStyle inactiveStyle;

  const _WordKaraokeSpanWidget({
    required this.text,
    required this.progress,
    required this.isCurrentWord,
    required this.activeStyle,
    required this.inactiveStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.0) {
      return Text(text, style: inactiveStyle);
    }
    if (progress >= 1.0) {
      return Text(text, style: activeStyle);
    }

    final activeColor = activeStyle.color ?? Colors.white;
    final inactiveColor = inactiveStyle.color ?? Colors.white.withValues(alpha: 0.38);

    final wobbleScale = 1.0 + (math.sin(progress * math.pi) * 0.05);

    return Transform.scale(
      scale: wobbleScale,
      alignment: Alignment.centerLeft,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          final stopLeft = (progress - 0.06).clamp(0.0, 1.0);
          final stopRight = (progress + 0.02).clamp(0.0, 1.0);
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              activeColor,
              activeColor,
              inactiveColor,
              inactiveColor,
            ],
            stops: [
              0.0,
              stopLeft,
              stopRight,
              1.0,
            ],
          ).createShader(bounds);
        },
        child: Text(
          text,
          style: activeStyle.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// Spicetify / Apple Music progressive left-to-right fade-in / wipe lyrics line.
/// When a line wraps into 2 or 3 sub-lines on the user's screen, animation
/// progresses line by line sequentially: subsequent lines stay completely inactive
/// until the preceding line has finished wiping.
class _SpicetifyProgressiveLyricsLine extends StatelessWidget {
  final String displayText;
  final Duration lineStart;
  final Duration lineDuration;
  final ValueNotifier<Duration> positionNotifier;
  final TextStyle activeStyle;
  final TextStyle inactiveStyle;
  final TextAlign textAlign;
  final Alignment alignment;

  const _SpicetifyProgressiveLyricsLine({
    required this.displayText,
    required this.lineStart,
    required this.lineDuration,
    required this.positionNotifier,
    required this.activeStyle,
    required this.inactiveStyle,
    this.textAlign = TextAlign.center,
    this.alignment = Alignment.center,
  });

  static List<String> _splitIntoLines(
    String text,
    TextStyle style,
    double maxWidth,
    TextAlign textAlign,
  ) {
    final cleanText = text.trim();
    if (cleanText.isEmpty || maxWidth <= 0 || maxWidth.isInfinite) {
      return [cleanText];
    }

    if (cleanText.contains('\n')) {
      final rawLines = cleanText.split('\n');
      final result = <String>[];
      for (final raw in rawLines) {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty) {
          result.addAll(_splitIntoLines(trimmed, style, maxWidth, textAlign));
        }
      }
      return result.isEmpty ? [cleanText] : result;
    }

    final painter = TextPainter(
      text: TextSpan(text: cleanText, style: style),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final metrics = painter.computeLineMetrics();
    if (metrics.length <= 1) {
      return [cleanText];
    }

    final lines = <String>[];
    int offset = 0;
    while (offset < cleanText.length) {
      final boundary = painter.getLineBoundary(TextPosition(offset: offset));
      if (boundary.start >= boundary.end || boundary.end <= offset) {
        final rem = cleanText.substring(offset).trim();
        if (rem.isNotEmpty) lines.add(rem);
        break;
      }
      final lineStr = cleanText.substring(boundary.start, boundary.end).trim();
      if (lineStr.isNotEmpty) {
        lines.add(lineStr);
      }
      offset = boundary.end;
      while (offset < cleanText.length &&
          (cleanText[offset] == ' ' || cleanText[offset] == '\n')) {
        offset++;
      }
    }

    return lines.isEmpty ? [cleanText] : lines;
  }

  Widget _buildSubLine(String text, double lineProgress) {
    if (lineProgress <= 0.0) {
      return Text(
        text,
        textAlign: textAlign,
        style: inactiveStyle,
      );
    }

    if (lineProgress >= 1.0) {
      return Text(
        text,
        textAlign: textAlign,
        style: activeStyle,
      );
    }

    final activeColor = activeStyle.color ?? Colors.white;
    final inactiveColor = inactiveStyle.color ?? Colors.white.withValues(alpha: 0.38);

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        final stopLeft = (lineProgress - 0.08).clamp(0.0, 1.0);
        final stopRight = (lineProgress + 0.02).clamp(0.0, 1.0);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            activeColor,
            activeColor,
            inactiveColor,
            inactiveColor,
          ],
          stops: [
            0.0,
            stopLeft,
            stopRight,
            1.0,
          ],
        ).createShader(bounds);
      },
      child: Text(
        text,
        textAlign: textAlign,
        style: activeStyle.copyWith(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final subLines = _splitIntoLines(displayText, activeStyle, maxWidth, textAlign);

        if (subLines.length <= 1) {
          return ValueListenableBuilder<Duration>(
            valueListenable: positionNotifier,
            builder: (context, pos, _) {
              final elapsed = (pos - lineStart).inMilliseconds;
              final total = lineDuration.inMilliseconds.clamp(500, 16000);
              final double progress = (elapsed / total).clamp(0.0, 1.0);
              return _buildSubLine(displayText, progress);
            },
          );
        }

        final totalChars = subLines.fold<int>(0, (sum, l) => sum + l.length);
        final safeTotalChars = totalChars > 0 ? totalChars : 1;
        final thresholds = <double>[];
        double accumulated = 0;
        for (int i = 0; i < subLines.length; i++) {
          accumulated += subLines[i].length / safeTotalChars;
          thresholds.add(accumulated);
        }
        if (thresholds.isNotEmpty) {
          thresholds[thresholds.length - 1] = 1.0;
        }

        return ValueListenableBuilder<Duration>(
          valueListenable: positionNotifier,
          builder: (context, pos, _) {
            final elapsed = (pos - lineStart).inMilliseconds;
            final total = lineDuration.inMilliseconds.clamp(500, 16000);
            final double progress = (elapsed / total).clamp(0.0, 1.0);

            return Stack(
              alignment: alignment,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.0,
                      child: Text(
                        displayText,
                        style: const TextStyle(fontSize: 0.01),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: textAlign == TextAlign.center
                      ? CrossAxisAlignment.center
                      : (textAlign == TextAlign.right
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start),
                  children: [
                    for (int i = 0; i < subLines.length; i++) ...[
                      () {
                        final tPrev = i == 0 ? 0.0 : thresholds[i - 1];
                        final tCurr = thresholds[i];
                        final double lineProgress;
                        if (progress <= tPrev) {
                          lineProgress = 0.0;
                        } else if (progress >= tCurr) {
                          lineProgress = 1.0;
                        } else {
                          lineProgress =
                              ((progress - tPrev) / (tCurr - tPrev)).clamp(0.0, 1.0);
                        }
                        return _buildSubLine(subLines[i], lineProgress);
                      }(),
                    ],
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
