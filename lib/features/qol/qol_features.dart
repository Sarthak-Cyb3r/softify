// ============================================================================
// Softify Quality of Life (QoL) Features Barrel & Centralized Registry
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../../presentation/theme/app_tokens.dart';

// ----------------------------------------------------------------------------
// Feature Module Exports (26 Modules)
// ----------------------------------------------------------------------------
export 'advanced_queue_actions.dart';
export 'audio_quality_badge_detail.dart';
export 'cache_storage_cleaner.dart';
export 'crossfade_transition_controller.dart' hide SharedPreferences;
export 'desktop_volume_scroll_listener.dart';
export 'double_tap_seek_overlay.dart';
export 'duplicate_track_detector.dart';
export 'headphone_disconnect_pause.dart';
export 'jump_to_current_track.dart';
export 'keyboard_shortcuts_dialog.dart';
export 'listening_history_manager.dart';
export 'lyrics_auto_scroll_lock.dart';
export 'lyrics_font_size_controller.dart' hide SharedPreferences;
export 'offline_mode_toggle.dart';
export 'oled_black_theme.dart' hide SharedPreferences;
export 'playback_speed_selector.dart';
export 'playlist_m3u_exporter.dart';
export 'playlist_m3u_importer.dart';
export 'playlist_search_filter.dart';
export 'playlist_sorter.dart';
export 'quick_mute_controller.dart';
export 'screen_wakelock_manager.dart';
export 'shake_to_shuffle.dart';
export 'sleep_timer_track_end.dart';
export 'track_share_helper.dart';
export 'track_tag_editor.dart';

// ----------------------------------------------------------------------------
// Internal imports for Registry & Showcase Screen
// ----------------------------------------------------------------------------
import 'advanced_queue_actions.dart';
import 'audio_quality_badge_detail.dart';
import 'cache_storage_cleaner.dart';
import 'crossfade_transition_controller.dart' hide SharedPreferences;
import 'double_tap_seek_overlay.dart';
import 'headphone_disconnect_pause.dart';
import 'keyboard_shortcuts_dialog.dart';
import 'listening_history_manager.dart';
import 'lyrics_auto_scroll_lock.dart';
import 'lyrics_font_size_controller.dart' hide SharedPreferences;
import 'offline_mode_toggle.dart';
import 'oled_black_theme.dart' hide SharedPreferences;
import 'playback_speed_selector.dart';
import 'playlist_m3u_importer.dart';
import 'playlist_search_filter.dart';
import 'playlist_sorter.dart';
import 'quick_mute_controller.dart';
import 'screen_wakelock_manager.dart';
import 'shake_to_shuffle.dart';
import 'sleep_timer_track_end.dart';
import 'track_share_helper.dart';
import 'track_tag_editor.dart';

// ============================================================================
// QoL Feature Categories
// ============================================================================

enum QolCategory {
  all('All Features', Icons.dashboard_customize_rounded),
  playback('Playback & Audio', Icons.play_circle_fill_rounded),
  lyrics('Lyrics & Typography', Icons.lyrics_rounded),
  playlistQueue('Playlists & Queue', Icons.queue_music_rounded),
  interfaceTheme('Appearance & Theme', Icons.palette_rounded),
  libraryData('Library & Storage', Icons.folder_rounded),
  convenience('Shortcuts & Utilities', Icons.bolt_rounded);

  final String label;
  final IconData icon;
  const QolCategory(this.label, this.icon);
}

// ============================================================================
// QoL Feature Definition Metadata
// ============================================================================

@immutable
class QolFeatureDefinition {
  final String id;
  final String name;
  final String description;
  final QolCategory category;
  final IconData icon;
  final String moduleFile;
  final bool hasToggle;
  final bool isExperimental;
  final bool isDesktopOnly;
  final String? badge;
  final void Function(BuildContext context, WidgetRef ref)? onTriggerDemo;

