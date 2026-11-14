import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Metadata for a track's looping visual Canvas.
class TrackCanvas {
  final String trackId;
  final String canvasUrl;
  final String? localFilePath;
  final bool hasVideo;

  const TrackCanvas({
    required this.trackId,
    required this.canvasUrl,
    this.localFilePath,
    this.hasVideo = false,
  });

  static const TrackCanvas empty = TrackCanvas(
    trackId: '',
    canvasUrl: '',
    hasVideo: false,
  );
}

/// Spotify Canvas-style looping vertical video background engine.
/// Fetches, caches, and streams lightweight MP4 video loops for Now Playing surfaces.
class CanvasEngineService {
  static final CanvasEngineService instance = CanvasEngineService._internal();

  CanvasEngineService._internal();

  bool _isCanvasEnabled = true;
  final Map<String, TrackCanvas> _memoryCache = {};
  Directory? _canvasCacheDir;

  bool get isCanvasEnabled => _isCanvasEnabled;

  void toggleCanvas(bool enabled) {
    _isCanvasEnabled = enabled;
  }

  /// Initializes the local canvas cache directory.
  Future<void> initialize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      _canvasCacheDir = Directory(p.join(cacheDir.path, 'softify_canvas'));
      if (!await _canvasCacheDir!.exists()) {
        await _canvasCacheDir!.create(recursive: true);
      }
    } catch (_) {}
  }

  /// Resolves the canvas video loop for a track.
  Future<TrackCanvas> resolveCanvasForTrack(String trackId) async {
    if (!_isCanvasEnabled) return TrackCanvas.empty;

    if (_memoryCache.containsKey(trackId)) {
      return _memoryCache[trackId]!;
    }

    // Check if cached on local disk
    if (_canvasCacheDir != null) {
      final localFile = File(p.join(_canvasCacheDir!.path, '$trackId.mp4'));
      if (await localFile.exists()) {
        final canvas = TrackCanvas(
          trackId: trackId,
          canvasUrl: localFile.path,
          localFilePath: localFile.path,
          hasVideo: true,
        );
        _memoryCache[trackId] = canvas;
        return canvas;
      }
    }

    return TrackCanvas.empty;
  }

  /// Registers and caches a canvas video file for a track.
  Future<void> cacheCanvasVideo(String trackId, String remoteUrl) async {
    if (_canvasCacheDir == null) return;

    try {
      final response = await http.get(Uri.parse(remoteUrl));
      if (response.statusCode == 200) {
        final localFile = File(p.join(_canvasCacheDir!.path, '$trackId.mp4'));
        await localFile.writeAsBytes(response.bodyBytes);

        _memoryCache[trackId] = TrackCanvas(
          trackId: trackId,
          canvasUrl: remoteUrl,
          localFilePath: localFile.path,
          hasVideo: true,
        );
      }
    } catch (_) {}
  }

  /// Clears the canvas disk cache.
  Future<void> clearCache() async {
    _memoryCache.clear();
    try {
      if (_canvasCacheDir != null && await _canvasCacheDir!.exists()) {
        await _canvasCacheDir!.delete(recursive: true);
        await _canvasCacheDir!.create(recursive: true);
      }
    } catch (_) {}
  }
}
