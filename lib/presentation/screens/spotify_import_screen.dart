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

  Future<void> _connectSpotify() async {
    final authService = ref.read(spotifyAuthServiceProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening browser to connect Spotify account...'),
        duration: Duration(seconds: 4),
      ),
    );
    final success = await authService.login();
    ref.invalidate(spotifyAuthStateProvider);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully connected to Spotify!'),
          backgroundColor: AppTheme.accent,
        ),
      );
      if (_urlController.text.isNotEmpty) {
        _onLoadTapped();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spotify connection was canceled or timed out.'),
        ),
      );
    }
  }

  Future<void> _disconnectSpotify() async {
    final authService = ref.read(spotifyAuthServiceProvider);
    await authService.logout();
    ref.invalidate(spotifyAuthStateProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disconnected Spotify account.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final importState = ref.watch(spotifyImportNotifierProvider);
    final notifier = ref.read(spotifyImportNotifierProvider.notifier);
    final audioHandler = ref.watch(audioHandlerProvider);
    final authState = ref.watch(spotifyAuthStateProvider);
    final isLoggedIn = authState.value?.isLoggedIn ?? false;
    final userName = authState.value?.userName;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: tokens.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.music_note,
                color: Colors.black,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Spotify Playlist Importer',
              style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          if (isLoggedIn)
            PopupMenuButton<String>(
              tooltip: 'Spotify Account ($userName)',
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  border: Border.all(color: tokens.accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: tokens.accent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      userName ?? 'Linked',
                      style: TextStyle(color: tokens.accent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              onSelected: (val) {
                if (val == 'disconnect') _disconnectSpotify();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text('Connected as ${userName ?? "User"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'disconnect',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Disconnect Spotify', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            )
          else
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: tokens.accent,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.account_circle_outlined, size: 18),
              label: const Text('Connect', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              onPressed: _connectSpotify,
            ),
        ],
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
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'https://open.spotify.com/playlist/...',
                            hintStyle: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: tokens.card,
                            prefixIcon: Icon(
                              Icons.link,
                              color: tokens.accent,
                              size: 20,
                            ),
                            suffixIcon: _urlController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: tokens.textSecondary,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _urlController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusCard),
                              borderSide: BorderSide(
                                color: tokens.surfaceHighlight,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusCard),
                              borderSide: BorderSide(
                                color: tokens.surfaceHighlight,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusCard),
                              borderSide: BorderSide(
                                color: tokens.accent,
                                width: 1.5,
                              ),
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
                          backgroundColor: tokens.card,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusCard),
                            side: BorderSide(color: tokens.surfaceHighlight),
                          ),
                        ),
                        icon: Icon(
                          Icons.content_paste,
                          color: tokens.accent,
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
                        backgroundColor: tokens.accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusPill),
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
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        importState.fetchProgress > 0
                            ? 'Loaded ${importState.fetchProgress} tracks\u2026'
                            : 'Connecting to Spotify & extracting tracks...',
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 13),
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
                          style: TextStyle(
                            color: tokens.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${((importState.matchedProgress / (importState.totalToMatch == 0 ? 1 : importState.totalToMatch)) * 100).round()}%',
                          style: AppTheme.tabularTimestamp(
                            color: tokens.textSecondary,
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
                      backgroundColor: tokens.surfaceHighlight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        tokens.accent,
                      ),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
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
                  color: tokens.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                  border: Border.all(color: tokens.error.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: tokens.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        importState.errorMessage!,
                        style: TextStyle(
                          color: tokens.error,
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
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.info_outline, color: Colors.amber, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            importState.playlist!.notice!,
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isLoggedIn) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: tokens.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.login, size: 16),
                          label: const Text('Connect Spotify Account'),
                          onPressed: _connectSpotify,
                        ),
                      ),
                    ],
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
                        decoration: BoxDecoration(
                          color: tokens.card,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.playlist_play,
                          size: 48,
                          color: tokens.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ready to Import',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Paste any public Spotify playlist URL above\nto stream and save your songs offline.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tokens.textSecondary,
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
              decoration: BoxDecoration(
                color: tokens.surfaceElevated,
                border: Border(
                  top: BorderSide(color: tokens.divider, width: 0.5),
                ),
              ),
              child: importState.status == SpotifyImportStatus.importedSuccess
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tokens.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(tokens.radiusPill),
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
                                foregroundColor: tokens.textPrimary,
                                side: BorderSide(color: tokens.surfaceHighlight),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(tokens.radiusPill),
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
                          backgroundColor: tokens.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusPill),
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
                                      backgroundColor: tokens.surfaceElevated,
                                      content: Text(
                                        'Imported "${importState.playlist!.name}" into your Library!',
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      action: SnackBarAction(
                                        label: 'CLOSE',
                                        textColor: tokens.accent,
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
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: tokens.card,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusCard),
            child: Container(
              width: 64,
              height: 64,
              color: tokens.surfaceElevated,
              child: playlist.coverUrl != null
                  ? Image.network(
                      playlist.coverUrl!,
                      width: 64,
                      height: 64,
                      cacheWidth: 150,
                      cacheHeight: 150,
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.music_note,
                        color: tokens.accent,
                        size: 32,
                      ),
                    )
                  : Icon(
                      Icons.music_note,
                      color: tokens.accent,
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
                  style: TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    color: tokens.textPrimary,
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
                      style: TextStyle(
                        color: tokens.textSecondary,
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
                        color: tokens.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(tokens.radiusCard),
                        border: Border.all(
                          color: tokens.accent.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${playlist.matchedCount} / ${playlist.totalCount} Matched (${playlist.matchPercentage.round()}%)',
                        style: TextStyle(
                          color: tokens.accent,
                          fontSize: 12,
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
    final tokens = context.tokens;
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    if (item.isMatched) {
      if (item.confidence >= 0.80) {
        badgeColor = tokens.accent;
        badgeIcon = Icons.check_circle;
        badgeText = 'Matched';
      } else {
        badgeColor = Colors.amber;
        badgeIcon = Icons.warning_amber_rounded;
        badgeText = 'Review (${(item.confidence * 100).round()}%)';
      }
    } else {
      badgeColor = tokens.textMuted;
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
              style: AppTheme.tabularTimestamp(
                color: tokens.textSecondary,
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
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
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
                        fontSize: 12,
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
              borderRadius: BorderRadius.circular(tokens.radiusCard),
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
                    fontSize: 12,
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
              icon: Icon(
                Icons.play_circle_outline,
                color: tokens.accent,
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
            icon: Icon(
              Icons.edit_outlined,
              color: tokens.textSecondary,
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
    final tokens = context.tokens;
    final searchCtrl = TextEditingController(text: '${item.title} ${item.artist}');
    final catalog = ref.read(catalogRepositoryProvider);
    List<Track> candidateResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusCard)),
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
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        color: tokens.textPrimary,
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
                            style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search alternative track...',
                              hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                              filled: true,
                              fillColor: tokens.background,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(tokens.radiusCard),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => performSearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusPill),
                            ),
                          ),
                          onPressed: performSearch,
                          child: const Text('Search'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isSearching)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: tokens.accent),
                        ),
                      )
                    else
                      Expanded(
                        child: candidateResults.isEmpty
                            ? Center(
                                child: Text(
                                  'Tap Search to query studio and production tracks.',
                                  style: TextStyle(color: tokens.textMuted, fontSize: 13),
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
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      cand.artist,
                                      style: TextStyle(
                                        color: tokens.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: TextButton(
                                      child: Text(
                                        'SELECT',
                                        style: TextStyle(
                                          color: tokens.accent,
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
