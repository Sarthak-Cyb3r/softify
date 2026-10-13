import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/entities/track.dart';

/// Lightweight Discord Rich Presence implementation communicating via
/// local Unix domain sockets (Linux/macOS) with zero third-party packages or developer tokens.
class DiscordRpcService {
  static const String defaultClientId = '1225849845771767909';

  final String clientId;
  Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  int _nonceCounter = 0;
  Timer? _reconnectTimer;

  DiscordRpcService({this.clientId = defaultClientId});

  bool get isConnected => _isConnected;

  /// Initializes and attempts connection to local Discord client.
  Future<void> connect() async {
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      return; // Only desktop environments have local Discord IPC
    }

    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      final socketPath = _findIpcSocket();
      if (socketPath == null) {
        _isConnecting = false;
        return;
      }

      _socket = await Socket.connect(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
        timeout: const Duration(milliseconds: 1500),
      );

      _socket!.listen(
        _onData,
        onError: (err) => _disconnect(),
        onDone: () => _disconnect(),
        cancelOnError: true,
      );

      // Send Handshake packet (Opcode 0)
      _sendPacket(0, {'v': 1, 'client_id': clientId});
      _isConnected = true;
    } catch (_) {
      _disconnect();
    } finally {
      _isConnecting = false;
    }
  }

  /// Locates the active Discord IPC socket file.
  String? _findIpcSocket() {
    if (Platform.isLinux || Platform.isMacOS) {
      final runtimeDir = Platform.environment['XDG_RUNTIME_DIR'];
      final tmpDir = Platform.environment['TMPDIR'] ?? '/tmp';

      final candidates = [
        if (runtimeDir != null) runtimeDir,
        tmpDir,
      ];

      for (final dir in candidates) {
        for (int i = 0; i < 10; i++) {
          final file = File('$dir/discord-ipc-$i');
          if (file.existsSync()) {
            return file.path;
          }
        }
      }
    }
    return null;
  }

  void _onData(Uint8List data) {
    // Discord responses are acknowledged silently
  }

  void _sendPacket(int opcode, Map<String, dynamic> payload) {
    if (_socket == null) return;
    try {
      final jsonBytes = utf8.encode(jsonEncode(payload));
      final header = ByteData(8);
      header.setInt32(0, opcode, Endian.little);
      header.setInt32(4, jsonBytes.length, Endian.little);

      final fullPacket = Uint8List(8 + jsonBytes.length)
        ..setRange(0, 8, header.buffer.asUint8List())
        ..setRange(8, 8 + jsonBytes.length, jsonBytes);

      _socket!.add(fullPacket);
      _socket!.flush().catchError((_) {});
    } catch (_) {
      _disconnect();
    }
  }

  /// Updates Discord user presence to reflect the actively playing song.
  Future<void> updatePresence({
    required Track? track,
    required bool isPlaying,
    Duration position = Duration.zero,
  }) async {
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      return;
    }

    if (!_isConnected) {
      await connect();
      if (!_isConnected) return;
    }

    _nonceCounter++;
    final nonce = 'softify_$_nonceCounter';

    if (track == null || !isPlaying) {
      // Clear rich presence
      _sendPacket(1, {
        'cmd': 'SET_ACTIVITY',
        'args': {
          'pid': pid,
          'activity': null,
        },
        'nonce': nonce,
      });
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final startSec = now - position.inSeconds;
    final remainingSec = track.duration.inSeconds - position.inSeconds;
    final endSec = remainingSec > 0 ? now + remainingSec : null;

    final activity = {
      'details': track.title,
      'state': 'by ${track.artist}',
      'timestamps': {
        'start': startSec,
        if (endSec != null) 'end': endSec,
      },
      'assets': {
        'large_image': 'softify_logo',
        'large_text': 'Softify Music',
        'small_image': isPlaying ? 'play' : 'pause',
        'small_text': isPlaying ? 'Playing' : 'Paused',
      },
      'instance': false,
    };

    _sendPacket(1, {
      'cmd': 'SET_ACTIVITY',
      'args': {
        'pid': pid,
        'activity': activity,
      },
      'nonce': nonce,
    });
  }

  void _disconnect() {
    _isConnected = false;
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _disconnect();
  }
}
