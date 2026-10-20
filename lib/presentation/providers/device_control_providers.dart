import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/device_control_service.dart';
import 'player_providers.dart';

class DeviceControlState {
  final bool isBlocked;
  final String? blockReason;
  final String deviceId;
  final String serverUrl;
  final bool isChecking;
  final bool isOffline;
  final String? bannerMessage;

  const DeviceControlState({
    this.isBlocked = false,
    this.blockReason,
    this.deviceId = '',
    this.serverUrl = DeviceControlService.defaultServerUrl,
    this.isChecking = false,
    this.isOffline = false,
    this.bannerMessage,
  });

  DeviceControlState copyWith({
    bool? isBlocked,
    String? blockReason,
    String? deviceId,
    String? serverUrl,
    bool? isChecking,
    bool? isOffline,
    String? bannerMessage,
  }) {
    return DeviceControlState(
      isBlocked: isBlocked ?? this.isBlocked,
      blockReason: blockReason ?? this.blockReason,
      deviceId: deviceId ?? this.deviceId,
      serverUrl: serverUrl ?? this.serverUrl,
      isChecking: isChecking ?? this.isChecking,
      isOffline: isOffline ?? this.isOffline,
      bannerMessage: bannerMessage ?? this.bannerMessage,
    );
  }
}

class DeviceControlNotifier extends StateNotifier<DeviceControlState> {
  final DeviceControlService _service;
  final Ref _ref;

  DeviceControlNotifier(this._service, this._ref) : super(const DeviceControlState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final id = await _service.getDeviceId();
    final url = await _service.getServerUrl();
    state = state.copyWith(deviceId: id, serverUrl: url);
    await checkStatus();
  }

  Future<void> checkStatus({String? overrideUrl}) async {
    state = state.copyWith(isChecking: true);
    final status = await _service.syncDevice(overrideUrl: overrideUrl);

    final isBlocked = !status.isAllowed;
    state = state.copyWith(
      isBlocked: isBlocked,
      blockReason: status.reason,
      isChecking: false,
      isOffline: status.isOffline,
      bannerMessage: status.banner,
    );

    // If blocked, immediately stop any running audio
    if (isBlocked) {
      try {
        final audioHandler = _ref.read(audioHandlerProvider);
        await audioHandler.stop();
      } catch (_) {}
    }
  }

  Future<void> updateServerUrl(String newUrl) async {
    await _service.setServerUrl(newUrl);
    final url = await _service.getServerUrl();
    state = state.copyWith(serverUrl: url);
    await checkStatus();
  }
}

final deviceControlServiceProvider = Provider<DeviceControlService>((ref) {
  final db = ref.watch(databaseProvider);
  return DeviceControlService(db: db);
});

final deviceControlProvider =
    StateNotifierProvider<DeviceControlNotifier, DeviceControlState>((ref) {
  final service = ref.watch(deviceControlServiceProvider);
  return DeviceControlNotifier(service, ref);
});
