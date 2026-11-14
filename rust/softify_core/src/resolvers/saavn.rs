use std::collections::HashSet;
use base64::Engine;
use cipher::{BlockDecrypt, KeyInit, generic_array::GenericArray};
use des::Des;
use regex::Regex;
use serde_json::Value;

use crate::models::{HeaderPair, QualityPreset, SoftifyError, StreamInfo, Track};

const SAAVN_DES_KEY: &[u8] = b"38346591";
const USER_AGENT: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

#[derive(Debug, Clone)]
pub struct SaavnMatchDetails {
    pub pid: String,
    pub title: String,
    pub artists: String,
    pub duration_diff_sec: i64,
    pub score: f64,
}

#[derive(Debug, Clone)]
pub struct SaavnRejectionDetails {
    pub candidate_title: String,
    pub candidate_artists: String,
    pub score: f64,
    pub reason: String,
}

#[derive(Debug, Clone)]
pub enum SaavnMatchResult {
    Matched(SaavnMatchDetails),
    Rejected(Option<SaavnRejectionDetails>),
}

pub struct SaavnStreamResolver {
    client: reqwest::Client,
    base_url: String,
}

impl SaavnStreamResolver {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(10))
            .build()
            .unwrap_or_default();
        Self {
            client,
            base_url: "https://www.jiosaavn.com".to_string(),
        }
    }

    #[cfg(test)]
    pub fn with_client_and_base_url(client: reqwest::Client, base_url: String) -> Self {
        Self { client, base_url }
    }

    pub fn client(&self) -> &reqwest::Client {
        &self.client
    }

    /// Decrypt Saavn encrypted media url using DES-ECB with key '38346591'
    pub fn decrypt_media_url(encrypted: &str) -> Result<String, SoftifyError> {
        let cipher = Des::new_from_slice(SAAVN_DES_KEY)
            .map_err(|e| SoftifyError::Decryption { reason: e.to_string() })?;
        let mut bytes = base64::engine::general_purpose::STANDARD
            .decode(encrypted)
            .map_err(|e| SoftifyError::Decryption { reason: format!("Base64 decode failed: {e}") })?;

        if bytes.len() % 8 != 0 {
            return Err(SoftifyError::Decryption {
                reason: format!("Invalid ciphertext length: {}", bytes.len()),
            });
        }

        for chunk in bytes.as_chunks_mut::<8>().0 {
            let block = GenericArray::from_mut_slice(chunk);
            cipher.decrypt_block(block);
        }

        let raw = String::from_utf8_lossy(&bytes).to_string();
        let cleaned = if let Some(idx) = raw.find(".mp4") {
            raw[..idx + 4].to_string()
        } else {
            raw.chars().filter(|c| c.is_ascii_graphic() || *c == ' ').collect::<String>().trim().to_string()
        };

        let https_url = if cleaned.starts_with("http://") && !cleaned.contains("127.0.0.1") && !cleaned.contains("localhost") {
            cleaned.replacen("http://", "https://", 1)
        } else {
            cleaned
        };

        Ok(https_url)
    }

    /// Rewrite URL for desired bitrate (_96.mp4, _160.mp4, _320.mp4)
    pub fn rewrite_bitrate_url(base_url: &str, bitrate_kbps: u32) -> String {
        let re = Regex::new(r"_(48|96|160|320)\.mp4").unwrap();
        let target = format!("_{bitrate_kbps}.mp4");
        re.replace(base_url, target.as_str()).to_string()
    }

    /// Probes a stream URL with a 1-byte range request or HEAD, returning (total_bytes, http_status)
    pub async fn probe_url(&self, url: &str) -> Result<(u64, u16), SoftifyError> {
        let res = self.client.get(url)
            .header("User-Agent", USER_AGENT)
            .header("Range", "bytes=0-0")
            .send()
            .await
            .map_err(|e| SoftifyError::Network { reason: e.to_string() })?;

        let status = res.status().as_u16();
        if status != 200 && status != 206 {
            return Ok((0, status));
        }

        let mut total_bytes: u64 = 0;
        if let Some(cr) = res.headers().get("content-range").and_then(|h| h.to_str().ok()) {
            // format: bytes 0-0/1234567
            if let Some(slash_idx) = cr.rfind('/') {
                if let Ok(len) = cr[slash_idx + 1..].trim().parse::<u64>() {
                    total_bytes = len;
                }
            }
        }
        if total_bytes == 0 {
            if let Some(cl) = res.headers().get("content-length").and_then(|h| h.to_str().ok()) {
                if let Ok(len) = cl.trim().parse::<u64>() {
                    total_bytes = len;
                }
            }
        }

        Ok((total_bytes, status))
    }

    /// Checks if Content-Length / duration aligns with expected bitrate within reasonable tolerance.
    /// 320 kbps = ~40 KB/s (tolerance: 28 KB/s - 55 KB/s)
    /// 160 kbps = ~20 KB/s (tolerance: 14 KB/s - 28 KB/s)
    /// 96 kbps  = ~12 KB/s (tolerance: 8 KB/s - 17 KB/s)
    pub fn is_bitrate_sane(total_bytes: u64, duration_sec: u64, bitrate_kbps: u32) -> bool {
        if duration_sec == 0 || total_bytes == 0 {
            return true; // No duration to verify against, accept if probe responded with 200/206
        }
        let byte_rate = total_bytes as f64 / duration_sec as f64;
        match bitrate_kbps {
            320 => (28_000.0..=55_000.0).contains(&byte_rate),
            160 => (14_000.0..=28_000.0).contains(&byte_rate),
            96 => (8_000.0..=17_000.0).contains(&byte_rate),
            _ => true,
        }
    }

    /// Resolves track to Saavn stream with HTTP probe quality verification and fallback step-down
    pub async fn resolve(
        &self,
        track: &Track,
        preset: QualityPreset,
    ) -> Result<StreamInfo, SoftifyError> {
        let song_pid = if track.source_id.starts_with("saavn_") {
            track.source_id.trim_start_matches("saavn_").trim().to_string()
        } else {
            self.find_best_matching_pid(track).await?
                .ok_or_else(|| SoftifyError::NotFound {
                    reason: format!("No matching Saavn track found for '{}' by '{}'", track.title, track.artist),
                })?
        };

        let details_url = format!(
            "{}/api.php?__call=song.getDetails&pids={}&_format=json&_marker=0&api_version=4&ctx=web6dot0",
            self.base_url, song_pid
        );

        let res = self.client.get(&details_url)
            .header("User-Agent", USER_AGENT)
            .send()
            .await
            .map_err(|e| SoftifyError::Network { reason: e.to_string() })?;

        if !res.status().is_success() {
            return Err(SoftifyError::Network {
                reason: format!("Saavn details returned HTTP {}", res.status()),
            });
        }

        let json: Value = res.json().await
            .map_err(|e| SoftifyError::Network { reason: format!("Failed to parse Saavn details JSON: {e}") })?;

        let song_data = if let Some(arr) = json.get("songs").and_then(|v| v.as_array()) {
            arr.first().cloned()
        } else {
            json.get(&song_pid).cloned()
        }.ok_or_else(|| SoftifyError::NotFound {
            reason: format!("Song data not found in response for pid {song_pid}"),
        })?;

        let more_info = song_data.get("more_info").unwrap_or(&song_data);
        let encrypted_url = more_info.get("encrypted_media_url")
            .or_else(|| song_data.get("encrypted_media_url"))
            .and_then(|v| v.as_str())
            .ok_or_else(|| SoftifyError::NotFound {
                reason: format!("No encrypted_media_url for pid {song_pid}"),
            })?;

        let base_mp4_url = Self::decrypt_media_url(encrypted_url)?;
        let duration_sec = track.duration_ms / 1000;

        // Step-down ladder according to requested preset
        let (ladder, requested_bitrate) = match preset {
            QualityPreset::High => (vec![320, 160, 96], 320),
            QualityPreset::Medium => (vec![160, 96], 160),
            QualityPreset::Low => (vec![96], 96),
        };

        for candidate_bitrate in ladder {
            let candidate_url = Self::rewrite_bitrate_url(&base_mp4_url, candidate_bitrate);
            if let Ok((total_bytes, status)) = self.probe_url(&candidate_url).await {
                if (status == 200 || status == 206) && Self::is_bitrate_sane(total_bytes, duration_sec, candidate_bitrate) {
                    let is_requested = candidate_bitrate == requested_bitrate;
                    let expires_at = std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .map(|d| d.as_secs() + 6 * 3600)
                        .ok();

                    return Ok(StreamInfo {
                        url: candidate_url,
                        container: "m4a".to_string(),
                        bitrate_kbps: candidate_bitrate,
                        codec: "aac".to_string(),
                        provider: format!("jiosaavn_studio ({}kbps)", candidate_bitrate),
                        is_requested_quality: is_requested,
                        headers: vec![HeaderPair {
                            name: "User-Agent".to_string(),
                            value: USER_AGENT.to_string(),
                        }],
                        expires_at,
                    });
                }
            }
        }

        Err(SoftifyError::QualityVerification {
            reason: format!("All Saavn quality streams failed verification for pid {song_pid}"),
        })
    }

    /// Finds best matching pid from JioSaavn searching, applying exact Flutter anti-mashup,
    /// exact Duration Guard, and artist verification.
    pub async fn find_best_matching_pid(&self, track: &Track) -> Result<Option<String>, SoftifyError> {
        let res = self.match_track_detailed(track).await?;
        match res {
            SaavnMatchResult::Matched(m) => Ok(Some(m.pid)),
            SaavnMatchResult::Rejected(_) => Ok(None),
        }
    }

    /// Evaluates all candidate tracks from JioSaavn and returns detailed match or rejection information.
    pub async fn match_track_detailed(&self, track: &Track) -> Result<SaavnMatchResult, SoftifyError> {
        let clean_title = normalize(&track.title);
        let clean_artist = normalize(&track.artist);
        let primary_artist = track.artist.split([',', '&', '/'])
            .next()
            .unwrap_or("")
            .trim()
            .to_string();

        let mut queries = Vec::new();
        if !primary_artist.is_empty() {
            queries.push(format!("{} {}", track.title, primary_artist));
        }
        if let Some(album) = &track.album {
            let clean_album = normalize(album);
            if !clean_album.is_empty() && clean_album != clean_title {
                if !primary_artist.is_empty() {
                    queries.push(format!("{} {} {}", track.title, primary_artist, album));
                }
                queries.push(format!("{} {}", track.title, album));
            }
        }
        queries.push(track.title.clone());

        let mut seen_pids = HashSet::new();
        let mut candidates = Vec::new();

        for q in queries {
            let encoded_q = urlencoding_encode(&q);
            let search_url = format!(
                "{}/api.php?__call=search.getResults&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=10&p=1&q={}",
                self.base_url, encoded_q
            );

            if let Ok(res) = self.client.get(&search_url).header("User-Agent", USER_AGENT).send().await {
                if res.status().is_success() {
                    if let Ok(json) = res.json::<Value>().await {
                        if let Some(results) = json.get("results").and_then(|v| v.as_array()) {
                            for item in results {
                                if let Some(pid) = item.get("id").and_then(|v| v.as_str()) {
                                    if seen_pids.insert(pid.to_string()) {
                                        candidates.push(item.clone());
                                    }
                                }
                            }
                            if candidates.len() >= 15 {
                                break;
                            }
                        }
                    }
                }
            }
        }

        if candidates.is_empty() {
            return Ok(SaavnMatchResult::Rejected(None));
        }

        let mut best_score = -1.0;
        let mut best_match = None;
        let mut best_rejection: Option<SaavnRejectionDetails> = None;

        for r in candidates {
            let pid = match r.get("id").and_then(|v| v.as_str()) {
                Some(p) => p.to_string(),
                None => continue,
            };

            let more_info = r.get("more_info").cloned().unwrap_or(Value::Null);
            let raw_cand_title = r.get("title").or_else(|| r.get("song")).and_then(|v| v.as_str()).unwrap_or("").to_lowercase();
            let cand_subtitle = r.get("subtitle").and_then(|v| v.as_str()).unwrap_or("").to_lowercase();
            let raw_cand_album = more_info.get("album").or_else(|| r.get("subtitle")).and_then(|v| v.as_str()).unwrap_or("").to_lowercase();
            let cand_title = normalize(&raw_cand_title);
            let cand_language = r.get("language").and_then(|v| v.as_str()).unwrap_or("").to_lowercase();

            // Extract candidate artists across primary_artists, featured_artists, artists, singers, music, subtitle
            let mut cand_singers_vec = Vec::new();
            if let Some(artist_map) = more_info.get("artistMap") {
                if let Some(pa) = artist_map.get("primary_artists").and_then(|v| v.as_array()) {
                    for a in pa {
                        if let Some(name) = a.get("name").and_then(|v| v.as_str()) {
                            cand_singers_vec.push(name);
                        }
                    }
                }
                if let Some(fa) = artist_map.get("featured_artists").and_then(|v| v.as_array()) {
                    for a in fa {
                        if let Some(name) = a.get("name").and_then(|v| v.as_str()) {
                            cand_singers_vec.push(name);
                        }
                    }
                }
                if let Some(all_a) = artist_map.get("artists").and_then(|v| v.as_array()) {
                    for a in all_a {
                        if a.get("role").and_then(|v| v.as_str()) != Some("starring") {
                            if let Some(name) = a.get("name").and_then(|v| v.as_str()) {
                                cand_singers_vec.push(name);
                            }
                        }
                    }
                }
            }
            if let Some(singers) = r.get("singers").and_then(|v| v.as_str()) {
                cand_singers_vec.push(singers);
            }
            if let Some(pa) = r.get("primary_artists").and_then(|v| v.as_str()) {
                cand_singers_vec.push(pa);
            }
            let subtitle_artist = if cand_subtitle.contains(" - ") {
                cand_subtitle.split(" - ").next().unwrap_or("").trim()
            } else {
                ""
            };
            if !subtitle_artist.is_empty() {
                cand_singers_vec.push(subtitle_artist);
            }
            if let Some(music) = more_info.get("music").and_then(|v| v.as_str()) {
                cand_singers_vec.push(music);
            }
            let cand_singers = normalize(&cand_singers_vec.join(" "));
            let display_artists = if cand_singers_vec.is_empty() { "Unknown".to_string() } else { cand_singers_vec.join(", ") };

            // 0. Hard Disqualification: Unwanted Remixes, DJ cuts, Covers, Lofi, Slowed, Acoustic, Karaoke
            let target_title_lower = track.title.to_lowercase();
            let target_album_lower = track.album.as_deref().unwrap_or("").to_lowercase();

            const UNWANTED_KEYWORDS: &[&str] = &[
                "remix", "re-mix", "mix", "mashup", "mash-up", "dj ", "dj-", "club",
                "lofi", "lo-fi", "slowed", "reverb", "sped up", "speed up", "speedup",
                "acoustic", "unplugged", "cover", "instrumental", "karaoke",
                "tribute", "rework", "flip", "recreated", "recreation", "rendition",
                "8d audio", "bass boosted", "reprise",
            ];

            let mut is_disqualified = false;
            let mut disqualified_kw = "";
            for &kw in UNWANTED_KEYWORDS {
                if !target_title_lower.contains(kw) && !target_album_lower.contains(kw) {
                    if kw == "mix" && (raw_cand_title.contains("original mix") || cand_subtitle.contains("original mix")) {
                        continue;
                    }
                    if raw_cand_title.contains(kw) || cand_subtitle.contains(kw) || raw_cand_album.contains(kw) {
                        is_disqualified = true;
                        disqualified_kw = kw;
                        break;
                    }
                }
            }
            if is_disqualified {
                if best_rejection.is_none() {
                    best_rejection = Some(SaavnRejectionDetails {
                        candidate_title: raw_cand_title,
                        candidate_artists: display_artists,
                        score: 0.0,
                        reason: format!("anti-mashup rule: keyword '{disqualified_kw}' detected"),
                    });
                }
                continue;
            }

            // 1. Hard Disqualification: Unrelated artist cover / mismatch
            const ARTIST_STOP_WORDS: &[&str] = &[
                "the", "and", "feat", "ft", "featuring", "with", "presents", "prod", "by",
                "music", "band", "records", "official", "original", "soundtrack", "all",
                "star", "stars", "dj", "vj", "mr", "ms", "mrs", "dr", "to", "in", "on", "of",
            ];

            let clean_primary = normalize(&primary_artist);
            let primary_words: Vec<&str> = clean_primary
                .split_whitespace()
                .filter(|w| w.len() >= 3 && !ARTIST_STOP_WORDS.contains(w))
                .collect();

            if !primary_words.is_empty() {
                if primary_words.len() >= 2 {
                    let has_exact_primary = cand_singers.contains(&clean_primary);
                    let has_all_tokens = primary_words.iter().all(|w| cand_singers.contains(*w));
                    if !has_exact_primary && !has_all_tokens {
                        if best_rejection.is_none() {
                            best_rejection = Some(SaavnRejectionDetails {
                                candidate_title: raw_cand_title,
                                candidate_artists: display_artists,
                                score: 0.0,
                                reason: format!("artist mismatch: primary '{clean_primary}' not found in candidate singers '{cand_singers}'"),
                            });
                        }
                        continue;
                    }
                } else {
                    let token = primary_words[0];
                    if !cand_singers.contains(token) {
                        if best_rejection.is_none() {
                            best_rejection = Some(SaavnRejectionDetails {
                                candidate_title: raw_cand_title,
                                candidate_artists: display_artists,
                                score: 0.0,
                                reason: format!("artist mismatch: single-token '{token}' not found in candidate singers '{cand_singers}'"),
                            });
                        }
                        continue;
                    }
                }
            }

            // 2. Exact Duration Guard: Ported from Flutter Dart code verbatim
            let cand_dur_sec: i64 = more_info.get("duration")
                .and_then(|v| {
                    if let Some(s) = v.as_str() {
                        s.parse::<i64>().ok()
                    } else {
                        v.as_i64()
                    }
                })
                .unwrap_or(0);

            let track_dur_sec = (track.duration_ms / 1000) as i64;
            if track.duration_ms > 45_000 {
                if cand_dur_sec <= 0 {
                    let target_album = normalize(track.album.as_deref().unwrap_or(""));
                    let cand_album = normalize(&raw_cand_album);
                    if target_album.is_empty() || cand_album.is_empty() || !cand_album.contains(&target_album) {
                        if best_rejection.is_none() {
                            best_rejection = Some(SaavnRejectionDetails {
                                candidate_title: raw_cand_title,
                                candidate_artists: display_artists,
                                score: 0.0,
                                reason: "duration guard: candidate duration unknown and album mismatch".to_string(),
                            });
                        }
                        continue;
                    }
                } else {
                    let diff_sec = (track_dur_sec - cand_dur_sec).abs();
                    let max_allowed_diff = ((track_dur_sec as f64 * 0.10).clamp(8.0, 25.0)) as i64;
                    if diff_sec > max_allowed_diff {
                        best_rejection = Some(SaavnRejectionDetails {
                            candidate_title: raw_cand_title,
                            candidate_artists: display_artists,
                            score: 0.0,
                            reason: format!("duration guard: diff {diff_sec}s > max allowed {max_allowed_diff}s (requested {track_dur_sec}s vs Saavn {cand_dur_sec}s)"),
                        });
                        continue;
                    }
                }
            }

            // 3. Scoring
            let mut score = 0.0;
            let clean_simple = phonetic_simplify(&clean_title);
            let cand_simple = phonetic_simplify(&cand_title);

            let mut title_matched = false;
            if cand_title == clean_title || (!cand_simple.is_empty() && cand_simple == clean_simple) {
                score += 70.0;
                title_matched = true;
            } else if cand_title.contains(&clean_title) && (clean_title.len() >= 4 || clean_title.len() == cand_title.len()) {
                score += 50.0;
                title_matched = true;
            } else if clean_title.contains(&cand_title) && cand_title.len() >= 4 && (cand_title.len() as f64 / clean_title.len() as f64 >= 0.65) {
                score += 45.0;
                title_matched = true;
            } else if !cand_simple.is_empty() && !clean_simple.is_empty() && (cand_simple.contains(&clean_simple) || clean_simple.contains(&cand_simple))
                && clean_simple.len() >= 4 && cand_simple.len() >= 4 {
                    score += 40.0;
                    title_matched = true;
                }

            if !title_matched {
                if best_rejection.is_none() {
                    best_rejection = Some(SaavnRejectionDetails {
                        candidate_title: raw_cand_title,
                        candidate_artists: display_artists,
                        score: 0.0,
                        reason: format!("title mismatch: candidate title '{cand_title}' does not match '{clean_title}'"),
                    });
                }
                continue;
            }

            // Language preservation
            const REGIONAL_LANGS: &[&str] = &["telugu", "tamil", "bhojpuri", "kannada", "malayalam", "marathi", "bengali"];
            let target_lower = format!("{} {}", track.title.to_lowercase(), track.artist.to_lowercase());
            if REGIONAL_LANGS.contains(&cand_language.as_str()) && !target_lower.contains(&cand_language) {
                score -= 40.0;
            }
            if (cand_language == "hindi" || cand_language == "english" || cand_language == "punjabi")
                && (target_lower.contains(&cand_language) || clean_artist.is_empty())
            {
                score += 10.0;
            }

            // Singer / artist bonus
            if !clean_artist.is_empty() && !cand_singers.is_empty() {
                if cand_singers.contains(&clean_primary) || cand_singers.contains(&clean_artist) {
                    score += 40.0;
                } else if !primary_words.is_empty() {
                    let matched = primary_words.iter().filter(|w| cand_singers.contains(**w)).count();
                    score += 40.0 * (matched as f64 / primary_words.len() as f64);
                }
            }

            // Album bonus
            let target_album = normalize(track.album.as_deref().unwrap_or(""));
            let cand_album = normalize(&raw_cand_album);
            if !target_album.is_empty() && !cand_album.is_empty()
                && (cand_album == target_album || cand_album.contains(&target_album) || target_album.contains(&cand_album)) {
                    score += 40.0;
                }

            // Duration proximity
            let diff_sec = if track.duration_ms > 0 && cand_dur_sec > 0 {
                let d = (track_dur_sec - cand_dur_sec).abs();
                if d <= 5 {
                    score += 40.0;
                } else if d <= 15 {
                    score += 25.0;
                } else if d <= 35 {
                    score += 10.0;
                } else if d > 60 {
                    score -= 25.0;
                }
                d
            } else {
                0
            };

            if score < 80.0 && best_rejection.as_ref().map(|b| b.score < score).unwrap_or(true) {
                best_rejection = Some(SaavnRejectionDetails {
                    candidate_title: raw_cand_title.clone(),
                    candidate_artists: display_artists.clone(),
                    score,
                    reason: format!("score below threshold: {score:.1} < 80.0 required"),
                });
            }

            if score > best_score {
                best_score = score;
                best_match = Some(SaavnMatchDetails {
                    pid,
                    title: raw_cand_title,
                    artists: display_artists,
                    duration_diff_sec: diff_sec,
                    score,
                });
            }
        }

        if best_score >= 80.0 {
            if let Some(m) = best_match {
                return Ok(SaavnMatchResult::Matched(m));
            }
        }
        Ok(SaavnMatchResult::Rejected(best_rejection))
    }
}

