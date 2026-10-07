import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/recommendations/automix_tail_reorderer.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  group('AutomixTailReorderer & Pre-Buffer Invariant', () {
    late AutomixTailReorderer reorderer;

    Track makeTrack(String id, String artist, {String? album}) {
      return Track(
        id: id,
        sourceId: 'src_$id',
        title: 'Song $id',
        artist: artist,
        album: album,
        duration: const Duration(minutes: 3),
      );
    }

    setUp(() {
      reorderer = AutomixTailReorderer();
    });

    test('Hard Invariant: Current track (N) and Pre-buffered track (N+1) are NEVER modified or reordered', () {
      final queue = [
        makeTrack('track_0_playing', 'Artist Current'),
        makeTrack('track_1_prebuffered', 'Artist Next'),
        makeTrack('track_2_tail', 'Artist C'),
        makeTrack('track_3_tail', 'Artist Current'), // Matching artist in tail
        makeTrack('track_4_tail', 'Artist D'),
      ];

      final reordered = reorderer.reorderTail(
        currentQueue: queue,
        currentIndex: 0,
        hasBufferedNext: true,
        sessionConsecutiveSkips: 0,
      );

      // Track 0 and Track 1 must be exactly identical to original
      expect(reordered[0].id, 'track_0_playing');
      expect(reordered[1].id, 'track_1_prebuffered');

      // Total queue length preserved
      expect(reordered.length, queue.length);
    });

    test('Two consecutive skips shifts tail candidates towards fast interest and penalizes skipped artist', () {
      final queue = [
        makeTrack('t0', 'SkippedArtist'),
        makeTrack('t1_buf', 'NeutralArtist'),
        makeTrack('t2_tail_skipped', 'SkippedArtist'), // Same as skipped artist
        makeTrack('t3_tail_fresh', 'FreshFavArtist'),
        makeTrack('t4_tail_fresh2', 'FreshFavArtist'),
      ];

      // Case A: 0 skips
      final normalReorder = reorderer.reorderTail(
        currentQueue: queue,
        currentIndex: 0,
        hasBufferedNext: true,
        sessionConsecutiveSkips: 0,
      );

      // Case B: 2 consecutive skips in session
      final fastInterestReorder = reorderer.reorderTail(
        currentQueue: queue,
        currentIndex: 0,
        hasBufferedNext: true,
        sessionConsecutiveSkips: 2,
      );

      // Invariant: track 0 and track 1 untouchable in both cases
      expect(normalReorder[0].id, 't0');
      expect(normalReorder[1].id, 't1_buf');
      expect(fastInterestReorder[0].id, 't0');
      expect(fastInterestReorder[1].id, 't1_buf');

      // With 2 consecutive skips, the skipped artist track in tail (t2_tail_skipped)
      // must be penalized and drop below fresh candidates
      expect(fastInterestReorder.last.id, 't2_tail_skipped');
    });

    test('Queue boundaries: empty queue or short tail returns intact queue', () {
      final shortQueue = [
        makeTrack('t0', 'Artist A'),
        makeTrack('t1', 'Artist B'),
      ];

      // No unbuffered tail exists
      final result = reorderer.reorderTail(
        currentQueue: shortQueue,
        currentIndex: 0,
        hasBufferedNext: true,
        sessionConsecutiveSkips: 3,
      );

      expect(result.length, 2);
      expect(result[0].id, 't0');
      expect(result[1].id, 't1');
    });
  });
}
