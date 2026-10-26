import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../../presentation/providers/settings_providers.dart';
import '../database/app_database.dart';

class AppNotice {
  final String id;
  final String title;
  final String message;
  final String type; // 'info' | 'announcement' | 'warning'
  final DateTime? createdAt;

  const AppNotice({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'info',
    this.createdAt,
  });

  factory AppNotice.fromJson(Map<String, dynamic> json) {
    return AppNotice(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Notice',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'info',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

class DeviceControlStatus {
  final bool isAllowed;
  final String status;
  final String? reason;
  final String? banner;
  final AppNotice? notice;
  final bool isOffline;

  const DeviceControlStatus({
    required this.isAllowed,
    required this.status,
    this.reason,
    this.banner,
    this.notice,
    this.isOffline = false,
  });
}

class DeviceControlService {
  final AppDatabase _db;
  final http.Client _client;

  static const String _keyDeviceId = 'device_control_id';
  static const String _keyServerUrl = 'device_control_server_url';
  static const String _keyLastStatus = 'device_control_last_status';
  static const String _keyLastReason = 'device_control_last_reason';
  static const String _keyLastDismissedNoticeId = 'device_control_last_dismissed_notice_id';

  // Default server URL - deployed live fleet command center
  static const String defaultServerUrl = 'https://server-eight-gamma-81.vercel.app';

  DeviceControlService({
    required AppDatabase db,
    http.Client? client,
  })  : _db = db,
        _client = client ?? http.Client();

  /// Retrieves or generates a persistent, unique Device UUID.
  Future<String> getDeviceId() async {
    final row = await (_db.select(_db.settings)
          ..where((tbl) => tbl.key.equals(_keyDeviceId)))
        .getSingleOrNull();

    if (row != null && row.value.trim().isNotEmpty) {
      return row.value.trim();
    }

    final newId = _generateUuidV4();
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: _keyDeviceId,
            value: newId,
          ),
        );
    return newId;
  }

  /// Retrieves the currently configured backend server URL.
  Future<String> getServerUrl() async {
    final row = await (_db.select(_db.settings)
          ..where((tbl) => tbl.key.equals(_keyServerUrl)))
        .getSingleOrNull();

    if (row != null && row.value.trim().isNotEmpty) {
      final val = row.value.trim();
      if (val != 'http://localhost:3000' && val != 'http://127.0.0.1:3000') {
        return val;
      }
    }
    return defaultServerUrl;
  }

  /// Saves a custom backend server URL.
  Future<void> setServerUrl(String url) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: _keyServerUrl,
            value: cleanUrl,
          ),
        );
  }

  /// Gets the ID of the last notice dismissed by the user.
  Future<String?> getLastDismissedNoticeId() async {
    final row = await (_db.select(_db.settings)
          ..where((tbl) => tbl.key.equals(_keyLastDismissedNoticeId)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Persists notice dismissal so the banner isn't repeatedly shown.
  Future<void> setLastDismissedNoticeId(String noticeId) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: _keyLastDismissedNoticeId,
            value: noticeId,
          ),
        );
  }

  /// Gathers system metadata for device registry, resolving genuine hardware model.
  Future<Map<String, String>> _collectDeviceInfo() async {
    final platform = Platform.operatingSystem;
    var osVersion = Platform.operatingSystemVersion;
    var model = '';
    const appVersion = kAppVersion;

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        final brand = android.brand.trim();
        final rawModel = android.model.trim();
        final cleanBrand = brand.isNotEmpty
            ? '${brand[0].toUpperCase()}${brand.substring(1)}'
            : '';
        if (cleanBrand.isNotEmpty &&
            !rawModel.toLowerCase().startsWith(cleanBrand.toLowerCase())) {
          model = '$cleanBrand $rawModel';
        } else {
          model = rawModel.isNotEmpty ? rawModel : 'Android Device';
        }
        osVersion = 'Android ${android.version.release} (SDK ${android.version.sdkInt})';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        model = ios.utsname.machine.isNotEmpty ? ios.utsname.machine : ios.name;
        osVersion = '${ios.systemName} ${ios.systemVersion}';
      } else if (Platform.isLinux) {
        final linux = await deviceInfo.linuxInfo;
        model = linux.prettyName.isNotEmpty
            ? linux.prettyName
            : (Platform.localHostname.isNotEmpty ? Platform.localHostname : 'Linux Desktop');
        osVersion = linux.versionId ?? Platform.operatingSystemVersion;
      } else if (Platform.isWindows) {
        final win = await deviceInfo.windowsInfo;
        model = win.productName.isNotEmpty ? win.productName : 'Windows PC';
        osVersion = 'Windows ${win.buildNumber}';
      } else if (Platform.isMacOS) {
        final mac = await deviceInfo.macOsInfo;
        model = mac.model.isNotEmpty ? mac.model : 'Apple Mac';
        osVersion = 'macOS ${mac.osRelease}';
      }
    } catch (_) {
      // Fallback
    }

    if (model.isEmpty || model.toLowerCase() == 'localhost') {
      if (Platform.isAndroid) {
        model = 'Android Device';
      } else if (Platform.isLinux) {
        model = Platform.localHostname != 'localhost' ? Platform.localHostname : 'Linux Desktop';
      } else {
        model = Platform.localHostname;
      }
    }

    return {
      'platform': platform,
      'osVersion': osVersion,
      'deviceModel': model,
      'appVersion': appVersion,
    };
  }

  /// Synchronizes device state with the backend server.
  /// Falls back to local cached status if network/server is unavailable.
  Future<DeviceControlStatus> syncDevice({String? overrideUrl}) async {
    final deviceId = await getDeviceId();
    final serverUrl = overrideUrl ?? await getServerUrl();
    final info = await _collectDeviceInfo();

    try {
      final uri = Uri.parse('$serverUrl/api/device/sync');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'deviceId': deviceId,
              'platform': info['platform'],
              'osVersion': info['osVersion'],
              'deviceModel': info['deviceModel'],
              'appVersion': info['appVersion'],
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isAllowed = data['allowed'] == true;
        final status = (data['status'] as String?) ?? (isAllowed ? 'allowed' : 'blocked');
        final reason = data['reason'] as String?;
        final banner = data['banner'] as String?;

        AppNotice? notice;
        if (data['notice'] != null && data['notice'] is Map<String, dynamic>) {
          notice = AppNotice.fromJson(data['notice'] as Map<String, dynamic>);
        } else if (banner != null && banner.trim().isNotEmpty) {
          notice = AppNotice(
            id: banner.trim().hashCode.toString(),
            title: 'Notice',
            message: banner.trim(),
          );
        }

        // Cache last confirmed status
        await _db.into(_db.settings).insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: _keyLastStatus,
                value: status,
              ),
            );

        if (reason != null) {
          await _db.into(_db.settings).insertOnConflictUpdate(
                SettingsCompanion.insert(
                  key: _keyLastReason,
                  value: reason,
                ),
              );
        }

        return DeviceControlStatus(
          isAllowed: isAllowed,
          status: status,
          reason: reason,
          banner: banner,
          notice: notice,
          isOffline: false,
        );
      }
    } catch (_) {
      // Network timeout / connection error - fall back to cached policy
    }

    // Offline fallback
    final cachedStatusRow = await (_db.select(_db.settings)
          ..where((tbl) => tbl.key.equals(_keyLastStatus)))
        .getSingleOrNull();

    final cachedReasonRow = await (_db.select(_db.settings)
          ..where((tbl) => tbl.key.equals(_keyLastReason)))
        .getSingleOrNull();

    final cachedStatus = cachedStatusRow?.value ?? 'allowed';
    final isAllowed = cachedStatus == 'allowed';

    return DeviceControlStatus(
      isAllowed: isAllowed,
      status: cachedStatus,
      reason: isAllowed ? null : (cachedReasonRow?.value ?? 'Access suspended by administrator'),
      isOffline: true,
    );
  }

  /// Cryptographically pseudo-random UUID v4 generator with 0 external dependencies.
  static String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));

    // Version 4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Variant 10xx
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

    return '${bytes.sublist(0, 4).map(hex).join()}-'
        '${bytes.sublist(4, 6).map(hex).join()}-'
        '${bytes.sublist(6, 8).map(hex).join()}-'
        '${bytes.sublist(8, 10).map(hex).join()}-'
        '${bytes.sublist(10, 16).map(hex).join()}';
  }
}
