use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;
use std::time::Instant;
use lofty::prelude::*;
use lofty::probe::Probe;
use rayon::prelude::*;
use walkdir::WalkDir;

use crate::db::repository::DatabaseRepository;
use crate::models::{ScanProgressCallback, ScanResult, SoftifyError, Track};

pub const MIN_FILE_SIZE_BYTES: u64 = 300 * 1024; // 300 KB

pub const SUPPORTED_EXTENSIONS: &[&str] = &[
    "mp3", "m4a", "flac", "wav", "ogg", "aac",
];

pub const EXCLUDED_FOLDERS: &[&str] = &[
    "node_modules", "build", "dist", "out", "target", "vendor",
    "bin", "obj", "src", "assets", "public", "temp", "tmp", "cache",
    "Android", ".Trash", "WhatsApp", "WhatsApp Audio", "Voice Notes",
    "Ringtones", "Notifications", "Alarms", "Call Recordings",
    ".venv", ".git", ".idea", ".vscode",
];

pub struct LocalAudioScanner {
    db: Arc<DatabaseRepository>,
}

impl LocalAudioScanner {
    pub fn new(db: Arc<DatabaseRepository>) -> Self {
        Self { db }
    }

    pub fn is_excluded_dir_name(name: &str) -> bool {
        if name.starts_with('.') && name != "." && name != ".." {
            return true;
        }
        EXCLUDED_FOLDERS.contains(&name)
    }

