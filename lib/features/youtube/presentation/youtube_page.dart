import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';
import '../../../presentation/widgets/shimmer_skeleton.dart';
import '../../../presentation/widgets/shared/app_dialog.dart';
import '../../../presentation/widgets/shared/app_network_image.dart';
import '../../../presentation/widgets/track_options_bottom_sheet.dart';
import '../domain/parse_youtube_link.dart';
import 'youtube_controller.dart';

class YoutubePage extends ConsumerStatefulWidget {
  const YoutubePage({super.key});

  @override
  ConsumerState<YoutubePage> createState() => _YoutubePageState();
}

class _YoutubePageState extends ConsumerState<YoutubePage>
    with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _detectedClipboardUrl;

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
        final parsed = parseYoutubeLink(text);
        if (parsed is! InvalidLink) {
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
      ref.read(youtubeControllerProvider.notifier).submit(text);
      if (_detectedClipboardUrl == text) {
        setState(() => _detectedClipboardUrl = null);
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '--:--';
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final youtubeState = ref.watch(youtubeControllerProvider);
    final historyAsync = ref.watch(youtubeRecentHistoryProvider);

    return Scaffold(
      backgroundColor: tokens.isGlass ? Colors.transparent : tokens.background,
      appBar: AppBar(
        backgroundColor:
            tokens.isGlass ? Colors.transparent : tokens.background,
        elevation: 0,
        title: Text(
          'Paste a Link',
          style: TextStyle(
            fontFamily: AppTheme.fontDisplay,
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
                  // Text input row with Paste and Clear icons
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
                      fillColor: tokens.isGlass ? tokens.glassSurface : tokens.card,
                      hintText: 'Paste YouTube link (watch, youtu.be, shorts)...',
                      hintStyle: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.smart_display_outlined,
                        color: tokens.isGlass ? tokens.accentCyan : tokens.accent,
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
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                        borderSide: tokens.isGlass
                            ? BorderSide(color: tokens.glassBorder, width: 1.0)
                            : BorderSide(
                                color: tokens.surfaceHighlight,
                                width: 1,
                              ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                        borderSide: tokens.isGlass
                            ? BorderSide(color: tokens.glassBorder, width: 1.0)
                            : BorderSide(
                                color: tokens.surfaceHighlight,
                                width: 1,
                              ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                        borderSide: BorderSide(
                          color: tokens.isGlass ? tokens.accentCyan : tokens.accent,
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
                                  BorderRadius.circular(tokens.radiusPill),
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
                                  'Play Audio',
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
                      borderRadius: BorderRadius.circular(tokens.radiusCard),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(tokens.radiusCard),
                          border: Border.all(
                            color: tokens.accent.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.smart_display_rounded,
                              color: tokens.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Play copied link?',
                                    style: TextStyle(
                                      color: tokens.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _detectedClipboardUrl!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: tokens.accent,
                              size: 14,
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

          // 2. Middle Section: Dynamic State (Loading, Error, Ready, Empty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildMiddleSection(context, tokens, youtubeState),
            ),
          ),

          // 3. Bottom Section: Recent Links History Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Links',
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  historyAsync.maybeWhen(
                    data: (items) => (items.isNotEmpty)
                        ? TextButton(
                            onPressed: () => _confirmClearHistory(context),
                            child: Text(
                              'Clear all',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Section: Recent History Items List
          historyAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No recent links played yet.',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = items[index] as YoutubeHistoryRow;
                    return _buildHistoryItem(context, tokens, item);
                  },
                  childCount: items.length,
                ),
              );
            },
            loading: () => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ShimmerSkeleton(
                        width: double.infinity,
                        height: 60,
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load history',
                  style: TextStyle(color: tokens.textMuted, fontSize: 13),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 140),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleSection(
    BuildContext context,
    AppTokens tokens,
    YoutubeState state,
  ) {
    if (state is YoutubeLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          border: Border.all(color: tokens.surfaceHighlight),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ShimmerSkeleton(
                  width: 72,
                  height: 72,
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerSkeleton(
                        width: 180,
                        height: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      ShimmerSkeleton(
                        width: 110,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Extracting audio stream...',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (state is YoutubeErrorState) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          border: Border.all(
            color: AppTheme.error.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.error,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Playback Error',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.failure.userMessage,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    ref.read(youtubeControllerProvider.notifier).reset();
                  },
                  child: Text(
                    'Dismiss',
                    style: TextStyle(color: tokens.textMuted, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.surfaceHighlight,
                    foregroundColor: tokens.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusFull),
                    ),
                  ),
                  onPressed: () {
                    ref.read(youtubeControllerProvider.notifier).retry();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (state is YoutubeReady) {
      final track = state.track;
      final pbState = ref.watch(playbackStateStreamProvider).value;
      final currentTrack = ref.watch(currentTrackProvider).value;
      final currentSpeed = ref.watch(playbackSpeedStreamProvider).value ??
          ref.watch(audioHandlerProvider).speed;
      final isPlayingThisTrack =
          currentTrack?.id == track.id && (pbState?.playing ?? false);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.isGlass ? tokens.glassSurface : tokens.card,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          border: tokens.isGlass
              ? Border.all(color: tokens.glassBorder, width: 1.0)
              : null,
          boxShadow: tokens.isGlass ? tokens.cardShadow : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.audiotrack_rounded,
                        color: tokens.accent,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AUDIO STREAM ACTIVE',
                        style: TextStyle(
                          color: tokens.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.startSeconds != null && state.startSeconds! > 0)
                  Text(
                    'Started at ${_formatDuration(state.startSeconds!)}',
                    style: AppTheme.tabularTimestamp(
                      color: tokens.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Track details
            Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: tokens.surfaceHighlight,
                    child: AppNetworkImage(
                      imageUrl: track.coverUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholderIcon: Icons.music_note_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Title and Artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(track.duration.inSeconds),
                        style: AppTheme.tabularTimestamp(
                          color: tokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Actions row: Play/Pause and More Options
            Row(
              children: [
                // Toggle Play/Pause
                IconButton.filledTonal(
                  icon: Icon(
                    isPlayingThisTrack
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: tokens.accent,
                  ),
                  onPressed: () {
                    final audioHandler = ref.read(audioHandlerProvider);
                    if (isPlayingThisTrack) {
                      audioHandler.pause();
                    } else {
                      audioHandler.play();
                    }
                  },
                ),
                const Spacer(),
                // More Options (Save to playlist, download, etc.)
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: tokens.textSecondary,
                  ),
                  onPressed: () {
                    TrackOptionsBottomSheet.show(context, track: track);
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Playback Speed Controls (1x, 1.5x, 2x, 2.5x, 3x)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: tokens.surfaceHighlight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(tokens.radiusCard),
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
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (currentSpeed - spd).abs() < 0.05
                                ? tokens.accent
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(tokens.radiusPill),
                          ),
                          child: Text(
                            spd == 1.0
                                ? '1x'
                                : (spd == 2.0
                                    ? '2x'
                                    : (spd == 3.0 ? '3x' : '${spd}x')),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: (currentSpeed - spd).abs() < 0.05
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

            // If Playlist detected: "Play whole playlist" button
            if (state.playlistTracks != null &&
                state.playlistTracks!.isNotEmpty) ...[
              const Divider(height: 24, thickness: 0.5),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.playlist_play_rounded, color: tokens.accent),
                  label: Text(
                    'Play all (${state.playlistTracks!.length} tracks)',
                    style: TextStyle(
                      color: tokens.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: tokens.accent.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusFull),
                    ),
                  ),
                  onPressed: () {
                    ref
                        .read(youtubeControllerProvider.notifier)
                        .playWholePlaylist();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Queued ${state.playlistTracks!.length} videos',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Default: Clean Empty State
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: tokens.isGlass ? tokens.glassSurface : tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(
          color: tokens.isGlass
              ? tokens.glassBorder
              : tokens.surfaceHighlight.withValues(alpha: 0.5),
        ),
        boxShadow: tokens.isGlass ? tokens.cardShadow : null,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_display_outlined,
              color: tokens.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Paste any YouTube link to listen audio-only.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'High-fidelity pure audio streaming with screen off background playback, lock screen controls, and automatic offline history.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    AppTokens tokens,
    YoutubeHistoryRow item,
  ) {
    return Dismissible(
      key: ValueKey(item.videoId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppTheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(youtubeHistoryDaoProvider).deleteEntry(item.videoId);
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          child: Container(
            width: 48,
            height: 48,
            color: tokens.surfaceElevated,
            child: AppNetworkImage(
              imageUrl: item.thumbnailUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholderIcon: Icons.smart_display_rounded,
            ),
          ),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${item.channel} • ${_formatDuration(item.durationSeconds)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.tabularTimestamp(
            color: tokens.textMuted,
            fontSize: 12,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.play_circle_fill_rounded,
            color: tokens.accent,
            size: 32,
          ),
          onPressed: () {
            ref.read(youtubeControllerProvider.notifier).submit(item.videoId);
          },
        ),
        onTap: () {
          ref.read(youtubeControllerProvider.notifier).submit(item.videoId);
        },
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Clear YouTube History?',
      message:
          'This will remove all recently played YouTube links from your history.',
      confirmText: 'Clear All',
      cancelText: 'Cancel',
      isDestructive: true,
    );
    if (confirmed == true) {
      ref.read(youtubeHistoryDaoProvider).clearAll();
    }
  }
}
