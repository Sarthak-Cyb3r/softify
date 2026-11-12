// ============================================================================
// Softify Quality of Life (QoL) - Feature 25: Export Listening History (CSV & JSON)
// ============================================================================
//
// Converts timestamped user listening history records into structured CSV
// (RFC 4180 compliant) and JSON strings.
//
// Required Fields:
// - trackId: Unique track identifier
// - title: Song title
// - artist: Primary/contributing artist
// - durationSeconds: Song duration in integer seconds
// - playedAt: Timestamp of play event (ISO-8601 string)
// - completionRatio: Proportion of track completed (0.0 to 1.0)
//
// Components:
// 1. ListeningHistoryEntry: Immutable representation of a history record.
// 2. ListeningHistoryExporter: Pure Dart exporter and parser for CSV & JSON.
// 3. ListeningHistorySummary: Aggregate statistics calculator for play history.
// 4. ExportHistoryButton: Material 3 action button with dialog & clipboard support.
// 5. Riverpod Providers: Reactive state management for history data & export flow.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/history_item.dart';
import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/shared/app_toast.dart';

// ============================================================================
// 1. Data Models & Enums
// ============================================================================

/// Available structured export formats for listening history.
enum HistoryExportFormat {
  csv('CSV', 'Comma-Separated Values', '.csv', 'text/csv'),
  json('JSON', 'Structured JavaScript Object Notation', '.json', 'application/json');

  final String label;
  final String description;
  final String fileExtension;
  final String mimeType;

  const HistoryExportFormat(
    this.label,
    this.description,
    this.fileExtension,
    this.mimeType,
  );
}

/// Date range filter presets for exporting listening history.
enum HistoryExportDateFilter {
  allTime('All History'),
  today('Last 24 Hours'),
  last7Days('Last 7 Days'),
  last30Days('Last 30 Days'),
  last90Days('Last 90 Days');

  final String label;
  const HistoryExportDateFilter(this.label);

  DateTime? get cutoffDate {
    final now = DateTime.now();
    switch (this) {
      case HistoryExportDateFilter.allTime:
        return null;
      case HistoryExportDateFilter.today:
        return now.subtract(const Duration(hours: 24));
      case HistoryExportDateFilter.last7Days:
        return now.subtract(const Duration(days: 7));
      case HistoryExportDateFilter.last30Days:
        return now.subtract(const Duration(days: 30));
      case HistoryExportDateFilter.last90Days:
        return now.subtract(const Duration(days: 90));
    }
  }
}

/// Immutable record representing a single timestamped play entry.
///
/// Contains the six required fields:
/// [trackId], [title], [artist], [durationSeconds], [playedAt], and [completionRatio].
@immutable
class ListeningHistoryEntry {
  final String trackId;
  final String title;
  final String artist;
  final int durationSeconds;
  final DateTime playedAt;
  final double completionRatio;

  const ListeningHistoryEntry({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    required this.playedAt,
    required this.completionRatio,
  });

  /// Factory converting Softify domain [HistoryItem] into exportable entry.
  factory ListeningHistoryEntry.fromHistoryItem(HistoryItem item) {
    final durationSec = item.track.duration.inSeconds >= 0
        ? item.track.duration.inSeconds
        : 0;

    return ListeningHistoryEntry(
      trackId: item.track.id,
      title: item.track.title,
      artist: item.track.artist,
      durationSeconds: durationSec,
      playedAt: item.playedAt,
      completionRatio: item.completedRatio,
    );
  }

  /// Factory creating an entry from a [Track] and play session attributes.
  factory ListeningHistoryEntry.fromTrack({
    required Track track,
    required DateTime playedAt,
    double completionRatio = 1.0,
  }) {
    final durationSec =
        track.duration.inSeconds >= 0 ? track.duration.inSeconds : 0;

    return ListeningHistoryEntry(
      trackId: track.id,
      title: track.title,
      artist: track.artist,
      durationSeconds: durationSec,
      playedAt: playedAt,
      completionRatio: completionRatio,
    );
  }

  /// Converts this record into a JSON Map adhering to required field naming.
  Map<String, dynamic> toJson() {
    return {
      'trackId': trackId,
      'title': title,
      'artist': artist,
      'durationSeconds': durationSeconds,
      'playedAt': playedAt.toIso8601String(),
      'completionRatio': completionRatio,
    };
  }

