import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/shared/app_surface.dart';

/// Supported contexts/modes that can request screen wake lock.
enum WakelockMode {
  fullscreenPlayer,
  lyricsMode,
  carMode,
}

extension WakelockModeDetails on WakelockMode {
  String get title {
    switch (this) {
      case WakelockMode.fullscreenPlayer:
        return 'Fullscreen Player';
      case WakelockMode.lyricsMode:
        return 'Lyrics View';
      case WakelockMode.carMode:
        return 'Car Mode';
    }
  }

  String get description {
    switch (this) {
      case WakelockMode.fullscreenPlayer:
        return 'Keep screen awake while viewing full-screen player';
      case WakelockMode.lyricsMode:
        return 'Keep screen awake when viewing synchronized lyrics';
      case WakelockMode.carMode:
        return 'Keep screen awake while in automotive driving mode';
    }
  }

  IconData get icon {
    switch (this) {
      case WakelockMode.fullscreenPlayer:
        return Icons.play_circle_outline_rounded;
      case WakelockMode.lyricsMode:
        return Icons.music_note_rounded;
      case WakelockMode.carMode:
        return Icons.directions_car_rounded;
    }
  }
}

/// Immutable state representing active wake lock acquisitions and user preferences.
class ScreenWakelockState {
  final bool isMasterEnabled;
  final bool keepAwakeFullscreen;
  final bool keepAwakeLyrics;
  final bool keepAwakeCarMode;
  final Set<WakelockMode> activeModes;
  final bool isLocked;

  const ScreenWakelockState({
    this.isMasterEnabled = true,
    this.keepAwakeFullscreen = true,
    this.keepAwakeLyrics = true,
    this.keepAwakeCarMode = true,
    this.activeModes = const {},
    this.isLocked = false,
  });

  /// Evaluates whether the screen should be held awake based on
  /// master toggle, per-feature settings, and currently active UI modes.
  bool get shouldBeAwake {
    if (!isMasterEnabled) return false;
    for (final mode in activeModes) {
      switch (mode) {
        case WakelockMode.fullscreenPlayer:
          if (keepAwakeFullscreen) return true;
          break;
        case WakelockMode.lyricsMode:
          if (keepAwakeLyrics) return true;
          break;
        case WakelockMode.carMode:
          if (keepAwakeCarMode) return true;
          break;
      }
    }
    return false;
  }

  bool isModeAllowed(WakelockMode mode) {
    switch (mode) {
      case WakelockMode.fullscreenPlayer:
        return keepAwakeFullscreen;
      case WakelockMode.lyricsMode:
        return keepAwakeLyrics;
      case WakelockMode.carMode:
        return keepAwakeCarMode;
    }
  }

  ScreenWakelockState copyWith({
    bool? isMasterEnabled,
    bool? keepAwakeFullscreen,
    bool? keepAwakeLyrics,
    bool? keepAwakeCarMode,
    Set<WakelockMode>? activeModes,
    bool? isLocked,
  }) {
    return ScreenWakelockState(
      isMasterEnabled: isMasterEnabled ?? this.isMasterEnabled,
      keepAwakeFullscreen: keepAwakeFullscreen ?? this.keepAwakeFullscreen,
      keepAwakeLyrics: keepAwakeLyrics ?? this.keepAwakeLyrics,
      keepAwakeCarMode: keepAwakeCarMode ?? this.keepAwakeCarMode,
      activeModes: activeModes ?? this.activeModes,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScreenWakelockState &&
        other.isMasterEnabled == isMasterEnabled &&
        other.keepAwakeFullscreen == keepAwakeFullscreen &&
        other.keepAwakeLyrics == keepAwakeLyrics &&
        other.keepAwakeCarMode == keepAwakeCarMode &&
        setEquals(other.activeModes, activeModes) &&
        other.isLocked == isLocked;
  }

  @override
  int get hashCode => Object.hash(
        isMasterEnabled,
        keepAwakeFullscreen,
        keepAwakeLyrics,
        keepAwakeCarMode,
        Object.hashAll(activeModes),
        isLocked,
      );
}

/// Platform-level screen wake lock abstraction.
///
/// Tries native Flutter wakelock method channels, and provides a safe fallback
/// for Linux desktop via freedesktop ScreenSaver DBus idle inhibition,
/// degrading gracefully to a safe no-op on failures.
class WakelockPlatformHandler {
  static const List<MethodChannel> _channels = [
    MethodChannel('wakelock_plus'),
    MethodChannel('plugins.flutter.io/wakelock'),
  ];

