import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Pure Dart implementation of the Shazam / Vibra acoustic fingerprinting engine.
///
/// Ports the Shazam signature algorithm reverse-engineered in SongRec / Metrolist:
/// - 16 kHz Mono 16-bit PCM input buffer handling.
/// - 2048-point Fast Fourier Transform (FFT) with rounded Hanning window:
///   `w[i] = 0.5 * (1 - cos(2 * pi * (i + 1) / 2049))`
/// - Landmark spectral peak extraction across 4 frequency bands:
///   - Band 0: 250 Hz - 520 Hz
///   - Band 1: 520 Hz - 1450 Hz
///   - Band 2: 1450 Hz - 3500 Hz
///   - Band 3: 3500 Hz - 5500 Hz
/// - Binary signature packing with CRC32 checksum, magic header `0xcafe2807`,
///   and base64 Data URI formatting (`data:audio/vnd.shazam.sig;base64,...`).
class ShazamSignatureGenerator {
  static const int kDefaultMagicHeader = 0xcafe2807;
  static const int kLegacyMagicHeader = 0xcafe2580;
  static const int kMagicHeader2 = 0x94119c00;

  static const int kSampleRate = 16000;
  static const int kFftSize = 2048;
  static const int kFftOutputSize = kFftSize ~/ 2 + 1; // 1025
  static const int kMaxPeaks = 255;
  static const double kMaxTimeSeconds = 12.0;
  static const int kRingBufSize = 256;

  static const String kDataUriPrefix = 'data:audio/vnd.shazam.sig;base64,';

  // 4 Frequency bands
  static const int kBand250To520 = 0;
  static const int kBand520To1450 = 1;
  static const int kBand1450To3500 = 2;
  static const int kBand3500To5500 = 3;

  /// Precomputed 2048-point Hanning window:
  /// `w[i] = 0.5 * (1.0 - cos(2 * pi * (i + 1) / 2049))` for i = 0..2047.
  static final Float64List _hanning = Float64List.fromList(
    List.generate(
      kFftSize,
      (i) => 0.5 * (1.0 - math.cos(2.0 * math.pi * (i + 1) / 2049.0)),
    ),
  );

  /// Generates a Shazam Data URI signature from raw 16-bit signed mono PCM bytes at 16kHz.
  ///
  /// [pcmBytes] must have an even length (2 bytes per sample, little-endian).
  /// [magicHeader] defaults to `0xcafe2807`.
  static String fromI16(
    Uint8List pcmBytes, {
    int magicHeader = kDefaultMagicHeader,
  }) {
    if (pcmBytes.length < 2 || pcmBytes.length % 2 != 0) {
      throw ArgumentError(
        'pcmBytes must be non-empty and have even length (16-bit PCM)',
      );
    }

    final byteData = ByteData.sublistView(pcmBytes);
    final pcm = Int16List(pcmBytes.length ~/ 2);
    for (int i = 0; i < pcm.length; i++) {
      pcm[i] = byteData.getInt16(i * 2, Endian.little);
    }

    return fromSamples(pcm, magicHeader: magicHeader);
  }

  /// Generates a Shazam Data URI signature from 16-bit signed PCM samples at 16kHz.
  static String fromSamples(
    Int16List samples, {
    int magicHeader = kDefaultMagicHeader,
  }) {
    return _SignatureGeneratorState(magicHeader: magicHeader).process(samples);
  }

