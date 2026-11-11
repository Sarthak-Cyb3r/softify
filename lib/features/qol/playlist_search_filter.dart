import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/widgets/shared/app_filter_chip.dart';
import '../../presentation/widgets/shared/app_surface.dart';

/// Scope for filtering tracks in a playlist.
enum PlaylistSearchScope {
  all('All'),
  title('Title'),
  artist('Artist'),
  album('Album');

  final String label;
  const PlaylistSearchScope(this.label);
}

/// Pure helper for filtering tracks against search queries.
class PlaylistSearchFilterHelper {
  const PlaylistSearchFilterHelper._();

  /// Filters a list of tracks against a search query and optional search scope.
  /// Matching is case-insensitive and supports multi-token matching across
  /// title, artist, and album.
  static List<Track> filterTracks({
    required List<Track> tracks,
    required String query,
    PlaylistSearchScope scope = PlaylistSearchScope.all,
  }) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return tracks;

    // Split query by whitespace for multi-token matching (e.g. "queen bohemian")
    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    return tracks.where((track) {
      final title = track.title.toLowerCase();
      final artist = track.artist.toLowerCase();
      final album = (track.album ?? '').toLowerCase();

      switch (scope) {
        case PlaylistSearchScope.title:
          return _matches(title, trimmed, tokens);
        case PlaylistSearchScope.artist:
          return _matches(artist, trimmed, tokens);
        case PlaylistSearchScope.album:
          return _matches(album, trimmed, tokens);
        case PlaylistSearchScope.all:
          final combined = '$title $artist $album';
          return _matches(combined, trimmed, tokens);
      }
    }).toList();
  }

  static bool _matches(String target, String query, List<String> tokens) {
    if (target.contains(query)) return true;
    if (tokens.length > 1) {
      return tokens.every((token) => target.contains(token));
    }
    return false;
  }
}

/// Controller that manages search query, scope, expansion state, and filtering.
class PlaylistSearchFilterController extends ChangeNotifier {
  PlaylistSearchFilterController({
    String initialQuery = '',
    PlaylistSearchScope initialScope = PlaylistSearchScope.all,
    bool initiallyExpanded = false,
  })  : _query = initialQuery,
        _scope = initialScope,
        _isExpanded = initiallyExpanded || initialQuery.trim().isNotEmpty {
    textController.text = initialQuery;
    textController.addListener(_onTextChanged);
  }

  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  String _query = '';
  PlaylistSearchScope _scope = PlaylistSearchScope.all;
  bool _isExpanded = false;

  String get query => _query;
  PlaylistSearchScope get scope => _scope;
  bool get isExpanded => _isExpanded;
  bool get hasActiveFilter => _query.trim().isNotEmpty;

  void _onTextChanged() {
    final text = textController.text;
    if (_query != text) {
      _query = text;
      notifyListeners();
    }
  }

  /// Sets the active search query.
  void setQuery(String newQuery) {
    if (textController.text != newQuery) {
      textController.text = newQuery;
      textController.selection = TextSelection.fromPosition(
        TextPosition(offset: newQuery.length),
      );
    }
  }

  /// Updates the search scope filter.
  void setScope(PlaylistSearchScope newScope) {
    if (_scope != newScope) {
      _scope = newScope;
      notifyListeners();
    }
  }

  /// Clears the search text and active query.
  void clear() {
    textController.clear();
    _query = '';
    notifyListeners();
  }