  /// Deserializes a JSON map into a [ListeningHistoryEntry].
  factory ListeningHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawDate = json['playedAt'];
    DateTime parsedDate;
    if (rawDate is String) {
      parsedDate =
          DateTime.tryParse(rawDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate, isUtc: true);
    } else {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    return ListeningHistoryEntry(
      trackId: json['trackId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      playedAt: parsedDate,
      completionRatio: (json['completionRatio'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Returns a copy of this entry with the given fields replaced.
  ListeningHistoryEntry copyWith({
    String? trackId,
    String? title,
    String? artist,
    int? durationSeconds,
    DateTime? playedAt,
    double? completionRatio,
  }) {
    return ListeningHistoryEntry(
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      playedAt: playedAt ?? this.playedAt,
      completionRatio: completionRatio ?? this.completionRatio,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListeningHistoryEntry &&
          runtimeType == other.runtimeType &&
          trackId == other.trackId &&
          title == other.title &&
          artist == other.artist &&
          durationSeconds == other.durationSeconds &&
          playedAt == other.playedAt &&
          (completionRatio - other.completionRatio).abs() < 0.0001;

  @override
  int get hashCode => Object.hash(
        trackId,
        title,
        artist,
        durationSeconds,
        playedAt,
        completionRatio.toStringAsFixed(4),
      );

  @override
  String toString() =>
      'ListeningHistoryEntry(trackId: $trackId, title: $title, artist: $artist, '
      'durationSeconds: $durationSeconds, playedAt: ${playedAt.toIso8601String()}, '
      'completionRatio: $completionRatio)';
}

/// Aggregated metrics and summary over a collection of listening records.
@immutable
class ListeningHistorySummary {
  final int totalPlays;
  final Duration totalDuration;
  final int uniqueTracksCount;
  final int uniqueArtistsCount;
  final double averageCompletionRatio;
  final DateTime? earliestPlay;
  final DateTime? latestPlay;

  const ListeningHistorySummary({
    required this.totalPlays,
    required this.totalDuration,
    required this.uniqueTracksCount,
    required this.uniqueArtistsCount,
    required this.averageCompletionRatio,
    this.earliestPlay,
    this.latestPlay,
  });

  /// Computes summary metrics from a list of entries.
  factory ListeningHistorySummary.fromEntries(
      List<ListeningHistoryEntry> entries) {
    if (entries.isEmpty) {
      return const ListeningHistorySummary(
        totalPlays: 0,
        totalDuration: Duration.zero,
        uniqueTracksCount: 0,
        uniqueArtistsCount: 0,
        averageCompletionRatio: 0.0,
      );
    }

    final uniqueTracks = <String>{};
    final uniqueArtists = <String>{};
    int totalSec = 0;
    double sumRatio = 0.0;
    DateTime? earliest;
    DateTime? latest;

    for (final e in entries) {
      final trackKey =
          e.trackId.isNotEmpty ? e.trackId : '${e.artist}_${e.title}';
      uniqueTracks.add(trackKey);

      if (e.artist.trim().isNotEmpty) {
        uniqueArtists.add(e.artist.trim().toLowerCase());
      }

      totalSec += e.durationSeconds;
      sumRatio += e.completionRatio;

      if (earliest == null || e.playedAt.isBefore(earliest)) {
        earliest = e.playedAt;
      }
      if (latest == null || e.playedAt.isAfter(latest)) {
        latest = e.playedAt;
      }
    }

    return ListeningHistorySummary(
      totalPlays: entries.length,
      totalDuration: Duration(seconds: totalSec),
      uniqueTracksCount: uniqueTracks.length,
      uniqueArtistsCount: uniqueArtists.length,
      averageCompletionRatio: sumRatio / entries.length,
      earliestPlay: earliest,
      latestPlay: latest,
    );
  }
}

/// Result metadata produced by a completed history export operation.
@immutable
class ExportResult {
  final HistoryExportFormat format;
  final int entryCount;
  final String? filePath;
  final String content;
  final bool copiedToClipboard;

  const ExportResult({
    required this.format,
    required this.entryCount,
    this.filePath,
    required this.content,
    this.copiedToClipboard = false,
  });
}

// ============================================================================
// 2. Listening History Exporter (Core Pure Dart Engine)
// ============================================================================

/// High-performance, pure Dart exporter and parser for listening history.
///
/// Features:
/// - RFC 4180 compliant CSV serialization and robust parsing.
/// - Structured JSON serialization with pretty-print or compact formatting.
/// - Filtering by date ranges, completion thresholds, and query strings.
/// - Cross-platform destination directory resolution and file writing.
class ListeningHistoryExporter {
  const ListeningHistoryExporter();

  /// Column headers for CSV export adhering to requirement 2.
  static const List<String> csvHeaders = [
    'trackId',
    'title',
    'artist',
    'durationSeconds',
    'playedAt',
    'completionRatio',
  ];

  /// Converts a collection of [ListeningHistoryEntry] items to an RFC 4180 CSV string.
  ///
  /// Escapes fields containing commas, double-quotes, or newlines by wrapping them
  /// in quotes and doubling any internal quotes.
  static String exportToCsv(
    List<ListeningHistoryEntry> entries, {
    bool includeHeader = true,
    String lineDelimiter = '\n',
  }) {
    final buffer = StringBuffer();

    if (includeHeader) {
      buffer.write(csvHeaders.join(','));
      buffer.write(lineDelimiter);
    }

    for (final entry in entries) {
      final trackId = escapeCsvField(entry.trackId);
      final title = escapeCsvField(entry.title);
      final artist = escapeCsvField(entry.artist);
      final durationSeconds = entry.durationSeconds;
      final playedAt = escapeCsvField(entry.playedAt.toIso8601String());
      final completionRatio = entry.completionRatio.toString();

      buffer.write(
        '$trackId,$title,$artist,$durationSeconds,$playedAt,$completionRatio',
      );
      buffer.write(lineDelimiter);
    }

    return buffer.toString();
  }

  /// Converts a collection of [ListeningHistoryEntry] items to a JSON string.
  ///
  /// If [pretty] is true, outputs indented JSON; otherwise returns compact JSON.
  static String exportToJson(
    List<ListeningHistoryEntry> entries, {
    bool pretty = true,
  }) {
    final jsonList = entries.map((e) => e.toJson()).toList();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(jsonList);
    }
    return jsonEncode(jsonList);
  }

  /// Convenience bridge to export domain [HistoryItem] objects to CSV.
  static String exportHistoryItemsToCsv(
    List<HistoryItem> items, {
    bool includeHeader = true,
    String lineDelimiter = '\n',
  }) {
    final entries = items.map(ListeningHistoryEntry.fromHistoryItem).toList();
    return exportToCsv(
      entries,
      includeHeader: includeHeader,
      lineDelimiter: lineDelimiter,
    );
  }

  /// Convenience bridge to export domain [HistoryItem] objects to JSON.
  static String exportHistoryItemsToJson(
    List<HistoryItem> items, {
    bool pretty = true,
  }) {
    final entries = items.map(ListeningHistoryEntry.fromHistoryItem).toList();
    return exportToJson(entries, pretty: pretty);
  }

  /// Escapes CSV values strictly following RFC 4180.
  static String escapeCsvField(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.isEmpty) return '';

    if (str.contains(',') ||
        str.contains('"') ||
        str.contains('\n') ||
        str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Parses an RFC 4180 CSV string back into [ListeningHistoryEntry] instances.
  ///
  /// Handles multiline quotes, double-quoted escapes, and case-insensitive headers.
  static List<ListeningHistoryEntry> parseCsv(String csvString) {
    if (csvString.trim().isEmpty) return const [];

    final rows = _parseCsvRows(csvString);
    if (rows.isEmpty) return const [];

    int trackIdIdx = 0;
    int titleIdx = 1;
    int artistIdx = 2;
    int durationIdx = 3;
    int playedAtIdx = 4;
    int ratioIdx = 5;

    int startIndex = 0;
    final firstRow = rows.first;

    final hasHeader = firstRow.any((cell) {
      final lower = cell.toLowerCase().trim();
      return lower == 'trackid' || lower == 'title' || lower == 'artist';
    });

    if (hasHeader) {
      startIndex = 1;
      for (int i = 0; i < firstRow.length; i++) {
        final col = firstRow[i].trim().toLowerCase();
        if (col == 'trackid') trackIdIdx = i;
        if (col == 'title') titleIdx = i;
        if (col == 'artist') artistIdx = i;
        if (col == 'durationseconds' || col == 'duration') durationIdx = i;
        if (col == 'playedat' || col == 'timestamp') playedAtIdx = i;
        if (col == 'completionratio' || col == 'completedratio') ratioIdx = i;
      }
    }

    final entries = <ListeningHistoryEntry>[];
    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || (row.length == 1 && row.first.trim().isEmpty)) {
        continue;
      }

      final trackId = row.length > trackIdIdx ? row[trackIdIdx] : '';
      final title = row.length > titleIdx ? row[titleIdx] : '';
      final artist = row.length > artistIdx ? row[artistIdx] : '';
      final durStr = row.length > durationIdx ? row[durationIdx] : '0';
      final playedAtStr = row.length > playedAtIdx ? row[playedAtIdx] : '';
      final ratioStr = row.length > ratioIdx ? row[ratioIdx] : '0.0';

      final durationSeconds = int.tryParse(durStr.trim()) ?? 0;
      final playedAt = DateTime.tryParse(playedAtStr.trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final completionRatio = double.tryParse(ratioStr.trim()) ?? 0.0;

      entries.add(ListeningHistoryEntry(
        trackId: trackId,
        title: title,
        artist: artist,
        durationSeconds: durationSeconds,
        playedAt: playedAt,
        completionRatio: completionRatio,
      ));
    }

    return entries;
  }

  /// Internal RFC 4180 streaming cell & row extractor.
  static List<List<String>> _parseCsvRows(String input) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    bool insideQuotes = false;
    int i = 0;

    while (i < input.length) {
      final char = input[i];

      if (insideQuotes) {
        if (char == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            currentCell.write('"');
            i += 2;
            continue;
          } else {
            insideQuotes = false;
            i++;
            continue;
          }
        } else {
          currentCell.write(char);
          i++;
        }
      } else {
        if (char == '"') {
          insideQuotes = true;
          i++;
        } else if (char == ',') {
          currentRow.add(currentCell.toString());
          currentCell.clear();
          i++;
        } else if (char == '\r') {
          if (i + 1 < input.length && input[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentCell.toString());
          currentCell.clear();
          rows.add(List<String>.from(currentRow));
          currentRow.clear();
          i++;
        } else if (char == '\n') {
          currentRow.add(currentCell.toString());
          currentCell.clear();
          rows.add(List<String>.from(currentRow));
          currentRow.clear();
          i++;
        } else {
          currentCell.write(char);
          i++;
        }
      }
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString());
      rows.add(currentRow);
    }

    return rows;
  }

  /// Parses a JSON string back into [ListeningHistoryEntry] records.
  ///
  /// Supports both root array `[...]` and wrapped objects `{"history": [...]}`.
  static List<ListeningHistoryEntry> parseJson(String jsonString) {
    if (jsonString.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) =>
                ListeningHistoryEntry.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } else if (decoded is Map) {
        final list = decoded['history'] ??
            decoded['entries'] ??
            decoded['items'] ??
            decoded['data'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) =>
                  ListeningHistoryEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      }
    } catch (_) {}
    return const [];
  }

  /// Filters [entries] by date range, completion ratio threshold, and query text.
  static List<ListeningHistoryEntry> filterEntries(
    List<ListeningHistoryEntry> entries, {
    DateTime? after,
    DateTime? before,
    double minCompletionRatio = 0.0,
    String? searchQuery,
  }) {
    return entries.where((entry) {
      if (after != null && entry.playedAt.isBefore(after)) return false;
      if (before != null && entry.playedAt.isAfter(before)) return false;
      if (entry.completionRatio < minCompletionRatio) return false;

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matches = entry.title.toLowerCase().contains(q) ||
            entry.artist.toLowerCase().contains(q) ||
            entry.trackId.toLowerCase().contains(q);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  /// Generates a standardized timestamped filename for history exports.
  static String generateDefaultFileName({
    required HistoryExportFormat format,
    DateTime? timestamp,
  }) {
    final dt = timestamp ?? DateTime.now();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');

    return 'softify_listening_history_${y}${m}${d}_${h}${min}${s}${format.fileExtension}';
  }

  /// Resolves the optimal filesystem directory for saving exported history files.
  static Future<Directory> resolveExportDirectory({
    Directory? overrideDirectory,
  }) async {
    if (overrideDirectory != null) return overrideDirectory;

    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final home =
            Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null && home.isNotEmpty) {
          final musicDir = Directory(p.join(home, 'Music'));
          if (musicDir.existsSync()) return musicDir;

          final docsDir = Directory(p.join(home, 'Documents'));
          if (docsDir.existsSync()) return docsDir;

          final downloadsDir = Directory(p.join(home, 'Downloads'));
          if (downloadsDir.existsSync()) return downloadsDir;
        }
      } else if (Platform.isAndroid) {
        for (final path in [
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Documents',
          '/storage/emulated/0/Download',
        ]) {
          final dir = Directory(path);
          if (dir.existsSync()) return dir;
        }
      }
    } catch (_) {}

    try {
      final appDocs = await getApplicationDocumentsDirectory();
      if (appDocs.existsSync()) return appDocs;
    } catch (_) {}

    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && downloads.existsSync()) return downloads;
    } catch (_) {}

    return Directory.systemTemp;
  }

