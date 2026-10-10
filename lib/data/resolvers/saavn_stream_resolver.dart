import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_des/dart_des.dart';

import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_stream_resolver.dart';

class SaavnStreamResolver implements IStreamResolver {
  final HttpClient _httpClient;
  final Map<String, StreamInfo> _cache = {};
  final Map<String, String> _pidCache = {};

  static const String _desKey = '38346591';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  SaavnStreamResolver({HttpClient? httpClient})
      : _httpClient = httpClient ??
            (HttpClient()
              ..idleTimeout = const Duration(seconds: 45)
              ..maxConnectionsPerHost = 8);

  @override
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  }) async {
    final cacheKey = '${track.sourceId}_${quality.name}';
    if (!forceFresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (!cached.isExpired) {
        return cached;
      }
    }

    String? songPid;
    if (track.sourceId.startsWith('saavn_')) {
      songPid = track.sourceId.replaceFirst('saavn_', '').trim();
    } else {
      songPid = await _findBestMatchingPid(track);
    }

    if (songPid == null || songPid.isEmpty) {
      throw Exception(
        'Could not find matching JioSaavn studio track for "${track.title}" (${track.artist})',
      );
    }

    final streamInfo = await _fetchStreamInfoByPid(songPid, quality);
    _cache[cacheKey] = streamInfo;
    return streamInfo;
  }

  @override
  Future<void> prefetch(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
  }) async {
    try {
      await resolve(track, quality: quality, forceFresh: false);
    } catch (_) {
      // Best-effort prefetch
    }
  }

  Future<String?> _findBestMatchingPid(Track track) async {
    final cleanTitle = _normalize(track.title);
    final cleanArtist = _normalize(track.artist);
    final cacheKey = '$cleanTitle|$cleanArtist';
    if (_pidCache.containsKey(cacheKey)) {
      return _pidCache[cacheKey];
    }

    List<dynamic> results = [];
    final primaryArtist = track.artist.split(RegExp(r'[,&/]')).first.trim();
    final queriesToTry = <String>{
      '${track.title} ${track.artist}'.trim(),
      if (primaryArtist.isNotEmpty && primaryArtist != track.artist)
        '${track.title} $primaryArtist'.trim(),
      track.title.trim(),
    }.toList();

    for (final q in queriesToTry) {
      final uri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=10&p=1&q=${Uri.encodeComponent(q)}',
      );
      try {
        final req = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 4));
        req.headers.set('User-Agent', _userAgent);
        final res = await req.close().timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final body = await res.transform(utf8.decoder).join();
          final json = jsonDecode(body);
          final list = (json['results'] as List<dynamic>?) ?? [];
          if (list.isNotEmpty) {
            results = list;
            break;
          }
        }
      } catch (_) {}
    }

    if (results.isEmpty) return null;

    double bestScore = -1.0;
    String? bestPid;

    for (final r in results) {
      final pid = r['id']?.toString();
      if (pid == null) continue;

      final moreInfo = r['more_info'] as Map<String, dynamic>?;
      final candTitle = _normalize((r['title'] ?? r['song'] ?? '').toString());
      final candLanguage = (r['language'] ?? '').toString().toLowerCase();

      // Extract candidate artists from primary_artists in artistMap, music, subtitle, or singers
      final primaryArtistsList = (moreInfo?['artistMap']?['primary_artists'] as List<dynamic>?)
          ?.map((a) => (a['name'] ?? '').toString())
          .join(', ');
      final candSingers = _normalize(
        (primaryArtistsList != null && primaryArtistsList.isNotEmpty)
            ? primaryArtistsList
            : (moreInfo?['music'] ?? r['subtitle'] ?? r['singers'] ?? r['primary_artists'] ?? '').toString(),
      );

      double score = 0.0;

      // 1. Title match
      if (candTitle == cleanTitle) {
        score += 60.0;
      } else if (candTitle.contains(cleanTitle) || cleanTitle.contains(candTitle)) {
        score += 45.0;
      } else {
        final tWords = cleanTitle.split(' ').where((w) => w.length > 2).toSet();
        final cWords = candTitle.split(' ').where((w) => w.length > 2).toSet();
        if (tWords.isNotEmpty) {
          final inter = tWords.intersection(cWords).length;
          score += 40.0 * (inter / tWords.length);
        }
      }

      // 2. Language preservation:
      // If target title/artist doesn't explicitly mention regional languages, penalize regional dubbed editions
      const regionalLangs = ['telugu', 'tamil', 'bhojpuri', 'kannada', 'malayalam', 'marathi', 'bengali'];
      final targetLower = '${track.title.toLowerCase()} ${track.artist.toLowerCase()}';
      if (regionalLangs.contains(candLanguage) && !targetLower.contains(candLanguage)) {
        score -= 40.0;
      }

      // 3. Prefer Hindi / English original tracks if candidate language matches or is primary
      if (candLanguage == 'hindi' || candLanguage == 'english' || candLanguage == 'punjabi') {
        score += 15.0;
      }

      // 4. Strict singer / artist verification:
      // A cover or recreation by an unrelated artist (e.g. Avinash Gupta) must NEVER be matched
      final targetWords = cleanArtist.split(' ').where((w) => w.length > 2).toSet();
      final candWords = candSingers.split(' ').where((w) => w.length > 2).toSet();
      final hasArtistOverlap = targetWords.any((w) => candWords.contains(w) || candSingers.contains(w));

      if (candSingers.isNotEmpty && cleanArtist.isNotEmpty) {
        if (hasArtistOverlap) {
          score += 35.0;
        } else {
          // Unrelated artist singing a track with same title -> heavy penalty to trigger fallback
          score -= 90.0;
        }
      }

      // 5. Proximity to expected duration
      final candDurSec = int.tryParse(moreInfo?['duration']?.toString() ?? '') ?? 0;
      if (track.duration > Duration.zero && candDurSec > 0) {
        final diffSec = (track.duration.inSeconds - candDurSec).abs();
        if (diffSec > 35) {
          score -= 60.0; // Major discrepancy (remix, cut, or cover)
        } else if (diffSec <= 10) {
          score += 20.0;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestPid = pid;
      }
    }

    // Require at least 50 points confidence to prevent erroneous matches
    if (bestScore >= 50.0 && bestPid != null) {
      _pidCache[cacheKey] = bestPid;
      return bestPid;
    }
    return null;
  }

  Future<StreamInfo> _fetchStreamInfoByPid(
    String pid,
    AudioQualityPreset quality,
  ) async {
    final uri = Uri.parse(
      'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=$pid&_format=json&_marker=0&api_version=4&ctx=web6dot0',
    );

    final req = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 6));
    req.headers.set('User-Agent', _userAgent);
    final res = await req.close().timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      throw HttpException('Failed to load Saavn song details (HTTP ${res.statusCode})', uri: uri);
    }

    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;

    Map<String, dynamic>? songData;
    if (json['songs'] is List && (json['songs'] as List).isNotEmpty) {
      songData = (json['songs'] as List).first as Map<String, dynamic>?;
    } else if (json[pid] is Map) {
      songData = json[pid] as Map<String, dynamic>?;
    }

    if (songData == null) {
      throw Exception('Song details not found for Saavn pid "$pid"');
    }

    final moreInfo = songData['more_info'] as Map<String, dynamic>? ?? songData;
    final encryptedMediaUrl = (moreInfo['encrypted_media_url'] ?? songData['encrypted_media_url']) as String?;

    if (encryptedMediaUrl == null || encryptedMediaUrl.isEmpty) {
      throw Exception('No encrypted media URL found for Saavn pid "$pid"');
    }

    // Decrypt media URL using DES-ECB with key '38346591'
    final keyBytes = utf8.encode(_desKey);
    final des = DES(key: keyBytes, mode: DESMode.ECB);
    final encryptedBytes = base64.decode(encryptedMediaUrl);
    final decryptedBytes = des.decrypt(encryptedBytes);
    final rawDecrypted = utf8.decode(decryptedBytes);

    // Bulletproof extraction of clean URL up to '.mp4'
    final mp4Index = rawDecrypted.indexOf('.mp4');
    final baseMp4Url = mp4Index != -1
        ? rawDecrypted.substring(0, mp4Index + 4)
        : rawDecrypted.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();

    final has320 = moreInfo['320kbps'] == 'true' || moreInfo['320kbps'] == true;
    final String finalUrl;
    final int bitrate;

    switch (quality) {
      case AudioQualityPreset.low:
        finalUrl = baseMp4Url.replaceAll('_96.mp4', '_96.mp4');
        bitrate = 96000;
        break;
      case AudioQualityPreset.standard:
        if (has320) {
          finalUrl = baseMp4Url.replaceAll('_96.mp4', '_320.mp4');
          bitrate = 320000;
        } else {
          finalUrl = baseMp4Url.replaceAll('_96.mp4', '_160.mp4');
          bitrate = 160000;
        }
        break;
    }

    return StreamInfo(
      url: Uri.parse(finalUrl),
      container: 'm4a',
      bitrate: bitrate,
      codec: 'aac',
      expiresAt: DateTime.now().add(const Duration(hours: 6)),
      providerName: 'jiosaavn_studio (${bitrate ~/ 1000}kbps)',
      headers: null,
    );
  }

  String _normalize(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim();
  }
}
