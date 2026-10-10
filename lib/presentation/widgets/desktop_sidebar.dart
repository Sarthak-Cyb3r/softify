import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import '../providers/settings_providers.dart';
import '../screens/equalizer_screen.dart';
import 'lyrics_view.dart';

/// Desktop Sidebar adhering to clean minimalist dark aesthetic:
/// - Palette: Surface Container Lowest (#0E0E0E / #131313), hairline border (#1F1F1F)
/// - Branding: SOFTIFY v2.0
/// - Sections: Main Navigation (Home, Search, YouTube, Podcasts, Library, Settings)
/// - Curated Library Access with real counters
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
    final likedCountAsync = ref.watch(likedTracksStreamProvider);
    final downloadsCountAsync = ref.watch(downloadsStreamProvider);

    final likedCount = likedCountAsync.value?.length ?? 0;
    final downloadsCount =
        downloadsCountAsync.value?.where((d) => d.isCompleted).length ?? 0;

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
      width: 256,
      decoration: const BoxDecoration(
        color: Color(0xFF121316),
        border: Border(
          right: BorderSide(
            color: Color(0xFF1F1F23),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Header & Studio Branding
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Row(
              children: [
                // Concentric machined badge container
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F23),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF4EDEA3).withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4EDEA3).withValues(alpha: 0.12),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4EDEA3).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: Color(0xFF4EDEA3),
                          size: 18,
                        ),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4EDEA3).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF4EDEA3).withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'LINUX v2.0',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Color(0xFF4EDEA3),
                                fontFamily: 'monospace',
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

          const SizedBox(height: 4),

          // Main Navigation Items (Scrollable with zero overflow)
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
                    trailingBadge: 'P',
                  ),
                  const SizedBox(height: 2),
                  _buildNavItem(
                    index: 4,
                    icon: Icons.library_music_outlined,
                    activeIcon: Icons.library_music_rounded,
                    label: 'Library',
                  ),
                  const SizedBox(height: 2),
                  _buildNavItem(
                    index: 5,
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    label: 'Settings',
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF1F1F23), height: 1),
                  const SizedBox(height: 8),

                  // Section: FEATURES
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'FEATURES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: const Color(0xFF86948A).withValues(alpha: 0.8),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildFeatureItem(
                    icon: Icons.mic_rounded,
                    label: 'Sing Along',
                    onTap: () {
                      final current = ref.read(currentTrackProvider).value;
                      if (current != null) {
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                            child: SizedBox(
                              width: 700,
                              height: 700,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: LyricsView(
                                  track: current,
                                  onClose: () => Navigator.of(ctx).pop(),
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        widget.onSelectTab(0);
                      }
                    },
                  ),
                  const SizedBox(height: 2),
                  _buildFeatureItem(
                    icon: Icons.tune_rounded,
                    label: 'Equalizer & Sound',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EqualizerScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  _buildFeatureItem(
                    icon: Icons.group_rounded,
                    label: 'Artists',
                    onTap: () {
                      widget.onSelectTab(1); // Navigates to search / artists
                    },
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF1F1F23), height: 1),
                  const SizedBox(height: 8),

                  // Section: QUICK ACCESS / PINNED PLAYLISTS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'QUICK ACCESS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: const Color(0xFF86948A).withValues(alpha: 0.8),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildPlaylistItem(
                    title: 'Liked Songs',
                    dotColor: const Color(0xFFFC7C78),
                    badge: likedCount > 0 ? '$likedCount' : null,
                    onTap: () => widget.onSelectTab(4),
                  ),
                  const SizedBox(height: 2),
                  _buildPlaylistItem(
                    title: 'Downloads',
                    dotColor: const Color(0xFF4EDEA3),
                    badge: downloadsCount > 0 ? '$downloadsCount' : null,
                    onTap: () => widget.onSelectTab(4),
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF1F1F23), height: 1),
                  const SizedBox(height: 8),

                  // Section: SHORTCUTS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'SHORTCUTS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: const Color(0xFF86948A).withValues(alpha: 0.8),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildShortcutRow('Ctrl+K', 'Search'),
                  _buildShortcutRow('P', 'Podcasts'),
                  _buildShortcutRow('Space', 'Play / Pause'),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Bottom User Profile & Hardware Status Footer
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF18191D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF292A2D),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1F1F23),
                        border: Border.all(
                          color: const Color(0xFF4EDEA3).withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4EDEA3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFFFFFF),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const Text(
                            'Local Account',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF86948A),
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
                        size: 16,
                        color: Color(0xFFBBCABF),
                      ),
                      onPressed: () => widget.onSelectTab(5),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4EDEA3),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x664EDEA3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              'Offline & Streaming',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFBBCABF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Ready',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF86948A),
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

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        hoverColor: const Color(0xFF1F1F23),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: const Color(0xFFBBCABF),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFBBCABF),
                    letterSpacing: -0.2,
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
    final isSelected = widget.currentIndex == index;
    final isHovered = _hoveredIndex == index;

    final bgColor = isSelected
        ? const Color(0xFF1F1F23)
        : (isHovered ? const Color(0xFF18191D) : Colors.transparent);

    final textColor = isSelected
        ? const Color(0xFFFFFFFF)
        : (isHovered ? const Color(0xFFFFFFFF) : const Color(0xFFBBCABF));

    final iconColor = isSelected
        ? const Color(0xFF4EDEA3)
        : (isHovered ? const Color(0xFFBBCABF) : const Color(0xFF86948A));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () => widget.onSelectTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFF292A2D), width: 1)
                : null,
          ),
          child: Row(
            children: [
              // Subtle Emerald Active Indicator Pill
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 3,
                height: isSelected ? 16 : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF4EDEA3),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4EDEA3).withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                isSelected ? activeIcon : icon,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: textColor,
                    letterSpacing: -0.2,
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF141518) : const Color(0xFF1A1B1F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF4EDEA3).withValues(alpha: 0.35)
              : const Color(0xFF2E3035),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 1),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        keyText,
        style: TextStyle(
          fontSize: 9.5,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: isSelected
              ? const Color(0xFF4EDEA3)
              : const Color(0xFF86948A),
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
        hoverColor: const Color(0xFF1F1F23),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFBBCABF),
                    letterSpacing: -0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F23),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF292A2D),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF86948A),
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
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          _buildKbdPill(keys),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFFBBCABF),
                letterSpacing: -0.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
