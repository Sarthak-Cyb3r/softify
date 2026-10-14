import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../screens/artist_detail_screen.dart';

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
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF333333),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                    ),
                    title: Text(
                      artist,
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
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArtistDetailScreen(
                            artistName: artist,
                            coverUrl: coverUrl,
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
