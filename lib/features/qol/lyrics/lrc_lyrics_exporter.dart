import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/track.dart';
import '../../../domain/ports/i_lyrics_provider.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/widgets/bouncing_scale_button.dart';
import '../../../presentation/widgets/shared/app_toast.dart';

// ============================================================================
// Enums & Models
// ============================================================================

/// Target format for exported/copied lyrics.
enum LyricsExportFormat {
  /// Standard timestamped format: `[mm:ss.xx] Lyric line`
  lrc,

  /// Clean plain text without timestamps or metadata header tags
  plainText;

  /// User-facing display title.
  String get label {
    switch (this) {
      case LyricsExportFormat.lrc:
        return 'Synced Lyrics (.lrc)';
      case LyricsExportFormat.plainText:
        return 'Plain Text (.txt)';
    }
  }

  /// Compact label for badges and small buttons.
  String get shortLabel {
    switch (this) {
      case LyricsExportFormat.lrc:
        return '.lrc';
      case LyricsExportFormat.plainText:
        return '.txt';
    }
  }

  /// File extension including the leading dot.
  String get fileExtension {
    switch (this) {
      case LyricsExportFormat.lrc:
        return '.lrc';
      case LyricsExportFormat.plainText:
        return '.txt';
    }
  }

  /// Whether this format represents time-synchronized lyrics.
  bool get isSynced => this == LyricsExportFormat.lrc;
}

/// Operational state of clipboard copying.
enum LyricsCopyStatus {
  idle,
  copying,
  copied,
  error,
}

/// Immutable state tracking the latest lyrics copy operation.
@immutable
class LyricsCopyState {
  final LyricsCopyStatus status;
  final LyricsExportFormat? lastFormat;
  final int lineCount;
  final String? errorMessage;
  final DateTime? timestamp;

  const LyricsCopyState({
    this.status = LyricsCopyStatus.idle,
    this.lastFormat,
    this.lineCount = 0,
    this.errorMessage,
    this.timestamp,
  });

  bool get isCopied => status == LyricsCopyStatus.copied;
  bool get isCopying => status == LyricsCopyStatus.copying;
  bool get hasError => status == LyricsCopyStatus.error;
  bool get isIdle => status == LyricsCopyStatus.idle;

