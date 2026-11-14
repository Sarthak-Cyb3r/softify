use crate::models::{LyricsLine, SyncedLyrics};
use regex::Regex;

/// Parses standard LRC strings into SyncedLyrics with millisecond timestamps
pub fn parse_lrc(lrc_text: &str) -> SyncedLyrics {
    let re = Regex::new(r"\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\](.*)").unwrap();
    let mut lines = Vec::new();
    let mut plain_buffer = Vec::new();

    for line in lrc_text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        if let Some(caps) = re.captures(trimmed) {
            let minutes: u64 = caps[1].parse().unwrap_or(0);
            let seconds: u64 = caps[2].parse().unwrap_or(0);
            let frac_str = caps.get(3).map(|m| m.as_str()).unwrap_or("0");
            let ms: u64 = if frac_str.len() == 2 {
                frac_str.parse::<u64>().unwrap_or(0) * 10
            } else {
                frac_str.parse::<u64>().unwrap_or(0)
            };

            let start_ms = minutes * 60_000 + seconds * 1_000 + ms;
            let text = caps[4].trim().to_string();

            plain_buffer.push(text.clone());
            lines.push(LyricsLine { start_ms, text });
        } else if !trimmed.starts_with('[') {
            plain_buffer.push(trimmed.to_string());
        }
    }

    let is_synced = !lines.is_empty();
    let plain_text = if !plain_buffer.is_empty() {
        Some(plain_buffer.join("\n"))
    } else {
        None
    };

    SyncedLyrics {
        is_synced,
        lines,
        plain_text,
    }
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
        assert_eq!(parsed.lines[1].start_ms, 15_890);
        assert_eq!(parsed.lines[1].text, "Line two");
        assert_eq!(parsed.lines[2].start_ms, 62_000);
        assert_eq!(parsed.lines[2].text, "Third line");
    }
}
