import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'biquad_filter.dart';
import 'parametric_eq.dart';

/// Single headphone measurement index entry from the ndellagrotte/AutoEq repository.
class AutoEqModelEntry {
  final String modelName;
  final String measurer;
  final String formFactor;
  final String path;
  final String sourceRepo;

  const AutoEqModelEntry({
    required this.modelName,
    required this.measurer,
    required this.formFactor,
    required this.path,
    this.sourceRepo = 'ndellagrotte/AutoEq',
  });

  /// Canonical download URL for raw ParametricEQ.txt
  String get rawUrl =>
      'https://raw.githubusercontent.com/$sourceRepo/master/${Uri.encodeFull(path)}';

  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'measurer': measurer,
        'formFactor': formFactor,
        'path': path,
        'sourceRepo': sourceRepo,
      };

  factory AutoEqModelEntry.fromJson(Map<String, dynamic> json) {
    return AutoEqModelEntry(
      modelName: json['modelName'] as String? ?? 'Unknown Model',
      measurer: json['measurer'] as String? ?? 'unknown',
      formFactor: json['formFactor'] as String? ?? 'over-ear',
      path: json['path'] as String? ?? '',
      sourceRepo: json['sourceRepo'] as String? ?? 'ndellagrotte/AutoEq',
    );
  }

  @override
  String toString() => '$modelName ($measurer - $formFactor)';
}

/// Parsed AutoEq parametric equalization profile with preamp and filter bands.
class AutoEqProfile {
  final String modelName;
  final String measurer;
  final double preampDb;
  final List<EqBand> bands;
  final String rawText;

  const AutoEqProfile({
    required this.modelName,
    required this.measurer,
    required this.preampDb,
    required this.bands,
    required this.rawText,
  });

  /// Configures a target [ParametricEqualizer] with this profile.
  void applyTo(ParametricEqualizer equalizer) {
    equalizer.setBands(bands, preampDb: preampDb);
    equalizer.enabled = true;
  }

  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'measurer': measurer,
        'preampDb': preampDb,
        'bands': bands.map((b) => b.toJson()).toList(),
        'rawText': rawText,
      };

  factory AutoEqProfile.fromJson(Map<String, dynamic> json) {
    return AutoEqProfile(
      modelName: json['modelName'] as String? ?? '',
      measurer: json['measurer'] as String? ?? '',
      preampDb: (json['preampDb'] as num?)?.toDouble() ?? 0.0,
      bands: (json['bands'] as List<dynamic>?)
              ?.map((e) => EqBand.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      rawText: json['rawText'] as String? ?? '',
    );
  }
}

/// AutoEq search and parsing service connecting to ndellagrotte/AutoEq GitHub index.
///
/// Discovers and indexes 5,000+ calibrated headphone compensation curves.
/// Includes 24-hour local caching and fallback catalog.
class AutoEqService {
  static final AutoEqService instance = AutoEqService();

  http.Client? _client;
  http.Client get _httpClient => _client ??= http.Client();

  /// Inject custom HTTP client for unit tests / mocking
  void setClient(http.Client client) {
    _client = client;
  }

  // In-memory model index and profile caches
  List<AutoEqModelEntry>? _cachedIndex;
  DateTime? _indexCachedAt;
  final Map<String, AutoEqProfile> _profileMemoryCache = {};

  static const Duration indexCacheTtl = Duration(hours: 24);
  static const String repoFullName = 'ndellagrotte/AutoEq';
  static const String gitTreeApiUrl =
      'https://api.github.com/repos/$repoFullName/git/trees/master?recursive=1';