  /// Exports entries directly to disk in the specified format.
  static Future<File> exportToFile({
    required List<ListeningHistoryEntry> entries,
    required HistoryExportFormat format,
    Directory? directory,
    String? fileName,
    bool prettyJson = true,
  }) async {
    final dir = directory ?? await resolveExportDirectory();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final name = fileName ?? generateDefaultFileName(format: format);
    final targetFile = File(p.join(dir.path, name));

    final content = format == HistoryExportFormat.csv
        ? exportToCsv(entries)
        : exportToJson(entries, pretty: prettyJson);

    targetFile.writeAsStringSync(content, flush: true, encoding: utf8);
    return targetFile;
  }

  /// Copies exported history content directly to the system clipboard.
  static Future<void> copyToClipboard({
    required List<ListeningHistoryEntry> entries,
    required HistoryExportFormat format,
    bool prettyJson = true,
  }) async {
    final content = format == HistoryExportFormat.csv
        ? exportToCsv(entries)
        : exportToJson(entries, pretty: prettyJson);

    await Clipboard.setData(ClipboardData(text: content));
  }
}

// ============================================================================
// 3. Riverpod State Management & Providers
// ============================================================================

/// Reactive export status state.
@immutable
class HistoryExportState {
  final bool isExporting;
  final String? lastExportedPath;
  final HistoryExportFormat lastFormat;
  final String? errorMessage;
  final int lastExportedCount;

