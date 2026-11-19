use crate::models::{LyricsLine, LyricsWord, SyncedLyrics};
use regex::Regex;

/// Parses LRC strings (standard or enhanced) into SyncedLyrics.
/// If true word timestamps (<mm:ss.xx>) are absent, marks lines as is_line_timed = true
/// with an empty words vector (NO synthetic character-proportional estimation).
pub fn parse_lrc(lrc_text: &str) -> SyncedLyrics {
    let line_re = Regex::new(r"\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\](.*)").unwrap();
    let word_tag_re = Regex::new(r"<(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?>").unwrap();

    let mut raw_lines = Vec::new();
    let mut plain_buffer = Vec::new();
    let mut has_any_word_tags = false;

    for line in lrc_text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        if let Some(caps) = line_re.captures(trimmed) {
            let minutes: u64 = caps[1].parse().unwrap_or(0);
            let seconds: u64 = caps[2].parse().unwrap_or(0);
            let frac_str = caps.get(3).map(|m| m.as_str()).unwrap_or("0");
            let ms: u64 = if frac_str.len() == 2 {
                frac_str.parse::<u64>().unwrap_or(0) * 10
            } else {
                frac_str.parse::<u64>().unwrap_or(0)
            };

            let start_ms = minutes * 60_000 + seconds * 1_000 + ms;
            let raw_content = caps[4].trim();

            if word_tag_re.is_match(raw_content) {
                has_any_word_tags = true;
            }

            // Clean line text for plain text buffer and display
            let clean_text = word_tag_re.replace_all(raw_content, "").trim().to_string();
            if !clean_text.is_empty() {
                plain_buffer.push(clean_text.clone());
                raw_lines.push((start_ms, raw_content.to_string(), clean_text));
            }
        } else if !trimmed.starts_with('[') {
            plain_buffer.push(trimmed.to_string());
        }
    }

    if raw_lines.is_empty() {
        return SyncedLyrics {
            is_synced: false,
            is_word_synced: false,
            lines: Vec::new(),
            plain_text: if !plain_buffer.is_empty() { Some(plain_buffer.join("\n")) } else { None },
            provider: "lrc".to_string(),
        };
    }

    // Sort by start_ms
    raw_lines.sort_by_key(|(start, _, _)| *start);

    let mut lines = Vec::new();
    let count = raw_lines.len();

    for i in 0..count {
        let (start_ms, raw_content, clean_text) = &raw_lines[i];
        let start_ms = *start_ms;

        // Determine line end_ms
        let next_start = if i + 1 < count {
            raw_lines[i + 1].0
        } else {
            start_ms + 4_000
        };

        let duration = if next_start > start_ms {
            (next_start - start_ms).clamp(1_000, 8_000)
        } else {
            3_000
        };
        let end_ms = start_ms + duration;

        // Parse words: either from enhanced tags or none (never synthetic)
        let (words, is_line_timed) = if has_any_word_tags && word_tag_re.is_match(raw_content) {
            let parsed = parse_enhanced_words(raw_content, start_ms, end_ms);
            let line_timed = parsed.is_empty();
            (parsed, line_timed)
        } else {
            (Vec::new(), true)
        };

        lines.push(LyricsLine {
            start_ms,
            end_ms,
            text: clean_text.clone(),
            words,
            is_line_timed,
            is_background: false,
        });
    }

    let is_synced = !lines.is_empty();
    let is_word_synced = has_any_word_tags && lines.iter().any(|l| !l.words.is_empty());

    SyncedLyrics {
        is_synced,
        is_word_synced,
        lines,
        plain_text: if !plain_buffer.is_empty() { Some(plain_buffer.join("\n")) } else { None },
        provider: if is_word_synced { "enhanced-lrc".to_string() } else { "lrc".to_string() },
    }
}

