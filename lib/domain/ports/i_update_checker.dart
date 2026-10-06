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

abstract class IUpdateChecker {
  /// Checks the hardcoded GitHub repository for an update with higher semver.
  Future<AppReleaseInfo?> checkForUpdate(String currentVersion);

  /// Downloads the APK, verifies its SHA-256 hash, and initiates Android installation.
  Future<void> downloadAndInstallUpdate(
    AppReleaseInfo release, {
    void Function(double progress)? onProgress,
  });
}
