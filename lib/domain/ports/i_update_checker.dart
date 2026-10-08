class AppReleaseInfo {
  final String tagName;       // e.g. "v1.0.0"
  final String releaseNotes;
  final String apkDownloadUrl;
  final String expectedSha256; // Checksum for verifying download integrity
  final int apkSizeBytes;

  const AppReleaseInfo({
    required this.tagName,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.expectedSha256,
    required this.apkSizeBytes,
  });
}

/// Why an install could not proceed, so the UI can react appropriately
/// (a signing-key change, for instance, requires a guided reinstall).
enum UpdateInstallError {
  signatureMismatch,
  versionNotNewer,
  installPermissionRequired,
  userAborted,
  invalidApk,
  storageFull,
  installFailed,
}

class UpdateInstallException implements Exception {
  final UpdateInstallError error;
  final String message;

  const UpdateInstallException(this.error, this.message);

  @override
  String toString() => message;
}

abstract class IUpdateChecker {
  /// Checks the hardcoded GitHub repository for an update with higher semver.
  Future<AppReleaseInfo?> checkForUpdate(String currentVersion);

  /// Downloads the APK, verifies its SHA-256 hash, and initiates Android installation.
  /// Throws [UpdateInstallException] when the platform refuses the install.
  Future<void> downloadAndInstallUpdate(
    AppReleaseInfo release, {
    void Function(double progress)? onProgress,
  });

  /// Copies the last downloaded update APK into the shared Downloads folder so it
  /// survives an uninstall. Returns the saved path. Only meaningful after a
  /// [downloadAndInstallUpdate] call.
  Future<String> stageDownloadedUpdate();

  /// Uninstalls the installed app (used when the signing key changed). The
  /// system kills this process, so the returned future may never complete.
  Future<void> uninstallInstalledApp();
}
