// ============================================================================
// Softify Quality of Life (QoL) - Feature 25: Export Listening History Tests
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/domain/entities/history_item.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/library/listening_history_exporter.dart';
import 'package:softify/presentation/providers/player_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final timestamp1 = DateTime.utc(2026, 11, 12, 10, 30, 0);
  final timestamp2 = DateTime.utc(2026, 11, 11, 14, 15, 30);
  final timestamp3 = DateTime.utc(2026, 11, 1, 9, 0, 0);

  final testEntry1 = ListeningHistoryEntry(
    trackId: 'trk_001',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    durationSeconds: 200,
    playedAt: timestamp1,
    completionRatio: 1.0,
  );

  final testEntry2 = ListeningHistoryEntry(
    trackId: 'trk_002',
    title: 'Starboy, (feat. Daft Punk)',
    artist: 'The Weeknd, Daft Punk',
    durationSeconds: 230,
    playedAt: timestamp2,
    completionRatio: 0.85,
  );

  final testEntry3 = ListeningHistoryEntry(
    trackId: 'trk_003',
    title: 'Song with "Quotes" & \nNewline',
    artist: 'Artist "The Great"',
    durationSeconds: 180,
    playedAt: timestamp3,
    completionRatio: 0.45,
  );

  final sampleEntries = [testEntry1, testEntry2, testEntry3];

  const sampleTrack1 = Track(
    id: 'trk_track_1',
    sourceId: 'src_01',
    title: 'Midnight City',
    artist: 'M83',
    duration: Duration(seconds: 243),
  );

  final sampleHistoryItem1 = HistoryItem(
    id: 101,
    track: sampleTrack1,
    playedAt: timestamp1,
    completedRatio: 0.92,
  );

  // ==========================================================================
  // Group 1: ListeningHistoryEntry Model Tests
  // ==========================================================================
  group('ListeningHistoryEntry Model', () {
    test('instantiates with all 6 required fields accurately', () {
      expect(testEntry1.trackId, 'trk_001');
      expect(testEntry1.title, 'Blinding Lights');
      expect(testEntry1.artist, 'The Weeknd');
      expect(testEntry1.durationSeconds, 200);
      expect(testEntry1.playedAt, timestamp1);
      expect(testEntry1.completionRatio, 1.0);
    });

    test('creates entry from domain HistoryItem correctly', () {
      final entry = ListeningHistoryEntry.fromHistoryItem(sampleHistoryItem1);

      expect(entry.trackId, 'trk_track_1');
      expect(entry.title, 'Midnight City');
      expect(entry.artist, 'M83');
      expect(entry.durationSeconds, 243);
      expect(entry.playedAt, timestamp1);
      expect(entry.completionRatio, 0.92);
    });

    test('creates entry from Track entity correctly', () {
      final entry = ListeningHistoryEntry.fromTrack(
        track: sampleTrack1,
        playedAt: timestamp2,
        completionRatio: 0.75,
      );

      expect(entry.trackId, 'trk_track_1');
      expect(entry.title, 'Midnight City');
      expect(entry.artist, 'M83');
      expect(entry.durationSeconds, 243);
      expect(entry.playedAt, timestamp2);
      expect(entry.completionRatio, 0.75);
    });

    test('serializes to JSON Map with exact required keys', () {
      final jsonMap = testEntry1.toJson();

      expect(jsonMap.containsKey('trackId'), isTrue);
      expect(jsonMap.containsKey('title'), isTrue);
      expect(jsonMap.containsKey('artist'), isTrue);
      expect(jsonMap.containsKey('durationSeconds'), isTrue);
      expect(jsonMap.containsKey('playedAt'), isTrue);
      expect(jsonMap.containsKey('completionRatio'), isTrue);

      expect(jsonMap['trackId'], 'trk_001');
      expect(jsonMap['title'], 'Blinding Lights');
      expect(jsonMap['artist'], 'The Weeknd');
      expect(jsonMap['durationSeconds'], 200);
      expect(jsonMap['playedAt'], timestamp1.toIso8601String());
      expect(jsonMap['completionRatio'], 1.0);
    });

    test('deserializes from JSON Map including edge cases', () {
      final map = {
        'trackId': 'trk_999',
        'title': 'Test Song',
        'artist': 'Test Artist',
        'durationSeconds': 150,
        'playedAt': timestamp1.toIso8601String(),
        'completionRatio': 0.88,
      };

      final entry = ListeningHistoryEntry.fromJson(map);

      expect(entry.trackId, 'trk_999');
      expect(entry.title, 'Test Song');
      expect(entry.artist, 'Test Artist');
      expect(entry.durationSeconds, 150);
      expect(entry.playedAt, timestamp1);
      expect(entry.completionRatio, 0.88);

      // Handle integer timestamp in ms
      final mapWithMs = {
        'trackId': 'trk_888',
        'playedAt': timestamp1.millisecondsSinceEpoch,
      };
      final entryWithMs = ListeningHistoryEntry.fromJson(mapWithMs);
      expect(entryWithMs.playedAt, timestamp1);
    });

    test('copyWith updates specified fields only', () {
      final updated = testEntry1.copyWith(
        title: 'New Title',
        completionRatio: 0.5,
      );

      expect(updated.trackId, testEntry1.trackId);
      expect(updated.title, 'New Title');
      expect(updated.artist, testEntry1.artist);
      expect(updated.durationSeconds, testEntry1.durationSeconds);
      expect(updated.playedAt, testEntry1.playedAt);
      expect(updated.completionRatio, 0.5);
    });

    test('value equality and hashCode behavior', () {
      final duplicate = ListeningHistoryEntry(
        trackId: 'trk_001',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        durationSeconds: 200,
        playedAt: timestamp1,
        completionRatio: 1.0,
      );

      expect(testEntry1 == duplicate, isTrue);
      expect(testEntry1.hashCode, duplicate.hashCode);
      expect(testEntry1 == testEntry2, isFalse);
    });
  });

  // ==========================================================================
  // Group 2: ListeningHistoryExporter CSV Functionality
  // ==========================================================================
  group('ListeningHistoryExporter CSV Export', () {
    test('exports empty entries list as CSV header only', () {
      final csv = ListeningHistoryExporter.exportToCsv([]);
      expect(
        csv.trim(),
        'trackId,title,artist,durationSeconds,playedAt,completionRatio',
      );
    });

    test('exports standard entries with correct header and values', () {
      final csv = ListeningHistoryExporter.exportToCsv([testEntry1]);
      final lines = csv.trim().split('\n');

      expect(lines.length, 2);
      expect(
        lines[0],
        'trackId,title,artist,durationSeconds,playedAt,completionRatio',
      );
      expect(
        lines[1],
        'trk_001,Blinding Lights,The Weeknd,200,${timestamp1.toIso8601String()},1.0',
      );
    });

    test('escapes commas, quotes, and newlines adhering to RFC 4180', () {
      final csv = ListeningHistoryExporter.exportToCsv([testEntry2, testEntry3]);
      final lines = csv.split('\n');

      // Entry 2 contains commas -> must be wrapped in quotes
      expect(csv.contains('"Starboy, (feat. Daft Punk)"'), isTrue);
      expect(csv.contains('"The Weeknd, Daft Punk"'), isTrue);

      // Entry 3 contains quotes and newline -> quotes doubled and wrapped
      expect(csv.contains('"Song with ""Quotes"" & \nNewline"'), isTrue);
      expect(csv.contains('"Artist ""The Great"""'), isTrue);
    });

    test('exports core HistoryItem list to CSV via convenience helper', () {
      final csv = ListeningHistoryExporter.exportHistoryItemsToCsv([
        sampleHistoryItem1,
      ]);

      expect(csv.contains('trk_track_1'), isTrue);
      expect(csv.contains('Midnight City'), isTrue);
      expect(csv.contains('M83'), isTrue);
      expect(csv.contains('243'), isTrue);
      expect(csv.contains('0.92'), isTrue);
    });
  });

  // ==========================================================================
  // Group 3: ListeningHistoryExporter JSON Functionality
  // ==========================================================================
  group('ListeningHistoryExporter JSON Export', () {
    test('exports empty entries list as empty JSON array', () {
      final json = ListeningHistoryExporter.exportToJson([], pretty: false);
      expect(json, '[]');
    });

    test('exports entries as valid structured JSON with all 6 fields', () {
      final jsonStr = ListeningHistoryExporter.exportToJson(
        [testEntry1],
        pretty: false,
      );
      final decoded = jsonDecode(jsonStr) as List;

      expect(decoded.length, 1);
      final item = decoded.first as Map<String, dynamic>;

      expect(item['trackId'], 'trk_001');
      expect(item['title'], 'Blinding Lights');
      expect(item['artist'], 'The Weeknd');
      expect(item['durationSeconds'], 200);
      expect(item['playedAt'], timestamp1.toIso8601String());
      expect(item['completionRatio'], 1.0);
    });

    test('exports pretty-printed JSON when pretty is true', () {
      final prettyJson = ListeningHistoryExporter.exportToJson(
        [testEntry1],
        pretty: true,
      );
      expect(prettyJson.contains('\n'), isTrue);
      expect(prettyJson.contains('  "trackId": "trk_001"'), isTrue);
    });

    test('exports domain HistoryItem list to JSON via convenience helper', () {
      final jsonStr = ListeningHistoryExporter.exportHistoryItemsToJson([
        sampleHistoryItem1,
      ]);
      final decoded = jsonDecode(jsonStr) as List;

      expect(decoded.length, 1);
      expect(decoded.first['title'], 'Midnight City');
    });
  });

  // ==========================================================================
  // Group 4: Full Roundtrip Serialization & Parsing
  // ==========================================================================
  group('ListeningHistoryExporter Roundtrip Serialization & Parsing', () {
    test('CSV roundtrip: exportToCsv -> parseCsv preserves all entries', () {
      final exportedCsv = ListeningHistoryExporter.exportToCsv(sampleEntries);
      final parsedEntries = ListeningHistoryExporter.parseCsv(exportedCsv);

      expect(parsedEntries.length, sampleEntries.length);
      for (int i = 0; i < sampleEntries.length; i++) {
        expect(parsedEntries[i].trackId, sampleEntries[i].trackId);
        expect(parsedEntries[i].title, sampleEntries[i].title);
        expect(parsedEntries[i].artist, sampleEntries[i].artist);
        expect(
          parsedEntries[i].durationSeconds,
          sampleEntries[i].durationSeconds,
        );
        expect(parsedEntries[i].playedAt, sampleEntries[i].playedAt);
        expect(
          (parsedEntries[i].completionRatio - sampleEntries[i].completionRatio).abs() < 0.001,
          isTrue,
        );
      }
    });

    test('JSON roundtrip: exportToJson -> parseJson preserves all entries', () {
      final exportedJson = ListeningHistoryExporter.exportToJson(sampleEntries);
      final parsedEntries = ListeningHistoryExporter.parseJson(exportedJson);

      expect(parsedEntries.length, sampleEntries.length);
      for (int i = 0; i < sampleEntries.length; i++) {
        expect(parsedEntries[i].trackId, sampleEntries[i].trackId);
        expect(parsedEntries[i].title, sampleEntries[i].title);
        expect(parsedEntries[i].artist, sampleEntries[i].artist);
        expect(
          parsedEntries[i].durationSeconds,
          sampleEntries[i].durationSeconds,
        );
        expect(parsedEntries[i].playedAt, sampleEntries[i].playedAt);
        expect(
          (parsedEntries[i].completionRatio - sampleEntries[i].completionRatio).abs() < 0.001,
          isTrue,
        );
      }
    });

    test('parseCsv handles Windows CRLF line endings', () {
      final csv = 'trackId,title,artist,durationSeconds,playedAt,completionRatio\r\n'
          'id_1,Song 1,Artist 1,180,${timestamp1.toIso8601String()},0.9\r\n'
          'id_2,Song 2,Artist 2,210,${timestamp2.toIso8601String()},1.0\r\n';

      final parsed = ListeningHistoryExporter.parseCsv(csv);
      expect(parsed.length, 2);
      expect(parsed[0].title, 'Song 1');
      expect(parsed[1].title, 'Song 2');
    });

    test('parseJson handles wrapped json payloads', () {
      final wrappedJson = jsonEncode({
        'history': [testEntry1.toJson(), testEntry2.toJson()],
      });

      final parsed = ListeningHistoryExporter.parseJson(wrappedJson);
      expect(parsed.length, 2);
      expect(parsed[0].trackId, 'trk_001');
      expect(parsed[1].trackId, 'trk_002');
    });
  });

  // ==========================================================================
  // Group 5: Filtering & ListeningHistorySummary
  // ==========================================================================
  group('Filtering & ListeningHistorySummary', () {
    test('filterEntries filters by date cutoff', () {
      final filtered = ListeningHistoryExporter.filterEntries(
        sampleEntries,
        after: DateTime.utc(2026, 11, 12, 0, 0, 0),
      );

      expect(filtered.length, 1);
      expect(filtered.first.trackId, 'trk_001');
    });

    test('filterEntries filters by completion ratio threshold', () {
      final filtered = ListeningHistoryExporter.filterEntries(
        sampleEntries,
        minCompletionRatio: 0.8,
      );

      expect(filtered.length, 2);
      expect(filtered.any((e) => e.trackId == 'trk_001'), isTrue);
      expect(filtered.any((e) => e.trackId == 'trk_002'), isTrue);
      expect(filtered.any((e) => e.trackId == 'trk_003'), isFalse);
    });

    test('filterEntries filters by text query', () {
      final filtered = ListeningHistoryExporter.filterEntries(
        sampleEntries,
        searchQuery: 'Daft',
      );

      expect(filtered.length, 1);
      expect(filtered.first.title, contains('Daft Punk'));
    });

    test('ListeningHistorySummary computes metrics correctly', () {
      final summary = ListeningHistorySummary.fromEntries(sampleEntries);

      expect(summary.totalPlays, 3);
      expect(summary.totalDuration, const Duration(seconds: 200 + 230 + 180));
      expect(summary.uniqueTracksCount, 3);
      expect(summary.uniqueArtistsCount, 3);
      expect(
        summary.averageCompletionRatio,
        closeTo((1.0 + 0.85 + 0.45) / 3, 0.001),
      );
      expect(summary.earliestPlay, timestamp3);
      expect(summary.latestPlay, timestamp1);
    });

    test('ListeningHistorySummary handles empty list safely', () {
      final summary = ListeningHistorySummary.fromEntries([]);

      expect(summary.totalPlays, 0);
      expect(summary.totalDuration, Duration.zero);
      expect(summary.uniqueTracksCount, 0);
      expect(summary.averageCompletionRatio, 0.0);
      expect(summary.earliestPlay, isNull);
    });
  });

  // ==========================================================================
  // Group 6: File Generation & Default File Naming
  // ==========================================================================
  group('File Export & File Naming', () {
    test('generateDefaultFileName creates valid timestamped file names', () {
      final csvName = ListeningHistoryExporter.generateDefaultFileName(
        format: HistoryExportFormat.csv,
        timestamp: DateTime.utc(2026, 11, 12, 15, 30, 45),
      );
      final jsonName = ListeningHistoryExporter.generateDefaultFileName(
        format: HistoryExportFormat.json,
        timestamp: DateTime.utc(2026, 11, 12, 15, 30, 45),
      );

      expect(csvName, 'softify_listening_history_20261112_153045.csv');
      expect(jsonName, 'softify_listening_history_20261112_153045.json');
    });

    test('exportToFile writes CSV file to filesystem', () async {
      final tempDir = await Directory.systemTemp.createTemp('softify_export_csv_');
      try {
        final file = await ListeningHistoryExporter.exportToFile(
          entries: sampleEntries,
          format: HistoryExportFormat.csv,
          directory: tempDir,
          fileName: 'custom_export.csv',
        );

        expect(await file.exists(), isTrue);
        final content = await file.readAsString();
        expect(content.contains('trk_001'), isTrue);
        expect(content.contains('Blinding Lights'), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('exportToFile writes JSON file to filesystem', () async {
      final tempDir = await Directory.systemTemp.createTemp('softify_export_json_');
      try {
        final file = await ListeningHistoryExporter.exportToFile(
          entries: sampleEntries,
          format: HistoryExportFormat.json,
          directory: tempDir,
          fileName: 'custom_export.json',
        );

        expect(await file.exists(), isTrue);
        final content = await file.readAsString();
        final decoded = jsonDecode(content) as List;
        expect(decoded.length, 3);
        expect(decoded.first['trackId'], 'trk_001');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  // ==========================================================================
  // Group 7: Riverpod Providers
  // ==========================================================================
  group('Riverpod Providers Integration', () {
    test('listeningHistoryExporterProvider returns valid exporter instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final exporter = container.read(listeningHistoryExporterProvider);
      expect(exporter, isA<ListeningHistoryExporter>());
    });

    test('historyExportNotifierProvider manages export workflow state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(historyExportNotifierProvider.notifier);
      final initialState = container.read(historyExportNotifierProvider);

      expect(initialState.isExporting, isFalse);
      expect(initialState.lastExportedCount, 0);

      final tempDir = await Directory.systemTemp.createTemp('softify_notifier_test_');
      try {
        final result = await notifier.exportHistory(
          entries: sampleEntries,
          format: HistoryExportFormat.csv,
          targetDirectory: tempDir,
        );

        expect(result, isNotNull);
        expect(result!.entryCount, 3);
        expect(result.format, HistoryExportFormat.csv);

        final updatedState = container.read(historyExportNotifierProvider);
        expect(updatedState.isExporting, isFalse);
        expect(updatedState.lastExportedCount, 3);
        expect(updatedState.lastExportedPath, isNotNull);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('allListeningHistoryEntriesProvider watches playHistoryStreamProvider', () async {
      final container = ProviderContainer(
        overrides: [
          playHistoryStreamProvider.overrideWith(
            (ref) => Stream.value([sampleHistoryItem1]),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Await stream resolution
      await container.read(playHistoryStreamProvider.future);

      final entries = container.read(allListeningHistoryEntriesProvider);
      expect(entries.length, 1);
      expect(entries.first.title, 'Midnight City');
      expect(entries.first.trackId, 'trk_track_1');
    });
  });

  // ==========================================================================
  // Group 8: Widget Tests: ExportHistoryButton & ExportHistorySheet
  // ==========================================================================
  group('ExportHistoryButton Widget Tests', () {
    testWidgets('renders standard button with label and icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ExportHistoryButton(
                entries: sampleEntries,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ExportHistoryButton), findsOneWidget);
      expect(find.text('Export History'), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });

    testWidgets('renders compact icon-only button when iconOnly is true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ExportHistoryButton(
                entries: sampleEntries,
                iconOnly: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ExportHistoryButton), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.text('Export History'), findsNothing);
    });

    testWidgets('tapping button with custom onPressed invokes callback', (tester) async {
      bool customPressed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ExportHistoryButton(
                entries: sampleEntries,
                onPressed: () => customPressed = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ExportHistoryButton));
      await tester.pumpAndSettle();

      expect(customPressed, isTrue);
    });

    testWidgets('tapping button with defaultFormat executes direct export', (tester) async {
      ExportResult? completedResult;
      final tempDir = Directory.systemTemp.createTempSync('softify_widget_direct_');

      try {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ExportHistoryButton(
                  entries: sampleEntries,
                  defaultFormat: HistoryExportFormat.json,
                  targetDirectory: tempDir,
                  showToast: false,
                  onExportCompleted: (res) => completedResult = res,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ExportHistoryButton));
        await tester.pumpAndSettle();

        expect(completedResult, isNotNull);
        expect(completedResult!.format, HistoryExportFormat.json);
        expect(completedResult!.entryCount, 3);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('tapping button opens interactive ExportHistorySheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ExportHistoryButton(
                entries: sampleEntries,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ExportHistoryButton));
      await tester.pumpAndSettle();

      // Verify bottom sheet title and options are presented
      expect(find.text('Export Listening History'), findsOneWidget);
      expect(find.text('FORMAT'), findsOneWidget);
      expect(find.text('CSV (.csv)'), findsOneWidget);
      expect(find.text('JSON (.json)'), findsOneWidget);
      expect(find.text('TIME RANGE'), findsOneWidget);
      expect(find.text('PREVIEW'), findsOneWidget);
      expect(find.byKey(const Key('export_copy_clipboard_button')), findsOneWidget);
      expect(find.byKey(const Key('export_save_file_button')), findsOneWidget);

      // Toggle to JSON format in sheet
      await tester.tap(find.text('JSON (.json)'));
      await tester.pumpAndSettle();

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Export Listening History'), findsNothing);
    });

    testWidgets('tapping Save File inside ExportHistorySheet triggers export', (tester) async {
      ExportResult? exported;
      final tempDir = Directory.systemTemp.createTempSync('softify_sheet_save_');

      try {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () {
                      showExportHistorySheet(
                        context,
                        entries: sampleEntries,
                        targetDirectory: tempDir,
                        onExportCompleted: (res) => exported = res,
                      );
                    },
                    child: const Text('Open Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('export_save_file_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('export_save_file_button')));
        await tester.pumpAndSettle();

        expect(exported, isNotNull);
        expect(exported!.entryCount, 3);
        expect(exported!.format, HistoryExportFormat.csv);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
