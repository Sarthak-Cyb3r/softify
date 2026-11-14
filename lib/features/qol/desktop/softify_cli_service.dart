// ============================================================================
// Softify Quality of Life (QoL): Desktop CLI Playback Controller Interface
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/player/softify_audio_handler.dart';
import '../../../domain/entities/audio_repeat_mode.dart';
import '../../../domain/entities/track.dart';
import '../../../presentation/providers/player_providers.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Enums & Data Models
// ============================================================================

/// Supported CLI playback controller command actions.
enum CliCommandType {
  play('play', 'Resume or start playback'),
  pause('pause', 'Pause current playback'),
  toggle('toggle', 'Toggle between play and pause states'),
  next('next', 'Skip to the next track in the queue'),
  prev('prev', 'Skip to the previous track or restart current'),
  status('status', 'Display current playback status and track metadata'),
  volume('volume', 'Set or query playback volume (0-100)'),
  seek('seek', 'Seek to a position in seconds or mm:ss'),
  help('help', 'Display help information and command syntax'),
  unknown('unknown', 'Unrecognized CLI command');

  final String name;
  final String description;
  const CliCommandType(this.name, this.description);
}

/// Output format for CLI command responses.
enum CliOutputFormat {
  human('human'),
  json('json');

  final String value;
  const CliOutputFormat(this.value);

  static CliOutputFormat fromString(String? raw) {
    if (raw == null) return CliOutputFormat.human;
    final lower = raw.trim().toLowerCase();
    if (lower == 'json' || lower == 'j') return CliOutputFormat.json;
    return CliOutputFormat.human;
  }
}

/// Represents a parsed CLI invocation.
@immutable
class CliCommand {
  final CliCommandType type;
  final String rawInput;
  final List<String> arguments;
  final Map<String, String> flags;
  final CliOutputFormat format;
  final int? targetVolume;
  final int? relativeVolumeDelta;
  final Duration? seekTarget;
  final bool prettyJson;
  final bool isQuiet;
  final String? parseError;

  const CliCommand({
    required this.type,
    required this.rawInput,
    this.arguments = const [],
    this.flags = const {},
    this.format = CliOutputFormat.human,
    this.targetVolume,
    this.relativeVolumeDelta,
    this.seekTarget,
    this.prettyJson = false,
    this.isQuiet = false,
    this.parseError,
  });

  bool get hasError => parseError != null;

  @override
  String toString() =>
      'CliCommand(type: $type, raw: "$rawInput", format: $format, targetVol: $targetVolume, delta: $relativeVolumeDelta)';
}

/// Comprehensive playback snapshot for CLI status reports.
@immutable
class CliPlaybackStatus {
  final String state; // 'playing', 'paused', 'stopped', 'buffering', 'idle'
  final String? title;
  final String? artist;
  final String? album;
  final String? trackId;
  final Duration position;
  final Duration? duration;
  final int volume; // 0 - 100
  final bool isMuted;
  final String repeatMode; // 'off', 'playlist', 'one'
  final bool shuffle;
  final double speed;

  const CliPlaybackStatus({
    required this.state,
    this.title,
    this.artist,
    this.album,
    this.trackId,
    this.position = Duration.zero,
    this.duration,
    this.volume = 100,
    this.isMuted = false,
    this.repeatMode = 'off',
    this.shuffle = false,
    this.speed = 1.0,
  });

  bool get isPlaying => state.toLowerCase() == 'playing';
  bool get isPaused => state.toLowerCase() == 'paused';
  bool get isStopped =>
      state.toLowerCase() == 'stopped' || state.toLowerCase() == 'idle';
  bool get hasTrack => title != null && title!.trim().isNotEmpty;

  double get progressRatio {
    if (duration == null || duration!.inMilliseconds <= 0) return 0.0;
    final ratio = position.inMilliseconds / duration!.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }

  String get formattedPosition => _formatDuration(position);
  String get formattedDuration =>
      duration != null ? _formatDuration(duration!) : '--:--';

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Generates an ASCII/Unicode progress bar string of fixed character [width].
  String generateProgressBar({int width = 20}) {
    if (width <= 2) return '';
    final innerWidth = width - 2;
    final ratio = progressRatio;
    final filledCount = (ratio * innerWidth).round().clamp(0, innerWidth);
    final emptyCount = innerWidth - filledCount;

    final headChar = (filledCount > 0 && filledCount < innerWidth) ? '>' : '=';
    final barBody = filledCount > 0
        ? '=' * (filledCount - 1) + headChar
        : '';
    final emptyBody = '-' * emptyCount;

    return '[$barBody$emptyBody]';
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'is_playing': isPlaying,
      'track': hasTrack
          ? {
              'id': trackId,
              'title': title,
              'artist': artist ?? 'Unknown Artist',
              'album': album ?? '',
              'duration_ms': duration?.inMilliseconds,
              'duration_formatted': formattedDuration,
            }
          : null,
      'position_ms': position.inMilliseconds,
      'position_formatted': formattedPosition,
      'duration_ms': duration?.inMilliseconds,
      'duration_formatted': formattedDuration,
      'progress_percent': (progressRatio * 100).toStringAsFixed(1),
      'volume': volume,
      'is_muted': isMuted,
      'repeat_mode': repeatMode,
      'shuffle': shuffle,
      'playback_speed': speed,
    };
  }

  String toHumanReadable() {
    final buf = StringBuffer();
    final stateIcon = isPlaying ? '▶ Playing' : (isPaused ? '⏸ Paused' : '⏹ Stopped');
    buf.writeln('$stateIcon');

    if (hasTrack) {
      buf.writeln('Track:    ${title ?? "Unknown Track"}');
      buf.writeln('Artist:   ${artist ?? "Unknown Artist"}');
      if (album != null && album!.trim().isNotEmpty) {
        buf.writeln('Album:    $album');
      }
      final percentStr = (progressRatio * 100).toStringAsFixed(0);
      buf.writeln(
        'Position: ${generateProgressBar(width: 22)} $formattedPosition / $formattedDuration ($percentStr%)',
      );
    } else {
      buf.writeln('Track:    No active track loaded');
    }

    final muteStr = isMuted ? ' (Muted)' : '';
    buf.write(
      'Volume:   $volume%$muteStr | Repeat: $repeatMode | Shuffle: ${shuffle ? "on" : "off"}',
    );
    if (speed != 1.0) {
      buf.write(' | Speed: ${speed}x');
    }

    return buf.toString();
  }

  @override
  String toString() => toHumanReadable();
}

