// ============================================================================
// Softify Quality of Life (QoL) Feature 45: Metered Network Bandwidth Throttler
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/audio_quality_preset.dart';
import '../../../presentation/providers/settings_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';

// ============================================================================
// Constants & SharedPreferences Keys
// ============================================================================

/// SharedPreferences persistent storage key for auto-throttling on metered connections.
const String kMeteredAutoThrottlePrefKey = 'softify_metered_auto_throttle';

/// SharedPreferences persistent storage key for prefetch suspension on metered connections.
const String kMeteredPrefetchSuspensionPrefKey = 'softify_metered_prefetch_suspend';

/// SharedPreferences persistent storage key for user manual bypass on metered connections.
const String kMeteredManualBypassPrefKey = 'softify_metered_manual_bypass';

/// SharedPreferences persistent storage key for saved user-preferred audio quality.
const String kMeteredSavedQualityPrefKey = 'softify_metered_saved_quality';

/// Bitrate target in kbps applied when auto-throttled to Low quality.
const int kMeteredLowBitrateKbps = 96;

// ============================================================================
// Persistence Contract & Self-Contained SharedPreferences Store
// ============================================================================

/// Storage contract for metered network guard preferences.
abstract class MeteredPrefsStorage {
  Future<bool?> getBool(String key);
  Future<bool> setBool(String key, bool value);
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<bool> remove(String key);
}

