import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../domain/ports/i_remote_config.dart';
import '../database/app_database.dart';

class RemoteConfigRepository implements IRemoteConfig {
  final AppDatabase _db;
  final HttpClient _client;
  final String configUrl;

  static const List<String> defaultFallbackInstances = [
    'https://pipedapi.kavin.rocks',
    'https://api.piped.privacydev.net',
    'https://piped-api.lunar.icu',
    'https://api.piped.projectsegfau.lt',
    'https://pipedapi.in.projectsegfau.lt',
    'https://pipedapi.leptons.xyz',
  ];

  static const Map<String, List<String>> defaultSearchAliases = {
    'arijit': ['arijit singh'],
    'kk': ['krishnakumar kunnath'],
    'weeknd': ['the weeknd'],
    'rahman': ['a. r. rahman', 'ar rahman'],
    'shreya': ['shreya ghoshal'],
    'badshah': ['badshah'],
    'diljit': ['diljit dosanjh'],
    'atif': ['atif aslam'],
    'pritam': ['pritam chakraborty'],
    'lata': ['lata mangeshkar'],
    'kishore': ['kishore kumar'],
  };

  static const Map<String, double> defaultRankerWeights = {
    'is_exact': 3.0,
    'prefix_match': 2.0,
    'played_count': 1.5,
    'taste_similarity': 1.0,
    'popularity_proxy': 0.5,
    'edit_distance_penalty': -1.2,
  };

  static const List<ShelfDefinition> defaultShelfDefinitions = [
    ShelfDefinition(
      id: 'jump_back_in',
      title: 'Jump Back In',
      rule: 'frequency_recency',
      limit: 12,
    ),
    ShelfDefinition(
      id: 'daily_mix',
      title: 'Daily Mix',
      rule: 'kmeans_clusters',
      limit: 20,
    ),
    ShelfDefinition(
      id: 'discover_weekly',
      title: 'Discover Weekly',
      rule: 'novelty_with_familiar_anchor',
      familiarRatio: 0.1,
      limit: 20,
    ),
  ];

  static const String defaultConfigUrl =
      'https://raw.githubusercontent.com/softify-app/softify-config/main/config.json';

  Map<String, List<String>> _cachedSearchAliases = Map.from(defaultSearchAliases);
  Map<String, double> _cachedRankerWeights = Map.from(defaultRankerWeights);
  List<ShelfDefinition> _cachedShelfDefinitions = List.from(defaultShelfDefinitions);

  RemoteConfigRepository({
    required AppDatabase db,
    HttpClient? client,
    this.configUrl = defaultConfigUrl,
  })  : _db = db,
        _client = client ?? HttpClient();

  @override
  List<String> getFallbackPipedInstances() =>
      List.unmodifiable(defaultFallbackInstances);

  @override
  Map<String, List<String>> getSearchAliases() =>
      Map.unmodifiable(_cachedSearchAliases);

  @override
  Map<String, double> getSearchRankerWeights() =>
      Map.unmodifiable(_cachedRankerWeights);

  @override
  List<ShelfDefinition> getShelfDefinitions() =>
      List.unmodifiable(_cachedShelfDefinitions);