/// Standard serialized response for CLI command executions.
@immutable
class CliResponse {
  final bool success;
  final String command;
  final String message;
  final Map<String, dynamic>? data;
  final int exitCode;
  final DateTime timestamp;

  const CliResponse({
    required this.success,
    required this.command,
    required this.message,
    this.data,
    this.exitCode = 0,
    required this.timestamp,
  });

  factory CliResponse.success({
    required String command,
    required String message,
    Map<String, dynamic>? data,
  }) {
    return CliResponse(
      success: true,
      command: command,
      message: message,
      data: data,
      exitCode: 0,
      timestamp: DateTime.now().toUtc(),
    );
  }

  factory CliResponse.error({
    required String command,
    required String message,
    int exitCode = 1,
    Map<String, dynamic>? data,
  }) {
    return CliResponse(
      success: false,
      command: command,
      message: message,
      data: data,
      exitCode: exitCode,
      timestamp: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'command': command,
      'message': message,
      'exit_code': exitCode,
      'timestamp': timestamp.toIso8601String(),
      if (data != null) 'data': data,
    };
  }

  String toJsonString({bool pretty = false}) {
    final map = toJson();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }
    return jsonEncode(map);
  }

  String toHumanReadable() {
    final symbol = success ? (exitCode == 0 ? '✔' : 'ℹ') : '❌';
    final buf = StringBuffer();
    buf.writeln('$symbol $message');

    if (data != null && data!.isNotEmpty) {
      // If data represents playback status, delegate to nice table formatting
      if (data!.containsKey('state') && data!.containsKey('volume')) {
        final state = data!['state'] ?? 'stopped';
        final track = data!['track'] as Map<String, dynamic>?;
        final vol = data!['volume'] ?? 0;
        final posFormatted = data!['position_formatted'] ?? '00:00';
        final durFormatted = data!['duration_formatted'] ?? '--:--';
        final progress = data!['progress_percent'] ?? '0';

        if (track != null) {
          buf.writeln('  Track:    ${track['title']}');
          buf.writeln('  Artist:   ${track['artist']}');
          if (track['album'] != null && track['album'].toString().isNotEmpty) {
            buf.writeln('  Album:    ${track['album']}');
          }
          buf.writeln('  Progress: $posFormatted / $durFormatted ($progress%)');
        }
        buf.writeln('  Volume:   $vol% | State: $state');
      } else if (data!.containsKey('commands')) {
        // Help listing
        final cmds = data!['commands'] as List<dynamic>?;
        if (cmds != null) {
          buf.writeln('\nAvailable Commands:');
          for (final item in cmds) {
            if (item is Map<String, dynamic>) {
              final cmdName = (item['command'] ?? '').toString().padRight(16);
              final desc = item['description'] ?? '';
              buf.writeln('  $cmdName $desc');
            }
          }
        }
      } else if (data!.containsKey('volume')) {
        buf.writeln('  Level:    ${data!['volume']}%');
      }
    }

    return buf.toString().trimRight();
  }

  /// Serializes response to either Human readable or JSON string.
  String serialize(CliOutputFormat format, {bool pretty = false}) {
    if (format == CliOutputFormat.json) {
      return toJsonString(pretty: pretty);
    }
    return toHumanReadable();
  }

  @override
  String toString() => toHumanReadable();
}

/// History log entry for executed CLI commands.
@immutable
class CliHistoryItem {
  final String rawInput;
  final CliResponse response;
  final DateTime executedAt;

  const CliHistoryItem({
    required this.rawInput,
    required this.response,
    required this.executedAt,
  });
}

// ============================================================================
// Command Parser: CliCommandParser
// ============================================================================

/// Robust command line tokenizer and parser for Softify CLI controller.
class CliCommandParser {
  const CliCommandParser._();

  /// Splits a command line string into tokens respecting single and double quotes.
  static List<String> tokenize(String input) {
    final tokens = <String>[];
    final trimmed = input.trim();
    if (trimmed.isEmpty) return tokens;

    final buffer = StringBuffer();
    bool inSingleQuote = false;
    bool inDoubleQuote = false;
    bool isEscaped = false;

    for (int i = 0; i < trimmed.length; i++) {
      final char = trimmed[i];

      if (isEscaped) {
        buffer.write(char);
        isEscaped = false;
        continue;
      }

      if (char == '\\') {
        isEscaped = true;
        continue;
      }

      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        continue;
      }

      if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        continue;
      }

