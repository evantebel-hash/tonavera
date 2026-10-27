class LyricLine {
  final Duration startTime;
  final String text;

  const LyricLine({required this.startTime, required this.text});

  @override
  String toString() => '${startTime.inMilliseconds}ms: $text';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricLine &&
          runtimeType == other.runtimeType &&
          startTime == other.startTime &&
          text == other.text;

  @override
  int get hashCode => startTime.hashCode ^ text.hashCode;
}
