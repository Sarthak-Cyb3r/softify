use crate::models::{LyricsLine, LyricsWord, SyncedLyrics};
use regex::Regex;

/// Parses LRC strings (standard or enhanced) into SyncedLyrics with word timestamps.
/// If true word timestamps are absent, estimates word timings proportionally by character length.
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
            provider: "lrclib".to_string(),
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

        // Parse words: either from enhanced tags or via character length estimation
        let words = if has_any_word_tags && word_tag_re.is_match(raw_content) {
            parse_enhanced_words(raw_content, start_ms, end_ms)
        } else {
            estimate_words_for_line(clean_text, start_ms, end_ms)
        };

        lines.push(LyricsLine {
            start_ms,
            end_ms,
            text: clean_text.clone(),
            words,
        });
    }

    let is_synced = !lines.is_empty();
    let is_word_synced = has_any_word_tags;

    SyncedLyrics {
        is_synced,
        is_word_synced,
        lines,
        plain_text: if !plain_buffer.is_empty() { Some(plain_buffer.join("\n")) } else { None },
        provider: if is_word_synced { "lrclib-enhanced".to_string() } else { "lrclib".to_string() },
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

    if words.is_empty() {
        let clean = tag_re.replace_all(raw_content, "").trim().to_string();
        estimate_words_for_line(&clean, line_start_ms, line_end_ms)
    } else {
        words
    }
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

/// Splits a line's duration across words by character count.
/// Formula: for word k with C_k characters out of total characters C,
/// duration d_k = (line_duration * C_k) / C.
pub fn estimate_words_for_line(text: &str, line_start_ms: u64, line_end_ms: u64) -> Vec<LyricsWord> {
    let tokens: Vec<&str> = text.split_whitespace().collect();
    if tokens.is_empty() {
        return Vec::new();
    }

    let line_duration = if line_end_ms > line_start_ms {
        line_end_ms - line_start_ms
    } else {
        3_000
    };

    let char_counts: Vec<usize> = tokens.iter().map(|w| w.chars().count().max(1)).collect();
    let total_chars: usize = char_counts.iter().sum();
    let total_chars = total_chars.max(1);

    let mut words = Vec::new();
    let mut current_start = line_start_ms;

    for (i, token) in tokens.iter().enumerate() {
        let is_last = i == tokens.len() - 1;
        let word_dur = if is_last {
            line_end_ms.saturating_sub(current_start).max(100)
        } else {
            let prop_dur = (line_duration as usize * char_counts[i]) / total_chars;
            (prop_dur as u64).max(100)
        };

        let end_ms = if is_last {
            line_end_ms.max(current_start + 100)
        } else {
            (current_start + word_dur).min(line_end_ms)
        };

        words.push(LyricsWord {
            text: token.to_string(),
            start_ms: current_start,
            end_ms,
        });

        current_start = end_ms;
    }

    words
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

    let flush_word = |words: &mut Vec<LyricsWord>, text: &mut String, start: u64, next_start: u64| {
        let trimmed = text.trim();
        if !trimmed.is_empty() {
            let end = if next_start > start { next_start } else { start + 300 };
            words.push(LyricsWord {
                text: trimmed.to_string(),
                start_ms: start,
                end_ms: end,
            });
            text.clear();
        }
    };

    let flush_line = |lines: &mut Vec<LyricsLine>, plain: &mut Vec<String>, text: &mut String, start: u64, end: u64, words: &mut Vec<LyricsWord>| {
        let trimmed = text.trim();
        if !trimmed.is_empty() {
            let line_end = if end > start { end } else { start + 3000 };
            plain.push(trimmed.to_string());
            if let Some(last) = words.last_mut() {
                if last.end_ms <= last.start_ms || last.end_ms < line_end {
                    last.end_ms = line_end;
                }
            }
            lines.push(LyricsLine {
                start_ms: start,
                end_ms: line_end,
                text: trimmed.to_string(),
                words: std::mem::take(words),
            });
            text.clear();
        }
    };

    for raw_line in lyricsfile_str.lines() {
        let trimmed = raw_line.trim();
        if trimmed == "lines:" {
            in_lines = true;
            continue;
        }
        if !in_lines {
            continue;
        }

        if trimmed.starts_with("- text:") {
            if in_words && !current_word_text.is_empty() {
                flush_word(&mut current_words, &mut current_word_text, current_word_start, current_line_end);
            }
            flush_line(&mut lines, &mut plain_buffer, &mut current_line_text, current_line_start, current_line_end, &mut current_words);
            in_words = false;
            let val = trimmed.trim_start_matches("- text:").trim().trim_matches('\'').trim_matches('"');
            current_line_text = val.to_string();
        } else if trimmed.starts_with("start_ms:") && !in_words {
            let val = trimmed.trim_start_matches("start_ms:").trim();
            current_line_start = val.parse().unwrap_or(0);
        } else if trimmed.starts_with("end_ms:") && !in_words {
            let val = trimmed.trim_start_matches("end_ms:").trim();
            current_line_end = val.parse().unwrap_or(0);
        } else if trimmed == "words:" {
            in_words = true;
        } else if in_words && trimmed.starts_with("- text:") {
            if !current_word_text.is_empty() {
                flush_word(&mut current_words, &mut current_word_text, current_word_start, 0);
            }
            let val = trimmed.trim_start_matches("- text:").trim().trim_matches('\'').trim_matches('"');
            current_word_text = val.to_string();
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
        }
    }

    if in_words && !current_word_text.is_empty() {
        flush_word(&mut current_words, &mut current_word_text, current_word_start, current_line_end);
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
    fn test_parse_lrc_standard() {
        let sample = "\
[00:12.50] Hello world
[00:15.890] Line two
[01:02.00] Third line";

        let parsed = parse_lrc(sample);
        assert!(parsed.is_synced);
        assert_eq!(parsed.lines.len(), 3);
        assert_eq!(parsed.lines[0].start_ms, 12_500);
        assert_eq!(parsed.lines[0].text, "Hello world");
        assert_eq!(parsed.lines[0].words.len(), 2);
        assert_eq!(parsed.lines[0].words[0].text, "Hello");
        assert_eq!(parsed.lines[0].words[1].text, "world");
        assert_eq!(parsed.lines[1].start_ms, 15_890);
        assert_eq!(parsed.lines[1].text, "Line two");
        assert_eq!(parsed.lines[2].start_ms, 62_000);
        assert_eq!(parsed.lines[2].text, "Third line");
    }

    #[test]
    fn test_parse_enhanced_lrc() {
        let sample = "\
[00:05.00]<00:05.00>Never <00:05.60>gonna <00:06.20>give <00:06.80>you <00:07.40>up
[00:08.00]<00:08.00>Never <00:08.50>gonna <00:09.00>let <00:09.50>you <00:10.00>down";

        let parsed = parse_lrc(sample);
        assert!(parsed.is_synced);
        assert!(parsed.is_word_synced);
        assert_eq!(parsed.lines.len(), 2);
        assert_eq!(parsed.lines[0].words.len(), 5);
        assert_eq!(parsed.lines[0].words[0].text, "Never");
        assert_eq!(parsed.lines[0].words[0].start_ms, 5_000);
        assert_eq!(parsed.lines[0].words[0].end_ms, 5_600);
        assert_eq!(parsed.lines[0].words[1].text, "gonna");
        assert_eq!(parsed.lines[0].words[1].start_ms, 5_600);
    }

    #[test]
    fn test_estimate_words_character_proportion() {
        let words = estimate_words_for_line("short supercalifragilistic", 0, 3000);
        assert_eq!(words.len(), 2);
        assert_eq!(words[0].text, "short");
        assert_eq!(words[1].text, "supercalifragilistic");
        // "short" is 5 chars, "supercalifragilistic" is 20 chars
        // Duration of "short" should be much shorter than "supercalifragilistic"
        let dur_short = words[0].end_ms - words[0].start_ms;
        let dur_long = words[1].end_ms - words[1].start_ms;
        assert!(dur_long > dur_short * 3, "Long word duration {} must be > 3x short word duration {}", dur_long, dur_short);
    }
}