      if ((char == ' ' || char == '\t') && !inSingleQuote && !inDoubleQuote) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }

      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }

  /// Parses a raw command line string into a structured [CliCommand].
  static CliCommand parse(String input, {CliOutputFormat defaultFormat = CliOutputFormat.human}) {
    final tokens = tokenize(input);
    return parseArgs(tokens, rawInput: input, defaultFormat: defaultFormat);
  }

  /// Parses an already tokenized list of arguments.
  static CliCommand parseArgs(
    List<String> rawArgs, {
    String? rawInput,
    CliOutputFormat defaultFormat = CliOutputFormat.human,
  }) {
    final originalRaw = rawInput ?? rawArgs.join(' ');
    if (rawArgs.isEmpty) {
      return CliCommand(
        type: CliCommandType.help,
        rawInput: originalRaw,
        format: defaultFormat,
      );
    }

    // Filter and extract flags
    CliOutputFormat format = defaultFormat;
    bool prettyJson = false;
    bool isQuiet = false;
    final cleanArgs = <String>[];
    final flags = <String, String>{};

    for (int i = 0; i < rawArgs.length; i++) {
      final arg = rawArgs[i];
      if (arg == '--json' || arg == '-j') {
        format = CliOutputFormat.json;
      } else if (arg == '--human') {
        format = CliOutputFormat.human;
      } else if (arg == '--pretty') {
        prettyJson = true;
      } else if (arg == '--quiet' || arg == '-q') {
        isQuiet = true;
      } else if (arg.startsWith('--format=')) {
        final fmtVal = arg.substring('--format='.length);
        format = CliOutputFormat.fromString(fmtVal);
      } else if (arg.startsWith('--')) {
        final flagBody = arg.substring(2);
        if (flagBody.contains('=')) {
          final parts = flagBody.split('=');
          flags[parts[0]] = parts.sublist(1).join('=');
        } else {
          flags[flagBody] = 'true';
        }
      } else if (arg.startsWith('-') && arg.length > 1 && !RegExp(r'^[+-]\d+$').hasMatch(arg)) {
        // e.g. -h or -v
        if (arg == '-h') {
          // If -h appears with no other commands, treat as help
          flags['help'] = 'true';
        } else {
          flags[arg.substring(1)] = 'true';
        }
      } else {
        cleanArgs.add(arg);
      }
    }

    if (flags.containsKey('help') || (cleanArgs.isEmpty && flags.isNotEmpty)) {
      return CliCommand(
        type: CliCommandType.help,
        rawInput: originalRaw,
        arguments: cleanArgs,
        flags: flags,
        format: format,
        prettyJson: prettyJson,
        isQuiet: isQuiet,
      );
    }

    if (cleanArgs.isEmpty) {
      return CliCommand(
        type: CliCommandType.help,
        rawInput: originalRaw,
        format: format,
      );
    }

    final firstToken = cleanArgs.first.toLowerCase();
    final remainingArgs = cleanArgs.sublist(1);

    // Map command token to CliCommandType
    switch (firstToken) {
      case 'play':
      case 'resume':
      case 'start':
        return CliCommand(
          type: CliCommandType.play,
          rawInput: originalRaw,
          arguments: remainingArgs,
          flags: flags,
          format: format,
          prettyJson: prettyJson,
          isQuiet: isQuiet,
        );

      case 'pause':
      case 'stop':
        return CliCommand(
          type: CliCommandType.pause,
          rawInput: originalRaw,
          arguments: remainingArgs,
          flags: flags,
          format: format,
          prettyJson: prettyJson,
          isQuiet: isQuiet,
        );

      case 'toggle':
      case 'playpause':
      case 'play-pause':
        return CliCommand(
          type: CliCommandType.toggle,
          rawInput: originalRaw,
          arguments: remainingArgs,
          flags: flags,
          format: format,
          prettyJson: prettyJson,
          isQuiet: isQuiet,
        );

      case 'next':
      case 'skip':
      case 'forward':
        return CliCommand(
          type: CliCommandType.next,
          rawInput: originalRaw,
          arguments: remainingArgs,
          flags: flags,
          format: format,
          prettyJson: prettyJson,
          isQuiet: isQuiet,
        );

      case 'prev':
      case 'previous':
      case 'back':
        return CliCommand(
          type: CliCommandType.prev,
          rawInput: originalRaw,
          arguments: remainingArgs,
          flags: flags,
          format: format,
          prettyJson: prettyJson,
          isQuiet: isQuiet,
        );

      case 'status':
      case 'info':
      case 'current':
      case 'now-playing':
      case 'np':
        return CliCommand(
          type: CliCommandType.status,
          rawInput: originalRaw,
          arguments: remainingArgs,
          flags: flags,
          format: format,
          prettyJson: prettyJson,
          isQuiet: isQuiet,
        );

      case 'volume':
      case 'vol':
      case 'v':
        return _parseVolumeCommand(
          originalRaw: originalRaw,
          remainingArgs: remainingArgs,
          flags: flags,
          format: format,
          prettyJson: prettyJson,
          isQuiet: isQuiet,
        );

      case 'seek':
        return _parseSeekCommand(
          originalRaw: originalRaw,
          remainingArgs: remainingArgs,
          flags: flags,
          format: format,
          prettyJson: prettyJson,
          isQuiet: isQuiet,
        );

      case 'help':
      case '--help':
      case '-h':
      case '?':
        return CliCommand(
          type: CliCommandType.help,
          rawInput: originalRaw,
          arguments: remainingArgs,
          flags: flags,
          format: format,
          prettyJson: prettyJson,
          isQuiet: isQuiet,
        );

      default:
        return CliCommand(
          type: CliCommandType.unknown,
          rawInput: originalRaw,
          arguments: remainingArgs,
          flags: flags,
          format: format,
          prettyJson: prettyJson,
          isQuiet: isQuiet,
          parseError: "Unknown command '$firstToken'. Run 'help' for available commands.",
        );
    }
  }

  static CliCommand _parseVolumeCommand({
    required String originalRaw,
    required List<String> remainingArgs,
    required Map<String, String> flags,
    required CliOutputFormat format,
    required bool prettyJson,
    required bool isQuiet,
  }) {
    // If no argument is provided, it is a query: "softify volume"
    if (remainingArgs.isEmpty) {
      return CliCommand(
        type: CliCommandType.volume,
        rawInput: originalRaw,
        arguments: remainingArgs,
        flags: flags,
        format: format,
        prettyJson: prettyJson,
        isQuiet: isQuiet,
      );
    }

    final valStr = remainingArgs.first.trim();

    // Handle relative adjustment e.g. +5 or -10
    if (valStr.startsWith('+') || (valStr.startsWith('-') && valStr.length > 1 && int.tryParse(valStr) != null)) {
      final delta = int.tryParse(valStr);
      if (delta != null) {
        return CliCommand(
          type: CliCommandType.volume,
          rawInput: originalRaw,
          arguments: remainingArgs,
          flags: flags,
          format: format,
          relativeVolumeDelta: delta,
          prettyJson: prettyJson,
          isQuiet: isQuiet,
        );
      }
    }

    // Handle absolute volume percentage: 0..100
    final target = int.tryParse(valStr);
    if (target == null) {
      return CliCommand(
        type: CliCommandType.volume,
        rawInput: originalRaw,
        arguments: remainingArgs,
        flags: flags,
        format: format,
        prettyJson: prettyJson,
        isQuiet: isQuiet,
        parseError: 'Volume must be an integer between 0 and 100 (got: "$valStr").',
      );
    }

    if (target < 0 || target > 100) {
      return CliCommand(
        type: CliCommandType.volume,
        rawInput: originalRaw,
        arguments: remainingArgs,
        flags: flags,
        format: format,
        prettyJson: prettyJson,
        isQuiet: isQuiet,
        parseError: 'Volume must be between 0 and 100 (got: $target).',
      );
    }

    return CliCommand(
      type: CliCommandType.volume,
      rawInput: originalRaw,
      arguments: remainingArgs,
      flags: flags,
      format: format,
      targetVolume: target,
      prettyJson: prettyJson,
      isQuiet: isQuiet,
    );
  }

  static CliCommand _parseSeekCommand({
    required String originalRaw,
    required List<String> remainingArgs,
    required Map<String, String> flags,
    required CliOutputFormat format,
    required bool prettyJson,
    required bool isQuiet,
  }) {
    if (remainingArgs.isEmpty) {
      return CliCommand(
        type: CliCommandType.seek,
        rawInput: originalRaw,
        arguments: remainingArgs,
        flags: flags,
        format: format,
        prettyJson: prettyJson,
        isQuiet: isQuiet,
        parseError: 'Seek command requires a target position (e.g. seek 90 or seek 01:30).',
      );
    }

    final seekStr = remainingArgs.first.trim();
    final duration = _parseSeekDuration(seekStr);
    if (duration == null) {
      return CliCommand(
        type: CliCommandType.seek,
        rawInput: originalRaw,
        arguments: remainingArgs,
        flags: flags,
        format: format,
        prettyJson: prettyJson,
        isQuiet: isQuiet,
        parseError: 'Invalid seek position: "$seekStr". Use seconds (90) or mm:ss format (01:30).',
      );
    }

    return CliCommand(
      type: CliCommandType.seek,
      rawInput: originalRaw,
      arguments: remainingArgs,
      flags: flags,
      format: format,
      seekTarget: duration,
      prettyJson: prettyJson,
      isQuiet: isQuiet,
    );
  }

  static Duration? _parseSeekDuration(String input) {
    var clean = input.replaceAll('s', '').trim();
    if (clean.contains(':')) {
      final parts = clean.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]);
        final s = int.tryParse(parts[1]);
        if (m != null && s != null && s >= 0 && s < 60) {
          return Duration(minutes: m, seconds: s);
        }
      } else if (parts.length == 3) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final s = int.tryParse(parts[2]);
        if (h != null && m != null && s != null) {
          return Duration(hours: h, minutes: m, seconds: s);
        }
      }
      return null;
    }

    final seconds = int.tryParse(clean);
    if (seconds != null && seconds >= 0) {
      return Duration(seconds: seconds);
    }
    return null;
  }

  /// Builds the human readable help / manual screen.
  static String getUsageText() {
    final buf = StringBuffer();
    buf.writeln('Softify Linux Desktop CLI Playback Controller');
    buf.writeln('Usage: softify-cli <command> [arguments] [options]');
    buf.writeln();
    buf.writeln('Commands:');
    buf.writeln('  play, resume      Resume or start playback');
    buf.writeln('  pause, stop       Pause audio playback');
    buf.writeln('  toggle            Toggle between playing and paused');
    buf.writeln('  next, skip        Skip to the next track');
    buf.writeln('  prev, back        Skip to previous track');
    buf.writeln('  status, np        Show current playback status and metadata');
    buf.writeln('  volume <0-100>    Set volume level (e.g. volume 80, volume +5)');
    buf.writeln('  volume            Query current volume level');
    buf.writeln('  seek <pos>        Seek to seconds or mm:ss (e.g. seek 90, seek 01:30)');
    buf.writeln('  help              Show this usage instructions');
    buf.writeln();
    buf.writeln('Options:');
    buf.writeln('  --json, -j        Output serialized response as JSON');
    buf.writeln('  --human           Output human-readable terminal text (default)');
    buf.writeln('  --pretty          Pretty-print JSON output');
    buf.writeln('  --quiet, -q       Suppress non-essential messages');
    return buf.toString();
  }

  /// Structured help metadata map for JSON serialization.
  static Map<String, dynamic> getHelpData() {
    return {
      'name': 'softify-cli',
      'description': 'Softify Linux Desktop CLI Playback Controller',
      'commands': [
        {'command': 'play', 'description': 'Resume or start playback'},
        {'command': 'pause', 'description': 'Pause audio playback'},
        {'command': 'toggle', 'description': 'Toggle between playing and paused'},
        {'command': 'next', 'description': 'Skip to the next track'},
        {'command': 'prev', 'description': 'Skip to previous track'},
        {'command': 'status', 'description': 'Show current playback status and metadata'},
        {'command': 'volume <0-100>', 'description': 'Set volume percentage (0-100) or adjust relative (+/-)'},
        {'command': 'volume', 'description': 'Query current volume level'},
        {'command': 'seek <pos>', 'description': 'Seek position in seconds or mm:ss'},
        {'command': 'help', 'description': 'Display CLI usage instructions'},
      ],
      'options': [
        {'flag': '--json, -j', 'description': 'Output response as JSON'},
        {'flag': '--human', 'description': 'Output response in human readable format'},
        {'flag': '--pretty', 'description': 'Pretty-print JSON output'},
        {'flag': '--quiet, -q', 'description': 'Minimal output'},
      ],
    };
  }
}

