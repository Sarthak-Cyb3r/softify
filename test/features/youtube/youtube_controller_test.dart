import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/youtube/domain/youtube_failure.dart';
import 'package:softify/features/youtube/presentation/youtube_controller.dart';

void main() {
  group('YoutubeController state transitions', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is YoutubeIdle', () {
      final state = container.read(youtubeControllerProvider);
      expect(state, isA<YoutubeIdle>());
    });

    test('empty input leaves state YoutubeIdle', () async {
      final notifier = container.read(youtubeControllerProvider.notifier);
      await notifier.submit('');
      expect(container.read(youtubeControllerProvider), isA<YoutubeIdle>());

      await notifier.submit('   ');
      expect(container.read(youtubeControllerProvider), isA<YoutubeIdle>());
    });

    test('invalid link input transitions to YoutubeErrorState with InvalidLinkFailure', () async {
      final notifier = container.read(youtubeControllerProvider.notifier);
      await notifier.submit('https://google.com');

      final state = container.read(youtubeControllerProvider);
      expect(state, isA<YoutubeErrorState>());
      final err = state as YoutubeErrorState;
      expect(err.failure, isA<InvalidLinkFailure>());
    });

    test('reset changes state back to YoutubeIdle', () async {
      final notifier = container.read(youtubeControllerProvider.notifier);
      await notifier.submit('not a valid url');
      expect(container.read(youtubeControllerProvider), isA<YoutubeErrorState>());

      notifier.reset();
      expect(container.read(youtubeControllerProvider), isA<YoutubeIdle>());
    });
  });
}
