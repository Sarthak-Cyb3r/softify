// ============================================================================
// Softify Quality of Life (QoL): Equalizer Quick Preset Cycler (Feature 53)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../presentation/providers/equalizer_providers.dart';
import '../../../presentation/theme/app_theme.dart';

// ============================================================================
// Presets & Domain Entities
// ============================================================================

/// Canonical 6-preset cycler set for rapid EQ switching during playback.
enum QuickEqPreset {
  flat(
    id: 'flat',
    name: 'Flat',
    label: 'Flat',
    canonicalEqualizerName: 'Flat',
    icon: Icons.linear_scale_rounded,
    subtitle: 'Neutral reference curve',
    description: '0 dB uncolored studio monitor frequency response',
    gains: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
  ),
  bassBoost(
    id: 'bass_boost',
    name: 'Bass Boost',
    label: 'Bass Boost',
    canonicalEqualizerName: 'Bass Booster',
    icon: Icons.graphic_eq_rounded,
    subtitle: 'Deep low-end punch',
    description: 'Elevated sub-bass and mid-bass for warm, physical impact',
    gains: [6.0, 5.0, 4.0, 2.5, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0],
  ),
  trebleBoost(
    id: 'treble_boost',
    name: 'Treble Boost',
    label: 'Treble Boost',
    canonicalEqualizerName: 'Treble Booster',
    icon: Icons.multitrack_audio_rounded,
    subtitle: 'Crisp airy highs',
    description: 'Upper harmonic boost for enhanced sparkle and transient detail',
    gains: [0.0, 0.0, 0.0, 0.0, 1.0, 2.0, 3.5, 4.5, 5.5, 6.0],
  ),
  vocal(
    id: 'vocal',
    name: 'Vocal',
    label: 'Vocal',
    canonicalEqualizerName: 'Vocal Booster',
    icon: Icons.record_voice_over_rounded,
    subtitle: 'Forward dialogue & lyrics',
    description: 'Midrange prominence centered on human vocal frequencies',
    gains: [-2.0, -1.0, 0.0, 1.5, 4.0, 4.5, 3.5, 2.0, 0.5, 0.0],
  ),
  electronic(
    id: 'electronic',
    name: 'Electronic',
    label: 'Electronic',
    canonicalEqualizerName: 'Electronic',
    icon: Icons.electric_bolt_rounded,
    subtitle: 'V-shaped club profile',
    description: 'Aggressive sub-bass punch and sizzling treble for EDM & synth',
    gains: [5.0, 4.5, 3.5, 1.0, -0.5, 0.5, 2.5, 4.0, 4.5, 5.0],
  ),
  rock(
    id: 'rock',
    name: 'Rock',
    label: 'Rock',
    canonicalEqualizerName: 'Rock',
    icon: Icons.music_note_rounded,
    subtitle: 'Punchy guitars & drums',
    description: 'Solid low-end drive with bite in guitars, snares and cymbals',
    gains: [4.5, 3.5, 2.5, 0.5, -1.0, 0.0, 2.0, 3.5, 4.5, 5.0],
  );

  final String id;
  final String name;
  final String label;
  final String canonicalEqualizerName;
  final IconData icon;
  final String subtitle;
  final String description;
  final List<double> gains;

  const QuickEqPreset({
    required this.id,
    required this.name,
    required this.label,
    required this.canonicalEqualizerName,
    required this.icon,
    required this.subtitle,
    required this.description,
    required this.gains,
  });

  /// 10-band ISO standard equalizer center frequencies in Hertz (Hz).
  static const List<double> frequencies = [
    31.0,
    62.0,
    125.0,
    250.0,
    500.0,
    1000.0,
    2000.0,
    4000.0,
    8000.0,
    16000.0,
  ];

