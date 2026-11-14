import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Constants & Preference Keys
// ============================================================================

/// SharedPreferences persistent storage key for including current track.
const String kQueueDurationIncludeCurrentPrefKey =
    'softify_queue_duration_include_current';

/// SharedPreferences persistent storage key for compact display mode.
const String kQueueDurationCompactModePrefKey =
    'softify_queue_duration_compact_mode';

// ============================================================================
// SharedPreferences Persistence Layer
// ============================================================================

/// Lightweight disk-backed and memory-cached storage interface for queue
/// duration counter user preferences.
class QueueDurationPrefsStorage {
  static final QueueDurationPrefsStorage _instance =
      QueueDurationPrefsStorage._internal();
  factory QueueDurationPrefsStorage() => _instance;
  QueueDurationPrefsStorage._internal();

  static Map<String, Object>? _mockInitialValues;

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;

  /// Sets mock initial values for unit and widget tests.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance._memoryCache = Map<String, dynamic>.from(values);
    _instance._isLoaded = true;
  }

  /// Resets the cached store and mock environment.
  static void reset() {
    _mockInitialValues = null;
    _instance._memoryCache.clear();
    _instance._isLoaded = false;
    _instance._cacheFile = null;
  }

  /// Initializes storage and loads cached values from disk.
  Future<void> init() async {
    if (_isLoaded) return;
    if (_mockInitialValues != null) {
      _memoryCache = Map<String, dynamic>.from(_mockInitialValues!);
      _isLoaded = true;
      return;
    }

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
      // In testing or restricted sandbox, fallback seamlessly to in-memory store
    } finally {
      _isLoaded = true;
    }
  }

  /// Reads a boolean setting from persistent storage.
  Future<bool?> getBool(String key) async {
    if (!_isLoaded) await init();
    final val = _memoryCache[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return null;
  }

  /// Writes a boolean setting to persistent storage and disk cache.
  Future<bool> setBool(String key, bool value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    if (_mockInitialValues != null) {
      _mockInitialValues![key] = value;
      return true;
    }

    try {
      if (_cacheFile != null) {
        if (!await _cacheFile!.parent.exists()) {
          await _cacheFile!.parent.create(recursive: true);
        }
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache), flush: true);
      }
    } catch (_) {
      // Memory cache is already updated
    }
    return true;
  }
}

// ============================================================================
// Model: QueueDurationSummary
// ============================================================================

/// Immutable summary holding dynamic playback queue duration and track count statistics.
@immutable
class QueueDurationSummary {
  /// Total unplayed duration remaining in the queue from the active track index.
  final Duration remainingDuration;

  /// Count of unplayed tracks remaining in the queue (including active track if enabled).
  final int remainingTrackCount;

  /// Total duration of all tracks currently in the queue.
  final Duration totalDuration;

  /// Total count of all tracks in the queue.
  final int totalTrackCount;

  /// Active track index in the queue (-1 if unstarted or unknown).
  final int currentIndex;

  /// Playback progress elapsed within the active track.
  final Duration currentPosition;

  /// Whether the remaining duration includes the unplayed portion of the active track.
  final bool includeCurrentTrack;

  const QueueDurationSummary({
    required this.remainingDuration,
    required this.remainingTrackCount,
    required this.totalDuration,
    required this.totalTrackCount,
    required this.currentIndex,
    this.currentPosition = Duration.zero,
    this.includeCurrentTrack = true,
  });

  /// An empty default summary representing an idle or empty playback queue.
  static const QueueDurationSummary empty = QueueDurationSummary(
    remainingDuration: Duration.zero,
    remainingTrackCount: 0,
    totalDuration: Duration.zero,
    totalTrackCount: 0,
    currentIndex: -1,
    currentPosition: Duration.zero,
    includeCurrentTrack: true,
  );

  /// Whether the queue contains zero tracks.
  bool get isEmpty => totalTrackCount == 0;

  /// Whether the queue contains at least one track.
  bool get isNotEmpty => !isEmpty;

  /// Whether there are tracks remaining to be played.
  bool get hasRemaining =>
      remainingTrackCount > 0 && remainingDuration > Duration.zero;

