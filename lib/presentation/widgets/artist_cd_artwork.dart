import 'package:flutter/material.dart';

/// Photorealistic Dark Vinyl/CD Disc artwork with centered artist portrait,
/// specular concentric grooves, radial light slices, and spindle hole.
/// Adheres to Stitch "Softify Mobile - Search & Discography" emblem specification.
class ArtistCdArtwork extends StatelessWidget {
  final String? artistImageUrl;
  final double size;

  const ArtistCdArtwork({
    super.key,
    required this.artistImageUrl,
    this.size = 58.0,
  });

  @override
  Widget build(BuildContext context) {
    final double centerSize = size * 0.44;
    final double spindleSize = size * 0.08;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0C0D11),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF53E076).withValues(alpha: 0.10),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Concentric Precision Vinyl Grooves (High-density concentric rings)
          for (final factor in [0.92, 0.84, 0.76, 0.68, 0.60, 0.52])
            Container(
              width: size * factor,
              height: size * factor,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 0.75,
                ),
              ),
            ),

          // 2. Glossy Vinyl Specular Radial Sheen & Light Slices
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.15),
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.12),
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
          ),

          // 3. Center Artist Picture Label with subtle green aura
          Container(
            width: centerSize,
            height: centerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF53E076).withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.60),
                  blurRadius: 6,
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  artistImageUrl != null && artistImageUrl!.isNotEmpty
                      ? Image.network(
                          artistImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildFallback(),
                        )
                      : _buildFallback(),
                  // Subtle emerald hologram tint
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        colors: [
                          const Color(0xFF53E076).withValues(alpha: 0.15),
                          Colors.transparent,
                          const Color(0xFF53E076).withValues(alpha: 0.10),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Center Micro Spindle Hole
          Container(
            width: spindleSize,
            height: spindleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0C0D11),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.9),
                  blurRadius: 2,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: const Color(0xFF1E222D),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: Color(0xFF86948A),
          size: 18,
        ),
      ),
    );
  }
}