  /// Decodes a Shazam base64 signature Data URI into a structured [DecodedSignature].
  ///
  /// Verifies the magic header, magic2, CRC-32 checksum, and extracts all frequency peaks.
  static DecodedSignature? decodeSignature(String uri) {
    if (!uri.startsWith(kDataUriPrefix)) return null;

    final base64Data = uri.substring(kDataUriPrefix.length);
    final bytes = base64.decode(base64Data);
    if (bytes.length < 56) return null;

    final byteData = ByteData.sublistView(bytes);
    final magic1 = byteData.getUint32(0, Endian.little);
    final expectedCrc32 = byteData.getUint32(4, Endian.little);
    final sizeMinusHeader = byteData.getUint32(8, Endian.little);
    final magic2 = byteData.getUint32(12, Endian.little);

    if (magic2 != kMagicHeader2) return null;
    if (sizeMinusHeader != bytes.length - 48) return null;

    // Verify CRC32
    final computedCrc32 = Crc32.compute(bytes, 8, bytes.length);
    if (computedCrc32 != expectedCrc32) return null;

    final shiftedSampleRate = byteData.getUint32(28, Endian.little);
    final sampleRateId = shiftedSampleRate >> 27;
    final sampleRate = sampleRateId == 3 ? 16000 : 8000 * sampleRateId;

    final samplesWithOffset = byteData.getUint32(40, Endian.little);
    final numberSamples = (samplesWithOffset - sampleRate * 0.24).round();

    // Verify TLV header at offset 48
    final tlvMagic = byteData.getUint32(48, Endian.little);
    final tlvSize = byteData.getUint32(52, Endian.little);
    if (tlvMagic != 0x40000000 || tlvSize != sizeMinusHeader) return null;

    final bandPeaks = <int, List<FrequencyPeak>>{};
    int offset = 56;

    while (offset + 8 <= bytes.length) {
      final bandTag = byteData.getUint32(offset, Endian.little);
      final bandSize = byteData.getUint32(offset + 4, Endian.little);
      offset += 8;

      if (offset + bandSize > bytes.length) break;

      final bandId = bandTag - 0x60030040;
      final peaks = <FrequencyPeak>[];
      int peakOffset = offset;
      final peakEnd = offset + bandSize;
      int fftPassNumber = 0;

      while (peakOffset < peakEnd) {
        final step = bytes[peakOffset++];
        if (step == 0xFF) {
          if (peakOffset + 4 > peakEnd) break;
          fftPassNumber = byteData.getUint32(peakOffset, Endian.little);
          peakOffset += 4;
          continue;
        }

        fftPassNumber += step;
        if (peakOffset + 4 > peakEnd) break;

        final magnitude = byteData.getUint16(peakOffset, Endian.little);
        final bin = byteData.getUint16(peakOffset + 2, Endian.little);
        peakOffset += 4;

        peaks.add(
          FrequencyPeak(
            fftPassNumber: fftPassNumber,
            peakMagnitude: magnitude,
            correctedPeakFrequencyBin: bin,
          ),
        );
      }

      bandPeaks[bandId] = peaks;

      // Skip padding to 4-byte alignment
      final padding = (4 - (bandSize % 4)) % 4;
      offset += bandSize + padding;
    }

    return DecodedSignature(
      magic1: magic1,
      magic2: magic2,
      sampleRate: sampleRate,
      numberSamples: numberSamples,
      bandPeaks: bandPeaks,
    );
  }
}

/// Internal state machine matching Vibra & Metrolist's SignatureGeneratorState.
class _SignatureGeneratorState {
  final int magicHeader;

  // Circular buffer for 2048 raw samples (Shorts stored in Int for speed)
  final Int32List samplesRing = Int32List(ShazamSignatureGenerator.kFftSize);
  int samplesPos = 0;

  // Circular buffer of FFT magnitude outputs (256 x 1025)
  final List<Float64List> fftOutputs = List.generate(
    ShazamSignatureGenerator.kRingBufSize,
    (_) => Float64List(ShazamSignatureGenerator.kFftOutputSize),
  );
  int fftPos = 0;
  int fftNumWritten = 0;

  // Circular buffer of time-spread FFT outputs (256 x 1025)
  final List<Float64List> spreadFfts = List.generate(
    ShazamSignatureGenerator.kRingBufSize,
    (_) => Float64List(ShazamSignatureGenerator.kFftOutputSize),
  );
  int spreadPos = 0;
  int spreadNumWritten = 0;