  /// Finds a preset by case-insensitive name, canonical name, or id.
  static QuickEqPreset match(String input) {
    final clean = input.trim().toLowerCase();
    for (final p in QuickEqPreset.values) {
      if (p.id == clean ||
          p.name.toLowerCase() == clean ||
          p.label.toLowerCase() == clean ||
          p.canonicalEqualizerName.toLowerCase() == clean) {
        return p;
      }
    }
    // Handle common variations
    if (clean.contains('bass')) return QuickEqPreset.bassBoost;
    if (clean.contains('treble')) return QuickEqPreset.trebleBoost;
    if (clean.contains('vocal') || clean.contains('voice')) return QuickEqPreset.vocal;
    if (clean.contains('electro') || clean.contains('edm')) return QuickEqPreset.electronic;
    if (clean.contains('rock')) return QuickEqPreset.rock;
    return QuickEqPreset.flat;
  }
}

/// Rich metadata model for an active Quick Preset.
@immutable
class QuickPresetInfo {
  final QuickEqPreset preset;
  final int index;
  final int totalCount;

  const QuickPresetInfo({
    required this.preset,
    required this.index,
    required this.totalCount,
  });

  String get id => preset.id;
  String get name => preset.name;
  String get label => preset.label;
  String get canonicalEqualizerName => preset.canonicalEqualizerName;
  IconData get icon => preset.icon;
  String get subtitle => preset.subtitle;
  String get description => preset.description;
  List<double> get gains => preset.gains;

  /// Human-readable step ratio (e.g., "2 of 6").
  String get stepRatio => '${index + 1} of $totalCount';

  /// Whether this is the default Flat response.
  bool get isFlat => preset == QuickEqPreset.flat;

  /// Max dB boost across bands.
  double get maxGain => gains.reduce(math.max);

  /// Max dB cut across bands.
  double get minGain => gains.reduce(math.min);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickPresetInfo &&
          runtimeType == other.runtimeType &&
          preset == other.preset &&
          index == other.index;

  @override
  int get hashCode => preset.hashCode ^ index.hashCode;
}

// ============================================================================
// Storage & Persistence Contracts
// ============================================================================

/// SharedPreferences persistent storage key for active quick preset.
const String kQuickPresetPrefKey = 'softify_quick_eq_preset';

/// Storage contract for saving and loading quick preset preferences.
abstract class QuickPresetPrefsStorage {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
}

/// SharedPreferences disk store with robust in-memory fallback.
class QuickPresetSharedPreferencesStore implements QuickPresetPrefsStorage {
  static final QuickPresetSharedPreferencesStore _instance =
      QuickPresetSharedPreferencesStore._internal();
  factory QuickPresetSharedPreferencesStore() => _instance;
  QuickPresetSharedPreferencesStore._internal();

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

  void clearForTesting() {
    _memoryCache.clear();
    _isLoaded = false;
    _cacheFile = null;
  }
}

/// In-memory mock storage for deterministic unit tests.
class InMemoryQuickPresetStore implements QuickPresetPrefsStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> getString(String key) async => _data[key];

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  void clear() => _data.clear();
}

// ============================================================================
// Service Layer: QuickPresetCyclerService
// ============================================================================

/// Manages cyclic rotation, persistence, and HUD toast events for EQ presets.
class QuickPresetCyclerService {
  static final QuickPresetCyclerService _singleton =
      QuickPresetCyclerService(storage: QuickPresetSharedPreferencesStore());
  static QuickPresetCyclerService get instance => _singleton;

  final QuickPresetPrefsStorage _storage;
  final List<QuickEqPreset> _presetList;

  int _currentIndex = 0;
  bool _isHudVisible = false;
  Timer? _hudDismissTimer;

  final StreamController<QuickPresetInfo> _presetStreamController =
      StreamController<QuickPresetInfo>.broadcast();
  final StreamController<bool> _hudVisibilityController =
      StreamController<bool>.broadcast();

  /// Optional callback invoked whenever a preset is cycled.
  void Function(QuickPresetInfo preset)? onPresetApplied;

  QuickPresetCyclerService({
    QuickPresetPrefsStorage? storage,
    List<QuickEqPreset>? presets,
    this.onPresetApplied,
  })  : _storage = storage ?? QuickPresetSharedPreferencesStore(),
        _presetList = presets ?? QuickEqPreset.values;