  const QolFeatureDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.moduleFile,
    this.hasToggle = true,
    this.isExperimental = false,
    this.isDesktopOnly = false,
    this.badge,
    this.onTriggerDemo,
  });
}

// ============================================================================
// Sample Track for Demonstrations
// ============================================================================

const _sampleDemoTrack = Track(
  id: 'demo_track_qol',
  sourceId: 'dX3k_PDnzHE',
  title: 'Midnight City',
  artist: 'M83',
  album: 'Hurry Up, We\'re Dreaming',
  duration: Duration(minutes: 4, seconds: 3),
);

// ============================================================================
// QoL Feature Registry
// ============================================================================

class QolFeatureRegistry {
  static final List<QolFeatureDefinition> features = [
    // 1. Lyrics Auto-Scroll Lock
    QolFeatureDefinition(
      id: 'lyrics_auto_scroll_lock',
      name: 'Lyrics Auto-Scroll Lock',
      description:
          'Temporarily locks auto-scroll when user manually scrolls lyrics, showing a floating resume pill.',
      category: QolCategory.lyrics,
      icon: Icons.lock_clock_rounded,
      moduleFile: 'lyrics_auto_scroll_lock.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        final notifier = ref.read(lyricsAutoScrollLockProvider.notifier);
        if (notifier.isLocked) {
          notifier.resume();
        } else {
          notifier.lock();
        }
        final locked = ref.read(lyricsAutoScrollLockProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lyrics Auto-Scroll Lock is now ${locked ? "LOCKED (paused)" : "UNLOCKED (auto-scrolling)"}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    ),

    // 2. Double Tap Seek Overlay
    QolFeatureDefinition(
      id: 'double_tap_seek_overlay',
      name: 'Double-Tap Artwork to Seek',
      description:
          'YouTube-style double tap gestures on player artwork to quickly jump forward or backward 10 seconds.',
      category: QolCategory.playback,
      icon: Icons.replay_10_rounded,
      moduleFile: 'double_tap_seek_overlay.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Double Tap Seek Demo'),
            content: SizedBox(
              height: 220,
              width: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DoubleTapSeekOverlay(
                  onTap: () {},
                  child: Container(
                    color: Colors.black87,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.album_rounded, size: 72, color: Colors.white70),
                        SizedBox(height: 12),
                        Text(
                          'Double tap Left or Right side',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    ),

    // 3. Track Share Helper
    QolFeatureDefinition(
      id: 'track_share_helper',
      name: '1-Tap Track Share & Clipboard Helper',
      description:
          'Instantly copy title, artist, streaming URLs, or display an elegant sharing sheet with system intent.',
      category: QolCategory.convenience,
      icon: Icons.share_rounded,
      moduleFile: 'track_share_helper.dart',
      hasToggle: false,
      onTriggerDemo: (context, ref) {
        TrackShareHelper.showShareModal(context, _sampleDemoTrack);
      },
    ),

    // 4. Playback Speed Selector
    QolFeatureDefinition(
      id: 'playback_speed_selector',
      name: 'Playback Speed Selector',
      description:
          'Fine-grained playback speed adjustment (0.5x to 2.0x) with pitch correction for podcasts and study.',
      category: QolCategory.playback,
      icon: Icons.speed_rounded,
      moduleFile: 'playback_speed_selector.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        PlaybackSpeedSelectorSheet.show(context);
      },
    ),

    // 5. Sleep Timer Stop After Track
    QolFeatureDefinition(
      id: 'sleep_timer_track_end',
      name: 'Sleep Timer: Stop at Track End',
      description:
          'Gracefully pauses audio immediately when the current track finishes playing, avoiding abrupt mid-song stops.',
      category: QolCategory.playback,
      icon: Icons.bedtime_rounded,
      moduleFile: 'sleep_timer_track_end.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        ref.read(endOfTrackSleepTimerProvider.notifier).toggle();
        final active = ref.read(endOfTrackSleepTimerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active
                  ? 'Stop after current track: ACTIVE'
                  : 'Stop after current track: OFF',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    ),

    // 6. Playlist Search Filter
    QolFeatureDefinition(
      id: 'playlist_search_filter',
      name: 'In-Playlist Instant Search & Filter',
      description:
          'Real-time keyword filtering across title, artist, and album in large playlists with match highlighting.',
      category: QolCategory.playlistQueue,
      icon: Icons.search_rounded,
      moduleFile: 'playlist_search_filter.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlaylistSearchFilterBar(
                  totalTrackCount: 42,
                  filteredTrackCount: 42,
                  onQueryChanged: (query) {},
                ),
                const SizedBox(height: 16),
                const Text(
                  'Type in the bar above to test instant search filtering.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    ),

    // 7. Playlist Sorter
    QolFeatureDefinition(
      id: 'playlist_sorter',
      name: 'Multi-Criteria Playlist Sorter',
      description:
          'Sort playlists by track title, artist, date added, duration, or randomized shuffle with order preservation.',
      category: QolCategory.playlistQueue,
      icon: Icons.sort_by_alpha_rounded,
      moduleFile: 'playlist_sorter.dart',
      hasToggle: false,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => PlaylistSortSheet(
            initialCriteria: PlaylistSortCriteria.titleAsc,
            onCriteriaSelected: (criteria) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected sort: ${criteria.label}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        );
      },
    ),

    // 8. Advanced Queue Actions
    QolFeatureDefinition(
      id: 'advanced_queue_actions',
      name: 'Advanced Queue Actions',
      description:
          'Batch operations, play next, insert after current, clear upcoming queue, and reorder controls.',
      category: QolCategory.playlistQueue,
      icon: Icons.queue_music_rounded,
      moduleFile: 'advanced_queue_actions.dart',
      hasToggle: false,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: QueueQuickActionsBar(),
          ),
        );
      },
    ),

    // 9. Desktop Volume Scroll Listener
    QolFeatureDefinition(
      id: 'desktop_volume_scroll_listener',
      name: 'Desktop Mouse Scroll Volume Control',
      description:
          'Scroll mouse wheel over the bottom player bar or full-screen view to dynamically adjust master volume.',
      category: QolCategory.convenience,
      icon: Icons.mouse_rounded,
      moduleFile: 'desktop_volume_scroll_listener.dart',
      hasToggle: true,
      isDesktopOnly: true,
      badge: 'Desktop',
      onTriggerDemo: (context, ref) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mouse wheel volume listener is ready. Scroll mouse wheel over the player to test.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      },
    ),

