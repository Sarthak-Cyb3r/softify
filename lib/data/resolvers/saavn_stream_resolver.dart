import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_des/dart_des.dart';

import '../../core/native/softify_native.dart';
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

    final cleanArtistStr = track.artist.replaceAll(RegExp(r'[\u00A0\u2000-\u200B\u202F\u205F\u3000]'), ' ');
    final primaryArtist = cleanArtistStr.split(RegExp(r'[,&/]')).first.trim();
    final cleanArtistQuery = cleanArtistStr
        .replaceAll(RegExp(r'[,&/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cleanAlbumQuery = (track.album ?? '')
        .replaceAll(RegExp(r'[\u00A0\u2000-\u200B\u202F\u205F\u3000]'), ' ')
        .replaceAll(RegExp(r'[\(\[].*?[\)\]]'), '')
        .replaceAll(RegExp(r'[,&/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
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

      // Extract candidate artists across primary_artists, featured_artists, artists (excluding actors/starring), singers, or subtitle
      final primaryArtistsList = (moreInfo?['artistMap']?['primary_artists'] as List<dynamic>?)
          ?.map((a) => (a['name'] ?? '').toString())
          .join(', ');
      final featuredArtistsList = (moreInfo?['artistMap']?['featured_artists'] as List<dynamic>?)
          ?.map((a) => (a['name'] ?? '').toString())
          .join(', ');
      final legitimateArtistsList = (moreInfo?['artistMap']?['artists'] as List<dynamic>?)
          ?.where((a) => a is Map<String, dynamic> && a['role'] != 'starring')
          .map((a) => (a['name'] ?? '').toString())
          .join(', ');
      final subtitleArtist = candSubtitle.contains(' - ')
          ? candSubtitle.split(' - ').first.trim()
          : '';
      final candSingers = _normalize(
        '$primaryArtistsList $featuredArtistsList $legitimateArtistsList ${moreInfo?['music']} ${r['singers']} ${r['primary_artists']} $subtitleArtist',
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

      // 1. Hard Disqualification: Unrelated artist cover / mismatch
      const artistStopWords = {
        'the', 'and', 'feat', 'ft', 'featuring', 'with', 'presents', 'prod', 'by',
        'music', 'band', 'records', 'official', 'original', 'soundtrack', 'all',
        'star', 'stars', 'dj', 'vj', 'mr', 'ms', 'mrs', 'dr', 'to', 'in', 'on', 'of',
      };
      final cleanPrimary = _normalize(primaryArtist);
      final primaryWords = cleanPrimary
          .split(' ')
          .where((w) => w.length >= 3 && !artistStopWords.contains(w))
          .toList();

      if (primaryWords.isNotEmpty) {
        if (primaryWords.length >= 2) {
          // Multi-token primary artist (e.g. "Atif Aslam", "Falak Shabbir", "Arijit Singh")
          // Require full primary artist containment OR all significant tokens
          final hasExactPrimary = candSingers.contains(cleanPrimary);
          final hasAllTokens = primaryWords.every((w) => candSingers.contains(w));
          if (!hasExactPrimary && !hasAllTokens) {
            continue; // Disqualify unrelated artist
          }
        } else {
          // Single-token primary artist (e.g. "Adele", "Eminem")
          final token = primaryWords.first;
          final candTokens = candSingers.split(RegExp(r'[^a-z0-9]+')).toSet();
          if (!candTokens.contains(token) && !candSingers.contains(token)) {
            continue;
          }
        }
      }

      // 2. Duration Guard: Reject extreme duration discrepancy (> 25s for tracks > 45s)
      final candDurSec = int.tryParse(moreInfo?['duration']?.toString() ?? '') ?? 0;
      if (track.duration > const Duration(seconds: 45)) {
        if (candDurSec <= 0) {
          // If candidate duration is unknown, only allow if album matches target
          final targetAlbum = _normalize(track.album ?? '');
          final candAlbum = _normalize((moreInfo?['album'] ?? r['subtitle'] ?? '').toString());
          if (targetAlbum.isEmpty || candAlbum.isEmpty || !candAlbum.contains(targetAlbum)) {
            continue;
          }
        } else {
          final diffSec = (track.duration.inSeconds - candDurSec).abs();
          final maxAllowedDiff = (track.duration.inSeconds * 0.10).clamp(8, 25).toInt();
          if (diffSec > maxAllowedDiff) {
            continue; // Reject completely wrong recording or alternate live version
          }
        }
      }

      double score = 0.0;

      final cleanSimple = _phoneticSimplify(cleanTitle);
      final candSimple = _phoneticSimplify(candTitle);

      // 3. Title match (Disqualify if title does not genuinely match)
      bool titleMatched = false;
      if (candTitle == cleanTitle || (candSimple.isNotEmpty && candSimple == cleanSimple)) {
        score += 70.0;
        titleMatched = true;
      } else if (candTitle.contains(cleanTitle) && (cleanTitle.length >= 4 || cleanTitle.length == candTitle.length)) {
        score += 50.0;
        titleMatched = true;
      } else if (cleanTitle.contains(candTitle) && candTitle.length >= 4 && (candTitle.length / cleanTitle.length >= 0.65)) {
        score += 45.0;
        titleMatched = true;
      } else if (candSimple.isNotEmpty && cleanSimple.isNotEmpty && (candSimple.contains(cleanSimple) || cleanSimple.contains(candSimple))) {
        if (cleanSimple.length >= 4 && candSimple.length >= 4) {
          score += 40.0;
          titleMatched = true;
        }
      } else {
        const titleStopWords = {'the', 'a', 'an', 'in', 'on', 'of', 'and', 'to', 'for', 'with', 'from', 'by', 'is', 'it', 'me', 'you'};
        final tWords = cleanSimple.split(' ').where((w) => w.length >= 3 && !titleStopWords.contains(w)).toSet();
        final cWords = candSimple.split(' ').where((w) => w.length >= 3 && !titleStopWords.contains(w)).toSet();
        if (tWords.isNotEmpty && cWords.isNotEmpty) {
          final inter = tWords.intersection(cWords).length;
          final ratio = inter / tWords.length;
          if (ratio >= 0.60) {
            score += 40.0 * ratio;
            titleMatched = true;
          }
        }
      }

      if (!titleMatched) {
        continue; // Disqualify candidate if title does not genuinely match
      }

      // 4. Language preservation
      const regionalLangs = ['telugu', 'tamil', 'bhojpuri', 'kannada', 'malayalam', 'marathi', 'bengali'];
      final targetLower = '${track.title.toLowerCase()} ${track.artist.toLowerCase()}';
      if (regionalLangs.contains(candLanguage) && !targetLower.contains(candLanguage)) {
        score -= 40.0;
      }

      // 5. Prefer Hindi / English / Punjabi original tracks only if matching target context
      if (candLanguage == 'hindi' || candLanguage == 'english' || candLanguage == 'punjabi') {
        if (targetLower.contains(candLanguage) || cleanArtist.isEmpty) {
          score += 10.0;
        }
      }

      // 6. Singer / artist bonus (proportional to overlap)
      if (cleanArtist.isNotEmpty && candSingers.isNotEmpty) {
        if (candSingers.contains(cleanPrimary) || candSingers.contains(cleanArtist)) {
          score += 40.0; // Exact primary artist match
        } else if (primaryWords.isNotEmpty) {
          final matchedTokens = primaryWords.where((t) => candSingers.contains(t)).length;
          score += 40.0 * (matchedTokens / primaryWords.length);
        }
      }

      // 7. Album / Soundtrack verification
      final targetAlbum = _normalize(track.album ?? '');
      final candAlbum = _normalize((moreInfo?['album'] ?? r['subtitle'] ?? '').toString());
      if (targetAlbum.isNotEmpty && candAlbum.isNotEmpty) {
        if (candAlbum == targetAlbum || candAlbum.contains(targetAlbum) || targetAlbum.contains(candAlbum)) {
          score += 40.0;
        }
      }

      // 8. Duration Proximity
      if (track.duration > Duration.zero && candDurSec > 0) {
        final diffSec = (track.duration.inSeconds - candDurSec).abs();
        if (diffSec <= 5) {
          score += 40.0; // High confidence original studio master match
        } else if (diffSec <= 15) {
          score += 25.0;
        } else if (diffSec <= 35) {
          score += 10.0;
        } else if (diffSec > 60) {
          score -= 25.0;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestPid = pid;
      }
    }

    // Require at least 80.0 points confidence to prevent erroneous matches
    if (bestScore >= 80.0 && bestPid != null) {
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

    // Decrypt media URL using native Rust engine, with graceful Dart fallback
    final int targetBitrate = switch (quality) {
      AudioQualityPreset.low => 96000,
      AudioQualityPreset.standard => 160000,
      AudioQualityPreset.high => 320000,
    };

    String? finalUrl = SoftifyNativeEngine.instance.decryptSaavnUrl(
      encryptedMediaUrl,
      targetBitrate: targetBitrate,
    );

    if (finalUrl == null) {
      // Fallback: Decrypt media URL using pure Dart DES-ECB with key '38346591'
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
      switch (quality) {
        case AudioQualityPreset.low:
          finalUrl = baseMp4Url.replaceAll(RegExp(r'_(48|96|160|320)\.mp4'), '_96.mp4');
          break;
        case AudioQualityPreset.standard:
          finalUrl = baseMp4Url.replaceAll(RegExp(r'_(48|96|160|320)\.mp4'), '_160.mp4');
          break;
        case AudioQualityPreset.high:
          // Studio Master 320kbps stream hosted on JioSaavn CDN edges.
          finalUrl = baseMp4Url.replaceAll(RegExp(r'_(48|96|160|320)\.mp4'), '_320.mp4');
          break;
      }
    }

    final bitrate = targetBitrate;

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
    final native = SoftifyNativeEngine.instance.normalizeText(str);
    if (native != null) return native;
    return str
        .replaceAll(RegExp(r'[\u00A0\u2000-\u200B\u202F\u205F\u3000]'), ' ')
        .toLowerCase()
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _phoneticSimplify(String s) {
    final native = SoftifyNativeEngine.instance.phoneticSimplify(s);
    if (native != null) return native;
    return s
        .replaceAll(RegExp(r'[\u00A0\u2000-\u200B\u202F\u205F\u3000]'), ' ')
        .toLowerCase()
        .replaceAll(RegExp(r'([aeiou])\1+'), r'$1')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
