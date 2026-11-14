import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/services/smart_playlists_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('SmartPlaylistsService computes On Repeat, Most Played, and Forgotten Favorites', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5)).millisecondsSinceEpoch;
    final twentyFiveDaysAgo = DateTime.now().subtract(const Duration(days: 25)).millisecondsSinceEpoch;

    // Insert 3 test tracks
    await db.into(db.tracks).insert(
          TrackRow(
            id: 'track_1',
            sourceId: 'src_1',
            title: 'Active Jam',
            artist: 'Star Artist',
            album: 'Hits',
            durationMs: 200000,
            coverUrl: null,
            matchConfidence: 1.0,
            isLiked: true,
            isUnavailable: false,
            createdAt: now,
          ),
        );

    await db.into(db.tracks).insert(
          TrackRow(
            id: 'track_2',
            sourceId: 'src_2',
            title: 'Old Favorite',
            artist: 'Classic Band',
            album: 'Gold',
            durationMs: 180000,
            coverUrl: null,
            matchConfidence: 1.0,
            isLiked: true,
            isUnavailable: false,
            createdAt: twentyFiveDaysAgo,
          ),
        );

    await db.into(db.tracks).insert(
          TrackRow(
            id: 'track_3',
            sourceId: 'src_3',
            title: 'Casual Song',
            artist: 'Indie Solo',
            album: 'EP',
            durationMs: 150000,
            coverUrl: null,
            matchConfidence: 1.0,
            isLiked: false,
            isUnavailable: false,
            createdAt: now,
          ),
        );

    // Track 1 played 3 times 5 days ago
    for (int i = 0; i < 3; i++) {
      await db.into(db.playHistories).insert(
            PlayHistoriesCompanion.insert(
              trackId: 'track_1',
              playedAt: fiveDaysAgo + i * 1000,
              completedRatio: 0.9,
            ),
          );
    }

    // Track 2 played once 25 days ago
    await db.into(db.playHistories).insert(
          PlayHistoriesCompanion.insert(
            trackId: 'track_2',
            playedAt: twentyFiveDaysAgo,
            completedRatio: 1.0,
          ),
        );

    // Verify On Repeat: only track_1 should appear (played in last 14 days)
    final onRepeat = await SmartPlaylistsService.getOnRepeatTracks(db);
    expect(onRepeat.length, 1);
    expect(onRepeat.first.id, 'track_1');

    // Verify Most Played This Month: track_1 (3 plays) then track_2 (1 play)
    final mostPlayed = await SmartPlaylistsService.getMostPlayedThisMonth(db);
    expect(mostPlayed.length, 2);
    expect(mostPlayed.first.id, 'track_1');

    // Verify Forgotten Favorites: track_2 is liked and was NOT played in the last 21 days
    final forgotten = await SmartPlaylistsService.getForgottenFavorites(db);
    expect(forgotten.any((t) => t.id == 'track_2'), isTrue);
    expect(forgotten.any((t) => t.id == 'track_1'), isFalse);

    // Verify Listening Insights ("Softify Wrapped")
    final insights = await SmartPlaylistsService.getListeningInsights(db);
    expect(insights.totalTracksPlayed, 4);
    expect(insights.topArtists.first.key, 'Star Artist');
    expect(insights.topArtists.first.value, 3);
    expect(insights.topTracks.first.id, 'track_1');
    expect(insights.detailedTopArtists.first.name, 'Star Artist');
    expect(insights.detailedTopTracks.first.track.id, 'track_1');
    expect(insights.hourlyDistribution.length, 24);
    expect(insights.timeframe, InsightsTimeframe.allTime);

    // Verify Timeframe filtering (track_2 was 25 days ago, so in past 7 days only track_1 appears)
    final past7DaysInsights = await SmartPlaylistsService.getListeningInsights(
      db,
      timeframe: InsightsTimeframe.past7Days,
    );
    expect(past7DaysInsights.totalTracksPlayed, 3);
    expect(past7DaysInsights.topTracks.first.id, 'track_1');
  });
}
