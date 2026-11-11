import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/jump_to_current_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget({
    required ScrollController scrollController,
    required int? currentTrackIndex,
    double itemExtent = 64.0,
    double leadingOffset = 0.0,
    int itemCount = 100,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: scrollController,
              itemCount: itemCount,
              itemExtent: itemExtent,
              itemBuilder: (context, index) => SizedBox(
                height: itemExtent,
                child: Text('Item $index'),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: JumpToCurrentTrackFab(
                scrollController: scrollController,
                currentTrackIndex: currentTrackIndex,
                itemExtent: itemExtent,
                leadingOffset: leadingOffset,
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('Hidden when track is in viewport', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(buildTestableWidget(
      scrollController: controller,
      currentTrackIndex: 2,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Jump to playing track'), findsNothing);
  });

  testWidgets('Hidden when currentTrackIndex is null or negative', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(buildTestableWidget(
      scrollController: controller,
      currentTrackIndex: null,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Jump to playing track'), findsNothing);
  });

  testWidgets('Shows floating pill when track is scrolled out of view below viewport', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(buildTestableWidget(
      scrollController: controller,
      currentTrackIndex: 50,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Jump to playing track'), findsOneWidget);
  });

  testWidgets('Tapping floating pill animates scrollController towards target track', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(buildTestableWidget(
      scrollController: controller,
      currentTrackIndex: 50,
      itemExtent: 64.0,
    ));
    await tester.pumpAndSettle();

    expect(controller.offset, 0.0);
    expect(find.text('Jump to playing track'), findsOneWidget);

    await tester.tap(find.text('Jump to playing track'));
    await tester.pumpAndSettle();

    expect(controller.offset > 2000.0, true);
  });

  testWidgets('Shows pill when track is scrolled above viewport and hides when scrolled into view', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(buildTestableWidget(
      scrollController: controller,
      currentTrackIndex: 0,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Jump to playing track'), findsNothing);

    controller.jumpTo(2500.0);
    await tester.pumpAndSettle();

    expect(find.text('Jump to playing track'), findsOneWidget);

    await tester.tap(find.text('Jump to playing track'));
    await tester.pumpAndSettle();

    expect(controller.offset, 0.0);
    expect(find.text('Jump to playing track'), findsNothing);
  });
}
