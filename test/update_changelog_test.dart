import 'dart:ui';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/data/database/app_database.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/providers/settings_providers.dart';
import 'package:softify/presentation/widgets/update_changelog_sheet.dart';
import 'package:softify/presentation/widgets/update_notification_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateChangelogSheet & Patch Notes Tests', () {
    testWidgets('UpdateChangelogSheet renders simple consumer-friendly highlights', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => UpdateChangelogSheet.show(context, version: '3.0.8'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Tap to open sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify header and badge
      expect(find.text("What's New"), findsOneWidget);
      expect(find.text('v3.0.8'), findsOneWidget);
      expect(find.text('Fresh looks, living artwork & smoother music'), findsOneWidget);

      // Verify simple consumer-friendly cards
      expect(find.text('Instant Liked Songs'), findsOneWidget);
      expect(find.text('Listen Together Rooms'), findsOneWidget);
      expect(find.text('Apple Music Style Player'), findsOneWidget);
      expect(find.text('Living Motion Album Artwork'), findsOneWidget);
      expect(find.text('Cinematic Blurred Lyrics'), findsOneWidget);

      // Scroll to verify remaining cards
      await tester.scrollUntilVisible(find.text('Liquid Glass Interface'), 150);
      expect(find.text('Liquid Glass Interface'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Smooth & Safe App Updates'), 150);
      expect(find.text('Smooth & Safe App Updates'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Faster & More Stable'), 150);
      expect(find.text('Faster & More Stable'), findsOneWidget);

      // Verify bottom action button
      expect(find.text("Got It, Let's Play!"), findsOneWidget);

      // Tap to close
      await tester.tap(find.text("Got It, Let's Play!"));
      await tester.pumpAndSettle();

      expect(find.text("What's New"), findsNothing);
    });
  });

  group('UpdateNotificationBanner Tests', () {
    testWidgets('UpdateNotificationBanner renders and handles Read Changelog action', (tester) async {
      bool readChangelogTapped = false;
      bool dismissTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateNotificationBanner(
              version: '3.0.7',
              onReadChangelog: () {
                readChangelogTapped = true;
              },
              onDismiss: () {
                dismissTapped = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify text and widgets
      expect(find.text('Softify Updated to v3.0.7! 🎉'), findsOneWidget);
      expect(find.text('Explore Apple Music player, motion covers & more.'), findsOneWidget);
      expect(find.text('Read Changelog'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap Read Changelog
      await tester.tap(find.text('Read Changelog'));
      await tester.pumpAndSettle();

      expect(readChangelogTapped, isTrue);
      expect(dismissTapped, isFalse);
    });

    testWidgets('UpdateNotificationBanner handles Dismiss action', (tester) async {
      bool readChangelogTapped = false;
      bool dismissTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateNotificationBanner(
              version: '3.0.7',
              onReadChangelog: () {
                readChangelogTapped = true;
              },
              onDismiss: () {
                dismissTapped = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Dismiss close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(dismissTapped, isTrue);
      expect(readChangelogTapped, isFalse);
    });
  });

  group('Post-Update Version Persistence in SQLite Drift', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('last_seen_app_version triggers update detection and persists upon acknowledge', () async {
      const currentVersion = '3.0.7';

      // 1. Initial State: last_seen_app_version is null
      final rowInitial = await (db.select(db.settings)
            ..where((t) => t.key.equals('last_seen_app_version')))
          .getSingleOrNull();
      expect(rowInitial, isNull);

      // Condition: lastSeen != currentVersion -> Banner should show
      bool shouldShowBanner = (rowInitial?.value != currentVersion);
      expect(shouldShowBanner, isTrue);

      // 2. User acknowledges or dismisses the banner
      await db.into(db.settings).insertOnConflictUpdate(
        const SettingRow(key: 'last_seen_app_version', value: currentVersion),
      );

      // Verify stored in DB
      final rowUpdated = await (db.select(db.settings)
            ..where((t) => t.key.equals('last_seen_app_version')))
          .getSingle();
      expect(rowUpdated.value, equals('3.0.7'));

      // 3. Subsequent check: lastSeen == currentVersion -> Banner suppressed
      final rowSubsequent = await (db.select(db.settings)
            ..where((t) => t.key.equals('last_seen_app_version')))
          .getSingleOrNull();
      bool shouldShowOnSubsequentLaunch = (rowSubsequent?.value != currentVersion);
      expect(shouldShowOnSubsequentLaunch, isFalse);
    });

    test('Upgrade from v3.0.6 to v3.0.7 triggers update detection', () async {
      // Seed DB with previous version
      await db.into(db.settings).insertOnConflictUpdate(
        const SettingRow(key: 'last_seen_app_version', value: '3.0.6'),
      );

      const targetVersion = '3.0.7';
      final row = await (db.select(db.settings)
            ..where((t) => t.key.equals('last_seen_app_version')))
          .getSingleOrNull();

      expect(row?.value, equals('3.0.6'));
      expect(row?.value != targetVersion, isTrue); // Triggers banner

      // After user opens changelog or dismisses banner:
      await db.into(db.settings).insertOnConflictUpdate(
        const SettingRow(key: 'last_seen_app_version', value: targetVersion),
      );

      final rowAfter = await (db.select(db.settings)
            ..where((t) => t.key.equals('last_seen_app_version')))
          .getSingleOrNull();
      expect(rowAfter?.value, equals('3.0.7'));
      expect(rowAfter?.value != targetVersion, isFalse); // Suppressed
    });
  });
}
