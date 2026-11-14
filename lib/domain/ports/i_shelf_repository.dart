import '../entities/shelf.dart';

abstract class IShelfRepository {
  /// Loads personalized algotorial home shelves.
  Future<List<Shelf>> loadShelves({bool forceRefresh = false});
}