// ============================================================================
// Playback Controller Adapter Contract & Implementations
// ============================================================================

/// Clean abstraction separating CLI service logic from underlying audio engine.
abstract class SoftifyCliPlaybackAdapter {
  Future<bool> play();
  Future<bool> pause();
  Future<bool> toggle();
  Future<bool> next();
  Future<bool> previous();
  Future<bool> setVolume(int volumePercent);
  Future<int> getVolume();
  Future<CliPlaybackStatus> getStatus();
  Future<bool> seek(Duration position);
}

/// Production adapter bridging [SoftifyCliService] directly to [SoftifyAudioHandler].
class SoftifyAudioHandlerCliAdapter implements SoftifyCliPlaybackAdapter {
  final SoftifyAudioHandler audioHandler;

  SoftifyAudioHandlerCliAdapter(this.audioHandler);

  @override
  Future<bool> play() async {
    await audioHandler.play();
    return true;
  }

  @override
  Future<bool> pause() async {
    await audioHandler.pause();
    return true;
  }

  @override
  Future<bool> toggle() async {
    final isPlaying = audioHandler.playbackState.value.playing;
    if (isPlaying) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
    return true;
  }

  @override
  Future<bool> next() async {
    await audioHandler.skipToNext();
    return true;
  }

  @override
  Future<bool> previous() async {
    await audioHandler.skipToPrevious();
    return true;
  }

