abstract class IColdStartSeeder {
  /// Seeds initial user taste profile and recommendations from onboarding artist choices.
  Future<void> seedFromInitialArtists(List<String> artistIds);

  /// Seeds user taste profile from imported Spotify playlist tracks.
  Future<void> seedFromSpotifyImport(String playlistId);
}
