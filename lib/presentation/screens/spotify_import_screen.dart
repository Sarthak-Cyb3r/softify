import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/spotify_import.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../providers/spotify_import_providers.dart';
import '../providers/diversity_providers.dart';
import '../providers/shelf_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/shared/app_network_image.dart';
import 'playlist_detail_screen.dart';
import 'settings_screen.dart';

class SpotifyImportScreen extends ConsumerStatefulWidget {
  const SpotifyImportScreen({super.key});

  @override
  ConsumerState<SpotifyImportScreen> createState() =>
      _SpotifyImportScreenState();
}

class _SpotifyImportScreenState extends ConsumerState<SpotifyImportScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _alsoAddToLikedSongs = false;

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

  bool _isBatchImporting = false;
  String? _batchImportStatus;

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
    ref.invalidate(spotifyUserProfileProvider);
    ref.invalidate(spotifyUserPlaylistsProvider);
    ref.invalidate(spotifyUserTopTracksProvider);
    ref.invalidate(spotifyUserRecentlyPlayedProvider);
    ref.invalidate(spotifyUserTopArtistsProvider);
    ref.invalidate(spotifyUserSavedAlbumsProvider);
    ref.invalidate(homeShelvesProvider);
    if (!mounted) return;
    if (success) {
      // Automatically seed taste profile from connected Spotify account
      ref.read(coldStartSeederProvider).seedFromSpotifyAccount();
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
    ref.invalidate(spotifyUserProfileProvider);
    ref.invalidate(spotifyUserPlaylistsProvider);
    ref.invalidate(spotifyUserTopTracksProvider);
    ref.invalidate(spotifyUserRecentlyPlayedProvider);
    ref.invalidate(spotifyUserTopArtistsProvider);
    ref.invalidate(spotifyUserSavedAlbumsProvider);
    ref.invalidate(homeShelvesProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disconnected Spotify account.')),
    );
  }

  Future<void> _importAllPlaylists(List<SpotifyUserPlaylistSummary> playlists) async {
    if (playlists.isEmpty) return;
    setState(() {
      _isBatchImporting = true;
      _batchImportStatus = 'Starting batch import...';
    });

    try {
      final count = await ref
          .read(spotifyImportNotifierProvider.notifier)
          .batchImportUserPlaylists(
            playlists,
            onProgress: (done, total, name) {
              if (mounted) {
                setState(() {
                  _batchImportStatus = 'Importing $done of $total: "$name"...';
                });
              }
            },
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $count Spotify playlists into Softify!'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batch import error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBatchImporting = false;
          _batchImportStatus = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final importState = ref.watch(spotifyImportNotifierProvider);
    final notifier = ref.read(spotifyImportNotifierProvider.notifier);
    final audioHandler = ref.watch(audioHandlerProvider);
    final authState = ref.watch(spotifyAuthStateProvider);
    final isLoggedIn = authState.value?.isLoggedIn ?? false;
    final rawName = authState.value?.userName;
    final userName = (rawName != null && rawName.trim().isNotEmpty && rawName != 'null')
        ? rawName.trim()
        : 'Spotify User';

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
                      userName,
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
                  child: Text('Connected as $userName', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  Text(
                    'Paste any Spotify playlist, album, or track link to import instantly into Softify without ads, keys, or Premium.',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '💡 Tip: Free Spotify account? To import Liked Songs, open them in Spotify, press Ctrl+A, add to a playlist, and paste the link here.',
                    style: TextStyle(
                      color: tokens.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                    if (importState.errorMessage!.contains('Ctrl+A') ||
                        importState.errorMessage!.contains('429') ||
                        importState.errorMessage!.contains('rate limit')) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.surfaceHighlight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: tokens.accent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tip: In Spotify (web/desktop), open Liked Songs, press Ctrl+A, add them to a playlist, copy the link, and paste it into the URL bar above for 1-tap import without Premium.',
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
              isLoggedIn
                  ? _buildConnectedUserLibrary(tokens)
                  : _buildUnconnectedPrompt(tokens),
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
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(tokens.radiusSm),
                            onTap: () {
                              setState(() {
                                _alsoAddToLikedSongs = !_alsoAddToLikedSongs;
                              });
                            },
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _alsoAddToLikedSongs,
                                    activeColor: tokens.accent,
                                    checkColor: Colors.black,
                                    onChanged: (val) {
                                      setState(() {
                                        _alsoAddToLikedSongs = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Also mark all tracks as Liked (add to Favorites)',
                                    style: TextStyle(
                                      color: tokens.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
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
                                        await notifier.commitImportToLibrary(
                                      alsoAddToFavorites: _alsoAddToLikedSongs,
                                    );
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
                      ],
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
              child: AppNetworkImage(
                imageUrl: playlist.coverUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                placeholderIcon: Icons.music_note,
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

  Widget _buildConnectedUserLibrary(AppTokens tokens) {
    final userPlaylistsAsync = ref.watch(spotifyUserPlaylistsProvider);
    final userProfileAsync = ref.watch(spotifyUserProfileProvider);

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          if (_isBatchImporting)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(tokens.radiusCard),
                border: Border.all(color: tokens.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: tokens.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _batchImportStatus ?? 'Importing playlists...',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // User Profile Card
          userProfileAsync.when(
            data: (profile) {
              if (profile == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                  border: Border.all(color: tokens.surfaceHighlight),
                ),
                child: Row(
                  children: [
                    if (profile.avatarUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AppNetworkImage(
                          imageUrl: profile.avatarUrl!,
                          width: 40,
                          height: 40,
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: tokens.accent,
                        child: Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.displayName,
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tokens.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                                ),
                                child: Text(
                                  profile.isPremium ? 'PREMIUM' : 'CONNECTED',
                                  style: TextStyle(
                                    color: tokens.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (profile.email != null)
                            Text(
                              profile.email!,
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Disconnect Account',
                      icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                      onPressed: _disconnectSpotify,
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Liked Songs Quick Import Tile
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF450af5).withValues(alpha: 0.35),
                  const Color(0xFF8e8ee5).withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(tokens.radiusCard),
              border: Border.all(
                color: const Color(0xFF450af5).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF450af5), Color(0xFF8e8ee5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Liked Songs',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sync via Web API (or paste playlist link above if on Free plan)',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    ref.read(spotifyImportNotifierProvider.notifier).loadUserLikedSongs();
                  },
                  child: const Text(
                    'Import',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Quick Spotify Mixes Row (Top Tracks & Recent Streams)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                    onTap: () {
                      ref.read(spotifyImportNotifierProvider.notifier).loadUserTopTracksAsPlaylist();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.card,
                        borderRadius: BorderRadius.circular(tokens.radiusCard),
                        border: Border.all(color: tokens.surfaceHighlight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(tokens.radiusSm),
                            ),
                            child: const Icon(Icons.whatshot_rounded, color: Colors.orange, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Heavy Rotation',
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Top tracks',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                    onTap: () {
                      ref.read(spotifyImportNotifierProvider.notifier).loadUserRecentlyPlayedAsPlaylist();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.card,
                        borderRadius: BorderRadius.circular(tokens.radiusCard),
                        border: Border.all(color: tokens.surfaceHighlight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(tokens.radiusSm),
                            ),
                            child: const Icon(Icons.history_rounded, color: Colors.teal, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recent Streams',
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Recently played',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Playlists Header
          userPlaylistsAsync.when(
            data: (playlists) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Playlists (${playlists.length})',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.fontDisplay,
                        ),
                      ),
                      if (playlists.isNotEmpty)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: tokens.accent,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Import All', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _isBatchImporting
                              ? null
                              : () => _importAllPlaylists(playlists),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (playlists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No playlists found in your Spotify account.',
                          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...playlists.map((playlist) => _buildUserPlaylistTile(playlist, tokens)),
                ],
              );
            },
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: tokens.accent, strokeWidth: 2),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Failed to load playlists: $err',
                  style: TextStyle(color: tokens.error, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPlaylistTile(
    SpotifyUserPlaylistSummary playlist,
    AppTokens tokens,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.surfaceHighlight),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: playlist.coverUrl != null
                ? AppNetworkImage(
                    imageUrl: playlist.coverUrl!,
                    width: 48,
                    height: 48,
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: tokens.surfaceHighlight,
                    child: Icon(Icons.music_note, color: tokens.textMuted, size: 24),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${playlist.trackCount} tracks • ${playlist.ownerName ?? 'Spotify'}',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.accent,
              side: BorderSide(color: tokens.accent.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radiusPill),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              ref.read(spotifyImportNotifierProvider.notifier).loadUserPlaylist(playlist);
            },
            child: const Text('Import', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildUnconnectedPrompt(AppTokens tokens) {
    return Expanded(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.accent.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Icon(
                  Icons.sync,
                  size: 36,
                  color: tokens.accent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Connect Your Spotify',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppTheme.fontDisplay,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Link your Spotify account to extract authentic metadata directly through Spotify and import your personal playlists and liked songs into Softify with zero ads or limits.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                  ),
                ),
                icon: const Icon(Icons.account_circle, size: 20),
                label: const Text(
                  'Connect Spotify Account',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _connectSpotify,
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              Text(
                'Or paste any public Spotify playlist URL in the search field above.',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
