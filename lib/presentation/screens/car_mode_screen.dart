import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/shared/app_network_image.dart';

/// High-contrast, large-touch-target Driving Interface for automotive head units & car mounts.
class CarModeScreen extends ConsumerStatefulWidget {
  const CarModeScreen({super.key});

  @override
  ConsumerState<CarModeScreen> createState() => _CarModeScreenState();
}

class _CarModeScreenState extends ConsumerState<CarModeScreen> {
  Timer? _clockTimer;
  String _timeString = '00:00';

  @override
  void initState() {
    super.initState();
    // Allow landscape orientation while in car mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final formatted = '$hour:$minute';
    if (mounted) {
      setState(() {
        _timeString = formatted;
      });
    } else {
      _timeString = formatted;
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    // Restore default portrait on mobile
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentTrack = ref.watch(currentTrackProvider).value;
    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final audioHandler = ref.watch(audioHandlerProvider);
    final isPlaying = playbackState?.playing ?? false;
    final isLikedAsync = currentTrack != null
        ? ref.watch(isTrackLikedProvider(currentTrack.id))
        : null;
    final isLiked = isLikedAsync?.value ?? currentTrack?.isLiked ?? false;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Header: Exit button, Car Audio pill & Live Clock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BouncingScaleButton(
                    scaleFactor: 0.95,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated,
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, color: tokens.textPrimary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Exit',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: tokens.card,
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_connected_rounded, color: tokens.accent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Car Audio',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _timeString,
                    style: AppTheme.tabularTimestamp(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Body Content
              Expanded(
                child: isLandscape
                    ? _buildLandscapeLayout(tokens, currentTrack, isPlaying, audioHandler, isLiked)
                    : _buildPortraitLayout(tokens, currentTrack, isPlaying, audioHandler, isLiked),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(
    AppTokens tokens,
    Track? currentTrack,
    bool isPlaying,
    AudioHandler audioHandler,
    bool isLiked,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Album art container
        _buildAlbumArt(tokens, currentTrack, 240),
        // Title & Artist
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Text(
                currentTrack?.title ?? 'No music playing',
                style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                currentTrack?.artist ?? 'Select a track to start playback',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: tokens.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // Big Controls
        _buildControlsRow(tokens, isPlaying, audioHandler),
        // Favorite button
        if (currentTrack != null)
          _buildFavoriteButton(tokens, currentTrack, isLiked)
        else
          const SizedBox(height: 52),
      ],
    );
  }

  Widget _buildLandscapeLayout(
    AppTokens tokens,
    Track? currentTrack,
    bool isPlaying,
    AudioHandler audioHandler,
    bool isLiked,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAlbumArt(tokens, currentTrack, 150),
              const SizedBox(height: 8),
              Text(
                currentTrack?.title ?? 'No music playing',
                style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                currentTrack?.artist ?? '',
                style: TextStyle(
                  fontSize: 15,
                  color: tokens.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlsRow(tokens, isPlaying, audioHandler),
              if (currentTrack != null) ...[
                const SizedBox(height: 16),
                _buildFavoriteButton(tokens, currentTrack, isLiked),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumArt(AppTokens tokens, Track? track, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: AppNetworkImage(
        imageUrl: track?.coverUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderIcon: Icons.music_note_rounded,
      ),
    );
  }


  Widget _buildControlsRow(AppTokens tokens, bool isPlaying, AudioHandler audioHandler) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BouncingScaleButton(
          scaleFactor: 0.9,
          onTap: () => audioHandler.skipToPrevious(),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.skip_previous_rounded,
              color: tokens.textPrimary,
              size: 34,
            ),
          ),
        ),
        const SizedBox(width: 28),
        BouncingScaleButton(
          scaleFactor: 0.93,
          onTap: () {
            if (isPlaying) {
              audioHandler.pause();
            } else {
              audioHandler.play();
            }
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: tokens.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 46,
            ),
          ),
        ),
        const SizedBox(width: 28),
        BouncingScaleButton(
          scaleFactor: 0.9,
          onTap: () => audioHandler.skipToNext(),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.skip_next_rounded,
              color: tokens.textPrimary,
              size: 34,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton(AppTokens tokens, Track track, bool isLiked) {
    return BouncingScaleButton(
      scaleFactor: 0.9,
      onTap: () {
        ref.read(libraryRepositoryProvider).setLiked(track.id, !isLiked, track: track);
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isLiked ? tokens.accent : tokens.textSecondary,
          size: 28,
        ),
      ),
    );
  }
}
