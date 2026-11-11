// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/player/softify_audio_handler.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';

// ============================================================================
// Enums & Models
// ============================================================================

/// Explains the root trigger cause of an automatic headphone disconnect pause.
enum HeadphoneDisconnectReason {
  /// The operating system sent a becoming-noisy broadcast (e.g. Android
  /// ACTION_AUDIO_BECOMING_NOISY or iOS oldDeviceUnavailable route change).
  becomingNoisy('Audio became noisy (headphones unplugged or Bluetooth lost)'),

  /// A headphone, headset, or Bluetooth output device was removed from the connected set.
  deviceDisconnected('Headphone or Bluetooth audio device removed'),

  /// Audio output route transitioned away from headphones/BT to built-in speaker.
  routeChangedToSpeaker('Audio output route switched to internal speaker'),

  /// Programmatically simulated or test-triggered disconnect event.
  simulated('Simulated disconnect event');

  final String description;
  const HeadphoneDisconnectReason(this.description);
}

// ============================================================================
// Database & Riverpod State Notifiers
// ============================================================================

AppDatabase? _safeGetDb(Ref ref) {
  try {
    return ref.read(databaseProvider);
  } catch (_) {
    return null;
  }
}

/// Notifier managing user preference for whether playback should automatically
/// pause when headphones or Bluetooth audio devices are disconnected.
///
/// Persists state in [AppDatabase] under the 'pause_on_headphone_disconnect' key.
/// Defaults to true for safety (preventing loud music blasting in public spaces).
class PauseOnDisconnectEnabledNotifier extends StateNotifier<bool> {
  final AppDatabase? _db;

  PauseOnDisconnectEnabledNotifier(this._db) : super(true) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    if (_db == null) return;
    try {
      final row = await (_db.select(_db.settings)
            ..where((t) => t.key.equals('pause_on_headphone_disconnect')))
          .getSingleOrNull();
      if (row != null) {
        state = row.value.toLowerCase() == 'true';
      }
    } catch (_) {
      // Non-fatal if database is uninitialized or in test harness
    }
  }

  /// Sets the auto-pause on disconnect preference and persists to database.
  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    if (_db != null) {
      try {
        await _db.into(_db.settings).insertOnConflictUpdate(
              SettingRow(
                key: 'pause_on_headphone_disconnect',
                value: enabled.toString(),
              ),
            );
      } catch (_) {}
    }
  }

  /// Toggles the current auto-pause on disconnect setting.
  Future<void> toggle() => setEnabled(!state);
}

/// Riverpod provider managing the state of auto-pause on headphone disconnect.
final pauseOnDisconnectEnabledProvider =
    StateNotifierProvider<PauseOnDisconnectEnabledNotifier, bool>((ref) {
  final db = _safeGetDb(ref);
  return PauseOnDisconnectEnabledNotifier(db);
});

// ============================================================================
// HeadphoneDisconnectPauseHandler
// ============================================================================

/// Listens to hardware audio device changes and audio route shifts.
///
/// When headphones or Bluetooth output devices disconnect while audio is playing,
/// automatically triggers [SoftifyAudioHandler.pause] if [pauseOnDisconnectEnabledProvider]
/// is enabled, preventing accidental blasting of sound on device loudspeakers.
class HeadphoneDisconnectPauseHandler {
  final Ref? _ref;
  final SoftifyAudioHandler? _customAudioHandler;
  final AudioSession? _customAudioSession;

  StreamSubscription<void>? _becomingNoisySubscription;
  StreamSubscription<Set<AudioDevice>>? _devicesSubscription;
  StreamSubscription<AudioDevicesChangedEvent>? _devicesChangedSubscription;

  Set<AudioDevice> _currentDevices = const {};
  DateTime? _lastPauseTriggerTime;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _initialScanComplete = false;

  /// Optional listener notified whenever an automatic pause is triggered.
  void Function(HeadphoneDisconnectReason reason)? onPauseTriggered;

  HeadphoneDisconnectPauseHandler({
    Ref? ref,
    SoftifyAudioHandler? customAudioHandler,
    AudioSession? customAudioSession,
    this.onPauseTriggered,
  })  : _ref = ref,
        _customAudioHandler = customAudioHandler,
        _customAudioSession = customAudioSession;

  /// Whether the handler has completed setup and is actively monitoring devices.
  bool get isInitialized => _isInitialized;