impl Default for SaavnStreamResolver {
    fn default() -> Self {
        Self::new()
    }
}

pub fn normalize(s: &str) -> String {
    let s_clean: String = s.chars()
        .map(|c| if ['\u{00A0}', '\u{2000}', '\u{2001}', '\u{2002}', '\u{2003}', '\u{2004}', '\u{2005}', '\u{2006}', '\u{2007}', '\u{2008}', '\u{2009}', '\u{200A}', '\u{200B}', '\u{202F}', '\u{205F}', '\u{3000}'].contains(&c) {
            ' '
        } else {
            c
        })
        .collect();
    let lower = s_clean.to_lowercase();
    let re_brackets = Regex::new(r"\s*[\(\[].*?[\)\]]").unwrap();
    let without_brackets = re_brackets.replace_all(&lower, " ");
    let re_non_alnum = Regex::new(r"[^a-z0-9 ]").unwrap();
    let alnum = re_non_alnum.replace_all(&without_brackets, " ");
    let re_spaces = Regex::new(r"\s+").unwrap();
    re_spaces.replace_all(&alnum, " ").trim().to_string()
}

pub fn phonetic_simplify(s: &str) -> String {
    let lower = normalize(s);
    let mut result = String::with_capacity(lower.len());
    let mut last_vowel = None;
    for c in lower.chars() {
        if matches!(c, 'a' | 'e' | 'i' | 'o' | 'u') {
            if Some(c) == last_vowel {
                continue;
            }
            last_vowel = Some(c);
        } else {
            last_vowel = None;
        }
        result.push(c);
    }
    result
}

fn urlencoding_encode(s: &str) -> String {
    url::form_urlencoded::byte_serialize(s.as_bytes()).collect()
}
