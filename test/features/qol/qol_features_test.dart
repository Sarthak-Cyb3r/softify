import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/qol_features.dart';

void main() {
  group('QoL Features Registry & Barrel Tests', () {
    test('Registry contains all 26 distinct QoL feature definitions', () {
      final features = QolFeatureRegistry.features;
      expect(features.length, 26);

      // Verify all unique IDs
      final ids = features.map((f) => f.id).toSet();
      expect(ids.length, 26);

      // Verify expected feature IDs are registered
      expect(ids.contains('lyrics_auto_scroll_lock'), isTrue);
      expect(ids.contains('double_tap_seek_overlay'), isTrue);
      expect(ids.contains('track_share_helper'), isTrue);
      expect(ids.contains('playback_speed_selector'), isTrue);
      expect(ids.contains('sleep_timer_track_end'), isTrue);
      expect(ids.contains('playlist_search_filter'), isTrue);
      expect(ids.contains('playlist_sorter'), isTrue);
      expect(ids.contains('advanced_queue_actions'), isTrue);
      expect(ids.contains('desktop_volume_scroll_listener'), isTrue);
      expect(ids.contains('quick_mute_controller'), isTrue);
      expect(ids.contains('keyboard_shortcuts_dialog'), isTrue);
      expect(ids.contains('duplicate_track_detector'), isTrue);
      expect(ids.contains('playlist_m3u_exporter'), isTrue);
      expect(ids.contains('playlist_m3u_importer'), isTrue);
      expect(ids.contains('lyrics_font_size_controller'), isTrue);
      expect(ids.contains('screen_wakelock_manager'), isTrue);
      expect(ids.contains('listening_history_manager'), isTrue);
      expect(ids.contains('audio_quality_badge_detail'), isTrue);
      expect(ids.contains('headphone_disconnect_pause'), isTrue);
      expect(ids.contains('jump_to_current_track'), isTrue);
      expect(ids.contains('track_tag_editor'), isTrue);
      expect(ids.contains('cache_storage_cleaner'), isTrue);
      expect(ids.contains('oled_black_theme'), isTrue);
      expect(ids.contains('shake_to_shuffle'), isTrue);
      expect(ids.contains('crossfade_transition_controller'), isTrue);
      expect(ids.contains('offline_mode_toggle'), isTrue);
    });

    test('Category filtering functions correctly', () {
      final playback = QolFeatureRegistry.getByCategory(QolCategory.playback);
      expect(playback.isNotEmpty, isTrue);

      final all = QolFeatureRegistry.getByCategory(QolCategory.all);
      expect(all.length, 26);
    });

    test('findById retrieves definition correctly', () {
      final feature = QolFeatureRegistry.findById('oled_black_theme');
      expect(feature, isNotNull);
      expect(feature!.name, 'Pure OLED Pitch Black Theme');
      expect(feature.category, QolCategory.interfaceTheme);
    });

    testWidgets('QolFeaturesHubScreen renders properly and lists features',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: QolFeaturesHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('QoL Features Hub'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Lyrics Auto-Scroll Lock'), findsOneWidget);
    });
  });
}
