import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/interaction_events.dart';
import '../../domain/ports/i_event_logger.dart';
import '../database/app_database.dart';

class DriftEventLogger implements IEventLogger {
  final AppDatabase _db;

  DriftEventLogger({required AppDatabase db}) : _db = db;

  @override
  void logSearch({
    required String query,
    required List<String> resultIds,
    String? clickedId,
    int? clickedPosition,
    int? msToClick,
    required String rankerVersion,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = SearchEventsCompanion.insert(
      ts: now,
      query: query,
      resultIdsJson: jsonEncode(resultIds),
      shownCount: resultIds.length,
      clickedId: Value(clickedId),
      clickedPosition: Value(clickedPosition),
      msToClick: Value(msToClick),
      rankerVersion: rankerVersion,
    );

    unawaited(
      _db.into(_db.searchEvents).insert(entry).catchError((_) => 0),
    );
  }

  @override
  void logPlay({
    required String trackId,
    required String source,
    required int listenedMs,
    required int durationMs,
    required bool saved,
    required bool addedToPlaylist,
    required String rankerVersion,
    Map<String, double>? features,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final skippedEarly = listenedMs < 30000;
    final entry = PlayEventsCompanion.insert(
      ts: now,
      trackId: trackId,
      source: source,
      listenedMs: listenedMs,
      durationMs: durationMs,
      skippedEarly: skippedEarly,
      saved: saved,
      addedToPlaylist: addedToPlaylist,
      rankerVersion: rankerVersion,
      featuresJson: Value(features != null ? jsonEncode(features) : null),
    );

    unawaited(
      _db.into(_db.playEvents).insert(entry).catchError((_) => 0),
    );
  }

  @override
  void logImpression({
    required String surface,
    required String itemId,
    required int position,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = ImpressionsCompanion.insert(
      ts: now,
      surface: surface,
      itemId: itemId,
      position: position,
    );

    unawaited(
      _db.into(_db.impressions).insert(entry).catchError((_) => 0),
    );
  }

  @override
  Future<DebugMetricsSummary> getMetricsSummary() async {
    final plays = await _db.select(_db.playEvents).get();
    final searches = await _db.select(_db.searchEvents).get();

    final totalPlays = plays.length;
    final streams = plays.where((p) => p.listenedMs >= 30000).length;
    final skips = plays.where((p) => p.skippedEarly).length;

    final streamRate = totalPlays > 0 ? streams / totalPlays : 0.0;
    final earlySkipRate = totalPlays > 0 ? skips / totalPlays : 0.0;

    final clickedSearches = searches.where((s) => s.clickedId != null).toList();
    final totalClickedSearches = clickedSearches.length;
    final top1Clicks =
        clickedSearches.where((s) => s.clickedPosition == 0).length;
    final searchTop1ClickRate = totalClickedSearches > 0
        ? top1Clicks / totalClickedSearches
        : 0.0;

    final clickLatencies = clickedSearches
        .map((s) => s.msToClick)
        .whereType<int>()
        .toList()
      ..sort();

    int medianMsToClick = 0;
    if (clickLatencies.isNotEmpty) {
      final middle = clickLatencies.length ~/ 2;
      if (clickLatencies.length.isOdd) {
        medianMsToClick = clickLatencies[middle];
      } else {
        medianMsToClick =
            ((clickLatencies[middle - 1] + clickLatencies[middle]) / 2).round();
      }
    }

    return DebugMetricsSummary(
      streamRate: streamRate,
      earlySkipRate: earlySkipRate,
      searchTop1ClickRate: searchTop1ClickRate,
      medianMsToClick: medianMsToClick,
      totalPlays: totalPlays,
      totalSearches: searches.length,
    );
  }

  @override
  Future<void> clearAllLearningData() async {
    await _db.delete(_db.searchEvents).go();
    await _db.delete(_db.playEvents).go();
    await _db.delete(_db.impressions).go();
  }
}
