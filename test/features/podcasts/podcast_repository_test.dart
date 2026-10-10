import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/podcasts/data/podcast_repository.dart';
import 'package:softify/features/podcasts/domain/podcast_failure.dart';

void main() {
  group('PodcastRepository failure mapping', () {
    test('PodcastException preserves typed failure message', () {
      const fail = EpisodeUnavailableFailure('Custom episode not found');
      const exc = PodcastException(fail);
      expect(exc.failure, isA<EpisodeUnavailableFailure>());
      expect(exc.failure.userMessage, 'Custom episode not found');
      expect(exc.toString(), contains('Custom episode not found'));
    });

    test('failure types contain user-friendly messages', () {
      expect(const InvalidPodcastLinkFailure().userMessage, isNotEmpty);
      expect(const EpisodeUnavailableFailure().userMessage, isNotEmpty);
      expect(const NetworkPodcastFailure().userMessage, isNotEmpty);
      expect(const PodcastRssNotFoundFailure().userMessage, isNotEmpty);
      expect(const GenericPodcastFailure().userMessage, isNotEmpty);
    });
  });
}