/// Parses words with enhanced LRC tags: `<mm:ss.xx> word <mm:ss.xx> word`
fn parse_enhanced_words(raw_content: &str, line_start_ms: u64, line_end_ms: u64) -> Vec<LyricsWord> {
    let tag_re = Regex::new(r"<(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?>").unwrap();
    let mut words = Vec::new();

    let mut last_tag_ms = line_start_ms;
    let mut last_word_start = 0;

    for mat in tag_re.find_iter(raw_content) {
        if mat.start() > last_word_start {
            let word_text = raw_content[last_word_start..mat.start()].trim();
            if !word_text.is_empty() {
                let current_tag_ms = parse_tag_ms(mat.as_str());
                words.push(LyricsWord {
                    text: word_text.to_string(),
                    start_ms: last_tag_ms,
                    end_ms: current_tag_ms.max(last_tag_ms + 100),
                });
                last_tag_ms = current_tag_ms;
            }
        } else {
            last_tag_ms = parse_tag_ms(mat.as_str());
        }
        last_word_start = mat.end();
    }

    if last_word_start < raw_content.len() {
        let remaining = raw_content[last_word_start..].trim();
        if !remaining.is_empty() {
            words.push(LyricsWord {
                text: remaining.to_string(),
                start_ms: last_tag_ms,
                end_ms: line_end_ms.max(last_tag_ms + 200),
            });
        }
    }

    words
}

fn parse_tag_ms(tag_str: &str) -> u64 {
    let re = Regex::new(r"<(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?>").unwrap();
    if let Some(caps) = re.captures(tag_str) {
        let minutes: u64 = caps[1].parse().unwrap_or(0);
        let seconds: u64 = caps[2].parse().unwrap_or(0);
        let frac_str = caps.get(3).map(|m| m.as_str()).unwrap_or("0");
        let ms: u64 = if frac_str.len() == 2 {
            frac_str.parse::<u64>().unwrap_or(0) * 10
        } else {
            frac_str.parse::<u64>().unwrap_or(0)
        };
        minutes * 60_000 + seconds * 1_000 + ms
    } else {
        0
    }
}

/// Parses TTML and timestamp attributes (e.g. "00:01.230", "1.23s", "1230ms", "12.5") into ms.
pub fn parse_time_str(time_str: &str) -> u64 {
    let t = time_str.trim();
    if t.is_empty() {
        return 0;
    }
    if t.contains(':') {
        let parts: Vec<&str> = t.split(':').collect();
        return match parts.len() {
            2 => {
                let min = parts[0].parse::<u64>().unwrap_or(0);
                let sec_f = parts[1].parse::<f64>().unwrap_or(0.0);
                min * 60_000 + (sec_f * 1000.0) as u64
            }
            3 => {
                let hr = parts[0].parse::<u64>().unwrap_or(0);
                let min = parts[1].parse::<u64>().unwrap_or(0);
                let sec_f = parts[2].parse::<f64>().unwrap_or(0.0);
                hr * 3_600_000 + min * 60_000 + (sec_f * 1000.0) as u64
            }
            _ => 0,
        };
    }

    if let Some(ms_str) = t.strip_suffix("ms") {
        return ms_str.parse::<u64>().unwrap_or(0);
    }
    if let Some(s_str) = t.strip_suffix('s') {
        let sec_f = s_str.parse::<f64>().unwrap_or(0.0);
        return (sec_f * 1000.0) as u64;
    }
    if let Some(m_str) = t.strip_suffix('m') {
        let min_f = m_str.parse::<f64>().unwrap_or(0.0);
        return (min_f * 60_000.0) as u64;
    }

    if let Ok(sec_f) = t.parse::<f64>() {
        (sec_f * 1000.0) as u64
    } else {
        0
    }
}

pub fn decode_xml_entities(s: &str) -> String {
    let mut result = s
        .replace("&apos;", "'")
        .replace("&#x27;", "'")
        .replace("&#39;", "'")
        .replace("&quot;", "\"")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">");

    if result.contains("&#") {
        let re_hex = Regex::new(r"&#x([0-9a-fA-F]+);").unwrap();
        result = re_hex
            .replace_all(&result, |caps: &regex::Captures| {
                if let Ok(code) = u32::from_str_radix(&caps[1], 16) {
                    if let Some(ch) = char::from_u32(code) {
                        return ch.to_string();
                    }
                }
                caps[0].to_string()
            })
            .to_string();

        let re_dec = Regex::new(r"&#([0-9]+);").unwrap();
        result = re_dec
            .replace_all(&result, |caps: &regex::Captures| {
                if let Ok(code) = caps[1].parse::<u32>() {
                    if let Some(ch) = char::from_u32(code) {
                        return ch.to_string();
                    }
                }
                caps[0].to_string()
            })
            .to_string();
    }
    result
}