  const HistoryExportState({
    this.isExporting = false,
    this.lastExportedPath,
    this.lastFormat = HistoryExportFormat.csv,
    this.errorMessage,
    this.lastExportedCount = 0,
  });

  HistoryExportState copyWith({
    bool? isExporting,
    String? lastExportedPath,
    HistoryExportFormat? lastFormat,
    String? errorMessage,
    int? lastExportedCount,
  }) {
    return HistoryExportState(
      isExporting: isExporting ?? this.isExporting,
      lastExportedPath: lastExportedPath ?? this.lastExportedPath,
      lastFormat: lastFormat ?? this.lastFormat,
      errorMessage: errorMessage,
      lastExportedCount: lastExportedCount ?? this.lastExportedCount,
    );
  }
}

/// StateNotifier coordinating export execution and notifying listeners.
class HistoryExportNotifier extends StateNotifier<HistoryExportState> {
  final Ref _ref;

  HistoryExportNotifier(this._ref) : super(const HistoryExportState());

  /// Coordinates exporting listening history records to a file or clipboard.
  Future<ExportResult?> exportHistory({
    required List<ListeningHistoryEntry> entries,
    required HistoryExportFormat format,
    bool copyOnly = false,
    Directory? targetDirectory,
    String? customFileName,
  }) async {
    state = state.copyWith(isExporting: true, errorMessage: null);

    try {
      final content = format == HistoryExportFormat.csv
          ? ListeningHistoryExporter.exportToCsv(entries)
          : ListeningHistoryExporter.exportToJson(entries, pretty: true);

      if (copyOnly) {
        await ListeningHistoryExporter.copyToClipboard(
          entries: entries,
          format: format,
        );
        state = state.copyWith(
          isExporting: false,
          lastFormat: format,
          lastExportedCount: entries.length,
        );
        return ExportResult(
          format: format,
          entryCount: entries.length,
          content: content,
          copiedToClipboard: true,
        );
      }

      final file = await ListeningHistoryExporter.exportToFile(
        entries: entries,
        format: format,
        directory: targetDirectory,
        fileName: customFileName,
      );

      state = state.copyWith(
        isExporting: false,
        lastExportedPath: file.path,
        lastFormat: format,
        lastExportedCount: entries.length,
      );

      return ExportResult(
        format: format,
        entryCount: entries.length,
        filePath: file.path,
        content: content,
        copiedToClipboard: false,
      );
    } catch (e, stack) {
      debugPrint('exportHistory error: $e\n$stack');
      state = state.copyWith(
        isExporting: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }
}

/// Riverpod provider for the stateless [ListeningHistoryExporter] engine.
final listeningHistoryExporterProvider =
    Provider<ListeningHistoryExporter>((ref) {
  return const ListeningHistoryExporter();
});

/// Riverpod provider watching Softify's core play history stream and mapping to [ListeningHistoryEntry].
final allListeningHistoryEntriesProvider =
    Provider<List<ListeningHistoryEntry>>((ref) {
  try {
    final historyAsync = ref.watch(playHistoryStreamProvider);
    return historyAsync.maybeWhen(
      data: (items) =>
          items.map(ListeningHistoryEntry.fromHistoryItem).toList(),
      orElse: () => const [],
    );
  } catch (_) {
    return const [];
  }
});

/// Riverpod provider for export operation state.
final historyExportNotifierProvider =
    StateNotifierProvider<HistoryExportNotifier, HistoryExportState>((ref) {
  return HistoryExportNotifier(ref);
});

// ============================================================================
// 4. UI Components: ExportHistoryButton & ExportHistorySheet
// ============================================================================

/// Material 3 action button enabling users to export their listening history
/// to CSV or JSON formats.
///
/// Supports:
/// - Explicit [entries] or domain [historyItems].
/// - Fallback to reactive [allListeningHistoryEntriesProvider].
/// - Compact icon-only or prominent tonal button layout.
/// - Direct one-tap export with [defaultFormat] or interactive dialog modal.
class ExportHistoryButton extends ConsumerWidget {
  /// Explicit entries to export. If null, falls back to [historyItems] or Riverpod.
  final List<ListeningHistoryEntry>? entries;

  /// Optional core domain [HistoryItem]s.
  final List<HistoryItem>? historyItems;

  /// Preselected format. If set, clicking triggers direct export; if null, opens modal.
  final HistoryExportFormat? defaultFormat;

  /// Renders compact icon button when true; full labeled button when false.
  final bool iconOnly;

  /// Custom icon widget. Defaults to [Icons.file_download_outlined].
  final Widget? icon;

  /// Custom label widget. Defaults to Text('Export History').
  final Widget? label;

  /// Custom button styling.
  final ButtonStyle? style;

  /// Custom tooltip message.
  final String? tooltip;

  /// Callback executed when export completes successfully.
  final ValueChanged<ExportResult>? onExportCompleted;

  /// Custom press callback override.
  final VoidCallback? onPressed;

  /// Whether to display toast notification on export.
  final bool showToast;

  /// Target filesystem directory override for testing.
  final Directory? targetDirectory;

  const ExportHistoryButton({
    super.key,
    this.entries,
    this.historyItems,
    this.defaultFormat,
    this.iconOnly = false,
    this.icon,
    this.label,
    this.style,
    this.tooltip,
    this.onExportCompleted,
    this.onPressed,
    this.showToast = true,
    this.targetDirectory,
  });

  List<ListeningHistoryEntry> _resolveEntries(WidgetRef ref) {
    if (entries != null) return entries!;
    if (historyItems != null) {
      return historyItems!
          .map(ListeningHistoryEntry.fromHistoryItem)
          .toList();
    }
    return ref.watch(allListeningHistoryEntriesProvider);
  }

  Future<void> _handlePress(BuildContext context, WidgetRef ref) async {
    if (onPressed != null) {
      onPressed!();
      return;
    }

    final resolvedEntries = _resolveEntries(ref);

    if (resolvedEntries.isEmpty) {
      _showFeedback(
        context,
        'No listening history available to export',
        isError: true,
      );
      return;
    }

    if (defaultFormat != null) {
      final notifier = ref.read(historyExportNotifierProvider.notifier);
      final result = await notifier.exportHistory(
        entries: resolvedEntries,
        format: defaultFormat!,
        targetDirectory: targetDirectory,
      );

      if (result != null) {
        if (showToast && context.mounted) {
          final target = result.filePath != null
              ? p.basename(result.filePath!)
              : 'clipboard';
          _showFeedback(
            context,
            'Exported ${result.entryCount} entries to $target',
          );
        }
        onExportCompleted?.call(result);
      } else if (context.mounted) {
        _showFeedback(context, 'Export failed', isError: true);
      }
      return;
    }

    await showExportHistorySheet(
      context,
      entries: resolvedEntries,
      targetDirectory: targetDirectory,
      onExportCompleted: onExportCompleted,
    );
  }

  static void _showFeedback(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    try {
      if (isError) {
        AppToast.showError(context, message: message);
      } else {
        AppToast.showSuccess(context, message: message);
      }
      return;
    } catch (_) {}

    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: isError ? Colors.redAccent : Colors.teal,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final resolvedTooltip = tooltip ?? 'Export Listening History (CSV & JSON)';
    final resolvedIcon = icon ??
        const Icon(
          Icons.file_download_outlined,
          size: 18.0,
          key: Key('export_history_icon'),
        );
    final resolvedLabel = label ?? const Text('Export History');

    if (iconOnly) {
      return Tooltip(
        message: resolvedTooltip,
        child: IconButton.filledTonal(
          key: const Key('export_history_button'),
          style: style ??
              IconButton.styleFrom(
                backgroundColor: tokens.surfaceElevated,
                foregroundColor: tokens.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  side: BorderSide(color: tokens.divider),
                ),
              ),
          icon: resolvedIcon,
          onPressed: () => _handlePress(context, ref),
        ),
      );
    }

    return Tooltip(
      message: resolvedTooltip,
      child: FilledButton.tonalIcon(
        key: const Key('export_history_button'),
        style: style ??
            FilledButton.styleFrom(
              backgroundColor: tokens.surfaceElevated,
              foregroundColor: tokens.textPrimary,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spaceMd,
                vertical: tokens.spaceSm + 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                side: BorderSide(color: tokens.divider),
              ),
            ),
        icon: resolvedIcon,
        label: resolvedLabel,
        onPressed: () => _handlePress(context, ref),
      ),
    );
  }
}

