import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Spotify-compatible SPCO binary bank serialization engine.
/// Directly implements the binary format extracted in SPOTIFY_KERNEL_ARCHITECTURE_RESEARCH.md:
///
/// Offset  Size   Field
/// 0x00    4B     Magic Bytes "SPCO" (0x53, 0x50, 0x43, 0x4F)
/// 0x04    4B     Storage Class Name Length (uint32 LE)
/// 0x08    Var    Storage Class Name (ASCII)
/// Var     2B     Schema Version (uint16 LE)
/// Var     Var    GZIP-compressed serialized JSON / Protobuf bytes (0x1F, 0x8B, 0x08...)
class SpcoStorageService {
  static final SpcoStorageService instance = SpcoStorageService._internal();

  SpcoStorageService._internal();

  static const List<int> magicBytes = [0x53, 0x50, 0x43, 0x4F]; // "SPCO"
  static const int currentVersion = 1;

  /// Writes an object or map to an SPCO binary bank file atomically.
  Future<void> writeBankFile(
    File targetFile, {
    required String storageClassName,
    required Map<String, dynamic> data,
  }) async {
    final classNameBytes = utf8.encode(storageClassName);
    final jsonBytes = utf8.encode(jsonEncode(data));
    final compressedPayload = gzip.encode(jsonBytes);

    // Calculate buffer layout
    final totalSize = 4 + 4 + classNameBytes.length + 2 + compressedPayload.length;
    final byteData = ByteData(totalSize);
    int offset = 0;

    // 1. Magic bytes "SPCO"
    for (int i = 0; i < 4; i++) {
      byteData.setUint8(offset++, magicBytes[i]);
    }

    // 2. Class name length (uint32 LE)
    byteData.setUint32(offset, classNameBytes.length, Endian.little);
    offset += 4;

    // 3. Class name
    for (final b in classNameBytes) {
      byteData.setUint8(offset++, b);
    }

    // 4. Schema Version (uint16 LE)
    byteData.setUint16(offset, currentVersion, Endian.little);
    offset += 2;

    // 5. Compressed Payload
    for (final b in compressedPayload) {
      byteData.setUint8(offset++, b);
    }

    // Atomic write via temporary file
    final tempFile = File('${targetFile.path}.tmp');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    await tempFile.rename(targetFile.path);
  }

  /// Reads and decompresses an SPCO binary bank file into a Map.
  Future<Map<String, dynamic>?> readBankFile(File file) async {
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    if (bytes.length < 10) return null;

    final byteData = ByteData.sublistView(bytes);
    int offset = 0;

    // Verify magic bytes "SPCO"
    for (int i = 0; i < 4; i++) {
      if (byteData.getUint8(offset++) != magicBytes[i]) {
        return null; // Invalid magic header
      }
    }

    // Read class name length
    final nameLen = byteData.getUint32(offset, Endian.little);
    offset += 4;

    if (offset + nameLen + 2 > bytes.length) return null;

    // Read class name
    final _ = utf8.decode(bytes.sublist(offset, offset + nameLen));
    offset += nameLen;

    // Read version
    final version = byteData.getUint16(offset, Endian.little);
    offset += 2;
    if (version > currentVersion) return null;

    // Decompress GZIP payload
    final compressedPayload = bytes.sublist(offset);
    final decompressedJsonBytes = gzip.decode(compressedPayload);
    final jsonStr = utf8.decode(decompressedJsonBytes);

    return jsonDecode(jsonStr) as Map<String, dynamic>?;
  }
}
