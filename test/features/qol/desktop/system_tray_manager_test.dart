import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/desktop/system_tray_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.reset();
  });

  tearDown(() {
    SharedPreferences.reset();
  });

  group('SharedPreferences In-Memory Tests', () {
    test('Reads and writes boolean, string, and double preferences', () async {
      SharedPreferences.setMockInitialValues({
        SystemTrayPreferenceKeys.enabled: true,
        SystemTrayPreferenceKeys.minimizeToTrayOnClose: false,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SystemTrayPreferenceKeys.enabled), isTrue);
      expect(
        prefs.getBool(SystemTrayPreferenceKeys.minimizeToTrayOnClose),
        isFalse,
      );
      expect(
        prefs.getBool(SystemTrayPreferenceKeys.startMinimized),
        isNull,
      );

      await prefs.setBool(SystemTrayPreferenceKeys.startMinimized, true);
      expect(
        prefs.getBool(SystemTrayPreferenceKeys.startMinimized),
        isTrue,
      );

      await prefs.setString('test_string', 'softify');
      expect(prefs.getString('test_string'), 'softify');

      await prefs.setDouble('test_double', 0.85);
      expect(prefs.getDouble('test_double'), 0.85);

      await prefs.remove('test_string');
      expect(prefs.getString('test_string'), isNull);

      await prefs.clear();
      expect(prefs.getBool(SystemTrayPreferenceKeys.enabled), isNull);
    });
  });

  group('TrayMenuItem Model', () {
    test('Constructors and factories create expected items', () {
      final actionItem = TrayMenuItem.action(
        id: 'play_pause',
        label: 'Play',
        action: TrayMenuAction.playPause,
        iconName: 'media-playback-start',
        tooltip: 'Play audio',
      );
      expect(actionItem.id, 'play_pause');
      expect(actionItem.label, 'Play');
      expect(actionItem.action, TrayMenuAction.playPause);
      expect(actionItem.isSeparator, isFalse);
      expect(actionItem.isEnabled, isTrue);
      expect(actionItem.iconName, 'media-playback-start');

      final sep = TrayMenuItem.separator(id: 'sep_1');
      expect(sep.id, 'sep_1');
      expect(sep.isSeparator, isTrue);
      expect(sep.action, TrayMenuAction.separator);
      expect(sep.isEnabled, isFalse);

      final info = TrayMenuItem.info(
        id: 'now_playing',
        label: 'Song Title • Artist',
      );
      expect(info.id, 'now_playing');
      expect(info.label, 'Song Title • Artist');
      expect(info.action, TrayMenuAction.nowPlayingInfo);
      expect(info.isEnabled, isFalse);
    });

    test('copyWith, equality, and toString work correctly', () {
      final item1 = TrayMenuItem.action(
        id: 'action_1',
        label: 'Action 1',
        action: TrayMenuAction.nextTrack,
      );
      final item2 = item1.copyWith(label: 'Action 2');

      expect(item1 == item2, isFalse);
      expect(item2.label, 'Action 2');
      expect(item2.id, 'action_1');

      final item3 = item1.copyWith();
      expect(item1 == item3, isTrue);
      expect(item1.hashCode, item3.hashCode);
      expect(item1.toString(), contains('Action 1'));
    });
  });

  group('SystemTrayState Model', () {
    test('Default state properties and computed getters', () {
      const state = SystemTrayState();
      expect(state.isEnabled, isTrue);
      expect(state.isAvailable, isTrue);
      expect(state.status, SystemTrayStatus.uninitialized);
      expect(state.isAppVisible, isTrue);
      expect(state.isPlaying, isFalse);
      expect(state.isMuted, isFalse);
      expect(state.volume, 1.0);
      expect(state.minimizeToTrayOnClose, isTrue);
      expect(state.startMinimized, isFalse);
      expect(state.showNotifications, isTrue);
      expect(state.isInitialized, isFalse);
      expect(state.isActive, isFalse);

      expect(state.playPauseLabel, 'Play');
      expect(state.playPauseIcon, 'media-playback-start');
      expect(state.muteUnmuteLabel, 'Mute');
      expect(state.muteUnmuteIcon, 'audio-volume-high');
      expect(state.showHideLabel, 'Hide to Tray');
      expect(state.formattedNowPlaying, 'Softify • No track playing');
    });

    test('Computed labels and icons reflect active playback and mute status', () {
      const playingState = SystemTrayState(
        isPlaying: true,
        isMuted: true,
        isAppVisible: false,
        currentTrackTitle: 'Starboy',
        currentArtist: 'The Weeknd',
      );

      expect(playingState.playPauseLabel, 'Pause');
      expect(playingState.playPauseIcon, 'media-playback-pause');
      expect(playingState.muteUnmuteLabel, 'Unmute');
      expect(playingState.muteUnmuteIcon, 'audio-volume-muted');
      expect(playingState.showHideLabel, 'Show Softify');
      expect(playingState.formattedNowPlaying, 'Starboy • The Weeknd');
    });

    test('copyWith, equality, and hashCode', () {
      const state1 = SystemTrayState(isPlaying: false);
      final state2 = state1.copyWith(isPlaying: true, currentTrackTitle: 'Song');

      expect(state1 == state2, isFalse);
      expect(state2.isPlaying, isTrue);
      expect(state2.currentTrackTitle, 'Song');

      final state3 = state2.copyWith();
      expect(state2 == state3, isTrue);
      expect(state2.hashCode, state3.hashCode);
      expect(state2.toString(), contains('Song'));
    });
  });

  group('SystemTrayManager Lifecycle & Platform Integration', () {
    test('Initializes active tray when platform is supported', () async {
      SharedPreferences.setMockInitialValues({
        SystemTrayPreferenceKeys.enabled: true,
        SystemTrayPreferenceKeys.minimizeToTrayOnClose: true,
        SystemTrayPreferenceKeys.startMinimized: false,
      });

      final mockBridge = MockTrayPlatformBridge(
        supported: true,
        mockDesktopEnvironment: 'GNOME Shell',
      );

      final manager = SystemTrayManager(bridge: mockBridge);
      final statusEvents = <SystemTrayStatus>[];
      final sub = manager.statusStream.listen(statusEvents.add);

      expect(manager.status, SystemTrayStatus.uninitialized);
      await manager.initialize();

      expect(manager.status, SystemTrayStatus.active);
      expect(statusEvents, [
        SystemTrayStatus.initializing,
        SystemTrayStatus.active,
      ]);
      expect(mockBridge.callLogs, contains('isPlatformSupported'));
      expect(mockBridge.callLogs, contains('initTray: Softify'));
      expect(mockBridge.lastContextMenu.length, 10);
      expect(manager.state.desktopEnvironment, 'GNOME Shell');
      expect(manager.state.isAppVisible, isTrue);

      await sub.cancel();
      manager.dispose();
    });

    test('Sets status to unsupported when platform is not Linux desktop', () async {
      final mockBridge = MockTrayPlatformBridge(supported: false);
      final manager = SystemTrayManager(bridge: mockBridge);

      await manager.initialize();
      expect(manager.status, SystemTrayStatus.unsupported);
      expect(manager.state.isAvailable, isFalse);

      manager.dispose();
    });

    test('Sets status to hidden when user preference disables tray', () async {
      SharedPreferences.setMockInitialValues({
        SystemTrayPreferenceKeys.enabled: false,
      });

      final mockBridge = MockTrayPlatformBridge(supported: true);
      final manager = SystemTrayManager(bridge: mockBridge);

      await manager.initialize();
      expect(manager.status, SystemTrayStatus.hidden);
      expect(manager.state.isEnabled, isFalse);

      manager.dispose();
    });

    test('Generates complete 10-item context menu hierarchy', () async {
      final mockBridge = MockTrayPlatformBridge(supported: true);
      final manager = SystemTrayManager(bridge: mockBridge);
      await manager.initialize();

      final items = manager.buildMenuItems();
      expect(items.length, 10);

      // Verify item actions and order
      expect(items[0].action, TrayMenuAction.nowPlayingInfo);
      expect(items[1].action, TrayMenuAction.separator);
      expect(items[2].action, TrayMenuAction.playPause);
      expect(items[3].action, TrayMenuAction.nextTrack);
      expect(items[4].action, TrayMenuAction.previousTrack);
      expect(items[5].action, TrayMenuAction.separator);
      expect(items[6].action, TrayMenuAction.toggleMute);
      expect(items[7].action, TrayMenuAction.separator);
      expect(items[8].action, TrayMenuAction.showApp);
      expect(items[9].action, TrayMenuAction.quit);

      manager.dispose();
    });
  });

  group('SystemTrayManager Menu Actions Handling', () {
    late MockTrayPlatformBridge mockBridge;
    late SystemTrayManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockBridge = MockTrayPlatformBridge(supported: true);
      manager = SystemTrayManager(bridge: mockBridge);
      await manager.initialize();
    });

    tearDown(() {
      manager.dispose();
    });

    test('Play/Pause action toggles isPlaying and rebuilds menu', () async {
      expect(manager.state.isPlaying, isFalse);

      // Trigger Play
      await manager.handleAction(TrayMenuAction.playPause);
      expect(manager.state.isPlaying, isTrue);
      expect(manager.state.lastAction, TrayMenuAction.playPause);
      expect(mockBridge.lastContextMenu[2].label, 'Pause');
      expect(mockBridge.lastContextMenu[2].iconName, 'media-playback-pause');

      // Trigger Pause
      await manager.handleAction(TrayMenuAction.playPause);
      expect(manager.state.isPlaying, isFalse);
      expect(mockBridge.lastContextMenu[2].label, 'Play');
      expect(mockBridge.lastContextMenu[2].iconName, 'media-playback-start');
    });

    test('Next Track and Previous Track update lastAction state', () async {
      await manager.handleAction(TrayMenuAction.nextTrack);
      expect(manager.state.lastAction, TrayMenuAction.nextTrack);

      await manager.handleAction(TrayMenuAction.previousTrack);
      expect(manager.state.lastAction, TrayMenuAction.previousTrack);
    });

    test('Toggle Mute updates volume, isMuted, and menu item labels', () async {
      expect(manager.state.isMuted, isFalse);
      expect(manager.state.volume, 1.0);

      // Mute
      await manager.handleAction(TrayMenuAction.toggleMute);
      expect(manager.state.isMuted, isTrue);
      expect(manager.state.volume, 0.0);
      expect(mockBridge.lastContextMenu[6].label, 'Unmute');
      expect(mockBridge.lastContextMenu[6].iconName, 'audio-volume-muted');

      // Unmute
      await manager.handleAction(TrayMenuAction.toggleMute);
      expect(manager.state.isMuted, isFalse);
      expect(manager.state.volume, 0.7);
      expect(mockBridge.lastContextMenu[6].label, 'Mute');
      expect(mockBridge.lastContextMenu[6].iconName, 'audio-volume-high');
    });

    test('Window visibility show and hide delegates to platform bridge', () async {
      expect(manager.state.isAppVisible, isTrue);

      // Toggle window visibility (hides it)
      await manager.handleAction(TrayMenuAction.showApp);
      expect(manager.state.isAppVisible, isFalse);
      expect(mockBridge.lastWindowVisibility, isFalse);
      expect(mockBridge.lastContextMenu[8].label, 'Show Softify');

      // Toggle again (shows it)
      await manager.handleAction(TrayMenuAction.showApp);
      expect(manager.state.isAppVisible, isTrue);
      expect(mockBridge.lastWindowVisibility, isTrue);
      expect(mockBridge.lastContextMenu[8].label, 'Hide to Tray');

      // Explicit hide and show methods
      await manager.hideApp();
      expect(manager.state.isAppVisible, isFalse);
      expect(mockBridge.lastWindowVisibility, isFalse);

      await manager.showApp();
      expect(manager.state.isAppVisible, isTrue);
      expect(mockBridge.lastWindowVisibility, isTrue);
    });

    test('Quit action delegates to platform bridge quitApplication', () async {
      expect(mockBridge.quitCallCount, 0);
      await manager.handleAction(TrayMenuAction.quit);
      expect(mockBridge.quitCallCount, 1);
      expect(manager.state.lastAction, TrayMenuAction.quit);
    });

    test('Platform bridge incoming action event triggers manager handler', () async {
      expect(manager.state.isPlaying, isFalse);

      // Platform sends playPause signal
      mockBridge.triggerAction(TrayMenuAction.playPause);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(manager.state.isPlaying, isTrue);
    });

    test('updatePlaybackState updates metadata and tooltip', () async {
      await manager.updatePlaybackState(
        isPlaying: true,
        title: 'Blinding Lights',
        artist: 'The Weeknd',
      );

      expect(manager.state.isPlaying, isTrue);
      expect(manager.state.currentTrackTitle, 'Blinding Lights');
      expect(manager.state.currentArtist, 'The Weeknd');
      expect(manager.state.formattedNowPlaying, 'Blinding Lights • The Weeknd');
      expect(mockBridge.lastTooltip, 'Blinding Lights • The Weeknd');
      expect(mockBridge.lastContextMenu[0].label, 'Blinding Lights • The Weeknd');
    });

    test('User preferences update state and persist to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();

      await manager.setMinimizeToTray(false);
      expect(manager.state.minimizeToTrayOnClose, isFalse);
      expect(
        prefs.getBool(SystemTrayPreferenceKeys.minimizeToTrayOnClose),
        isFalse,
      );

      await manager.setStartMinimized(true);
      expect(manager.state.startMinimized, isTrue);
      expect(
        prefs.getBool(SystemTrayPreferenceKeys.startMinimized),
        isTrue,
      );

      await manager.setShowNotifications(false);
      expect(manager.state.showNotifications, isFalse);
      expect(
        prefs.getBool(SystemTrayPreferenceKeys.showNotifications),
        isFalse,
      );

      await manager.setEnabled(false);
      expect(manager.state.isEnabled, isFalse);
      expect(manager.status, SystemTrayStatus.hidden);
      expect(prefs.getBool(SystemTrayPreferenceKeys.enabled), isFalse);

      await manager.setEnabled(true);
      expect(manager.state.isEnabled, isTrue);
      expect(manager.status, SystemTrayStatus.active);
      expect(prefs.getBool(SystemTrayPreferenceKeys.enabled), isTrue);
    });
  });

  group('Riverpod Notifier & Providers', () {
    test('StateNotifier exposes manager methods and updates state', () async {
      final mockBridge = MockTrayPlatformBridge(supported: true);
      final manager = SystemTrayManager(bridge: mockBridge);
      await manager.initialize();

      final notifier = SystemTrayStateNotifier(manager);
      expect(notifier.state.isPlaying, isFalse);

      await notifier.togglePlayback();
      expect(notifier.state.isPlaying, isTrue);

      await notifier.setMinimizeToTray(false);
      expect(notifier.state.minimizeToTrayOnClose, isFalse);

      notifier.dispose();
      manager.dispose();
    });

    test('ProviderContainer reads system tray providers', () async {
      final mockBridge = MockTrayPlatformBridge(supported: true);
      final manager = SystemTrayManager(bridge: mockBridge);
      await manager.initialize();

      final container = ProviderContainer(
        overrides: [
          systemTrayManagerProvider.overrideWithValue(manager),
        ],
      );

      try {
        final retrievedManager = container.read(systemTrayManagerProvider);
        expect(retrievedManager, equals(manager));

        final state = container.read(systemTrayStateProvider);
        expect(state.isEnabled, isTrue);
        expect(state.minimizeToTrayOnClose, isTrue);

        final isEnabled = container.read(systemTrayEnabledProvider);
        expect(isEnabled, isTrue);

        final minimizeToTray =
            container.read(systemTrayMinimizeToTrayProvider);
        expect(minimizeToTray, isTrue);

        // Mutate via notifier
        final notifier = container.read(systemTrayStateProvider.notifier);
        await notifier.togglePlayback();

        expect(container.read(systemTrayStateProvider).isPlaying, isTrue);
      } finally {
        container.dispose();
        manager.dispose();
      }
    });
  });

  group('LinuxSystemTraySettingsCard Widget Tests', () {
    testWidgets('Renders settings card and interacts with controls',
        (tester) async {
      final mockBridge = MockTrayPlatformBridge(
        supported: true,
        mockDesktopEnvironment: 'GNOME Shell',
      );
      final manager = SystemTrayManager(bridge: mockBridge);
      await manager.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemTrayManagerProvider.overrideWithValue(manager),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LinuxSystemTraySettingsCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header texts and badges
      expect(find.text('Linux System Tray & Menu'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Desktop: GNOME Shell'), findsOneWidget);
      expect(find.text('Minimize to Tray on Close'), findsOneWidget);
      expect(find.text('Start Minimized'), findsOneWidget);
      expect(find.text('Track Change Notifications'), findsOneWidget);
      expect(find.text('TRAY CONTEXT MENU PREVIEW'), findsOneWidget);

      // Verify preview actions
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

      // Tap play button preview
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(manager.state.isPlaying, isTrue);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Tap mute button preview
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pumpAndSettle();
      expect(manager.state.isMuted, isTrue);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

      manager.dispose();
    });

    testWidgets('Renders unsupported message when platform is not Linux',
        (tester) async {
      final mockBridge = MockTrayPlatformBridge(supported: false);
      final manager = SystemTrayManager(bridge: mockBridge);
      await manager.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemTrayManagerProvider.overrideWithValue(manager),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LinuxSystemTraySettingsCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unsupported'), findsOneWidget);
      expect(
        find.text(
          'System Tray / StatusNotifierItem is only available on Linux Desktop environments.',
        ),
        findsOneWidget,
      );

      manager.dispose();
    });
  });
}
