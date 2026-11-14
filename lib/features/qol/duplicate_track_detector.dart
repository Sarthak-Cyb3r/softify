import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist_entry.dart';
import '../../domain/entities/track.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';

/// Provider for [DuplicateTrackDetector].
final duplicateTrackDetectorProvider = Provider<DuplicateTrackDetector>((ref) {
  return const DuplicateTrackDetector();
});

/// Utility class for detecting duplicate tracks in a playlist and prompting
/// the user for confirmation before adding.
class DuplicateTrackDetector {
  const DuplicateTrackDetector();

  /// Checks if [track] already exists in the playlist specified by [playlistId].
  ///
  /// Criteria for duplicate detection:
  /// 1. ID match (matching `trackId` or entry track `id`)
  /// 2. Source ID match (matching entry track `sourceId`)
  /// 3. Exact title and artist match (case-insensitive, trimmed) against
  ///    either the resolved track or the entry's original metadata.
  ///
  /// If a duplicate is found, displays an [AlertDialog] warning the user:
  /// - Title: "Track Already in Playlist"
  /// - Content: "'[Title]' is already in this playlist. Do you want to add it anyway?"
  /// - Actions: "Add Anyway" (confirms add) and "Cancel" (cancels add).
  ///
  /// Returns `true` if safe to add (no duplicate or user confirmed "Add Anyway"),
  /// and `false` if user cancelled or dismissed the dialog.
  static Future<bool> checkAndConfirmAdd(
    BuildContext context,
    WidgetRef ref, {
    required String playlistId,
    required Track track,
  }) async {
    try {
      final libraryRepo = ref.read(libraryRepositoryProvider);
      final playlistData = await libraryRepo.getPlaylistWithTracks(playlistId);

      if (playlistData == null || playlistData.entries.isEmpty) {
        return true;
      }

      final hasDuplicate = isDuplicate(
        entries: playlistData.entries,
        track: track,
      );

      if (!hasDuplicate) {
        return true;
      }
    } catch (_) {
      // If unable to query playlist, allow operation to avoid blocking user
      return true;
    }

    if (!context.mounted) {
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        final tokens = dialogCtx.tokens;
        return AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusCard),
            side: BorderSide(
              color: tokens.divider,
              width: 1.0,
            ),
          ),
          title: Text(
            'Track Already in Playlist',
            style: TextStyle(
              fontFamily: AppTheme.fontPageTitle,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
          ),
          content: Text(
            "'${track.title}' is already in this playlist. Do you want to add it anyway?",
            style: TextStyle(
              fontFamily: AppTheme.fontUi,
              fontSize: 14.0,
              color: tokens.textSecondary,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  color: tokens.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(
                'Add Anyway',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontWeight: FontWeight.bold,
                  color: tokens.accent,
                ),
              ),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  /// Checks if [track] matches any entry in [entries] by:
  /// - id
  /// - sourceId
  /// - exact title and artist
  static bool isDuplicate({
    required List<PlaylistEntry> entries,
    required Track track,
  }) {
    final targetId = track.id.trim();
    final targetSourceId = track.sourceId.trim();
    final targetTitle = track.title.trim().toLowerCase();
    final targetArtist = track.artist.trim().toLowerCase();

    for (final entry in entries) {
      // 1. By ID
      if (targetId.isNotEmpty) {
        if (entry.trackId != null && entry.trackId!.trim() == targetId) {
          return true;
        }
        if (entry.track != null && entry.track!.id.trim() == targetId) {
          return true;
        }
      }

      // 2. By sourceId
      if (targetSourceId.isNotEmpty) {
        if (entry.track != null &&
            entry.track!.sourceId.trim() == targetSourceId) {
          return true;
        }
      }

      // 3. By exact title + artist
      if (targetTitle.isNotEmpty && targetArtist.isNotEmpty) {
        if (entry.track != null) {
          final entryTitle = entry.track!.title.trim().toLowerCase();
          final entryArtist = entry.track!.artist.trim().toLowerCase();
          if (entryTitle == targetTitle && entryArtist == targetArtist) {
            return true;
          }
        }

        final originalTitle = entry.originalTitle.trim().toLowerCase();
        final originalArtist = entry.originalArtist.trim().toLowerCase();
        if (originalTitle == targetTitle && originalArtist == targetArtist) {
          return true;
        }
      }
    }

    return false;
  }
}

/// Extension allowing instance calls on [DuplicateTrackDetector] if instantiated.
extension DuplicateTrackDetectorInstanceExtension on DuplicateTrackDetector {
  Future<bool> checkAndConfirmAdd(
    BuildContext context,
    WidgetRef ref, {
    required String playlistId,
    required Track track,
  }) =>
      DuplicateTrackDetector.checkAndConfirmAdd(
        context,
        ref,
        playlistId: playlistId,
        track: track,
      );
}
