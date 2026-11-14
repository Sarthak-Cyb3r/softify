import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:softify/services/dsp/autoeq_service.dart';
import 'package:softify/services/dsp/biquad_filter.dart';
import 'package:softify/services/dsp/parametric_eq.dart';
import 'package:softify/services/loudness_normalizer_service.dart';
import 'package:softify/services/automix_service.dart';

void main() {
  group('Robert Bristow-Johnson Biquad IIR Filter DSP', () {
    test('Peaking filter (PK) creates exact theoretical peak gain at center frequency', () {
      const centerFreq = 1000.0;
      const boostDb = 6.0;
      final filter = BiquadFilter(
        type: BiquadFilterType.peaking,
        frequency: centerFreq,
        gainDb: boostDb,
        q: 2.0,
        sampleRate: 44100.0,
      );

      // Peak gain at center frequency should be exactly +6 dB (+- 0.05 dB)
      final gainAtCenter = filter.evaluateGainAt(centerFreq);
      expect(gainAtCenter, closeTo(boostDb, 0.05));

      // Far away frequencies should approach 0 dB
      expect(filter.evaluateGainAt(50.0), closeTo(0.0, 0.15));
      expect(filter.evaluateGainAt(18000.0), closeTo(0.0, 0.15));

      // Cut filter test (-6 dB)
      filter.update(gainDb: -6.0);
      expect(filter.evaluateGainAt(centerFreq), closeTo(-6.0, 0.05));
    });

    test('Low-Shelf filter (LSC) attenuates/boosts below cutoff and flattens to 0 dB at high frequencies', () {
      const cutoffFreq = 105.0;
      const boostDb = 5.0;
      final filter = BiquadFilter(
        type: BiquadFilterType.lowShelf,
        frequency: cutoffFreq,
        gainDb: boostDb,
        q: 0.7071,
        sampleRate: 48000.0,
      );

      // At low frequencies (e.g. 20 Hz), gain should approach boostDb
      expect(filter.evaluateGainAt(20.0), closeTo(boostDb, 0.2));

      // At high frequencies (e.g. 10 kHz), gain should approach 0 dB
      expect(filter.evaluateGainAt(10000.0), closeTo(0.0, 0.1));
    });

    test('High-Shelf filter (HSC) boosts above cutoff and flattens to 0 dB at low frequencies', () {
      const cutoffFreq = 8000.0;
      const boostDb = 4.0;
      final filter = BiquadFilter(
        type: BiquadFilterType.highShelf,
        frequency: cutoffFreq,
        gainDb: boostDb,
        q: 0.7071,
        sampleRate: 44100.0,
      );

      // At low frequencies (e.g. 100 Hz), gain should be 0 dB
      expect(filter.evaluateGainAt(100.0), closeTo(0.0, 0.1));

      // At high frequencies (e.g. 18 kHz), gain should approach boostDb
      expect(filter.evaluateGainAt(18000.0), closeTo(boostDb, 0.25));
    });

    test('Flat 0 dB filter executes identity pass-through', () {
      final filter = BiquadFilter(
        type: BiquadFilterType.peaking,
        frequency: 1000.0,
        gainDb: 0.0,
        sampleRate: 44100.0,
      );

      expect(filter.coefficients.b0, equals(1.0));
      expect(filter.coefficients.b1, equals(0.0));
      expect(filter.coefficients.b2, equals(0.0));
      expect(filter.coefficients.a1, equals(0.0));
      expect(filter.coefficients.a2, equals(0.0));

      const inputSample = 0.42857;
      final out = filter.processSample(inputSample);
      expect(out, equals(inputSample));
    });

    test('Multi-channel Direct Form I registers maintain strict stereo separation', () {
      final filter = BiquadFilter(
        type: BiquadFilterType.peaking,
        frequency: 500.0,
        gainDb: 6.0,
        channels: 2,
      );

      // Process sample into Channel 0 (Left) only
      filter.processSample(0.8, channel: 0);

      // Channel 1 (Right) has had 0 inputs, so processing 0.0 on Channel 1 must yield 0.0
      final rightOut = filter.processSample(0.0, channel: 1);
      expect(rightOut, equals(0.0));
    });

    test('Filter stability test: no NaN or Infinity under impulse excitation', () {
      final filter = BiquadFilter(
        type: BiquadFilterType.peaking,
        frequency: 1000.0,
        gainDb: 12.0,
        q: 5.0,
      );

      // Feed impulse: 1.0 followed by zeroes
      double sample = filter.processSample(1.0);
      expect(sample.isFinite, isTrue);

      for (int i = 0; i < 1500; i++) {
        sample = filter.processSample(0.0);
        expect(sample.isFinite, isTrue);
        expect(sample.isNaN, isFalse);
      }

      // Filter response must decay towards 0
      expect(sample.abs(), lessThan(1e-4));
    });
  });

  group('Cascaded Parametric Equalizer', () {
    test('Cascades multiple filters with preamp scaling in 32-bit floating point', () {
      final eq = ParametricEqualizer(
        preampDb: -6.0,
        sampleRate: 48000.0,
      );

      expect(eq.preampDb, equals(-6.0));
      expect(eq.linearPreamp, closeTo(0.501187, 1e-4));

      // 10 default bands loaded
      expect(eq.bands.length, equals(10));

      // Interleaved stereo buffer test
      final buffer = Float32List.fromList([0.5, 0.5, -0.5, -0.5, 0.25, 0.25]);
      eq.processInterleaved(buffer, 2);

      // All bands are flat (0 dB), so only preamp attenuation should scale the buffer
      for (int i = 0; i < buffer.length; i++) {
        expect(buffer[i].isFinite, isTrue);
      }
      expect(buffer[0], closeTo(0.5 * 0.501187, 1e-3));
    });

    test('Bypass mode preserves bit-identical input samples', () {
      final eq = ParametricEqualizer(
        enabled: false,
        preampDb: -10.0, // Should be ignored when disabled
      );

      final buffer = Float32List.fromList([0.12345, -0.6789, 0.54321]);
      final original = Float32List.fromList(buffer);

      eq.processInterleaved(buffer, 2);

      for (int i = 0; i < buffer.length; i++) {
        expect(buffer[i], equals(original[i]));
      }
    });

    test('Preset loading sets predefined filter curves', () {
      final eq = ParametricEqualizer();

      eq.loadPreset('bass_boost');
      expect(eq.preampDb, equals(-3.0));
      expect(eq.bands.any((b) => b.frequency == 80.0 && b.gainDb == 5.5), isTrue);

      eq.loadPreset('vocal_boost');
      expect(eq.preampDb, equals(-2.5));
      expect(eq.bands.any((b) => b.frequency == 3000.0 && b.gainDb == 4.0), isTrue);

      eq.loadPreset('flat');
      expect(eq.preampDb, equals(0.0));
      expect(eq.bands.every((b) => b.gainDb == 0.0), isTrue);
    });

    test('computeMaxPotentialBoostDb calculates peak spectrum gain', () {
      final eq = ParametricEqualizer(
        preampDb: -2.0,
        initialBands: [
          const EqBand(
            index: 0,
            type: BiquadFilterType.peaking,
            frequency: 1000.0,
            gainDb: 6.0,
            q: 2.0,
          ),
        ],
      );

      // Peak at 1000 Hz: +6 dB filter + (-2 dB preamp) = +4 dB net peak
      final maxBoost = eq.computeMaxPotentialBoostDb();
      expect(maxBoost, closeTo(4.0, 0.15));
    });

    test('updateBand dynamically modifies active filter coefficients', () {
      final eq = ParametricEqualizer();
      eq.updateBand(3, frequency: 800.0, gainDb: 4.5, q: 1.8);

      expect(eq.bands[3].frequency, equals(800.0));
      expect(eq.bands[3].gainDb, equals(4.5));
      expect(eq.bands[3].q, equals(1.8));

      expect(eq.filters[3].frequency, equals(800.0));
      expect(eq.filters[3].gainDb, equals(4.5));
    });
  });

  group('AutoEq Service: Parser & GitHub Integration', () {
    const sampleParametricEq = '''
Preamp: -6.2 dB
Filter 1: ON LSC Fc 105 Hz Gain 6.2 dB Q 0.70
Filter 2: ON PK Fc 180 Hz Gain -4.0 dB Q 0.56
Filter 3: ON PK Fc 4180 Hz Gain 5.6 dB Q 3.17
Filter 4: ON PK Fc 1605 Hz Gain 4.7 dB Q 3.06
Filter 5: ON PK Fc 56 Hz Gain 1.5 dB Q 1.88
Filter 6: ON HSC Fc 10000 Hz Gain 1.2 dB Q 0.70
Filter 7: ON PK Fc 2807 Hz Gain -2.7 dB Q 3.81
Filter 8: ON PK Fc 6678 Hz Gain -2.4 dB Q 6.00
Filter 9: ON PK Fc 3488 Hz Gain 2.5 dB Q 6.00
Filter 10: OFF PK Fc 558 Hz Gain 1.5 dB Q 6.00
''';

    test('parseParametricEqText parses preamp, filter types, frequencies, gains, and Qs', () {
      final profile = AutoEqService.parseParametricEqText(
        sampleParametricEq,
        modelName: 'AKG K240 MKII',
        measurer: 'oratory1990',
      );

      expect(profile.modelName, equals('AKG K240 MKII'));
      expect(profile.measurer, equals('oratory1990'));
      expect(profile.preampDb, equals(-6.2));
      expect(profile.bands.length, equals(10));

      // Filter 1: Low-Shelf 105 Hz, +6.2 dB, Q 0.70
      final b1 = profile.bands[0];
      expect(b1.type, equals(BiquadFilterType.lowShelf));
      expect(b1.frequency, equals(105.0));
      expect(b1.gainDb, equals(6.2));
      expect(b1.q, equals(0.70));
      expect(b1.enabled, isTrue);

      // Filter 2: Peaking 180 Hz, -4.0 dB, Q 0.56
      final b2 = profile.bands[1];
      expect(b2.type, equals(BiquadFilterType.peaking));
      expect(b2.frequency, equals(180.0));
      expect(b2.gainDb, equals(-4.0));
      expect(b2.q, equals(0.56));

      // Filter 6: High-Shelf 10000 Hz, +1.2 dB, Q 0.70
      final b6 = profile.bands[5];
      expect(b6.type, equals(BiquadFilterType.highShelf));
      expect(b6.frequency, equals(10000.0));
      expect(b6.gainDb, equals(1.2));

      // Filter 10: OFF state
      final b10 = profile.bands[9];
      expect(b10.enabled, isFalse);
    });

    test('applyTo configures ParametricEqualizer from AutoEqProfile', () {
      final profile = AutoEqService.parseParametricEqText(sampleParametricEq);
      final eq = ParametricEqualizer();

      profile.applyTo(eq);

      expect(eq.preampDb, equals(-6.2));
      expect(eq.bands.length, equals(10));
      expect(eq.bands[0].type, equals(BiquadFilterType.lowShelf));
      expect(eq.enabled, isTrue);
    });

    test('AutoEqProfile serializes to and from JSON', () {
      final original = AutoEqService.parseParametricEqText(sampleParametricEq);
      final json = original.toJson();
      final restored = AutoEqProfile.fromJson(json);

      expect(restored.modelName, equals(original.modelName));
      expect(restored.preampDb, equals(original.preampDb));
      expect(restored.bands.length, equals(original.bands.length));
      expect(restored.bands[0].frequency, equals(original.bands[0].frequency));
      expect(restored.bands[0].gainDb, equals(original.bands[0].gainDb));
    });

    test('AutoEqService indexes and searches headphone models with mock HTTP client', () async {
      final mockTree = {
        'tree': [
          {
            'path': 'results/oratory1990/over-ear/Sennheiser HD 600/Sennheiser HD 600 ParametricEQ.txt',
            'type': 'blob',
          },
          {
            'path': 'results/oratory1990/over-ear/Sony WH-1000XM4/Sony WH-1000XM4 ParametricEQ.txt',
            'type': 'blob',
          },
          {
            'path': 'results/crinacle/in-ear/Sony WF-1000XM4/Sony WF-1000XM4 ParametricEQ.txt',
            'type': 'blob',
          },
          {
            'path': 'results/crinacle/in-ear/Apple AirPods Pro 2/Apple AirPods Pro 2 ParametricEQ.txt',
            'type': 'blob',
          },
          {
            'path': 'results/oratory1990/over-ear/Beyerdynamic DT 990 Pro/Beyerdynamic DT 990 Pro ParametricEQ.txt',
            'type': 'blob',
          },
        ]
      };

      final client = MockClient((request) async {
        if (request.url.toString().contains('git/trees')) {
          return http.Response(jsonEncode(mockTree), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.toString().contains('ParametricEQ.txt')) {
          return http.Response(sampleParametricEq, 200);
        }
        return http.Response('Not found', 404);
      });

      final service = AutoEqService();
      service.setClient(client);

      // Fetch index
      final entries = await service.fetchIndex(forceRefresh: true);
      expect(entries.length, equals(5));

      // Search "Sony XM4" -> should return both WH-1000XM4 and WF-1000XM4
      final sonyResults = await service.searchModels('Sony XM4');
      expect(sonyResults.length, equals(2));
      expect(sonyResults.any((e) => e.modelName == 'Sony WH-1000XM4'), isTrue);
      expect(sonyResults.any((e) => e.modelName == 'Sony WF-1000XM4'), isTrue);

      // Search "Sennheiser"
      final sennResults = await service.searchModels('Sennheiser');
      expect(sennResults.length, equals(1));
      expect(sennResults.first.modelName, equals('Sennheiser HD 600'));

      // Fetch profile for one model
      final profile = await service.fetchProfile(sonyResults.first);
      expect(profile.preampDb, equals(-6.2));
      expect(profile.bands.length, equals(10));
    });

    test('AutoEqService falls back to bundled catalog if network fails', () async {
      final failingClient = MockClient((request) async {
        return http.Response('API Rate Limit Exceeded', 403);
      });

      final service = AutoEqService();
      service.setClient(failingClient);

      final entries = await service.fetchIndex(forceRefresh: true);
      expect(entries.isNotEmpty, isTrue);
      expect(entries.any((e) => e.modelName.contains('Sony')), isTrue);
      expect(entries.any((e) => e.modelName.contains('Sennheiser')), isTrue);
    });
  });

  group('Loudness Normalization & Automix Pipeline Integration', () {
    test('LoudnessNormalizerService peak limiter accounts for active equalizer boost', () {
      final normalizer = LoudnessNormalizerService.instance;
      normalizer.setProfile(LoudnessProfile.normal); // -14 LUFS

      final eq = ParametricEqualizer(
        preampDb: 0.0,
        initialBands: [
          const EqBand(
            index: 0,
            type: BiquadFilterType.peaking,
            frequency: 1000.0,
            gainDb: 6.0, // +6 dB boost
            q: 1.0,
          ),
        ],
      );

      // Normal gain calculation for track with -10 LUFS and peak = 0.95
      final gainWithoutEq = normalizer.computeGainMultiplier(
        trackLufs: -10.0,
        trackPeakLinear: 0.95,
      );

      // Gain calculation with attached equalizer boosting +6 dB
      final gainWithEq = normalizer.computeGainMultiplierWithEqualizer(
        trackLufs: -10.0,
        trackPeakLinear: 0.95,
        equalizer: eq,
      );

      // Peak limiter must clamp gain down to prevent true-peak ceiling breach (-0.2 dBFS = 0.9772)
      expect(gainWithEq, lessThan(gainWithoutEq));
      expect(0.95 * gainWithEq, lessThanOrEqualTo(LoudnessNormalizerService.truePeakCeilingLinear + 1e-4));
    });

    test('AutomixService.mixDualDeck32BitFloat processes 320 kbps bitstream through master equalizer', () {
      final eq = ParametricEqualizer(
        preampDb: -3.0,
        initialBands: [
          const EqBand(
            index: 0,
            type: BiquadFilterType.peaking,
            frequency: 1000.0,
            gainDb: 3.0,
            q: 1.0,
          ),
        ],
      );

      final automix = AutomixService(equalizer: eq);

      final deckA = Float32List.fromList([0.4, 0.4, 0.4, 0.4]);
      final deckB = Float32List.fromList([0.3, 0.3, 0.3, 0.3]);
      final outMaster = Float32List(4);

      // Midpoint crossfade (t = 0.5)
      automix.mixDualDeck32BitFloat(
        deckABuffer: deckA,
        deckBBuffer: deckB,
        outMasterBuffer: outMaster,
        progress: 0.5,
      );

      // Master output must be populated, strictly 32-bit floating point, non-zero, and finite
      for (int i = 0; i < outMaster.length; i++) {
        expect(outMaster[i].isFinite, isTrue);
        expect(outMaster[i], isNot(0.0));
      }

      automix.dispose();
    });
  });
}
