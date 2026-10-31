import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/lyrics/spotify_lyrics_synchronizer.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import '../../services/lyrics/romanization_service.dart';
import '../providers/player_providers.dart';
import '../providers/settings_providers.dart';
import '../providers/ui_style_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'bouncing_scale_button.dart';

/// Pixel-perfect Apple Music Lyrics Canvas matching the exact UI specification.
/// Features dynamic optical depth-of-field blur on non-active lines, crisp bold
/// active lyric rendering, fluid scrolling playhead sync, and floating action dock
/// (sync offset, quote share, and fullscreen expansion).
class AppleMusicLyricsCanvas extends ConsumerStatefulWidget {
  final Track track;
  final dynamic audioHandler;
  final VoidCallback? onToggleFullscreen;
  final bool isFullScreen;

  const AppleMusicLyricsCanvas({
    super.key,
    required this.track,
    required this.audioHandler,
    this.onToggleFullscreen,
    this.isFullScreen = false,
  });

  @override
  ConsumerState<AppleMusicLyricsCanvas> createState() =>
      _AppleMusicLyricsCanvasState();
}

class _AppleMusicLyricsCanvasState extends ConsumerState<AppleMusicLyricsCanvas> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};

  int _lastActiveIndex = -1;
  int _lastScrolledIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollTimer;
  int _syncOffsetMs = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedOffset();
  }

  @override
  void didUpdateWidget(AppleMusicLyricsCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _lastActiveIndex = -1;
      _lastScrolledIndex = -1;
      _lineKeys.clear();
      _loadSavedOffset();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    _userScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedOffset() async {
    try {
      final db = ref.read(databaseProvider);
      final key = 'lyrics_offset_${widget.track.id}';
      final row = await (db.select(db.settings)..where((t) => t.key.equals(key)))
          .getSingleOrNull();
      if (row != null && mounted) {
        setState(() {
          _syncOffsetMs = int.tryParse(row.value) ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveOffset(int newOffsetMs) async {
    setState(() {
      _syncOffsetMs = newOffsetMs;
    });
    try {
      final db = ref.read(databaseProvider);
      final key = 'lyrics_offset_${widget.track.id}';
      await db.into(db.settings).insertOnConflictUpdate(
            SettingRow(key: key, value: newOffsetMs.toString()),
          );
    } catch (_) {}
  }

  GlobalKey _getKeyForIndex(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  void _scrollToActiveLine(int index, {bool force = false}) {
    if ((_userIsScrolling && !force) || index < 0) return;
    if (!force && index == _lastScrolledIndex) return;

    void performScroll([int retryCount = 0]) {
      if (!mounted || (_userIsScrolling && !force)) return;
      if (!_scrollController.hasClients) {
        if (retryCount < 8) {
          WidgetsBinding.instance.addPostFrameCallback((_) => performScroll(retryCount + 1));
        }
        return;
      }
      _lastScrolledIndex = index;
      final key = _lineKeys[index];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: 0.22,
        );
      } else {
        final targetOffset =
            (index * 68.0).clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    }

    if (WidgetsBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks ||
        WidgetsBinding.instance.schedulerPhase ==
            SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => performScroll());
    } else {
      performScroll();
    }
  }

  void _onUserInteractedWithScroll() {
    _userIsScrolling = true;
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _userIsScrolling = false;
        });
        _scrollToActiveLine(_lastActiveIndex);
      }
    });
  }

  void _showOffsetDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E24),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Lyrics Sync Calibration',
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current offset: ${_syncOffsetMs >= 0 ? "+" : ""}${_syncOffsetMs}ms',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _offsetButton('-500ms', () {
                          _saveOffset(_syncOffsetMs - 500);
                          setSheetState(() {});
                        }),
                        _offsetButton('-100ms', () {
                          _saveOffset(_syncOffsetMs - 100);
                          setSheetState(() {});
                        }),
                        _offsetButton('Reset (0ms)', () {
                          _saveOffset(0);
                          setSheetState(() {});
                        }),
                        _offsetButton('+100ms', () {
                          _saveOffset(_syncOffsetMs + 100);
                          setSheetState(() {});
                        }),
                        _offsetButton('+500ms', () {
                          _saveOffset(_syncOffsetMs + 500);
                          setSheetState(() {});
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _offsetButton(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }

  void _shareActiveLyric(String? activeText) {
    final textToShare = activeText != null && activeText.trim().isNotEmpty
        ? activeText.trim()
        : widget.track.title;
    final shareString =
        '"$textToShare"\n— ${widget.track.artist} (${widget.track.title})\nShared via Softify 🎧';
    Clipboard.setData(ClipboardData(text: shareString));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Lyric quote copied to clipboard',
              style: TextStyle(
                fontFamily: AppTheme.fontUi,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF26262E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(trackLyricsProvider(widget.track));
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final effectivePosition = Duration(
      milliseconds: (position.inMilliseconds + _syncOffsetMs).clamp(0, 9999999),
    );
    final reduceEffects = ref.watch(shouldReduceEffectsProvider);
    final romanizeEnabled = ref.watch(lyricsRomanizeProvider);

    return Stack(
      children: [
        // Lyrics List
        NotificationListener<UserScrollNotification>(
          onNotification: (_) {
            _onUserInteractedWithScroll();
            return false;
          },
          child: lyricsAsync.when(
            loading: () => const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'No lyrics available',
                style: TextStyle(
                  fontFamily: AppTheme.fontUi,
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
            data: (lyrics) {
              if (lyrics == null || lyrics.lines.isEmpty) {
                if (lyrics?.plainLyrics != null &&
                    lyrics!.plainLyrics!.trim().isNotEmpty) {
                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Text(
                      romanizeEnabled
                          ? RomanizationService.romanize(lyrics.plainLyrics!)
                          : lyrics.plainLyrics!,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  );
                }
                return Center(
                  child: Text(
                    'No lyrics found for this song',
                    style: TextStyle(
                      fontFamily: AppTheme.fontUi,
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                );
              }

              final lines = lyrics.lines;
              final activeIdx =
                  SpotifyLyricsSynchronizer.findActiveLineIndex(lines, effectivePosition);

              if (activeIdx >= 0) {
                if (_lastActiveIndex == -1) {
                  _lastActiveIndex = activeIdx;
                  _scrollToActiveLine(activeIdx, force: true);
                } else if (activeIdx != _lastActiveIndex) {
                  _lastActiveIndex = activeIdx;
                  _scrollToActiveLine(activeIdx);
                }
              }

              return NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  if (notification.direction != ScrollDirection.idle) {
                    _onUserInteractedWithScroll();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 64, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(lines.length, (i) {
                      final line = lines[i];
                      final isActive = i == activeIdx;
                      final distance = (i - activeIdx).abs();

                      final double blur;
                      final double opacity;
                      final double fontSize;
                      final FontWeight fontWeight;

                      if (isActive) {
                        blur = 0.0;
                        opacity = 1.0;
                        fontSize = 32.0;
                        fontWeight = FontWeight.w800;
                      } else {
                        if (reduceEffects) {
                          blur = 0.0;
                        } else if (distance == 1) {
                          blur = 1.8;
                        } else if (distance == 2) {
                          blur = 3.6;
                        } else {
                          blur = 5.2;
                        }

                        opacity = (1.0 - (distance * 0.22)).clamp(0.24, 0.65);
                        fontSize = 28.0;
                        fontWeight = FontWeight.w700;
                      }

                      final lineText = romanizeEnabled
                          ? RomanizationService.romanize(line.text)
                          : line.text;

                      Widget textWidget = Text(
                        lineText,
                        style: TextStyle(
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: fontSize,
                          fontWeight: fontWeight,
                          letterSpacing: -0.4,
                          height: 1.28,
                          color: Colors.white.withValues(alpha: opacity),
                        ),
                      );

                      if (blur > 0.0) {
                        textWidget = ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                          child: textWidget,
                        );
                      }

                      return GestureDetector(
                        key: _getKeyForIndex(i),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          try {
                            widget.audioHandler.seek(line.timestamp);
                          } catch (_) {}
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: textWidget,
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),

        // Floating Action Buttons on Right (Screenshot 1: Romanize, Clock, Share, Expand)
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Romanization Toggle Button (Transliterate to English Latin alphabet)
              _floatingGlassButton(
                icon: Icons.translate_rounded,
                isActive: romanizeEnabled,
                badgeText: romanizeEnabled ? 'EN' : null,
                tooltip: romanizeEnabled ? 'Romanization ON (English)' : 'Romanize to English',
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(lyricsRomanizeProvider.notifier).toggle();
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        !romanizeEnabled
                            ? 'Lyrics Romanization (English) enabled'
                            : 'Original script restored',
                      ),
                      duration: const Duration(milliseconds: 900),
                      backgroundColor: const Color(0xFF16161B),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 2. Clock / Sync Calibration Button
              _floatingGlassButton(
                icon: Icons.access_time_rounded,
                onTap: () => _showOffsetDialog(context),
              ),
              const SizedBox(height: 12),

              // 3. Share Active Lyric Button
              _floatingGlassButton(
                icon: Icons.share_rounded,
                onTap: () {
                  final lines = lyricsAsync.valueOrNull?.lines;
                  String? activeText;
                  if (lines != null && _lastActiveIndex >= 0 && _lastActiveIndex < lines.length) {
                    final raw = lines[_lastActiveIndex].text;
                    activeText = romanizeEnabled ? RomanizationService.romanize(raw) : raw;
                  }
                  _shareActiveLyric(activeText);
                },
              ),
              const SizedBox(height: 12),

              // 4. Fullscreen / Expand Button
              _floatingGlassButton(
                icon: Icons.open_in_full_rounded,
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onToggleFullscreen?.call();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _floatingGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    String? badgeText,
    String? tooltip,
  }) {
    Widget button = BouncingScaleButton(
      scaleFactor: 0.90,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFED5564).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.20),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? const Color(0xFFED5564)
                    : Colors.white.withValues(alpha: 0.18),
                width: isActive ? 1.4 : 0.8,
              ),
            ),
            child: Center(
              child: badgeText != null
                  ? Text(
                      badgeText,
                      style: TextStyle(
                        fontFamily: AppTheme.fontUi,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isActive ? Colors.white : Colors.white70,
                      ),
                    )
                  : Icon(
                      icon,
                      color: isActive ? Colors.white : Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip,
        child: button,
      );
    }
    return button;
  }
}