  @override
  Future<bool> setVolume(int volumePercent) async {
    final clamped = volumePercent.clamp(0, 100);
    await audioHandler.setVolume(clamped / 100.0);
    return true;
  }

  @override
  Future<int> getVolume() async {
    final vol = audioHandler.volume;
    return (vol * 100).round().clamp(0, 100);
  }

  @override
  Future<bool> seek(Duration position) async {
    await audioHandler.seek(position);
    return true;
  }

  @override
  Future<CliPlaybackStatus> getStatus() async {
    final currentTrack = audioHandler.currentTrack;
    final isPlaying = audioHandler.playbackState.value.playing;
    final stateStr = isPlaying ? 'playing' : (currentTrack != null ? 'paused' : 'stopped');
    final volume = (audioHandler.volume * 100).round().clamp(0, 100);
    final pos = audioHandler.position;
    final repeatMode = _repeatModeString(audioHandler.repeatMode);

    return CliPlaybackStatus(
      state: stateStr,
      title: currentTrack?.title,
      artist: currentTrack?.artist,
      album: currentTrack?.album,
      trackId: currentTrack?.id,
      position: pos,
      duration: currentTrack?.duration,
      volume: volume,
      isMuted: volume == 0,
      repeatMode: repeatMode,
      shuffle: false,
    );
  }

  String _repeatModeString(AudioRepeatMode mode) {
    return switch (mode) {
      AudioRepeatMode.off => 'off',
      AudioRepeatMode.playlist => 'playlist',
      AudioRepeatMode.one => 'one',
    };
  }
}

/// In-memory mock adapter for unit tests, headless CLI execution, and verification.
class MockCliPlaybackAdapter implements SoftifyCliPlaybackAdapter {
  String state;
  Track? currentTrack;
  Duration position;
  int volume;
  String repeatMode;
  bool shuffle;
  double speed;

  final List<String> callHistory = [];
  bool shouldThrow = false;
  String? throwMessage;

  MockCliPlaybackAdapter({
    this.state = 'paused',
    this.currentTrack,
    this.position = Duration.zero,
    this.volume = 70,
    this.repeatMode = 'off',
    this.shuffle = false,
    this.speed = 1.0,
  });

  void _checkThrow(String op) {
    callHistory.add(op);
    if (shouldThrow) {
      throw Exception(throwMessage ?? 'Simulated error in $op');
    }
  }

  @override
  Future<bool> play() async {
    _checkThrow('play');
    state = 'playing';
    return true;
  }

  @override
  Future<bool> pause() async {
    _checkThrow('pause');
    state = 'paused';
    return true;
  }

  @override
  Future<bool> toggle() async {
    _checkThrow('toggle');
    state = (state == 'playing') ? 'paused' : 'playing';
    return true;
  }

  @override
  Future<bool> next() async {
    _checkThrow('next');
    return true;
  }

  @override
  Future<bool> previous() async {
    _checkThrow('previous');
    return true;
  }

  @override
  Future<bool> setVolume(int volumePercent) async {
    _checkThrow('setVolume($volumePercent)');
    volume = volumePercent.clamp(0, 100);
    return true;
  }

  @override
  Future<int> getVolume() async {
    _checkThrow('getVolume');
    return volume;
  }

  @override
  Future<bool> seek(Duration target) async {
    _checkThrow('seek(${target.inSeconds}s)');
    position = target;
    return true;
  }

  @override
  Future<CliPlaybackStatus> getStatus() async {
    _checkThrow('getStatus');
    return CliPlaybackStatus(
      state: state,
      title: currentTrack?.title,
      artist: currentTrack?.artist,
      album: currentTrack?.album,
      trackId: currentTrack?.id,
      position: position,
      duration: currentTrack?.duration,
      volume: volume,
      isMuted: volume == 0,
      repeatMode: repeatMode,
      shuffle: shuffle,
      speed: speed,
    );
  }
}

// ============================================================================
// Persistence Engine: CliPrefsStorage
// ============================================================================

/// Contract for persistent CLI controller preferences.
abstract class CliPrefsStorage {
  Future<bool?> getBool(String key);
  Future<bool> setBool(String key, bool value);
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<int?> getInt(String key);
  Future<bool> setInt(String key, int value);
}

/// Durable, self-contained key-value store with in-memory fallback for test environments.
class CliSharedPreferencesStore implements CliPrefsStorage {
  static final CliSharedPreferencesStore _instance = CliSharedPreferencesStore._internal();
  factory CliSharedPreferencesStore() => _instance;
  CliSharedPreferencesStore._internal();

  Map<String, dynamic> _memoryCache = {};
  bool _isLoaded = false;
  File? _cacheFile;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _cacheFile = File(p.join(dir.path, 'softify_cli_settings.json'));
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
      // In-memory fallback
    } finally {
      _isLoaded = true;
    }
  }

  Future<void> _persist() async {
    try {
      if (_cacheFile != null) {
        await _cacheFile!.parent.create(recursive: true);
        await _cacheFile!.writeAsString(jsonEncode(_memoryCache));
      }
    } catch (_) {}
  }

  @override
  Future<bool?> getBool(String key) async {
    if (!_isLoaded) await init();
    final v = _memoryCache[key];
    return v is bool ? v : null;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    await _persist();
    return true;
  }

  @override
  Future<String?> getString(String key) async {
    if (!_isLoaded) await init();
    final v = _memoryCache[key];
    return v is String ? v : null;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    await _persist();
    return true;
  }

  @override
  Future<int?> getInt(String key) async {
    if (!_isLoaded) await init();
    final v = _memoryCache[key];
    return v is int ? v : null;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    if (!_isLoaded) await init();
    _memoryCache[key] = value;
    await _persist();
    return true;
  }

  /// Clears in-memory storage for test isolation.
  void reset() {
    _memoryCache = {};
    _isLoaded = false;
    _cacheFile = null;
  }
}

// ============================================================================
// Core Service: SoftifyCliService
// ============================================================================

/// Central orchestrator executing CLI playback commands and serializing responses.
class SoftifyCliService {
  final SoftifyCliPlaybackAdapter adapter;
  final CliPrefsStorage? storage;
  final List<CliHistoryItem> _history = [];
  CliOutputFormat _defaultFormat = CliOutputFormat.human;

  ServerSocket? _ipcServer;
  int? _activePort;

