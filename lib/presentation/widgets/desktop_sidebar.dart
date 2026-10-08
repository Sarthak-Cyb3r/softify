import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';

/// Professional desktop sidebar navigation adhering to ui-ux-pro-max guidelines:
/// - Dark background (#1B1B30 / OLED surface)
/// - 240px fixed width with subtle border
/// - Smooth 150ms hover transitions
/// - Distinct active state indicator pill & emerald accent
/// - Full keyboard & accessibility compliance
class DesktopSidebar extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectTab;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
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

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B30),
        border: Border(
          right: BorderSide(
            color: Color(0xFF27273B),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Header & Branding
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: Color(0xFF22C55E),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Softify',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: Color(0xFFF8FAFC),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B4B),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF312E81),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'LINUX v2.0',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: Color(0xFF22C55E),
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

          const SizedBox(height: 8),

          // Main Navigation Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 1,
                  icon: Icons.search_rounded,
                  activeIcon: Icons.search_rounded,
                  label: 'Search',
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 2,
                  icon: Icons.smart_display_outlined,
                  activeIcon: Icons.smart_display,
                  label: 'YouTube',
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 3,
                  icon: Icons.library_music_outlined,
                  activeIcon: Icons.library_music_rounded,
                  label: 'Library',
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  index: 4,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Section Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: Color(0xFF27273B),
              height: 1,
            ),
          ),

          const SizedBox(height: 10),

          // Section Header: QUICK ACCESS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'QUICK ACCESS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Quick Access List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildQuickItem(
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFE91E63),
                  title: 'Liked Songs',
                  badge: likedCount > 0 ? '$likedCount' : null,
                  onTap: () {
                    widget.onSelectTab(2); // Jump to library
                  },
                ),
                const SizedBox(height: 4),
                _buildQuickItem(
                  icon: Icons.download_done_rounded,
                  iconColor: const Color(0xFF22C55E),
                  title: 'Downloads',
                  badge: downloadsCount > 0 ? '$downloadsCount' : null,
                  onTap: () {
                    widget.onSelectTab(2); // Jump to library
                  },
                ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom Shortcut Hints Card
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F23),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF27273B),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.keyboard_outlined,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'SHORTCUTS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildShortcutRow('Space', 'Play / Pause'),
                _buildShortcutRow('Ctrl + →', 'Next Track'),
                _buildShortcutRow('Ctrl + ←', 'Prev Track'),
                _buildShortcutRow('Ctrl + S', 'Search'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = widget.currentIndex == index;
    final isHovered = _hoveredIndex == index;

    final bgColor = isSelected
        ? const Color(0xFF1E1B4B)
        : (isHovered ? const Color(0xFF27273B) : Colors.transparent);

    final textColor = isSelected
        ? const Color(0xFFF8FAFC)
        : (isHovered ? const Color(0xFFF8FAFC) : const Color(0xFF94A3B8));

    final iconColor = isSelected
        ? const Color(0xFF22C55E)
        : (isHovered ? const Color(0xFFF8FAFC) : const Color(0xFF94A3B8));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () => widget.onSelectTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: const Color(0xFF312E81),
                    width: 0.8,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Active vertical accent pill
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: isSelected ? 18 : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: isSelected ? 8 : 11),
              Icon(
                isSelected ? activeIcon : icon,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? badge,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        hoverColor: const Color(0xFF27273B),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27273B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF8FAFC),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B30),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFF312E81),
                width: 0.6,
              ),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF8FAFC),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