  int? _linuxInhibitCookie;
  bool _isDisposed = false;

  Future<bool> setKeepAwake(bool enable) async {
    if (_isDisposed) return false;

    // 1. Try standard mobile/desktop native wakelock plugin channels first.
    for (final channel in _channels) {
      try {
        await channel.invokeMethod<void>('toggle', {'enable': enable});
        return true;
      } on MissingPluginException {
        // Plugin not registered on this platform, continue to fallback.
      } on PlatformException {
        // Platform invocation failed, continue to fallback.
      } catch (_) {
        // Any other error, continue to fallback.
      }
    }

    // 2. Linux Desktop fallback: Freedesktop ScreenSaver idle inhibit.
    if (!kIsWeb && Platform.isLinux) {
      return await _handleLinuxIdleInhibit(enable);
    }

    // Safe fallback: no-op if native plugin is unavailable.
    return false;
  }

  Future<bool> _handleLinuxIdleInhibit(bool enable) async {
    try {
      if (enable) {
        if (_linuxInhibitCookie != null) return true;

        // Try dbus-send method call
        final result = await Process.run('dbus-send', [
          '--session',
          '--dest=org.freedesktop.ScreenSaver',
          '--type=method_call',
          '--print-reply',
          '/org/freedesktop/ScreenSaver',
          'org.freedesktop.ScreenSaver.Inhibit',
          'string:Softify',
          'string:Music Playback Keep-Awake',
        ]);

        if (result.exitCode == 0) {
          final stdoutStr = result.stdout.toString();
          final match = RegExp(r'uint32\s+(\d+)').firstMatch(stdoutStr);
          if (match != null) {
            _linuxInhibitCookie = int.tryParse(match.group(1)!);
            return true;
          }
        }

        // Secondary fallback: gdbus
        final gdbusResult = await Process.run('gdbus', [
          'call',
          '--session',
          '--dest',
          'org.freedesktop.ScreenSaver',
          '--object-path',
          '/org/freedesktop/ScreenSaver',
          '--method',
          'org.freedesktop.ScreenSaver.Inhibit',
          'Softify',
          'Music Playback Keep-Awake',
        ]);

        if (gdbusResult.exitCode == 0) {
          final stdoutStr = gdbusResult.stdout.toString();
          final match = RegExp(r'uint32\s+(\d+)').firstMatch(stdoutStr);
          if (match != null) {
            _linuxInhibitCookie = int.tryParse(match.group(1)!);
            return true;
          }
        }
      } else {
        if (_linuxInhibitCookie != null) {
          final cookie = _linuxInhibitCookie!;
          _linuxInhibitCookie = null;

          await Process.run('dbus-send', [
            '--session',
            '--dest=org.freedesktop.ScreenSaver',
            '--type=method_call',
            '/org/freedesktop/ScreenSaver',
            'org.freedesktop.ScreenSaver.UnInhibit',
            'uint32:$cookie',
          ]);
          return true;
        }
      }
    } catch (_) {
      // Safe no-op on missing binaries, sandbox restrictions, or permission errors.
    }
    return false;
  }

  void dispose() {
    _isDisposed = true;
    if (_linuxInhibitCookie != null) {
      final cookie = _linuxInhibitCookie!;
      _linuxInhibitCookie = null;
      try {
        Process.runSync('dbus-send', [
          '--session',
          '--dest=org.freedesktop.ScreenSaver',
          '--type=method_call',
          '/org/freedesktop/ScreenSaver',
          'org.freedesktop.ScreenSaver.UnInhibit',
          'uint32:$cookie',
        ]);
      } catch (_) {}
    }
  }
}

/// Screen WakeLock Manager coordinates keep-awake state across
/// Fullscreen Player, Lyrics Mode, and Car Mode, persisting user preferences
/// in Drift database and delegating to [WakelockPlatformHandler].
class ScreenWakelockManager extends StateNotifier<ScreenWakelockState> {
  final AppDatabase? _db;
  final WakelockPlatformHandler _platformHandler;