fn extract_attribute<'a>(tag: &'a str, attr_name: &str) -> Option<&'a str> {
    let patterns = [
        format!("{}=\"", attr_name),
        format!("itunes:{}=\"", attr_name),
        format!("ttm:{}=\"", attr_name),
        format!("lrc:{}=\"", attr_name),
    ];
    for p in &patterns {
        if let Some(pos) = tag.find(p.as_str()) {
            let start = pos + p.len();
            if let Some(end) = tag[start..].find('"') {
                return Some(&tag[start..start + end]);
            }
        }
    }
    None
}

/// Parses TTML XML (Apple Music / BetterLyrics / lrc.red).
pub fn parse_ttml(ttml: &str) -> SyncedLyrics {
    let p_regex = Regex::new(r"(?s)<p\b([^>]*)>(.*?)</p>").unwrap();
    let span_regex = Regex::new(r"(?s)<span\b([^>]*)>(.*?)</span>").unwrap();
    let strip_tags_regex = Regex::new(r"<[^>]+>").unwrap();

    let mut lines = Vec::new();
    let mut plain_buffer = Vec::new();
    let mut has_word_sync = false;

    for p_cap in p_regex.captures_iter(ttml) {
        let p_attrs = &p_cap[1];
        let p_content = &p_cap[2];

        let p_begin_str = extract_attribute(p_attrs, "begin");
        let p_end_str = extract_attribute(p_attrs, "end");
        let p_role = extract_attribute(p_attrs, "role").unwrap_or("");
        let is_p_bg = p_role == "x-bg";

        let mut words = Vec::new();
        let mut full_text_spans = Vec::new();

        for span_cap in span_regex.captures_iter(p_content) {
            let span_attrs = &span_cap[1];
            let span_raw_text = &span_cap[2];
            let span_clean_text = decode_xml_entities(&strip_tags_regex.replace_all(span_raw_text, ""));

            let span_begin_str = extract_attribute(span_attrs, "begin");
            let span_end_str = extract_attribute(span_attrs, "end");

            if let (Some(b_str), Some(e_str)) = (span_begin_str, span_end_str) {
                let start_ms = parse_time_str(b_str);
                let end_ms = parse_time_str(e_str);
                let text_trimmed = span_clean_text.trim();
                if !text_trimmed.is_empty() {
                    words.push(LyricsWord {
                        text: text_trimmed.to_string(),
                        start_ms,
                        end_ms,
                    });
                }
            }
            if !span_clean_text.trim().is_empty() {
                full_text_spans.push(span_clean_text);
            }
        }

        let line_text = if !full_text_spans.is_empty() {
            full_text_spans.join("").trim().to_string()
        } else {
            decode_xml_entities(&strip_tags_regex.replace_all(p_content, "")).trim().to_string()
        };

        if line_text.is_empty() {
            continue;
        }

        let start_ms = if let Some(b) = p_begin_str {
            parse_time_str(b)
        } else if let Some(w0) = words.first() {
            w0.start_ms
        } else {
            0
        };

        let end_ms = if let Some(e) = p_end_str {
            parse_time_str(e)
        } else if let Some(w_last) = words.last() {
            w_last.end_ms
        } else {
            start_ms + 3000
        };

        let is_line_timed = words.is_empty();
        if !words.is_empty() {
            has_word_sync = true;
        }

        plain_buffer.push(line_text.clone());
        lines.push(LyricsLine {
            start_ms,
            end_ms,
            text: line_text,
            words,
            is_line_timed,
            is_background: is_p_bg,
        });
    }

    lines.sort_by_key(|l| l.start_ms);

    let is_synced = !lines.is_empty();
    SyncedLyrics {
        is_synced,
        is_word_synced: has_word_sync,
        lines,
        plain_text: if !plain_buffer.is_empty() { Some(plain_buffer.join("\n")) } else { None },
        provider: "ttml".to_string(),
    }
}

