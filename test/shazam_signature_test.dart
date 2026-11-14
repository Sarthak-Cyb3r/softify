import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:softify/services/recognition/shazam_signature_generator.dart';
import 'package:softify/services/recognition/song_recognition_service.dart';

void main() {
  group('CRC32 Tests', () {
    test('computes standard IEEE 802.3 CRC32 for known test vector', () {
      final input = utf8.encode('123456789');
      final crc = Crc32.compute(input);
      expect(crc, equals(0xCBF43926));
    });

    test('computes CRC32 for empty byte array', () {
      final crc = Crc32.compute([]);
      expect(crc, equals(0));
    });

    test('computes CRC32 with custom range', () {
      final input = utf8.encode('prefix_123456789_suffix');
      final crc = Crc32.compute(input, 7, 16);
      expect(crc, equals(0xCBF43926));
    });
  });

  group('ShazamSignatureGenerator Input Validation', () {
    test('throws ArgumentError on empty PCM buffer', () {
      expect(
        () => ShazamSignatureGenerator.fromI16(Uint8List(0)),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError on odd-length PCM buffer', () {
      expect(
        () => ShazamSignatureGenerator.fromI16(Uint8List(3)),
        throwsArgumentError,
      );
    });
  });

  group('ShazamSignatureGenerator Binary Packing & Decoding', () {
    test('generates valid Data URI format for silence buffer', () {
      // 1 second of 16kHz 16-bit mono silence (16000 samples = 32000 bytes)
      final pcmBytes = Uint8List(32000);
      final sigUri = ShazamSignatureGenerator.fromI16(pcmBytes);

      expect(sigUri.startsWith('data:audio/vnd.shazam.sig;base64,'), isTrue);

      final decoded = ShazamSignatureGenerator.decodeSignature(sigUri);
      expect(decoded, isNotNull);
      expect(decoded!.magic1, equals(0xcafe2807));
      expect(decoded.magic2, equals(0x94119c00));
      expect(decoded.sampleRate, equals(16000));
      expect(decoded.totalPeaks, equals(0)); // Silence has 0 peaks
    });

    test('supports custom/legacy magic header 0xcafe2580', () {
      final pcmBytes = Uint8List(16000);
      final sigUri = ShazamSignatureGenerator.fromI16(
        pcmBytes,
        magicHeader: ShazamSignatureGenerator.kLegacyMagicHeader,
      );

      final decoded = ShazamSignatureGenerator.decodeSignature(sigUri);
      expect(decoded, isNotNull);
      expect(decoded!.magic1, equals(0xcafe2580));
    });
  });

  group('ShazamSignatureGenerator Spectral Peak Extraction', () {
    /// Generates 16-bit signed PCM mono audio for a given frequency in Hz.
    Uint8List generateSinePcm(
      List<double> frequencies,
      double durationSeconds, {
      double amplitude = 18000.0,
    }) {
      const sampleRate = 16000;
      final numSamples = (durationSeconds * sampleRate).toInt();
      final byteData = ByteData(numSamples * 2);

      for (int i = 0; i < numSamples; i++) {
        final t = i / sampleRate;
        double sample = 0;
        for (final freq in frequencies) {
          sample += amplitude * math.sin(2.0 * math.pi * freq * t);
        }
        final clamped = sample.clamp(-32768.0, 32767.0).toInt();
        byteData.setInt16(i * 2, clamped, Endian.little);
      }

      return byteData.buffer.asUint8List();
    }

    test('extracts peaks across the 4 frequency bands', () {
      // 4 distinct tones within each of the 4 bands:
      // Band 0: 250 - 520 Hz -> 400 Hz
      // Band 1: 520 - 1450 Hz -> 900 Hz
      // Band 2: 1450 - 3500 Hz -> 2400 Hz
      // Band 3: 3500 - 5500 Hz -> 4400 Hz
      final pcm = generateSinePcm(
        [400.0, 900.0, 2400.0, 4400.0],
        3.5, // 3.5 seconds
      );

      final sigUri = ShazamSignatureGenerator.fromI16(pcm);
      expect(sigUri.startsWith('data:audio/vnd.shazam.sig;base64,'), isTrue);

      final decoded = ShazamSignatureGenerator.decodeSignature(sigUri);
      expect(decoded, isNotNull);
      expect(decoded!.magic1, equals(0xcafe2807));
      expect(decoded.totalPeaks, greaterThan(0));

      // Check that peaks were extracted into all 4 bands
      expect(decoded.bandPeaks.containsKey(0), isTrue);
      expect(decoded.bandPeaks.containsKey(1), isTrue);
      expect(decoded.bandPeaks.containsKey(2), isTrue);
      expect(decoded.bandPeaks.containsKey(3), isTrue);

      // Verify peak frequencies align with the input frequencies
      final band0Peaks = decoded.bandPeaks[0]!;
      expect(band0Peaks, isNotEmpty);
      final hasNear400 = band0Peaks.any((p) => (p.frequencyHz - 400).abs() < 50);
      expect(hasNear400, isTrue);

      final band1Peaks = decoded.bandPeaks[1]!;
      expect(band1Peaks, isNotEmpty);
      final hasNear900 = band1Peaks.any((p) => (p.frequencyHz - 900).abs() < 50);
      expect(hasNear900, isTrue);

      final band2Peaks = decoded.bandPeaks[2]!;
      expect(band2Peaks, isNotEmpty);
      final hasNear2400 = band2Peaks.any((p) => (p.frequencyHz - 2400).abs() < 60);
      expect(hasNear2400, isTrue);

      final band3Peaks = decoded.bandPeaks[3]!;
      expect(band3Peaks, isNotEmpty);
      final hasNear4400 = band3Peaks.any((p) => (p.frequencyHz - 4400).abs() < 80);
      expect(hasNear4400, isTrue);
    });

    test('delta encoding with >255 fftPassNumber jump formats 0xFF marker', () {
      // Create 2 bursts separated by silence to ensure FFT pass jump > 255
      final pcm1 = generateSinePcm([1000.0], 1.0);
      final silence = Uint8List(16000 * 2 * 4); // 4 seconds of silence (~500 FFT passes)
      final pcm2 = generateSinePcm([1000.0], 1.0);

      final combined = BytesBuilder();
      combined.add(pcm1);
      combined.add(silence);
      combined.add(pcm2);

      final sigUri = ShazamSignatureGenerator.fromI16(combined.toBytes());
      final decoded = ShazamSignatureGenerator.decodeSignature(sigUri);

      expect(decoded, isNotNull);
      expect(decoded!.totalPeaks, greaterThan(1));
    });
  });

  group('SongRecognitionService Tests', () {
    const mockShazamSuccessResponse = '''
{
  "matches": [
    {
      "id": "1516142137",
      "offset": 42.5,
      "timeskew": 0.001,
      "frequencyskew": 0.0
    }
  ],
  "tagid": "D2C8A9B1-E374-4C23-8812-7A9128073D42",
  "track": {
    "key": "1516142137",
    "title": "Blinding Lights",
    "subtitle": "The Weeknd",
    "url": "https://www.shazam.com/track/1516142137/blinding-lights",
    "isrc": "USUG11904206",
    "genres": {
      "primary": "Pop"
    },
    "images": {
      "coverart": "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/coverart.jpg",
      "coverarthq": "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/coverarthq.jpg"
    },
    "sections": [
      {
        "type": "SONG",
        "metadata": [
          {"title": "Album", "text": "After Hours"},
          {"title": "Label", "text": "XO / Republic Records"},
          {"title": "Released", "text": "2020"}
        ]
      },
      {
        "type": "LYRICS",
        "text": [
          "Yeah",
          "I've been tryna call",
          "I've been on my own for long enough"
        ]
      }
    ],
    "hub": {
      "options": [
        {
          "providername": "applemusic",
          "actions": [
            {"uri": "https://music.apple.com/us/album/blinding-lights/1499378108?i=1499378607"}
          ]
        },
        {
          "type": "video",
          "actions": [
            {"uri": "https://www.youtube.com/watch?v=4NRXx6U8ABQ"}
          ]
        }
      ],
      "providers": [
        {
          "caption": "Open in Spotify",
          "actions": [
            {"uri": "spotify:track:0VjIjW4GlUZAMYd2vXMi3b"}
          ]
        }
      ]
    }
  }
}
''';

    test('successfully resolves track, artist, album, and catalog IDs', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, equals('amp.shazam.com'));
        expect(request.url.path, contains('/discovery/v5/en/US/android/-/tag/'));
        expect(request.headers['User-Agent'], isNotEmpty);
        expect(request.headers['Content-Type'], equals('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['signature']['uri'], startsWith('data:audio/vnd.shazam.sig;base64,'));

        return http.Response(mockShazamSuccessResponse, 200);
      });

      final service = SongRecognitionService(client: mockClient);
      final pcm = Uint8List(32000);
      final result = await service.recognizePcm(pcm);

      expect(result, isNotNull);
      expect(result!.trackId, equals('1516142137'));
      expect(result.title, equals('Blinding Lights'));
      expect(result.artist, equals('The Weeknd'));
      expect(result.album, equals('After Hours'));
      expect(result.label, equals('XO / Republic Records'));
      expect(result.releaseDate, equals('2020'));
      expect(result.genre, equals('Pop'));
      expect(result.isrc, equals('USUG11904206'));
      expect(result.coverArtUrl, contains('coverart.jpg'));
      expect(result.coverArtHqUrl, contains('coverarthq.jpg'));
      expect(result.lyrics?.first, equals('Yeah'));
      expect(result.appleMusicUrl, contains('music.apple.com'));
      expect(result.spotifyUrl, equals('spotify:track:0VjIjW4GlUZAMYd2vXMi3b'));
      expect(result.youtubeVideoId, equals('4NRXx6U8ABQ'));
      expect(result.offsetSeconds, equals(42.5));

      // Test conversion to Softify's Track domain entity
      final track = result.toTrack();
      expect(track.id, equals('1516142137'));
      expect(track.sourceId, equals('4NRXx6U8ABQ'));
      expect(track.title, equals('Blinding Lights'));
      expect(track.artist, equals('The Weeknd'));
      expect(track.album, equals('After Hours'));
      expect(track.coverUrl, contains('coverarthq.jpg'));
      expect(track.matchConfidence, equals(1.0));
    });

    test('returns null when no track matches', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"matches":[],"tagid":"empty-tag"}', 200);
      });

      final service = SongRecognitionService(client: mockClient);
      final result = await service.recognizeSignature(
        'data:audio/vnd.shazam.sig;base64,mock',
      );
      expect(result, isNull);
    });

    test('returns null on HTTP 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = SongRecognitionService(client: mockClient);
      final result = await service.recognizeSignature(
        'data:audio/vnd.shazam.sig;base64,mock',
      );
      expect(result, isNull);
    });

    test('caches recognized results to prevent redundant network hits', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(mockShazamSuccessResponse, 200);
      });

      final service = SongRecognitionService(client: mockClient);
      const testSig = 'data:audio/vnd.shazam.sig;base64,cached_test_sig';

      final res1 = await service.recognizeSignature(testSig);
      final res2 = await service.recognizeSignature(testSig);

      expect(res1?.title, equals('Blinding Lights'));
      expect(res2?.title, equals('Blinding Lights'));
      expect(requestCount, equals(1)); // Only hit network once

      // After clearing cache, hits network again
      service.clearCache();
      await service.recognizeSignature(testSig);
      expect(requestCount, equals(2));
    });

    test('throws RecognitionException on HTTP 500 error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = SongRecognitionService(client: mockClient);
      expect(
        () => service.recognizeSignature('data:audio/vnd.shazam.sig;base64,error'),
        throwsA(isA<RecognitionException>()),
      );
    });
  });
}
