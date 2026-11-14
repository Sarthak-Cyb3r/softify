// ============================================================================
// Softify Quality of Life (QoL): Headphone Crossfeed (Bauer BS2B DSP)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Presets & Domain Model
// ============================================================================

/// Available Bauer stereophonic-to-binaural (BS2B) crossfeed presets.
///
/// Crossfeed feeds a low-passed and attenuated signal from each stereo channel
/// into the opposing channel to emulate acoustic head diffraction and interaural
/// time/level differences (ITD/ILD), eliminating extreme headphone isolation and
/// listening fatigue.
enum Bs2bPreset {
  /// Crossfeed processing completely bypassed.
  off(
    id: 'off',
    name: 'Off',
    label: 'Off',
    cutoffHz: null,
    feedDb: 0.0,
    subtitle: 'Bypass',
    description:
        'Stereo audio channels routed normally without crossfeed processing.',
    recommendation:
        'Recommended for loudspeaker listening or naturally blended master tracks.',
  ),

  /// Bauer default crossfeed curve (700 Hz cutoff, 4.5 dB feed level).
  defaultPreset(
    id: 'default',
    name: 'Default',
    label: 'Default (700Hz, 4.5dB)',
    cutoffHz: 700,
    feedDb: 4.5,
    subtitle: '700 Hz · 4.5 dB',
    description:
        'Standard Bauer BS2B curve. Balanced spatial blending that simulates '
        'natural front-firing studio monitors and significantly reduces ear fatigue.',
    recommendation:
        'Recommended baseline for all-day headphone listening and varied music genres.',
  ),

  /// Chu Moy classic crossfeed circuit (700 Hz cutoff, 6.0 dB feed level).
  chuMoy(
    id: 'chu_moy',
    name: 'Chu Moy',
    label: 'Chu Moy (700Hz, 6dB)',
    cutoffHz: 700,
    feedDb: 6.0,
    subtitle: '700 Hz · 6.0 dB',
    description:
        'Classic HeadWize Chu Moy crossfeed filter. Stronger low-frequency blending '
        'that brings aggressive stereo separation forward into a coherent center stage.',
    recommendation:
        'Ideal for classic rock (60s-70s), hard-panned jazz recordings, and older stereo mixes.',
  ),

  /// Jan Meier Corda subtle crossfeed curve (650 Hz cutoff, 9.5 dB feed level).
  janMeier(
    id: 'jan_meier',
    name: 'Jan Meier',
    label: 'Jan Meier (650Hz, 9.5dB)',
    cutoffHz: 650,
    feedDb: 9.5,
    subtitle: '650 Hz · 9.5 dB',
    description:
        'Jan Meier (Corda Audio) subtle crossfeed design. Employs a gentler 9.5 dB '
        'crossover to preserve expansive soundstage width while easing listener tension.',
    recommendation:
        'Ideal for acoustic, live orchestral, modern pop, and wide-stage audiophile headphones.',
  );

  final String id;
  final String name;
  final String label;
  final int? cutoffHz;
  final double feedDb;
  final String subtitle;
  final String description;
  final String recommendation;

  const Bs2bPreset({
    required this.id,
    required this.name,
    required this.label,
    required this.cutoffHz,
    required this.feedDb,
    required this.subtitle,
    required this.description,
    required this.recommendation,
  });

  /// Whether crossfeed DSP processing is active for this preset.
  bool get isEnabled => this != Bs2bPreset.off;

  /// Resolves a [Bs2bPreset] by string [id], defaulting to [Bs2bPreset.off].
  static Bs2bPreset fromId(String? id) {
    if (id == null) return Bs2bPreset.off;
    for (final preset in Bs2bPreset.values) {
      if (preset.id == id || preset.name.toLowerCase() == id.toLowerCase()) {
        return preset;
      }
    }
    return Bs2bPreset.off;
  }
}

// ============================================================================
// Storage & Persistence Contracts
// ============================================================================

/// SharedPreferences persistent storage key for BS2B Crossfeed preset.
const String kBs2bCrossfeedPresetPrefKey = 'softify_bs2b_crossfeed_preset';

/// Contract for persistent storage compatible with SharedPreferences semantics.
abstract class Bs2bPrefsStorage {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
}

/// Disk-backed key-value store providing SharedPreferences persistence
/// without external native plugin compilation hazards.
class Bs2bSharedPreferencesStore implements Bs2bPrefsStorage {
  static final Bs2bSharedPreferencesStore _instance =
      Bs2bSharedPreferencesStore._internal();
  factory Bs2bSharedPreferencesStore() => _instance;
  Bs2bSharedPreferencesStore._internal();

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;

