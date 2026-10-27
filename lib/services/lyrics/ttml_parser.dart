import 'package:xml/xml.dart';

import '../../domain/ports/i_lyrics_provider.dart';

/// Syllable-level word timestamp representation extracted from TTML / Apple Music XML.
class ParsedWord {
  final String text;
  final double startTime; // In seconds
  final double endTime; // In seconds
  final bool hasTrailingSpace;

  const ParsedWord({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.hasTrailingSpace = true,
  });

  ParsedWord copyWith({
    String? text,
    double? startTime,
    double? endTime,
    bool? hasTrailingSpace,
  }) {
    return ParsedWord(
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hasTrailingSpace: hasTrailingSpace ?? this.hasTrailingSpace,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedWord &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          (startTime - other.startTime).abs() < 0.001 &&
          (endTime - other.endTime).abs() < 0.001 &&
          hasTrailingSpace == other.hasTrailingSpace;

  @override
  int get hashCode => Object.hash(text, startTime, endTime, hasTrailingSpace);

  @override
  String toString() =>
      'ParsedWord(text: $text, start: $startTime, end: $endTime, space: $hasTrailingSpace)';
}

/// A parsed lyric line containing text, onset timestamp, syllable-level words,
/// vocalist agent tag (e.g. v1, v2), and background vocal indicators.
class ParsedLine {
  final String text;
  final double startTime; // In seconds
  final List<ParsedWord> words;
  final String? agent;
  final bool isBackground;
  final List<ParsedLine> backgroundLines;

  const ParsedLine({
    required this.text,
    required this.startTime,
    required this.words,
    this.agent,
    this.isBackground = false,
    this.backgroundLines = const [],
  });

  ParsedLine copyWith({
    String? text,
    double? startTime,
    List<ParsedWord>? words,
    String? agent,
    bool? isBackground,
    List<ParsedLine>? backgroundLines,
  }) {
    return ParsedLine(
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      words: words ?? this.words,
      agent: agent ?? this.agent,
      isBackground: isBackground ?? this.isBackground,
      backgroundLines: backgroundLines ?? this.backgroundLines,
    );
  }

  @override
  String toString() =>
      'ParsedLine(text: $text, start: $startTime, words: ${words.length}, agent: $agent, bg: $isBackground)';
}

class _SpanInfo {
  final String text;
  final double startTime;
  final double endTime;
  final bool hasTrailingSpace;

  const _SpanInfo({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.hasTrailingSpace,
  });
}

/// Advanced Apple Music / TTML XML syllable-level karaoke parser.
/// Reverse-engineered from Metrolist kernel architecture with support for
/// word-by-word timestamps, duet vocalist agents (`v1`, `v2`, `v1000`),
/// offset adjustments, and background vocals (`x-bg`).
class TTMLParser {
  TTMLParser._();

  static const String ttmlParameterNs = 'http://www.w3.org/ns/ttml#parameter';
  static const String ttmlMetadataNs = 'http://www.w3.org/ns/ttml#metadata';

  /// Parses a raw TTML XML document string into structured [ParsedLine]s.
  static List<ParsedLine> parseTTML(String ttml) {
    if (ttml.trim().isEmpty) return const [];

    try {
      final document = XmlDocument.parse(ttml);
      final root = document.rootElement;

      double globalOffset = 0.0;
      final head = _findChild(root, 'head');
      if (head != null) {
        final meta = _findChild(head, 'metadata');
        if (meta != null) {
          final audio = _findChild(meta, 'audio');
          if (audio != null) {
            final offsetAttr = _getAttr(audio, 'lyricOffset');
            if (offsetAttr != null) {
              globalOffset = double.tryParse(offsetAttr) ?? 0.0;
            }
          }
        }
      }

      final body = _findChild(root, 'body');
      if (body == null) return const [];

      final lines = <ParsedLine>[];
      _walk(body, lines, globalOffset, null);
      return lines;
    } catch (_) {
      return const [];
    }
  }

  static XmlElement? _findChild(XmlElement parent, String localName) {
    for (final child in parent.children) {
      if (child is XmlElement) {
        if (child.name.local == localName) {
          return child;
        }
      }
    }
    return null;
  }

  static String? _getAttr(XmlElement el, String localName) {
    for (final attr in el.attributes) {
      if (attr.name.local == localName) {
        return attr.value;
      }
    }
    return null;
  }

  static String? _timingAttr(XmlElement el, String localName) {
    for (final attr in el.attributes) {
      if (attr.name.local == localName) {
        return attr.value;
      }
    }
    return null;
  }

  static void _walk(
    XmlElement element,
    List<ParsedLine> lines,
    double offset,
    String? parentAgent,
  ) {
    final name = element.name.local;
    var currentAgent = parentAgent;

    switch (name) {
      case 'div':
        final a = _getAttr(element, 'agent');
        if (a != null && a.isNotEmpty) {
          currentAgent = a;
        }
        break;
      case 'p':
        _parseP(element, lines, offset, currentAgent);
        return; // Don't descend into p, _parseP handles children
    }

    for (final child in element.children) {
      if (child is XmlElement) {
        _walk(child, lines, offset, currentAgent);
      }
    }
  }

  static void _parseP(
    XmlElement p,
    List<ParsedLine> lines,
    double offset,
    String? divAgent,
  ) {
    var begin = _timingAttr(p, 'begin');
    if (begin == null || begin.isEmpty) {
      begin = _findFirstSpanBegin(p);
      if (begin == null || begin.isEmpty) {
        return;
      }
    }

    final startTime = parseTime(begin) + offset;
    final spanInfos = <_SpanInfo>[];
    final backgroundLines = <ParsedLine>[];

    final pAgentAttr = _getAttr(p, 'agent');
    final agent = (pAgentAttr != null && pAgentAttr.isNotEmpty)
        ? pAgentAttr
        : divAgent;
    final isPBackground = _getAttr(p, 'role') == 'x-bg';

    final children = p.children;
    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      if (child is XmlElement && child.name.local == 'span') {
        final role = _getAttr(child, 'role');
        switch (role) {
          case 'x-bg':
            if (isPBackground) {
              _parseWordSpan(child, offset, spanInfos, i, children);
            } else {
              final bgLine = _parseBackgroundSpan(child, startTime, offset);
              if (bgLine != null) {
                backgroundLines.add(bgLine);
              }
            }
            break;
          case 'x-translation':
          case 'x-roman':
            // Ignored in standard primary lyric stream
            break;
          default:
            _parseWordSpan(child, offset, spanInfos, i, children);
            break;
        }
      }
    }

    final words = _mergeSpansIntoWords(spanInfos);
    final lineText = words.isEmpty
        ? _getDirectText(p).trim()
        : _buildLineText(words);

    if (lineText.isNotEmpty) {
      final bgLines = backgroundLines.isNotEmpty
          ? [
              ParsedLine(
                text: backgroundLines.map((l) => l.text).join(' '),
                startTime: backgroundLines
                    .map((l) => l.startTime)
                    .reduce((a, b) => a < b ? a : b),
                words: backgroundLines.expand((l) => l.words).toList(),
                isBackground: true,
              ),
            ]
          : const <ParsedLine>[];

      lines.add(
        ParsedLine(
          text: lineText,
          startTime: startTime,
          words: words,
          agent: agent,
          isBackground: isPBackground,
          backgroundLines: bgLines,
        ),
      );
    } else if (backgroundLines.isNotEmpty) {
      lines.add(
        ParsedLine(
          text: backgroundLines.map((l) => l.text).join(' '),
          startTime: backgroundLines
              .map((l) => l.startTime)
              .reduce((a, b) => a < b ? a : b),
          words: backgroundLines.expand((l) => l.words).toList(),
          isBackground: true,
        ),
      );
    }
  }

  static String? _findFirstSpanBegin(XmlElement p) {
    String? best;
    double bestSeconds = double.infinity;

    for (final child in p.children) {
      if (child is XmlElement && child.name.local == 'span') {
        final b = _timingAttr(child, 'begin');
        if (b != null && b.isNotEmpty) {
          final s = parseTime(b);
          if (s < bestSeconds) {
            bestSeconds = s;
            best = b;
          }
        }
      }
    }
    return best;
  }

  static void _parseWordSpan(
    XmlElement span,
    double offset,
    List<_SpanInfo> spanInfos,
    int nodeIndex,
    List<XmlNode> siblings,
  ) {
    final begin = _timingAttr(span, 'begin');
    final end = _timingAttr(span, 'end');
    final text = span.innerText;

    if (begin != null &&
        begin.isNotEmpty &&
        end != null &&
        end.isNotEmpty) {
      bool space = false;
      if (text.isNotEmpty && text[text.length - 1].trim().isEmpty) {
        space = true;
      } else if (nodeIndex + 1 < siblings.length) {
        final next = siblings[nodeIndex + 1];
        if (next is XmlText &&
            next.value.isNotEmpty &&
            next.value[0].trim().isEmpty) {
          space = true;
        }
      }

      spanInfos.add(
        _SpanInfo(
          text: text,
          startTime: parseTime(begin) + offset,
          endTime: parseTime(end) + offset,
          hasTrailingSpace: space,
        ),
      );
    }
  }

  static ParsedLine? _parseBackgroundSpan(
    XmlElement span,
    double parentStart,
    double offset,
  ) {
    final begin = _timingAttr(span, 'begin');
    final start =
        (begin != null && begin.isNotEmpty) ? parseTime(begin) + offset : parentStart;
    final spanInfos = <_SpanInfo>[];

    final children = span.children;
    bool hasSpans = false;

    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      if (child is XmlElement && child.name.local == 'span') {
        hasSpans = true;
        final role = _getAttr(child, 'role');
        if (role != 'x-translation' && role != 'x-roman') {
          _parseWordSpan(child, offset, spanInfos, i, children);
        }
      }
    }

    if (!hasSpans) {
      final text = span.innerText.trim();
      return ParsedLine(
        text: text,
        startTime: start,
        words: const [],
        isBackground: true,
      );
    }

    final words = _mergeSpansIntoWords(spanInfos);
    final text = words.isEmpty ? _getDirectText(span).trim() : _buildLineText(words);
    return ParsedLine(
      text: text,
      startTime: start,
      words: words,
      isBackground: true,
    );
  }

