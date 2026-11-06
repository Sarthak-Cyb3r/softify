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
    final cacheKey = '$cleanTitle|$cleanArtist|${track.album ?? ''}';
    if (_pidCache.containsKey(cacheKey)) {
      return _pidCache[cacheKey];
    }

    final primaryArtist = track.artist.split(RegExp(r'[,&/]')).first.trim();
    final cleanArtistQuery = track.artist
        .replaceAll(RegExp(r'[,&/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cleanAlbumQuery = (track.album ?? '')
        .replaceAll(RegExp(r'[\(\[].*?[\)\]]'), '')
        .replaceAll(RegExp(r'[,&/]'), ' ')
        .trim();

    final queriesToTry = <String>{
      if (primaryArtist.isNotEmpty)
        '${track.title} $primaryArtist'.trim(),
      if (cleanAlbumQuery.isNotEmpty && primaryArtist.isNotEmpty && cleanAlbumQuery.toLowerCase() != cleanTitle.toLowerCase())
        '${track.title} $primaryArtist $cleanAlbumQuery'.trim(),
      if (cleanArtistQuery.isNotEmpty && cleanArtistQuery != primaryArtist)
        '${track.title} $cleanArtistQuery'.trim(),
      if (cleanAlbumQuery.isNotEmpty && cleanAlbumQuery.toLowerCase() != cleanTitle.toLowerCase())
        '${track.title} $cleanAlbumQuery'.trim(),
      track.title.trim(),
    }.toList();

    final seenPids = <String>{};
    final allCandidates = <dynamic>[];

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
          for (final item in list) {
            final pid = item['id']?.toString();
            if (pid != null && seenPids.add(pid)) {
              allCandidates.add(item);
            }
          }
          if (allCandidates.length >= 15) break;
        }
      } catch (_) {}
    }

    if (allCandidates.isEmpty) return null;

    double bestScore = -1.0;
    String? bestPid;

    for (final r in allCandidates) {
      final pid = r['id']?.toString();
      if (pid == null) continue;

      final moreInfo = r['more_info'] as Map<String, dynamic>?;
      final rawCandTitle = (r['title'] ?? r['song'] ?? '').toString().toLowerCase();
      final candSubtitle = (r['subtitle'] ?? '').toString().toLowerCase();
      final rawCandAlbum = ((moreInfo?['album'] ?? r['more_info']?['album'] ?? r['subtitle'] ?? '')).toString().toLowerCase();
      final candTitle = _normalize(rawCandTitle);
      final candLanguage = (r['language'] ?? '').toString().toLowerCase();

      // Extract candidate artists across primary_artists, artists, music, subtitle, or singers
      final primaryArtistsList = (moreInfo?['artistMap']?['primary_artists'] as List<dynamic>?)
          ?.map((a) => (a['name'] ?? '').toString())
          .join(', ');
      final allArtistsList = (moreInfo?['artistMap']?['artists'] as List<dynamic>?)
          ?.map((a) => (a['name'] ?? '').toString())
          .join(', ');
      final candSingers = _normalize(
        '$primaryArtistsList $allArtistsList ${moreInfo?['music']} ${r['subtitle']} ${r['singers']} ${r['primary_artists']}',
      );

      // 0. Hard Disqualification: Unwanted Remixes, DJ cuts, Covers, Lofi, Slowed, Acoustic, Karaoke
      final targetTitleLower = track.title.toLowerCase();
      final targetAlbumLower = (track.album ?? '').toLowerCase();

      const unwantedKeywords = [
        'remix', 're-mix', 'mix', 'mashup', 'mash-up', 'dj ', 'dj-', 'club',
        'lofi', 'lo-fi', 'slowed', 'reverb', 'sped up', 'speed up', 'speedup',
        'acoustic', 'unplugged', 'cover', 'instrumental', 'karaoke',
        'tribute', 'rework', 'flip', 'recreated', 'recreation', 'rendition',
        '8d audio', 'bass boosted', 'reprise',
      ];

      bool isDisqualifiedVariant = false;
      for (final kw in unwantedKeywords) {
        if (!targetTitleLower.contains(kw) && !targetAlbumLower.contains(kw)) {
          // Allow 'original mix'
          if (kw == 'mix' && (rawCandTitle.contains('original mix') || candSubtitle.contains('original mix'))) {
            continue;
          }
          if (rawCandTitle.contains(kw) || candSubtitle.contains(kw) || rawCandAlbum.contains(kw)) {
            isDisqualifiedVariant = true;
            break;
          }
        }
      }
      if (isDisqualifiedVariant) continue;

      // 1. Hard Disqualification: Unrelated artist cover
      final targetWords = cleanArtist.split(' ').where((w) => w.length > 2).toSet();
      if (candSingers.isNotEmpty && targetWords.isNotEmpty) {
        final hasArtistOverlap = targetWords.any((w) => candSingers.contains(w));
        if (!hasArtistOverlap) {
          continue; // Disqualify track by unrelated singer
        }
      }

      // 2. Hard Disqualification: Major duration discrepancy (> 20s from official duration)
      final candDurSec = int.tryParse(moreInfo?['duration']?.toString() ?? '') ?? 0;
      if (track.duration > Duration.zero && candDurSec > 0) {
        final diffSec = (track.duration.inSeconds - candDurSec).abs();
        if (diffSec > 20) {
          continue; // Reject radio cuts or completely wrong tracks
        }
      }

      double score = 0.0;

      final cleanSimple = _phoneticSimplify(cleanTitle);
      final candSimple = _phoneticSimplify(candTitle);

      // 3. Title match
      if (candTitle == cleanTitle || (candSimple.isNotEmpty && candSimple == cleanSimple)) {
        score += 60.0;
      } else if (candTitle.contains(cleanTitle) ||
          cleanTitle.contains(candTitle) ||
          (candSimple.isNotEmpty &&
              (candSimple.contains(cleanSimple) || cleanSimple.contains(candSimple)))) {
        score += 45.0;
      } else {
        final tWords = cleanSimple.split(' ').where((w) => w.length >= 2).toSet();
        final cWords = candSimple.split(' ').where((w) => w.length >= 2).toSet();
        if (tWords.isNotEmpty) {
          final inter = tWords.intersection(cWords).length;
          if (inter == 0) {
            continue;
          } else {
            score += 40.0 * (inter / tWords.length);
          }
        } else {
          continue;
        }
      }

      // 4. Language preservation
      const regionalLangs = ['telugu', 'tamil', 'bhojpuri', 'kannada', 'malayalam', 'marathi', 'bengali'];
      final targetLower = '${track.title.toLowerCase()} ${track.artist.toLowerCase()}';
      if (regionalLangs.contains(candLanguage) && !targetLower.contains(candLanguage)) {
        score -= 40.0;
      }

      // 5. Prefer Hindi / English / Punjabi original tracks
      if (candLanguage == 'hindi' || candLanguage == 'english' || candLanguage == 'punjabi') {
        score += 15.0;
      }

      // 6. Singer / artist bonus
      if (candSingers.isNotEmpty && cleanArtist.isNotEmpty) {
        score += 35.0;
      }

      // 7. Album / Soundtrack verification
      final targetAlbum = _normalize(track.album ?? '');
      final candAlbum = _normalize((moreInfo?['album'] ?? r['subtitle'] ?? '').toString());
      if (targetAlbum.isNotEmpty && candAlbum.isNotEmpty) {
        if (candAlbum == targetAlbum || candAlbum.contains(targetAlbum) || targetAlbum.contains(candAlbum)) {
          score += 40.0;
        }
      }

      // 8. Strict Duration Proximity
      if (track.duration > Duration.zero && candDurSec > 0) {
        final diffSec = (track.duration.inSeconds - candDurSec).abs();
        if (diffSec <= 4) {
          score += 45.0; // High confidence original studio master match
        } else if (diffSec <= 10) {
          score += 25.0;
        } else if (diffSec <= 18) {
          score += 10.0;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestPid = pid;
      }
    }

    // Require at least 65 points confidence to prevent erroneous matches
    if (bestScore >= 65.0 && bestPid != null) {
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
    final rawDecrypted = utf8.decode(decryptedBytes, allowMalformed: true);

    // Bulletproof extraction of clean URL up to '.mp4'
    final mp4Index = rawDecrypted.indexOf('.mp4');
    final rawMp4Url = mp4Index != -1
        ? rawDecrypted.substring(0, mp4Index + 4)
        : rawDecrypted.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
    // Enforce HTTPS to prevent Android cleartext network traffic blocks
    final baseMp4Url = rawMp4Url.startsWith('http://')
        ? rawMp4Url.replaceFirst('http://', 'https://')
        : rawMp4Url;

    // Strict 320 kbps Studio Master Invariant (preserve 320 kbps on all devices)
    final String finalUrl;
    final int bitrate;

    switch (quality) {
      case AudioQualityPreset.low:
        finalUrl = baseMp4Url.replaceAll(RegExp(r'_(48|96|160|320)\.mp4'), '_96.mp4');
        bitrate = 96000;
        break;
      case AudioQualityPreset.standard:
        finalUrl = baseMp4Url.replaceAll(RegExp(r'_(48|96|160|320)\.mp4'), '_160.mp4');
        bitrate = 160000;
        break;
      case AudioQualityPreset.high:
        // Studio Master 320kbps stream hosted on JioSaavn CDN edges.
        finalUrl = baseMp4Url.replaceAll(RegExp(r'_(48|96|160|320)\.mp4'), '_320.mp4');
        bitrate = 320000;
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

  static String _phoneticSimplify(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'([aeiou])\1+'), r'$1')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