  // Accumulated samples count
  int numSamples = 0;

  // Band -> list of peaks (bands 0..3)
  final List<List<FrequencyPeak>> bandPeaks = List.generate(
    4,
    (_) => <FrequencyPeak>[],
  );
  int totalPeaks = 0;

  _SignatureGeneratorState({required this.magicHeader});

  String process(Int16List pcm) {
    int offset = 0;
    while (offset + 128 <= pcm.length) {
      final elapsedSec = numSamples / ShazamSignatureGenerator.kSampleRate;
      if (elapsedSec >= ShazamSignatureGenerator.kMaxTimeSeconds &&
          totalPeaks >= ShazamSignatureGenerator.kMaxPeaks) {
        break;
      }

      numSamples += 128;
      feedSamples(pcm, offset, 128);
      doFFT();
      doPeakSpreadingAndRecognition();
      offset += 128;
    }

    return encodeSignature();
  }

  void feedSamples(Int16List pcm, int start, int count) {
    final ring = samplesRing;
    int pos = samplesPos;
    final ringLen = ring.length;

    for (int k = start; k < start + count; k++) {
      ring[pos] = pcm[k];
      pos = (pos + 1) % ringLen;
    }
    samplesPos = pos;
  }

  void doFFT() {
    final windowed = Float64List(ShazamSignatureGenerator.kFftSize);
    final ring = samplesRing;
    final pos = samplesPos;
    final hanning = ShazamSignatureGenerator._hanning;
    const n = ShazamSignatureGenerator.kFftSize;

    for (int i = 0; i < n; i++) {
      windowed[i] = ring[(pos + i) % n] * hanning[i];
    }

    final result = computeRfft(windowed);
    fftOutputs[fftPos].setAll(0, result);
    fftPos = (fftPos + 1) % ShazamSignatureGenerator.kRingBufSize;
    fftNumWritten++;
  }

  void doPeakSpreadingAndRecognition() {
    doPeakSpreading();
    if (spreadNumWritten >= 47) {
      doPeakRecognition();
    }
  }

  void doPeakSpreading() {
    const ringBufSize = ShazamSignatureGenerator.kRingBufSize;
    const outputSize = ShazamSignatureGenerator.kFftOutputSize;

    final lastFftIdx = (fftPos - 1 + ringBufSize) % ringBufSize;
    final spread = Float64List.fromList(fftOutputs[lastFftIdx]);

    // Frequency spreading: 3-point running max (in-place, forward pass)
    for (int pos = 0; pos < outputSize - 2; pos++) {
      spread[pos] = math.max(
        spread[pos],
        math.max(spread[pos + 1], spread[pos + 2]),
      );
    }

    // Time spreading: propagate max to/from older spread entries at offsets -1, -3, -6
    // Only older entries are updated; the new entry keeps only frequency spreading.
    for (int pos = 0; pos < outputSize; pos++) {
      double maxVal = spread[pos];
      for (final offset in const [-1, -3, -6]) {
        final idx = ((spreadPos + offset) % ringBufSize + ringBufSize) % ringBufSize;
        final oldVal = spreadFfts[idx][pos];
        if (oldVal > maxVal) maxVal = oldVal;
        spreadFfts[idx][pos] = maxVal;
      }
    }

    spreadFfts[spreadPos].setAll(0, spread);
    spreadPos = (spreadPos + 1) % ringBufSize;
    spreadNumWritten++;
  }

