import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'bouncing_scale_button.dart';

/// Data model representing a changelog item in the update showcase.
class _ChangelogItem {
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final Color iconColor;
  final String? highlightTag;

  const _ChangelogItem({
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.iconColor,
    this.highlightTag,
  });
}

/// Consumer-friendly update changelog modal sheet.
/// Designed with Apple Music / Liquid Glass aesthetics, interactive category filters,
/// frosted glass cards, and tactile animations.
class UpdateChangelogSheet extends StatefulWidget {
  final String version;

  const UpdateChangelogSheet({
    super.key,
    this.version = '4.0.0',
  });

  /// Displays the changelog modal sheet.
  static Future<void> show(BuildContext context, {String version = '4.0.0'}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => UpdateChangelogSheet(version: version),
    );
  }

  @override
  State<UpdateChangelogSheet> createState() => _UpdateChangelogSheetState();
}

class _UpdateChangelogSheetState extends State<UpdateChangelogSheet> {
  String _selectedCategory = 'All';

  static const List<_ChangelogItem> _items = [
    _ChangelogItem(
      title: 'Accurate Audio Matching',
      description:
          'Track matching is now powered by strict phonetics, subtitle parsing, and song-title integrity checks — eliminating incorrect cover versions on movie soundtracks.',
      category: 'Audio',
      icon: Icons.graphic_eq_rounded,
      iconColor: Color(0xFF4EDEA3),
      highlightTag: 'Engine',
    ),
    _ChangelogItem(
      title: 'Apple Music Style Player',
      description:
          'Switch seamlessly between Softify Classic and modern Apple Music style player with a floating bottom control dock, repeat toggle, and fluid volume slider.',
      category: 'UI/UX',
      icon: Icons.music_note_rounded,
      iconColor: Color(0xFFFF375F),
      highlightTag: 'Featured',
    ),
    _ChangelogItem(
      title: 'Living Motion Album Artwork',
      description:
          'Album covers now come alive with high-definition video motion artwork extracted straight from music catalogs that loop seamlessly while you listen.',
      category: 'Visuals',
      icon: Icons.movie_filter_rounded,
      iconColor: Color(0xFF40C4FF),
      highlightTag: 'Living Art',
    ),
    _ChangelogItem(
      title: 'Multi-Provider Lyrics Engine',
      description:
          'Lyrics now fetch across multiple global sources with multi-artist and subtitle extraction, providing rich synced karaoke lines and zero empty lyric screens.',
      category: 'Lyrics',
      icon: Icons.subtitles_rounded,
      iconColor: Color(0xFFFFB74D),
      highlightTag: 'Synced',
    ),
    _ChangelogItem(
      title: 'Cinematic Blurred Lyrics',
      description:
          'Active lyric lines stay sharp in the spotlight while past and upcoming lines gently soften with a natural optical depth blur.',
      category: 'Lyrics',
      icon: Icons.blur_circular_rounded,
      iconColor: Color(0xFFFF9100),
    ),
    _ChangelogItem(
      title: 'Listen Together Rooms',
      description:
          'Track switches, scrubbing, and playback stay precisely in sync across mobile and desktop devices in shared listening rooms with sub-second clock alignment.',
      category: 'Social',
      icon: Icons.group_rounded,
      iconColor: Color(0xFF00E676),
      highlightTag: 'Real-time',
    ),
    _ChangelogItem(
      title: 'Instant Liked Songs & Sync',
      description:
          'Favorites save instantly across search, playlists, and full-screen player, staying permanently preserved across app restarts.',
      category: 'Audio',
      icon: Icons.favorite_rounded,
      iconColor: Color(0xFFFF4081),
    ),
    _ChangelogItem(
      title: 'Liquid Glass Interface 2.0',
      description:
          'Enjoy an eye-catching frosted-glass design featuring glossy highlights, directional reflections, and fluid bento layouts.',
      category: 'UI/UX',
      icon: Icons.blur_on_rounded,
      iconColor: Color(0xFFB388FF),
    ),
    _ChangelogItem(
      title: 'Smooth & Safe In-App Updates',
      description:
          'Optimized GitHub releases updater with safe APK staging and signature verification for zero-friction background updates.',
      category: 'System',
      icon: Icons.verified_user_rounded,
      iconColor: Color(0xFF69F0AE),
    ),
    _ChangelogItem(
      title: 'Faster & Battery Efficient',
      description:
          'Smoother audio crossfades, faster search caching, reduced CPU overhead, and overall stability enhancements.',
      category: 'System',
      icon: Icons.bolt_rounded,
      iconColor: Color(0xFFFFD54F),
    ),
  ];

  static const List<String> _categories = [
    'All',
    'Audio',
    'Visuals',
    'Lyrics',
    'UI/UX',
    'Social',
    'System',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = tokens.accent;
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.88;

    final filteredItems = _selectedCategory == 'All'
        ? _items
        : _items.where((item) => item.category == _selectedCategory).toList();

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: maxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.isGlass ? const Color(0xF0121714) : tokens.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              const BoxShadow(
                color: Color(0x99000000),
                blurRadius: 36,
                offset: Offset(0, -8),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
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
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hero Header Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent,
                                  Color.lerp(accent, const Color(0xFF00E676), 0.4) ?? accent,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFF08120D),
                              size: 28,
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
                                        fontSize: 21,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: accent.withValues(alpha: 0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'v${widget.version}',
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Living artwork, Apple Music player & synced lyrics',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Category Filter Pills
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = cat == _selectedCategory;
                          return BouncingScaleButton(
                            scaleDown: 0.94,
                            minTouchTarget: 34,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedCategory = cat;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accent
                                    : (tokens.isGlass
                                        ? const Color(0x18FFFFFF)
                                        : tokens.card),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? accent
                                      : Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF08120D)
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                    ),

                    // Scrollable Items List
                    Flexible(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _buildChangelogCard(
                            context: context,
                            item: item,
                          );
                        },
                      ),
                    ),

                    // Bottom Action Button
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.06),
                            width: 1,
                          ),
                        ),
                      ),
                      child: BouncingScaleButton(
                        scaleDown: 0.97,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                Color.lerp(accent, Colors.white, 0.12) ?? accent,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: Color(0xFF09140E),
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Got It, Let\'s Play!',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF09140E),
                                  letterSpacing: 0.2,
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChangelogCard({
    required BuildContext context,
    required _ChangelogItem item,
  }) {
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.isGlass
            ? const Color(0x10FFFFFF)
            : tokens.card.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.iconColor.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  item.iconColor.withValues(alpha: 0.25),
                  item.iconColor.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.iconColor.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Icon(
              item.icon,
              color: item.iconColor,
              size: 22,
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
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: item.iconColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.iconColor.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        item.highlightTag ?? item.category,
                        style: TextStyle(
                          color: item.iconColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: Color(0xFFC8D5CD),
                    fontSize: 12.5,
                    height: 1.4,
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
