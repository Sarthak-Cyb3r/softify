// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/theme/app_theme.dart';

/// Single visual keycap rendering with dark elevated surface and border highlights.
class VisualKeycap extends StatelessWidget {
  final String label;
  final bool isSmall;

  const VisualKeycap({
    super.key,
    required this.label,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: isSmall ? 22 : 28,
        minHeight: isSmall ? 22 : 28,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 9,
        vertical: isSmall ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2026),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0x38FFFFFF),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            offset: Offset(0, 2),
            blurRadius: 1,
          ),
          BoxShadow(
            color: Color(0x14FFFFFF),
            offset: Offset(0, -1),
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontUi,
          fontSize: isSmall ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF0F2F5),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Renders a combination or list of keycaps (e.g., [Ctrl] + [F] or [Left] / [Right]).
class KeycapComboWidget extends StatelessWidget {
  final List<List<String>> comboGroups;
  final bool isSmall;

  const KeycapComboWidget({
    super.key,
    required this.comboGroups,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];

    for (int groupIdx = 0; groupIdx < comboGroups.length; groupIdx++) {
      final group = comboGroups[groupIdx];

      // Render keys in this group joined by '+'
      for (int keyIdx = 0; keyIdx < group.length; keyIdx++) {
        children.add(VisualKeycap(label: group[keyIdx], isSmall: isSmall));
        if (keyIdx < group.length - 1) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '+',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: isSmall ? 10 : 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white38,
                ),
              ),
            ),
          );
        }
      }

      // If there are more alternative groups, add '/' separator
      if (groupIdx < comboGroups.length - 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '/',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: isSmall ? 11 : 12,
                fontWeight: FontWeight.w400,
                color: Colors.white24,
              ),
            ),
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// Representation of a single desktop shortcut entry.
class DesktopShortcut {
  final String label;
  final String description;
  final List<List<String>> keys;

  const DesktopShortcut({
    required this.label,
    required this.description,
    required this.keys,
  });
}

/// Representation of a categorized section of shortcuts.
class ShortcutCategory {
  final String title;
  final IconData icon;
  final List<DesktopShortcut> shortcuts;

  const ShortcutCategory({
    required this.title,
    required this.icon,
    required this.shortcuts,
  });
}

/// Desktop Keyboard Shortcuts Cheat Sheet Modal.
///
/// Displays categorized shortcuts:
/// - Playback: Space, Left/Right (Seek ±5s), J/K (Prev/Next Track), Shift+Left/Right (Seek ±15s).
/// - Volume: Up/Down (Volume ±5%), M (Mute/Unmute).
/// - Navigation: Ctrl+F (Search), L (Lyrics), Q (Queue), Escape (Close/Back).
/// - General: Shortcuts modal (? / F1), Screensaver (F11), Tab Navigation.
class KeyboardShortcutsDialog extends ConsumerStatefulWidget {
  const KeyboardShortcutsDialog({super.key});

  /// Opens the Keyboard Shortcuts cheat sheet modal dialog.
  static Future<void> show(BuildContext context) {
    final tokens = context.tokens;
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (isDesktop) {
      return showDialog<void>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.65),
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: KeyboardShortcutsDialog(),
        ),
      );
    } else {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusCard * 2),
          ),
        ),
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.85,
          child: KeyboardShortcutsDialog(),
        ),
      );
    }
  }

  @override
  ConsumerState<KeyboardShortcutsDialog> createState() =>
      _KeyboardShortcutsDialogState();
}

