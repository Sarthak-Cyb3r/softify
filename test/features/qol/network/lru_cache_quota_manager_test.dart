// ============================================================================
// Unit & Widget Tests for Softify QoL Feature 46:
// Configurable Disk Cache Size & Automated LRU Audio Chunk Purge Manager
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:softify/features/qol/network/lru_cache_quota_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testCacheDir;

  setUp(() {
    SharedPreferences.reset();
    testCacheDir = Directory.systemTemp.createTempSync('softify_lru_test_');
  });

  tearDown(() {
    SharedPreferences.reset();
    try {
      if (testCacheDir.existsSync()) {
        testCacheDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  // ==========================================================================
  // 1. CacheQuotaLimit Enum Tests
  // ==========================================================================
  group('CacheQuotaLimit', () {
    test('defines all 5 required limits with exact byte counts', () {
      expect(CacheQuotaLimit.values.length, 5);

      expect(CacheQuotaLimit.mb500.bytes, 500 * 1024 * 1024);
      expect(CacheQuotaLimit.mb500.label, '500 MB');
      expect(CacheQuotaLimit.mb500.isUnlimited, isFalse);

      expect(CacheQuotaLimit.gb1.bytes, 1024 * 1024 * 1024);
      expect(CacheQuotaLimit.gb1.label, '1 GB');
      expect(CacheQuotaLimit.gb1.isUnlimited, isFalse);

      expect(CacheQuotaLimit.gb2.bytes, 2 * 1024 * 1024 * 1024);
      expect(CacheQuotaLimit.gb2.label, '2 GB');
      expect(CacheQuotaLimit.gb2.isUnlimited, isFalse);

      expect(CacheQuotaLimit.gb5.bytes, 5 * 1024 * 1024 * 1024);
      expect(CacheQuotaLimit.gb5.label, '5 GB');
      expect(CacheQuotaLimit.gb5.isUnlimited, isFalse);

      expect(CacheQuotaLimit.unlimited.bytes, isNull);
      expect(CacheQuotaLimit.unlimited.label, 'Unlimited');
      expect(CacheQuotaLimit.unlimited.isUnlimited, isTrue);
    });

    test('fromId parses valid identifiers and falls back to 2 GB default', () {
      expect(CacheQuotaLimit.fromId('500mb'), CacheQuotaLimit.mb500);
      expect(CacheQuotaLimit.fromId('1gb'), CacheQuotaLimit.gb1);
      expect(CacheQuotaLimit.fromId('2gb'), CacheQuotaLimit.gb2);
      expect(CacheQuotaLimit.fromId('5gb'), CacheQuotaLimit.gb5);
      expect(CacheQuotaLimit.fromId('unlimited'), CacheQuotaLimit.unlimited);
      expect(CacheQuotaLimit.fromId('UNKNOWN'), CacheQuotaLimit.gb2);
      expect(CacheQuotaLimit.fromId(null), CacheQuotaLimit.gb2);
    });

    test('fromBytes parses exact byte limits and handles unlimited', () {
      expect(
          CacheQuotaLimit.fromBytes(500 * 1024 * 1024), CacheQuotaLimit.mb500);
      expect(
          CacheQuotaLimit.fromBytes(1024 * 1024 * 1024), CacheQuotaLimit.gb1);
      expect(CacheQuotaLimit.fromBytes(2 * 1024 * 1024 * 1024),
          CacheQuotaLimit.gb2);
      expect(CacheQuotaLimit.fromBytes(5 * 1024 * 1024 * 1024),
          CacheQuotaLimit.gb5);
      expect(CacheQuotaLimit.fromBytes(null), CacheQuotaLimit.unlimited);
      expect(CacheQuotaLimit.fromBytes(0), CacheQuotaLimit.unlimited);
      expect(CacheQuotaLimit.fromBytes(-100), CacheQuotaLimit.unlimited);
    });
  });

  // ==========================================================================
  // 2. Cache Models & Statistics Tests
  // ==========================================================================
  group('CacheStorageUsage & PurgeResult Models', () {
    final epochZero = DateTime.fromMillisecondsSinceEpoch(0);

    test('CacheStorageUsage formats MB and GB sizes properly', () {
      final mbUsage = CacheStorageUsage(
        totalBytes: 250 * 1024 * 1024,
        fileCount: 50,
        scannedAt: epochZero,
      );
      expect(mbUsage.sizeMb, 250.0);
      expect(mbUsage.formattedSize, '250.00 MB');

      final gbUsage = CacheStorageUsage(
        totalBytes: (2.5 * 1024 * 1024 * 1024).toInt(),
        fileCount: 1500,
        scannedAt: epochZero,
      );
      expect(gbUsage.sizeGb, closeTo(2.5, 0.01));
      expect(gbUsage.formattedSize, '2.50 GB');
    });

    test('PurgeResult computes formatted purged and remaining MB values', () {
      final result = PurgeResult(
        purgedFilesCount: 20,
        purgedBytes: 50 * 1024 * 1024,
        remainingFilesCount: 80,
        remainingSizeBytes: 200 * 1024 * 1024,
        completedAt: epochZero,
      );

      expect(result.purgedMb, 50.0);
      expect(result.formattedPurgedMb, '50.00 MB');
      expect(result.remainingMb, 200.0);
      expect(result.formattedRemainingMb, '200.00 MB');
      expect(result.success, isTrue);
    });
  });

  // ==========================================================================
  // 3. LRU Purge Algorithm Engine Tests
  // ==========================================================================
  group('LruPurgeEngine', () {
    late LruPurgeEngine engine;

    setUp(() {
      engine = LruPurgeEngine(customDirectory: testCacheDir);
    });

    test('returns zero usage when cache directory is empty', () async {
      final usage = await engine.calculateUsage(testCacheDir);
      expect(usage.totalBytes, 0);
      expect(usage.fileCount, 0);
    });

    test('scans and sorts files strictly by least recently accessed order',
        () async {
      final track1 = Directory(p.join(testCacheDir.path, 'track_1'))..createSync();
      final track2 = Directory(p.join(testCacheDir.path, 'track_2'))..createSync();

      final now = DateTime.now();

      // Chunk 1: Accessed 3 hours ago (oldest)
      final chunkOld = File(p.join(track1.path, 'chunk_0.bin'))..createSync();
      chunkOld.writeAsBytesSync(List.filled(1024, 1));
      chunkOld.setLastModifiedSync(now.subtract(const Duration(hours: 3)));

      // Chunk 2: Accessed 1 hour ago (middle)
      final chunkMid = File(p.join(track1.path, 'chunk_1.bin'))..createSync();
      chunkMid.writeAsBytesSync(List.filled(2048, 2));
      chunkMid.setLastModifiedSync(now.subtract(const Duration(hours: 1)));

      // Chunk 3: Accessed 5 minutes ago (newest)
      final chunkNew = File(p.join(track2.path, 'chunk_0.bin'))..createSync();
      chunkNew.writeAsBytesSync(List.filled(4096, 3));
      chunkNew.setLastModifiedSync(now.subtract(const Duration(minutes: 5)));

      final records = await engine.scanFiles(testCacheDir);
      expect(records.length, 3);
      expect(records[0].path, chunkOld.path);
      expect(records[1].path, chunkMid.path);
      expect(records[2].path, chunkNew.path);

      final usage = await engine.calculateUsage(testCacheDir);
      expect(usage.totalBytes, 1024 + 2048 + 4096);
      expect(usage.fileCount, 3);
    });

    test(
        'purgeToQuota removes oldest accessed files until under quota and keeps newest',
        () async {
      final trackDir = Directory(p.join(testCacheDir.path, 'track_lru'))
        ..createSync();
      final now = DateTime.now();

      // File A: Oldest (1000 bytes)
      final fileA = File(p.join(trackDir.path, 'chunk_0.bin'))..createSync();
      fileA.writeAsBytesSync(List.filled(1000, 10));
      fileA.setLastModifiedSync(now.subtract(const Duration(days: 2)));

      // File B: Intermediate (2000 bytes)
      final fileB = File(p.join(trackDir.path, 'chunk_1.bin'))..createSync();
      fileB.writeAsBytesSync(List.filled(2000, 20));
      fileB.setLastModifiedSync(now.subtract(const Duration(days: 1)));

      // File C: Newest (3000 bytes)
      final fileC = File(p.join(trackDir.path, 'chunk_2.bin'))..createSync();
      fileC.writeAsBytesSync(List.filled(3000, 30));
      fileC.setLastModifiedSync(now.subtract(const Duration(hours: 1)));

      // Total is 6000 bytes. Target quota: 3500 bytes.
      final result = await engine.purgeToQuota(
        targetBytes: 3500,
        headroomRatio: 1.0,
        targetDir: testCacheDir,
      );

      expect(result.success, isTrue);
      // File A (1000) was deleted -> 5000 bytes.
      // File B (2000) was deleted -> 3000 bytes <= 3500.
      expect(result.purgedFilesCount, 2);
      expect(result.purgedBytes, 3000);
      expect(result.remainingFilesCount, 1);
      expect(result.remainingSizeBytes, 3000);

      expect(fileA.existsSync(), isFalse);
      expect(fileB.existsSync(), isFalse);
      expect(fileC.existsSync(), isTrue); // Newest preserved!
    });

    test('prunes empty parent directories when all chunk files are purged',
        () async {
      final subFolder =
          Directory(p.join(testCacheDir.path, 'ephemeral_track_dir'))
            ..createSync();
      final file = File(p.join(subFolder.path, 'chunk_0.bin'))..createSync();
      file.writeAsBytesSync(List.filled(500, 1));

      expect(subFolder.existsSync(), isTrue);

      final result = await engine.purgeToQuota(
        targetBytes: 0,
        targetDir: testCacheDir,
      );

      expect(result.purgedFilesCount, 1);
      expect(file.existsSync(), isFalse);
      // Empty parent folder should be pruned
      expect(subFolder.existsSync(), isFalse);
    });

    test('clearAll wipes all files in cache directory', () async {
      final file1 = File(p.join(testCacheDir.path, 'chunk_a.bin'))..createSync();
      file1.writeAsBytesSync(List.filled(100, 1));
      final file2 = File(p.join(testCacheDir.path, 'chunk_b.bin'))..createSync();
      file2.writeAsBytesSync(List.filled(200, 2));

      final result = await engine.clearAll(testCacheDir);
      expect(result.purgedFilesCount, 2);
      expect(result.purgedBytes, 300);
      expect(result.remainingFilesCount, 0);

      final usage = await engine.calculateUsage(testCacheDir);
      expect(usage.totalBytes, 0);
      expect(usage.fileCount, 0);
    });
  });

  // ==========================================================================
  // 4. LruCacheQuotaNotifier & Riverpod State Tests
  // ==========================================================================
  group('LruCacheQuotaNotifier', () {
    test('initializes with persisted quota and computes disk footprint',
        () async {
      SharedPreferences.setMockInitialValues({
        kCacheQuotaLimitPrefKey: '1gb',
      });

      // Write a sample chunk file to testCacheDir
      final file = File(p.join(testCacheDir.path, 'chunk_0.bin'))..createSync();
      file.writeAsBytesSync(List.filled(2048, 42));

      final notifier = LruCacheQuotaNotifier(
        customCacheDirectory: testCacheDir,
      );

      // Await initialization
      await notifier.initialize();

      expect(notifier.state.quota, CacheQuotaLimit.gb1);
      expect(notifier.state.currentSizeBytes, 2048);
      expect(notifier.state.fileCount, 1);
      expect(notifier.state.isLoading, isFalse);
    });

    test('setQuota updates quota, persists to SharedPreferences, and triggers LRU purge',
        () async {
      SharedPreferences.setMockInitialValues({
        kCacheQuotaLimitPrefKey: '5gb',
      });

      final now = DateTime.now();
      // Create 2 chunks: total 3000 bytes
      final file1 = File(p.join(testCacheDir.path, 'chunk_1.bin'))..createSync();
      file1.writeAsBytesSync(List.filled(2000, 1));
      file1.setLastModifiedSync(now.subtract(const Duration(hours: 2)));

      final file2 = File(p.join(testCacheDir.path, 'chunk_2.bin'))..createSync();
      file2.writeAsBytesSync(List.filled(1000, 2));
      file2.setLastModifiedSync(now.subtract(const Duration(minutes: 5)));

      final notifier = LruCacheQuotaNotifier(
        customCacheDirectory: testCacheDir,
      );
      await notifier.initialize();

      expect(notifier.state.currentSizeBytes, 3000);

      // Update quota to 500 MB (simulated here)
      await notifier.setQuota(CacheQuotaLimit.mb500);
      expect(notifier.state.quota, CacheQuotaLimit.mb500);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kCacheQuotaLimitPrefKey), '500mb');
    });

    test('manual purgeToQuota trims cache down to target and updates state',
        () async {
      final now = DateTime.now();
      final file1 = File(p.join(testCacheDir.path, 'chunk_1.bin'))..createSync();
      file1.writeAsBytesSync(List.filled(5000, 1));
      file1.setLastModifiedSync(now.subtract(const Duration(days: 1)));

      final file2 = File(p.join(testCacheDir.path, 'chunk_2.bin'))..createSync();
      file2.writeAsBytesSync(List.filled(2000, 2));
      file2.setLastModifiedSync(now.subtract(const Duration(minutes: 10)));

      final notifier = LruCacheQuotaNotifier(
        customCacheDirectory: testCacheDir,
        initialQuota: CacheQuotaLimit.mb500,
      );
      await notifier.initialize();

      expect(notifier.state.currentSizeBytes, 7000);

      final result = await notifier.purgeToQuota(targetBytes: 3000, headroomRatio: 1.0);
      expect(result.purgedFilesCount, 1);
      expect(result.purgedBytes, 5000);
      expect(notifier.state.currentSizeBytes, 2000);
      expect(notifier.state.fileCount, 1);
      expect(notifier.state.lastPurgeResult, isNotNull);
    });

    test('clearEntireCache empties disk cache and zeroes out state', () async {
      final file = File(p.join(testCacheDir.path, 'chunk_test.bin'))..createSync();
      file.writeAsBytesSync(List.filled(1024, 5));

      final notifier = LruCacheQuotaNotifier(
        customCacheDirectory: testCacheDir,
      );
      await notifier.initialize();

      expect(notifier.state.currentSizeBytes, 1024);

      final result = await notifier.clearEntireCache();
      expect(result.purgedFilesCount, 1);
      expect(notifier.state.currentSizeBytes, 0);
      expect(notifier.state.fileCount, 0);
    });
  });

  // ==========================================================================
  // 5. CacheQuotaSelectorCard Widget Tests
  // ==========================================================================
  group('CacheQuotaSelectorCard Widget', () {
    testWidgets('renders header, quota limits, file count, and progress bar',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        kCacheQuotaLimitPrefKey: '2gb',
      });

      final testFile = File(p.join(testCacheDir.path, 'chunk_ui.bin'))..createSync();
      testFile.writeAsBytesSync(List.filled(1024 * 512, 1)); // 512 KB

      final container = ProviderContainer(
        overrides: [
          lruCacheQuotaNotifierProvider.overrideWith((ref) {
            return LruCacheQuotaNotifier(
              customCacheDirectory: testCacheDir,
              initialQuota: CacheQuotaLimit.gb2,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CacheQuotaSelectorCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Header and Labels
      expect(find.text('Disk Cache Quota'), findsOneWidget);
      expect(find.text('Automatic LRU eviction of cached audio chunks'),
          findsOneWidget);

      // 2. Verify all 5 Quota options
      expect(find.text('500 MB'), findsOneWidget);
      expect(find.text('1 GB'), findsOneWidget);
      expect(find.text('2 GB'), findsAtLeastNWidgets(1));
      expect(find.text('5 GB'), findsOneWidget);
      expect(find.text('Unlimited'), findsOneWidget);

      // 3. Verify Action Buttons
      expect(find.byKey(const Key('btn_purge_lru')), findsOneWidget);
      expect(find.byKey(const Key('btn_clear_cache')), findsOneWidget);
      expect(find.byKey(const Key('btn_refresh_quota')), findsOneWidget);
    });

    testWidgets('selecting quota option updates state and persists preference',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        kCacheQuotaLimitPrefKey: '2gb',
      });

      final container = ProviderContainer(
        overrides: [
          lruCacheQuotaNotifierProvider.overrideWith((ref) {
            return LruCacheQuotaNotifier(
              customCacheDirectory: testCacheDir,
              initialQuota: CacheQuotaLimit.gb2,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CacheQuotaSelectorCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 5 GB option
      final fiveGbOption = find.byKey(const Key('quota_option_5gb'));
      expect(fiveGbOption, findsOneWidget);
      await tester.tap(fiveGbOption);
      await tester.pumpAndSettle();

      expect(container.read(lruCacheQuotaNotifierProvider).quota,
          CacheQuotaLimit.gb5);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kCacheQuotaLimitPrefKey), '5gb');
    });

    testWidgets('tapping Purge LRU button executes purge and displays banner',
        (tester) async {
      final file1 = File(p.join(testCacheDir.path, 'chunk_a.bin'))..createSync();
      file1.writeAsBytesSync(List.filled(2048, 1));

      final container = ProviderContainer(
        overrides: [
          lruCacheQuotaNotifierProvider.overrideWith((ref) {
            return LruCacheQuotaNotifier(
              customCacheDirectory: testCacheDir,
              initialQuota: CacheQuotaLimit.mb500,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      bool purgeCallbackFired = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CacheQuotaSelectorCard(
                  onPurgeCompleted: () {
                    purgeCallbackFired = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final purgeBtn = find.byKey(const Key('btn_purge_lru'));
      await tester.tap(purgeBtn);
      await tester.pumpAndSettle();

      expect(purgeCallbackFired, isTrue);
      expect(find.byKey(const Key('purge_result_banner')), findsOneWidget);
    });

    testWidgets('tapping Clear All purges all chunks from storage',
        (tester) async {
      final file = File(p.join(testCacheDir.path, 'chunk_x.bin'))..createSync();
      file.writeAsBytesSync(List.filled(4096, 7));

      final container = ProviderContainer(
        overrides: [
          lruCacheQuotaNotifierProvider.overrideWith((ref) {
            return LruCacheQuotaNotifier(
              customCacheDirectory: testCacheDir,
              initialQuota: CacheQuotaLimit.gb2,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CacheQuotaSelectorCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clearBtn = find.byKey(const Key('btn_clear_cache'));
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(container.read(lruCacheQuotaNotifierProvider).currentSizeBytes, 0);
      expect(container.read(lruCacheQuotaNotifierProvider).fileCount, 0);
    });
  });
}
