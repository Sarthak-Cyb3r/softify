import 'package:drift/drift.dart';

import '../../domain/ports/i_cold_start_seeder.dart';
import '../../domain/ports/i_spotify_importer.dart';
import '../database/app_database.dart';
import '../services/spotify_api_service.dart';

class ColdStartSeeder implements IColdStartSeeder {
  final AppDatabase _db;
  final ISpotifyImporter? _spotifyImporter;
  final SpotifyApiService? _spotifyApi;

  ColdStartSeeder({
    required AppDatabase db,
    ISpotifyImporter? spotifyImporter,
    SpotifyApiService? spotifyApi,
  })  : _db = db,
        _spotifyImporter = spotifyImporter,
        _spotifyApi = spotifyApi;

  @override
  Future<void> seedFromInitialArtists(List<String> artistIds) async {
    if (artistIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final artist in artistIds) {
      final cleanArtist = artist.trim();
      if (cleanArtist.isEmpty) continue;

      // Seed initial positive taste profile: slowWeight = 1.0, fastWeight = 1.0
      await _db.into(_db.tasteProfiles).insertOnConflictUpdate(
        TasteProfilesCompanion(
          entityType: const Value('artist'),
          entityId: Value(cleanArtist),
          slowWeight: const Value(1.0),
          fastWeight: const Value(1.0),
          updatedAt: Value(now),
        ),
      );
    }
  }

  @override
  Future<void> seedFromSpotifyImport(String playlistId) async {
    final importer = _spotifyImporter;
    if (importer == null) return;

    try {
      final playlist = await importer.fetchPlaylist(playlistId);
      final now = DateTime.now().millisecondsSinceEpoch;
      final artistWeights = <String, double>{};

      for (final item in playlist.tracks) {
        final artist = item.artist.trim();
        if (artist.isNotEmpty) {
          artistWeights[artist] = (artistWeights[artist] ?? 0.0) + 0.2;
        }
      }

      for (final entry in artistWeights.entries) {
        final weight = entry.value.clamp(0.2, 1.5);
        await _db.into(_db.tasteProfiles).insertOnConflictUpdate(
          TasteProfilesCompanion(
            entityType: const Value('artist'),
            entityId: Value(entry.key),
            slowWeight: Value(weight),
            fastWeight: Value(weight),
            updatedAt: Value(now),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Future<int> seedFromSpotifyAccount() async {
    final api = _spotifyApi;
    if (api == null) return 0;
    try {
      final loggedIn = await api.isUserLoggedIn();
      if (!loggedIn) return 0;

      final topArtists = await api.getUserTopArtists(timeRange: 'medium_term', limit: 25);
      final now = DateTime.now().millisecondsSinceEpoch;
      int count = 0;

      for (int i = 0; i < topArtists.length; i++) {
        final artist = topArtists[i].name.trim();
        if (artist.isEmpty) continue;
        // Top ranked artists get highest weight (2.0 down to 1.2)
        final weight = 2.0 - (i / topArtists.length) * 0.8;
        await _db.into(_db.tasteProfiles).insertOnConflictUpdate(
          TasteProfilesCompanion(
            entityType: const Value('artist'),
            entityId: Value(artist),
            slowWeight: Value(weight),
            fastWeight: Value(weight),
            updatedAt: Value(now),
          ),
        );
        count++;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }
}
