import '../entities/track.dart';

abstract class IFtsRepository {
  Future<List<String>> queryFts(String query);
  Future<void> indexTrack(Track track);
  Future<void> removeTrack(String trackId);
  Future<void> rebuildFullIndex();
}
