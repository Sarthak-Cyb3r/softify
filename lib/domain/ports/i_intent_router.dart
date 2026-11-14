import '../entities/search_intent.dart';

abstract class IIntentRouter {
  /// Resolves a user query into a structured SearchIntent.
  SearchIntent resolve(String query);
}