  SoftifyCliService({
    required this.adapter,
    this.storage,
    CliOutputFormat defaultFormat = CliOutputFormat.human,
  }) : _defaultFormat = defaultFormat;

  CliOutputFormat get defaultFormat => _defaultFormat;
  set defaultFormat(CliOutputFormat format) => _defaultFormat = format;

  List<CliHistoryItem> get history => List.unmodifiable(_history);
  bool get isIpcServerRunning => _ipcServer != null;
  int? get activeIpcPort => _activePort;

  void clearHistory() => _history.clear();

  /// Executes a raw command line string (e.g. "volume 80 --json" or "toggle").
  Future<CliResponse> execute(String commandLine, {CliOutputFormat? formatOverride}) async {
    final parsed = CliCommandParser.parse(
      commandLine,
      defaultFormat: formatOverride ?? _defaultFormat,
    );
    return executeParsed(parsed);
  }

  /// Executes tokenized arguments (e.g. `['volume', '75', '--json']`).
  Future<CliResponse> executeArgs(List<String> args, {CliOutputFormat? formatOverride}) async {
    final parsed = CliCommandParser.parseArgs(
      args,
      defaultFormat: formatOverride ?? _defaultFormat,
    );
    return executeParsed(parsed);
  }

  /// Executes command line and immediately serializes to a formatted string.
  Future<String> executeAndFormat(String commandLine, {CliOutputFormat? formatOverride}) async {
    final parsed = CliCommandParser.parse(
      commandLine,
      defaultFormat: formatOverride ?? _defaultFormat,
    );
    final response = await executeParsed(parsed);
    return response.serialize(parsed.format, pretty: parsed.prettyJson);
  }

  /// Dispatches a parsed [CliCommand] to the appropriate handler.
  Future<CliResponse> executeParsed(CliCommand command) async {
    CliResponse response;

    if (command.hasError) {
      response = CliResponse.error(
        command: command.type.name,
        message: command.parseError!,
        exitCode: 2,
        data: {'raw_input': command.rawInput},
      );
      _recordHistory(command.rawInput, response);
      return response;
    }

    try {
      switch (command.type) {
        case CliCommandType.play:
          response = await play(format: command.format);
          break;

        case CliCommandType.pause:
          response = await pause(format: command.format);
          break;

        case CliCommandType.toggle:
          response = await toggle(format: command.format);
          break;

        case CliCommandType.next:
          response = await next(format: command.format);
          break;

        case CliCommandType.prev:
          response = await prev(format: command.format);
          break;

        case CliCommandType.status:
          response = await status(format: command.format);
          break;

        case CliCommandType.volume:
          if (command.relativeVolumeDelta != null) {
            response = await adjustVolume(command.relativeVolumeDelta!, format: command.format);
          } else if (command.targetVolume != null) {
            response = await setVolume(command.targetVolume!, format: command.format);
          } else {
            response = await getVolume(format: command.format);
          }
          break;

        case CliCommandType.seek:
          if (command.seekTarget != null) {
            response = await seek(command.seekTarget!, format: command.format);
          } else {
            response = CliResponse.error(
              command: 'seek',
              message: 'Target seek position missing',
              exitCode: 2,
            );
          }
          break;

        case CliCommandType.help:
          response = getHelp(format: command.format);
          break;

        case CliCommandType.unknown:
          response = CliResponse.error(
            command: 'unknown',
            message: "Unrecognized command. Type 'help' for available commands.",
            exitCode: 2,
            data: {'raw_input': command.rawInput},
          );
          break;
      }
    } catch (e) {
      response = CliResponse.error(
        command: command.type.name,
        message: 'Command execution failed: $e',
        exitCode: 1,
        data: {'error': e.toString(), 'raw_input': command.rawInput},
      );
    }

    _recordHistory(command.rawInput, response);
    return response;
  }

  // --------------------------------------------------------------------------
  // Direct Action Commands
  // --------------------------------------------------------------------------

  /// Plays or resumes audio playback.
  Future<CliResponse> play({CliOutputFormat? format}) async {
    try {
      await adapter.play();
      final statusSnapshot = await adapter.getStatus();
      return CliResponse.success(
        command: 'play',
        message: 'Playback resumed',
        data: statusSnapshot.toJson(),
      );
    } catch (e) {
      return CliResponse.error(
        command: 'play',
        message: 'Failed to resume playback: $e',
      );
    }
  }

  /// Pauses audio playback.
  Future<CliResponse> pause({CliOutputFormat? format}) async {
    try {
      await adapter.pause();
      final statusSnapshot = await adapter.getStatus();
      return CliResponse.success(
        command: 'pause',
        message: 'Playback paused',
        data: statusSnapshot.toJson(),
      );
    } catch (e) {
      return CliResponse.error(
        command: 'pause',
        message: 'Failed to pause playback: $e',
      );
    }
  }

  /// Toggles between play and pause states.
  Future<CliResponse> toggle({CliOutputFormat? format}) async {
    try {
      await adapter.toggle();
      final statusSnapshot = await adapter.getStatus();
      final msg = statusSnapshot.isPlaying ? 'Playback resumed' : 'Playback paused';
      return CliResponse.success(
        command: 'toggle',
        message: msg,
        data: statusSnapshot.toJson(),
      );
    } catch (e) {
      return CliResponse.error(
        command: 'toggle',
        message: 'Failed to toggle playback: $e',
      );
    }
  }

  /// Skips to the next track.
  Future<CliResponse> next({CliOutputFormat? format}) async {
    try {
      await adapter.next();
      final statusSnapshot = await adapter.getStatus();
      final msg = statusSnapshot.hasTrack
          ? 'Skipped to next track: ${statusSnapshot.title} - ${statusSnapshot.artist}'
          : 'Skipped to next track';
      return CliResponse.success(
        command: 'next',
        message: msg,
        data: statusSnapshot.toJson(),
      );
    } catch (e) {
      return CliResponse.error(
        command: 'next',
        message: 'Failed to skip to next track: $e',
      );
    }
  }

  /// Skips to the previous track.
  Future<CliResponse> prev({CliOutputFormat? format}) async {
    try {
      await adapter.previous();
      final statusSnapshot = await adapter.getStatus();
      final msg = statusSnapshot.hasTrack
          ? 'Skipped to previous track: ${statusSnapshot.title} - ${statusSnapshot.artist}'
          : 'Skipped to previous track';
      return CliResponse.success(
        command: 'prev',
        message: msg,
        data: statusSnapshot.toJson(),
      );
    } catch (e) {
      return CliResponse.error(
        command: 'prev',
        message: 'Failed to skip to previous track: $e',
      );
    }
  }

