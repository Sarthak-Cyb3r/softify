// ============================================================================
// Softify Quality of Life (QoL): Linux Single Instance UNIX Socket Guard
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Enums & Action Models
// ============================================================================

/// High-level actions that a secondary Softify process can request the primary
/// instance to execute.
enum SingleInstanceAction {
  /// Focus and bring the primary Softify window to the front.
  focus('focus'),

  /// Open one or more audio files, playlists, or stream URLs passed in args.
  open('open'),

  /// Toggle playback state (play/pause).
  playPause('play_pause'),

  /// Skip to the next track in queue.
  next('next'),

  /// Jump to the previous track in queue.
  previous('previous'),

  /// Stop audio playback.
  stop('stop'),

  /// IPC heartbeat probe / connection ping.
  ping('ping'),

  /// Custom or unclassified command-line argument list.
  custom('custom');

  final String value;
  const SingleInstanceAction(this.value);

  static SingleInstanceAction fromValue(String? raw) {
    if (raw == null) return SingleInstanceAction.focus;
    for (final action in SingleInstanceAction.values) {
      if (action.value == raw) return action;
    }
    return SingleInstanceAction.custom;
  }

  /// Infers the appropriate [SingleInstanceAction] from command-line arguments.
  static SingleInstanceAction inferFromArgs(List<String> args) {
    if (args.isEmpty) {
      return SingleInstanceAction.focus;
    }

    final lowerArgs = args.map((a) => a.toLowerCase().trim()).toList();

    if (lowerArgs.contains('--play-pause') ||
        lowerArgs.contains('-p') ||
        lowerArgs.contains('--toggle-play')) {
      return SingleInstanceAction.playPause;
    }
    if (lowerArgs.contains('--next') || lowerArgs.contains('-n')) {
      return SingleInstanceAction.next;
    }
    if (lowerArgs.contains('--prev') ||
        lowerArgs.contains('--previous') ||
        lowerArgs.contains('-b')) {
      return SingleInstanceAction.previous;
    }
    if (lowerArgs.contains('--stop') || lowerArgs.contains('-s')) {
      return SingleInstanceAction.stop;
    }
    if (lowerArgs.contains('--ping')) {
      return SingleInstanceAction.ping;
    }
    if (lowerArgs.contains('--focus') || lowerArgs.contains('-f')) {
      return SingleInstanceAction.focus;
    }

    // Check for media links or local audio file paths
    for (final arg in args) {
      if (arg.startsWith('http://') ||
          arg.startsWith('https://') ||
          arg.startsWith('file://')) {
        return SingleInstanceAction.open;
      }
      final lower = arg.toLowerCase();
      if (lower.endsWith('.mp3') ||
          lower.endsWith('.flac') ||
          lower.endsWith('.m4a') ||
          lower.endsWith('.wav') ||
          lower.endsWith('.ogg') ||
          lower.endsWith('.opus') ||
          lower.endsWith('.m3u') ||
          lower.endsWith('.m3u8')) {
        return SingleInstanceAction.open;
      }
    }

    return SingleInstanceAction.custom;
  }
}

/// Structured IPC message payload sent across the UNIX domain socket
/// from a secondary process to the primary instance.
@immutable
class SingleInstanceMessage {
  final String id;
  final SingleInstanceAction action;
  final List<String> args;
  final String? workingDirectory;
  final int? senderPid;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const SingleInstanceMessage({
    required this.id,
    required this.action,
    this.args = const [],
    this.workingDirectory,
    this.senderPid,
    required this.timestamp,
    this.metadata = const {},
  });

