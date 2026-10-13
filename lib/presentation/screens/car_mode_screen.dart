import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import '../theme/app_tokens.dart';
import '../widgets/bouncing_scale_button.dart';

/// High-contrast, large-touch-target Driving Interface for automotive head units & car mounts.
class CarModeScreen extends ConsumerStatefulWidget {
  const CarModeScreen({super.key});

  @override
  ConsumerState<CarModeScreen> createState() => _CarModeScreenState();
}

class _CarModeScreenState extends ConsumerState<CarModeScreen> {
  @override
  void initState() {
    super.initState();
    // Allow landscape orientation while in car mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
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

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Header: Exit button & Car Mode Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: tokens.accent, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.directions_car_filled_rounded, color: tokens.accent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'CAR MODE',
                              style: TextStyle(
                                color: tokens.accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  BouncingScaleButton(
                    scaleFactor: 0.9,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Middle: Large Track & Artist Typography
              if (currentTrack != null) ...[
                Text(
                  currentTrack.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  currentTrack.artist,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
              ] else ...[
                const Icon(Icons.music_off_rounded, color: Colors.white38, size: 64),
                const SizedBox(height: 12),
                const Text(
                  'No music playing',
                  style: TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],

              const Spacer(),

              // Large Driving Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Previous Track
                  BouncingScaleButton(
                    scaleFactor: 0.88,
                    onTap: () => audioHandler.skipToPrevious(),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 40),
                    ),
                  ),

                  // Big Play / Pause Target (96x96)
                  BouncingScaleButton(
                    scaleFactor: 0.92,
                    onTap: () {
                      if (isPlaying) {
                        audioHandler.pause();
                      } else {
                        audioHandler.play();
                      }
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: tokens.accent, blurRadius: 24, spreadRadius: -4),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 56,
                      ),
                    ),
                  ),

                  // Next Track
                  BouncingScaleButton(
                    scaleFactor: 0.88,
                    onTap: () => audioHandler.skipToNext(),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 40),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
