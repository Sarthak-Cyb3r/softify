abstract class IAutocompleteRepository {
  /// Returns prioritized autocomplete query suggestions for the given prefix.
  Future<List<String>> getSuggestions(String prefix);

  /// Records downstream success (stream >=30s or save) for a query, incrementing its success weight.
  Future<void> recordSuccessfulQuery(String query);
}
