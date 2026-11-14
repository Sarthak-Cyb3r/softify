// ============================================================================
// Softify Quality of Life (QoL): Mono Audio Downmix Mode & Accessibility Router
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
// Storage & Persistence Contracts
// ============================================================================

/// SharedPreferences persistent storage key for Mono Audio Downmix mode.
const String kMonoAudioDownmixPrefKey = 'softify_mono_downmix_enabled';

/// Contract for persistent storage compatible with SharedPreferences semantics.
abstract class MonoAudioPrefsStorage {
  /// Reads a boolean value by key. Returns null if key is unset.
  Future<bool?> getBool(String key);

  /// Stores a boolean value by key.
  Future<bool> setBool(String key, bool value);
}

/// Disk-backed key-value store providing SharedPreferences persistence
/// without external native plugin compilation hazards.
class MonoAudioSharedPreferencesStore implements MonoAudioPrefsStorage {
  static final MonoAudioSharedPreferencesStore _instance =
      MonoAudioSharedPreferencesStore._internal();
  factory MonoAudioSharedPreferencesStore() => _instance;
  MonoAudioSharedPreferencesStore._internal();

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
  Future<bool?> getBool(String key) async {
    if (!_isLoaded) await init();
    final value = _memoryCache[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return null;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
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
// DSP Mono Downmixing Engine & Accessibility Audio Router
// ============================================================================

/// Software-defined DSP mono audio downmixer and accessibility audio routing engine.
///
/// When enabled, folds multi-channel stereo audio down into a balanced mono signal:
/// ```
/// Mono = (Left + Right) / 2
/// Left' = Mono
/// Right' = Mono
/// ```
///
/// This delivers full-frequency, equal-energy acoustic reproduction through
/// a single earbud or for listeners with unilateral hearing loss, without
/// stereo panning dropouts or frequency-cancellation artifacts.
class MonoDownmixAudioRouter {
  static final MonoDownmixAudioRouter instance = MonoDownmixAudioRouter();

  bool _isEnabled;

  MonoDownmixAudioRouter({bool isEnabled = false}) : _isEnabled = isEnabled;

  /// Whether mono audio routing is currently active.
  bool get isEnabled => _isEnabled;

  set isEnabled(bool value) {
    _isEnabled = value;
  }

  /// Mixes a single stereo sample pair (Left, Right) into mono: (L + R) / 2.
  ///
  /// Returns a record `(left, right)`. If mono is disabled, returns samples unmodified.
  @pragma('vm:prefer-inline')
  (double, double) processSample(double left, double right) {
    if (!_isEnabled) {
      return (left, right);
    }
    final mono = (left + right) * 0.5;
    return (mono, mono);
  }

  /// In-place downmixing of 32-bit floating-point interleaved stereo PCM audio.
  /// Format: [L0, R0, L1, R1, L2, R2, ...]
  ///
  /// When active, replaces each (L, R) pair with `(L + R) / 2` across all frames.
  /// Executes with zero heap allocations and 32-bit floating-point accuracy.
  void processInterleaved(Float32List buffer, {int channels = 2}) {
    if (!_isEnabled || channels < 2 || buffer.isEmpty) {
      return;
    }

    final int length = buffer.length;
    final int safeLength = length - (length % channels);

    for (int i = 0; i < safeLength; i += channels) {
      final double l = buffer[i];
      final double r = buffer[i + 1];
      final double mono = (l + r) * 0.5;
      buffer[i] = mono;
      buffer[i + 1] = mono;
    }
  }

  /// In-place downmixing of planar stereo audio buffers (separate Left and Right channel lists).
  ///
  /// For every index $i$, sets `Left[i] = Right[i] = (Left[i] + Right[i]) / 2`.
  void processPlanar(Float32List left, Float32List right) {
    if (!_isEnabled) {
      return;
    }

    final int frames = math.min(left.length, right.length);
    for (int i = 0; i < frames; i++) {
      final double mono = (left[i] + right[i]) * 0.5;
      left[i] = mono;
      right[i] = mono;
    }
  }

  /// Downmixes an interleaved Float32 buffer into a freshly allocated mono stereo copy.
  /// Original buffer remains unmodified.
  Float32List downmixInterleavedCopy(Float32List source, {int channels = 2}) {
    final copy = Float32List.fromList(source);
    processInterleaved(copy, channels: channels);
    return copy;
  }

  /// In-place downmixing of 16-bit integer PCM interleaved stereo audio samples.
  /// Format: [L0, R0, L1, ...]
  void processInt16Interleaved(Int16List buffer, {int channels = 2}) {
    if (!_isEnabled || channels < 2 || buffer.isEmpty) {
      return;
    }

    final int length = buffer.length;
    final int safeLength = length - (length % channels);

    for (int i = 0; i < safeLength; i += channels) {
      final int l = buffer[i];
      final int r = buffer[i + 1];
      final int mono = ((l + r) ~/ 2).clamp(-32768, 32767);
      buffer[i] = mono;
      buffer[i + 1] = mono;
    }
  }

  /// Calculates mean stereo separation absolute delta: average(|L - R|) across planar buffers.
  /// Returns 0.0 for identical mono signals, or up to 2.0 for antiphase signals.
  double computeStereoSeparation(Float32List left, Float32List right) {
    final int frames = math.min(left.length, right.length);
    if (frames == 0) return 0.0;

    double diffSum = 0.0;
    for (int i = 0; i < frames; i++) {
      diffSum += (left[i] - right[i]).abs();
    }
    return diffSum / frames;
  }
}

// ============================================================================
// Riverpod StateNotifier
// ============================================================================

/// Riverpod StateNotifier managing the mono audio downmix toggle state (`bool isMonoEnabled`).
///
/// Automatically synchronizes the active [MonoDownmixAudioRouter] singleton and
/// persists the user preference across application sessions.
class MonoAudioDownmixNotifier extends StateNotifier<bool> {
  final MonoAudioPrefsStorage _storage;
  final MonoDownmixAudioRouter _router;

  /// Custom storage override for unit tests.
  static MonoAudioPrefsStorage? customStorage;

  /// Custom initial state override for tests.
  static bool? initialOverride;

  MonoAudioDownmixNotifier({
    MonoAudioPrefsStorage? storage,
    MonoDownmixAudioRouter? router,
    bool? initial,
  })  : _storage = storage ?? customStorage ?? MonoAudioSharedPreferencesStore(),
        _router = router ?? MonoDownmixAudioRouter.instance,
        super(initial ?? initialOverride ?? false) {
    _router.isEnabled = state;
    _loadPersistedPreference();
  }

  /// Convenience getter for readability matching requirement specification.
  bool get isMonoEnabled => state;

  /// Loads initial state from persistent storage asynchronously.
  Future<void> _loadPersistedPreference() async {
    try {
      final stored = await _storage.getBool(kMonoAudioDownmixPrefKey);
      if (stored != null && mounted) {
        state = stored;
        _router.isEnabled = stored;
      }
    } catch (_) {}
  }

  /// Toggles the mono audio downmix setting.
  Future<void> toggle() async {
    await setMonoEnabled(!state);
  }

  /// Sets the mono downmix state to [enabled], updating DSP routing and persistent storage.
  Future<void> setMonoEnabled(bool enabled) async {
    state = enabled;
    _router.isEnabled = enabled;
    try {
      await _storage.setBool(kMonoAudioDownmixPrefKey, enabled);
    } catch (_) {}
  }

  /// Resets state and custom test overrides.
  static void resetForTesting() {
    customStorage = null;
    initialOverride = null;
    MonoDownmixAudioRouter.instance.isEnabled = false;
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Primary Riverpod provider for mono audio downmixing state (`bool`).
final monoAudioDownmixProvider =
    StateNotifierProvider<MonoAudioDownmixNotifier, bool>((ref) {
  return MonoAudioDownmixNotifier();
});

/// Convenience readable provider exposing `bool isMonoEnabled`.
final isMonoDownmixEnabledProvider = Provider<bool>((ref) {
  return ref.watch(monoAudioDownmixProvider);
});

/// Provider exposing the active [MonoDownmixAudioRouter] configured with current state.
final monoDownmixRouterProvider = Provider<MonoDownmixAudioRouter>((ref) {
  final isEnabled = ref.watch(monoAudioDownmixProvider);
  final router = MonoDownmixAudioRouter.instance;
  router.isEnabled = isEnabled;
  return router;
});

// ============================================================================
// UI Widget: MonoAudioToggleCard
// ============================================================================

/// Descriptive tooltip explaining mono audio downmix accessibility routing.
const String kMonoAudioTooltipDescription =
    'Combines left and right stereo audio channels into both earbuds ((L+R)/2). '
    'Recommended for single-earbud listening or unilateral hearing accessibility.';

/// Material 3 Card Widget providing a toggle switch and descriptive tooltip
/// for the Mono Audio Downmix mode.
class MonoAudioToggleCard extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool showTooltip;
  final String? customTooltip;
  final ValueChanged<bool>? onToggled;

  const MonoAudioToggleCard({
    super.key,
    this.margin,
    this.padding,
    this.showTooltip = true,
    this.customTooltip,
    this.onToggled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMonoEnabled = ref.watch(monoAudioDownmixProvider);
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();

    // Design Tokens & Fallbacks
    final cardColor = tokens?.card ?? theme.cardColor;
    final primaryAccent = tokens?.accent ?? theme.colorScheme.primary;
    final textPrimary = tokens?.textPrimary ?? theme.colorScheme.onSurface;
    final textSecondary = tokens?.textSecondary ??
        theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final dividerColor = tokens?.divider ?? theme.dividerColor;

    final tooltipMessage = customTooltip ?? kMonoAudioTooltipDescription;

    final cardContent = Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(tokens?.radiusCard ?? 16),
        border: Border.all(
          color: isMonoEnabled
              ? primaryAccent.withValues(alpha: 0.35)
              : dividerColor.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Icon with accessibility badge background
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isMonoEnabled
                  ? primaryAccent.withValues(alpha: 0.15)
                  : textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.hearing_rounded,
              color: isMonoEnabled ? primaryAccent : textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Title, Subtitle, and Active Tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Mono Audio Downmix',
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
                    if (isMonoEnabled) ...[
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
                          'Mono (L+R)/2',
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
                  isMonoEnabled
                      ? 'Stereo folded to (L+R)/2 on both channels'
                      : 'Stereo audio channels routed normally',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Info / Tooltip Button
          if (showTooltip)
            Tooltip(
              message: tooltipMessage,
              waitDuration: const Duration(milliseconds: 300),
              showDuration: const Duration(seconds: 4),
              triggerMode: TooltipTriggerMode.tap,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                tooltip: 'Information',
                visualDensity: VisualDensity.compact,
                onPressed: () {},
              ),
            ),

          // Material 3 Switch
          Semantics(
            label: 'Mono Audio Downmix Toggle',
            hint: 'Mixes Left and Right audio channels for single earbud listening',
            toggled: isMonoEnabled,
            child: Switch(
              value: isMonoEnabled,
              activeTrackColor: primaryAccent,
              onChanged: (newValue) {
                ref.read(monoAudioDownmixProvider.notifier).setMonoEnabled(newValue);
                onToggled?.call(newValue);
              },
            ),
          ),
        ],
      ),
    );

    if (showTooltip) {
      return Tooltip(
        message: tooltipMessage,
        waitDuration: const Duration(seconds: 1),
        child: cardContent,
      );
    }

    return cardContent;
  }
}
