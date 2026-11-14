import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/playlist_m3u_exporter.dart';

class _TestMockContext extends Fake implements BuildContext {
  @override
  bool get mounted => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleTracks = [
    const Track(
      id: 'track_1',
      sourceId: 'dQw4w9WgXcQ',
      title: 'Never Gonna Give You Up',
      artist: 'Rick Astley',
      album: 'Whenever You Need Somebody',
      duration: Duration(seconds: 213),
    ),
    const Track(
      id: 'track_2',
      sourceId: '/storage/emulated/0/Music/song2.mp3',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      album: 'A Night at the Opera',
      duration: Duration(seconds: 354),
    ),
    const Track(
      id: 'track_3',
      sourceId: 'https://example.com/audio/live.mp3',
      title: 'Special "Title", with commas & "quotes"',
      artist: 'Artist, The Great',
      album: 'Quoted "Album"',
      duration: Duration(seconds: 125),
    ),
  ];

  group('PlaylistM3uExporter - generateM3u8', () {
    test('generates valid M3U8 with #EXTM3U header and #EXTINF lines', () {
      final m3u = PlaylistM3uExporter.generateM3u8('My Chill Vibes', sampleTracks);

      expect(m3u, startsWith('#EXTM3U\n'));
      expect(m3u, contains('#PLAYLIST:My Chill Vibes\n'));

      // Check Track 1 (YouTube source ID)
      expect(m3u, contains('#EXTINF:213,Rick Astley - Never Gonna Give You Up\n'));
      expect(m3u, contains('https://www.youtube.com/watch?v=dQw4w9WgXcQ\n'));

      // Check Track 2 (Local file path)
      expect(m3u, contains('#EXTINF:354,Queen - Bohemian Rhapsody\n'));
      expect(m3u, contains('/storage/emulated/0/Music/song2.mp3\n'));

      // Check Track 3 (HTTPS url)
      expect(m3u, contains('#EXTINF:125,Artist, The Great - Special "Title", with commas & "quotes"\n'));
      expect(m3u, contains('https://example.com/audio/live.mp3\n'));
    });

    test('generates empty playlist with #EXTM3U header only when no tracks', () {
      final m3u = PlaylistM3uExporter.generateM3u8('Empty List', []);
      expect(m3u, equals('#EXTM3U\n#PLAYLIST:Empty List\n'));
    });

    test('omits playlist header if playlistName is empty', () {
      final m3u = PlaylistM3uExporter.generateM3u8('', sampleTracks);
      expect(m3u, startsWith('#EXTM3U\n'));
      expect(m3u, isNot(contains('#PLAYLIST:')));
    });

    test('instance method works via extension', () {
      const exporter = PlaylistM3uExporter();
      final m3u = exporter.generateM3u8('Test', sampleTracks);
      expect(m3u, startsWith('#EXTM3U\n'));
    });
  });

  group('PlaylistM3uExporter - generateCsv', () {
    test('generates RFC 4180 compliant CSV', () {
      final csv = PlaylistM3uExporter.generateCsv('My Chill Vibes', sampleTracks);

      final lines = csv.trim().split('\n');
      expect(lines.first, equals('Index,Title,Artist,Album,Duration,DurationSeconds,SourceId'));

      // 1 header + 3 tracks = 4 lines
      expect(lines.length, equals(4));

      // Check line 2 (first track)
      expect(lines[1], equals('1,Never Gonna Give You Up,Rick Astley,Whenever You Need Somebody,03:33,213,dQw4w9WgXcQ'));

      // Check line 4 (escaped quotes and commas)
      expect(lines[3], contains('"Special ""Title"", with commas & ""quotes"""'));
      expect(lines[3], contains('"Artist, The Great"'));
      expect(lines[3], contains('"Quoted ""Album"""'));
      expect(lines[3], contains('02:05,125'));
    });

    test('handles empty track list in CSV', () {
      final csv = PlaylistM3uExporter.generateCsv('Empty', []);
      expect(csv.trim(), equals('Index,Title,Artist,Album,Duration,DurationSeconds,SourceId'));
    });
  });

  group('PlaylistM3uExporter - sanitizeFileName & formatDuration', () {
    test('sanitizes illegal filesystem characters', () {
      expect(
        PlaylistM3uExporter.sanitizeFileName('Rock/Metal: Best & Loud? *Yes* | "Cool" <1>'),
        equals('Rock_Metal_ Best & Loud_ _Yes_ _ _Cool_ _1_'),
      );
      expect(PlaylistM3uExporter.sanitizeFileName('   '), equals('playlist'));
      expect(PlaylistM3uExporter.sanitizeFileName('My Playlist...'), equals('My Playlist'));
    });

    test('formats duration correctly with and without hours', () {
      expect(PlaylistM3uExporter.formatDuration(const Duration(seconds: 45)), equals('00:45'));
      expect(PlaylistM3uExporter.formatDuration(const Duration(minutes: 3, seconds: 25)), equals('03:25'));
      expect(PlaylistM3uExporter.formatDuration(const Duration(hours: 1, minutes: 12, seconds: 4)), equals('01:12:04'));
    });
  });

  group('PlaylistM3uExporter - exportToFile', () {
    test('exports M3U8 and CSV files to disk with correct contents', () async {
      final tempDir = await Directory.systemTemp.createTemp('softify_export_test_');
      final mockContext = _TestMockContext();

      try {
        // Export M3U8
        final m3uPath = await PlaylistM3uExporter.exportToFile(
          mockContext,
          'Test Export',
          sampleTracks,
          isCsv: false,
          customDirectory: tempDir,
        );
        expect(m3uPath, isNotNull);
        final m3uFile = File(m3uPath!);
        expect(await m3uFile.exists(), isTrue);
        final m3uContent = await m3uFile.readAsString();
        expect(m3uContent, contains('#EXTM3U'));
        expect(m3uContent, contains('Rick Astley - Never Gonna Give You Up'));

        // Export CSV
        final csvPath = await PlaylistM3uExporter.exportToFile(
          mockContext,
          'Test Export',
          sampleTracks,
          isCsv: true,
          customDirectory: tempDir,
        );
        expect(csvPath, isNotNull);
        final csvFile = File(csvPath!);
        expect(await csvFile.exists(), isTrue);
        final csvContent = await csvFile.readAsString();
        expect(csvContent, contains('Never Gonna Give You Up'));
        expect(csvContent, contains('Index,Title,Artist,Album'));
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('handles export error gracefully and returns null', () async {
      final mockContext = _TestMockContext();
      // An invalid directory path that cannot be created or written to
      final invalidDir = Directory('/sys/firmware/softify_invalid_forbidden_dir');
      final result = await PlaylistM3uExporter.exportToFile(
        mockContext,
        'Invalid',
        sampleTracks,
        customDirectory: invalidDir,
      );
      expect(result, isNull);
    });
  });

  group('PlaylistM3uExporter - Riverpod Provider', () {
    test('container resolves playlistM3uExporterProvider', () {
      final container = ProviderContainer();
      final exporter = container.read(playlistM3uExporterProvider);
      expect(exporter, isA<PlaylistM3uExporter>());

      final m3u = exporter.generateM3u8('Provider Playlist', sampleTracks);
      expect(m3u, contains('#PLAYLIST:Provider Playlist'));
    });
  });
}