    pub fn is_supported_audio_file(path: &Path) -> bool {
        if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
            let lower = ext.to_lowercase();
            SUPPORTED_EXTENSIONS.contains(&lower.as_str())
        } else {
            false
        }
    }

    pub fn discover_audio_files(root: &Path, max_depth: usize) -> Vec<PathBuf> {
        if !root.exists() || !root.is_dir() {
            return Vec::new();
        }

        let mut discovered = Vec::new();
        let walker = WalkDir::new(root)
            .max_depth(max_depth)
            .follow_links(false)
            .into_iter();

        for entry in walker.filter_entry(|e| {
            let file_name = e.file_name().to_string_lossy();
            if e.file_type().is_dir() {
                if Self::is_excluded_dir_name(&file_name) {
                    return false;
                }
                // Check if directory has .nomedia file
                if e.path().join(".nomedia").exists() {
                    return false;
                }
            }
            true
        }) {
            let entry = match entry {
                Ok(e) => e,
                Err(_) => continue,
            };

            let path = entry.path();
            if path.is_file() && Self::is_supported_audio_file(path) {
                if let Ok(meta) = entry.metadata() {
                    if meta.len() >= MIN_FILE_SIZE_BYTES {
                        discovered.push(path.to_path_buf());
                    }
                }
            }
        }

        discovered
    }

    pub fn parse_audio_metadata(path: &Path) -> Option<Track> {
        let path_str = path.to_string_lossy().to_string();
        let file_stem = path.file_stem()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|| "Unknown Title".to_string());

        let mut title = file_stem;
        let mut artist = "Unknown Artist".to_string();
        let mut album: Option<String> = None;
        let mut duration_ms = 0u64;

        if let Ok(tagged_file) = Probe::open(path).and_then(|p| p.read()) {
            let properties = tagged_file.properties();
            duration_ms = properties.duration().as_millis() as u64;

            if let Some(tag) = tagged_file.primary_tag().or_else(|| tagged_file.first_tag()) {
                if let Some(t) = tag.title() {
                    let trimmed = t.trim();
                    if !trimmed.is_empty() {
                        title = trimmed.to_string();
                    }
                }
                if let Some(a) = tag.artist() {
                    let trimmed = a.trim();
                    if !trimmed.is_empty() {
                        artist = trimmed.to_string();
                    }
                }
                if let Some(al) = tag.album() {
                    let trimmed = al.trim();
                    if !trimmed.is_empty() {
                        album = Some(trimmed.to_string());
                    }
                }
            }
        }

        // Generate deterministic 64-bit ID from path
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        use std::hash::{Hash, Hasher};
        path_str.hash(&mut hasher);
        let hash_val = hasher.finish();
        let track_id = format!("local_{:016x}", hash_val);

        Some(Track {
            id: track_id,
            source_id: format!("local:{}", path_str),
            title,
            artist,
            album,
            duration_ms,
            cover_url: None,
            match_confidence: Some(1.0),
            is_liked: false,
            is_unavailable: false,
        })
    }

    pub fn scan_directories(
        &self,
        directories: Vec<String>,
        callback: Option<Box<dyn ScanProgressCallback>>,
    ) -> Result<ScanResult, SoftifyError> {
        let start = Instant::now();
        let mut all_paths = Vec::new();

        for dir_str in directories {
            let path = Path::new(&dir_str);
            if !path.exists() {
                continue;
            }

            let is_downloads = path.file_name()
                .map(|n| {
                    let lower = n.to_string_lossy().to_lowercase();
                    lower == "download" || lower == "downloads"
                })
                .unwrap_or(false);

            let max_depth = if is_downloads { 2 } else { 4 };
            let discovered = Self::discover_audio_files(path, max_depth);
            all_paths.extend(discovered);
        }

        let total_files = all_paths.len() as u32;
        let scanned_counter = AtomicU32::new(0);
        let added_counter = AtomicU32::new(0);

        // Parse tags in parallel with Rayon
        let parsed_tracks: Vec<(PathBuf, Track)> = all_paths
            .par_iter()
            .filter_map(|path| {
                let track = Self::parse_audio_metadata(path)?;
                Some((path.clone(), track))
            })
            .collect();

        // Sequential DB insertion into SQLite (ensuring single lock)
        for (path, track) in parsed_tracks {
            let current = scanned_counter.fetch_add(1, Ordering::SeqCst) + 1;
            if self.db.insert_or_update_track(&track).is_ok() {
                added_counter.fetch_add(1, Ordering::SeqCst);
            }

            if let Some(cb) = &callback {
                cb.on_progress(path.to_string_lossy().to_string(), current, total_files);
            }
        }

        let elapsed = start.elapsed().as_millis() as u64;
        let scanned_files = scanned_counter.load(Ordering::SeqCst);
        let added_tracks = added_counter.load(Ordering::SeqCst);

        Ok(ScanResult {
            scanned_files,
            added_tracks,
            updated_tracks: 0,
            elapsed_ms: elapsed,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;
    use std::fs::File;
    use std::io::Write;

    #[test]
    fn test_excluded_folders_and_nomedia() {
        let dir = tempdir().unwrap();
        let music_dir = dir.path().join("Music");
        std::fs::create_dir_all(&music_dir).unwrap();

        // Regular audio file (size > 300KB)
        let song_file = music_dir.join("song1.mp3");
        let mut f = File::create(&song_file).unwrap();
        f.write_all(&vec![0u8; 350 * 1024]).unwrap();

        // Small audio file (< 300KB, e.g. click/beep)
        let beep_file = music_dir.join("beep.wav");
        let mut f_beep = File::create(&beep_file).unwrap();
        f_beep.write_all(&vec![0u8; 50 * 1024]).unwrap();

        // Excluded folder
        let git_dir = music_dir.join(".git");
        std::fs::create_dir_all(&git_dir).unwrap();
        let git_song = git_dir.join("song_git.mp3");
        let mut f_git = File::create(&git_song).unwrap();
        f_git.write_all(&vec![0u8; 350 * 1024]).unwrap();

        // Nomedia folder
        let nomedia_dir = music_dir.join("hidden_album");
        std::fs::create_dir_all(&nomedia_dir).unwrap();
        File::create(nomedia_dir.join(".nomedia")).unwrap();
        let nomedia_song = nomedia_dir.join("secret.mp3");
        let mut f_no = File::create(&nomedia_song).unwrap();
        f_no.write_all(&vec![0u8; 350 * 1024]).unwrap();

        let discovered = LocalAudioScanner::discover_audio_files(&music_dir, 4);
        assert_eq!(discovered.len(), 1);
        assert_eq!(discovered[0], song_file);
    }
}
