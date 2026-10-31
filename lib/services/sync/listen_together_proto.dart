import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Minimal, zero-dependency, ultra-fast Protobuf binary wire encoder.
class ProtoWriter {
  final BytesBuilder _buffer = BytesBuilder();

  void writeVarint(int value) {
    var v = value;
    while (v >= 0x80 || v < 0) {
      _buffer.addByte((v & 0x7F) | 0x80);
      v = (v >> 7) & 0x01FFFFFFFFFFFFFF;
      if (v == 0) break;
    }
    _buffer.addByte(v & 0x7F);
  }

  void writeTag(int fieldNumber, int wireType) {
    writeVarint((fieldNumber << 3) | wireType);
  }

  void writeString(int fieldNumber, String value) {
    final bytes = utf8.encode(value);
    writeTag(fieldNumber, 2);
    writeVarint(bytes.length);
    _buffer.add(bytes);
  }

  void writeBytes(int fieldNumber, List<int> bytes) {
    writeTag(fieldNumber, 2);
    writeVarint(bytes.length);
    _buffer.add(bytes);
  }

  void writeBool(int fieldNumber, bool value) {
    writeTag(fieldNumber, 0);
    writeVarint(value ? 1 : 0);
  }

  void writeInt64(int fieldNumber, int value) {
    writeTag(fieldNumber, 0);
    writeVarint(value);
  }

  void writeFloat(int fieldNumber, double value) {
    writeTag(fieldNumber, 5);
    final b = ByteData(4)..setFloat32(0, value, Endian.little);
    _buffer.add(b.buffer.asUint8List());
  }

  Uint8List takeBytes() => _buffer.toBytes();
}

/// Minimal, zero-dependency, ultra-fast Protobuf binary wire decoder.
class ProtoReader {
  final Uint8List _data;
  int _pos = 0;

  ProtoReader(this._data);

  bool get hasMore => _pos < _data.length;

  int readVarint() {
    int result = 0;
    int shift = 0;
    while (_pos < _data.length) {
      final b = _data[_pos++];
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    return result;
  }

  (int fieldNumber, int wireType)? readTag() {
    if (!hasMore) return null;
    final tag = readVarint();
    return (tag >> 3, tag & 0x07);
  }

  String readString() {
    final length = readVarint();
    if (_pos + length > _data.length) return '';
    final bytes = _data.sublist(_pos, _pos + length);
    _pos += length;
    return utf8.decode(bytes, allowMalformed: true);
  }

  Uint8List readBytes() {
    final length = readVarint();
    if (_pos + length > _data.length) return Uint8List(0);
    final bytes = _data.sublist(_pos, _pos + length);
    _pos += length;
    return Uint8List.fromList(bytes);
  }

  int readInt64() => readVarint();

  bool readBool() => readVarint() != 0;

  double readFloat() {
    if (_pos + 4 > _data.length) return 0.0;
    final bd = ByteData.sublistView(_data, _pos, _pos + 4);
    _pos += 4;
    return bd.getFloat32(0, Endian.little);
  }

  void skipField(int wireType) {
    if (wireType == 0) {
      readVarint();
    } else if (wireType == 2) {
      final len = readVarint();
      _pos = (_pos + len).clamp(0, _data.length);
    } else if (wireType == 1) {
      _pos = (_pos + 8).clamp(0, _data.length);
    } else if (wireType == 5) {
      _pos = (_pos + 4).clamp(0, _data.length);
    }
  }
}

/// Metrolist protobuf wire codec implementation.
class ListenTogetherProtoCodec {
  static const int compressionThreshold = 100;

  static List<int> encodeEnvelope(String type, List<int> payloadBytes,
      {bool compressed = false}) {
    List<int> finalPayload = payloadBytes;
    bool isCompressed = false;
    if (compressed && payloadBytes.length > compressionThreshold) {
      try {
        final gzipped = gzip.encode(payloadBytes);
        if (gzipped.length < payloadBytes.length) {
          finalPayload = gzipped;
          isCompressed = true;
        }
      } catch (_) {}
    }

    final writer = ProtoWriter();
    writer.writeString(1, type);
    if (finalPayload.isNotEmpty) {
      writer.writeBytes(2, finalPayload);
    }
    if (isCompressed) {
      writer.writeBool(3, true);
    }
    return writer.takeBytes();
  }

