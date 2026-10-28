import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/presentation/widgets/spotify_logo_badge.dart';

void main() {
  testWidgets('SpotifyLogoBadge renders properly at various sizes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SpotifyLogoBadge(size: 16),
              SpotifyLogoBadge(size: 24),
              SpotifyLogoBadge(size: 48, hasShadow: false),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SpotifyLogoBadge), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(SpotifyLogoBadge),
        matching: find.byType(CustomPaint),
      ),
      findsNWidgets(3),
    );
  });
}
