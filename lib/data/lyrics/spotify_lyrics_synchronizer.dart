import 'dart:math' as math;

import '../../domain/ports/i_lyrics_provider.dart';

/// Kernel & Math-Level Synchronization Model for Spotify Lyrics Engine.
/// Reverse-engineered from Spotify Desktop xpui Modules 29735 and 52427.
class SpotifyLyricsSynchronizer {
  /// Base perceptual lead compensation in milliseconds.
  /// Compensates for OS audio driver buffer latency (ALSA/PulseAudio/AAudio/CoreAudio).
  static const int defaultBaseLeadMs = 280;

  /// High-Precision Dead-Reckoning Extrapolation (Module 29735).
  ///
  /// Mathematical model:
  ///   extrapolated = P_ref + (t_now - t_ref) * speed + baseLeadMs
  ///
  /// If paused, buffering, or reference is invalid, the position is frozen at [referencePosition].
  /// The position is clamped between 0 and [duration] (if non-null and > 0).
  static Duration extrapolatePosition({
    required Duration referencePosition,
    required DateTime referenceTimestamp,
    required DateTime now,
    double speed = 1.0,
    bool isPaused = false,
    bool isBuffering = false,
    Duration? duration,
    int latencyCompensationMs = defaultBaseLeadMs,
    int userOffsetMs = 0,
  }) {
    // If paused, buffering, or negative delta, position is frozen at reference point
    if (isPaused || isBuffering) {
      final frozenMs = referencePosition.inMilliseconds + userOffsetMs;
      final clamped = (duration != null && duration.inMilliseconds > 0)
          ? frozenMs.clamp(0, duration.inMilliseconds)
          : (frozenMs < 0 ? 0 : frozenMs);
      return Duration(milliseconds: clamped);
    }

    final elapsedMs = now.difference(referenceTimestamp).inMilliseconds;
    final effectiveElapsedMs = elapsedMs < 0 ? 0 : elapsedMs;

    final extrapolatedMs = referencePosition.inMilliseconds +
        (effectiveElapsedMs * speed).round() +
        latencyCompensationMs +
        userOffsetMs;

    final clampedMs = (duration != null && duration.inMilliseconds > 0)
        ? extrapolatedMs.clamp(0, duration.inMilliseconds)
        : (extrapolatedMs < 0 ? 0 : extrapolatedMs);

    return Duration(milliseconds: clampedMs);
  }

