class ShelfDefinition {
  final String id;
  final String title;
  final String rule;
  final int limit;
  final double familiarRatio;

  const ShelfDefinition({
    required this.id,
    required this.title,
    required this.rule,
    this.limit = 20,
    this.familiarRatio = 0.1,
  });

  factory ShelfDefinition.fromJson(Map<String, dynamic> json) {
    return ShelfDefinition(
      id: json['id'] as String,
      title: json['title'] as String,
      rule: json['rule'] as String,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      familiarRatio: (json['familiar_ratio'] as num?)?.toDouble() ?? 0.1,
    );
  }
}

class RemoteConfigData {
  final List<String> pipedInstances; // Validated HTTPS URLs, max 10
  final String primaryResolver;      // e.g. "youtube_explode" or "piped"
  final int minAppVersionCode;
  final Map<String, List<String>> searchAliases;
  final Map<String, double> searchRankerWeights;
  final List<ShelfDefinition> shelfDefinitions;

  const RemoteConfigData({
    required this.pipedInstances,
    required this.primaryResolver,
    required this.minAppVersionCode,
    this.searchAliases = const {},
    this.searchRankerWeights = const {},
    this.shelfDefinitions = const [],
  });
}

abstract class IRemoteConfig {
  /// Fetches the latest dynamic configuration from the verified repository raw JSON.
  Future<RemoteConfigData> fetchLatestConfig();

  /// Returns trusted fallback HTTPS Piped instances capped at <= 10.
  List<String> getFallbackPipedInstances();

  /// Returns cached or fallback search aliases.
  Map<String, List<String>> getSearchAliases();

  /// Returns cached or fallback ranker weights.
  Map<String, double> getSearchRankerWeights();

  /// Returns cached or fallback home shelf definitions.
  List<ShelfDefinition> getShelfDefinitions();
}
