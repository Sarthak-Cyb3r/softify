import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/playlist.dart';
import '../../../domain/entities/track.dart';
import '../../../domain/ports/i_library_repository.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';
import '../../../presentation/widgets/shared/app_dialog.dart';
import '../../../presentation/widgets/shared/app_pill_button.dart';
import '../../../presentation/widgets/shared/app_surface.dart';
import '../../../presentation/widgets/shared/app_toast.dart';

// ============================================================================
// Enums & Models
// ============================================================================

/// Determines which portion of the playback queue is saved to the new playlist.
enum QueueSaveScope {
  /// Save all tracks currently in the playback queue.
  all('Entire Queue', 'All tracks in queue'),

  /// Save only pending tracks positioned after the currently playing song.
  upcoming('Upcoming Only', 'Songs scheduled after current track'),

  /// Save from the currently playing song through the rest of the queue.
  currentAndUpcoming('Current & Upcoming', 'Current song and pending tracks');

  final String label;
  final String description;
  const QueueSaveScope(this.label, this.description);
}

/// Validation result with human-readable error descriptions.
@immutable
class SaveQueueValidationResult {
  final bool isValid;
  final String? errorMessage;

  const SaveQueueValidationResult._({
    required this.isValid,
    this.errorMessage,
  });

  factory SaveQueueValidationResult.valid() =>
      const SaveQueueValidationResult._(isValid: true);

  factory SaveQueueValidationResult.invalid(String error) =>
      SaveQueueValidationResult._(isValid: false, errorMessage: error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveQueueValidationResult &&
          isValid == other.isValid &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(isValid, errorMessage);

  @override
  String toString() => isValid
      ? 'SaveQueueValidationResult.valid()'
      : 'SaveQueueValidationResult.invalid("$errorMessage")';
}

/// Result returned after converting a queue into a playlist.
@immutable
class SaveQueueResult {
  final bool success;
  final Playlist? playlist;
  final int trackCount;
  final String? errorMessage;

  const SaveQueueResult._({
    required this.success,
    this.playlist,
    this.trackCount = 0,
    this.errorMessage,
  });

  factory SaveQueueResult.success({
    required Playlist playlist,
    required int trackCount,
  }) =>
      SaveQueueResult._(
        success: true,
        playlist: playlist,
        trackCount: trackCount,
      );

  factory SaveQueueResult.failure(String errorMessage) =>
      SaveQueueResult._(
        success: false,
        errorMessage: errorMessage,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveQueueResult &&
          success == other.success &&
          playlist?.id == other.playlist?.id &&
          trackCount == other.trackCount &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(success, playlist?.id, trackCount, errorMessage);

  @override
  String toString() => success
      ? 'SaveQueueResult.success(playlist: "${playlist?.name}", tracks: $trackCount)'
      : 'SaveQueueResult.failure("$errorMessage")';
}

// ============================================================================
// Pure Logic & Naming Helpers
// ============================================================================

/// Pure helper functions for naming, queue extraction, formatting, and validation.
class SaveQueueHelper {
  const SaveQueueHelper._();

  /// Maximum allowed length for playlist names.
  static const int maxPlaylistNameLength = 100;

  /// Default 3-letter month abbreviations used for auto-naming.
  static const List<String> monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Generates a standardized auto-name: "Queue Mix - [Date]".
  ///
  /// Examples:
  /// - `Queue Mix - Nov 12, 2026`
  /// - If [date] is omitted, [DateTime.now()] is used.
  static String generateDefaultName([DateTime? date]) {
    final d = date ?? DateTime.now();
    final month = (d.month >= 1 && d.month <= 12)
        ? monthNames[d.month - 1]
        : 'Mix';
    return 'Queue Mix - $month ${d.day}, ${d.year}';
  }

  /// Generates an ISO-date based name: "Queue Mix - YYYY-MM-DD".
  static String generateIsoName([DateTime? date]) {
    final d = date ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'Queue Mix - $y-$m-$day';
  }

  /// Validates a candidate playlist title.
  static SaveQueueValidationResult validateName(
    String? name, {
    int maxLength = maxPlaylistNameLength,
  }) {
    if (name == null || name.trim().isEmpty) {
      return SaveQueueValidationResult.invalid('Playlist name cannot be empty');
    }
    final trimmed = name.trim();
    if (trimmed.length > maxLength) {
      return SaveQueueValidationResult.invalid(
        'Playlist name must be $maxLength characters or fewer (currently ${trimmed.length})',
      );
    }
    return SaveQueueValidationResult.valid();
  }

