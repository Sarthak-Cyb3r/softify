import 'dart:io';

import '../../data/lyrics/kugou_lyrics_provider.dart';
import '../../data/lyrics/lrclib_lyrics_provider.dart';
import '../../data/lyrics/spotify_lyrics_provider.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'better_lyrics_provider.dart';
import 'paxsenix_lyrics_provider.dart';
import 'zemer_lyrics_provider.dart';

/// Multi-provider fallback registry for synchronized and syllable-accurate lyrics.
/// Inspired by Metrolist's lyrics registry, with runtime configurable priority
/// ordering across BetterLyrics, LrcLib, KuGou, Paxsenix, Zemer, and Spotify.
class LyricsProviderRegistry implements ILyricsProvider {
  static const List<String> defaultPriorityOrder = [
    'BetterLyrics',
    'LrcLib',
    'KuGou',
    'Paxsenix',
    'Zemer',
    'Spotify',
  ];

  final Map<String, ILyricsProvider> _providers = {};
  final Map<String, bool> _enabledState = {};
  List<String> _priorityOrder = List.from(defaultPriorityOrder);
  final Map<String, SyncedLyrics?> _cache = {};

  LyricsProviderRegistry({
    HttpClient? httpClient,
    ILyricsProvider? betterLyrics,
    ILyricsProvider? lrclib,
    ILyricsProvider? kugou,
    ILyricsProvider? paxsenix,
    ILyricsProvider? zemer,
    ILyricsProvider? spotify,
    List<String>? initialPriorityOrder,
  }) {
    // Register standard providers
    registerProvider(
      'BetterLyrics',
      betterLyrics ?? BetterLyricsProvider(httpClient: httpClient),
    );
    registerProvider(
      'LrcLib',
      lrclib ?? LrclibLyricsProvider(httpClient: httpClient),
    );
    registerProvider(
      'KuGou',
      kugou ?? KugouLyricsProvider(httpClient: httpClient),
    );
    registerProvider(
      'Paxsenix',
      paxsenix ?? PaxsenixLyricsProvider(httpClient: httpClient),
    );
    registerProvider(
      'Zemer',
      zemer ?? ZemerLyricsProvider(httpClient: httpClient),
    );
    registerProvider(
      'Spotify',
      spotify ?? SpotifyLyricsProvider(httpClient: httpClient),
    );

    if (initialPriorityOrder != null) {
      setPriorityOrder(initialPriorityOrder);
    }
  }

  /// All registered provider names.
  List<String> get registeredNames => _providers.keys.toList();

  /// Currently configured priority order.
  List<String> get priorityOrder => List.unmodifiable(_priorityOrder);

  /// Registers a provider with the given identifier.
  void registerProvider(
    String name,
    ILyricsProvider provider, {
    bool enabled = true,
  }) {
    _providers[name] = provider;
    _enabledState[name] = enabled;
    if (!_priorityOrder.contains(name)) {
      _priorityOrder.add(name);
    }
  }

  /// Unregisters a provider.
  void unregisterProvider(String name) {
    _providers.remove(name);
    _enabledState.remove(name);
    _priorityOrder.remove(name);
  }

  /// Retrieves a provider instance by name.
  ILyricsProvider? getProvider(String name) => _providers[name];

  /// Checks if a provider is enabled.
  bool isProviderEnabled(String name) => _enabledState[name] ?? false;

  /// Enables or disables a provider.
  void setProviderEnabled(String name, bool enabled) {
    if (_providers.containsKey(name)) {
      _enabledState[name] = enabled;
    }
  }

  /// Sets the active priority order.
  void setPriorityOrder(List<String> order) {
    final valid = order.where((p) => _providers.containsKey(p)).toList();
    final remaining = _priorityOrder.where((p) => !valid.contains(p));
    _priorityOrder = [...valid, ...remaining];
  }

  /// Deserializes a comma-separated priority order string (e.g. "BetterLyrics,LrcLib,KuGou,Spotify").
  List<String> deserializeProviderOrder(String orderString) {
    if (orderString.trim().isEmpty) {
      return List.from(defaultPriorityOrder);
    }
    final saved = orderString
        .split(',')
        .map((s) => s.trim())
        .where((s) => _providers.containsKey(s))
        .toList();
    final defaults = defaultPriorityOrder.where((p) => !saved.contains(p));
    return [...saved, ...defaults];
  }

  /// Serializes the priority order into a comma-separated string.
  String serializeProviderOrder([List<String>? order]) {
    final list = order ?? _priorityOrder;
    return list.where((p) => _providers.containsKey(p)).join(',');
  }

  /// Returns the active providers in configured order.
  List<ILyricsProvider> getOrderedProviders({String? orderString}) {
    final order = orderString != null
        ? deserializeProviderOrder(orderString)
        : _priorityOrder;

    return order
        .where((name) => isProviderEnabled(name))
        .map((name) => _providers[name])
        .whereType<ILyricsProvider>()
        .toList();
  }

  @override
  Future<SyncedLyrics?> getLyrics(
    Track track, {
    bool preferSyllableSynced = true,
  }) async {
    if (_cache.containsKey(track.id)) {
      return _cache[track.id];
    }

    final ordered = getOrderedProviders();
    SyncedLyrics? fallbackCandidate;

    for (final provider in ordered) {
      try {
        final result = await provider.getLyrics(track);
        if (result != null) {
          // If the provider returned syllable-level karaoke timings, return immediately
          if (result.isSyllableSynced) {
            _cache[track.id] = result;
            return result;
          }

          // If line synced, save or return if not explicitly waiting for syllable
          if (result.isSynced) {
            if (!preferSyllableSynced) {
              _cache[track.id] = result;
              return result;
            }
            fallbackCandidate ??= result;
          } else {
            // Keep plain lyrics candidate as last-resort fallback
            fallbackCandidate ??= result;
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (fallbackCandidate != null) {
      _cache[track.id] = fallbackCandidate;
      return fallbackCandidate;
    }

    _cache[track.id] = null;
    return null;
  }

  void clearCache() => _cache.clear();
}
