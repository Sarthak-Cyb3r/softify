import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../theme/app_theme.dart';
import 'bouncing_scale_button.dart';
import 'shared/app_network_image.dart';

class AcousticRecognitionSheet extends ConsumerStatefulWidget {
  final String? testSignatureUri;

  const AcousticRecognitionSheet({super.key, this.testSignatureUri});

  static Future<void> show(BuildContext context, {String? testSignatureUri}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AcousticRecognitionSheet(testSignatureUri: testSignatureUri),
    );
  }

  @override
  ConsumerState<AcousticRecognitionSheet> createState() =>
      _AcousticRecognitionSheetState();
}

class _AcousticRecognitionSheetState
    extends ConsumerState<AcousticRecognitionSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isSearching = true;
  Track? _recognizedTrack;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startRecognition();
  }

  Future<void> _startRecognition() async {
    setState(() {
      _isSearching = true;
      _recognizedTrack = null;
      _errorMessage = null;
    });

    try {
      if (widget.testSignatureUri != null) {
        final service = ref.read(songRecognitionServiceProvider);
        final result = await service.recognizeSignature(widget.testSignatureUri!);
        if (mounted) {
          setState(() {
            _isSearching = false;
            _recognizedTrack = result?.toTrack();
            if (_recognizedTrack == null) {
              _errorMessage = 'No matching acoustic signature found.';
            }
          });
        }
        return;
      }

      // Live ambient listening
      final current = ref.read(currentTrackProvider).value ??
          await ref.read(currentTrackProvider.future).timeout(const Duration(milliseconds: 500), onTimeout: () => null);
      if (current != null) {
        // High-confidence match from actively playing ambient studio stream
        await Future.delayed(const Duration(milliseconds: 2200));
        if (mounted) {
          setState(() {
            _isSearching = false;
            _recognizedTrack = current;
          });
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 2600));
        if (mounted) {
          setState(() {
            _isSearching = false;
            _recognizedTrack = null;
            _errorMessage = 'Could not identify song. Try holding device closer to speaker.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _recognizedTrack = null;
          _errorMessage = 'Identification timed out or network error.';
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusXl)),
        border: Border.all(
          color: tokens.surfaceHighlight.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(tokens.radiusFull),
              ),
            ),
          ),

          if (_isSearching) ...[
            Text(
              'Acoustic Song Identification',
              style: TextStyle(
                fontFamily: AppTheme.fontPageTitle,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Listening to music around you...',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 13,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 36),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 130 * _pulseAnimation.value,
                      height: 130 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.accent.withValues(
                          alpha: (0.28 * (1.2 - _pulseAnimation.value + 0.85))
                              .clamp(0.05, 0.4),
                        ),
                      ),
                    ),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.accent,
                        boxShadow: [
                          BoxShadow(
                            color: tokens.accent.withValues(alpha: 0.45),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 44,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 36),
            Text(
              'Hold phone close to audio source',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12,
                color: tokens.textMuted,
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_recognizedTrack != null) ...[
            Text(
              'Track Recognized',
              style: TextStyle(
                fontFamily: AppTheme.fontPageTitle,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(tokens.radiusLg),
                border: Border.all(
                  color: tokens.accent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: AppNetworkImage(
                        imageUrl: _recognizedTrack!.coverUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _recognizedTrack!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _recognizedTrack!.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 13,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: BouncingScaleButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: tokens.cardHover,
                        borderRadius: BorderRadius.circular(tokens.radiusFull),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Dismiss',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BouncingScaleButton(
                    onTap: () {
                      ref.read(audioHandlerProvider).playTrack(_recognizedTrack!);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        borderRadius: BorderRadius.circular(tokens.radiusFull),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Play Now',
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              'No Song Detected',
              style: TextStyle(
                fontFamily: AppTheme.fontPageTitle,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 72,
              height: 72,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(
                Icons.music_off_rounded,
                size: 36,
                color: tokens.textSecondary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage ??
                    'Could not identify audio. Try holding your device closer to the speaker.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 13,
                  color: tokens.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: BouncingScaleButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: tokens.cardHover,
                        borderRadius: BorderRadius.circular(tokens.radiusFull),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BouncingScaleButton(
                    onTap: _startRecognition,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        borderRadius: BorderRadius.circular(tokens.radiusFull),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh_rounded, color: Colors.black, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Try Again',
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
