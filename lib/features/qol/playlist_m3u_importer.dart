import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_library_repository.dart';
import '../../presentation/providers/player_providers.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/shared/app_pill_button.dart';
import '../../presentation/widgets/shared/app_surface.dart';
import '../../presentation/widgets/shared/app_toast.dart';

/// Item representing a parsed track from an M3U file or plain text track list.
class ParsedTrackItem {
  final String title;
  final String artist;
  final Duration duration;
  final String? album;
  final String? pathOrUrl;

  const ParsedTrackItem({
    required this.title,
    required this.artist,
    this.duration = Duration.zero,
    this.album,
    this.pathOrUrl,
  });

  ParsedTrackItem copyWith({
    String? title,
    String? artist,
    Duration? duration,
    String? album,
    String? pathOrUrl,
  }) {
    return ParsedTrackItem(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      duration: duration ?? this.duration,
      album: album ?? this.album,
      pathOrUrl: pathOrUrl ?? this.pathOrUrl,
    );
  }

  /// Formatted duration string (e.g., "3:45" or "--:--" when unknown).
  String get formattedDuration {
    if (duration.inSeconds <= 0) return '--:--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedTrackItem &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          artist == other.artist &&
          duration == other.duration &&
          album == other.album &&
          pathOrUrl == other.pathOrUrl;

  @override
  int get hashCode => Object.hash(title, artist, duration, album, pathOrUrl);

  @override
  String toString() =>
      'ParsedTrackItem(title: "$title", artist: "$artist", duration: $formattedDuration)';
}

/// Result of parsing an M3U or plain text track list.
class ParsedPlaylistResult {
  final String playlistName;
  final List<ParsedTrackItem> tracks;

  const ParsedPlaylistResult({
    required this.playlistName,
    required this.tracks,
  });

  int get totalDurationSeconds =>
      tracks.fold(0, (sum, t) => sum + t.duration.inSeconds);

  /// Human-friendly duration summary (e.g., "12 tracks • 45 min").
  String get formattedSummary {
    final totalSec = totalDurationSeconds;
    final count = tracks.length;
    final trackLabel = count == 1 ? '1 track' : '$count tracks';

    if (totalSec <= 0) return trackLabel;

    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;

    if (hours > 0) {
      return '$trackLabel • $hours hr $minutes min';
    } else {
      return '$trackLabel • $minutes min';
    }
  }
}

/// Riverpod provider for [PlaylistM3uImporter].
final playlistM3uImporterProvider = Provider<PlaylistM3uImporter>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return PlaylistM3uImporter(repository: repo);
});

/// Playlist importer capable of parsing `.m3u`, `.m3u8`, or plain text track lists
/// (`Artist - Title` per line) and importing them into Softify library playlists.
class PlaylistM3uImporter {
  final ILibraryRepository? _repository;

  const PlaylistM3uImporter({ILibraryRepository? repository})
      : _repository = repository;

  // ==========================================
  // Parsing API
  // ==========================================

  /// Parses raw text content (either M3U/M3U8 format or plain text tracklist).
  static ParsedPlaylistResult parseContent(
    String content, {
    String? defaultPlaylistName,
  }) {
    final cleanContent = content.replaceAll('\uFEFF', '').trim();
    if (cleanContent.isEmpty) {
      return ParsedPlaylistResult(
        playlistName: defaultPlaylistName ?? _generateDefaultPlaylistName(),
        tracks: const [],
      );
    }

    final lines = cleanContent.split(RegExp(r'\r?\n'));
    final isM3u = lines.any((l) {
      final t = l.trim();
      return t.startsWith('#EXTM3U') || t.startsWith('#EXTINF:');
    });

    if (isM3u) {
      return _parseM3u(lines, defaultPlaylistName: defaultPlaylistName);
    } else {
      return _parsePlainText(lines, defaultPlaylistName: defaultPlaylistName);
    }
  }

