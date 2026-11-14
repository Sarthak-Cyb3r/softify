enum AudioRepeatMode {
  off,
  playlist,
  one;

  /// Backward-compatible alias for previous `all` mode
  static const AudioRepeatMode all = AudioRepeatMode.playlist;

  AudioRepeatMode next() {
    return switch (this) {
      AudioRepeatMode.off => AudioRepeatMode.playlist,
      AudioRepeatMode.playlist => AudioRepeatMode.one,
      AudioRepeatMode.one => AudioRepeatMode.off,
    };
  }

  String get label => switch (this) {
    AudioRepeatMode.off => 'Repeat: Off',
    AudioRepeatMode.playlist => 'Repeat: Playlist',
    AudioRepeatMode.one => 'Repeat: Current Song',
  };
}
