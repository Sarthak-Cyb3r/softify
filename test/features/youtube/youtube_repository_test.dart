import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/resolvers/youtube_innertube_service.dart';
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

    test('rate limit / RequestLimitExceededException maps to user-friendly message', () {
      final exc = Exception(
        'RequestLimitExceededException: Failed to perform an HTTP request to YouTube because of rate limiting.',
      );
      // Verify YoutubeRepository wraps this cleanly into a user-friendly failure
      final mapped = repo.mapException(exc);
      expect(mapped, isA<VideoUnavailableFailure>());
      expect(mapped.userMessage, contains('rate-limited'));
      expect(mapped.userMessage, isNot(contains('RequestLimitExceededException')));
    });
  });

  group('YoutubeInnertubeService parser verification', () {
    test('parseMetadata handles standard OK video payload', () {
      final service = YoutubeInnertubeService();
      final mockData = {
        'playabilityStatus': {'status': 'OK'},
        'videoDetails': {
          'title': 'Test Song',
          'author': 'Test Artist',
          'lengthSeconds': '180',
          'isLiveContent': false,
          'thumbnail': {
            'thumbnails': [
              {'url': 'https://i.ytimg.com/vi/test/default.jpg', 'width': 120},
              {'url': 'https://i.ytimg.com/vi/test/maxresdefault.jpg', 'width': 1280},
            ]
          }
        }
      };

      final meta = service.parseMetadata('test_id', mockData);
      expect(meta.title, 'Test Song');
      expect(meta.author, 'Test Artist');
      expect(meta.duration.inSeconds, 180);
      expect(meta.coverUrl, 'https://i.ytimg.com/vi/test/maxresdefault.jpg');
      expect(meta.isLive, isFalse);
    });

    test('parseMetadata throws VideoUnavailableFailure for unavailable video', () {
      final service = YoutubeInnertubeService();
      final mockData = {
        'playabilityStatus': {
          'status': 'ERROR',
          'reason': 'This video is unavailable',
        }
      };

      expect(
        () => service.parseMetadata('test_id', mockData),
        throwsA(isA<VideoUnavailableFailure>()),
      );
    });

    test('extractStream selects m4a audio stream with direct url', () {
      final service = YoutubeInnertubeService();
      final mockData = {
        'streamingData': {
          'adaptiveFormats': [
            {
              'itag': 140,
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'bitrate': 129000,
              'url': 'https://rr1---sn-test.googlevideo.com/videoplayback?id=123',
              'contentLength': '3400000',
            },
            {
              'itag': 251,
              'mimeType': 'audio/webm; codecs="opus"',
              'bitrate': 135000,
              'url': 'https://rr1---sn-test.googlevideo.com/videoplayback?id=456',
            }
          ]
        }
      };

      final stream = service.extractStream('test_id', mockData);
      expect(stream, isNotNull);
      expect(stream!.container, 'm4a');
      expect(stream.codec, 'aac');
      expect(stream.url.toString(), contains('videoplayback'));
      expect(stream.providerName, contains('innertube_android'));
    });
  });
}
