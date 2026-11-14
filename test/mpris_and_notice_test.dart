import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/services/device_control_service.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:audio_service/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notice Broadcast & Device Model Data Tests', () {
    test('AppNotice parses full json accurately', () {
      final json = {
        'id': '1730000000',
        'title': 'Test Notice',
        'message': 'This is a test broadcast banner',
        'type': 'warning',
        'createdAt': '2026-10-26T14:00:00.000Z',
      };

      final notice = AppNotice.fromJson(json);
      expect(notice.id, equals('1730000000'));
      expect(notice.title, equals('Test Notice'));
      expect(notice.message, equals('This is a test broadcast banner'));
      expect(notice.type, equals('warning'));
      expect(notice.createdAt, isNotNull);
    });

    test('AppNotice handles null or partial json with safe defaults', () {
      final json = <String, dynamic>{
        'id': null,
        'message': 'Simple message without title',
      };

      final notice = AppNotice.fromJson(json);
      expect(notice.id, equals(''));
      expect(notice.title, equals('Notice'));
      expect(notice.message, equals('Simple message without title'));
      expect(notice.type, equals('info'));
      expect(notice.createdAt, isNull);
    });

    test('DeviceControlService persists and retrieves dismissed notice ID', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final service = DeviceControlService(db: db);

      final initialId = await service.getLastDismissedNoticeId();
      expect(initialId, isNull);

      await service.setLastDismissedNoticeId('notice-42');
      final savedId = await service.getLastDismissedNoticeId();
      expect(savedId, equals('notice-42'));

      await service.setLastDismissedNoticeId('notice-99');
      final updatedId = await service.getLastDismissedNoticeId();
      expect(updatedId, equals('notice-99'));

      await db.close();
    });

    test('DeviceControlService generates persistent unique UUID v4', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final service = DeviceControlService(db: db);

      final id1 = await service.getDeviceId();
      final id2 = await service.getDeviceId();

      expect(id1, isNotEmpty);
      expect(id1, equals(id2));
      expect(id1.split('-').length, equals(5));

      await db.close();
    });
  });

  group('MPRIS 2 Audio Metadata & Control Mapping Contract', () {
    test('Track correctly converts to MediaItem with full MPRIS metadata and valid URI', () {
      const track = Track(
        id: 'track_12345',
        sourceId: 'track_12345',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: Duration(seconds: 200),
        coverUrl: 'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36',
      );

      final mediaItem = MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        artUri: Uri.parse(track.coverUrl!),
      );

      expect(mediaItem.id, equals('track_12345'));
      expect(mediaItem.title, equals('Blinding Lights'));
      expect(mediaItem.artist, equals('The Weeknd'));
      expect(mediaItem.album, equals('After Hours'));
      expect(mediaItem.duration, equals(const Duration(seconds: 200)));
      expect(mediaItem.artUri?.scheme, equals('https'));
    });

    test('PlaybackState provides accurate controls, actions, and position for D-Bus status', () {
      final state = PlaybackState(
        controls: const [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        playing: true,
        updatePosition: const Duration(seconds: 45),
        processingState: AudioProcessingState.ready,
      );

      expect(state.playing, isTrue);
      expect(state.updatePosition, equals(const Duration(seconds: 45)));
      expect(state.systemActions.contains(MediaAction.seek), isTrue);
      expect(state.controls.contains(MediaControl.pause), isTrue);
    });
  });
}
