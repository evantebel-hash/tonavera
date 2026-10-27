class YouTubeNormalizer {
  /// Normalizes track title by trimming common noise tags like (Official Video), [HD], etc.
  static String normalizeTitle(String rawTitle) {
    if (rawTitle.isEmpty) return 'Untitled Track';
    String clean = rawTitle;

    final regexes = [
      RegExp(
        r'\s*[\(\[]\s*.*?(official|music|video|lyric|lyrics|audio|hd|4k|remastered).*?[\)\]]',
        caseSensitive: false,
      ),
      RegExp(r'\s*\|?\s*official\s*music\s*video\s*$', caseSensitive: false),
    ];

    for (final reg in regexes) {
      clean = clean.replaceAll(reg, '');
    }

    return clean.trim().isEmpty ? rawTitle : clean.trim();
  }

  /// Parses duration string like "3:45", "03:45", or "1:15:30" into seconds
  static int parseDurationToSeconds(dynamic durationInput) {
    if (durationInput == null) return 0;
    if (durationInput is int) return durationInput;
    final str = durationInput.toString().trim();
    if (str.isEmpty) return 0;

    // If it's a numeric string in seconds
    final numVal = int.tryParse(str);
    if (numVal != null) return numVal;

    final parts = str.split(':');
    try {
      if (parts.length == 2) {
        final m = int.parse(parts[0].trim());
        final s = int.parse(parts[1].trim());
        return (m * 60) + s;
      } else if (parts.length == 3) {
        final h = int.parse(parts[0].trim());
        final m = int.parse(parts[1].trim());
        final s = int.parse(parts[2].trim());
        return (h * 3600) + (m * 60) + s;
      }
    } catch (_) {}

    return 0;
  }

  /// Standardizes thumbnail URL to high quality
  static String formatThumbnailUrl(String? rawUrl, String videoId) {
    if (rawUrl != null && rawUrl.isNotEmpty) {
      if (rawUrl.startsWith('//')) return 'https:$rawUrl';
      return rawUrl;
    }
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }
}