/// Displays the interactive Material 3 Modal Bottom Sheet for configuring
/// and executing listening history exports.
Future<ExportResult?> showExportHistorySheet(
  BuildContext context, {
  required List<ListeningHistoryEntry> entries,
  Directory? targetDirectory,
  ValueChanged<ExportResult>? onExportCompleted,
}) {
  return showModalBottomSheet<ExportResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ExportHistorySheet(
      entries: entries,
      targetDirectory: targetDirectory,
      onExportCompleted: onExportCompleted,
    ),
  );
}

/// Interactive sheet presenting format toggle (CSV/JSON), date range filters,
/// live preview, and export actions.
class ExportHistorySheet extends ConsumerStatefulWidget {
  final List<ListeningHistoryEntry> entries;
  final Directory? targetDirectory;
  final ValueChanged<ExportResult>? onExportCompleted;

  const ExportHistorySheet({
    super.key,
    required this.entries,
    this.targetDirectory,
    this.onExportCompleted,
  });

  @override
  ConsumerState<ExportHistorySheet> createState() => _ExportHistorySheetState();
}

class _ExportHistorySheetState extends ConsumerState<ExportHistorySheet> {
  HistoryExportFormat _format = HistoryExportFormat.csv;
  HistoryExportDateFilter _dateFilter = HistoryExportDateFilter.allTime;
  double _minCompletion = 0.0;
  bool _isExporting = false;