  ScreenWakelockManager([this._db, WakelockPlatformHandler? platformHandler])
      : _platformHandler = platformHandler ?? WakelockPlatformHandler(),
        super(const ScreenWakelockState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_db == null) return;
    try {
      final rows = await (_db.select(_db.settings)
            ..where((t) => t.key.isIn([
                  'screen_wakelock_master',
                  'screen_wakelock_fullscreen',
                  'screen_wakelock_lyrics',
                  'screen_wakelock_car_mode',
                ])))
          .get();

      bool master = true;
      bool fullscreen = true;
      bool lyrics = true;
      bool carMode = true;

      for (final row in rows) {
        if (row.key == 'screen_wakelock_master') {
          master = row.value != 'false';
        } else if (row.key == 'screen_wakelock_fullscreen') {
          fullscreen = row.value != 'false';
        } else if (row.key == 'screen_wakelock_lyrics') {
          lyrics = row.value != 'false';
        } else if (row.key == 'screen_wakelock_car_mode') {
          carMode = row.value != 'false';
        }
      }

      state = state.copyWith(
        isMasterEnabled: master,
        keepAwakeFullscreen: fullscreen,
        keepAwakeLyrics: lyrics,
        keepAwakeCarMode: carMode,
      );
      await _syncWakelock();
    } catch (_) {}
  }

  Future<void> _saveSetting(String key, bool value) async {
    if (_db == null) return;
    try {
      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingRow(
              key: key,
              value: value.toString(),
            ),
          );
    } catch (_) {}
  }

  /// Request screen wake lock for a given UI mode.
  void acquire(WakelockMode mode) {
    if (state.activeModes.contains(mode)) return;
    final updated = Set<WakelockMode>.from(state.activeModes)..add(mode);
    state = state.copyWith(activeModes: updated);
    _syncWakelock();
  }

  /// Release screen wake lock request for a given UI mode.
  void release(WakelockMode mode) {
    if (!state.activeModes.contains(mode)) return;
    final updated = Set<WakelockMode>.from(state.activeModes)..remove(mode);
    state = state.copyWith(activeModes: updated);
    _syncWakelock();
  }

  /// Convenience helper to set wake lock state active or inactive.
  void setModeActive(WakelockMode mode, bool active) {
    if (active) {
      acquire(mode);
    } else {
      release(mode);
    }
  }

  /// Master switch to enable or disable wake lock globally.
  Future<void> setMasterEnabled(bool enabled) async {
    if (state.isMasterEnabled == enabled) return;
    state = state.copyWith(isMasterEnabled: enabled);
    await _saveSetting('screen_wakelock_master', enabled);
    await _syncWakelock();
  }

  /// Toggle keep-awake for Fullscreen Player.
  Future<void> setFullscreenEnabled(bool enabled) async {
    if (state.keepAwakeFullscreen == enabled) return;
    state = state.copyWith(keepAwakeFullscreen: enabled);
    await _saveSetting('screen_wakelock_fullscreen', enabled);
    await _syncWakelock();
  }

  /// Toggle keep-awake for Lyrics Mode.
  Future<void> setLyricsEnabled(bool enabled) async {
    if (state.keepAwakeLyrics == enabled) return;
    state = state.copyWith(keepAwakeLyrics: enabled);
    await _saveSetting('screen_wakelock_lyrics', enabled);
    await _syncWakelock();
  }

  /// Toggle keep-awake for Car Mode.
  Future<void> setCarModeEnabled(bool enabled) async {
    if (state.keepAwakeCarMode == enabled) return;
    state = state.copyWith(keepAwakeCarMode: enabled);
    await _saveSetting('screen_wakelock_car_mode', enabled);
    await _syncWakelock();
  }

  /// Toggle master wake lock switch.
  Future<void> toggleMaster() => setMasterEnabled(!state.isMasterEnabled);

  /// Toggle wake lock setting for a specific mode.
  Future<void> toggleMode(WakelockMode mode) {
    switch (mode) {
      case WakelockMode.fullscreenPlayer:
        return setFullscreenEnabled(!state.keepAwakeFullscreen);
      case WakelockMode.lyricsMode:
        return setLyricsEnabled(!state.keepAwakeLyrics);
      case WakelockMode.carMode:
        return setCarModeEnabled(!state.keepAwakeCarMode);
    }
  }

  Future<void> _syncWakelock() async {
    final shouldLock = state.shouldBeAwake;
    if (state.isLocked != shouldLock) {
      state = state.copyWith(isLocked: shouldLock);
      await _platformHandler.setKeepAwake(shouldLock);
    }
  }

  @override
  void dispose() {
    _platformHandler.dispose();
    super.dispose();
  }
}

/// Riverpod provider for [ScreenWakelockManager].
final screenWakelockProvider =
    StateNotifierProvider<ScreenWakelockManager, ScreenWakelockState>((ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}
  return ScreenWakelockManager(db);
});

/// A declarative wrapper that acquires wake lock for [mode] while mounted
/// and automatically releases it when unmounted.
class ScreenWakelockScope extends ConsumerStatefulWidget {
  final WakelockMode mode;
  final Widget child;

