use super::tagger::{M4aAtomTagger, M4aMetadata};
use crate::db::repository::DatabaseRepository;
use crate::models::{DownloadItem, DownloadProgressCallback, QualityPreset, SoftifyError, Track};
use crate::resolvers::hybrid::HybridStreamResolver;
use reqwest::Client;
use std::fs::File;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Arc;

pub struct DownloadManager {
    client: Client,
    resolver: Arc<HybridStreamResolver>,
    db: Option<DatabaseRepository>,
}

impl DownloadManager {
    pub fn new(resolver: Arc<HybridStreamResolver>, db: Option<DatabaseRepository>) -> Self {
        Self {
            client: Client::builder().build().unwrap_or_else(|_| Client::new()),
            resolver,
            db,
        }
    }

    pub async fn download_track(
        &self,
        track: &Track,
        preset: QualityPreset,
        target_dir: &str,
        callback: Option<&dyn DownloadProgressCallback>,
    ) -> Result<DownloadItem, SoftifyError> {
        let dir = Path::new(target_dir);
        if !dir.exists() {
            std::fs::create_dir_all(dir).map_err(|e| SoftifyError::Download {
                reason: format!("Cannot create directory {target_dir}: {e}"),
            })?;
        }

        if let Some(cb) = callback {
            cb.on_progress(track.id.clone(), 0, 0, "resolving_stream".to_string());
        }

        // 1. Resolve highest quality stream available
        let stream = self.resolver.resolve(track, preset).await?;

        // 2. Prepare filename
        let sanitized_title: String = track
            .title
            .chars()
            .map(|c| {
                if c.is_alphanumeric() || c == ' ' {
                    c
                } else {
                    '_'
                }
            })
            .collect();
        let file_name = format!(
            "{}_{}.m4a",
            track.id,
            sanitized_title.trim().replace(' ', "_")
        );
        let file_path = dir.join(&file_name);

        if let Some(cb) = callback {
            cb.on_progress(track.id.clone(), 0, 0, "connecting".to_string());
        }

        // 3. Initiate download with custom headers if required
        let mut req = self.client.get(&stream.url);
        for h in &stream.headers {
            req = req.header(&h.name, &h.value);
        }

        let mut resp = req.send().await.map_err(|e| SoftifyError::Download {
            reason: format!("Download request failed: {e}"),
        })?;

        let total_size = resp.content_length().unwrap_or(0);

        let mut file = File::create(&file_path).map_err(|e| SoftifyError::Download {
            reason: format!("Cannot create file {:?}: {e}", file_path),
        })?;

        let mut downloaded: u64 = 0;

        while let Some(chunk) = resp.chunk().await.map_err(|e| SoftifyError::Download {
            reason: format!("Chunk read error: {e}"),
        })? {
            file.write_all(&chunk).map_err(|e| SoftifyError::Download {
                reason: format!("Chunk write error: {e}"),
            })?;
            downloaded += chunk.len() as u64;

            if let Some(cb) = callback {
                cb.on_progress(
                    track.id.clone(),
                    downloaded,
                    total_size,
                    "downloading".to_string(),
                );
            }
        }

        drop(file);

        // 4. Download cover art if available
        let cover_bytes = if let Some(ref cover_url) = track.cover_url {
            if let Ok(r) = self.client.get(cover_url).send().await {
                r.bytes().await.ok().map(|b| b.to_vec())
            } else {
                None
            }
        } else {
            None
        };

        // 5. Tag M4A with metadata and realign sample chunk offsets
        let meta = M4aMetadata {
            title: &track.title,
            artist: &track.artist,
            album: track.album.as_deref(),
            cover_art_bytes: cover_bytes.as_deref(),
        };

        let tag_res = M4aAtomTagger::write_metadata(&file_path, &meta);
        if let Err(e) = tag_res {
            eprintln!("[DownloadManager] Warning: M4A tagging notice: {e}");
        }

        let final_size = std::fs::metadata(&file_path)
            .map(|m| m.len())
            .unwrap_or(downloaded);

        let item = DownloadItem {
            track_id: track.id.clone(),
            relative_path: file_path.to_string_lossy().to_string(),
            container_format: "m4a".to_string(),
            file_size_bytes: final_size,
            bytes_downloaded: final_size,
            status: "completed".to_string(),
            bitrate_kbps: stream.bitrate_kbps,
            created_at: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs() as i64,
            last_error: None,
        };

        // 6. Record in DB
        if let Some(ref db) = self.db {
            let _ = db.record_download(
                &item.track_id,
                &item.relative_path,
                &item.container_format,
                item.file_size_bytes,
                item.bytes_downloaded,
                &item.status,
                item.bitrate_kbps,
                None,
            );
        }

        if let Some(cb) = callback {
            cb.on_progress(
                track.id.clone(),
                final_size,
                final_size,
                "completed".to_string(),
            );
        }

        Ok(item)
    }

    pub fn get_downloads(&self) -> Result<Vec<DownloadItem>, SoftifyError> {
        if let Some(ref db) = self.db {
            db.get_downloads()
        } else {
            Ok(Vec::new())
        }
    }

    pub fn delete_download(&self, track_id: &str) -> Result<(), SoftifyError> {
        if let Some(ref db) = self.db {
            if let Ok(downloads) = db.get_downloads() {
                if let Some(d) = downloads.into_iter().find(|item| item.track_id == track_id) {
                    let _ = std::fs::remove_file(PathBuf::from(&d.relative_path));
                }
            }
            db.delete_download(track_id)?;
        }
        Ok(())
    }
}
