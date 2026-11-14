use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use walkdir::WalkDir;

#[derive(Serialize, Deserialize, Debug)]
pub struct ScannedAudioTrack {
    pub path: String,
    pub title: String,
    pub artist: String,
    pub album: Option<String>,
    pub file_size_bytes: u64,
    pub duration_seconds: u32,
    pub extension: String,
}

pub fn scan_local_directory(root_dir: &str) -> Vec<ScannedAudioTrack> {
    let entries: Vec<_> = WalkDir::new(root_dir)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
        .collect();

    entries
        .par_iter()
        .filter_map(|entry| {
            let path = entry.path();
            let ext = path.extension()?.to_str()?.to_lowercase();
            if !matches!(ext.as_str(), "mp3" | "flac" | "m4a" | "aac" | "ogg" | "wav") {
                return None;
            }

            let file_stem = path.file_stem()?.to_str()?.to_string();
            let metadata = fs::metadata(path).ok()?;
            let file_size_bytes = metadata.len();

            // Default heuristic parsing: "Artist - Title"
            let (artist, title) = if let Some(idx) = file_stem.find(" - ") {
                let (a, t) = file_stem.split_at(idx);
                (a.trim().to_string(), t[3..].trim().to_string())
            } else {
                ("Unknown Artist".to_string(), file_stem)
            };

            Some(ScannedAudioTrack {
                path: path.to_string_lossy().to_string(),
                title,
                artist,
                album: None,
                file_size_bytes,
                duration_seconds: 0,
                extension: ext,
            })
        })
        .collect()
}