  /// Currently active preset information.
  QuickPresetInfo get currentPreset => QuickPresetInfo(
        preset: _presetList[_currentIndex],
        index: _currentIndex,
        totalCount: _presetList.length,
      );

  /// Index of the current preset.
  int get currentIndex => _currentIndex;

  /// All available presets in the cycler loop.
  List<QuickPresetInfo> get presets => [
        for (int i = 0; i < _presetList.length; i++)
          QuickPresetInfo(
            preset: _presetList[i],
            index: i,
            totalCount: _presetList.length,
          ),
      ];

  /// Whether the floating HUD toast is currently active.
  bool get isHudVisible => _isHudVisible;

  /// Broadcast stream emitting whenever the preset changes.
  Stream<QuickPresetInfo> get onPresetChanged => _presetStreamController.stream;

  /// Broadcast stream emitting whenever HUD visibility changes.
  Stream<bool> get onHudVisibilityChanged => _hudVisibilityController.stream;

  /// Initializes the service and restores persisted preset.
  Future<void> init() async {
    try {
      final savedId = await _storage.getString(kQuickPresetPrefKey);
      if (savedId != null && savedId.isNotEmpty) {
        final matched = QuickEqPreset.match(savedId);
        final foundIndex = _presetList.indexOf(matched);
        if (foundIndex != -1) {
          _currentIndex = foundIndex;
        }
      }
    } catch (_) {}
    _notifyPresetChanged(showToast: false);
  }

  /// Cycles to the next EQ preset in circular sequence.
  QuickPresetInfo cycleNext({bool triggerHudToast = true}) {
    _currentIndex = (_currentIndex + 1) % _presetList.length;
    final info = currentPreset;
    _persistCurrentPreset();
    _notifyPresetChanged(showToast: triggerHudToast);
    return info;
  }

  /// Cycles to the previous EQ preset in circular sequence.
  QuickPresetInfo cyclePrevious({bool triggerHudToast = true}) {
    _currentIndex = (_currentIndex - 1 + _presetList.length) % _presetList.length;
    final info = currentPreset;
    _persistCurrentPreset();
    _notifyPresetChanged(showToast: triggerHudToast);
    return info;
  }

  /// Selects a specific preset by [QuickEqPreset], name string, or index.
  QuickPresetInfo selectPreset(
    dynamic target, {
    bool triggerHudToast = true,
  }) {
    if (target is int) {
      if (_presetList.isNotEmpty) {
        _currentIndex = target.clamp(0, _presetList.length - 1);
      }
    } else if (target is QuickEqPreset) {
      final idx = _presetList.indexOf(target);
      if (idx != -1) _currentIndex = idx;
    } else if (target is QuickPresetInfo) {
      final idx = _presetList.indexOf(target.preset);
      if (idx != -1) _currentIndex = idx;
    } else if (target is String) {
      final matched = QuickEqPreset.match(target);
      final idx = _presetList.indexOf(matched);
      if (idx != -1) _currentIndex = idx;
    }

    final info = currentPreset;
    _persistCurrentPreset();
    _notifyPresetChanged(showToast: triggerHudToast);
    return info;
  }

  /// Triggers the floating HUD toast and auto-dismisses after [duration].
  void showHud({
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    _hudDismissTimer?.cancel();
    _isHudVisible = true;
    if (!_hudVisibilityController.isClosed) {
      _hudVisibilityController.add(true);
    }

    _hudDismissTimer = Timer(duration, () {
      dismissHud();
    });
  }

  /// Immediately dismisses the floating HUD toast.
  void dismissHud() {
    _hudDismissTimer?.cancel();
    if (_isHudVisible) {
      _isHudVisible = false;
      if (!_hudVisibilityController.isClosed) {
        _hudVisibilityController.add(false);
      }
    }
  }

  void _persistCurrentPreset() {
    unawaited(_storage.setString(kQuickPresetPrefKey, currentPreset.id));
  }

  void _notifyPresetChanged({bool showToast = true}) {
    final info = currentPreset;
    if (!_presetStreamController.isClosed) {
      _presetStreamController.add(info);
    }
    onPresetApplied?.call(info);
    if (showToast) {
      showHud();
    }
  }

  /// Cleans up timers and stream controllers.
  void dispose() {
    _hudDismissTimer?.cancel();
    _presetStreamController.close();
    _hudVisibilityController.close();
  }
}

// ============================================================================
// Riverpod State & Notifiers
// ============================================================================

/// Immutable state holding the active EQ quick preset and HUD display state.
@immutable
class QuickPresetState {
  final QuickPresetInfo currentPreset;
  final int currentIndex;
  final List<QuickPresetInfo> presets;
  final bool isHudVisible;
  final int cycleCount;
  final bool isEnabled;