  void doPeakRecognition() {
    const ringBufSize = ShazamSignatureGenerator.kRingBufSize;
    const outputSize = ShazamSignatureGenerator.kFftOutputSize;

    final fftMinus46 =
        fftOutputs[(fftPos - 46 + ringBufSize * 2) % ringBufSize];
    final spreadMinus49 =
        spreadFfts[(spreadPos - 49 + ringBufSize * 2) % ringBufSize];

    const otherOffsets = [
      -53, -45, 165, 172, 179, 186, 193, 200, 214, 221, 228, 235, 242, 249,
    ];
    const neighborOffsets = [-10, -7, -4, -3, 1, 2, 5, 8];

    for (int binPos = 10; binPos < outputSize - 8; binPos++) {
      final fftVal = fftMinus46[binPos];
      if (fftVal < 1.0 / 64.0 || fftVal < spreadMinus49[binPos]) continue;

      // Check 8 neighbors in spreadMinus49
      double maxNeighborSpread49 = 0.0;
      for (final neighborOffset in neighborOffsets) {
        final v = spreadMinus49[binPos + neighborOffset];
        if (v > maxNeighborSpread49) maxNeighborSpread49 = v;
      }
      if (fftVal <= maxNeighborSpread49) continue;

      // Check 14 other spread FFT offsets
      double maxNeighborOther = maxNeighborSpread49;
      for (final otherOffset in otherOffsets) {
        final spreadIdx =
            ((spreadPos + otherOffset) % ringBufSize + ringBufSize) %
            ringBufSize;
        final v = spreadFfts[spreadIdx][binPos - 1];
        if (v > maxNeighborOther) maxNeighborOther = v;
      }
      if (fftVal <= maxNeighborOther) continue;

      // Valid peak found: compute corrected bin and frequency
      final fftNumber = spreadNumWritten - 46;

      final peakMag =
          math.log(math.max(1.0 / 64.0, fftVal)) * 1477.3 + 6144.0;
      final peakMagBefore =
          math.log(math.max(1.0 / 64.0, fftMinus46[binPos - 1])) * 1477.3 +
          6144.0;
      final peakMagAfter =
          math.log(math.max(1.0 / 64.0, fftMinus46[binPos + 1])) * 1477.3 +
          6144.0;

      final peakVariation1 = peakMag * 2 - peakMagBefore - peakMagAfter;
      final peakVariation2 = (peakMagAfter - peakMagBefore) * 32.0 / peakVariation1;

      final correctedBin = binPos * 64.0 + peakVariation2;
      final frequencyHz =
          correctedBin * (16000.0 / 2.0 / 1024.0 / 64.0);

      final int band;
      if (frequencyHz < 250.0) {
        continue;
      } else if (frequencyHz < 520.0) {
        band = ShazamSignatureGenerator.kBand250To520;
      } else if (frequencyHz < 1450.0) {
        band = ShazamSignatureGenerator.kBand520To1450;
      } else if (frequencyHz < 3500.0) {
        band = ShazamSignatureGenerator.kBand1450To3500;
      } else if (frequencyHz <= 5500.0) {
        band = ShazamSignatureGenerator.kBand3500To5500;
      } else {
        continue;
      }

      bandPeaks[band].add(
        FrequencyPeak(
          fftPassNumber: fftNumber,
          peakMagnitude: peakMag.toInt(),
          correctedPeakFrequencyBin: correctedBin.toInt(),
        ),
      );
      totalPeaks++;
    }
  }

