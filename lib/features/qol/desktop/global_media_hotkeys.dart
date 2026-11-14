// ============================================================================
// Softify Quality of Life (QoL) - Feature 28: Configurable Global Media Hotkeys
// ============================================================================
//
// Provides application-wide and system-level configurable keyboard shortcuts
// for controlling playback and audio volume on Linux desktop environments.
//
// Key Capabilities:
// - Actions: PlayPause, Next, Prev, VolumeUp, VolumeDown, Mute.
// - Full modifier support: Ctrl, Alt, Shift, Meta (Super/Command).
// - Fallback recognition for dedicated hardware multimedia keyboard keys.
// - HotkeySettingsCard Material 3 widget with interactive key recording.
// - Conflict detection, live modifier preview, and one-click reset to defaults.
// - HardwareKeyboard global handler and scoped Focus key listeners.
// - Durable SharedPreferences persistence with in-memory caching.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// 1. Media Actions Enumeration
// ============================================================================

/// Supported media control actions configurable via global desktop hotkeys.
enum MediaAction {
  playPause(
    label: 'Play / Pause',
    description: 'Toggle playback between playing and paused',
    icon: Icons.play_arrow_rounded,
  ),
  next(
    label: 'Next Track',
    description: 'Skip forward to the next track in the queue',
    icon: Icons.skip_next_rounded,
  ),
  prev(
    label: 'Previous Track',
    description: 'Return to previous track or beginning of song',
    icon: Icons.skip_previous_rounded,
  ),
  volumeUp(
    label: 'Volume Up',
    description: 'Increase audio output volume by step',
    icon: Icons.volume_up_rounded,
  ),
  volumeDown(
    label: 'Volume Down',
    description: 'Decrease audio output volume by step',
    icon: Icons.volume_down_rounded,
  ),
  mute(
    label: 'Mute / Unmute',
    description: 'Toggle volume mute and restore previous level',
    icon: Icons.volume_off_rounded,
  );

  final String label;
  final String description;
  final IconData icon;

  const MediaAction({
    required this.label,
    required this.description,
    required this.icon,
  });

  /// Factory helper to resolve a [MediaAction] by string name.
  static MediaAction? fromName(String name) {
    for (final action in MediaAction.values) {
      if (action.name.toLowerCase() == name.trim().toLowerCase()) {
        return action;
      }
    }
    return null;
  }
}

// ============================================================================
// 2. Hotkey Model & Key Formatter
// ============================================================================

/// Clean human-readable formatter for Flutter [LogicalKeyboardKey] instances.
String formatLogicalKey(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.space) return 'Space';
  if (key == LogicalKeyboardKey.arrowUp) return 'Up';
  if (key == LogicalKeyboardKey.arrowDown) return 'Down';
  if (key == LogicalKeyboardKey.arrowLeft) return 'Left';
  if (key == LogicalKeyboardKey.arrowRight) return 'Right';
  if (key == LogicalKeyboardKey.enter) return 'Enter';
  if (key == LogicalKeyboardKey.escape) return 'Esc';
  if (key == LogicalKeyboardKey.backspace) return 'Backspace';
  if (key == LogicalKeyboardKey.tab) return 'Tab';
  if (key == LogicalKeyboardKey.delete) return 'Delete';
  if (key == LogicalKeyboardKey.home) return 'Home';
  if (key == LogicalKeyboardKey.end) return 'End';
  if (key == LogicalKeyboardKey.pageUp) return 'PageUp';
  if (key == LogicalKeyboardKey.pageDown) return 'PageDown';
  if (key == LogicalKeyboardKey.mediaPlayPause) return 'Media Play/Pause';
  if (key == LogicalKeyboardKey.mediaTrackNext) return 'Media Next';
  if (key == LogicalKeyboardKey.mediaTrackPrevious) return 'Media Prev';
  if (key == LogicalKeyboardKey.mediaStop) return 'Media Stop';
  if (key == LogicalKeyboardKey.audioVolumeUp) return 'Volume Up';
  if (key == LogicalKeyboardKey.audioVolumeDown) return 'Volume Down';
  if (key == LogicalKeyboardKey.audioVolumeMute) return 'Mute';

  final label = key.keyLabel;
  if (label.isNotEmpty && label.trim().isNotEmpty) {
    return label.toUpperCase();
  }
  return key.debugName ?? 'Key(${key.keyId})';
}

