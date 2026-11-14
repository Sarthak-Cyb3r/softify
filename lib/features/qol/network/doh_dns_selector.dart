// ============================================================================
// Softify Quality of Life (QoL) Feature 51:
// Custom DNS-over-HTTPS (DoH) Selector & Anti-Throttling Resolver
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../presentation/theme/app_theme.dart';

// ============================================================================
// Storage Keys & Persistence Contracts
// ============================================================================

/// SharedPreferences persistent storage key for selected DoH provider.
const String kSelectedDohProviderPrefKey = 'softify_doh_selected_provider';

/// SharedPreferences persistent storage key for custom DoH endpoint URL.
const String kCustomDohEndpointPrefKey = 'softify_doh_custom_endpoint';

/// SharedPreferences persistent storage key for fallback to system DNS.
const String kDohFallbackToSystemPrefKey = 'softify_doh_fallback_to_system';

/// SharedPreferences persistent storage key for DNS caching toggle.
const String kDohCacheEnabledPrefKey = 'softify_doh_cache_enabled';

/// Abstract storage contract compatible with SharedPreferences semantics.
abstract class DohPrefsStorage {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<bool?> getBool(String key);
  Future<bool> setBool(String key, bool value);
}

/// Durable disk-backed key-value store for DoH settings with an in-memory fallback.
class DohSharedPreferencesStore implements DohPrefsStorage {
  static final DohSharedPreferencesStore _instance =
      DohSharedPreferencesStore._internal();
  factory DohSharedPreferencesStore() => _instance;
  DohSharedPreferencesStore._internal();

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File(p.join(dir.path, 'shared_preferences.json'));
      if (await _cacheFile!.exists()) {
        final content = await _cacheFile!.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _memoryCache = Map<String, dynamic>.from(decoded);
          }
        }
      }
    } catch (_) {
      // Graceful fallback to memory store
    } finally {
      _isLoaded = true;
    }
  }

  @override
  Future<String?> getString(String key) async {
    if (!_isLoaded) await init();
    final val = _memoryCache[key];
    return val is String ? val : null;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    return _persist();
  }

  @override
  Future<bool?> getBool(String key) async {
    if (!_isLoaded) await init();
    final val = _memoryCache[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return null;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    return _persist();
  }

  Future<bool> _persist() async {
    try {
      if (_cacheFile != null) {
        if (!await _cacheFile!.parent.exists()) {
          await _cacheFile!.parent.create(recursive: true);
        }
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache), flush: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// Enums & Models
// ============================================================================

/// Supported DNS-over-HTTPS providers.
enum DohProviderType {
  system(
    id: 'system',
    displayName: 'System',
    fullTitle: 'System Default',
    ipDescription: 'OS Resolver',
    defaultEndpoint: '',
    primaryIps: [],
    description:
        'Uses standard operating system DNS resolver and local network DHCP.',
    icon: Icons.dns_rounded,
    isEncrypted: false,
  ),
  cloudflare(
    id: 'cloudflare',
    displayName: 'Cloudflare 1.1.1.1',
    fullTitle: 'Cloudflare (1.1.1.1)',
    ipDescription: '1.1.1.1 / 1.0.0.1',
    defaultEndpoint: 'https://cloudflare-dns.com/dns-query',
    primaryIps: ['1.1.1.1', '1.0.0.1', '2606:4700:4700::1111'],
    description:
        'Privacy-first, lightning fast DNS with strict zero-logging audited by KPMG.',
    icon: Icons.bolt_rounded,
    isEncrypted: true,
  ),
  google(
    id: 'google',
    displayName: 'Google 8.8.8.8',
    fullTitle: 'Google (8.8.8.8)',
    ipDescription: '8.8.8.8 / 8.8.4.4',
    defaultEndpoint: 'https://dns.google/resolve',
    primaryIps: ['8.8.8.8', '8.8.4.4', '2001:4860:4860::8888'],
    description:
        'Global anycast infrastructure with planetary scale redundancy and geo-routing.',
    icon: Icons.public_rounded,
    isEncrypted: true,
  ),
  quad9(
    id: 'quad9',
    displayName: 'Quad9 9.9.9.9',
    fullTitle: 'Quad9 (9.9.9.9)',
    ipDescription: '9.9.9.9 / 149.112.112.112',
    defaultEndpoint: 'https://dns.quad9.net/dns-query',
    primaryIps: ['9.9.9.9', '149.112.112.112', '2620:fe::fe'],
    description:
        'Swiss non-profit blocking malicious phishing, malware, and trackers at DNS level.',
    icon: Icons.security_rounded,
    isEncrypted: true,
  ),
  custom(
    id: 'custom',
    displayName: 'Custom',
    fullTitle: 'Custom DoH',
    ipDescription: 'User Endpoint',
    defaultEndpoint: 'https://dns.adguard-dns.com/dns-query',
    primaryIps: [],
    description:
        'Connects to your custom RFC 8484 / JSON DoH server, Pi-hole, or AdGuard Home.',
    icon: Icons.tune_rounded,
    isEncrypted: true,
  );

  final String id;
  final String displayName;
  final String fullTitle;
  final String ipDescription;
  final String defaultEndpoint;
  final List<String> primaryIps;
  final String description;
  final IconData icon;
  final bool isEncrypted;

  const DohProviderType({
    required this.id,
    required this.displayName,
    required this.fullTitle,
    required this.ipDescription,
    required this.defaultEndpoint,
    required this.primaryIps,
    required this.description,
    required this.icon,
    required this.isEncrypted,
  });

  static DohProviderType fromId(String? id) {
    if (id == null) return DohProviderType.system;
    for (final p in DohProviderType.values) {
      if (p.id == id.toLowerCase() || p.name == id.toLowerCase()) {
        return p;
      }
    }
    return DohProviderType.system;
  }
}

/// Represents a cached DNS record with TTL expiration.
@immutable
class DohRecord {
  final String host;
  final List<String> ipAddresses;
  final int ttlSeconds;
  final DateTime fetchedAt;
  final DohProviderType provider;

  const DohRecord({
    required this.host,
    required this.ipAddresses,
    required this.ttlSeconds,
    required this.fetchedAt,
    required this.provider,
  });

  bool get isExpired {
    final age = DateTime.now().difference(fetchedAt).inSeconds;
    return age >= ttlSeconds;
  }

  int get remainingTtl {
    final age = DateTime.now().difference(fetchedAt).inSeconds;
    return math.max(0, ttlSeconds - age);
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'ipAddresses': ipAddresses,
        'ttlSeconds': ttlSeconds,
        'fetchedAt': fetchedAt.toIso8601String(),
        'provider': provider.id,
      };

  factory DohRecord.fromJson(Map<String, dynamic> json) => DohRecord(
        host: json['host'] as String? ?? '',
        ipAddresses: (json['ipAddresses'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        ttlSeconds: json['ttlSeconds'] as int? ?? 300,
        fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
            DateTime.now(),
        provider: DohProviderType.fromId(json['provider'] as String?),
      );
}

/// Diagnostic result of a DNS lookup operation.
@immutable
class DnsLookupResult {
  final String host;
  final List<String> addresses;
  final DohProviderType provider;
  final int latencyMs;
  final int ttl;
  final bool isFromCache;
  final bool isFallback;
  final bool isSuccess;
  final String? errorMessage;
  final DateTime timestamp;

  const DnsLookupResult({
    required this.host,
    required this.addresses,
    required this.provider,
    required this.latencyMs,
    required this.ttl,
    this.isFromCache = false,
    this.isFallback = false,
    this.isSuccess = true,
    this.errorMessage,
    required this.timestamp,
  });

  factory DnsLookupResult.failure({
    required String host,
    required DohProviderType provider,
    required String error,
    int latencyMs = 0,
  }) {
    return DnsLookupResult(
      host: host,
      addresses: const [],
      provider: provider,
      latencyMs: latencyMs,
      ttl: 0,
      isSuccess: false,
      errorMessage: error,
      timestamp: DateTime.now(),
    );
  }
}

/// Immutable state container for DNS-over-HTTPS settings and diagnostics.
@immutable
class DohConfig {
  final DohProviderType selectedProvider;
  final String customEndpoint;
  final bool fallbackToSystem;
  final bool cacheEnabled;
  final Map<DohProviderType, int?> latencyMap;
  final bool isTestingLatency;
  final bool isResolving;
  final DnsLookupResult? lastLookupResult;
  final int cachedEntriesCount;
  final int totalQueries;
  final int cacheHits;

  const DohConfig({
    this.selectedProvider = DohProviderType.system,
    this.customEndpoint = 'https://dns.adguard-dns.com/dns-query',
    this.fallbackToSystem = true,
    this.cacheEnabled = true,
    this.latencyMap = const {},
    this.isTestingLatency = false,
    this.isResolving = false,
    this.lastLookupResult,
    this.cachedEntriesCount = 0,
    this.totalQueries = 0,
    this.cacheHits = 0,
  });

  bool get isEncrypted => selectedProvider.isEncrypted;

  DohConfig copyWith({
    DohProviderType? selectedProvider,
    String? customEndpoint,
    bool? fallbackToSystem,
    bool? cacheEnabled,
    Map<DohProviderType, int?>? latencyMap,
    bool? isTestingLatency,
    bool? isResolving,
    DnsLookupResult? lastLookupResult,
    int? cachedEntriesCount,
    int? totalQueries,
    int? cacheHits,
  }) {
    return DohConfig(
      selectedProvider: selectedProvider ?? this.selectedProvider,
      customEndpoint: customEndpoint ?? this.customEndpoint,
      fallbackToSystem: fallbackToSystem ?? this.fallbackToSystem,
      cacheEnabled: cacheEnabled ?? this.cacheEnabled,
      latencyMap: latencyMap ?? this.latencyMap,
      isTestingLatency: isTestingLatency ?? this.isTestingLatency,
      isResolving: isResolving ?? this.isResolving,
      lastLookupResult: lastLookupResult ?? this.lastLookupResult,
      cachedEntriesCount: cachedEntriesCount ?? this.cachedEntriesCount,
      totalQueries: totalQueries ?? this.totalQueries,
      cacheHits: cacheHits ?? this.cacheHits,
    );
  }
}

// ============================================================================
// DNS-over-HTTPS Resolver Engine
// ============================================================================

/// Function signature for system DNS resolution, overridable for unit tests.
typedef SystemDnsLookup = Future<List<InternetAddress>> Function(String host);

/// Pure Dart DNS-over-HTTPS client supporting RFC 8484 and DNS JSON endpoints.
class DohResolver {
  final http.Client _httpClient;
  final Map<String, DohRecord> _cache = {};

  /// Global override hook for OS DNS lookups during unit tests.
  static SystemDnsLookup? systemLookupOverride;

  DohResolver({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  int get cacheSize => _cache.length;
  List<DohRecord> get cachedRecords => _cache.values.toList();

  void clearCache() => _cache.clear();

  void pruneExpired() {
    _cache.removeWhere((_, record) => record.isExpired);
  }

  /// Resolves [host] using the chosen [provider] or cached records.
  Future<DnsLookupResult> lookup(
    String host, {
    required DohProviderType provider,
    String? customEndpoint,
    bool fallbackToSystem = true,
    bool useCache = true,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final cleanHost = host.trim().toLowerCase();
    if (cleanHost.isEmpty) {
      return DnsLookupResult.failure(
        host: host,
        provider: provider,
        error: 'Hostname cannot be empty',
      );
    }

    // 1. Check local cache
    if (useCache && _cache.containsKey(cleanHost)) {
      final cached = _cache[cleanHost]!;
      if (!cached.isExpired) {
        return DnsLookupResult(
          host: cleanHost,
          addresses: cached.ipAddresses,
          provider: cached.provider,
          latencyMs: 0,
          ttl: cached.remainingTtl,
          isFromCache: true,
          timestamp: DateTime.now(),
        );
      } else {
        _cache.remove(cleanHost);
      }
    }

    // 2. System DNS resolution
    if (provider == DohProviderType.system) {
      return _lookupSystem(cleanHost, timeout: timeout, isFallback: false);
    }

    // 3. DNS-over-HTTPS resolution
    final stopwatch = Stopwatch()..start();
    try {
      final endpoint = provider == DohProviderType.custom
          ? (customEndpoint ?? provider.defaultEndpoint)
          : provider.defaultEndpoint;

      final uri = _buildDohUri(provider, endpoint, cleanHost);
      final headers = {'Accept': 'application/dns-json'};

      final response = await _httpClient.get(uri, headers: headers).timeout(timeout);
      stopwatch.stop();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final answers = (decoded['Answer'] as List?) ?? [];
          final ips = <String>[];
          int minTtl = 300;

          for (final ans in answers) {
            if (ans is Map) {
              final type = ans['type'] as int?;
              final data = ans['data']?.toString() ?? '';
              final ttl = ans['TTL'] as int? ?? 300;
              // Type 1: A (IPv4), Type 28: AAAA (IPv6)
              if ((type == 1 || type == 28) && data.isNotEmpty) {
                ips.add(data);
                if (ttl < minTtl && ttl > 0) minTtl = ttl;
              }
            }
          }

          if (ips.isNotEmpty) {
            if (useCache) {
              _cache[cleanHost] = DohRecord(
                host: cleanHost,
                ipAddresses: ips,
                ttlSeconds: minTtl,
                fetchedAt: DateTime.now(),
                provider: provider,
              );
            }

            return DnsLookupResult(
              host: cleanHost,
              addresses: ips,
              provider: provider,
              latencyMs: stopwatch.elapsedMilliseconds,
              ttl: minTtl,
              timestamp: DateTime.now(),
            );
          }
        }
      }

      throw HttpException('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      stopwatch.stop();
      if (fallbackToSystem) {
        return _lookupSystem(
          cleanHost,
          timeout: timeout,
          isFallback: true,
          originalProvider: provider,
        );
      }
      return DnsLookupResult.failure(
        host: cleanHost,
        provider: provider,
        error: 'DoH resolution failed: $e',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Measures ping / query latency to the specified provider endpoint.
  Future<int?> measureLatency(
    DohProviderType provider, {
    String? customEndpoint,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    const canaryHost = 'google.com';
    final stopwatch = Stopwatch()..start();
    try {
      if (provider == DohProviderType.system) {
        final lookupFn = systemLookupOverride ?? InternetAddress.lookup;
        final res = await lookupFn(canaryHost).timeout(timeout);
        stopwatch.stop();
        return res.isNotEmpty ? stopwatch.elapsedMilliseconds : null;
      }

      final endpoint = provider == DohProviderType.custom
          ? (customEndpoint ?? provider.defaultEndpoint)
          : provider.defaultEndpoint;

      final uri = _buildDohUri(provider, endpoint, canaryHost);
      final res = await _httpClient
          .get(uri, headers: {'Accept': 'application/dns-json'}).timeout(timeout);
      stopwatch.stop();

      return res.statusCode == 200 ? stopwatch.elapsedMilliseconds : null;
    } catch (_) {
      return null;
    }
  }

  Uri _buildDohUri(DohProviderType provider, String endpoint, String host) {
    final baseUri = Uri.parse(endpoint);
    final params = Map<String, String>.from(baseUri.queryParameters);
    params['name'] = host;
    params['type'] = 'A';

    return baseUri.replace(queryParameters: params);
  }

  Future<DnsLookupResult> _lookupSystem(
    String host, {
    required Duration timeout,
    required bool isFallback,
    DohProviderType originalProvider = DohProviderType.system,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final lookupFn = systemLookupOverride ?? InternetAddress.lookup;
      final results = await lookupFn(host).timeout(timeout);
      stopwatch.stop();

      final ips = results.map((a) => a.address).toList();
      if (ips.isEmpty) {
        return DnsLookupResult.failure(
          host: host,
          provider: isFallback ? originalProvider : DohProviderType.system,
          error: 'No DNS records found via system lookup',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }

      return DnsLookupResult(
        host: host,
        addresses: ips,
        provider: isFallback ? originalProvider : DohProviderType.system,
        latencyMs: stopwatch.elapsedMilliseconds,
        ttl: 300,
        isFallback: isFallback,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      stopwatch.stop();
      return DnsLookupResult.failure(
        host: host,
        provider: isFallback ? originalProvider : DohProviderType.system,
        error: 'System lookup failed: $e',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
}

// ============================================================================
// Riverpod State Notifier & Providers
// ============================================================================

/// Riverpod StateNotifier managing DoH configuration, latencies, and persistence.
class DohNotifier extends StateNotifier<DohConfig> {
  final DohPrefsStorage _storage;
  final DohResolver _resolver;

  /// Test injection hooks.
  static DohPrefsStorage? customStorage;
  static http.Client? customHttpClient;

  static void resetForTesting() {
    customStorage = null;
    customHttpClient = null;
    DohResolver.systemLookupOverride = null;
  }

  DohNotifier({DohPrefsStorage? storage, DohResolver? resolver})
      : _storage = storage ?? customStorage ?? DohSharedPreferencesStore(),
        _resolver = resolver ??
            DohResolver(httpClient: customHttpClient),
        super(const DohConfig()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final providerId = await _storage.getString(kSelectedDohProviderPrefKey);
      final customUrl = await _storage.getString(kCustomDohEndpointPrefKey);
      final fallback = await _storage.getBool(kDohFallbackToSystemPrefKey);
      final cacheEnabled = await _storage.getBool(kDohCacheEnabledPrefKey);

      state = state.copyWith(
        selectedProvider: DohProviderType.fromId(providerId),
        customEndpoint: customUrl ?? state.customEndpoint,
        fallbackToSystem: fallback ?? true,
        cacheEnabled: cacheEnabled ?? true,
        cachedEntriesCount: _resolver.cacheSize,
      );
    } catch (_) {
      // Retain default config on load error
    }
  }

  Future<void> setProvider(DohProviderType provider) async {
    state = state.copyWith(selectedProvider: provider);
    await _storage.setString(kSelectedDohProviderPrefKey, provider.id);
  }

  Future<void> setCustomEndpoint(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(customEndpoint: trimmed);
    await _storage.setString(kCustomDohEndpointPrefKey, trimmed);
  }

  Future<void> setFallbackToSystem(bool enabled) async {
    state = state.copyWith(fallbackToSystem: enabled);
    await _storage.setBool(kDohFallbackToSystemPrefKey, enabled);
  }

  Future<void> setCacheEnabled(bool enabled) async {
    state = state.copyWith(cacheEnabled: enabled);
    await _storage.setBool(kDohCacheEnabledPrefKey, enabled);
    if (!enabled) {
      clearCache();
    }
  }

  void clearCache() {
    _resolver.clearCache();
    state = state.copyWith(cachedEntriesCount: 0);
  }

  /// Measures latency across all supported DoH providers.
  Future<void> testLatencies() async {
    if (state.isTestingLatency) return;
    state = state.copyWith(isTestingLatency: true);

    final results = Map<DohProviderType, int?>.from(state.latencyMap);
    for (final p in DohProviderType.values) {
      final latency = await _resolver.measureLatency(
        p,
        customEndpoint: state.customEndpoint,
      );
      results[p] = latency;
    }

    state = state.copyWith(
      latencyMap: results,
      isTestingLatency: false,
    );
  }

  /// Live diagnostic resolver for user-entered hostnames.
  Future<DnsLookupResult> testResolve(String host) async {
    state = state.copyWith(isResolving: true);
    final result = await _resolver.lookup(
      host,
      provider: state.selectedProvider,
      customEndpoint: state.customEndpoint,
      fallbackToSystem: state.fallbackToSystem,
      useCache: state.cacheEnabled,
    );

    state = state.copyWith(
      isResolving: false,
      lastLookupResult: result,
      cachedEntriesCount: _resolver.cacheSize,
      totalQueries: state.totalQueries + 1,
      cacheHits: result.isFromCache ? state.cacheHits + 1 : state.cacheHits,
    );

    return result;
  }
}

/// Primary Riverpod provider for DNS-over-HTTPS configuration.
final dohConfigProvider =
    StateNotifierProvider<DohNotifier, DohConfig>((ref) {
  return DohNotifier();
});

/// Convenience provider watching active provider type.
final selectedDohProvider = Provider<DohProviderType>((ref) {
  return ref.watch(dohConfigProvider).selectedProvider;
});

/// Convenience provider watching tested latency map.
final dohLatenciesProvider = Provider<Map<DohProviderType, int?>>((ref) {
  return ref.watch(dohConfigProvider).latencyMap;
});

// ============================================================================
// Material 3 UI Widget: DohDnsSelectorCard
// ============================================================================

/// Clean, responsive Material 3 card allowing users to inspect and switch
/// DNS-over-HTTPS providers with live latency indicators and testing diagnostics.
class DohDnsSelectorCard extends ConsumerStatefulWidget {
  final EdgeInsetsGeometry padding;
  final bool showDiagnostics;

  const DohDnsSelectorCard({
    super.key,
    this.padding = const EdgeInsets.all(16.0),
    this.showDiagnostics = true,
  });

  @override
  ConsumerState<DohDnsSelectorCard> createState() => _DohDnsSelectorCardState();
}

class _DohDnsSelectorCardState extends ConsumerState<DohDnsSelectorCard> {
  final TextEditingController _customUrlController = TextEditingController();
  final TextEditingController _testHostController =
      TextEditingController(text: 'music.youtube.com');
  bool _isDiagnosticExpanded = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(dohConfigProvider);
    _customUrlController.text = config.customEndpoint;
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    _testHostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final config = ref.watch(dohConfigProvider);
    final notifier = ref.read(dohConfigProvider.notifier);

    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(
          color: tokens.divider.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Section: Icon, Title, and Encrypted Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                ),
                child: Icon(
                  Icons.dns_rounded,
                  color: tokens.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DNS-over-HTTPS (DoH)',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bypass ISP CDN throttling & encrypt DNS queries',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                isEncrypted: config.isEncrypted,
                tokens: tokens,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Provider Selector Chips (Cloudflare, Google, Quad9, System, Custom)
          Text(
            'SELECT PROVIDER',
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DohProviderType.values.map((provider) {
              final isSelected = config.selectedProvider == provider;
              final latency = config.latencyMap[provider];

              return _DohProviderChip(
                key: Key('doh_chip_${provider.id}'),
                provider: provider,
                isSelected: isSelected,
                latencyMs: latency,
                tokens: tokens,
                onTap: () => notifier.setProvider(provider),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // 3. Selected Provider Summary Card
          _ProviderDetailBox(
            provider: config.selectedProvider,
            tokens: tokens,
          ),

          // 4. Custom Endpoint Field (if Custom selected)
          if (config.selectedProvider == DohProviderType.custom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('doh_custom_url_field'),
                    controller: _customUrlController,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 13,
                      color: tokens.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Custom DoH Endpoint URL',
                      labelStyle: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                      hintText: 'https://dns.example.com/dns-query',
                      hintStyle: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12,
                        color: tokens.textMuted,
                      ),
                      filled: true,
                      fillColor: tokens.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('doh_save_custom_url_btn'),
                  onPressed: () {
                    notifier.setCustomEndpoint(_customUrlController.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Custom DoH endpoint saved.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // 5. Advanced Controls & Switches
          Container(
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('doh_fallback_switch'),
                  dense: true,
                  title: Text(
                    'Fallback to System DNS on Failure',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Prevents playback stalls if the DoH server is unreachable.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11,
                      color: tokens.textSecondary,
                    ),
                  ),
                  value: config.fallbackToSystem,
                  activeThumbColor: tokens.accent,
                  onChanged: (val) => notifier.setFallbackToSystem(val),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: tokens.divider.withValues(alpha: 0.08),
                ),
                SwitchListTile(
                  key: const Key('doh_cache_switch'),
                  dense: true,
                  title: Text(
                    'Local DNS Response Caching',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Eliminates repeat lookups during audio preloading.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11,
                      color: tokens.textSecondary,
                    ),
                  ),
                  value: config.cacheEnabled,
                  activeThumbColor: tokens.accent,
                  onChanged: (val) => notifier.setCacheEnabled(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 6. Action Bar: Test Latencies & Clear Cache
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('doh_test_latencies_btn'),
                onPressed:
                    config.isTestingLatency ? null : () => notifier.testLatencies(),
                icon: config.isTestingLatency
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.speed_rounded, size: 16),
                label: Text(
                  config.isTestingLatency ? 'Testing...' : 'Test Latencies',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.textPrimary,
                  side: BorderSide(
                    color: tokens.divider.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('doh_clear_cache_btn'),
                onPressed: config.cachedEntriesCount > 0
                    ? () => notifier.clearCache()
                    : null,
                icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                label: Text(
                  'Cache (${config.cachedEntriesCount})',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.textSecondary,
                  side: BorderSide(
                    color: tokens.divider.withValues(alpha: 0.1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                ),
              ),
              const Spacer(),
              if (widget.showDiagnostics)
                IconButton(
                  key: const Key('doh_toggle_diagnostics_btn'),
                  tooltip: 'DNS Diagnostic Tester',
                  icon: Icon(
                    _isDiagnosticExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.troubleshoot_rounded,
                    color: tokens.textSecondary,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isDiagnosticExpanded = !_isDiagnosticExpanded;
                    });
                  },
                ),
            ],
          ),

          // 7. Expandable DNS Diagnostic Tester
          if (widget.showDiagnostics && _isDiagnosticExpanded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.surfaceHighlight,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CANARY DOMAIN RESOLUTION TESTER',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: tokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('doh_test_domain_input'),
                          controller: _testHostController,
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12,
                            color: tokens.textPrimary,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Enter domain (e.g. i.ytimg.com)',
                            filled: true,
                            fillColor: tokens.surfaceElevated,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        key: const Key('doh_resolve_test_btn'),
                        onPressed: config.isResolving
                            ? null
                            : () => notifier.testResolve(_testHostController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                          ),
                        ),
                        child: config.isResolving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Resolve', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (config.lastLookupResult != null) ...[
                    const SizedBox(height: 10),
                    _DiagnosticResultBox(
                      result: config.lastLookupResult!,
                      tokens: tokens,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Internal Presentation Subcomponents
// ============================================================================

class _DohProviderChip extends StatelessWidget {
  final DohProviderType provider;
  final bool isSelected;
  final int? latencyMs;
  final AppTokens tokens;
  final VoidCallback onTap;

  const _DohProviderChip({
    super.key,
    required this.provider,
    required this.isSelected,
    this.latencyMs,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color latencyColor = tokens.textMuted;
    if (latencyMs != null) {
      if (latencyMs! < 50) {
        latencyColor = const Color(0xFF4CAF50); // Green
      } else if (latencyMs! < 120) {
        latencyColor = const Color(0xFFFFB300); // Amber
      } else {
        latencyColor = const Color(0xFFEF5350); // Red
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.accent.withValues(alpha: 0.18)
              : tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          border: Border.all(
            color: isSelected
                ? tokens.accent
                : tokens.divider.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              provider.icon,
              size: 15,
              color: isSelected ? tokens.accent : tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              provider.displayName,
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? tokens.textPrimary : tokens.textSecondary,
              ),
            ),
            if (latencyMs != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: latencyColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${latencyMs}ms',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: latencyColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isEncrypted;
  final AppTokens tokens;

  const _StatusPill({
    required this.isEncrypted,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isEncrypted ? const Color(0xFF4CAF50) : const Color(0xFF757575);
    final text = isEncrypted ? 'Encrypted' : 'System';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEncrypted ? Icons.lock_rounded : Icons.public_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderDetailBox extends StatelessWidget {
  final DohProviderType provider;
  final AppTokens tokens;

  const _ProviderDetailBox({
    required this.provider,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                provider.fullTitle,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.surfaceHighlight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  provider.ipDescription,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            provider.description,
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 11.5,
              color: tokens.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticResultBox extends StatelessWidget {
  final DnsLookupResult result;
  final AppTokens tokens;

  const _DiagnosticResultBox({
    required this.result,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.isSuccess) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Error: ${result.errorMessage ?? "Unknown resolution failure"}',
          style: TextStyle(
            fontSize: 11,
            color: tokens.error,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Host: ${result.host}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                result.isFromCache
                    ? 'Cached (${result.ttl}s TTL)'
                    : '${result.latencyMs}ms (${result.provider.displayName})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: result.isFromCache
                      ? const Color(0xFF4CAF50)
                      : tokens.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            result.addresses.join(', '),
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