  static (String type, Uint8List payload)? decodeEnvelope(Uint8List data) {
    try {
      final reader = ProtoReader(data);
      String? type;
      Uint8List? payload;
      bool compressed = false;

      while (reader.hasMore) {
        final tag = reader.readTag();
        if (tag == null) break;
        if (tag.$1 == 1) {
          type = reader.readString();
        } else if (tag.$1 == 2) {
          payload = reader.readBytes();
        } else if (tag.$1 == 3) {
          compressed = reader.readBool();
        } else {
          reader.skipField(tag.$2);
        }
      }

      if (type == null) return null;
      var rawPayload = payload ?? Uint8List(0);
      if (compressed && rawPayload.isNotEmpty) {
        try {
          rawPayload = Uint8List.fromList(gzip.decode(rawPayload));
        } catch (_) {}
      }
      return (type, rawPayload);
    } catch (_) {
      return null;
    }
  }

  // --- Encoders ---

  static List<int> encodeClientCapabilities({
    bool supportsProtobuf = true,
    bool supportsCompression = true,
    String clientVersion = '3.0.8',
  }) {
    final w = ProtoWriter()
      ..writeBool(1, supportsProtobuf)
      ..writeBool(2, supportsCompression)
      ..writeString(3, clientVersion);
    return encodeEnvelope('client_capabilities', w.takeBytes());
  }

  static List<int> encodeCreateRoom(String username) {
    final w = ProtoWriter()..writeString(1, username);
    return encodeEnvelope('create_room', w.takeBytes());
  }

  static List<int> encodeJoinRoom(String roomCode, String username) {
    final w = ProtoWriter()
      ..writeString(1, roomCode.toUpperCase())
      ..writeString(2, username);
    return encodeEnvelope('join_room', w.takeBytes());
  }

  static List<int> encodeApproveJoin(String userId) {
    final w = ProtoWriter()..writeString(1, userId);
    return encodeEnvelope('approve_join', w.takeBytes());
  }

  static List<int> encodeRejectJoin(String userId, [String reason = '']) {
    final w = ProtoWriter()
      ..writeString(1, userId)
      ..writeString(2, reason);
    return encodeEnvelope('reject_join', w.takeBytes());
  }

  static List<int> encodeLeaveRoom() {
    return encodeEnvelope('leave_room', Uint8List(0));
  }

  static List<int> encodePing(int clientTime, int sequence) {
    final w = ProtoWriter()
      ..writeInt64(1, clientTime)
      ..writeInt64(2, sequence);
    return encodeEnvelope('ping', w.takeBytes());
  }

  static List<int> encodeBufferReady(String trackId) {
    final w = ProtoWriter()..writeString(1, trackId);
    return encodeEnvelope('buffer_ready', w.takeBytes());
  }

  static List<int> encodeReconnect(String sessionToken) {
    final w = ProtoWriter()..writeString(1, sessionToken);
    return encodeEnvelope('reconnect', w.takeBytes());
  }

  static List<int> encodeRequestSync() {
    return encodeEnvelope('request_sync', Uint8List(0));
  }

  static List<int> encodePlaybackAction({
    required String action,
    String? trackId,
    int? position,
    Map<String, dynamic>? trackInfo,
    bool isPlaying = true,
    int? serverTime,
    int? revision,
    String envelopeType = 'playback_action',
  }) {
    final w = ProtoWriter();
    w.writeString(1, action);
    if (trackId != null) w.writeString(2, trackId);
    if (position != null) w.writeInt64(3, position);
    if (trackInfo != null) {
      final tw = ProtoWriter();
      tw.writeString(1, trackInfo['id'] ?? '');
      tw.writeString(2, trackInfo['title'] ?? '');
      tw.writeString(3, trackInfo['artist'] ?? '');
      tw.writeString(4, trackInfo['album'] ?? '');
      tw.writeInt64(5, trackInfo['duration'] ?? trackInfo['duration_ms'] ?? trackInfo['durationMs'] ?? 0);
      tw.writeString(6, trackInfo['thumbnail'] ?? trackInfo['thumbnail_url'] ?? trackInfo['thumbnailUrl'] ?? '');
      w.writeBytes(4, tw.takeBytes());
    }
    w.writeBool(5, isPlaying);
    if (serverTime != null) {
      w.writeInt64(9, serverTime);
    }
    if (revision != null) {
      w.writeInt64(6, revision);
      w.writeInt64(10, revision);
    }
    return encodeEnvelope(envelopeType, w.takeBytes());
  }

  // --- Decoders ---

