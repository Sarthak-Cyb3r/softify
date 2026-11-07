pub fn normalize_stream_url(raw_url: &str) -> String {
    let mut url = raw_url.trim().to_string();
    if url.starts_with("http://") {
        url = url.replacen("http://", "https://", 1);
    }
    url
}
