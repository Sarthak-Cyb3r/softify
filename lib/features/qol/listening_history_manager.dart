import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/player/softify_audio_handler.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';

// ==========================================
// 1. Private Listening Mode State & Notifier
// ==========================================

/// StateNotifier that manages Incognito / Private Session state.
/// When enabled, played songs will NOT be recorded to recent playback history,
/// event logs, or personal taste profile insights.
class PrivateListeningModeNotifier extends StateNotifier<bool> {
  final Ref? _ref;
  final AppDatabase? _db;

  PrivateListeningModeNotifier({Ref? ref, AppDatabase? db})
      : _ref = ref,
        _db = db,
        super(false) {
    _loadFromDb();
  }

  /// Expose setter for state to allow StateController-like syntax.
  @override
  set state(bool value) {
    super.state = value;
    _persist(value);
    _syncToAudioHandler(value);
  }

  /// Updates state via a callback function.
  bool update(bool Function(bool state) cb) {
    final next = cb(state);
    state = next;
    return next;
  }

  /// Toggles private session on/off and returns the new state.
  bool toggle() {
    final next = !state;
    state = next;
    return next;
  }

  /// Explicitly enables or disables private listening session.
  void setEnabled(bool enabled) {
    if (state != enabled) {
      state = enabled;
    }
  }

  /// Convenient shorthand to enable private session.
  void enable() => setEnabled(true);

  /// Convenient shorthand to disable private session.
  void disable() => setEnabled(false);

  Future<void> _loadFromDb() async {
    try {
      final db = _db ?? _ref?.read(databaseProvider);
      if (db == null) return;
      final row = await (db.select(db.settings)
            ..where((t) => t.key.equals('private_listening_mode')))
          .getSingleOrNull();
      if (row != null) {
        final loaded = row.value.trim().toLowerCase() == 'true';
        if (state != loaded) {
          super.state = loaded;
          _syncToAudioHandler(loaded);
        }
      }
    } catch (_) {
      // Ignored: database may not be available in standalone tests
    }
  }

  Future<void> _persist(bool enabled) async {
    try {
      final db = _db ?? _ref?.read(databaseProvider);
      if (db == null) return;
      await db.into(db.settings).insertOnConflictUpdate(
            SettingRow(
              key: 'private_listening_mode',
              value: enabled.toString(),
            ),
          );
    } catch (_) {
      // Ignored: database may not be available in standalone tests
    }
  }

  void _syncToAudioHandler(bool enabled) {
    try {
      final SoftifyAudioHandler? handler = _ref?.read(audioHandlerProvider);
      if (handler != null) {
        handler.setPrivateSession(enabled);
      }
    } catch (_) {
      // Audio handler may not be present in widget tests
    }
  }
}

/// Riverpod provider for Private Listening Mode (Incognito mode).
/// Watches/reads yield a [bool] indicating whether private listening is active.
final privateListeningModeProvider =
    StateNotifierProvider<PrivateListeningModeNotifier, bool>((ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {
    // Allows testing in isolation without databaseProvider registered
  }
  return PrivateListeningModeNotifier(ref: ref, db: db);
});

// ==========================================
// 2. Listening History Manager
// ==========================================

/// Coordinator for managing user listening history and privacy mode.
///
/// Provides both static and instance invocations:
/// - [clearAllListeningHistory]: Purges playback history from database and invalidates stream providers.
/// - [togglePrivateSession]: Turns private listening on/off.
class ListeningHistoryManager {
  const ListeningHistoryManager();

  /// Purges play history table and notifies active reactive providers.
  static Future<void> clearAllListeningHistory(WidgetRef ref) async {
    await _performHistoryPurge(ref);
  }

  /// Turns private listening on/off and returns the new private session state.
  static bool togglePrivateSession(WidgetRef ref) {
    HapticFeedback.lightImpact();
    final notifier = ref.read(privateListeningModeProvider.notifier);
    return notifier.toggle();
  }

  /// Reads whether private listening session is currently active.
  static bool isPrivateSessionActive(WidgetRef ref) {
    return ref.watch(privateListeningModeProvider);
  }

  /// Explicitly sets private listening session state.
  static void setPrivateSession(WidgetRef ref, bool enabled) {
    ref.read(privateListeningModeProvider.notifier).setEnabled(enabled);
  }

  /// Shows a confirmation dialog before clearing listening history.
  /// Returns `true` if cleared, `false` or `null` if cancelled.
  static Future<bool?> showClearHistoryDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    Color? surfaceColor;
    Color? textPrimary;
    Color? textSecondary;
    Color? errorColor;

    try {
      final tokens = context.tokens;
      surfaceColor = tokens.surfaceElevated;
      textPrimary = tokens.textPrimary;
      textSecondary = tokens.textSecondary;
      errorColor = tokens.error;
    } catch (_) {
      final theme = Theme.of(context);
      surfaceColor = theme.dialogBackgroundColor;
      textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.white;
      textSecondary = theme.textTheme.bodyMedium?.color ?? Colors.white70;
      errorColor = theme.colorScheme.error;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: errorColor ?? Colors.redAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Clear Play History?',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently remove all tracks from your playback history. Your liked tracks and custom playlists will not be affected.',
          style: TextStyle(
            color: textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: errorColor ?? Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await clearAllListeningHistory(ref);
      return true;
    }
    return false;
  }