  List<ListeningHistoryEntry> get _filteredEntries {
    final cutoff = _dateFilter.cutoffDate;
    return ListeningHistoryExporter.filterEntries(
      widget.entries,
      after: cutoff,
      minCompletionRatio: _minCompletion,
    );
  }

  String get _previewSnippet {
    final subset = _filteredEntries.take(3).toList();
    if (subset.isEmpty) {
      return '// No records match the active filters';
    }
    if (_format == HistoryExportFormat.csv) {
      return ListeningHistoryExporter.exportToCsv(subset);
    }
    return ListeningHistoryExporter.exportToJson(subset, pretty: true);
  }

  Future<void> _performExport({required bool copyOnly}) async {
    setState(() => _isExporting = true);

    try {
      final entriesToExport = _filteredEntries;
      if (entriesToExport.isEmpty) {
        ExportHistoryButton._showFeedback(
          context,
          'No matching records to export',
          isError: true,
        );
        setState(() => _isExporting = false);
        return;
      }

      final notifier = ref.read(historyExportNotifierProvider.notifier);
      final result = await notifier.exportHistory(
        entries: entriesToExport,
        format: _format,
        copyOnly: copyOnly,
        targetDirectory: widget.targetDirectory,
      );

      if (result != null && mounted) {
        widget.onExportCompleted?.call(result);
        final label = copyOnly
            ? 'Copied ${result.entryCount} plays to clipboard'
            : 'Saved to ${p.basename(result.filePath ?? "file")}';
        ExportHistoryButton._showFeedback(context, label);
        Navigator.of(context).pop(result);
      } else if (mounted) {
        ExportHistoryButton._showFeedback(
          context,
          'Export operation failed',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final summary = ListeningHistorySummary.fromEntries(_filteredEntries);
    final count = _filteredEntries.length;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        border: Border.all(color: tokens.divider),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        tokens.spaceLg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40.0,
                  height: 4.0,
                  margin: EdgeInsets.symmetric(vertical: tokens.spaceSm),
                  decoration: BoxDecoration(
                    color: tokens.divider,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    child: Icon(
                      Icons.history_edu_rounded,
                      color: tokens.accent,
                      size: 22.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Listening History',
                          style: TextStyle(
                            fontFamily: AppTheme.fontPageTitle,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          '$count ${count == 1 ? "track play" : "track plays"} selected • ${summary.uniqueArtistsCount} artists',
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12.0,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: tokens.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // Format Selector
              Text(
                'FORMAT',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 8.0),
              SegmentedButton<HistoryExportFormat>(
                segments: [
                  ButtonSegment<HistoryExportFormat>(
                    value: HistoryExportFormat.csv,
                    label: const Text('CSV (.csv)'),
                    icon: const Icon(Icons.table_chart_outlined, size: 16.0),
                  ),
                  ButtonSegment<HistoryExportFormat>(
                    value: HistoryExportFormat.json,
                    label: const Text('JSON (.json)'),
                    icon: const Icon(Icons.data_object_rounded, size: 16.0),
                  ),
                ],
                selected: {_format},
                onSelectionChanged: (selected) {
                  setState(() => _format = selected.first);
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: tokens.surface,
                  selectedBackgroundColor: tokens.accent.withValues(alpha: 0.2),
                  selectedForegroundColor: tokens.accent,
                ),
              ),
              const SizedBox(height: 16.0),

              // Time Range Chips
              Text(
                'TIME RANGE',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 8.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: HistoryExportDateFilter.values.map((filter) {
                  final isSelected = _dateFilter == filter;
                  return ChoiceChip(
                    label: Text(filter.label),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _dateFilter = filter);
                    },
                    selectedColor: tokens.accent.withValues(alpha: 0.2),
                    backgroundColor: tokens.surface,
                    labelStyle: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 12.0,
                      color: isSelected ? tokens.accent : tokens.textSecondary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16.0),

              // Monospace Preview Box
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PREVIEW',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: tokens.textMuted,
                    ),
                  ),
                  Text(
                    _format.label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: tokens.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              Container(
                constraints: const BoxConstraints(maxHeight: 110.0),
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(color: tokens.divider),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _previewSnippet,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      height: 1.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('export_copy_clipboard_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.textPrimary,
                        side: BorderSide(color: tokens.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18.0),
                      label: const Text('Copy Text'),
                      onPressed: _isExporting
                          ? null
                          : () => _performExport(copyOnly: true),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('export_save_file_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                        ),
                      ),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16.0,
                              height: 16.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_alt_rounded, size: 18.0),
                      label: Text(_isExporting ? 'Exporting...' : 'Save File'),
                      onPressed: _isExporting
                          ? null
                          : () => _performExport(copyOnly: false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