    // 10. Quick Mute Controller
    QolFeatureDefinition(
      id: 'quick_mute_controller',
      name: '1-Tap Quick Mute & Restore',
      description:
          'Instant volume mute toggle with memory of previous level, automatically restoring exact volume on unmute.',
      category: QolCategory.playback,
      icon: Icons.volume_off_rounded,
      moduleFile: 'quick_mute_controller.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        ref.read(quickMuteProvider.notifier).toggleMute();
        final state = ref.read(quickMuteProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.isMuted
                  ? 'Quick Mute: MUTED (Volume was ${(state.previousVolume * 100).round()}%)'
                  : 'Quick Mute: UNMUTED (Volume restored to ${(state.volume * 100).round()}%)',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    ),

    // 11. Keyboard Shortcuts Dialog
    QolFeatureDefinition(
      id: 'keyboard_shortcuts_dialog',
      name: 'Desktop Keyboard Shortcuts Cheat Sheet',
      description:
          'Rich visual modal showcasing all hotkeys for playback, queue management, volume, seeking, and navigation.',
      category: QolCategory.convenience,
      icon: Icons.keyboard_rounded,
      moduleFile: 'keyboard_shortcuts_dialog.dart',
      hasToggle: false,
      badge: 'Hotkeys',
      onTriggerDemo: (context, ref) {
        KeyboardShortcutsDialog.show(context);
      },
    ),

    // 12. Duplicate Track Detector
    QolFeatureDefinition(
      id: 'duplicate_track_detector',
      name: 'Smart Duplicate Track Detector',
      description:
          'Scans playlists for identical or duplicate audio items by URI or fuzzy metadata and cleans them in 1 tap.',
      category: QolCategory.playlistQueue,
      icon: Icons.copy_all_rounded,
      moduleFile: 'duplicate_track_detector.dart',
      hasToggle: false,
      onTriggerDemo: (context, ref) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Duplicate detector scanned: No duplicate tracks detected in active queue.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    ),

    // 13. Playlist M3U Exporter
    QolFeatureDefinition(
      id: 'playlist_m3u_exporter',
      name: 'Universal Playlist M3U8 Exporter',
      description:
          'Exports Softify playlists into standardized extended M3U8 playlist format for VLC and external players.',
      category: QolCategory.libraryData,
      icon: Icons.file_upload_rounded,
      moduleFile: 'playlist_m3u_exporter.dart',
      hasToggle: false,
      onTriggerDemo: (context, ref) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playlist M3U8 exporter initialized. Select playlist to export.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    ),

    // 14. Playlist M3U Importer
    QolFeatureDefinition(
      id: 'playlist_m3u_importer',
      name: 'Universal Playlist M3U8 Importer',
      description:
          'Parses local M3U/M3U8 files or raw playlist text, matching track metadata and importing to Softify.',
      category: QolCategory.libraryData,
      icon: Icons.file_download_rounded,
      moduleFile: 'playlist_m3u_importer.dart',
      hasToggle: false,
      onTriggerDemo: (context, ref) {
        PlaylistM3uImporter.showImportDialog(context);
      },
    ),

    // 15. Lyrics Font Size & Spacing Scaler
    QolFeatureDefinition(
      id: 'lyrics_font_size_controller',
      name: 'Lyrics Dynamic Typography Scaler',
      description:
          'Customizable lyrics text scale (0.8x to 1.6x) and line height spacing with live preview sheet.',
      category: QolCategory.lyrics,
      icon: Icons.format_size_rounded,
      moduleFile: 'lyrics_font_size_controller.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        LyricsFontScaleSheet.show(context);
      },
    ),