  /// Parses `ParametricEQ.txt` configuration string into an [AutoEqProfile].
  ///
  /// Supports AutoEq / EqualizerAPO format:
  /// Preamp: -6.2 dB
  /// Filter 1: ON LSC Fc 105 Hz Gain 6.2 dB Q 0.70
  /// Filter 2: ON PK Fc 180 Hz Gain -4.0 dB Q 0.56
  /// Filter 6: ON HSC Fc 10000 Hz Gain 1.2 dB Q 0.70
  static AutoEqProfile parseParametricEqText(
    String text, {
    String modelName = 'Custom AutoEq',
    String measurer = 'AutoEq',
  }) {
    double preampDb = 0.0;
    final bands = <EqBand>[];

    final lines = text.split('\n');

    // Preamp regex: Preamp: -6.2 dB
    final preampRegex = RegExp(
      r'Preamp:\s*([+-]?\d+(?:\.\d+)?)\s*dB',
      caseSensitive: false,
    );

    // Filter band regex: Filter 1: ON PK Fc 180 Hz Gain -4.0 dB Q 0.56
    // Group 1: index, Group 2: ON/OFF, Group 3: type, Group 4: Fc, Group 5: Gain, Group 6: Q
    final filterRegex = RegExp(
      r'Filter\s+(\d+):\s*(ON|OFF)\s+([A-Za-z0-9_]+)\s+Fc\s+([0-9.]+)\s*Hz\s+Gain\s+([+-]?[0-9.]+)\s*dB\s+Q\s+([0-9.]+)',
      caseSensitive: false,
    );

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final preampMatch = preampRegex.firstMatch(line);
      if (preampMatch != null) {
        preampDb = double.tryParse(preampMatch.group(1)!) ?? 0.0;
        continue;
      }

      final filterMatch = filterRegex.firstMatch(line);
      if (filterMatch != null) {
        final index = int.tryParse(filterMatch.group(1)!) ?? (bands.length + 1);
        final state = filterMatch.group(2)!.toUpperCase();
        final rawType = filterMatch.group(3)!.toUpperCase();
        final fc = double.tryParse(filterMatch.group(4)!) ?? 1000.0;
        final gain = double.tryParse(filterMatch.group(5)!) ?? 0.0;
        final q = double.tryParse(filterMatch.group(6)!) ?? 1.0;

        final BiquadFilterType filterType;
        if (rawType == 'PK' || rawType == 'PEAK' || rawType == 'PEAKING') {
          filterType = BiquadFilterType.peaking;
        } else if (rawType == 'LSC' ||
            rawType == 'LOW_SHELF' ||
            rawType == 'LOWSHELF' ||
            rawType == 'LS') {
          filterType = BiquadFilterType.lowShelf;
        } else if (rawType == 'HSC' ||
            rawType == 'HIGH_SHELF' ||
            rawType == 'HIGHSHELF' ||
            rawType == 'HS') {
          filterType = BiquadFilterType.highShelf;
        } else if (rawType == 'LPF' || rawType == 'LOW_PASS') {
          filterType = BiquadFilterType.lowPass;
        } else if (rawType == 'HPF' || rawType == 'HIGH_PASS') {
          filterType = BiquadFilterType.highPass;
        } else {
          filterType = BiquadFilterType.peaking;
        }

        bands.add(EqBand(
          index: index - 1,
          enabled: state == 'ON',
          type: filterType,
          frequency: fc,
          gainDb: gain,
          q: q,
        ));
      }
    }

