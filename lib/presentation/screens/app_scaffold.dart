import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';
import '../theme/app_tokens.dart';
import '../widgets/desktop_player_bar.dart';
import '../widgets/desktop_sidebar.dart';
import '../widgets/mini_player.dart';
import '../../features/podcasts/domain/parse_podcast_link.dart';
import '../../features/podcasts/presentation/podcast_controller.dart';
import '../../features/podcasts/presentation/podcast_page.dart';
import '../../features/youtube/data/share_intent_service.dart';
import '../../features/youtube/domain/parse_youtube_link.dart';
import '../../features/youtube/presentation/youtube_controller.dart';
import '../../features/youtube/presentation/youtube_page.dart';
import '../widgets/slim_bottom_nav_bar.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'equalizer_screen.dart';
import '../providers/settings_providers.dart';
import '../../data/database/app_database.dart';
import '../../data/services/auto_update_service.dart';
import '../widgets/terms_and_conditions_dialog.dart';

/// Centralized application tab icon registry for consistent styling and quick theme swaps
class AppTabIcons {
  static const IconData youtube = Icons.smart_display_outlined;
  static const IconData youtubeActive = Icons.smart_display;
  static const IconData podcasts = Icons.podcasts_outlined;
  static const IconData podcastsActive = Icons.podcasts_rounded;
}

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
    YoutubePage(),
    PodcastPage(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    ShareIntentService.initialize(
      onReceived: (text) {
        final parsedYt = parseYoutubeLink(text);
        if (parsedYt is! InvalidLink) {
          if (mounted) {
            setState(() {
              _currentIndex = 2; // Switch to YouTube tab
            });
            ref.read(youtubeControllerProvider.notifier).submit(text);
          }
          return;
        }

        final parsedPodcast = parsePodcastLink(text);
        if (parsedPodcast is! InvalidPodcastLink) {
          if (mounted) {
            setState(() {
              _currentIndex = 3; // Switch to Podcasts tab
            });
            ref.read(podcastControllerProvider.notifier).submit(text);
          }
          return;
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 1. Mandatory First-Run Terms & Conditions Verification
      final db = ref.read(databaseProvider);
      TermsAndConditionsDialog.showIfNeeded(
        context: context,
        isTermsAccepted: () async {
          final row = await (db.select(db.settings)
                ..where((t) => t.key.equals('terms_accepted')))
              .getSingleOrNull();
          return row?.value == 'true';
        },
        onTermsAccepted: () async {
          await db.into(db.settings).insertOnConflictUpdate(
                const SettingRow(key: 'terms_accepted', value: 'true'),
              );
        },
      );

      // 2. Silent Auto Background Update Check (No prompts, headless)
      AutoUpdateService().runSilentBackgroundUpdateCheck();
    });
  }

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
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): PlayPauseIntent(),
      },
      child: Actions(
        actions: {
          PlayPauseIntent: PlayPauseAction(() {
            final pb = ref.read(playbackStateStreamProvider).value;
            final isPlaying = pb?.playing ?? false;
            final audioHandler = ref.read(audioHandlerProvider);
            if (isPlaying) {
              audioHandler.pause();
            } else {
              audioHandler.play();
            }
          }),
        },
        child: CallbackShortcuts(
          bindings: {
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
        // Ctrl + Y: Switch to YouTube
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
          setState(() => _currentIndex = 2);
        },
        // Ctrl + P: Switch to Podcasts
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          setState(() => _currentIndex = 3);
        },
        // Ctrl + L: Switch to Library
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
          setState(() => _currentIndex = 4);
        },
        // Ctrl + Comma: Switch to Settings
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          setState(() => _currentIndex = 5);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: tokens.background,
          body: Row(
            children: [
              // 1. Persistent Desktop Sidebar (256px)
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
                    // Persistent Desktop Top Header (Stitch Design)
                    _buildDesktopTopHeader(context, tokens),

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
    ),
    ),
    );
  }

  Widget _buildDesktopTopHeader(BuildContext context, AppTokens tokens) {
    String userName = 'My Account';
    try {
      final name = ref.watch(userNameProvider);
      if (name != null && name.trim().isNotEmpty) {
        userName = name.trim();
      }
    } catch (_) {}

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF121316),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF1F1F23),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Navigation Chevrons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderCircleButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Back',
                onTap: () {
                  if (_currentIndex > 0) {
                    setState(() => _currentIndex--);
                  }
                },
              ),
              const SizedBox(width: 6),
              _buildHeaderCircleButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Forward',
                onTap: () {
                  if (_currentIndex < _screens.length - 1) {
                    setState(() => _currentIndex++);
                  }
                },
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Search Bar Pill
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = 1),
              child: Container(
                width: 320,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F23),
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                  border: Border.all(
                    color: const Color(0xFF292A2D),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: Color(0xFF86948A),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Search songs, albums, or artists...',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF86948A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF292A2D),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '⌘K',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF86948A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // Right Actions
          _buildHeaderCircleButton(
            icon: Icons.tune_rounded,
            tooltip: 'Equalizer & Sound',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EqualizerScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _buildHeaderCircleButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => setState(() => _currentIndex = 5),
          ),
          const SizedBox(width: 14),

          // User Profile Pill
          Container(
            height: 30,
            padding: const EdgeInsets.only(left: 4, right: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F23),
              borderRadius: BorderRadius.circular(tokens.radiusFull),
              border: Border.all(
                color: const Color(0xFF292A2D),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF292A2D),
                  ),
                  child: Center(
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4EDEA3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE3E2E6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1F1F23),
              border: Border.all(
                color: const Color(0xFF292A2D),
                width: 0.8,
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: const Color(0xFFBBCABF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, AppTokens tokens) {
    final mobileIndex = _currentIndex.clamp(0, 4);

    return Scaffold(
      backgroundColor: tokens.background,
      body: Stack(
        children: [
          // Current Tab Page (IndexedStack preserves state)
          IndexedStack(
            index: mobileIndex,
            children: _screens.sublist(0, 5),
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
                        icon: AppTabIcons.youtube,
                        activeIcon: AppTabIcons.youtubeActive,
                        label: 'YouTube',
                      ),
                      SlimNavItem(
                        icon: AppTabIcons.podcasts,
                        activeIcon: AppTabIcons.podcastsActive,
                        label: 'Podcasts',
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

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class PlayPauseAction extends Action<PlayPauseIntent> {
  final VoidCallback onToggle;
  PlayPauseAction(this.onToggle);

  @override
  bool isEnabled(PlayPauseIntent intent) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.context == null) return true;
    final ctx = focus.context!;
    if (ctx.widget is EditableText) return false;
    if (ctx.findAncestorWidgetOfExactType<EditableText>() != null) return false;
    if (ctx.findAncestorStateOfType<EditableTextState>() != null) return false;
    return true;
  }

  @override
  Object? invoke(PlayPauseIntent intent) {
    onToggle();
    return null;
  }
}
