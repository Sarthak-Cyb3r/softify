use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::RwLock;
use std::time::Duration;

static DEFAULT_CONFIG_STR: &str = include_str!("../resources/default_config.json");

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub fallback_piped_instances: Vec<String>,
    pub search_aliases: HashMap<String, Vec<String>>,
    pub ranker_weights: HashMap<String, f64>,
    pub client_version: String,
    pub endpoints: HashMap<String, String>,
}

impl Default for AppConfig {
    fn default() -> Self {
        serde_json::from_str(DEFAULT_CONFIG_STR)
            .expect("Embedded default_config.json must be valid JSON")
    }
}

pub struct ConfigManager {
    config: RwLock<AppConfig>,
    client: reqwest::Client,
}

impl ConfigManager {
    pub fn new() -> Self {
        Self {
            config: RwLock::new(AppConfig::default()),
            client: reqwest::Client::builder()
                .timeout(Duration::from_secs(3))
                .build()
                .unwrap_or_else(|_| reqwest::Client::new()),
        }
    }
}

impl Default for ConfigManager {
    fn default() -> Self {
        Self::new()
    }
}

impl ConfigManager {
    pub fn get_config(&self) -> AppConfig {
        self.config.read().map(|c| c.clone()).unwrap_or_default()
    }

    pub async fn fetch_remote_config(&self, url: &str) {
        if let Ok(resp) = self.client.get(url).send().await {
            if resp.status().is_success() {
                if let Ok(new_cfg) = resp.json::<AppConfig>().await {
                    if let Ok(mut lock) = self.config.write() {
                        *lock = new_cfg;
                    }
                }
            }
        }
    }

    pub fn get_endpoint(&self, key: &str, fallback: &str) -> String {
        let cfg = self.get_config();
        cfg.endpoints
            .get(key)
            .cloned()
            .unwrap_or_else(|| fallback.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bundled_default_config_loads() {
        let mgr = ConfigManager::new();
        let cfg = mgr.get_config();
        assert!(!cfg.fallback_piped_instances.is_empty());
        assert!(cfg.search_aliases.contains_key("arijit"));
        assert_eq!(cfg.client_version, "1.02");
    }

    #[tokio::test]
    async fn test_remote_config_fails_fallback_to_bundled_default() {
        let mgr = ConfigManager::new();
        // Point to an invalid unreachable address
        mgr.fetch_remote_config("http://127.0.0.1:1/invalid_non_existent")
            .await;
        let cfg = mgr.get_config();
        // Should retain bundled default
        assert!(!cfg.fallback_piped_instances.is_empty());
        assert_eq!(cfg.client_version, "1.02");
    }
}
