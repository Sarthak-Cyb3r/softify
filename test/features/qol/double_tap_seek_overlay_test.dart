import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/features/qol/double_tap_seek_overlay.dart';
import 'package:softify/presentation/providers/player_providers.dart';

class _FakeAudioHandler extends Fake implements SoftifyAudioHandler {
  @override
  Duration get position => const Duration(seconds: 30);
  @override
  Track? get currentTrack => const Track(id: '1', sourceId: '1', title: 'T', artist: 'A', duration: Duration(seconds: 180));
  @override
  Future<void> seek(Duration position) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget({
    required Widget child,
    VoidCallback? onTap,
    void Function(Duration, int)? onSeek,
    Duration seekDuration = const Duration(seconds: 10),
    bool enabled = true,
  }) {
    return ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(_FakeAudioHandler()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: DoubleTapSeekOverlay(
                onTap: onTap,
                onSeek: onSeek,
                seekDuration: seekDuration,
                enabled: enabled,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('DoubleTapSeekOverlay Widget', () {
    testWidgets('renders child widget properly', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const Text('Artwork Card'),
        ),
      );

      expect(find.text('Artwork Card'), findsOneWidget);
    });

    testWidgets('single tap triggers onTap callback', (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        buildTestableWidget(
          onTap: () => tapCount++,
          child: const ColoredBox(
            color: Colors.blue,
            child: SizedBox.expand(),
          ),
        ),
      );

      // Single tap center
      await tester.tap(find.byType(DoubleTapSeekOverlay));
      // Settle disambiguation timeout
      await tester.pump(const Duration(milliseconds: 350));

      expect(tapCount, 1);
    });

    testWidgets('double tap on right half triggers forward seek (+10s)', (tester) async {
      int? accumulated;

      await tester.pumpWidget(
        buildTestableWidget(
          onSeek: (_, secs) {
            accumulated = secs;
          },
          child: const ColoredBox(
            color: Colors.blue,
            child: SizedBox.expand(),
          ),
        ),
      );

      final topLeft = tester.getTopLeft(find.byType(DoubleTapSeekOverlay));
      // Right half tap: x = 220 (out of 300)
      final rightHalfPos = topLeft + const Offset(220, 150);

      await tester.tapAt(rightHalfPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(rightHalfPos);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(accumulated, 10);
      expect(find.text('+10s'), findsOneWidget);
    });

    testWidgets('double tap on left half triggers rewind seek (-10s)', (tester) async {
      int? accumulated;

      await tester.pumpWidget(
        buildTestableWidget(
          onSeek: (_, secs) {
            accumulated = secs;
          },
          child: const ColoredBox(
            color: Colors.blue,
            child: SizedBox.expand(),
          ),
        ),
      );

      final topLeft = tester.getTopLeft(find.byType(DoubleTapSeekOverlay));
      // Left half tap: x = 80 (out of 300)
      final leftHalfPos = topLeft + const Offset(80, 150);

      await tester.tapAt(leftHalfPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(leftHalfPos);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(accumulated, 10);
      expect(find.text('-10s'), findsOneWidget);
    });

    testWidgets('rapid taps accumulate seek time (+20s)', (tester) async {
      int? accumulated;

      await tester.pumpWidget(
        buildTestableWidget(
          onSeek: (_, secs) => accumulated = secs,
          child: const ColoredBox(
            color: Colors.blue,
            child: SizedBox.expand(),
          ),
        ),
      );

      final topLeft = tester.getTopLeft(find.byType(DoubleTapSeekOverlay));
      final rightHalfPos = topLeft + const Offset(220, 150);

      // Double tap to activate
      await tester.tapAt(rightHalfPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(rightHalfPos);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('+10s'), findsOneWidget);
      expect(accumulated, 10);

      // 3rd tap while overlay is active
      await tester.tapAt(rightHalfPos);
      await tester.pump(const Duration(milliseconds: 350));

      expect(accumulated, 20);
      expect(find.text('+20s'), findsOneWidget);
    });

    testWidgets('disabled overlay does not trigger seek on double tap', (tester) async {
      int seekCount = 0;
      int tapCount = 0;

      await tester.pumpWidget(
        buildTestableWidget(
          enabled: false,
          onTap: () => tapCount++,
          onSeek: (_, __) => seekCount++,
          child: const ColoredBox(
            color: Colors.blue,
            child: SizedBox.expand(),
          ),
        ),
      );

      final topLeft = tester.getTopLeft(find.byType(DoubleTapSeekOverlay));
      final rightHalfPos = topLeft + const Offset(220, 150);

      await tester.tapAt(rightHalfPos);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(rightHalfPos);
      await tester.pump(const Duration(milliseconds: 100));

      expect(seekCount, 0);
      expect(find.text('+10s'), findsNothing);
    });
  });
}
