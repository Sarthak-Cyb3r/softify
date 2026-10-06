import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/data/verification/milestone0_runner.dart';
import 'package:softify/domain/entities/stream_info.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  group('Milestone 0: Domain Entities & Invariants', () {
    test('Track entity maintains synthetic UUID and external sourceId', () {
      const track = Track(
        id: 'softify_uuid_123',
        sourceId: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        duration: Duration(seconds: 213),
      );

      expect(track.id, 'softify_uuid_123');
      expect(track.sourceId, 'dQw4w9WgXcQ');
      expect(track.isUnavailable, false);
      expect(track.isLiked, false);

      final map = track.toMap();
      final revived = Track.fromMap(map);
      expect(revived, equals(track));
    });

    test('StreamInfo reports expiration correctly', () {
      final expired = StreamInfo(
        url: Uri.parse('https://example.com/audio.m4a'),
        container: 'm4a',
        bitrate: 128000,
        codec: 'mp4a.40.2',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        providerName: 'test',
      );
      expect(expired.isExpired, isTrue);

      final valid = StreamInfo(
        url: Uri.parse('https://example.com/audio.m4a'),
        container: 'm4a',
        bitrate: 128000,
        codec: 'mp4a.40.2',
        expiresAt: DateTime.now().add(const Duration(minutes: 45)),
        providerName: 'test',
      );
      expect(valid.isExpired, isFalse);
    });
  });

  group('Milestone 0: M4A Atom Tagging & Byte Verification', () {
    test('writes iTunes MP4 atoms into container and verifies tags', () async {
      final tempDir = Directory.systemTemp.createTempSync('softify_tag_test');
      try {
        final pass = await Milestone0Runner.runTaggingTest(tempDir);
        expect(pass, isTrue, reason: 'M4A container tagging and byte check must pass');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
