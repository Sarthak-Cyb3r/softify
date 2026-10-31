import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/ports/i_update_checker.dart';

class GitHubReleaseUpdateChecker implements IUpdateChecker {
  final String repoOwner;
  final String repoName;
  final HttpClient _client;
  static const MethodChannel _installerChannel =
      MethodChannel('com.softify/installer');

  GitHubReleaseUpdateChecker({
    this.repoOwner = 'Sarthak-Cyb3r',
    this.repoName = 'softify',
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  @override
  Future<AppReleaseInfo?> checkForUpdate(String currentVersion) async {
    try {
      // Query native Android PackageManager if available to ensure exact installed version comparison
      String effectiveCurrent = currentVersion;
      if (Platform.isAndroid) {
        try {
          final info = await _installerChannel.invokeMapMethod<dynamic, dynamic>('getInstalledInfo');
          final nativeVersion = info?['versionName'] as String?;
          if (nativeVersion != null && nativeVersion.trim().isNotEmpty) {
            effectiveCurrent = nativeVersion.trim();
          }
        } catch (_) {}
      }

      final uri = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=5',
      );
      final request =
          await _client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.set('User-Agent', 'Softify/1.0 (Mobile Android)');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response =
          await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      final List<dynamic> releases = decoded is List ? decoded : [decoded];

      for (final rel in releases) {
        if (rel is! Map<String, dynamic>) continue;
        final tagName = (rel['tag_name'] as String? ?? '').trim();
        if (tagName.isEmpty || !isNewerVersion(tagName, effectiveCurrent)) {
          continue;
        }

        final releaseNotes = (rel['body'] as String? ?? '').trim();
        final assets = (rel['assets'] as List<dynamic>?) ?? [];

        // Find primary APK asset: prioritize compact 64-bit ARM APK (arm64-v8a, ~19MB), fallback to Universal
        dynamic apkAsset = assets.firstWhere(
          (a) {
            final name = (a['name'] as String? ?? '').toLowerCase();
            return name.endsWith('.apk') &&
                name.contains('arm64-v8a') &&
                !name.contains('unaligned');
          },
          orElse: () => null,
        );

        apkAsset ??= assets.firstWhere(
          (a) {
            final name = (a['name'] as String? ?? '').toLowerCase();
            return name.endsWith('.apk') && !name.contains('unaligned');
          },
          orElse: () => null,
        );

        if (apkAsset == null && !Platform.isAndroid) {
          apkAsset = assets.firstWhere(
            (a) {
              final name = (a['name'] as String? ?? '').toLowerCase();
              return name.endsWith('.tar.gz') || name.endsWith('.zip');
            },
            orElse: () => null,
          );
        }

        if (apkAsset == null) continue;

        final downloadUrl = apkAsset['browser_download_url'] as String? ?? '';
        final apkSizeBytes = (apkAsset['size'] as num?)?.toInt() ?? 0;
        if (downloadUrl.isEmpty) continue;

        // Extract SHA-256 checksum from release description if available
        final shaMatch = RegExp(
          r'(?:sha-?256|checksum):\s*([a-fA-F0-9]{64})',
          caseSensitive: false,
        ).firstMatch(releaseNotes);
        final expectedSha256 = shaMatch != null ? shaMatch.group(1)! : '';

        return AppReleaseInfo(
          tagName: tagName,
          releaseNotes: releaseNotes,
          apkDownloadUrl: downloadUrl,
          expectedSha256: expectedSha256,
          apkSizeBytes: apkSizeBytes,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _downloadedFilePath;
  String? _lastReleaseTagName;

  @override
  Future<void> downloadAndInstallUpdate(
    AppReleaseInfo release, {
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'softify_update_${release.tagName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}.apk';
    final targetFile = File(p.join(tempDir.path, fileName));

    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    final uri = Uri.parse(release.apkDownloadUrl);
    final request = await _client.getUrl(uri);
    request.headers.set('User-Agent', 'Softify/1.0 (Mobile Android)');
    final response = await request.close();

    if (response.statusCode != 200) {
      throw HttpException('Failed to download update: HTTP ${response.statusCode}', uri: uri);
    }

    final totalBytes = response.contentLength > 0
        ? response.contentLength
        : release.apkSizeBytes;

    final outputSink = targetFile.openWrite();
    final bytesBuilder = BytesBuilder(copy: false);
    int bytesDownloaded = 0;

    try {
      await for (final chunk in response) {
        outputSink.add(chunk);
        bytesBuilder.add(chunk);
        bytesDownloaded += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(bytesDownloaded / totalBytes);
        }
      }
      await outputSink.flush();
      await outputSink.close();
    } catch (e) {
      await outputSink.close();
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      rethrow;
    }

    final calculatedSha256 =
        sha256.convert(bytesBuilder.takeBytes()).toString();

    // Verify SHA-256 integrity if checksum was published with release
    if (release.expectedSha256.isNotEmpty) {
      if (calculatedSha256.toLowerCase() != release.expectedSha256.toLowerCase()) {
        await targetFile.delete();
        throw SecurityException(
          'SHA-256 integrity verification failed: expected ${release.expectedSha256}, got $calculatedSha256',
        );
      }
    }

    _downloadedFilePath = targetFile.path;
    _lastReleaseTagName = release.tagName;

    // Launch Android package installer (or open release URL on desktop)
    if (!Platform.isAndroid) {
      try {
        await launchUrl(
          Uri.parse(release.apkDownloadUrl.isNotEmpty
              ? release.apkDownloadUrl
              : 'https://github.com/Sarthak-Cyb3r/softify/releases/latest'),
          mode: LaunchMode.externalApplication,
        );
        return;
      } catch (_) {
        throw const UpdateInstallException(
          UpdateInstallError.installFailed,
          'Automatic installation is only supported on Android. Please install via GitHub releases.',
        );
      }
    }

    // Refuse early when the APK cannot legally replace the installed app:
    // a different signing key or a non-newer versionCode both end in a
    // system "package conflict" dialog if we let the installer try.
    Map<dynamic, dynamic> preflight = <dynamic, dynamic>{};
    try {
      preflight = await _installerChannel.invokeMapMethod<dynamic, dynamic>(
            'preflightInstall',
            {'filePath': targetFile.path},
          ) ??
          <dynamic, dynamic>{};
    } on PlatformException {
      // Non-fatal: if preflight fails on specific OEM/frameworks,
      // proceed directly to Android's native PackageInstaller which
      // handles authoritative OS-level signature & package verification.
      preflight = <dynamic, dynamic>{};
    }

    if (preflight['signatureMatch'] == false) {
      throw const UpdateInstallException(
        UpdateInstallError.signatureMismatch,
        'The update is signed with a different key than the installed app.',
      );
    }
    final apkVersionCode = (preflight['apkVersionCode'] as num?)?.toInt() ?? 0;
    final installedVersionCode = (preflight['installedVersionCode'] as num?)?.toInt() ?? 0;
    if (installedVersionCode > 0 && apkVersionCode <= installedVersionCode) {
      throw UpdateInstallException(
        UpdateInstallError.versionNotNewer,
        'The downloaded build (versionCode $apkVersionCode) is not newer than '
        'the installed one (versionCode $installedVersionCode).',
      );
    }

    try {
      await _installerChannel.invokeMethod('installApk', {
        'filePath': targetFile.path,
      });
    } on PlatformException catch (e) {
      try {
        // Fallback: Delegate directly to system browser / release download (SimpMusic pattern)
        final targetUrl = release.apkDownloadUrl.isNotEmpty
            ? release.apkDownloadUrl
            : 'https://github.com/Sarthak-Cyb3r/softify/releases/latest';
        await launchUrl(
          Uri.parse(targetUrl),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        throw _installException(e.code, e.message);
      }
    }
  }

  @override
  Future<String> stageDownloadedUpdate() async {
    final path = _downloadedFilePath;
    if (path == null || !File(path).existsSync()) {
      throw const UpdateInstallException(
        UpdateInstallError.installFailed,
        'The downloaded update is no longer available. Download it again.',
      );
    }
    final tag = (_lastReleaseTagName ?? 'update')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    try {
      final result = await _installerChannel.invokeMapMethod<dynamic, dynamic>(
        'stageApk',
        {'filePath': path, 'fileName': 'Softify-$tag-Android-Universal.apk'},
      );
      return (result?['path'] as String?) ?? '';
    } on PlatformException catch (e) {
      throw UpdateInstallException(
        UpdateInstallError.installFailed,
        e.message ?? 'Could not save the update to Downloads.',
      );
    }
  }

  @override
  Future<void> uninstallInstalledApp() async {
    try {
      await _installerChannel.invokeMethod('uninstallApk');
    } on PlatformException catch (e) {
      if (e.code == 'USER_ABORTED') {
        throw const UpdateInstallException(
          UpdateInstallError.userAborted,
          'Uninstall cancelled.',
        );
      }
      throw UpdateInstallException(
        UpdateInstallError.installFailed,
        e.message ?? 'Could not uninstall the app.',
      );
    }
  }

  UpdateInstallException _installException(String code, String? message) {
    switch (code) {
      case 'BLOCKED':
        return const UpdateInstallException(
          UpdateInstallError.installPermissionRequired,
          'Android requires permission to install apps. It has been opened '
          'in Settings — enable it for Softify, then tap Update again.',
        );
      case 'USER_ABORTED':
        return const UpdateInstallException(
          UpdateInstallError.userAborted,
          'Installation cancelled.',
        );
      case 'CONFLICT':
        return const UpdateInstallException(
          UpdateInstallError.signatureMismatch,
          'The update conflicts with the installed app (different signing key).',
        );
      case 'VERSION_DOWNGRADE':
        return const UpdateInstallException(
          UpdateInstallError.versionNotNewer,
          'The downloaded build is not newer than the installed app.',
        );
      case 'INVALID':
        return const UpdateInstallException(
          UpdateInstallError.invalidApk,
          'The downloaded file is not a valid APK.',
        );
      case 'STORAGE':
        return const UpdateInstallException(
          UpdateInstallError.storageFull,
          'Not enough storage to install the update.',
        );
      default:
        return UpdateInstallException(
          UpdateInstallError.installFailed,
          message ?? 'Installation failed.',
        );
    }
  }

  /// Compares two semver strings (e.g. "v1.0.1" vs "1.0.0").
  /// Returns true if remote is strictly newer than current.
  static bool isNewerVersion(String remote, String current) {
    final cleanRemote = remote.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final cleanCurrent = current.trim().replaceFirst(RegExp(r'^[vV]'), '');

    final remoteParts = cleanRemote
        .split(RegExp(r'[-+.]'))
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final currentParts = cleanCurrent
        .split(RegExp(r'[-+.]'))
        .map((p) => int.tryParse(p) ?? 0)
        .toList();

    final maxLen = remoteParts.length > currentParts.length
        ? remoteParts.length
        : currentParts.length;

    for (int i = 0; i < maxLen; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}