  LyricsCopyState copyWith({
    LyricsCopyStatus? status,
    LyricsExportFormat? lastFormat,
    int? lineCount,
    String? errorMessage,
    DateTime? timestamp,
  }) {
    return LyricsCopyState(
      status: status ?? this.status,
      lastFormat: lastFormat ?? this.lastFormat,
      lineCount: lineCount ?? this.lineCount,
      errorMessage: errorMessage ?? this.errorMessage,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsCopyState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          lastFormat == other.lastFormat &&
          lineCount == other.lineCount &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(status, lastFormat, lineCount, errorMessage);

  @override
  String toString() =>
      'LyricsCopyState(status: $status, lastFormat: $lastFormat, lineCount: $lineCount, error: $errorMessage)';
}

// ============================================================================
// Formatter & Exporter Engine: LrcLyricsExporter
// ============================================================================

/// Production-grade utility to format, clean, and export synchronized (.lrc)
/// or plain text lyrics to the system clipboard and external files.
class LrcLyricsExporter {
  const LrcLyricsExporter();

  /// Formats a [Duration] into the standard LRC timestamp tag: `[mm:ss.xx]`.
  ///
  /// - `mm`: minutes (at least 2 digits, supports values >= 60 without wrapping)
  /// - `ss`: 2-digit seconds remainder (00-59)
  /// - `xx`: 2-digit hundredths of a second (centiseconds, 00-99)
  ///
  /// Clamps negative durations to `Duration.zero` (`[00:00.00]`).
  static String formatTimestamp(Duration duration) {
    final nonNegative = duration.isNegative ? Duration.zero : duration;
    final minutes = nonNegative.inMinutes;
    final seconds = nonNegative.inSeconds.remainder(60);
    final centiseconds = (nonNegative.inMilliseconds.remainder(1000) ~/ 10);

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    final xx = centiseconds.toString().padLeft(2, '0');

    return '[$mm:$ss.$xx]';
  }

  /// Generates a standard extended LRC formatted string.
  ///
  /// If [includeMetadataTags] is `true` and metadata is provided, standard header
  /// tags (`[ti:]`, `[ar:]`, `[al:]`, `[length:]`, `[by:Softify]`) are prepended.
  ///
  /// [offsetMs] applies a time shift across all lines (or generates an `[offset:]` tag).
  /// If [applyOffsetToTimestamps] is `true`, each timestamp is adjusted directly.
  static String generateLrc({
    required List<LyricLine> lines,
    Track? track,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    int offsetMs = 0,
    bool includeMetadataTags = true,
    bool applyOffsetToTimestamps = true,
    bool includeDuetAgents = false,
  }) {
    final buffer = StringBuffer();

    // 1. Optional Metadata Header
    if (includeMetadataTags) {
      final effectiveTitle = title ?? track?.title;
      final effectiveArtist = artist ?? track?.artist;
      final effectiveAlbum = album ?? track?.album;
      final effectiveDuration = duration ?? track?.duration;

      if (effectiveTitle != null && effectiveTitle.trim().isNotEmpty) {
        buffer.writeln('[ti:${effectiveTitle.trim()}]');
      }
      if (effectiveArtist != null && effectiveArtist.trim().isNotEmpty) {
        buffer.writeln('[ar:${effectiveArtist.trim()}]');
      }
      if (effectiveAlbum != null && effectiveAlbum.trim().isNotEmpty) {
        buffer.writeln('[al:${effectiveAlbum.trim()}]');
      }
      if (effectiveDuration != null && effectiveDuration > Duration.zero) {
        final m = effectiveDuration.inMinutes.toString().padLeft(2, '0');
        final s = effectiveDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
        buffer.writeln('[length:$m:$s]');
      }
      if (offsetMs != 0 && !applyOffsetToTimestamps) {
        buffer.writeln('[offset:$offsetMs]');
      }
      buffer.writeln('[by:Softify]');
    }

    // 2. Timestamped Lines
    final offsetDuration = Duration(milliseconds: offsetMs);
    for (final line in lines) {
      final effectiveDuration = applyOffsetToTimestamps
          ? (line.timestamp + offsetDuration)
          : line.timestamp;
      final tag = formatTimestamp(effectiveDuration);

      String lineText = line.text;
      if (includeDuetAgents && line.agent != null && line.agent!.trim().isNotEmpty) {
        lineText = '{agent:${line.agent!.trim()}} $lineText';
      }

      buffer.writeln('$tag$lineText');
    }

    return buffer.toString().trimRight();
  }

  /// Cleans raw LRC strings by stripping timestamps, header tags, word-level
  /// sync markers, and vocal agent tags, returning human-readable plain text.
  static String cleanRawLyrics(
    String raw, {
    bool collapseEmptyLines = true,
    bool trimLines = true,
  }) {
    if (raw.trim().isEmpty) return '';

    // Regex patterns for LRC metadata tags and timestamps
    final headerTagRegex = RegExp(
      r'^\[(?:ti|ar|al|au|by|length|offset|re|ve):.*?\]\r?$',
      multiLine: true,
      caseSensitive: false,
    );
    final timestampRegex = RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]');
    final wordSyncRegex = RegExp(r'<(?:\d{1,2}:)?\d{2}(?:[.:]\d{1,3})?>|<\d+>');
    final agentTagRegex = RegExp(r'[\{\[]agent:?\s*[a-zA-Z0-9_-]+[\}\]]', caseSensitive: false);

    // Strip header tags
    String cleaned = raw.replaceAll(headerTagRegex, '');
    // Strip timestamps
    cleaned = cleaned.replaceAll(timestampRegex, '');
    // Strip inline syllable/karaoke markers
    cleaned = cleaned.replaceAll(wordSyncRegex, '');
    // Strip agent annotations
    cleaned = cleaned.replaceAll(agentTagRegex, '');

    final rawLines = cleaned.split(RegExp(r'\r?\n'));
    final List<String> resultLines = [];
    bool previousWasEmpty = false;

    for (final rawLine in rawLines) {
      final line = trimLines ? rawLine.trim() : rawLine;
      final isEmpty = line.isEmpty;

      if (isEmpty) {
        if (collapseEmptyLines) {
          if (!previousWasEmpty && resultLines.isNotEmpty) {
            resultLines.add('');
            previousWasEmpty = true;
          }
        } else {
          resultLines.add('');
        }
      } else {
        resultLines.add(line);
        previousWasEmpty = false;
      }
    }

    // Trim trailing empty lines
    while (resultLines.isNotEmpty && resultLines.last.isEmpty) {
      resultLines.removeLast();
    }
    // Trim leading empty lines
    while (resultLines.isNotEmpty && resultLines.first.isEmpty) {
      resultLines.removeAt(0);
    }

    return resultLines.join('\n');
  }

  /// Generates clean, readable plain lyrics text from structured lines or raw LRC.
  static String generatePlainText({
    List<LyricLine>? lines,
    String? rawLyrics,
    bool collapseEmptyLines = true,
  }) {
    if (lines != null && lines.isNotEmpty) {
      final List<String> resultLines = [];
      bool prevEmpty = false;

      for (final line in lines) {
        final cleanedText = cleanRawLyrics(line.text, collapseEmptyLines: false);
        final isEmpty = cleanedText.trim().isEmpty;

        if (isEmpty) {
          if (collapseEmptyLines) {
            if (!prevEmpty && resultLines.isNotEmpty) {
              resultLines.add('');
              prevEmpty = true;
            }
          } else {
            resultLines.add('');
          }
        } else {
          resultLines.add(cleanedText.trim());
          prevEmpty = false;
        }
      }

      while (resultLines.isNotEmpty && resultLines.last.isEmpty) {
        resultLines.removeLast();
      }
      return resultLines.join('\n');
    }

    if (rawLyrics != null && rawLyrics.trim().isNotEmpty) {
      return cleanRawLyrics(rawLyrics, collapseEmptyLines: collapseEmptyLines);
    }

    return '';
  }

  /// Exports [SyncedLyrics] in the requested [LyricsExportFormat].
  static String export({
    required SyncedLyrics lyrics,
    required LyricsExportFormat format,
    Track? track,
    int offsetMs = 0,
    bool includeMetadata = true,
  }) {
    switch (format) {
      case LyricsExportFormat.lrc:
        if (lyrics.lines.isNotEmpty) {
          return generateLrc(
            lines: lyrics.lines,
            track: track,
            offsetMs: offsetMs,
            includeMetadataTags: includeMetadata,
          );
        } else if (lyrics.rawLrc != null && lyrics.rawLrc!.trim().isNotEmpty) {
          return lyrics.rawLrc!.trim();
        } else if (lyrics.plainLyrics != null && lyrics.plainLyrics!.trim().isNotEmpty) {
          return lyrics.plainLyrics!.trim();
        }
        return '';

      case LyricsExportFormat.plainText:
        if (lyrics.plainLyrics != null && lyrics.plainLyrics!.trim().isNotEmpty) {
          return cleanRawLyrics(lyrics.plainLyrics!);
        } else if (lyrics.lines.isNotEmpty) {
          return generatePlainText(lines: lyrics.lines);
        } else if (lyrics.rawLrc != null && lyrics.rawLrc!.trim().isNotEmpty) {
          return cleanRawLyrics(lyrics.rawLrc!);
        }
        return '';
    }
  }

  /// Counts the number of non-empty lyric lines in a formatted text payload.
  static int countLines(String formattedText) {
    if (formattedText.trim().isEmpty) return 0;
    return formattedText
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('['))
        .length;
  }

