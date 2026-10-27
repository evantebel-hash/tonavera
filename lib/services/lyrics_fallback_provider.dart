import '../models/lyrics_model.dart';
import '../models/song_model.dart';

abstract class LyricsFallbackProvider {
  String get providerName;
  Future<LyricsModel?> fetchLyrics(SongModel song);
}

/// Placeholder provider for future Local AI Whisper / Demucs transcription.
class LocalAiLyricsProvider implements LyricsFallbackProvider {
  @override
  String get providerName => 'Local AI Transcription (Future Enhancement)';

  @override
  Future<LyricsModel?> fetchLyrics(SongModel song) async {
    // Intentionally deferred to future AI phase
    return null;
  }
}
