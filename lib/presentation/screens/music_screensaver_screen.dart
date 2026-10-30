import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../data/lyrics/spotify_lyrics_synchronizer.dart';
import '../../services/lyrics/romanization_service.dart';
import '../../data/player/softify_audio_handler.dart';
import '../../domain/entities/audio_repeat_mode.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_music_wave_indicator.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/play_pause_morph_button.dart';
import '../widgets/shared/app_network_image.dart';

class MusicScreensaverScreen extends ConsumerStatefulWidget {
  const MusicScreensaverScreen({super.key});

  @override
  ConsumerState<MusicScreensaverScreen> createState() =>
      _MusicScreensaverScreenState();
}

class _MusicScreensaverScreenState extends ConsumerState<MusicScreensaverScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _lyricsScrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  String? _lastTrackId;

  static final Map<String, Color> _paletteCache = {};
  Color _ambientColor = const Color(0xFF1E2822);
  String? _lastExtractedCoverUrl;

  Timer? _hudTimer;
  bool _hudVisible = true;
  bool _romanize = false;
  double? _dragPositionSeconds;
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _resetHudTimer();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _clockTimer?.cancel();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _resetHudTimer() {
    if (!_hudVisible && mounted) {
      setState(() => _hudVisible = true);
    }
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _hudVisible = false);
      }
    });
  }

  void _extractArtworkPalette(String? coverUrl) {
    if (coverUrl == null || coverUrl.isEmpty || coverUrl == _lastExtractedCoverUrl) {
      return;
    }
    _lastExtractedCoverUrl = coverUrl;

    if (_paletteCache.containsKey(coverUrl)) {
      _ambientColor = _paletteCache[coverUrl]!;
      return;
    }

    PaletteGenerator.fromImageProvider(
      NetworkImage(coverUrl),
      size: const Size(48, 48),
      maximumColorCount: 8,
    ).then((generator) {
      if (!mounted) return;
      final color = generator.dominantColor?.color ??
          generator.vibrantColor?.color ??
          generator.mutedColor?.color ??
          const Color(0xFF1E2822);

      _paletteCache[coverUrl] = color;
      setState(() {
        _ambientColor = color;
      });
    }).catchError((_) {});
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatClock(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  void _scrollToActiveLine(int activeIndex) {
    if (!_lyricsScrollController.hasClients) return;
    final key = _lineKeys[activeIndex];
    if (key == null || key.currentContext == null) return;

    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.42,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentTrack = ref.watch(currentTrackProvider).value;
    final playbackState = ref.watch(playbackStateStreamProvider).value;

    if (currentTrack?.id != _lastTrackId) {
      _lastTrackId = currentTrack?.id;
      _lineKeys.clear();
      if (_lyricsScrollController.hasClients) {
        _lyricsScrollController.jumpTo(0.0);
      }
    }
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration =
        ref.watch(durationStreamProvider).value ?? currentTrack?.duration ?? Duration.zero;
    final repeatMode =
        ref.watch(repeatModeStreamProvider).value ?? AudioRepeatMode.off;
    final isShuffle = ref.watch(shuffleModeStreamProvider).value ?? false;
    final volume = ref.watch(volumeStreamProvider).value ?? 1.0;
    final audioHandler = ref.watch(audioHandlerProvider);
    final isPlaying = playbackState?.playing ?? false;

    if (currentTrack != null) {
      _extractArtworkPalette(currentTrack.coverUrl);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060608),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
          const SingleActivator(LogicalKeyboardKey.space): () {
            if (isPlaying) {
              audioHandler.pause();
            } else {
              audioHandler.play();
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => audioHandler.skipToPrevious(),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => audioHandler.skipToNext(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              audioHandler.setVolume((volume + 0.05).clamp(0.0, 1.0)),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              audioHandler.setVolume((volume - 0.05).clamp(0.0, 1.0)),
          const SingleActivator(LogicalKeyboardKey.keyL): () =>
              setState(() => _romanize = !_romanize),
        },
        child: Focus(
          autofocus: true,
          child: MouseRegion(
            onHover: (_) => _resetHudTimer(),
            child: GestureDetector(
              onTap: _resetHudTimer,
              behavior: HitTestBehavior.translucent,
              child: Stack(
                children: [
                  // 1. Dynamic Ambient Aura Background
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.6, -0.2),
                          radius: 1.25,
                          colors: [
                            _ambientColor.withValues(alpha: 0.32),
                            const Color(0xFF0C0E11).withValues(alpha: 0.7),
                            const Color(0xFF060608),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // 2. Main Content View (Adaptive: Split-Deck for Wide/Landscape, Centered Stack for Portrait)
                  Positioned.fill(
                    child: SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 640 &&
                              constraints.maxWidth > constraints.maxHeight;
                          final posSeconds = _dragPositionSeconds ?? position.inSeconds.toDouble();
                          final totalSeconds =
                              duration.inSeconds <= 0 ? 1.0 : duration.inSeconds.toDouble();

                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              isWide ? 36 : 20,
                              _hudVisible ? (isWide ? 56 : 50) : 16,
                              isWide ? 36 : 20,
                              12,
                            ),
                            child: currentTrack == null
                                ? const Center(
                                    child: Text(
                                      'No track playing',
                                      style: TextStyle(color: Colors.white54, fontSize: 18),
                                    ),
                                  )
                                : (isWide
                                    ? Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Left Column: Artwork & Player Dock (~40%)
                                          SizedBox(
                                            width: (constraints.maxWidth * 0.40)
                                                .clamp(280.0, 440.0),
                                            child: _buildLeftDeck(
                                              context,
                                              tokens,
                                              currentTrack,
                                              isPlaying,
                                              position,
                                              duration,
                                              isShuffle,
                                              repeatMode,
                                              posSeconds,
                                              totalSeconds,
                                              audioHandler,
                                              constraints.maxHeight,
                                            ),
                                          ),
                                          const SizedBox(width: 40),

                                          // Right Column: Giant Synchronized Lyrics (~60%)
                                          Expanded(
                                            child: _buildLyricsDeck(
                                              context,
                                              tokens,
                                              currentTrack,
                                              position,
                                              audioHandler,
                                              isWide: true,
                                            ),
                                          ),
                                        ],
                                      )
                                    : _buildCompactPortraitDeck(
                                        context,
                                        tokens,
                                        currentTrack,
                                        isPlaying,
                                        position,
                                        duration,
                                        isShuffle,
                                        repeatMode,
                                        posSeconds,
                                        totalSeconds,
                                        audioHandler,
                                        constraints,
                                      )),
                          );
                        },
                      ),
                    ),
                  ),

                  // 3. Top HUD Bar (Autohides during idle playback)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      opacity: _hudVisible ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !_hudVisible,
                        child: SafeArea(
                          bottom: false,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 640 &&
                                  constraints.maxWidth > constraints.maxHeight;

                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isWide ? 36 : 20,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    // Clock & Pulse indicator
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: tokens.accent,
                                            boxShadow: [
                                              BoxShadow(
                                                color: tokens.accent.withValues(alpha: 0.6),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatClock(_currentTime),
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontUi,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white70,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isWide) ...[
                                      const SizedBox(width: 14),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            width: 0.6,
                                          ),
                                        ),
                                        child: const Text(
                                          'SCREENSAVER MODE',
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontUi,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2EE66B),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Spacer(),

                                    // Romanize Toggle
                                    IconButton(
                                      tooltip: 'Toggle Romanized Lyrics (L)',
                                      icon: Icon(
                                        Icons.translate_rounded,
                                        size: 19,
                                        color: _romanize ? tokens.accent : Colors.white60,
                                      ),
                                      onPressed: () =>
                                          setState(() => _romanize = !_romanize),
                                    ),
                                    const SizedBox(width: 4),

                                    // Exit Screensaver Button
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: () => Navigator.of(context).maybePop(),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.12),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.close_rounded,
                                                  size: 16, color: Colors.white),
                                              SizedBox(width: 4),
                                              Text(
                                                'Exit',
                                                style: TextStyle(
                                                  fontFamily: AppTheme.fontUi,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactPortraitDeck(
    BuildContext context,
    AppTokens tokens,
    Track track,
    bool isPlaying,
    Duration position,
    Duration duration,
    bool isShuffle,
    AudioRepeatMode repeatMode,
    double posSeconds,
    double totalSeconds,
    SoftifyAudioHandler audioHandler,
    BoxConstraints constraints,
  ) {
    final artSize = (constraints.maxHeight * 0.26).clamp(140.0, 220.0);

    return Column(
      children: [
        // 1. Centered Hero Album Artwork with glow
        Center(
          child: Container(
            width: artSize,
            height: artSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _ambientColor.withValues(alpha: 0.45),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: AppNetworkImage(
                imageUrl: track.coverUrl,
                fit: BoxFit.cover,
                fallbackIcon: Icons.music_note_rounded,
                backgroundColor: tokens.surfaceElevated,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2. Track Title & Artist (Centered, prominent)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedMusicWaveIndicator(
                    isPlaying: isPlaying,
                    size: 12,
                    barCount: 3,
                    color: tokens.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Synchronized Lyrics Viewport (Expanded, centered)
        Expanded(
          child: _buildLyricsDeck(
            context,
            tokens,
            track,
            position,
            audioHandler,
            isWide: false,
          ),
        ),
        const SizedBox(height: 8),

        // 4. Audio Scrubber & Timers
        _buildScrubber(context, tokens, posSeconds, totalSeconds, duration, audioHandler),
        const SizedBox(height: 8),

        // 5. Playback Transport Controls
        _buildControls(tokens, isPlaying, isShuffle, repeatMode, audioHandler),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildLeftDeck(
    BuildContext context,
    AppTokens tokens,
    Track track,
    bool isPlaying,
    Duration position,
    Duration duration,
    bool isShuffle,
    AudioRepeatMode repeatMode,
    double posSeconds,
    double totalSeconds,
    SoftifyAudioHandler audioHandler,
    double maxHeight,
  ) {
    final artSize = (maxHeight * 0.44).clamp(160.0, 340.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hero Album Artwork with vinyl glow
        Center(
          child: Container(
            width: artSize,
            height: artSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _ambientColor.withValues(alpha: 0.45),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 16),
                ),
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: AppNetworkImage(
                imageUrl: track.coverUrl,
                fit: BoxFit.cover,
                fallbackIcon: Icons.music_note_rounded,
                backgroundColor: tokens.surfaceElevated,
              ),
            ),
          ),
        ),
        SizedBox(height: maxHeight > 600 ? 24 : 14),

        // 2. Track Title & Artist
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: maxHeight > 600 ? 24 : 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: maxHeight > 600 ? 15 : 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedMusicWaveIndicator(
              isPlaying: isPlaying,
              size: 14,
              barCount: 4,
              color: tokens.accent,
            ),
          ],
        ),
        SizedBox(height: maxHeight > 600 ? 16 : 10),

        // 3. Audio Scrubber & Timers
        _buildScrubber(context, tokens, posSeconds, totalSeconds, duration, audioHandler),
        SizedBox(height: maxHeight > 600 ? 14 : 8),

        // 4. Playback Controls Dock
        _buildControls(tokens, isPlaying, isShuffle, repeatMode, audioHandler),
      ],
    );
  }

  Widget _buildScrubber(
    BuildContext context,
    AppTokens tokens,
    double posSeconds,
    double totalSeconds,
    Duration duration,
    SoftifyAudioHandler audioHandler,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: tokens.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            thumbColor: Colors.white,
            overlayColor: tokens.accent.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: totalSeconds > 0 ? posSeconds.clamp(0.0, totalSeconds) : 0.0,
            min: 0.0,
            max: totalSeconds > 0 ? totalSeconds : 1.0,
            onChanged: totalSeconds > 0
                ? (val) => setState(() => _dragPositionSeconds = val)
                : null,
            onChangeEnd: totalSeconds > 0
                ? (val) {
                    audioHandler.seek(Duration(seconds: val.round()));
                    setState(() => _dragPositionSeconds = null);
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(seconds: posSeconds.round())),
                style: AppTheme.tabularTimestamp(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              Text(
                _formatDuration(duration),
                style: AppTheme.tabularTimestamp(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(
    AppTokens tokens,
    bool isPlaying,
    bool isShuffle,
    AudioRepeatMode repeatMode,
    SoftifyAudioHandler audioHandler,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Shuffle
        IconButton(
          tooltip: isShuffle ? 'Shuffle On' : 'Shuffle Off',
          icon: Icon(
            Icons.shuffle_rounded,
            size: 22,
            color: isShuffle ? tokens.accent : Colors.white54,
          ),
          splashRadius: 22,
          onPressed: () => audioHandler.setShuffleEnabled(!isShuffle),
        ),

        // Previous
        BouncingScaleButton(
          scaleFactor: 0.9,
          onTap: () {
            HapticFeedback.lightImpact();
            audioHandler.skipToPrevious();
          },
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: const Icon(
              Icons.skip_previous_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
        ),

        // Play / Pause Hero Button
        PlayPauseMorphButton(
          isPlaying: isPlaying,
          size: 56,
          iconSize: 26,
          backgroundColor: tokens.accent,
          iconColor: Colors.black,
          showGlow: true,
          onTap: () {
            HapticFeedback.mediumImpact();
            if (isPlaying) {
              audioHandler.pause();
            } else {
              audioHandler.play();
            }
          },
        ),

        // Next
        BouncingScaleButton(
          scaleFactor: 0.9,
          onTap: () {
            HapticFeedback.lightImpact();
            audioHandler.skipToNext();
          },
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: const Icon(
              Icons.skip_next_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
        ),

        // Repeat Mode
        IconButton(
          tooltip: 'Repeat: ${repeatMode.name}',
          icon: Icon(
            repeatMode == AudioRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            size: 22,
            color: repeatMode != AudioRepeatMode.off ? tokens.accent : Colors.white54,
          ),
          splashRadius: 22,
          onPressed: () => audioHandler.setAudioRepeatMode(repeatMode.next()),
        ),
      ],
    );
  }

  Widget _buildLyricsDeck(
    BuildContext context,
    AppTokens tokens,
    Track track,
    Duration position,
    SoftifyAudioHandler audioHandler, {
    bool isWide = true,
  }) {
    final lyricsAsync = ref.watch(trackLyricsProvider(track));

    return lyricsAsync.when(
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Loading lyrics...',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => _buildNoLyricsFallback(tokens, track, isWide: isWide),
      data: (lyrics) {
        if (lyrics == null || lyrics.lines.isEmpty) {
          return _buildNoLyricsFallback(tokens, track, isWide: isWide);
        }

        final lines = lyrics.lines;
        final activeIndex =
            SpotifyLyricsSynchronizer.findActiveLineIndex(lines, position);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (activeIndex >= 0) {
            _scrollToActiveLine(activeIndex);
          }
        });

        return ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.15, 0.85, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            key: ValueKey('screensaver_lyrics_${track.id}'),
            controller: _lyricsScrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              vertical: isWide ? 90 : 28,
              horizontal: 16,
            ),
            itemCount: lines.length,
            itemBuilder: (context, index) {
              final line = lines[index];
              final isActive = index == activeIndex;
              final isPast = index < activeIndex;

              _lineKeys.putIfAbsent(index, () => GlobalKey());

              final displayText = _romanize
                  ? RomanizationService.romanize(line.text)
                  : line.text;

              return KeyedSubtree(
                key: _lineKeys[index],
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    audioHandler.seek(line.timestamp);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      vertical: isWide ? 12 : 7,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      textAlign: isWide ? TextAlign.left : TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: isWide
                            ? (isActive ? 30 : (isPast ? 20 : 22))
                            : (isActive ? 20 : (isPast ? 14 : 15)),
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        height: 1.3,
                        letterSpacing: isActive ? -0.4 : -0.2,
                        color: isActive
                            ? Colors.white
                            : (isPast
                                ? Colors.white.withValues(alpha: 0.28)
                                : Colors.white.withValues(alpha: 0.45)),
                        shadows: isActive
                            ? [
                                BoxShadow(
                                  color: tokens.accent.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(displayText),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNoLyricsFallback(AppTokens tokens, Track track, {bool isWide = true}) {
    if (!isWide) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.graphic_eq_rounded, size: 16, color: tokens.accent),
              const SizedBox(width: 8),
              Text(
                'Studio Master Audio',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              size: 40,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Studio Master Audio',
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