  /// Queries and returns full playback status.
  Future<CliResponse> status({CliOutputFormat? format}) async {
    try {
      final statusSnapshot = await adapter.getStatus();
      final msg = statusSnapshot.isPlaying
          ? 'Playback is playing (${statusSnapshot.title ?? "No track"})'
          : (statusSnapshot.isPaused ? 'Playback is paused' : 'Playback is stopped');
      return CliResponse.success(
        command: 'status',
        message: msg,
        data: statusSnapshot.toJson(),
      );
    } catch (e) {
      return CliResponse.error(
        command: 'status',
        message: 'Failed to retrieve playback status: $e',
      );
    }
  }

  /// Sets volume to an exact percentage (0 - 100).
  Future<CliResponse> setVolume(int volumePercent, {CliOutputFormat? format}) async {
    if (volumePercent < 0 || volumePercent > 100) {
      return CliResponse.error(
        command: 'volume',
        message: 'Volume level must be between 0 and 100 (got: $volumePercent)',
        exitCode: 2,
        data: {'attempted_volume': volumePercent},
      );
    }

    try {
      final prevVol = await adapter.getVolume();
      await adapter.setVolume(volumePercent);
      return CliResponse.success(
        command: 'volume',
        message: 'Volume set to $volumePercent%',
        data: {
          'volume': volumePercent,
          'previous_volume': prevVol,
        },
      );
    } catch (e) {
      return CliResponse.error(
        command: 'volume',
        message: 'Failed to adjust volume: $e',
      );
    }
  }

  /// Adjusts volume relatively by [delta] percentage points.
  Future<CliResponse> adjustVolume(int delta, {CliOutputFormat? format}) async {
    try {
      final curVol = await adapter.getVolume();
      final target = (curVol + delta).clamp(0, 100);
      await adapter.setVolume(target);
      final sign = delta >= 0 ? '+$delta' : '$delta';
      return CliResponse.success(
        command: 'volume',
        message: 'Volume adjusted by $sign% (now: $target%)',
        data: {
          'volume': target,
          'previous_volume': curVol,
          'delta': delta,
        },
      );
    } catch (e) {
      return CliResponse.error(
        command: 'volume',
        message: 'Failed to adjust volume delta: $e',
      );
    }
  }

  /// Queries the current volume level.
  Future<CliResponse> getVolume({CliOutputFormat? format}) async {
    try {
      final vol = await adapter.getVolume();
      return CliResponse.success(
        command: 'volume',
        message: 'Current volume is $vol%',
        data: {'volume': vol},
      );
    } catch (e) {
      return CliResponse.error(
        command: 'volume',
        message: 'Failed to get volume: $e',
      );
    }
  }

  /// Seeks to a designated position.
  Future<CliResponse> seek(Duration position, {CliOutputFormat? format}) async {
    try {
      await adapter.seek(position);
      final formatted = CliPlaybackStatus._formatDuration(position);
      return CliResponse.success(
        command: 'seek',
        message: 'Seeked to $formatted',
        data: {
          'position_ms': position.inMilliseconds,
          'position_formatted': formatted,
        },
      );
    } catch (e) {
      return CliResponse.error(
        command: 'seek',
        message: 'Failed to seek: $e',
      );
    }
  }

  /// Returns CLI usage and syntax information.
  CliResponse getHelp({CliOutputFormat? format}) {
    return CliResponse.success(
      command: 'help',
      message: CliCommandParser.getUsageText(),
      data: CliCommandParser.getHelpData(),
    );
  }

  void _recordHistory(String input, CliResponse response) {
    _history.insert(
      0,
      CliHistoryItem(
        rawInput: input,
        response: response,
        executedAt: DateTime.now().toUtc(),
      ),
    );
    if (_history.length > 50) {
      _history.removeLast();
    }
  }

  // --------------------------------------------------------------------------
  // Local IPC Socket / TCP Server for Linux Desktop Controller
  // --------------------------------------------------------------------------

  /// Starts a local loopback TCP socket server for IPC communication.
  ///
  /// Command line utilities (such as `softify-cli` or `nc 127.0.0.1 48123`) can connect,
  /// send a single-line command (e.g. "toggle --json\n"), and receive the serialized
  /// response before the connection closes.
  Future<bool> startIpcServer({int port = 48123}) async {
    if (_ipcServer != null) return true;

    try {
      _ipcServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      _activePort = _ipcServer!.port;
      _ipcServer!.listen(_handleIpcClient, onError: (e) {
        stopIpcServer();
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stops and tears down the active IPC socket server.
  Future<void> stopIpcServer() async {
    if (_ipcServer != null) {
      await _ipcServer!.close();
      _ipcServer = null;
      _activePort = null;
    }
  }

  void _handleIpcClient(Socket client) {
    final buffer = StringBuffer();
    client
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) async {
        buffer.writeln(line);
        final cmdStr = line.trim();
        if (cmdStr.isNotEmpty) {
          final responseStr = await executeAndFormat(cmdStr);
          try {
            client.writeln(responseStr);
            await client.flush();
            await client.close();
          } catch (_) {}
        }
      },
      onError: (_) {
        try {
          client.destroy();
        } catch (_) {}
      },
      cancelOnError: true,
    );
  }
}

// ============================================================================
// Riverpod State Management & Dependency Providers
// ============================================================================

/// Provider for the CLI playback controller adapter.
final cliPlaybackAdapterProvider = Provider<SoftifyCliPlaybackAdapter>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return SoftifyAudioHandlerCliAdapter(audioHandler);
});

/// Provider for persistent storage of CLI preferences.
final cliPrefsStorageProvider = Provider<CliPrefsStorage>((ref) {
  return CliSharedPreferencesStore();
});

/// Default output format preference state (human vs json).
final cliDefaultOutputFormatProvider = StateProvider<CliOutputFormat>((ref) {
  return CliOutputFormat.human;
});

