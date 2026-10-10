import '../../domain/entities/track.dart';
import '../../domain/ports/i_cooccurrence_repository.dart';
import '../../domain/ports/i_taste_profile_repository.dart';

class ExplanationGenerator {
  final ITasteProfileRepository? _tasteRepo;
  final ICooccurrenceRepository? _cooccurRepo;

  ExplanationGenerator({
    ITasteProfileRepository? tasteRepo,
    ICooccurrenceRepository? cooccurRepo,
  })  : _tasteRepo = tasteRepo,
        _cooccurRepo = cooccurRepo;

  /// Generates a concise, user-facing 1-line reason for a recommended track.
  Future<String> generateExplanation(
    Track track, {
    String? shelfId,
    Track? seedTrack,
  }) async {
    if (seedTrack != null) {
      return 'Because you listened to ${seedTrack.title}';
    }

    if (shelfId == 'jump_back_in') {
      return 'From your recent rotation';
    }

    if (shelfId == 'discover_weekly') {
      return 'Recommended based on your taste in ${track.artist}';
    }

    if (shelfId == 'daily_mix') {
      return 'Mix inspired by ${track.artist}';
    }

    final tasteRepo = _tasteRepo;
    if (tasteRepo != null) {
      final topArtists = await tasteRepo.getTopEntities(entityType: 'artist', limit: 5);
      final isTopArtist = topArtists.any(
        (a) => a.entityId.toLowerCase() == track.artist.toLowerCase(),
      );
      if (isTopArtist) {
        return 'Top artist match for you';
      }
    }

    final cooccur = _cooccurRepo;
    if (cooccur != null) {
      final neighbors = await cooccur.getTopNeighbors(track.id, limit: 1);
      if (neighbors.isNotEmpty) {
        return 'Frequently enjoyed alongside your favorites';
      }
    }

    return 'Because you like ${track.artist}';
  }
}
