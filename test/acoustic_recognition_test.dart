import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/providers/player_providers.dart';
import 'package:softify/presentation/theme/app_theme.dart';
import 'package:softify/presentation/widgets/acoustic_recognition_sheet.dart';

void main() {
  testWidgets('AcousticRecognitionSheet renders and identifies track from stream', (tester) async {
    const testTrack = Track(
      id: 'test_rec_123',
      sourceId: 'rec_123',
      title: 'Starboy',
      artist: 'The Weeknd',
      duration: Duration(seconds: 230),
      coverUrl: 'https://example.com/cover.jpg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTrackProvider.overrideWith((ref) => Stream.value(testTrack)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: AcousticRecognitionSheet(),
          ),
        ),
      ),
    );

    // Initial listening state
    expect(find.text('Acoustic Song Identification'), findsOneWidget);
    expect(find.text('Listening to music around you...'), findsOneWidget);

    // Fast-forward past recognition delay
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 200));

    // Recognized state
    expect(find.text('Track Recognized'), findsOneWidget);
    expect(find.text('Starboy'), findsOneWidget);
    expect(find.text('The Weeknd'), findsOneWidget);
    expect(find.text('Play Now'), findsOneWidget);
  });

  testWidgets('AcousticRecognitionSheet shows No Song Detected when no stream or match', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTrackProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: AcousticRecognitionSheet(),
          ),
        ),
      ),
    );

    expect(find.text('Acoustic Song Identification'), findsOneWidget);

    // Fast-forward past recognition delay
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('No Song Detected'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
