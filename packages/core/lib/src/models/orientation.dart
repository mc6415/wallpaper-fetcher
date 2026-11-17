enum WallpaperOrientation {
  landscape,
  portrait,
  square;

  /// Anything within 5% of square counts as square.
  static WallpaperOrientation of(int width, int height) {
    if (width <= 0 || height <= 0) return square;
    final ratio = width / height;
    if (ratio > 1.05) return landscape;
    if (ratio < 0.95) return portrait;
    return square;
  }
}

typedef Resolution = ({int width, int height});

/// Parses `3840x2160`. Returns null for anything else (including `any`).
Resolution? parseResolution(String? value) {
  final match = RegExp(r'^\s*(\d+)\s*[xX×]\s*(\d+)\s*$').firstMatch(value ?? '');
  if (match == null) return null;
  final width = int.parse(match.group(1)!);
  final height = int.parse(match.group(2)!);
  if (width == 0 || height == 0) return null;
  return (width: width, height: height);
}

String formatResolution(Resolution r) => '${r.width}x${r.height}';
