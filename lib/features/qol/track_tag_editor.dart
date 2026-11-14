import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_fts_repository.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/shared/app_filter_chip.dart';
import '../../presentation/widgets/shared/app_pill_button.dart';
import '../../presentation/widgets/shared/app_surface.dart';
import '../../presentation/widgets/shared/app_toast.dart';

/// Extension enabling direct syntax `_db.tracks.insertOnConflictUpdate(...)`.
extension TracksTableEditorExtension on $TracksTable {
  Future<int> insertOnConflictUpdate(Insertable<TrackRow> entity) {
    return attachedDatabase.into(this).insertOnConflictUpdate(entity);
  }
}

/// Service provider for performing track metadata updates and tag persistence.
final trackTagEditorServiceProvider = Provider<TrackTagEditorService>((ref) {
  final db = ref.watch(databaseProvider);
  dynamic handler;
  try {
    handler = ref.watch(audioHandlerProvider);
  } catch (_) {
    handler = null;
  }
  final fts = ref.watch(ftsRepositoryProvider);
  return TrackTagEditorService(db: db, audioHandler: handler, ftsRepository: fts);
});

/// Service responsible for updating track details in Drift and synchronizing
/// full-text search, taste profile tags, in-memory queue, and playback state.
class TrackTagEditorService {
  final AppDatabase _db;
  final dynamic _audioHandler;
  final IFtsRepository? _ftsRepository;

  const TrackTagEditorService({
    required AppDatabase db,
    dynamic audioHandler,
    IFtsRepository? ftsRepository,
  })  : _db = db,
        _audioHandler = audioHandler,
        _ftsRepository = ftsRepository;

  /// Fetches saved genre tag for a given track from Settings table.
  Future<String?> getTrackGenre(String trackId) async {
    try {
      final setting = await (_db.select(_db.settings)
            ..where((s) => s.key.equals('track_genre_$trackId')))
          .getSingleOrNull();
      return setting?.value;
    } catch (_) {
      return null;
    }
  }