  /// Low-level clipboard copy operation.
  static Future<bool> copyToClipboard(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shows an interactive bottom sheet modal with format switching,
  /// live preview, and 1-tap clipboard copy.
  static Future<void> showExportBottomSheet(
    BuildContext context, {
    required SyncedLyrics lyrics,
    Track? track,
    int offsetMs = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _LyricsExportBottomSheet(
        lyrics: lyrics,
        track: track,
        offsetMs: offsetMs,
      ),
    );
  }
}

// ============================================================================
// Riverpod Notifier & Providers
// ============================================================================

/// Manages clipboard copy state, confirmation timers, and toast notifications.
class LyricsCopyNotifier extends StateNotifier<LyricsCopyState> {
  Timer? _resetTimer;

  LyricsCopyNotifier() : super(const LyricsCopyState());

  /// Copies [text] to the system clipboard, triggers haptic feedback,
  /// displays confirmation status, and updates state.
  Future<bool> copyText({
    required String text,
    LyricsExportFormat format = LyricsExportFormat.lrc,
    int lineCount = 0,
    BuildContext? context,
    bool showToast = true,
    String? customSuccessMessage,
  }) async {
    if (text.trim().isEmpty) {
      state = state.copyWith(
        status: LyricsCopyStatus.error,
        errorMessage: 'Lyrics content is empty',
      );
      return false;
    }

    _resetTimer?.cancel();
    _resetTimer = null;
    state = state.copyWith(status: LyricsCopyStatus.copying);

    try {
      await Clipboard.setData(ClipboardData(text: text));
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}

      final effectiveLineCount =
          lineCount > 0 ? lineCount : LrcLyricsExporter.countLines(text);

      state = LyricsCopyState(
        status: LyricsCopyStatus.copied,
        lastFormat: format,
        lineCount: effectiveLineCount,
        timestamp: DateTime.now(),
      );

      if (showToast && context != null && context.mounted) {
        final msg = customSuccessMessage ??
            'Copied ${format.label} to clipboard ($effectiveLineCount lines)';
        AppToast.showSuccess(context, message: msg);
      }

      // Automatically reset status back to idle after 3 seconds
      _resetTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          state = const LyricsCopyState();
        }
      });

      return true;
    } catch (e) {
      state = LyricsCopyState(
        status: LyricsCopyStatus.error,
        lastFormat: format,
        errorMessage: e.toString(),
      );
      if (showToast && context != null && context.mounted) {
        AppToast.showError(context, message: 'Failed to copy lyrics: $e');
      }
      return false;
    }
  }

  /// Formats and copies [lyrics] according to [format].
  Future<bool> copyLyrics({
    required SyncedLyrics lyrics,
    required LyricsExportFormat format,
    Track? track,
    int offsetMs = 0,
    BuildContext? context,
    bool showToast = true,
    bool includeMetadata = true,
  }) async {
    final content = LrcLyricsExporter.export(
      lyrics: lyrics,
      format: format,
      track: track,
      offsetMs: offsetMs,
      includeMetadata: includeMetadata,
    );
    final count = LrcLyricsExporter.countLines(content);

    return copyText(
      text: content,
      format: format,
      lineCount: count,
      context: context,
      showToast: showToast,
    );
  }

  /// Manually resets confirmation state to idle.
  void reset() {
    _resetTimer?.cancel();
    _resetTimer = null;
    if (mounted) {
      state = const LyricsCopyState();
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }
}

