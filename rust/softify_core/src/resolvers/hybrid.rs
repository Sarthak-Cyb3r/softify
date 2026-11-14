use crate::models::{QualityPreset, SoftifyError, StreamInfo, Track};
use super::saavn::SaavnStreamResolver;
use super::youtube::YoutubeStreamResolver;

pub struct HybridStreamResolver {
    saavn: SaavnStreamResolver,
    youtube: YoutubeStreamResolver,
}

impl HybridStreamResolver {
    pub fn new() -> Self {
        Self {
            saavn: SaavnStreamResolver::new(),
            youtube: YoutubeStreamResolver::new(),
        }
    }

    pub fn saavn(&self) -> &SaavnStreamResolver {
        &self.saavn
    }

    pub fn youtube(&self) -> &YoutubeStreamResolver {
        &self.youtube
    }

    pub async fn resolve(
        &self,
        track: &Track,
        preset: QualityPreset,
    ) -> Result<StreamInfo, SoftifyError> {
        // 1. Try JioSaavn Studio Master (320kbps -> 160kbps -> 96kbps)
        match self.saavn.resolve(track, preset).await {
            Ok(info) => {
                println!(
                    "[RESOLVER] JioSaavn resolved: '{}' -> {} kbps, codec={}, requested_quality_met={}",
                    track.title, info.bitrate_kbps, info.codec, info.is_requested_quality
                );
                return Ok(info);
            }
            Err(e) => {
                println!(
                    "[RESOLVER] JioSaavn unavailable for '{}' ({}): Falling back to YouTube Innertube",
                    track.title, e
                );
            }
        }

        // 2. Fallback to YouTube
        match self.youtube.resolve(track, preset).await {
            Ok(info) => {
                println!(
                    "[RESOLVER] YouTube fallback resolved: '{}' -> {} kbps, codec={}, provider={}",
                    track.title, info.bitrate_kbps, info.codec, info.provider
                );
                Ok(info)
            }
            Err(e) => {
                eprintln!("[RESOLVER] Both JioSaavn and YouTube failed for '{}': {}", track.title, e);
                Err(e)
            }
        }
    }
}

impl Default for HybridStreamResolver {
    fn default() -> Self {
        Self::new()
    }
}
