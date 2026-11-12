import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Consumer-friendly update changelog modal sheet.
/// Explains new features and enhancements in simple, easy-to-understand language
/// while using Apple Music / Liquid Glass aesthetics.
class UpdateChangelogSheet extends StatelessWidget {
  final String version;

  const UpdateChangelogSheet({
    super.key,
    this.version = '4.0.2',
  });

  /// Displays the changelog modal sheet.
  static Future<void> show(BuildContext context, {String version = '4.0.2'}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => UpdateChangelogSheet(version: version),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = tokens.accent;
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.88;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: maxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.isGlass ? const Color(0xE8121614) : tokens.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: tokens.isGlass ? accent.withValues(alpha: 0.35) : const Color(0x22FFFFFF),
              width: 1,
            ),
            boxShadow: [
              const BoxShadow(
                color: Color(0x66000000),
                blurRadius: 28,
                offset: Offset(0, -6),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Drag Pill
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent,
                                  Color.lerp(accent, const Color(0xFF00E676), 0.4) ?? accent,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFF0A120E),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'What\'s New',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: accent.withValues(alpha: 0.45),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        'v$version',
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Spotify account sync, pure studio audio & high-res art',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    const Divider(color: Color(0x1FFFFFFF), height: 1),

                    // Scrollable Items List
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        children: [
                          _buildChangelogCard(
                            context: context,
                            icon: Icons.keyboard_rounded,
                            iconColor: const Color(0xFF69F0AE),
                            title: 'Zero-Conflict Desktop Shortcuts',
                            description:
                                'Typing "k", "j", "m", or arrow keys in search bars, playlist editors, and text fields now never triggers song skips or mutes. Hotkeys are automatically suspended during typing.',
                            badge: 'Linux / Desktop',
                          ),
                          _buildChangelogCard(
                            context: context,
                            icon: Icons.track_changes_rounded,
                            iconColor: const Color(0xFF40C4FF),
                            title: 'Precision Audio Match & Anti-Mismatch',
                            description:
                                'Fixed wrong song stream resolution. Dual-catalog strict artist, title, and duration validation ensures you always hear the exact song selected with instant YouTube Music fallback.',
                            badge: 'Stream Engine',
                          ),
                          _buildChangelogCard(
                            context: context,
                            icon: Icons.sync_alt_rounded,
                            iconColor: const Color(0xFF1DB954),
                            title: 'Spotify Library & Playlists Import',
                            description:
                                'Connect your Spotify account with 1-tap PKCE login to view and import your Liked Songs and personal playlists directly into Softify.',
                            badge: 'Spotify Sync',
                          ),
                          _buildChangelogCard(
                            context: context,
                            icon: Icons.album_rounded,
                            iconColor: const Color(0xFF40C4FF),
                            title: 'High-Resolution Spotify Metadata',
                            description:
                                'Track titles, verified artists, albums, and authentic 640x640 album covers are borrowed directly from Spotify, eliminating low-res video thumbnails.',
                            badge: 'Metadata',
                          ),
                          _buildChangelogCard(
                            context: context,
                            icon: Icons.verified_rounded,
                            iconColor: const Color(0xFF69F0AE),
                            title: 'Studio Audio & Anti-Remix Shield',
                            description:
                                'Strict studio audio matching rejects unwanted remixes, covers, lofi, and karaoke cuts, preserving authentic 320 Kbps studio master playback.',
                            badge: 'Audio Engine',
                          ),
                          _buildChangelogCard(
                            context: context,
                            icon: Icons.graphic_eq_rounded,
                            iconColor: const Color(0xFF4EDEA3),
                            title: 'Real-Time Audio Quality Switching',
                            description:
                                'Switch between High (320kbps), Standard (160kbps), and Data Saver (96kbps) with instant hot-swapping and cellular bandwidth savings.',
                            badge: 'Audio Engine',
                          ),
                          _buildChangelogCard(
                            context: context,
                            icon: Icons.translate_rounded,
                            iconColor: const Color(0xFF40C4FF),
                            title: 'Language-Personalized Moods',
                            description:
                                'Mood shelves automatically learn your listening language (Hindi, Punjabi, Tamil, Spanish, etc.) and bring songs in your favorite regional sounds.',
                            badge: 'Taste Engine',
                          ),
                          _buildChangelogCard(
                            context: context,
                            icon: Icons.subtitles_rounded,
                            iconColor: const Color(0xFFFFB74D),
                            title: 'Kinetic Synced Lyrics',
                            description:
                                'Synchronized karaoke lyrics track along with every beat with multi-catalog fallback to prevent plain text lyrics.',
                            badge: 'Lyrics',
                          ),
                        ],
                      ),
                    ),

                    // Bottom Dismiss Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: const Color(0xFF09140E),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Got It, Let\'s Play!',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChangelogCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String badge,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x14FFFFFF),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFBAC5BE),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