/// Provider managing active lyrics clipboard copy status.
final lyricsCopyNotifierProvider =
    StateNotifierProvider<LyricsCopyNotifier, LyricsCopyState>((ref) {
  return LyricsCopyNotifier();
});

/// Provider for pure [LrcLyricsExporter] instance.
final lrcLyricsExporterProvider = Provider<LrcLyricsExporter>((ref) {
  return const LrcLyricsExporter();
});

// ============================================================================
// UI Widget: CopyLyricsButton
// ============================================================================

/// Material 3 button with animated confirmation feedback to copy synced (.lrc)
/// or plain text lyrics to the system clipboard.
///
/// Supports:
/// - Single-click default copy or Popup Menu to choose format
/// - Animated checkmark and label transition upon successful copy
/// - Automatic sync offset inclusion when [track] is provided
/// - Compact icon-only mode or full button with label
class CopyLyricsButton extends ConsumerWidget {
  /// The lyrics object to export. If null or empty, button disables.
  final SyncedLyrics? lyrics;

  /// Optional track metadata for LRC tags and sync offset lookup.
  final Track? track;

  /// Fallback/default export format when tapped directly.
  final LyricsExportFormat defaultFormat;

  /// Whether to render in compact icon-only mode.
  final bool compact;

  /// If true, clicking opens a popup menu to choose between LRC and Plain Text.
  /// If false, clicking immediately copies [defaultFormat].
  final bool showFormatMenu;