  /// Validates that track list is not empty.
  static SaveQueueValidationResult validateQueue(List<Track>? tracks) {
    if (tracks == null || tracks.isEmpty) {
      return SaveQueueValidationResult.invalid(
        'Cannot save an empty queue as a playlist. Add songs first.',
      );
    }
    return SaveQueueValidationResult.valid();
  }

  /// Filters [queue] according to the selected [QueueSaveScope] and [currentIndex].
  static List<Track> filterTracksByScope({
    required List<Track> queue,
    int currentIndex = -1,
    QueueSaveScope scope = QueueSaveScope.all,
  }) {
    if (queue.isEmpty) return const [];

    switch (scope) {
      case QueueSaveScope.all:
        return List<Track>.from(queue);

      case QueueSaveScope.upcoming:
        if (currentIndex >= 0 && currentIndex < queue.length - 1) {
          return queue.sublist(currentIndex + 1);
        } else if (currentIndex < 0) {
          // No track is playing; everything in the queue is upcoming
          return List<Track>.from(queue);
        }
        return const [];

      case QueueSaveScope.currentAndUpcoming:
        if (currentIndex >= 0 && currentIndex < queue.length) {
          return queue.sublist(currentIndex);
        }
        return List<Track>.from(queue);
    }
  }

  /// Computes cumulative playback duration of [tracks].
  static Duration calculateTotalDuration(List<Track> tracks) {
    return tracks.fold<Duration>(
      Duration.zero,
      (total, track) => total + track.duration,
    );
  }

  /// Formats [duration] into a human-friendly string (e.g. "45 sec", "34 min", "1 hr 12 min").
  static String formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return '0 sec';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return minutes > 0 ? '$hours hr $minutes min' : '$hours hr';
    }
    if (minutes > 0) {
      return seconds > 0 ? '$minutes min $seconds sec' : '$minutes min';
    }
    return '$seconds sec';
  }

  /// Formats track count with correct singular/plural grammar.
  static String formatTrackCount(int count) {
    return count == 1 ? '1 track' : '$count tracks';
  }
}

// ============================================================================
// Controller
// ============================================================================

/// Controller responsible for validating inputs, querying repository, and
/// persisting the queue tracks into a new database playlist.
class SaveQueueAsPlaylistController {
  const SaveQueueAsPlaylistController();

  /// Saves [tracks] into a new custom playlist named [name] using [repository].
  ///
  /// Returns a [SaveQueueResult] indicating success or failure with error details.
  static Future<SaveQueueResult> saveQueueToPlaylist({
    required ILibraryRepository repository,
    required List<Track> tracks,
    required String name,
    String? description,
    bool isImported = false,
  }) async {
    // 1. Validate inputs
    final nameValidation = SaveQueueHelper.validateName(name);
    if (!nameValidation.isValid) {
      return SaveQueueResult.failure(nameValidation.errorMessage!);
    }

    final queueValidation = SaveQueueHelper.validateQueue(tracks);
    if (!queueValidation.isValid) {
      return SaveQueueResult.failure(queueValidation.errorMessage!);
    }

    final cleanName = name.trim();
    final defaultDesc = description ??
        'Created from current play queue (${SaveQueueHelper.formatTrackCount(tracks.length)}).';

    try {
      // 2. Create playlist entity in Softify database
      final playlist = await repository.createPlaylist(
        cleanName,
        description: defaultDesc,
        isImported: isImported,
      );

      // 3. Attach track metadata entries to the playlist
      final metadata = tracks
          .map((t) => (title: t.title, artist: t.artist))
          .toList(growable: false);

      await repository.addTracksToPlaylist(
        playlist.id,
        tracks,
        originalMetadata: metadata,
      );

      final updatedPlaylist = playlist.copyWith(trackCount: tracks.length);
      return SaveQueueResult.success(
        playlist: updatedPlaylist,
        trackCount: tracks.length,
      );
    } catch (error) {
      return SaveQueueResult.failure(
        'Failed to save playlist "$cleanName": $error',
      );
    }
  }

