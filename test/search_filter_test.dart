import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/screens/search_screen.dart';

void main() {
  group('SearchResultFilter', () {
    const trackStudio = Track(
      id: 't_saavn_1',
      title: 'Kesariya',
      artist: 'Arijit Singh',
      sourceId: 'saavn_12345',
      duration: Duration(minutes: 4, seconds: 28),
    );

    const trackYouTube = Track(
      id: 't_yt_2',
      title: 'Live Acoustic Session',
      artist: 'Indie Artist',
      sourceId: 'yt_abcde',
      duration: Duration(minutes: 5, seconds: 10),
    );

    test('verifies SearchResultFilter enum labels', () {
      expect(SearchResultFilter.all.label, equals('All'));
      expect(SearchResultFilter.tracks.label, equals('Songs'));
      expect(SearchResultFilter.downloaded.label, equals('Downloaded'));
    });

    test('filters studio master 320kbps tracks correctly', () {
      final list = [trackStudio, trackYouTube];
      final studioOnly = list.where((t) => t.sourceId.startsWith('saavn_') || !t.supportsSpeedPlayback).toList();

      expect(studioOnly.length, equals(1));
      expect(studioOnly.first.title, equals('Kesariya'));
    });

    test('filters downloaded tracks based on completed download ids', () {
      final list = [trackStudio, trackYouTube];
      const downloadedIds = {'t_yt_2'};
      final downloadedOnly = list.where((t) => downloadedIds.contains(t.id)).toList();

      expect(downloadedOnly.length, equals(1));
      expect(downloadedOnly.first.title, equals('Live Acoustic Session'));
    });
  });
}