  /// Factory creating an IPC message from raw command-line arguments and process context.
  factory SingleInstanceMessage.fromCommandLine(
    List<String> args, {
    String? workingDir,
    int? pid,
    SingleInstanceAction? explicitAction,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    final inferredAction = explicitAction ?? SingleInstanceAction.inferFromArgs(args);
    final msgId = 'msg_${now.millisecondsSinceEpoch}_${pid ?? 0}';

    return SingleInstanceMessage(
      id: msgId,
      action: inferredAction,
      args: List.unmodifiable(args),
      workingDirectory: workingDir,
      senderPid: pid,
      timestamp: now,
      metadata: metadata ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.value,
      'args': args,
      'workingDirectory': workingDirectory,
      'senderPid': senderPid,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory SingleInstanceMessage.fromJson(Map<String, dynamic> json) {
    return SingleInstanceMessage(
      id: json['id'] as String? ?? 'unknown_id',
      action: SingleInstanceAction.fromValue(json['action'] as String?),
      args: (json['args'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      workingDirectory: json['workingDirectory'] as String?,
      senderPid: json['senderPid'] as int?,
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  SingleInstanceMessage copyWith({
    String? id,
    SingleInstanceAction? action,
    List<String>? args,
    String? workingDirectory,
    int? senderPid,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return SingleInstanceMessage(
      id: id ?? this.id,
      action: action ?? this.action,
      args: args ?? this.args,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      senderPid: senderPid ?? this.senderPid,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'SingleInstanceMessage(id: $id, action: ${action.value}, args: $args, senderPid: $senderPid)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleInstanceMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          action == other.action &&
          listEquals(args, other.args) &&
          workingDirectory == other.workingDirectory &&
          senderPid == other.senderPid;

  @override
  int get hashCode => Object.hash(id, action, Object.hashAll(args), senderPid);
}

/// Structured IPC response returned by the primary instance to the secondary process.
@immutable
class SingleInstanceResponse {
  final bool success;
  final String message;
  final int? receiverPid;
  final SingleInstanceAction? handledAction;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const SingleInstanceResponse({
    required this.success,
    required this.message,
    this.receiverPid,
    this.handledAction,
    required this.timestamp,
    this.data = const {},
  });

  const SingleInstanceResponse.success({
    this.message = 'Arguments forwarded successfully',
    this.receiverPid,
    this.handledAction,
    this.data = const {},
  })  : success = true,
        timestamp = const _StaticDateTime();

  const SingleInstanceResponse.failure({
    required this.message,
    this.receiverPid,
    this.handledAction,
    this.data = const {},
  })  : success = false,
        timestamp = const _StaticDateTime();

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'receiverPid': receiverPid,
      'handledAction': handledAction?.value,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
    };
  }

  factory SingleInstanceResponse.fromJson(Map<String, dynamic> json) {
    return SingleInstanceResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      receiverPid: json['receiverPid'] as int?,
      handledAction: json['handledAction'] != null
          ? SingleInstanceAction.fromValue(json['handledAction'] as String)
          : null,
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
      data: (json['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  @override
  String toString() =>
      'SingleInstanceResponse(success: $success, message: $message, receiverPid: $receiverPid)';
}

/// Constant fallback DateTime to avoid runtime clock instantiation in const constructors.
class _StaticDateTime implements DateTime {
  const _StaticDateTime();

  DateTime get _real => DateTime.now();

  @override
  bool isAfter(DateTime other) => _real.isAfter(other);
  @override
  bool isBefore(DateTime other) => _real.isBefore(other);
  @override
  bool isAtSameMomentAs(DateTime other) => _real.isAtSameMomentAs(other);
  @override
  int compareTo(DateTime other) => _real.compareTo(other);
  @override
  int get millisecondsSinceEpoch => _real.millisecondsSinceEpoch;
  @override
  int get microsecondsSinceEpoch => _real.microsecondsSinceEpoch;
  @override
  String get timeZoneName => _real.timeZoneName;
  @override
  Duration get timeZoneOffset => _real.timeZoneOffset;
  @override
  DateTime add(Duration duration) => _real.add(duration);
  @override
  DateTime subtract(Duration duration) => _real.subtract(duration);
  @override
  Duration difference(DateTime other) => _real.difference(other);
  @override
  String toIso8601String() => _real.toIso8601String();
  @override
  DateTime toLocal() => _real.toLocal();
  @override
  DateTime toUtc() => _real.toUtc();
  @override
  int get year => _real.year;
  @override
  int get month => _real.month;
  @override
  int get day => _real.day;
  @override
  int get hour => _real.hour;
  @override
  int get minute => _real.minute;
  @override
  int get second => _real.second;
  @override
  int get millisecond => _real.millisecond;
  @override
  int get microsecond => _real.microsecond;
  @override
  int get weekday => _real.weekday;
  @override
  bool get isUtc => _real.isUtc;
}

// ============================================================================
// Single Instance Status & State
// ============================================================================

/// Execution role and health status of the single instance guard.
enum SingleInstanceStatus {
  /// Guard has not been initialized.
  idle,

  /// Currently probing existing sockets and establishing IPC.
  starting,

  /// Active primary instance listening on the UNIX domain socket.
  primary,

  /// Identified existing primary; successfully forwarded command arguments.
  secondaryForwarded,

  /// Secondary instance has invoked process termination callback.
  secondaryExited,

  /// Socket binding or IPC transmission encountered an unrecoverable error.
  error,

  /// Primary instance socket closed and cleaned up cleanly.
  stopped,

  /// Operating system platform does not support UNIX domain sockets.
  unsupported,
}

/// Immutable state snapshot of the [SingleInstanceGuard].
@immutable
class SingleInstanceState {
  final SingleInstanceStatus status;
  final String socketPath;
  final bool isPrimary;
  final int? primaryPid;
  final SingleInstanceMessage? lastMessage;
  final int receivedMessagesCount;
  final String? errorMessage;
  final DateTime? startedAt;
  final bool autoExitSecondary;

  const SingleInstanceState({
    this.status = SingleInstanceStatus.idle,
    this.socketPath = '',
    this.isPrimary = false,
    this.primaryPid,
    this.lastMessage,
    this.receivedMessagesCount = 0,
    this.errorMessage,
    this.startedAt,
    this.autoExitSecondary = true,
  });

  bool get isRunning => status == SingleInstanceStatus.primary;
  bool get isSecondary =>
      status == SingleInstanceStatus.secondaryForwarded ||
      status == SingleInstanceStatus.secondaryExited;
  bool get hasError => status == SingleInstanceStatus.error;

  SingleInstanceState copyWith({
    SingleInstanceStatus? status,
    String? socketPath,
    bool? isPrimary,
    int? primaryPid,
    SingleInstanceMessage? lastMessage,
    int? receivedMessagesCount,
    String? errorMessage,
    DateTime? startedAt,
    bool? autoExitSecondary,
  }) {
    return SingleInstanceState(
      status: status ?? this.status,
      socketPath: socketPath ?? this.socketPath,
      isPrimary: isPrimary ?? this.isPrimary,
      primaryPid: primaryPid ?? this.primaryPid,
      lastMessage: lastMessage ?? this.lastMessage,
      receivedMessagesCount:
          receivedMessagesCount ?? this.receivedMessagesCount,
      errorMessage: errorMessage,
      startedAt: startedAt ?? this.startedAt,
      autoExitSecondary: autoExitSecondary ?? this.autoExitSecondary,
    );
  }

  @override
  String toString() =>
      'SingleInstanceState(status: $status, isPrimary: $isPrimary, socketPath: $socketPath, count: $receivedMessagesCount)';
}

/// Result returned immediately by `SingleInstanceGuard.initialize()`.
@immutable
class SingleInstanceResult {
  final bool isPrimary;
  final bool forwardedSuccessfully;
  final SingleInstanceResponse? response;
  final String? errorMessage;
  final SingleInstanceStatus status;

  const SingleInstanceResult({
    required this.isPrimary,
    required this.forwardedSuccessfully,
    this.response,
    this.errorMessage,
    required this.status,
  });

  const SingleInstanceResult.primary({String? socketPath})
      : isPrimary = true,
        forwardedSuccessfully = false,
        response = null,
        errorMessage = null,
        status = SingleInstanceStatus.primary;

  const SingleInstanceResult.secondary({
    required this.forwardedSuccessfully,
    this.response,
    this.errorMessage,
  })  : isPrimary = false,
        status = SingleInstanceStatus.secondaryForwarded;

  const SingleInstanceResult.error(this.errorMessage)
      : isPrimary = false,
        forwardedSuccessfully = false,
        response = null,
        status = SingleInstanceStatus.error;

  const SingleInstanceResult.unsupported([this.errorMessage])
      : isPrimary = true,
        forwardedSuccessfully = false,
        response = null,
        status = SingleInstanceStatus.unsupported;

  @override
  String toString() =>
      'SingleInstanceResult(isPrimary: $isPrimary, forwarded: $forwardedSuccessfully, status: $status)';
}

// ============================================================================
// Socket Connector & Binder Signatures for Injection/Testing
// ============================================================================

typedef SocketConnector = Future<Socket> Function(
  dynamic host,
  int port, {
  Duration? timeout,
});

typedef ServerSocketBinder = Future<ServerSocket> Function(
  dynamic address,
  int port, {
  int backlog,
  bool v6Only,
  bool shared,
});

/// Default production socket connector using `dart:io`.
Future<Socket> defaultSocketConnector(
  dynamic host,
  int port, {
  Duration? timeout,
}) {
  return Socket.connect(host, port, timeout: timeout);
}

/// Default production server socket binder using `dart:io`.
Future<ServerSocket> defaultServerSocketBinder(
  dynamic address,
  int port, {
  int backlog = 0,
  bool v6Only = false,
  bool shared = false,
}) {
  return ServerSocket.bind(address, port, backlog: backlog, shared: shared);
}

/// Default production exit handler calling `exit(code)`.
void defaultProcessExitHandler(int exitCode) {
  exit(exitCode);
}

// ============================================================================
// Configuration Options
// ============================================================================

/// Configuration parameters for the single instance guard.
class SingleInstanceConfig {
  /// Custom UNIX domain socket file path. If null, defaults to `/tmp/softify-$USER.sock`.
  final String? socketPath;

  /// Connection timeout when checking if an existing instance is listening.
  final Duration connectionTimeout;

  /// IPC response timeout waiting for acknowledgment from primary instance.
  final Duration responseTimeout;

  /// Whether to automatically call [exitHandler] when running as a secondary instance.
  final bool autoExitSecondary;

  /// Process exit delegate (injectable for unit tests).
  final void Function(int exitCode) exitHandler;

  /// Whether to automatically delete a stale socket file if connection is refused.
  final bool autoCleanStaleSocket;

  /// Optional platform override for unit tests (simulating Linux in headless tests).
  final bool? isSupportedPlatformOverride;

  /// Pluggable socket connector for unit tests.
  final SocketConnector socketConnector;

  /// Pluggable server socket binder for unit tests.
  final ServerSocketBinder serverSocketBinder;

  const SingleInstanceConfig({
    this.socketPath,
    this.connectionTimeout = const Duration(milliseconds: 600),
    this.responseTimeout = const Duration(milliseconds: 2500),
    this.autoExitSecondary = true,
    this.exitHandler = defaultProcessExitHandler,
    this.autoCleanStaleSocket = true,
    this.isSupportedPlatformOverride,
    this.socketConnector = defaultSocketConnector,
    this.serverSocketBinder = defaultServerSocketBinder,
  });

  SingleInstanceConfig copyWith({
    String? socketPath,
    Duration? connectionTimeout,
    Duration? responseTimeout,
    bool? autoExitSecondary,
    void Function(int exitCode)? exitHandler,
    bool? autoCleanStaleSocket,
    bool? isSupportedPlatformOverride,
    SocketConnector? socketConnector,
    ServerSocketBinder? serverSocketBinder,
  }) {
    return SingleInstanceConfig(
      socketPath: socketPath ?? this.socketPath,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      responseTimeout: responseTimeout ?? this.responseTimeout,
      autoExitSecondary: autoExitSecondary ?? this.autoExitSecondary,
      exitHandler: exitHandler ?? this.exitHandler,
      autoCleanStaleSocket: autoCleanStaleSocket ?? this.autoCleanStaleSocket,
      isSupportedPlatformOverride:
          isSupportedPlatformOverride ?? this.isSupportedPlatformOverride,
      socketConnector: socketConnector ?? this.socketConnector,
      serverSocketBinder: serverSocketBinder ?? this.serverSocketBinder,
    );
  }
}

// ============================================================================
// Persistent Preferences Store
// ============================================================================

const String kSingleInstanceGuardEnabledPrefKey = 'softify_single_instance_guard_enabled';
const String kSingleInstanceCustomSocketPathPrefKey = 'softify_single_instance_custom_socket_path';

/// Local key-value store for single instance settings.
class SingleInstancePreferencesStore {
  static final SingleInstancePreferencesStore _instance =
      SingleInstancePreferencesStore._internal();
  factory SingleInstancePreferencesStore() => _instance;
  SingleInstancePreferencesStore._internal();

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File(p.join(dir.path, 'shared_preferences.json'));
      if (await _cacheFile!.exists()) {
        final content = await _cacheFile!.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _memoryCache = Map<String, dynamic>.from(decoded);
          }
        }
      }
    } catch (_) {
      // Graceful fallback to memory store
    } finally {
      _isLoaded = true;
    }
  }

  Future<bool?> getBool(String key) async {
    if (!_isLoaded) await init();
    final val = _memoryCache[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    try {
      if (_cacheFile != null) {
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache), flush: true);
      }
    } catch (_) {}
    return true;
  }

  Future<String?> getString(String key) async {
    if (!_isLoaded) await init();
    final val = _memoryCache[key];
    if (val != null) return val.toString();
    return null;
  }

  Future<bool> setString(String key, String value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    try {
      if (_cacheFile != null) {
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache), flush: true);
      }
    } catch (_) {}
    return true;
  }

  void clearForTesting() {
    _memoryCache.clear();
    _isLoaded = false;
    _cacheFile = null;
  }
}

// ============================================================================
// Core SingleInstanceGuard Service
// ============================================================================

/// Quality-of-Life (QoL) service that ensures only a single instance of Softify
/// runs simultaneously on Linux desktop systems.
///
/// Features:
/// - Single instance protection backed by a UNIX domain socket at `/tmp/softify-$USER.sock`.
/// - Probes for an active existing instance on application startup.
/// - If active: packages command line arguments, forwards them over the socket to
///   the primary instance, awaits acknowledgment, and cleanly terminates the secondary process.
/// - If inactive or stale socket file detected: removes stale socket file and binds
///   the UNIX server socket as the primary instance.
/// - Emits streams for received messages, command arguments, and bring-to-front activation events.
/// - Provides configurable process exit handlers, custom socket paths, and pluggable connectors for test isolation.
class SingleInstanceGuard {
  static SingleInstanceGuard? _instance;
  static SingleInstanceGuard get instance => _instance ??= SingleInstanceGuard();

  ServerSocket? _serverSocket;
  StreamSubscription<Socket>? _serverSubscription;
  final List<StreamSubscription<dynamic>> _clientSubscriptions = [];

  final StreamController<SingleInstanceState> _stateController =
      StreamController<SingleInstanceState>.broadcast();
  final StreamController<SingleInstanceMessage> _messageController =
      StreamController<SingleInstanceMessage>.broadcast();
  final StreamController<List<String>> _argsController =
      StreamController<List<String>>.broadcast();
  final StreamController<void> _bringToFrontController =
      StreamController<void>.broadcast();

  SingleInstanceState _state = const SingleInstanceState();
  SingleInstanceConfig _config = const SingleInstanceConfig();

  SingleInstanceGuard({SingleInstanceConfig? config}) {
    if (config != null) {
      _config = config;
    }
  }

  /// Current state snapshot.
  SingleInstanceState get state => _state;

  /// Broadcast stream of state changes.
  Stream<SingleInstanceState> get stateStream => _stateController.stream;

  /// Stream of messages received from secondary instances.
  Stream<SingleInstanceMessage> get onMessage => _messageController.stream;

  /// Stream of raw argument lists forwarded by secondary processes.
  Stream<List<String>> get onArgsReceived => _argsController.stream;

  /// Stream signaling that the window should be brought to front.
  Stream<void> get onBringToFront => _bringToFrontController.stream;

  /// Whether current process is the primary instance.
  bool get isPrimary => _state.isPrimary;

  /// Active socket path.
  String get socketPath => _state.socketPath;

  /// Resolves the standard UNIX domain socket path: `/tmp/softify-$USER.sock`.
  ///
  /// Sanitizes usernames to ensure valid POSIX filesystem compatibility.
  static String resolveDefaultSocketPath({Map<String, String>? env}) {
    final environment = env ?? Platform.environment;
    final rawUser = environment['USER'] ??
        environment['LOGNAME'] ??
        environment['USERNAME'] ??
        'user';

    // Sanitize username (allow only a-z, A-Z, 0-9, _, -)
    final sanitizedUser = rawUser.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final safeUser = sanitizedUser.isEmpty ? 'user' : sanitizedUser;

    return '/tmp/softify-$safeUser.sock';
  }

  /// Determines if the current platform supports UNIX domain sockets.
  static bool isPlatformSupported({bool? override}) {
    if (override != null) return override;
    return Platform.isLinux || Platform.isMacOS || Platform.isAndroid;
  }

  /// Initializes the guard and performs single-instance check.
  ///
  /// - If another instance is running: forwards [args], executes secondary exit, and returns.
  /// - If this is the only instance: binds UNIX domain socket and listens for future invocations.
  Future<SingleInstanceResult> initialize({
    List<String> args = const [],
    String? workingDirectory,
    SingleInstanceConfig? config,
  }) async {
    if (config != null) {
      _config = config;
    }

    final isSupported = isPlatformSupported(
      override: _config.isSupportedPlatformOverride,
    );

    if (!isSupported) {
      _updateState(_state.copyWith(
        status: SingleInstanceStatus.unsupported,
        isPrimary: true,
      ));
      return const SingleInstanceResult.unsupported(
        'UNIX domain sockets are not supported on this platform.',
      );
    }

    final effectiveSocketPath = _config.socketPath ?? resolveDefaultSocketPath();
    final currentPid = pid;

    _updateState(_state.copyWith(
      status: SingleInstanceStatus.starting,
      socketPath: effectiveSocketPath,
      autoExitSecondary: _config.autoExitSecondary,
    ));

    // Step 1: Probe existing socket to see if a primary instance is already listening.
    final existingConnected = await _probeExistingInstance(
      socketPath: effectiveSocketPath,
      args: args,
      workingDirectory: workingDirectory,
      senderPid: currentPid,
    );

    if (existingConnected != null) {
      // Existing primary instance responded!
      _updateState(_state.copyWith(
        status: SingleInstanceStatus.secondaryForwarded,
        isPrimary: false,
        primaryPid: existingConnected.receiverPid,
      ));

      if (_config.autoExitSecondary) {
        _updateState(_state.copyWith(
          status: SingleInstanceStatus.secondaryExited,
        ));
        _config.exitHandler(0);
      }

      return SingleInstanceResult.secondary(
        forwardedSuccessfully: true,
        response: existingConnected,
      );
    }

    // Step 2: No active instance found. Handle potential stale socket file.
    final socketFile = File(effectiveSocketPath);
    if (socketFile.existsSync()) {
      if (_config.autoCleanStaleSocket) {
        try {
          socketFile.deleteSync();
        } catch (e) {
          debugPrint('SingleInstanceGuard: Failed to remove stale socket file: $e');
        }
      }
    }

    // Step 3: Bind UNIX domain server socket as Primary Instance.
    try {
      final bindAddress = InternetAddress(
        effectiveSocketPath,
        type: InternetAddressType.unix,
      );

      _serverSocket = await _config.serverSocketBinder(bindAddress, 0);

      _updateState(_state.copyWith(
        status: SingleInstanceStatus.primary,
        isPrimary: true,
        socketPath: effectiveSocketPath,
        primaryPid: currentPid,
        startedAt: DateTime.now(),
        errorMessage: null,
      ));

      _serverSubscription = _serverSocket!.listen(
        _handleIncomingClient,
        onError: (error) {
          debugPrint('SingleInstanceGuard server error: $error');
          _updateState(_state.copyWith(
            status: SingleInstanceStatus.error,
            errorMessage: error.toString(),
          ));
        },
      );

      return SingleInstanceResult.primary(socketPath: effectiveSocketPath);
    } catch (bindError) {
      // If address in use and cleanup failed, try one more cleanup attempt
      if (socketFile.existsSync() && _config.autoCleanStaleSocket) {
        try {
          socketFile.deleteSync();
          final bindAddress = InternetAddress(
            effectiveSocketPath,
            type: InternetAddressType.unix,
          );
          _serverSocket = await _config.serverSocketBinder(bindAddress, 0);

          _updateState(_state.copyWith(
            status: SingleInstanceStatus.primary,
            isPrimary: true,
            socketPath: effectiveSocketPath,
            primaryPid: currentPid,
            startedAt: DateTime.now(),
            errorMessage: null,
          ));

          _serverSubscription = _serverSocket!.listen(_handleIncomingClient);
          return SingleInstanceResult.primary(socketPath: effectiveSocketPath);
        } catch (_) {}
      }

      final errorMsg = 'Failed to bind UNIX domain socket at $effectiveSocketPath: $bindError';
      debugPrint('SingleInstanceGuard: $errorMsg');

      _updateState(_state.copyWith(
        status: SingleInstanceStatus.error,
        errorMessage: errorMsg,
      ));

      return SingleInstanceResult.error(errorMsg);
    }
  }

  /// Probes for an existing instance, sends message if connected, and waits for response.
  Future<SingleInstanceResponse?> _probeExistingInstance({
    required String socketPath,
    required List<String> args,
    String? workingDirectory,
    int? senderPid,
  }) async {
    final socketFile = File(socketPath);
    if (!socketFile.existsSync()) {
      return null;
    }

    Socket? socket;
    try {
      final address = InternetAddress(socketPath, type: InternetAddressType.unix);
      socket = await _config.socketConnector(
        address,
        0,
        timeout: _config.connectionTimeout,
      );

      final message = SingleInstanceMessage.fromCommandLine(
        args,
        workingDir: workingDirectory,
        pid: senderPid,
      );

      final responseCompleter = Completer<SingleInstanceResponse>();

      // Listen for line-delimited response
      final sub = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (!responseCompleter.isCompleted && line.trim().isNotEmpty) {
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;
              responseCompleter.complete(SingleInstanceResponse.fromJson(json));
            } catch (e) {
              responseCompleter.complete(
                SingleInstanceResponse.failure(message: 'Invalid response: $e'),
              );
            }
          }
        },
        onError: (err) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.complete(
              SingleInstanceResponse.failure(message: err.toString()),
            );
          }
        },
        onDone: () {
          if (!responseCompleter.isCompleted) {
            responseCompleter.complete(
              const SingleInstanceResponse.success(message: 'Forwarded (closed)'),
            );
          }
        },
      );

      // Write message to socket
      socket.write('${jsonEncode(message.toJson())}\n');
      await socket.flush();

      final response = await responseCompleter.future.timeout(
        _config.responseTimeout,
        onTimeout: () => const SingleInstanceResponse.success(
          message: 'Forwarded without awaiting ACK',
        ),
      );

      await sub.cancel();
      await socket.close();
      socket.destroy();
      return response;
    } on SocketException {
      // Connection refused or stale socket file
      try {
        await socket?.close();
        socket?.destroy();
      } catch (_) {}
      return null;
    } catch (_) {
      try {
        await socket?.close();
        socket?.destroy();
      } catch (_) {}
      return null;
    }
  }

  /// Handles an incoming connection from a secondary process.
  void _handleIncomingClient(Socket clientSocket) {
    StreamSubscription<dynamic>? clientSub;

    clientSub = clientSocket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) async {
        if (line.trim().isEmpty) return;

        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final message = SingleInstanceMessage.fromJson(json);

          // Update primary instance state & metrics
          final updatedCount = _state.receivedMessagesCount + 1;
          _updateState(_state.copyWith(
            lastMessage: message,
            receivedMessagesCount: updatedCount,
          ));

          // Notify internal event streams
          _messageController.add(message);
          _argsController.add(message.args);

          if (message.action == SingleInstanceAction.focus ||
              message.action == SingleInstanceAction.open ||
              message.action == SingleInstanceAction.playPause ||
              message.action == SingleInstanceAction.custom) {
            _bringToFrontController.add(null);
          }

          // Send positive acknowledgment back to secondary
          final response = SingleInstanceResponse(
            success: true,
            message: 'Arguments handled by primary Softify instance',
            receiverPid: pid,
            handledAction: message.action,
            timestamp: DateTime.now(),
            data: {'forwardedCount': updatedCount},
          );

          clientSocket.write('${jsonEncode(response.toJson())}\n');
          await clientSocket.flush();
        } catch (e) {
          final errorResponse = SingleInstanceResponse.failure(
            message: 'Failed to process IPC payload: $e',
            receiverPid: pid,
          );
          clientSocket.write('${jsonEncode(errorResponse.toJson())}\n');
          await clientSocket.flush();
        } finally {
          await clientSocket.close();
          clientSocket.destroy();
        }
      },
      onError: (err) {
        debugPrint('SingleInstanceGuard client socket error: $err');
      },
      onDone: () {
        if (clientSub != null) {
          _clientSubscriptions.remove(clientSub);
          clientSub.cancel();
        }
      },
    );

    _clientSubscriptions.add(clientSub);
  }

  /// Manually transmits a command or action to the primary instance.
  Future<SingleInstanceResponse> sendCommand(
    SingleInstanceAction action, {
    List<String> args = const [],
    String? socketPath,
    Map<String, dynamic>? metadata,
  }) async {
    final targetPath = socketPath ??
        (_state.socketPath.isNotEmpty
            ? _state.socketPath
            : resolveDefaultSocketPath());

    final address = InternetAddress(targetPath, type: InternetAddressType.unix);
    Socket? socket;
    try {
      socket = await _config.socketConnector(
        address,
        0,
        timeout: _config.connectionTimeout,
      );

      final message = SingleInstanceMessage.fromCommandLine(
        args,
        explicitAction: action,
        pid: pid,
        metadata: metadata,
      );

      final completer = Completer<SingleInstanceResponse>();

      final sub = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (!completer.isCompleted && line.trim().isNotEmpty) {
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;
              completer.complete(SingleInstanceResponse.fromJson(json));
            } catch (e) {
              completer.complete(SingleInstanceResponse.failure(message: e.toString()));
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.complete(SingleInstanceResponse.failure(message: e.toString()));
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(
              const SingleInstanceResponse.success(message: 'Command sent'),
            );
          }
        },
      );

      socket.write('${jsonEncode(message.toJson())}\n');
      await socket.flush();

      final res = await completer.future.timeout(
        _config.responseTimeout,
        onTimeout: () => const SingleInstanceResponse.failure(message: 'Command timed out'),
      );

      await sub.cancel();
      await socket.close();
      socket.destroy();
      return res;
    } catch (e) {
      try {
        await socket?.close();
        socket?.destroy();
      } catch (_) {}
      return SingleInstanceResponse.failure(message: e.toString());
    }
  }

  /// Sends a lightweight IPC ping to verify primary instance responsiveness.
  Future<SingleInstanceResponse> sendPing({String? socketPath}) {
    return sendCommand(
      SingleInstanceAction.ping,
      args: const ['--ping'],
      socketPath: socketPath,
    );
  }

  /// Manually checks and removes a stale socket file if no process is actively listening.
  Future<bool> cleanStaleSocket({String? socketPath}) async {
    final target = socketPath ??
        (_state.socketPath.isNotEmpty
            ? _state.socketPath
            : resolveDefaultSocketPath());

    final file = File(target);
    if (!file.existsSync()) return false;

    // Check if an instance is alive
    try {
      final addr = InternetAddress(target, type: InternetAddressType.unix);
      final socket = await _config.socketConnector(
        addr,
        0,
        timeout: const Duration(milliseconds: 300),
      );
      await socket.close();
      socket.destroy();
      // Socket is alive! Do not delete!
      return false;
    } on SocketException {
      // Connection refused, socket is stale
      try {
        file.deleteSync();
        return true;
      } catch (_) {
        return false;
      }
    } catch (_) {
      try {
        file.deleteSync();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Shuts down the UNIX server socket and cleanly deletes the socket file from `/tmp`.
  Future<void> stop() async {
    await _serverSubscription?.cancel();
    _serverSubscription = null;

    for (final sub in _clientSubscriptions) {
      await sub.cancel();
    }
    _clientSubscriptions.clear();

    if (_serverSocket != null) {
      try {
        await _serverSocket!.close();
      } catch (_) {}
      _serverSocket = null;
    }

    // Clean up socket file if still present
    if (_state.socketPath.isNotEmpty) {
      try {
        final f = File(_state.socketPath);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
    }

    _updateState(_state.copyWith(
      status: SingleInstanceStatus.stopped,
      isPrimary: false,
    ));
  }

  /// Disposes all internal streams and cleans up IPC socket listeners.
  Future<void> dispose() async {
    await stop();
    await _stateController.close();
    await _messageController.close();
    await _argsController.close();
    await _bringToFrontController.close();
  }

  void _updateState(SingleInstanceState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Resets singleton state for test isolation.
  @visibleForTesting
  static void resetForTesting() {
    _instance?.stop();
    _instance = null;
  }
}

// ============================================================================
// Riverpod StateNotifier & Providers
// ============================================================================

/// Riverpod StateNotifier controlling the single instance lifecycle.
class SingleInstanceNotifier extends StateNotifier<SingleInstanceState> {
  final SingleInstanceGuard guard;
  StreamSubscription<SingleInstanceState>? _subscription;

  SingleInstanceNotifier(this.guard) : super(guard.state) {
    _subscription = guard.stateStream.listen((newState) {
      state = newState;
    });
  }

  /// Initializes the single instance guard with optional startup arguments.
  Future<SingleInstanceResult> initialize({
    List<String> args = const [],
    String? workingDirectory,
    SingleInstanceConfig? config,
  }) {
    return guard.initialize(
      args: args,
      workingDirectory: workingDirectory,
      config: config,
    );
  }

  /// Sends a ping probe to the active UNIX domain socket.
  Future<SingleInstanceResponse> ping() => guard.sendPing();

  /// Removes stale socket files left behind by killed processes.
  Future<bool> cleanStaleSocket() => guard.cleanStaleSocket();

  /// Stops the primary server socket and releases the UNIX domain socket file.
  Future<void> stop() => guard.stop();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Primary Riverpod provider exposing the [SingleInstanceGuard] service.
final singleInstanceGuardProvider = Provider<SingleInstanceGuard>((ref) {
  final guard = SingleInstanceGuard.instance;
  ref.onDispose(() {
    // Avoid disposing the persistent singleton on transient widget unmounts
  });
  return guard;
});

/// Riverpod provider exposing the current immutable [SingleInstanceState].
final singleInstanceStateProvider =
    StateNotifierProvider<SingleInstanceNotifier, SingleInstanceState>((ref) {
  final guard = ref.watch(singleInstanceGuardProvider);
  return SingleInstanceNotifier(guard);
});

/// Convenience provider exposing whether current process is the primary instance.
final isSingleInstancePrimaryProvider = Provider<bool>((ref) {
  return ref.watch(singleInstanceStateProvider).isPrimary;
});

/// Stream provider for incoming messages sent by secondary instances.
final singleInstanceMessageProvider = StreamProvider<SingleInstanceMessage>((ref) {
  final guard = ref.watch(singleInstanceGuardProvider);
  return guard.onMessage;
});

/// Stream provider for raw argument lists forwarded by terminal / app launcher invocations.
final singleInstanceArgsProvider = StreamProvider<List<String>>((ref) {
  final guard = ref.watch(singleInstanceGuardProvider);
  return guard.onArgsReceived;
});

/// Stream provider triggering when primary instance window should be brought to front.
final singleInstanceBringToFrontProvider = StreamProvider<void>((ref) {
  final guard = ref.watch(singleInstanceGuardProvider);
  return guard.onBringToFront;
});

// ============================================================================
// UI Widgets: Listener & Status Card
// ============================================================================

/// Desktop Quality-of-Life wrapper widget that listens for incoming secondary instance
/// activation signals and argument lists.
///
/// Features:
/// - Hooks into [singleInstanceArgsProvider] and [singleInstanceBringToFrontProvider].
/// - Invokes [onArgsReceived] when terminal arguments or URLs arrive.
/// - Invokes [onBringToFront] to trigger window manager focus.
/// - Optionally displays a sleek Material 3 SnackBar notification on the desktop UI.
class SingleInstanceGuardListener extends ConsumerStatefulWidget {
  final Widget child;
  final ValueChanged<List<String>>? onArgsReceived;
  final VoidCallback? onBringToFront;
  final ValueChanged<SingleInstanceMessage>? onMessageReceived;
  final bool showNotificationOnArgs;

  const SingleInstanceGuardListener({
    super.key,
    required this.child,
    this.onArgsReceived,
    this.onBringToFront,
    this.onMessageReceived,
    this.showNotificationOnArgs = true,
  });

  @override
  ConsumerState<SingleInstanceGuardListener> createState() =>
      _SingleInstanceGuardListenerState();
}

class _SingleInstanceGuardListenerState
    extends ConsumerState<SingleInstanceGuardListener> {
  StreamSubscription<SingleInstanceMessage>? _msgSub;
  StreamSubscription<void>? _focusSub;

  @override
  void initState() {
    super.initState();
    final guard = ref.read(singleInstanceGuardProvider);

    _msgSub = guard.onMessage.listen((msg) {
      widget.onMessageReceived?.call(msg);
      widget.onArgsReceived?.call(msg.args);

      if (widget.showNotificationOnArgs && mounted && msg.args.isNotEmpty) {
        final text = msg.args.join(' ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.terminal_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Forwarded command: $text',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    _focusSub = guard.onBringToFront.listen((_) {
      widget.onBringToFront?.call();
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _focusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Material 3 Card displaying active UNIX domain socket single instance guard status,
/// active process PID, socket path badge, and diagnostics tools.
class SingleInstanceStatusCard extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const SingleInstanceStatusCard({
    super.key,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(singleInstanceStateProvider);
    final notifier = ref.read(singleInstanceStateProvider.notifier);

    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();

    final cardColor = tokens?.card ?? theme.cardColor;
    final primaryAccent = tokens?.accent ?? theme.colorScheme.primary;
    final textPrimary = tokens?.textPrimary ?? theme.colorScheme.onSurface;
    final textSecondary = tokens?.textSecondary ??
        theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final dividerColor = tokens?.divider ?? theme.dividerColor;

    final isPrimary = state.isPrimary;
    final statusColor = isPrimary
        ? const Color(0xFF10B981) // Emerald Green
        : (state.hasError ? const Color(0xFFEF4444) : Colors.orangeAccent);

    final statusText = isPrimary
        ? 'Active Primary Server'
        : (state.hasError ? 'Guard Error' : state.status.name);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(tokens?.radiusCard ?? 16),
        border: Border.all(
          color: isPrimary
              ? primaryAccent.withValues(alpha: 0.35)
              : dividerColor.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? primaryAccent.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: isPrimary ? primaryAccent : textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linux Single Instance Guard',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'UNIX domain socket command forwarder',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(tokens?.radiusPill ?? 999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.memory_rounded,
                size: 16,
                color: textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Socket Path:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    state.socketPath.isNotEmpty
                        ? state.socketPath
                        : SingleInstanceGuard.resolveDefaultSocketPath(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Process PID: ${state.primaryPid ?? pid}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'Invocations Forwarded: ${state.receivedMessagesCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final cleaned = await notifier.cleanStaleSocket();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          cleaned
                              ? 'Stale socket removed'
                              : 'No stale socket file found or active server listening',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                label: const Text('Clean Socket'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final res = await notifier.ping();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          res.success
                              ? 'IPC Ping ACK from PID ${res.receiverPid ?? "primary"}'
                              : 'Ping failed: ${res.message}',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.network_ping_rounded, size: 16),
                label: const Text('Ping IPC'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
