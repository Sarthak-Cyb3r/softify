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
import '../widgets/shared/shared_components.dart';
import '../widgets/shimmer_skeleton.dart';
import '../widgets/track_options_bottom_sheet.dart';
import 'equalizer_screen.dart';
import 'settings_screen.dart';
import 'spotify_import_screen.dart';
import 'artist_discography_screen.dart';
import '../../features/podcasts/presentation/podcast_page.dart';
import '../providers/search_providers.dart';

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
  }

  String _getGreeting(String? userName) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : (hour < 18 ? 'Good afternoon' : 'Good evening');

    if (userName != null && userName.trim().isNotEmpty) {
      return '$timeGreeting, ${userName.trim()}';
    }
    return timeGreeting;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final userName = ref.watch(userNameProvider);
    final historyAsync = ref.watch(playHistoryStreamProvider);
    final likedCountAsync = ref.watch(likedTracksStreamProvider);
    final downloadsCountAsync = ref.watch(downloadsStreamProvider);
    final featuredAsync = ref.watch(featuredMusicProvider);
    final shelvesAsync = ref.watch(homeShelvesProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: isDesktop
          ? null
          : AppBar(
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
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1DB954),
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
                ],
              ),
              actions: [
                BouncingScaleButton(
                  scaleFactor: 0.9,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EqualizerScreen(),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Icon(Icons.tune_rounded, size: 22, color: Color(0xFFB3B3B3)),
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
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 8),
                    child: Icon(Icons.settings_outlined, size: 22, color: Color(0xFFB3B3B3)),
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
                      // Filter Chips Bar
                      _buildFilterChips(tokens),
                      // 1. Listening Room Header & Status Indicator
                      _buildGreetingHeader(tokens, userName, true),
                      const SizedBox(height: 20),

                      // 2. 6-Card Quick-Access Bento Grid
                      _buildBentoGrid(
                        tokens: tokens,
                        likedCount: likedCountAsync.value?.length ?? 0,
                        downloadsCount: downloadsCountAsync.value?.where((d) => d.isCompleted).length ?? 0,
                        onLikedTap: () {
                          final liked = likedCountAsync.value;
                          if (liked != null && liked.isNotEmpty) {
                            audioHandler.setQueue(liked);
                          }
                        },
                        onDownloadsTap: () {
                          final dls = downloadsCountAsync.value
                              ?.where((d) => d.isCompleted && d.track != null)
                              .map((d) => d.track!)
                              .toList();
                          if (dls != null && dls.isNotEmpty) {
                            audioHandler.setQueue(dls);
                          }
                        },
                        isDesktop: true,
                      ),
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
                _buildGreetingHeader(tokens, userName, false),
                const SizedBox(height: 14),
                _buildBentoGrid(
                  tokens: tokens,
                  likedCount: likedCountAsync.value?.length ?? 0,
                  downloadsCount: downloadsCountAsync.value?.where((d) => d.isCompleted).length ?? 0,
                  onLikedTap: () {
                    final liked = likedCountAsync.value;
                    if (liked != null && liked.isNotEmpty) {
                      audioHandler.setQueue(liked);
                    }
                  },
                  onDownloadsTap: () {
                    final dls = downloadsCountAsync.value
                        ?.where((d) => d.isCompleted && d.track != null)
                        .map((d) => d.track!)
                        .toList();
                    if (dls != null && dls.isNotEmpty) {
                      audioHandler.setQueue(dls);
                    }
                  },
                  isDesktop: false,
                ),
                const SizedBox(height: 28),
                _buildContinueListeningSection(
                  tokens,
                  historyAsync,
                  audioHandler,
                  isDesktop: false,
                ),
                const SizedBox(height: 32),
                _buildFeaturedSection(tokens, featuredAsync, audioHandler, ref),
                const SizedBox(height: 32),
                _buildPopularArtistsShelf(tokens),
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

  Widget _buildTrackTile(AppTokens tokens, Track track, List<Track> playlist,
      dynamic audioHandler, WidgetRef ref) {
    final isLikedAsync = ref.watch(isTrackLikedProvider(track.id));
    final isLiked = isLikedAsync.value ?? track.isLiked;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        onTap: () {
          final idx = playlist.indexOf(track);
          audioHandler.setQueue(playlist, startIndex: idx >= 0 ? idx : 0);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                child: track.coverUrl != null
                    ? Image.network(
                        track.coverUrl!,
                        width: 48,
                        height: 48,
                        cacheWidth: 144,
                        cacheHeight: 144,
                        gaplessPlayback: true,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackThumb(tokens),
                      )
                    : _fallbackThumb(tokens),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.2,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              BouncingScaleButton(
                scaleFactor: 0.88,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(libraryRepositoryProvider)
                      .setLiked(track.id, !isLiked, track: track);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? tokens.accent : tokens.textSecondary.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ),
              ),
              BouncingScaleButton(
                scaleFactor: 0.88,
                onTap: () {
                  TrackOptionsBottomSheet.show(context, track: track);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: tokens.textSecondary.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildFilterChips(AppTokens tokens) {
    const filters = ['All', 'Music', 'Podcasts'];
    return Padding(
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
                    _getGreeting(userName),
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

  Widget _buildBentoGrid({
    required AppTokens tokens,
    required int likedCount,
    required int downloadsCount,
    required VoidCallback onLikedTap,
    required VoidCallback onDownloadsTap,
    required bool isDesktop,
  }) {
    final crossAxisCount = isDesktop ? 3 : 2;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: isDesktop ? 3.4 : 2.5,
      children: [
        _buildBentoItem(
          tokens: tokens,
          title: 'Liked Songs',
          subtitle: '$likedCount songs',
          isGradient: true,
          icon: Icons.favorite_rounded,
          iconColor: Colors.white,
          onTap: onLikedTap,
        ),
        _buildBentoItem(
          tokens: tokens,
          title: 'Downloads',
          subtitle: '$downloadsCount tracks',
          icon: Icons.download_done_rounded,
          iconColor: tokens.accent,
          onTap: onDownloadsTap,
        ),
        _buildBentoItem(
          tokens: tokens,
          title: 'Rainy Twilight',
          subtitle: 'Curated mix',
          icon: Icons.music_note_rounded,
          iconColor: tokens.accent,
          onTap: onLikedTap,
        ),
        _buildBentoItem(
          tokens: tokens,
          title: 'Deep Focus',
          subtitle: 'Ambient beats',
          icon: Icons.headphones_rounded,
          iconColor: tokens.accent,
          onTap: onDownloadsTap,
        ),
        _buildBentoItem(
          tokens: tokens,
          title: 'Daily Mix 1',
          subtitle: 'Made for you',
          icon: Icons.album_rounded,
          iconColor: tokens.accent,
          onTap: onLikedTap,
        ),
        _buildBentoItem(
          tokens: tokens,
          title: 'Discover Weekly',
          subtitle: 'Fresh arrivals',
          icon: Icons.auto_awesome_rounded,
          iconColor: tokens.accent,
          onTap: onDownloadsTap,
        ),
      ],
    );
  }

  Widget _buildBentoItem({
    required AppTokens tokens,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool isGradient = false,
  }) {
    return _BentoHoverItem(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      isGradient: isGradient,
      tokens: tokens,
      onTap: onTap,
    );
  }

  Widget _fallbackThumb(AppTokens tokens) {
    return Container(
      width: 48,
      height: 48,
      color: tokens.surfaceHighlight,
      child: Icon(
        Icons.music_note_rounded,
        color: tokens.textMuted,
        size: 22,
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
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Continue Listening',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: tokens.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              'RESUME BUFFER',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: tokens.textMuted,
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
                width: 136,
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
                      width: 120,
                      height: 120,
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

            // On Mobile: Clean 2x2 Continue Listening Grid (Stitch spec)
            if (!isDesktop && history.length >= 2) {
              final gridItems = history.take(4).toList();
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.5,
                ),
                itemCount: gridItems.length,
                itemBuilder: (context, index) {
                  final track = gridItems[index].track;
                  return _buildMobileContinueCard(tokens, track, audioHandler);
                },
              );
            }

            return SizedBox(
              height: 204,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
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

  Widget _buildMobileContinueCard(
    AppTokens tokens,
    Track track,
    dynamic audioHandler,
  ) {
    return BouncingScaleButton(
      scaleFactor: 0.96,
      minTouchTarget: 0,
      onTap: () => audioHandler.playTrack(track),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          border: Border.all(
            color: tokens.surfaceHighlight.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              child: SizedBox(
                width: 42,
                height: 42,
                child: track.coverUrl != null
                    ? Image.network(
                        track.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackThumb(tokens),
                      )
                    : _fallbackThumb(tokens),
              ),
            ),
            const SizedBox(width: 8),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.accent,
              ),
              child: const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 17,
                  color: Color(0xFF080F11),
                ),
              ),
            ),
          ],
        ),
      ),
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
          ShimmerSkeleton(
            width: 160,
            height: 20,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            4,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  ShimmerSkeleton(
                    width: 48,
                    height: 48,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerSkeleton(
                          width: double.infinity,
                          height: 14,
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                        ),
                        const SizedBox(height: 6),
                        ShimmerSkeleton(
                          width: 120,
                          height: 10,
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (featured) {
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        featured.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                BouncingScaleButton(
                  scaleFactor: 0.94,
                  minTouchTarget: 0,
                  onTap: () {
                    if (featured.tracks.isNotEmpty) {
                      audioHandler.setQueue(featured.tracks);
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
                      border: Border.all(
                        color: tokens.accent.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'Play All',
                      style: TextStyle(
                        color: tokens.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...featured.tracks.map((t) =>
                _buildTrackTile(tokens, t, featured.tracks, audioHandler, ref)),
          ],
        );
      },
    );
  }

  Widget _buildPopularArtistsShelf(AppTokens tokens) {
    const popularArtists = [
      {'name': 'Daft Punk', 'tag': 'Electronic Duo'},
      {'name': 'The Weeknd', 'tag': 'R&B / Synthpop'},
      {'name': 'Billie Eilish', 'tag': 'Alt Pop'},
      {'name': 'Taylor Swift', 'tag': 'Pop / Indie Folk'},
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
                imageUrl: null,
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
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1F1F23),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Up Next',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE3E2E6),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF292A2D),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${queue.length} in queue',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4EDEA3),
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
                color: const Color(0xFF292A2D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4EDEA3).withValues(alpha: 0.25),
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
                          color: const Color(0xFF1F1F23),
                          borderRadius: BorderRadius.circular(8),
                          image: currentTrack.coverUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(currentTrack.coverUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: currentTrack.coverUrl == null
                            ? const Icon(Icons.music_note_rounded, color: Color(0xFF4EDEA3), size: 22)
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
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE3E2E6),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentTrack.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFBBCABF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                        color: const Color(0xFF4EDEA3),
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
                            color: isCurrent ? const Color(0xFF292A2D) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(tokens.radiusCard),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF292A2D),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Space',
                    style: TextStyle(
                      fontSize: 12, // Strict 12px floor
                      fontFamily: AppTheme.fontUi,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
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

class _BentoHoverItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isGradient;
  final AppTokens tokens;
  final VoidCallback onTap;

  const _BentoHoverItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.tokens,
    required this.onTap,
    this.isGradient = false,
  });

  @override
  State<_BentoHoverItem> createState() => _BentoHoverItemState();
}

class _BentoHoverItemState extends State<_BentoHoverItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: _isHovered ? tokens.cardHover : tokens.card,
            borderRadius: BorderRadius.circular(tokens.radiusCard),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: widget.isGradient
                      ? const LinearGradient(
                          colors: [Color(0xFF450AF5), Color(0xFFC4EFD9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: widget.isGradient ? null : tokens.surfaceElevated,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(tokens.radiusCard),
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: 22,
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
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
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
              const SizedBox(width: 6),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: _isHovered ? 1.0 : 0.0,
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 20,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
