import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/features/youtube/data/youtube_history_dao.dart';

void main() {
  late AppDatabase db;
  late YoutubeHistoryDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = YoutubeHistoryDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upsertHistory inserts and updates on conflict', () async {
    await dao.upsertHistory(
      videoId: 'vid1',
      title: 'Video 1',
      channel: 'Channel A',
      thumbnailUrl: 'https://thumb.url/1',
      durationSeconds: 180,
      lastPlayedAt: 1000,
    );

    var recent = await dao.getRecent();
    expect(recent.length, 1);
    expect(recent.first.videoId, 'vid1');
    expect(recent.first.title, 'Video 1');
    expect(recent.first.lastPlayedAt, 1000);

    // Update with new timestamp and title
    await dao.upsertHistory(
      videoId: 'vid1',
      title: 'Video 1 Updated',
      channel: 'Channel A',
      thumbnailUrl: 'https://thumb.url/1',
      durationSeconds: 180,
      lastPlayedAt: 2000,
    );

    recent = await dao.getRecent();
    expect(recent.length, 1);
    expect(recent.first.title, 'Video 1 Updated');
    expect(recent.first.lastPlayedAt, 2000);
  });

  test('watchRecent orders newest first and honors limit', () async {
    for (int i = 1; i <= 60; i++) {
      await dao.upsertHistory(
        videoId: 'vid_$i',
        title: 'Video $i',
        channel: 'Channel',
        durationSeconds: 100,
        lastPlayedAt: i * 1000,
      );
    }

    final recent50 = await dao.getRecent(limit: 50);
    expect(recent50.length, 50);
    expect(recent50.first.videoId, 'vid_60');
    expect(recent50.last.videoId, 'vid_11');
  });

  test('deleteEntry removes specific item', () async {
    await dao.upsertHistory(
      videoId: 'vid1',
      title: 'Video 1',
      channel: 'Channel A',
      durationSeconds: 100,
      lastPlayedAt: 1000,
    );
    await dao.upsertHistory(
      videoId: 'vid2',
      title: 'Video 2',
      channel: 'Channel B',
      durationSeconds: 200,
      lastPlayedAt: 2000,
    );

    await dao.deleteEntry('vid1');
    final recent = await dao.getRecent();
    expect(recent.length, 1);
    expect(recent.first.videoId, 'vid2');
  });

  test('clearAll removes all entries', () async {
    await dao.upsertHistory(
      videoId: 'vid1',
      title: 'Video 1',
      channel: 'Channel A',
      durationSeconds: 100,
      lastPlayedAt: 1000,
    );
    await dao.upsertHistory(
      videoId: 'vid2',
      title: 'Video 2',
      channel: 'Channel B',
      durationSeconds: 200,
      lastPlayedAt: 2000,
    );

    await dao.clearAll();
    final recent = await dao.getRecent();
    expect(recent, isEmpty);
  });
}