  const QuickPresetState({
    required this.currentPreset,
    required this.currentIndex,
    required this.presets,
    this.isHudVisible = false,
    this.cycleCount = 0,
    this.isEnabled = true,
  });

  QuickPresetState copyWith({
    QuickPresetInfo? currentPreset,
    int? currentIndex,
    List<QuickPresetInfo>? presets,
    bool? isHudVisible,
    int? cycleCount,
    bool? isEnabled,
  }) {
    return QuickPresetState(
      currentPreset: currentPreset ?? this.currentPreset,
      currentIndex: currentIndex ?? this.currentIndex,
      presets: presets ?? this.presets,
      isHudVisible: isHudVisible ?? this.isHudVisible,
      cycleCount: cycleCount ?? this.cycleCount,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickPresetState &&
          runtimeType == other.runtimeType &&
          currentPreset == other.currentPreset &&
          currentIndex == other.currentIndex &&
          isHudVisible == other.isHudVisible &&
          cycleCount == other.cycleCount &&
          isEnabled == other.isEnabled;

  @override
  int get hashCode =>
      currentPreset.hashCode ^
      currentIndex.hashCode ^
      isHudVisible.hashCode ^
      cycleCount.hashCode ^
      isEnabled.hashCode;
}

/// Notifier driving the reactive state of the quick EQ cycler.
class QuickPresetNotifier extends StateNotifier<QuickPresetState> {
  final QuickPresetCyclerService _service;
  final Ref? _ref;
  StreamSubscription<QuickPresetInfo>? _presetSub;
  StreamSubscription<bool>? _hudSub;

  QuickPresetNotifier({
    required QuickPresetCyclerService service,
    Ref? ref,
  })  : _service = service,
        _ref = ref,
        super(
          QuickPresetState(
            currentPreset: service.currentPreset,
            currentIndex: service.currentIndex,
            presets: service.presets,
            isHudVisible: service.isHudVisible,
          ),
        ) {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _presetSub = _service.onPresetChanged.listen((info) {
      state = state.copyWith(
        currentPreset: info,
        currentIndex: info.index,
        cycleCount: state.cycleCount + 1,
      );
      _syncWithEqualizer(info);
    });

    _hudSub = _service.onHudVisibilityChanged.listen((visible) {
      state = state.copyWith(isHudVisible: visible);
    });
  }

  /// Cycles forward to the next EQ preset (e.g., Flat -> Bass Boost -> Treble Boost...).
  QuickPresetInfo cycleNext({bool triggerHudToast = true}) {
    final next = _service.cycleNext(triggerHudToast: triggerHudToast);
    state = state.copyWith(
      currentPreset: next,
      currentIndex: next.index,
      cycleCount: state.cycleCount + 1,
      isHudVisible: triggerHudToast ? true : state.isHudVisible,
    );
    _syncWithEqualizer(next);
    return next;
  }

  /// Cycles backward to the previous EQ preset.
  QuickPresetInfo cyclePrevious({bool triggerHudToast = true}) {
    final prev = _service.cyclePrevious(triggerHudToast: triggerHudToast);
    state = state.copyWith(
      currentPreset: prev,
      currentIndex: prev.index,
      cycleCount: state.cycleCount + 1,
      isHudVisible: triggerHudToast ? true : state.isHudVisible,
    );
    _syncWithEqualizer(prev);
    return prev;
  }

  /// Directly selects a specific preset.
  QuickPresetInfo selectPreset(dynamic target, {bool triggerHudToast = true}) {
    final info = _service.selectPreset(target, triggerHudToast: triggerHudToast);
    state = state.copyWith(
      currentPreset: info,
      currentIndex: info.index,
      cycleCount: state.cycleCount + 1,
      isHudVisible: triggerHudToast ? true : state.isHudVisible,
    );
    _syncWithEqualizer(info);
    return info;
  }

  /// Shows the floating HUD toast.
  void showHud({Duration duration = const Duration(milliseconds: 1800)}) {
    _service.showHud(duration: duration);
    state = state.copyWith(isHudVisible: true);
  }

  /// Dismisses the floating HUD toast.
  void dismissHud() {
    _service.dismissHud();
    state = state.copyWith(isHudVisible: false);
  }

  /// Toggles whether preset cycling is enabled.
  void setEnabled(bool enabled) {
    state = state.copyWith(isEnabled: enabled);
  }

  /// Safely delegates to Softify's core equalizerProvider if available.
  void _syncWithEqualizer(QuickPresetInfo preset) {
    if (_ref == null) return;
    try {
      final eqNotifier = _ref.read(equalizerProvider.notifier);
      eqNotifier.selectPreset(preset.canonicalEqualizerName);
    } catch (_) {
      // In isolated test environments or headless runners, ignore missing audio harness
    }
  }

  @override
  void dispose() {
    _presetSub?.cancel();
    _hudSub?.cancel();
    super.dispose();
  }
}

/// Provider for SharedPreferences storage contract.
final quickPresetStorageProvider = Provider<QuickPresetPrefsStorage>((ref) {
  return QuickPresetSharedPreferencesStore();
});

/// Provider for the singleton cycler service.
final quickPresetCyclerServiceProvider =
    Provider<QuickPresetCyclerService>((ref) {
  final storage = ref.watch(quickPresetStorageProvider);
  final service = QuickPresetCyclerService(storage: storage);
  unawaited(service.init());
  ref.onDispose(() => service.dispose());
  return service;
});

/// Primary state notifier provider for quick EQ preset cycling.
final quickPresetStateProvider =
    StateNotifierProvider<QuickPresetNotifier, QuickPresetState>((ref) {
  final service = ref.watch(quickPresetCyclerServiceProvider);
  return QuickPresetNotifier(service: service, ref: ref);
});

// ============================================================================
// UI Component: QuickPresetMiniVisualizer (10-Band Curve Display)
// ============================================================================

/// Compact 10-band equalizer curve visualizer bar graph.
class QuickPresetMiniVisualizer extends StatelessWidget {
  final List<double> gains;
  final double height;
  final double barWidth;
  final double spacing;
  final Color? barColor;
  final Color? baseLineColor;

  const QuickPresetMiniVisualizer({
    super.key,
    required this.gains,
    this.height = 24.0,
    this.barWidth = 3.5,
    this.spacing = 2.5,
    this.barColor,
    this.baseLineColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    final activeColor = barColor ?? tokens?.accent ?? AppTheme.accent;
    final mutedLine = baseLineColor ?? (tokens?.divider ?? Colors.white24);

    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(gains.length, (i) {
          final gain = gains[i];
          // Normalized value between -1.0 (-12dB) and +1.0 (+12dB)
          final normalized = (gain / 12.0).clamp(-1.0, 1.0);
          final barHeight = math.max(3.0, (normalized.abs() * (height / 2.0)));
          final isPositive = gain >= 0;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: SizedBox(
              width: barWidth,
              height: height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center 0 dB baseline marker
                  Container(
                    width: barWidth,
                    height: 1.5,
                    color: mutedLine,
                  ),
                  // Animated gain bar
                  Align(
                    alignment: isPositive ? Alignment.topCenter : Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: isPositive ? (height / 2.0) - barHeight : 0,
                        bottom: !isPositive ? (height / 2.0) - barHeight : 0,
                      ),
                      child: Container(
                        width: barWidth,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: activeColor.withValues(
                            alpha: 0.65 + (normalized.abs() * 0.35),
                          ),
                          borderRadius: BorderRadius.circular(barWidth / 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================================
// UI Component: QuickPresetCycleButton
// ============================================================================

/// Desktop/mobile action button to cycle EQ presets on tap with hotkey tooltip.
class QuickPresetCycleButton extends ConsumerWidget {
  final bool showLabel;
  final bool compact;
  final VoidCallback? onPressed;
  final String? tooltip;

  const QuickPresetCycleButton({
    super.key,
    this.showLabel = true,
    this.compact = false,
    this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quickPresetStateProvider);
    final notifier = ref.read(quickPresetStateProvider.notifier);
    final preset = state.currentPreset;

    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    final accent = tokens?.accent ?? AppTheme.accent;
    final textPrimary = tokens?.textPrimary ?? AppTheme.textPrimary;
    final surfaceElevated = tokens?.surfaceElevated ?? AppTheme.surfaceElevated;

    final buttonTooltip = tooltip ??
        'Cycle EQ Preset (Ctrl+E) • Currently: ${preset.label} (${preset.stepRatio})';

    return Tooltip(
      message: buttonTooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (onPressed != null) {
              onPressed!();
            } else {
              notifier.cycleNext();
            }
          },
          onSecondaryTap: () {
            notifier.cyclePrevious();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: preset.isFlat
                  ? surfaceElevated.withValues(alpha: 0.6)
                  : accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: preset.isFlat
                    ? Colors.white.withValues(alpha: 0.1)
                    : accent.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  preset.icon,
                  size: compact ? 16 : 18,
                  color: preset.isFlat ? textPrimary : accent,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Text(
                    compact ? preset.label : 'EQ: ${preset.label}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: preset.isFlat ? textPrimary : accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                QuickPresetMiniVisualizer(
                  gains: preset.gains,
                  height: compact ? 14 : 18,
                  barWidth: 2.0,
                  spacing: 1.5,
                  barColor: preset.isFlat ? textPrimary : accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// UI Component: QuickPresetHudOverlay
// ============================================================================

/// Overlay widget that wraps content to handle EQ cycling hotkeys (`Ctrl+E`, `Alt+E`)
/// and displays an animated, frosted Material 3 floating HUD toast.
class QuickPresetHudOverlay extends ConsumerStatefulWidget {
  /// Content to wrap with hotkeys and floating HUD toast.
  final Widget child;

  /// Whether desktop keyboard shortcut listening is active.
  final bool enableHotkeys;

  /// Duration to display floating HUD toast before auto-dismissal.
  final Duration hudDuration;

  /// Screen alignment for the floating HUD toast.
  final Alignment hudAlignment;

  /// Margin around the floating HUD toast.
  final EdgeInsetsGeometry hudMargin;

  /// Optional listener invoked when preset changes.
  final void Function(QuickPresetInfo preset)? onPresetChanged;

  const QuickPresetHudOverlay({
    super.key,
    required this.child,
    this.enableHotkeys = true,
    this.hudDuration = const Duration(milliseconds: 1800),
    this.hudAlignment = Alignment.topCenter,
    this.hudMargin = const EdgeInsets.only(top: 48),
    this.onPresetChanged,
  });

  @override
  ConsumerState<QuickPresetHudOverlay> createState() =>
      _QuickPresetHudOverlayState();
}

class _QuickPresetHudOverlayState extends ConsumerState<QuickPresetHudOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  final FocusNode _focusNode = FocusNode(debugLabel: 'QuickPresetHudFocus');

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInBack,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _animController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    _pulseController.forward().then((_) {
      if (mounted) {
        _pulseController.reverse();
      }
    });
  }

  void _handleCycleNext() {
    final notifier = ref.read(quickPresetStateProvider.notifier);
    final preset = notifier.cycleNext();
    widget.onPresetChanged?.call(preset);
    _triggerPulse();
  }

  void _handleCyclePrevious() {
    final notifier = ref.read(quickPresetStateProvider.notifier);
    final preset = notifier.cyclePrevious();
    widget.onPresetChanged?.call(preset);
    _triggerPulse();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickPresetStateProvider);
    final preset = state.currentPreset;

    // React to visibility state
    if (state.isHudVisible) {
      if (!_animController.isAnimating && _animController.value < 1.0) {
        _animController.forward();
      }
    } else {
      if (!_animController.isAnimating && _animController.value > 0.0) {
        _animController.reverse();
      }
    }

    Widget content = Stack(
      alignment: widget.hudAlignment,
      children: [
        widget.child,

        // Floating HUD Toast
        Positioned.fill(
          child: Align(
            alignment: widget.hudAlignment,
            child: Padding(
              padding: widget.hudMargin,
              child: IgnorePointer(
                ignoring: !state.isHudVisible,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: _QuickPresetHudToastCard(
                        preset: preset,
                        onDismiss: () {
                          ref
                              .read(quickPresetStateProvider.notifier)
                              .dismissHud();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (!widget.enableHotkeys) {
      return content;
    }

    // Keyboard shortcut bindings for Desktop Linux & multiplatform
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyE, control: true):
          _handleCycleNext,
      const SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true):
          _handleCyclePrevious,
      const SingleActivator(LogicalKeyboardKey.keyE, alt: true):
          _handleCycleNext,
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
          _handleCycleNext,
    };

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        focusNode: _focusNode,
        autofocus: false,
        canRequestFocus: false,
        child: content,
      ),
    );
  }
}

// ============================================================================
// UI Component: _QuickPresetHudToastCard (Frosted Toast Presentation)
// ============================================================================

class _QuickPresetHudToastCard extends StatelessWidget {
  final QuickPresetInfo preset;
  final VoidCallback onDismiss;

  const _QuickPresetHudToastCard({
    required this.preset,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    final accent = tokens?.accent ?? AppTheme.accent;
    final textPrimary = tokens?.textPrimary ?? AppTheme.textPrimary;
    final textSecondary = tokens?.textSecondary ?? AppTheme.textSecondary;

    return GestureDetector(
      onTap: onDismiss,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420, minWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xE613151B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  offset: const Offset(0, 2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Category Microtag & Step Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.equalizer_rounded,
                          size: 13,
                          color: accent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'EQUALIZER PRESET',
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    _buildPillStepIndicator(accent),
                  ],
                ),
                const SizedBox(height: 8),

                // Main Content Row: Icon Avatar + Name/Subtitle + Mini EQ Visualizer
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Glowing Icon Avatar
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        preset.icon,
                        size: 22,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Preset Name and Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            preset.label,
                            style: TextStyle(
                              fontFamily: AppTheme.fontDisplay,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.subtitle,
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 10-Band EQ Curve Visualizer
                    QuickPresetMiniVisualizer(
                      gains: preset.gains,
                      height: 28,
                      barWidth: 3.0,
                      spacing: 2.0,
                      barColor: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Bottom Hint Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      preset.description,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: textSecondary.withValues(alpha: 0.75),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Ctrl + E to cycle',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillStepIndicator(Color accent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(preset.totalCount, (i) {
        final isActive = i == preset.index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(left: 4),
          width: isActive ? 16 : 5,
          height: 4,
          decoration: BoxDecoration(
            color: isActive ? accent : Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ============================================================================
// UI Component: QuickPresetSelectorRow
// ============================================================================

/// Horizontal scrollable chip row of all 6 presets for quick selection.
class QuickPresetSelectorRow extends ConsumerWidget {
  final EdgeInsetsGeometry padding;

  const QuickPresetSelectorRow({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quickPresetStateProvider);
    final notifier = ref.read(quickPresetStateProvider.notifier);

    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    final accent = tokens?.accent ?? AppTheme.accent;
    final textPrimary = tokens?.textPrimary ?? AppTheme.textPrimary;
    final textSecondary = tokens?.textSecondary ?? AppTheme.textSecondary;
    final surfaceElevated = tokens?.surfaceElevated ?? AppTheme.surfaceElevated;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: state.presets.map((preset) {
          final isSelected = preset.index == state.currentIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  notifier.selectPreset(preset);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: 0.2)
                        : surfaceElevated.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? accent
                          : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        preset.icon,
                        size: 16,
                        color: isSelected ? accent : textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        preset.label,
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? textPrimary : textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