  String encodeSignature() {
    final contentsBuilder = BytesBuilder();

    // Write each frequency band's peaks in ascending band order (0..3)
    for (int bandId = 0; bandId <= 3; bandId++) {
      final peaks = bandPeaks[bandId];
      if (peaks.isEmpty) continue;

      final peakBuf = BytesBuilder();
      int prevFftPassNumber = 0;

      for (final peak in peaks) {
        final diff = peak.fftPassNumber - prevFftPassNumber;
        if (diff >= 255) {
          // Encode absolute position with 0xFF marker
          peakBuf.addByte(0xFF);
          _writeLittleEndian32(peakBuf, peak.fftPassNumber);
          prevFftPassNumber = peak.fftPassNumber;
        }
        peakBuf.addByte(peak.fftPassNumber - prevFftPassNumber);
        _writeLittleEndian16(peakBuf, peak.peakMagnitude);
        _writeLittleEndian16(peakBuf, peak.correctedPeakFrequencyBin);
        prevFftPassNumber = peak.fftPassNumber;
      }

      final peakBytes = peakBuf.toBytes();

      // Band tag: 0x60030040 + bandId
      _writeLittleEndian32(contentsBuilder, 0x60030040 + bandId);
      _writeLittleEndian32(contentsBuilder, peakBytes.length);
      contentsBuilder.add(peakBytes);

      // Pad to 4-byte alignment
      final padBytes = (4 - (peakBytes.length % 4)) % 4;
      for (int p = 0; p < padBytes; p++) {
        contentsBuilder.addByte(0);
      }
    }

    final contents = contentsBuilder.toBytes();
    final sizeMinusHeader = contents.length + 8;
    final samplesAndOffset =
        (numSamples + ShazamSignatureGenerator.kSampleRate * 0.24).toInt();

    // Build 48-byte header struct (all fields little-endian)
    final headerBytes = Uint8List(48);
    final headerData = ByteData.sublistView(headerBytes);

    headerData.setUint32(0, magicHeader, Endian.little); // magic1
    headerData.setUint32(4, 0, Endian.little);           // crc32 placeholder
    headerData.setUint32(8, sizeMinusHeader, Endian.little);
    headerData.setUint32(12, ShazamSignatureGenerator.kMagicHeader2, Endian.little);
    headerData.setUint32(16, 0, Endian.little);          // void1[0]
    headerData.setUint32(20, 0, Endian.little);          // void1[1]
    headerData.setUint32(24, 0, Endian.little);          // void1[2]
    headerData.setUint32(28, 3 << 27, Endian.little);    // shifted_sample_rate_id
    headerData.setUint32(32, 0, Endian.little);          // void2[0]
    headerData.setUint32(36, 0, Endian.little);          // void2[1]
    headerData.setUint32(40, samplesAndOffset, Endian.little);
    headerData.setUint32(44, (15 << 19) + 0x40000, Endian.little); // fixed_value

    // Assemble full buffer: header(48) + 0x40000000(4) + sizeMinusHeader(4) + contents
    final fullBuilder = BytesBuilder();
    fullBuilder.add(headerBytes);
    _writeLittleEndian32(fullBuilder, 0x40000000);
    _writeLittleEndian32(fullBuilder, contents.length + 8);
    fullBuilder.add(contents);

    final fullBytes = fullBuilder.toBytes();

    // CRC32 over bytes from offset 8 to end (skipping magic1 and crc32)
    final crc32Val = Crc32.compute(fullBytes, 8, fullBytes.length);

    // Write CRC32 at offset 4 (little-endian)
    final fullByteData = ByteData.sublistView(fullBytes);
    fullByteData.setUint32(4, crc32Val, Endian.little);

    final base64String = base64.encode(fullBytes);
    return '${ShazamSignatureGenerator.kDataUriPrefix}$base64String';
  }

  void _writeLittleEndian32(BytesBuilder out, int value) {
    out.addByte(value & 0xFF);
    out.addByte((value >>> 8) & 0xFF);
    out.addByte((value >>> 16) & 0xFF);
    out.addByte((value >>> 24) & 0xFF);
  }

  void _writeLittleEndian16(BytesBuilder out, int value) {
    out.addByte(value & 0xFF);
    out.addByte((value >>> 8) & 0xFF);
  }

