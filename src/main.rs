slint::include_modules!();

use std::sync::{Arc, Mutex};
use slint::{ModelRc, SharedString, VecModel};
use tokio::runtime::Runtime;

mod audio;
mod core;
mod db;
mod models;
mod resolvers;

use audio::AudioPlayer;
use db::Database;
use models::Track;
use resolvers::{SaavnResolver, YouTubeResolver};

fn track_to_item(t: &Track) -> TrackItem {
    TrackItem {
        id: SharedString::from(t.id.as_str()),
        title: SharedString::from(t.title.as_str()),
        artist: SharedString::from(t.artist.as_str()),
        album: SharedString::from(t.album.as_deref().unwrap_or("")),
        duration_str: SharedString::from(t.duration_formatted()),
        is_liked: t.is_liked,
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let rt = Arc::new(Runtime::new()?);
    let ui = AppWindow::new()?;

    let db = Arc::new(Database::new());
    let player = match AudioPlayer::new() {
        Ok(p) => Arc::new(p),
        Err(e) => {
            eprintln!("Audio player warning: {}", e);
            // Create dummy or bubble up error
            return Err(e.into());
        }
    };

    let saavn = Arc::new(SaavnResolver::new());
    let youtube = Arc::new(YouTubeResolver::new());

    let current_tracks = Arc::new(Mutex::new(Vec::<Track>::new()));

    // Initial load: Library Tracks
    let initial_tracks = db.get_all_tracks().unwrap_or_default();
    *current_tracks.lock().unwrap() = initial_tracks.clone();

    let track_models: Vec<TrackItem> = initial_tracks.iter().map(track_to_item).collect();
    ui.set_tracks(ModelRc::new(VecModel::from(track_models)));

    // Callback: Load Library Tracks
    {
        let ui_weak = ui.as_weak();
        let db_clone = db.clone();
        let current_tracks_clone = current_tracks.clone();

        ui.on_load_library(move || {
            let tracks = db_clone.get_all_tracks().unwrap_or_default();
            *current_tracks_clone.lock().unwrap() = tracks.clone();
            let items: Vec<TrackItem> = tracks.iter().map(track_to_item).collect();

            if let Some(ui) = ui_weak.upgrade() {
                ui.set_tracks(ModelRc::new(VecModel::from(items)));
                ui.set_active_tab(SharedString::from("library"));
            }
        });
    }

    // Callback: Load Liked Songs
    {
        let ui_weak = ui.as_weak();
        let db_clone = db.clone();
        let current_tracks_clone = current_tracks.clone();

        ui.on_load_liked_songs(move || {
            let tracks = db_clone.get_liked_tracks().unwrap_or_default();
            *current_tracks_clone.lock().unwrap() = tracks.clone();
            let items: Vec<TrackItem> = tracks.iter().map(track_to_item).collect();

            if let Some(ui) = ui_weak.upgrade() {
                ui.set_tracks(ModelRc::new(VecModel::from(items)));
                ui.set_active_tab(SharedString::from("liked"));
            }
        });
    }

    // Callback: Search Submitted
    {
        let ui_weak = ui.as_weak();
        let saavn_clone = saavn.clone();
        let rt_clone = rt.clone();
        let current_tracks_clone = current_tracks.clone();

        ui.on_search_submitted(move |query| {
            let q = query.to_string();
            if q.trim().is_empty() {
                return;
            }

            let ui_weak_inner = ui_weak.clone();
            let saavn_inner = saavn_clone.clone();
            let current_tracks_inner = current_tracks_clone.clone();

            if let Some(ui) = ui_weak.upgrade() {
                ui.set_current_status(SharedString::from(format!("Searching for '{}'...", q)));
            }

            rt_clone.spawn(async move {
                match saavn_inner.search_tracks(&q).await {
                    Ok(results) => {
                        *current_tracks_inner.lock().unwrap() = results.clone();
                        let items: Vec<TrackItem> = results.iter().map(track_to_item).collect();
                        let count = items.len();

                        let _ = slint::invoke_from_event_loop(move || {
                            if let Some(ui) = ui_weak_inner.upgrade() {
                                ui.set_tracks(ModelRc::new(VecModel::from(items)));
                                ui.set_current_status(SharedString::from(format!("Found {} tracks", count)));
                            }
                        });
                    }
                    Err(err) => {
                        let _ = slint::invoke_from_event_loop(move || {
                            if let Some(ui) = ui_weak_inner.upgrade() {
                                ui.set_current_status(SharedString::from(format!("Search failed: {}", err)));
                            }
                        });
                    }
                }
            });
        });
    }

    // Callback: Play Track Index
    {
        let ui_weak = ui.as_weak();
        let player_clone = player.clone();
        let saavn_clone = saavn.clone();
        let youtube_clone = youtube.clone();
        let rt_clone = rt.clone();
        let current_tracks_clone = current_tracks.clone();

        ui.on_play_track_index(move |idx| {
            let index = idx as usize;
            let tracks_guard = current_tracks_clone.lock().unwrap();
            if index >= tracks_guard.len() {
                return;
            }
            let track = tracks_guard[index].clone();
            drop(tracks_guard);

            let ui_weak_inner = ui_weak.clone();
            let player_inner = player_clone.clone();
            let saavn_inner = saavn_clone.clone();
            let youtube_inner = youtube_clone.clone();

            if let Some(ui) = ui_weak.upgrade() {
                ui.set_current_title(SharedString::from(track.title.as_str()));
                ui.set_current_artist(SharedString::from(track.artist.as_str()));
                ui.set_current_status(SharedString::from("Resolving audio stream..."));
                ui.set_is_playing(true);
            }

            rt_clone.spawn(async move {
                let stream_url_result = match saavn_inner.resolve_track(&track).await {
                    Ok(url) => Ok(url),
                    Err(_) => {
                        // YouTube fallback
                        youtube_inner.resolve_stream_url(&track.source_id).await
                    }
                };

                match stream_url_result {
                    Ok(url) => {
                        match player_inner.play_url(&url).await {
                            Ok(()) => {
                                let _ = slint::invoke_from_event_loop(move || {
                                    if let Some(ui) = ui_weak_inner.upgrade() {
                                        ui.set_current_status(SharedString::from("Playing"));
                                        ui.set_is_playing(true);
                                    }
                                });
                            }
                            Err(e) => {
                                let _ = slint::invoke_from_event_loop(move || {
                                    if let Some(ui) = ui_weak_inner.upgrade() {
                                        ui.set_current_status(SharedString::from(format!("Playback error: {}", e)));
                                        ui.set_is_playing(false);
                                    }
                                });
                            }
                        }
                    }
                    Err(e) => {
                        let _ = slint::invoke_from_event_loop(move || {
                            if let Some(ui) = ui_weak_inner.upgrade() {
                                ui.set_current_status(SharedString::from(format!("Stream error: {}", e)));
                                ui.set_is_playing(false);
                            }
                        });
                    }
                }
            });
        });
    }

    // Transport Controls
    {
        let player_clone = player.clone();
        let ui_weak = ui.as_weak();
        ui.on_toggle_play_pause(move || {
            let is_now_playing = player_clone.toggle_pause();
            if let Some(ui) = ui_weak.upgrade() {
                ui.set_is_playing(is_now_playing);
                ui.set_current_status(SharedString::from(if is_now_playing { "Playing" } else { "Paused" }));
            }
        });
    }

    {
        let player_clone = player.clone();
        ui.on_volume_changed(move |val| {
            player_clone.set_volume(val);
        });
    }

    // Run Slint Event Loop
    ui.run()?;

    Ok(())
}
