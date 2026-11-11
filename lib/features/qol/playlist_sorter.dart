import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/track.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';

/// Supported criteria for sorting tracks within a playlist.
enum PlaylistSortCriteria {
  customOrder,
  titleAsc,
  titleDesc,
  artistAsc,
  durationAsc,
  durationDesc,
  dateAdded;

  String get label => switch (this) {
        PlaylistSortCriteria.customOrder => 'Custom Order',
        PlaylistSortCriteria.titleAsc => 'Title (A-Z)',
        PlaylistSortCriteria.titleDesc => 'Title (Z-A)',
        PlaylistSortCriteria.artistAsc => 'Artist (A-Z)',
        PlaylistSortCriteria.durationAsc => 'Duration (Shortest)',
        PlaylistSortCriteria.durationDesc => 'Duration (Longest)',
        PlaylistSortCriteria.dateAdded => 'Recently Added',
      };

  String get description => switch (this) {
        PlaylistSortCriteria.customOrder => 'Original playlist sequence',
        PlaylistSortCriteria.titleAsc => 'Alphabetical from A to Z',
        PlaylistSortCriteria.titleDesc => 'Alphabetical from Z to A',
        PlaylistSortCriteria.artistAsc => 'Artist name from A to Z',
        PlaylistSortCriteria.durationAsc => 'Shortest duration first',
        PlaylistSortCriteria.durationDesc => 'Longest duration first',
        PlaylistSortCriteria.dateAdded => 'Most recently added first',
      };

  IconData get icon => switch (this) {
        PlaylistSortCriteria.customOrder => Icons.reorder_rounded,
        PlaylistSortCriteria.titleAsc => Icons.arrow_upward_rounded,
        PlaylistSortCriteria.titleDesc => Icons.arrow_downward_rounded,
        PlaylistSortCriteria.artistAsc => Icons.person_rounded,
        PlaylistSortCriteria.durationAsc => Icons.timelapse_rounded,
        PlaylistSortCriteria.durationDesc => Icons.timer_rounded,
        PlaylistSortCriteria.dateAdded => Icons.calendar_today_rounded,
      };

  static PlaylistSortCriteria fromString(String? value) {
    if (value == null) return PlaylistSortCriteria.customOrder;
    for (final criteria in PlaylistSortCriteria.values) {
      if (criteria.name == value) {
        return criteria;
      }
    }
    return PlaylistSortCriteria.customOrder;
  }
}

/// In-memory local state store for fast synchronous access and persistence across screens.
final Map<String, PlaylistSortCriteria> _inMemorySortStore = {};

/// State notifier managing the selected sort criteria for a playlist,
/// persisting changes into local state and SQLite settings.
class PlaylistSortNotifier extends StateNotifier<PlaylistSortCriteria> {
  final Ref _ref;
  final String playlistId;

  PlaylistSortNotifier(this._ref, this.playlistId)
      : super(_inMemorySortStore[playlistId] ?? PlaylistSortCriteria.customOrder) {
    _loadPersistedSort();
  }

  Future<void> _loadPersistedSort() async {
    try {
      final dynamic db = _ref.read(databaseProvider);
      final key = 'playlist_sort_$playlistId';
      final query = db.select(db.settings)..where((t) => (t as dynamic).key.equals(key));
      final row = await query.getSingleOrNull();
      if (row != null && mounted) {
        final loaded = PlaylistSortCriteria.fromString(row.value as String?);
        _inMemorySortStore[playlistId] = loaded;
        state = loaded;
      }
    } catch (_) {
      // Graceful local state fallback
    }
  }

  Future<void> setCriteria(PlaylistSortCriteria criteria) async {
    state = criteria;
    _inMemorySortStore[playlistId] = criteria;
    try {
      final dynamic db = _ref.read(databaseProvider);
      final key = 'playlist_sort_$playlistId';
      await db.into(db.settings).insertOnConflictUpdate(
            SettingRow(
              key: key,
              value: criteria.name,
            ),
          );
    } catch (_) {
      // Graceful local state fallback
    }
  }

  Future<void> reset() async {
    await setCriteria(PlaylistSortCriteria.customOrder);
  }
}

/// Riverpod family provider for managing sort criteria per playlist id.
final playlistSortProvider =
    StateNotifierProvider.family<PlaylistSortNotifier, PlaylistSortCriteria, String>(
  (ref, playlistId) => PlaylistSortNotifier(ref, playlistId),
);