  /// Updates track metadata in the local Drift database (`_db.tracks.insertOnConflictUpdate`),
  /// stores genre tags, updates FTS search index, and synchronizes the queue state.
  Future<Track> updateTrackMetadata({
    required Track track,
    required String title,
    required String artist,
    String? album,
    String? genre,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist =
        artist.trim().isNotEmpty ? artist.trim() : 'Unknown Artist';
    final cleanAlbum =
        album?.trim().isNotEmpty == true ? album!.trim() : null;
    final cleanGenre = genre?.trim();

    // 1. Fetch existing row to preserve timestamps, duration, and user states.
    final existing = await (_db.select(_db.tracks)
          ..where((t) => t.id.equals(track.id)))
        .getSingleOrNull();

    final updatedTrack = track.copyWith(
      title: cleanTitle,
      artist: cleanArtist,
      album: cleanAlbum,
    );

    // 2. Updates track details in local Drift database (_db.tracks.insertOnConflictUpdate).
    await _db.tracks.insertOnConflictUpdate(
      TracksCompanion(
        id: Value(track.id),
        sourceId: Value(
          track.sourceId.isNotEmpty ? track.sourceId : track.id,
        ),
        title: Value(cleanTitle),
        artist: Value(cleanArtist),
        album: Value(cleanAlbum),
        durationMs: Value(
          existing?.durationMs ?? track.duration.inMilliseconds,
        ),
        coverUrl: Value(existing?.coverUrl ?? track.coverUrl),
        matchConfidence: Value(
          existing?.matchConfidence ?? track.matchConfidence ?? 1.0,
        ),
        isLiked: Value(existing?.isLiked ?? track.isLiked),
        isUnavailable: Value(existing?.isUnavailable ?? track.isUnavailable),
        createdAt: Value(
          existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );

    // 3. Persist genre tag to Settings and TasteProfiles for recommendation relevance.
    if (cleanGenre != null && cleanGenre.isNotEmpty) {
      await _db.into(_db.settings).insertOnConflictUpdate(
        SettingsCompanion(
          key: Value('track_genre_${track.id}'),
          value: Value(cleanGenre),
        ),
      );
      try {
        await _db.into(_db.tasteProfiles).insertOnConflictUpdate(
          TasteProfilesCompanion(
            entityType: const Value('genre'),
            entityId: Value(cleanGenre.toLowerCase()),
            slowWeight: const Value(1.0),
            fastWeight: const Value(1.0),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      } catch (_) {}
    } else {
      await (_db.delete(_db.settings)
            ..where((s) => s.key.equals('track_genre_${track.id}')))
          .go();
    }

    // 4. Update FTS search index for fast discovery.
    if (_ftsRepository != null) {
      try {
        await _ftsRepository.indexTrack(updatedTrack);
      } catch (_) {}
    }

    // 5. Update audio handler in-memory queue and broadcast stream.
    if (_audioHandler != null) {
      try {
        _audioHandler.updateTrackMetadata(updatedTrack);
      } catch (_) {}
    }

    return updatedTrack;
  }
}

/// Modal dialog for quickly editing a track's Title, Artist, Album, and Genre tags.
class TrackTagEditorDialog extends ConsumerStatefulWidget {
  final Track track;
  final VoidCallback? onSaved;
  final bool isBottomSheet;

  const TrackTagEditorDialog({
    super.key,
    required this.track,
    this.onSaved,
    this.isBottomSheet = false,
  });

  /// Displays [TrackTagEditorDialog] inside a centered modal dialog.
  static Future<Track?> show(
    BuildContext context, {
    required Track track,
    VoidCallback? onSaved,
  }) {
    return showDialog<Track?>(
      context: context,
      barrierDismissible: true,
      builder: (_) => TrackTagEditorDialog(
        track: track,
        onSaved: onSaved,
        isBottomSheet: false,
      ),
    );
  }

  /// Displays [TrackTagEditorDialog] inside a draggable bottom sheet.
  static Future<Track?> showBottomSheet(
    BuildContext context, {
    required Track track,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet<Track?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TrackTagEditorDialog(
        track: track,
        onSaved: onSaved,
        isBottomSheet: true,
      ),
    );
  }

  @override
  ConsumerState<TrackTagEditorDialog> createState() =>
      _TrackTagEditorDialogState();
}

class _TrackTagEditorDialogState extends ConsumerState<TrackTagEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  late final TextEditingController _genreController;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _selectedGenreChip;

  static const List<String> presetGenres = [
    'Pop',
    'Rock',
    'Hip-Hop',
    'Electronic',
    'Indie',
    'R&B',
    'Acoustic',
    'Jazz',
    'Classical',
    'Metal',
    'Lo-Fi',
    'Bollywood',
    'Folk',
    'Soul',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.track.title);
    _artistController = TextEditingController(text: widget.track.artist);
    _albumController = TextEditingController(text: widget.track.album ?? '');
    _genreController = TextEditingController();

    _loadInitialGenre();
  }

  Future<void> _loadInitialGenre() async {
    try {
      final service = ref.read(trackTagEditorServiceProvider);
      final genre = await service.getTrackGenre(widget.track.id);
      if (genre != null && genre.isNotEmpty && mounted) {
        setState(() {
          _genreController.text = genre;
          _syncSelectedChip(genre);
        });
      }
    } catch (_) {}
  }

  void _syncSelectedChip(String currentText) {
    final trimmed = currentText.trim().toLowerCase();
    final match = presetGenres.cast<String?>().firstWhere(
          (g) => g!.toLowerCase() == trimmed,
          orElse: () => null,
        );
    _selectedGenreChip = match;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  void _onGenreChipTapped(String genre) {
    setState(() {
      if (_genreController.text.trim().toLowerCase() == genre.toLowerCase()) {
        _genreController.clear();
        _selectedGenreChip = null;
      } else {
        _genreController.text = genre;
        _selectedGenreChip = genre;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ref.read(trackTagEditorServiceProvider);
      final updatedTrack = await service.updateTrackMetadata(
        track: widget.track,
        title: _titleController.text,
        artist: _artistController.text,
        album: _albumController.text,
        genre: _genreController.text,
      );

      // Invalidate Riverpod streams for instant reactive UI refresh
      ref.invalidate(localTracksStreamProvider);
      ref.invalidate(queueProvider);
      ref.invalidate(currentTrackProvider);
      ref.invalidate(likedTracksStreamProvider);
      ref.invalidate(likedTrackIdsProvider);

      widget.onSaved?.call();

      if (mounted) {
        Navigator.of(context).pop(updatedTrack);
        AppToast.showSuccess(context, message: 'Track metadata updated');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.showError(context, message: 'Failed to update track: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final content = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                  Icons.edit_note_rounded,
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
                      'Edit Track Tags',
                      style: TextStyle(
                        fontFamily: AppTheme.fontPageTitle,
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.track.sourceId.isNotEmpty
                          ? widget.track.sourceId
                          : widget.track.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12.0,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: tokens.textSecondary),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Scrollable inputs area
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Track Title Field
                  _buildInputLabel('Track Title', tokens, isRequired: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      color: tokens.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: _buildInputDecoration(
                      hintText: 'Song Title',
                      prefixIcon: Icons.title_rounded,
                      tokens: tokens,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Track title cannot be empty';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 2. Artist Name Field
                  _buildInputLabel('Artist Name', tokens, isRequired: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _artistController,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      color: tokens.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: _buildInputDecoration(
                      hintText: 'Artist or Band Name',
                      prefixIcon: Icons.person_outline_rounded,
                      tokens: tokens,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Artist name cannot be empty';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 3. Album Name Field
                  _buildInputLabel('Album Name', tokens),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _albumController,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      color: tokens.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: _buildInputDecoration(
                      hintText: 'Album Name (Optional)',
                      prefixIcon: Icons.album_outlined,
                      tokens: tokens,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Genre Field
                  _buildInputLabel('Genre / Tag', tokens),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _genreController,
                    textInputAction: TextInputAction.done,
                    onChanged: (text) => setState(() => _syncSelectedChip(text)),
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      color: tokens.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: _buildInputDecoration(
                      hintText: 'e.g. Pop, Rock, Lo-Fi',
                      prefixIcon: Icons.local_offer_outlined,
                      tokens: tokens,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Genre Chips
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: tokens.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Quick Tags',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presetGenres.map((genre) {
                      final isSelected = _selectedGenreChip?.toLowerCase() ==
                          genre.toLowerCase();
                      return AppFilterChip(
                        label: genre,
                        isSelected: isSelected,
                        height: 28.0,
                        onTap: () => _onGenreChipTapped(genre),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppPillButton(
                label: 'Cancel',
                variant: AppPillButtonVariant.ghost,
                height: 38.0,
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              AppPillButton(
                label: _isSaving ? 'Saving...' : 'Save Tags',
                icon: _isSaving
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tokens.isGlass ? Colors.white : Colors.black,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 16),
                variant: AppPillButtonVariant.primary,
                height: 38.0,
                onPressed: _isSaving ? null : _handleSave,
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.isBottomSheet) {
      return Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: tokens.isGlass ? tokens.glassSurface : tokens.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: tokens.isGlass
              ? Border(top: BorderSide(color: tokens.glassBorder, width: 1.0))
              : null,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(child: content),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AppSurface(
          withBlur: tokens.isGlass,
          color: tokens.isGlass ? tokens.glassSurface : tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          border: Border.all(
            color: tokens.isGlass ? tokens.glassBorder : tokens.divider,
            width: 1.0,
          ),
          padding: const EdgeInsets.all(22),
          child: content,
        ),
      ),
    );
  }

  Widget _buildInputLabel(
    String label,
    AppTokens tokens, {
    bool isRequired = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.textSecondary,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: tokens.accent,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    required AppTokens tokens,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontFamily: AppTheme.fontUi,
        color: tokens.textMuted,
        fontSize: 14,
      ),
      prefixIcon: Icon(
        prefixIcon,
        size: 18,
        color: tokens.textSecondary,
      ),
      filled: true,
      fillColor: tokens.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        borderSide: BorderSide(
          color: tokens.divider.withValues(alpha: 0.4),
          width: 1.0,
        ),
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
          width: 1.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        borderSide: BorderSide(
          color: tokens.error,
          width: 1.5,
        ),
      ),
    );
  }
}
