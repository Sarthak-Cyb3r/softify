import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/presentation/theme/app_theme.dart';
import 'package:softify/presentation/widgets/shared/media_card.dart';
import 'package:softify/presentation/widgets/spotify_logo_badge.dart';

void main() {
  testWidgets('MediaCard renders with emoji and SpotifyLogoBadge in Classic and Glass', (tester) async {
    for (final style in [UiStyle.classic, UiStyle.auroraGlass]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeFor(style),
          home: const Scaffold(
            body: MediaCard(
              title: ';)',
              subtitle: '10 tracks • Spotify',
              badgeWidget: SpotifyLogoBadge(size: 22),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(';)'), findsOneWidget);
    }
  });

  testWidgets('MediaCard inside GridView with 0.78 aspect ratio', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(UiStyle.classic),
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.78,
              ),
              itemCount: 2,
              itemBuilder: (context, index) {
                return MediaCard(
                  title: index == 0 ? ';)' : '<3',
                  subtitle: '5 tracks • Spotify',
                  badgeWidget: const SpotifyLogoBadge(size: 22),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(';)'), findsOneWidget);
    expect(find.text('<3'), findsOneWidget);
  });
}
