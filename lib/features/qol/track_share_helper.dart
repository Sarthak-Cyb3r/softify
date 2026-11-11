import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/track.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/shared/app_network_image.dart';
import '../../presentation/widgets/shared/app_surface.dart';
import '../../presentation/widgets/shared/app_toast.dart';

/// Quality-of-Life helper for rich 1-tap track sharing, link extraction,
/// and system clipboard actions.
class TrackShareHelper {
  static const MethodChannel _shareChannel =
      MethodChannel('com.softify/share_intent');

  /// Formats track representation as `"Title" by Artist`.
  static String getTrackInfo(Track track) {
    final title = track.title.trim();
    final artist = track.artist.trim();
    return '"$title" by $artist';
  }

  /// Extracts the canonical Spotify link if available on the track.
  static String? getSpotifyLink(Track track) {
    String? rawId;
    if (track.id.startsWith('spotify:track:')) {
      rawId = track.id.substring('spotify:track:'.length);
    } else if (track.sourceId.startsWith('spotify:track:')) {
      rawId = track.sourceId.substring('spotify:track:'.length);
    } else if (track.id.startsWith('spotify_')) {
      final candidate = track.id.substring('spotify_'.length);
      if (!candidate.contains('_') && candidate.isNotEmpty) {
        rawId = candidate;
      }
    } else if (track.sourceId.startsWith('spotify_')) {
      final candidate = track.sourceId.substring('spotify_'.length);
      if (!candidate.contains('_') && candidate.isNotEmpty) {
        rawId = candidate;
      }
    }

    if (rawId != null && rawId.isNotEmpty) {
      return 'https://open.spotify.com/track/$rawId';
    }
    return null;
  }

  /// Resolves the canonical YouTube / YouTube Music link or fallback search URL.
  static String getYoutubeLink(Track track) {
    String rawId = '';
    if (track.id.startsWith('yt_')) {
      rawId = track.id.replaceFirst('yt_', '');
    } else if (track.sourceId.startsWith('yt_')) {
      rawId = track.sourceId.replaceFirst('yt_', '');
    } else if (track.id.length == 11 && !track.id.contains(' ')) {
      rawId = track.id;
    } else if (track.sourceId.length == 11 && !track.sourceId.contains(' ')) {
      rawId = track.sourceId;
    }

    if (rawId.isNotEmpty) {
      return 'https://music.youtube.com/watch?v=$rawId';
    }
    return 'https://music.youtube.com/search?q=${Uri.encodeComponent('${track.artist} - ${track.title}')}';
  }

  /// Returns the best available web link for the track.
  static String getShareLink(Track track) {
    final spotifyLink = getSpotifyLink(track);
    if (spotifyLink != null) {
      return spotifyLink;
    }
    return getYoutubeLink(track);
  }

  /// Copies `"Title" by Artist` to system clipboard and shows a sleek SnackBar / toast.
  static Future<void> copyTrackInfoToClipboard(
    BuildContext context,
    Track track,
  ) async {
    HapticFeedback.lightImpact();
    final text = getTrackInfo(track);
    await Clipboard.setData(ClipboardData(text: text));

    if (context.mounted) {
      AppToast.show(
        context,
        message: 'Copied: $text',
        icon: const Icon(
          Icons.copy_rounded,
          color: AppTheme.accent,
          size: 18.0,
        ),
      );
    }
  }

  /// Copies Spotify / YouTube link if available and displays a sleek SnackBar / toast.
  static Future<void> copyShareLink(
    BuildContext context,
    Track track,
  ) async {
    HapticFeedback.lightImpact();
    final link = getShareLink(track);
    await Clipboard.setData(ClipboardData(text: link));

    if (context.mounted) {
      final isSpotify = link.contains('open.spotify.com');
      AppToast.show(
        context,
        message: '${isSpotify ? 'Spotify' : 'YouTube'} link copied to clipboard',
        icon: const Icon(
          Icons.link_rounded,
          color: AppTheme.accent,
          size: 18.0,
        ),
      );
    }
  }

  /// Dispatches a native System Intent share sheet, falling back to clipboard copy.
  static Future<void> shareViaSystemIntent(
    BuildContext context,
    Track track,
  ) async {
    HapticFeedback.selectionClick();
    final info = getTrackInfo(track);
    final link = getShareLink(track);
    final fullShareText = '$info\n$link';

    bool intentLaunched = false;
    if (Platform.isAndroid) {
      try {
        final result = await _shareChannel.invokeMethod<bool>('shareText', {
          'text': fullShareText,
          'subject': info,
        });
        intentLaunched = result == true;
      } catch (_) {
        intentLaunched = false;
      }
    }

    if (!intentLaunched) {
      await Clipboard.setData(ClipboardData(text: fullShareText));
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'Track info & link copied to clipboard',
          icon: const Icon(
            Icons.share_rounded,
            color: AppTheme.accent,
            size: 18.0,
          ),
        );
      }
    }
  }

  /// Shows the rich 1-Tap Share Bottom Sheet with clipboard and system intent options.
  static Future<void> showShareModal(
    BuildContext context,
    Track track,
  ) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => _TrackShareModalContent(
        parentContext: context,
        track: track,
      ),
    );
  }
}

