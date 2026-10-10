import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Silent background updater service.
/// Checks for updates and prepares release binaries in the background
/// without prompting or interrupting the user.
class AutoUpdateService {
  final http.Client _client;
  static const String _releasesEndpoint =
      'https://api.github.com/repos/Sarthak-Cyb3r/softify/releases/latest';

  AutoUpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// Silently checks for and downloads background updates.
  /// Runs fully headless without blocking the user interface.
  Future<void> runSilentBackgroundUpdateCheck() async {
    try {
      final res = await _client.get(
        Uri.parse(_releasesEndpoint),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Softify-AutoUpdater/1.0',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return;

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final assets = data['assets'] as List<dynamic>? ?? [];

      if (Platform.isLinux) {
        final linuxAsset = assets.firstWhere(
          (a) => (a['name'] as String? ?? '').endsWith('.tar.gz') ||
              (a['name'] as String? ?? '').contains('linux'),
          orElse: () => null,
        );
        if (linuxAsset != null) {
          final downloadUrl = linuxAsset['browser_download_url'] as String?;
          if (downloadUrl != null) {
            await _stageLinuxUpdate(downloadUrl);
          }
        }
      } else if (Platform.isAndroid) {
        final apkAsset = assets.firstWhere(
          (a) => (a['name'] as String? ?? '').endsWith('.apk'),
          orElse: () => null,
        );
        if (apkAsset != null) {
          final downloadUrl = apkAsset['browser_download_url'] as String?;
          if (downloadUrl != null) {
            await _stageAndroidUpdate(downloadUrl);
          }
        }
      }
    } catch (_) {
      // Headless fail-safe: never crash or bother the user
    }
  }

  Future<void> _stageLinuxUpdate(String url) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final targetFile = File('${dir.path}/update_staged.bin');
      final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
      if (res.statusCode == 200) {
        await targetFile.writeAsBytes(res.bodyBytes);
      }
    } catch (_) {}
  }

  Future<void> _stageAndroidUpdate(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetFile = File('${dir.path}/softify_update.apk');
      final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        await targetFile.writeAsBytes(res.bodyBytes);
      }
    } catch (_) {}
  }
}