/// Sorts a playlist of items of type [T] according to [criteria].
///
/// Uses [trackExtractor] to retrieve the domain [Track] from each item.
/// If sorting by [PlaylistSortCriteria.dateAdded], an optional [dateExtractor]
/// can be provided; otherwise, it treats later entries as newer and reverses them.
List<T> sortPlaylistTracks<T>(
  List<T> tracks,
  PlaylistSortCriteria criteria, {
  required Track Function(T) trackExtractor,
  DateTime? Function(T)? dateExtractor,
}) {
  if (tracks.isEmpty || tracks.length == 1) {
    return List<T>.from(tracks);
  }

  final result = List<T>.from(tracks);

  switch (criteria) {
    case PlaylistSortCriteria.customOrder:
      return result;

    case PlaylistSortCriteria.titleAsc:
      result.sort((a, b) {
        final tA = trackExtractor(a);
        final tB = trackExtractor(b);
        final cmp = tA.title.toLowerCase().compareTo(tB.title.toLowerCase());
        if (cmp != 0) return cmp;
        return tA.artist.toLowerCase().compareTo(tB.artist.toLowerCase());
      });
      return result;

    case PlaylistSortCriteria.titleDesc:
      result.sort((a, b) {
        final tA = trackExtractor(a);
        final tB = trackExtractor(b);
        final cmp = tB.title.toLowerCase().compareTo(tA.title.toLowerCase());
        if (cmp != 0) return cmp;
        return tA.artist.toLowerCase().compareTo(tB.artist.toLowerCase());
      });
      return result;

    case PlaylistSortCriteria.artistAsc:
      result.sort((a, b) {
        final tA = trackExtractor(a);
        final tB = trackExtractor(b);
        final cmp = tA.artist.toLowerCase().compareTo(tB.artist.toLowerCase());
        if (cmp != 0) return cmp;
        return tA.title.toLowerCase().compareTo(tB.title.toLowerCase());
      });
      return result;

    case PlaylistSortCriteria.durationAsc:
      result.sort((a, b) {
        final tA = trackExtractor(a);
        final tB = trackExtractor(b);
        final cmp = tA.duration.compareTo(tB.duration);
        if (cmp != 0) return cmp;
        return tA.title.toLowerCase().compareTo(tB.title.toLowerCase());
      });
      return result;

    case PlaylistSortCriteria.durationDesc:
      result.sort((a, b) {
        final tA = trackExtractor(a);
        final tB = trackExtractor(b);
        final cmp = tB.duration.compareTo(tA.duration);
        if (cmp != 0) return cmp;
        return tA.title.toLowerCase().compareTo(tB.title.toLowerCase());
      });
      return result;

    case PlaylistSortCriteria.dateAdded:
      if (dateExtractor != null) {
        result.sort((a, b) {
          final dA = dateExtractor(a);
          final dB = dateExtractor(b);
          if (dA == null && dB == null) return 0;
          if (dA == null) return 1;
          if (dB == null) return -1;
          return dB.compareTo(dA); // Newest first
        });
        return result;
      }
      return result.reversed.toList();
  }
}

/// Extension on [List] for cleaner chaining when sorting tracks.
extension PlaylistTrackSortExtension<T> on List<T> {
  List<T> sortedBy(
    PlaylistSortCriteria criteria, {
    required Track Function(T) trackExtractor,
    DateTime? Function(T)? dateExtractor,
  }) {
    return sortPlaylistTracks(
      this,
      criteria,
      trackExtractor: trackExtractor,
      dateExtractor: dateExtractor,
    );
  }
}

/// Bottom sheet widget allowing the user to select playlist sort criteria.
class PlaylistSortSheet extends ConsumerStatefulWidget {
  final String? playlistId;
  final PlaylistSortCriteria? initialCriteria;
  final ValueChanged<PlaylistSortCriteria>? onCriteriaSelected;
  final String? title;

  const PlaylistSortSheet({
    super.key,
    this.playlistId,
    this.initialCriteria,
    this.onCriteriaSelected,
    this.title,
  });

  /// Displays the [PlaylistSortSheet] as a modal bottom sheet.
  static Future<PlaylistSortCriteria?> show(
    BuildContext context, {
    String? playlistId,
    PlaylistSortCriteria? currentCriteria,
    ValueChanged<PlaylistSortCriteria>? onSelected,
    String? title,
  }) {
    return showModalBottomSheet<PlaylistSortCriteria>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PlaylistSortSheet(
        playlistId: playlistId,
        initialCriteria: currentCriteria,
        onCriteriaSelected: onSelected,
        title: title,
      ),
    );
  }

  @override
  ConsumerState<PlaylistSortSheet> createState() => _PlaylistSortSheetState();
}

class _PlaylistSortSheetState extends ConsumerState<PlaylistSortSheet> {
  late PlaylistSortCriteria _localSelected;

  @override
  void initState() {
    super.initState();
    _localSelected = widget.initialCriteria ??
        (widget.playlistId != null
            ? _inMemorySortStore[widget.playlistId!] ?? PlaylistSortCriteria.customOrder
            : PlaylistSortCriteria.customOrder);
  }

  void _onSelect(PlaylistSortCriteria criteria) {
    setState(() => _localSelected = criteria);
    HapticFeedback.selectionClick();

    if (widget.playlistId != null) {
      ref.read(playlistSortProvider(widget.playlistId!).notifier).setCriteria(criteria);
    }

    widget.onCriteriaSelected?.call(criteria);
    Navigator.of(context).pop(criteria);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeCriteria = widget.playlistId != null
        ? ref.watch(playlistSortProvider(widget.playlistId!))
        : _localSelected;

    return Material(
      color: tokens.surfaceElevated,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 2. Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.sort_rounded,
                      color: tokens.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title ?? 'Sort Playlist',
                          style: TextStyle(
                            fontFamily: AppTheme.fontDisplay,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose how tracks are ordered',
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: tokens.divider, height: 1),

            // 3. Criteria Radio Options
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: PlaylistSortCriteria.values.map((criteria) {
                    final isSelected = activeCriteria == criteria;
                    return _SortRadioTile(
                      criteria: criteria,
                      isSelected: isSelected,
                      tokens: tokens,
                      onTap: () => _onSelect(criteria),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SortRadioTile extends StatelessWidget {
  final PlaylistSortCriteria criteria;
  final bool isSelected;
  final AppTokens tokens;
  final VoidCallback onTap;

  const _SortRadioTile({
    required this.criteria,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: isSelected ? tokens.accent.withValues(alpha: 0.08) : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isSelected
                    ? tokens.accent.withValues(alpha: 0.2)
                    : tokens.surfaceHighlight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                criteria.icon,
                size: 18,
                color: isSelected ? tokens.accent : tokens.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    criteria.label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    criteria.description,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Radio<PlaylistSortCriteria>(
              value: criteria,
              groupValue: isSelected ? criteria : null,
              onChanged: (_) => onTap(),
              activeColor: tokens.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