  /// Convenience wrapper to save the currently playing queue directly using Riverpod [ref].
  static Future<SaveQueueResult> saveFromRef(
    WidgetRef ref, {
    required String name,
    String? description,
    QueueSaveScope scope = QueueSaveScope.all,
  }) async {
    final audioHandler = ref.read(audioHandlerProvider);
    final repository = ref.read(libraryRepositoryProvider);

    final queue = audioHandler.currentQueue.isNotEmpty
        ? audioHandler.currentQueue
        : (ref.read(queueProvider).value ?? const <Track>[]);

    final currentIndex = audioHandler.currentIndex;
    final resolvedTracks = SaveQueueHelper.filterTracksByScope(
      queue: queue,
      currentIndex: currentIndex,
      scope: scope,
    );

    return saveQueueToPlaylist(
      repository: repository,
      tracks: resolvedTracks,
      name: name,
      description: description,
    );
  }

  /// Instance method wrapper for testing or object-oriented usage.
  Future<SaveQueueResult> save({
    required ILibraryRepository repository,
    required List<Track> tracks,
    required String name,
    String? description,
    bool isImported = false,
  }) {
    return saveQueueToPlaylist(
      repository: repository,
      tracks: tracks,
      name: name,
      description: description,
      isImported: isImported,
    );
  }
}

/// Riverpod provider exposing [SaveQueueAsPlaylistController].
final saveQueueControllerProvider =
    Provider<SaveQueueAsPlaylistController>((ref) {
  return const SaveQueueAsPlaylistController();
});

// ============================================================================
// UI: SaveQueueDialog
// ============================================================================

/// Modal dialog allowing the user to convert their active play queue into a
/// permanent, named custom playlist.
///
/// Features:
/// - Auto-generated playlist name ("Queue Mix - [Date]")
/// - Real-time validation feedback (empty check, length limits)
/// - Track count badge with cumulative duration indicator
/// - Scope selector (Entire Queue vs Upcoming) when applicable
/// - Track list preview with expandable details
/// - Fluid Material 3 & Softify dark glass aesthetics
class SaveQueueDialog extends ConsumerStatefulWidget {
  /// Explicit tracks to save; if null, fetches queue from Riverpod state.
  final List<Track>? initialTracks;

  /// Current playing track index; if null, fetches from audio handler.
  final int? currentIndex;

  /// Initial prefilled title; if null, uses [SaveQueueHelper.generateDefaultName()].
  final String? initialName;

  /// Optional repository override for tests or decoupled invocation.
  final ILibraryRepository? repository;

  /// Default scope selection (defaults to [QueueSaveScope.all]).
  final QueueSaveScope defaultScope;

  /// Optional callback invoked upon successful playlist creation.
  final ValueChanged<Playlist>? onSaved;

  const SaveQueueDialog({
    super.key,
    this.initialTracks,
    this.currentIndex,
    this.initialName,
    this.repository,
    this.defaultScope = QueueSaveScope.all,
    this.onSaved,
  });

  /// Displays the [SaveQueueDialog] as a modal dialog and returns the created [Playlist],
  /// or null if dismissed without saving.
  static Future<Playlist?> show(
    BuildContext context, {
    List<Track>? tracks,
    int? currentIndex,
    String? initialName,
    ILibraryRepository? repository,
    QueueSaveScope defaultScope = QueueSaveScope.all,
  }) {
    return showDialog<Playlist>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => SaveQueueDialog(
        initialTracks: tracks,
        currentIndex: currentIndex,
        initialName: initialName,
        repository: repository,
        defaultScope: defaultScope,
      ),
    );
  }

  @override
  ConsumerState<SaveQueueDialog> createState() => _SaveQueueDialogState();
}

