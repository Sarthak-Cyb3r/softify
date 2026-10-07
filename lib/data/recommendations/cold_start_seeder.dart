import 'package:drift/drift.dart';

import '../../domain/ports/i_cold_start_seeder.dart';
import '../../domain/ports/i_spotify_importer.dart';
import '../database/app_database.dart';

class ColdStartSeeder implements IColdStartSeeder {
  final AppDatabase _db;
  final ISpotifyImporter? _spotifyImporter;

  ColdStartSeeder({
    required AppDatabase db,
    ISpotifyImporter? spotifyImporter,
  })  : _db = db,
        _spotifyImporter = spotifyImporter;

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
}