  /// Loads persisted key-values from disk into memory.
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
      // Graceful fallback to memory cache in test/headless environments
    } finally {
      _isLoaded = true;
    }
  }

  @override
  Future<String?> getString(String key) async {
    if (!_isLoaded) await init();
    final value = _memoryCache[key];
    if (value is String) return value;
    return null;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    try {
      if (_cacheFile != null) {
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache), flush: true);
      }
    } catch (_) {}
    return true;
  }

  /// Clears in-memory cache and reloads next access (for testing).
  void clearForTesting() {
    _memoryCache.clear();
    _isLoaded = false;
    _cacheFile = null;
  }
}

// ============================================================================
// Pure Dart Bauer BS2B DSP Engine
// ============================================================================

/// Authentic implementation of Sebastian Bauer's stereophonic-to-binaural (BS2B)
/// digital IIR crossfeed filter engine.
///
/// Simulates natural interaural acoustics using 1st-order IIR low-pass and high-boost
/// shelving filters:
/// - Low frequencies diffract around the listener's head to reach the opposing ear
///   with slight delay and attenuation.
/// - High frequencies are shadowed by the head, remaining isolated to the direct channel.
/// - Direct channel receives a complementary high-boost filter to retain transparent
///   tonal balance and flat power response across all audible frequencies.
class Bs2bCrossfeedEngine {
  static final Bs2bCrossfeedEngine instance = Bs2bCrossfeedEngine();

  Bs2bPreset _preset;
  int _sampleRate;

  // Filter Coefficients (Lowpass crossfeed path)
  double _a0Lo = 0.0;
  double _b1Lo = 0.0;

  // Filter Coefficients (Highboost direct path)
  double _a0Hi = 0.0;
  double _a1Hi = 0.0;
  double _b1Hi = 0.0;

  // Master Gain factor to normalize energy
  double _gain = 1.0;

  // Filter Delay State History (0 = Left, 1 = Right)
  double _lo0 = 0.0;
  double _lo1 = 0.0;
  double _hi0 = 0.0;
  double _hi1 = 0.0;
  double _asis0 = 0.0;
  double _asis1 = 0.0;

  Bs2bCrossfeedEngine({
    Bs2bPreset preset = Bs2bPreset.off,
    int sampleRate = 44100,
  })  : _preset = preset,
        _sampleRate = sampleRate.clamp(2000, 384000) {
    _updateCoefficients();
  }

  /// Currently configured crossfeed preset.
  Bs2bPreset get preset => _preset;

  /// Whether crossfeed DSP processing is active.
  bool get isEnabled => _preset.isEnabled;

  /// Audio sample rate in Hertz (e.g. 44100, 48000, 96000).
  int get sampleRate => _sampleRate;

  /// Calculated lowpass filter feed coefficient [a0Lo].
  double get a0Lo => _a0Lo;

  /// Calculated lowpass filter recursion coefficient [b1Lo].
  double get b1Lo => _b1Lo;

  /// Calculated highboost feed coefficient [a0Hi].
  double get a0Hi => _a0Hi;

  /// Calculated highboost delay coefficient [a1Hi].
  double get a1Hi => _a1Hi;

  /// Calculated highboost recursion coefficient [b1Hi].
  double get b1Hi => _b1Hi;

  /// Calculated overall acoustic energy normalization gain.
  double get gain => _gain;

  /// Updates active preset and recalculates filter coefficients.
  void setPreset(Bs2bPreset newPreset) {
    if (_preset == newPreset) return;
    _preset = newPreset;
    _updateCoefficients();
  }

  /// Updates processing sample rate and recalculates filter coefficients.
  void setSampleRate(int rate) {
    final clamped = rate.clamp(2000, 384000);
    if (_sampleRate == clamped) return;
    _sampleRate = clamped;
    _updateCoefficients();
  }

  /// Clears internal delay state histories to prevent transient pops on track change.
  void reset() {
    _lo0 = 0.0;
    _lo1 = 0.0;
    _hi0 = 0.0;
    _hi1 = 0.0;
    _asis0 = 0.0;
    _asis1 = 0.0;
  }