/// Parses YouTube caption track json3 (fmt=json3).
pub fn parse_youtube_json3(json_str: &str) -> SyncedLyrics {
    let Ok(val) = serde_json::from_str::<serde_json::Value>(json_str) else {
        return SyncedLyrics {
            is_synced: false,
            is_word_synced: false,
            lines: Vec::new(),
            plain_text: None,
            provider: "youtube-captions".to_string(),
        };
    };

    let events = match val.get("events").and_then(|v| v.as_array()) {
        Some(evs) => evs,
        None => {
            return SyncedLyrics {
                is_synced: false,
                is_word_synced: false,
                lines: Vec::new(),
                plain_text: None,
                provider: "youtube-captions".to_string(),
            };
        }
    };

    let mut lines = Vec::new();
    let mut plain_buffer = Vec::new();
    let mut has_any_words = false;

    for event in events {
        let Some(start_ms) = event.get("tStartMs").and_then(|v| v.as_u64()) else {
            continue;
        };
        let duration_ms = event.get("dDurationMs").and_then(|v| v.as_u64()).unwrap_or(3000);
        let end_ms = start_ms + duration_ms;

        let segs = event.get("segs").and_then(|v| v.as_array());
        if let Some(segs) = segs {
            let has_word_offsets = segs.iter().any(|s| {
                s.get("tOffsetMs").and_then(|v| v.as_u64()).map(|o| o > 0).unwrap_or(false)
            });

            let mut line_text_builder = String::new();
            let mut words = Vec::new();

            for (idx, seg) in segs.iter().enumerate() {
                let seg_text = seg.get("utf8").and_then(|v| v.as_str()).unwrap_or("");
                line_text_builder.push_str(seg_text);

                if has_word_offsets {
                    let offset_ms = seg.get("tOffsetMs").and_then(|v| v.as_u64()).unwrap_or(0);
                    let word_start = start_ms + offset_ms;
                    let clean_seg = seg_text.replace('\n', " ").trim().to_string();
                    if !clean_seg.is_empty() && clean_seg != "♪" && clean_seg != "♫" {
                        let next_offset = if idx + 1 < segs.len() {
                            segs[idx + 1].get("tOffsetMs").and_then(|v| v.as_u64()).map(|o| start_ms + o)
                        } else {
                            None
                        };
                        let word_end = next_offset.unwrap_or(end_ms).max(word_start + 50);
                        words.push(LyricsWord {
                            text: clean_seg,
                            start_ms: word_start,
                            end_ms: word_end,
                        });
                    }
                }
            }

            let clean_line = line_text_builder
                .replace('\n', " ")
                .trim_matches(|c| c == '♪' || c == '♫' || c == ' ')
                .trim()
                .to_string();

            if !clean_line.is_empty() {
                plain_buffer.push(clean_line.clone());
                let is_line_timed = words.is_empty();
                if !words.is_empty() {
                    has_any_words = true;
                }
                lines.push(LyricsLine {
                    start_ms,
                    end_ms,
                    text: clean_line,
                    words,
                    is_line_timed,
                    is_background: false,
                });
            }
        }
    }

    let is_synced = !lines.is_empty();
    SyncedLyrics {
        is_synced,
        is_word_synced: has_any_words,
        lines,
        plain_text: if !plain_buffer.is_empty() { Some(plain_buffer.join("\n")) } else { None },
        provider: "youtube-captions".to_string(),
    }
}

fn unquote_yaml(s: &str) -> String {
    let s = s.trim();
    if s.starts_with('\'') && s.ends_with('\'') && s.len() >= 2 {
        s[1..s.len() - 1].replace("''", "'")
    } else if s.starts_with('"') && s.ends_with('"') && s.len() >= 2 {
        s[1..s.len() - 1].replace("\\\"", "\"")
    } else {
        s.to_string()
    }
}

