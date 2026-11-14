import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/features/qol/desktop_volume_scroll_listener.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('volumeScrollStepProvider', () {
    test('defaults to 0.05 (5%)', () {
      final container = ProviderContainer();
      try {
        final step = container.read(volumeScrollStepProvider);
        expect(step, 0.05);
      } finally {
        container.dispose();
      }
    });

    test('can be updated to 0.01 or custom steps', () {
      final container = ProviderContainer();
      try {
        container.read(volumeScrollStepProvider.notifier).state =
            VolumeScrollSteps.onePercent;
        expect(container.read(volumeScrollStepProvider), 0.01);

        container.read(volumeScrollStepProvider.notifier).state =
            VolumeScrollSteps.tenPercent;
        expect(container.read(volumeScrollStepProvider), 0.10);
      } finally {
        container.dispose();
      }
    });
  });

  group('DesktopVolumeScrollListener Widget', () {
    testWidgets('renders child widget correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DesktopVolumeScrollListener(
                child: Text('Desktop Player Bar Child'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Desktop Player Bar Child'), findsOneWidget);
    });

    testWidgets('scroll wheel up increases volume', (tester) async {
      double? changedVolume;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 100,
                  child: DesktopVolumeScrollListener(
                    step: 0.05,
                    onVolumeChanged: (vol) => changedVolume = vol,
                    child: const ColoredBox(
                      color: Colors.black,
                      child: Text('Player Bar'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.text('Player Bar'));

      // Simulate mouse wheel up: PointerScrollEvent with negative scrollDelta.dy
      final pointerSignal = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, -20),
      );

      final hitResult = HitTestResult();
      tester.binding.hitTestInView(hitResult, center, tester.view.viewId);
      for (final entry in hitResult.path) {
        entry.target.handleEvent(pointerSignal, entry);
      }
      await tester.pump();

      // Default volume was 1.0, so increasing stays clamped at 1.0
      expect(changedVolume, 1.0);
    });

    testWidgets('scroll wheel down decreases volume by configured step', (tester) async {
      double? changedVolume;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 100,
                  child: DesktopVolumeScrollListener(
                    step: 0.05,
                    onVolumeChanged: (vol) => changedVolume = vol,
                    child: const ColoredBox(
                      color: Colors.black,
                      child: Text('Player Bar Target'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.text('Player Bar Target'));

      // Simulate mouse wheel down: positive scrollDelta.dy (+20)
      final pointerSignal = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, 20),
      );

      final hitResult = HitTestResult();
      tester.binding.hitTestInView(hitResult, center, tester.view.viewId);
      for (final entry in hitResult.path) {
        entry.target.handleEvent(pointerSignal, entry);
      }
      await tester.pump();

      // 1.0 - 0.05 = 0.95
      expect(changedVolume, 0.95);
    });

    testWidgets('invertScroll reverses direction', (tester) async {
      double? changedVolume;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 100,
                  child: DesktopVolumeScrollListener(
                    step: 0.05,
                    invertScroll: true,
                    onVolumeChanged: (vol) => changedVolume = vol,
                    child: const Text('Invert Target'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.text('Invert Target'));

      // With invertScroll: true, dy = -20 (normally up) should decrease volume
      final pointerSignal = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, -20),
      );

      final hitResult = HitTestResult();
      tester.binding.hitTestInView(hitResult, center, tester.view.viewId);
      for (final entry in hitResult.path) {
        entry.target.handleEvent(pointerSignal, entry);
      }
      await tester.pump();

      expect(changedVolume, 0.95);
    });

    testWidgets('enabled: false ignores scroll signals', (tester) async {
      double? changedVolume;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 100,
                  child: DesktopVolumeScrollListener(
                    enabled: false,
                    step: 0.05,
                    onVolumeChanged: (vol) => changedVolume = vol,
                    child: const Text('Disabled Target'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.text('Disabled Target'));

      final pointerSignal = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, 20),
      );

      final hitResult = HitTestResult();
      tester.binding.hitTestInView(hitResult, center, tester.view.viewId);
      for (final entry in hitResult.path) {
        entry.target.handleEvent(pointerSignal, entry);
      }
      await tester.pump();

      expect(changedVolume, null);
    });

    testWidgets('shows floating HUD toast with percentage when scrolling', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 90,
                  child: DesktopVolumeScrollListener(
                    step: 0.05,
                    showFloatingHud: true,
                    child: Text('HUD Bar Target'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.text('HUD Bar Target'));

      // Scroll down: 1.0 -> 0.95 (95%)
      final pointerSignal = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, 20),
      );

      final hitResult = HitTestResult();
      tester.binding.hitTestInView(hitResult, center, tester.view.viewId);
      for (final entry in hitResult.path) {
        entry.target.handleEvent(pointerSignal, entry);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 95% HUD text is visible
      expect(find.text('95%'), findsOneWidget);

      // Advance past dismiss duration
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 300));

      // HUD has faded out
      expect(find.text('95%'), findsNothing);
    });
  });
}