  /// Callback invoked when copy succeeds.
  final ValueChanged<LyricsExportFormat>? onCopied;

  /// Foreground icon/text color in idle state.
  final Color? color;

  /// Active color when copied (defaults to [AppTheme.accent]).
  final Color? activeColor;

  /// Custom tooltip text.
  final String? tooltip;

  /// Internal padding.
  final EdgeInsetsGeometry? padding;

  /// Icon size.
  final double iconSize;

  /// Whether to display toast snackbar notification on copy.
  final bool showToast;

  const CopyLyricsButton({
    super.key,
    required this.lyrics,
    this.track,
    this.defaultFormat = LyricsExportFormat.lrc,
    this.compact = false,
    this.showFormatMenu = true,
    this.onCopied,
    this.color,
    this.activeColor,
    this.tooltip,
    this.padding,
    this.iconSize = 18.0,
    this.showToast = true,
  });

  bool get _hasValidLyrics {
    if (lyrics == null) return false;
    final l = lyrics!;
    return l.lines.isNotEmpty ||
        (l.rawLrc != null && l.rawLrc!.trim().isNotEmpty) ||
        (l.plainLyrics != null && l.plainLyrics!.trim().isNotEmpty);
  }

  Future<void> _executeCopy(
    BuildContext context,
    WidgetRef ref,
    LyricsExportFormat format,
  ) async {
    if (!_hasValidLyrics) return;

    int offsetMs = 0;
    if (track != null) {
      try {
        offsetMs = ref.read(lyricsOffsetProvider(track!.id));
      } catch (_) {}
    }

    final notifier = ref.read(lyricsCopyNotifierProvider.notifier);
    final success = await notifier.copyLyrics(
      lyrics: lyrics!,
      format: format,
      track: track,
      offsetMs: offsetMs,
      context: context,
      showToast: showToast,
    );

    if (success && onCopied != null) {
      onCopied!(format);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final copyState = ref.watch(lyricsCopyNotifierProvider);
    final isCopied = copyState.isCopied;
    final isEnabled = _hasValidLyrics;

    final resolvedActiveColor = activeColor ?? tokens.accent;
    final resolvedColor = color ?? tokens.textSecondary;
    final effectiveColor = !isEnabled
        ? tokens.textMuted.withOpacity(0.4)
        : (isCopied ? resolvedActiveColor : resolvedColor);

    final resolvedTooltip = !isEnabled
        ? 'No lyrics available'
        : (isCopied ? 'Copied to clipboard!' : (tooltip ?? 'Copy Lyrics (.lrc / text)'));

    // Animated icon widget
    final iconWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: isCopied
          ? Icon(
              Icons.check_rounded,
              key: const ValueKey('copied_icon'),
              size: iconSize,
              color: resolvedActiveColor,
            )
          : Icon(
              Icons.content_copy_rounded,
              key: const ValueKey('copy_icon'),
              size: iconSize,
              color: effectiveColor,
            ),
    );

    // 1. Compact Icon Button Mode
    if (compact) {
      if (!isEnabled) {
        return IconButton(
          icon: iconWidget,
          tooltip: resolvedTooltip,
          onPressed: null,
          padding: padding ?? const EdgeInsets.all(8.0),
          iconSize: iconSize,
        );
      }

      if (showFormatMenu) {
        return Tooltip(
          message: resolvedTooltip,
          child: PopupMenuButton<LyricsExportFormat>(
            tooltip: '',
            color: tokens.surfaceElevated,
            elevation: 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusCard),
              side: BorderSide(
                color: tokens.isGlass ? tokens.glassBorder : tokens.divider,
                width: 1.0,
              ),
            ),
            icon: iconWidget,
            padding: padding ?? const EdgeInsets.all(8.0),
            onSelected: (format) => _executeCopy(context, ref, format),
            itemBuilder: (ctx) => _buildMenuItems(ctx, tokens),
          ),
        );
      }

