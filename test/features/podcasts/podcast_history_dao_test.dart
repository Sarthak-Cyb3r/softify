import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/features/podcasts/data/podcast_history_dao.dart';

void main() {
  late AppDatabase db;
  late PodcastHistoryDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = PodcastHistoryDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upsertHistory inserts and updates on conflict', () async {
    await dao.upsertHistory(
      episodeId: 'ep1',
      showId: 'show1',
      showName: 'Show One',
      title: 'Episode 1',
      durationSeconds: 1800,
      resumePositionMs: 120000,
      lastPlayedAt: 1000,
    );

    var recent = await dao.getRecent();
    expect(recent.length, 1);
    expect(recent.first.episodeId, 'ep1');
    expect(recent.first.showName, 'Show One');
    expect(recent.first.title, 'Episode 1');
    expect(recent.first.resumePositionMs, 120000);
    expect(recent.first.lastPlayedAt, 1000);

    // Update with new position and timestamp
    await dao.upsertHistory(
      episodeId: 'ep1',
      showId: 'show1',
      showName: 'Show One',
      title: 'Episode 1 Updated',
      durationSeconds: 1800,
      resumePositionMs: 240000,
      lastPlayedAt: 2000,
    );

    recent = await dao.getRecent();
    expect(recent.length, 1);
    expect(recent.first.title, 'Episode 1 Updated');
    expect(recent.first.resumePositionMs, 240000);
    expect(recent.first.lastPlayedAt, 2000);
  });

  test('updatePosition updates only resume position and lastPlayedAt', () async {
    await dao.upsertHistory(
      episodeId: 'ep1',
      showId: 'show1',
      showName: 'Show One',
      title: 'Episode 1',
      durationSeconds: 1800,
      resumePositionMs: 10000,
      lastPlayedAt: 1000,
    );

    await dao.updatePosition('ep1', 95000);

    final recent = await dao.getRecent();
    expect(recent.first.resumePositionMs, 95000);
  });

  test('watchRecent orders newest first and honors limit', () async {
    for (int i = 1; i <= 60; i++) {
      await dao.upsertHistory(
        episodeId: 'ep_$i',
        showId: 'show_1',
        showName: 'Show',
        title: 'Episode $i',
        durationSeconds: 600,
        lastPlayedAt: i * 1000,
      );
    }

    final recent50 = await dao.getRecent(limit: 50);
    expect(recent50.length, 50);
    expect(recent50.first.episodeId, 'ep_60');
    expect(recent50.last.episodeId, 'ep_11');
  });

  test('deleteEntry removes specific item', () async {
    await dao.upsertHistory(
      episodeId: 'ep1',
      showId: 'show1',
      showName: 'Show 1',
      title: 'Episode 1',
      durationSeconds: 100,
      lastPlayedAt: 1000,
    );
    await dao.upsertHistory(
      episodeId: 'ep2',
      showId: 'show2',
      showName: 'Show 2',
      title: 'Episode 2',
      durationSeconds: 200,
      lastPlayedAt: 2000,
    );

    await dao.deleteEntry('ep1');
    final recent = await dao.getRecent();
    expect(recent.length, 1);
    expect(recent.first.episodeId, 'ep2');
  });

  test('clearAll removes all entries', () async {
    await dao.upsertHistory(
      episodeId: 'ep1',
      showId: 'show1',
      showName: 'Show 1',
      title: 'Episode 1',
      durationSeconds: 100,
      lastPlayedAt: 1000,
    );
    await dao.upsertHistory(
      episodeId: 'ep2',
      showId: 'show2',
      showName: 'Show 2',
      title: 'Episode 2',
      durationSeconds: 200,
      lastPlayedAt: 2000,
    );

    await dao.clearAll();
    final recent = await dao.getRecent();
    expect(recent, isEmpty);
  });
}
