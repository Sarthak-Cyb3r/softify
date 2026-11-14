use std::time::Instant;
use softify_core::models::{QualityPreset, Track};
use softify_core::resolvers::hybrid::HybridStreamResolver;

struct BenchmarkTrack {
    title: &'static str,
    artist: &'static str,
    album: Option<&'static str>,
    duration_ms: u64,
}

#[tokio::main]
async fn main() {
    println!("=== Softify Audio Quality Verifier (Target: 320 kbps Studio Master) ===");
    let args: Vec<String> = std::env::args().collect();
    let count: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(10);

    let benchmark_catalog: Vec<BenchmarkTrack> = vec![
        BenchmarkTrack { title: "Tum Hi Ho", artist: "Arijit Singh", album: Some("Aashiqui 2"), duration_ms: 262_000 },
        BenchmarkTrack { title: "Kesariya", artist: "Arijit Singh", album: Some("Brahmastra"), duration_ms: 268_000 },
        BenchmarkTrack { title: "Blinding Lights", artist: "The Weeknd", album: Some("After Hours"), duration_ms: 200_000 },
        BenchmarkTrack { title: "Shape of You", artist: "Ed Sheeran", album: Some("Divide"), duration_ms: 233_000 },
        BenchmarkTrack { title: "Starboy", artist: "The Weeknd", album: Some("Starboy"), duration_ms: 230_000 },
        BenchmarkTrack { title: "Apna Bana Le", artist: "Arijit Singh", album: Some("Bhediya"), duration_ms: 261_000 },
        BenchmarkTrack { title: "Levitating", artist: "Dua Lipa", album: Some("Future Nostalgia"), duration_ms: 203_000 },
        BenchmarkTrack { title: "Chaleya", artist: "Arijit Singh", album: Some("Jawan"), duration_ms: 200_000 },
        BenchmarkTrack { title: "Flowers", artist: "Miley Cyrus", album: Some("Endless Summer Vacation"), duration_ms: 200_000 },
        BenchmarkTrack { title: "Raataan Lambiyan", artist: "Jubin Nautiyal", album: Some("Shershaah"), duration_ms: 230_000 },
    ];

    let resolver = HybridStreamResolver::new();
    let http_client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(8))
        .build()
        .unwrap();

    println!("\nResolving top {count} tracks with High (320 kbps) preset:\n");
    println!("| # | Track | Provider | Codec | Requested | Actual | Verified | TTFA |");
    println!("|---|-------|----------|-------|-----------|--------|----------|------|");

    let tracks_to_run = benchmark_catalog.into_iter().take(count);

    for (i, b) in tracks_to_run.enumerate() {
        let track = Track {
            id: format!("bench_{}", i + 1),
            source_id: format!("bench_{}", i + 1),
            title: b.title.to_string(),
            artist: b.artist.to_string(),
            album: b.album.map(|s| s.to_string()),
            duration_ms: b.duration_ms,
            cover_url: None,
            match_confidence: None,
            is_liked: false,
            is_unavailable: false,
        };

        let t0 = Instant::now();
        match resolver.resolve(&track, QualityPreset::High).await {
            Ok(stream) => {
                // Measure TTFA by requesting first byte of audio
                let mut req = http_client.get(&stream.url).header("Range", "bytes=0-0");
                for h in &stream.headers {
                    req = req.header(&h.name, &h.value);
                }

                let (verified_status, ttfa_ms) = match req.send().await {
                    Ok(resp) => {
                        let status = resp.status().as_u16();
                        let elapsed = t0.elapsed().as_millis();
                        let is_ok = status == 200 || status == 206;
                        (if is_ok { "YES" } else { "NO (HTTP)" }, elapsed)
                    }
                    Err(_) => ("NO (Conn)", t0.elapsed().as_millis()),
                };

                let actual_kbps = stream.bitrate_kbps;
                let req_kbps = 320;
                let provider_short = if stream.provider.contains("jiosaavn") {
                    "JioSaavn Studio"
                } else if stream.provider.contains("youtube") {
                    "YouTube Fallback"
                } else {
                    &stream.provider
                };

                println!(
                    "| {:02} | {} - {} | {} | {} | {} kbps | {} kbps | {} | {} ms |",
                    i + 1,
                    b.title,
                    b.artist,
                    provider_short,
                    stream.codec.to_uppercase(),
                    req_kbps,
                    actual_kbps,
                    verified_status,
                    ttfa_ms
                );
            }
            Err(e) => {
                let ttfa_ms = t0.elapsed().as_millis();
                println!(
                    "| {:02} | {} - {} | FAILED: {} | - | 320 kbps | 0 kbps | NO | {} ms |",
                    i + 1,
                    b.title,
                    b.artist,
                    e,
                    ttfa_ms
                );
            }
        }
    }
    println!();
}
