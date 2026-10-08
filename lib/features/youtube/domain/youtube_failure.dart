sealed class YoutubeFailure {
  final String userMessage;
  const YoutubeFailure(this.userMessage);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YoutubeFailure &&
          runtimeType == other.runtimeType &&
          userMessage == other.userMessage;

  @override
  int get hashCode => userMessage.hashCode;

  @override
  String toString() => '$runtimeType("$userMessage")';
}

class InvalidLinkFailure extends YoutubeFailure {
  const InvalidLinkFailure([
    super.userMessage = 'The provided link is not a valid YouTube link.',
  ]);
}

class VideoUnavailableFailure extends YoutubeFailure {
  const VideoUnavailableFailure([
    super.userMessage = 'This video is unavailable or has been removed.',
  ]);
}

class PrivateVideoFailure extends YoutubeFailure {
  const PrivateVideoFailure([
    super.userMessage = 'This video is private and cannot be played.',
  ]);
}

class AgeRestrictedFailure extends YoutubeFailure {
  const AgeRestrictedFailure([
    super.userMessage =
        'This video is age-restricted and requires signing in.',
  ]);
}

class RegionBlockedFailure extends YoutubeFailure {
  const RegionBlockedFailure([
    super.userMessage =
        'This video is blocked in your region by the content owner.',
  ]);
}

class LiveStreamFailure extends YoutubeFailure {
  const LiveStreamFailure([
    super.userMessage = 'Live streams are not supported for audio playback.',
  ]);
}

class NetworkErrorFailure extends YoutubeFailure {
  const NetworkErrorFailure([
    super.userMessage =
        'Network connection error. Please check your internet connection.',
  ]);
}

class GenericYoutubeFailure extends YoutubeFailure {
  const GenericYoutubeFailure([
    super.userMessage = 'Failed to load YouTube content. Please try again.',
  ]);
}
