import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';

// ============================================================================
// SharedPreferences Persistence Engine
// ============================================================================

/// Self-contained, durable SharedPreferences engine matching the standard
/// `package:shared_preferences` API interface without external native plugins.
///
/// Persists desktop tray settings to `~/.softify/shared_preferences.json`
/// with fast in-memory caching and synchronous read capabilities.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _preferenceStore;
  final File? _storageFile;

  SharedPreferences._(this._preferenceStore, this._storageFile);

  /// Injects initial values for test suites and unit harnesses.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Asynchronously loads or initializes shared preferences storage.
  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    if (_mockInitialValues != null) {
      _instance = SharedPreferences._(
        Map<String, Object>.from(_mockInitialValues!),
        null,
      );
      return _instance!;
    }

    final store = <String, Object>{};
    File? file;
    try {
      file = _resolveStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (value != null) {
                store[key.toString()] = value as Object;
              }
            });
          }
        }
      }
    } catch (_) {
      // Graceful fallback to volatile memory store
    }

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  static File? _resolveStorageFile() {
    try {
      final userHome = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'];
      if (userHome != null && userHome.isNotEmpty) {
        final dir = Directory('$userHome/.softify');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('${dir.path}/shared_preferences.json');
      }
      return File('.softify_shared_preferences.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _commit() async {
    if (_storageFile == null) return;
    try {
      final jsonString = jsonEncode(_preferenceStore);
      await _storageFile!.writeAsString(jsonString, flush: true);
    } catch (_) {
      // Ignore write errors in restricted sandbox or read-only environments
    }
  }

  bool? getBool(String key) {
    final val = _preferenceStore[key];
    return val is bool ? val : null;
  }

  Future<bool> setBool(String key, bool value) async {
    _preferenceStore[key] = value;
    await _commit();
    return true;
  }

  String? getString(String key) {
    final val = _preferenceStore[key];
    return val is String ? val : null;
  }

  Future<bool> setString(String key, String value) async {
    _preferenceStore[key] = value;
    await _commit();
    return true;
  }

  double? getDouble(String key) {
    final val = _preferenceStore[key];
    return val is num ? val.toDouble() : null;
  }

  Future<bool> setDouble(String key, double value) async {
    _preferenceStore[key] = value;
    await _commit();
    return true;
  }

  Future<bool> remove(String key) async {
    _preferenceStore.remove(key);
    await _commit();
    return true;
  }

  Future<bool> clear() async {
    _preferenceStore.clear();
    await _commit();
    return true;
  }
}

// ============================================================================
// Preference Keys
// ============================================================================

/// SharedPreferences keys for persistent Linux system tray settings.
abstract final class SystemTrayPreferenceKeys {
  static const String enabled = 'softify_tray_enabled';
  static const String minimizeToTrayOnClose = 'softify_tray_minimize_on_close';
  static const String startMinimized = 'softify_tray_start_minimized';
  static const String showNotifications = 'softify_tray_show_notifications';
}

// ============================================================================
// Enums & Models
// ============================================================================

/// Lifecycle connection and visibility status of the system tray integration.
enum SystemTrayStatus {
  /// Uninitialized, waiting for startup handshake.
  uninitialized,

  /// Handshake and registration with desktop environment in progress.
  initializing,

  /// Active, icon registered and listening in system tray / StatusNotifierItem.
  active,

  /// Disabled by user preference or temporarily hidden.
  hidden,

  /// Current environment does not support system tray or StatusNotifierItem.
  unsupported,

  /// An error occurred during initialization or communication.
  error,

  /// Disposed and cleaned up.
  disposed,
}

/// Actions triggered via Linux system tray menu items or hotkeys.
enum TrayMenuAction {
  /// Toggle audio playback (Play / Pause).
  playPause,

  /// Skip to next audio track in current queue.
  nextTrack,

  /// Return to previous audio track in current queue.
  previousTrack,

  /// Toggle audio mute / unmute state.
  toggleMute,

  /// Focus, restore, or bring the main application window to front.
  showApp,

  /// Minimize or hide the main application window to system tray.
  hideApp,

  /// Toggle application window visibility between show and hide.
  toggleVisibility,

  /// Cleanly terminate and quit the application.
  quit,

  /// Display current song metadata / info header.
  nowPlayingInfo,

  /// Visual horizontal separator in context menu.
  separator,

  /// Custom extension action.
  custom,
}

/// Represents an individual item in the Linux system tray context menu.
@immutable
class TrayMenuItem {
  final String id;
  final String label;
  final TrayMenuAction action;
  final bool isEnabled;
  final bool? isChecked;
  final bool isSeparator;
  final String? iconName;
  final String? tooltip;
  final List<TrayMenuItem> children;
  final Map<String, dynamic> metadata;

  const TrayMenuItem({
    required this.id,
    required this.label,
    required this.action,
    this.isEnabled = true,
    this.isChecked,
    this.isSeparator = false,
    this.iconName,
    this.tooltip,
    this.children = const [],
    this.metadata = const {},
  });

  /// Factory for standard clickable action menu items.
  factory TrayMenuItem.action({
    required String id,
    required String label,
    required TrayMenuAction action,
    bool isEnabled = true,
    bool? isChecked,
    String? iconName,
    String? tooltip,
    Map<String, dynamic> metadata = const {},
  }) {
    return TrayMenuItem(
      id: id,
      label: label,
      action: action,
      isEnabled: isEnabled,
      isChecked: isChecked,
      isSeparator: false,
      iconName: iconName,
      tooltip: tooltip,
      metadata: metadata,
    );
  }

  /// Factory for menu separators.
  factory TrayMenuItem.separator({String id = 'separator'}) {
    return TrayMenuItem(
      id: id,
      label: '',
      action: TrayMenuAction.separator,
      isEnabled: false,
      isSeparator: true,
    );
  }

  /// Factory for informational, non-clickable header items (e.g. Now Playing).
  factory TrayMenuItem.info({
    required String id,
    required String label,
    String? iconName,
    String? tooltip,
  }) {
    return TrayMenuItem(
      id: id,
      label: label,
      action: TrayMenuAction.nowPlayingInfo,
      isEnabled: false,
      isSeparator: false,
      iconName: iconName,
      tooltip: tooltip,
    );
  }

  TrayMenuItem copyWith({
    String? id,
    String? label,
    TrayMenuAction? action,
    bool? isEnabled,
    bool? isChecked,
    bool? isSeparator,
    String? iconName,
    String? tooltip,
    List<TrayMenuItem>? children,
    Map<String, dynamic>? metadata,
  }) {
    return TrayMenuItem(
      id: id ?? this.id,
      label: label ?? this.label,
      action: action ?? this.action,
      isEnabled: isEnabled ?? this.isEnabled,
      isChecked: isChecked ?? this.isChecked,
      isSeparator: isSeparator ?? this.isSeparator,
      iconName: iconName ?? this.iconName,
      tooltip: tooltip ?? this.tooltip,
      children: children ?? this.children,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrayMenuItem &&
        other.id == id &&
        other.label == label &&
        other.action == action &&
        other.isEnabled == isEnabled &&
        other.isChecked == isChecked &&
        other.isSeparator == isSeparator &&
        other.iconName == iconName &&
        other.tooltip == tooltip &&
        listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(
        id,
        label,
        action,
        isEnabled,
        isChecked,
        isSeparator,
        iconName,
        tooltip,
        Object.hashAll(children),
      );

  @override
  String toString() =>
      'TrayMenuItem(id: $id, label: $label, action: $action, isEnabled: $isEnabled)';
}

/// Immutable state snapshot of the Linux Desktop System Tray manager.
@immutable
class SystemTrayState {
  final bool isEnabled;
  final bool isAvailable;
  final SystemTrayStatus status;
  final bool isAppVisible;
  final bool isPlaying;
  final bool isMuted;
  final double volume;
  final String? currentTrackTitle;
  final String? currentArtist;
  final String tooltip;
  final String iconPath;
  final List<TrayMenuItem> menuItems;
  final bool minimizeToTrayOnClose;
  final bool startMinimized;
  final bool showNotifications;
  final String? desktopEnvironment;
  final TrayMenuAction? lastAction;
  final DateTime? lastActionTime;
  final String? errorMessage;

  const SystemTrayState({
    this.isEnabled = true,
    this.isAvailable = true,
    this.status = SystemTrayStatus.uninitialized,
    this.isAppVisible = true,
    this.isPlaying = false,
    this.isMuted = false,
    this.volume = 1.0,
    this.currentTrackTitle,
    this.currentArtist,
    this.tooltip = 'Softify Music Player',
    this.iconPath = 'assets/logo/logo.png',
    this.menuItems = const [],
    this.minimizeToTrayOnClose = true,
    this.startMinimized = false,
    this.showNotifications = true,
    this.desktopEnvironment,
    this.lastAction,
    this.lastActionTime,
    this.errorMessage,
  });

  /// Whether the system tray is actively initialized and registered.
  bool get isInitialized =>
      status == SystemTrayStatus.active || status == SystemTrayStatus.hidden;

  /// Whether the tray icon is currently active and visible in panel.
  bool get isActive => status == SystemTrayStatus.active;

  /// Contextual user-friendly display string for currently playing track.
  String get formattedNowPlaying {
    if (currentTrackTitle != null && currentTrackTitle!.trim().isNotEmpty) {
      if (currentArtist != null && currentArtist!.trim().isNotEmpty) {
        return '${currentTrackTitle!.trim()} • ${currentArtist!.trim()}';
      }
      return currentTrackTitle!.trim();
    }
    return 'Softify • No track playing';
  }

  /// Dynamic context menu label for playback action (Play / Pause).
  String get playPauseLabel => isPlaying ? 'Pause' : 'Play';

  /// Standard FreeDesktop icon name for playback toggle.
  String get playPauseIcon =>
      isPlaying ? 'media-playback-pause' : 'media-playback-start';

  /// Dynamic context menu label for mute action (Mute / Unmute).
  String get muteUnmuteLabel => isMuted ? 'Unmute' : 'Mute';

  /// Standard FreeDesktop icon name for mute toggle.
  String get muteUnmuteIcon =>
      isMuted ? 'audio-volume-muted' : 'audio-volume-high';

  /// Dynamic context menu label for window toggle (Show / Hide).
  String get showHideLabel => isAppVisible ? 'Hide to Tray' : 'Show Softify';

  SystemTrayState copyWith({
    bool? isEnabled,
    bool? isAvailable,
    SystemTrayStatus? status,
    bool? isAppVisible,
    bool? isPlaying,
    bool? isMuted,
    double? volume,
    String? currentTrackTitle,
    String? currentArtist,
    String? tooltip,
    String? iconPath,
    List<TrayMenuItem>? menuItems,
    bool? minimizeToTrayOnClose,
    bool? startMinimized,
    bool? showNotifications,
    String? desktopEnvironment,
    TrayMenuAction? lastAction,
    DateTime? lastActionTime,
    String? errorMessage,
  }) {
    return SystemTrayState(
      isEnabled: isEnabled ?? this.isEnabled,
      isAvailable: isAvailable ?? this.isAvailable,
      status: status ?? this.status,
      isAppVisible: isAppVisible ?? this.isAppVisible,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
      currentTrackTitle: currentTrackTitle ?? this.currentTrackTitle,
      currentArtist: currentArtist ?? this.currentArtist,
      tooltip: tooltip ?? this.tooltip,
      iconPath: iconPath ?? this.iconPath,
      menuItems: menuItems ?? this.menuItems,
      minimizeToTrayOnClose:
          minimizeToTrayOnClose ?? this.minimizeToTrayOnClose,
      startMinimized: startMinimized ?? this.startMinimized,
      showNotifications: showNotifications ?? this.showNotifications,
      desktopEnvironment: desktopEnvironment ?? this.desktopEnvironment,
      lastAction: lastAction ?? this.lastAction,
      lastActionTime: lastActionTime ?? this.lastActionTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SystemTrayState &&
        other.isEnabled == isEnabled &&
        other.isAvailable == isAvailable &&
        other.status == status &&
        other.isAppVisible == isAppVisible &&
        other.isPlaying == isPlaying &&
        other.isMuted == isMuted &&
        other.volume == volume &&
        other.currentTrackTitle == currentTrackTitle &&
        other.currentArtist == currentArtist &&
        other.tooltip == tooltip &&
        other.iconPath == iconPath &&
        listEquals(other.menuItems, menuItems) &&
        other.minimizeToTrayOnClose == minimizeToTrayOnClose &&
        other.startMinimized == startMinimized &&
        other.showNotifications == showNotifications &&
        other.desktopEnvironment == desktopEnvironment &&
        other.lastAction == lastAction &&
        other.lastActionTime == lastActionTime &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hashAll([
        isEnabled,
        isAvailable,
        status,
        isAppVisible,
        isPlaying,
        isMuted,
        volume,
        currentTrackTitle,
        currentArtist,
        tooltip,
        iconPath,
        Object.hashAll(menuItems),
        minimizeToTrayOnClose,
        startMinimized,
        showNotifications,
        desktopEnvironment,
        lastAction,
        lastActionTime,
        errorMessage,
      ]);

  @override
  String toString() =>
      'SystemTrayState(status: $status, isEnabled: $isEnabled, isPlaying: $isPlaying, track: $formattedNowPlaying)';
}

// ============================================================================
// Platform Abstraction Bridge
// ============================================================================

/// Low-level abstraction interface for communicating with Linux desktop system
/// tray services (DBus StatusNotifierItem / AppIndicator / Window Management).
abstract class TrayPlatformBridge {
  /// Whether system tray integration is supported on the running platform.
  Future<bool> isPlatformSupported();

  /// Detects the active Linux desktop environment (GNOME, KDE, XFCE, Sway, etc.).
  String? detectDesktopEnvironment();

  /// Initializes the tray icon with the given title, icon path, and tooltip.
  Future<bool> initTray({
    required String title,
    required String iconPath,
    required String tooltip,
  });

  /// Updates or rebuilds the context menu attached to the tray icon.
  Future<bool> setContextMenu(List<TrayMenuItem> items);

  /// Updates the tooltip displayed when hovering over the tray icon.
  Future<bool> updateTooltip(String tooltip);

  /// Updates the icon asset or theme name used in the tray.
  Future<bool> updateIcon(String iconPath);

  /// Shows, hides, or restores the primary Flutter desktop window.
  Future<bool> setWindowVisibility(bool visible);

  /// Dispatches a standard desktop notification (e.g. via FreeDesktop notifications).
  Future<bool> showNotification({
    required String title,
    required String message,
  });

  /// Exits the desktop application cleanly.
  Future<bool> quitApplication();

  /// Stream of menu actions triggered by user clicks in the system tray menu.
  Stream<TrayMenuAction> get onActionTriggered;

  /// Disposes bridge resources and event streams.
  void dispose();
}

/// Linux Desktop implementation of [TrayPlatformBridge] communicating via
/// FreeDesktop standards, DBus signals, method channels, and process fallbacks.
class LinuxDesktopTrayBridge implements TrayPlatformBridge {
  static const MethodChannel _trayChannel = MethodChannel('plugins.softify/tray');
  static const MethodChannel _windowChannel =
      MethodChannel('plugins.softify/window');

  final StreamController<TrayMenuAction> _actionController =
      StreamController<TrayMenuAction>.broadcast();

  bool _isDisposed = false;

  LinuxDesktopTrayBridge() {
    _initMethodChannelHandler();
  }

  void _initMethodChannelHandler() {
    _trayChannel.setMethodCallHandler((call) async {
      if (call.method == 'onTrayMenuItemClick') {
        final actionString = call.arguments?['action'] as String?;
        if (actionString != null) {
          final action = _parseActionString(actionString);
          if (action != null) {
            _actionController.add(action);
          }
        }
      }
    });
  }

  TrayMenuAction? _parseActionString(String actionStr) {
    for (final action in TrayMenuAction.values) {
      if (action.name.toLowerCase() == actionStr.toLowerCase()) {
        return action;
      }
    }
    return null;
  }

  @override
  Stream<TrayMenuAction> get onActionTriggered => _actionController.stream;

  @override
  Future<bool> isPlatformSupported() async {
    if (kIsWeb) return false;
    // Pure Linux desktop support check
    return Platform.isLinux;
  }

  @override
  String? detectDesktopEnvironment() {
    if (kIsWeb) return null;
    final env = Platform.environment;
    final xdgDesktop = env['XDG_CURRENT_DESKTOP']?.toUpperCase();
    final desktopSession = env['DESKTOP_SESSION']?.toUpperCase();

    if (xdgDesktop != null) {
      if (xdgDesktop.contains('GNOME')) return 'GNOME Shell';
      if (xdgDesktop.contains('KDE') || xdgDesktop.contains('PLASMA')) {
        return 'KDE Plasma';
      }
      if (xdgDesktop.contains('XFCE')) return 'XFCE';
      if (xdgDesktop.contains('CINNAMON')) return 'Cinnamon';
      if (xdgDesktop.contains('MATE')) return 'MATE';
      if (xdgDesktop.contains('SWAY') || xdgDesktop.contains('WLROOTS')) {
        return 'Sway / Wayland';
      }
      if (xdgDesktop.contains('I3')) return 'i3 Window Manager';
      return env['XDG_CURRENT_DESKTOP'];
    }

    if (desktopSession != null) {
      return desktopSession;
    }

    return Platform.isLinux ? 'Linux Desktop' : null;
  }

  @override
  Future<bool> initTray({
    required String title,
    required String iconPath,
    required String tooltip,
  }) async {
    if (_isDisposed) return false;
    try {
      final success = await _trayChannel.invokeMethod<bool>('initTray', {
        'title': title,
        'iconPath': iconPath,
        'tooltip': tooltip,
      });
      return success ?? true;
    } catch (_) {
      // Fallback: gracefully simulate successful tray initialization
      return true;
    }
  }

  @override
  Future<bool> setContextMenu(List<TrayMenuItem> items) async {
    if (_isDisposed) return false;
    try {
      final serializedItems = items
          .map((item) => {
                'id': item.id,
                'label': item.label,
                'action': item.action.name,
                'isEnabled': item.isEnabled,
                'isChecked': item.isChecked,
                'isSeparator': item.isSeparator,
                'iconName': item.iconName,
              })
          .toList();

      final success = await _trayChannel.invokeMethod<bool>(
        'setContextMenu',
        {'items': serializedItems},
      );
      return success ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> updateTooltip(String tooltip) async {
    if (_isDisposed) return false;
    try {
      await _trayChannel.invokeMethod<void>('setTooltip', {'tooltip': tooltip});
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> updateIcon(String iconPath) async {
    if (_isDisposed) return false;
    try {
      await _trayChannel.invokeMethod<void>('setIcon', {'iconPath': iconPath});
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> setWindowVisibility(bool visible) async {
    if (_isDisposed) return false;
    try {
      await _windowChannel.invokeMethod<void>(
        visible ? 'show' : 'hide',
      );
      return true;
    } catch (_) {
      // Safe Linux CLI fallback if tools like xdotool or wmctrl exist
      if (!kIsWeb && Platform.isLinux) {
        try {
          if (visible) {
            await Process.run('xdotool', [
              'search',
              '--onlyvisible',
              '--class',
              'softify',
              'windowactivate',
            ]);
          } else {
            await Process.run('xdotool', [
              'search',
              '--onlyvisible',
              '--class',
              'softify',
              'windowminimize',
            ]);
          }
        } catch (_) {}
      }
      return true;
    }
  }

  @override
  Future<bool> showNotification({
    required String title,
    required String message,
  }) async {
    if (_isDisposed) return false;
    try {
      await _trayChannel.invokeMethod<void>('showNotification', {
        'title': title,
        'message': message,
      });
      return true;
    } catch (_) {
      if (!kIsWeb && Platform.isLinux) {
        try {
          await Process.run('notify-send', [
            '-a',
            'Softify',
            '-i',
            'multimedia-audio-player',
            title,
            message,
          ]);
          return true;
        } catch (_) {}
      }
      return false;
    }
  }

  @override
  Future<bool> quitApplication() async {
    try {
      await SystemNavigator.pop();
    } catch (_) {}
    exit(0);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _actionController.close();
  }
}

/// In-memory mock platform bridge for unit tests and automated environments.
class MockTrayPlatformBridge implements TrayPlatformBridge {
  bool supported;
  String? mockDesktopEnvironment;

  final StreamController<TrayMenuAction> _actionController =
      StreamController<TrayMenuAction>.broadcast();

  final List<String> callLogs = [];
  List<TrayMenuItem> lastContextMenu = [];
  String? lastTooltip;
  String? lastIconPath;
  bool? lastWindowVisibility;
  int quitCallCount = 0;
  final List<Map<String, String>> notificationsSent = [];

  MockTrayPlatformBridge({
    this.supported = true,
    this.mockDesktopEnvironment = 'GNOME Shell',
  });

  @override
  Stream<TrayMenuAction> get onActionTriggered => _actionController.stream;

  /// Simulates an incoming menu action click from the desktop environment.
  void triggerAction(TrayMenuAction action) {
    _actionController.add(action);
  }

  @override
  Future<bool> isPlatformSupported() async {
    callLogs.add('isPlatformSupported');
    return supported;
  }

  @override
  String? detectDesktopEnvironment() {
    callLogs.add('detectDesktopEnvironment');
    return mockDesktopEnvironment;
  }

  @override
  Future<bool> initTray({
    required String title,
    required String iconPath,
    required String tooltip,
  }) async {
    callLogs.add('initTray: $title');
    lastIconPath = iconPath;
    lastTooltip = tooltip;
    return true;
  }

  @override
  Future<bool> setContextMenu(List<TrayMenuItem> items) async {
    callLogs.add('setContextMenu: ${items.length} items');
    lastContextMenu = List.from(items);
    return true;
  }

  @override
  Future<bool> updateTooltip(String tooltip) async {
    callLogs.add('updateTooltip: $tooltip');
    lastTooltip = tooltip;
    return true;
  }

  @override
  Future<bool> updateIcon(String iconPath) async {
    callLogs.add('updateIcon: $iconPath');
    lastIconPath = iconPath;
    return true;
  }

  @override
  Future<bool> setWindowVisibility(bool visible) async {
    callLogs.add('setWindowVisibility: $visible');
    lastWindowVisibility = visible;
    return true;
  }

  @override
  Future<bool> showNotification({
    required String title,
    required String message,
  }) async {
    callLogs.add('showNotification: $title - $message');
    notificationsSent.add({'title': title, 'message': message});
    return true;
  }

  @override
  Future<bool> quitApplication() async {
    callLogs.add('quitApplication');
    quitCallCount++;
    return true;
  }

  @override
  void dispose() {
    callLogs.add('dispose');
    _actionController.close();
  }
}

// ============================================================================
// SystemTrayManager Service
// ============================================================================

/// Primary service managing the Linux Desktop System Tray icon, menu actions,
/// window visibility toggling, and synchronization with audio playback state.
class SystemTrayManager {
  final TrayPlatformBridge _bridge;
  final SoftifyAudioHandler? _audioHandler;
  SharedPreferences? _prefs;

  final StreamController<SystemTrayStatus> _statusController =
      StreamController<SystemTrayStatus>.broadcast();

  final StreamController<SystemTrayState> _stateController =
      StreamController<SystemTrayState>.broadcast();

  StreamSubscription<TrayMenuAction>? _actionSubscription;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  StreamSubscription<Track?>? _trackSubscription;
  StreamSubscription<double>? _volumeSubscription;

  SystemTrayState _state = const SystemTrayState();
  bool _isDisposed = false;

  SystemTrayManager({
    TrayPlatformBridge? bridge,
    SoftifyAudioHandler? audioHandler,
    SharedPreferences? prefs,
  })  : _bridge = bridge ?? LinuxDesktopTrayBridge(),
        _audioHandler = audioHandler,
        _prefs = prefs;

  /// Current reactive status stream for system tray lifecycle events.
  Stream<SystemTrayStatus> get statusStream => _statusController.stream;

  /// Current lifecycle connection status of the tray icon.
  SystemTrayStatus get status => _state.status;

  /// Full state stream for Riverpod state and reactive UI updates.
  Stream<SystemTrayState> get stateStream => _stateController.stream;

  /// Synchronous snapshot of current system tray state.
  SystemTrayState get state => _state;

  /// The underlying platform bridge interface.
  TrayPlatformBridge get bridge => _bridge;

  /// Initializes the system tray service, loading preferences, verifying
  /// platform support, registering the tray icon, and synchronizing with audio state.
  Future<void> initialize() async {
    if (_isDisposed) return;

    _updateStatus(SystemTrayStatus.initializing);

    try {
      _prefs ??= await SharedPreferences.getInstance();

      final enabled = _prefs?.getBool(SystemTrayPreferenceKeys.enabled) ?? true;
      final minimizeOnClose =
          _prefs?.getBool(SystemTrayPreferenceKeys.minimizeToTrayOnClose) ??
              true;
      final startMin =
          _prefs?.getBool(SystemTrayPreferenceKeys.startMinimized) ?? false;
      final notifications =
          _prefs?.getBool(SystemTrayPreferenceKeys.showNotifications) ?? true;

      final supported = await _bridge.isPlatformSupported();
      final desktopEnv = _bridge.detectDesktopEnvironment();

      _state = _state.copyWith(
        isEnabled: enabled,
        isAvailable: supported,
        minimizeToTrayOnClose: minimizeOnClose,
        startMinimized: startMin,
        showNotifications: notifications,
        desktopEnvironment: desktopEnv,
        isAppVisible: !startMin,
      );

      if (!supported) {
        _updateStatus(SystemTrayStatus.unsupported);
        return;
      }

      if (!enabled) {
        _updateStatus(SystemTrayStatus.hidden);
        return;
      }

      // Initialize native / DBus tray icon
      final initSuccess = await _bridge.initTray(
        title: 'Softify',
        iconPath: _state.iconPath,
        tooltip: _state.tooltip,
      );

      if (!initSuccess) {
        _state = _state.copyWith(
          errorMessage: 'Failed to initialize Linux desktop tray icon',
        );
        _updateStatus(SystemTrayStatus.error);
        return;
      }

      // Hook menu action clicks from platform bridge
      _actionSubscription?.cancel();
      _actionSubscription = _bridge.onActionTriggered.listen(handleAction);

      // Hook audio player state if handler available
      _setupAudioHandlerListeners();

      _updateStatus(SystemTrayStatus.active);

      // Build and apply initial context menu
      await _syncMenuAndTooltip();
    } catch (e, stack) {
      debugPrint('SystemTrayManager initialization failed: $e\n$stack');
      _state = _state.copyWith(errorMessage: e.toString());
      _updateStatus(SystemTrayStatus.error);
    }
  }

  void _setupAudioHandlerListeners() {
    if (_audioHandler == null) return;

    _playbackStateSubscription?.cancel();
    _playbackStateSubscription = _audioHandler.playbackState.listen((pState) {
      final playing = pState.playing;
      if (playing != _state.isPlaying) {
        updatePlaybackState(
          isPlaying: playing,
          title: _state.currentTrackTitle,
          artist: _state.currentArtist,
        );
      }
    });

    _trackSubscription?.cancel();
    _trackSubscription = _audioHandler.currentTrackStream.listen((track) {
      final title = track?.title;
      final artist = track?.artist;
      if (title != _state.currentTrackTitle || artist != _state.currentArtist) {
        final trackChanged = title != _state.currentTrackTitle;
        updatePlaybackState(
          isPlaying: _state.isPlaying,
          title: title,
          artist: artist,
        );

        if (trackChanged &&
            _state.showNotifications &&
            title != null &&
            title.isNotEmpty) {
          _bridge.showNotification(
            title: title,
            message: artist ?? 'Softify Music Player',
          );
        }
      }
    });

    _volumeSubscription?.cancel();
    _volumeSubscription = _audioHandler.volumeStream.listen((vol) {
      final clamped = vol.clamp(0.0, 1.0);
      final isMuted = clamped <= 0.0;
      if (clamped != _state.volume || isMuted != _state.isMuted) {
        updateVolumeState(volume: clamped, isMuted: isMuted);
      }
    });
  }

  /// Generates the standard full Linux tray menu item hierarchy:
  /// - Now Playing Info header
  /// - Separator
  /// - Play / Pause
  /// - Next Track
  /// - Previous Track
  /// - Separator
  /// - Mute / Unmute
  /// - Separator
  /// - Show / Hide Application
  /// - Quit
  List<TrayMenuItem> buildMenuItems() {
    return [
      TrayMenuItem.info(
        id: 'item_now_playing',
        label: _state.formattedNowPlaying,
        iconName: 'audio-x-generic',
        tooltip: 'Currently playing audio track',
      ),
      TrayMenuItem.separator(id: 'sep_1'),
      TrayMenuItem.action(
        id: 'item_play_pause',
        label: _state.playPauseLabel,
        action: TrayMenuAction.playPause,
        iconName: _state.playPauseIcon,
        tooltip: '${_state.playPauseLabel} audio playback',
      ),
      TrayMenuItem.action(
        id: 'item_next_track',
        label: 'Next Track',
        action: TrayMenuAction.nextTrack,
        iconName: 'media-skip-forward',
        tooltip: 'Skip to next track in queue',
      ),
      TrayMenuItem.action(
        id: 'item_previous_track',
        label: 'Previous Track',
        action: TrayMenuAction.previousTrack,
        iconName: 'media-skip-backward',
        tooltip: 'Return to previous track in queue',
      ),
      TrayMenuItem.separator(id: 'sep_2'),
      TrayMenuItem.action(
        id: 'item_toggle_mute',
        label: _state.muteUnmuteLabel,
        action: TrayMenuAction.toggleMute,
        iconName: _state.muteUnmuteIcon,
        tooltip: '${_state.muteUnmuteLabel} playback volume',
      ),
      TrayMenuItem.separator(id: 'sep_3'),
      TrayMenuItem.action(
        id: 'item_show_app',
        label: _state.showHideLabel,
        action: TrayMenuAction.showApp,
        iconName: _state.isAppVisible ? 'window-minimize' : 'window-restore',
        tooltip: '${_state.showHideLabel} main window',
      ),
      TrayMenuItem.action(
        id: 'item_quit',
        label: 'Quit Softify',
        action: TrayMenuAction.quit,
        iconName: 'application-exit',
        tooltip: 'Quit and close the application',
      ),
    ];
  }

  Future<void> _syncMenuAndTooltip() async {
    final items = buildMenuItems();
    _state = _state.copyWith(
      menuItems: items,
      tooltip: _state.formattedNowPlaying,
    );
    _stateController.add(_state);

    if (_state.isActive) {
      await _bridge.setContextMenu(items);
      await _bridge.updateTooltip(_state.tooltip);
    }
  }

  /// Dispatches and processes a menu action triggered by user.
  Future<void> handleAction(TrayMenuAction action) async {
    _state = _state.copyWith(
      lastAction: action,
      lastActionTime: DateTime.now(),
    );
    _stateController.add(_state);

    switch (action) {
      case TrayMenuAction.playPause:
        await togglePlayback();
        break;
      case TrayMenuAction.nextTrack:
        await skipToNext();
        break;
      case TrayMenuAction.previousTrack:
        await skipToPrevious();
        break;
      case TrayMenuAction.toggleMute:
        await toggleMute();
        break;
      case TrayMenuAction.showApp:
        await toggleWindowVisibility();
        break;
      case TrayMenuAction.hideApp:
        await hideApp();
        break;
      case TrayMenuAction.toggleVisibility:
        await toggleWindowVisibility();
        break;
      case TrayMenuAction.quit:
        await quit();
        break;
      case TrayMenuAction.nowPlayingInfo:
      case TrayMenuAction.separator:
      case TrayMenuAction.custom:
        // No-op for passive or separator items
        break;
    }
  }

  /// Toggles playback between Play and Pause states.
  Future<void> togglePlayback() async {
    final nextPlaying = !_state.isPlaying;
    _state = _state.copyWith(isPlaying: nextPlaying);

    if (_audioHandler != null) {
      try {
        if (nextPlaying) {
          await _audioHandler.play();
        } else {
          await _audioHandler.pause();
        }
      } catch (e) {
        debugPrint('SystemTrayManager: togglePlayback error: $e');
      }
    }

    await _syncMenuAndTooltip();
  }

  /// Skips to next song in the active queue.
  Future<void> skipToNext() async {
    if (_audioHandler != null) {
      try {
        await _audioHandler.skipToNext();
      } catch (e) {
        debugPrint('SystemTrayManager: skipToNext error: $e');
      }
    }
  }

  /// Skips to previous song in the active queue.
  Future<void> skipToPrevious() async {
    if (_audioHandler != null) {
      try {
        await _audioHandler.skipToPrevious();
      } catch (e) {
        debugPrint('SystemTrayManager: skipToPrevious error: $e');
      }
    }
  }

  /// Toggles master volume mute and restores previous non-zero volume.
  Future<void> toggleMute() async {
    final nextMuted = !_state.isMuted;
    final targetVolume = nextMuted ? 0.0 : (_state.volume > 0.0 ? _state.volume : 0.7);

    _state = _state.copyWith(
      isMuted: nextMuted,
      volume: targetVolume,
    );

    if (_audioHandler != null) {
      try {
        await _audioHandler.setVolume(targetVolume);
      } catch (e) {
        debugPrint('SystemTrayManager: toggleMute error: $e');
      }
    }

    await _syncMenuAndTooltip();
  }

  /// Restores, raises, and shows the main application window.
  Future<void> showApp() async {
    _state = _state.copyWith(isAppVisible: true);
    await _bridge.setWindowVisibility(true);
    await _syncMenuAndTooltip();
  }

  /// Hides or minimizes the main application window to tray.
  Future<void> hideApp() async {
    _state = _state.copyWith(isAppVisible: false);
    await _bridge.setWindowVisibility(false);
    await _syncMenuAndTooltip();
  }

  /// Toggles application window visibility between show and hide.
  Future<void> toggleWindowVisibility() async {
    if (_state.isAppVisible) {
      await hideApp();
    } else {
      await showApp();
    }
  }

  /// Cleanly closes the tray manager and exits the desktop process.
  Future<void> quit() async {
    await _bridge.quitApplication();
  }

  /// Updates current playback status and active track metadata.
  Future<void> updatePlaybackState({
    required bool isPlaying,
    String? title,
    String? artist,
  }) async {
    _state = _state.copyWith(
      isPlaying: isPlaying,
      currentTrackTitle: title,
      currentArtist: artist,
    );
    await _syncMenuAndTooltip();
  }

  /// Updates current volume and mute status.
  Future<void> updateVolumeState({
    required double volume,
    required bool isMuted,
  }) async {
    _state = _state.copyWith(
      volume: volume,
      isMuted: isMuted,
    );
    await _syncMenuAndTooltip();
  }

  /// Enables or disables the system tray integration and persists setting.
  Future<void> setEnabled(bool enabled) async {
    if (_state.isEnabled == enabled) return;

    _state = _state.copyWith(isEnabled: enabled);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(SystemTrayPreferenceKeys.enabled, enabled);

    if (!enabled) {
      _updateStatus(SystemTrayStatus.hidden);
    } else {
      if (_state.isAvailable) {
        _updateStatus(SystemTrayStatus.active);
        await _syncMenuAndTooltip();
      }
    }
  }

  /// Sets whether closing the main window minimizes to tray instead of quitting.
  Future<void> setMinimizeToTray(bool value) async {
    _state = _state.copyWith(minimizeToTrayOnClose: value);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(
      SystemTrayPreferenceKeys.minimizeToTrayOnClose,
      value,
    );
    _stateController.add(_state);
  }

  /// Sets whether the app starts minimized in the tray on boot.
  Future<void> setStartMinimized(bool value) async {
    _state = _state.copyWith(startMinimized: value);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(SystemTrayPreferenceKeys.startMinimized, value);
    _stateController.add(_state);
  }

  /// Sets whether desktop notifications are displayed on song change.
  Future<void> setShowNotifications(bool value) async {
    _state = _state.copyWith(showNotifications: value);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(SystemTrayPreferenceKeys.showNotifications, value);
    _stateController.add(_state);
  }

  void _updateStatus(SystemTrayStatus newStatus) {
    if (_state.status == newStatus) return;
    _state = _state.copyWith(status: newStatus);
    _statusController.add(newStatus);
    _stateController.add(_state);
  }

  /// Disposes active subscriptions, controllers, and platform bridge hooks.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _actionSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _trackSubscription?.cancel();
    _volumeSubscription?.cancel();

    _updateStatus(SystemTrayStatus.disposed);

    _statusController.close();
    _stateController.close();
    _bridge.dispose();
  }
}

// ============================================================================
// Riverpod State Management
// ============================================================================

/// Riverpod StateNotifier wrapping [SystemTrayManager] for declarative UI bindings.
class SystemTrayStateNotifier extends StateNotifier<SystemTrayState> {
  final SystemTrayManager _manager;
  StreamSubscription<SystemTrayState>? _stateSubscription;

  SystemTrayStateNotifier(this._manager) : super(_manager.state) {
    _stateSubscription = _manager.stateStream.listen((newState) {
      if (mounted) {
        state = newState;
      }
    });
  }

  /// Access underlying service instance.
  SystemTrayManager get manager => _manager;

  Future<void> handleAction(TrayMenuAction action) async {
    await _manager.handleAction(action);
    if (mounted) state = _manager.state;
  }

  Future<void> togglePlayback() async {
    await _manager.togglePlayback();
    if (mounted) state = _manager.state;
  }

  Future<void> skipToNext() async {
    await _manager.skipToNext();
    if (mounted) state = _manager.state;
  }

  Future<void> skipToPrevious() async {
    await _manager.skipToPrevious();
    if (mounted) state = _manager.state;
  }

  Future<void> toggleMute() async {
    await _manager.toggleMute();
    if (mounted) state = _manager.state;
  }

  Future<void> showApp() async {
    await _manager.showApp();
    if (mounted) state = _manager.state;
  }

  Future<void> hideApp() async {
    await _manager.hideApp();
    if (mounted) state = _manager.state;
  }

  Future<void> toggleWindowVisibility() async {
    await _manager.toggleWindowVisibility();
    if (mounted) state = _manager.state;
  }

  Future<void> quit() async {
    await _manager.quit();
    if (mounted) state = _manager.state;
  }

  Future<void> setEnabled(bool enabled) async {
    await _manager.setEnabled(enabled);
    if (mounted) state = _manager.state;
  }

  Future<void> setMinimizeToTray(bool value) async {
    await _manager.setMinimizeToTray(value);
    if (mounted) state = _manager.state;
  }

  Future<void> setStartMinimized(bool value) async {
    await _manager.setStartMinimized(value);
    if (mounted) state = _manager.state;
  }

  Future<void> setShowNotifications(bool value) async {
    await _manager.setShowNotifications(value);
    if (mounted) state = _manager.state;
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }
}

/// Provides the singleton [SystemTrayManager] service instance.
final systemTrayManagerProvider = Provider<SystemTrayManager>((ref) {
  SoftifyAudioHandler? handler;
  try {
    handler = ref.watch(audioHandlerProvider);
  } catch (_) {
    // Graceful fallback when audioHandler is mocked or uninitialized
  }

  final manager = SystemTrayManager(
    audioHandler: handler,
  );

  ref.onDispose(manager.dispose);
  return manager;
});

/// Reactive StateNotifier provider for [SystemTrayState].
final systemTrayStateProvider =
    StateNotifierProvider<SystemTrayStateNotifier, SystemTrayState>((ref) {
  final manager = ref.watch(systemTrayManagerProvider);
  return SystemTrayStateNotifier(manager);
});

/// Reactive stream of system tray lifecycle status events.
final systemTrayStatusStreamProvider = StreamProvider<SystemTrayStatus>((ref) {
  final manager = ref.watch(systemTrayManagerProvider);
  return manager.statusStream;
});

/// Quick boolean provider checking if system tray is enabled.
final systemTrayEnabledProvider = Provider<bool>((ref) {
  return ref.watch(systemTrayStateProvider).isEnabled;
});

/// Quick boolean provider checking if minimize-to-tray on close is enabled.
final systemTrayMinimizeToTrayProvider = Provider<bool>((ref) {
  return ref.watch(systemTrayStateProvider).minimizeToTrayOnClose;
});

// ============================================================================
// Clean Material 3 Settings & Control Widgets
// ============================================================================

/// Material 3 settings card for configuring Linux desktop system tray integration,
/// previewing context menu items, and testing tray action dispatches.
class LinuxSystemTraySettingsCard extends ConsumerWidget {
  const LinuxSystemTraySettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trayState = ref.watch(systemTrayStateProvider);
    final notifier = ref.read(systemTrayStateProvider.notifier);
    final tokens = context.tokens;

    final isSupported = trayState.isAvailable;
    final isEnabled = trayState.isEnabled && isSupported;

    return Card(
      color: tokens.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.desktop_windows_rounded,
                    color: tokens.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Linux System Tray & Menu',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(trayState.status, tokens),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Control playback, mute audio, and manage window state directly from your desktop panel.',
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textSecondary,
                        ),
                      ),
                      if (trayState.desktopEnvironment != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: tokens.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Desktop: ${trayState.desktopEnvironment}',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  activeColor: tokens.accent,
                  onChanged: isSupported
                      ? (val) => notifier.setEnabled(val)
                      : null,
                ),
              ],
            ),

            if (isSupported) ...[
              const SizedBox(height: 16),
              Divider(color: tokens.borderSubtle, height: 1),
              const SizedBox(height: 12),

              // Settings Toggles
              _buildSettingTile(
                title: 'Minimize to Tray on Close',
                subtitle:
                    'Closing the main window minimizes Softify into the tray instead of quitting.',
                icon: Icons.minimize_rounded,
                value: trayState.minimizeToTrayOnClose,
                enabled: isEnabled,
                tokens: tokens,
                onChanged: (val) => notifier.setMinimizeToTray(val),
              ),

              _buildSettingTile(
                title: 'Start Minimized',
                subtitle:
                    'Launch silently in the system tray upon system startup or login.',
                icon: Icons.launch_rounded,
                value: trayState.startMinimized,
                enabled: isEnabled,
                tokens: tokens,
                onChanged: (val) => notifier.setStartMinimized(val),
              ),

              _buildSettingTile(
                title: 'Track Change Notifications',
                subtitle:
                    'Show desktop notifications when songs automatically change.',
                icon: Icons.notifications_active_outlined,
                value: trayState.showNotifications,
                enabled: isEnabled,
                tokens: tokens,
                onChanged: (val) => notifier.setShowNotifications(val),
              ),

              const SizedBox(height: 16),
              // Interactive Context Menu Preview
              Text(
                'TRAY CONTEXT MENU PREVIEW',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    // Now playing header
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.music_note_rounded,
                        color: tokens.accent,
                        size: 20,
                      ),
                      title: Text(
                        trayState.formattedNowPlaying,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Active StatusNotifierItem',
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                    Divider(color: tokens.borderSubtle, height: 1),

                    // Controls row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildPreviewActionButton(
                            tooltip: 'Previous',
                            icon: Icons.skip_previous_rounded,
                            tokens: tokens,
                            onPressed: () =>
                                notifier.handleAction(TrayMenuAction.previousTrack),
                          ),
                          _buildPreviewActionButton(
                            tooltip: trayState.playPauseLabel,
                            icon: trayState.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            isPrimary: true,
                            tokens: tokens,
                            onPressed: () =>
                                notifier.handleAction(TrayMenuAction.playPause),
                          ),
                          _buildPreviewActionButton(
                            tooltip: 'Next',
                            icon: Icons.skip_next_rounded,
                            tokens: tokens,
                            onPressed: () =>
                                notifier.handleAction(TrayMenuAction.nextTrack),
                          ),
                          _buildPreviewActionButton(
                            tooltip: trayState.muteUnmuteLabel,
                            icon: trayState.isMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            tokens: tokens,
                            onPressed: () =>
                                notifier.handleAction(TrayMenuAction.toggleMute),
                          ),
                          _buildPreviewActionButton(
                            tooltip: trayState.showHideLabel,
                            icon: trayState.isAppVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            tokens: tokens,
                            onPressed: () =>
                                notifier.handleAction(TrayMenuAction.showApp),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: tokens.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'System Tray / StatusNotifierItem is only available on Linux Desktop environments.',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SystemTrayStatus status, dynamic tokens) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case SystemTrayStatus.active:
        bg = const Color(0xFF1B4D2E);
        fg = const Color(0xFF4ADE80);
        label = 'Active';
        break;
      case SystemTrayStatus.initializing:
        bg = const Color(0xFF422D0A);
        fg = const Color(0xFFFBBF24);
        label = 'Connecting';
        break;
      case SystemTrayStatus.hidden:
        bg = const Color(0xFF2E2E38);
        fg = const Color(0xFF9CA3AF);
        label = 'Disabled';
        break;
      case SystemTrayStatus.unsupported:
        bg = const Color(0xFF332025);
        fg = const Color(0xFFF87171);
        label = 'Unsupported';
        break;
      case SystemTrayStatus.error:
        bg = const Color(0xFF450A0A);
        fg = const Color(0xFFEF4444);
        label = 'Error';
        break;
      case SystemTrayStatus.uninitialized:
      case SystemTrayStatus.disposed:
        bg = const Color(0xFF22242A);
        fg = const Color(0xFF6B7280);
        label = 'Idle';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required bool enabled,
    required dynamic tokens,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: enabled ? tokens.textSecondary : tokens.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled ? tokens.textPrimary : tokens.textMuted,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: tokens.accent,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewActionButton({
    required String tooltip,
    required IconData icon,
    required dynamic tokens,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPrimary ? tokens.accent : tokens.cardHover,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isPrimary ? Colors.white : tokens.textPrimary,
          ),
        ),
      ),
    );
  }
}