class _SaveQueueDialogState extends ConsumerState<SaveQueueDialog> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  late QueueSaveScope _selectedScope;

  bool _isSubmitting = false;
  String? _validationError;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    final defaultTitle =
        widget.initialName ?? SaveQueueHelper.generateDefaultName();
    _nameController = TextEditingController(text: defaultTitle);
    _nameFocusNode = FocusNode();
    _selectedScope = widget.defaultScope;

    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final validation = SaveQueueHelper.validateName(_nameController.text);
    setState(() {
      _validationError = validation.isValid ? null : validation.errorMessage;
      _submissionError = null;
    });
  }

  List<Track> _getRawQueue() {
    if (widget.initialTracks != null) {
      return widget.initialTracks!;
    }
    final handler = ref.read(audioHandlerProvider);
    if (handler.currentQueue.isNotEmpty) {
      return handler.currentQueue;
    }
    final asyncQueue = ref.read(queueProvider).value;
    return asyncQueue ?? const <Track>[];
  }

  int _getCurrentIndex() {
    if (widget.currentIndex != null) {
      return widget.currentIndex!;
    }
    try {
      final handler = ref.read(audioHandlerProvider);
      return handler.currentIndex;
    } catch (_) {
      return -1;
    }
  }

  ILibraryRepository _resolveRepository() {
    if (widget.repository != null) {
      return widget.repository!;
    }
    return ref.read(libraryRepositoryProvider);
  }

  List<Track> _getFilteredTracks(List<Track> rawQueue, int currentIndex) {
    return SaveQueueHelper.filterTracksByScope(
      queue: rawQueue,
      currentIndex: currentIndex,
      scope: _selectedScope,
    );
  }

  void _resetToDefaultName() {
    final freshName = SaveQueueHelper.generateDefaultName();
    _nameController.text = freshName;
    _nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: freshName.length,
    );
  }

  Future<void> _handleSave() async {
    final validation = SaveQueueHelper.validateName(_nameController.text);
    if (!validation.isValid) {
      setState(() {
        _validationError = validation.errorMessage;
      });
      return;
    }

    final rawQueue = _getRawQueue();
    final currentIndex = _getCurrentIndex();
    final tracksToSave = _getFilteredTracks(rawQueue, currentIndex);

    final queueValidation = SaveQueueHelper.validateQueue(tracksToSave);
    if (!queueValidation.isValid) {
      setState(() {
        _submissionError = queueValidation.errorMessage;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    final repo = _resolveRepository();
    final result = await SaveQueueAsPlaylistController.saveQueueToPlaylist(
      repository: repo,
      tracks: tracksToSave,
      name: _nameController.text,
    );

    if (!mounted) return;

    if (result.success && result.playlist != null) {
      widget.onSaved?.call(result.playlist!);
      Navigator.of(context).pop(result.playlist);

      AppToast.show(
        context,
        message: 'Saved "${result.playlist!.name}" (${result.trackCount} tracks)',
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Colors.greenAccent,
          size: 18,
        ),
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _submissionError = result.errorMessage ?? 'Could not create playlist';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final rawQueue = _getRawQueue();
    final currentIndex = _getCurrentIndex();
    final filteredTracks = _getFilteredTracks(rawQueue, currentIndex);
    final totalDuration =
        SaveQueueHelper.calculateTotalDuration(filteredTracks);

    final upcomingCount = (currentIndex >= 0 && currentIndex < rawQueue.length - 1)
        ? rawQueue.length - (currentIndex + 1)
        : 0;
    final canChooseUpcoming = upcomingCount > 0 && upcomingCount != rawQueue.length;

    final canSave = _validationError == null &&
        filteredTracks.isNotEmpty &&
        !_isSubmitting &&
        _nameController.text.trim().isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AppSurface(
          withBlur: tokens.isGlass,
          color: tokens.isGlass ? tokens.glassSurface : tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          border: Border.all(
            color: tokens.isGlass
                ? tokens.glassBorder
                : Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    child: Icon(
                      Icons.playlist_add_rounded,
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
                          'Save Queue as Playlist',
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Save your active listening queue to your library',
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: tokens.textMuted,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(null),
                    tooltip: 'Close',
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Badges Row: Track Count & Duration
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BadgeChip(
                    icon: Icons.queue_music_rounded,
                    label: SaveQueueHelper.formatTrackCount(filteredTracks.length),
                    tokens: tokens,
                    isAccent: true,
                  ),
                  if (totalDuration.inSeconds > 0)
                    _BadgeChip(
                      icon: Icons.schedule_rounded,
                      label: SaveQueueHelper.formatDuration(totalDuration),
                      tokens: tokens,
                      isAccent: false,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Scope Selector (Optional: only if queue has meaningful upcoming split)
              if (canChooseUpcoming) ...[
                Text(
                  'QUEUE SELECTION',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: tokens.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ScopeOptionButton(
                        label: 'All (${rawQueue.length})',
                        isSelected: _selectedScope == QueueSaveScope.all,
                        tokens: tokens,
                        onTap: () {
                          if (_isSubmitting) return;
                          setState(() {
                            _selectedScope = QueueSaveScope.all;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ScopeOptionButton(
                        label: 'Upcoming ($upcomingCount)',
                        isSelected: _selectedScope == QueueSaveScope.upcoming,
                        tokens: tokens,
                        onTap: () {
                          if (_isSubmitting) return;
                          setState(() {
                            _selectedScope = QueueSaveScope.upcoming;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Text Field Input
              Text(
                'PLAYLIST NAME',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                enabled: !_isSubmitting,
                maxLength: SaveQueueHelper.maxPlaylistNameLength,
                autofocus: true,
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  color: tokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Chill Session, Road Trip',
                  hintStyle: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    color: tokens.textMuted,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: tokens.card,
                  counterStyle: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    color: tokens.textMuted,
                    fontSize: 10,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: tokens.textMuted,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_nameController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          color: tokens.textMuted,
                          tooltip: 'Clear',
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  _nameController.clear();
                                  _nameFocusNode.requestFocus();
                                },
                        ),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        color: tokens.accent,
                        tooltip: 'Reset to auto-name',
                        onPressed: _isSubmitting ? null : _resetToDefaultName,
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    borderSide: BorderSide(
                      color: tokens.accent,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    borderSide: BorderSide(
                      color: tokens.error,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) {
                  if (canSave) _handleSave();
                },
              ),

              // Inline Validation Error
              if (_validationError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _validationError!,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 12,
                    color: tokens.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              // Inline Submission Error
              if (_submissionError != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(
                      color: tokens.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 16, color: tokens.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _submissionError!,
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12,
                            color: tokens.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Track Preview Snippet
              if (filteredTracks.isNotEmpty) ...[
                const SizedBox(height: 14),
                _TrackPreviewList(
                  tracks: filteredTracks,
                  tokens: tokens,
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppPillButton(
                    label: 'Cancel',
                    variant: AppPillButtonVariant.ghost,
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(null),
                  ),
                  const SizedBox(width: 10),
                  AppPillButton(
                    label: 'Save Playlist',
                    variant: AppPillButtonVariant.primary,
                    isLoading: _isSubmitting,
                    onPressed: canSave ? _handleSave : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Internal Private Supporting Widgets
// ============================================================================

/// Compact metadata badge chip displaying count or duration.
class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppTokens tokens;
  final bool isAccent;

  const _BadgeChip({
    required this.icon,
    required this.label,
    required this.tokens,
    required this.isAccent,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isAccent
        ? tokens.accent.withValues(alpha: 0.12)
        : tokens.surfaceHighlight.withValues(alpha: 0.7);
    final fg = isAccent ? tokens.accent : tokens.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tokens.radiusFull),
        border: Border.all(
          color: isAccent
              ? tokens.accent.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 12,
              fontWeight: isAccent ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scope switch button (All Queue vs Upcoming Only).
class _ScopeOptionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final AppTokens tokens;
  final VoidCallback onTap;

  const _ScopeOptionButton({
    required this.label,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (tokens.isGlass
                    ? Colors.white.withValues(alpha: 0.15)
                    : tokens.surfaceHighlight)
                : tokens.card,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(
              color: isSelected
                  ? tokens.accent
                  : Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? tokens.accent : tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact track preview snippet showing the first 3 items and an overflow count.
class _TrackPreviewList extends StatelessWidget {
  final List<Track> tracks;
  final AppTokens tokens;

  const _TrackPreviewList({
    required this.tracks,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final previewTracks = tracks.take(3).toList();
    final remaining = tracks.length - previewTracks.length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_rounded, size: 14, color: tokens.textMuted),
              const SizedBox(width: 6),
              Text(
                'PREVIEW',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: tokens.textMuted,
                ),
              ),
              const Spacer(),
              if (remaining > 0)
                Text(
                  '+$remaining more',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ...previewTracks.map((track) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 11,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ============================================================================
// Quick Action Button: SaveQueueButton
// ============================================================================

/// Quick action button that can be embedded directly into queue bottom sheets,
/// player bars, or header toolbars to prompt the user to save the queue.
class SaveQueueButton extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;
  final bool isCompact;

  const SaveQueueButton({
    super.key,
    this.padding,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final queue = ref.watch(queueProvider).value ?? const [];

    final isEnabled = queue.isNotEmpty;

    if (isCompact) {
      return IconButton(
        icon: const Icon(Icons.playlist_add_rounded),
        tooltip: 'Save queue as playlist',
        color: isEnabled ? tokens.textPrimary : tokens.textMuted,
        onPressed: isEnabled
            ? () {
                HapticFeedback.lightImpact();
                SaveQueueDialog.show(context);
              }
            : null,
      );
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: AppPillButton(
        label: 'Save as Playlist',
        icon: const Icon(Icons.playlist_add_rounded, size: 16),
        variant: AppPillButtonVariant.secondary,
        onPressed: isEnabled
            ? () {
                HapticFeedback.lightImpact();
                SaveQueueDialog.show(context);
              }
            : null,
      ),
    );
  }
}