class _KeyboardShortcutsDialogState
    extends ConsumerState<KeyboardShortcutsDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<ShortcutCategory> _categories = [
    ShortcutCategory(
      title: 'Playback',
      icon: Icons.play_circle_outline_rounded,
      shortcuts: [
        DesktopShortcut(
          label: 'Play / Pause',
          description: 'Toggle playback of currently loaded track',
          keys: [
            ['Space']
          ],
        ),
        DesktopShortcut(
          label: 'Seek ±5s',
          description: 'Skip 5 seconds backward or forward',
          keys: [
            ['Left'],
            ['Right']
          ],
        ),
        DesktopShortcut(
          label: 'Seek ±15s',
          description: 'Skip 15 seconds backward or forward',
          keys: [
            ['Shift', 'Left'],
            ['Shift', 'Right']
          ],
        ),
        DesktopShortcut(
          label: 'Prev / Next Track',
          description: 'Skip to previous track (J) or next track (K)',
          keys: [
            ['J'],
            ['K']
          ],
        ),
      ],
    ),
    ShortcutCategory(
      title: 'Volume',
      icon: Icons.volume_up_rounded,
      shortcuts: [
        DesktopShortcut(
          label: 'Volume ±5%',
          description: 'Step master output volume up or down by 5%',
          keys: [
            ['Up'],
            ['Down']
          ],
        ),
        DesktopShortcut(
          label: 'Mute / Unmute',
          description: 'Toggle audio volume mute state',
          keys: [
            ['M']
          ],
        ),
      ],
    ),
    ShortcutCategory(
      title: 'Navigation',
      icon: Icons.explore_outlined,
      shortcuts: [
        DesktopShortcut(
          label: 'Search',
          description: 'Switch to Search view and focus search input',
          keys: [
            ['Ctrl', 'F']
          ],
        ),
        DesktopShortcut(
          label: 'Lyrics',
          description: 'Open full-screen synced lyrics modal',
          keys: [
            ['L']
          ],
        ),
        DesktopShortcut(
          label: 'Queue',
          description: 'Open playback queue bottom sheet',
          keys: [
            ['Q']
          ],
        ),
        DesktopShortcut(
          label: 'Close / Back',
          description: 'Dismiss active dialog, drawer, or navigate back',
          keys: [
            ['Escape']
          ],
        ),
      ],
    ),
    ShortcutCategory(
      title: 'General & Desktop',
      icon: Icons.keyboard_outlined,
      shortcuts: [
        DesktopShortcut(
          label: 'Shortcuts Cheat Sheet',
          description: 'Open this desktop shortcuts reference dialog',
          keys: [
            ['?'],
            ['F1']
          ],
        ),
        DesktopShortcut(
          label: 'Music Screensaver',
          description: 'Toggle full-screen ambient screensaver mode',
          keys: [
            ['F11']
          ],
        ),
        DesktopShortcut(
          label: 'Switch to Home / Library',
          description: 'Quickly jump to Home or Library views',
          keys: [
            ['Ctrl', 'H'],
            ['Ctrl', 'L']
          ],
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ShortcutCategory> _getFilteredCategories() {
    if (_searchQuery.trim().isEmpty) {
      return _categories;
    }
    final q = _searchQuery.toLowerCase();
    final List<ShortcutCategory> filtered = [];

    for (final cat in _categories) {
      final matchingShortcuts = cat.shortcuts.where((s) {
        if (s.label.toLowerCase().contains(q) ||
            s.description.toLowerCase().contains(q)) {
          return true;
        }
        for (final group in s.keys) {
          for (final key in group) {
            if (key.toLowerCase().contains(q)) {
              return true;
            }
          }
        }
        return false;
      }).toList();

      if (matchingShortcuts.isNotEmpty || cat.title.toLowerCase().contains(q)) {
        filtered.add(
          ShortcutCategory(
            title: cat.title,
            icon: cat.icon,
            shortcuts: matchingShortcuts.isNotEmpty
                ? matchingShortcuts
                : cat.shortcuts,
          ),
        );
      }
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final filteredCategories = _getFilteredCategories();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 680,
              maxHeight: 640,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: tokens.surfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusCard * 1.5),
                border: Border.all(
                  color: tokens.isGlass ? tokens.glassBorder : tokens.divider,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(0, 16),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusCard * 1.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    _buildHeader(context, tokens),

                    // Search / Filter Input
                    _buildSearchBar(tokens),

                    const Divider(height: 1, color: Colors.white12),

                    // Scrollable Categories Body
                    Flexible(
                      child: filteredCategories.isEmpty
                          ? _buildEmptyState(tokens)
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              itemCount: filteredCategories.length,
                              itemBuilder: (context, index) {
                                return _buildCategorySection(
                                  filteredCategories[index],
                                  tokens,
                                );
                              },
                            ),
                    ),

                    const Divider(height: 1, color: Colors.white12),

                    // Footer with tips
                    _buildFooter(context, tokens),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppTokens tokens) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          bottom: BorderSide(
            color: tokens.divider,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tokens.accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(
                color: tokens.accent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.keyboard_outlined,
              size: 20,
              color: tokens.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keyboard Shortcuts',
                  style: TextStyle(
                    fontFamily: AppTheme.fontPageTitle,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Desktop Cheat Sheet & Quick Controls',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 12,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Quick Esc pill indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.surfaceHighlight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VisualKeycap(label: 'Esc', isSmall: true),
                const SizedBox(width: 6),
                Text(
                  'close',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: tokens.textSecondary,
            tooltip: 'Close (Esc)',
            hoverColor: tokens.cardHover,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: tokens.surface,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: Colors.white10,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                style: const TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 13,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Search shortcuts (e.g. seek, volume, lyrics)...',
                  hintStyle: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 13,
                    color: tokens.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: tokens.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(ShortcutCategory category, AppTokens tokens) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(
                  category.icon,
                  size: 16,
                  color: tokens.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  category.title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: tokens.surfaceHighlight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${category.shortcuts.length}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Categorized Card
          Container(
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(tokens.radiusCard),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 1,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: category.shortcuts.length,
              separatorBuilder: (context, _) => Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withOpacity(0.04),
              ),
              itemBuilder: (context, idx) {
                final shortcut = category.shortcuts[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shortcut.label,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shortcut.description,
                              style: TextStyle(
                                fontFamily: AppTheme.fontUi,
                                fontSize: 11,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      KeycapComboWidget(comboGroups: shortcut.keys),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: tokens.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No shortcuts found for "$_searchQuery"',
              style: const TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try searching with another keyword like "seek", "volume", or "lyrics"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12,
                color: tokens.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              child: Text(
                'Clear search',
                style: TextStyle(
                  color: tokens.accent,
                  fontFamily: AppTheme.fontUi,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AppTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: tokens.surface,
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: tokens.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Press ? or F1 anywhere to view this cheat sheet.',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12,
                color: tokens.textSecondary,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              backgroundColor: tokens.surfaceHighlight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text(
              'Done',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
