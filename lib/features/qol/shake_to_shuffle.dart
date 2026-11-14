// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/player/softify_audio_handler.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/bouncing_scale_button.dart';
import '../../presentation/widgets/shared/app_surface.dart';
import '../../presentation/widgets/shared/app_toast.dart';

// ============================================================================
// Enums & Models
// ============================================================================

/// Sensitivity levels for detecting device shake motions.
enum ShakeSensitivity {
  low(
    label: 'Low',
    threshold: 22.0,
    requiredSpikes: 2,
    description: 'Requires a vigorous shake to prevent accidental triggers',
  ),
  medium(
    label: 'Medium',
    threshold: 16.5,
    requiredSpikes: 2,
    description: 'Balanced sensitivity for everyday listening',
  ),
  high(
    label: 'High',
    threshold: 12.5,
    requiredSpikes: 1,
    description: 'Sensitive to lighter shakes with minimal effort',
  );

  final String label;
  final double threshold;
  final int requiredSpikes;
  final String description;

  const ShakeSensitivity({
    required this.label,
    required this.threshold,
    required this.requiredSpikes,
    required this.description,
  });

  static ShakeSensitivity fromString(String? val) {
    if (val == null) return ShakeSensitivity.medium;
    return ShakeSensitivity.values.firstWhere(
      (e) =>
          e.name.toLowerCase() == val.toLowerCase() ||
          e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => ShakeSensitivity.medium,
    );
  }
}

/// Available actions when a valid device shake is detected.
enum ShakeAction {
  skipNext(
    title: 'Skip to Next Track',
    shortLabel: 'Skip Track',
    description: 'Instantly skips to the next track in the queue',
    icon: Icons.skip_next_rounded,
  ),
  shuffleQueue(
    title: 'Shuffle Current Queue',
    shortLabel: 'Shuffle Queue',
    description: 'Re-shuffles the current queue and continues playback',
    icon: Icons.shuffle_rounded,
  );

  final String title;
  final String shortLabel;
  final String description;
  final IconData icon;

  const ShakeAction({
    required this.title,
    required this.shortLabel,
    required this.description,
    required this.icon,
  });

  static ShakeAction fromString(String? val) {
    if (val == null) return ShakeAction.skipNext;
    return ShakeAction.values.firstWhere(
      (e) =>
          e.name.toLowerCase() == val.toLowerCase() ||
          e.title.toLowerCase() == val.toLowerCase(),
      orElse: () => ShakeAction.skipNext,
    );
  }
}

/// Encapsulates metadata about a triggered shake event.
class ShakeTriggerEvent {
  final ShakeAction action;
  final ShakeSensitivity sensitivity;
  final bool isSimulation;
  final DateTime timestamp;

  const ShakeTriggerEvent({
    required this.action,
    required this.sensitivity,
    this.isSimulation = false,
    required this.timestamp,
  });
}

// ============================================================================
// Database & State Helpers
// ============================================================================

AppDatabase? _safeGetDb(Ref ref) {
  try {
    return ref.read(databaseProvider);
  } catch (_) {
    return null;
  }
}

// ============================================================================
// State Notifiers & Riverpod Providers
// ============================================================================

/// Notifier managing whether shake to shuffle / skip is enabled.
class ShakeToShuffleEnabledNotifier extends StateNotifier<bool> {
  final AppDatabase? _db;

  ShakeToShuffleEnabledNotifier(this._db) : super(false) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    if (_db == null) return;
    try {
      final row = await (_db.select(_db.settings)
            ..where((t) => t.key.equals('shake_to_shuffle_enabled')))
          .getSingleOrNull();
      if (row != null) {
        state = row.value.toLowerCase() == 'true';
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    if (_db != null) {
      try {
        await _db.into(_db.settings).insertOnConflictUpdate(
              SettingRow(
                key: 'shake_to_shuffle_enabled',
                value: enabled.toString(),
              ),
            );
      } catch (_) {}
    }
  }

  Future<void> toggle() => setEnabled(!state);
}

/// Provider exposing whether shake motion detection is currently enabled.
final shakeToShuffleEnabledProvider =
    StateNotifierProvider<ShakeToShuffleEnabledNotifier, bool>((ref) {
  final db = _safeGetDb(ref);
  return ShakeToShuffleEnabledNotifier(db);
});

/// Notifier managing the current shake sensitivity preset.
class ShakeSensitivityNotifier extends StateNotifier<ShakeSensitivity> {
  final AppDatabase? _db;