/// Helper to determine if a [LogicalKeyboardKey] is a modifier key.
bool isModifierKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.control ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.shift ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight ||
      key == LogicalKeyboardKey.alt ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight ||
      key == LogicalKeyboardKey.meta;
}

/// Represents an immutable keyboard shortcut combining modifier flags and a base key.
@immutable
class MediaHotkey {
  final LogicalKeyboardKey key;
  final bool isCtrl;
  final bool isShift;
  final bool isAlt;
  final bool isMeta;

  const MediaHotkey({
    required this.key,
    this.isCtrl = false,
    this.isShift = false,
    this.isAlt = false,
    this.isMeta = false,
  });

  /// Single key shortcut without any modifiers.
  const MediaHotkey.single(this.key)
      : isCtrl = false,
        isShift = false,
        isAlt = false,
        isMeta = false;

  /// Control modifier + key shortcut.
  const MediaHotkey.ctrl(this.key)
      : isCtrl = true,
        isShift = false,
        isAlt = false,
        isMeta = false;

  /// Returns individual key labels in conventional desktop display order.
  List<String> get keyLabels {
    final list = <String>[];
    if (isCtrl) list.add('Ctrl');
    if (isAlt) list.add('Alt');
    if (isShift) list.add('Shift');
    if (isMeta) list.add('Super');
    list.add(formatLogicalKey(key));
    return list;
  }

  /// Compact string display of shortcut (e.g. "Ctrl + Alt + Space").
  String get displayString => keyLabels.join(' + ');

  /// Checks if key and modifiers match explicitly passed values.
  bool matches({
    required LogicalKeyboardKey key,
    bool ctrl = false,
    bool shift = false,
    bool alt = false,
    bool meta = false,
  }) {
    return this.key.keyId == key.keyId &&
        isCtrl == ctrl &&
        isShift == shift &&
        isAlt == alt &&
        isMeta == meta;
  }

  /// Checks whether an incoming Flutter [KeyEvent] satisfies this hotkey.
  bool matchesEvent(KeyEvent event) {
    if (event.logicalKey.keyId != key.keyId) return false;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    return isCtrl == ctrl && isShift == shift && isAlt == alt && isMeta == meta;
  }

