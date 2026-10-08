import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/spotify_import.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../providers/spotify_import_providers.dart';
import '../theme/app_theme.dart';
import 'playlist_detail_screen.dart';

class SpotifyImportScreen extends ConsumerStatefulWidget {
  const SpotifyImportScreen({super.key});

  @override
  ConsumerState<SpotifyImportScreen> createState() =>
      _SpotifyImportScreenState();
}

class _SpotifyImportScreenState extends ConsumerState<SpotifyImportScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _urlController.text = data.text!.trim();
      ref
          .read(spotifyImportNotifierProvider.notifier)
          .setInputUrl(data.text!.trim());
    }
  }

  void _onLoadTapped() {
    FocusScope.of(context).unfocus();
    ref
        .read(spotifyImportNotifierProvider.notifier)
        .loadAndMatchPlaylist(_urlController.text);
  }

  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(spotifyImportNotifierProvider);
    final notifier = ref.read(spotifyImportNotifierProvider.notifier);
    final audioHandler = ref.watch(audioHandlerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF1DB954), // Spotify Green
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.music_note,
                color: Colors.black,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Spotify Importer',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top input section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paste a public Spotify playlist link or URI to import tracks into Softify without ads or keys.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'https://open.spotify.com/playlist/...',
                            hintStyle: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceElevated,
                            prefixIcon: const Icon(
                              Icons.link,
                              color: Color(0xFF1DB954),
                              size: 20,
                            ),
                            suffixIcon: _urlController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.white54,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _urlController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {});
                            notifier.setInputUrl(val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Paste from Clipboard',
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.surfaceElevated,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.content_paste,
                          color: Color(0xFF1DB954),
                          size: 20,
                        ),
                        onPressed: _pasteFromClipboard,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: importState.status ==
                                  SpotifyImportStatus.fetchingPlaylist ||
                              importState.status ==
                                  SpotifyImportStatus.matchingTracks ||
                              importState.status ==
                                  SpotifyImportStatus.importingToDb
                          ? null
                          : _onLoadTapped,
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text(
                        'Fetch & Match Playlist',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Loading / Matching Status bar
            if (importState.status == SpotifyImportStatus.fetchingPlaylist)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1DB954),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        importState.fetchProgress > 0
                            ? 'Loaded ${importState.fetchProgress} tracks\u2026'
                            : 'Connecting to Spotify & extracting tracks...',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            if (importState.status == SpotifyImportStatus.matchingTracks)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Matching studio tracks: ${importState.matchedProgress} / ${importState.totalToMatch}',
                          style: const TextStyle(
                            color: Color(0xFF1DB954),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${((importState.matchedProgress / (importState.totalToMatch == 0 ? 1 : importState.totalToMatch)) * 100).round()}%',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: importState.totalToMatch == 0
                          ? 0.0
                          : importState.matchedProgress /
                              importState.totalToMatch,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF1DB954),
                      ),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              ),

            // Error display
            if (importState.errorMessage != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        importState.errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Non-fatal notice (e.g. Web API rate-limited, embed fallback used)
            if (importState.playlist?.notice != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        importState.playlist!.notice!,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Playlist Content
            if (importState.playlist != null)
              Expanded(
                child: Column(
                  children: [
                    // Header card
                    _buildPlaylistHeaderCard(importState.playlist!),
                    const Divider(height: 1, color: Colors.white12),

                    // Track match list
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: importState.playlist!.tracks.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Colors.white10),
                        itemBuilder: (context, index) {
                          final item = importState.playlist!.tracks[index];
                          return _buildTrackRow(
                            item: item,
                            index: index,
                            audioHandler: audioHandler,
                            notifier: notifier,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            else if (importState.status == SpotifyImportStatus.idle)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.playlist_play,
                          size: 48,
                          color: Color(0xFF1DB954),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Ready to Import',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Paste any public Spotify playlist URL above\nto stream and save your songs offline.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomSheet: (importState.playlist != null &&
              importState.status != SpotifyImportStatus.matchingTracks &&
              importState.status != SpotifyImportStatus.fetchingPlaylist)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceElevated,
                border: Border(
                  top: BorderSide(color: Colors.white12, width: 0.5),
                ),
              ),
              child: importState.status == SpotifyImportStatus.importedSuccess
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1DB954),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              final matchedTracks = importState.playlist?.tracks
                                  .where((t) => t.isMatched && t.matchedTrack != null)
                                  .map((t) => t.matchedTrack!)
                                  .toList();
                              if (matchedTracks != null && matchedTracks.isNotEmpty) {
                                ref.read(audioHandlerProvider).setQueue(matchedTracks);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Playing "${importState.playlist!.name}"!'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.play_arrow, size: 22),
                            label: const Text(
                              'Play Now',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (importState.importedPlaylistId != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textPrimary,
                                side: const BorderSide(color: Colors.white30),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlaylistDetailScreen(
                                      playlistId: importState.importedPlaylistId!,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.queue_music, size: 20),
                              label: const Text(
                                'View Playlist',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: importState.status ==
                                SpotifyImportStatus.importingToDb
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(context);
                                final playlistId =
                                    await notifier.commitImportToLibrary();
                                if (!mounted) return;
                                if (playlistId != null) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF1DB954),
                                      content: Text(
                                        'Imported "${importState.playlist!.name}" into your Library!',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      action: SnackBarAction(
                                        label: 'CLOSE',
                                        textColor: Colors.black,
                                        onPressed: () => nav.pop(),
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: importState.status ==
                                SpotifyImportStatus.importingToDb
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.playlist_add_check, size: 22),
                        label: Text(
                          importState.status ==
                                  SpotifyImportStatus.importedSuccess
                              ? 'Imported! (Save Again)'
                              : 'Import ${importState.playlist!.matchedCount} Tracks to Library',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
            )
          : null,
    );
  }

  Widget _buildPlaylistHeaderCard(SpotifyImportPlaylist playlist) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.surfaceElevated,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 64,
              height: 64,
              color: Colors.white10,
              child: playlist.coverUrl != null
                  ? Image.network(
                      playlist.coverUrl!,
                      width: 64,
                      height: 64,
                      cacheWidth: 150,
                      cacheHeight: 150,
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.music_note,
                        color: Color(0xFF1DB954),
                        size: 32,
                      ),
                    )
                  : const Icon(
                      Icons.music_note,
                      color: Color(0xFF1DB954),
                      size: 32,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (playlist.description != null &&
                    playlist.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      playlist.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF1DB954),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${playlist.matchedCount} / ${playlist.totalCount} Matched (${playlist.matchPercentage.round()}%)',
                        style: const TextStyle(
                          color: Color(0xFF1DB954),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackRow({
    required SpotifyTrackItem item,
    required int index,
    required dynamic audioHandler,
    required SpotifyImportNotifier notifier,
  }) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    if (item.isMatched) {
      if (item.confidence >= 0.80) {
        badgeColor = const Color(0xFF1DB954);
        badgeIcon = Icons.check_circle;
        badgeText = 'Matched';
      } else {
        badgeColor = Colors.amber;
        badgeIcon = Icons.warning_amber_rounded;
        badgeText = 'Review (${(item.confidence * 100).round()}%)';
      }
    } else {
      badgeColor = Colors.white38;
      badgeIcon = Icons.help_outline;
      badgeText = 'Unresolved';
    }

    return Padding(
      key: ValueKey(item.spotifyUri.isNotEmpty ? item.spotifyUri : 'track_$index'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Index number
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Track Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (item.matchedTrack != null &&
                    item.matchedTrack!.title.toLowerCase() !=
                        item.title.toLowerCase())
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '→ Matched: "${item.matchedTrack!.title}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: badgeColor.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Confidence Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, color: badgeColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Preview Play Button (if matched)
          if (item.matchedTrack != null)
            IconButton(
              tooltip: 'Preview Audio',
              icon: const Icon(
                Icons.play_circle_outline,
                color: Color(0xFF1DB954),
                size: 22,
              ),
              onPressed: () {
                audioHandler.setQueue([item.matchedTrack!]);
                audioHandler.play();
              },
            ),

          // Change / Manual Search Match
          IconButton(
            tooltip: 'Change Match',
            icon: const Icon(
              Icons.edit_outlined,
              color: Colors.white54,
              size: 18,
            ),
            onPressed: () => _showManualMatchDialog(context, item, index, notifier),
          ),
        ],
      ),
    );
  }

  void _showManualMatchDialog(
    BuildContext context,
    SpotifyTrackItem item,
    int index,
    SpotifyImportNotifier notifier,
  ) {
    final searchCtrl = TextEditingController(text: '${item.title} ${item.artist}');
    final catalog = ref.read(catalogRepositoryProvider);
    List<Track> candidateResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            void performSearch() async {
              setSheetState(() => isSearching = true);
              try {
                final results = await catalog.search(searchCtrl.text, limit: 10);
                setSheetState(() {
                  candidateResults = results;
                  isSearching = false;
                });
              } catch (_) {
                setSheetState(() => isSearching = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Match for "${item.title}"',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search alternative track...',
                              filled: true,
                              fillColor: AppTheme.background,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => performSearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: performSearch,
                          child: const Text('Search'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isSearching)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                        ),
                      )
                    else
                      Expanded(
                        child: candidateResults.isEmpty
                            ? const Center(
                                child: Text(
                                  'Tap Search to query studio and production tracks.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                                itemCount: candidateResults.length,
                                itemBuilder: (ctx, candIdx) {
                                  final cand = candidateResults[candIdx];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      cand.title,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      cand.artist,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: TextButton(
                                      child: const Text(
                                        'SELECT',
                                        style: TextStyle(
                                          color: Color(0xFF1DB954),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () {
                                        notifier.updateTrackMatch(index, cand);
                                        Navigator.pop(sheetContext);
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