  ShakeSensitivityNotifier(this._db) : super(ShakeSensitivity.medium) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    if (_db == null) return;
    try {
      final row = await (_db.select(_db.settings)
            ..where((t) => t.key.equals('shake_to_shuffle_sensitivity')))
          .getSingleOrNull();
      if (row != null) {
        state = ShakeSensitivity.fromString(row.value);
      }
    } catch (_) {}
  }

  Future<void> setSensitivity(ShakeSensitivity sensitivity) async {
    if (state == sensitivity) return;
    state = sensitivity;
    if (_db != null) {
      try {
        await _db.into(_db.settings).insertOnConflictUpdate(
              SettingRow(
                key: 'shake_to_shuffle_sensitivity',
                value: sensitivity.name,
              ),
            );
      } catch (_) {}
    }
  }
}

/// Provider exposing the configured shake sensitivity.
final shakeSensitivityProvider =
    StateNotifierProvider<ShakeSensitivityNotifier, ShakeSensitivity>((ref) {
  final db = _safeGetDb(ref);
  return ShakeSensitivityNotifier(db);
});

/// Notifier managing the configured action on shake.
class ShakeActionNotifier extends StateNotifier<ShakeAction> {
  final AppDatabase? _db;

  ShakeActionNotifier(this._db) : super(ShakeAction.skipNext) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    if (_db == null) return;
    try {
      final row = await (_db.select(_db.settings)
            ..where((t) => t.key.equals('shake_to_shuffle_action')))
          .getSingleOrNull();
      if (row != null) {
        state = ShakeAction.fromString(row.value);
      }
    } catch (_) {}
  }

  Future<void> setAction(ShakeAction action) async {
    if (state == action) return;
    state = action;
    if (_db != null) {
      try {
        await _db.into(_db.settings).insertOnConflictUpdate(
              SettingRow(
                key: 'shake_to_shuffle_action',
                value: action.name,
              ),
            );
      } catch (_) {}
    }
  }
}

/// Provider exposing the configured action triggered on shake.
final shakeActionProvider =
    StateNotifierProvider<ShakeActionNotifier, ShakeAction>((ref) {
  final db = _safeGetDb(ref);
  return ShakeActionNotifier(db);
});

// ============================================================================
// ShakeToShuffleHandler
// ============================================================================

/// Core handler orchestrating accelerometer event listening, shake mathematical
/// detection, debounce / cooldown timing, haptic feedback vibration, and playback dispatch.
class ShakeToShuffleHandler {
  final Ref _ref;
  bool isEnabled;
  ShakeSensitivity sensitivity;
  ShakeAction action;

  StreamSubscription? _subscription;
  final StreamController<ShakeTriggerEvent> _eventController =
      StreamController<ShakeTriggerEvent>.broadcast();

  DateTime? _lastTriggerTime;
  DateTime? _lastSpikeTime;
  int _spikeCount = 0;

  static const int _cooldownMs = 1200;
  static const int _minSpikeIntervalMs = 70;
  static const int _shakeWindowMs = 800;

  bool get isListening => _subscription != null;
  Stream<ShakeTriggerEvent> get onShake => _eventController.stream;

  ShakeToShuffleHandler({
    required Ref ref,
    this.isEnabled = false,
    this.sensitivity = ShakeSensitivity.medium,
    this.action = ShakeAction.skipNext,
    Stream<List<double>>? customAccelerometerStream,
  }) : _ref = ref {
    if (customAccelerometerStream != null) {
      _subscription = customAccelerometerStream.listen(
        (data) {
          if (data.length >= 3) {
            feedAccelerometerEvent(data[0], data[1], data[2]);
          }
        },
        onError: (_) {},
      );
    } else if (isEnabled) {
      startListening();
    }
  }

