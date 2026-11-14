import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Device category in the Softify Connect cluster.
enum ConnectDeviceType {
  desktop,
  smartphone,
  tablet,
  speaker,
}

/// Information about a discovered device in the Softify Connect cluster.
class ConnectDevice {
  final String deviceId;
  final String name;
  final ConnectDeviceType type;
  final String ipAddress;
  final int port;
  final bool isActivePlayer;
  final double volume;
  final DateTime lastSeen;

  const ConnectDevice({
    required this.deviceId,
    required this.name,
    required this.type,
    required this.ipAddress,
    required this.port,
    this.isActivePlayer = false,
    this.volume = 1.0,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'name': name,
        'type': type.name,
        'ipAddress': ipAddress,
        'port': port,
        'isActivePlayer': isActivePlayer,
        'volume': volume,
        'timestamp': lastSeen.millisecondsSinceEpoch,
      };

  factory ConnectDevice.fromJson(Map<String, dynamic> json, String remoteIp) {
    return ConnectDevice(
      deviceId: json['deviceId'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Softify Device',
      type: ConnectDeviceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ConnectDeviceType.desktop,
      ),
      ipAddress: remoteIp,
      port: (json['port'] as num?)?.toInt() ?? 4070,
      isActivePlayer: json['isActivePlayer'] as bool? ?? false,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      lastSeen: DateTime.now(),
    );
  }
}

/// Remote command packet transmitted over local network between Connect nodes.
class ConnectCommand {
  final String command; // 'play', 'pause', 'seek', 'volume', 'transfer'
  final Map<String, dynamic> payload;

  const ConnectCommand({required this.command, required this.payload});

  Map<String, dynamic> toJson() => {
        'command': command,
        'payload': payload,
      };
}

/// Spotify Connect-style local cluster discovery and remote playback service.
/// Coordinates peer-to-peer playback handoff and remote control on local WiFi.
class SoftifyConnectService {
  static final SoftifyConnectService instance =
      SoftifyConnectService._internal();

  SoftifyConnectService._internal();

  static const int broadcastPort = 4070;
  RawDatagramSocket? _socket;
  Timer? _beaconTimer;

  String _localDeviceId = '';
  String _localDeviceName = 'Softify Device';
  ConnectDeviceType _localDeviceType = ConnectDeviceType.desktop;
  bool _isLocalActivePlayer = true;
  double _localVolume = 1.0;

  final Map<String, ConnectDevice> _clusterDevices = {};
  final _devicesController =
      StreamController<List<ConnectDevice>>.broadcast();
  final _commandController = StreamController<ConnectCommand>.broadcast();

  Stream<List<ConnectDevice>> get devicesStream => _devicesController.stream;
  Stream<ConnectCommand> get commandStream => _commandController.stream;
  List<ConnectDevice> get activeCluster => _clusterDevices.values.toList();
  bool get isLocalActivePlayer => _isLocalActivePlayer;

  /// Initializes the Connect node on local network.
  Future<void> initialize({
    required String deviceId,
    required String deviceName,
    required ConnectDeviceType deviceType,
  }) async {
    _localDeviceId = deviceId;
    _localDeviceName = deviceName;
    _localDeviceType = deviceType;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        broadcastPort,
        reuseAddress: true,
        reusePort: true,
      );
      _socket?.broadcastEnabled = true;

      _socket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _handleIncomingPacket(datagram);
          }
        }
      });

      // Periodic mDNS/UDP beacon every 3 seconds (spirc_hello)
      _beaconTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _broadcastHello();
        _purgeStaleDevices();
      });

      _broadcastHello();
    } catch (_) {
      // In restricted sandbox environments, socket binding fails gracefully
    }
  }

  void updateLocalPlayerState({required bool isActive, required double volume}) {
    _isLocalActivePlayer = isActive;
    _localVolume = volume;
    _broadcastHello();
  }

  void _broadcastHello() {
    if (_socket == null || _localDeviceId.isEmpty) return;

    final payload = jsonEncode({
      'type': 'spirc_hello',
      'device': {
        'deviceId': _localDeviceId,
        'name': _localDeviceName,
        'type': _localDeviceType.name,
        'port': broadcastPort,
        'isActivePlayer': _isLocalActivePlayer,
        'volume': _localVolume,
      }
    });

    try {
      final bytes = utf8.encode(payload);
      _socket?.send(bytes, InternetAddress('255.255.255.255'), broadcastPort);
    } catch (_) {}
  }

  void _handleIncomingPacket(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'spirc_hello') {
        final devData = json['device'] as Map<String, dynamic>?;
        if (devData != null) {
          final remoteId = devData['deviceId'] as String?;
          if (remoteId != null && remoteId != _localDeviceId) {
            final device = ConnectDevice.fromJson(devData, datagram.address.address);
            _clusterDevices[remoteId] = device;
            _devicesController.add(_clusterDevices.values.toList());
          }
        }
      } else if (type == 'spirc_command') {
        final targetId = json['targetDeviceId'] as String?;
        if (targetId == null || targetId == _localDeviceId) {
          final cmd = json['command'] as String? ?? '';
          final payload = json['payload'] as Map<String, dynamic>? ?? {};
          _commandController.add(ConnectCommand(command: cmd, payload: payload));
        }
      }
    } catch (_) {}
  }

  /// Sends a remote command to a target device or the active player.
  void sendCommand(String targetDeviceId, String command, Map<String, dynamic> payload) {
    if (_socket == null) return;

    final target = _clusterDevices[targetDeviceId];
    if (target == null) return;

    final message = jsonEncode({
      'type': 'spirc_command',
      'targetDeviceId': targetDeviceId,
      'senderDeviceId': _localDeviceId,
      'command': command,
      'payload': payload,
    });

    try {
      final bytes = utf8.encode(message);
      _socket?.send(bytes, InternetAddress(target.ipAddress), target.port);
    } catch (_) {}
  }

  /// Initiates seamless cross-device playback transfer with monotonic timestamp.
  void transferPlaybackTo(String targetDeviceId, {
    required String trackId,
    required int positionMs,
    required double speed,
  }) {
    sendCommand(targetDeviceId, 'transferPlayback', {
      'trackId': trackId,
      'positionMs': positionMs,
      'speed': speed,
      'transferTimestamp': DateTime.now().millisecondsSinceEpoch,
    });
    _isLocalActivePlayer = false;
    _broadcastHello();
  }

  void _purgeStaleDevices() {
    final now = DateTime.now();
    bool changed = false;
    _clusterDevices.removeWhere((id, dev) {
      if (now.difference(dev.lastSeen).inSeconds > 10) {
        changed = true;
        return true;
      }
      return false;
    });
    if (changed) {
      _devicesController.add(_clusterDevices.values.toList());
    }
  }

  void dispose() {
    _beaconTimer?.cancel();
    _socket?.close();
    _devicesController.close();
    _commandController.close();
  }
}
