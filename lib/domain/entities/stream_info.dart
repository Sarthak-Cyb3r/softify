class StreamInfo {
  final Uri url;
  final String container; // e.g. "m4a"
  final int bitrate;      // in bits per second
  final String codec;     // e.g. "mp4a.40.2"
  final DateTime expiresAt;
  final String providerName; // e.g. "youtube_explode", "piped_instance"
  final Map<String, String>? headers;
  final int? sizeBytes;

  const StreamInfo({
    required this.url,
    required this.container,
    required this.bitrate,
    required this.codec,
    required this.expiresAt,
    required this.providerName,
    this.headers,
    this.sizeBytes,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  String toString() =>
      'StreamInfo(url: $url, container: $container, bitrate: ${bitrate ~/ 1000}kbps, provider: $providerName)';
}
