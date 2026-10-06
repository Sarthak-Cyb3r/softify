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

  static const String defaultConfigUrl =
      'https://raw.githubusercontent.com/softify-app/softify-config/main/config.json';

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

      // Persist instances to Drift database
      await _persistInstances(effectiveInstances);

      return RemoteConfigData(
        pipedInstances: effectiveInstances,
        primaryResolver: primaryResolver,
        minAppVersionCode: minAppVersionCode,
      );
    } catch (_) {
      // Fallback on network or parsing error
      return const RemoteConfigData(
        pipedInstances: defaultFallbackInstances,
        primaryResolver: 'youtube_explode',
        minAppVersionCode: 1,
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