  /// Recomputes 1st-order IIR discrete transfer function coefficients according
  /// to Sebastian Bauer's BS2B acoustic specification.
  void _updateCoefficients() {
    if (!_preset.isEnabled || _preset.cutoffHz == null) {
      _a0Lo = 0.0;
      _b1Lo = 0.0;
      _a0Hi = 1.0;
      _a1Hi = 0.0;
      _b1Hi = 0.0;
      _gain = 1.0;
      return;
    }

    final double fcLo = _preset.cutoffHz!.toDouble();
    final double level = _preset.feedDb;

    // Acoustic gain calculations in decibels
    final double gbLo = level * -5.0 / 6.0 - 3.0;
    final double gbHi = level / 6.0 - 3.0;

    final double gLo = math.pow(10.0, gbLo / 20.0).toDouble();
    final double gHi = 1.0 - math.pow(10.0, gbHi / 20.0).toDouble();
    final double fcHi = fcLo *
        math.pow(2.0, (gbLo - 20.0 * (math.log(gHi) / math.ln10)) / 12.0).toDouble();

    // Lowpass filter pole mapping
    final double xLo = math.exp(-2.0 * math.pi * fcLo / _sampleRate);
    _b1Lo = xLo;
    _a0Lo = gLo * (1.0 - xLo);

    // Highboost filter pole-zero mapping
    final double xHi = math.exp(-2.0 * math.pi * fcHi / _sampleRate);
    _b1Hi = xHi;
    _a0Hi = 1.0 - gHi * (1.0 - xHi);
    _a1Hi = -xHi;

    // Normalization gain to prevent overall acoustic attenuation
    _gain = 1.0 / (1.0 - gHi + gLo);
  }

  /// Processes a single stereo sample pair (inL, inR) through the BS2B crossfeed network.
  ///
  /// Returns a record `(outL, outR)`. When bypassed ([Bs2bPreset.off]), returns samples unmodified.
  @pragma('vm:prefer-inline')
  (double, double) processSample(double inL, double inR) {
    if (!_preset.isEnabled) {
      return (inL, inR);
    }

    // 1. Lowpass filter (crossfeed path from opposing channel)
    _lo0 = _a0Lo * inL + _b1Lo * _lo0;
    _lo1 = _a0Lo * inR + _b1Lo * _lo1;

    // 2. Highboost filter (direct path of current channel)
    _hi0 = _a0Hi * inL + _a1Hi * _asis0 + _b1Hi * _hi0;
    _hi1 = _a0Hi * inR + _a1Hi * _asis1 + _b1Hi * _hi1;

    _asis0 = inL;
    _asis1 = inR;

    // 3. Binaural acoustic cross-summing
    final double outL = (_hi0 + _lo1) * _gain;
    final double outR = (_hi1 + _lo0) * _gain;

    return (outL, outR);
  }

  /// In-place processing of 32-bit floating-point interleaved stereo PCM audio.
  /// Format: [L0, R0, L1, R1, L2, R2, ...]
  ///
  /// Executes zero heap allocations in the hot processing loop.
  void processInterleaved(Float32List buffer, {int channels = 2}) {
    if (!_preset.isEnabled || channels < 2 || buffer.isEmpty) {
      return;
    }

    final int length = buffer.length;
    final int safeLength = length - (length % channels);

    for (int i = 0; i < safeLength; i += channels) {
      final double inL = buffer[i];
      final double inR = buffer[i + 1];

      _lo0 = _a0Lo * inL + _b1Lo * _lo0;
      _lo1 = _a0Lo * inR + _b1Lo * _lo1;

      _hi0 = _a0Hi * inL + _a1Hi * _asis0 + _b1Hi * _hi0;
      _hi1 = _a0Hi * inR + _a1Hi * _asis1 + _b1Hi * _hi1;

      _asis0 = inL;
      _asis1 = inR;

      buffer[i] = (_hi0 + _lo1) * _gain;
      buffer[i + 1] = (_hi1 + _lo0) * _gain;
    }
  }

  /// In-place processing of planar stereo audio buffers (separate Left and Right channel lists).
  void processPlanar(Float32List left, Float32List right) {
    if (!_preset.isEnabled) {
      return;
    }

    final int frames = math.min(left.length, right.length);
    for (int i = 0; i < frames; i++) {
      final double inL = left[i];
      final double inR = right[i];

      _lo0 = _a0Lo * inL + _b1Lo * _lo0;
      _lo1 = _a0Lo * inR + _b1Lo * _lo1;

      _hi0 = _a0Hi * inL + _a1Hi * _asis0 + _b1Hi * _hi0;
      _hi1 = _a0Hi * inR + _a1Hi * _asis1 + _b1Hi * _hi1;

      _asis0 = inL;
      _asis1 = inR;

      left[i] = (_hi0 + _lo1) * _gain;
      right[i] = (_hi1 + _lo0) * _gain;
    }
  }