  /// Number of completed tracks that have already been played.
  int get completedTrackCount {
    final count = totalTrackCount - remainingTrackCount;
    return count < 0 ? 0 : count;
  }

  /// Total duration of music already played or completed in the current queue session.
  Duration get completedDuration {
    if (totalDuration <= remainingDuration) return Duration.zero;
    return totalDuration - remainingDuration;
  }

  /// Completion progress fraction across the entire queue between 0.0 and 1.0.
  double get progressFraction {
    if (totalDuration.inMilliseconds <= 0) return 0.0;
    return (completedDuration.inMilliseconds / totalDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  /// Formats this summary into the standard humanized queue duration label.
  ///
  /// Example: `"1 hr 14 min remaining · 18 tracks"`
  String get humanized => QueueDurationFormatter.formatSummary(this);

  /// Computes the estimated clock time when the current queue will finish playing.
  DateTime? estimatedEndTime({DateTime? fromTime}) {
    if (remainingDuration <= Duration.zero) return null;
    return (fromTime ?? DateTime.now()).add(remainingDuration);
  }

  QueueDurationSummary copyWith({
    Duration? remainingDuration,
    int? remainingTrackCount,
    Duration? totalDuration,
    int? totalTrackCount,
    int? currentIndex,
    Duration? currentPosition,
    bool? includeCurrentTrack,
  }) {
    return QueueDurationSummary(
      remainingDuration: remainingDuration ?? this.remainingDuration,
      remainingTrackCount: remainingTrackCount ?? this.remainingTrackCount,
      totalDuration: totalDuration ?? this.totalDuration,
      totalTrackCount: totalTrackCount ?? this.totalTrackCount,
      currentIndex: currentIndex ?? this.currentIndex,
      currentPosition: currentPosition ?? this.currentPosition,
      includeCurrentTrack: includeCurrentTrack ?? this.includeCurrentTrack,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueDurationSummary &&
          runtimeType == other.runtimeType &&
          remainingDuration == other.remainingDuration &&
          remainingTrackCount == other.remainingTrackCount &&
          totalDuration == other.totalDuration &&
          totalTrackCount == other.totalTrackCount &&
          currentIndex == other.currentIndex &&
          currentPosition == other.currentPosition &&
          includeCurrentTrack == other.includeCurrentTrack;

  @override
  int get hashCode => Object.hash(
        remainingDuration,
        remainingTrackCount,
        totalDuration,
        totalTrackCount,
        currentIndex,
        currentPosition,
        includeCurrentTrack,
      );

  @override
  String toString() =>
      'QueueDurationSummary(remaining: $remainingDuration, remainingTracks: $remainingTrackCount, total: $totalDuration, totalTracks: $totalTrackCount, index: $currentIndex, pos: $currentPosition, includeCurrent: $includeCurrentTrack)';
}

// ============================================================================
// Calculator: QueueDurationCalculator
// ============================================================================

/// Pure business logic calculator that computes queue duration metrics, remaining
/// track counts, and whole-queue aggregates based on the active queue index and
/// playback position.
class QueueDurationCalculator {
  const QueueDurationCalculator._();

  /// Computes remaining total duration in [queue] starting from [currentIndex].
  ///
  /// Behavior:
  /// - If [queue] is empty, returns [Duration.zero].
  /// - If [currentIndex] is past the queue bounds (`currentIndex >= queue.length`),
  ///   returns [Duration.zero].
  /// - If [currentIndex] < 0 (unstarted queue), returns the sum of all track durations.
  /// - If [includeCurrentTrack] is true:
  ///   Adds the unplayed portion of `queue[currentIndex]` (`track.duration - currentPosition`,
  ///   clamped to >= 0) plus the sum of durations of all tracks from `currentIndex + 1` to end.
  /// - If [includeCurrentTrack] is false:
  ///   Includes only the upcoming tracks strictly after `currentIndex`.
  /// - Guards against negative track durations by clamping individual items to [Duration.zero].
  static Duration computeRemainingDuration({
    required List<Track> queue,
    required int currentIndex,
    Duration currentPosition = Duration.zero,
    bool includeCurrentTrack = true,
  }) {
    if (queue.isEmpty) return Duration.zero;
    if (currentIndex >= queue.length) return Duration.zero;

    Duration total = Duration.zero;

    if (currentIndex < 0) {
      for (final t in queue) {
        if (t.duration > Duration.zero) {
          total += t.duration;
        }
      }
      return total;
    }

    // Unplayed remainder of the active song
    if (includeCurrentTrack) {
      final currentTrack = queue[currentIndex];
      final trackDur =
          currentTrack.duration > Duration.zero ? currentTrack.duration : Duration.zero;
      final safePos =
          currentPosition < Duration.zero ? Duration.zero : currentPosition;
      final remainingOnCurrent =
          trackDur > safePos ? trackDur - safePos : Duration.zero;
      total += remainingOnCurrent;
    }

    // All upcoming tracks strictly after active track
    for (int i = currentIndex + 1; i < queue.length; i++) {
      final t = queue[i];
      if (t.duration > Duration.zero) {
        total += t.duration;
      }
    }

    return total;
  }

  /// Computes the number of remaining tracks to be played in [queue].
  ///
  /// Behavior:
  /// - If [queue] is empty, returns 0.
  /// - If [currentIndex] < 0, returns the total queue length.
  /// - If [currentIndex] >= queue.length, returns 0.
  /// - If [includeCurrentTrack] is true: returns `queue.length - currentIndex`.
  /// - If [includeCurrentTrack] is false: returns `queue.length - 1 - currentIndex` (clamped >= 0).
  static int computeRemainingTrackCount({
    required List<Track> queue,
    required int currentIndex,
    bool includeCurrentTrack = true,
  }) {
    if (queue.isEmpty) return 0;
    if (currentIndex >= queue.length) return 0;
    if (currentIndex < 0) return queue.length;

    if (includeCurrentTrack) {
      return queue.length - currentIndex;
    } else {
      final upcoming = queue.length - 1 - currentIndex;
      return upcoming < 0 ? 0 : upcoming;
    }
  }

  /// Calculates the total duration of all tracks in [queue].
  static Duration computeTotalQueueDuration(List<Track> queue) {
    if (queue.isEmpty) return Duration.zero;
    Duration total = Duration.zero;
    for (final t in queue) {
      if (t.duration > Duration.zero) {
        total += t.duration;
      }
    }
    return total;
  }

  /// Computes a full [QueueDurationSummary] representing the current queue state.
  static QueueDurationSummary computeSummary({
    required List<Track> queue,
    required int currentIndex,
    Duration currentPosition = Duration.zero,
    bool includeCurrentTrack = true,
  }) {
    final remainingDur = computeRemainingDuration(
      queue: queue,
      currentIndex: currentIndex,
      currentPosition: currentPosition,
      includeCurrentTrack: includeCurrentTrack,
    );
    final remainingCount = computeRemainingTrackCount(
      queue: queue,
      currentIndex: currentIndex,
      includeCurrentTrack: includeCurrentTrack,
    );
    final totalDur = computeTotalQueueDuration(queue);

    return QueueDurationSummary(
      remainingDuration: remainingDur,
      remainingTrackCount: remainingCount,
      totalDuration: totalDur,
      totalTrackCount: queue.length,
      currentIndex: currentIndex,
      currentPosition: currentPosition,
      includeCurrentTrack: includeCurrentTrack,
    );
  }
}

// ============================================================================
// Formatter: QueueDurationFormatter
// ============================================================================

/// Pure string formatter that produces humanized, localized duration labels,
/// adhering strictly to formats like:
/// `"1 hr 14 min remaining · 18 tracks"`
class QueueDurationFormatter {
  const QueueDurationFormatter._();

  /// Formats a remaining duration and track count into humanized music player text.
  ///
  /// Examples:
  /// - `1 hr 14 min remaining · 18 tracks`
  /// - `45 min remaining · 12 tracks`
  /// - `1 hr remaining · 8 tracks`
  /// - `3 min remaining · 1 track`
  /// - `< 1 min remaining · 1 track`
  /// - `0 min remaining · 0 tracks`
  static String formatHumanizedRemaining({
    required Duration remainingDuration,
    required int trackCount,
    bool includeRemainingWord = true,
    bool showTrackCount = true,
    String separator = ' · ',
    bool allowSeconds = false,
    bool pluralHours = false,
  }) {
    final durationPart = formatDuration(
      remainingDuration,
      allowSeconds: allowSeconds,
      pluralHours: pluralHours,
    );

    final suffix = includeRemainingWord ? ' remaining' : '';
    final timeStr = '$durationPart$suffix';

    if (!showTrackCount) {
      return timeStr;
    }

    final trackLabel = trackCount == 1 ? 'track' : 'tracks';
    final trackStr = '$trackCount $trackLabel';

    return '$timeStr$separator$trackStr';
  }

  /// Formats a [Duration] into humanized components:
  /// - Both hours and minutes: `"1 hr 14 min"`
  /// - Hours only: `"1 hr"` (or `"2 hrs"` if [pluralHours] is true)
  /// - Minutes only: `"45 min"`
  /// - Under one minute: `"< 1 min"` (or `"45 sec"` if [allowSeconds] is true)
  /// - Zero duration: `"0 min"`
  static String formatDuration(
    Duration duration, {
    bool compact = false,
    bool allowSeconds = false,
    bool pluralHours = false,
  }) {
    if (duration <= Duration.zero) {
      return compact ? '0m' : '0 min';
    }

    final totalSeconds = duration.inSeconds;
    final totalMinutes = duration.inMinutes;
    final hours = duration.inHours;
    final minutes = totalMinutes % 60;
    final seconds = totalSeconds % 60;

    if (compact) {
      if (hours > 0) {
        return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
      }
      if (minutes > 0) {
        return '${minutes}m';
      }
      return '${seconds}s';
    }

    final hourUnit = (pluralHours && hours > 1) ? 'hrs' : 'hr';

    if (hours > 0) {
      if (minutes > 0) {
        return '$hours $hourUnit $minutes min';
      }
      return '$hours $hourUnit';
    }

    if (minutes > 0) {
      return '$minutes min';
    }

    if (allowSeconds && seconds > 0) {
      return '$seconds sec';
    }

    return '< 1 min';
  }

  /// Formats a complete [QueueDurationSummary] using standard display options.
  static String formatSummary(
    QueueDurationSummary? summary, {
    bool includeRemainingWord = true,
    bool showTrackCount = true,
    String separator = ' · ',
    bool compact = false,
    bool allowSeconds = false,
    bool pluralHours = false,
  }) {
    final s = summary ?? QueueDurationSummary.empty;
    if (compact) {
      return formatCompact(s);
    }

    return formatHumanizedRemaining(
      remainingDuration: s.remainingDuration,
      trackCount: s.remainingTrackCount,
      includeRemainingWord: includeRemainingWord,
      showTrackCount: showTrackCount,
      separator: separator,
      allowSeconds: allowSeconds,
      pluralHours: pluralHours,
    );
  }

  /// Formats a compact representation suitable for tight UI elements or narrow sidebars:
  /// e.g. `"1h 14m · 18 tracks"`
  static String formatCompact(
    QueueDurationSummary? summary, {
    String separator = ' · ',
  }) {
    final s = summary ?? QueueDurationSummary.empty;
    final time = formatDuration(s.remainingDuration, compact: true);
    final count = s.remainingTrackCount;
    final trackLabel = count == 1 ? 'track' : 'tracks';
    return '$time$separator$count $trackLabel';
  }

  /// Formats a [DateTime] into a friendly 12-hour or 24-hour clock time.
  ///
  /// Example: `"4:32 PM"` or `"16:32"`
  static String formatTimeOfDay(DateTime time, {bool use24Hour = false}) {
    if (use24Hour) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    final hour12 = time.hour == 0
        ? 12
        : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  /// Formats a duration into standard digital display: `"MM:SS"` or `"HH:MM:SS"`.
  static String formatDigital(Duration duration) {
    if (duration <= Duration.zero) return '0:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final secondsPadded = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final minutesPadded = minutes.toString().padLeft(2, '0');
      return '$hours:$minutesPadded:$secondsPadded';
    }
    return '$minutes:$secondsPadded';
  }
}

// ============================================================================
// State Management & Riverpod Providers
// ============================================================================

/// Provider supplying the storage engine for queue duration counter preferences.
final queueDurationPrefsStorageProvider =
    Provider<QueueDurationPrefsStorage>((ref) {
  return QueueDurationPrefsStorage();
});

/// Notifier managing whether the current track is included in the queue remaining duration.
class QueueDurationIncludeCurrentNotifier extends StateNotifier<bool> {
  final QueueDurationPrefsStorage _storage;

  QueueDurationIncludeCurrentNotifier({
    QueueDurationPrefsStorage? storage,
    bool initialValue = true,
  })  : _storage = storage ?? QueueDurationPrefsStorage(),
        super(initialValue) {
    _loadPersistedPreference();
  }

  Future<void> _loadPersistedPreference() async {
    final persisted =
        await _storage.getBool(kQueueDurationIncludeCurrentPrefKey);
    if (persisted != null && mounted) {
      state = persisted;
    }
  }

  /// Toggles whether current track is included in remaining calculation.
  Future<void> toggle() async {
    await setIncludeCurrent(!state);
  }

  /// Sets whether current track is included in remaining calculation.
  Future<void> setIncludeCurrent(bool value) async {
    if (state == value) return;
    state = value;
    await _storage.setBool(kQueueDurationIncludeCurrentPrefKey, value);
  }
}

/// Provider managing whether to include the active track in queue duration calculations.
final queueDurationIncludeCurrentTrackProvider =
    StateNotifierProvider<QueueDurationIncludeCurrentNotifier, bool>((ref) {
  final storage = ref.watch(queueDurationPrefsStorageProvider);
  return QueueDurationIncludeCurrentNotifier(storage: storage);
});

/// Primary Riverpod provider delivering real-time [QueueDurationSummary] metrics.
///
/// Watches:
/// - [queueProvider] for the current list of tracks.
/// - [audioHandlerProvider] for the active queue index.
/// - [positionStreamProvider] for real-time elapsed position of active track.
/// - [queueDurationIncludeCurrentTrackProvider] for user calculation preference.
final queueDurationSummaryProvider = Provider<QueueDurationSummary>((ref) {
  final queueAsync = ref.watch(queueProvider);
  List<Track> queue = queueAsync.value ?? const <Track>[];

  int currentIndex = -1;
  Duration currentPosition = Duration.zero;

  try {
    final audioHandler = ref.watch(audioHandlerProvider);
    currentIndex = audioHandler.currentIndex;
    if (queue.isEmpty && audioHandler.currentQueue.isNotEmpty) {
      queue = audioHandler.currentQueue;
    }
  } catch (_) {
    // Audio handler may be uninitialized or mock-substituted
  }

  // Fallback: match currentTrack in queue if currentIndex is unresolved
  if (currentIndex < 0 || currentIndex >= queue.length) {
    try {
      final currentTrackAsync = ref.watch(currentTrackProvider);
      final currentTrack = currentTrackAsync.value;
      if (currentTrack != null) {
        final idx = queue.indexWhere((t) => t.id == currentTrack.id);
        if (idx != -1) currentIndex = idx;
      }
    } catch (_) {}
  }

  try {
    final posAsync = ref.watch(positionStreamProvider);
    currentPosition = posAsync.value ?? Duration.zero;
  } catch (_) {}

  final includeCurrent = ref.watch(queueDurationIncludeCurrentTrackProvider);

  return QueueDurationCalculator.computeSummary(
    queue: queue,
    currentIndex: currentIndex,
    currentPosition: currentPosition,
    includeCurrentTrack: includeCurrent,
  );
});

/// Convenience provider returning the ready-to-display humanized string:
/// `"1 hr 14 min remaining · 18 tracks"`
final queueRemainingDurationFormattedProvider = Provider<String>((ref) {
  final summary = ref.watch(queueDurationSummaryProvider);
  return summary.humanized;
});

// ============================================================================
// UI Component: QueueRemainingDurationChip
// ============================================================================

/// Material 3 chip widget displaying remaining queue duration and track count.
///
/// Renders standard output such as:
/// `"1 hr 14 min remaining · 18 tracks"`
///
/// Supports automatic Riverpod observation or explicit [summary] injection.
/// When tapped without a custom [onTap] handler, opens a detail modal with
/// total queue statistics and estimation controls.
class QueueRemainingDurationChip extends ConsumerWidget {
  /// Optional precomputed summary. If null, automatically watches [queueDurationSummaryProvider].
  final QueueDurationSummary? summary;

  /// Custom tap callback. If null, opens [QueueDurationDetailModal].
  final VoidCallback? onTap;

  /// Whether to display the leading clock icon.
  final bool showIcon;

  /// Icon data for the leading indicator.
  final IconData icon;

  /// Compact display mode (e.g. `"1h 14m · 18 tracks"`).
  final bool compact;

  /// Whether to include the word "remaining" in the label.
  final bool showRemainingWord;

  /// Whether to show the track count portion (e.g. `"· 18 tracks"`).
  final bool showTrackCount;

  /// Whether hovering or long-pressing shows a rich breakdown tooltip.
  final bool enableTooltip;

  /// Padding surrounding chip contents.
  final EdgeInsetsGeometry? padding;

  /// Custom chip background color.
  final Color? backgroundColor;

  /// Custom foreground/text color.
  final Color? foregroundColor;

  /// Custom typography style.
  final TextStyle? textStyle;

  /// Custom corner border radius.
  final BorderRadius? borderRadius;

  /// Whether interactive press actions and cursor changes are enabled.
  final bool interactive;

  const QueueRemainingDurationChip({
    super.key,
    this.summary,
    this.onTap,
    this.showIcon = true,
    this.icon = Icons.schedule_rounded,
    this.compact = false,
    this.showRemainingWord = true,
    this.showTrackCount = true,
    this.enableTooltip = true,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.textStyle,
    this.borderRadius,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final QueueDurationSummary activeSummary = summary ?? ref.watch(queueDurationSummaryProvider);
    final tokens = Theme.of(context).extension<AppTokens>();
    final theme = Theme.of(context);

    final resolvedText = QueueDurationFormatter.formatSummary(
      activeSummary,
      compact: compact,
      includeRemainingWord: showRemainingWord,
      showTrackCount: showTrackCount,
    );

    final defaultTextColor = tokens?.textSecondary ??
        theme.colorScheme.onSurfaceVariant;

    final textColor = foregroundColor ?? defaultTextColor;

    final defaultBgColor = tokens?.surfaceElevated ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    final bgColor = backgroundColor ?? defaultBgColor;

    final defaultBorderColor = tokens?.glassBorder ??
        theme.colorScheme.outlineVariant.withValues(alpha: 0.3);

    final radius = borderRadius ?? BorderRadius.circular(16.0);

    final resolvedTextStyle = (textStyle ??
        TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: textColor,
        ));

    final chipChild = InkWell(
      onTap: interactive
          ? (onTap ?? () => _showDetailModal(context, activeSummary))
          : null,
      borderRadius: radius,
      child: Container(
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: radius,
          border: Border.all(color: defaultBorderColor, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showIcon) ...[
              Icon(
                icon,
                size: 14.0,
                color: textColor.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6.0),
            ],
            Text(
              resolvedText,
              style: resolvedTextStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    if (!enableTooltip) {
      return Semantics(
        label: 'Queue duration remaining: $resolvedText',
        button: interactive,
        child: chipChild,
      );
    }

    final endTime = activeSummary.estimatedEndTime();
    final endTimeStr = endTime != null
        ? QueueDurationFormatter.formatTimeOfDay(endTime)
        : 'N/A';

    final tooltipMessage = 'Remaining: ${QueueDurationFormatter.formatDuration(activeSummary.remainingDuration)} (${activeSummary.remainingTrackCount} tracks)\n'
        'Total Queue: ${QueueDurationFormatter.formatDuration(activeSummary.totalDuration)} (${activeSummary.totalTrackCount} tracks)\n'
        'Finishes at: $endTimeStr';

    return Tooltip(
      message: tooltipMessage,
      waitDuration: const Duration(milliseconds: 400),
      showDuration: const Duration(seconds: 4),
      child: Semantics(
        label: 'Queue duration remaining: $resolvedText',
        button: interactive,
        child: chipChild,
      ),
    );
  }

  void _showDetailModal(BuildContext context, [QueueDurationSummary? summary]) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => QueueDurationDetailModal(summary: summary),
    );
  }
}

// ============================================================================
// UI Modal: QueueDurationDetailModal
// ============================================================================

/// Modal sheet showcasing granular queue metrics, progress bars, and duration
/// calculation preferences.
class QueueDurationDetailModal extends ConsumerWidget {
  final QueueDurationSummary? summary;

  const QueueDurationDetailModal({super.key, this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final QueueDurationSummary activeSummary = summary ?? ref.watch(queueDurationSummaryProvider);
    final includeCurrent =
        ref.watch(queueDurationIncludeCurrentTrackProvider);
    final tokens = Theme.of(context).extension<AppTokens>();
    final theme = Theme.of(context);

    final bg = tokens?.surface ?? theme.colorScheme.surface;
    final textPrimary = tokens?.textPrimary ?? theme.colorScheme.onSurface;
    final textSecondary =
        tokens?.textSecondary ?? theme.colorScheme.onSurfaceVariant;
    final accent = tokens?.accent ?? theme.colorScheme.primary;

    final endTime = activeSummary.estimatedEndTime();
    final endTimeText = endTime != null
        ? QueueDurationFormatter.formatTimeOfDay(endTime)
        : 'Queue ended';

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20.0,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Title
            Row(
              children: [
                Icon(Icons.queue_music_rounded, color: accent, size: 22.0),
                const SizedBox(width: 10.0),
                Text(
                  'Queue Duration Statistics',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: LinearProgressIndicator(
                value: activeSummary.progressFraction,
                minHeight: 8.0,
                backgroundColor: textSecondary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 16.0),

            // Metric Cards Grid
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    title: 'Remaining',
                    value: QueueDurationFormatter.formatDuration(
                      activeSummary.remainingDuration,
                    ),
                    subtitle: '${activeSummary.remainingTrackCount} tracks',
                    icon: Icons.hourglass_top_rounded,
                    accentColor: accent,
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: _MetricTile(
                    title: 'Completed',
                    value: QueueDurationFormatter.formatDuration(
                      activeSummary.completedDuration,
                    ),
                    subtitle: '${activeSummary.completedTrackCount} tracks',
                    icon: Icons.check_circle_outline_rounded,
                    accentColor: Colors.tealAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    title: 'Total Queue',
                    value: QueueDurationFormatter.formatDuration(
                      activeSummary.totalDuration,
                    ),
                    subtitle: '${activeSummary.totalTrackCount} tracks total',
                    icon: Icons.library_music_rounded,
                    accentColor: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: _MetricTile(
                    title: 'Estimated Finish',
                    value: endTimeText,
                    subtitle: 'At current playback speed',
                    icon: Icons.access_time_rounded,
                    accentColor: Colors.amberAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),

            // Toggle include current track
            Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Include currently playing song',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Count remaining unplayed time of current track in total',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: textSecondary,
                  ),
                ),
                value: includeCurrent,
                activeTrackColor: accent,
                onChanged: (val) {
                  ref
                      .read(queueDurationIncludeCurrentTrackProvider.notifier)
                      .setIncludeCurrent(val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    final cardBg = tokens?.card ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final textPrimary = tokens?.textPrimary ?? theme.colorScheme.onSurface;
    final textSecondary =
        tokens?.textSecondary ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: (tokens?.glassBorder ?? theme.colorScheme.outlineVariant)
              .withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16.0, color: accentColor),
              const SizedBox(width: 6.0),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.0,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.0,
              color: textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
