import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/track.dart';
import '../../services/animated_artwork_service.dart';
import 'player_providers.dart';

class AnimatedArtworkNotifier extends StateNotifier<bool> {
  final AppDatabase? _db;
  static const String _key = 'animated_artwork_enabled';

  AnimatedArtworkNotifier(this._db) : super(true) {
    if (_db != null) {
      _loadFromDb();
    }
  }

  Future<void> _loadFromDb() async {
    final db = _db;
    if (db == null) return;
    try {
      final row = await (db.select(db.settings)
            ..where((t) => t.key.equals(_key)))
          .getSingleOrNull();
      if (row != null) {
        state = row.value == 'true';
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    final db = _db;
    if (db == null) return;
    try {
      await db.into(db.settings).insertOnConflictUpdate(
            SettingRow(
              key: _key,
              value: enabled.toString(),
            ),
          );
    } catch (_) {}
  }
}

/// Toggles whether Apple Music animated motion cover artwork is used instead of static covers/canvas.
final animatedArtworkEnabledProvider =
    StateNotifierProvider<AnimatedArtworkNotifier, bool>((ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {}
  return AnimatedArtworkNotifier(db);
});

/// Resolves animated artwork for a specific track when enabled.
final animatedArtworkProvider =
    FutureProvider.family<AnimatedArtwork?, Track>((ref, track) async {
  final isEnabled = ref.watch(animatedArtworkEnabledProvider);
  if (!isEnabled) return null;
  if (track.id.isEmpty) return null;
  return AnimatedArtworkService.instance.resolveAnimatedArtwork(track);
});
