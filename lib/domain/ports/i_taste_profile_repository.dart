import '../entities/taste_profile.dart';
import '../entities/track.dart';

abstract class ITasteProfileRepository {
  Future<void> updateFromPlay({
    required Track track,
    required bool isStream,
    required bool isEarlySkip,
    required bool isSave,
  });

  Future<double> computeTasteSimilarity(Track track);

  Future<void> applyDecay();

  Future<List<TasteProfileEntity>> getTopEntities({
    String entityType = 'artist',
    int limit = 10,
  });
}