  /// Expands the search field and focuses the input.
  void expand({bool requestFocus = true}) {
    if (!_isExpanded) {
      _isExpanded = true;
      notifyListeners();
      if (requestFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (focusNode.canRequestFocus) {
            focusNode.requestFocus();
          }
        });
      }
    }
  }

  /// Collapses the search field, clears input, and unfocuses.
  void collapse() {
    if (_isExpanded) {
      _isExpanded = false;
      clear();
      focusNode.unfocus();
      notifyListeners();
    }
  }

  /// Toggles between expanded and collapsed states.
  void toggle() {
    if (_isExpanded) {
      collapse();
    } else {
      expand();
    }
  }

  /// Filters a list of tracks using current query and scope.
  List<Track> filter(List<Track> tracks) {
    return PlaylistSearchFilterHelper.filterTracks(
      tracks: tracks,
      query: _query,
      scope: _scope,
    );
  }

  @override
  void dispose() {
    textController.removeListener(_onTextChanged);
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

/// Family provider for per-playlist search controller state.
final playlistSearchControllerProvider = ChangeNotifierProvider.autoDispose
    .family<PlaylistSearchFilterController, String>(
  (ref, playlistId) => PlaylistSearchFilterController(),
);

/// Collapsible/expandable search & filter bar widget for playlist screens.
///
/// Features:
/// - Smooth animated expansion/collapse using [AppTokens] motion curves.
/// - Glassmorphic / elevated surface styling following Softify visual tokens.
/// - Live match count indicator ("Showing 14 of 120 tracks").
/// - Inline scope filter chips (All, Title, Artist, Album).
/// - Instant clear button with keyboard dismissal.
class PlaylistSearchFilterBar extends ConsumerStatefulWidget {
  final PlaylistSearchFilterController? controller;
  final String? playlistId;
  final int totalTrackCount;
  final int filteredTrackCount;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<PlaylistSearchScope>? onScopeChanged;
  final VoidCallback? onCleared;
  final ValueChanged<bool>? onExpandedChanged;
  final bool collapsible;
  final bool initiallyExpanded;
  final bool showScopeChips;
  final String hintText;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const PlaylistSearchFilterBar({
    super.key,
    this.controller,
    this.playlistId,
    required this.totalTrackCount,
    required this.filteredTrackCount,
    this.onQueryChanged,
    this.onScopeChanged,
    this.onCleared,
    this.onExpandedChanged,
    this.collapsible = true,
    this.initiallyExpanded = false,
    this.showScopeChips = true,
    this.hintText = 'Find in playlist (title, artist, album)...',
    this.padding,
    this.margin,
  });

  @override
  ConsumerState<PlaylistSearchFilterBar> createState() =>
      _PlaylistSearchFilterBarState();
}

class _PlaylistSearchFilterBarState extends ConsumerState<PlaylistSearchFilterBar>
    with SingleTickerProviderStateMixin {
  PlaylistSearchFilterController? _internalController;
  late AnimationController _animController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;

  PlaylistSearchFilterController get _effectiveController {
    if (widget.controller != null) return widget.controller!;
    if (widget.playlistId != null) {
      return ref.watch(playlistSearchControllerProvider(widget.playlistId!));
    }
    return _internalController ??= PlaylistSearchFilterController(
      initiallyExpanded: widget.initiallyExpanded || !widget.collapsible,
    );
  }

  @override
  void initState() {
    super.initState();
    final isInitiallyOpen = !widget.collapsible ||
        widget.initiallyExpanded ||
        (widget.controller?.isExpanded ?? false);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: isInitiallyOpen ? 1.0 : 0.0,
    );

    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 0.8, curve: Curves.easeIn),
    );

    _effectiveController.addListener(_onControllerUpdated);
  }

  @override
  void didUpdateWidget(covariant PlaylistSearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdated);
      _effectiveController.addListener(_onControllerUpdated);
    }
  }

  void _onControllerUpdated() {
    if (!mounted) return;
    final isExpanded = _effectiveController.isExpanded || !widget.collapsible;

    if (isExpanded && _animController.value < 1.0) {
      _animController.forward();
      widget.onExpandedChanged?.call(true);
    } else if (!isExpanded && _animController.value > 0.0) {
      _animController.reverse();
      widget.onExpandedChanged?.call(false);
    }

    widget.onQueryChanged?.call(_effectiveController.query);
    widget.onScopeChanged?.call(_effectiveController.scope);
    setState(() {});
  }

  void _handleToggleExpand() {
    if (_effectiveController.isExpanded) {
      _effectiveController.collapse();
    } else {
      _effectiveController.expand();
    }
  }

  void _handleClear() {
    _effectiveController.clear();
    widget.onCleared?.call();
    setState(() {});
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onControllerUpdated);
    _internalController?.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final controller = _effectiveController;
    final hasActiveQuery = controller.hasActiveFilter;
    final isExpanded = controller.isExpanded || !widget.collapsible;

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: widget.padding ?? EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Collapsed trigger button (shown when collapsible and not fully open)
          if (widget.collapsible && !isExpanded)
            _buildCollapsedTrigger(tokens, controller)
          else ...[
            // 2. Expanded Search Input Field with smooth animation
            SizeTransition(
              sizeFactor: _expandAnimation,
              axisAlignment: -1.0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchInputField(tokens, controller, hasActiveQuery),
                    const SizedBox(height: 8),

                    // 3. Match Count & Filter Status Header
                    _buildMatchCountBar(tokens, controller, hasActiveQuery),

                    // 4. Quick Scope Filter Chips (Optional)
                    if (widget.showScopeChips && hasActiveQuery) ...[
                      const SizedBox(height: 8),
                      _buildScopeFilterRow(tokens, controller),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact trigger displayed before expanding the search bar.
  Widget _buildCollapsedTrigger(
    AppTokens tokens,
    PlaylistSearchFilterController controller,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleToggleExpand,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: tokens.isGlass
                ? tokens.glassSurface.withValues(alpha: 0.3)
                : tokens.surfaceElevated.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            border: Border.all(
              color: tokens.isGlass
                  ? tokens.glassBorder
                  : tokens.divider.withValues(alpha: 0.15),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 18,
                color: tokens.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Find in playlist...',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 13,
                    color: tokens.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.surfaceHighlight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
                child: Text(
                  '${widget.totalTrackCount}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontUi,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Styled input field with clear icon and collapse trigger.
  Widget _buildSearchInputField(
    AppTokens tokens,
    PlaylistSearchFilterController controller,
    bool hasActiveQuery,
  ) {
    final searchInput = TextField(
      controller: controller.textController,
      focusNode: controller.focusNode,
      cursorColor: tokens.accent,
      style: TextStyle(
        fontFamily: AppTheme.fontUi,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: tokens.textPrimary,
      ),
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        hintText: widget.hintText,
        hintStyle: TextStyle(
          fontFamily: AppTheme.fontUi,
          fontSize: 13,
          color: tokens.textMuted,
          fontWeight: FontWeight.w400,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: tokens.accent,
          size: 20,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasActiveQuery)
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: tokens.textSecondary,
                  size: 18,
                ),
                tooltip: 'Clear search',
                splashRadius: 18,
                onPressed: _handleClear,
              ),
            if (widget.collapsible)
              IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: tokens.textSecondary,
                  size: 20,
                ),
                tooltip: 'Close search',
                splashRadius: 18,
                onPressed: _handleToggleExpand,
              ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );

    if (tokens.isGlass) {
      return AppSurface(
        withBlur: false,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: tokens.glassBorder, width: 1.0),
        color: tokens.glassSurface.withValues(alpha: 0.6),
        child: searchInput,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(
          color: tokens.divider.withValues(alpha: 0.2),
          width: 1.0,
        ),
      ),
      child: searchInput,
    );
  }

  /// Match count indicator (e.g. "Showing 14 of 120 tracks").
  Widget _buildMatchCountBar(
    AppTokens tokens,
    PlaylistSearchFilterController controller,
    bool hasActiveQuery,
  ) {
    if (!hasActiveQuery) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '${widget.totalTrackCount} tracks in playlist',
          style: TextStyle(
            fontFamily: AppTheme.fontUi,
            fontSize: 12,
            color: tokens.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final isZero = widget.filteredTrackCount == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isZero ? tokens.error : tokens.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isZero
                  ? 'No matching tracks for "${controller.query.trim()}"'
                  : 'Showing ${widget.filteredTrackCount} of ${widget.totalTrackCount} tracks',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isZero ? tokens.error : tokens.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isZero)
            GestureDetector(
              onTap: _handleClear,
              child: Text(
                'Reset',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: tokens.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Scope filter chips to quickly filter by Title, Artist, Album, or All.
  Widget _buildScopeFilterRow(
    AppTokens tokens,
    PlaylistSearchFilterController controller,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: PlaylistSearchScope.values.map((scope) {
          final isSelected = controller.scope == scope;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: AppFilterChip(
              label: scope.label,
              isSelected: isSelected,
              height: 28,
              onTap: () => controller.setScope(scope),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Convenience sliver wrapper for inserting [PlaylistSearchFilterBar]
/// seamlessly into [CustomScrollView] inside playlist detail screens.
class SliverPlaylistSearchFilterBar extends StatelessWidget {
  final PlaylistSearchFilterController? controller;
  final String? playlistId;
  final int totalTrackCount;
  final int filteredTrackCount;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<PlaylistSearchScope>? onScopeChanged;
  final VoidCallback? onCleared;
  final ValueChanged<bool>? onExpandedChanged;
  final bool collapsible;
  final bool initiallyExpanded;
  final bool showScopeChips;
  final String hintText;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const SliverPlaylistSearchFilterBar({
    super.key,
    this.controller,
    this.playlistId,
    required this.totalTrackCount,
    required this.filteredTrackCount,
    this.onQueryChanged,
    this.onScopeChanged,
    this.onCleared,
    this.onExpandedChanged,
    this.collapsible = true,
    this.initiallyExpanded = false,
    this.showScopeChips = true,
    this.hintText = 'Find in playlist (title, artist, album)...',
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: PlaylistSearchFilterBar(
        controller: controller,
        playlistId: playlistId,
        totalTrackCount: totalTrackCount,
        filteredTrackCount: filteredTrackCount,
        onQueryChanged: onQueryChanged,
        onScopeChanged: onScopeChanged,
        onCleared: onCleared,
        onExpandedChanged: onExpandedChanged,
        collapsible: collapsible,
        initiallyExpanded: initiallyExpanded,
        showScopeChips: showScopeChips,
        hintText: hintText,
        padding: padding,
        margin: margin,
      ),
    );
  }
}
