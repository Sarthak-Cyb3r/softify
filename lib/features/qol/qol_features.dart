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
// DSP & Audio Engine Extensions
export 'dsp/linux_audio_sink_selector.dart';
export 'dsp/bs2b_crossfeed_service.dart';
export 'dsp/mono_downmix_service.dart';
export 'dsp/pitch_shifter.dart' hide SharedPreferences;
export 'dsp/quick_preset_cycler.dart';
export 'dsp/silence_trimmer_service.dart';
export 'dsp/stereo_balance_controller.dart' hide SharedPreferences;
export 'dsp/target_lufs_selector.dart' hide SharedPreferences;
export 'dsp/true_crossfade_engine.dart';

// Desktop & System Integration
export 'desktop/command_palette.dart' hide SharedPreferences;
export 'desktop/discord_privacy_masker.dart' hide SharedPreferences;
export 'desktop/global_media_hotkeys.dart' hide VisualKeycap, KeycapComboWidget;
export 'desktop/middle_click_mute.dart' hide SharedPreferences;
export 'desktop/mpris_seek_handler.dart';
export 'desktop/pip_floating_mini_player.dart' hide SharedPreferences;
export 'desktop/single_instance_guard.dart';
export 'desktop/softify_cli_service.dart';
export 'desktop/system_tray_manager.dart' hide SharedPreferences;

// Lyrics & Visualizer Enhancements
export 'lyrics/ambient_clock_screensaver.dart' hide SharedPreferences;
export 'lyrics/canvas_wave_visualizer.dart' hide SharedPreferences;
export 'lyrics/dynamic_cover_color_palette.dart';
export 'lyrics/instant_lyric_translator.dart' hide SharedPreferences;
export 'lyrics/karaoke_duet_highlighter.dart' hide SharedPreferences;
export 'lyrics/lrc_lyrics_exporter.dart';
export 'lyrics/lyrics_font_switcher.dart' hide SharedPreferences;
export 'lyrics/lyrics_sync_offset_slider.dart' hide SharedPreferences;
export 'lyrics/transliteration_switcher.dart' hide SharedPreferences;

// Library & Smart Playlists
export 'library/custom_playlist_cover_picker.dart' hide SharedPreferences;
export 'library/library_stats_dashboard.dart' hide SharedPreferences;
export 'library/listening_history_exporter.dart';
export 'library/playlist_duplicate_cleaner.dart';
export 'library/playlist_folder_manager.dart' hide SharedPreferences;
export 'library/smart_playlist_forgotten_favorites.dart';
export 'library/smart_playlist_heavy_rotation.dart';
export 'library/smart_playlist_recently_added.dart';
export 'library/smart_playlist_speed_dial.dart';

// Network & Buffer Optimization
export 'network/doh_dns_selector.dart';
export 'network/exponential_backoff_recovery.dart';
export 'network/full_app_backup_restore.dart';
export 'network/gradual_sleep_fadeout.dart';
export 'network/lookahead_buffer_slider.dart' hide SharedPreferences;
export 'network/lru_cache_quota_manager.dart' hide SharedPreferences;
export 'network/metered_connection_guard.dart';
export 'network/stream_health_diagnostic.dart';

// Queue & Timeline Enhancements
export 'queue/ab_loop_controller.dart' hide SharedPreferences;
export 'queue/desktop_lock_pause_listener.dart' hide SharedPreferences;
export 'queue/multi_track_batch_reorder.dart';
export 'queue/priority_play_next.dart';
export 'queue/queue_duration_counter.dart';
export 'queue/queue_history_stack.dart';
export 'queue/queue_search_filter.dart';
export 'queue/save_queue_as_playlist.dart';
export 'queue/smart_bpm_shuffle.dart' hide SharedPreferences;

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
import 'desktop/system_tray_manager.dart' hide SharedPreferences;

// DSP & Audio Engine Extensions
import 'dsp/linux_audio_sink_selector.dart';
import 'dsp/bs2b_crossfeed_service.dart';
import 'dsp/mono_downmix_service.dart';
import 'dsp/pitch_shifter.dart' hide SharedPreferences;
import 'dsp/quick_preset_cycler.dart';
import 'dsp/silence_trimmer_service.dart';
import 'dsp/stereo_balance_controller.dart' hide SharedPreferences;
import 'dsp/target_lufs_selector.dart' hide SharedPreferences;
import 'dsp/true_crossfade_engine.dart';