  /// Reads and parses an M3U, M3U8, or text file from the given [filePath].
  static Future<ParsedPlaylistResult> parseFile(
    String filePath, {
    String? defaultPlaylistName,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final content = await file.readAsString();
    var fallbackName = defaultPlaylistName ?? '';
    if (fallbackName.isEmpty) {
      final base = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'Playlist';
      fallbackName = base.replaceAll(
          RegExp(r'\.(?:m3u8?|txt|csv)$', caseSensitive: false), '');
    }

    return parseContent(content, defaultPlaylistName: fallbackName);
  }

  // ==========================================
  // Library Integration API
  // ==========================================

  /// Integrates with [ILibraryRepository.createPlaylist()] and adds the parsed tracks.
  static Future<Playlist> importTracks({
    required ILibraryRepository repository,
    required String playlistName,
    required List<ParsedTrackItem> tracks,
    String? description,
  }) async {
    final cleanName = playlistName.trim().isEmpty
        ? _generateDefaultPlaylistName()
        : playlistName.trim();

    final desc = description ??
        'Imported playlist with ${tracks.length} track${tracks.length == 1 ? '' : 's'}.';

    // 1. Create playlist in Softify library
    final playlist = await repository.createPlaylist(
      cleanName,
      description: desc,
      isImported: true,
    );

    if (tracks.isEmpty) {
      return playlist;
    }

    // 2. Map parsed tracks to Softify domain Track entities
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = math.Random();
    final trackEntities = <Track>[];
    final originalMeta = <({String title, String artist})>[];

    for (int i = 0; i < tracks.length; i++) {
      final item = tracks[i];
      final uniqueSuffix = '${now}_${random.nextInt(0xFFFFFF)}';
      final trackId = 'm3u_${playlist.id}_${i}_$uniqueSuffix';
      final sourceId = (item.pathOrUrl != null && item.pathOrUrl!.isNotEmpty)
          ? item.pathOrUrl!
          : 'm3u_${playlist.id}_$i';

      trackEntities.add(Track(
        id: trackId,
        sourceId: sourceId,
        title: item.title,
        artist: item.artist,
        album: item.album,
        duration: item.duration,
      ));

      originalMeta.add((title: item.title, artist: item.artist));
    }

    // 3. Batch add tracks into newly created playlist
    await repository.addTracksToPlaylist(
      playlist.id,
      trackEntities,
      originalMetadata: originalMeta,
    );

    return playlist;
  }

  /// Instance wrapper for [importTracks] using bound repository.
  Future<Playlist> import(
    String playlistName,
    List<ParsedTrackItem> tracks, {
    String? description,
  }) {
    if (_repository == null) {
      throw StateError('PlaylistM3uImporter was created without a repository');
    }
    return importTracks(
      repository: _repository,
      playlistName: playlistName,
      tracks: tracks,
      description: description,
    );
  }

  // ==========================================
  // UI Dialog Helpers
  // ==========================================

  /// Opens the Review Dialog directly with pre-parsed tracks.
  static Future<Playlist?> showReviewDialog(
    BuildContext context, {
    required ParsedPlaylistResult parsedPlaylist,
    ILibraryRepository? repository,
  }) {
    return showDialog<Playlist>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PlaylistImportReviewDialog(
        parsedPlaylist: parsedPlaylist,
        repository: repository,
      ),
    );
  }