/// Disk-backed key-value store providing SharedPreferences persistence
/// without external native plugin compilation hazards.
class MeteredSharedPreferencesStore implements MeteredPrefsStorage {
  static final MeteredSharedPreferencesStore _instance =
      MeteredSharedPreferencesStore._internal();
  factory MeteredSharedPreferencesStore() => _instance;
  MeteredSharedPreferencesStore._internal();

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
      // In-memory fallback in headless / test environments
    } finally {
      _isLoaded = true;
    }
  }

  @override
  Future<bool?> getBool(String key) async {
    if (!_isLoaded) await init();
    final value = _memoryCache[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return null;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    return _flush();
  }

  @override
  Future<String?> getString(String key) async {
    if (!_isLoaded) await init();
    final value = _memoryCache[key];
    return value?.toString();
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    return _flush();
  }

  @override
  Future<bool> remove(String key) async {
    if (!_isLoaded) await init();
    _memoryCache.remove(key);
    return _flush();
  }

  Future<bool> _flush() async {
    try {
      if (_cacheFile != null) {
        if (!await _cacheFile!.parent.exists()) {
          await _cacheFile!.parent.create(recursive: true);
        }
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  void clearMemoryForTesting() {
    _memoryCache.clear();
    _isLoaded = true;
  }
}

// ============================================================================
// Network Connection Types & Metadata Models
// ============================================================================

/// Network connection taxonomy identifying metered vs unmetered interfaces.
enum MeteredConnectionType {
  /// Unmetered Wi-Fi network (typically unlimited broadband).
  unmeteredWifi,

  /// Metered Wi-Fi network (e.g. smartphone mobile hotspot / tethering).
  meteredWifi,

  /// Mobile broadband cellular network (3G, 4G, 5G, LTE, WWAN).
  cellular,

  /// Wired Ethernet connection (typically unmetered).
  ethernet,

  /// No active network interface or internet connectivity.
  offline,

  /// Connection state cannot be determined or is unsupported.
  unknown;

  /// True if this connection type is inherently or configured as metered.
  bool get isMetered =>
      this == MeteredConnectionType.meteredWifi ||
      this == MeteredConnectionType.cellular;

  /// Human-readable label for user interface representation.
  String get displayName {
    switch (this) {
      case MeteredConnectionType.unmeteredWifi:
        return 'Wi-Fi (Unmetered)';
      case MeteredConnectionType.meteredWifi:
        return 'Metered Wi-Fi / Hotspot';
      case MeteredConnectionType.cellular:
        return 'Cellular Mobile Data';
      case MeteredConnectionType.ethernet:
        return 'Wired Ethernet';
      case MeteredConnectionType.offline:
        return 'Offline (No Connection)';
      case MeteredConnectionType.unknown:
        return 'Unknown Network';
    }
  }

  /// Suggestive icon for network status badges and banners.
  IconData get icon {
    switch (this) {
      case MeteredConnectionType.unmeteredWifi:
        return Icons.wifi_rounded;
      case MeteredConnectionType.meteredWifi:
        return Icons.wifi_tethering_rounded;
      case MeteredConnectionType.cellular:
        return Icons.signal_cellular_alt_rounded;
      case MeteredConnectionType.ethernet:
        return Icons.settings_ethernet_rounded;
      case MeteredConnectionType.offline:
        return Icons.wifi_off_rounded;
      case MeteredConnectionType.unknown:
        return Icons.help_outline_rounded;
    }
  }
}

/// Immutable snapshot of detected network connection parameters.
@immutable
class MeteredNetworkInfo {
  final bool isMetered;
  final MeteredConnectionType connectionType;
  final String? networkName;
  final String? interfaceName;
  final int? estimatedKbps;
  final DateTime timestamp;

  const MeteredNetworkInfo({
    required this.isMetered,
    required this.connectionType,
    this.networkName,
    this.interfaceName,
    this.estimatedKbps,
    required this.timestamp,
  });

  /// Factory constructor for an unmetered baseline status.
  factory MeteredNetworkInfo.unmetered({
    MeteredConnectionType connectionType = MeteredConnectionType.unmeteredWifi,
    String? networkName,
    String? interfaceName,
  }) {
    return MeteredNetworkInfo(
      isMetered: false,
      connectionType: connectionType,
      networkName: networkName ?? 'Wi-Fi Network',
      interfaceName: interfaceName,
      estimatedKbps: 320,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for a metered status.
  factory MeteredNetworkInfo.metered({
    MeteredConnectionType connectionType = MeteredConnectionType.meteredWifi,
    String? networkName,
    String? interfaceName,
  }) {
    return MeteredNetworkInfo(
      isMetered: true,
      connectionType: connectionType,
      networkName: networkName ?? (connectionType == MeteredConnectionType.cellular ? 'Cellular Data' : 'Mobile Hotspot'),
      interfaceName: interfaceName,
      estimatedKbps: kMeteredLowBitrateKbps,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for offline status.
  factory MeteredNetworkInfo.offline() {
    return MeteredNetworkInfo(
      isMetered: false,
      connectionType: MeteredConnectionType.offline,
      networkName: 'Offline',
      interfaceName: null,
      estimatedKbps: 0,
      timestamp: DateTime.now(),
    );
  }

  MeteredNetworkInfo copyWith({
    bool? isMetered,
    MeteredConnectionType? connectionType,
    String? networkName,
    String? interfaceName,
    int? estimatedKbps,
    DateTime? timestamp,
  }) {
    return MeteredNetworkInfo(
      isMetered: isMetered ?? this.isMetered,
      connectionType: connectionType ?? this.connectionType,
      networkName: networkName ?? this.networkName,
      interfaceName: interfaceName ?? this.interfaceName,
      estimatedKbps: estimatedKbps ?? this.estimatedKbps,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeteredNetworkInfo &&
          runtimeType == other.runtimeType &&
          isMetered == other.isMetered &&
          connectionType == other.connectionType &&
          networkName == other.networkName &&
          interfaceName == other.interfaceName &&
          estimatedKbps == other.estimatedKbps;

  @override
  int get hashCode => Object.hash(
        isMetered,
        connectionType,
        networkName,
        interfaceName,
        estimatedKbps,
      );

  @override
  String toString() =>
      'MeteredNetworkInfo(isMetered: $isMetered, type: $connectionType, name: $networkName, iface: $interfaceName)';
}

// ============================================================================
// Network Detector Contracts & Platform Implementations
// ============================================================================

/// Contract for network connection monitoring and metered status detection.
abstract class MeteredNetworkDetector {
  /// Asynchronously queries current network connection parameters.
  Future<MeteredNetworkInfo> checkStatus();

  /// Stream emitting updates whenever the network state changes.
  Stream<MeteredNetworkInfo> get onStatusChanged;

  /// Releases monitoring timers and system resources.
  void dispose();
}

/// Linux desktop detector querying NetworkManager (`nmcli`) and sysfs interfaces.
class LinuxMeteredNetworkDetector implements MeteredNetworkDetector {
  final Duration pollInterval;
  Timer? _pollTimer;
  final StreamController<MeteredNetworkInfo> _controller =
      StreamController<MeteredNetworkInfo>.broadcast();

  MeteredNetworkInfo? _lastInfo;

  LinuxMeteredNetworkDetector({
    this.pollInterval = const Duration(seconds: 15),
  }) {
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) async {
      final info = await checkStatus();
      if (_lastInfo == null ||
          _lastInfo!.isMetered != info.isMetered ||
          _lastInfo!.connectionType != info.connectionType ||
          _lastInfo!.networkName != info.networkName) {
        _lastInfo = info;
        if (!_controller.isClosed) {
          _controller.add(info);
        }
      }
    });
  }

  @override
  Stream<MeteredNetworkInfo> get onStatusChanged => _controller.stream;

  @override
  Future<MeteredNetworkInfo> checkStatus() async {
    // 1. Primary check: Query NetworkManager via nmcli command
    final nmcliResult = await _checkNmcli();
    if (nmcliResult != null) {
      _lastInfo = nmcliResult;
      return nmcliResult;
    }

    // 2. Secondary fallback: Inspect Linux /sys/class/net interface hierarchy
    final sysfsResult = await _checkSysfsNet();
    if (sysfsResult != null) {
      _lastInfo = sysfsResult;
      return sysfsResult;
    }

    // 3. Default fallback
    final fallback = MeteredNetworkInfo(
      isMetered: false,
      connectionType: MeteredConnectionType.unknown,
      networkName: 'Standard Network',
      interfaceName: null,
      estimatedKbps: 320,
      timestamp: DateTime.now(),
    );
    _lastInfo = fallback;
    return fallback;
  }

  Future<MeteredNetworkInfo?> _checkNmcli() async {
    try {
      final result = await Process.run('nmcli', [
        '-t',
        '-f',
        'GENERAL.DEVICE,GENERAL.TYPE,GENERAL.METERED,GENERAL.CONNECTION',
        'dev',
        'show',
      ]).timeout(const Duration(milliseconds: 1800));

      if (result.exitCode == 0 && result.stdout != null) {
        return parseNmcliOutput(result.stdout.toString());
      }
    } catch (_) {
      // nmcli not present or timed out
    }
    return null;
  }

  /// Parses nmcli tabular device output into structured [MeteredNetworkInfo].
  @visibleForTesting
  static MeteredNetworkInfo? parseNmcliOutput(String output) {
    if (output.trim().isEmpty) return null;

    final blocks = output.split('\n\n');
    String? activeDevice;
    String? activeType;
    String? activeMetered;
    String? activeConnection;

    for (final rawBlock in blocks) {
      final block = rawBlock.trim();
      if (block.isEmpty) continue;

      final lines = block.split('\n');
      String? device;
      String? type;
      String? metered;
      String? connection;

      for (final line in lines) {
        final colonIdx = line.indexOf(':');
        if (colonIdx == -1) continue;
        final key = line.substring(0, colonIdx).trim();
        final value = line.substring(colonIdx + 1).trim();

        if (key == 'GENERAL.DEVICE') device = value;
        if (key == 'GENERAL.TYPE') type = value.toLowerCase();
        if (key == 'GENERAL.METERED') metered = value.toLowerCase();
        if (key == 'GENERAL.CONNECTION') connection = value;
      }

      // Ignore loopback and disconnected/unmanaged interfaces
      if (device == 'lo' || connection == '--' || connection == null || connection.isEmpty) {
        continue;
      }

      // Found an active primary connected interface
      activeDevice = device;
      activeType = type;
      activeMetered = metered;
      activeConnection = connection;
      break;
    }

    if (activeDevice == null) {
      return null;
    }

    final isMetered = activeMetered != null &&
        (activeMetered.startsWith('yes') || activeMetered == '1' || activeMetered == '3');

    final MeteredConnectionType connType;
    if (activeType == 'gsm' ||
        activeType == 'cdma' ||
        activeType == 'cellular' ||
        activeType == 'wwan') {
      connType = MeteredConnectionType.cellular;
    } else if (activeType == 'wifi' || activeType == '802-11-wireless') {
      connType = isMetered
          ? MeteredConnectionType.meteredWifi
          : MeteredConnectionType.unmeteredWifi;
    } else if (activeType == 'ethernet' || activeType == '802-3-ethernet') {
      connType = isMetered
          ? MeteredConnectionType.meteredWifi
          : MeteredConnectionType.ethernet;
    } else {
      connType = isMetered
          ? MeteredConnectionType.meteredWifi
          : MeteredConnectionType.unknown;
    }

    return MeteredNetworkInfo(
      isMetered: isMetered || connType == MeteredConnectionType.cellular,
      connectionType: connType,
      networkName: activeConnection,
      interfaceName: activeDevice,
      estimatedKbps: (isMetered || connType == MeteredConnectionType.cellular)
          ? kMeteredLowBitrateKbps
          : 320,
      timestamp: DateTime.now(),
    );
  }

  Future<MeteredNetworkInfo?> _checkSysfsNet() async {
    try {
      final netDir = Directory('/sys/class/net');
      if (!await netDir.exists()) return null;

      final entries = await netDir.list().toList();
      for (final entry in entries) {
        final ifName = p.basename(entry.path);
        if (ifName == 'lo') continue;

        final operstateFile = File(p.join(entry.path, 'operstate'));
        if (await operstateFile.exists()) {
          final state = (await operstateFile.readAsString()).trim().toLowerCase();
          if (state == 'up') {
            if (ifName.startsWith('wwan') ||
                ifName.startsWith('ppp') ||
                ifName.startsWith('cdc-wdm')) {
              return MeteredNetworkInfo(
                isMetered: true,
                connectionType: MeteredConnectionType.cellular,
                interfaceName: ifName,
                networkName: 'Cellular Interface ($ifName)',
                estimatedKbps: kMeteredLowBitrateKbps,
                timestamp: DateTime.now(),
              );
            }
            if (ifName.startsWith('wl')) {
              return MeteredNetworkInfo(
                isMetered: false,
                connectionType: MeteredConnectionType.unmeteredWifi,
                interfaceName: ifName,
                networkName: 'Wi-Fi Interface ($ifName)',
                estimatedKbps: 320,
                timestamp: DateTime.now(),
              );
            }
            if (ifName.startsWith('en') || ifName.startsWith('eth')) {
              return MeteredNetworkInfo(
                isMetered: false,
                connectionType: MeteredConnectionType.ethernet,
                interfaceName: ifName,
                networkName: 'Ethernet ($ifName)',
                estimatedKbps: 320,
                timestamp: DateTime.now(),
              );
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.close();
  }
}

/// In-memory mockable detector for unit testing and interactive debugging.
class MockMeteredNetworkDetector implements MeteredNetworkDetector {
  MeteredNetworkInfo _currentInfo;
  final StreamController<MeteredNetworkInfo> _controller =
      StreamController<MeteredNetworkInfo>.broadcast();

  MockMeteredNetworkDetector({MeteredNetworkInfo? initialInfo})
      : _currentInfo = initialInfo ?? MeteredNetworkInfo.unmetered();

  @override
  Future<MeteredNetworkInfo> checkStatus() async => _currentInfo;

  @override
  Stream<MeteredNetworkInfo> get onStatusChanged => _controller.stream;

  /// Simulates a network transition and broadcasts the event to listeners.
  void setNetworkInfo(MeteredNetworkInfo info) {
    _currentInfo = info;
    if (!_controller.isClosed) {
      _controller.add(info);
    }
  }

  @override
  void dispose() {
    _controller.close();
  }
}

// ============================================================================
// Metered Guard State Model
// ============================================================================

/// Immutable state capturing network metering status and bandwidth throttling.
@immutable
class MeteredGuardState {
  /// Raw detected network parameters.
  final MeteredNetworkInfo networkInfo;

  /// User preference: automatically drop streaming quality to Low (96kbps) when metered.
  final bool autoThrottleEnabled;

  /// User preference: suspend speculative background prefetching when metered.
  final bool prefetchSuspensionEnabled;

  /// User manual override: force unthrottled streaming on the current metered network.
  final bool isManualBypass;

  /// Whether the user dismissed the metered connection notification banner for this session.
  final bool isBannerDismissed;

  /// Saved user quality preference to restore once the connection returns to unmetered.
  final AudioQualityPreset? savedPreviousQuality;

  const MeteredGuardState({
    required this.networkInfo,
    this.autoThrottleEnabled = true,
    this.prefetchSuspensionEnabled = true,
    this.isManualBypass = false,
    this.isBannerDismissed = false,
    this.savedPreviousQuality,
  });

  /// True if current network is metered.
  bool get isMetered => networkInfo.isMetered;

  /// True if stream quality is currently being throttled to Low (96kbps).
  bool get isThrottled => isMetered && autoThrottleEnabled && !isManualBypass;

  /// True if speculative background prefetching is currently suspended.
  bool get isPrefetchSuspended =>
      isMetered && prefetchSuspensionEnabled && !isManualBypass;

  /// Effective active audio quality preset accounting for metering and manual overrides.
  AudioQualityPreset get effectiveQualityPreset =>
      isThrottled ? AudioQualityPreset.low : (savedPreviousQuality ?? AudioQualityPreset.standard);

  /// Target stream bitrate in kbps for display badges and network statistics.
  int get streamBitrateKbps {
    if (isThrottled) return kMeteredLowBitrateKbps;
    switch (effectiveQualityPreset) {
      case AudioQualityPreset.low:
        return kMeteredLowBitrateKbps;
      case AudioQualityPreset.high:
        return 320;
      case AudioQualityPreset.standard:
        return 160;
    }
  }

  /// True if the warning banner should be rendered to the user.
  bool get shouldShowBanner => isMetered && !isBannerDismissed;

  MeteredGuardState copyWith({
    MeteredNetworkInfo? networkInfo,
    bool? autoThrottleEnabled,
    bool? prefetchSuspensionEnabled,
    bool? isManualBypass,
    bool? isBannerDismissed,
    AudioQualityPreset? savedPreviousQuality,
    bool clearSavedQuality = false,
  }) {
    return MeteredGuardState(
      networkInfo: networkInfo ?? this.networkInfo,
      autoThrottleEnabled: autoThrottleEnabled ?? this.autoThrottleEnabled,
      prefetchSuspensionEnabled:
          prefetchSuspensionEnabled ?? this.prefetchSuspensionEnabled,
      isManualBypass: isManualBypass ?? this.isManualBypass,
      isBannerDismissed: isBannerDismissed ?? this.isBannerDismissed,
      savedPreviousQuality: clearSavedQuality
          ? null
          : (savedPreviousQuality ?? this.savedPreviousQuality),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeteredGuardState &&
          runtimeType == other.runtimeType &&
          networkInfo == other.networkInfo &&
          autoThrottleEnabled == other.autoThrottleEnabled &&
          prefetchSuspensionEnabled == other.prefetchSuspensionEnabled &&
          isManualBypass == other.isManualBypass &&
          isBannerDismissed == other.isBannerDismissed &&
          savedPreviousQuality == other.savedPreviousQuality;

  @override
  int get hashCode => Object.hash(
        networkInfo,
        autoThrottleEnabled,
        prefetchSuspensionEnabled,
        isManualBypass,
        isBannerDismissed,
        savedPreviousQuality,
      );

  @override
  String toString() =>
      'MeteredGuardState(isMetered: $isMetered, isThrottled: $isThrottled, isPrefetchSuspended: $isPrefetchSuspended, quality: $effectiveQualityPreset)';
}

// ============================================================================
// Synchronous Accessor & Global Static Mirror
// ============================================================================

/// Global synchronous mirror providing low-latency lookups for the audio engine,
/// background downloaders, and stream resolvers without requiring Riverpod context.
class MeteredConnectionGuard {
  const MeteredConnectionGuard._();

  static bool _isMetered = false;
  static bool _isThrottled = false;
  static bool _isPrefetchSuspended = false;
  static AudioQualityPreset _effectiveQuality = AudioQualityPreset.standard;
  static MeteredConnectionType _connectionType = MeteredConnectionType.unmeteredWifi;

  /// Synchronous boolean flag indicating if the active connection is metered.
  static bool get isMetered => _isMetered;

  /// Synchronous boolean flag indicating if bandwidth throttling is actively enforced.
  static bool get isThrottled => _isThrottled;

  /// Synchronous boolean flag indicating if background speculative prefetch is suspended.
  static bool get isPrefetchSuspended => _isPrefetchSuspended;

  /// Synchronously resolved audio stream quality preset.
  static AudioQualityPreset get effectiveQualityPreset => _effectiveQuality;

  /// Active connection type.
  static MeteredConnectionType get currentConnectionType => _connectionType;

  /// Custom persistence storage backend for dependency injection and tests.
  static MeteredPrefsStorage? customStorage;

  /// Custom network detector for dependency injection and tests.
  static MeteredNetworkDetector? customDetector;

  /// Resets global static variables for testing isolation.
  @visibleForTesting
  static void resetForTesting() {
    _isMetered = false;
    _isThrottled = false;
    _isPrefetchSuspended = false;
    _effectiveQuality = AudioQualityPreset.standard;
    _connectionType = MeteredConnectionType.unmeteredWifi;
    customStorage = null;
    customDetector = null;
  }

  static void _syncFromState(MeteredGuardState state) {
    _isMetered = state.isMetered;
    _isThrottled = state.isThrottled;
    _isPrefetchSuspended = state.isPrefetchSuspended;
    _effectiveQuality = state.effectiveQualityPreset;
    _connectionType = state.networkInfo.connectionType;
  }
}

// ============================================================================
// Riverpod StateNotifier
// ============================================================================

/// Riverpod StateNotifier managing network monitoring, bandwidth throttling,
/// quality adjustments, and background prefetch suspension.
class MeteredConnectionGuardNotifier extends StateNotifier<MeteredGuardState> {
  final Ref? _ref;
  final MeteredPrefsStorage _storage;
  final MeteredNetworkDetector _detector;
  StreamSubscription<MeteredNetworkInfo>? _detectorSubscription;

  MeteredConnectionGuardNotifier([
    this._ref,
    MeteredNetworkDetector? detector,
    MeteredPrefsStorage? storage,
  ])  : _storage = storage ?? MeteredConnectionGuard.customStorage ?? MeteredSharedPreferencesStore(),
        _detector = detector ?? MeteredConnectionGuard.customDetector ?? LinuxMeteredNetworkDetector(),
        super(MeteredGuardState(networkInfo: MeteredNetworkInfo.unmetered())) {
    _init();
  }

  Future<void> _init() async {
    // 1. Load persisted preferences
    await _loadPersistedPreferences();

    // 2. Initial network check
    try {
      final info = await _detector.checkStatus();
      _handleNetworkUpdate(info);
    } catch (_) {
      // Fallback to unmetered baseline
    }

    // 3. Listen to network change stream
    _detectorSubscription = _detector.onStatusChanged.listen((info) {
      _handleNetworkUpdate(info);
    });
  }

  Future<void> _loadPersistedPreferences() async {
    try {
      final autoThrottle = await _storage.getBool(kMeteredAutoThrottlePrefKey);
      final prefetchSuspend =
          await _storage.getBool(kMeteredPrefetchSuspensionPrefKey);
      final manualBypass = await _storage.getBool(kMeteredManualBypassPrefKey);
      final savedQualityStr =
          await _storage.getString(kMeteredSavedQualityPrefKey);

      AudioQualityPreset? savedQuality;
      if (savedQualityStr != null) {
        if (savedQualityStr == AudioQualityPreset.high.name) {
          savedQuality = AudioQualityPreset.high;
        } else if (savedQualityStr == AudioQualityPreset.standard.name) {
          savedQuality = AudioQualityPreset.standard;
        } else if (savedQualityStr == AudioQualityPreset.low.name) {
          savedQuality = AudioQualityPreset.low;
        }
      }

      final updated = state.copyWith(
        autoThrottleEnabled: autoThrottle ?? state.autoThrottleEnabled,
        prefetchSuspensionEnabled:
            prefetchSuspend ?? state.prefetchSuspensionEnabled,
        isManualBypass: manualBypass ?? state.isManualBypass,
        savedPreviousQuality: savedQuality ?? state.savedPreviousQuality,
      );

      _applyStateChange(updated);
    } catch (_) {}
  }

  void _handleNetworkUpdate(MeteredNetworkInfo info) {
    if (!mounted) return;

    final wasMetered = state.isMetered;
    final isNowMetered = info.isMetered;

    AudioQualityPreset? preservedQuality = state.savedPreviousQuality;

    // Transitioning from unmetered -> metered: capture user's active quality preference
    if (!wasMetered && isNowMetered) {
      preservedQuality = _resolveCurrentActiveQuality();
      if (preservedQuality != null) {
        _storage.setString(kMeteredSavedQualityPrefKey, preservedQuality.name);
      }
    }

    // When connection type or metered state changes, un-dismiss the banner so user is notified
    final resetBanner = wasMetered != isNowMetered;

    final updated = state.copyWith(
      networkInfo: info,
      savedPreviousQuality: preservedQuality,
      isBannerDismissed: resetBanner ? false : state.isBannerDismissed,
      // Reset temporary bypass if network switches to a different interface
      isManualBypass: resetBanner ? false : state.isManualBypass,
    );

    _applyStateChange(updated);
  }

  AudioQualityPreset? _resolveCurrentActiveQuality() {
    final ref = _ref;
    if (ref != null) {
      try {
        return ref.read(audioQualityPresetProvider);
      } catch (_) {}
    }
    return state.savedPreviousQuality ?? AudioQualityPreset.standard;
  }

  void _applyStateChange(MeteredGuardState nextState) {
    final previousState = state;
    state = nextState;
    MeteredConnectionGuard._syncFromState(nextState);

    // Coordinate with system audio quality provider
    if (_ref != null) {
      if (nextState.isThrottled && !previousState.isThrottled) {
        // Enforce Low (96kbps) audio quality
        _syncAudioQuality(AudioQualityPreset.low);
      } else if (!nextState.isThrottled && previousState.isThrottled) {
        // Restore user's preferred quality
        final restoreTo =
            nextState.savedPreviousQuality ?? AudioQualityPreset.standard;
        _syncAudioQuality(restoreTo);
      }
    }
  }

  void _syncAudioQuality(AudioQualityPreset preset) {
    final ref = _ref;
    if (ref == null) return;
    try {
      ref.read(audioQualityPresetProvider.notifier).setQuality(preset);
    } catch (_) {
      // In standalone tests or when databaseProvider is mock-isolated
    }
  }

  /// Forces an on-demand refresh of network connection status.
  Future<void> refreshNetworkStatus() async {
    try {
      final info = await _detector.checkStatus();
      _handleNetworkUpdate(info);
    } catch (_) {}
  }

  /// Configures whether automatic stream quality throttling is enabled.
  Future<void> setAutoThrottleEnabled(bool enabled) async {
    if (state.autoThrottleEnabled == enabled) return;
    final updated = state.copyWith(autoThrottleEnabled: enabled);
    await _storage.setBool(kMeteredAutoThrottlePrefKey, enabled);
    _applyStateChange(updated);
  }

  /// Configures whether background prefetch suspension is enabled.
  Future<void> setPrefetchSuspensionEnabled(bool enabled) async {
    if (state.prefetchSuspensionEnabled == enabled) return;
    final updated = state.copyWith(prefetchSuspensionEnabled: enabled);
    await _storage.setBool(kMeteredPrefetchSuspensionPrefKey, enabled);
    _applyStateChange(updated);
  }

  /// Toggles manual bypass, allowing full-fidelity streaming on metered networks.
  Future<void> setManualBypass(bool bypass) async {
    if (state.isManualBypass == bypass) return;
    final updated = state.copyWith(isManualBypass: bypass);
    await _storage.setBool(kMeteredManualBypassPrefKey, bypass);
    _applyStateChange(updated);
  }

  /// Dismisses the notification banner for the active network session.
  void dismissBanner() {
    if (state.isBannerDismissed) return;
    state = state.copyWith(isBannerDismissed: true);
  }

  /// Re-enables the visibility of the notification banner.
  void showBanner() {
    if (!state.isBannerDismissed) return;
    state = state.copyWith(isBannerDismissed: false);
  }

  /// Injects simulated network parameters for testing or manual Data Saver mode.
  void simulateConnection(MeteredNetworkInfo info) {
    _handleNetworkUpdate(info);
  }

  /// Convenience toggle for Data Saver mode (simulating or overriding metered status).
  Future<void> toggleManualDataSaver() async {
    if (state.isMetered) {
      await setManualBypass(!state.isManualBypass);
    } else {
      // User requested Data Saver on unmetered network: simulate metered Wi-Fi
      simulateConnection(MeteredNetworkInfo.metered(
        networkName: 'Manual Data Saver Mode',
      ));
    }
  }

  @override
  void dispose() {
    _detectorSubscription?.cancel();
    _detector.dispose();
    super.dispose();
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Global StateNotifierProvider managing metered connection guard state.
final meteredConnectionGuardProvider =
    StateNotifierProvider<MeteredConnectionGuardNotifier, MeteredGuardState>((ref) {
  return MeteredConnectionGuardNotifier(ref);
});

/// Reactive boolean provider indicating whether the active connection is metered.
final isMeteredConnectionProvider = Provider<bool>((ref) {
  return ref.watch(meteredConnectionGuardProvider).isMetered;
});

/// Reactive boolean provider indicating whether bandwidth throttling is currently active.
final isBandwidthThrottledProvider = Provider<bool>((ref) {
  return ref.watch(meteredConnectionGuardProvider).isThrottled;
});

/// Reactive boolean provider indicating whether speculative background prefetching is suspended.
final isBackgroundPrefetchSuspendedProvider = Provider<bool>((ref) {
  return ref.watch(meteredConnectionGuardProvider).isPrefetchSuspended;
});

/// Reactive provider emitting the detected network connection type.
final meteredConnectionTypeProvider = Provider<MeteredConnectionType>((ref) {
  return ref.watch(meteredConnectionGuardProvider).networkInfo.connectionType;
});

/// Reactive provider emitting complete network metadata info.
final meteredNetworkInfoProvider = Provider<MeteredNetworkInfo>((ref) {
  return ref.watch(meteredConnectionGuardProvider).networkInfo;
});

/// Reactive provider resolving the active effective audio quality preset.
final meteredEffectiveQualityProvider = Provider<AudioQualityPreset>((ref) {
  return ref.watch(meteredConnectionGuardProvider).effectiveQualityPreset;
});

// ============================================================================
// MeteredConnectionBanner Widget (Material 3)
// ============================================================================

/// Material 3 notification banner alerting the user when connected to a metered
/// network and bandwidth throttling (96kbps Low quality & prefetch pause) is engaged.
class MeteredConnectionBanner extends ConsumerWidget {
  /// If true, the banner renders regardless of network state (useful for previews & settings).
  final bool forceVisible;

  /// External margins surrounding the banner card.
  final EdgeInsetsGeometry margin;

  /// Inner padding inside the banner card.
  final EdgeInsetsGeometry padding;

  /// Optional callback invoked when the user dismisses the banner.
  final VoidCallback? onDismiss;

  /// Optional callback invoked when user taps the banner to open quality settings.
  final VoidCallback? onSettingsTap;

  /// If true, renders a compact, slender pill style suited for headers or mini-players.
  final bool compact;

  const MeteredConnectionBanner({
    super.key,
    this.forceVisible = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    this.onDismiss,
    this.onSettingsTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meteredConnectionGuardProvider);
    final notifier = ref.read(meteredConnectionGuardProvider.notifier);
    final tokens = context.tokens;

    final shouldShow = forceVisible || state.shouldShowBanner;
    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return _buildCompactPill(context, ref, state, notifier, tokens);
    }
    return _buildFullBanner(context, ref, state, notifier, tokens);
  }

  Widget _buildCompactPill(
    BuildContext context,
    WidgetRef ref,
    MeteredGuardState state,
    MeteredConnectionGuardNotifier notifier,
    AppTokens tokens,
  ) {
    final isThrottled = state.isThrottled;
    final accent = isThrottled ? const Color(0xFFFFB020) : tokens.accentCyan;

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          onTap: onSettingsTap ?? () => notifier.setManualBypass(!state.isManualBypass),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.networkInfo.connectionType.icon,
                  size: 14.0,
                  color: accent,
                ),
                const SizedBox(width: 6.0),
                Text(
                  isThrottled ? 'Data Saver Active (96 kbps)' : 'Metered Network (Override)',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8.0),
                GestureDetector(
                  onTap: () {
                    notifier.dismissBanner();
                    onDismiss?.call();
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 14.0,
                    color: accent.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullBanner(
    BuildContext context,
    WidgetRef ref,
    MeteredGuardState state,
    MeteredConnectionGuardNotifier notifier,
    AppTokens tokens,
  ) {
    final isThrottled = state.isThrottled;
    const warningColor = Color(0xFFF59E0B);
    final accentColor = isThrottled ? warningColor : tokens.accentCyan;

    final connectionLabel = state.networkInfo.networkName ??
        state.networkInfo.connectionType.displayName;

    final titleText = isThrottled
        ? 'Metered Connection Detected'
        : 'Data Saver Overridden';

    final bodyText = isThrottled
        ? 'Stream quality set to Low (96 kbps) & background prefetching suspended to preserve bandwidth ($connectionLabel).'
        : 'Streaming at full fidelity on metered connection ($connectionLabel). Background prefetch enabled.';

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10.0,
            offset: const Offset(0.0, 3.0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: 0.12),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7.0),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    child: Icon(
                      state.networkInfo.connectionType.icon,
                      size: 18.0,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              titleText,
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(tokens.radiusSm),
                              ),
                              child: Text(
                                isThrottled ? '96 kbps' : 'Bypassed',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontUi,
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18.0,
                      color: tokens.textMuted,
                    ),
                    splashRadius: 18.0,
                    tooltip: 'Dismiss',
                    onPressed: () {
                      notifier.dismissBanner();
                      onDismiss?.call();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8.0),

              // Description body text
              Text(
                bodyText,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12.0,
                  height: 1.35,
                  color: tokens.textSecondary,
                ),
              ),

              const SizedBox(height: 12.0),

              // Interactive action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onSettingsTap != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 6.0,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onSettingsTap,
                      child: Text(
                        'Quality Settings',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8.0),
                  BouncingScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      notifier.setManualBypass(!state.isManualBypass);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isThrottled
                                ? Icons.speed_rounded
                                : Icons.savings_rounded,
                            size: 14.0,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 5.0),
                          Text(
                            isThrottled ? 'Keep High Quality' : 'Save Bandwidth',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Settings Tile Component
// ============================================================================

/// Clean settings tile for configuring metered bandwidth throttler behavior.
class MeteredConnectionSettingsTile extends ConsumerWidget {
  const MeteredConnectionSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meteredConnectionGuardProvider);
    final notifier = ref.read(meteredConnectionGuardProvider.notifier);
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
                child: Icon(
                  Icons.signal_cellular_alt_rounded,
                  color: tokens.accent,
                  size: 20.0,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Metered Bandwidth Throttler',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      state.isMetered
                          ? 'Active (${state.networkInfo.connectionType.displayName})'
                          : 'Monitoring network interfaces',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12.0,
                        color: state.isMetered ? const Color(0xFFFFB020) : tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: state.autoThrottleEnabled,
                onChanged: (val) => notifier.setAutoThrottleEnabled(val),
                activeThumbColor: tokens.accent,
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Divider(color: tokens.divider, height: 1.0),
          const SizedBox(height: 12.0),
          // Sub-toggles
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Suspend background prefetching on metered networks',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12.5,
                color: tokens.textSecondary,
              ),
            ),
            subtitle: Text(
              'Prevents speculative lookahead buffering to reduce mobile data usage.',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 11.0,
                color: tokens.textMuted,
              ),
            ),
            value: state.prefetchSuspensionEnabled,
            onChanged: (val) =>
                notifier.setPrefetchSuspensionEnabled(val ?? true),
            activeColor: tokens.accent,
          ),
        ],
      ),
    );
  }
}
