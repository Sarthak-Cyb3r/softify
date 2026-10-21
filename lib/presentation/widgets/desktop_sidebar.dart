import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import '../providers/settings_providers.dart';
import '../screens/equalizer_screen.dart';
import '../theme/app_theme.dart';
import 'lyrics_view.dart';
import 'wrapped_insights_dialog.dart';

/// Desktop Sidebar adhering to Content-First Spotify-inspired design:
/// - Background: Sidebar #000000 (Chrome surface 0)
/// - Navigation: Home, Search, Paste a Link, Podcasts, Equalizer, Library, Settings
/// - Highlight: #2EE66B green active accent indicator, #282828 hover state
/// - Zero borders, zero outlines, zero neon glows
class DesktopSidebar extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectTab;
  final String? userName;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
    this.userName,
  });

  @override
  ConsumerState<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<DesktopSidebar> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    String? watchedName;
    try {
      watchedName = ref.watch(userNameProvider);
    } catch (_) {}
    final userName = (widget.userName != null && widget.userName!.isNotEmpty)
        ? widget.userName!
        : (watchedName != null && watchedName.isNotEmpty)
            ? watchedName
            : 'My Account';

    return Container(
      width: 260.0,
      color: tokens.sidebar, // Pure #000000
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Header & Studio Branding
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: Row(
              children: [
                // Softify official logo
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tokens.card,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/logo/logo.png',
                      width: 22,
                      height: 22,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.graphic_eq_rounded,
                        color: AppTheme.accent,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Softify',
                        style: TextStyle(
                          fontFamily: AppTheme.fontPageTitle,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.surfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LINUX v2.0',
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: tokens.accent,
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
          ),

          // Main Navigation Items (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  const SizedBox(height: 2),
                  _buildNavItem(
                    index: 1,
                    icon: Icons.search_rounded,
                    activeIcon: Icons.search_rounded,
                    label: 'Search',
                    trailingBadge: 'Ctrl+K',
                  ),
                  const SizedBox(height: 2),
                  _buildNavItem(
                    index: 2,
                    icon: Icons.smart_display_outlined,
                    activeIcon: Icons.smart_display,
                    label: 'YouTube',
                  ),
                  const SizedBox(height: 2),
                  _buildNavItem(
                    index: 3,
                    icon: Icons.podcasts_outlined,
                    activeIcon: Icons.podcasts_rounded,
                    label: 'Podcasts',
                    trailingBadge: 'Ctrl+P',
                  ),
                  const SizedBox(height: 2),
                  _buildNavItem(
                    index: 4,
                    icon: Icons.local_library_outlined,
                    activeIcon: Icons.local_library_rounded,
                    label: 'Library',
                  ),
                  const SizedBox(height: 2),
                  _buildNavItem(
                    index: 5,
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    label: 'Settings',
                  ),

                  const SizedBox(height: 16),
                  Divider(color: tokens.divider, height: 1),
                  const SizedBox(height: 12),

                  // Section: FEATURES & TOOLS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'AUDIO TOOLS',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12, // Strict 12px floor
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: tokens.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildFeatureItem(
                    icon: Icons.tune_rounded,
                    label: 'Equalizer & DSP',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EqualizerScreen(),
                        ),
                      );
                    },
                  ),
                  _buildFeatureItem(
                    icon: Icons.lyrics_outlined,
                    label: 'Synced Lyrics View',
                    onTap: () {
                      final currentTrack =
                          ref.read(currentTrackProvider).value;
                      if (currentTrack != null) {
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => Dialog(
                            backgroundColor: tokens.surfaceElevated,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusCard),
                            ),
                            insetPadding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 30,
                            ),
                            child: SizedBox(
                              width: 880,
                              height: 660,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(tokens.radiusCard),
                                child: LyricsView(
                                  track: currentTrack,
                                  onClose: () => Navigator.of(ctx).pop(),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  _buildFeatureItem(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Wrapped Stories',
                    onTap: () {
                      WrappedInsightsDialog.show(context);
                    },
                  ),

                  const SizedBox(height: 16),
                  Divider(color: tokens.divider, height: 1),
                  const SizedBox(height: 12),

                  // Section: QUICK ACCESS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'QUICK ACCESS',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12, // Strict 12px floor
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: tokens.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildPlaylistItem(
                    title: 'Liked Songs',
                    dotColor: tokens.accent,
                    badge: null,
                    onTap: () => widget.onSelectTab(4),
                  ),
                  const SizedBox(height: 2),
                  _buildPlaylistItem(
                    title: 'Downloads',
                    dotColor: tokens.accent,
                    badge: null,
                    onTap: () => widget.onSelectTab(4),
                  ),

                  const SizedBox(height: 16),
                  Divider(color: tokens.divider, height: 1),
                  const SizedBox(height: 12),

                  // Section: SHORTCUTS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'SHORTCUTS',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12, // Strict 12px floor
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: tokens.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildShortcutRow('Ctrl+K', 'Search'),
                  _buildShortcutRow('Ctrl+P', 'Podcasts'),
                  _buildShortcutRow('Space', 'Play / Pause'),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom User Profile & Status Footer
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(tokens.radiusCard),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent,
                  ),
                  child: Center(
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Text(
                        'Local User',
                        style: TextStyle(
                          fontFamily: AppTheme.fontUi,
                          fontSize: 12, // Strict 12px floor
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () => widget.onSelectTab(5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        hoverColor: const Color(0xFF282828),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    String? trailingBadge,
  }) {
    final tokens = context.tokens;
    final isSelected = widget.currentIndex == index;
    final isHovered = _hoveredIndex == index;

    final bgColor = isSelected
        ? tokens.card
        : (isHovered ? tokens.cardHover : Colors.transparent);

    final textColor = isSelected
        ? tokens.textPrimary
        : (isHovered ? tokens.textPrimary : tokens.textSecondary);

    final iconColor = isSelected ? tokens.accent : (isHovered ? tokens.textPrimary : tokens.textSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () => widget.onSelectTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(tokens.radiusCard),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingBadge != null)
                _buildKbdPill(trailingBadge, isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKbdPill(String keyText, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        keyText,
        style: const TextStyle(
          fontSize: 12, // Strict 12px floor
          fontFamily: AppTheme.fontUi,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildPlaylistItem({
    required String title,
    required Color dotColor,
    String? badge,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        hoverColor: const Color(0xFF282828),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: AppTheme.tabularTimestamp(
                      fontSize: 12, // Strict 12px floor
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutRow(String keys, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          _buildKbdPill(keys),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
