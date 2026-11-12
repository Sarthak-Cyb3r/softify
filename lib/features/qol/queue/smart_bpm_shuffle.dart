// ============================================================================
// Softify - Smart Shuffle (BPM & Harmonic Transition Engine)
// Feature 11: Musical Key & Tempo Coherent Queue Reordering
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/track.dart';
import '../../../data/player/softify_audio_handler.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';
import '../../../presentation/widgets/shared/app_surface.dart';
import '../../../presentation/widgets/shared/app_toast.dart';

// ============================================================================
// SharedPreferences Persistence Engine
// ============================================================================

const String kSmartShuffleActivePrefKey = 'softify_smart_shuffle_active';
const String kSmartShuffleModePrefKey = 'softify_smart_shuffle_mode';
const String kSmartShuffleRandomnessPrefKey = 'softify_smart_shuffle_randomness';

/// Self-contained persistent storage layer matching SharedPreferences semantics.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _preferenceStore;
  final File? _storageFile;

  SharedPreferences._(this._preferenceStore, this._storageFile);

  /// Injects initial mock values for unit and widget test suites.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Loads or initializes shared preferences storage.
  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    if (_mockInitialValues != null) {
      _instance = SharedPreferences._(
        Map<String, Object>.from(_mockInitialValues!),
        null,
      );
      return _instance!;
    }

    final store = <String, Object>{};
    File? file;
    try {
      file = _resolveStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (value != null) {
                store[key.toString()] = value as Object;
              }
            });
          }
        }
      }
    } catch (_) {
      // Memory fallback if filesystem access fails
    }

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  static File? _resolveStorageFile() {
    try {
      final userHome = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Platform.environment['LOCALAPPDATA'];
      if (userHome != null && userHome.isNotEmpty) {
        final dir = Directory('$userHome/.softify');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('${dir.path}/shared_preferences.json');
      }
      return File('.softify_shared_preferences.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist() async {
    final file = _storageFile;
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_preferenceStore);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  bool? getBool(String key) {
    final val = _preferenceStore[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  String? getString(String key) {
    final val = _preferenceStore[key];
    return val?.toString();
  }

  Future<bool> setString(String key, String value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }

  double? getDouble(String key) {
    final val = _preferenceStore[key];
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  Future<bool> setDouble(String key, double value) async {
    _preferenceStore[key] = value;
    await _persist();
    return true;
  }
}

// ============================================================================
// Harmonic Mixing & Camelot Wheel Models
// ============================================================================

/// Musical key representation mapped to the Camelot Wheel (1A - 12A, 1B - 12B).
///
/// In harmonic mixing:
/// - Letter 'A' represents Minor keys (e.g., 8A = A minor).
/// - Letter 'B' represents Major keys (e.g., 8B = C major).
/// - Adjacent keys (±1 step around the 12-hour wheel) are harmonically compatible.
/// - Relative major/minor keys (same number, different letter) share the same key signature.
@immutable
class CamelotKey {
  final int number; // 1..12
  final String letter; // 'A' (Minor) or 'B' (Major)

  const CamelotKey(this.number, this.letter)
      : assert(number >= 1 && number <= 12, 'Camelot number must be between 1 and 12'),
        assert(letter == 'A' || letter == 'B', 'Camelot letter must be A or B');

  /// Camelot code representation, e.g. "8A" or "11B".
  String get code => '$number$letter';

  /// Human-readable standard musical key name.
  String get musicalName {
    if (letter == 'A') {
      return switch (number) {
        1 => 'Ab minor',
        2 => 'Eb minor',
        3 => 'Bb minor',
        4 => 'F minor',
        5 => 'C minor',
        6 => 'G minor',
        7 => 'D minor',
        8 => 'A minor',
        9 => 'E minor',
        10 => 'B minor',
        11 => 'F# minor',
        12 => 'Db minor',
        _ => '$number$letter',
      };
    } else {
      return switch (number) {
        1 => 'B major',
        2 => 'F# major',
        3 => 'Db major',
        4 => 'Ab major',
        5 => 'Eb major',
        6 => 'Bb major',
        7 => 'F major',
        8 => 'C major',
        9 => 'G major',
        10 => 'D major',
        11 => 'A major',
        12 => 'E major',
        _ => '$number$letter',
      };
    }
  }

  /// Parses a Camelot code (e.g. "8A", "11B") or standard pitch key name (e.g. "Am", "C#m", "G").
  static CamelotKey? parse(String? input) {
    if (input == null) return null;
    final clean = input.trim();
    if (clean.isEmpty) return null;

    // Check direct Camelot format like "8A", "8a", "12B"
    final camelotRegex = RegExp(r'^([1-9]|1[0-2])\s*([ABab])$');
    final match = camelotRegex.firstMatch(clean);
    if (match != null) {
      final numVal = int.parse(match.group(1)!);
      final letterVal = match.group(2)!.toUpperCase();
      return CamelotKey(numVal, letterVal);
    }

    // Standard musical pitch name matching
    final pitchLower = clean.toLowerCase().replaceAll(' ', '');
    return switch (pitchLower) {
      // Minor keys
      'abm' || 'g#m' || 'abminor' || 'g#minor' => const CamelotKey(1, 'A'),
      'ebm' || 'd#m' || 'ebminor' || 'd#minor' => const CamelotKey(2, 'A'),
      'bbm' || 'a#m' || 'bbminor' || 'a#minor' => const CamelotKey(3, 'A'),
      'fm' || 'fminor' => const CamelotKey(4, 'A'),
      'cm' || 'cminor' => const CamelotKey(5, 'A'),
      'gm' || 'gminor' => const CamelotKey(6, 'A'),
      'dm' || 'dminor' => const CamelotKey(7, 'A'),
      'am' || 'aminor' => const CamelotKey(8, 'A'),
      'em' || 'eminor' => const CamelotKey(9, 'A'),
      'bm' || 'bminor' => const CamelotKey(10, 'A'),
      'f#m' || 'gbm' || 'f#minor' || 'gbminor' => const CamelotKey(11, 'A'),
      'c#m' || 'dbm' || 'c#minor' || 'dbminor' => const CamelotKey(12, 'A'),

      // Major keys
      'b' || 'bmaj' || 'bmajor' => const CamelotKey(1, 'B'),
      'f#' || 'gb' || 'f#maj' || 'gbmaj' || 'f#major' || 'gbmajor' => const CamelotKey(2, 'B'),
      'db' || 'c#' || 'dbmaj' || 'c#maj' || 'dbmajor' || 'c#major' => const CamelotKey(3, 'B'),
      'ab' || 'g#' || 'abmaj' || 'g#maj' || 'abmajor' || 'g#major' => const CamelotKey(4, 'B'),
      'eb' || 'd#' || 'ebmaj' || 'd#maj' || 'ebmajor' || 'd#major' => const CamelotKey(5, 'B'),
      'bb' || 'a#' || 'bbmaj' || 'a#maj' || 'bbmajor' || 'a#major' => const CamelotKey(6, 'B'),
      'f' || 'fmaj' || 'fmajor' => const CamelotKey(7, 'B'),
      'c' || 'cmaj' || 'cmajor' => const CamelotKey(8, 'B'),
      'g' || 'gmaj' || 'gmajor' => const CamelotKey(9, 'B'),
      'd' || 'dmaj' || 'dmajor' => const CamelotKey(10, 'B'),
      'a' || 'amaj' || 'amajor' => const CamelotKey(11, 'B'),
      'e' || 'emaj' || 'emajor' => const CamelotKey(12, 'B'),

      _ => null,
    };
  }

  /// Calculates harmonic distance to [other] on the Camelot wheel.
  ///
  /// Returns:
  /// - 0.0 for exact key match.
  /// - 1.0 for perfect harmonic transition (adjacent ±1 hour or relative major/minor).
  /// - 2.0 to 6.0 for wider key jumps.
  double harmonicDistanceTo(CamelotKey other) {
    final diff = (number - other.number).abs();
    final clockSteps = math.min(diff, 12 - diff);

    if (letter == other.letter) {
      if (clockSteps == 0) return 0.0;
      if (clockSteps == 1) return 1.0;
      return clockSteps * 1.4;
    } else {
      // Relative major/minor transition (e.g. 8A to 8B)
      if (clockSteps == 0) return 1.0;
      if (clockSteps == 1) return 2.0;
      return (clockSteps + 1) * 1.5;
    }
  }

  /// Whether transition to [other] is musically harmonious (distance <= 1.0).
  bool isHarmonicallyCompatible(CamelotKey other) => harmonicDistanceTo(other) <= 1.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CamelotKey &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          letter == other.letter;

  @override
  int get hashCode => Object.hash(number, letter);

  @override
  String toString() => code;
}

// ============================================================================
// Track Audio Features & Transition Metrics
// ============================================================================

/// Musical acoustic features required for smart transitions.
@immutable
class TrackAudioFeatures {
  final String trackId;
  final double bpm;
  final CamelotKey? key;
  final double energy; // 0.0 (ambient) to 1.0 (peak intensity)
  final double danceability; // 0.0 to 1.0
  final double valence; // 0.0 (somber) to 1.0 (euphoric)
  final bool isEstimated;

  const TrackAudioFeatures({
    required this.trackId,
    required this.bpm,
    this.key,
    this.energy = 0.5,
    this.danceability = 0.5,
    this.valence = 0.5,
    this.isEstimated = true,
  });

  TrackAudioFeatures copyWith({
    String? trackId,
    double? bpm,
    CamelotKey? key,
    double? energy,
    double? danceability,
    double? valence,
    bool? isEstimated,
  }) {
    return TrackAudioFeatures(
      trackId: trackId ?? this.trackId,
      bpm: bpm ?? this.bpm,
      key: key ?? this.key,
      energy: energy ?? this.energy,
      danceability: danceability ?? this.danceability,
      valence: valence ?? this.valence,
      isEstimated: isEstimated ?? this.isEstimated,
    );
  }

  @override
  String toString() =>
      'TrackAudioFeatures(id: $trackId, bpm: ${bpm.toStringAsFixed(1)}, key: ${key?.code}, energy: ${energy.toStringAsFixed(2)})';
}

/// Supported transition profile modes for smart shuffle.
enum SmartShuffleMode {
  harmonicFlow(
    title: 'Harmonic Flow',
    subtitle: 'Prioritizes Camelot key matches with smooth BPM steps',
    icon: Icons.waves_rounded,
  ),
  bpmMatch(
    title: 'BPM Alignment',
    subtitle: 'Prioritizes tight tempo matching and half-time transitions',
    icon: Icons.speed_rounded,
  ),
  energyRamp(
    title: 'Energy Build-up',
    subtitle: 'Ascends energy and tempo progressively for building momentum',
    icon: Icons.trending_up_rounded,
  ),
  balancedTransition(
    title: 'Balanced DJ Mix',
    subtitle: 'Equal harmonic compatibility and tempo continuity',
    icon: Icons.auto_awesome_rounded,
  );

  final String title;
  final String subtitle;
  final IconData icon;

  const SmartShuffleMode({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  static SmartShuffleMode fromString(String? val) {
    if (val == null) return SmartShuffleMode.harmonicFlow;
    return SmartShuffleMode.values.firstWhere(
      (m) => m.name.toLowerCase() == val.toLowerCase(),
      orElse: () => SmartShuffleMode.harmonicFlow,
    );
  }
}

/// Detailed evaluation score between two consecutive tracks.
@immutable
class TransitionScore {
  final double totalCost;
  final double bpmDelta;
  final double harmonicDistance;
  final double energyDelta;
  final bool isHarmonicMatch;
  final bool isTempoMatch;

  const TransitionScore({
    required this.totalCost,
    required this.bpmDelta,
    required this.harmonicDistance,
    required this.energyDelta,
    required this.isHarmonicMatch,
    required this.isTempoMatch,
  });
}

/// Aggregated transition health for a reordered queue.
@immutable
class TransitionQualitySummary {
  final int totalTracks;
  final int totalTransitions;
  final double averageBpmDelta;
  final double harmonicCompatibilityPercent;
  final double averageTransitionCost;

  const TransitionQualitySummary({
    required this.totalTracks,
    required this.totalTransitions,
    required this.averageBpmDelta,
    required this.harmonicCompatibilityPercent,
    required this.averageTransitionCost,
  });

  String get summaryText {
    if (totalTransitions == 0) return 'Single track in queue';
    final bpmStr = averageBpmDelta.toStringAsFixed(1);
    final harmStr = harmonicCompatibilityPercent.toStringAsFixed(0);
    return 'Avg BPM Δ: $bpmStr | $harmStr% harmonic match';
  }
}

// ============================================================================
// Core Algorithm: SmartBpmShuffleAlgorithm
// ============================================================================

/// Pure algorithm for harmonic and BPM proximity queue reordering.
class SmartBpmShuffleAlgorithm {
  const SmartBpmShuffleAlgorithm._();

  /// Estimates audio features deterministically using track metadata when explicit
  /// acoustic analysis is unavailable.
  static TrackAudioFeatures estimateFeatures(Track track) {
    // Generate stable hash from track identifier, title, artist, and duration
    final seedString = '${track.id}_${track.title}_${track.artist}_${track.duration.inSeconds}';
    int hash = 5381;
    for (int i = 0; i < seedString.length; i++) {
      hash = ((hash << 5) + hash) + seedString.codeUnitAt(i);
      hash &= 0x7FFFFFFF;
    }

    final rng = math.Random(hash);

    // 1. Analyze title/genre text cues for tempo & energy heuristics
    final lowerTitle = track.title.toLowerCase();
    final lowerArtist = track.artist.toLowerCase();
    final combined = '$lowerTitle $lowerArtist';

    double baseBpm = 95.0 + (rng.nextDouble() * 45.0); // 95 - 140 base
    double baseEnergy = 0.45 + (rng.nextDouble() * 0.40); // 0.45 - 0.85 base

    // Low energy / slower tempo keywords
    if (combined.contains('acoustic') ||
        combined.contains('lo-fi') ||
        combined.contains('lofi') ||
        combined.contains('ambient') ||
        combined.contains('slow') ||
        combined.contains('piano') ||
        combined.contains('sleep') ||
        combined.contains('chill') ||
        combined.contains('ballad')) {
      baseBpm = 75.0 + (rng.nextDouble() * 25.0);
      baseEnergy = 0.20 + (rng.nextDouble() * 0.28);
    }
    // High energy / faster tempo keywords
    else if (combined.contains('remix') ||
        combined.contains('club') ||
        combined.contains('dance') ||
        combined.contains('techno') ||
        combined.contains('house') ||
        combined.contains('drum and bass') ||
        combined.contains('dnb') ||
        combined.contains('dubstep') ||
        combined.contains('hardstyle') ||
        combined.contains('rock') ||
        combined.contains('metal')) {
      baseBpm = 124.0 + (rng.nextDouble() * 40.0);
      baseEnergy = 0.78 + (rng.nextDouble() * 0.20);
    }

    // 2. Derive Camelot Key (1..12, A or B)
    final camelotNumber = 1 + (hash % 12);
    final camelotLetter = ((hash ~/ 12) % 2 == 0) ? 'A' : 'B';
    final camelotKey = CamelotKey(camelotNumber, camelotLetter);

    // Clamp derived attributes
    final clampedBpm = double.parse(baseBpm.clamp(60.0, 185.0).toStringAsFixed(1));
    final clampedEnergy = double.parse(baseEnergy.clamp(0.15, 0.98).toStringAsFixed(2));

    return TrackAudioFeatures(
      trackId: track.id,
      bpm: clampedBpm,
      key: camelotKey,
      energy: clampedEnergy,
      danceability: 0.5 + (rng.nextDouble() * 0.4),
      valence: 0.4 + (rng.nextDouble() * 0.4),
      isEstimated: true,
    );
  }

  /// Calculates effective tempo distance considering standard delta as well as
  /// DJ half-time and double-time harmonic compatibility (e.g., 75 BPM blends with 150 BPM).
  static double calculateEffectiveBpmDelta(double bpmA, double bpmB) {
    final direct = (bpmA - bpmB).abs();
    final halfTime = (bpmA - (bpmB * 2.0)).abs();
    final doubleTime = ((bpmA * 2.0) - bpmB).abs();
    return math.min(direct, math.min(halfTime, doubleTime));
  }

  /// Computes a composite transition penalty cost between [from] and [to] based on [mode].
  /// Lower cost indicates a smoother, more coherent musical transition.
  static TransitionScore scoreTransition(
    TrackAudioFeatures from,
    TrackAudioFeatures to,
    SmartShuffleMode mode,
  ) {
    final bpmDelta = calculateEffectiveBpmDelta(from.bpm, to.bpm);
    final harmonicDistance = (from.key != null && to.key != null)
        ? from.key!.harmonicDistanceTo(to.key!)
        : 2.5;

    final energyDelta = (from.energy - to.energy).abs();

    // Normalized components (0.0 to 1.0)
    final normBpm = (bpmDelta / 30.0).clamp(0.0, 1.0);
    final normHarmonic = (harmonicDistance / 6.0).clamp(0.0, 1.0);
    final normEnergy = energyDelta.clamp(0.0, 1.0);

    double totalCost;

    switch (mode) {
      case SmartShuffleMode.harmonicFlow:
        totalCost = (0.55 * normHarmonic) + (0.30 * normBpm) + (0.15 * normEnergy);
      case SmartShuffleMode.bpmMatch:
        totalCost = (0.60 * normBpm) + (0.25 * normHarmonic) + (0.15 * normEnergy);
      case SmartShuffleMode.energyRamp:
        // Penalize drops in energy when building up
        final energyDropPenalty = (to.energy < from.energy)
            ? (from.energy - to.energy) * 1.6
            : (to.energy - from.energy) * 0.4;
        totalCost = (0.50 * energyDropPenalty.clamp(0.0, 1.0)) +
            (0.30 * normBpm) +
            (0.20 * normHarmonic);
      case SmartShuffleMode.balancedTransition:
        totalCost = (0.40 * normBpm) + (0.40 * normHarmonic) + (0.20 * normEnergy);
    }

    return TransitionScore(
      totalCost: totalCost,
      bpmDelta: bpmDelta,
      harmonicDistance: harmonicDistance,
      energyDelta: energyDelta,
      isHarmonicMatch: harmonicDistance <= 1.0,
      isTempoMatch: bpmDelta <= 6.0,
    );
  }

  /// Reorders [tracks] using harmonic and tempo proximity rather than pure pseudo-randomness.
  ///
  /// Guarantees:
  /// - Exact preservation of all tracks without drop or duplication.
  /// - If [anchorTrack] is supplied, it acts as the transition seed.
  /// - Controlled [randomness] (0.0 to 0.3) introduces organic variety while preserving harmonic flow.
  static List<Track> reorder({
    required List<Track> tracks,
    Track? anchorTrack,
    SmartShuffleMode mode = SmartShuffleMode.harmonicFlow,
    double randomness = 0.12,
    int? randomSeed,
    Map<String, TrackAudioFeatures>? explicitFeatures,
  }) {
    if (tracks.length <= 1) {
      return List<Track>.from(tracks);
    }

    final rng = math.Random(randomSeed);

    // Build features cache
    final featuresMap = <String, TrackAudioFeatures>{};
    for (final track in tracks) {
      featuresMap[track.id] = explicitFeatures?[track.id] ?? estimateFeatures(track);
    }

    final candidatePool = List<Track>.from(tracks);
    final reordered = <Track>[];

    // Determine seed track
    Track currentAnchor;
    if (anchorTrack != null && candidatePool.any((t) => t.id == anchorTrack.id)) {
      currentAnchor = anchorTrack;
      candidatePool.removeWhere((t) => t.id == anchorTrack.id);
      reordered.add(currentAnchor);
    } else {
      // Pick random seed from candidate pool to ensure variety
      final seedIdx = rng.nextInt(candidatePool.length);
      currentAnchor = candidatePool.removeAt(seedIdx);
      reordered.add(currentAnchor);
    }

    var currentFeatures = featuresMap[currentAnchor.id] ??
        (explicitFeatures?[currentAnchor.id] ?? estimateFeatures(currentAnchor));

    // Greedily chain transitions minimizing transition cost
    while (candidatePool.isNotEmpty) {
      if (candidatePool.length == 1) {
        reordered.add(candidatePool.removeAt(0));
        break;
      }

      // Score all remaining candidates against current track
      final scoredCandidates = candidatePool.map((candidate) {
        final feat = featuresMap[candidate.id]!;
        final score = scoreTransition(currentFeatures, feat, mode);
        // Small stochastic jitter prevents deterministic lock when costs are identical
        final jitter = (randomness > 0) ? rng.nextDouble() * randomness : 0.0;
        final finalWeight = score.totalCost + jitter;
        return MapEntry(candidate, finalWeight);
      }).toList();

      // Sort by best score (lowest cost)
      scoredCandidates.sort((a, b) => a.value.compareTo(b.value));

      // Stochastic tournament selection: pick from top candidates
      final poolSize = math.min(3, scoredCandidates.length);
      final pickIdx = (randomness > 0.15 && poolSize > 1)
          ? rng.nextInt(poolSize)
          : 0;

      final bestCandidate = scoredCandidates[pickIdx].key;
      candidatePool.removeWhere((t) => t.id == bestCandidate.id);
      reordered.add(bestCandidate);

      currentAnchor = bestCandidate;
      currentFeatures = featuresMap[bestCandidate.id]!;
    }

    return reordered;
  }

  /// Evaluates transition smoothness across a sequence of tracks.
  static TransitionQualitySummary evaluateQueueQuality(
    List<Track> queue, {
    SmartShuffleMode mode = SmartShuffleMode.harmonicFlow,
    Map<String, TrackAudioFeatures>? explicitFeatures,
  }) {
    if (queue.length <= 1) {
      return TransitionQualitySummary(
        totalTracks: queue.length,
        totalTransitions: 0,
        averageBpmDelta: 0.0,
        harmonicCompatibilityPercent: 100.0,
        averageTransitionCost: 0.0,
      );
    }

    double totalBpmDelta = 0.0;
    double totalCost = 0.0;
    int harmonicMatches = 0;
    final transitionCount = queue.length - 1;

    for (int i = 0; i < transitionCount; i++) {
      final tA = queue[i];
      final tB = queue[i + 1];
      final fA = explicitFeatures?[tA.id] ?? estimateFeatures(tA);
      final fB = explicitFeatures?[tB.id] ?? estimateFeatures(tB);

      final score = scoreTransition(fA, fB, mode);
      totalBpmDelta += score.bpmDelta;
      totalCost += score.totalCost;
      if (score.isHarmonicMatch) {
        harmonicMatches++;
      }
    }

    return TransitionQualitySummary(
      totalTracks: queue.length,
      totalTransitions: transitionCount,
      averageBpmDelta: totalBpmDelta / transitionCount,
      harmonicCompatibilityPercent: (harmonicMatches / transitionCount) * 100.0,
      averageTransitionCost: totalCost / transitionCount,
    );
  }
}

// ============================================================================
// Riverpod State & StateNotifier
// ============================================================================

/// Reactive state for Smart Shuffle mode.
@immutable
class SmartShuffleState {
  final bool isSmartShuffleActive;
  final SmartShuffleMode mode;
  final double randomness;
  final TransitionQualitySummary? lastSummary;
  final bool isProcessing;

  const SmartShuffleState({
    this.isSmartShuffleActive = false,
    this.mode = SmartShuffleMode.harmonicFlow,
    this.randomness = 0.12,
    this.lastSummary,
    this.isProcessing = false,
  });

  SmartShuffleState copyWith({
    bool? isSmartShuffleActive,
    SmartShuffleMode? mode,
    double? randomness,
    TransitionQualitySummary? lastSummary,
    bool? isProcessing,
  }) {
    return SmartShuffleState(
      isSmartShuffleActive: isSmartShuffleActive ?? this.isSmartShuffleActive,
      mode: mode ?? this.mode,
      randomness: randomness ?? this.randomness,
      lastSummary: lastSummary ?? this.lastSummary,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartShuffleState &&
          runtimeType == other.runtimeType &&
          isSmartShuffleActive == other.isSmartShuffleActive &&
          mode == other.mode &&
          randomness == other.randomness &&
          isProcessing == other.isProcessing;

  @override
  int get hashCode => Object.hash(isSmartShuffleActive, mode, randomness, isProcessing);
}

/// StateNotifier controlling Smart Shuffle toggle, mode selection, and audio queue application.
class SmartShuffleNotifier extends StateNotifier<SmartShuffleState> {
  final Ref? _ref;

  SmartShuffleNotifier([this._ref]) : super(const SmartShuffleState()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final active = prefs.getBool(kSmartShuffleActivePrefKey) ?? false;
      final modeStr = prefs.getString(kSmartShuffleModePrefKey);
      final randomness = prefs.getDouble(kSmartShuffleRandomnessPrefKey) ?? 0.12;

      state = state.copyWith(
        isSmartShuffleActive: active,
        mode: SmartShuffleMode.fromString(modeStr),
        randomness: randomness,
      );
    } catch (_) {}
  }

  /// Toggles Smart Shuffle active state and persists the preference.
  Future<void> toggle() async {
    final nextActive = !state.isSmartShuffleActive;
    await setEnabled(nextActive);
  }

  /// Sets Smart Shuffle state explicitly.
  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(isSmartShuffleActive: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kSmartShuffleActivePrefKey, enabled);
    } catch (_) {}
  }

  /// Sets transition algorithm mode.
  Future<void> setMode(SmartShuffleMode mode) async {
    state = state.copyWith(mode: mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kSmartShuffleModePrefKey, mode.name);
    } catch (_) {}
  }

  /// Sets stochastic randomness weight (0.0 = purely deterministic, 0.3 = creative variety).
  Future<void> setRandomness(double val) async {
    final clamped = val.clamp(0.0, 0.4);
    state = state.copyWith(randomness: clamped);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(kSmartShuffleRandomnessPrefKey, clamped);
    } catch (_) {}
  }

  /// Applies harmonic BPM shuffle to the upcoming tracks in the playback queue.
  /// Preserves the currently playing song without disrupting active playback.
  Future<bool> applyToQueue({SoftifyAudioHandler? handler}) async {
    SoftifyAudioHandler? targetHandler = handler;
    if (targetHandler == null && _ref != null) {
      try {
        targetHandler = _ref.read(audioHandlerProvider);
      } catch (_) {}
    }

    if (targetHandler == null) return false;

    final currentQueue = targetHandler.currentQueue;
    if (currentQueue.isEmpty) return false;

    final currentIndex = targetHandler.currentIndex;
    final startIndex = (currentIndex >= 0) ? currentIndex + 1 : 0;
    final upcomingCount = currentQueue.length - startIndex;

    if (upcomingCount <= 1) return false;

    state = state.copyWith(isProcessing: true);

    try {
      final currentTrack = (currentIndex >= 0 && currentIndex < currentQueue.length)
          ? currentQueue[currentIndex]
          : null;

      final upcomingTracks = currentQueue.sublist(startIndex);

      final reorderedUpcoming = SmartBpmShuffleAlgorithm.reorder(
        tracks: upcomingTracks,
        anchorTrack: currentTrack,
        mode: state.mode,
        randomness: state.randomness,
      );

      final summary = SmartBpmShuffleAlgorithm.evaluateQueueQuality(
        [if (currentTrack != null) currentTrack, ...reorderedUpcoming],
        mode: state.mode,
      );

      // Apply reordered upcoming tracks to handler safely
      try {
        await (targetHandler as dynamic).replaceUpcomingQueue(reorderedUpcoming);
      } catch (_) {
        // Fallback for handlers that implement standard reorder
        for (int i = 0; i < reorderedUpcoming.length; i++) {
          final target = reorderedUpcoming[i];
          final currentIdx = targetHandler.currentQueue.indexWhere((t) => t.id == target.id);
          final desiredIdx = startIndex + i;
          if (currentIdx != -1 && currentIdx != desiredIdx) {
            await targetHandler.reorderQueue(currentIdx, desiredIdx);
          }
        }
      }

      state = state.copyWith(
        lastSummary: summary,
        isProcessing: false,
      );
      return true;
    } catch (_) {
      state = state.copyWith(isProcessing: false);
      return false;
    }
  }

  /// Helper reordering tracks pure in-memory without mutating external queues.
  List<Track> reorderTracks(List<Track> tracks, {Track? anchorTrack}) {
    return SmartBpmShuffleAlgorithm.reorder(
      tracks: tracks,
      anchorTrack: anchorTrack,
      mode: state.mode,
      randomness: state.randomness,
    );
  }
}

// ============================================================================
// Providers
// ============================================================================

final smartShuffleNotifierProvider =
    StateNotifierProvider<SmartShuffleNotifier, SmartShuffleState>((ref) {
  return SmartShuffleNotifier(ref);
});

final isSmartShuffleActiveProvider = Provider<bool>((ref) {
  return ref.watch(smartShuffleNotifierProvider).isSmartShuffleActive;
});

final smartShuffleModeProvider = Provider<SmartShuffleMode>((ref) {
  return ref.watch(smartShuffleNotifierProvider).mode;
});

final smartShuffleSummaryProvider = Provider<TransitionQualitySummary?>((ref) {
  return ref.watch(smartShuffleNotifierProvider).lastSummary;
});

// ============================================================================
// Widget: SmartShuffleBadgeButton
// ============================================================================

/// Material 3 interactive badge button that displays active glow when Smart Shuffle
/// is enabled and provides 1-tap toggling plus long-press mode configuration.
class SmartShuffleBadgeButton extends ConsumerStatefulWidget {
  final bool isCompact;
  final bool showTooltip;
  final Color? activeColor;
  final VoidCallback? onToggled;

  const SmartShuffleBadgeButton({
    super.key,
    this.isCompact = false,
    this.showTooltip = true,
    this.activeColor,
    this.onToggled,
  });

  @override
  ConsumerState<SmartShuffleBadgeButton> createState() =>
      _SmartShuffleBadgeButtonState();
}

class _SmartShuffleBadgeButtonState extends ConsumerState<SmartShuffleBadgeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowPulseController;
  late Animation<double> _glowPulseAnimation;

  @override
  void initState() {
    super.initState();
    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowPulseAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _glowPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowPulseController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.lightImpact();
    final notifier = ref.read(smartShuffleNotifierProvider.notifier);
    await notifier.toggle();

    final isActive = ref.read(smartShuffleNotifierProvider).isSmartShuffleActive;

    if (isActive) {
      await notifier.applyToQueue();
    }

    if (mounted) {
      final mode = ref.read(smartShuffleNotifierProvider).mode;
      final msg = isActive
          ? 'Smart Shuffle on (${mode.title} & BPM alignment)'
          : 'Smart Shuffle off (Standard shuffle)';
      AppToast.show(
        context,
        message: msg,
        icon: Icon(
          isActive ? Icons.auto_awesome_rounded : Icons.shuffle_rounded,
          color: isActive ? (widget.activeColor ?? Theme.of(context).colorScheme.primary) : Colors.white70,
          size: 18,
        ),
      );
    }

    widget.onToggled?.call();
  }

  void _showConfigSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SmartShuffleSettingsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final state = ref.watch(smartShuffleNotifierProvider);
    final isActive = state.isSmartShuffleActive;
    final primaryColor = widget.activeColor ?? tokens.accent;

    final tooltipMessage = isActive
        ? 'Smart Shuffle: Active (${state.mode.title})\nHarmonic & BPM transition enabled'
        : 'Smart Shuffle: Inactive\nTap to align upcoming tracks by key & tempo';

    Widget buttonContent = AnimatedBuilder(
      animation: _glowPulseAnimation,
      builder: (context, child) {
        final glowFactor = isActive ? _glowPulseAnimation.value : 0.0;

        return AnimatedContainer(
          duration: tokens.motionStandard,
          curve: Curves.easeOutCubic,
          padding: widget.isCompact
              ? const EdgeInsets.all(8)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            color: isActive
                ? primaryColor.withValues(alpha: 0.16)
                : tokens.surfaceElevated.withValues(alpha: 0.65),
            border: Border.all(
              color: isActive
                  ? primaryColor.withValues(alpha: 0.75 + (0.25 * glowFactor))
                  : tokens.divider.withValues(alpha: 0.4),
              width: isActive ? 1.4 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35 * glowFactor),
                      blurRadius: 10.0 * glowFactor,
                      spreadRadius: 1.0 * glowFactor,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with sparkle/glow
              Icon(
                isActive ? Icons.auto_awesome_rounded : Icons.shuffle_rounded,
                size: widget.isCompact ? 16 : 15,
                color: isActive ? primaryColor : tokens.textSecondary,
              ),
              if (!widget.isCompact) ...[
                const SizedBox(width: 6),
                Text(
                  'Smart BPM',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isActive ? tokens.textPrimary : tokens.textSecondary,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'FLOW',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );

    final interactiveButton = BouncingScaleButton(
      onTap: _handleTap,
      onLongPress: _showConfigSheet,
      scaleDown: 0.94,
      child: buttonContent,
    );

    if (!widget.showTooltip) {
      return interactiveButton;
    }

    return Tooltip(
      message: tooltipMessage,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: interactiveButton,
    );
  }
}

// ============================================================================
// Modal: SmartShuffleSettingsModal
// ============================================================================

/// Modal sheet providing transitions preview and mode selection.
class SmartShuffleSettingsModal extends ConsumerWidget {
  const SmartShuffleSettingsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(smartShuffleNotifierProvider);
    final notifier = ref.read(smartShuffleNotifierProvider.notifier);
    final audioHandler = ref.watch(audioHandlerProvider);
    final queue = audioHandler.currentQueue;
    final currentIndex = audioHandler.currentIndex;
    final currentTrack = (currentIndex >= 0 && currentIndex < queue.length)
        ? queue[currentIndex]
        : null;

    final summary = state.lastSummary ??
        SmartBpmShuffleAlgorithm.evaluateQueueQuality(
          queue,
          mode: state.mode,
        );

    return AppSurface(
      withBlur: true,
      color: tokens.isGlass ? tokens.glassSurface : tokens.surfaceElevated,
      borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusXl)),
      border: Border(
        top: BorderSide(
          color: tokens.isGlass ? tokens.glassBorder : Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(tokens.radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.auto_awesome_rounded, color: tokens.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Shuffle Settings',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          ),
                          Text(
                            'Harmonic & BPM transition alignment',
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 12,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: state.isSmartShuffleActive,
                    activeTrackColor: tokens.accent,
                    onChanged: (val) async {
                      await notifier.setEnabled(val);
                      if (val) {
                        await notifier.applyToQueue();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Transition Health Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.card.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HARMONIC COMPATIBILITY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: tokens.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${summary.harmonicCompatibilityPercent.toStringAsFixed(0)}% of transitions',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: tokens.accentCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: tokens.divider),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AVERAGE TEMPO STEP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: tokens.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '±${summary.averageBpmDelta.toStringAsFixed(1)} BPM',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: tokens.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (currentTrack != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.music_note_rounded, size: 14, color: tokens.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Now: "${currentTrack.title}" (${SmartBpmShuffleAlgorithm.estimateFeatures(currentTrack).bpm.toInt()} BPM • ${SmartBpmShuffleAlgorithm.estimateFeatures(currentTrack).key?.code ?? "Key"})',
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Text(
                'TRANSITION PROFILE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 10),

              // Modes Selector
              for (final mode in SmartShuffleMode.values)
                _buildModeTile(context, mode, state.mode == mode, (selected) async {
                  await notifier.setMode(selected);
                  if (state.isSmartShuffleActive) {
                    await notifier.applyToQueue();
                  }
                }),

              const SizedBox(height: 16),

              // Re-shuffle Action Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: state.isProcessing
                      ? null
                      : () async {
                          HapticFeedback.mediumImpact();
                          final success = await notifier.applyToQueue();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            AppToast.show(
                              context,
                              message: success
                                  ? 'Upcoming tracks reordered by BPM & Key'
                                  : 'Queue too short to reorder',
                              icon: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                            );
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusCard),
                    ),
                  ),
                  icon: state.isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    state.isProcessing ? 'Aligning Transitions...' : 'Re-Shuffle Upcoming Queue Now',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTile(
    BuildContext context,
    SmartShuffleMode mode,
    bool isSelected,
    ValueChanged<SmartShuffleMode> onSelect,
  ) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelect(mode),
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected
                  ? tokens.accent.withValues(alpha: 0.12)
                  : tokens.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(tokens.radiusCard),
              border: Border.all(
                color: isSelected
                    ? tokens.accent.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.04),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  mode.icon,
                  size: 20,
                  color: isSelected ? tokens.accent : tokens.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                        ),
                      ),
                      Text(
                        mode.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 18, color: tokens.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
