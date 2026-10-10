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
import '../providers/player_providers.dart';
import '../theme/app_tokens.dart';
import 'bouncing_scale_button.dart';

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
  Duration _interpolatedPosition = Duration.zero;

  // Visual perceptual lead compensation (matches human auditory-visual synchrony curve)
  static const int _baseLeadMs = 280;

  // Track-calibrated sync offset (persisted in Drift SQLite)
  int _syncOffsetMs = 0;
  bool _showTuner = false;
  bool _isKaraokeMode = false;

  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollTimer;

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
        final posDelta = (rawPlayerPos - _lastPlayerPosition).abs();
        if (posDelta > const Duration(milliseconds: 1200)) {
          // Explicit seek by user
          _lastPlayerPosition = rawPlayerPos;
          _lastPlayerReceipt = now;
          _interpolatedPosition = rawPlayerPos;
        } else {
          // Monotonic progress without backward micro-stutter
          _lastPlayerPosition = rawPlayerPos;
          _lastPlayerReceipt = now;
          if (rawPlayerPos > _interpolatedPosition) {
            _interpolatedPosition = rawPlayerPos;
          }
        }
      } else {
        final diff = now.difference(_lastPlayerReceipt);
        if (diff <= const Duration(milliseconds: 2500)) {
          final predicted = _lastPlayerPosition + diff;
          if (predicted > _interpolatedPosition) {
            _interpolatedPosition = predicted;
          }
        }
      }

      final effectivePos =
          _interpolatedPosition + Duration(milliseconds: _syncOffsetMs + _baseLeadMs);
      _positionNotifier.value = effectivePos;

      // Only trigger widget tree re-layout when active lyric line advances
      final lyrics = ref.read(trackLyricsProvider(widget.track)).valueOrNull;
      if (lyrics != null && lyrics.isSynced && lyrics.lines.isNotEmpty) {
        final activeIdx = _findActiveLineIndex(lyrics.lines, effectivePos);
        if (activeIdx != _lastActiveIndex && mounted) {
          setState(() {
            _lastActiveIndex = activeIdx;
          });
          _scrollToActiveLine(activeIdx);
        }
      }
    });
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
    } catch (_) {}
  }

  Future<void> _saveOffset(int offsetMs) async {
    setState(() {
      _syncOffsetMs = offsetMs;
    });
    try {
      final db = ref.read(databaseProvider);
      final key = 'lyrics_offset_${widget.track.id}';
      await db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: offsetMs.toString()),
      );
    } catch (_) {}
  }

  void _nudgeOffset(int deltaMs) {
    HapticFeedback.selectionClick();
    _saveOffset((_syncOffsetMs + deltaMs).clamp(-3000, 3000));
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
      _lineKeys.clear();
      _loadSavedOffset();
    }
  }

  GlobalKey _getKeyForIndex(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  void _scrollToActiveLine(int index) {
    if (_userIsScrolling || !_scrollController.hasClients || index < 0) return;

    void performScroll() {
      if (!mounted || _userIsScrolling || !_scrollController.hasClients) return;
      final key = _lineKeys[index];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          alignment: 0.38, // Golden ratio focal line
        );
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
    if (lines.isEmpty) return -1;
    // Before first line begins (instrumental intro)
    if (currentPosition < lines.first.timestamp) {
      return -1;
    }
    for (int i = lines.length - 1; i >= 0; i--) {
      if (currentPosition >= lines[i].timestamp) {
        int primaryIndex = i;
        while (primaryIndex > 0 &&
            lines[primaryIndex - 1].timestamp == lines[i].timestamp) {
          primaryIndex--;
        }
        return primaryIndex;
      }
    }
    return -1;
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

  void _toggleTuner() {
    HapticFeedback.selectionClick();
    setState(() {
      _showTuner = !_showTuner;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeAccent = widget.ambientColor ?? tokens.accent;

    final lyricsAsync = ref.watch(trackLyricsProvider(widget.track));
    final positionAsync = ref.watch(positionStreamProvider);
    final playbackAsync = ref.watch(playbackStateStreamProvider);

    // Sync playback state safely
    final isPlayingNow = playbackAsync.valueOrNull?.playing ?? false;
    if (isPlayingNow != _isPlaying) {
      _isPlaying = isPlayingNow;
      if (_isPlaying && !_ticker.isActive) {
        _ticker.start();
      } else if (!_isPlaying && _ticker.isActive) {
        _ticker.stop();
      }
    }

    // Sync audio position stream
    final streamPos = positionAsync.value ?? Duration.zero;
    if (streamPos != _lastPlayerPosition) {
      final posDelta = (streamPos - _lastPlayerPosition).abs();
      _lastPlayerPosition = streamPos;
      _lastPlayerReceipt = DateTime.now();
      if (posDelta > const Duration(milliseconds: 1200) || streamPos > _interpolatedPosition) {
        _interpolatedPosition = streamPos;
      }
    }

    // Apply lead compensation offset to eliminate audio pipeline latency
    final effectivePos =
        _interpolatedPosition + Duration(milliseconds: _syncOffsetMs + _baseLeadMs);
    _positionNotifier.value = effectivePos;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusXl),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D0E11),
          borderRadius: BorderRadius.circular(tokens.radiusXl),
          border: Border.all(
            color: const Color(0xFF1F1F23),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              activeAccent.withValues(alpha: 0.05),
              const Color(0xFF0D0E11),
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

                if (_showTuner)
                  _buildTunerDrawer(tokens, activeAccent),

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
                              lyrics.plainLyrics ?? '',
                              style: TextStyle(
                                fontSize: 18,
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
                      final activeIndex =
                          _findActiveLineIndex(lines, effectivePos);

                      if (activeIndex != _lastActiveIndex) {
                        _lastActiveIndex = activeIndex;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToActiveLine(activeIndex);
                        });
                      }

                      return Stack(
                        children: [
                          // Top & Bottom Optical Gradient Fade Mask
                          ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) {
                              return const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.08, 0.90, 1.0],
                              ).createShader(bounds);
                            },
                            child: NotificationListener<UserScrollNotification>(
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
                                        currentPos: effectivePos,
                                        tokens: tokens,
                                        accentColor: activeAccent,
                                      ),
                                  ],
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
                                  _scrollToActiveLine(activeIndex);
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

          // Badges Row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1F),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF292A2D), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4EDEA3),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Sync Live',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4EDEA3),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1F),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF292A2D), width: 0.8),
                ),
                child: const Text(
                  'Stereo Hi-Fi',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFBBCABF),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1F),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF292A2D), width: 0.8),
                ),
                child: const Text(
                  '171 BPM',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF86948A),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Vocal Volume Mode Toggle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF292A2D), width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VOCAL VOLUME MODE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF86948A),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isKaraokeMode = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: !_isKaraokeMode ? const Color(0xFF292A2D) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !_isKaraokeMode ? const Color(0xFF4EDEA3) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Original',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: !_isKaraokeMode ? const Color(0xFF4EDEA3) : const Color(0xFFBBCABF),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isKaraokeMode = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _isKaraokeMode ? const Color(0xFF292A2D) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isKaraokeMode ? const Color(0xFF4EDEA3) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Karaoke',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _isKaraokeMode ? const Color(0xFF4EDEA3) : const Color(0xFFBBCABF),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4EDEA3),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Play / Pause instant switch',
                    style: TextStyle(fontSize: 11, color: Color(0xFFBBCABF)),
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
              const Icon(Icons.mic_none_rounded, size: 14, color: Color(0xFFBBCABF)),
              const SizedBox(width: 6),
              const Text(
                'VOCALS 92%',
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFBBCABF),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF292A2D),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.92,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4EDEA3).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4EDEA3),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Continuous Track Sync',
                style: TextStyle(
                  fontSize: 10.5,
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
                    Row(
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
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: activeAccent,
                                  letterSpacing: 0.8,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Interactive Latency Offset Tuner Badge
                        BouncingScaleButton(
                          scaleFactor: 0.92,
                          onTap: _toggleTuner,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: _showTuner
                                  ? activeAccent.withValues(alpha: 0.28)
                                  : const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(tokens.radiusSm),
                              border: Border.all(
                                color: _showTuner
                                    ? activeAccent
                                    : const Color(0xFF1F1F1F),
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined,
                                    color: activeAccent, size: 11),
                                const SizedBox(width: 4),
                                Text(
                                  '${_syncOffsetMs > 0 ? '+' : ''}${_syncOffsetMs}ms',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: activeAccent,
                                    letterSpacing: 0.2,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
          const SizedBox(height: 10),
          // Pitch & Audio Engine Bar
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 420) {
                return Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 13, color: activeAccent),
                    const SizedBox(width: 5),
                    const Text(
                      'Vocal Pitch Tracking',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFA3A3A3),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.graphic_eq_rounded, size: 13, color: activeAccent),
                      const SizedBox(width: 5),
                      const Text(
                        'Vocal Pitch Tracking',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFA3A3A3),
                        ),
                      ),
                    ],
                  ),
                  Row(
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
                      const Text(
                        'Direct-ALSA • 440Hz Reference',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF525252),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTunerDrawer(AppTokens tokens, Color activeAccent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: activeAccent, size: 13),
              const SizedBox(width: 6),
              Text(
                'SYNC CALIBRATION',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: activeAccent,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${_syncOffsetMs > 0 ? '+' : ''}${_syncOffsetMs}ms)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                'Auto-saved for track',
                style: TextStyle(
                  fontSize: 10,
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quick Step Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNudgePill('-500ms', () => _nudgeOffset(-500), tokens, activeAccent),
              _buildNudgePill('-100ms', () => _nudgeOffset(-100), tokens, activeAccent),
              _buildNudgePill('Reset 0ms', () => _saveOffset(0), tokens, activeAccent, isReset: true),
              _buildNudgePill('+100ms', () => _nudgeOffset(100), tokens, activeAccent),
              _buildNudgePill('+500ms', () => _nudgeOffset(500), tokens, activeAccent),
            ],
          ),
          const SizedBox(height: 6),
          // Fine Millisecond Slider
          Row(
            children: [
              Text('-3s', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: activeAccent,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                    thumbColor: Colors.white,
                    overlayColor: activeAccent.withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 2.5,
                  ),
                  child: Slider(
                    value: _syncOffsetMs.clamp(-3000, 3000).toDouble(),
                    min: -3000,
                    max: 3000,
                    divisions: 120, // 50ms steps
                    onChanged: (val) {
                      _saveOffset(val.round());
                    },
                  ),
                ),
              ),
              Text('+3s', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgePill(
    String label,
    VoidCallback onTap,
    AppTokens tokens,
    Color activeAccent, {
    bool isReset = false,
  }) {
    return BouncingScaleButton(
      scaleFactor: 0.94,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isReset
              ? activeAccent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: isReset
                ? activeAccent.withValues(alpha: 0.40)
                : Colors.white.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isReset ? activeAccent : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildLyricLine({
    required int index,
    required List<LyricLine> lines,
    required int activeIndex,
    required Duration currentPos,
    required AppTokens tokens,
    required Color accentColor,
  }) {
    final line = lines[index];
    final isActive = index == activeIndex;
    final distanceFromActive = (index - activeIndex).abs();

    final isMusicSymbol = line.text.trim() == '♪' ||
        line.text.trim().toLowerCase() == '[instrumental]';

    // Depth-of-field opacity gradient
    final double lineOpacity = isActive
        ? 1.0
        : (0.40 - (distanceFromActive * 0.04)).clamp(0.20, 0.40);

    return AnimatedScale(
      scale: isActive ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      child: Container(
      key: _getKeyForIndex(index),
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? accentColor.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        border: Border.all(
          color: isActive
              ? accentColor.withValues(alpha: 0.18)
              : Colors.transparent,
          width: 0.8,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.06),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : null,
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
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          splashColor: accentColor.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Active Indicator Glowing Bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: 3.5,
                  height: isActive ? 32 : 0,
                  margin: const EdgeInsets.only(right: 12, top: 2),
                  decoration: BoxDecoration(
                    color: isActive ? accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.65),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),

                // Main Line Content
                Expanded(
                  child: isMusicSymbol
                      ? _buildInstrumentalIndicator(isActive, accentColor)
                      : (isActive
                          ? ValueListenableBuilder<Duration>(
                              valueListenable: _positionNotifier,
                              builder: (context, pos, _) {
                                return _buildActiveKaraokeWords(
                                  line: line,
                                  nextLine: index + 1 < lines.length
                                      ? lines[index + 1]
                                      : null,
                                  currentPos: pos,
                                  accentColor: accentColor,
                                  tokens: tokens,
                                );
                              },
                            )
                          : _buildInactiveLineText(
                              text: line.text,
                              opacity: lineOpacity,
                            )),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildInactiveLineText({
    required String text,
    required double opacity,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: opacity,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          color: Color(0xFF86948A),
          height: 1.45,
          letterSpacing: -0.2,
        ),
      ),
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
            color: isActive ? accentColor : Colors.white.withValues(alpha: 0.25),
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
                  ? accentColor
                  : Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveKaraokeWords({
    required LyricLine line,
    required LyricLine? nextLine,
    required Duration currentPos,
    required Color accentColor,
    required AppTokens tokens,
  }) {
    final rawWords = line.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (rawWords.isEmpty) return const SizedBox.shrink();

    final lineStart = line.timestamp;
    final hasTrueWordSync = line.words != null && line.words!.isNotEmpty;

    final List<_WordTiming> wordTimings = [];
    if (hasTrueWordSync) {
      final wordsList = line.words!;
      for (int i = 0; i < wordsList.length; i++) {
        final w = wordsList[i];
        final wStart = w.timestamp;
        final wEnd = i + 1 < wordsList.length
            ? wordsList[i + 1].timestamp
            : (nextLine != null && nextLine.timestamp > wStart
                ? nextLine.timestamp
                : wStart + const Duration(milliseconds: 500));
        wordTimings.add(
          _WordTiming(
            text: w.text,
            startTime: wStart,
            endTime: wEnd > wStart ? wEnd : wStart + const Duration(milliseconds: 300),
          ),
        );
      }
    } else {
      // Standard line-synced lyrics (LRCLIB / Spotify Line-Synced):
      // The entire active line is active together in full crisp white with accent glow.
      // All words are immediately active so there is zero artificial word lag.
      for (final w in rawWords) {
        wordTimings.add(
          _WordTiming(
            text: w,
            startTime: lineStart,
            endTime: nextLine?.timestamp ?? lineStart + const Duration(seconds: 4),
          ),
        );
      }
    }

    return Wrap(
      spacing: 7.0,
      runSpacing: 5.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final wt in wordTimings)
          _KaraokeWordItem(
            wordTiming: wt,
            currentPos: currentPos,
            accentColor: accentColor,
            hasTrueWordSync: hasTrueWordSync,
          ),
      ],
    );
  }
}

class _WordTiming {
  final String text;
  final Duration startTime;
  final Duration endTime;

  _WordTiming({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}

class _KaraokeWordItem extends StatelessWidget {
  final _WordTiming wordTiming;
  final Duration currentPos;
  final Color accentColor;
  final bool hasTrueWordSync;

  const _KaraokeWordItem({
    required this.wordTiming,
    required this.currentPos,
    required this.accentColor,
    this.hasTrueWordSync = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = wordTiming.text;
    if (text.isEmpty) return const SizedBox.shrink();

    // Standard line-synced lyrics: All words are immediately fully active and illuminated
    if (!hasTrueWordSync) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.45,
          letterSpacing: -0.3,
          shadows: [
            Shadow(
              color: accentColor.withValues(alpha: 0.85),
              blurRadius: 16,
            ),
            const Shadow(
              color: Colors.white70,
              blurRadius: 6,
            ),
          ],
        ),
      );
    }

    final isPast = currentPos >= wordTiming.endTime;
    final isFuture = currentPos < wordTiming.startTime;

    // 1. Past word: Sung and settled in solid crisp white with subtle glow
    if (isPast) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.45,
          letterSpacing: -0.3,
          shadows: [
            Shadow(
              color: Colors.white24,
              blurRadius: 4,
            ),
          ],
        ),
      );
    }

    // 2. Future word: Unsung, dimmed translucent
    if (isFuture) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF86948A).withValues(alpha: 0.45),
          height: 1.45,
          letterSpacing: -0.3,
        ),
      );
    }

    // 3. Active word: Being vocalized RIGHT NOW! High-precision word-to-word kinetic bloom
    final durationMs =
        (wordTiming.endTime - wordTiming.startTime).inMilliseconds;
    final elapsedMs =
        (currentPos - wordTiming.startTime).inMilliseconds;
    final double wordProgress =
        durationMs > 0 ? (elapsedMs / durationMs).clamp(0.0, 1.0) : 1.0;

    final bounce = math.sin(wordProgress * math.pi);
    final scale = 1.0 + (0.07 * bounce);
    final translateY = -2.5 * bounce;

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.bottomCenter,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.45,
            letterSpacing: -0.3,
            shadows: [
              Shadow(
                color: accentColor.withValues(alpha: 0.95),
                blurRadius: 18,
              ),
              const Shadow(
                color: Colors.white,
                blurRadius: 10,
              ),
              Shadow(
                color: accentColor.withValues(alpha: 0.60),
                blurRadius: 28,
              ),
            ],
          ),
        ),
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