  /// Subscribes to available platform accelerometer channels safely.
  void startListening() {
    if (_subscription != null) return;

    const channels = [
      'dev.fluttercommunity.plus/sensors/accelerometer',
      'plugins.flutter.io/sensors/accelerometer',
      'dev.fluttercommunity.plus/sensors/user_accelerometer',
    ];

    for (final channelName in channels) {
      try {
        final channel = EventChannel(channelName);
        _subscription = channel.receiveBroadcastStream().listen(
          (dynamic event) {
            if (event is List && event.length >= 3) {
              final x = (event[0] as num).toDouble();
              final y = (event[1] as num).toDouble();
              final z = (event[2] as num).toDouble();
              feedAccelerometerEvent(x, y, z);
            }
          },
          onError: (_) {
            // Unsupported platform or missing channel: fail silently without crashes
          },
          cancelOnError: false,
        );
        break;
      } catch (_) {
        // Fallback to next channel candidate
      }
    }
  }

  /// Cancels platform accelerometer subscription.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _spikeCount = 0;
    _lastSpikeTime = null;
  }

  /// Ingests raw accelerometer acceleration vector values (m/s²).
  void feedAccelerometerEvent(double x, double y, double z) {
    if (!isEnabled) return;

    final now = DateTime.now();

    // 1. Cooldown guard
    if (_lastTriggerTime != null &&
        now.difference(_lastTriggerTime!).inMilliseconds < _cooldownMs) {
      return;
    }

    // 2. Magnitude & net acceleration
    final magnitude = math.sqrt(x * x + y * y + z * z);
    final netAcceleration = (magnitude - 9.80665).abs();

    // 3. Threshold check
    final threshold = sensitivity.threshold;
    final isSpike = magnitude >= threshold ||
        netAcceleration >= (threshold - 9.8).clamp(2.5, 40.0);

    if (isSpike) {
      final diff = _lastSpikeTime == null
          ? 999999
          : now.difference(_lastSpikeTime!).inMilliseconds;

      if (diff >= _minSpikeIntervalMs && diff <= _shakeWindowMs) {
        _spikeCount++;
      } else if (diff > _shakeWindowMs) {
        _spikeCount = 1;
      }

      _lastSpikeTime = now;

      if (_spikeCount >= sensitivity.requiredSpikes) {
        _spikeCount = 0;
        _lastTriggerTime = now;
        handleShake();
      }
    }
  }

  /// Triggers the shake action along with haptic vibration feedback.
  Future<void> handleShake({bool isSimulation = false}) async {
    // 1. Dual haptic pulse vibration
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 70));
      await HapticFeedback.selectionClick();
    } catch (_) {}

    // 2. Dispatch audio playback action
    try {
      final audioHandler = _tryGetAudioHandler();
      if (audioHandler != null) {
        switch (action) {
          case ShakeAction.skipNext:
            await audioHandler.skipToNext();
            break;
          case ShakeAction.shuffleQueue:
            if (audioHandler.isShuffleEnabled) {
              await audioHandler.setShuffleEnabled(false);
              await audioHandler.setShuffleEnabled(true);
            } else {
              await audioHandler.setShuffleEnabled(true);
            }
            break;
        }
      }
    } catch (e) {
      debugPrint('ShakeToShuffleHandler: Error executing action: $e');
    }

    // 3. Broadcast trigger event
    _eventController.add(ShakeTriggerEvent(
      action: action,
      sensitivity: sensitivity,
      isSimulation: isSimulation,
      timestamp: DateTime.now(),
    ));
  }

  /// Simulates a shake motion trigger (useful for testing and previews).
  Future<void> simulateShake() => handleShake(isSimulation: true);

  SoftifyAudioHandler? _tryGetAudioHandler() {
    try {
      return _ref.read(audioHandlerProvider);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    stopListening();
    _eventController.close();
  }
}

/// Provider that maintains and syncs the active `ShakeToShuffleHandler` instance.
final shakeToShuffleHandlerProvider = Provider<ShakeToShuffleHandler>((ref) {
  final isEnabled = ref.watch(shakeToShuffleEnabledProvider);
  final sensitivity = ref.watch(shakeSensitivityProvider);
  final action = ref.watch(shakeActionProvider);

  final handler = ShakeToShuffleHandler(
    ref: ref,
    isEnabled: isEnabled,
    sensitivity: sensitivity,
    action: action,
  );

  if (isEnabled) {
    handler.startListening();
  } else {
    handler.stopListening();
  }

  ref.onDispose(() {
    handler.dispose();
  });

  return handler;
});

