import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/presentation/widgets/wavy_slider.dart';

void main() {
  group('WavySlider Widget Tests', () {
    testWidgets('renders correctly with given value and max', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: WavySlider(
                value: 30.0,
                max: 100.0,
                isPlaying: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WavySlider), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('handles tap and drag gestures updating value', (tester) async {
      double changedValue = 0.0;
      double finalValue = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WavySlider(
                  value: 0.0,
                  max: 100.0,
                  isPlaying: false,
                  onChanged: (v) => changedValue = v,
                  onChangeEnd: (v) => finalValue = v,
                ),
              ),
            ),
          ),
        ),
      );

      // Tap at center (x = 100 of 200 => 50% = 50.0)
      final sliderFinder = find.byType(WavySlider);
      await tester.tap(sliderFinder);
      await tester.pumpAndSettle();

      expect(finalValue, closeTo(50.0, 5.0));
      expect(changedValue, closeTo(50.0, 5.0));
    });

    testWidgets('disabled slider ignores gestures', (tester) async {
      double finalValue = -1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: WavySlider(
                  value: 10.0,
                  max: 100.0,
                  enabled: false,
                  onChangeEnd: (v) => finalValue = v,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(WavySlider));
      await tester.pumpAndSettle();

      expect(finalValue, -1.0); // Never updated
    });
  });
}
