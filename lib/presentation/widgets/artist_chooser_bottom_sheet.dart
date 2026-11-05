import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../data/services/spotify_api_service.dart';
import '../theme/app_theme.dart';
import '../screens/artist_detail_screen.dart';
import 'shared/app_network_image.dart';

/// In-memory cache & resolver for artist profile pictures.
class ArtistAvatarResolver {
  static final Map<String, String?> _cache = {};
  static final SpotifyApiService _spotifyApi = SpotifyApiService();

  static Future<String?> getArtistImageUrl(String artistName) async {
    final clean = artistName.trim();
    if (clean.isEmpty) return null;
    final key = clean.toLowerCase();
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    // 1. Primary: Spotify Artist Search (Official high-res artist avatars)
    try {
      final res = await _spotifyApi.search(clean, limit: 3);
      for (final artist in res.artists) {
        if (artist.imageUrl != null && artist.imageUrl!.isNotEmpty) {
          _cache[key] = artist.imageUrl;
          return artist.imageUrl;
        }
      }
    } catch (_) {}

    // 2. Secondary fallback: Deezer Artist Search
    try {
      final uri = Uri.parse(
        'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(clean)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          final list = data['data'] as List;
          for (final item in list) {
            if (item is Map) {
              final img = item['picture_medium'] ?? item['picture_big'] ?? item['picture'];
              if (img is String &&
                  img.isNotEmpty &&
                  !img.contains('artist//') &&
                  !img.endsWith('/0-0-0.jpg')) {
                _cache[key] = img;
                return img;
              }
            }
          }
        }
      }
    } catch (_) {}

    _cache[key] = null;
    return null;
  }
}


/// Splits combined artist text into individual artist names.
/// Handles ',', ';', '&', '/', 'and', 'feat.', 'ft.', 'with' cleanly.
List<String> parseArtistNames(String rawArtist) {
  if (rawArtist.trim().isEmpty) return [];

  final pattern = RegExp(
    r'(?:\s*,\s*|\s*;\s*|\s+&\s+|\s+/\s+|\s+and\s+|\s+(?:feat\.?|ft\.?|with)\s+)',
    caseSensitive: false,
  );

  final parts = rawArtist
      .split(pattern)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  return parts.isNotEmpty ? parts : [rawArtist.trim()];
}

/// Navigates directly to [ArtistDetailScreen] if single artist, or opens
/// Spotify-style artist chooser bottom sheet if track has multiple artists.
void showArtistChooserOrDetail(
  BuildContext context, {
  required String rawArtist,
  String? coverUrl,
}) {
  final artists = parseArtistNames(rawArtist);
  if (artists.isEmpty) return;

  if (artists.length == 1) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistDetailScreen(
          artistName: artists.first,
          coverUrl: coverUrl,
        ),
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ArtistChooserBottomSheet(
      artists: artists,
      coverUrl: coverUrl,
    ),
  );
}

class ArtistChooserBottomSheet extends StatelessWidget {
  final List<String> artists;
  final String? coverUrl;

  const ArtistChooserBottomSheet({
    super.key,
    required this.artists,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Spotify drag pill
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF535353),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Artists',
                style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(
                  8,
                  0,
                  8,
                  bottomPadding > 0 ? bottomPadding : 16,
                ),
                itemCount: artists.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.white.withValues(alpha: 0.05),
                  indent: 64,
                ),
                itemBuilder: (context, index) {
                  final artist = artists[index];
                  return _ArtistChooserTile(
                    artist: artist,
                    onTap: (resolvedImage) {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute(
                          builder: (_) => ArtistDetailScreen(
                            artistName: artist,
                            coverUrl: resolvedImage,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistChooserTile extends StatefulWidget {
  final String artist;
  final ValueChanged<String?> onTap;

  const _ArtistChooserTile({
    required this.artist,
    required this.onTap,
  });

  @override
  State<_ArtistChooserTile> createState() => _ArtistChooserTileState();
}

class _ArtistChooserTileState extends State<_ArtistChooserTile> {
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _fetchAvatar();
  }

  Future<void> _fetchAvatar() async {
    final img = await ArtistAvatarResolver.getArtistImageUrl(widget.artist);
    if (mounted) {
      setState(() {
        _imageUrl = img;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: _imageUrl != null
              ? AppNetworkImage(
                  imageUrl: _imageUrl,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  placeholderIcon: Icons.person_rounded,
                  fallbackIcon: Icons.person_rounded,
                  backgroundColor: const Color(0xFF333333),
                )
              : Center(
                  child: Text(
                    widget.artist.trim().isNotEmpty
                        ? widget.artist.trim()[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ),

      title: Text(
        widget.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tokens.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: const Text(
        'Artist',
        style: TextStyle(
          color: Color(0xFFA7A7A7),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFB3B3B3),
        size: 20,
      ),
      onTap: () => widget.onTap(_imageUrl),
    );
  }
}