// ============================================================================
// Setting Tile: ShakeToShuffleTile
// ============================================================================

/// An expressive Settings Tile for configuring Shake to Shuffle / Skip Track.
///
/// Provides toggles for enabling/disabling motion detection, choosing between
/// "Skip to Next Track" and "Shuffle Current Queue", selecting motion sensitivity
/// (Low, Medium, High), and includes a button to test haptics & actions immediately.
class ShakeToShuffleTile extends ConsumerWidget {
  const ShakeToShuffleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(shakeToShuffleEnabledProvider);
    final sensitivity = ref.watch(shakeSensitivityProvider);
    final action = ref.watch(shakeActionProvider);
    final tokens = context.tokens;

    return AppSurface(
      withBlur: false,
      color: tokens.card,
      borderRadius: BorderRadius.circular(tokens.radiusCard),
      padding: EdgeInsets.all(tokens.spaceMd),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon, Title, Status, and Switch
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? tokens.accent.withOpacity(0.18)
                      : tokens.surfaceHighlight,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: isEnabled
                        ? tokens.accent.withOpacity(0.4)
                        : tokens.divider.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.vibration_rounded,
                  color: isEnabled ? tokens.accent : tokens.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shake to Control',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isEnabled
                          ? '${action.shortLabel} • ${sensitivity.label} sensitivity'
                          : 'Shake device to control playback (Disabled)',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12.5,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                activeColor: tokens.accent,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  ref.read(shakeToShuffleEnabledProvider.notifier).setEnabled(val);
                },
              ),
            ],
          ),

          // Configurable Options Panel (visible when enabled)
          AnimatedCrossFade(
            crossFadeState: isEnabled
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 240),
            secondChild: const SizedBox.shrink(),
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    color: tokens.divider.withOpacity(0.2),
                    height: 1,
                  ),
                  const SizedBox(height: 14),

                  // 1. Action Picker
                  Text(
                    'SHAKE ACTION',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: tokens.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionChip(
                          title: ShakeAction.skipNext.shortLabel,
                          icon: ShakeAction.skipNext.icon,
                          isSelected: action == ShakeAction.skipNext,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(shakeActionProvider.notifier)
                                .setAction(ShakeAction.skipNext);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionChip(
                          title: ShakeAction.shuffleQueue.shortLabel,
                          icon: ShakeAction.shuffleQueue.icon,
                          isSelected: action == ShakeAction.shuffleQueue,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(shakeActionProvider.notifier)
                                .setAction(ShakeAction.shuffleQueue);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.description,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11.5,
                      color: tokens.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Sensitivity Picker
                  Text(
                    'SENSITIVITY',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: tokens.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: tokens.surfaceHighlight,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(
                        color: tokens.divider.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(3.0),
                    child: Row(
                      children: ShakeSensitivity.values.map((item) {
                        final isSel = item == sensitivity;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(shakeSensitivityProvider.notifier)
                                  .setSensitivity(item);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? tokens.accent : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(tokens.radiusSm - 2),
                              ),
                              child: Text(
                                item.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontUi,
                                  fontSize: 12.5,
                                  fontWeight:
                                      isSel ? FontWeight.bold : FontWeight.w500,
                                  color: isSel
                                      ? const Color(0xFF080F11)
                                      : tokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sensitivity.description,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11.5,
                      color: tokens.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Test Shake Button
                  BouncingScaleButton(
                    onTap: () {
                      final handler = ref.read(shakeToShuffleHandlerProvider);
                      handler.simulateShake();
                      AppToast.show(
                        context,
                        message: 'Shake triggered: ${action.title}!',
                        icon: Icon(action.icon, color: tokens.accent, size: 18),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated,
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        border: Border.all(
                          color: tokens.accent.withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            color: tokens.accent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Test Shake Trigger & Vibration',
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActionChip({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.accent.withOpacity(0.18)
              : tokens.surfaceHighlight,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: isSelected
                ? tokens.accent
                : tokens.divider.withOpacity(0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? tokens.accent : tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12.0,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? tokens.accent : tokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