    return AutoEqProfile(
      modelName: modelName,
      measurer: measurer,
      preampDb: preampDb,
      bands: bands,
      rawText: text,
    );
  }

  /// Gets directory used for caching AutoEq indexes and profiles.
  Future<Directory?> _getCacheDirectory() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final cacheDir = Directory(p.join(appDir.path, 'autoeq_cache'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      return cacheDir;
    } catch (_) {
      // In non-flutter/desktop test environments without plugin mock
      return null;
    }
  }

  /// Loads cached index from local disk storage.
  Future<List<AutoEqModelEntry>?> _loadIndexFromDisk() async {
    try {
      final dir = await _getCacheDirectory();
      if (dir == null) return null;

      final file = File(p.join(dir.path, 'index.json'));
      if (!await file.exists()) return null;

      final contents = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(contents);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);

      if (DateTime.now().difference(timestamp) > indexCacheTtl) {
        // Cache expired
        return null;
      }

      final List<dynamic> entriesJson = data['entries'] as List<dynamic>;
      return entriesJson
          .map((e) => AutoEqModelEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Saves model index to local disk storage.
  Future<void> _saveIndexToDisk(List<AutoEqModelEntry> entries) async {
    try {
      final dir = await _getCacheDirectory();
      if (dir == null) return;

      final file = File(p.join(dir.path, 'index.json'));
      final data = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'entries': entries.map((e) => e.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // Ignore cache write errors
    }
  }

  /// Fetches and caches the GitHub git tree index containing 5,000+ headphone models.
  Future<List<AutoEqModelEntry>> fetchIndex({bool forceRefresh = false}) async {
    // 1. Check in-memory cache
    if (!forceRefresh &&
        _cachedIndex != null &&
        _indexCachedAt != null &&
        DateTime.now().difference(_indexCachedAt!) < indexCacheTtl) {
      return _cachedIndex!;
    }

    // 2. Check local disk cache
    if (!forceRefresh) {
      final diskEntries = await _loadIndexFromDisk();
      if (diskEntries != null && diskEntries.isNotEmpty) {
        _cachedIndex = diskEntries;
        _indexCachedAt = DateTime.now();
        return diskEntries;
      }
    }

    // 3. Request fresh tree from GitHub API
    try {
      final response = await _httpClient.get(
        Uri.parse(gitTreeApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Softify/3.0.5 AutoEq-Indexer',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> treeJson = jsonDecode(response.body);
        final List<dynamic> tree = treeJson['tree'] as List<dynamic>? ?? [];

        final entries = <AutoEqModelEntry>[];

        for (final item in tree) {
          final path = item['path'] as String? ?? '';
          if (path.startsWith('results/') && path.endsWith('ParametricEQ.txt')) {
            // Path structure: results/<measurer>/<formFactor>/<modelName>/<fileName>
            final segments = path.split('/');
            if (segments.length >= 4) {
              final measurer = segments[1];
              final formFactor = segments[2];
              // Model name is either segment[3] or stripped filename
              final modelFolder = segments[3];
              entries.add(AutoEqModelEntry(
                modelName: modelFolder,
                measurer: measurer,
                formFactor: formFactor,
                path: path,
              ));
            }
          }
        }

        if (entries.isNotEmpty) {
          _cachedIndex = entries;
          _indexCachedAt = DateTime.now();
          await _saveIndexToDisk(entries);
          return entries;
        }
      }
    } catch (_) {
      // Fall through to offline fallback
    }

    // 4. Return expired in-memory or fallback catalog if network/rate-limited
    if (_cachedIndex != null && _cachedIndex!.isNotEmpty) {
      return _cachedIndex!;
    }

    final fallback = _getBundledFallbackCatalog();
    _cachedIndex = fallback;
    _indexCachedAt = DateTime.now();
    return fallback;
  }

  /// Searches headphone models by query with token matching and relevance ranking.
  Future<List<AutoEqModelEntry>> searchModels(
    String query, {
    int limit = 50,
    String? measurerFilter,
    String? formFactorFilter,
  }) async {
    final catalog = await fetchIndex();
    final trimmed = query.trim().toLowerCase();

    if (trimmed.isEmpty) {
      return catalog.take(limit).toList();
    }

    final queryTokens = trimmed.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    final scored = <MapEntry<AutoEqModelEntry, int>>[];

    for (final entry in catalog) {
      if (measurerFilter != null &&
          entry.measurer.toLowerCase() != measurerFilter.toLowerCase()) {
        continue;
      }
      if (formFactorFilter != null &&
          entry.formFactor.toLowerCase() != formFactorFilter.toLowerCase()) {
        continue;
      }

      final nameLower = entry.modelName.toLowerCase();
      final measurerLower = entry.measurer.toLowerCase();

      int score = 0;

      // Exact match bonus
      if (nameLower == trimmed) {
        score += 1000;
      } else if (nameLower.startsWith(trimmed)) {
        score += 500;
      }

      // Check all query tokens
      bool allTokensMatched = true;
      for (final token in queryTokens) {
        if (nameLower.contains(token)) {
          score += 100;
        } else if (measurerLower.contains(token)) {
          score += 30;
        } else {
          allTokensMatched = false;
          break;
        }
      }

      if (allTokensMatched) {
        // Prefer highly respected measurers in scoring tie-breaks
        if (measurerLower == 'oratory1990') score += 25;
        if (measurerLower == 'crinacle') score += 20;
        if (measurerLower == 'rtings') score += 15;

        scored.add(MapEntry(entry, score));
      }
    }

    // Sort descending by relevance score
    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.map((e) => e.key).take(limit).toList();
  }

  /// Downloads and parses the [AutoEqProfile] for a given [AutoEqModelEntry].
  Future<AutoEqProfile> fetchProfile(AutoEqModelEntry entry) async {
    // 1. Check memory cache
    if (_profileMemoryCache.containsKey(entry.path)) {
      return _profileMemoryCache[entry.path]!;
    }

    // 2. Check disk cache
    final dir = await _getCacheDirectory();
    File? profileFile;
    if (dir != null) {
      final safeFileName = entry.path.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      profileFile = File(p.join(dir.path, 'profiles', safeFileName));
      if (await profileFile.exists()) {
        final text = await profileFile.readAsString();
        final profile = parseParametricEqText(
          text,
          modelName: entry.modelName,
          measurer: entry.measurer,
        );
        _profileMemoryCache[entry.path] = profile;
        return profile;
      }
    }

    // 3. Download from raw GitHub URL
    final response = await _httpClient.get(
      Uri.parse(entry.rawUrl),
      headers: {'User-Agent': 'Softify/3.0.5 AutoEq-Downloader'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      // If download fails, check bundled profile or throw
      final bundledText = _getBundledProfileText(entry.modelName);
      if (bundledText != null) {
        return parseParametricEqText(
          bundledText,
          modelName: entry.modelName,
          measurer: entry.measurer,
        );
      }
      throw HttpException(
        'Failed to download AutoEq profile for ${entry.modelName} (status ${response.statusCode})',
      );
    }

    final rawText = response.body;
    final profile = parseParametricEqText(
      rawText,
      modelName: entry.modelName,
      measurer: entry.measurer,
    );

    // Save to caches
    _profileMemoryCache[entry.path] = profile;
    if (profileFile != null) {
      try {
        await profileFile.parent.create(recursive: true);
        await profileFile.writeAsString(rawText);
      } catch (_) {}
    }

    return profile;
  }

  /// Curated fallback catalog containing top 30+ popular headphone models
  /// available instantly even offline or under GitHub API rate limiting.
  List<AutoEqModelEntry> _getBundledFallbackCatalog() {
    const fallbackList = [
      ('Sony WH-1000XM4', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Sony WH-1000XM4/Sony WH-1000XM4 ParametricEQ.txt'),
      ('Sony WH-1000XM5', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Sony WH-1000XM5/Sony WH-1000XM5 ParametricEQ.txt'),
      ('Sony WF-1000XM4', 'crinacle', 'in-ear', 'results/crinacle/in-ear/Sony WF-1000XM4/Sony WF-1000XM4 ParametricEQ.txt'),
      ('Apple AirPods Pro 2', 'crinacle', 'in-ear', 'results/crinacle/in-ear/Apple AirPods Pro 2/Apple AirPods Pro 2 ParametricEQ.txt'),
      ('Apple AirPods Max', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Apple AirPods Max/Apple AirPods Max ParametricEQ.txt'),
      ('Sennheiser HD 600', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Sennheiser HD 600/Sennheiser HD 600 ParametricEQ.txt'),
      ('Sennheiser HD 650', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Sennheiser HD 650/Sennheiser HD 650 ParametricEQ.txt'),
      ('Sennheiser HD 560S', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Sennheiser HD 560S/Sennheiser HD 560S ParametricEQ.txt'),
      ('Sennheiser HD 800 S', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Sennheiser HD 800 S/Sennheiser HD 800 S ParametricEQ.txt'),
      ('Beyerdynamic DT 770 Pro 80 Ohm', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Beyerdynamic DT 770 Pro 80 Ohm/Beyerdynamic DT 770 Pro 80 Ohm ParametricEQ.txt'),
      ('Beyerdynamic DT 990 Pro 250 Ohm', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Beyerdynamic DT 990 Pro 250 Ohm/Beyerdynamic DT 990 Pro 250 Ohm ParametricEQ.txt'),
      ('Audio-Technica ATH-M50x', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Audio-Technica ATH-M50x/Audio-Technica ATH-M50x ParametricEQ.txt'),
      ('Moondrop Aria', 'crinacle', 'in-ear', 'results/crinacle/in-ear/Moondrop Aria/Moondrop Aria ParametricEQ.txt'),
      ('Moondrop Blessing 2:Dusk', 'crinacle', 'in-ear', 'results/crinacle/in-ear/Moondrop Blessing 2:Dusk/Moondrop Blessing 2:Dusk ParametricEQ.txt'),
      ('Moondrop Chu', 'crinacle', 'in-ear', 'results/crinacle/in-ear/Moondrop Chu/Moondrop Chu ParametricEQ.txt'),
      ('7Hz Salnotes Zero', 'crinacle', 'in-ear', 'results/crinacle/in-ear/7Hz Salnotes Zero/7Hz Salnotes Zero ParametricEQ.txt'),
      ('Truthear x Crinacle Zero RED', 'crinacle', 'in-ear', 'results/crinacle/in-ear/Truthear x Crinacle Zero RED/Truthear x Crinacle Zero RED ParametricEQ.txt'),
      ('Truthear Hexa', 'crinacle', 'in-ear', 'results/crinacle/in-ear/Truthear Hexa/Truthear Hexa ParametricEQ.txt'),
      ('Tangzu Wan\'er S.G', 'crinacle', 'in-ear', 'results/crinacle/in-ear/Tangzu Wan\'er S.G/Tangzu Wan\'er S.G ParametricEQ.txt'),
      ('Hifiman Sundara', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Hifiman Sundara/Hifiman Sundara ParametricEQ.txt'),
      ('Hifiman Edition XS', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Hifiman Edition XS/Hifiman Edition XS ParametricEQ.txt'),
      ('Bose QuietComfort 35 II', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Bose QuietComfort 35 II/Bose QuietComfort 35 II ParametricEQ.txt'),
      ('Bose QuietComfort 45', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Bose QuietComfort 45/Bose QuietComfort 45 ParametricEQ.txt'),
      ('AKG K240 MKII', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/AKG K240 MKII/AKG K240 MKII ParametricEQ.txt'),
      ('AKG K371', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/AKG K371/AKG K371 ParametricEQ.txt'),
      ('Philips Fidelio X2HR', 'oratory1990', 'over-ear', 'results/oratory1990/over-ear/Philips Fidelio X2HR/Philips Fidelio X2HR ParametricEQ.txt'),
      ('Koss Porta Pro', 'oratory1990', 'on-ear', 'results/oratory1990/on-ear/Koss Porta Pro/Koss Porta Pro ParametricEQ.txt'),
    ];

    return fallbackList
        .map((item) => AutoEqModelEntry(
              modelName: item.$1,
              measurer: item.$2,
              formFactor: item.$3,
              path: item.$4,
            ))
        .toList();
  }

  /// Bundled reference profile text for offline testing and fallbacks.
  String? _getBundledProfileText(String modelName) {
    if (modelName.contains('AKG K240 MKII')) {
      return '''Preamp: -6.2 dB
Filter 1: ON LSC Fc 105 Hz Gain 6.2 dB Q 0.70
Filter 2: ON PK Fc 180 Hz Gain -4.0 dB Q 0.56
Filter 3: ON PK Fc 4180 Hz Gain 5.6 dB Q 3.17
Filter 4: ON PK Fc 1605 Hz Gain 4.7 dB Q 3.06
Filter 5: ON PK Fc 56 Hz Gain 1.5 dB Q 1.88
Filter 6: ON HSC Fc 10000 Hz Gain 1.2 dB Q 0.70
Filter 7: ON PK Fc 2807 Hz Gain -2.7 dB Q 3.81
Filter 8: ON PK Fc 6678 Hz Gain -2.4 dB Q 6.00
Filter 9: ON PK Fc 3488 Hz Gain 2.5 dB Q 6.00
Filter 10: ON PK Fc 558 Hz Gain 1.5 dB Q 6.00''';
    }
    if (modelName.contains('Sony WH-1000XM4')) {
      return '''Preamp: -6.5 dB
Filter 1: ON PK Fc 26 Hz Gain -4.8 dB Q 1.41
Filter 2: ON PK Fc 72 Hz Gain -2.2 dB Q 0.82
Filter 3: ON PK Fc 167 Hz Gain -4.3 dB Q 1.83
Filter 4: ON PK Fc 632 Hz Gain 2.1 dB Q 2.01
Filter 5: ON PK Fc 1282 Hz Gain -3.8 dB Q 2.21
Filter 6: ON PK Fc 2855 Hz Gain 3.8 dB Q 2.11
Filter 7: ON PK Fc 5938 Hz Gain -5.1 dB Q 3.51
Filter 8: ON HSC Fc 10000 Hz Gain -2.0 dB Q 0.70''';
    }
    return null;
  }
}
