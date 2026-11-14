import '../entities/audio_quality_preset.dart';
import '../entities/stream_info.dart';
import '../entities/track.dart';

abstract class IStreamResolver {
  /// Resolves the direct audio stream URL for a given track just-in-time.
  ///
  /// If [forceFresh] is true, ignores any in-memory cached stream URLs and
  /// performs a fresh resolution (e.g. following a 403 Forbidden error).
  Future<StreamInfo> resolve(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
    bool forceFresh = false,
  });

  /// Asynchronously pre-fetches and caches stream information for upcoming tracks.
  Future<void> prefetch(
    Track track, {
    AudioQualityPreset quality = AudioQualityPreset.standard,
  });
}
