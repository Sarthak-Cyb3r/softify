/// Metrolist Canonical Design System Dimensions & Physics Constants
/// Reverse-engineered directly from com.metrolist.music.constants.Dimensions.kt
class MetrolistDimensions {
  // Navigation
  static const double navigationBarHeight = 80.0;
  static const double slimNavBarHeight = 64.0;
  static const double appBarHeight = 64.0;

  // Player & BottomSheet
  static const double miniPlayerHeight = 64.0;
  static const double minMiniPlayerHeight = 16.0;
  static const double miniPlayerBottomSpacing = 8.0;
  static const double queuePeekHeight = 64.0;
  static const double playerHorizontalPadding = 32.0;

  // List & Grid Items
  static const double listItemHeight = 64.0;
  static const double suggestionItemHeight = 56.0;
  static const double searchFilterHeight = 48.0;
  static const double listThumbnailSize = 48.0;
  static const double smallGridThumbnailHeight = 104.0;
  static const double gridThumbnailHeight = 128.0;
  static const double albumThumbnailSize = 144.0;

  // Geometry
  static const double thumbnailCornerRadius = 3.0;
  static const double modernPillRadius = 32.0;
  static const double chipCornerRadius = 16.0;
  static const double cardCornerRadius = 24.0;

  // Spring Physics (Critical Damping)
  // Jetpack Compose: Spring.DampingRatioNoBouncy (1.0f)
  // StiffnessMediumLow = 400f; StiffnessLow = 200f
  static const double springDamping = 1.0;
  static const double springStiffnessMediumLow = 400.0;
  static const double springStiffnessLow = 200.0;

  // MiniPlayer Swipe Threshold Calculation
  // threshold = round(600 / (1 + exp(-(-11.44748 * sensitivity + 9.04945))))
  static double getAutoSwipeThreshold(double sensitivity) {
    // Default sensitivity = 0.73 -> ~206 px
    return 600.0 / (1.0 + (-( -11.44748 * sensitivity + 9.04945 )).clamp(-20.0, 20.0).abs());
  }
}
