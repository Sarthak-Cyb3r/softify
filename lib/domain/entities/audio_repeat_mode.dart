enum AudioRepeatMode {
  off,
  all,
  one;

  AudioRepeatMode next() {
    return switch (this) {
      AudioRepeatMode.off => AudioRepeatMode.all,
      AudioRepeatMode.all => AudioRepeatMode.one,
      AudioRepeatMode.one => AudioRepeatMode.off,
    };
  }
}
