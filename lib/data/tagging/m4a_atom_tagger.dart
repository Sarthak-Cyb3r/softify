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

  /// Writes iTunes-style MP4 metadata atoms into an M4A file.
  static Future<void> writeMetadata(File m4aFile, M4aMetadata metadata) async {
    final bytes = await m4aFile.readAsBytes();
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

    // Insert or append udta inside moov atom
    final updatedBytes = _injectUdtaIntoMoov(bytes, reader, udtaAtom);

    // Atomic write
    final tempFile = File('${m4aFile.path}.tmp');
    await tempFile.writeAsBytes(updatedBytes);
    await tempFile.rename(m4aFile.path);
  }

  static Uint8List _buildTextAtom(String name, String text) {
    final textBytes = utf8.encode(text);
    // 'data' box inside text atom: length (4) + 'data' (4) + type (4) + locale (4) + textBytes
    // Type 1 = UTF-8 text
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
    // Determine image type: 13 for JPEG, 14 for PNG
    int type = 13;
    if (imageBytes.length >= 8 &&
        imageBytes[0] == 0x89 &&
        imageBytes[1] == 0x50 &&
        imageBytes[2] == 0x4E &&
        imageBytes[3] == 0x47) {
      type = 14; // PNG signature
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
    while (offset + 8 <= originalBytes.length) {
      final size = reader.getUint32(offset);
      final type = latin1.decode(originalBytes.sublist(offset + 4, offset + 8));

      if (type == 'moov') {
        final moovDataStart = offset + 8;
        final moovDataEnd = offset + size;

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

        // Update the moov box size
        final result = builder.toBytes();
        final resultReader = ByteData.sublistView(result);
        final addedBytes = existingUdtaSize != null
            ? udtaAtom.length - existingUdtaSize
            : udtaAtom.length;
        resultReader.setUint32(offset, size + addedBytes);
        return result;
      }

      if (size < 8) break;
      offset += size;
    }

    // Fallback: If no moov found, return original bytes unchanged
    return originalBytes;
  }
}