/// Parses LRCLIB `lyricsfile` format (YAML-like line/words structure)
pub fn parse_lrclib_lyricsfile(lyricsfile_str: &str) -> Option<SyncedLyrics> {
    if !lyricsfile_str.contains("lines:") || !lyricsfile_str.contains("start_ms:") {
        return None;
    }

    let mut lines = Vec::new();
    let mut plain_buffer = Vec::new();

    let mut current_line_text = String::new();
    let mut current_line_start: u64 = 0;
    let mut current_line_end: u64 = 0;
    let mut current_words: Vec<LyricsWord> = Vec::new();
    let mut in_lines = false;
    let mut in_words = false;

    let mut current_word_text = String::new();
    let mut current_word_start: u64 = 0;
    let mut current_word_end: u64 = 0;

    let flush_word = |words: &mut Vec<LyricsWord>, text: &mut String, start: u64, explicit_end: u64| {
        let trimmed = text.trim();
        if !trimmed.is_empty() {
            let end = if explicit_end > start {
                explicit_end
            } else {
                0
            };
            words.push(LyricsWord {
                text: trimmed.to_string(),
                start_ms: start,
                end_ms: end,
            });
            text.clear();
        }
    };

    let flush_line = |lines: &mut Vec<LyricsLine>,
                      plain: &mut Vec<String>,
                      text: &mut String,
                      start: u64,
                      end: u64,
                      words: &mut Vec<LyricsWord>| {
        let trimmed = text.trim();
        if !trimmed.is_empty() {
            let line_end = if end > start { end } else { start + 3000 };
            plain.push(trimmed.to_string());

            // Resolve any unset or invalid word end timestamps
            for i in 0..words.len() {
                if words[i].end_ms <= words[i].start_ms {
                    if i + 1 < words.len() && words[i + 1].start_ms > words[i].start_ms {
                        words[i].end_ms = words[i + 1].start_ms;
                    } else {
                        words[i].end_ms = line_end.max(words[i].start_ms + 100);
                    }
                }
            }

            lines.push(LyricsLine {
                start_ms: start,
                end_ms: line_end,
                text: trimmed.to_string(),
                words: std::mem::take(words),
                is_line_timed: false,
                is_background: false,
            });
            text.clear();
        }
    };

    for raw_line in lyricsfile_str.lines() {
        let trimmed = raw_line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }

        if trimmed == "lines:" {
            in_lines = true;
            continue;
        }
        if !in_lines {
            continue;
        }

        let indent = raw_line.chars().take_while(|c| *c == ' ').count();

        if indent == 0 && trimmed.starts_with("- text:") {
            if in_words && !current_word_text.is_empty() {
                flush_word(&mut current_words, &mut current_word_text, current_word_start, current_word_end);
            }
            flush_line(&mut lines, &mut plain_buffer, &mut current_line_text, current_line_start, current_line_end, &mut current_words);
            in_words = false;
            let val = trimmed.trim_start_matches("- text:").trim();
            current_line_text = unquote_yaml(val);
            current_line_start = 0;
            current_line_end = 0;
            current_word_text.clear();
            current_word_start = 0;
            current_word_end = 0;
        } else if !in_words && trimmed.starts_with("start_ms:") {
            let val = trimmed.trim_start_matches("start_ms:").trim();
            current_line_start = val.parse().unwrap_or(0);
        } else if !in_words && trimmed.starts_with("end_ms:") {
            let val = trimmed.trim_start_matches("end_ms:").trim();
            current_line_end = val.parse().unwrap_or(0);
        } else if trimmed == "words:" {
            in_words = true;
        } else if in_words && indent > 0 && trimmed.starts_with("- text:") {
            if !current_word_text.is_empty() {
                flush_word(&mut current_words, &mut current_word_text, current_word_start, current_word_end);
            }
            let val = trimmed.trim_start_matches("- text:").trim();
            current_word_text = unquote_yaml(val);
            current_word_start = 0;
            current_word_end = 0;
        } else if in_words && trimmed.starts_with("start_ms:") {
            let val = trimmed.trim_start_matches("start_ms:").trim();
            let parsed_start = val.parse().unwrap_or(0);
            if !current_words.is_empty() {
                let last_idx = current_words.len() - 1;
                if current_words[last_idx].end_ms <= current_words[last_idx].start_ms {
                    current_words[last_idx].end_ms = parsed_start;
                }
            }
            current_word_start = parsed_start;
        } else if in_words && trimmed.starts_with("end_ms:") {
            let val = trimmed.trim_start_matches("end_ms:").trim();
            current_word_end = val.parse().unwrap_or(0);
        }
    }

    if in_words && !current_word_text.is_empty() {
        flush_word(&mut current_words, &mut current_word_text, current_word_start, current_word_end);
    }
    flush_line(&mut lines, &mut plain_buffer, &mut current_line_text, current_line_start, current_line_end, &mut current_words);

    if lines.is_empty() {
        return None;
    }

    Some(SyncedLyrics {
        is_synced: true,
        is_word_synced: true,
        lines,
        plain_text: if !plain_buffer.is_empty() { Some(plain_buffer.join("\n")) } else { None },
        provider: "lrclib-enhanced".to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_lrc_standard_is_line_timed_no_synthetic_words() {
        let sample = "\
[00:12.50] Hello world
[00:15.890] Line two
[01:02.00] Third line";

        let parsed = parse_lrc(sample);
        assert!(parsed.is_synced);
        assert!(!parsed.is_word_synced);
        assert_eq!(parsed.lines.len(), 3);
        assert_eq!(parsed.lines[0].start_ms, 12_500);
        assert_eq!(parsed.lines[0].text, "Hello world");
        assert!(parsed.lines[0].is_line_timed);
        assert!(parsed.lines[0].words.is_empty(), "Standard LRC must have no synthetic words");
    }

    #[test]
    fn test_parse_lrc_enhanced() {
        let sample = "\
[00:10.00] <00:10.00>First <00:10.50>word <00:11.20>test
[00:15.00] <00:15.00>Second <00:15.80>line";

        let parsed = parse_lrc(sample);
        assert!(parsed.is_synced);
        assert!(parsed.is_word_synced);
        assert_eq!(parsed.lines.len(), 2);
        assert!(!parsed.lines[0].is_line_timed);
        assert_eq!(parsed.lines[0].words.len(), 3);
        assert_eq!(parsed.lines[0].words[0].text, "First");
        assert_eq!(parsed.lines[0].words[0].start_ms, 10_000);
        assert_eq!(parsed.lines[0].words[0].end_ms, 10_500);
        assert_eq!(parsed.lines[0].words[1].text, "word");
        assert_eq!(parsed.lines[0].words[1].start_ms, 10_500);
        assert_eq!(parsed.lines[0].words[1].end_ms, 11_200);
        assert_eq!(parsed.lines[0].words[2].text, "test");
        assert_eq!(parsed.lines[0].words[2].start_ms, 11_200);
    }

    #[test]
    fn test_parse_ttml_apple_music() {
        let ttml = r#"
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <body>
    <div>
      <p begin="00:01.000" end="00:04.000">
        <span begin="00:01.000" end="00:02.000">Hello </span>
        <span begin="00:02.000" end="00:03.500">world</span>
      </p>
      <p begin="00:05.000" end="00:08.000" ttm:role="x-bg">
        <span begin="00:05.000" end="00:07.000">Background echo</span>
      </p>
    </div>
  </body>
</tt>
"#;
        let parsed = parse_ttml(ttml);
        assert!(parsed.is_synced);
        assert!(parsed.is_word_synced);
        assert_eq!(parsed.lines.len(), 2);

        let l0 = &parsed.lines[0];
        assert_eq!(l0.text, "Hello world");
        assert_eq!(l0.start_ms, 1000);
        assert_eq!(l0.end_ms, 4000);
        assert!(!l0.is_line_timed);
        assert!(!l0.is_background);
        assert_eq!(l0.words.len(), 2);
        assert_eq!(l0.words[0].text, "Hello");
        assert_eq!(l0.words[0].start_ms, 1000);
        assert_eq!(l0.words[0].end_ms, 2000);
        assert_eq!(l0.words[1].text, "world");
        assert_eq!(l0.words[1].start_ms, 2000);
        assert_eq!(l0.words[1].end_ms, 3500);

        let l1 = &parsed.lines[1];
        assert_eq!(l1.text, "Background echo");
        assert!(l1.is_background);
    }

    #[test]
    fn test_parse_youtube_json3_with_word_offsets() {
        let json = r#"{
          "events": [
            {
              "tStartMs": 5000,
              "dDurationMs": 2500,
              "segs": [
                { "utf8": "Look ", "tOffsetMs": 0 },
                { "utf8": "at ", "tOffsetMs": 400 },
                { "utf8": "the stars", "tOffsetMs": 800 }
              ]
            }
          ]
        }"#;

        let parsed = parse_youtube_json3(json);
        assert!(parsed.is_synced);
        assert!(parsed.is_word_synced);
        assert_eq!(parsed.lines.len(), 1);
        let l = &parsed.lines[0];
        assert_eq!(l.text, "Look at the stars");
        assert_eq!(l.start_ms, 5000);
        assert_eq!(l.end_ms, 7500);
        assert_eq!(l.words.len(), 3);
        assert_eq!(l.words[0].text, "Look");
        assert_eq!(l.words[0].start_ms, 5000);
        assert_eq!(l.words[1].text, "at");
        assert_eq!(l.words[1].start_ms, 5400);
        assert_eq!(l.words[2].text, "the stars");
        assert_eq!(l.words[2].start_ms, 5800);
    }

    #[test]
    fn test_parse_real_sombr_back_to_friends_lyricsfile() {
        let fixture_path = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/lrclib_back_to_friends.json");
        let fixture_data = std::fs::read_to_string(fixture_path).expect("Failed to read lrclib fixture");
        let parsed_json: serde_json::Value = serde_json::from_str(&fixture_data).expect("Failed to parse fixture JSON");
        let lyricsfile_str = parsed_json["lyricsfile"].as_str().expect("Fixture missing lyricsfile");

        let lyrics = parse_lrclib_lyricsfile(lyricsfile_str).expect("Failed to parse lyricsfile");
        assert!(lyrics.is_synced);
        assert!(lyrics.is_word_synced);

        // Crucial bug check: Must be real number of lines (30), NOT 222!
        assert_eq!(lyrics.lines.len(), 30, "Expected 30 lines for 'back to friends', found {}", lyrics.lines.len());

        let line0 = &lyrics.lines[0];
        assert_eq!(line0.text, "Touch my body tender");
        assert_eq!(line0.start_ms, 22950);
        assert_eq!(line0.end_ms, 26678);
        assert_eq!(line0.words.len(), 4, "Expected 4 nested words in line 0");
        assert_eq!(line0.words[0].text, "Touch");
        assert_eq!(line0.words[0].start_ms, 22950);
        assert_eq!(line0.words[0].end_ms, 23205);
        assert_eq!(line0.words[1].text, "my");
        assert_eq!(line0.words[1].start_ms, 23205);
        assert_eq!(line0.words[1].end_ms, 23526);
        assert_eq!(line0.words[2].text, "body");
        assert_eq!(line0.words[2].start_ms, 23526);
        assert_eq!(line0.words[2].end_ms, 24141);
        assert_eq!(line0.words[3].text, "tender");
        assert_eq!(line0.words[3].start_ms, 24141);
        assert_eq!(line0.words[3].end_ms, 26678);

        let total_words: usize = lyrics.lines.iter().map(|l| l.words.len()).sum();
        assert_eq!(total_words, 192, "Expected 192 total nested words");

        for (i, l) in lyrics.lines.iter().enumerate() {
            assert!(!l.words.is_empty(), "Line {} ('{}') must have nested words", i, l.text);
            assert!(!l.is_line_timed);
        }
    }
}