  /// Displays an interactive input dialog allowing users to paste M3U or text tracklists,
  /// review the parsed tracks, and import into Softify.
  static Future<Playlist?> showImportDialog(
    BuildContext context, {
    String? initialContent,
    String? defaultPlaylistName,
    ILibraryRepository? repository,
  }) {
    return showDialog<Playlist>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _PlaylistTextInputDialog(
        initialContent: initialContent,
        defaultPlaylistName: defaultPlaylistName,
        repository: repository,
      ),
    );
  }

  // ==========================================
  // Private Parsing Implementation
  // ==========================================

  static ParsedPlaylistResult _parseM3u(
    List<String> lines, {
    String? defaultPlaylistName,
  }) {
    String playlistName = defaultPlaylistName ?? '';
    final tracks = <ParsedTrackItem>[];

    Duration currentDuration = Duration.zero;
    String currentTitle = '';
    String currentArtist = '';
    String? currentAlbum;
    String? currentPath;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#')) {
        // Parse metadata directives
        if (line.startsWith('#PLAYLIST:') || line.startsWith('#EXT-X-NAME:')) {
          final colonIdx = line.indexOf(':');
          if (colonIdx != -1) {
            final name = line.substring(colonIdx + 1).trim();
            if (name.isNotEmpty && playlistName.isEmpty) {
              playlistName = name;
            }
          }
        } else if (line.startsWith('#EXTALB:')) {
          currentAlbum = line.substring(8).trim();
        } else if (line.startsWith('#EXTART:')) {
          currentArtist = line.substring(8).trim();
        } else if (line.startsWith('#EXTINF:')) {
          final infoPart = line.substring(8).trim();
          final firstComma = infoPart.indexOf(',');

          if (firstComma != -1) {
            final durationPart = infoPart.substring(0, firstComma).trim();
            final titlePart = infoPart.substring(firstComma + 1).trim();

            final durMatch = RegExp(r'^(-?[\d\.]+)').firstMatch(durationPart);
            if (durMatch != null) {
              final secondsNum = double.tryParse(durMatch.group(1)!);
              if (secondsNum != null && secondsNum > 0) {
                currentDuration =
                    Duration(milliseconds: (secondsNum * 1000).round());
              } else {
                currentDuration = Duration.zero;
              }
            }

            final parsed = extractArtistAndTitle(titlePart);
            currentTitle = parsed.title;
            if (currentArtist.isEmpty || currentArtist == 'Unknown Artist') {
              currentArtist = parsed.artist;
            }
          } else {
            final durMatch = RegExp(r'^(-?[\d\.]+)').firstMatch(infoPart);
            if (durMatch != null) {
              final secondsNum = double.tryParse(durMatch.group(1)!);
              if (secondsNum != null && secondsNum > 0) {
                currentDuration =
                    Duration(milliseconds: (secondsNum * 1000).round());
              }
            }
          }
        }
      } else {
        // URI or file path line
        currentPath = line;

        // If title is missing or incomplete, derive from the path/filename
        if (currentTitle.isEmpty) {
          final fromPath = stripFileExtensionAndPath(line);
          final cleaned = stripTrackNumber(fromPath);
          final parsed = extractArtistAndTitle(cleaned);
          currentTitle = parsed.title;
          if (currentArtist.isEmpty || currentArtist == 'Unknown Artist') {
            currentArtist = parsed.artist;
          }
        }

        if (currentTitle.isNotEmpty) {
          tracks.add(ParsedTrackItem(
            title: currentTitle,
            artist: currentArtist.isEmpty ? 'Unknown Artist' : currentArtist,
            duration: currentDuration,
            album: currentAlbum,
            pathOrUrl: currentPath,
          ));
        }

        // Reset per-track state
        currentDuration = Duration.zero;
        currentTitle = '';
        currentArtist = '';
        currentAlbum = null;
        currentPath = null;
      }
    }

    // Flush trailing EXTINF without trailing path line
    if (currentTitle.isNotEmpty) {
      tracks.add(ParsedTrackItem(
        title: currentTitle,
        artist: currentArtist.isEmpty ? 'Unknown Artist' : currentArtist,
        duration: currentDuration,
        album: currentAlbum,
        pathOrUrl: currentPath,
      ));
    }

    if (playlistName.isEmpty) {
      playlistName = _generateDefaultPlaylistName();
    }

    return ParsedPlaylistResult(
      playlistName: playlistName,
      tracks: tracks,
    );
  }

  static ParsedPlaylistResult _parsePlainText(
    List<String> lines, {
    String? defaultPlaylistName,
  }) {
    final tracks = <ParsedTrackItem>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) continue;

      // 1. Extract optional duration: (3:45), [03:45], or trailing 3:45
      final durResult = extractDuration(line);
      final duration = durResult.duration;
      var clean = durResult.cleanText;

      // 2. Strip file path / audio extensions if line represents a file
      clean = stripFileExtensionAndPath(clean);

      // 3. Strip track numbers ("01. ", "1 - ", etc.)
      clean = stripTrackNumber(clean);

      if (clean.isEmpty) continue;

      // 4. Extract artist and title
      final parsed = extractArtistAndTitle(clean);

      if (parsed.title.isNotEmpty) {
        tracks.add(ParsedTrackItem(
          title: parsed.title,
          artist: parsed.artist,
          duration: duration,
        ));
      }
    }

    final name = (defaultPlaylistName != null && defaultPlaylistName.isNotEmpty)
        ? defaultPlaylistName
        : _generateDefaultPlaylistName();

    return ParsedPlaylistResult(
      playlistName: name,
      tracks: tracks,
    );
  }

  // ==========================================
  // String & Regex Helpers
  // ==========================================

  /// Extracts duration and returns duration with cleaned string.
  static ({Duration duration, String cleanText}) extractDuration(String input) {
    var text = input.trim();

    // 1. Bracketed or parenthesized duration: (3:45), [03:45], (01:12:30), [4:15]
    final bracketMatch = RegExp(
      r'[\(\[]\s*(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\s*[\)\]]',
    ).firstMatch(text);

    if (bracketMatch != null) {
      final h = int.tryParse(bracketMatch.group(1) ?? '0') ?? 0;
      final m = int.tryParse(bracketMatch.group(2) ?? '0') ?? 0;
      final s = int.tryParse(bracketMatch.group(3) ?? '0') ?? 0;
      final dur = Duration(hours: h, minutes: m, seconds: s);

      final clean = text.replaceRange(bracketMatch.start, bracketMatch.end, '').trim();
      return (duration: dur, cleanText: clean);
    }

    // 2. Trailing duration at end of line: "Song Name - 3:45" or "Song Name 03:45"
    final trailMatch = RegExp(
      r'(?:[-–—−:\s]+)?(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\s*$',
    ).firstMatch(text);

    if (trailMatch != null) {
      final h = int.tryParse(trailMatch.group(1) ?? '0') ?? 0;
      final m = int.tryParse(trailMatch.group(2) ?? '0') ?? 0;
      final s = int.tryParse(trailMatch.group(3) ?? '0') ?? 0;
      final dur = Duration(hours: h, minutes: m, seconds: s);

      final clean = text.substring(0, trailMatch.start).trim();
      return (duration: dur, cleanText: clean);
    }

    return (duration: Duration.zero, cleanText: text);
  }

  /// Strips leading track index numbers (e.g., "1. ", "01 - ", "Track 03: ", "(1) ").
  static String stripTrackNumber(String input) {
    var s = input.trim();
    s = s.replaceFirst(
      RegExp(
        r'^(?:(?:Track\s*)?\d+[\.\-\)\:]\s*|\(\d+\)\s*|\[\d+\]\s*|[•\*\-]\s*)',
        caseSensitive: false,
      ),
      '',
    );
    return s.trim();
  }

  /// Strips directories and audio extensions if string resembles a file path or URL.
  static String stripFileExtensionAndPath(String input) {
    var s = input.trim();

    if (s.startsWith('http://') ||
        s.startsWith('https://') ||
        s.startsWith('file://')) {
      try {
        final uri = Uri.parse(s);
        if (uri.pathSegments.isNotEmpty) {
          s = Uri.decodeComponent(uri.pathSegments.last);
        }
      } catch (_) {}
    } else if (s.contains('/') || s.contains(r'\')) {
      final lastSlash = math.max(s.lastIndexOf('/'), s.lastIndexOf(r'\'));
      if (lastSlash >= 0 && lastSlash < s.length - 1) {
        s = s.substring(lastSlash + 1);
      }
    }

    s = s.replaceFirst(
      RegExp(
        r'\.(?:mp3|flac|m4a|wav|aac|ogg|opus|wma|alac|aiff|webm)$',
        caseSensitive: false,
      ),
      '',
    );

    return s.trim();
  }

  /// Extracts artist and title from lines formatted as "Artist - Title", "Title by Artist", etc.
  static ({String artist, String title}) extractArtistAndTitle(String input) {
    var s = input.trim();

    // Strip surrounding quotes
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }

    // Format 1: "Title by Artist"
    final byMatch = RegExp(r'\s+by\s+', caseSensitive: false).firstMatch(s);
    if (byMatch != null) {
      final titlePart = s.substring(0, byMatch.start).trim();
      final artistPart = s.substring(byMatch.end).trim();
      if (titlePart.isNotEmpty && artistPart.isNotEmpty) {
        return (artist: _cleanQuotes(artistPart), title: _cleanQuotes(titlePart));
      }
    }

    // Format 2: "Artist - Title" (handles hyphen, en-dash, em-dash, minus)
    final dashMatch = RegExp(r'\s+[-–—−]\s+').firstMatch(s);
    if (dashMatch != null) {
      final artistPart = s.substring(0, dashMatch.start).trim();
      final titlePart = s.substring(dashMatch.end).trim();
      if (artistPart.isNotEmpty && titlePart.isNotEmpty) {
        return (artist: _cleanQuotes(artistPart), title: _cleanQuotes(titlePart));
      }
    }

    // Format 3: "Artist : Title" or "Artist | Title"
    final sepMatch = RegExp(r'\s+[:\|\/]\s+').firstMatch(s);
    if (sepMatch != null) {
      final artistPart = s.substring(0, sepMatch.start).trim();
      final titlePart = s.substring(sepMatch.end).trim();
      if (artistPart.isNotEmpty && titlePart.isNotEmpty) {
        return (artist: _cleanQuotes(artistPart), title: _cleanQuotes(titlePart));
      }
    }

    // Fallback: entire string is title
    return (artist: 'Unknown Artist', title: _cleanQuotes(s));
  }

  static String _cleanQuotes(String input) {
    var s = input.trim();
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }
    return s;
  }

  static String _generateDefaultPlaylistName() {
    final now = DateTime.now();
    return 'Imported Playlist (${now.month}/${now.day})';
  }
}

