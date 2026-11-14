import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/download_item.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/screens/library_screen.dart';

void main() {
  group('LibrarySortOrder', () {
    const trackA = Track(
      id: 't1',
      title: 'Believer',
      artist: 'Imagine Dragons',
      sourceId: 'saavn_1',
      duration: Duration(minutes: 3, seconds: 24),
    );

    const trackB = Track(
      id: 't2',
      title: 'Animals',
      artist: 'Martin Garrix',
      sourceId: 'saavn_2',
      duration: Duration(minutes: 2, seconds: 56),
    );

    const trackC = Track(
      id: 't3',
      title: 'Counting Stars',
      artist: 'OneRepublic',
      sourceId: 'saavn_3',
      duration: Duration(minutes: 4, seconds: 17),
    );

    test('verifies enum values and human readable labels', () {
      expect(LibrarySortOrder.recentlyAdded.label, equals('Recent'));
      expect(LibrarySortOrder.titleAZ.label, equals('Title A-Z'));
      expect(LibrarySortOrder.artistAZ.label, equals('Artist A-Z'));
    });

    test('sorts tracks alphabetically by title case-insensitively', () {
      final input = [trackA, trackB, trackC];
      final sorted = List<Track>.from(input)
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

      expect(sorted.map((t) => t.title).toList(), equals(['Animals', 'Believer', 'Counting Stars']));
    });

    test('sorts tracks alphabetically by artist case-insensitively', () {
      final input = [trackC, trackB, trackA];
      final sorted = List<Track>.from(input)
        ..sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));

      expect(sorted.map((t) => t.artist).toList(), equals(['Imagine Dragons', 'Martin Garrix', 'OneRepublic']));
    });

    test('sorts downloads by track title', () {
      final now = DateTime.now();
      final dl1 = DownloadItem(
        trackId: 't1',
        relativePath: 't1.m4a',
        createdAt: now,
        status: DownloadStatus.completed,
        bytesDownloaded: 5000,
        fileSizeBytes: 5000,
        track: trackA,
      );
      final dl2 = DownloadItem(
        trackId: 't2',
        relativePath: 't2.m4a',
        createdAt: now,
        status: DownloadStatus.completed,
        bytesDownloaded: 4000,
        fileSizeBytes: 4000,
        track: trackB,
      );

      final list = [dl1, dl2];
      list.sort((a, b) {
        final aTitle = a.track?.title ?? a.trackId;
        final bTitle = b.track?.title ?? b.trackId;
        return aTitle.toLowerCase().compareTo(bTitle.toLowerCase());
      });

      expect(list.first.track?.title, equals('Animals'));
      expect(list.last.track?.title, equals('Believer'));
    });
  });
}
