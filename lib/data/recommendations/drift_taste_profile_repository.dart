import 'dart:math';

import 'package:drift/drift.dart';

import '../../domain/entities/taste_profile.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_taste_profile_repository.dart';
import '../database/app_database.dart';

class DriftTasteProfileRepository implements ITasteProfileRepository {
  final AppDatabase _db;

  static const double fastHalfLifeHours = 4.0;
  static const double slowHalfLifeDays = 14.0;

  static const double fastHalfLifeMs = fastHalfLifeHours * 3600 * 1000;
  static const double slowHalfLifeMs = slowHalfLifeDays * 86400 * 1000;

  DriftTasteProfileRepository(this._db);

  @override
  Future<void> updateFromPlay({
    required Track track,
    required bool isStream,
    required bool isEarlySkip,
    required bool isSave,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final artist = track.artist.trim();
    if (artist.isEmpty) return;

    final existing = await (_db.select(_db.tasteProfiles)
          ..where((t) =>
              t.entityType.equals('artist') & t.entityId.equals(artist)))
        .getSingleOrNull();

    double currentFast = 0.0;
    double currentSlow = 0.0;

    if (existing != null) {
      final dt = (now - existing.updatedAt).toDouble();
      currentFast = existing.fastWeight * pow(2.0, -dt / fastHalfLifeMs);
      currentSlow = existing.slowWeight * pow(2.0, -dt / slowHalfLifeMs);
    }

    if (isStream) {
      currentFast += 1.0;
      currentSlow += 1.0;
    }
    if (isSave) {
      currentFast += 2.0;
      currentSlow += 2.0;
    }
    if (isEarlySkip) {
      currentFast = max(0.0, currentFast - 1.5);
      currentSlow = max(0.0, currentSlow - 0.5);
    }

    if (existing != null) {
      await (_db.update(_db.tasteProfiles)..where((t) => t.id.equals(existing.id)))
          .write(
        TasteProfilesCompanion(
          fastWeight: Value(currentFast),
          slowWeight: Value(currentSlow),
          updatedAt: Value(now),
        ),
      );
    } else {
      await _db.into(_db.tasteProfiles).insert(
            TasteProfilesCompanion.insert(
              entityType: 'artist',
              entityId: artist,
              fastWeight: Value(currentFast),
              slowWeight: Value(currentSlow),
              updatedAt: now,
            ),
          );
    }
  }

  @override
  Future<double> computeTasteSimilarity(Track track) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final artist = track.artist.trim();
    if (artist.isEmpty) return 0.0;

    final existing = await (_db.select(_db.tasteProfiles)
          ..where((t) =>
              t.entityType.equals('artist') & t.entityId.equals(artist)))
        .getSingleOrNull();

    if (existing == null) return 0.0;

    final dt = (now - existing.updatedAt).toDouble();
    final decayedFast = existing.fastWeight * pow(2.0, -dt / fastHalfLifeMs);
    final decayedSlow = existing.slowWeight * pow(2.0, -dt / slowHalfLifeMs);

    final blended = (0.4 * decayedFast) + (0.6 * decayedSlow);
    if (blended <= 0.0) return 0.0;

    // Soft saturation function: x / (x + 2.0)
    return (blended / (blended + 2.0)).clamp(0.0, 1.0);
  }

  @override
  Future<void> applyDecay() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db.select(_db.tasteProfiles).get();

    for (final row in rows) {
      final dt = (now - row.updatedAt).toDouble();
      if (dt > 60000) {
        final decayedFast = row.fastWeight * pow(2.0, -dt / fastHalfLifeMs);
        final decayedSlow = row.slowWeight * pow(2.0, -dt / slowHalfLifeMs);

        await (_db.update(_db.tasteProfiles)..where((t) => t.id.equals(row.id)))
            .write(
          TasteProfilesCompanion(
            fastWeight: Value(decayedFast),
            slowWeight: Value(decayedSlow),
            updatedAt: Value(now),
          ),
        );
      }
    }
  }

  @override
  Future<List<TasteProfileEntity>> getTopEntities({
    String entityType = 'artist',
    int limit = 10,
  }) async {
    final rows = await (_db.select(_db.tasteProfiles)
          ..where((t) => t.entityType.equals(entityType)))
        .get();

    final now = DateTime.now().millisecondsSinceEpoch;
    final entities = rows.map((r) {
      final dt = (now - r.updatedAt).toDouble();
      final fast = r.fastWeight * pow(2.0, -dt / fastHalfLifeMs);
      final slow = r.slowWeight * pow(2.0, -dt / slowHalfLifeMs);
      return TasteProfileEntity(
        id: r.id,
        entityType: r.entityType,
        entityId: r.entityId,
        fastWeight: fast,
        slowWeight: slow,
        updatedAt: r.updatedAt,
      );
    }).toList();

    entities.sort((a, b) => b.blendedAffinity.compareTo(a.blendedAffinity));
    return entities.take(limit).toList();
  }
}