  /// Serializes hotkey to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'keyId': key.keyId,
        'keyLabel': formatLogicalKey(key),
        'isCtrl': isCtrl,
        'isShift': isShift,
        'isAlt': isAlt,
        'isMeta': isMeta,
      };

  /// Deserializes hotkey from a JSON map with graceful fallback.
  factory MediaHotkey.fromJson(Map<String, dynamic> json) {
    final keyId = json['keyId'] as int;
    final logicalKey = LogicalKeyboardKey.findKeyByKeyId(keyId) ??
        LogicalKeyboardKey(keyId);
    return MediaHotkey(
      key: logicalKey,
      isCtrl: json['isCtrl'] as bool? ?? false,
      isShift: json['isShift'] as bool? ?? false,
      isAlt: json['isAlt'] as bool? ?? false,
      isMeta: json['isMeta'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaHotkey &&
          runtimeType == other.runtimeType &&
          key.keyId == other.key.keyId &&
          isCtrl == other.isCtrl &&
          isShift == other.isShift &&
          isAlt == other.isAlt &&
          isMeta == other.isMeta;

  @override
  int get hashCode => Object.hash(key.keyId, isCtrl, isShift, isAlt, isMeta);

  @override
  String toString() => 'MediaHotkey($displayString)';
}

// ============================================================================
// 3. Hotkey Configuration Model
// ============================================================================

/// Complete configuration model storing media hotkey bindings and settings.
@immutable
class GlobalHotkeysConfig {
  final bool isEnabled;
  final Map<MediaAction, MediaHotkey?> bindings;
  final double volumeStep;

  const GlobalHotkeysConfig({
    this.isEnabled = true,
    required this.bindings,
    this.volumeStep = 0.05,
  });

  /// Factory providing canonical default shortcuts for Linux desktop.
  factory GlobalHotkeysConfig.defaults() {
    return const GlobalHotkeysConfig(
      isEnabled: true,
      volumeStep: 0.05,
      bindings: {
        MediaAction.playPause:
            MediaHotkey(key: LogicalKeyboardKey.space, isCtrl: true),
        MediaAction.next:
            MediaHotkey(key: LogicalKeyboardKey.arrowRight, isCtrl: true),
        MediaAction.prev:
            MediaHotkey(key: LogicalKeyboardKey.arrowLeft, isCtrl: true),
        MediaAction.volumeUp:
            MediaHotkey(key: LogicalKeyboardKey.arrowUp, isCtrl: true),
        MediaAction.volumeDown:
            MediaHotkey(key: LogicalKeyboardKey.arrowDown, isCtrl: true),
        MediaAction.mute:
            MediaHotkey(key: LogicalKeyboardKey.keyM, isCtrl: true),
      },
    );
  }

  /// Finds the bound [MediaAction] corresponding to key press and modifier state.
  /// Also recognises native hardware media keys automatically.
  MediaAction? findActionFor(
    LogicalKeyboardKey key, {
    bool ctrl = false,
    bool shift = false,
    bool alt = false,
    bool meta = false,
  }) {
    if (!isEnabled) return null;

    // 1. Check user configured bindings
    for (final entry in bindings.entries) {
      final hotkey = entry.value;
      if (hotkey != null &&
          hotkey.matches(
            key: key,
            ctrl: ctrl,
            shift: shift,
            alt: alt,
            meta: meta,
          )) {
        return entry.key;
      }
    }

    // 2. Hardware multimedia key automatic passthrough fallback (no modifiers)
    if (!ctrl && !shift && !alt && !meta) {
      if (key == LogicalKeyboardKey.mediaPlayPause ||
          key == LogicalKeyboardKey.mediaPlay ||
          key == LogicalKeyboardKey.mediaPause) {
        return MediaAction.playPause;
      }
      if (key == LogicalKeyboardKey.mediaTrackNext) {
        return MediaAction.next;
      }
      if (key == LogicalKeyboardKey.mediaTrackPrevious) {
        return MediaAction.prev;
      }
      if (key == LogicalKeyboardKey.audioVolumeUp) {
        return MediaAction.volumeUp;
      }
      if (key == LogicalKeyboardKey.audioVolumeDown) {
        return MediaAction.volumeDown;
      }
      if (key == LogicalKeyboardKey.audioVolumeMute) {
        return MediaAction.mute;
      }
    }

    return null;
  }

  /// Identifies whether another action is already bound to the specified hotkey.
  MediaAction? findConflict(MediaAction targetAction, MediaHotkey hotkey) {
    for (final entry in bindings.entries) {
      if (entry.key != targetAction && entry.value == hotkey) {
        return entry.key;
      }
    }
    return null;
  }

  /// Returns a copy with updated binding for a specific [action].
  GlobalHotkeysConfig updateBinding(MediaAction action, MediaHotkey? hotkey) {
    final next = Map<MediaAction, MediaHotkey?>.from(bindings);
    next[action] = hotkey;
    return copyWith(bindings: next);
  }

  /// Removes the binding for [action].
  GlobalHotkeysConfig removeBinding(MediaAction action) {
    return updateBinding(action, null);
  }

  /// Restores default bindings while preserving enabled state and volumeStep.
  GlobalHotkeysConfig resetToDefaults() {
    final defaults = GlobalHotkeysConfig.defaults();
    return copyWith(
      bindings: defaults.bindings,
      volumeStep: defaults.volumeStep,
    );
  }

  /// Copies instance with optional overrides.
  GlobalHotkeysConfig copyWith({
    bool? isEnabled,
    Map<MediaAction, MediaHotkey?>? bindings,
    double? volumeStep,
  }) {
    return GlobalHotkeysConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      bindings: bindings ?? this.bindings,
      volumeStep: volumeStep ?? this.volumeStep,
    );
  }

  /// Serializes config to JSON map.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'isEnabled': isEnabled,
      'volumeStep': volumeStep,
      'bindings': {},
    };
    final bindingsMap = <String, dynamic>{};
    for (final entry in bindings.entries) {
      if (entry.value != null) {
        bindingsMap[entry.key.name] = entry.value!.toJson();
      }
    }
    map['bindings'] = bindingsMap;
    return map;
  }

  /// Deserializes config from JSON map.
  factory GlobalHotkeysConfig.fromJson(Map<String, dynamic> json) {
    final isEnabled = json['isEnabled'] as bool? ?? true;
    final volumeStep = (json['volumeStep'] as num?)?.toDouble() ?? 0.05;
    final bindingsMap = json['bindings'] as Map<String, dynamic>? ?? {};

    final Map<MediaAction, MediaHotkey?> bindings = {};
    for (final action in MediaAction.values) {
      if (bindingsMap.containsKey(action.name)) {
        final hotkeyData = bindingsMap[action.name];
        if (hotkeyData is Map<String, dynamic>) {
          bindings[action] = MediaHotkey.fromJson(hotkeyData);
        } else {
          bindings[action] = null;
        }
      } else {
        // Fall back to default if absent in stored config
        bindings[action] = GlobalHotkeysConfig.defaults().bindings[action];
      }
    }

    return GlobalHotkeysConfig(
      isEnabled: isEnabled,
      bindings: bindings,
      volumeStep: volumeStep,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GlobalHotkeysConfig) return false;
    if (isEnabled != other.isEnabled || volumeStep != other.volumeStep) {
      return false;
    }
    if (bindings.length != other.bindings.length) return false;
    for (final entry in bindings.entries) {
      if (other.bindings[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(isEnabled, volumeStep, Object.hashAll(bindings.entries));

  @override
  String toString() =>
      'GlobalHotkeysConfig(isEnabled: $isEnabled, bindings: ${bindings.length})';
}

// ============================================================================
// 4. Persistence Layer (SharedPreferences Store)
// ============================================================================

/// SharedPreferences persistent storage key for Global Media Hotkeys.
const String kGlobalMediaHotkeysPrefKey = 'softify_global_media_hotkeys_config';

/// Contract for persistent storage compatible with SharedPreferences semantics.
abstract class HotkeyStorage {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
}

/// Disk-backed key-value store providing SharedPreferences persistence
/// without external native plugin compilation hazards.
class HotkeySharedPreferencesStore implements HotkeyStorage {
  static final HotkeySharedPreferencesStore _instance =
      HotkeySharedPreferencesStore._internal();
  factory HotkeySharedPreferencesStore() => _instance;
  HotkeySharedPreferencesStore._internal();

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;

  /// Loads persisted key-values from disk into memory.
  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File(p.join(dir.path, 'shared_preferences.json'));
      if (await _cacheFile!.exists()) {
        final content = await _cacheFile!.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _memoryCache = Map<String, dynamic>.from(decoded);
          }
        }
      }
    } catch (_) {
      // Fallback to in-memory store
    } finally {
      _isLoaded = true;
    }
  }

  @override
  Future<String?> getString(String key) async {
    await init();
    return _memoryCache[key] as String?;
  }

  @override
  Future<bool> setString(String key, String value) async {
    await init();
    _memoryCache[key] = value;
    try {
      if (_cacheFile != null) {
        await _cacheFile!.parent.create(recursive: true);
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache), flush: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clears in-memory cache (primarily for tests).
  void clearMemoryCache() {
    _memoryCache.clear();
    _isLoaded = false;
  }
}

// ============================================================================
// 5. Hotkey Action Dispatcher / Mapper
// ============================================================================

/// Routes triggered [MediaAction]s to the player or execution callback.
class MediaHotkeyMapper {
  final SoftifyAudioHandler? audioHandler;
  final FutureOr<void> Function(MediaAction action)? onAction;

  const MediaHotkeyMapper({
    this.audioHandler,
    this.onAction,
  });

  static double _lastNonZeroVolume = 0.7;

  /// Executes the given [MediaAction] against audio backend or custom delegate.
  Future<void> execute(
    MediaAction action, {
    double volumeStep = 0.05,
  }) async {
    if (onAction != null) {
      await onAction!(action);
      return;
    }

    if (audioHandler == null) return;

    try {
      switch (action) {
        case MediaAction.playPause:
          final isPlaying = audioHandler!.playbackState.value.playing;
          if (isPlaying) {
            await audioHandler!.pause();
          } else {
            await audioHandler!.play();
          }
          break;
        case MediaAction.next:
          await audioHandler!.skipToNext();
          break;
        case MediaAction.prev:
          await audioHandler!.skipToPrevious();
          break;
        case MediaAction.volumeUp:
          final current = audioHandler!.volume;
          final target = (current + volumeStep).clamp(0.0, 1.0);
          await audioHandler!.setVolume(target);
          break;
        case MediaAction.volumeDown:
          final current = audioHandler!.volume;
          final target = (current - volumeStep).clamp(0.0, 1.0);
          await audioHandler!.setVolume(target);
          break;
        case MediaAction.mute:
          final current = audioHandler!.volume;
          if (current > 0.0) {
            _lastNonZeroVolume = current;
            await audioHandler!.setVolume(0.0);
          } else {
            final restore = _lastNonZeroVolume > 0.0 ? _lastNonZeroVolume : 0.7;
            await audioHandler!.setVolume(restore);
          }
          break;
      }
    } catch (e) {
      debugPrint('[MediaHotkeyMapper] Error executing $action: $e');
    }
  }

  /// Processes an incoming [KeyEvent]. Returns `true` if consumed and handled.
  bool handleKeyEvent(
    KeyEvent event, {
    required GlobalHotkeysConfig config,
    double volumeStep = 0.05,
  }) {
    if (!config.isEnabled) return false;
    if (event is! KeyDownEvent) return false;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;

    final action = config.findActionFor(
      event.logicalKey,
      ctrl: isCtrl,
      shift: isShift,
      alt: isAlt,
      meta: isMeta,
    );

    if (action != null) {
      execute(action, volumeStep: volumeStep);
      return true;
    }
    return false;
  }
}

// ============================================================================
// 6. Riverpod State Management
// ============================================================================

/// Storage provider for hotkey configuration persistence.
final hotkeyStorageProvider = Provider<HotkeyStorage>((ref) {
  return HotkeySharedPreferencesStore();
});

/// StateNotifier that manages reactive hotkey state and SharedPreferences sync.
class GlobalHotkeysNotifier extends StateNotifier<GlobalHotkeysConfig> {
  final HotkeyStorage _storage;

  static HotkeyStorage? customStorage;

  GlobalHotkeysNotifier({HotkeyStorage? storage})
      : _storage = storage ?? customStorage ?? HotkeySharedPreferencesStore(),
        super(GlobalHotkeysConfig.defaults()) {
    _loadFromStorage();
  }

  /// Loads persisted hotkey configuration.
  Future<void> _loadFromStorage() async {
    try {
      final raw = await _storage.getString(kGlobalMediaHotkeysPrefKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          state = GlobalHotkeysConfig.fromJson(decoded);
        }
      }
    } catch (e) {
      debugPrint('[GlobalHotkeysNotifier] Load error: $e');
    }
  }

  /// Persists current configuration to storage.
  Future<void> _saveToStorage() async {
    try {
      final encoded = jsonEncode(state.toJson());
      await _storage.setString(kGlobalMediaHotkeysPrefKey, encoded);
    } catch (e) {
      debugPrint('[GlobalHotkeysNotifier] Save error: $e');
    }
  }

  /// Updates hotkey binding for an action.
  Future<void> setBinding(MediaAction action, MediaHotkey? hotkey) async {
    state = state.updateBinding(action, hotkey);
    await _saveToStorage();
  }

  /// Removes hotkey binding for an action.
  Future<void> removeBinding(MediaAction action) async {
    state = state.removeBinding(action);
    await _saveToStorage();
  }

  /// Resets bindings to defaults.
  Future<void> resetToDefaults() async {
    state = state.resetToDefaults();
    await _saveToStorage();
  }

  /// Toggles the global hotkey master switch.
  Future<void> toggleEnabled() async {
    state = state.copyWith(isEnabled: !state.isEnabled);
    await _saveToStorage();
  }

  /// Explicitly sets the global hotkey master switch.
  Future<void> setEnabled(bool enabled) async {
    if (state.isEnabled == enabled) return;
    state = state.copyWith(isEnabled: enabled);
    await _saveToStorage();
  }

  /// Updates volume increment step size.
  Future<void> setVolumeStep(double step) async {
    final clamped = step.clamp(0.01, 0.25);
    state = state.copyWith(volumeStep: clamped);
    await _saveToStorage();
  }

  /// Resets test harness state.
  static void resetForTesting() {
    customStorage = null;
    HotkeySharedPreferencesStore().clearMemoryCache();
  }
}