      return Tooltip(
        message: resolvedTooltip,
        child: BouncingScaleButton(
          onTap: () => _executeCopy(context, ref, defaultFormat),
          child: IconButton(
            icon: iconWidget,
            onPressed: () => _executeCopy(context, ref, defaultFormat),
            padding: padding ?? const EdgeInsets.all(8.0),
            iconSize: iconSize,
          ),
        ),
      );
    }

    // 2. Full Button Mode (Icon + Text)
    final labelText = isCopied
        ? 'Copied!'
        : (showFormatMenu ? 'Copy Lyrics' : 'Copy ${defaultFormat.shortLabel}');

    if (!isEnabled) {
      return OutlinedButton.icon(
        icon: iconWidget,
        label: Text(
          'No Lyrics',
          style: TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 13.0,
            color: effectiveColor,
          ),
        ),
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: tokens.spaceSm + 4.0,
                vertical: tokens.spaceSm,
              ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
          ),
        ),
      );
    }

    if (showFormatMenu) {
      return PopupMenuButton<LyricsExportFormat>(
        tooltip: resolvedTooltip,
        color: tokens.surfaceElevated,
        elevation: 6.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          side: BorderSide(
            color: tokens.isGlass ? tokens.glassBorder : tokens.divider,
            width: 1.0,
          ),
        ),
        onSelected: (format) => _executeCopy(context, ref, format),
        itemBuilder: (ctx) => _buildMenuItems(ctx, tokens),
        child: Container(
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: tokens.spaceSm + 4.0,
                vertical: tokens.spaceSm - 2.0,
              ),
          decoration: BoxDecoration(
            color: isCopied
                ? resolvedActiveColor.withOpacity(0.14)
                : tokens.card,
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            border: Border.all(
              color: isCopied
                  ? resolvedActiveColor.withOpacity(0.5)
                  : tokens.divider,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(width: 6.0),
              Text(
                labelText,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isCopied ? resolvedActiveColor : tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 4.0),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18.0,
                color: isCopied ? resolvedActiveColor : tokens.textSecondary,
              ),
            ],
          ),
        ),
      );
    }

    // Direct Full Button
    return BouncingScaleButton(
      onTap: () => _executeCopy(context, ref, defaultFormat),
      child: Container(
        padding: padding ??
            EdgeInsets.symmetric(
              horizontal: tokens.spaceSm + 4.0,
              vertical: tokens.spaceSm - 2.0,
            ),
        decoration: BoxDecoration(
          color: isCopied
              ? resolvedActiveColor.withOpacity(0.14)
              : tokens.card,
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          border: Border.all(
            color: isCopied
                ? resolvedActiveColor.withOpacity(0.5)
                : tokens.divider,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(width: 6.0),
            Text(
              labelText,
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isCopied ? resolvedActiveColor : tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<LyricsExportFormat>> _buildMenuItems(
    BuildContext context,
    AppTokens tokens,
  ) {
    return [
      PopupMenuItem<LyricsExportFormat>(
        value: LyricsExportFormat.lrc,
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 18.0,
              color: tokens.accent,
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Synced Lyrics (.lrc)',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Text(
                    'With [mm:ss.xx] timestamps',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11.0,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<LyricsExportFormat>(
        value: LyricsExportFormat.plainText,
        child: Row(
          children: [
            Icon(
              Icons.notes_rounded,
              size: 18.0,
              color: tokens.textSecondary,
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Plain Text (.txt)',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Text(
                    'Clean text without tags',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11.0,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

// ============================================================================
// Interactive Modal Sheet: _LyricsExportBottomSheet
// ============================================================================

class _LyricsExportBottomSheet extends ConsumerStatefulWidget {
  final SyncedLyrics lyrics;
  final Track? track;
  final int offsetMs;

  const _LyricsExportBottomSheet({
    required this.lyrics,
    this.track,
    this.offsetMs = 0,
  });

  @override
  ConsumerState<_LyricsExportBottomSheet> createState() =>
      _LyricsExportBottomSheetState();
}

class _LyricsExportBottomSheetState
    extends ConsumerState<_LyricsExportBottomSheet> {
  late LyricsExportFormat _selectedFormat;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.lyrics.lines.isNotEmpty
        ? LyricsExportFormat.lrc
        : LyricsExportFormat.plainText;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final formattedContent = LrcLyricsExporter.export(
      lyrics: widget.lyrics,
      format: _selectedFormat,
      track: widget.track,
      offsetMs: widget.offsetMs,
    );
    final lineCount = LrcLyricsExporter.countLines(formattedContent);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        border: Border(
          top: BorderSide(
            color: tokens.isGlass ? tokens.glassBorder : tokens.divider,
            width: 1.0,
          ),
        ),
      ),
      padding: EdgeInsets.all(tokens.spaceMd),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 38.0,
                height: 4.0,
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                  color: tokens.divider,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
            // Header Row
            Row(
              children: [
                Icon(
                  Icons.lyrics_rounded,
                  color: tokens.accent,
                  size: 22.0,
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copy Lyrics',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      if (widget.track != null)
                        Text(
                          '${widget.track!.title} • ${widget.track!.artist}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12.0,
                            color: tokens.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  iconSize: 20.0,
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Format Toggle Pill
            Container(
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(tokens.radiusPill),
              ),
              padding: const EdgeInsets.all(4.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFormatTab(
                      format: LyricsExportFormat.lrc,
                      label: 'Synced (.lrc)',
                      tokens: tokens,
                    ),
                  ),
                  Expanded(
                    child: _buildFormatTab(
                      format: LyricsExportFormat.plainText,
                      label: 'Plain Text (.txt)',
                      tokens: tokens,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12.0),

            // Lyrics Preview Box
            Container(
              height: 180.0,
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(tokens.radiusCard),
                border: Border.all(color: tokens.divider, width: 1.0),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  formattedContent,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: tokens.textPrimary.withOpacity(0.9),
                    height: 1.45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10.0),

            // Status Bar & Action Button
            Row(
              children: [
                Text(
                  '$lineCount lines • ${formattedContent.length} chars',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11.5,
                    color: tokens.textMuted,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16.0),
                  label: Text('Copy ${_selectedFormat.shortLabel}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                    ),
                  ),
                  onPressed: () async {
                    final notifier = ref.read(lyricsCopyNotifierProvider.notifier);
                    await notifier.copyText(
                      text: formattedContent,
                      format: _selectedFormat,
                      lineCount: lineCount,
                      context: context,
                      showToast: true,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatTab({
    required LyricsExportFormat format,
    required String label,
    required AppTokens tokens,
  }) {
    final isSelected = _selectedFormat == format;
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? tokens.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radiusPill),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 12.0,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? tokens.accent : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