  /// Whether this handler has been disposed.
  bool get isDisposed => _isDisposed;

  /// Current cached snapshot of available audio devices.
  Set<AudioDevice> get currentDevices => Set.unmodifiable(_cachedDevices);
  Set<AudioDevice> get _cachedDevices => _currentDevices;

  /// Returns true if at least one headphone or Bluetooth output device is connected.
  bool get isHeadphoneOrBluetoothConnected =>
      hasHeadphonesOrBluetooth(_currentDevices);

  /// Initializes the audio session listeners.
  ///
  /// Safe to call on all platforms; silently falls back if platform audio session
  /// channel is unsupported (e.g. Linux desktop or headless unit test environments).
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      final session = _customAudioSession ?? await AudioSession.instance;

      // Ensure session is configured for music playback
      try {
        await session.configure(const AudioSessionConfiguration.music());
      } catch (_) {}

      // Cache initial connected audio devices
      try {
        final initialDevices = await session.getDevices();
        _currentDevices = Set.of(initialDevices);
      } catch (_) {
        _currentDevices = const {};
      }
      _initialScanComplete = true;

      // 1. Listen to OS-level becoming-noisy stream (fires immediately on unplug/disconnect)
      _becomingNoisySubscription = session.becomingNoisyEventStream.listen(
        (_) => _handleBecomingNoisy(),
        onError: (err) {
          debugPrint('[HeadphoneDisconnectPauseHandler] becomingNoisy error: $err');
        },
      );

      // 2. Listen to device set changes stream
      _devicesSubscription = session.devicesStream.listen(
        (devices) => _handleDevicesChanged(devices),
        onError: (err) {
          debugPrint('[HeadphoneDisconnectPauseHandler] devicesStream error: $err');
        },
      );

      // 3. Listen to granular device addition/removal events
      _devicesChangedSubscription = session.devicesChangedEventStream.listen(
        (event) => _handleDevicesChangedEvent(event),
        onError: (err) {
          debugPrint('[HeadphoneDisconnectPauseHandler] devicesChangedEvent error: $err');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('[HeadphoneDisconnectPauseHandler] Initialization failed: $e');
    }
  }

  /// Cancels all hardware subscriptions and cleans up references.
  void dispose() {
    _isDisposed = true;
    _becomingNoisySubscription?.cancel();
    _becomingNoisySubscription = null;
    _devicesSubscription?.cancel();
    _devicesSubscription = null;
    _devicesChangedSubscription?.cancel();
    _devicesChangedSubscription = null;
    _currentDevices = const {};
    _isInitialized = false;
  }

  // --------------------------------------------------------------------------
  // Event Handlers
  // --------------------------------------------------------------------------

  void _handleBecomingNoisy() {
    _triggerAutoPause(HeadphoneDisconnectReason.becomingNoisy);
  }

  void _handleDevicesChanged(Set<AudioDevice> newDevices) {
    final previousDevices = _currentDevices;
    _currentDevices = Set.of(newDevices);

    if (!_initialScanComplete) {
      _initialScanComplete = true;
      return;
    }

    final hadHeadphones = hasHeadphonesOrBluetooth(previousDevices);
    final hasHeadphonesNow = hasHeadphonesOrBluetooth(newDevices);

    // If we previously had headphones/BT and now we don't, trigger pause
    if (hadHeadphones && !hasHeadphonesNow) {
      _triggerAutoPause(HeadphoneDisconnectReason.deviceDisconnected);
    }
  }

  void _handleDevicesChangedEvent(AudioDevicesChangedEvent event) {
    if (event.devicesRemoved.isEmpty) return;

    final removedHeadphones = event.devicesRemoved.where(isHeadphoneOrBluetooth);
    if (removedHeadphones.isNotEmpty) {
      // Check if any headphones remain in current set after removal
      final remainingHeadphones =
          _currentDevices.difference(event.devicesRemoved).where(isHeadphoneOrBluetooth);

      if (remainingHeadphones.isEmpty) {
        _triggerAutoPause(HeadphoneDisconnectReason.deviceDisconnected);
      }
    }
  }

  // --------------------------------------------------------------------------
  // Auto-Pause Execution & Guard Logic
  // --------------------------------------------------------------------------