  static Map<String, dynamic> decodeError(Uint8List payload) {
    final r = ProtoReader(payload);
    String code = 'error';
    String message = 'An error occurred';
    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) {
        code = r.readString();
      } else if (t.$1 == 2) {
        message = r.readString();
      } else {
        r.skipField(t.$2);
      }
    }
    return {'code': code, 'message': message};
  }

  static Map<String, dynamic> decodeServerCapabilities(Uint8List payload) {
    final r = ProtoReader(payload);
    bool supportsProtobuf = false;
    bool supportsCompression = false;
    String serverVersion = '';
    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) {
        supportsProtobuf = r.readBool();
      } else if (t.$1 == 2) {
        supportsCompression = r.readBool();
      } else if (t.$1 == 3) {
        serverVersion = r.readString();
      } else {
        r.skipField(t.$2);
      }
    }
    return {
      'supports_protobuf': supportsProtobuf,
      'supports_compression': supportsCompression,
      'server_version': serverVersion,
    };
  }

  static Map<String, dynamic> decodeJoinRequest(Uint8List payload) {
    final r = ProtoReader(payload);
    String userId = '';
    String username = '';
    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) {
        userId = r.readString();
      } else if (t.$1 == 2) {
        username = r.readString();
      } else {
        r.skipField(t.$2);
      }
    }
    return {'user_id': userId, 'username': username};
  }

  static Map<String, dynamic> decodeJoinRejected(Uint8List payload) {
    final r = ProtoReader(payload);
    String reason = 'Join rejected by host';
    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) {
        reason = r.readString();
      } else {
        r.skipField(t.$2);
      }
    }
    return {'reason': reason};
  }

  static Map<String, dynamic> decodeRoomCreated(Uint8List payload) {
    final r = ProtoReader(payload);
    String roomCode = '';
    String userId = '';
    String sessionToken = '';
    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) roomCode = r.readString();
      else if (t.$1 == 2) userId = r.readString();
      else if (t.$1 == 3) sessionToken = r.readString();
      else r.skipField(t.$2);
    }
    return {
      'room_code': roomCode,
      'user_id': userId,
      'session_token': sessionToken,
    };
  }

  static Map<String, dynamic> decodeJoinApproved(Uint8List payload) {
    final r = ProtoReader(payload);
    String roomCode = '';
    String userId = '';
    String sessionToken = '';
    Map<String, dynamic>? state;

    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) roomCode = r.readString();
      else if (t.$1 == 2) userId = r.readString();
      else if (t.$1 == 3) sessionToken = r.readString();
      else if (t.$1 == 4) state = decodeRoomState(r.readBytes());
      else r.skipField(t.$2);
    }
    return {
      'room_code': roomCode,
      'user_id': userId,
      'session_token': sessionToken,
      'state': state,
    };
  }

  static Map<String, dynamic> decodeRoomState(Uint8List bytes) {
    final r = ProtoReader(bytes);
    String roomCode = '';
    String hostId = '';
    final List<Map<String, dynamic>> users = [];
    Map<String, dynamic>? currentTrack;
    bool isPlaying = true;
    int position = 0;
    int lastUpdate = 0;
    double volume = 1.0;

    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) roomCode = r.readString();
      else if (t.$1 == 2) hostId = r.readString();
      else if (t.$1 == 3) users.add(decodeUserInfo(r.readBytes()));
      else if (t.$1 == 4) currentTrack = decodeTrackInfo(r.readBytes());
      else if (t.$1 == 5) isPlaying = r.readBool();
      else if (t.$1 == 6) position = r.readInt64();
      else if (t.$1 == 7) lastUpdate = r.readInt64();
      else if (t.$1 == 8) volume = r.readFloat();
      else if (t.$1 == 10) isPlaying = r.readInt64() != 0;
      else r.skipField(t.$2);
    }

    return {
      'room_code': roomCode,
      'host_id': hostId,
      'users': users,
      'current_track': currentTrack,
      'is_playing': isPlaying,
      'position': position,
      'last_update': lastUpdate,
      'volume': volume,
    };
  }

  static Map<String, dynamic> decodeSyncState(Uint8List payload) {
    final r = ProtoReader(payload);
    Map<String, dynamic>? currentTrack;
    int position = 0;
    int lastUpdate = 0;
    double volume = 1.0;
    bool isPlaying = true;
    int revision = 0;

    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) {
        currentTrack = decodeTrackInfo(r.readBytes());
      } else if (t.$1 == 2) {
        position = r.readInt64();
      } else if (t.$1 == 4) {
        lastUpdate = r.readInt64();
      } else if (t.$1 == 6) {
        volume = r.readFloat();
      } else if (t.$1 == 7) {
        isPlaying = r.readInt64() != 0;
      } else if (t.$1 == 8 || t.$1 == 10) {
        revision = r.readInt64();
      } else {
        r.skipField(t.$2);
      }
    }

    return {
      'current_track': currentTrack,
      'is_playing': isPlaying,
      'position': position,
      'last_update': lastUpdate,
      'volume': volume,
      'revision': revision,
    };
  }

  static Map<String, dynamic> decodeUserInfo(Uint8List bytes) {
    final r = ProtoReader(bytes);
    String userId = '';
    String username = '';
    bool isHost = false;
    bool isConnected = true;

    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) userId = r.readString();
      else if (t.$1 == 2) username = r.readString();
      else if (t.$1 == 3) isHost = r.readBool();
      else if (t.$1 == 4) isConnected = r.readBool();
      else r.skipField(t.$2);
    }

    return {
      'user_id': userId,
      'username': username,
      'is_host': isHost,
      'is_connected': isConnected,
    };
  }

  static Map<String, dynamic> decodeTrackInfo(Uint8List bytes) {
    final r = ProtoReader(bytes);
    String id = '';
    String title = '';
    String artist = '';
    String album = '';
    int duration = 0;
    String thumbnail = '';

    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) id = r.readString();
      else if (t.$1 == 2) title = r.readString();
      else if (t.$1 == 3) artist = r.readString();
      else if (t.$1 == 4) album = r.readString();
      else if (t.$1 == 5) duration = r.readInt64();
      else if (t.$1 == 6) thumbnail = r.readString();
      else r.skipField(t.$2);
    }

    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'thumbnail': thumbnail,
    };
  }

  static Map<String, dynamic> decodePong(Uint8List payload) {
    final r = ProtoReader(payload);
    int clientTime = 0;
    int serverReceiveTime = 0;
    int serverSendTime = 0;
    int sequence = 0;

    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) clientTime = r.readInt64();
      else if (t.$1 == 2) serverReceiveTime = r.readInt64();
      else if (t.$1 == 3) serverSendTime = r.readInt64();
      else if (t.$1 == 4) sequence = r.readInt64();
      else r.skipField(t.$2);
    }

    return {
      'client_time': clientTime,
      'server_receive_time': serverReceiveTime,
      'server_send_time': serverSendTime,
      'sequence': sequence,
    };
  }

  static Map<String, dynamic> decodeUserJoined(Uint8List payload) {
    final r = ProtoReader(payload);
    String userId = '';
    String username = '';

    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) userId = r.readString();
      else if (t.$1 == 2) username = r.readString();
      else r.skipField(t.$2);
    }

    return {
      'user_id': userId,
      'username': username,
      'is_host': false,
      'is_connected': true,
    };
  }

  static Map<String, dynamic> decodeUserLeft(Uint8List payload) {
    final r = ProtoReader(payload);
    String userId = '';
    String username = '';

    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) userId = r.readString();
      else if (t.$1 == 2) username = r.readString();
      else r.skipField(t.$2);
    }

    return {
      'user_id': userId,
      'username': username,
    };
  }

  static Map<String, dynamic> decodePlaybackAction(Uint8List payload) {
    final r = ProtoReader(payload);
    String action = '';
    String trackId = '';
    int position = 0;
    Map<String, dynamic>? trackInfo;
    bool isPlaying = true;
    int serverTime = 0;
    int revision = 0;

    while (r.hasMore) {
      final t = r.readTag();
      if (t == null) break;
      if (t.$1 == 1) action = r.readString();
      else if (t.$1 == 2) trackId = r.readString();
      else if (t.$1 == 3) position = r.readInt64();
      else if (t.$1 == 4) trackInfo = decodeTrackInfo(r.readBytes());
      else if (t.$1 == 5) isPlaying = r.readBool();
      else if (t.$1 == 9) serverTime = r.readInt64();
      else if (t.$1 == 6 || t.$1 == 10) revision = r.readInt64();
      else r.skipField(t.$2);
    }

    return {
      'action': action,
      'track_id': trackId,
      'position': position,
      'track_info': trackInfo,
      'is_playing': isPlaying,
      'server_time': serverTime,
      'revision': revision,
    };
  }
}
