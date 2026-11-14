use std::time::Instant;
use softify_core::models::{QualityPreset, Track};
use softify_core::resolvers::hybrid::HybridStreamResolver;

struct BenchmarkTrack {
    category: &'static str,
    title: &'static str,
    artist: &'static str,
    album: Option<&'static str>,
    duration_ms: u64,
}

#[tokio::main]
async fn main() {
    println!("=== Softify Audio Quality Verifier (Target: 320 kbps Studio Master) ===");
    println!("Mode: LIVE NETWORK VERIFICATION (Real JioSaavn CDN & YouTube Innertube)\n");

    let args: Vec<String> = std::env::args().collect();
    let disable_saavn = args.iter().any(|a| a == "--disable-saavn" || a == "--force-youtube");
    let count: usize = args.iter()
        .find_map(|s| s.parse::<usize>().ok())
        .unwrap_or(30);

    if disable_saavn {
        println!(">>> Flag enabled: --disable-saavn (Forcing YouTube fallback path for all tracks) <<<\n");
    }

    let catalog: Vec<BenchmarkTrack> = vec![
        // 1-10: Popular Global & Bollywood
        BenchmarkTrack { category: "Popular", title: "Tum Hi Ho", artist: "Arijit Singh", album: Some("Aashiqui 2"), duration_ms: 262_000 },
        BenchmarkTrack { category: "Popular", title: "Kesariya", artist: "Arijit Singh", album: Some("Brahmāstra"), duration_ms: 268_000 },
        BenchmarkTrack { category: "Popular", title: "Blinding Lights", artist: "The Weeknd", album: Some("After Hours"), duration_ms: 200_000 },
        BenchmarkTrack { category: "Popular", title: "Shape of You", artist: "Ed Sheeran", album: Some("Divide"), duration_ms: 233_000 },
        BenchmarkTrack { category: "Popular", title: "Starboy", artist: "The Weeknd", album: Some("Starboy"), duration_ms: 230_000 },
        BenchmarkTrack { category: "Popular", title: "Apna Bana Le", artist: "Arijit Singh", album: Some("Bhediya"), duration_ms: 261_000 },
        BenchmarkTrack { category: "Popular", title: "Levitating", artist: "Dua Lipa", album: Some("Future Nostalgia"), duration_ms: 203_000 },
        BenchmarkTrack { category: "Popular", title: "Chaleya", artist: "Arijit Singh", album: Some("Jawan"), duration_ms: 200_000 },
        BenchmarkTrack { category: "Popular", title: "Flowers", artist: "Miley Cyrus", album: Some("Endless Summer Vacation"), duration_ms: 200_000 },
        BenchmarkTrack { category: "Popular", title: "Raataan Lambiyan", artist: "Jubin Nautiyal", album: Some("Shershaah"), duration_ms: 230_000 },

        // 11-20: Older & Regional (Hindi Retro, Punjabi, Tamil, Telugu)
        BenchmarkTrack { category: "Retro/Regional", title: "Lag Ja Gale", artist: "Lata Mangeshkar", album: Some("Woh Kaun Thi"), duration_ms: 258_000 },
        BenchmarkTrack { category: "Retro/Regional", title: "Pal Pal Dil Ke Paas", artist: "Kishore Kumar", album: Some("Blackmail"), duration_ms: 329_000 },
        BenchmarkTrack { category: "Retro/Regional", title: "Roop Tera Mastana", artist: "Kishore Kumar", album: Some("Aradhana"), duration_ms: 225_000 },
        BenchmarkTrack { category: "Retro/Regional", title: "Brown Munde", artist: "AP Dhillon", album: None, duration_ms: 267_000 },
        BenchmarkTrack { category: "Retro/Regional", title: "295", artist: "Sidhu Moose Wala", album: Some("Moosetape"), duration_ms: 270_000 },
        BenchmarkTrack { category: "Retro/Regional", title: "Lover", artist: "Diljit Dosanjh", album: Some("MoonChild Era"), duration_ms: 191_000 },
        BenchmarkTrack { category: "Retro/Regional", title: "Why This Kolaveri Di", artist: "Dhanush", album: Some("3"), duration_ms: 245_000 },
        BenchmarkTrack { category: "Retro/Regional", title: "Arabic Kuthu", artist: "Anirudh Ravichander", album: Some("Beast"), duration_ms: 280_000 },
        BenchmarkTrack { category: "Retro/Regional", title: "Samajavaragamana", artist: "Sid Sriram", album: Some("Ala Vaikunthapurramuloo"), duration_ms: 214_000 },
        BenchmarkTrack { category: "Retro/Regional", title: "Rowdy Baby", artist: "Dhanush", album: Some("Maari 2"), duration_ms: 284_000 },

        // 21-30: Obscure & Independent
        BenchmarkTrack { category: "Indie/Obscure", title: "Kasoor", artist: "Prateek Kuhad", album: None, duration_ms: 197_000 },
        BenchmarkTrack { category: "Indie/Obscure", title: "Cold/mess", artist: "Prateek Kuhad", album: None, duration_ms: 275_000 },
        BenchmarkTrack { category: "Indie/Obscure", title: "Alag Aasmaan", artist: "Anuv Jain", album: None, duration_ms: 212_000 },
        BenchmarkTrack { category: "Indie/Obscure", title: "Baarishein", artist: "Anuv Jain", album: None, duration_ms: 207_000 },
        BenchmarkTrack { category: "Indie/Obscure", title: "Roz Roz", artist: "The Yellow Diary", album: None, duration_ms: 236_000 },
        BenchmarkTrack { category: "Indie/Obscure", title: "Choojhn De", artist: "When Chai Met Toast", album: None, duration_ms: 220_000 },
        BenchmarkTrack { category: "Indie/Obscure", title: "Khoj", artist: "When Chai Met Toast", album: None, duration_ms: 245_000 },
        BenchmarkTrack { category: "Indie/Obscure", title: "Liggi", artist: "Ritviz", album: None, duration_ms: 181_000 },
        BenchmarkTrack { category: "Indie/Obscure", title: "Sage", artist: "Ritviz", album: None, duration_ms: 184_000 },
        BenchmarkTrack { category: "Indie/Obscure", title: "Udaan", artist: "Amit Trivedi", album: Some("Udaan"), duration_ms: 274_000 },
    ];

    let resolver = HybridStreamResolver::new();
    let http_client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(8))
        .build()
        .unwrap();

    let tracks_to_run: Vec<BenchmarkTrack> = catalog.into_iter().take(count).collect();

    println!("| # | Track | Category | Provider | Codec | Requested | Actual | Verified | TTFA |");
    println!("|---|-------|----------|----------|-------|-----------|--------|----------|------|");

    let mut success_count = 0;
    let mut studio_master_320_count = 0;

    for (i, b) in tracks_to_run.iter().enumerate() {
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
        match resolver.resolve_with_options(&track, QualityPreset::High, disable_saavn).await {
            Ok(stream) => {
                let mut req = http_client.get(&stream.url).header("Range", "bytes=0-1");
                for h in &stream.headers {
                    req = req.header(&h.name, &h.value);
                }

                let (verified, ttfa_ms) = match req.send().await {
                    Ok(resp) => {
                        let status = resp.status();
                        let verified = status == 200 || status == 206;
                        let elapsed = t0.elapsed().as_millis() as u64;
                        (if verified { "YES" } else { "NO" }, elapsed)
                    }
                    Err(_) => ("NO", t0.elapsed().as_millis() as u64),
                };

                let provider_display = if stream.provider.contains("jiosaavn") {
                    "JioSaavn Studio"
                } else {
                    "YouTube Fallback"
                };

                if verified == "YES" {
                    success_count += 1;
                    if stream.bitrate_kbps >= 320 {
                        studio_master_320_count += 1;
                    }
                }

                println!(
                    "| {:02} | {} - {} | {} | {} | {} | 320 kbps | {} kbps | {} | {} ms |",
                    i + 1,
                    track.title,
                    track.artist,
                    b.category,
                    provider_display,
                    stream.codec.to_uppercase(),
                    stream.bitrate_kbps,
                    verified,
                    ttfa_ms
                );
            }
            Err(e) => {
                println!(
                    "| {:02} | {} - {} | {} | FAILED | N/A | 320 kbps | 0 kbps | NO | {} ms ({}) |",
                    i + 1,
                    track.title,
                    track.artist,
                    b.category,
                    t0.elapsed().as_millis(),
                    e
                );
            }
        }
    }

    let total = tracks_to_run.len();
    let success_rate = (success_count as f64 / total as f64) * 100.0;
    println!("\n=== Summary ===");
    println!("Total tracks resolved: {}/{}", success_count, total);
    println!("Studio Master (320 kbps) achieved: {}/{}", studio_master_320_count, total);
    println!("Success rate: {:.1}%\n", success_rate);
}
