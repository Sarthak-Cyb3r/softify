import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet allowing users to set or cancel a playback sleep timer.
class SleepTimerBottomSheet extends ConsumerWidget {
  const SleepTimerBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SleepTimerBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final remainingAsync = ref.watch(sleepTimerRemainingProvider);
    final isEndOfTrackAsync = ref.watch(sleepTimerEndOfTrackProvider);

    final remaining = remainingAsync.value;
    final isEndOfTrack = isEndOfTrackAsync.value ?? false;
    final isTimerActive = (remaining != null && remaining > Duration.zero) || isEndOfTrack;

    final tokens = context.tokens;

    return Material(
      color: tokens.surfaceElevated,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 2. Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.bedtime_rounded,
                      color: tokens.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sleep timer',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Music will pause automatically',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Active Timer Banner (if running)
            if (isTimerActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tokens.accent.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        color: tokens.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isEndOfTrack
                              ? 'Active: Stops at end of current song'
                              : 'Active: ${_formatRemaining(remaining!)} remaining',
                          style: TextStyle(
                            color: tokens.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          audioHandler.cancelSleepTimer();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sleep timer turned off'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Turn off', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),

            const Divider(height: 1, color: Colors.white12),

            // 4. Timer Preset Options
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildOption(
                      context,
                      label: '5 minutes',
                      onTap: () => _applyTimer(context, audioHandler, const Duration(minutes: 5)),
                    ),
                    _buildOption(
                      context,
                      label: '10 minutes',
                      onTap: () => _applyTimer(context, audioHandler, const Duration(minutes: 10)),
                    ),
                    _buildOption(
                      context,
                      label: '15 minutes',
                      onTap: () => _applyTimer(context, audioHandler, const Duration(minutes: 15)),
                    ),
                    _buildOption(
                      context,
                      label: '30 minutes',
                      onTap: () => _applyTimer(context, audioHandler, const Duration(minutes: 30)),
                    ),
                    _buildOption(
                      context,
                      label: '45 minutes',
                      onTap: () => _applyTimer(context, audioHandler, const Duration(minutes: 45)),
                    ),
                    _buildOption(
                      context,
                      label: '1 hour',
                      onTap: () => _applyTimer(context, audioHandler, const Duration(hours: 1)),
                    ),
                    _buildOption(
                      context,
                      label: 'End of this song',
                      icon: Icons.music_note_rounded,
                      onTap: () {
                        audioHandler.setSleepTimerEndOfTrack();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sleep timer set: Audio will pause after this song'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    _buildOption(
                      context,
                      label: 'Custom duration...',
                      icon: Icons.tune_rounded,
                      onTap: () => _showCustomDurationDialog(context, audioHandler),
                    ),
                    if (isTimerActive)
                      _buildOption(
                        context,
                        label: 'Turn off timer',
                        icon: Icons.timer_off_outlined,
                        textColor: Colors.redAccent,
                        iconColor: Colors.redAccent,
                        onTap: () {
                          audioHandler.cancelSleepTimer();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sleep timer turned off'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    IconData? icon,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      dense: true,
      leading: icon != null
          ? Icon(icon, color: iconColor ?? AppTheme.textPrimary, size: 20)
          : const SizedBox(width: 20),
      title: Text(
        label,
        style: TextStyle(
          color: textColor ?? AppTheme.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _applyTimer(BuildContext context, dynamic audioHandler, Duration duration) {
    audioHandler.setSleepTimer(duration);
    Navigator.pop(context);
    final mins = duration.inMinutes;
    final label = mins >= 60 ? '${(mins / 60).toStringAsFixed(0)} hour' : '$mins minutes';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sleep timer set for $label'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showCustomDurationDialog(BuildContext context, dynamic audioHandler) async {
    final controller = TextEditingController(text: '20');
    final tokens = context.tokens;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          title: Row(
            children: [
              Icon(Icons.bedtime_rounded, color: tokens.accent, size: 22),
              const SizedBox(width: 10),
              Text(
                'Custom Sleep Timer',
                style: TextStyle(color: tokens.textPrimary, fontSize: 17),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter minutes before music stops (1 - 1440):',
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: tokens.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: tokens.surface,
                  suffixText: 'mins',
                  suffixStyle: TextStyle(color: tokens.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: tokens.accent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed != null && parsed > 0) {
                  Navigator.pop(ctx, parsed.clamp(1, 1440));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: const Color(0xFF080F11),
              ),
              child: const Text('Set Timer'),
            ),
          ],
        );
      },
    );

    if (result != null && context.mounted) {
      _applyTimer(context, audioHandler, Duration(minutes: result));
    }
  }

  String _formatRemaining(Duration duration) {
    if (duration.isNegative) return '0s';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${seconds}s';
    }
  }
}