/// Primary CLI Playback Controller service provider.
final softifyCliServiceProvider = Provider<SoftifyCliService>((ref) {
  final adapter = ref.watch(cliPlaybackAdapterProvider);
  final storage = ref.watch(cliPrefsStorageProvider);
  final defaultFmt = ref.watch(cliDefaultOutputFormatProvider);

  final service = SoftifyCliService(
    adapter: adapter,
    storage: storage,
    defaultFormat: defaultFmt,
  );

  ref.onDispose(() {
    service.stopIpcServer();
  });

  return service;
});

/// Reactive stream or snapshot of current playback status.
final cliPlaybackStatusProvider = FutureProvider<CliPlaybackStatus>((ref) async {
  final service = ref.watch(softifyCliServiceProvider);
  final response = await service.status();
  final data = response.data;
  if (data != null) {
    final track = data['track'] as Map<String, dynamic>?;
    return CliPlaybackStatus(
      state: data['state'] ?? 'stopped',
      title: track?['title'],
      artist: track?['artist'],
      album: track?['album'],
      volume: data['volume'] ?? 100,
      isMuted: data['is_muted'] ?? false,
      repeatMode: data['repeat_mode'] ?? 'off',
      shuffle: data['shuffle'] ?? false,
    );
  }
  return const CliPlaybackStatus(state: 'stopped');
});

/// Notifier tracking executed CLI command history.
class CliCommandHistoryNotifier extends StateNotifier<List<CliHistoryItem>> {
  CliCommandHistoryNotifier() : super(const []);

  void record(CliHistoryItem item) {
    state = [item, ...state.take(49)];
  }

  void clear() {
    state = const [];
  }
}

final cliCommandHistoryProvider =
    StateNotifierProvider<CliCommandHistoryNotifier, List<CliHistoryItem>>((ref) {
  return CliCommandHistoryNotifier();
});

/// Tracks the most recent response from interactive CLI tests.
final cliLastResponseProvider = StateProvider<CliResponse?>((ref) => null);

/// State provider tracking whether IPC server is running.
final cliIpcServerRunningProvider = StateProvider<bool>((ref) => false);

// ============================================================================
// Material 3 Desktop UI Widget: SoftifyCliControlCard
// ============================================================================

/// Interactive Material 3 desktop settings card showcasing CLI commands,
/// syntax cheatsheets, copy-to-clipboard actions, and a live terminal sandbox.
class SoftifyCliControlCard extends ConsumerStatefulWidget {
  final EdgeInsetsGeometry? padding;
  final bool showTerminalPlayground;

  const SoftifyCliControlCard({
    super.key,
    this.padding,
    this.showTerminalPlayground = true,
  });

  @override
  ConsumerState<SoftifyCliControlCard> createState() => _SoftifyCliControlCardState();
}

class _SoftifyCliControlCardState extends ConsumerState<SoftifyCliControlCard> {
  final TextEditingController _terminalInputController = TextEditingController();
  final FocusNode _terminalFocusNode = FocusNode();
  String? _terminalOutput;
  bool _isExecuting = false;

  @override
  void dispose() {
    _terminalInputController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  Future<void> _executeCommand([String? overrideText]) async {
    final text = (overrideText ?? _terminalInputController.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _isExecuting = true;
    });

    final service = ref.read(softifyCliServiceProvider);
    final output = await service.executeAndFormat(text);

    if (mounted) {
      setState(() {
        _terminalOutput = output;
        _isExecuting = false;
      });
      ref.read(cliLastResponseProvider.notifier).state =
          await service.execute(text);
    }
  }

  void _copyCommand(BuildContext context, String command) {
    Clipboard.setData(ClipboardData(text: command));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$command" to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    final theme = Theme.of(context);
    final cardColor = tokens?.card ?? theme.colorScheme.surface;
    final primaryAccent = tokens?.accent ?? theme.colorScheme.primary;
    final textPrimary = tokens?.textPrimary ?? theme.colorScheme.onSurface;
    final textSecondary = tokens?.textSecondary ?? theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final currentFmt = ref.watch(cliDefaultOutputFormatProvider);

    return Container(
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(tokens?.radiusCard ?? 16),
        border: Border.all(
          color: (tokens?.borderLight ?? theme.dividerColor).withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.terminal_rounded,
                  color: primaryAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'CLI Playback Controller',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Feature 35',
                            style: TextStyle(
                              color: primaryAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Control Softify headless or from terminal via IPC socket & command line',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // JSON Output Toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'JSON',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: currentFmt == CliOutputFormat.json,
                    onChanged: (isJson) {
                      ref.read(cliDefaultOutputFormatProvider.notifier).state =
                          isJson ? CliOutputFormat.json : CliOutputFormat.human;
                    },
                    activeColor: primaryAccent,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Command Quick-Action Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCommandChip('play', 'softify play', primaryAccent, textPrimary),
              _buildCommandChip('pause', 'softify pause', primaryAccent, textPrimary),
              _buildCommandChip('toggle', 'softify toggle', primaryAccent, textPrimary),
              _buildCommandChip('next', 'softify next', primaryAccent, textPrimary),
              _buildCommandChip('prev', 'softify prev', primaryAccent, textPrimary),
              _buildCommandChip('status', 'softify status', primaryAccent, textPrimary),
              _buildCommandChip('volume 80', 'softify volume 80', primaryAccent, textPrimary),
            ],
          ),

          if (widget.showTerminalPlayground) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Live Terminal Playground Header
            Text(
              'Terminal Sandbox',
              style: TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Command Input Box
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (tokens?.borderLight ?? theme.dividerColor).withValues(alpha: 0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _terminalInputController,
                      focusNode: _terminalFocusNode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.chevron_right_rounded, color: Colors.greenAccent, size: 20),
                        hintText: 'e.g. status --json or volume 75',
                        hintStyle: TextStyle(
                          color: Colors.white38,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _executeCommand(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isExecuting ? null : () => _executeCommand(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isExecuting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Run', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            if (_terminalOutput != null) ...[
              const SizedBox(height: 10),
              // Terminal Output Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: SelectableText(
                  _terminalOutput!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFFE0E0E0),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCommandChip(
    String label,
    String fullCommand,
    Color accent,
    Color textColor,
  ) {
    return ActionChip(
      avatar: const Icon(Icons.content_copy_rounded, size: 14),
      label: Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
      onPressed: () {
        _terminalInputController.text = label;
        _executeCommand(label);
      },
      tooltip: 'Run "$fullCommand" or click copy',
    );
  }
}
