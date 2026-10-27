import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Mobile emulation metadata simulating the official Discord Android client.
/// Reverse-engineered from Metrolist (DiscordSuperProperties.kt).
class DiscordSuperProperties {
  final String os;
  final String browser;
  final String device;
  final String clientVersion;
  final String releaseChannel;
  final String systemLocale;
  final String osVersion;
  final int clientBuildNumber;

  const DiscordSuperProperties({
    this.os = 'Android',
    this.browser = 'Discord Android',
    this.device = 'Mobile',
    this.clientVersion = '220.0',
    this.releaseChannel = 'googleRelease',
    this.systemLocale = 'en-US',
    this.osVersion = '34',
    this.clientBuildNumber = 220015,
  });

  factory DiscordSuperProperties.android() => const DiscordSuperProperties();

  factory DiscordSuperProperties.fromJson(Map<String, dynamic> json) {
    return DiscordSuperProperties(
      os: json['os'] as String? ?? 'Android',
      browser: json['browser'] as String? ?? 'Discord Android',
      device: json['device'] as String? ?? 'Mobile',
      clientVersion: json['client_version'] as String? ?? '220.0',
      releaseChannel: json['release_channel'] as String? ?? 'googleRelease',
      systemLocale: json['system_locale'] as String? ?? 'en-US',
      osVersion: json['os_version'] as String? ?? '34',
      clientBuildNumber: json['client_build_number'] as int? ?? 220015,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'os': os,
      'browser': browser,
      'device': device,
      'system_locale': systemLocale,
      'client_version': clientVersion,
      'release_channel': releaseChannel,
      'device_vendor_id': '00000000-0000-0000-0000-000000000000',
      'os_version': osVersion,
      'client_build_number': clientBuildNumber,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  String toBase64() {
    return base64Encode(utf8.encode(jsonEncode(toMap())));
  }
}

/// Abstract representation of a WebSocket channel to enable deterministic unit testing.
abstract class IDiscordWebSocket {
  Stream<dynamic> get stream;
  void send(String data);
  Future<void> close([int? code, String? reason]);
}

/// Production implementation of [IDiscordWebSocket] backed by [dart:io.WebSocket].
class IoDiscordWebSocket implements IDiscordWebSocket {
  final WebSocket _webSocket;

  IoDiscordWebSocket(this._webSocket);

  @override
  Stream<dynamic> get stream => _webSocket;

  @override
  void send(String data) => _webSocket.add(data);

  @override
  Future<void> close([int? code, String? reason]) => _webSocket.close(code, reason);
}

typedef DiscordSocketConnector = Future<IDiscordWebSocket> Function(Uri uri);

enum DiscordGatewayStatus {
  disconnected,
  connecting,
  connected,
  identifying,
  ready,
  reconnecting,
}

/// Direct Discord Mobile Gateway WebSocket RPC service.
/// Connects directly to Discord's Gateway v9 (wss://gateway.discord.gg/?v=9&encoding=json)
/// without requiring a local desktop Discord IPC socket or companion daemon.
class DiscordGatewayService {
  static const String defaultGatewayUrl = 'wss://gateway.discord.gg/?v=9&encoding=json';
  static const String appName = 'Softify';
  static const String defaultSmallImage = 'softify_logo';
  static const String defaultSmallText = 'Softify StudioMaster 320kbps';

  // Discord Gateway Opcodes
  static const int opDispatch = 0;
  static const int opHeartbeat = 1;
  static const int opIdentify = 2;
  static const int opPresenceUpdate = 3;
  static const int opResume = 6;
  static const int opReconnect = 7;
  static const int opInvalidSession = 9;
  static const int opHello = 10;
  static const int opHeartbeatAck = 11;

  // Discord Activity Types
  static const int activityGame = 0;
  static const int activityStreaming = 1;
  static const int activityListening = 2;
  static const int activityWatching = 3;
  static const int activityCustom = 4;
  static const int activityCompeting = 5;

  final String gatewayUrl;
  final DiscordSuperProperties superProperties;
  final DiscordSocketConnector socketConnector;
  final double? fixedJitter; // For unit tests

  String? _userToken;
  IDiscordWebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;

  DiscordGatewayStatus _status = DiscordGatewayStatus.disconnected;
  final StreamController<DiscordGatewayStatus> _statusController =
      StreamController<DiscordGatewayStatus>.broadcast();

  int? _lastSequenceNumber;
  String? _sessionId;
  int _heartbeatIntervalMs = 41250;
  Timer? _heartbeatTimer;
  Timer? _initialHeartbeatTimer;
  Timer? _reconnectTimer;

  bool _lastHeartbeatAcked = true;
  bool _hasReceivedFirstAck = false;
  bool _isDisposed = false;
  bool _intentionalDisconnect = false;

  // Cached presence for auto-reconnect restoration
  Map<String, dynamic>? _lastPresencePayload;

  DiscordGatewayService({
    this.gatewayUrl = defaultGatewayUrl,
    DiscordSuperProperties? superProperties,
    DiscordSocketConnector? socketConnector,
    this.fixedJitter,
  })  : superProperties = superProperties ?? DiscordSuperProperties.android(),
        socketConnector = socketConnector ?? _defaultConnector;

  static Future<IDiscordWebSocket> _defaultConnector(Uri uri) async {
    final ws = await WebSocket.connect(uri.toString());
    return IoDiscordWebSocket(ws);
  }

  DiscordGatewayStatus get status => _status;
  Stream<DiscordGatewayStatus> get statusStream => _statusController.stream;
  bool get isConnected =>
      _status == DiscordGatewayStatus.ready || _status == DiscordGatewayStatus.connected;
  bool get isConnecting =>
      _status == DiscordGatewayStatus.connecting ||
      _status == DiscordGatewayStatus.identifying ||
      _status == DiscordGatewayStatus.reconnecting;
  int? get lastSequenceNumber => _lastSequenceNumber;
  String? get sessionId => _sessionId;
  int get heartbeatIntervalMs => _heartbeatIntervalMs;
  bool get lastHeartbeatAcked => _lastHeartbeatAcked;

  void _setStatus(DiscordGatewayStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      if (!_statusController.isClosed) {
        _statusController.add(newStatus);
      }
    }
  }

  /// Calculates the jittered initial heartbeat delay according to Discord specifications.
  static int calculateJitteredHeartbeat(int intervalMs, [double? jitter]) {
    final j = (jitter ?? math.Random().nextDouble()).clamp(0.0, 1.0);
    return (intervalMs * j).round();
  }

  /// Builds the Identify (Opcode 2) payload containing DiscordSuperProperties mobile emulation.
  Map<String, dynamic> buildIdentifyPayload(String token, {Map<String, dynamic>? initialPresence}) {
    return {
      'op': opIdentify,
      'd': {
        'token': token,
        'properties': superProperties.toMap(),
        'presence': initialPresence ??
            {
              'status': 'online',
              'since': 0,
              'activities': [],
              'afk': false,
            },
        'compress': false,
      },
    };
  }

  /// Builds the Heartbeat (Opcode 1) payload.
  Map<String, dynamic> buildHeartbeatPayload([int? sequenceNumber]) {
    return {
      'op': opHeartbeat,
      'd': sequenceNumber ?? _lastSequenceNumber,
    };
  }

  /// Builds the Listening Activity Presence Update (Opcode 3) payload.
  Map<String, dynamic> buildPresencePayload({
    required String title,
    required String artist,
    String? album,
    String? coverUrl,
    int? positionMs,
    int? durationMs,
    bool isPlaying = true,
    int? currentTimeMs,
  }) {
    if (!isPlaying) {
      return {
        'op': opPresenceUpdate,
        'd': {
          'since': 0,
          'activities': [],
          'status': 'online',
          'afk': false,
        },
      };
    }

    final now = currentTimeMs ?? DateTime.now().millisecondsSinceEpoch;
    final int start = positionMs != null ? (now - positionMs) : now;
    final int? end = (durationMs != null && positionMs != null)
        ? (now + (durationMs - positionMs))
        : (durationMs != null ? (now + durationMs) : null);

    final Map<String, dynamic> timestamps = {
      'start': start,
      if (end != null) 'end': end,
    };

    final Map<String, dynamic> activity = {
      'name': appName,
      'type': activityListening, // 2 = Listening
      'details': title,
      'state': artist,
      'timestamps': timestamps,
      'assets': {
        'large_image': (coverUrl != null && coverUrl.isNotEmpty) ? coverUrl : defaultSmallImage,
        'large_text': (album != null && album.isNotEmpty) ? album : title,
        'small_image': defaultSmallImage,
        'small_text': defaultSmallText,
      },
    };

    return {
      'op': opPresenceUpdate,
      'd': {
        'since': 0,
        'activities': [activity],
        'status': 'online',
        'afk': false,
      },
    };
  }

  /// Connects to the Discord Gateway using the provided user auth token.
  Future<void> connect({required String token}) async {
    if (_isDisposed) return;
    _userToken = token;
    _intentionalDisconnect = false;

    if (isConnected || _status == DiscordGatewayStatus.connecting) {
      return;
    }

    _setStatus(DiscordGatewayStatus.connecting);

    try {
      final uri = Uri.parse(gatewayUrl);
      _socket = await socketConnector(uri);

      _socketSubscription = _socket!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );

      _setStatus(DiscordGatewayStatus.connected);
    } catch (e) {
      _setStatus(DiscordGatewayStatus.disconnected);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic rawMessage) {
    if (_isDisposed) return;

    try {
      final String text = rawMessage is String ? rawMessage : utf8.decode(rawMessage as List<int>);
      final Map<String, dynamic> data = jsonDecode(text) as Map<String, dynamic>;

      final int op = data['op'] as int? ?? -1;
      final int? seq = data['s'] as int?;
      if (seq != null) {
        _lastSequenceNumber = seq;
      }

      switch (op) {
        case opHello:
          _handleHello(data['d'] as Map<String, dynamic>? ?? {});
          break;
        case opHeartbeatAck:
          _lastHeartbeatAcked = true;
          _hasReceivedFirstAck = true;
          break;
        case opHeartbeat:
          // Gateway requested immediate heartbeat
          _sendHeartbeat();
          break;
        case opReconnect:
          _handleReconnectRequest();
          break;
        case opInvalidSession:
          _handleInvalidSession();
          break;
        case opDispatch:
          _handleDispatch(data['t'] as String?, data['d']);
          break;
      }
    } catch (_) {
      // Discard malformed packets
    }
  }

  void _handleHello(Map<String, dynamic> payload) {
    final int interval = payload['heartbeat_interval'] as int? ?? 41250;
    _heartbeatIntervalMs = interval;
    _lastHeartbeatAcked = true;
    _hasReceivedFirstAck = false;

    _startHeartbeatWatchdog(interval);

    // After Hello, send Identify
    if (_userToken != null && _userToken!.isNotEmpty) {
      _sendIdentify();
    }
  }

  void _startHeartbeatWatchdog(int intervalMs) {
    _heartbeatTimer?.cancel();
    _initialHeartbeatTimer?.cancel();

    // Jitter initial heartbeat delay according to Discord spec
    final initialDelayMs = calculateJitteredHeartbeat(intervalMs, fixedJitter);

    _initialHeartbeatTimer = Timer(Duration(milliseconds: initialDelayMs), () {
      if (_isDisposed || _socket == null) return;
      _sendHeartbeat();

      // Start regular periodic heartbeat
      _heartbeatTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
        if (_isDisposed || _socket == null) return;

        // ACK Watchdog: Check if the previous heartbeat was acknowledged
        if (_hasReceivedFirstAck && !_lastHeartbeatAcked) {
          // Connection is a zombie - close and reconnect
          _cleanupSocket(4000, 'Heartbeat ACK timeout');
          _scheduleReconnect();
          return;
        }

        _sendHeartbeat();
      });
    });
  }

  void _sendHeartbeat() {
    if (_socket == null) return;
    _lastHeartbeatAcked = false;
    final payload = buildHeartbeatPayload(_lastSequenceNumber);
    _sendJson(payload);
  }

  void _sendIdentify() {
    if (_socket == null || _userToken == null) return;
    _setStatus(DiscordGatewayStatus.identifying);
    final payload = buildIdentifyPayload(_userToken!, initialPresence: _lastPresencePayload);
    _sendJson(payload);
  }

  void _handleDispatch(String? eventName, dynamic eventData) {
    if (eventName == 'READY') {
      if (eventData is Map<String, dynamic>) {
        _sessionId = eventData['session_id'] as String?;
      }
      _setStatus(DiscordGatewayStatus.ready);

      // Re-send cached presence if any
      if (_lastPresencePayload != null) {
        _sendJson(_lastPresencePayload!);
      }
    } else if (eventName == 'RESUMED') {
      _setStatus(DiscordGatewayStatus.ready);
    }
  }

  void _handleReconnectRequest() {
    _cleanupSocket();
    _scheduleReconnect();
  }

  void _handleInvalidSession() {
    _sessionId = null;
    _lastSequenceNumber = null;
    _cleanupSocket();
    _scheduleReconnect();
  }

  void _sendJson(Map<String, dynamic> data) {
    if (_socket != null) {
      try {
        _socket!.send(jsonEncode(data));
      } catch (_) {}
    }
  }

  /// Updates Discord Rich Presence with current listening track.
  Future<void> updatePresence({
    required String title,
    required String artist,
    String? album,
    String? coverUrl,
    int? positionMs,
    int? durationMs,
    bool isPlaying = true,
  }) async {
    final payload = buildPresencePayload(
      title: title,
      artist: artist,
      album: album,
      coverUrl: coverUrl,
      positionMs: positionMs,
      durationMs: durationMs,
      isPlaying: isPlaying,
    );

    _lastPresencePayload = payload;

    if (isConnected) {
      _sendJson(payload);
    }
  }

  /// Clears active listening presence from Discord.
  Future<void> clearPresence() async {
    final payload = {
      'op': opPresenceUpdate,
      'd': {
        'since': 0,
        'activities': [],
        'status': 'online',
        'afk': false,
      },
    };

    _lastPresencePayload = null;

    if (isConnected) {
      _sendJson(payload);
    }
  }

  void _onError(dynamic error) {
    _cleanupSocket();
    _setStatus(DiscordGatewayStatus.disconnected);
    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _onDone() {
    _cleanupSocket();
    _setStatus(DiscordGatewayStatus.disconnected);
    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed || _intentionalDisconnect) return;

    _setStatus(DiscordGatewayStatus.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (!_isDisposed && !_intentionalDisconnect && _userToken != null) {
        connect(token: _userToken!);
      }
    });
  }

  void _cleanupSocket([int? code, String? reason]) {
    _heartbeatTimer?.cancel();
    _initialHeartbeatTimer?.cancel();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    if (_socket != null) {
      final s = _socket;
      _socket = null;
      s?.close(code, reason);
    }
  }

  /// Cleanly closes the gateway session.
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _cleanupSocket();
    _setStatus(DiscordGatewayStatus.disconnected);
  }

  /// Disposes all timers and streams.
  void dispose() {
    _isDisposed = true;
    disconnect();
    _statusController.close();
  }
}