  SoftifyAudioHandler? _getAudioHandler() {
    if (_customAudioHandler != null) return _customAudioHandler;
    if (_ref != null) {
      try {
        return _ref.read(audioHandlerProvider);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _isAutoPauseEnabled() {
    if (_ref != null) {
      try {
        return _ref.read(pauseOnDisconnectEnabledProvider);
      } catch (_) {
        return true;
      }
    }
    return true;
  }

  /// Core pause execution. Protects against:
  /// - Feature being disabled by user
  /// - Audio not currently playing
  /// - Rapid double-triggers (e.g. both becomingNoisy and devicesStream firing)
  Future<void> _triggerAutoPause(HeadphoneDisconnectReason reason) async {
    if (_isDisposed) return;

    // Guard: user setting
    if (!_isAutoPauseEnabled()) {
      debugPrint('[HeadphoneDisconnectPauseHandler] Disconnect detected, but auto-pause is disabled.');
      return;
    }

    // Guard: cooldown debouncing (1500ms debounce window)
    final now = DateTime.now();
    if (_lastPauseTriggerTime != null &&
        now.difference(_lastPauseTriggerTime!) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastPauseTriggerTime = now;

    final handler = _getAudioHandler();
    if (handler == null) return;

    try {
      bool isPlaying = true;
      if (_ref != null) {
        try {
          isPlaying = _ref.read(isPlayingProvider);
        } catch (_) {
          isPlaying = true;
        }
      } else {
        try {
          isPlaying = (handler as dynamic).playbackState?.value?.playing ?? true;
        } catch (_) {
          isPlaying = true;
        }
      }

      if (isPlaying) {
        debugPrint(
          '[HeadphoneDisconnectPauseHandler] Disconnect triggered auto-pause: ${reason.description}',
        );
        await handler.pause();
        onPauseTriggered?.call(reason);
      }
    } catch (e) {
      debugPrint('[HeadphoneDisconnectPauseHandler] Error pausing audio: $e');
    }
  }

  /// Manually simulates a headphone disconnect event.
  ///
  /// Useful for automated testing, debugging, or user testing inside settings.
  Future<void> simulateDisconnect({
    HeadphoneDisconnectReason reason = HeadphoneDisconnectReason.simulated,
  }) async {
    await _triggerAutoPause(reason);
  }

  // --------------------------------------------------------------------------
  // Device Inspection Helpers
  // --------------------------------------------------------------------------

  /// Determines whether an [AudioDevice] represents headphones, a headset,
  /// or a personal Bluetooth audio endpoint.
  static bool isHeadphoneOrBluetooth(AudioDevice device) {
    if (!device.isOutput) return false;
    return isHeadphoneOrBluetoothType(device.type);
  }

  /// Determines whether an [AudioDeviceType] represents personal listening hardware.
  static bool isHeadphoneOrBluetoothType(AudioDeviceType type) {
    switch (type) {
      case AudioDeviceType.wiredHeadphones:
      case AudioDeviceType.wiredHeadset:
      case AudioDeviceType.bluetoothA2dp:
      case AudioDeviceType.bluetoothSco:
      case AudioDeviceType.bluetoothLe:
      case AudioDeviceType.usbAudio:
      case AudioDeviceType.hearingAid:
      case AudioDeviceType.airPlay:
        return true;
      case AudioDeviceType.builtInSpeaker:
      case AudioDeviceType.builtInSpeakerSafe:
      case AudioDeviceType.builtInEarpiece:
      case AudioDeviceType.builtInMic:
      case AudioDeviceType.headsetMic:
      case AudioDeviceType.lineAnalog:
      case AudioDeviceType.lineDigital:
      case AudioDeviceType.hdmi:
      case AudioDeviceType.hdmiArc:
      case AudioDeviceType.dock:
      case AudioDeviceType.fm:
      case AudioDeviceType.fmTuner:
      case AudioDeviceType.tvTuner:
      case AudioDeviceType.telephony:
      case AudioDeviceType.auxLine:
      case AudioDeviceType.ip:
      case AudioDeviceType.bus:
      case AudioDeviceType.avb:
      case AudioDeviceType.displayPort:
      case AudioDeviceType.carAudio:
      case AudioDeviceType.fireWire:
      case AudioDeviceType.unknown:
      default:
        return false;
    }
  }

  /// Checks if any device in the iterable is a headphone or Bluetooth device.
  static bool hasHeadphonesOrBluetooth(Iterable<AudioDevice> devices) {
    return devices.any(isHeadphoneOrBluetooth);
  }
}

// ============================================================================
// Riverpod Lifecycle Provider
// ============================================================================

/// Singleton Riverpod provider managing the [HeadphoneDisconnectPauseHandler] lifecycle.
final headphoneDisconnectPauseHandlerProvider =
    Provider<HeadphoneDisconnectPauseHandler>((ref) {
  final handler = HeadphoneDisconnectPauseHandler(ref: ref);
  unawaited(handler.initialize());
  ref.onDispose(handler.dispose);
  return handler;
});

/// Riverpod provider exposing whether headphones or Bluetooth devices are currently attached.
final isHeadphoneConnectedProvider = Provider<bool>((ref) {
  final handler = ref.watch(headphoneDisconnectPauseHandlerProvider);
  return handler.isHeadphoneOrBluetoothConnected;
});

// ============================================================================
// Settings Toggle Tile: PauseOnDisconnectTile
// ============================================================================

/// An expressive Settings Toggle Tile for configuring Auto-Pause on Headphone Disconnect.
///
/// Can be rendered as either a standard [SwitchListTile] inside an existing settings card
/// or as a standalone themed card container using the [.card] constructor.
class PauseOnDisconnectTile extends ConsumerWidget {
  /// Optional outer margins around the tile.
  final EdgeInsetsGeometry? margin;

  /// Optional padding inside the tile.
  final EdgeInsetsGeometry? padding;

  /// Primary label text. Defaults to 'Pause on Headphone Disconnect'.
  final String title;

  /// Secondary explanatory description.
  final String? subtitle;

  /// Custom icon override. If null, dynamically shows headphone or headset-off icon.
  final IconData? icon;

  /// Whether to display the leading icon.
  final bool showIcon;

  /// Accent color override for active switch and container glow.
  final Color? activeColor;

  /// If true, renders inside a standalone styled card container.
  final bool isCard;

  /// Optional callback invoked whenever the user flips the toggle.
  final ValueChanged<bool>? onChanged;

  const PauseOnDisconnectTile({
    super.key,
    this.margin,
    this.padding,
    this.title = 'Pause on Headphone Disconnect',
    this.subtitle,
    this.icon,
    this.showIcon = true,
    this.activeColor,
    this.isCard = false,
    this.onChanged,
  });

  /// Factory constructor for rendering as a standalone rounded card.
  const PauseOnDisconnectTile.card({
    super.key,
    this.margin,
    this.padding,
    this.title = 'Pause on Headphone Disconnect',
    this.subtitle,
    this.icon,
    this.showIcon = true,
    this.activeColor,
    this.onChanged,
  }) : isCard = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final isEnabled = ref.watch(pauseOnDisconnectEnabledProvider);
    final accent = activeColor ?? tokens.accent;
    final effectiveSubtitle = subtitle ??
        'Automatically pauses playback when headphones or Bluetooth devices disconnect.';

    final effectiveIcon = icon ??
        (isEnabled ? Icons.headphones_rounded : Icons.headset_off_rounded);

    if (isCard) {
      return Container(
        margin: margin ?? const EdgeInsets.symmetric(vertical: 6.0),
        padding: padding ?? EdgeInsets.all(tokens.spaceMd),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          border: Border.all(
            color: isEnabled
                ? accent.withValues(alpha: 0.28)
                : tokens.divider.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (showIcon) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? accent.withValues(alpha: 0.18)
                      : tokens.surfaceHighlight,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
                child: Icon(
                  effectiveIcon,
                  color: isEnabled ? accent : tokens.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    effectiveSubtitle,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 12.5,
                      color: tokens.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: isEnabled,
              activeColor: accent,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                ref
                    .read(pauseOnDisconnectEnabledProvider.notifier)
                    .setEnabled(val);
                onChanged?.call(val);
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: SwitchListTile(
        contentPadding: padding,
        activeColor: accent,
        secondary: showIcon
            ? Icon(
                effectiveIcon,
                color: isEnabled ? accent : tokens.textSecondary,
              )
            : null,
        title: Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        subtitle: Text(
          effectiveSubtitle,
          style: TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 12.5,
            color: tokens.textSecondary,
          ),
        ),
        value: isEnabled,
        onChanged: (val) {
          HapticFeedback.selectionClick();
          ref
              .read(pauseOnDisconnectEnabledProvider.notifier)
              .setEnabled(val);
          onChanged?.call(val);
        },
      ),
    );
  }
}
