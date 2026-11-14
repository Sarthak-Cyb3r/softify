import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/search/multi_source_autocomplete.dart';
import '../../data/search/rule_intent_router.dart';
import '../../domain/ports/i_autocomplete_repository.dart';
import '../../domain/ports/i_intent_router.dart';
import 'diversity_providers.dart';
import 'player_providers.dart';

final autocompleteRepositoryProvider = Provider<IAutocompleteRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final remoteConfig = ref.watch(remoteConfigProvider);
  final diversityController = ref.watch(diversityControllerProvider);
  final spotifyApi = ref.watch(spotifyApiServiceProvider);
  return MultiSourceAutocomplete(
    db: db,
    remoteConfig: remoteConfig,
    diversityController: diversityController,
    spotifyApi: spotifyApi,
  );
});

final intentRouterProvider = Provider<IIntentRouter>((ref) {
  final remoteConfig = ref.watch(remoteConfigProvider);
  return RuleIntentRouter(remoteConfig: remoteConfig);
});

final autocompleteSuggestionsProvider =
    FutureProvider.family<List<String>, String>((ref, prefix) async {
  if (prefix.trim().isEmpty) return const [];
  final repo = ref.watch(autocompleteRepositoryProvider);
  return repo.getSuggestions(prefix);
});
