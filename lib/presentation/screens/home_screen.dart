import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/shelf.dart';
import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../providers/settings_providers.dart';
import '../providers/shelf_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/metrolist_speed_dial_item.dart';
import '../widgets/shared/shared_components.dart';
import '../widgets/shimmer_skeleton.dart';
import 'equalizer_screen.dart';
import 'settings_screen.dart';
import 'spotify_import_screen.dart';
import 'artist_discography_screen.dart';
import 'tracks_list_screen.dart';
import '../../features/podcasts/presentation/podcast_page.dart';
import '../providers/search_providers.dart';
import '../widgets/track_options_bottom_sheet.dart';
import '../widgets/wrapped_insights_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunchPrompt();
    });
  }

  Future<void> _checkFirstLaunchPrompt() async {
    try {
      final completed = await ref.read(hasCompletedNamePromptProvider.future);
      final currentName = ref.read(userNameProvider);
      if (!completed && (currentName == null || currentName.trim().isEmpty)) {
        if (!mounted) return;
        _showNamePromptModal(context);
      }
    } catch (_) {}
  }

  Future<void> _showNamePromptModal(BuildContext context) async {
    final tokens = context.tokens;
    final controller = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusXl)),
        ),
        builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(tokens.radiusFull),
                  ),
                ),
              ),
              Text(
                'Welcome to Softify',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'What should we call you?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: tokens.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  hintStyle: TextStyle(color: tokens.textMuted),
                  filled: true,
                  fillColor: tokens.surface,
                  prefixIcon: Icon(Icons.person_outline_rounded, color: tokens.accent),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                    borderSide: BorderSide(color: tokens.accent, width: 1.5),
                  ),
                ),
                onSubmitted: (value) async {
                  final text = value.trim();
                  if (text.isNotEmpty) {
                    await ref.read(userNameProvider.notifier).setUserName(text);
                  } else {
                    await ref.read(userNameProvider.notifier).markPromptCompleted();
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 20),
              BouncingScaleButton(
                onTap: () async {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    await ref.read(userNameProvider.notifier).setUserName(text);
                  } else {
                    await ref.read(userNameProvider.notifier).markPromptCompleted();
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    borderRadius: BorderRadius.circular(tokens.radiusFull),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await ref.read(userNameProvider.notifier).markPromptCompleted();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(
                  'Skip',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
    } finally {
      controller.dispose();
    }
  }

  String _getGreeting(String? userName, {bool isDesktop = false}) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : (hour < 18 ? 'Good afternoon' : 'Good evening');

    if (isDesktop && userName != null && userName.trim().isNotEmpty) {
      return '$timeGreeting, ${userName.trim()}';
    }
    return timeGreeting;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final userName = ref.watch(userNameProvider);
    final historyAsync = ref.watch(playHistoryStreamProvider);
    final featuredAsync = ref.watch(featuredMusicProvider);
    final shelvesAsync = ref.watch(homeShelvesProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    final historyTracks = (historyAsync.value ?? [])
        .map((h) => h.track)
        .whereType<Track>()
        .toList();
    final fallbackTracks = (featuredAsync.value is List<Track>)
        ? (featuredAsync.value as List<Track>)
        : (shelvesAsync.value?.isNotEmpty == true
            ? (shelvesAsync.value!.first.tracks)
            : <Track>[]);
    final quickPicksTracks =
        historyTracks.isNotEmpty ? historyTracks : fallbackTracks;

    return Scaffold(
      backgroundColor: tokens.isGlass ? Colors.transparent : tokens.background,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor:
                  tokens.isGlass ? Colors.transparent : tokens.background,
              elevation: 0,
              titleSpacing: 16,
              title: Row(
                children: [
                  BouncingScaleButton(
                    scaleFactor: 0.9,
                    onTap: () {
                      _showNamePromptModal(context);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.accent,
                      ),
                      child: Center(
                        child: Text(
                          (userName != null && userName.trim().isNotEmpty)
                              ? userName.trim()[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontUi,
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getGreeting(userName, isDesktop: false),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontPageTitle,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                BouncingScaleButton(
                  scaleFactor: 0.9,
                  onTap: () {
                    final history = historyAsync.value ?? [];
                    final tracks = history
                        .map((h) => h.track)
                        .whereType<Track>()
                        .toList();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TracksListScreen(
                          title: 'Recently Played',
                          subtitle: '${tracks.length} tracks',
                          icon: Icons.history_rounded,
                          iconColor: tokens.accent,
                          initialTracks: tracks,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Icon(Icons.history_rounded, size: 22, color: tokens.textSecondary),
                  ),
                ),
                BouncingScaleButton(
                  scaleFactor: 0.9,
                  onTap: () {
                    WrappedInsightsDialog.show(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Icon(Icons.bar_chart_rounded, size: 22, color: tokens.textSecondary),
                  ),
                ),
                BouncingScaleButton(
                  scaleFactor: 0.9,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EqualizerScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Icon(Icons.tune_rounded, size: 22, color: tokens.textSecondary),
                  ),
                ),
                BouncingScaleButton(
                  scaleFactor: 0.9,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 14, top: 8, bottom: 8),
                    child: Icon(Icons.settings_outlined, size: 22, color: tokens.textSecondary),
                  ),
                ),
              ],
            ),
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 8-column Main Stream
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
                    children: [
                      // 1. Listening Room Header & Status Indicator
                      _buildGreetingHeader(tokens, userName, true),
                      const SizedBox(height: 14),
                      // Filter Chips Bar
                      _buildFilterChips(tokens),
                      const SizedBox(height: 16),

                      // 2. Metrolist Speed Dial Section
                      if (historyTracks.isNotEmpty) ...[
                        _buildSpeedDialSection(tokens, historyTracks, audioHandler),
                        const SizedBox(height: 24),
                      ],

                      // Metrolist 2-row Quick Picks Grid
                      _buildQuickPicksSection(tokens, quickPicksTracks, audioHandler),
                      const SizedBox(height: 32),

                      // 3. Continue Listening Shelf
                      _buildContinueListeningSection(
                        tokens,
                        historyAsync,
                        audioHandler,
                        isDesktop: true,
                      ),
                      const SizedBox(height: 32),

                      // 4. Made For You Shelf
                      _buildFeaturedSection(tokens, featuredAsync, audioHandler, ref),
                      const SizedBox(height: 32),

                      // 5. Popular Artists Shelf (Daft Punk, The Weeknd, Billie Eilish, Taylor Swift)
                      _buildPopularArtistsShelf(tokens),
                      const SizedBox(height: 32),

                      // 6. Algotorial Personalized Home Shelves
                      shelvesAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (shelves) {
                          if (shelves.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final shelf in shelves) ...[
                                _buildShelfSection(context, tokens, shelf, audioHandler, ref),
                                const SizedBox(height: 32),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),

                // 4-column Sticky Up Next Queue Sidebar
                _buildUpNextSidebar(tokens, audioHandler),
              ],
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildFilterChips(tokens),
                const SizedBox(height: 8),
                if (historyTracks.isNotEmpty) ...[
                  _buildSpeedDialSection(tokens, historyTracks, audioHandler),
                  const SizedBox(height: 24),
                ],
                _buildQuickPicksSection(tokens, quickPicksTracks, audioHandler),
                const SizedBox(height: 28),
                _buildFeaturedSection(tokens, featuredAsync, audioHandler, ref),
                const SizedBox(height: 28),
                _buildContinueListeningSection(
                  tokens,
                  historyAsync,
                  audioHandler,
                  isDesktop: false,
                ),
                const SizedBox(height: 32),
                shelvesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (shelves) {
                    if (shelves.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final shelf in shelves) ...[
                          _buildShelfSection(context, tokens, shelf, audioHandler, ref),
                          const SizedBox(height: 32),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                _buildPopularArtistsShelf(tokens),
                const SizedBox(height: 140),
              ],
            ),
    );
  }

  Widget _buildShelfSection(
    BuildContext context,
    AppTokens tokens,
    Shelf shelf,
    dynamic audioHandler,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shelf.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontPageTitle,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: tokens.textPrimary,
                    ),
                  ),
                  if (shelf.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      shelf.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BouncingScaleButton(
                  scaleFactor: 0.94,
                  minTouchTarget: 0,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TracksListScreen(
                          title: shelf.title,
                          subtitle: shelf.subtitle,
                          icon: Icons.music_note_rounded,
                          iconColor: tokens.accent,
                          initialTracks: shelf.tracks,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Show all',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      color: tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BouncingScaleButton(
                  scaleFactor: 0.94,
                  onTap: () {
                    if (shelf.tracks.isNotEmpty) {
                      audioHandler.setQueue(shelf.tracks);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(tokens.radiusFull),
                    ),
                    child: Text(
                      'Play All',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        color: tokens.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 215,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shelf.tracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final track = shelf.tracks[index];
              return _buildRecentTrackCard(tokens, track, audioHandler);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTrackCard(
      AppTokens tokens, Track track, dynamic audioHandler) {
    return MediaCard(
      title: track.title,
      subtitle: track.artist,
      imageUrl: track.coverUrl,
      width: 140,
      onTap: () => audioHandler.playTrack(track),
      onPlayTap: () => audioHandler.playTrack(track),
    );
  }

  Widget _buildFilterChips(AppTokens tokens) {
    const filters = ['All', 'Energize', 'Workout', 'Relax', 'Focus', 'Commute', 'Podcasts'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: filters.map((f) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppFilterChip(
              label: f,
              isSelected: _selectedFilter == f,
              onTap: () {
                if (f == 'Podcasts') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PodcastPage(),
                    ),
                  );
                  return;
                }
                setState(() => _selectedFilter = f);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGreetingHeader(AppTokens tokens, String? userName, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(userName, isDesktop: isDesktop),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontPageTitle,
                      fontSize: isDesktop ? 30 : 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: tokens.textPrimary,
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Pick up right where you left off, or explore your library.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 13,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isDesktop)
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Linux Desktop Client',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  AppPillButton(
                    label: 'Import Spotify',
                    icon: const Icon(Icons.sync_alt_rounded, size: 16),
                    variant: AppPillButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SpotifyImportScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedDialSection(
    AppTokens tokens,
    List<Track> tracks,
    dynamic audioHandler,
  ) {
    if (tracks.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // Metrolist columns: 3 on mobile portrait, 4-6 on tablet/desktop
        final columns = (availableWidth / 120).floor().clamp(3, 6);
        final rows = columns >= 5 ? 1 : 2;
        final totalSlots = columns * rows;
        // Reserve the last slot for Lucky Pick (Surprise Me / Randomize)
        final displayTracks = tracks.take(totalSlots - 1).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Speed dial',
                style: TextStyle(
                  fontFamily: AppTheme.fontPageTitle,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemCount: displayTracks.length + 1,
              itemBuilder: (context, i) {
                if (i == displayTracks.length) {
                  return MetrolistRandomizeGridItem(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      final list = tracks;
                      if (list.isNotEmpty) {
                        final lucky = list[math.Random().nextInt(list.length)];
                        audioHandler.playTrack(lucky);
                      }
                    },
                  );
                }
                final track = displayTracks[i];
                return MetrolistSpeedDialItem(
                  title: track.title,
                  subtitle: track.artist,
                  coverUrl: track.coverUrl,
                  onTap: () => audioHandler.playTrack(track),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickPicksSection(
    AppTokens tokens,
    List<Track> tracks,
    dynamic audioHandler,
  ) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    final displayTracks = tracks.take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'START RADIO FROM A SONG',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Quick picks',
                    style: TextStyle(
                      fontFamily: AppTheme.fontPageTitle,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () {
                if (displayTracks.isNotEmpty) {
                  audioHandler.setQueue(displayTracks);
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: tokens.accent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                minimumSize: const Size(0, 28),
              ),
              child: Text(
                'Play all',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  color: tokens.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 126,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 260,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: displayTracks.length,
            itemBuilder: (context, index) {
              final track = displayTracks[index];
              return _buildQuickPickItem(tokens, track, audioHandler);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPickItem(
    AppTokens tokens,
    Track track,
    dynamic audioHandler,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => audioHandler.playTrack(track),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            border: Border.all(
              color: tokens.surfaceHighlight.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        imageUrl: track.coverUrl,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.2),
                        child: Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
                        fontSize: 11,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: tokens.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 18,
                onPressed: () {
                  TrackOptionsBottomSheet.show(context, track: track);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }


  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildContinueListeningSection(
    AppTokens tokens,
    AsyncValue<List<dynamic>> historyAsync,
    dynamic audioHandler, {
    required bool isDesktop,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Recently Played',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontPageTitle,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            BouncingScaleButton(
              scaleFactor: 0.94,
              minTouchTarget: 0,
              onTap: () {
                final history = historyAsync.value ?? [];
                final tracks = history
                    .map((h) => h.track)
                    .whereType<Track>()
                    .toList();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TracksListScreen(
                      title: 'Recently Played',
                      subtitle: '${tracks.length} tracks',
                      icon: Icons.history_rounded,
                      iconColor: tokens.accent,
                      initialTracks: tracks,
                    ),
                  ),
                );
              },
              child: Text(
                'Show all',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        historyAsync.when(
          loading: () => SizedBox(
            height: 204,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, __) => Container(
                width: 140,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusLg),
                  border: Border.all(
                    color: tokens.surfaceHighlight.withValues(alpha: 0.8),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(
                      width: 124,
                      height: 124,
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                    ),
                    const SizedBox(height: 8),
                    ShimmerSkeleton(
                      width: 100,
                      height: 12,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    const SizedBox(height: 4),
                    ShimmerSkeleton(
                      width: 70,
                      height: 10,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ],
                ),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (history) {
            if (history.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusLg),
                  border: Border.all(
                    color: tokens.surfaceHighlight,
                    width: 1,
                  ),
                ),
                child: Text(
                  'No recently played tracks yet. Start exploring below.',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 13,
                  ),
                ),
              );
            }

            return SizedBox(
              height: 204,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = history[index];
                  return _buildRecentTrackCard(tokens, item.track, audioHandler);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeaturedSection(
    AppTokens tokens,
    AsyncValue<dynamic> featuredAsync,
    dynamic audioHandler,
    WidgetRef ref,
  ) {
    return featuredAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerSkeleton(
                width: 140,
                height: 22,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
              ShimmerSkeleton(
                width: 50,
                height: 14,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 204,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, __) => Container(
                width: 140,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusLg),
                  border: Border.all(
                    color: tokens.surfaceHighlight.withValues(alpha: 0.8),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(
                      width: 124,
                      height: 124,
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                    ),
                    const SizedBox(height: 8),
                    ShimmerSkeleton(
                      width: 100,
                      height: 12,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    const SizedBox(height: 4),
                    ShimmerSkeleton(
                      width: 70,
                      height: 10,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (featured) {
        if (featured.tracks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Made For You',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontPageTitle,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: tokens.textPrimary,
                        ),
                      ),
                      if (featured.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          featured.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontUi,
                            fontSize: 12,
                            color: tokens.textSecondary,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                BouncingScaleButton(
                  scaleFactor: 0.94,
                  minTouchTarget: 0,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TracksListScreen(
                          title: 'Made For You',
                          subtitle: featured.subtitle,
                          icon: Icons.auto_awesome_rounded,
                          iconColor: tokens.accent,
                          initialTracks: featured.tracks,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Show all',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      color: tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 204,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.tracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final track = featured.tracks[index];
                  return MediaCard(
                    title: track.title,
                    subtitle: track.artist,
                    imageUrl: track.coverUrl,
                    width: 140,
                    onTap: () {
                      final idx = featured.tracks.indexOf(track);
                      audioHandler.setQueue(featured.tracks, startIndex: idx >= 0 ? idx : 0);
                    },
                    onPlayTap: () {
                      final idx = featured.tracks.indexOf(track);
                      audioHandler.setQueue(featured.tracks, startIndex: idx >= 0 ? idx : 0);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopularArtistsShelf(AppTokens tokens) {
    const popularArtists = [
      {
        'name': 'Daft Punk',
        'tag': 'Electronic Duo',
        'image': 'https://cdn-images.dzcdn.net/images/artist/638e69b9caaf9f9f3f8826febea7b543/500x500-000000-80-0-0.jpg',
      },
      {
        'name': 'The Weeknd',
        'tag': 'R&B / Synthpop',
        'image': 'https://cdn-images.dzcdn.net/images/artist/581693b4724a7fcfa754455101e13a44/500x500-000000-80-0-0.jpg',
      },
      {
        'name': 'Billie Eilish',
        'tag': 'Alt Pop',
        'image': 'https://cdn-images.dzcdn.net/images/artist/8eab1a9a644889aabaca1e193e05f984/500x500-000000-80-0-0.jpg',
      },
      {
        'name': 'Taylor Swift',
        'tag': 'Pop / Indie Folk',
        'image': 'https://cdn-images.dzcdn.net/images/artist/cc2495870fe1a792ad0cdb05501ad5ec/500x500-000000-80-0-0.jpg',
      },
      {
        'name': 'Arijit Singh',
        'tag': 'Bollywood / Playback',
        'image': 'https://cdn-images.dzcdn.net/images/artist/ac5350cff290edd5b69fa584b8b1bd4f/500x500-000000-80-0-0.jpg',
      },
      {
        'name': 'Coldplay',
        'tag': 'Alt Rock / Pop',
        'image': 'https://cdn-images.dzcdn.net/images/artist/3087954bca22f306324912e5ac8375c3/500x500-000000-80-0-0.jpg',
      },
      {
        'name': 'Drake',
        'tag': 'Hip-Hop / Rap',
        'image': 'https://cdn-images.dzcdn.net/images/artist/70223888f501f4b843142e071abda364/500x500-000000-80-0-0.jpg',
      },
      {
        'name': 'Diljit Dosanjh',
        'tag': 'Punjabi Pop',
        'image': 'https://cdn-images.dzcdn.net/images/artist/79b85e695e0ca6529e56bf3b628e92bd/500x500-000000-80-0-0.jpg',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Popular Artists',
              style: TextStyle(
                fontFamily: AppTheme.fontPageTitle,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: popularArtists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final a = popularArtists[index];
              return ArtistCard(
                name: a['name']!,
                subtitle: a['tag'],
                imageUrl: a['image'],
                width: 130,
                onTap: () async {
                  final disco = await ref.read(artistDiscographySearchProvider(a['name']!).future);
                  if (disco != null && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ArtistDiscographyScreen(disco: disco),
                      ),
                    );
                  }
                },
                onPlayTap: () async {
                  final disco = await ref.read(artistDiscographySearchProvider(a['name']!).future);
                  if (disco != null && disco.allTracks.isNotEmpty) {
                    ref.read(audioHandlerProvider).setQueue(disco.allTracks);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpNextSidebar(AppTokens tokens, dynamic audioHandler) {
    final queueAsync = ref.watch(queueProvider);
    final currentTrack = ref.watch(currentTrackProvider).value;
    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final isPlaying = playbackState?.playing ?? false;
    final queue = queueAsync.value ?? [];

    return Container(
      width: 330,
      margin: const EdgeInsets.fromLTRB(0, 24, 24, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(
          color: tokens.divider,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Up Next',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTheme.fontPageTitle,
                  color: tokens.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusFull),
                  border: Border.all(color: tokens.divider, width: 1),
                ),
                child: Text(
                  '${queue.length} in queue',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: tokens.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // "Playing Now" Card
          if (currentTrack != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.surfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: tokens.accent.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tokens.card,
                          borderRadius: BorderRadius.circular(6),
                          image: currentTrack.coverUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(currentTrack.coverUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: currentTrack.coverUrl == null
                            ? Icon(Icons.music_note_rounded, color: tokens.accent, size: 22)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentTrack.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentTrack.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                        color: tokens.accent,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // Queue Items
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: Text(
                      'Queue is empty.\nPlay any song to populate.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textMuted,
                        height: 1.5,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: queue.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final track = queue[index];
                      final isCurrent = currentTrack?.id == track.id;

                      return InkWell(
                        onTap: () => audioHandler.skipToQueueItem(index),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent ? tokens.surfaceElevated : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isCurrent
                                ? Border.all(color: tokens.divider, width: 1)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${index + 1}',
                                style: AppTheme.tabularTimestamp(
                                  fontSize: 12,
                                  color: isCurrent ? tokens.accent : tokens.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
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
                                        fontSize: 12,
                                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                        color: isCurrent ? tokens.accent : tokens.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontUi,
                                        fontSize: 12, // Strict 12px floor
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatDuration(track.duration),
                                style: AppTheme.tabularTimestamp(
                                  fontSize: 12,
                                  color: tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 12),

          // Friendly Tip spacebar shortcut card
          AppSurface(
            padding: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(tokens.radiusCard),
            withBlur: true,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tokens.divider, width: 1.0),
                  ),
                  child: Text(
                    'Space',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: tokens.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Press [Space] anywhere to pause or play immediately.',
                    style: TextStyle(
                      fontSize: 12, // Strict 12px floor
                      fontFamily: AppTheme.fontUi,
                      color: AppTheme.textSecondary,
                    ),
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


