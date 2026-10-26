import 'dart:async';
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
  final AppNotice? pendingNotice;

  const DeviceControlState({
    this.isBlocked = false,
    this.blockReason,
    this.deviceId = '',
    this.serverUrl = DeviceControlService.defaultServerUrl,
    this.isChecking = false,
    this.isOffline = false,
    this.bannerMessage,
    this.pendingNotice,
  });

  DeviceControlState copyWith({
    bool? isBlocked,
    String? blockReason,
    String? deviceId,
    String? serverUrl,
    bool? isChecking,
    bool? isOffline,
    String? bannerMessage,
    AppNotice? pendingNotice,
    bool clearPendingNotice = false,
  }) {
    return DeviceControlState(
      isBlocked: isBlocked ?? this.isBlocked,
      blockReason: blockReason ?? this.blockReason,
      deviceId: deviceId ?? this.deviceId,
      serverUrl: serverUrl ?? this.serverUrl,
      isChecking: isChecking ?? this.isChecking,
      isOffline: isOffline ?? this.isOffline,
      bannerMessage: bannerMessage ?? this.bannerMessage,
      pendingNotice: clearPendingNotice ? null : (pendingNotice ?? this.pendingNotice),
    );
  }
}

class DeviceControlNotifier extends StateNotifier<DeviceControlState> {
  final DeviceControlService _service;
  final Ref _ref;
  Timer? _heartbeatTimer;

  DeviceControlNotifier(this._service, this._ref) : super(const DeviceControlState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final id = await _service.getDeviceId();
    final url = await _service.getServerUrl();
    state = state.copyWith(deviceId: id, serverUrl: url);
    await checkStatus();

    // Automatically sync heartbeat in the background every 60 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      checkStatus();
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> checkStatus({String? overrideUrl}) async {
    state = state.copyWith(isChecking: true);
    final status = await _service.syncDevice(overrideUrl: overrideUrl);

    final isBlocked = !status.isAllowed;
    final lastDismissedId = await _service.getLastDismissedNoticeId();

    AppNotice? pendingNotice;
    if (status.notice != null &&
        status.notice!.id.isNotEmpty &&
        status.notice!.id != lastDismissedId &&
        status.notice!.message.trim().isNotEmpty) {
      pendingNotice = status.notice;
    }

    state = state.copyWith(
      isBlocked: isBlocked,
      blockReason: status.reason,
      isChecking: false,
      isOffline: status.isOffline,
      bannerMessage: status.banner,
      pendingNotice: pendingNotice,
    );

    // If blocked, immediately stop any running audio
    if (isBlocked) {
      try {
        final audioHandler = _ref.read(audioHandlerProvider);
        await audioHandler.stop();
      } catch (_) {}
    }
  }

  Future<void> dismissPendingNotice() async {
    final notice = state.pendingNotice;
    if (notice != null) {
      await _service.setLastDismissedNoticeId(notice.id);
      state = state.copyWith(clearPendingNotice: true);
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
