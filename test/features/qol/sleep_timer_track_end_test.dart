import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:softify/features/qol/sleep_timer_track_end.dart';

void main() {
  group('EndOfTrackSleepController tests', () {
    test('initial state is false and toggles state correctly', () {
      final controller = EndOfTrackSleepController();
      expect(controller.state, false);

      controller.enable();
      expect(controller.state, true);

      controller.disable();
      expect(controller.state, false);

      controller.toggle();
      expect(controller.state, true);

      controller.setEnabled(false);
      expect(controller.state, false);

      controller.dispose();
    });
  });

  group('EndOfTrackSleepTile widget tests', () {
    testWidgets('renders tile with default properties', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: EndOfTrackSleepTile(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Stop after current track'), findsOneWidget);
      expect(find.text('Pauses music when current song finishes'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });
  });
}
