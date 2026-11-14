import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/resolvers/youtube_stream_resolver.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/screens/app_scaffold.dart';

void main() {
  group('Keyboard Shortcuts Conflict Resolution', () {
    testWidgets('SoftifyAction is disabled when an EditableText has focus', (tester) async {
      bool actionExecuted = false;
      final action = SoftifyAction((type) {
        actionExecuted = true;
      });

      final controller = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Actions(
              actions: {
                SoftifyIntent: action,
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );

      // 1. Without focus, skipNext shortcut intent is enabled
      const skipNextIntent = SoftifyIntent(SoftifyShortcutType.skipNext);
      expect(action.isEnabled(skipNextIntent), isTrue);

      // 2. Request focus on TextField (EditableText)
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);

      // 3. While typing in TextField, single-key shortcuts like 'k' (skipNext) MUST be disabled!
      expect(action.isEnabled(skipNextIntent), isFalse);

      const skipPrevIntent = SoftifyIntent(SoftifyShortcutType.skipPrevious);
      expect(action.isEnabled(skipPrevIntent), isFalse);

      const muteIntent = SoftifyIntent(SoftifyShortcutType.toggleMute);
      expect(action.isEnabled(muteIntent), isFalse);

      // 4. Escape has allowInTextInput: true, so it remains enabled to allow unfocusing/closing
      const escapeIntent = SoftifyIntent(SoftifyShortcutType.escape, allowInTextInput: true);
      expect(action.isEnabled(escapeIntent), isTrue);

      // 5. Unfocus text input -> shortcuts re-enable
      focusNode.unfocus();
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isFalse);
      expect(action.isEnabled(skipNextIntent), isTrue);

      // 6. Invoke triggers callback when enabled
      action.invoke(skipNextIntent);
      expect(actionExecuted, isTrue);
    });
  });

  group('Stream Resolver Matching Accuracy Guard', () {
    test('YoutubeStreamResolver.hasTitleMatch strictly matches identical and genuine titles', () {
      expect(YoutubeStreamResolver.hasTitleMatch('Starboy', 'Starboy (Official Audio)'), isTrue);
      expect(YoutubeStreamResolver.hasTitleMatch('Die With A Smile', 'Lady Gaga, Bruno Mars - Die With A Smile (Official Video)'), isTrue);
      expect(YoutubeStreamResolver.hasTitleMatch('Blinding Lights', 'The Weeknd - Blinding Lights'), isTrue);

      // Rejects short subphrases that are different tracks
      expect(YoutubeStreamResolver.hasTitleMatch('Starboy', 'Star'), isFalse);
      expect(YoutubeStreamResolver.hasTitleMatch('One', 'Only One'), isFalse);
      expect(YoutubeStreamResolver.hasTitleMatch('In The End', 'The End'), isFalse);
    });

    test('YoutubeStreamResolver.hasArtistMatch handles artist tokens accurately and rejects unrelated artists', () {
      expect(YoutubeStreamResolver.hasArtistMatch('The Weeknd', 'The Weeknd'), isTrue);
      expect(YoutubeStreamResolver.hasArtistMatch('The Weeknd', 'The Weeknd - Topic'), isTrue);
      expect(YoutubeStreamResolver.hasArtistMatch('Lady Gaga & Bruno Mars', 'Lady Gaga, Bruno Mars'), isTrue);
      expect(YoutubeStreamResolver.hasArtistMatch('Arijit Singh', 'Arijit Singh, Mithoon'), isTrue);

      // Rejects completely unrelated artists
      expect(YoutubeStreamResolver.hasArtistMatch('The Weeknd', 'Arijit Singh'), isFalse);
      expect(YoutubeStreamResolver.hasArtistMatch('Taylor Swift', 'Kanye West'), isFalse);
      expect(YoutubeStreamResolver.hasArtistMatch('Billie Eilish', 'Finneas O\'Connell'), isFalse);
    });

    test('YoutubeStreamResolver.isDisqualifiedVariant filters out unwanted remixes, covers, and lofi cuts', () {
      expect(YoutubeStreamResolver.isDisqualifiedVariant('Starboy', 'Starboy (Remix)'), isTrue);
      expect(YoutubeStreamResolver.isDisqualifiedVariant('Starboy', 'Starboy - Lofi version'), isTrue);
      expect(YoutubeStreamResolver.isDisqualifiedVariant('Starboy', 'Starboy (Acoustic Cover)'), isTrue);
      expect(YoutubeStreamResolver.isDisqualifiedVariant('Starboy', 'Starboy (Slowed + Reverb)'), isTrue);

      // Allows legitimate studio tracks
      expect(YoutubeStreamResolver.isDisqualifiedVariant('Starboy', 'Starboy (Official Music Video)'), isFalse);
    });

    test('Resolvers accurately handle Unicode non-breaking spaces (\\u00A0) in metadata without token squashing', () {
      const spotifyArtistWithNbsp = 'Himesh Reshammiya,\u00A0Vineet Singh,\u00A0Aaman Trikha';
      const cleanArtist = 'Himesh Reshammiya, Vineet Singh, Aaman Trikha';
      expect(YoutubeStreamResolver.hasArtistMatch(spotifyArtistWithNbsp, cleanArtist), isTrue);

      const dualArtistNbsp = 'Blackway,\u00A0Black Caviar';
      expect(YoutubeStreamResolver.hasArtistMatch(dualArtistNbsp, 'Blackway & Black Caviar'), isTrue);

      const titleWithNbsp = "What's\u00A0Up\u00A0Danger";
      expect(YoutubeStreamResolver.hasTitleMatch(titleWithNbsp, "What's Up Danger"), isTrue);
    });
  });
}
