import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../database/app_database.dart';

/// Service managing Spotify OAuth 2.0 PKCE authentication.
///
/// Uses client_id `65b708073fc0480ea92a077233ca87bd` (standard public desktop client)
/// and a loopback redirect URI `http://127.0.0.1:8989/login`.
///
/// Logged-in user accounts have dedicated, generous quotas and are never subject
/// to the global anonymous IP rate limit (`429 QUOTA_EXCEEDED`).
class SpotifyAuthService {
  final AppDatabase _db;
  final http.Client _client;

  static const String clientId = '65b708073fc0480ea92a077233ca87bd';
  static const int loopbackPort = 8989;
  static const String redirectUri = 'http://127.0.0.1:$loopbackPort/login';

  static const String _keyAccessToken = 'spotify_user_token';
  static const String _keyRefreshToken = 'spotify_refresh_token';
  static const String _keyExpiresAt = 'spotify_token_expires_at';
  static const String _keyUserName = 'spotify_user_name';

  static const String _tokenEndpoint = 'https://accounts.spotify.com/api/token';
  static const String _authorizeEndpoint = 'https://accounts.spotify.com/authorize';
  static const String _meEndpoint = 'https://api.spotify.com/v1/me';

  SpotifyAuthService({
    required AppDatabase db,
    http.Client? client,
  })  : _db = db,
        _client = client ?? http.Client();

  /// Checks whether an active or refreshable user session exists.
  Future<bool> isLoggedIn() async {
    final token = await getValidAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Returns the cached Spotify display name or user ID, if logged in.
  Future<String?> getConnectedUserName() async {
    final row = await (_db.select(_db.settings)
          ..where((t) => t.key.equals(_keyUserName)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Retrieves a valid Bearer access token, refreshing it if expired.
  Future<String?> getValidAccessToken() async {
    final tokenRow = await (_db.select(_db.settings)
          ..where((t) => t.key.equals(_keyAccessToken)))
        .getSingleOrNull();
    final expiresRow = await (_db.select(_db.settings)
          ..where((t) => t.key.equals(_keyExpiresAt)))
        .getSingleOrNull();
    final refreshRow = await (_db.select(_db.settings)
          ..where((t) => t.key.equals(_keyRefreshToken)))
        .getSingleOrNull();

    if (tokenRow == null || tokenRow.value.isEmpty) {
      return null;
    }

    final expiresAtMs = int.tryParse(expiresRow?.value ?? '') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Token is still valid (give 60-second grace window)
    if (expiresAtMs > now + 60000) {
      return tokenRow.value;
    }

    // Token expired; try refreshing if refresh token is present
    if (refreshRow != null && refreshRow.value.isNotEmpty) {
      return _refreshAccessToken(refreshRow.value);
    }

    return null;
  }

  /// Initiates 1-tap PKCE login via browser.
  ///
  /// Binds a temporary loopback HTTP server on port [loopbackPort], launches
  /// the Spotify authorization URL, and exchanges the authorization code for tokens.
  Future<bool> login({Duration timeout = const Duration(seconds: 120)}) async {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);

    HttpServer? server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        loopbackPort,
        shared: true,
      );
    } catch (_) {
      // If port is busy or cannot be bound, fail gracefully
      return false;
    }

    final completer = Completer<String?>();

    // Listen for the incoming loopback OAuth callback
    final sub = server.listen((HttpRequest request) async {
      final uri = request.uri;
      if (uri.path == '/login') {
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        request.response.headers.contentType = ContentType.html;
        if (code != null) {
          request.response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Softify - Spotify Connected</title>
  <style>
    body { background-color: #121212; color: #ffffff; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
    .card { background: #1e1e1e; border-radius: 16px; padding: 36px 32px; text-align: center; max-width: 360px; box-shadow: 0 12px 32px rgba(0,0,0,0.6); }
    .badge { width: 52px; height: 52px; border-radius: 50%; background: #1DB954; color: #000; display: inline-flex; align-items: center; justify-content: center; font-size: 28px; font-weight: bold; margin-bottom: 18px; }
    h2 { margin: 0 0 10px; font-size: 22px; }
    p { color: #a0a0a0; font-size: 14px; line-height: 1.5; margin: 0; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">&#10003;</div>
    <h2>Connected to Softify!</h2>
    <p>Your Spotify account is successfully linked. You can close this tab and return to the app.</p>
  </div>
</body>
</html>
''');
          await request.response.close();
          if (!completer.isCompleted) completer.complete(code);
        } else {
          request.response.write('''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Softify - Connection Canceled</title></head>
<body style="background:#121212;color:#fff;font-family:sans-serif;text-align:center;padding:50px;">
  <h2>Connection canceled ($error)</h2>
  <p>You can close this tab and return to Softify.</p>
</body>
</html>
''');
          await request.response.close();
          if (!completer.isCompleted) completer.complete(null);
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });

    final authUri = Uri.parse(_authorizeEndpoint).replace(queryParameters: {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'scope': 'playlist-read-private playlist-read-collaborative user-library-read',
    });

    final launched = await launchUrl(authUri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await sub.cancel();
      await server.close(force: true);
      return false;
    }

    String? authCode;
    try {
      authCode = await completer.future.timeout(timeout);
    } catch (_) {
      authCode = null;
    } finally {
      await sub.cancel();
      await server.close(force: true);
    }

    if (authCode == null) return false;

    // Exchange code for tokens
    final success = await _exchangeCodeForTokens(authCode, verifier);
    if (success) {
      await _fetchAndStoreUserProfile();
    }
    return success;
  }

  /// Disconnects the Spotify account and clears stored tokens.
  Future<void> logout() async {
    await (_db.delete(_db.settings)
          ..where((t) => t.key.isIn([
                _keyAccessToken,
                _keyRefreshToken,
                _keyExpiresAt,
                _keyUserName,
              ])))
        .go();
  }

  Future<bool> _exchangeCodeForTokens(String code, String verifier) async {
    try {
      final response = await _client.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': verifier,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final accessToken = json['access_token'] as String?;
      final refreshToken = json['refresh_token'] as String?;
      final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;

      if (accessToken == null || accessToken.isEmpty) return false;

      final expiresAtMs = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);

      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingRow(key: _keyAccessToken, value: accessToken),
          );
      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingRow(key: _keyExpiresAt, value: expiresAtMs.toString()),
          );
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _db.into(_db.settings).insertOnConflictUpdate(
              SettingRow(key: _keyRefreshToken, value: refreshToken),
            );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await _client.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'client_id': clientId,
          'refresh_token': refreshToken,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final newAccessToken = json['access_token'] as String?;
      final newRefreshToken = json['refresh_token'] as String?;
      final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;

      if (newAccessToken == null || newAccessToken.isEmpty) return null;

      final expiresAtMs = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);

      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingRow(key: _keyAccessToken, value: newAccessToken),
          );
      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingRow(key: _keyExpiresAt, value: expiresAtMs.toString()),
          );
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _db.into(_db.settings).insertOnConflictUpdate(
              SettingRow(key: _keyRefreshToken, value: newRefreshToken),
            );
      }
      return newAccessToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchAndStoreUserProfile() async {
    try {
      final token = await getValidAccessToken();
      if (token == null) return;

      final response = await _client.get(
        Uri.parse(_meEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final displayName = (json['display_name'] as String?) ?? (json['id'] as String?);
        if (displayName != null && displayName.isNotEmpty) {
          await _db.into(_db.settings).insertOnConflictUpdate(
                SettingRow(key: _keyUserName, value: displayName),
              );
        }
      }
    } catch (_) {}
  }

  String _generateCodeVerifier([int length = 64]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
