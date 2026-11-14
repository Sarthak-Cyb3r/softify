import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/animated_music_wave_indicator.dart';
import '../../../presentation/widgets/shared/app_network_image.dart';

// ============================================================================
// Model: QueueSearchMatch
// ============================================================================

/// Represents a matched track item within the queue during an in-place search filter.
///
/// Preserves the track's original [originalIndex] in the playback queue so tapping
/// on a filtered item accurately jumps directly to that queue position without
/// mutating or reordering the underlying queue.
@immutable
class QueueSearchMatch {
  final int originalIndex;
  final Track track;
  final bool isCurrent;

  const QueueSearchMatch({
    required this.originalIndex,
    required this.track,
    this.isCurrent = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueSearchMatch &&
          runtimeType == other.runtimeType &&
          originalIndex == other.originalIndex &&
          track == other.track &&
          isCurrent == other.isCurrent;

  @override
  int get hashCode => Object.hash(originalIndex, track, isCurrent);

  @override
  String toString() =>
      'QueueSearchMatch(originalIndex: $originalIndex, title: ${track.title}, artist: ${track.artist}, isCurrent: $isCurrent)';
}

// ============================================================================
// Helper / Pure Service: QueueSearchFilterHelper
// ============================================================================

/// Pure helper providing search filtering logic over playback queue tracks.
class QueueSearchFilterHelper {
  const QueueSearchFilterHelper._();

  /// Determines if [track] matches the given search [query] across title, artist,
  /// or album metadata using case-insensitive multi-token matching.
  static bool matchesTrack(Track track, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return true;

    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.isEmpty) return true;

    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();
    final album = (track.album ?? '').toLowerCase();

    // Check full query match first
    if (title.contains(trimmed) ||
        artist.contains(trimmed) ||
        album.contains(trimmed)) {
      return true;
    }

    // Split token multi-match (all tokens must match title, artist, or album)
    final combined = '$title $artist $album';
    return tokens.every((token) => combined.contains(token));
  }

  /// Filters [queue] against [query] while preserving each track's [originalIndex]
  /// and flagging the currently playing track via [currentIndex].
  ///
  /// If [query] is empty or whitespace, returns all tracks in the queue wrapped
  /// as [QueueSearchMatch] instances in original order.
  static List<QueueSearchMatch> filterQueue({
    required List<Track> queue,
    required String query,
    int? currentIndex,
  }) {
    final trimmed = query.trim();
    final matches = <QueueSearchMatch>[];

    for (int i = 0; i < queue.length; i++) {
      final track = queue[i];
      final isCurrent = (currentIndex != null && i == currentIndex);

      if (trimmed.isEmpty || matchesTrack(track, trimmed)) {
        matches.add(QueueSearchMatch(
          originalIndex: i,
          track: track,
          isCurrent: isCurrent,
        ));
      }
    }

    return matches;
  }

  /// Counts the number of tracks in [queue] that match [query].
  static int matchCount({
    required List<Track> queue,
    required String query,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return queue.length;
    return queue.where((track) => matchesTrack(track, trimmed)).length;
  }
}

// ============================================================================
// Controller: QueueSearchFilterController
// ============================================================================

/// Controller managing text editing, query state, focus, and notifications for
/// the queue search filter bar.
class QueueSearchFilterController extends ChangeNotifier {
  QueueSearchFilterController({
    String initialQuery = '',
    TextEditingController? textController,
    FocusNode? focusNode,
  })  : _query = initialQuery,
        _internalTextController = textController == null,
        _internalFocusNode = focusNode == null,
        textController =
            textController ?? TextEditingController(text: initialQuery),
        focusNode = focusNode ?? FocusNode() {
    this.textController.addListener(_onTextChanged);
  }

  final bool _internalTextController;
  final bool _internalFocusNode;
  final TextEditingController textController;
  final FocusNode focusNode;

  String _query = '';

  String get query => _query;
  bool get hasActiveFilter => _query.trim().isNotEmpty;

  void _onTextChanged() {
    final text = textController.text;
    if (_query != text) {
      _query = text;
      notifyListeners();
    }
  }

  /// Updates the query programmatically.
  void setQuery(String newQuery) {
    if (textController.text != newQuery) {
      textController.text = newQuery;
      textController.selection = TextSelection.fromPosition(
        TextPosition(offset: newQuery.length),
      );
    }
  }

  /// Clears the search field query and keeps focus active.
  void clear() {
    textController.clear();
    focusNode.requestFocus();
  }

  @override
  void dispose() {
    textController.removeListener(_onTextChanged);
    if (_internalTextController) {
      textController.dispose();
    }
    if (_internalFocusNode) {
      focusNode.dispose();
    }
    super.dispose();
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// Global search query provider for filtering queue tracks.
final queueSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provides a [QueueSearchFilterController] synchronized with Riverpod state.
final queueSearchFilterControllerProvider =
    ChangeNotifierProvider.autoDispose<QueueSearchFilterController>((ref) {
  final controller = QueueSearchFilterController();
  controller.addListener(() {
    ref.read(queueSearchQueryProvider.notifier).state = controller.query;
  });
  return controller;
});

/// Provides the active filtered queue items along with their original queue indices.
final filteredQueueProvider = Provider<List<QueueSearchMatch>>((ref) {
  final queue = ref.watch(queueProvider).value ?? const [];
  final query = ref.watch(queueSearchQueryProvider);
  final audioHandler = ref.watch(audioHandlerProvider);
  final currentIndex = audioHandler.currentIndex;

  return QueueSearchFilterHelper.filterQueue(
    queue: queue,
    query: query,
    currentIndex: currentIndex,
  );
});

// ============================================================================
// UI Widget: QueueSearchHeaderField
// ============================================================================

/// In-place search header field styled specifically for queue filtering in bottom
/// sheets and desktop queue panels.
class QueueSearchHeaderField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String hintText;
  final int? totalCount;
  final int? matchCount;
  final bool autoFocus;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const QueueSearchHeaderField({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onClear,
    this.hintText = 'Filter queue by title or artist...',
    this.totalCount,
    this.matchCount,
    this.autoFocus = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
    this.trailing,
  });

  @override
  State<QueueSearchHeaderField> createState() => _QueueSearchHeaderFieldState();
}

class _QueueSearchHeaderFieldState extends State<QueueSearchHeaderField> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _textController = widget.controller!;
    } else {
      _textController = TextEditingController();
      _ownsController = true;
    }

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    _textController.addListener(_handleTextChange);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant QueueSearchHeaderField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _textController.removeListener(_handleTextChange);
        _textController.dispose();
      }
      if (widget.controller != null) {
        _textController = widget.controller!;
        _ownsController = false;
      } else {
        _textController = TextEditingController();
        _ownsController = true;
      }
      _textController.addListener(_handleTextChange);
    }

    if (widget.focusNode != oldWidget.focusNode) {
      if (_ownsFocusNode) {
        _focusNode.removeListener(_handleFocusChange);
        _focusNode.dispose();
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _ownsFocusNode = false;
      } else {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      }
      _focusNode.addListener(_handleFocusChange);
    }
  }

  void _handleTextChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  void _clear() {
    _textController.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChange);
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsController) {
      _textController.dispose();
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasText = _textController.text.trim().isNotEmpty;

    return Padding(
      padding: widget.padding,
      child: AnimatedContainer(
        duration: tokens.motionQuick,
        height: 42,
        decoration: BoxDecoration(
          color: tokens.surfaceHighlight.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          border: Border.all(
            color: _isFocused
                ? tokens.accent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: _isFocused ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(
              Icons.search_rounded,
              size: 18,
              color: _isFocused ? tokens.accent : tokens.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                autofocus: widget.autoFocus,
                onChanged: widget.onChanged,
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: tokens.textMuted.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (hasText && widget.matchCount != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  border: Border.all(
                    color: tokens.accent.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  widget.totalCount != null
                      ? '${widget.matchCount} / ${widget.totalCount}'
                      : '${widget.matchCount} found',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.accent,
                  ),
                ),
              ),
            ],
            if (hasText)
              Tooltip(
                message: 'Clear search',
                child: InkWell(
                  onTap: _clear,
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: tokens.textMuted,
                    ),
                  ),
                ),
              ),
            if (widget.trailing != null) widget.trailing!,
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UI Widget: QueueFilteredTrackTile
// ============================================================================

/// Reusable track tile for displaying a filtered queue item.
///
/// Tapping the tile jumps directly to [match.originalIndex] in the playback queue.
class QueueFilteredTrackTile extends ConsumerWidget {
  final QueueSearchMatch match;
  final VoidCallback? onTap;

  const QueueFilteredTrackTile({
    super.key,
    required this.match,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final track = match.track;
    final isCurrent = match.isCurrent;
    final audioHandler = ref.watch(audioHandlerProvider);

    return Material(
      color: isCurrent
          ? tokens.surfaceHighlight.withValues(alpha: 0.45)
          : Colors.transparent,
      child: ListTile(
        onTap: () {
          if (onTap != null) {
            onTap!();
          } else {
            audioHandler.skipToQueueItem(match.originalIndex);
          }
        },
        leading: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              child: AppNetworkImage(
                imageUrl: track.coverUrl,
                width: 40,
                height: 40,
                cacheWidth: 120,
                cacheHeight: 120,
                fit: BoxFit.cover,
                placeholderIcon: Icons.music_note_rounded,
              ),
            ),
            if (isCurrent)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
                child: Center(
                  child: AnimatedMusicWaveIndicator(
                    isPlaying: ref.watch(isPlayingProvider),
                    color: tokens.accent,
                    size: 18,
                    barCount: 3,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? tokens.accent : tokens.textPrimary,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: tokens.surfaceHighlight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#${match.originalIndex + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.remove_circle_outline_rounded,
            color: tokens.textMuted,
            size: 18,
          ),
          tooltip: 'Remove from queue',
          onPressed: () {
            audioHandler.removeQueueItemAt(match.originalIndex);
          },
        ),
      ),
    );
  }
}