// ============================================================================
// Review Dialog Widget
// ============================================================================

/// Content-first review dialog for previewing parsed M3U / text tracks before
/// adding them to the Softify library.
class PlaylistImportReviewDialog extends ConsumerStatefulWidget {
  final ParsedPlaylistResult parsedPlaylist;
  final ILibraryRepository? repository;
  final ValueChanged<Playlist>? onImportSuccess;

  const PlaylistImportReviewDialog({
    super.key,
    required this.parsedPlaylist,
    this.repository,
    this.onImportSuccess,
  });

  @override
  ConsumerState<PlaylistImportReviewDialog> createState() =>
      _PlaylistImportReviewDialogState();
}

class _PlaylistImportReviewDialogState
    extends ConsumerState<PlaylistImportReviewDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _filterController;
  late List<ParsedTrackItem> _tracks;
  late Set<int> _selectedIndices;

  bool _isImporting = false;
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.parsedPlaylist.playlistName);
    _filterController = TextEditingController();
    _tracks = List<ParsedTrackItem>.from(widget.parsedPlaylist.tracks);
    _selectedIndices = {for (int i = 0; i < _tracks.length; i++) i};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  List<int> get _visibleIndices {
    if (_filterQuery.isEmpty) {
      return List<int>.generate(_tracks.length, (i) => i);
    }
    final q = _filterQuery.toLowerCase();
    return [
      for (int i = 0; i < _tracks.length; i++)
        if (_tracks[i].title.toLowerCase().contains(q) ||
            _tracks[i].artist.toLowerCase().contains(q))
          i
    ];
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndices.length == _tracks.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices = {for (int i = 0; i < _tracks.length; i++) i};
      }
    });
  }

  void _removeTrack(int index) {
    setState(() {
      _tracks.removeAt(index);
      _selectedIndices.remove(index);
      // Re-index remaining selected items
      final newSelected = <int>{};
      for (final s in _selectedIndices) {
        if (s > index) {
          newSelected.add(s - 1);
        } else {
          newSelected.add(s);
        }
      }
      _selectedIndices = newSelected;
    });
  }

  Future<void> _handleImport() async {
    if (_selectedIndices.isEmpty || _isImporting) return;

    final ILibraryRepository repo =
        widget.repository ?? ref.read(libraryRepositoryProvider);
    final playlistTitle = _nameController.text.trim().isEmpty
        ? 'Imported Playlist'
        : _nameController.text.trim();

    final selectedTracks = [
      for (final i in _selectedIndices.toList()..sort()) _tracks[i]
    ];

    setState(() {
      _isImporting = true;
    });

    try {
      final createdPlaylist = await PlaylistM3uImporter.importTracks(
        repository: repo,
        playlistName: playlistTitle,
        tracks: selectedTracks,
      );

      if (mounted) {
        widget.onImportSuccess?.call(createdPlaylist);
        AppToast.show(
          context,
          message:
              'Imported "${createdPlaylist.name}" (${selectedTracks.length} tracks)',
          icon: const Icon(Icons.check_circle_rounded,
              color: AppTheme.accent, size: 20),
        );
        Navigator.of(context).pop(createdPlaylist);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        AppToast.show(
          context,
          message: 'Failed to import playlist: $e',
          icon: const Icon(Icons.error_outline_rounded,
              color: AppTheme.error, size: 20),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final visible = _visibleIndices;
    final selectedCount = _selectedIndices.length;
    final totalCount = _tracks.length;

    // Calculate selected duration
    int selectedSec = 0;
    for (final i in _selectedIndices) {
      if (i < _tracks.length) {
        selectedSec += _tracks[i].duration.inSeconds;
      }
    }
    final minutes = (selectedSec % 3600) ~/ 60;
    final hours = selectedSec ~/ 3600;
    final durationStr = hours > 0
        ? '$hours hr $minutes min'
        : (selectedSec > 0 ? '$minutes min' : '');

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.all(tokens.spaceMd),
      child: AppSurface(
        withBlur: tokens.isGlass,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        color: tokens.surfaceElevated,
        border: Border.all(
          color: tokens.isGlass ? tokens.glassBorder : tokens.divider,
          width: 1.0,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 540.0,
            maxHeight: 660.0,
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                      ),
                      child: Icon(
                        Icons.playlist_add_check_rounded,
                        color: tokens.accent,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: tokens.spaceSm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import Playlist',
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
                            'Review and select tracks to add to your library',
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 12.0,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: tokens.textMuted,
                      tooltip: 'Close',
                      onPressed: _isImporting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                SizedBox(height: tokens.spaceMd),

                // 2. Playlist Name Input
                Text(
                  'Playlist Name',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  enabled: !_isImporting,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    color: tokens.textPrimary,
                    fontSize: 14.0,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter playlist name',
                    hintStyle: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      color: tokens.textMuted,
                      fontSize: 14.0,
                    ),
                    prefixIcon: Icon(
                      Icons.queue_music_rounded,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                    filled: true,
                    fillColor: tokens.card,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 10.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      borderSide: BorderSide(color: tokens.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      borderSide: BorderSide(color: tokens.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      borderSide: BorderSide(color: tokens.accent, width: 1.5),
                    ),
                  ),
                ),

                SizedBox(height: tokens.spaceMd),

                // 3. Selection Summary & Filter Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$selectedCount of $totalCount selected'
                      '${durationStr.isNotEmpty ? ' • $durationStr' : ''}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: tokens.textSecondary,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _isImporting ? null : _toggleSelectAll,
                      child: Text(
                        selectedCount == totalCount
                            ? 'Deselect All'
                            : 'Select All',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: tokens.accent,
                        ),
                      ),
                    ),
                  ],
                ),

                if (_tracks.length > 6) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: _filterController,
                    enabled: !_isImporting,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      color: tokens.textPrimary,
                      fontSize: 12.0,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _filterQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Filter parsed tracks...',
                      hintStyle: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        color: tokens.textMuted,
                        fontSize: 12.0,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: tokens.textMuted,
                      ),
                      filled: true,
                      fillColor: tokens.card,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 6.0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // 4. Track List
                Expanded(
                  child: _tracks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'No tracks found in the provided input.\nCheck that your list follows "Artist - Title" format.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 13.0,
                                color: tokens.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: tokens.card,
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                            border: Border.all(color: tokens.divider),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                            child: ListView.separated(
                              itemCount: visible.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1.0,
                                thickness: 1.0,
                                color: tokens.divider.withValues(alpha: 0.5),
                              ),
                              itemBuilder: (context, idx) {
                                final originalIndex = visible[idx];
                                final track = _tracks[originalIndex];
                                final isSelected =
                                    _selectedIndices.contains(originalIndex);

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isImporting
                                        ? null
                                        : () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedIndices
                                                    .remove(originalIndex);
                                              } else {
                                                _selectedIndices
                                                    .add(originalIndex);
                                              }
                                            });
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0,
                                        vertical: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: Checkbox(
                                              value: isSelected,
                                              activeColor: tokens.accent,
                                              checkColor: Colors.black,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              onChanged: _isImporting
                                                  ? null
                                                  : (val) {
                                                      setState(() {
                                                        if (val == true) {
                                                          _selectedIndices.add(
                                                              originalIndex);
                                                        } else {
                                                          _selectedIndices
                                                              .remove(
                                                                  originalIndex);
                                                        }
                                                      });
                                                    },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 26,
                                            child: Text(
                                              '${originalIndex + 1}',
                                              style: TextStyle(
                                                fontFamily: AppTheme.fontUi,
                                                fontSize: 11.0,
                                                color: tokens.textMuted,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  track.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontFamily: AppTheme.fontUi,
                                                    fontSize: 13.0,
                                                    fontWeight: FontWeight.w600,
                                                    color: isSelected
                                                        ? tokens.textPrimary
                                                        : tokens.textMuted,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  track.artist,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontFamily: AppTheme.fontUi,
                                                    fontSize: 11.5,
                                                    color: isSelected
                                                        ? tokens.textSecondary
                                                        : tokens.textMuted
                                                            .withValues(alpha: 0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            track.formattedDuration,
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontUi,
                                              fontSize: 11.0,
                                              color: tokens.textMuted,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                            ),
                                            color: tokens.textMuted,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                            tooltip: 'Remove track',
                                            onPressed: _isImporting
                                                ? null
                                                : () =>
                                                    _removeTrack(originalIndex),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ),

                SizedBox(height: tokens.spaceMd),

                // 5. Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppPillButton(
                      label: 'Cancel',
                      variant: AppPillButtonVariant.ghost,
                      height: 38.0,
                      onPressed: _isImporting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    SizedBox(width: tokens.spaceSm),
                    AppPillButton(
                      label: selectedCount > 0
                          ? 'Import into Softify ($selectedCount)'
                          : 'Import into Softify',
                      variant: AppPillButtonVariant.primary,
                      height: 38.0,
                      isLoading: _isImporting,
                      onPressed:
                          (selectedCount > 0 && !_isImporting) ? _handleImport : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Text / File Input Dialog Helper
// ============================================================================

class _PlaylistTextInputDialog extends ConsumerStatefulWidget {
  final String? initialContent;
  final String? defaultPlaylistName;
  final ILibraryRepository? repository;

  const _PlaylistTextInputDialog({
    this.initialContent,
    this.defaultPlaylistName,
    this.repository,
  });

  @override
  ConsumerState<_PlaylistTextInputDialog> createState() =>
      _PlaylistTextInputDialogState();
}

class _PlaylistTextInputDialogState
    extends ConsumerState<_PlaylistTextInputDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseAndReview() {
    final raw = _textController.text.trim();
    if (raw.isEmpty) {
      AppToast.show(
        context,
        message: 'Please paste tracklist or M3U content first',
        icon: const Icon(Icons.info_outline_rounded,
            color: AppTheme.accent, size: 20),
      );
      return;
    }

    final parsed = PlaylistM3uImporter.parseContent(
      raw,
      defaultPlaylistName: widget.defaultPlaylistName,
    );

    // Close this input dialog and open the review dialog
    Navigator.of(context).pop();
    PlaylistM3uImporter.showReviewDialog(
      context,
      parsedPlaylist: parsed,
      repository: widget.repository,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.all(tokens.spaceMd),
      child: AppSurface(
        withBlur: tokens.isGlass,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        color: tokens.surfaceElevated,
        border: Border.all(
          color: tokens.isGlass ? tokens.glassBorder : tokens.divider,
          width: 1.0,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 480.0,
            maxHeight: 520.0,
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                      ),
                      child: Icon(
                        Icons.file_upload_outlined,
                        color: tokens.accent,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: tokens.spaceSm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import M3U / Plain Text',
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
                            'Paste M3U content or tracklist ("Artist - Title")',
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 12.0,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: tokens.textMuted,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                SizedBox(height: tokens.spaceMd),

                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      color: tokens.textPrimary,
                      fontSize: 13.0,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Paste .m3u, .m3u8, or plain text track list here...\n\n'
                          'Example:\n'
                          '#EXTINF:254,Queen - Bohemian Rhapsody\n'
                          'queen.mp3\n\n'
                          'Or plain text:\n'
                          '1. The Beatles - Come Together (4:20)\n'
                          '2. Pink Floyd - Time [6:53]\n'
                          'Led Zeppelin - Stairway to Heaven',
                      hintStyle: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        color: tokens.textMuted,
                        fontSize: 12.0,
                        height: 1.4,
                      ),
                      filled: true,
                      fillColor: tokens.card,
                      contentPadding: const EdgeInsets.all(12.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        borderSide: BorderSide(color: tokens.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        borderSide: BorderSide(color: tokens.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        borderSide: BorderSide(color: tokens.accent, width: 1.5),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: tokens.spaceMd),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppPillButton(
                      label: 'Cancel',
                      variant: AppPillButtonVariant.ghost,
                      height: 38.0,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    SizedBox(width: tokens.spaceSm),
                    AppPillButton(
                      label: 'Parse & Review',
                      variant: AppPillButtonVariant.primary,
                      height: 38.0,
                      onPressed: _parseAndReview,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