    // 16. Screen Wakelock Manager
    QolFeatureDefinition(
      id: 'screen_wakelock_manager',
      name: 'Player Screen Wakelock',
      description:
          'Prevents display sleep and dimming while lyrics view or full-screen album artwork is open.',
      category: QolCategory.convenience,
      icon: Icons.screen_lock_portrait_rounded,
      moduleFile: 'screen_wakelock_manager.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        ref.read(screenWakelockProvider.notifier).toggleMaster();
        final state = ref.read(screenWakelockProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.isMasterEnabled
                  ? 'Screen Wakelock: ENABLED (Screen will stay awake)'
                  : 'Screen Wakelock: DISABLED',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    ),

    // 17. Detailed Listening History
    QolFeatureDefinition(
      id: 'listening_history_manager',
      name: 'Listening History & Activity Log',
      description:
          'Chronological log of played songs, completion percentages, playback duration, and private session mode.',
      category: QolCategory.libraryData,
      icon: Icons.history_rounded,
      moduleFile: 'listening_history_manager.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        ref.read(privateListeningModeProvider.notifier).toggle();
        final isPrivate = ref.read(privateListeningModeProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPrivate
                  ? 'Private Listening Session: ACTIVE (History paused)'
                  : 'Private Listening Session: OFF (History active)',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    ),

    // 18. Audio Quality Badge & Detail Specs
    QolFeatureDefinition(
      id: 'audio_quality_badge_detail',
      name: 'Audio Quality Badge & Stream Specs',
      description:
          'Detailed audiophile inspector showing bitrate, sample rate, codec (Opus/AAC/FLAC), and CDN source.',
      category: QolCategory.playback,
      icon: Icons.high_quality_rounded,
      moduleFile: 'audio_quality_badge_detail.dart',
      hasToggle: false,
      onTriggerDemo: (context, ref) {
        showDialog(
          context: context,
          builder: (ctx) => const AudioQualityDetailDialog(),
        );
      },
    ),

    // 19. Headphone Disconnect Auto-Pause
    QolFeatureDefinition(
      id: 'headphone_disconnect_pause',
      name: 'Headphone / Bluetooth Disconnect Auto-Pause',
      description:
          'Protects privacy by immediately pausing playback when wired headphones or Bluetooth devices disconnect.',
      category: QolCategory.playback,
      icon: Icons.headphones_rounded,
      moduleFile: 'headphone_disconnect_pause.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        ref.read(pauseOnDisconnectEnabledProvider.notifier).toggle();
        final active = ref.read(pauseOnDisconnectEnabledProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active
                  ? 'Headphone Disconnect Auto-Pause: ACTIVE'
                  : 'Headphone Disconnect Auto-Pause: DISABLED',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    ),

    // 20. Jump to Current Track FAB
    QolFeatureDefinition(
      id: 'jump_to_current_track',
      name: 'Jump to Current Active Track',
      description:
          'Floating action button and shortcut to smoothly auto-scroll queue or playlist directly to the playing song.',
      category: QolCategory.playlistQueue,
      icon: Icons.my_location_rounded,
      moduleFile: 'jump_to_current_track.dart',
      hasToggle: false,
      onTriggerDemo: (context, ref) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jumped to active track in queue!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    ),

    // 21. Track Tag Editor
    QolFeatureDefinition(
      id: 'track_tag_editor',
      name: 'Audio Metadata & Tag Editor',
      description:
          'Edit title, artist, album, genre, release year, and embedded lyrics directly on downloaded songs.',
      category: QolCategory.libraryData,
      icon: Icons.edit_note_rounded,
      moduleFile: 'track_tag_editor.dart',
      hasToggle: false,
      onTriggerDemo: (context, ref) {
        showDialog(
          context: context,
          builder: (ctx) => const TrackTagEditorDialog(
            track: _sampleDemoTrack,
          ),
        );
      },
    ),

    // 22. Cache Storage Cleaner
    QolFeatureDefinition(
      id: 'cache_storage_cleaner',
      name: 'Smart Storage & Cache Cleaner',
      description:
          'Categorized breakdown of audio cache, artwork cache, and temporary files with 1-tap reclamation.',
      category: QolCategory.libraryData,
      icon: Icons.cleaning_services_rounded,
      moduleFile: 'cache_storage_cleaner.dart',
      hasToggle: false,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => const CacheStorageCleanerSheet(),
        );
      },
    ),

    // 23. OLED Pure Pitch Black Theme
    QolFeatureDefinition(
      id: 'oled_black_theme',
      name: 'Pure OLED Pitch Black Theme',
      description:
          'True #000000 pitch-black styling to maximize battery savings and aesthetic contrast on AMOLED screens.',
      category: QolCategory.interfaceTheme,
      icon: Icons.dark_mode_rounded,
      moduleFile: 'oled_black_theme.dart',
      hasToggle: true,
      badge: 'AMOLED',
      onTriggerDemo: (context, ref) {
        ref.read(isOledBlackEnabledProvider.notifier).toggle();
        final enabled = ref.read(isOledBlackEnabledProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled ? 'OLED Pitch Black Theme ENABLED' : 'OLED Pitch Black Theme DISABLED',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    ),

    // 24. Shake to Shuffle
    QolFeatureDefinition(
      id: 'shake_to_shuffle',
      name: 'Shake Device to Shuffle',
      description:
          'Physical device gesture support: give your phone a gentle shake to randomize the current queue and skip.',
      category: QolCategory.convenience,
      icon: Icons.vibration_rounded,
      moduleFile: 'shake_to_shuffle.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        ref.read(shakeToShuffleEnabledProvider.notifier).toggle();
        final enabled = ref.read(shakeToShuffleEnabledProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled ? 'Shake to Shuffle: ENABLED' : 'Shake to Shuffle: DISABLED',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    ),

    // 25. Crossfade Transition Controller
    QolFeatureDefinition(
      id: 'crossfade_transition_controller',
      name: 'Audio Crossfade & Gapless Transition',
      description:
          'Configurable smooth crossfade duration (0s to 12s) between tracks for seamless uninterrupted listening.',
      category: QolCategory.playback,
      icon: Icons.compare_arrows_rounded,
      moduleFile: 'crossfade_transition_controller.dart',
      hasToggle: true,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: CrossfadeSettingsCard(),
          ),
        );
      },
    ),

    // 26. Offline-Only Mode Toggle
    QolFeatureDefinition(
      id: 'offline_mode_toggle',
      name: 'Offline-Only Mode Toggle',
      description:
          'Enforce zero network data consumption by restricting playback strictly to downloaded and cached tracks.',
      category: QolCategory.libraryData,
      icon: Icons.cloud_off_rounded,
      moduleFile: 'offline_mode_toggle.dart',
      hasToggle: true,
      badge: 'Data Saver',
      onTriggerDemo: (context, ref) {
        ref.read(isOfflineOnlyModeProvider.notifier).toggle();
        final isOffline = ref.read(isOfflineOnlyModeProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOffline
                  ? 'Offline Mode: ENABLED (Only downloaded songs will play)'
                  : 'Offline Mode: DISABLED (Online streaming active)',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    ),
  ];

  static QolFeatureDefinition? findById(String id) {
    try {
      return features.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<QolFeatureDefinition> getByCategory(QolCategory category) {
    if (category == QolCategory.all) return features;
    return features.where((f) => f.category == category).toList();
  }
}

// ============================================================================
// Showcase Screen: QolFeaturesHubScreen
// ============================================================================

class QolFeaturesHubScreen extends ConsumerStatefulWidget {
  const QolFeaturesHubScreen({super.key});

  @override
  ConsumerState<QolFeaturesHubScreen> createState() => _QolFeaturesHubScreenState();
}

class _QolFeaturesHubScreenState extends ConsumerState<QolFeaturesHubScreen> {
  QolCategory _selectedCategory = QolCategory.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QolFeatureDefinition> get _filteredFeatures {
    final list = QolFeatureRegistry.getByCategory(_selectedCategory);
    if (_searchQuery.trim().isEmpty) return list;

    final q = _searchQuery.toLowerCase();
    return list.where((f) {
      return f.name.toLowerCase().contains(q) ||
          f.description.toLowerCase().contains(q) ||
          f.moduleFile.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // Watch active toggle states for live reactive UI
    final isOffline = ref.watch(isOfflineOnlyModeProvider);
    final isOled = ref.watch(isOledBlackEnabledProvider);
    final isAutoScrollLocked = ref.watch(lyricsAutoScrollLockProvider);
    final isQuickMuted = ref.watch(quickMuteProvider).isMuted;
    final isStopAtEnd = ref.watch(endOfTrackSleepTimerProvider);
    final isWakelock = ref.watch(screenWakelockProvider).isMasterEnabled;
    final isShakeEnabled = ref.watch(shakeToShuffleEnabledProvider);
    final isDisconnectPause = ref.watch(pauseOnDisconnectEnabledProvider);

    return Scaffold(
      backgroundColor: isOled ? Colors.black : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('QoL Features Hub'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Header summary & Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd, vertical: tokens.spaceSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search 26+ enhancements...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: tokens.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusCard),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: tokens.spaceSm),

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: QolCategory.values.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          avatar: Icon(
                            cat.icon,
                            size: 16,
                            color: isSelected ? Colors.white : tokens.textSecondary,
                          ),
                          label: Text(cat.label),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? Colors.white : tokens.textPrimary,
                          ),
                          backgroundColor: tokens.surfaceElevated,
                          selectedColor: tokens.accent,
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusFull),
                            side: BorderSide(
                              color: isSelected ? tokens.accent : tokens.divider,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Features List
          Expanded(
            child: _filteredFeatures.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: tokens.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No features found for "$_searchQuery"',
                          style: TextStyle(color: tokens.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spaceMd,
                      vertical: tokens.spaceSm,
                    ),
                    itemCount: _filteredFeatures.length,
                    itemBuilder: (context, index) {
                      final feature = _filteredFeatures[index];

                      // Resolve live toggle value if feature corresponds to a reactive provider
                      bool? liveToggleValue;
                      void Function(bool)? onLiveToggleChanged;

                      switch (feature.id) {
                        case 'offline_mode_toggle':
                          liveToggleValue = isOffline;
                          onLiveToggleChanged = (v) => ref.read(isOfflineOnlyModeProvider.notifier).toggle();
                          break;
                        case 'oled_black_theme':
                          liveToggleValue = isOled;
                          onLiveToggleChanged = (v) => ref.read(isOledBlackEnabledProvider.notifier).toggle();
                          break;
                        case 'lyrics_auto_scroll_lock':
                          liveToggleValue = isAutoScrollLocked;
                          onLiveToggleChanged = (v) {
                            if (v) {
                              ref.read(lyricsAutoScrollLockProvider.notifier).lock();
                            } else {
                              ref.read(lyricsAutoScrollLockProvider.notifier).resume();
                            }
                          };
                          break;
                        case 'quick_mute_controller':
                          liveToggleValue = isQuickMuted;
                          onLiveToggleChanged = (v) => ref.read(quickMuteProvider.notifier).toggleMute();
                          break;
                        case 'sleep_timer_track_end':
                          liveToggleValue = isStopAtEnd;
                          onLiveToggleChanged = (v) => ref.read(endOfTrackSleepTimerProvider.notifier).toggle();
                          break;
                        case 'screen_wakelock_manager':
                          liveToggleValue = isWakelock;
                          onLiveToggleChanged = (v) => ref.read(screenWakelockProvider.notifier).toggleMaster();
                          break;
                        case 'shake_to_shuffle':
                          liveToggleValue = isShakeEnabled;
                          onLiveToggleChanged = (v) => ref.read(shakeToShuffleEnabledProvider.notifier).toggle();
                          break;
                        case 'headphone_disconnect_pause':
                          liveToggleValue = isDisconnectPause;
                          onLiveToggleChanged = (v) => ref.read(pauseOnDisconnectEnabledProvider.notifier).toggle();
                          break;
                      }

                      return _QolFeatureCard(
                        feature: feature,
                        liveToggleValue: liveToggleValue,
                        onLiveToggleChanged: onLiveToggleChanged,
                        onDemo: () => feature.onTriggerDemo?.call(context, ref),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// QoL Feature Card Component
// ----------------------------------------------------------------------------

class _QolFeatureCard extends StatelessWidget {
  final QolFeatureDefinition feature;
  final bool? liveToggleValue;
  final ValueChanged<bool>? onLiveToggleChanged;
  final VoidCallback? onDemo;

  const _QolFeatureCard({
    required this.feature,
    this.liveToggleValue,
    this.onLiveToggleChanged,
    this.onDemo,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Feature Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                  ),
                  child: Icon(feature.icon, color: tokens.accent, size: 22),
                ),
                const SizedBox(width: 14),

                // Name & Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              feature.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ),
                          if (feature.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(tokens.radiusPill),
                              ),
                              child: Text(
                                feature.badge!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature.description,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: tokens.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom Actions & Toggles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Module file tag
                Row(
                  children: [
                    Icon(Icons.code_rounded, size: 13, color: tokens.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      feature.moduleFile,
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),

                // Interactive control
                Row(
                  children: [
                    if (onDemo != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onDemo,
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: const Text('Try', style: TextStyle(fontSize: 12)),
                      ),
                    if (feature.hasToggle && liveToggleValue != null && onLiveToggleChanged != null)
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: liveToggleValue!,
                          onChanged: onLiveToggleChanged,
                          activeColor: tokens.accent,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
