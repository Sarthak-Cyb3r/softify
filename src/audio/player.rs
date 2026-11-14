use std::io::Cursor;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use rodio::{Decoder, DeviceSinkBuilder, MixerDeviceSink, Player};

pub struct AudioPlayer {
    _sink: MixerDeviceSink,
    player: Arc<Mutex<Option<Player>>>,
    client: reqwest::Client,
    mixer: rodio::mixer::Mixer,
}

impl AudioPlayer {
    pub fn new() -> Result<Self, String> {
        let sink = DeviceSinkBuilder::open_default_sink()
            .map_err(|e| format!("Failed to open default audio output stream: {}", e))?;
        
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());

        let mixer = sink.mixer().clone();

        Ok(Self {
            _sink: sink,
            player: Arc::new(Mutex::new(None)),
            client,
            mixer,
        })
    }

    pub async fn play_url(&self, url: &str) -> Result<(), String> {
        let resp = self.client.get(url)
            .send()
            .await
            .map_err(|e| format!("Failed to fetch stream: {}", e))?;

        let bytes = resp.bytes().await.map_err(|e| format!("Failed to read stream body: {}", e))?;

        let cursor = Cursor::new(bytes);
        let source = Decoder::try_from(cursor)
            .map_err(|e| format!("Failed to decode audio stream: {}", e))?;

        let new_player = Player::connect_new(&self.mixer);
        new_player.append(source);
        new_player.play();

        let mut player_guard = self.player.lock().unwrap();
        if let Some(old_player) = player_guard.take() {
            old_player.stop();
        }
        *player_guard = Some(new_player);

        Ok(())
    }

    pub fn toggle_pause(&self) -> bool {
        let player_guard = self.player.lock().unwrap();
        if let Some(player) = player_guard.as_ref() {
            if player.is_paused() {
                player.play();
                true
            } else {
                player.pause();
                false
            }
        } else {
            false
        }
    }

    pub fn set_volume(&self, volume: f32) {
        let player_guard = self.player.lock().unwrap();
        if let Some(player) = player_guard.as_ref() {
            player.set_volume(volume.clamp(0.0, 1.0));
        }
    }

    pub fn is_playing(&self) -> bool {
        let player_guard = self.player.lock().unwrap();
        if let Some(player) = player_guard.as_ref() {
            !player.is_paused() && !player.empty()
        } else {
            false
        }
    }

    pub fn stop(&self) {
        let mut player_guard = self.player.lock().unwrap();
        if let Some(player) = player_guard.take() {
            player.stop();
        }
    }
}
