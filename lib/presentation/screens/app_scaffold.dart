import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import '../theme/app_tokens.dart';
import '../widgets/desktop_player_bar.dart';
import '../widgets/desktop_sidebar.dart';
import '../widgets/mini_player.dart';
import '../widgets/slim_bottom_nav_bar.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Adaptive Application Shell supporting:
/// - Desktop Linux UI (Width >= 800px): Persistent left navigation sidebar,
///   full-width bottom player bar, and global keyboard shortcuts.
/// - Mobile UI (Width < 800px): Bottom navigation bar and docked MiniPlayer.
class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({super.key});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          return _buildDesktopLayout(context, tokens);
        } else {
          return _buildMobileLayout(context, tokens);
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AppTokens tokens) {
    return CallbackShortcuts(
      bindings: {
        // Space: Toggle Play / Pause
        const SingleActivator(LogicalKeyboardKey.space): () {
          final pb = ref.read(playbackStateStreamProvider).value;
          final isPlaying = pb?.playing ?? false;
          final audioHandler = ref.read(audioHandlerProvider);
          if (isPlaying) {
            audioHandler.pause();
          } else {
            audioHandler.play();
          }
        },
        // Ctrl + Right: Skip Next
        const SingleActivator(LogicalKeyboardKey.arrowRight, control: true): () {
          ref.read(audioHandlerProvider).skipToNext();
        },
        // Ctrl + Left: Skip Previous
        const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true): () {
          ref.read(audioHandlerProvider).skipToPrevious();
        },
        // Ctrl + Up: Volume Up (+10%)
        const SingleActivator(LogicalKeyboardKey.arrowUp, control: true): () {
          final currentVol = ref.read(volumeStreamProvider).value ?? 1.0;
          ref.read(audioHandlerProvider).setVolume((currentVol + 0.1).clamp(0.0, 1.0));
        },
        // Ctrl + Down: Volume Down (-10%)
        const SingleActivator(LogicalKeyboardKey.arrowDown, control: true): () {
          final currentVol = ref.read(volumeStreamProvider).value ?? 1.0;
          ref.read(audioHandlerProvider).setVolume((currentVol - 0.1).clamp(0.0, 1.0));
        },
        // Ctrl + S or Ctrl + F: Switch to Search
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          setState(() => _currentIndex = 1);
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          setState(() => _currentIndex = 1);
        },
        // Ctrl + H: Switch to Home
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () {
          setState(() => _currentIndex = 0);
        },
        // Ctrl + L: Switch to Library
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
          setState(() => _currentIndex = 2);
        },
        // Ctrl + Comma: Switch to Settings
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          setState(() => _currentIndex = 3);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: tokens.background,
          body: Row(
            children: [
              // 1. Persistent Desktop Sidebar (240px)
              DesktopSidebar(
                currentIndex: _currentIndex,
                onSelectTab: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),

              // 2. Main Content Viewport & Bottom Playback Bar
              Expanded(
                child: Column(
                  children: [
                    // Main Viewport
                    Expanded(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: _screens,
                      ),
                    ),

                    // Persistent Desktop Bottom Player Bar
                    const DesktopPlayerBar(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, AppTokens tokens) {
    final mobileIndex = _currentIndex.clamp(0, 2);

    return Scaffold(
      backgroundColor: tokens.background,
      body: Stack(
        children: [
          // Current Tab Page
          IndexedStack(
            index: mobileIndex,
            children: _screens.sublist(0, 3),
          ),

          // Floating MiniPlayer docked cleanly above SlimBottomNavBar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayer(),
                  SlimBottomNavBar(
                    currentIndex: mobileIndex,
                    onTap: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    items: const [
                      SlimNavItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_filled,
                        label: 'Home',
                      ),
                      SlimNavItem(
                        icon: Icons.search_outlined,
                        activeIcon: Icons.search_rounded,
                        label: 'Search',
                      ),
                      SlimNavItem(
                        icon: Icons.library_music_outlined,
                        activeIcon: Icons.library_music_rounded,
                        label: 'Library',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
