import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/player/softify_audio_handler.dart';
import 'package:softify/features/podcasts/domain/podcast_failure.dart';
import 'package:softify/features/podcasts/presentation/podcast_controller.dart';
import 'package:softify/presentation/providers/player_providers.dart';

class DummyAudioHandler extends Fake implements SoftifyAudioHandler {
  @override
  Stream<Duration> get positionStream => Stream.value(Duration.zero);

  @override
  void setTrackSource(String source) {}
}

void main() {
  group('PodcastController state transitions', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          audioHandlerProvider.overrideWithValue(DummyAudioHandler()),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('initial state is PodcastIdle', () {
      final state = container.read(podcastControllerProvider);
      expect(state, isA<PodcastIdle>());
    });

    test('empty input leaves state PodcastIdle', () async {
      final notifier = container.read(podcastControllerProvider.notifier);
      await notifier.submit('');
      expect(container.read(podcastControllerProvider), isA<PodcastIdle>());

      await notifier.submit('   ');
      expect(container.read(podcastControllerProvider), isA<PodcastIdle>());
    });

    test('invalid link input transitions to PodcastErrorState with InvalidPodcastLinkFailure', () async {
      final notifier = container.read(podcastControllerProvider.notifier);
      await notifier.submit('https://google.com');

      final state = container.read(podcastControllerProvider);
      expect(state, isA<PodcastErrorState>());
      final err = state as PodcastErrorState;
      expect(err.failure, isA<InvalidPodcastLinkFailure>());
    });

    test('spotify show link input loads show or reports failure', () async {
      final notifier = container.read(podcastControllerProvider.notifier);
      await notifier.submit('https://open.spotify.com/show/7cpFspd2FfvM45014vXfUq');

      final state = container.read(podcastControllerProvider);
      expect(state, isA<PodcastErrorState>());
      final err = state as PodcastErrorState;
      expect(err.failure, isA<EpisodeUnavailableFailure>());
    });

    test('reset changes state back to PodcastIdle', () async {
      final notifier = container.read(podcastControllerProvider.notifier);
      await notifier.submit('https://notapodcastlink.com');
      expect(container.read(podcastControllerProvider), isA<PodcastErrorState>());

      notifier.reset();
      expect(container.read(podcastControllerProvider), isA<PodcastIdle>());
    });
  });
}
