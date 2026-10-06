import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/player_providers.dart';
import '../providers/settings_providers.dart';
import '../theme/app_tokens.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/shimmer_skeleton.dart';
import '../widgets/track_options_bottom_sheet.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
    final audioHandler = ref.watch(audioHandlerProvider);

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(
          _getGreeting(userName),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: tokens.textPrimary,
          ),
        ),
        actions: [
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Icon(Icons.settings_outlined, size: 22),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. Quick Access Row (Liked Songs, Offline Downloads)
          Row(
            children: [
              Expanded(
                child: _buildQuickCard(
                  tokens: tokens,
                  title: 'Liked Songs',
                  subtitle: '${likedCountAsync.value?.length ?? 0} tracks',
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFE91E63),
                  onTap: () {
                    final liked = likedCountAsync.value;
                    if (liked != null && liked.isNotEmpty) {
                      audioHandler.setQueue(liked);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickCard(
                  tokens: tokens,
                  title: 'Downloads',
                  subtitle:
                      '${downloadsCountAsync.value?.where((d) => d.isCompleted).length ?? 0} offline',
                  icon: Icons.download_done_rounded,
                  iconColor: tokens.accent,
                  onTap: () {
                    final dls = downloadsCountAsync.value
                        ?.where((d) => d.isCompleted && d.track != null)
                        .map((d) => d.track!)
                        .toList();
                    if (dls != null && dls.isNotEmpty) {
                      audioHandler.setQueue(dls);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // 2. Recently Played Section
          Text(
            'Recently Played',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          historyAsync.when(
            loading: () => SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(
                      width: 130,
                      height: 130,
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                    ),
                    const SizedBox(height: 8),
                    ShimmerSkeleton(
                      width: 100,
                      height: 12,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ],
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (history) {
              if (history.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
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
                height: 185,
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

          const SizedBox(height: 32),

          // 3. Featured Music Section (Taste-Based Recommendations)
          featuredAsync.when(
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
                  5,
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
                                borderRadius:
                                    BorderRadius.circular(tokens.radiusSm),
                              ),
                              const SizedBox(height: 6),
                              ShimmerSkeleton(
                                width: 120,
                                height: 10,
                                borderRadius:
                                    BorderRadius.circular(tokens.radiusSm),
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
                              'Featured Music',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
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
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      BouncingScaleButton(
                        scaleFactor: 0.94,
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
                            borderRadius:
                                BorderRadius.circular(tokens.radiusFull),
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
          ),

          // Generous bottom clearance for floating MiniPlayer + SlimBottomNavBar
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildQuickCard({
    required AppTokens tokens,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return BouncingScaleButton(
      scaleFactor: 0.96,
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: -0.2,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTrackCard(
      AppTokens tokens, Track track, dynamic audioHandler) {
    return BouncingScaleButton(
      scaleFactor: 0.95,
      onTap: () => audioHandler.playTrack(track),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                child: track.coverUrl != null
                    ? Image.network(
                        track.coverUrl!,
                        width: 130,
                        height: 130,
                        cacheWidth: 390,
                        cacheHeight: 390,
                        gaplessPlayback: true,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackThumb(tokens),
                      )
                    : _fallbackThumb(tokens),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: -0.2,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
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
}
