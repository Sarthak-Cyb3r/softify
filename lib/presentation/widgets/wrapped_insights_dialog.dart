// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/smart_playlists_service.dart';
import '../providers/player_providers.dart';
import '../providers/shelf_providers.dart';
import '../theme/app_theme.dart';

/// Full-featured, interactive Softify Wrapped & On-Device Insights modal.
class WrappedInsightsDialog extends ConsumerStatefulWidget {
  const WrappedInsightsDialog({super.key});

  static Future<void> show(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (isDesktop) {
      return showDialog<void>(
        context: context,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: WrappedInsightsDialog(),
        ),
      );
    } else {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF131417),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => const WrappedInsightsDialog(),
      );
    }
  }

  @override
  ConsumerState<WrappedInsightsDialog> createState() => _WrappedInsightsDialogState();
}

class _WrappedInsightsDialogState extends ConsumerState<WrappedInsightsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final insightsAsync = ref.watch(listeningInsightsProvider);
    final activeTimeframe = ref.watch(listeningInsightsTimeframeProvider);

    return Container(
      width: isDesktop ? 680 : double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF131417),
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 0),
        border: Border.all(
          color: const Color(0xFF292A2D),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle for mobile
          if (!isDesktop) ...[
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],

          // Top Header & Title Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4EDEA3).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF4EDEA3),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Softify Wrapped & Insights',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '100% on-device telemetry • Zero central tracking',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: const Color(0xFF86948A),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Timeframe Selector Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                for (final tf in InsightsTimeframe.values) ...[
                  GestureDetector(
                    onTap: () {
                      ref.read(listeningInsightsTimeframeProvider.notifier).state = tf;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: activeTimeframe == tf
                            ? const Color(0xFF4EDEA3)
                            : const Color(0xFF1F2024),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: activeTimeframe == tf
                              ? const Color(0xFF4EDEA3)
                              : const Color(0xFF2C2D32),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        tf.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: activeTimeframe == tf ? FontWeight.w700 : FontWeight.w500,
                          color: activeTimeframe == tf
                              ? const Color(0xFF003824)
                              : const Color(0xFFBBCABF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Segmented Navigation Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1C20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF26272C), width: 1),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: const Color(0xFF282A30),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: const Color(0xFF4EDEA3),
              unselectedLabelColor: const Color(0xFF86948A),
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              padding: const EdgeInsets.all(3),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Top Songs'),
                Tab(text: 'Top Artists'),
                Tab(text: 'Rhythm & Clock'),
                Tab(text: 'Share Card'),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Tab Content
          Expanded(
            child: insightsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF4EDEA3), strokeWidth: 2.5),
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Failed to load insights: $err',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                ),
              ),
              data: (data) => TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(context, data),
                  _buildTopSongsTab(context, data),
                  _buildTopArtistsTab(context, data),
                  _buildRhythmTab(context, data),
                  _buildShareCardTab(context, data),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: OVERVIEW & BENTO METRICS
  // ==========================================
  Widget _buildOverviewTab(BuildContext context, ListeningInsights data) {
    final tokens = context.tokens;
    final hours = (data.totalListeningTime.inMinutes / 60).toStringAsFixed(1);
    final completionPct = (data.completionRate * 100).toStringAsFixed(0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Archetype Persona Hero Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E2824), Color(0xFF141917)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF4EDEA3).withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF4EDEA3).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    data.archetype.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4EDEA3).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LISTENING ARCHETYPE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4EDEA3),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.archetype.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE3E2E6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.archetype.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 4-Cell Bento Grid
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF4EDEA3),
                title: 'Total Listened',
                value: '$hours hrs',
                caption: '${data.totalListeningTime.inMinutes} minutes logged',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBentoCard(
                icon: Icons.graphic_eq_rounded,
                iconColor: const Color(0xFF60A5FA),
                title: 'Songs Streamed',
                value: '${data.totalTracksPlayed}',
                caption: 'Active listening plays',
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                icon: Icons.group_outlined,
                iconColor: const Color(0xFFA78BFA),
                title: 'Artists Discovered',
                value: '${data.uniqueArtistsCount}',
                caption: 'Catalog variety',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBentoCard(
                icon: Icons.task_alt_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Completion Rate',
                value: '$completionPct%',
                caption: 'Tracks heard fully',
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Prime Listening Vibe
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF292A2D), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.wb_twilight_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peak Sonic Habit',
                      style: TextStyle(color: tokens.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.primeListeningTime,
                      style: const TextStyle(
                        color: Color(0xFFE3E2E6),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Top Artist Spotlight
        if (data.detailedTopArtists.isNotEmpty) ...[
          Text(
            'Top Artist Spotlight',
            style: TextStyle(color: tokens.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _buildArtistHighlightCard(data.detailedTopArtists.first),
        ],
      ],
    );
  }

  Widget _buildBentoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String caption,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF292A2D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF86948A), fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF86948A), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistHighlightCard(ArtistInsight artist) {
    final mins = (artist.totalTime.inSeconds / 60).toStringAsFixed(1);
    final share = (artist.sharePercentage * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF292A2D), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF4EDEA3).withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.person_rounded, color: Color(0xFF4EDEA3), size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE3E2E6),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${artist.playCount} plays • $mins mins ($share% of your listening)',
                  style: const TextStyle(color: Color(0xFF86948A), fontSize: 11.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4EDEA3).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '#1 ARTIST',
              style: TextStyle(
                color: Color(0xFF4EDEA3),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: TOP SONGS
  // ==========================================
  Widget _buildTopSongsTab(BuildContext context, ListeningInsights data) {
    final tokens = context.tokens;

    if (data.detailedTopTracks.isEmpty) {
      return Center(
        child: Text(
          'No songs streamed in this timeframe yet.',
          style: TextStyle(color: tokens.textMuted, fontSize: 13),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Queue All Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Most Played Tracks',
              style: TextStyle(color: tokens.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              icon: const Icon(Icons.playlist_play_rounded, size: 18, color: Color(0xFF4EDEA3)),
              label: const Text(
                'Play Top Tracks',
                style: TextStyle(color: Color(0xFF4EDEA3), fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                backgroundColor: const Color(0xFF4EDEA3).withOpacity(0.12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final tracks = data.topTracks;
                if (tracks.isNotEmpty) {
                  ref.read(audioHandlerProvider).setQueue(tracks);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playing Top ${tracks.length} Wrapped tracks'),
                      backgroundColor: const Color(0xFF1B1B1F),
                    ),
                  );
                }
              },
            ),
          ],
        ),

        const SizedBox(height: 10),

        for (int i = 0; i < data.detailedTopTracks.length; i++) ...[
          _buildTopTrackRow(context, i + 1, data.detailedTopTracks[i]),
          if (i < data.detailedTopTracks.length - 1)
            const Divider(color: Color(0xFF1F2024), height: 1),
        ],
      ],
    );
  }

  Widget _buildTopTrackRow(BuildContext context, int rank, TrackInsight item) {
    final track = item.track;
    final mins = (item.totalTime.inSeconds / 60).toStringAsFixed(1);

    Color rankColor = const Color(0xFF86948A);
    if (rank == 1) rankColor = const Color(0xFFF59E0B);
    if (rank == 2) rankColor = const Color(0xFFE5E7EB);
    if (rank == 3) rankColor = const Color(0xFFD97706);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        ref.read(audioHandlerProvider).setQueue([track]);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // Rank Number
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rankColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 40,
                height: 40,
                color: const Color(0xFF222328),
                child: track.coverUrl != null && track.coverUrl!.isNotEmpty
                    ? Image.network(
                        track.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.music_note,
                          color: Colors.white54,
                          size: 18,
                        ),
                      )
                    : const Icon(Icons.music_note, color: Colors.white54, size: 18),
              ),
            ),
            const SizedBox(width: 12),

            // Title & Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE3E2E6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF86948A),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Plays & Duration
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.playCount} plays',
                  style: const TextStyle(
                    color: Color(0xFF4EDEA3),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$mins mins',
                  style: const TextStyle(
                    color: Color(0xFF86948A),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: TOP ARTISTS
  // ==========================================
  Widget _buildTopArtistsTab(BuildContext context, ListeningInsights data) {
    final tokens = context.tokens;

    if (data.detailedTopArtists.isEmpty) {
      return Center(
        child: Text(
          'No artist data logged for this timeframe.',
          style: TextStyle(color: tokens.textMuted, fontSize: 13),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        for (int i = 0; i < data.detailedTopArtists.length; i++) ...[
          _buildArtistRow(context, i + 1, data.detailedTopArtists[i]),
          if (i < data.detailedTopArtists.length - 1)
            const Divider(color: Color(0xFF1F2024), height: 1),
        ],
      ],
    );
  }

  Widget _buildArtistRow(BuildContext context, int rank, ArtistInsight artist) {
    final mins = (artist.totalTime.inSeconds / 60).toStringAsFixed(1);
    final sharePct = (artist.sharePercentage * 100).toStringAsFixed(0);

    Color rankColor = const Color(0xFF86948A);
    if (rank == 1) rankColor = const Color(0xFFF59E0B);
    if (rank == 2) rankColor = const Color(0xFFE5E7EB);
    if (rank == 3) rankColor = const Color(0xFFD97706);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF4EDEA3).withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    artist.name.isNotEmpty ? artist.name.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFF4EDEA3),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE3E2E6),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${artist.playCount} plays • $mins mins',
                      style: const TextStyle(color: Color(0xFF86948A), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '$sharePct%',
                style: const TextStyle(
                  color: Color(0xFF4EDEA3),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Share percentage bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: artist.sharePercentage.clamp(0.02, 1.0),
              backgroundColor: const Color(0xFF222328),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4EDEA3)),
              minHeight: 3.5,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: LISTENING RHYTHM & 24H CLOCK
  // ==========================================
  Widget _buildRhythmTab(BuildContext context, ListeningInsights data) {
    final tokens = context.tokens;
    final maxBucket = data.hourlyDistribution.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          '24-Hour Listening Activity',
          style: TextStyle(color: tokens.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Shows how your listening rhythm shifts across the day',
          style: TextStyle(color: tokens.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 16),

        // Visual 24h Bar Chart
        Container(
          height: 130,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF292A2D), width: 1),
          ),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int h = 0; h < 24; h++) ...[
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final val = data.hourlyDistribution[h];
                            final double heightFactor =
                                maxBucket > 0 ? (val / maxBucket).clamp(0.04, 1.0) : 0.04;
                            final bool isPeak = val == maxBucket && maxBucket > 0;

                            return Tooltip(
                              message: '$h:00 - $val plays',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: Container(
                                  height: constraints.maxHeight * heightFactor,
                                  decoration: BoxDecoration(
                                    color: isPeak
                                        ? const Color(0xFF4EDEA3)
                                        : (val > 0
                                            ? const Color(0xFF4EDEA3).withOpacity(0.4)
                                            : const Color(0xFF2C2D32)),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('12 AM', style: TextStyle(color: Color(0xFF86948A), fontSize: 9.5)),
                  Text('6 AM', style: TextStyle(color: Color(0xFF86948A), fontSize: 9.5)),
                  Text('12 PM', style: TextStyle(color: Color(0xFF86948A), fontSize: 9.5)),
                  Text('6 PM', style: TextStyle(color: Color(0xFF86948A), fontSize: 9.5)),
                  Text('11 PM', style: TextStyle(color: Color(0xFF86948A), fontSize: 9.5)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Time quadrant breakdown
        Text(
          'Day Quadrant Distribution',
          style: TextStyle(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _buildQuadrantRow('Morning', '5 AM - 12 PM', _sumRange(data.hourlyDistribution, 5, 12), const Color(0xFFF59E0B)),
        const SizedBox(height: 8),
        _buildQuadrantRow('Afternoon', '12 PM - 5 PM', _sumRange(data.hourlyDistribution, 12, 17), const Color(0xFF3B82F6)),
        const SizedBox(height: 8),
        _buildQuadrantRow('Evening', '5 PM - 10 PM', _sumRange(data.hourlyDistribution, 17, 22), const Color(0xFF10B981)),
        const SizedBox(height: 8),
        _buildQuadrantRow('Night', '10 PM - 5 AM', _sumNight(data.hourlyDistribution), const Color(0xFF8B5CF6)),
      ],
    );
  }

  int _sumRange(List<int> list, int start, int end) {
    int sum = 0;
    for (int i = start; i < end && i < list.length; i++) {
      sum += list[i];
    }
    return sum;
  }

  int _sumNight(List<int> list) {
    int sum = 0;
    for (int i = 22; i < 24; i++) {
      sum += list[i];
    }
    for (int i = 0; i < 5; i++) {
      sum += list[i];
    }
    return sum;
  }

  Widget _buildQuadrantRow(String name, String timeRange, int count, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF292A2D), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Color(0xFFE3E2E6), fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                Text(timeRange, style: const TextStyle(color: Color(0xFF86948A), fontSize: 10.5)),
              ],
            ),
          ),
          Text(
            '$count plays',
            style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: SHAREABLE WRAPPED CARD
  // ==========================================
  Widget _buildShareCardTab(BuildContext context, ListeningInsights data) {
    final hours = (data.totalListeningTime.inMinutes / 60).toStringAsFixed(1);
    final topArtist = data.detailedTopArtists.isNotEmpty ? data.detailedTopArtists.first.name : 'Unknown';
    final topSong = data.topTracks.isNotEmpty ? data.topTracks.first.title : 'None';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // The Wrapped Poster Card
        Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2621), Color(0xFF0F1211), Color(0xFF141916)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4EDEA3).withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4EDEA3).withOpacity(0.12),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Softify Wrapped branding header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4EDEA3).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF4EDEA3), size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SOFTIFY',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4EDEA3).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data.timeframe.label.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF4EDEA3),
                          fontWeight: FontWeight.w800,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Archetype Badge
                Row(
                  children: [
                    Text(data.archetype.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MY LISTENING PERSONA',
                            style: TextStyle(
                              color: Color(0xFF4EDEA3),
                              fontWeight: FontWeight.w800,
                              fontSize: 9.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            data.archetype.title,
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(color: Color(0xFF2C3530), height: 1),
                const SizedBox(height: 16),

                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('HOURS LISTENED', style: TextStyle(color: Color(0xFF86948A), fontSize: 10, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('$hours hrs', style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 18, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TRACKS PLAYED', style: TextStyle(color: Color(0xFF86948A), fontSize: 10, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('${data.totalTracksPlayed}', style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 18, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Top Artist & Song
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOP ARTIST', style: TextStyle(color: Color(0xFF86948A), fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(topArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4EDEA3), fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    const Text('TOP SONG', style: TextStyle(color: Color(0xFF86948A), fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(topSong, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE3E2E6), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(color: Color(0xFF2C3530), height: 1),
                const SizedBox(height: 12),

                // Footer
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '100% On-Device & Private',
                      style: TextStyle(color: Color(0xFF86948A), fontSize: 10),
                    ),
                    Text(
                      '#SoftifyWrapped',
                      style: TextStyle(color: Color(0xFF4EDEA3), fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Copy Button
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Wrapped Story to Clipboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4EDEA3),
              foregroundColor: const Color(0xFF003824),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            onPressed: () {
              final shareText = '''
🎧 My Softify Wrapped (${data.timeframe.label})
⏱️ Total Listened: $hours hours (${data.totalListeningTime.inMinutes} mins)
🎵 Songs Streamed: ${data.totalTracksPlayed}
👥 Artists Discovered: ${data.uniqueArtistsCount}
🌟 Persona: ${data.archetype.title} ${data.archetype.emoji}
🎤 Top Artist: $topArtist
🎶 Top Track: $topSong
#SoftifyWrapped #PrivateMusic
'''.trim();

              Clipboard.setData(ClipboardData(text: shareText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied Softify Wrapped story to clipboard! 📋'),
                  backgroundColor: Color(0xFF1B1B1F),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