  static String _getDirectText(XmlElement el) {
    final sb = StringBuffer();
    for (final child in el.children) {
      if (child is XmlText) {
        sb.write(child.value);
      } else if (child is XmlElement && child.name.local == 'span') {
        final role = _getAttr(child, 'role');
        if (role != 'x-bg' && role != 'x-translation' && role != 'x-roman') {
          sb.write(child.innerText);
        }
      }
    }
    return sb.toString();
  }

  static String _buildLineText(List<ParsedWord> words) {
    final sb = StringBuffer();
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      sb.write(w.text);
      if (w.hasTrailingSpace &&
          !w.text.endsWith('-') &&
          i < words.length - 1) {
        sb.write(' ');
      }
    }
    return sb.toString().trim();
  }

  static List<ParsedWord> _mergeSpansIntoWords(List<_SpanInfo> spanInfos) {
    if (spanInfos.isEmpty) return const [];
    final words = <ParsedWord>[];
    var text = StringBuffer(spanInfos[0].text);
    var start = spanInfos[0].startTime;
    var end = spanInfos[0].endTime;

    for (int i = 1; i < spanInfos.length; i++) {
      final prev = spanInfos[i - 1];
      final curr = spanInfos[i];
      if (prev.hasTrailingSpace && !prev.text.endsWith('-')) {
        words.add(
          ParsedWord(
            text: text.toString(),
            startTime: start,
            endTime: end,
            hasTrailingSpace: true,
          ),
        );
        text = StringBuffer(curr.text);
        start = curr.startTime;
        end = curr.endTime;
      } else {
        text.write(curr.text);
        end = curr.endTime;
      }
    }

    words.add(
      ParsedWord(
        text: text.toString(),
        startTime: start,
        endTime: end,
        hasTrailingSpace: spanInfos.last.hasTrailingSpace,
      ),
    );

    return words
        .map((w) => w.copyWith(text: w.text.trim()))
        .where((w) => w.text.isNotEmpty)
        .toList();
  }

  /// Parses timestamps like `00:01.500`, `01:00:01.500`, `1.5s`, `2000ms`, `1.5m`, `1h`, `2.5`.
  static double parseTime(String time) {
    final t = time.trim();
    final c1 = t.indexOf(':');
    if (c1 != -1) {
      final c2 = t.lastIndexOf(':');
      if (c1 == c2) {
        final min = int.tryParse(t.substring(0, c1)) ?? 0;
        final sec = double.tryParse(t.substring(c1 + 1)) ?? 0.0;
        return min * 60.0 + sec;
      } else {
        final hours = int.tryParse(t.substring(0, c1)) ?? 0;
        final min = int.tryParse(t.substring(c1 + 1, c2)) ?? 0;
        final sec = double.tryParse(t.substring(c2 + 1)) ?? 0.0;
        return hours * 3600.0 + min * 60.0 + sec;
      }
    }

    if (t.endsWith('ms')) {
      final val = double.tryParse(t.substring(0, t.length - 2)) ?? 0.0;
      return val / 1000.0;
    }

    final s = (t.endsWith('s') || t.endsWith('m') || t.endsWith('h'))
        ? t.substring(0, t.length - 1)
        : t;
    final v = double.tryParse(s) ?? 0.0;
    if (t.endsWith('m')) return v * 60.0;
    if (t.endsWith('h')) return v * 3600.0;
    return v;
  }

  /// Formats seconds into standard LRC time tag `[mm:ss.xx]`.
  static String formatLrcTime(double time) {
    final totalMs = (time * 1000).round();
    final m = totalMs ~/ 60000;
    final s = (totalMs % 60000) ~/ 1000;
    final c = (totalMs % 1000) ~/ 10;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    final cStr = c.toString().padLeft(2, '0');
    return '[$mStr:$sStr.$cStr]';
  }

  /// Converts a parsed TTML lyric stream into extended LRC format with
  /// vocalist agent tags `{agent:v1}`, `{agent:v2}`, background markers `{bg}`,
  /// and rich word sync `<word:start:end|...>`.
  static String toLRC(List<ParsedLine> lines) {
    final agentMap = <String, String>{};

    // Phase 1: Preserve explicit v1, v2, v1000
    for (final line in lines) {
      final raw = line.agent?.toLowerCase();
      if (raw != null && (raw == 'v1' || raw == 'v2' || raw == 'v1000')) {
        agentMap[raw] = raw;
      }
    }

    // Phase 2: Map other agents to v1/v2 if available
    int nextNum = 1;
    for (final line in lines) {
      final raw = line.agent?.toLowerCase();
      if (raw != null && !agentMap.containsKey(raw)) {
        while (nextNum <= 2 &&
            (agentMap.containsKey('v$nextNum') ||
                agentMap.values.contains('v$nextNum'))) {
          nextNum++;
        }
        agentMap[raw] = (nextNum <= 2) ? 'v$nextNum' : 'v1';
      }
    }

    // v1000 (group) shares display slot with v2 when a primary v1 vocalist exists
    if (agentMap.containsKey('v1000') && agentMap.containsKey('v1')) {
      agentMap['v1000'] = 'v2';
    }

    final hasBackgroundLine =
        lines.any((l) => l.isBackground || l.backgroundLines.isNotEmpty);
    final multi = agentMap.length > 1 ||
        (agentMap.length == 1 && !agentMap.containsKey('v1')) ||
        (hasBackgroundLine &&
            agentMap.length == 1 &&
            agentMap.containsKey('v1'));

    final sb = StringBuffer();
    bool lastBg = false;

    for (final line in lines) {
      final time = formatLrcTime(line.startTime);
      final isBg = line.isBackground;
      if (!isBg) lastBg = false;

      final agentId = agentMap[line.agent?.toLowerCase()];
      String tag = '';
      if (isBg) {
        tag = lastBg ? '' : '{bg}';
      } else if (multi && agentId != null) {
        tag = '{agent:$agentId}';
      }
      if (isBg) lastBg = true;

      sb.write(time);
      sb.write(tag);
      sb.write(line.text);
      sb.write('\n');

      if (line.words.isNotEmpty) {
        sb.write('<');
        for (int i = 0; i < line.words.length; i++) {
          final w = line.words[i];
          sb.write('${w.text}:${w.startTime}:${w.endTime}');
          if (i < line.words.length - 1) sb.write('|');
        }
        sb.write('>\n');
      }

      for (final bg in line.backgroundLines) {
        final bTag = lastBg ? '' : '{bg}';
        sb.write(formatLrcTime(bg.startTime));
        sb.write(bTag);
        sb.write(bg.text);
        sb.write('\n');
        lastBg = true;
        if (bg.words.isNotEmpty) {
          sb.write('<');
          for (int i = 0; i < bg.words.length; i++) {
            final w = bg.words[i];
            sb.write('${w.text}:${w.startTime}:${w.endTime}');
            if (i < bg.words.length - 1) sb.write('|');
          }
          sb.write('>\n');
        }
      }
    }

    return sb.toString();
  }

  /// Converts parsed TTML lines into Softify's native [LyricLine] domain entities.
  static List<LyricLine> toLyricLines(List<ParsedLine> lines) {
    final result = <LyricLine>[];

    for (final line in lines) {
      final lineTimestamp =
          Duration(milliseconds: (line.startTime * 1000).round());
      final words = line.words.map((w) {
        final wordStart =
            Duration(milliseconds: (w.startTime * 1000).round());
        final wordEnd = Duration(milliseconds: (w.endTime * 1000).round());
        final dur = wordEnd > wordStart ? wordEnd - wordStart : null;
        return LyricWord(
          timestamp: wordStart,
          text: w.text,
          duration: dur,
        );
      }).toList();

      result.add(
        LyricLine(
          timestamp: lineTimestamp,
          text: line.text,
          words: words.isNotEmpty ? words : null,
          agent: line.agent,
        ),
      );

      for (final bg in line.backgroundLines) {
        final bgTimestamp =
            Duration(milliseconds: (bg.startTime * 1000).round());
        final bgWords = bg.words.map((w) {
          final wordStart =
              Duration(milliseconds: (w.startTime * 1000).round());
          final wordEnd = Duration(milliseconds: (w.endTime * 1000).round());
          final dur = wordEnd > wordStart ? wordEnd - wordStart : null;
          return LyricWord(
            timestamp: wordStart,
            text: w.text,
            duration: dur,
          );
        }).toList();

        result.add(
          LyricLine(
            timestamp: bgTimestamp,
            text: bg.text,
            words: bgWords.isNotEmpty ? bgWords : null,
            agent: bg.agent ?? line.agent,
          ),
        );
      }
    }

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  /// Converts parsed TTML lines into a complete [SyncedLyrics] container.
  static SyncedLyrics toSyncedLyrics(
    String trackId,
    List<ParsedLine> lines, {
    String? rawLrc,
    String? providerName,
  }) {
    final lyricLines = toLyricLines(lines);
    final hasWords = lines.any((l) => l.words.isNotEmpty);

    return SyncedLyrics(
      trackId: trackId,
      lines: lyricLines,
      rawLrc: rawLrc ?? toLRC(lines),
      plainLyrics: lines.map((l) => l.text).join('\n'),
      syncType: hasWords ? 'SYLLABLE_SYNCED' : 'LINE_SYNCED',
      providerName: providerName ?? 'BetterLyrics (TTML)',
    );
  }
}
