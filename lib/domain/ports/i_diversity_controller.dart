import '../entities/track.dart';

abstract class IDiversityController {
  /// Maximal Marginal Relevance (MMR) re-ranking with a hard per-artist cap.
  /// Formulated as: Argmax [ lambda * Relevance(d) - (1 - lambda) * max_{s in S} Sim(d, s) ]
  /// Hard invariant: At most [maxPerArtist] tracks from the same artist in the returned list.
  List<Track> applyMmr(
    List<Track> ranked, {
    int maxPerArtist = 2,
    double lambda = 0.7,
  });

  /// Snoozes an artist for the specified duration (e.g. 30 days).
  /// Hard invariant: Snoozed artists are completely excluded from recommendations and suggestions.
  Future<void> snoozeArtist(String artistId, Duration duration);

  /// Checks if an artist is currently actively snoozed.
  Future<bool> isSnoozed(String artistId);

  /// Returns the list of currently active snoozed artist IDs.
  Future<List<String>> getSnoozedArtists();

  /// Removes an active snooze on an artist immediately.
  Future<void> removeSnooze(String artistId);

  /// Wipes all on-device learning data (taste profiles, co-occurrences, bandit states, completion queries).
  Future<void> resetAllLearning();

  /// Pauses or resumes taste profile updating.
  Future<void> setLearningPaused(bool paused);

  /// Checks if learning is currently paused by the user.
  Future<bool> isLearningPaused();
}
