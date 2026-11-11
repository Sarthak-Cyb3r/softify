import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/offline_mode_toggle.dart';

class MockPrefsStorage implements OfflineModePrefsStorage {
  final Map<String, bool> store = {};

  @override
  Future<bool?> getBool(String key) async => store[key];

  @override
  Future<bool> setBool(String key, bool value) async {
    store[key] = value;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPrefsStorage mockStorage;

  setUp(() {
    mockStorage = MockPrefsStorage();
    OfflineModeNotifier.customStorage = mockStorage;
  });

  tearDown(() {
    OfflineModeNotifier.customStorage = null;
  });

  const localTrack1 = Track(
    id: 'local_101',
    sourceId: 'local_source_101',
    title: 'Local Song 1',
    artist: 'Local Artist',
    duration: Duration(seconds: 180),
  );

  const localTrackPath = Track(
    id: 'file_track_02',
    sourceId: '/storage/emulated/0/Music/song.mp3',
    title: 'Storage Song',
    artist: 'Storage Artist',
    duration: Duration(seconds: 210),
  );

  const onlineTrackDownloaded = Track(
    id: 'online_down_01',
    sourceId: 'yt_abc123',
    title: 'Downloaded Hit',
    artist: 'Famous Artist',
    duration: Duration(seconds: 240),
  );

  const onlineTrackStreamOnly = Track(
    id: 'online_stream_99',
    sourceId: 'yt_xyz999',
    title: 'Cloud Only Song',
    artist: 'Streamer Artist',
    duration: Duration(seconds: 195),
  );

  final allTestTracks = [
    localTrack1,
    localTrackPath,
    onlineTrackDownloaded,
    onlineTrackStreamOnly,
  ];

  group('OfflineModeNotifier & isOfflineOnlyModeProvider', () {
    test('defaults to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isOffline = container.read(isOfflineOnlyModeProvider);
      expect(isOffline, false);
      expect(OfflineModeNotifier.isOffline, false);
    });

    test('can toggle and persist offline mode state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(isOfflineOnlyModeProvider.notifier);

      await notifier.setOfflineMode(true);
      expect(container.read(isOfflineOnlyModeProvider), true);
      expect(OfflineModeNotifier.isOffline, true);
      expect(mockStorage.store[kOfflineOnlyModePrefKey], true);

      await notifier.toggle();
      expect(container.read(isOfflineOnlyModeProvider), false);
      expect(OfflineModeNotifier.isOffline, false);
      expect(mockStorage.store[kOfflineOnlyModePrefKey], false);
    });

    test('loads persisted true state from storage', () async {
      mockStorage.store[kOfflineOnlyModePrefKey] = true;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger instantiation and loading
      container.read(isOfflineOnlyModeProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(isOfflineOnlyModeProvider), true);
      expect(OfflineModeNotifier.isOffline, true);
    });
  });

  group('isTrackOffline logic', () {
    test('identifies local tracks by ID and sourceId prefix', () {
      expect(isTrackOffline(localTrack1), true);
      expect(isTrackOffline(localTrackPath), true);
      expect(isLocalDeviceTrack(localTrack1), true);
      expect(isLocalDeviceTrack(localTrackPath), true);
    });

    test('identifies downloaded track when trackId is in completed set', () {
      final completed = {'online_down_01'};
      expect(isTrackOffline(onlineTrackDownloaded, completed), true);
      expect(isTrackOffline(onlineTrackStreamOnly, completed), false);
    });
  });

  group('filterOfflineTracks helper', () {
    test('returns all tracks unmodified when offline mode is false', () {
      final result = filterOfflineTracks(
        allTestTracks,
        isOfflineMode: false,
        downloadedTrackIds: {'online_down_01'},
      );

      expect(result.length, 4);
      expect(result, equals(allTestTracks));
    });

    test('filters out online stream tracks when offline mode is true', () {
      final result = filterOfflineTracks(
        allTestTracks,
        isOfflineMode: true,
        downloadedTrackIds: {'online_down_01'},
      );

      // Should keep: localTrack1, localTrackPath, onlineTrackDownloaded
      // Should exclude: onlineTrackStreamOnly
      expect(result.length, 3);
      expect(result.contains(localTrack1), true);
      expect(result.contains(localTrackPath), true);
      expect(result.contains(onlineTrackDownloaded), true);
      expect(result.contains(onlineTrackStreamOnly), false);
    });

    test('extension filterOfflineOnly delegates cleanly', () {
      final filtered = allTestTracks.filterOfflineOnly(
        isOfflineMode: true,
        downloadedTrackIds: {'online_down_01'},
      );

      expect(filtered.length, 3);
      expect(filtered.contains(onlineTrackStreamOnly), false);
    });
  });

  group('OfflineModeSwitchTile Widget', () {
    testWidgets('renders switch and toggles offline mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool? toggledValue;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: OfflineModeSwitchTile(
                onToggle: (val) => toggledValue = val,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Offline Mode'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Initially off
      expect(container.read(isOfflineOnlyModeProvider), false);

      // Tap switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(container.read(isOfflineOnlyModeProvider), true);
      expect(toggledValue, true);
    });
  });

  group('OfflineModeBanner Widget', () {
    testWidgets('hidden when offline mode is disabled', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  OfflineModeBanner(),
                  Text('Content Area'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Content Area'), findsOneWidget);
      // Banner text should not be visible
      expect(find.text('Offline Mode Active'), findsNothing);
    });

    testWidgets('visible when offline mode is enabled and Go Online button works',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Enable offline mode
      await container.read(isOfflineOnlyModeProvider.notifier).setOfflineMode(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  OfflineModeBanner(),
                  Text('Content Area'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline Mode Active'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('Go Online'), findsOneWidget);

      // Tap Go Online
      await tester.tap(find.text('Go Online'));
      await tester.pumpAndSettle();

      // Offline mode should now be turned off
      expect(container.read(isOfflineOnlyModeProvider), false);
    });

    testWidgets('OfflineModeBannerSliver integrates with CustomScrollView',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(isOfflineOnlyModeProvider.notifier).setOfflineMode(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  OfflineModeBannerSliver(),
                  SliverToBoxAdapter(child: Text('Sliver Content')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline Mode Active'), findsOneWidget);
      expect(find.text('Sliver Content'), findsOneWidget);
    });
  });
}
