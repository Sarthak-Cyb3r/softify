import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_tokens.dart';
import '../widgets/mini_player.dart';
import '../widgets/slim_bottom_nav_bar.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

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
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.background,
      body: Stack(
        children: [
          // Current Tab Page
          IndexedStack(
            index: _currentIndex,
            children: _screens,
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
                    currentIndex: _currentIndex,
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