  static Future<void> _performHistoryPurge(dynamic ref) async {
    // 1. Clear via Library Repository
    try {
      final libraryRepo = ref.read(libraryRepositoryProvider);
      await libraryRepo.clearPlayHistory();
    } catch (_) {}

    // 2. Direct database delete fallback for full consistency
    try {
      final db = ref.read(databaseProvider);
      if (db is AppDatabase) {
        await db.delete(db.playHistories).go();
      }
    } catch (_) {}

    // 3. Invalidate reactive stream providers
    try {
      ref.invalidate(playHistoryStreamProvider);
    } catch (_) {}
  }
}

/// Extension enabling instance-method syntax on [ListeningHistoryManager].
extension ListeningHistoryManagerInstanceExtension on ListeningHistoryManager {
  Future<void> clearAllListeningHistory(WidgetRef ref) =>
      ListeningHistoryManager.clearAllListeningHistory(ref);

  bool togglePrivateSession(WidgetRef ref) =>
      ListeningHistoryManager.togglePrivateSession(ref);

  bool isPrivateSessionActive(WidgetRef ref) =>
      ListeningHistoryManager.isPrivateSessionActive(ref);

  void setPrivateSession(WidgetRef ref, bool enabled) =>
      ListeningHistoryManager.setPrivateSession(ref, enabled);
}

/// Riverpod provider for [ListeningHistoryManager].
final listeningHistoryManagerProvider =
    Provider<ListeningHistoryManager>((ref) {
  return const ListeningHistoryManager();
});

// ==========================================
// 3. Private Session Banner & Indicators
// ==========================================

/// Discrete indicator banner displayed whenever private listening session is active.
///
/// Features smooth animated collapse/expansion, Liquid Glass / Material styling,
/// and an optional quick-action to turn off the private session.
class PrivateSessionBanner extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool compact;
  final bool showEndButton;
  final VoidCallback? onTurnOff;
  final VoidCallback? onTap;

  const PrivateSessionBanner({
    super.key,
    this.margin,
    this.padding,
    this.compact = false,
    this.showEndButton = true,
    this.onTurnOff,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate = ref.watch(privateListeningModeProvider);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: isPrivate
          ? Padding(
              padding: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildBannerContent(context, ref),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildBannerContent(BuildContext context, WidgetRef ref) {
    Color surfaceColor;
    Color borderColor;
    Color accentColor;
    Color textPrimary;
    Color textSecondary;
    double radius;

    try {
      final tokens = context.tokens;
      surfaceColor = tokens.isGlass
          ? const Color(0xE8161A24)
          : tokens.surfaceElevated.withValues(alpha: 0.95);
      accentColor = tokens.accentViolet;
      borderColor = accentColor.withValues(alpha: 0.35);
      textPrimary = tokens.textPrimary;
      textSecondary = tokens.textSecondary;
      radius = tokens.radiusCard;
    } catch (_) {
      surfaceColor = const Color(0xFF1E2230);
      accentColor = Colors.deepPurpleAccent;
      borderColor = accentColor.withValues(alpha: 0.4);
      textPrimary = Colors.white;
      textSecondary = Colors.white70;
      radius = 16.0;
    }

    if (compact) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off_rounded, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(
                'Private Session Active',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showEndButton) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    ListeningHistoryManager.togglePrivateSession(ref);
                    onTurnOff?.call();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded, size: 14, color: textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            children: [
              // Discreet shield / incognito badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1),
                ),
                child: Icon(
                  Icons.visibility_off_rounded,
                  size: 20,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              // Explanatory texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Private Session',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Incognito',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Playback history and taste profile recommendations are paused.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (showEndButton) ...[
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: accentColor.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    ListeningHistoryManager.togglePrivateSession(ref);
                    onTurnOff?.call();
                  },
                  child: Text(
                    'End',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact pill indicator suitable for AppBar actions or player overlays.
class PrivateSessionPillIndicator extends ConsumerWidget {
  final VoidCallback? onTap;

  const PrivateSessionPillIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate = ref.watch(privateListeningModeProvider);
    if (!isPrivate) return const SizedBox.shrink();

    Color accentColor;
    Color surfaceColor;

    try {
      final tokens = context.tokens;
      accentColor = tokens.accentViolet;
      surfaceColor = tokens.surfaceElevated;
    } catch (_) {
      accentColor = Colors.deepPurpleAccent;
      surfaceColor = const Color(0xFF1E2230);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: 'Private Session is Active',
        child: InkWell(
          onTap: onTap ?? () => ListeningHistoryManager.togglePrivateSession(ref),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_off_rounded, size: 14, color: accentColor),
                const SizedBox(width: 4),
                Text(
                  'Private',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
