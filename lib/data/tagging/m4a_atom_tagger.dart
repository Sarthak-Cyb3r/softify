import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class M4aMetadata {
  final String title;
  final String artist;
  final String? album;
  final Uint8List? coverArtBytes; // JPEG or PNG bytes

  const M4aMetadata({
    required this.title,
    required this.artist,
    this.album,
    this.coverArtBytes,
  });
}

class M4aAtomTagger {
  /// Verifies that a downloaded file matches the expected byte count.
  static Future<bool> verifyFileSize(File file, int expectedBytes) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    return length == expectedBytes;
  }

  /// Verifies if a file starts with the ISO Base Media File Format box (ftyp).
  static bool isValidIsoMp4(Uint8List bytes) {
    if (bytes.length < 8) return false;
    final type = latin1.decode(bytes.sublist(4, 8));
    return type == 'ftyp';
  }

  /// Writes iTunes-style MP4 metadata atoms into an M4A file with sample table offset alignment.
  static Future<void> writeMetadata(File m4aFile, M4aMetadata metadata) async {
    if (!await m4aFile.exists()) return;
    final bytes = await m4aFile.readAsBytes();
    if (!isValidIsoMp4(bytes)) return;

    final reader = ByteData.sublistView(bytes);

    // Build the ilst payload
    final ilstPayload = BytesBuilder();

    // 1. Title (©nam)
    ilstPayload.add(_buildTextAtom('©nam', metadata.title));

    // 2. Artist (©ART)
    ilstPayload.add(_buildTextAtom('©ART', metadata.artist));

    // 3. Album (©alb)
    if (metadata.album != null && metadata.album!.isNotEmpty) {
      ilstPayload.add(_buildTextAtom('©alb', metadata.album!));
    }

    // 4. Cover Art (covr)
    if (metadata.coverArtBytes != null && metadata.coverArtBytes!.isNotEmpty) {
      ilstPayload.add(_buildCoverAtom(metadata.coverArtBytes!));
    }

    final ilstData = ilstPayload.toBytes();
    final ilstAtom = _buildBox('ilst', ilstData);

    // Build meta box containing ilst (meta has 4 bytes version/flags before children)
    final metaHeader = Uint8List(4); // Version 0, flags 0
    final metaPayload = BytesBuilder();
    metaPayload.add(metaHeader);
    metaPayload.add(ilstAtom);
    final metaAtom = _buildBox('meta', metaPayload.toBytes());

    // Build udta box containing meta
    final udtaAtom = _buildBox('udta', metaAtom);

    // Insert udta inside moov atom and realign stco/co64 chunk offsets
    final updatedBytes = _injectUdtaIntoMoov(bytes, reader, udtaAtom);
    if (identical(updatedBytes, bytes)) return;

    // Atomic write
    final tempFile = File('${m4aFile.path}.tmp');
    await tempFile.writeAsBytes(updatedBytes);
    await tempFile.rename(m4aFile.path);
  }

  /// Automatically inspects and repairs any previously misaligned stco chunk offsets
  /// caused by prior v1.0.0 metadata injection bugs.
  static Future<bool> repairCorruptedFile(File m4aFile) async {
    if (!await m4aFile.exists()) return false;
    try {
      final bytes = await m4aFile.readAsBytes();
      if (!isValidIsoMp4(bytes)) return false;

      final reader = ByteData.sublistView(bytes);
      int offset = 0;
      int? moovOffset;
      int? moovSize;
      int? mdatOffset;
      bool mdatHas64BitSize = false;

      while (offset + 8 <= bytes.length) {
        int size = reader.getUint32(offset);
        final type = latin1.decode(bytes.sublist(offset + 4, offset + 8));

        if (size == 1 && offset + 16 <= bytes.length) {
          size = reader.getInt64(offset + 8);
          if (type == 'mdat') mdatHas64BitSize = true;
        }

        if (type == 'moov') {
          moovOffset = offset;
          moovSize = size;
        } else if (type == 'mdat') {
          mdatOffset = offset;
        }

        if (size < 8) break;
        offset += size;
      }

      if (moovOffset == null || moovSize == null || mdatOffset == null) {
        return false;
      }

      // If moov is before mdat, verify stco chunk offset alignment
      if (moovOffset < mdatOffset) {
        final mdatDataStart = mdatOffset + (mdatHas64BitSize ? 16 : 8);
        final firstChunk = _findFirstChunkOffset(bytes, reader, moovOffset + 8, moovOffset + moovSize);
        if (firstChunk != null && firstChunk < mdatDataStart) {
          final diff = mdatDataStart - firstChunk;
          if (diff > 0 && diff <= 30 * 1024 * 1024) {
            final mutableBytes = Uint8List.fromList(bytes);
            final mutableReader = ByteData.sublistView(mutableBytes);
            _shiftChunkOffsets(mutableBytes, mutableReader, moovOffset + 8, moovOffset + moovSize, diff);

            final tempFile = File('${m4aFile.path}.repaired');
            await tempFile.writeAsBytes(mutableBytes);
            await tempFile.rename(m4aFile.path);
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  static Uint8List _buildTextAtom(String name, String text) {
    final textBytes = utf8.encode(text);
    final dataPayload = BytesBuilder();
    final dataHeader = ByteData(8);
    dataHeader.setUint32(0, 1); // Type 1: UTF-8 without BOM
    dataHeader.setUint32(4, 0); // Locale
    dataPayload.add(dataHeader.buffer.asUint8List());
    dataPayload.add(textBytes);

    final dataBox = _buildBox('data', dataPayload.toBytes());
    return _buildBox(name, dataBox);
  }

  static Uint8List _buildCoverAtom(Uint8List imageBytes) {
    int type = 13; // 13 = JPEG
    if (imageBytes.length >= 8 &&
        imageBytes[0] == 0x89 &&
        imageBytes[1] == 0x50 &&
        imageBytes[2] == 0x4E &&
        imageBytes[3] == 0x47) {
      type = 14; // 14 = PNG
    }

    final dataPayload = BytesBuilder();
    final dataHeader = ByteData(8);
    dataHeader.setUint32(0, type);
    dataHeader.setUint32(4, 0);
    dataPayload.add(dataHeader.buffer.asUint8List());
    dataPayload.add(imageBytes);

    final dataBox = _buildBox('data', dataPayload.toBytes());
    return _buildBox('covr', dataBox);
  }

  static Uint8List _buildBox(String type, Uint8List data) {
    final length = 8 + data.length;
    final box = ByteData(8);
    box.setUint32(0, length);
    final typeCodes = latin1.encode(type);
    for (int i = 0; i < 4; i++) {
      box.setUint8(4 + i, typeCodes[i]);
    }
    final builder = BytesBuilder();
    builder.add(box.buffer.asUint8List());
    builder.add(data);
    return builder.toBytes();
  }

  static Uint8List _injectUdtaIntoMoov(
    Uint8List originalBytes,
    ByteData reader,
    Uint8List udtaAtom,
  ) {
    int offset = 0;
    int? moovOffset;
    int? moovSize;
    int? mdatOffset;

    while (offset + 8 <= originalBytes.length) {
      int size = reader.getUint32(offset);
      final type = latin1.decode(originalBytes.sublist(offset + 4, offset + 8));

      if (size == 1 && offset + 16 <= originalBytes.length) {
        size = reader.getInt64(offset + 8);
      }

      if (type == 'moov') {
        moovOffset = offset;
        moovSize = size;
      } else if (type == 'mdat') {
        mdatOffset = offset;
      }

      if (size < 8) break;
      offset += size;
    }

    if (moovOffset == null || moovSize == null) {
      return originalBytes;
    }

    final moovDataStart = moovOffset + 8;
    final moovDataEnd = moovOffset + moovSize;

    // Check if moov already has a udta atom
    int subOffset = moovDataStart;
    int? existingUdtaOffset;
    int? existingUdtaSize;

    while (subOffset + 8 <= moovDataEnd) {
      final subSize = reader.getUint32(subOffset);
      if (subSize < 8 || subOffset + subSize > moovDataEnd) break;
      final subType = latin1.decode(originalBytes.sublist(subOffset + 4, subOffset + 8));

      if (subType == 'udta') {
        existingUdtaOffset = subOffset;
        existingUdtaSize = subSize;
        break;
      }
      subOffset += subSize;
    }

    final builder = BytesBuilder();
    if (existingUdtaOffset != null && existingUdtaSize != null) {
      // Replace existing udta
      builder.add(originalBytes.sublist(0, existingUdtaOffset));
      builder.add(udtaAtom);
      builder.add(originalBytes.sublist(existingUdtaOffset + existingUdtaSize));
    } else {
      // Append udta inside moov
      builder.add(originalBytes.sublist(0, moovDataEnd));
      builder.add(udtaAtom);
      builder.add(originalBytes.sublist(moovDataEnd));
    }

    final addedBytes = existingUdtaSize != null
        ? udtaAtom.length - existingUdtaSize
        : udtaAtom.length;

    // Update the moov box size
    final result = builder.toBytes();
    final resultReader = ByteData.sublistView(result);
    final newMoovSize = moovSize + addedBytes;
    resultReader.setUint32(moovOffset, newMoovSize);

    // CRITICAL: If moov is located before mdat, inserting udta pushed mdat
    // backward by addedBytes. We must shift all sample table chunk offsets
    // (stco 32-bit and co64 64-bit) by addedBytes to maintain perfect AAC alignment!
    if (mdatOffset != null && moovOffset < mdatOffset) {
      _shiftChunkOffsets(result, resultReader, moovOffset + 8, moovOffset + newMoovSize, addedBytes);
    }

    return result;
  }

  static void _shiftChunkOffsets(
    Uint8List bytes,
    ByteData reader,
    int start,
    int end,
    int addedBytes,
  ) {
    int offset = start;
    while (offset + 8 <= end && offset + 8 <= bytes.length) {
      final size = reader.getUint32(offset);
      if (size < 8 || offset + size > end) break;
      final type = latin1.decode(bytes.sublist(offset + 4, offset + 8));

      if (type == 'trak' || type == 'mdia' || type == 'minf' || type == 'stbl') {
        _shiftChunkOffsets(bytes, reader, offset + 8, offset + size, addedBytes);
      } else if (type == 'stco') {
        if (offset + 16 <= bytes.length) {
          final count = reader.getUint32(offset + 12);
          for (int i = 0; i < count; i++) {
            final entryPos = offset + 16 + (i * 4);
            if (entryPos + 4 <= bytes.length) {
              final oldVal = reader.getUint32(entryPos);
              reader.setUint32(entryPos, oldVal + addedBytes);
            }
          }
        }
      } else if (type == 'co64') {
        if (offset + 16 <= bytes.length) {
          final count = reader.getUint32(offset + 12);
          for (int i = 0; i < count; i++) {
            final entryPos = offset + 16 + (i * 8);
            if (entryPos + 8 <= bytes.length) {
              final oldVal = reader.getInt64(entryPos);
              reader.setInt64(entryPos, oldVal + addedBytes);
            }
          }
        }
      }
      offset += size;
    }
  }

  static int? _findFirstChunkOffset(
    Uint8List bytes,
    ByteData reader,
    int start,
    int end,
  ) {
    int offset = start;
    while (offset + 8 <= end && offset + 8 <= bytes.length) {
      final size = reader.getUint32(offset);
      if (size < 8 || offset + size > end) break;
      final type = latin1.decode(bytes.sublist(offset + 4, offset + 8));

      if (type == 'trak' || type == 'mdia' || type == 'minf' || type == 'stbl') {
        final res = _findFirstChunkOffset(bytes, reader, offset + 8, offset + size);
        if (res != null) return res;
      } else if (type == 'stco') {
        if (offset + 16 <= bytes.length) {
          final count = reader.getUint32(offset + 12);
          if (count > 0 && offset + 20 <= bytes.length) {
            return reader.getUint32(offset + 16);
          }
        }
      } else if (type == 'co64') {
        if (offset + 16 <= bytes.length) {
          final count = reader.getUint32(offset + 12);
          if (count > 0 && offset + 24 <= bytes.length) {
            return reader.getInt64(offset + 16);
          }
        }
      }
      offset += size;
    }
    return null;
  }
}
