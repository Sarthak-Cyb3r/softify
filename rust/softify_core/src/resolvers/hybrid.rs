use super::saavn::SaavnStreamResolver;
use super::youtube::YoutubeStreamResolver;
use crate::models::{ProviderHealth, QualityPreset, SoftifyError, StreamInfo, Track};
use std::time::Instant;

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
}

impl Default for HybridStreamResolver {
    fn default() -> Self {
        Self::new()
    }
}

impl HybridStreamResolver {
    pub fn saavn(&self) -> &SaavnStreamResolver {
        &self.saavn
    }

    pub fn youtube(&self) -> &YoutubeStreamResolver {
        &self.youtube
    }

    pub async fn check_provider_health(&self) -> Vec<ProviderHealth> {
        let mut results = Vec::new();

        // 1. Saavn health check
        let saavn_start = Instant::now();
        let saavn_ok = self
            .saavn
            .client()
            .get("https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&query=test")
            .send()
            .await
            .map(|r| r.status().is_success())
            .unwrap_or(false);
        let saavn_latency = if saavn_ok {
            Some(saavn_start.elapsed().as_millis() as u64)
        } else {
            None
        };

        results.push(ProviderHealth {
            provider: "JioSaavn".to_string(),
            is_healthy: saavn_ok,
            latency_ms: saavn_latency,
        });

        // 2. YouTube health check
        let yt_start = Instant::now();
        let yt_ok = self
            .youtube
            .client()
            .get("https://music.youtube.com")
            .send()
            .await
            .map(|r| r.status().is_success())
            .unwrap_or(false);
        let yt_latency = if yt_ok {
            Some(yt_start.elapsed().as_millis() as u64)
        } else {
            None
        };

        results.push(ProviderHealth {
            provider: "YouTube".to_string(),
            is_healthy: yt_ok,
            latency_ms: yt_latency,
        });

        results
    }

    pub async fn resolve(
        &self,
        track: &Track,
        preset: QualityPreset,
    ) -> Result<StreamInfo, SoftifyError> {
        self.resolve_with_options(track, preset, false).await
    }

    pub async fn resolve_with_options(
        &self,
        track: &Track,
        preset: QualityPreset,
        disable_saavn: bool,
    ) -> Result<StreamInfo, SoftifyError> {
        // 1. Try JioSaavn Studio Master (unless explicitly disabled)
        if !disable_saavn {
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
        } else {
            println!(
                "[RESOLVER] JioSaavn disabled by option for '{}': Using YouTube fallback directly",
                track.title
            );
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
                eprintln!(
                    "[RESOLVER] Both JioSaavn and YouTube failed for '{}': {}",
                    track.title, e
                );
                Err(SoftifyError::ProviderUnavailable {
                    provider: "Hybrid".to_string(),
                    reason: format!("All providers failed to resolve stream: {}", e),
                })
            }
        }
    }
}
