import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/youtube/data/youtube_repository.dart';
import 'package:softify/features/youtube/domain/youtube_failure.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  group('YoutubeRepository failure mapping', () {
    late YoutubeRepository repo;

    setUp(() {
      repo = YoutubeRepository();
    });

    tearDown(() {
      repo.close();
    });

    test('maps VideoUnplayableException with live stream reason to LiveStreamFailure', () {
      final exc = VideoUnplayableException.liveStream(VideoId('abcdefghijk'));
      expect(exc.message.toLowerCase(), contains('live stream'));
    });

    test('exception mapping recognizes private videos', () {
      final exc = VideoUnavailableException.unavailable(VideoId('abcdefghijk'));
      expect(exc, isA<VideoUnavailableException>());
    });

    test('YoutubeException preserves typed failure message', () {
      const fail = LiveStreamFailure('Custom message');
      const exc = YoutubeException(fail);
      expect(exc.failure, isA<LiveStreamFailure>());
      expect(exc.failure.userMessage, 'Custom message');
      expect(exc.toString(), contains('Custom message'));
    });

    test('failure types contain user-friendly messages', () {
      expect(const InvalidLinkFailure().userMessage, isNotEmpty);
      expect(const VideoUnavailableFailure().userMessage, isNotEmpty);
      expect(const PrivateVideoFailure().userMessage, isNotEmpty);
      expect(const AgeRestrictedFailure().userMessage, isNotEmpty);
      expect(const RegionBlockedFailure().userMessage, isNotEmpty);
      expect(const LiveStreamFailure().userMessage, isNotEmpty);
      expect(const NetworkErrorFailure().userMessage, isNotEmpty);
    });
  });
}