  @override
  Future<RemoteConfigData> fetchLatestConfig() async {
    try {
      final uri = Uri.parse(configUrl);
      if (uri.scheme != 'https') {
        throw ArgumentError('Remote config URL must use HTTPS');
      }

      final request =
          await _client.getUrl(uri).timeout(const Duration(seconds: 5));
      request.headers.set('User-Agent', 'Softify/1.0 (Mobile Android)');
      final response =
          await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final rawInstances = (json['piped_instances'] as List<dynamic>?) ?? [];
      final validatedInstances = <String>[];

      for (final item in rawInstances) {
        if (item is String) {
          final trimmed = item.trim().replaceAll(RegExp(r'/+$'), '');
          if (trimmed.startsWith('https://')) {
            validatedInstances.add(trimmed);
            if (validatedInstances.length >= 10) break;
          }
        }
      }

      final effectiveInstances = validatedInstances.isNotEmpty
          ? validatedInstances
          : defaultFallbackInstances;

      final primaryResolver =
          (json['primary_resolver'] as String?) ?? 'youtube_explode';
      final minAppVersionCode =
          (json['min_app_version_code'] as num?)?.toInt() ?? 1;

      final searchAliases = Map<String, List<String>>.from(defaultSearchAliases);
      if (json['search_aliases'] is Map<String, dynamic>) {
        final rawMap = json['search_aliases'] as Map<String, dynamic>;
        for (final entry in rawMap.entries) {
          if (entry.value is List) {
            searchAliases[entry.key] = (entry.value as List)
                .map((e) => e.toString())
                .toList();
          }
        }
      }

      final rankerWeights = Map<String, double>.from(defaultRankerWeights);
      if (json['search_ranker_weights_v1'] is Map<String, dynamic>) {
        final rawMap = json['search_ranker_weights_v1'] as Map<String, dynamic>;
        for (final entry in rawMap.entries) {
          if (entry.value is num) {
            rankerWeights[entry.key] = (entry.value as num).toDouble();
          }
        }
      }

      final shelfDefinitions = <ShelfDefinition>[];
      if (json['shelves'] is List) {
        for (final item in json['shelves'] as List) {
          if (item is Map<String, dynamic>) {
            try {
              shelfDefinitions.add(ShelfDefinition.fromJson(item));
            } catch (_) {}
          }
        }
      }
      final effectiveShelves = shelfDefinitions.isNotEmpty
          ? shelfDefinitions
          : defaultShelfDefinitions;

      _cachedSearchAliases = searchAliases;
      _cachedRankerWeights = rankerWeights;
      _cachedShelfDefinitions = effectiveShelves;

      // Persist instances to Drift database
      await _persistInstances(effectiveInstances);

      return RemoteConfigData(
        pipedInstances: effectiveInstances,
        primaryResolver: primaryResolver,
        minAppVersionCode: minAppVersionCode,
        searchAliases: searchAliases,
        searchRankerWeights: rankerWeights,
        shelfDefinitions: effectiveShelves,
      );
    } catch (_) {
      // Fallback on network or parsing error
      return const RemoteConfigData(
        pipedInstances: defaultFallbackInstances,
        primaryResolver: 'youtube_explode',
        minAppVersionCode: 1,
        searchAliases: defaultSearchAliases,
        searchRankerWeights: defaultRankerWeights,
        shelfDefinitions: defaultShelfDefinitions,
      );
    }
  }

  Future<void> _persistInstances(List<String> urls) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final url in urls) {
        batch.insert(
          _db.pipedInstances,
          PipedInstancesCompanion(
            url: Value(url),
            isHealthy: const Value(true),
            lastChecked: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Pings an instance and updates latency in database
  Future<int?> checkInstanceLatency(String instanceUrl) async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse('$instanceUrl/feed/unauthenticated');
      final req =
          await _client.getUrl(uri).timeout(const Duration(seconds: 4));
      final res = await req.close().timeout(const Duration(seconds: 4));
      sw.stop();
      final isHealthy = res.statusCode == 200;
      final latency = isHealthy ? sw.elapsedMilliseconds : null;

      await (_db.update(_db.pipedInstances)
            ..where((t) => t.url.equals(instanceUrl)))
          .write(
        PipedInstancesCompanion(
          latencyMs: Value(latency),
          isHealthy: Value(isHealthy),
          lastChecked: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      return latency;
    } catch (_) {
      sw.stop();
      await (_db.update(_db.pipedInstances)
            ..where((t) => t.url.equals(instanceUrl)))
          .write(
        PipedInstancesCompanion(
          latencyMs: const Value(null),
          isHealthy: const Value(false),
          lastChecked: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      return null;
    }
  }
}
