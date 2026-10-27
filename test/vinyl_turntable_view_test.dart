import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/presentation/widgets/vinyl_turntable_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VinylTurntableView renders with album art and responds to taps', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VinylTurntableView(
              coverUrl: null,
              isPlaying: true,
              ambientColor: const Color(0xFF1DB954),
              onTap: () => tapped = true,
              size: 300,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(VinylTurntableView), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    // Tap the turntable
    await tester.tap(find.byType(VinylTurntableView));
    expect(tapped, isTrue);

    // Advance frame for rotation
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('VinylTurntableView handles pause and stop gracefully', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: VinylTurntableView(
              coverUrl: null,
              isPlaying: false,
              ambientColor: Color(0xFF6366F1),
              showTonearm: false,
              size: 250,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(VinylTurntableView), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
  });
}