class _TrackShareModalContent extends StatelessWidget {
  final BuildContext parentContext;
  final Track track;

  const _TrackShareModalContent({
    required this.parentContext,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textInfo = TrackShareHelper.getTrackInfo(track);
    final spotifyLink = TrackShareHelper.getSpotifyLink(track);
    final ytLink = TrackShareHelper.getYoutubeLink(track);
    final primaryLink = TrackShareHelper.getShareLink(track);

    return AppSurface(
      withBlur: true,
      color: tokens.isGlass ? tokens.glassSurface : tokens.surfaceElevated,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: tokens.isGlass
          ? Border(
              top: BorderSide(color: tokens.glassBorder, width: 1.0),
              left: BorderSide(color: tokens.glassBorder, width: 1.0),
              right: BorderSide(color: tokens.glassBorder, width: 1.0),
            )
          : null,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spaceMd,
            tokens.spaceSm,
            tokens.spaceMd,
            tokens.spaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Track Header
              Container(
                padding: EdgeInsets.all(tokens.spaceSm + 2),
                decoration: BoxDecoration(
                  color: tokens.isGlass
                      ? tokens.glass
                      : tokens.surfaceHighlight.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                  border: Border.all(
                    color: tokens.divider,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      child: AppNetworkImage(
                        imageUrl: track.coverUrl,
                        width: 48,
                        height: 48,
                        cacheWidth: 144,
                        cacheHeight: 144,
                        fit: BoxFit.cover,
                        placeholderIcon: Icons.music_note_rounded,
                      ),
                    ),
                    SizedBox(width: tokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontUi,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: tokens.spaceMd),

              // Option 1: Copy Title & Artist
              _buildActionTile(
                context: context,
                icon: Icons.copy_rounded,
                title: 'Copy Title & Artist',
                subtitle: textInfo,
                onTap: () {
                  Navigator.of(context).pop();
                  TrackShareHelper.copyTrackInfoToClipboard(
                    parentContext.mounted ? parentContext : context,
                    track,
                  );
                },
              ),

              const SizedBox(height: 8),

              // Option 2: Copy Link
              _buildActionTile(
                context: context,
                icon: Icons.link_rounded,
                title: 'Copy Link',
                subtitle: primaryLink,
                onTap: () {
                  Navigator.of(context).pop();
                  TrackShareHelper.copyShareLink(
                    parentContext.mounted ? parentContext : context,
                    track,
                  );
                },
              ),

              // Option 2b: If Spotify and YouTube links are both available, offer the other link too
              if (spotifyLink != null && ytLink != primaryLink) ...[
                const SizedBox(height: 8),
                _buildActionTile(
                  context: context,
                  icon: Icons.smart_display_outlined,
                  title: 'Copy YouTube Music Link',
                  subtitle: ytLink,
                  onTap: () async {
                    Navigator.of(context).pop();
                    HapticFeedback.lightImpact();
                    await Clipboard.setData(ClipboardData(text: ytLink));
                    final targetCtx =
                        parentContext.mounted ? parentContext : context;
                    if (targetCtx.mounted) {
                      AppToast.show(
                        targetCtx,
                        message: 'YouTube Music link copied',
                        icon: const Icon(
                          Icons.link_rounded,
                          color: AppTheme.accent,
                          size: 18.0,
                        ),
                      );
                    }
                  },
                ),
              ],

              const SizedBox(height: 8),

              // Option 3: Share via System Intent
              _buildActionTile(
                context: context,
                icon: Icons.share_rounded,
                title: 'Share via System Intent',
                subtitle: 'Send to apps, chats, or social media',
                onTap: () {
                  Navigator.of(context).pop();
                  TrackShareHelper.shareViaSystemIntent(
                    parentContext.mounted ? parentContext : context,
                    track,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        splashColor: tokens.accent.withValues(alpha: 0.12),
        highlightColor: tokens.accent.withValues(alpha: 0.06),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spaceMd,
            vertical: tokens.spaceSm + 4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radiusCard),
            border: Border.all(
              color: tokens.divider,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tokens.isGlass
                      ? tokens.glass
                      : tokens.surfaceHighlight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
                child: Icon(
                  icon,
                  color: tokens.accent,
                  size: 20,
                ),
              ),
              SizedBox(width: tokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: tokens.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