  /// Processes an interleaved Float32 buffer into a freshly allocated stereo copy.
  /// Original buffer remains unmodified.
  Float32List processInterleavedCopy(Float32List source, {int channels = 2}) {
    final copy = Float32List.fromList(source);
    processInterleaved(copy, channels: channels);
    return copy;
  }

  /// In-place processing of 16-bit signed integer PCM interleaved stereo audio samples.
  /// Format: [L0, R0, L1, ...]
  void processInt16Interleaved(Int16List buffer, {int channels = 2}) {
    if (!_preset.isEnabled || channels < 2 || buffer.isEmpty) {
      return;
    }

    final int length = buffer.length;
    final int safeLength = length - (length % channels);

    for (int i = 0; i < safeLength; i += channels) {
      final double inL = buffer[i] / 32768.0;
      final double inR = buffer[i + 1] / 32768.0;

      _lo0 = _a0Lo * inL + _b1Lo * _lo0;
      _lo1 = _a0Lo * inR + _b1Lo * _lo1;

      _hi0 = _a0Hi * inL + _a1Hi * _asis0 + _b1Hi * _hi0;
      _hi1 = _a0Hi * inR + _a1Hi * _asis1 + _b1Hi * _hi1;

      _asis0 = inL;
      _asis1 = inR;

      final double outL = (_hi0 + _lo1) * _gain;
      final double outR = (_hi1 + _lo0) * _gain;

      buffer[i] = (outL * 32767.0).round().clamp(-32768, 32767);
      buffer[i + 1] = (outR * 32767.0).round().clamp(-32768, 32767);
    }
  }
}

// ============================================================================
// Riverpod State & StateNotifier
// ============================================================================

/// Immutable state encapsulating the active BS2B Crossfeed configuration.
@immutable
class Bs2bCrossfeedState {
  final Bs2bPreset preset;
  final int sampleRate;
  final Bs2bPreset lastActivePreset;

  const Bs2bCrossfeedState({
    this.preset = Bs2bPreset.off,
    this.sampleRate = 44100,
    this.lastActivePreset = Bs2bPreset.defaultPreset,
  });

  /// Convenience getter for whether crossfeed is currently active.
  bool get isEnabled => preset.isEnabled;

  /// Convenience getter for whether crossfeed is currently off.
  bool get isOff => preset == Bs2bPreset.off;

