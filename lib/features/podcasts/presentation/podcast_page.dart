import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';
import '../../../presentation/widgets/shimmer_skeleton.dart';
import '../domain/parse_podcast_link.dart';
import 'podcast_controller.dart';

class PodcastPage extends ConsumerStatefulWidget {
  const PodcastPage({super.key});

  @override
  ConsumerState<PodcastPage> createState() => _PodcastPageState();
}

class _PodcastPageState extends ConsumerState<PodcastPage>
    with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _detectedClipboardUrl;
  bool _showDescription = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim();
      if (text != null && text.isNotEmpty) {
        final parsed = parsePodcastLink(text);
        if (parsed is! InvalidPodcastLink) {
          if (mounted && _detectedClipboardUrl != text) {
            setState(() {
              _detectedClipboardUrl = text;
            });
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted && _detectedClipboardUrl != null) {
      setState(() {
        _detectedClipboardUrl = null;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty) {
        _urlController.text = text;
        setState(() {});
        _submitCurrentText();
      }
    } catch (_) {}
  }

  void _submitCurrentText() {
    final text = _urlController.text.trim();
    if (text.isNotEmpty) {
      _focusNode.unfocus();
      ref.read(podcastControllerProvider.notifier).submit(text);
      if (_detectedClipboardUrl == text) {
        setState(() => _detectedClipboardUrl = null);
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDurationMinutes(Duration d) {
    final m = d.inMinutes;
    if (m <= 0) return '';
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem > 0 ? '${h}h ${rem}m' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final podcastState = ref.watch(podcastControllerProvider);
    final historyAsync = ref.watch(podcastRecentHistoryProvider);
    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final isPlaying = playbackState?.playing ?? false;
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final currentSpeed = ref.watch(playbackSpeedStreamProvider).value ??
        ref.watch(audioHandlerProvider).speed;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(
          'Podcasts',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: tokens.textPrimary,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Top Input & Actions Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _urlController,
                    focusNode: _focusNode,
                    cursorColor: tokens.accent,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _submitCurrentText(),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: tokens.surfaceElevated,
                      hintText: 'Paste Spotify episode, show link, or podcast name...',
                      hintStyle: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.podcasts_rounded,
                        color: tokens.accent,
                        size: 22,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_urlController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: tokens.textSecondary,
                                size: 18,
                              ),
                              onPressed: () {
                                _urlController.clear();
                                setState(() {});
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.content_paste_rounded,
                              color: tokens.textSecondary,
                              size: 18,
                            ),
                            tooltip: 'Paste from clipboard',
                            onPressed: _pasteFromClipboard,
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusFull),
                        borderSide: BorderSide(
                          color: tokens.surfaceHighlight,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusFull),
                        borderSide: BorderSide(
                          color: tokens.surfaceHighlight,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusFull),
                        borderSide: BorderSide(
                          color: tokens.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Play Button
                  Row(
                    children: [
                      Expanded(
                        child: BouncingScaleButton(
                          onTap: _submitCurrentText,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: tokens.accent,
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusFull),
                              boxShadow: [
                                BoxShadow(
                                  color: tokens.accent.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Load & Play',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Clipboard Chip: "Play copied link?"
                  if (_detectedClipboardUrl != null) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        _urlController.text = _detectedClipboardUrl!;
                        _submitCurrentText();
                      },
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(tokens.radiusMd),
                          border: Border.all(
                            color: tokens.accent.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.podcasts_rounded,
                              color: tokens.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Play copied podcast link?',
                                    style: TextStyle(
                                      color: tokens.accent,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _detectedClipboardUrl!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tokens.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: tokens.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 2. State Content: Loading / Error / Active Card
          if (podcastState is PodcastLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(tokens.radiusLg),
                    border: Border.all(
                      color: tokens.surfaceHighlight,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ShimmerSkeleton(
                        width: 60,
                        height: 60,
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerSkeleton(
                              width: 180,
                              height: 14,
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                            ),
                            const SizedBox(height: 8),
                            ShimmerSkeleton(
                              width: 100,
                              height: 11,
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Resolving audio stream...',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (podcastState is PodcastErrorState)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(tokens.radiusLg),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          podcastState.failure.userMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(podcastControllerProvider.notifier).retry();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (podcastState is PodcastReady)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(tokens.radiusLg),
                    border: Border.all(
                      color: tokens.surfaceHighlight,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Episode Meta Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusMd),
                            child: podcastState.episode.coverUrl != null
                                ? Image.network(
                                    podcastState.episode.coverUrl!,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 72,
                                      height: 72,
                                      color: tokens.surfaceHighlight,
                                      child: Icon(
                                        Icons.podcasts_rounded,
                                        color: tokens.accent,
                                        size: 32,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 72,
                                    height: 72,
                                    color: tokens.surfaceHighlight,
                                    child: Icon(
                                      Icons.podcasts_rounded,
                                      color: tokens.accent,
                                      size: 32,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  podcastState.episode.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  podcastState.episode.showName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: tokens.accent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Duration: ${_formatDuration(podcastState.episode.duration.inSeconds)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tokens.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Player Controls Bar (15s back, Play/Pause, 30s forward)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 28,
                            tooltip: 'Rewind 15 seconds',
                            icon: const Icon(Icons.replay_10_rounded),
                            color: tokens.textPrimary,
                            onPressed: () {
                              ref
                                  .read(podcastControllerProvider.notifier)
                                  .skipBackward(15);
                            },
                          ),
                          const SizedBox(width: 20),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tokens.accent,
                            ),
                            child: IconButton(
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 30,
                              ),
                              onPressed: () {
                                final audioHandler =
                                    ref.read(audioHandlerProvider);
                                if (isPlaying) {
                                  audioHandler.pause();
                                } else {
                                  audioHandler.play();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            iconSize: 28,
                            tooltip: 'Skip 30 seconds',
                            icon: const Icon(Icons.forward_30_rounded),
                            color: tokens.textPrimary,
                            onPressed: () {
                              ref
                                  .read(podcastControllerProvider.notifier)
                                  .skipForward(30);
                            },
                          ),
                        ],
                      ),

                      // Scrubber Progress & Timers
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final durationSec =
                              podcastState.episode.duration.inSeconds > 0
                                  ? podcastState.episode.duration.inSeconds
                                  : 1;
                          final currentSec =
                              position.inSeconds.clamp(0, durationSec);

                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: tokens.accent,
                                  inactiveTrackColor: tokens.surfaceHighlight,
                                  thumbColor: tokens.accent,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 10,
                                  ),
                                  trackHeight: 3,
                                ),
                                child: Slider(
                                  value: currentSec.toDouble(),
                                  max: durationSec.toDouble(),
                                  onChanged: (val) {
                                    ref
                                        .read(audioHandlerProvider)
                                        .seek(Duration(seconds: val.toInt()));
                                  },
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(currentSec),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(durationSec),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // Playback Speed Controls (1x, 1.5x, 2x, 2.5x, 3x)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceHighlight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(tokens.radiusMd),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              size: 15,
                              color: tokens.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Speed',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            for (final spd in const [1.0, 1.5, 2.0, 2.5, 3.0])
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    ref.read(audioHandlerProvider).setSpeed(spd);
                                  },
                                  borderRadius:
                                      BorderRadius.circular(tokens.radiusSm),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (currentSpeed - spd).abs() < 0.05
                                          ? tokens.accent
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(tokens.radiusSm),
                                    ),
                                    child: Text(
                                      spd == 1.0
                                          ? '1x'
                                          : (spd == 2.0
                                              ? '2x'
                                              : (spd == 3.0 ? '3x' : '${spd}x')),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                            (currentSpeed - spd).abs() < 0.05
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                        color: (currentSpeed - spd).abs() < 0.05
                                            ? Colors.black
                                            : tokens.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Collapsible Show Notes
                      if (podcastState.episode.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showDescription = !_showDescription;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  'Episode Notes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _showDescription
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: tokens.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showDescription)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              podcastState.episode.description,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: tokens.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Show Banner (if show metadata is present)
          if (podcastState is PodcastReady && podcastState.show != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(tokens.radiusLg),
                    border: Border.all(
                      color: tokens.surfaceHighlight,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                        child: podcastState.show!.coverUrl != null
                            ? Image.network(
                                podcastState.show!.coverUrl!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 72,
                                  height: 72,
                                  color: tokens.surfaceHighlight,
                                  child: Icon(Icons.podcasts_rounded, color: tokens.accent, size: 32),
                                ),
                              )
                            : Container(
                                width: 72,
                                height: 72,
                                color: tokens.surfaceHighlight,
                                child: Icon(Icons.podcasts_rounded, color: tokens.accent, size: 32),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              podcastState.show!.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              podcastState.show!.publisher,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${podcastState.feedEpisodes?.length ?? 0} Episodes Available',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Show Episodes Section
          if (podcastState is PodcastReady &&
              podcastState.feedEpisodes != null &&
              podcastState.feedEpisodes!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'ALL EPISODES (${podcastState.feedEpisodes!.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: tokens.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final ep = podcastState.feedEpisodes![index];
                  final isCurrent = ep.id == podcastState.episode.id || ep.title == podcastState.episode.title;
                  final dateStr = ep.releaseDate != null ? _formatDate(ep.releaseDate) : '';
                  final durStr = ep.duration.inSeconds > 0 ? _formatDurationMinutes(ep.duration) : '';
                  final metaInfo = [if (dateStr.isNotEmpty) dateStr, if (durStr.isNotEmpty) durStr].join(' • ');

                  return InkWell(
                    onTap: () {
                      ref.read(podcastControllerProvider.notifier).playEpisode(ep);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? tokens.accent.withValues(alpha: 0.08)
                              : tokens.surfaceElevated.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(tokens.radiusMd),
                          border: Border.all(
                            color: isCurrent
                                ? tokens.accent.withValues(alpha: 0.35)
                                : tokens.surfaceHighlight.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(tokens.radiusSm),
                              child: ep.coverUrl != null
                                  ? Image.network(
                                      ep.coverUrl!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 48,
                                        height: 48,
                                        color: tokens.surfaceHighlight,
                                        child: Icon(Icons.podcasts_rounded, color: tokens.accent, size: 20),
                                      ),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: tokens.surfaceHighlight,
                                      child: Icon(Icons.podcasts_rounded, color: tokens.accent, size: 20),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ep.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                      color: isCurrent ? tokens.accent : tokens.textPrimary,
                                    ),
                                  ),
                                  if (metaInfo.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      metaInfo,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isCurrent
                                  ? (isPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded)
                                  : Icons.play_circle_outline_rounded,
                              color: isCurrent ? tokens.accent : tokens.textSecondary,
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: podcastState.feedEpisodes!.length,
              ),
            ),
          ],

          // 3. History Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Text(
                    'RECENTLY PLAYED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: tokens.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  historyAsync.maybeWhen(
                    data: (list) => list.isNotEmpty
                        ? Text(
                            '${list.length} episodes',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textMuted,
                            ),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // 4. History List
          historyAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load history: $e',
                  style: TextStyle(color: tokens.textMuted),
                ),
              ),
            ),
            data: (historyList) {
              if (historyList.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.podcasts_outlined,
                            size: 48,
                            color: tokens.textMuted.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No podcast episodes played yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: tokens.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Paste any Spotify episode link to begin listening',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textMuted.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = historyList[index];
                    final progressPercent = item.durationSeconds > 0
                        ? ((item.resumePositionMs / 1000) /
                                item.durationSeconds)
                            .clamp(0.0, 1.0)
                        : 0.0;

                    return Dismissible(
                      key: Key('podcast_hist_${item.episodeId}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red.withValues(alpha: 0.2),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                        ),
                      ),
                      onDismissed: (_) {
                        ref
                            .read(podcastControllerProvider.notifier)
                            .deleteHistory(item.episodeId);
                      },
                      child: InkWell(
                        onTap: () {
                          ref
                              .read(podcastControllerProvider.notifier)
                              .resumeFromHistory(item);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(tokens.radiusSm),
                                child: item.thumbnailUrl != null
                                    ? Image.network(
                                        item.thumbnailUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          width: 50,
                                          height: 50,
                                          color: tokens.surfaceElevated,
                                          child: Icon(
                                            Icons.podcasts_rounded,
                                            color: tokens.accent,
                                            size: 24,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 50,
                                        height: 50,
                                        color: tokens.surfaceElevated,
                                        child: Icon(
                                          Icons.podcasts_rounded,
                                          color: tokens.accent,
                                          size: 24,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.showName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Resume Progress Bar
                                    if (progressPercent > 0.05) ...[
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: progressPercent,
                                          minHeight: 2.5,
                                          backgroundColor:
                                              tokens.surfaceHighlight,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            tokens.accent,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                    ],
                                    Text(
                                      item.resumePositionMs > 3000
                                          ? 'Resumes at ${_formatDuration((item.resumePositionMs / 1000).round())}'
                                          : _formatDuration(
                                              item.durationSeconds),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color:
                                      tokens.textMuted.withValues(alpha: 0.6),
                                ),
                                onPressed: () {
                                  ref
                                      .read(podcastControllerProvider.notifier)
                                      .deleteHistory(item.episodeId);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: historyList.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }
}
