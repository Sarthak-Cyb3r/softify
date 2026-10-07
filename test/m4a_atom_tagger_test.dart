import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/tagging/m4a_atom_tagger.dart';

void main() {
  group('M4aAtomTagger & Audio Offset Alignment Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('m4a_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Uint8List buildMinimalMp4({required int initialChunkOffset}) {
      final builder = BytesBuilder();

      // 1. ftyp box (32 bytes)
      final ftypData = BytesBuilder();
      ftypData.add(latin1.encode('M4A ')); // major brand
      final ftypVer = ByteData(4)..setUint32(0, 0);
      ftypData.add(ftypVer.buffer.asUint8List());
      ftypData.add(latin1.encode('isommp42'));
      final ftypBytes = ftypData.toBytes();
      final ftypHeader = ByteData(8)
        ..setUint32(0, 8 + ftypBytes.length)
        ..setUint8(4, $f)
        ..setUint8(5, $t)
        ..setUint8(6, $y)
        ..setUint8(7, $p);
      builder.add(ftypHeader.buffer.asUint8List());
      builder.add(ftypBytes);

      // 2. moov box containing trak -> mdia -> minf -> stbl -> stco
      // stco box
      final stcoPayload = BytesBuilder();
      final stcoHeader = ByteData(8);
      stcoHeader.setUint32(0, 0); // version 0, flags 0
      stcoHeader.setUint32(4, 1); // 1 entry
      stcoPayload.add(stcoHeader.buffer.asUint8List());
      final chunkOffsetData = ByteData(4)..setUint32(0, initialChunkOffset);
      stcoPayload.add(chunkOffsetData.buffer.asUint8List());
      final stcoBox = _box('stco', stcoPayload.toBytes());

      final stblBox = _box('stbl', stcoBox);
      final minfBox = _box('minf', stblBox);
      final mdiaBox = _box('mdia', minfBox);
      final trakBox = _box('trak', mdiaBox);
      final moovBox = _box('moov', trakBox);
      builder.add(moovBox);

      // 3. mdat box
      final mdatData = Uint8List(1024); // 1KB audio payload
      final mdatBox = _box('mdat', mdatData);
      builder.add(mdatBox);

      return builder.toBytes();
    }

    test('isValidIsoMp4 recognizes ftyp header and rejects non-MP4', () {
      final valid = buildMinimalMp4(initialChunkOffset: 100);
      expect(M4aAtomTagger.isValidIsoMp4(valid), isTrue);

      final invalid = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      expect(M4aAtomTagger.isValidIsoMp4(invalid), isFalse);
    });

    test('writeMetadata shifts stco chunk offsets when moov is before mdat', () async {
      final testFile = File('${tempDir.path}/test_track.m4a');
      final initialMp4 = buildMinimalMp4(initialChunkOffset: 500);
      await testFile.writeAsBytes(initialMp4);

      final initialLength = initialMp4.length;

      await M4aAtomTagger.writeMetadata(
        testFile,
        const M4aMetadata(
          title: 'Test Song',
          artist: 'Test Artist',
          album: 'Test Album',
        ),
      );

      final taggedBytes = await testFile.readAsBytes();
      final taggedLength = taggedBytes.length;
      final addedBytes = taggedLength - initialLength;
      expect(addedBytes, greaterThan(0));

      // Read stco from tagged file
      final reader = ByteData.sublistView(taggedBytes);
      int? updatedChunkOffset;

      void scan(int start, int end) {
        int off = start;
        while (off + 8 <= end) {
          final sz = reader.getUint32(off);
          if (sz < 8 || off + sz > end) break;
          final type = latin1.decode(taggedBytes.sublist(off + 4, off + 8));
          if (type == 'moov' || type == 'trak' || type == 'mdia' || type == 'minf' || type == 'stbl') {
            scan(off + 8, off + sz);
          } else if (type == 'stco') {
            updatedChunkOffset = reader.getUint32(off + 16);
            return;
          }
          off += sz;
        }
      }

      scan(0, taggedBytes.length);

      // The new chunk offset MUST be initial (500) + addedBytes
      expect(updatedChunkOffset, equals(500 + addedBytes));
    });

    test('repairCorruptedFile detects and repairs misaligned stco', () async {
      // Simulate an MP4 where moov is at offset 32, size 200, mdat is at offset 232.
      // mdat payload starts at 232 + 8 = 240.
      // But stco was erroneously pointing to 200 (shifted by -40).
      final testFile = File('${tempDir.path}/corrupt_track.m4a');
      // Build mp4 with initial chunk offset pointing BEFORE mdat (50 < 92)
      final bytes = buildMinimalMp4(initialChunkOffset: 50);
      await testFile.writeAsBytes(bytes);

      // The file mdat starts at roughly ~140, but stco is at 100.
      final repaired = await M4aAtomTagger.repairCorruptedFile(testFile);
      expect(repaired, isTrue);

      final repairedBytes = await testFile.readAsBytes();
      final reader = ByteData.sublistView(repairedBytes);
      int? fixedChunkOffset;

      void scan(int start, int end) {
        int off = start;
        while (off + 8 <= end) {
          final sz = reader.getUint32(off);
          if (sz < 8 || off + sz > end) break;
          final type = latin1.decode(repairedBytes.sublist(off + 4, off + 8));
          if (type == 'moov' || type == 'trak' || type == 'mdia' || type == 'minf' || type == 'stbl') {
            scan(off + 8, off + sz);
          } else if (type == 'stco') {
            fixedChunkOffset = reader.getUint32(off + 16);
            return;
          }
          off += sz;
        }
      }

      scan(0, repairedBytes.length);

      // Verify that after repair, stco points exactly to mdat data start!
      int offset = 0;
      int? mdatDataStart;
      while (offset + 8 <= repairedBytes.length) {
        final sz = reader.getUint32(offset);
        final type = latin1.decode(repairedBytes.sublist(offset + 4, offset + 8));
        if (type == 'mdat') {
          mdatDataStart = offset + 8;
          break;
        }
        offset += sz;
      }

      expect(fixedChunkOffset, equals(mdatDataStart));
    });
  });
}

Uint8List _box(String type, Uint8List payload) {
  final header = ByteData(8);
  header.setUint32(0, 8 + payload.length);
  final typeCodes = latin1.encode(type);
  for (int i = 0; i < 4; i++) {
    header.setUint8(4 + i, typeCodes[i]);
  }
  final b = BytesBuilder();
  b.add(header.buffer.asUint8List());
  b.add(payload);
  return b.toBytes();
}

const int $f = 0x66;
const int $t = 0x74;
const int $y = 0x79;
const int $p = 0x70;