// Desktop & System Integration
import 'desktop/command_palette.dart' hide SharedPreferences;
import 'desktop/discord_privacy_masker.dart' hide SharedPreferences;
import 'desktop/global_media_hotkeys.dart' hide VisualKeycap, KeycapComboWidget;
import 'desktop/middle_click_mute.dart' hide SharedPreferences;
import 'desktop/mpris_seek_handler.dart';
import 'desktop/pip_floating_mini_player.dart' hide SharedPreferences;
import 'desktop/single_instance_guard.dart';
import 'desktop/softify_cli_service.dart';

// Lyrics & Visualizer Enhancements
import 'lyrics/ambient_clock_screensaver.dart' hide SharedPreferences;
import 'lyrics/canvas_wave_visualizer.dart' hide SharedPreferences;
import 'lyrics/dynamic_cover_color_palette.dart';
import 'lyrics/instant_lyric_translator.dart' hide SharedPreferences;
import 'lyrics/karaoke_duet_highlighter.dart' hide SharedPreferences;
import 'lyrics/lrc_lyrics_exporter.dart';
import 'lyrics/lyrics_font_switcher.dart' hide SharedPreferences;
import 'lyrics/lyrics_sync_offset_slider.dart' hide SharedPreferences;
import 'lyrics/transliteration_switcher.dart' hide SharedPreferences;

// Library & Smart Playlists
import 'library/custom_playlist_cover_picker.dart' hide SharedPreferences;
import 'library/library_stats_dashboard.dart' hide SharedPreferences;
import 'library/listening_history_exporter.dart';
import 'library/playlist_duplicate_cleaner.dart';
import 'library/playlist_folder_manager.dart' hide SharedPreferences;
import 'library/smart_playlist_forgotten_favorites.dart';
import 'library/smart_playlist_heavy_rotation.dart';
import 'library/smart_playlist_recently_added.dart';
import 'library/smart_playlist_speed_dial.dart';

// Network & Buffer Optimization
import 'network/doh_dns_selector.dart';
import 'network/exponential_backoff_recovery.dart';
import 'network/full_app_backup_restore.dart';
import 'network/gradual_sleep_fadeout.dart';
import 'network/lookahead_buffer_slider.dart' hide SharedPreferences;
import 'network/lru_cache_quota_manager.dart' hide SharedPreferences;
import 'network/metered_connection_guard.dart';
import 'network/stream_health_diagnostic.dart';