  const ScreenWakelockScope({
    super.key,
    required this.mode,
    required this.child,
  });

  @override
  ConsumerState<ScreenWakelockScope> createState() =>
      _ScreenWakelockScopeState();
}

class _ScreenWakelockScopeState extends ConsumerState<ScreenWakelockScope> {
  ScreenWakelockManager? _manager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _manager = ref.read(screenWakelockProvider.notifier);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _manager?.acquire(widget.mode);
      }
    });
  }

  @override
  void dispose() {
    final manager = _manager;
    final mode = widget.mode;
    scheduleMicrotask(() {
      manager?.release(mode);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Modular toggle setting tile for Settings screen.
///
/// Features a master keep-awake switch, status indicator, and expandable
/// fine-grained toggles for Fullscreen Player, Lyrics Mode, and Car Mode.
class ScreenWakelockTile extends ConsumerStatefulWidget {
  final bool showDetailedToggles;
  final bool isCard;
  final EdgeInsetsGeometry? padding;

  const ScreenWakelockTile({
    super.key,
    this.showDetailedToggles = true,
    this.isCard = false,
    this.padding,
  });

  @override
  ConsumerState<ScreenWakelockTile> createState() => _ScreenWakelockTileState();
}

class _ScreenWakelockTileState extends ConsumerState<ScreenWakelockTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final state = ref.watch(screenWakelockProvider);
    final notifier = ref.read(screenWakelockProvider.notifier);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          secondary: Icon(
            state.isLocked
                ? Icons.screen_lock_portrait_rounded
                : Icons.stay_current_portrait_rounded,
            color: state.isLocked ? tokens.accent : tokens.textSecondary,
          ),
          activeColor: tokens.accent,
          title: Text(
            'Keep Screen Awake',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            state.isMasterEnabled
                ? (state.isLocked
                    ? 'Screen kept awake (Active now)'
                    : 'Keeps screen on for Player, Lyrics & Car Mode')
                : 'Screen will turn off according to system timeout',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 13,
            ),
          ),
          value: state.isMasterEnabled,
          onChanged: (val) => notifier.setMasterEnabled(val),
        ),
        if (widget.showDetailedToggles && state.isMasterEnabled) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fine-tune active modes',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: tokens.textSecondary,
                    size: 20,
                  ),
                  tooltip: _isExpanded ? 'Hide modes' : 'Show modes',
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(color: Colors.black26, height: 1),
                _buildSubToggle(
                  context: context,
                  tokens: tokens,
                  title: 'Fullscreen Player',
                  subtitle: 'Keep screen awake while viewing full player',
                  icon: Icons.play_circle_outline_rounded,
                  value: state.keepAwakeFullscreen,
                  isActive:
                      state.activeModes.contains(WakelockMode.fullscreenPlayer),
                  onChanged: (val) => notifier.setFullscreenEnabled(val),
                ),
                const Divider(color: Colors.black26, height: 1),
                _buildSubToggle(
                  context: context,
                  tokens: tokens,
                  title: 'Lyrics Mode',
                  subtitle: 'Keep screen awake when synced lyrics are visible',
                  icon: Icons.music_note_rounded,
                  value: state.keepAwakeLyrics,
                  isActive: state.activeModes.contains(WakelockMode.lyricsMode),
                  onChanged: (val) => notifier.setLyricsEnabled(val),
                ),
                const Divider(color: Colors.black26, height: 1),
                _buildSubToggle(
                  context: context,
                  tokens: tokens,
                  title: 'Car Mode',
                  subtitle:
                      'Keep screen awake during driving & automotive display',
                  icon: Icons.directions_car_rounded,
                  value: state.keepAwakeCarMode,
                  isActive: state.activeModes.contains(WakelockMode.carMode),
                  onChanged: (val) => notifier.setCarModeEnabled(val),
                ),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ],
    );

    if (widget.isCard) {
      return AppSurface(
        withBlur: true,
        padding: widget.padding,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildSubToggle({
    required BuildContext context,
    required AppTokens tokens,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required bool isActive,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      secondary: Icon(
        icon,
        size: 20,
        color: isActive ? tokens.accent : tokens.textSecondary,
      ),
      activeColor: tokens.accent,
      title: Text(
        title,
        style: TextStyle(
          color: tokens.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        isActive ? '$subtitle (Currently active)' : subtitle,
        style: TextStyle(
          color:
              isActive ? tokens.accent.withValues(alpha: 0.8) : tokens.textSecondary,
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