/// Main Riverpod provider exposing [GlobalHotkeysConfig] state.
final globalHotkeysConfigProvider =
    StateNotifierProvider<GlobalHotkeysNotifier, GlobalHotkeysConfig>((ref) {
  final storage = ref.watch(hotkeyStorageProvider);
  return GlobalHotkeysNotifier(storage: storage);
});

/// Tracks which [MediaAction] is actively recording a key combination, or null.
final activeRecordingActionProvider = StateProvider<MediaAction?>((ref) => null);

// ============================================================================
// 7. Visual UI Components (Keycap, KeycapComboWidget, HotkeySettingsCard)
// ============================================================================

/// Single visual keycap rendering with dark elevated surface and highlight border.
class VisualKeycap extends StatelessWidget {
  final String label;
  final bool isSmall;
  final bool isHighlighted;

  const VisualKeycap({
    super.key,
    required this.label,
    this.isSmall = false,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final highlightColor = tokens.accent;

    return Container(
      constraints: BoxConstraints(
        minWidth: isSmall ? 22 : 28,
        minHeight: isSmall ? 22 : 28,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 9,
        vertical: isSmall ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: isHighlighted
            ? highlightColor.withOpacity(0.18)
            : const Color(0xFF1E2026),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlighted
              ? highlightColor.withOpacity(0.7)
              : const Color(0x38FFFFFF),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            offset: Offset(0, 2),
            blurRadius: 1,
          ),
          BoxShadow(
            color: Color(0x14FFFFFF),
            offset: Offset(0, -1),
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontUi,
          fontSize: isSmall ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: isHighlighted ? highlightColor : const Color(0xFFF0F2F5),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Renders a series of keycaps separated by '+'.
class KeycapComboWidget extends StatelessWidget {
  final List<String> keyLabels;
  final bool isSmall;
  final bool isHighlighted;

  const KeycapComboWidget({
    super.key,
    required this.keyLabels,
    this.isSmall = false,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (keyLabels.isEmpty) {
      return Text(
        'Unassigned',
        style: TextStyle(
          fontFamily: AppTheme.fontUi,
          fontSize: isSmall ? 11 : 12,
          color: Colors.white38,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final children = <Widget>[];
    for (int i = 0; i < keyLabels.length; i++) {
      children.add(
        VisualKeycap(
          label: keyLabels[i],
          isSmall: isSmall,
          isHighlighted: isHighlighted,
        ),
      );
      if (i < keyLabels.length - 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '+',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: isSmall ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: Colors.white38,
              ),
            ),
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// Material 3 settings card for configuring global desktop media hotkeys.
/// Supports interactive recording, conflict detection, and reset to defaults.
class HotkeySettingsCard extends ConsumerStatefulWidget {
  final VoidCallback? onResetToDefaults;

  const HotkeySettingsCard({
    super.key,
    this.onResetToDefaults,
  });

  @override
  ConsumerState<HotkeySettingsCard> createState() => HotkeySettingsCardState();
}

class HotkeySettingsCardState extends ConsumerState<HotkeySettingsCard> {
  final FocusNode _recordingFocusNode = FocusNode(debugLabel: 'HotkeyRecorder');
  MediaAction? _recordingAction;
  String? _conflictNotice;

  @override
  void dispose() {
    _recordingFocusNode.dispose();
    super.dispose();
  }

  /// Initiates interactive shortcut recording for the given [action].
  void startRecording(MediaAction action) {
    setState(() {
      _recordingAction = action;
      _conflictNotice = null;
    });
    ref.read(activeRecordingActionProvider.notifier).state = action;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _recordingFocusNode.requestFocus();
      }
    });
  }

  /// Cancels active recording without modifying bindings.
  void cancelRecording() {
    setState(() {
      _recordingAction = null;
      _conflictNotice = null;
    });
    ref.read(activeRecordingActionProvider.notifier).state = null;
  }

  /// Applies recorded shortcut to [action], handling conflicts gracefully.
  void applyRecordedHotkey(MediaAction action, MediaHotkey hotkey) {
    final config = ref.read(globalHotkeysConfigProvider);
    final conflict = config.findConflict(action, hotkey);

    if (conflict != null) {
      // Clear conflicting action
      ref.read(globalHotkeysConfigProvider.notifier).removeBinding(conflict);
      setState(() {
        _conflictNotice =
            'Reassigned "${hotkey.displayString}" from ${conflict.label} to ${action.label}';
      });
    } else {
      setState(() {
        _conflictNotice = null;
      });
    }

    ref.read(globalHotkeysConfigProvider.notifier).setBinding(action, hotkey);
    cancelRecording();
  }

  /// Handles incoming key events during recording.
  KeyEventResult _handleRecorderKeyEvent(FocusNode node, KeyEvent event) {
    if (_recordingAction == null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Escape cancels recording
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      cancelRecording();
      return KeyEventResult.handled;
    }

    // Ignore solitary modifier presses while user is building combination
    if (isModifierKey(event.logicalKey)) {
      setState(() {});
      return KeyEventResult.handled;
    }

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;

    final newHotkey = MediaHotkey(
      key: event.logicalKey,
      isCtrl: isCtrl,
      isShift: isShift,
      isAlt: isAlt,
      isMeta: isMeta,
    );

    applyRecordedHotkey(_recordingAction!, newHotkey);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final config = ref.watch(globalHotkeysConfigProvider);
    final notifier = ref.read(globalHotkeysConfigProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.divider, width: 1.0),
      ),
      padding: EdgeInsets.all(tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title, Subtitle, Master Switch
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.keyboard_outlined,
                  color: tokens.accent,
                  size: 22,
                ),
              ),
              SizedBox(width: tokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global Media Hotkeys',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Control playback and volume globally via configurable keyboard shortcuts.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const Key('hotkeys_master_switch'),
                value: config.isEnabled,
                activeColor: tokens.accent,
                onChanged: (val) => notifier.setEnabled(val),
              ),
            ],
          ),

          if (_conflictNotice != null) ...[
            SizedBox(height: tokens.spaceSm),
            Container(
              key: const Key('hotkeys_conflict_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _conflictNotice!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.amber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: tokens.spaceMd),
          Divider(color: tokens.divider, height: 1),
          SizedBox(height: tokens.spaceSm),

          // Action Rows
          ...MediaAction.values.map((action) {
            final hotkey = config.bindings[action];
            final isRecording = _recordingAction == action;

            return Padding(
              key: Key('hotkey_row_${action.name}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isRecording
                      ? tokens.accent.withOpacity(0.08)
                      : tokens.surfaceElevated.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: isRecording
                        ? tokens.accent
                        : Colors.transparent,
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: isRecording
                    ? _buildRecordingRow(context, action)
                    : _buildStandardRow(context, action, hotkey, config.isEnabled),
              ),
            );
          }),

          SizedBox(height: tokens.spaceMd),
          Divider(color: tokens.divider, height: 1),
          SizedBox(height: tokens.spaceSm),

          // Footer Controls: Reset to Defaults & Step Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Volume Step: ${(config.volumeStep * 100).toInt()}%',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11,
                  color: tokens.textMuted,
                ),
              ),
              OutlinedButton.icon(
                key: const Key('hotkey_reset_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.textSecondary,
                  side: BorderSide(color: tokens.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Reset to Defaults',
                    style: TextStyle(fontSize: 12)),
                onPressed: () {
                  notifier.resetToDefaults();
                  widget.onResetToDefaults?.call();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the standard view for an action row.
  Widget _buildStandardRow(
    BuildContext context,
    MediaAction action,
    MediaHotkey? hotkey,
    bool isEnabled,
  ) {
    final tokens = context.tokens;
    final notifier = ref.read(globalHotkeysConfigProvider.notifier);

    return Row(
      children: [
        Icon(action.icon, size: 18, color: tokens.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action.label,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isEnabled ? tokens.textPrimary : tokens.textMuted,
                ),
              ),
              Text(
                action.description,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11,
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (hotkey != null)
          KeycapComboWidget(keyLabels: hotkey.keyLabels)
        else
          Text(
            'Unassigned',
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 11,
              color: tokens.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        const SizedBox(width: 8),
        // Record / Edit Button
        IconButton(
          key: Key('hotkey_record_${action.name}'),
          tooltip: 'Record Shortcut',
          icon: Icon(
            Icons.fiber_manual_record_rounded,
            size: 16,
            color: tokens.accent,
          ),
          onPressed: isEnabled ? () => startRecording(action) : null,
          visualDensity: VisualDensity.compact,
        ),
        // Clear Button
        IconButton(
          key: Key('hotkey_clear_${action.name}'),
          tooltip: 'Clear Shortcut',
          icon: Icon(
            Icons.close_rounded,
            size: 16,
            color: tokens.textMuted,
          ),
          onPressed: isEnabled && hotkey != null
              ? () => notifier.removeBinding(action)
              : null,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  /// Builds the active recording state for an action row.
  Widget _buildRecordingRow(BuildContext context, MediaAction action) {
    final tokens = context.tokens;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;

    final activeModifiers = <String>[];
    if (isCtrl) activeModifiers.add('Ctrl');
    if (isAlt) activeModifiers.add('Alt');
    if (isShift) activeModifiers.add('Shift');
    if (isMeta) activeModifiers.add('Super');

    return Focus(
      focusNode: _recordingFocusNode,
      autofocus: true,
      onKeyEvent: _handleRecorderKeyEvent,
      child: Row(
        key: const Key('hotkey_recording_box'),
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: tokens.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recording for ${action.label}...',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.accent,
                  ),
                ),
                Text(
                  activeModifiers.isNotEmpty
                      ? '${activeModifiers.join(" + ")} + ... (Press key or Esc)'
                      : 'Press desired keys (Esc to cancel)',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (activeModifiers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: KeycapComboWidget(
                keyLabels: [...activeModifiers, '...'],
                isHighlighted: true,
              ),
            ),
          TextButton(
            key: const Key('hotkey_cancel_recording'),
            onPressed: cancelRecording,
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 8. Global Media Hotkey Desktop Listener Widget
// ============================================================================

/// Wraps application or window content to globally intercept media hotkeys
/// on desktop platforms, seamlessly invoking the player backend.
class GlobalMediaHotkeyListener extends ConsumerStatefulWidget {
  final Widget child;
  final bool enabled;
  final FutureOr<void> Function(MediaAction action)? onAction;

  const GlobalMediaHotkeyListener({
    super.key,
    required this.child,
    this.enabled = true,
    this.onAction,
  });

  @override
  ConsumerState<GlobalMediaHotkeyListener> createState() =>
      _GlobalMediaHotkeyListenerState();
}

class _GlobalMediaHotkeyListenerState
    extends ConsumerState<GlobalMediaHotkeyListener> {
  late final MediaHotkeyMapper _mapper;

  @override
  void initState() {
    super.initState();
    _initMapper();
    HardwareKeyboard.instance.addHandler(_onGlobalHardwareKeyEvent);
  }

  void _initMapper() {
    SoftifyAudioHandler? handler;
    try {
      handler = ref.read(audioHandlerProvider);
    } catch (_) {
      // AudioHandler not injected or running in lightweight test
    }
    _mapper = MediaHotkeyMapper(
      audioHandler: handler,
      onAction: widget.onAction,
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalHardwareKeyEvent);
    super.dispose();
  }

  bool _onGlobalHardwareKeyEvent(KeyEvent event) {
    if (!widget.enabled) return false;
    final config = ref.read(globalHotkeysConfigProvider);
    return _mapper.handleKeyEvent(
      event,
      config: config,
      volumeStep: config.volumeStep,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (!widget.enabled) return KeyEventResult.ignored;
        final config = ref.read(globalHotkeysConfigProvider);
        final handled = _mapper.handleKeyEvent(
          event,
          config: config,
          volumeStep: config.volumeStep,
        );
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}