// Queue & Timeline Enhancements
import 'queue/ab_loop_controller.dart' hide SharedPreferences;
import 'queue/desktop_lock_pause_listener.dart' hide SharedPreferences;
import 'queue/multi_track_batch_reorder.dart';
import 'queue/priority_play_next.dart';
import 'queue/queue_duration_counter.dart';
import 'queue/queue_history_stack.dart';
import 'queue/queue_search_filter.dart';
import 'queue/save_queue_as_playlist.dart';
import 'queue/smart_bpm_shuffle.dart' hide SharedPreferences;

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

    // 27. Linux System Tray Menu & Controls
    QolFeatureDefinition(
      id: 'system_tray_manager',
      name: 'Linux System Tray Menu & Controls',
      description:
          'Native Linux StatusNotifierItem integration with playback controls, mute toggle, and minimize-to-tray.',
      category: QolCategory.convenience,
      icon: Icons.desktop_windows_rounded,
      moduleFile: 'desktop/system_tray_manager.dart',
      isDesktopOnly: true,
      hasToggle: true,
      badge: 'Linux',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: LinuxSystemTraySettingsCard(),
          ),
        );
      },
    ),

    // --- 52 Net-New QoL Features ---

    // 28. BS2B Binaural Crossfeed
    QolFeatureDefinition(
      id: 'bs2b_crossfeed',
      name: 'BS2B Binaural Crossfeed',
      description:
          'Bauer stereophonic-to-binaural DSP crossfeed algorithm to eliminate headphone listening fatigue.',
      category: QolCategory.playback,
      icon: Icons.headphones_rounded,
      moduleFile: 'dsp/bs2b_crossfeed_service.dart',
      badge: 'DSP',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: Bs2bCrossfeedSelector(),
          ),
        );
      },
    ),

    // 29. Linux Audio Sink Selector
    QolFeatureDefinition(
      id: 'linux_audio_sink_selector',
      name: 'Linux Audio Sink Selector',
      description:
          'Switch PipeWire and PulseAudio output devices dynamically without restarting playback.',
      category: QolCategory.playback,
      icon: Icons.speaker_group_rounded,
      moduleFile: 'dsp/linux_audio_sink_selector.dart',
      badge: 'Linux',
      isDesktopOnly: true,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const AudioSinkSelectorSheet(),
        );
      },
    ),

    // 30. Mono Audio Downmixing
    QolFeatureDefinition(
      id: 'mono_downmix',
      name: 'Mono Audio Downmixing',
      description:
          'Sum stereo channels into balanced mono for single-earbud or accessibility listening.',
      category: QolCategory.playback,
      icon: Icons.hearing_rounded,
      moduleFile: 'dsp/mono_downmix_service.dart',
      badge: 'DSP',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: MonoAudioToggleCard(),
          ),
        );
      },
    ),

    // 31. Real-Time Pitch Shifter
    QolFeatureDefinition(
      id: 'pitch_shifter',
      name: 'Real-Time Pitch Shifter',
      description:
          'Shift pitch by semitones and fine cents independently from playback tempo.',
      category: QolCategory.playback,
      icon: Icons.graphic_eq_rounded,
      moduleFile: 'dsp/pitch_shifter.dart',
      badge: 'DSP',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: PitchShifterControl(),
          ),
        );
      },
    ),

    // 32. Quick EQ Preset Cycler
    QolFeatureDefinition(
      id: 'quick_preset_cycler',
      name: 'Quick EQ Preset Cycler',
      description:
          'Instant cycling through Flat, Bass Boost, Vocal, and Treble EQ curves with mini visualizer.',
      category: QolCategory.playback,
      icon: Icons.equalizer_rounded,
      moduleFile: 'dsp/quick_preset_cycler.dart',
      badge: 'DSP',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: QuickPresetSelectorRow(),
          ),
        );
      },
    ),

    // 33. Smart Silence Trimmer
    QolFeatureDefinition(
      id: 'silence_trimmer',
      name: 'Smart Silence Trimmer',
      description:
          'Automatically skip silent intros and outros based on configurable dB thresholds.',
      category: QolCategory.playback,
      icon: Icons.content_cut_rounded,
      moduleFile: 'dsp/silence_trimmer_service.dart',
      badge: 'DSP',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: SilenceTrimmerSettingsCard(),
          ),
        );
      },
    ),

    // 34. Stereo Balance & Pan Slider
    QolFeatureDefinition(
      id: 'stereo_balance',
      name: 'Stereo Balance & Pan Slider',
      description:
          'Fine-tune left and right audio balance with center snap haptics.',
      category: QolCategory.playback,
      icon: Icons.tune_rounded,
      moduleFile: 'dsp/stereo_balance_controller.dart',
      badge: 'DSP',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: StereoBalanceSlider(),
          ),
        );
      },
    ),

    // 35. Target LUFS Loudness Matcher
    QolFeatureDefinition(
      id: 'target_lufs_selector',
      name: 'Target LUFS Loudness Matcher',
      description:
          'Selectable loudness targets (-14 LUFS Spotify, -16 LUFS Apple, -23 LUFS EBU R128).',
      category: QolCategory.playback,
      icon: Icons.volume_up_rounded,
      moduleFile: 'dsp/target_lufs_selector.dart',
      badge: 'DSP',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: TargetLufsSelectorCard(),
          ),
        );
      },
    ),

    // 36. Dual-Engine Overlapping Crossfade
    QolFeatureDefinition(
      id: 'true_crossfade_engine',
      name: 'Dual-Engine Overlapping Crossfade',
      description:
          'Simultaneous incoming and outgoing audio decrescendo/crescendo with equal-power curves.',
      category: QolCategory.playback,
      icon: Icons.merge_type_rounded,
      moduleFile: 'dsp/true_crossfade_engine.dart',
      badge: 'Audio',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: CrossfadeLiveVisualizer(),
          ),
        );
      },
    ),

    // 37. Ctrl+K Omnibar Command Palette
    QolFeatureDefinition(
      id: 'command_palette',
      name: 'Ctrl+K Omnibar Command Palette',
      description:
          'Quick-action launcher for navigation, settings, playback commands, and search.',
      category: QolCategory.convenience,
      icon: Icons.terminal_rounded,
      moduleFile: 'desktop/command_palette.dart',
      badge: 'Desktop',
      isDesktopOnly: true,
      onTriggerDemo: (context, ref) {
        showDialog<void>(
          context: context,
          builder: (ctx) => const CommandPaletteDialog(),
        );
      },
    ),

    // 38. Discord Streamer Privacy Mode
    QolFeatureDefinition(
      id: 'discord_privacy_masker',
      name: 'Discord Streamer Privacy Mode',
      description:
          'Mask private listening activity or customize rich presence details while streaming.',
      category: QolCategory.convenience,
      icon: Icons.visibility_off_rounded,
      moduleFile: 'desktop/discord_privacy_masker.dart',
      badge: 'Desktop',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: DiscordPrivacySelectorTile(isCard: true, showPreview: true),
          ),
        );
      },
    ),

    // 39. OS Global Media Hotkeys
    QolFeatureDefinition(
      id: 'global_media_hotkeys',
      name: 'OS Global Media Hotkeys',
      description:
          'Hardware media keys and customizable desktop global key combinations.',
      category: QolCategory.convenience,
      icon: Icons.keyboard_rounded,
      moduleFile: 'desktop/global_media_hotkeys.dart',
      badge: 'Desktop',
      isDesktopOnly: true,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: HotkeySettingsCard(),
          ),
        );
      },
    ),

    // 40. Middle-Click Quick Mute
    QolFeatureDefinition(
      id: 'middle_click_mute',
      name: 'Middle-Click Quick Mute',
      description:
          'Click middle mouse button anywhere on the player bar or volume slider to toggle mute.',
      category: QolCategory.convenience,
      icon: Icons.mouse_rounded,
      moduleFile: 'desktop/middle_click_mute.dart',
      badge: 'Desktop',
      isDesktopOnly: true,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: MiddleClickMuteButton(),
          ),
        );
      },
    ),

    // 41. MPRIS-2 Fractional Seek Handler
    QolFeatureDefinition(
      id: 'mpris_seek_handler',
      name: 'MPRIS-2 Fractional Seek Handler',
      description:
          'Seamless D-Bus MPRIS-2 position reporting and fast-forward / rewind controls.',
      category: QolCategory.convenience,
      icon: Icons.fast_forward_rounded,
      moduleFile: 'desktop/mpris_seek_handler.dart',
      badge: 'Linux',
      isDesktopOnly: true,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: MprisSeekCard(),
          ),
        );
      },
    ),

    // 42. Always-On-Top PiP Mini Player
    QolFeatureDefinition(
      id: 'pip_floating_mini_player',
      name: 'Always-On-Top PiP Mini Player',
      description:
          'Compact floating window with album art, scrub bar, and transport controls.',
      category: QolCategory.interfaceTheme,
      icon: Icons.picture_in_picture_alt_rounded,
      moduleFile: 'desktop/pip_floating_mini_player.dart',
      badge: 'Desktop',
      isDesktopOnly: true,
      onTriggerDemo: (context, ref) {
        showDialog<void>(
          context: context,
          builder: (ctx) => const AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: 320,
              child: CompactFloatingMiniPlayer(),
            ),
          ),
        );
      },
    ),

    // 43. Single-Instance Socket Guard
    QolFeatureDefinition(
      id: 'single_instance_guard',
      name: 'Single-Instance Socket Guard',
      description:
          'Enforce one running instance and pass command-line arguments to existing window.',
      category: QolCategory.convenience,
      icon: Icons.security_rounded,
      moduleFile: 'desktop/single_instance_guard.dart',
      badge: 'Linux',
      isDesktopOnly: true,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: SingleInstanceStatusCard(),
          ),
        );
      },
    ),

    // 44. Softify CLI Unix Socket Controller
    QolFeatureDefinition(
      id: 'softify_cli_service',
      name: 'Softify CLI Unix Socket Controller',
      description:
          'Terminal IPC controls: softify play, softify next, softify status.',
      category: QolCategory.convenience,
      icon: Icons.code_rounded,
      moduleFile: 'desktop/softify_cli_service.dart',
      badge: 'CLI',
      isDesktopOnly: true,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: SoftifyCliControlCard(),
          ),
        );
      },
    ),

    // 45. Ambient Clock & Lyrics Screensaver
    QolFeatureDefinition(
      id: 'ambient_clock_screensaver',
      name: 'Ambient Clock & Lyrics Screensaver',
      description:
          'OLED-safe full-screen display with typography clock and current track visuals.',
      category: QolCategory.lyrics,
      icon: Icons.watch_later_rounded,
      moduleFile: 'lyrics/ambient_clock_screensaver.dart',
      badge: 'Display',
      onTriggerDemo: (context, ref) {
        showDialog<void>(
          context: context,
          builder: (ctx) => const AmbientClockScreensaverSettingsDialog(),
        );
      },
    ),

    // 46. Canvas Audio Wave Visualizer
    QolFeatureDefinition(
      id: 'canvas_wave_visualizer',
      name: 'Canvas Audio Wave Visualizer',
      description:
          'Smooth hardware-accelerated 60 FPS waveform animation beneath active lyrics.',
      category: QolCategory.lyrics,
      icon: Icons.waves_rounded,
      moduleFile: 'lyrics/canvas_wave_visualizer.dart',
      badge: 'Visuals',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const CanvasWaveVisualizerSheet(),
        );
      },
    ),

    // 47. Dynamic Album Palette Theme
    QolFeatureDefinition(
      id: 'dynamic_cover_color_palette',
      name: 'Dynamic Album Palette Theme',
      description:
          'Extract dominant vibrant colors from album artwork to tint background gradients.',
      category: QolCategory.interfaceTheme,
      icon: Icons.color_lens_rounded,
      moduleFile: 'lyrics/dynamic_cover_color_palette.dart',
      badge: 'Visuals',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: DynamicPalettePreviewCard(),
          ),
        );
      },
    ),

    // 48. Instant Lyric Translation
    QolFeatureDefinition(
      id: 'instant_lyric_translator',
      name: 'Instant Lyric Translation',
      description:
          'Display bilingual or translated subtitles alongside synchronized lyrics.',
      category: QolCategory.lyrics,
      icon: Icons.translate_rounded,
      moduleFile: 'lyrics/instant_lyric_translator.dart',
      badge: 'Lyrics',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: LyricTranslationToggle(),
          ),
        );
      },
    ),

    // 49. Karaoke Duet Multi-Color Highlighting
    QolFeatureDefinition(
      id: 'karaoke_duet_highlighter',
      name: 'Karaoke Duet Multi-Color Highlighting',
      description:
          'Distinct singer colors for duet tracks with synchronized progressive fill.',
      category: QolCategory.lyrics,
      icon: Icons.mic_external_on_rounded,
      moduleFile: 'lyrics/karaoke_duet_highlighter.dart',
      badge: 'Lyrics',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const KaraokeDuetSettingsSheet(),
        );
      },
    ),

    // 50. LRC Synced Lyrics Exporter
    QolFeatureDefinition(
      id: 'lrc_lyrics_exporter',
      name: 'LRC Synced Lyrics Exporter',
      description:
          'Export synchronized lyrics with precise timestamp tags to clipboard or .lrc file.',
      category: QolCategory.lyrics,
      icon: Icons.file_download_rounded,
      moduleFile: 'lyrics/lrc_lyrics_exporter.dart',
      badge: 'Lyrics',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: CopyLyricsButton(lyrics: null),
          ),
        );
      },
    ),

    // 51. Lyrics Typography & Font Selector
    QolFeatureDefinition(
      id: 'lyrics_font_switcher',
      name: 'Lyrics Typography & Font Selector',
      description:
          'Switch between Modern Sans, Editorial Serif, and Monospace display fonts.',
      category: QolCategory.lyrics,
      icon: Icons.font_download_rounded,
      moduleFile: 'lyrics/lyrics_font_switcher.dart',
      badge: 'Lyrics',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const LyricsFontPickerSheet(),
        );
      },
    ),

    // 52. Microsecond Lyrics Sync Calibration
    QolFeatureDefinition(
      id: 'lyrics_sync_offset_slider',
      name: 'Microsecond Lyrics Sync Calibration',
      description:
          'Nudge lyric timing offset from -5000ms to +5000ms for perfect karaoke alignment.',
      category: QolCategory.lyrics,
      icon: Icons.av_timer_rounded,
      moduleFile: 'lyrics/lyrics_sync_offset_slider.dart',
      badge: 'Lyrics',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: LyricsSyncOffsetSlider(),
          ),
        );
      },
    ),

    // 53. Lyric Transliteration (Romaji / Pinyin)
    QolFeatureDefinition(
      id: 'transliteration_switcher',
      name: 'Lyric Transliteration (Romaji / Pinyin)',
      description:
          'Toggle phonetic Latin script for Japanese, Chinese, and Korean lyrics.',
      category: QolCategory.lyrics,
      icon: Icons.subtitles_rounded,
      moduleFile: 'lyrics/transliteration_switcher.dart',
      badge: 'Lyrics',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: TransliterationToggleChip(),
          ),
        );
      },
    ),

    // 54. Custom Playlist Artwork Designer
    QolFeatureDefinition(
      id: 'custom_playlist_cover_picker',
      name: 'Custom Playlist Artwork Designer',
      description:
          'Upload custom images or generate dynamic 2x2 mosaic covers for playlists.',
      category: QolCategory.libraryData,
      icon: Icons.image_rounded,
      moduleFile: 'library/custom_playlist_cover_picker.dart',
      badge: 'Library',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const PlaylistCoverEditorSheet(playlistId: 'demo_playlist'),
        );
      },
    ),

    // 55. Listening Stats & Analytics Dashboard
    QolFeatureDefinition(
      id: 'library_stats_dashboard',
      name: 'Listening Stats & Analytics Dashboard',
      description:
          'Explore total hours listened, top tracks, genres, and audio bitrate breakdown.',
      category: QolCategory.libraryData,
      icon: Icons.analytics_rounded,
      moduleFile: 'library/library_stats_dashboard.dart',
      badge: 'Library',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: LibraryStatsDashboardWidget(),
          ),
        );
      },
    ),

    // 56. Listening History Exporter (JSON / CSV)
    QolFeatureDefinition(
      id: 'listening_history_exporter',
      name: 'Listening History Exporter (JSON / CSV)',
      description:
          'Export listening activity, play counts, and timestamps to portable open formats.',
      category: QolCategory.libraryData,
      icon: Icons.download_rounded,
      moduleFile: 'library/listening_history_exporter.dart',
      badge: 'Library',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const ExportHistorySheet(entries: []),
        );
      },
    ),

    // 57. Playlist Duplicate Cleaner
    QolFeatureDefinition(
      id: 'playlist_duplicate_cleaner',
      name: 'Playlist Duplicate Cleaner',
      description:
          'Scan playlists for redundant tracks and remove duplicates with 1 click.',
      category: QolCategory.libraryData,
      icon: Icons.cleaning_services_rounded,
      moduleFile: 'library/playlist_duplicate_cleaner.dart',
      badge: 'Library',
      onTriggerDemo: (context, ref) {
        showDialog<void>(
          context: context,
          builder: (ctx) => const DuplicateCleanerDialog(playlistId: 'demo_playlist'),
        );
      },
    ),

    // 58. Nested Playlist Folders
    QolFeatureDefinition(
      id: 'playlist_folder_manager',
      name: 'Nested Playlist Folders',
      description:
          'Organize playlists into hierarchical expandable folders and categories.',
      category: QolCategory.libraryData,
      icon: Icons.folder_special_rounded,
      moduleFile: 'library/playlist_folder_manager.dart',
      badge: 'Library',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const PlaylistFolderTreeView(),
        );
      },
    ),

    // 59. Smart Playlist: Forgotten Favorites
    QolFeatureDefinition(
      id: 'smart_playlist_forgotten_favorites',
      name: 'Smart Playlist: Forgotten Favorites',
      description:
          'Surface loved songs that have not been played in the last 30 days.',
      category: QolCategory.playlistQueue,
      icon: Icons.auto_awesome_motion_rounded,
      moduleFile: 'library/smart_playlist_forgotten_favorites.dart',
      badge: 'Smart Mix',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const ForgottenFavoritesDetailSheet(),
        );
      },
    ),

    // 60. Smart Playlist: Heavy Rotation
    QolFeatureDefinition(
      id: 'smart_playlist_heavy_rotation',
      name: 'Smart Playlist: Heavy Rotation',
      description:
          'Automatically curated dynamic top 25 most played songs this month.',
      category: QolCategory.playlistQueue,
      icon: Icons.local_fire_department_rounded,
      moduleFile: 'library/smart_playlist_heavy_rotation.dart',
      badge: 'Smart Mix',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const HeavyRotationSettingsSheet(),
        );
      },
    ),

    // 61. Smart Playlist: Recently Added
    QolFeatureDefinition(
      id: 'smart_playlist_recently_added',
      name: 'Smart Playlist: Recently Added',
      description:
          'Real-time chronological feed of newly added songs across all playlists.',
      category: QolCategory.playlistQueue,
      icon: Icons.new_releases_rounded,
      moduleFile: 'library/smart_playlist_recently_added.dart',
      badge: 'Smart Mix',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const RecentlyAddedPlaylistSheet(),
        );
      },
    ),

    // 62. Home Speed Dial Quick Playlists
    QolFeatureDefinition(
      id: 'smart_playlist_speed_dial',
      name: 'Home Speed Dial Quick Playlists',
      description:
          'Pinned quick-launch tiles on the home screen for your top 6 playlists.',
      category: QolCategory.playlistQueue,
      icon: Icons.dialpad_rounded,
      moduleFile: 'library/smart_playlist_speed_dial.dart',
      badge: 'Smart Mix',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const SpeedDialMixSheet(),
        );
      },
    ),

    // 63. Encrypted DNS-over-HTTPS (DoH)
    QolFeatureDefinition(
      id: 'doh_dns_selector',
      name: 'Encrypted DNS-over-HTTPS (DoH)',
      description:
          'Bypass ISP audio CDN blocks with encrypted Cloudflare, Google, or Quad9 DNS.',
      category: QolCategory.convenience,
      icon: Icons.lock_outline_rounded,
      moduleFile: 'network/doh_dns_selector.dart',
      badge: 'Network',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: DohDnsSelectorCard(),
          ),
        );
      },
    ),

    // 64. Resilient Stream Glitch Recovery
    QolFeatureDefinition(
      id: 'exponential_backoff_recovery',
      name: 'Resilient Stream Glitch Recovery',
      description:
          'Seamless jitter-dampened retry logic that recovers dropped audio streams without pausing.',
      category: QolCategory.playback,
      icon: Icons.replay_rounded,
      moduleFile: 'network/exponential_backoff_recovery.dart',
      badge: 'Network',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: NetworkRecoveryStatsCard(),
          ),
        );
      },
    ),

    // 65. Full App Backup & Restore (Zip)
    QolFeatureDefinition(
      id: 'full_app_backup_restore',
      name: 'Full App Backup & Restore (Zip)',
      description:
          'One-click archive and import of playlists, favorites, settings, and EQ presets.',
      category: QolCategory.libraryData,
      icon: Icons.archive_rounded,
      moduleFile: 'network/full_app_backup_restore.dart',
      badge: 'Backup',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: BackupRestoreCard(),
          ),
        );
      },
    ),

    // 66. Sleep Timer Gradual Fadeout
    QolFeatureDefinition(
      id: 'gradual_sleep_fadeout',
      name: 'Sleep Timer Gradual Fadeout',
      description:
          'Smooth logarithmic volume decrescendo over the last 60 seconds of sleep timer.',
      category: QolCategory.playback,
      icon: Icons.bedtime_rounded,
      moduleFile: 'network/gradual_sleep_fadeout.dart',
      badge: 'Timer',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: SleepTimerFadeoutToggleTile(),
          ),
        );
      },
    ),

    // 67. Audio Prefetch Lookahead Buffer
    QolFeatureDefinition(
      id: 'lookahead_buffer_slider',
      name: 'Audio Prefetch Lookahead Buffer',
      description:
          'Tune pre-buffering duration from 10s up to 120s for stutter-free subway/train listening.',
      category: QolCategory.playback,
      icon: Icons.hourglass_top_rounded,
      moduleFile: 'network/lookahead_buffer_slider.dart',
      badge: 'Buffer',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: LookaheadBufferSliderCard(),
          ),
        );
      },
    ),

    // 68. LRU Disk Cache Quota Manager
    QolFeatureDefinition(
      id: 'lru_cache_quota_manager',
      name: 'LRU Disk Cache Quota Manager',
      description:
          'Set custom cache limits (500MB to 10GB) with automatic least-recently-used eviction.',
      category: QolCategory.libraryData,
      icon: Icons.storage_rounded,
      moduleFile: 'network/lru_cache_quota_manager.dart',
      badge: 'Storage',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: CacheQuotaSelectorCard(),
          ),
        );
      },
    ),

    // 69. Metered Bandwidth Saver
    QolFeatureDefinition(
      id: 'metered_connection_guard',
      name: 'Metered Bandwidth Saver',
      description:
          'Automatically throttle streaming bitrate and disable video/canvas on cellular hotspot.',
      category: QolCategory.convenience,
      icon: Icons.data_saver_on_rounded,
      moduleFile: 'network/metered_connection_guard.dart',
      badge: 'Network',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: MeteredConnectionSettingsTile(),
          ),
        );
      },
    ),

    // 70. Real-Time Stream Health Monitor
    QolFeatureDefinition(
      id: 'stream_health_diagnostic',
      name: 'Real-Time Stream Health Monitor',
      description:
          'Inspect live buffer level, ping latency, bitrate, and codec details during playback.',
      category: QolCategory.playback,
      icon: Icons.monitor_heart_rounded,
      moduleFile: 'network/stream_health_diagnostic.dart',
      badge: 'Diagnostics',
      onTriggerDemo: (context, ref) {
        showDialog<void>(
          context: context,
          builder: (ctx) => const StreamHealthDetailDialog(),
        );
      },
    ),

    // 71. A-B Loop Section Repeater
    QolFeatureDefinition(
      id: 'ab_loop_controller',
      name: 'A-B Loop Section Repeater',
      description:
          'Set start (A) and end (B) timestamp markers to loop song passages endlessly for practice.',
      category: QolCategory.playback,
      icon: Icons.repeat_one_on_rounded,
      moduleFile: 'queue/ab_loop_controller.dart',
      badge: 'Playback',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: AbLoopFloatingWidget(),
          ),
        );
      },
    ),

    // 72. Auto-Pause on Desktop Screen Lock
    QolFeatureDefinition(
      id: 'desktop_lock_pause_listener',
      name: 'Auto-Pause on Desktop Screen Lock',
      description:
          'Automatically pause playback when Linux session locks or screensaver turns on via D-Bus.',
      category: QolCategory.convenience,
      icon: Icons.lock_clock_rounded,
      moduleFile: 'queue/desktop_lock_pause_listener.dart',
      badge: 'Linux',
      isDesktopOnly: true,
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: DesktopLockPauseToggleTile(),
          ),
        );
      },
    ),

    // 73. Multi-Track Batch Queue Reorder
    QolFeatureDefinition(
      id: 'multi_track_batch_reorder',
      name: 'Multi-Track Batch Queue Reorder',
      description:
          'Shift-select multiple queue items to move them to top, bottom, or remove together.',
      category: QolCategory.playlistQueue,
      icon: Icons.checklist_rounded,
      moduleFile: 'queue/multi_track_batch_reorder.dart',
      badge: 'Queue',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: QueueBatchActionBar(),
          ),
        );
      },
    ),

    // 74. Priority Play Next Queue VIP
    QolFeatureDefinition(
      id: 'priority_play_next',
      name: 'Priority Play Next Queue VIP',
      description:
          'Insert selected track into VIP queue slot to play immediately after the current song.',
      category: QolCategory.playlistQueue,
      icon: Icons.low_priority_rounded,
      moduleFile: 'queue/priority_play_next.dart',
      badge: 'Queue',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const PriorityQueueView(),
        );
      },
    ),

    // 75. Queue Total Duration & End Clock
    QolFeatureDefinition(
      id: 'queue_duration_counter',
      name: 'Queue Total Duration & End Clock',
      description:
          'Displays aggregate remaining hours:minutes and calculates projected finish clock time.',
      category: QolCategory.playlistQueue,
      icon: Icons.timer_rounded,
      moduleFile: 'queue/queue_duration_counter.dart',
      badge: 'Queue',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const QueueDurationDetailModal(),
        );
      },
    ),

    // 76. Queue Undo / Redo History Stack
    QolFeatureDefinition(
      id: 'queue_history_stack',
      name: 'Queue Undo / Redo History Stack',
      description:
          'Undo accidental queue clears or track skips with a full undo/redo action stack.',
      category: QolCategory.playlistQueue,
      icon: Icons.undo_rounded,
      moduleFile: 'queue/queue_history_stack.dart',
      badge: 'Queue',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: QueueUndoRedoBar(),
          ),
        );
      },
    ),

    // 77. Instant Queue Search & Filter
    QolFeatureDefinition(
      id: 'queue_search_filter',
      name: 'Instant Queue Search & Filter',
      description:
          'Real-time search bar to find and jump to songs inside large playlists and queues.',
      category: QolCategory.playlistQueue,
      icon: Icons.filter_list_rounded,
      moduleFile: 'queue/queue_search_filter.dart',
      badge: 'Queue',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const Padding(
            padding: EdgeInsets.all(20),
            child: QueueSearchHeaderField(),
          ),
        );
      },
    ),

    // 78. 1-Click Save Queue as Playlist
    QolFeatureDefinition(
      id: 'save_queue_as_playlist',
      name: '1-Click Save Queue as Playlist',
      description:
          'Save current active listening queue as a permanent playlist with one tap.',
      category: QolCategory.playlistQueue,
      icon: Icons.playlist_add_check_circle_rounded,
      moduleFile: 'queue/save_queue_as_playlist.dart',
      badge: 'Queue',
      onTriggerDemo: (context, ref) {
        showDialog<void>(
          context: context,
          builder: (ctx) => const SaveQueueDialog(),
        );
      },
    ),

    // 79. Smart BPM & Camelot Key Shuffle
    QolFeatureDefinition(
      id: 'smart_bpm_shuffle',
      name: 'Smart BPM & Camelot Key Shuffle',
      description:
          'Intelligent DJ-style queue shuffle that sorts adjacent songs by matching tempo and musical key.',
      category: QolCategory.playlistQueue,
      icon: Icons.shuffle_on_rounded,
      moduleFile: 'queue/smart_bpm_shuffle.dart',
      badge: 'Queue',
      onTriggerDemo: (context, ref) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const SmartShuffleSettingsModal(),
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
                    hintText: 'Search 75+ enhancements...',
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
                          activeThumbColor: tokens.accent,
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
