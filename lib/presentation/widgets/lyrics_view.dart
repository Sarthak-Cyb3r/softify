import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import '../../data/database/app_database.dart';
import '../../data/lyrics/script_romanizer.dart';
import '../../data/lyrics/spotify_lyrics_synchronizer.dart';
import '../providers/player_providers.dart';
import '../theme/app_theme.dart';
import 'bouncing_scale_button.dart';

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

  const LyricsView({
    super.key,
    required this.track,
    this.onClose,
    this.ambientColor,
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

  Duration _calculateEffectivePosition(DateTime now) {
    if (!_isPlaying) {
      final pausedMs = _lastPlayerPosition.inMilliseconds + _syncOffsetMs;
      return Duration(milliseconds: pausedMs < 0 ? 0 : pausedMs);
    }
    final elapsed = now.difference(_lastPlayerReceipt);
    final clampedElapsedMs = elapsed.inMilliseconds.clamp(0, 1500);
    final extrapolatedMs = _lastPlayerPosition.inMilliseconds +
        clampedElapsedMs +
        _syncOffsetMs;
    final clampedMs = (widget.track.duration.inMilliseconds > 0)
        ? extrapolatedMs.clamp(0, widget.track.duration.inMilliseconds)
        : (extrapolatedMs < 0 ? 0 : extrapolatedMs);
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
      if (rawPlayerPos != _lastPlayerPosition && rawPlayerPos > Duration.zero) {
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
    final nextVal = !_romanizeLyrics;
    setState(() => _romanizeLyrics = nextVal);
    try {
      final db = ref.read(databaseProvider);
      db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: 'lyrics_romanize', value: nextVal.toString()),
      );
    } catch (_) {}
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
    }
  }

  GlobalKey _getKeyForIndex(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  void _scrollToActiveLine(int index, {bool force = false}) {
    if ((_userIsScrolling && !force) || !_scrollController.hasClients || index < 0) return;
    if (!force && index == _lastScrolledIndex) return;
    _lastScrolledIndex = index;

    void performScroll() {
      if (!mounted || (_userIsScrolling && !force) || !_scrollController.hasClients) return;
      final key = _lineKeys[index];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.35, // Focal golden ratio line where active lyrics sit
        );
      } else {
        // Line widget not laid out yet; retry on next post-frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final retryCtx = _lineKeys[index]?.currentContext;
          if (retryCtx != null) {
            Scrollable.ensureVisible(
              retryCtx,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: 0.35,
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
    final lyricsAsync = ref.watch(trackLyricsProvider(widget.track));
    final lyricsData = lyricsAsync.valueOrNull;

    Color activeAccent = widget.ambientColor ?? tokens.accent;
    Color backgroundColor = const Color(0xFF0D0E11);
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusXl),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(tokens.radiusXl),
          border: Border.all(
            color: const Color(0xFF1F1F23),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              activeAccent.withValues(alpha: 0.12),
              backgroundColor,
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
                          ((lyrics.plainLyrics != null &&
                              (lyrics.plainLyrics!.contains('♪ Instrumental ♪') ||
                               lyrics.plainLyrics!.contains('[instrumental]'))) ||
                           (lyrics.lines.isNotEmpty &&
                              (lyrics.lines.first.text.contains('♪ Instrumental ♪') ||
                               lyrics.lines.first.text.contains('[instrumental]'))));

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
                        final displayLyrics = _romanizeLyrics ? ScriptRomanizer.romanize(rawLyrics) : rawLyrics;
                        return NotificationListener<UserScrollNotification>(
                          onNotification: (_) {
                            _onUserInteractedWithScroll();
                            return false;
                          },
                          child: SingleChildScrollView(
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
                                color: tokens.textPrimary.withValues(alpha: 0.9),
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
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 80,
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
                          BouncingScaleButton(
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
        _romanizeLyrics ? ScriptRomanizer.romanize(line.text) : line.text;

    // Depth-of-field opacity gradient
    final double lineOpacity = isActive
        ? 1.0
        : (0.40 - (distanceFromActive * 0.04)).clamp(0.20, 0.40);

    return Container(
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
            child: isMusicSymbol
                ? _buildInstrumentalIndicator(isActive, accentColor)
                : ((line.words != null && line.words!.isNotEmpty)
                    ? _buildSyllableKaraokeLine(
                        line: line,
                        isActive: isActive,
                        lineOpacity: lineOpacity,
                        tokens: tokens,
                        accentColor: accentColor,
                      )
                    : AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          fontFamily: AppTheme.fontEditorial,
                          fontStyle: FontStyle.italic,
                          fontSize: isActive
                              ? _lyricFontSize.activeSize
                              : _lyricFontSize.inactiveSize,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive
                              ? Colors.white
                              : tokens.textPrimary.withValues(alpha: lineOpacity),
                          height: 1.45,
                          letterSpacing: isActive ? -0.3 : 0.0,
                        ),
                        child: Text(displayText),
                      )),
          ),
        ),
      ),
    );
  }

  Widget _buildSyllableKaraokeLine({
    required LyricLine line,
    required bool isActive,
    required double lineOpacity,
    required AppTokens tokens,
    required Color accentColor,
  }) {
    final displayText =
        _romanizeLyrics ? ScriptRomanizer.romanize(line.text) : line.text;

    if (!isActive) {
      return Text(
        displayText,
        style: TextStyle(
          fontFamily: AppTheme.fontEditorial,
          fontStyle: FontStyle.italic,
          fontSize: _lyricFontSize.inactiveSize,
          fontWeight: FontWeight.w400,
          color: tokens.textPrimary.withValues(alpha: lineOpacity),
          height: 1.45,
        ),
      );
    }

    final words = line.words!;
    return ValueListenableBuilder<Duration>(
      valueListenable: _positionNotifier,
      builder: (context, pos, _) {
        final activeWordIdx =
            SpotifyLyricsSynchronizer.findActiveWordIndex(words, pos);

        return RichText(
          text: TextSpan(
            children: [
              for (int w = 0; w < words.length; w++) ...[
                () {
                  final word = words[w];
                  final wordText = _romanizeLyrics
                      ? ScriptRomanizer.romanize(word.text)
                      : word.text;
                  final isWordSung = w <= activeWordIdx;

                  return TextSpan(
                    text: (w < words.length - 1 && !wordText.endsWith(' '))
                        ? '$wordText '
                        : wordText,
                    style: TextStyle(
                      fontFamily: AppTheme.fontEditorial,
                      fontStyle: FontStyle.italic,
                      fontSize: _lyricFontSize.activeSize,
                      fontWeight:
                          isWordSung ? FontWeight.w800 : FontWeight.w400,
                      color: isWordSung
                          ? Colors.white
                          : tokens.textPrimary.withValues(alpha: 0.35),
                    ),
                  );
                }(),
              ],
            ],
          ),
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
