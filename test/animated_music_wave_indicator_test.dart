import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/presentation/widgets/animated_music_wave_indicator.dart';

void main() {
  group('AnimatedMusicWaveIndicator Tests', () {
    testWidgets('renders correctly when playing and paused', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedMusicWaveIndicator(
                isPlaying: true,
                size: 24,
                barCount: 4,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedMusicWaveIndicator), findsOneWidget);

      // Verify widget rebuilds when toggling isPlaying
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedMusicWaveIndicator(
                isPlaying: false,
                size: 24,
                barCount: 4,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AnimatedMusicWaveIndicator), findsOneWidget);
    });
  });
}