  /// Active Line Binary Search Interval Matcher (Module 52427).
  ///
  /// Finds the index i where lines[i].timestamp <= currentPosition < lines[i+1].timestamp.
  /// If currentPosition is before lines.first.timestamp, returns -1 (instrumental intro).
  /// If currentPosition >= lines.last.timestamp, returns lines.length - 1.
  static int findActiveLineIndex(
    List<LyricLine> lines,
    Duration currentPosition,
  ) {
    if (lines.isEmpty) return -1;
    if (currentPosition < lines.first.timestamp) return -1;

    int low = 0;
    int high = lines.length - 1;
    int candidate = -1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].timestamp <= currentPosition) {
        candidate = mid;
        low = mid + 1; // Look for a later matching line
      } else {
        high = mid - 1;
      }
    }

    // Handle identical timestamps: collapse to first occurrence of same timestamp
    if (candidate > 0) {
      int primary = candidate;
      while (primary > 0 &&
          lines[primary - 1].timestamp == lines[candidate].timestamp) {
        primary--;
      }
      return primary;
    }

    return candidate;
  }

  /// Finds the active word / syllable within a line's word array.
  /// Returns the index of the last word whose timestamp is <= currentPosition.
  static int findActiveWordIndex(
    List<LyricWord> words,
    Duration currentPosition,
  ) {
    if (words.isEmpty) return -1;
    if (currentPosition < words.first.timestamp) return -1;

    for (int i = words.length - 1; i >= 0; i--) {
      if (currentPosition >= words[i].timestamp) {
        return i;
      }
    }
    return -1;
  }

  /// Calculates the progressive fill ratio [0.0, 1.0] for a syllable / word.
  static double calculateWordProgress({
    required Duration wordStart,
    Duration? nextWordStart,
    Duration? wordDuration,
    required Duration currentPosition,
  }) {
    if (currentPosition < wordStart) return 0.0;

    final durationMs = wordDuration?.inMilliseconds ??
        (nextWordStart != null
            ? (nextWordStart.inMilliseconds - wordStart.inMilliseconds)
            : 350);

    if (durationMs <= 0) return 1.0;

    final elapsed = (currentPosition - wordStart).inMilliseconds;
    return (elapsed / durationMs).clamp(0.0, 1.0);
  }

  /// Safe Auto-Scroll Deadzone Calculation (Module 52427).
  ///
  /// Prevents viewport scroll jitter by maintaining an adaptive deadzone
  /// scaled with the viewport height. Auto-scroll is only triggered when
  /// the active line departs this safe bounding zone.
  static bool isInAutoScrollZone({
    required double lineTop,
    required double lineHeight,
    required double viewTop,
    required double viewHeight,
  }) {
    if (viewHeight <= 0) return true;

    // Dynamic deadzone factor scaled with viewport height (Module 52427)
    final heightNorm = ((viewHeight - 400.0) / 200.0).clamp(0.0, 1.0);
    final deadzoneRatio = 0.8 - (0.3 * heightNorm);
    final safeZoneHeight = viewHeight * deadzoneRatio;

    final lowerBound =
        viewTop + lineHeight + ((viewHeight - safeZoneHeight) / 2.0);
    final upperBound =
        math.min(lowerBound + safeZoneHeight, viewTop + viewHeight);

    return lineTop >= lowerBound && lineTop <= upperBound;
  }

  /// Sanitizes track titles by stripping bracketed video/metadata tags,
  /// featured artist clauses, and remaster/deluxe suffixes so lyrics APIs
  /// match the underlying song title accurately.
  static String cleanTrackTitle(String title) {
    var cleaned = title;
    // Remove (Official Video), [Audio], (Lyric Video), (From "..."), (Remastered...), etc.
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*[\(\[](?:official|lyric|audio|video|remaster|live|from|original|deluxe|bonus|version|acoustic|full|hd|4k)[^\)\]]*[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    // Remove general dashes with movie or album tags: " - From ..." or " - Remastered ..."
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*-\s*(?:from|official|remastered|remaster|radio edit|single|bonus|deluxe|live).*$',
        caseSensitive: false,
      ),
      '',
    );
    // Remove featured artists: feat., ft., featuring
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+(?:feat\.?|ft\.?|featuring)\s+.*$', caseSensitive: false),
      '',
    );
    // Remove trailing pipes (e.g. "Song | Movie")
    if (cleaned.contains('|')) {
      cleaned = cleaned.split('|').first;
    }
    final trimmed = cleaned.trim();
    return trimmed.isNotEmpty ? trimmed : title.trim();
  }

  /// Cleans artist string by stripping YouTube/VEVO tags and topic channels.
  static String cleanArtistName(String artist) {
    var cleaned = artist;
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+VEVO$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Official$', caseSensitive: false), '');
    final trimmed = cleaned.trim();
    return trimmed.isNotEmpty ? trimmed : artist.trim();
  }

  /// AppSec: Validates and sanitizes custom lyrics endpoint URLs to prevent SSRF.
  /// Rejects localhost, loopback, private RFC-1918 networks, and non-http(s) schemes.
  static Uri? sanitizeEndpoint(String? endpoint) {
    if (endpoint == null) return null;
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return null;
    }

    final host = uri.host.toLowerCase();
    if (host.isEmpty) return null;

    // Prevent SSRF: block localhost, loopback, and cloud metadata endpoints
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '169.254.169.254') {
      return null;
    }

    // Block private subnets (RFC 1918)
    if (host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        _isPrivateClassB(host)) {
      return null;
    }

    return uri;
  }

  static bool _isPrivateClassB(String host) {
    if (!host.startsWith('172.')) return false;
    final parts = host.split('.');
    if (parts.length < 2) return false;
    final secondOctet = int.tryParse(parts[1]);
    return secondOctet != null && secondOctet >= 16 && secondOctet <= 31;
  }
}
