import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Robust network image widget with:
/// - Insecure http:// -> https:// auto-upgrade to bypass Android ATS/cleartext restrictions
/// - Multi-tier automatic CDN fallback (e.g. YouTube maxresdefault -> hqdefault, JioSaavn 500x500 -> 150x150)
/// - Graceful placeholder/error rendering with zero visual glitches
class AppNetworkImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool isCircular;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;
  final IconData fallbackIcon;
  final Color? backgroundColor;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    bool isCircular = false,
    bool isCircle = false,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorWidget,
    IconData? fallbackIcon,
    IconData? placeholderIcon,
    this.backgroundColor,
  })  : isCircular = isCircular || isCircle,
        fallbackIcon = fallbackIcon ?? placeholderIcon ?? Icons.music_note_rounded;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  int _candidateIndex = 0;
  List<String> _candidates = const [];

  @override
  void initState() {
    super.initState();
    _buildCandidates();
  }

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _buildCandidates();
    }
  }

  void _buildCandidates() {
    _candidateIndex = 0;
    final raw = widget.imageUrl?.trim();
    if (raw == null || raw.isEmpty) {
      _candidates = const [];
      return;
    }

    var primary = raw;
    if (primary.startsWith('//')) {
      primary = 'https:$primary';
    } else if (primary.startsWith('http://')) {
      primary = 'https://${primary.substring(7)}';
    }

    // Replace Apple Music / mzstatic dynamic dimension placeholders
    if (primary.contains('{w}x{h}')) {
      primary = primary.replaceAll('{w}x{h}', '600x600');
    }
    if (primary.contains('{w}') || primary.contains('{h}')) {
      primary = primary.replaceAll('{w}', '600').replaceAll('{h}', '600');
    }
    if (primary.contains('{c}')) {
      primary = primary.replaceAll('{c}', '');
    }
    if (primary.contains('{f}')) {
      primary = primary.replaceAll('{f}', 'jpg');
    }

    if (!primary.startsWith('https://')) {
      _candidates = const [];
      return;
    }

    final list = <String>[primary];

    // YouTube: fallback to universally supported 480x360 hqdefault and mqdefault
    if (primary.contains('maxresdefault.jpg')) {
      list.add(primary.replaceAll('maxresdefault.jpg', 'hqdefault.jpg'));
      list.add(primary.replaceAll('maxresdefault.jpg', 'mqdefault.jpg'));
    } else if (primary.contains('sddefault.jpg')) {
      list.add(primary.replaceAll('sddefault.jpg', 'hqdefault.jpg'));
    }

    // Google User Content (YouTube Music high-res avatars & covers)
    if (primary.contains('googleusercontent.com') && primary.contains('=')) {
      final base = primary.split('=').first;
      list.add('$base=s500');
      list.add('$base=w500-h500-l90-rj');
      list.add(base);
    }

    // JioSaavn: fallback across 500x500, 150x150, and 50x50 CDN resolutions
    if (primary.contains('500x500')) {
      list.add(primary.replaceAll('500x500', '150x150'));
      list.add(primary.replaceAll('500x500', '50x50'));
    } else if (primary.contains('150x150')) {
      list.add(primary.replaceAll('150x150', '500x500'));
      list.add(primary.replaceAll('150x150', '50x50'));
    }

    // iTunes / Apple: fallback to 300x300 and 100x100 if 600x600 fails
    if (primary.contains('600x600bb')) {
      list.add(primary.replaceAll('600x600bb', '300x300bb'));
      list.add(primary.replaceAll('600x600bb', '100x100bb'));
    }

    _candidates = list.toSet().toList();
  }

  void _handleImageError() {
    if (_candidateIndex < _candidates.length - 1) {
      if (mounted) {
        setState(() {
          _candidateIndex++;
        });
      }
    }
  }

  Widget _buildFallback(BuildContext context) {
    if (widget.errorWidget != null) return widget.errorWidget!;
    final tokens = context.tokens;

    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor ?? tokens.surfaceElevated,
      alignment: Alignment.center,
      child: Icon(
        widget.fallbackIcon,
        color: tokens.textMuted,
        size: (widget.width != null && widget.height != null)
            ? (widget.width! < widget.height! ? widget.width! * 0.45 : widget.height! * 0.45)
            : 24.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_candidates.isEmpty || _candidateIndex >= _candidates.length) {
      content = _buildFallback(context);
    } else {
      final currentUrl = _candidates[_candidateIndex];
      final effectiveCacheWidth = widget.cacheWidth ??
          (widget.width != null ? (widget.width! * 2.5).round() : null);
      final effectiveCacheHeight = widget.cacheHeight ??
          (widget.height != null ? (widget.height! * 2.5).round() : null);

      content = Image.network(
        currentUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: effectiveCacheWidth,
        cacheHeight: effectiveCacheHeight,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return widget.placeholder ?? _buildFallback(context);
        },
        errorBuilder: (context, error, stackTrace) {
          // If we have alternative candidate URLs, switch to the next one
          if (_candidateIndex < _candidates.length - 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleImageError();
            });
            return widget.placeholder ?? _buildFallback(context);
          }
          return _buildFallback(context);
        },
      );
    }

    if (widget.isCircular) {
      return ClipOval(child: content);
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
