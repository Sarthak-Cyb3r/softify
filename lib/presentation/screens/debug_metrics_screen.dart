import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/evaluation/team_draft_interleaver.dart';
import '../../domain/entities/interaction_events.dart';
import '../providers/player_providers.dart';
import '../theme/app_tokens.dart';

class DebugMetricsScreen extends ConsumerStatefulWidget {
  const DebugMetricsScreen({super.key});

  @override
  ConsumerState<DebugMetricsScreen> createState() => _DebugMetricsScreenState();
}

class _DebugMetricsScreenState extends ConsumerState<DebugMetricsScreen> {
  DebugMetricsSummary? _summary;
  Map<String, int>? _winRates;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    final logger = ref.read(eventLoggerProvider);
    final summary = await logger.getMetricsSummary();
    final db = ref.read(databaseProvider);
    final interleaver = TeamDraftInterleaver(db: db);
    final winRates = await interleaver.getModelWinRates();
    if (mounted) {
      setState(() {
        _summary = summary;
        _winRates = winRates;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearData() async {
    final tokens = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surfaceElevated,
        title: Text('Clear All Learning Data', style: TextStyle(color: tokens.textPrimary)),
        content: Text(
          'This will permanently delete all local play events, search events, and impression logs.',
          style: TextStyle(color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final logger = ref.read(eventLoggerProvider);
      await logger.clearAllLearningData();
      await _loadMetrics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All local learning data cleared.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Serving & Learning Metrics',
          style: TextStyle(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: tokens.textPrimary),
            onPressed: _loadMetrics,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: tokens.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Local Serving Diagnostics (No Telemetry)',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    tokens: tokens,
                    title: 'Stream Rate (≥ 30s)',
                    value: '${((_summary?.streamRate ?? 0) * 100).toStringAsFixed(1)}%',
                    subtitle: 'Plays sustained for 30 seconds or longer',
                    icon: Icons.play_circle_filled,
                    color: tokens.accent,
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    tokens: tokens,
                    title: 'Early Skip Rate (< 30s)',
                    value: '${((_summary?.earlySkipRate ?? 0) * 100).toStringAsFixed(1)}%',
                    subtitle: 'Plays skipped early before 30 seconds',
                    icon: Icons.skip_next,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    tokens: tokens,
                    title: 'Search Top-1 Click Rate',
                    value: '${((_summary?.searchTop1ClickRate ?? 0) * 100).toStringAsFixed(1)}%',
                    subtitle: 'Queries where top result was selected',
                    icon: Icons.filter_1,
                    color: Colors.cyanAccent,
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    tokens: tokens,
                    title: 'Median Time to Click',
                    value: '${_summary?.medianMsToClick ?? 0} ms',
                    subtitle: 'Decision latency from query display to click',
                    icon: Icons.timer,
                    color: Colors.purpleAccent,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCountTile(tokens, 'Total Plays', '${_summary?.totalPlays ?? 0}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCountTile(tokens, 'Total Searches', '${_summary?.totalSearches ?? 0}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // A/B Team-Draft Scoreboard
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.compare_arrows, color: Colors.cyanAccent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'A/B Team-Draft Interleaving Scoreboard',
                              style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Empirical single-device ranking validation between baseline and candidate models.',
                          style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ...(_winRates == null || _winRates!.isEmpty)
                            ? [
                                const Text(
                                  'No interleaving trials logged yet. Trials log automatically as searches and plays occur.',
                                  style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ]
                            : [
                                ..._winRates!.entries.map((e) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            e.key,
                                            style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                                          ),
                                          Text(
                                            '${e.value} wins',
                                            style: const TextStyle(
                                              color: Colors.cyanAccent,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear All Learning Data', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _clearData,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required AppTokens tokens,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCountTile(AppTokens tokens, String label, String count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Text(count, style: TextStyle(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
