import '../models/lyric_line.dart';

class LrcParseResult {
  final List<LyricLine> lines;
  final int offsetMs;

  const LrcParseResult({required this.lines, required this.offsetMs});
}

class LrcParser {
  // Regex supporting [mm:ss.xx], [mm:ss.xxx], and [hh:mm:ss.xx]
  static final RegExp _timestampPattern = RegExp(
    r'\[(?:(\d{1,2}):)?(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]',
  );

  /// Parses a raw LRC string into a sorted list of [LyricLine].
  static List<LyricLine> parse(String? rawLrc) {
    return parseWithDetails(rawLrc).lines;
  }

  /// Parses a raw LRC string returning both lines and metadata (e.g. offsetMs).
  static LrcParseResult parseWithDetails(String? rawLrc) {
    if (rawLrc == null || rawLrc.trim().isEmpty) {
      return const LrcParseResult(lines: [], offsetMs: 0);
    }

    final lines = rawLrc
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final parsedLines = <LyricLine>[];

    // LRC specification: [offset:+/-Milliseconds]
    // A positive value delays lyrics (shifts timestamps later: +offsetMs).
    // A negative value advances lyrics (shifts timestamps earlier: -offsetMs).
    int offsetMs = 0;
    final offsetRegex = RegExp(
      r'^\[offset:\s*([+-]?\d+)\s*\]$',
      caseSensitive: false,
    );

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final offsetMatch = offsetRegex.firstMatch(trimmed);
      if (offsetMatch != null) {
        offsetMs = int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
        continue;
      }

      // Ignore other ID tags like [ar:Artist], [ti:Title], [al:Album], [length:03:45], [by:Author]
      if (RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(trimmed)) {
        continue;
      }

      final matches = _timestampPattern.allMatches(trimmed).toList();
      if (matches.isEmpty) continue;

      // The text is whatever comes after the last timestamp tag
      final lastMatch = matches.last;
      final text = trimmed.substring(lastMatch.end).trim();

      // Handle multiple timestamps on one lyric line, e.g. [00:12.50][01:15.20]Chorus text
      for (final match in matches) {
        final hoursStr = match.group(1);
        final minsStr = match.group(2)!;
        final secsStr = match.group(3)!;
        final millisStr = match.group(4);

        int hours = hoursStr != null ? int.tryParse(hoursStr) ?? 0 : 0;
        int minutes = int.tryParse(minsStr) ?? 0;
        int seconds = int.tryParse(secsStr) ?? 0;
        int millis = 0;

        if (millisStr != null && millisStr.isNotEmpty) {
          if (millisStr.length == 1) {
            millis = (int.tryParse(millisStr) ?? 0) * 100;
          } else if (millisStr.length == 2) {
            millis = (int.tryParse(millisStr) ?? 0) * 10;
          } else {
            millis = int.tryParse(millisStr.substring(0, 3)) ?? 0;
          }
        }

        final rawTotalMs =
            (hours * 3600000) + (minutes * 60000) + (seconds * 1000) + millis;
        // Standard LRC specification:
        // [offset:+/-Milliseconds]
        // Positive (+) offset delays lyrics (increases start time: rawTotalMs + offsetMs).
        // Negative (-) offset advances lyrics (decreases start time: rawTotalMs - offsetMs).
        final adjustedMs = rawTotalMs + offsetMs;
        final duration = Duration(
          milliseconds: adjustedMs < 0 ? 0 : adjustedMs,
        );

        parsedLines.add(LyricLine(startTime: duration, text: text));
      }
    }

    // Sort ascending by timestamp
    parsedLines.sort((a, b) => a.startTime.compareTo(b.startTime));
    return LrcParseResult(lines: parsedLines, offsetMs: offsetMs);
  }

  /// Normalizes lyrics by cleaning carriage returns and excess whitespace.
  static String normalize(String text) {
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  }

  /// Checks if a string contains synchronized LRC timestamp patterns.
  static bool hasTimestamps(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    return _timestampPattern.hasMatch(text);
  }

  /// Uses binary search O(log N) to find the currently active lyric line index.
  /// Returns -1 if position is before the first lyric line.
  static int findActiveLineIndex(
    List<LyricLine> lines,
    Duration currentPosition,
  ) {
    if (lines.isEmpty) return -1;
    if (currentPosition < lines.first.startTime) return -1;
    if (currentPosition >= lines.last.startTime) return lines.length - 1;

    int low = 0;
    int high = lines.length - 1;
    int result = 0;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].startTime <= currentPosition) {
        result = mid;
        low =
            mid +
            1; // Try to find a later line that also satisfies <= currentPosition
      } else {
        high = mid - 1;
      }
    }

    return result;
  }
}