  /// Computes the real-input FFT of [windowed] (size 2048) using an iterative
  /// Cooley-Tukey radix-2 DIT algorithm.
  ///
  /// Returns 1025 magnitude values:
  /// `magnitude[k] = max((re[k]^2 + im[k]^2) / 2^17, 1e-10)`
  static Float64List computeRfft(Float64List windowed) {
    final n = windowed.length; // 2048
    final re = Float64List.fromList(windowed);
    final im = Float64List(n);

    // Bit-reversal permutation
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >>> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>>= 1;
      }
      j ^= bit;
      if (i < j) {
        final tmpRe = re[i];
        re[i] = re[j];
        re[j] = tmpRe;
        final tmpIm = im[i];
        im[i] = im[j];
        im[j] = tmpIm;
      }
    }

    // Cooley-Tukey butterfly stages (11 stages for n=2048)
    int len = 2;
    while (len <= n) {
      final halfLen = len >>> 1;
      final ang = -math.pi / halfLen; // -2*pi / len
      final wBaseRe = math.cos(ang);
      final wBaseIm = math.sin(ang);

      int i = 0;
      while (i < n) {
        double wRe = 1.0;
        double wIm = 0.0;
        for (int k = 0; k < halfLen; k++) {
          final u = i + k;
          final v = u + halfLen;
          final evenRe = re[u];
          final evenIm = im[u];
          final oddRe = re[v] * wRe - im[v] * wIm;
          final oddIm = re[v] * wIm + im[v] * wRe;

          re[u] = evenRe + oddRe;
          im[u] = evenIm + oddIm;
          re[v] = evenRe - oddRe;
          im[v] = evenIm - oddIm;

          final newWRe = wRe * wBaseRe - wIm * wBaseIm;
          final newWIm = wRe * wBaseIm + wIm * wBaseRe;
          wRe = newWRe;
          wIm = newWIm;
        }
        i += len;
      }
      len <<= 1;
    }

    // Extract magnitudes for bins 0..n/2 (FFT_OUTPUT_SIZE = 1025)
    const scaleFactor = 1.0 / (1 << 17);
    const minVal = 1e-10;
    final magnitudes = Float64List(ShazamSignatureGenerator.kFftOutputSize);
    for (int idx = 0; idx < ShazamSignatureGenerator.kFftOutputSize; idx++) {
      final r = re[idx];
      final img = im[idx];
      final mag = (r * r + img * img) * scaleFactor;
      magnitudes[idx] = mag < minVal ? minVal : mag;
    }

    return magnitudes;
  }
}

/// Represents an acoustic frequency peak in a Shazam signature.
class FrequencyPeak {
  final int fftPassNumber;
  final int peakMagnitude;
  final int correctedPeakFrequencyBin;

  const FrequencyPeak({
    required this.fftPassNumber,
    required this.peakMagnitude,
    required this.correctedPeakFrequencyBin,
  });

  /// Approximate frequency in Hertz.
  double get frequencyHz =>
      correctedPeakFrequencyBin * (16000.0 / 2.0 / 1024.0 / 64.0);

  /// Approximate time in seconds from start of audio.
  double get seconds => (fftPassNumber * 128) / 16000.0;

  @override
  String toString() =>
      'FrequencyPeak(fftPass: $fftPassNumber, freq: ${frequencyHz.toStringAsFixed(1)}Hz, mag: $peakMagnitude)';
}

/// Structured inspection representation of a decoded Shazam signature.
class DecodedSignature {
  final int magic1;
  final int magic2;
  final int sampleRate;
  final int numberSamples;
  final Map<int, List<FrequencyPeak>> bandPeaks;

  const DecodedSignature({
    required this.magic1,
    required this.magic2,
    required this.sampleRate,
    required this.numberSamples,
    required this.bandPeaks,
  });

  int get totalPeaks =>
      bandPeaks.values.fold(0, (sum, list) => sum + list.length);

  double get durationSeconds => numberSamples / sampleRate;
}

/// High-performance IEEE 802.3 32-bit Cyclic Redundancy Check (CRC32).
class Crc32 {
  static final List<int> _table = () {
    final table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int c = i;
      for (int k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      }
      table[i] = c;
    }
    return table;
  }();

  /// Computes CRC32 checksum over [bytes] from [start] to [end].
  static int compute(List<int> bytes, [int start = 0, int? end]) {
    final actualEnd = end ?? bytes.length;
    int crc = 0xFFFFFFFF;
    for (int i = start; i < actualEnd; i++) {
      crc = _table[(crc ^ bytes[i]) & 0xFF] ^ (crc >>> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}