  Bs2bCrossfeedState copyWith({
    Bs2bPreset? preset,
    int? sampleRate,
    Bs2bPreset? lastActivePreset,
  }) {
    return Bs2bCrossfeedState(
      preset: preset ?? this.preset,
      sampleRate: sampleRate ?? this.sampleRate,
      lastActivePreset: lastActivePreset ?? this.lastActivePreset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bs2bCrossfeedState &&
          runtimeType == other.runtimeType &&
          preset == other.preset &&
          sampleRate == other.sampleRate &&
          lastActivePreset == other.lastActivePreset;

  @override
  int get hashCode =>
      preset.hashCode ^ sampleRate.hashCode ^ lastActivePreset.hashCode;

  @override
  String toString() =>
      'Bs2bCrossfeedState(preset: ${preset.id}, sampleRate: $sampleRate, isEnabled: $isEnabled)';
}

/// Riverpod StateNotifier managing BS2B Headphone Crossfeed state and persistence.
class Bs2bCrossfeedNotifier extends StateNotifier<Bs2bCrossfeedState> {
  final Bs2bPrefsStorage _storage;
  final Bs2bCrossfeedEngine _engine;

  /// Custom storage override for unit tests.
  static Bs2bPrefsStorage? customStorage;

  /// Custom initial state override for tests.
  static Bs2bCrossfeedState? initialOverride;

  Bs2bCrossfeedNotifier({
    Bs2bPrefsStorage? storage,
    Bs2bCrossfeedEngine? engine,
    Bs2bCrossfeedState? initial,
  })  : _storage = storage ?? customStorage ?? Bs2bSharedPreferencesStore(),
        _engine = engine ?? Bs2bCrossfeedEngine.instance,
        super(initial ?? initialOverride ?? const Bs2bCrossfeedState()) {
    _engine.setPreset(state.preset);
    _engine.setSampleRate(state.sampleRate);
    _loadPersistedPreference();
  }

  /// Active preset convenience getter.
  Bs2bPreset get preset => state.preset;

  /// Whether crossfeed is enabled.
  bool get isEnabled => state.isEnabled;

  /// Loads initial state from persistent storage.
  Future<void> _loadPersistedPreference() async {
    try {
      final storedId = await _storage.getString(kBs2bCrossfeedPresetPrefKey);
      if (storedId != null && mounted) {
        final loadedPreset = Bs2bPreset.fromId(storedId);
        final lastActive = loadedPreset.isEnabled
            ? loadedPreset
            : state.lastActivePreset;
        state = state.copyWith(
          preset: loadedPreset,
          lastActivePreset: lastActive,
        );
        _engine.setPreset(loadedPreset);
      }
    } catch (_) {}
  }

  /// Sets the active crossfeed preset, updating DSP coefficients and persistence.
  Future<void> setPreset(Bs2bPreset newPreset) async {
    final lastActive = newPreset.isEnabled ? newPreset : state.lastActivePreset;
    state = state.copyWith(
      preset: newPreset,
      lastActivePreset: lastActive,
    );
    _engine.setPreset(newPreset);
    try {
      await _storage.setString(kBs2bCrossfeedPresetPrefKey, newPreset.id);
    } catch (_) {}
  }

  /// Toggles crossfeed between [Bs2bPreset.off] and the last active preset
  /// (defaulting to [Bs2bPreset.defaultPreset]).
  Future<void> toggle() async {
    if (state.isEnabled) {
      await setPreset(Bs2bPreset.off);
    } else {
      await setPreset(state.lastActivePreset);
    }
  }

  /// Cycles to the next available preset in the sequence:
  /// Off -> Default -> Chu Moy -> Jan Meier -> Off.
  Future<void> cycleNextPreset() async {
    const values = Bs2bPreset.values;
    final currentIndex = values.indexOf(state.preset);
    final nextIndex = (currentIndex + 1) % values.length;
    await setPreset(values[nextIndex]);
  }

  /// Updates the audio sample rate used for coefficient computation.
  void setSampleRate(int rate) {
    state = state.copyWith(sampleRate: rate);
    _engine.setSampleRate(rate);
  }

  /// Clears filter delay memory.
  void resetDspState() {
    _engine.reset();
  }

  /// Resets test hooks and singleton states.
  static void resetForTesting() {
    customStorage = null;
    initialOverride = null;
    Bs2bCrossfeedEngine.instance.setPreset(Bs2bPreset.off);
    Bs2bCrossfeedEngine.instance.reset();
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Primary Riverpod StateNotifierProvider for BS2B Headphone Crossfeed state.
final bs2bCrossfeedProvider =
    StateNotifierProvider<Bs2bCrossfeedNotifier, Bs2bCrossfeedState>((ref) {
  return Bs2bCrossfeedNotifier();
});

/// Convenience readable provider exposing the current [Bs2bPreset].
final bs2bCurrentPresetProvider = Provider<Bs2bPreset>((ref) {
  return ref.watch(bs2bCrossfeedProvider).preset;
});

/// Convenience readable provider exposing whether crossfeed is active.
final isBs2bCrossfeedEnabledProvider = Provider<bool>((ref) {
  return ref.watch(bs2bCrossfeedProvider).isEnabled;
});

/// Provider exposing the active [Bs2bCrossfeedEngine] singleton.
final bs2bEngineProvider = Provider<Bs2bCrossfeedEngine>((ref) {
  final state = ref.watch(bs2bCrossfeedProvider);
  final engine = Bs2bCrossfeedEngine.instance;
  engine.setPreset(state.preset);
  engine.setSampleRate(state.sampleRate);
  return engine;
});

// ============================================================================
// UI Widget: Bs2bCrossfeedSelector
// ============================================================================

/// Tooltip message explaining the purpose and physics of the Bauer BS2B filter.
const String kBs2bCrossfeedTooltip =
    'Bauer Stereophonic-to-Binaural (BS2B) DSP blends low frequencies between '
    'stereo channels with calculated interaural delays and head-shadowing attenuation. '
    'This emulates speaker listening in a real room, eliminating the fatiguing "in-the-head" '
    'sensation of headphones.';

/// Material 3 Card Widget providing interactive preset chips, technical details,
/// and descriptive feedback for Bauer BS2B Headphone Crossfeed.
class Bs2bCrossfeedSelector extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool compact;
  final ValueChanged<Bs2bPreset>? onPresetChanged;

  const Bs2bCrossfeedSelector({
    super.key,
    this.margin,
    this.padding,
    this.compact = false,
    this.onPresetChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bs2bCrossfeedProvider);
    final activePreset = state.preset;
    final isEnabled = state.isEnabled;

    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();

    final cardColor = tokens?.card ?? theme.cardColor;
    final primaryAccent = tokens?.accent ?? theme.colorScheme.primary;
    final textPrimary = tokens?.textPrimary ?? theme.colorScheme.onSurface;
    final textSecondary = tokens?.textSecondary ??
        theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final dividerColor = tokens?.divider ?? theme.dividerColor;

    return Container(
      key: const Key('bs2b_selector_card'),
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(tokens?.radiusCard ?? 16),
        border: Border.all(
          color: isEnabled
              ? primaryAccent.withValues(alpha: 0.35)
              : dividerColor.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ------------------------------------------------------------------
          // Header Row: Icon, Title, Subtitle, Tooltip, Switch
          // ------------------------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? primaryAccent.withValues(alpha: 0.15)
                      : textSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.headphones_rounded,
                  color: isEnabled ? primaryAccent : textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Headphone Crossfeed',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isEnabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryAccent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'BS2B Active',
                              style: TextStyle(
                                color: primaryAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Bauer stereophonic-to-binaural DSP · Prevents ear fatigue',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Tooltip Info Button
              Tooltip(
                message: kBs2bCrossfeedTooltip,
                waitDuration: const Duration(milliseconds: 300),
                showDuration: const Duration(seconds: 4),
                triggerMode: TooltipTriggerMode.tap,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primaryAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.35,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: textSecondary.withValues(alpha: 0.8),
                  ),
                  tooltip: 'BS2B Explanation',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {},
                ),
              ),

              // Master On/Off Switch
              Semantics(
                label: 'Headphone Crossfeed Master Switch',
                hint: 'Enables or disables Bauer stereophonic crossfeed',
                toggled: isEnabled,
                child: Switch(
                  key: const Key('bs2b_switch'),
                  value: isEnabled,
                  activeTrackColor: primaryAccent,
                  onChanged: (turnOn) {
                    if (turnOn) {
                      ref
                          .read(bs2bCrossfeedProvider.notifier)
                          .setPreset(state.lastActivePreset);
                      onPresetChanged?.call(state.lastActivePreset);
                    } else {
                      ref
                          .read(bs2bCrossfeedProvider.notifier)
                          .setPreset(Bs2bPreset.off);
                      onPresetChanged?.call(Bs2bPreset.off);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ------------------------------------------------------------------
          // Preset Choice Chips Row
          // ------------------------------------------------------------------
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Bs2bPreset.values.map((preset) {
              final isSelected = activePreset == preset;
              final keyString = 'bs2b_chip_${preset.id}';

              return ChoiceChip(
                key: Key(keyString),
                label: Text(preset.label),
                selected: isSelected,
                labelStyle: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : textPrimary,
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                selectedColor: primaryAccent,
                backgroundColor: textSecondary.withValues(alpha: 0.08),
                side: BorderSide(
                  color: isSelected
                      ? primaryAccent
                      : dividerColor.withValues(alpha: 0.2),
                  width: 1,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (selected) {
                  if (selected) {
                    ref
                        .read(bs2bCrossfeedProvider.notifier)
                        .setPreset(preset);
                    onPresetChanged?.call(preset);
                  }
                },
              );
            }).toList(),
          ),

          // ------------------------------------------------------------------
          // Detailed Preset Description & Acoustic Specs Card
          // ------------------------------------------------------------------
          if (!compact) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('bs2b_info_card'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: dividerColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        activePreset.name,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (activePreset.cutoffHz != null) ...[
                        _buildBadge(
                          context,
                          '${activePreset.cutoffHz} Hz Cutoff',
                          primaryAccent,
                        ),
                        const SizedBox(width: 6),
                        _buildBadge(
                          context,
                          '${activePreset.feedDb.toStringAsFixed(1)} dB Level',
                          primaryAccent,
                        ),
                      ] else ...[
                        _buildBadge(
                          context,
                          'Bypass',
                          textSecondary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activePreset.description,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.audiotrack_rounded,
                        size: 14,
                        color: isEnabled ? primaryAccent : textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          activePreset.recommendation,
                          style: TextStyle(
                            color: isEnabled
                                ? textPrimary.withValues(alpha: 0.85)
                                : textSecondary,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
