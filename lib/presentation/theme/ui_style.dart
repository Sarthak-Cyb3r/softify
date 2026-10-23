/// Supported UI Presentation Styles for Softify.
enum UiStyle {
  /// Authentic Spotify-inspired content-first solid UI (#121212, #181818, #1DB954).
  classic,

  /// Luminous frosted glassmorphism UI (#0B0B1A, #14122B, #7C5CFF, #4FD1FF, #FF7AC6).
  auroraGlass;

  String get displayName {
    switch (this) {
      case UiStyle.classic:
        return 'Classic';
      case UiStyle.auroraGlass:
        return 'Aurora Glass';
    }
  }

  String get description {
    switch (this) {
      case UiStyle.classic:
        return 'Spotify-inspired solid dark theme with emerald green accents';
      case UiStyle.auroraGlass:
        return 'Frosted midnight glassmorphism with violet, cyan, and rose aurora accents';
    }
  }

  bool get isGlass => this == UiStyle.auroraGlass;
}

/// Control mode for performance-sensitive effects (BackdropFilter blur, animations).
enum ReduceEffectsMode {
  /// Automatically disable heavy blur on low-end devices or when system reduce-motion is active.
  auto,

  /// Always reduce effects (swap blur for solid translucent fills and static gradients).
  on,

  /// Always render full glassmorphism blur regardless of hardware heuristics.
  off;

  String get displayName {
    switch (this) {
      case ReduceEffectsMode.auto:
        return 'Auto';
      case ReduceEffectsMode.on:
        return 'On';
      case ReduceEffectsMode.off:
        return 'Off';
    }
  }

  String get description {
    switch (this) {
      case ReduceEffectsMode.auto:
        return 'Auto-detect low-end hardware & system reduce-motion';
      case ReduceEffectsMode.on:
        return 'Reduce blur & complex effects for maximum battery & smoothness';
      case ReduceEffectsMode.off:
        return 'Always enable full blur & dynamic gradients';
    }
  }
}
