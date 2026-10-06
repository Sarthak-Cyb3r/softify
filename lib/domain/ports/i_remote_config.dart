class RemoteConfigData {
  final List<String> pipedInstances; // Validated HTTPS URLs, max 10
  final String primaryResolver;      // e.g. "youtube_explode" or "piped"
  final int minAppVersionCode;

  const RemoteConfigData({
    required this.pipedInstances,
    required this.primaryResolver,
    required this.minAppVersionCode,
  });
}

abstract class IRemoteConfig {
  /// Fetches the latest dynamic configuration from the verified repository raw JSON.
  Future<RemoteConfigData> fetchLatestConfig();

  /// Returns trusted fallback HTTPS Piped instances capped at <= 10.
  List<String> getFallbackPipedInstances();
}
