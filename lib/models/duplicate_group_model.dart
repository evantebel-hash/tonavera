import 'dart:io';
import '../models/song_model.dart';

enum DuplicateMatchReason {
  exactPath,
  trackHash,
  metadataExact,
  metadataStrong,
}

class DuplicateSongCandidate {
  final SongModel song;
  final int? fileSizeBytes;
  final bool fileExists;
  final String fileFormat;
  final int completenessScore;

  DuplicateSongCandidate({
    required this.song,
    this.fileSizeBytes,
    required this.fileExists,
    required this.fileFormat,
    required this.completenessScore,
  });

  String get fileSizeFormatted {
    if (fileSizeBytes == null || fileSizeBytes! <= 0) return 'Unknown size';
    final kb = fileSizeBytes! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  static DuplicateSongCandidate fromSong(SongModel song) {
    final path = song.filePath ?? song.audioPath;
    final file = File(path);
    final exists = file.existsSync();
    int? size;
    if (exists) {
      try {
        size = file.lengthSync();
      } catch (_) {}
    }

    final ext = path.contains('.')
        ? path.split('.').last.toUpperCase()
        : 'UNKNOWN';

    // Calculate metadata completeness score
    int score = 0;
    if (exists) score += 10;
    if (song.title.isNotEmpty && song.title != 'Unknown Title') score += 2;
    if (song.artistName != null &&
        song.artistName!.isNotEmpty &&
        song.artistName != 'Unknown Artist')
      score += 2;
    if (song.albumTitle != null &&
        song.albumTitle!.isNotEmpty &&
        song.albumTitle != 'Unknown Album')
      score += 2;
    if (song.genreName != null && song.genreName!.isNotEmpty) score += 1;
    if (song.lyrics != null && song.lyrics!.isNotEmpty) score += 1;
    if (song.cover != null && song.cover!.isNotEmpty) score += 2;
    if (song.duration > 0) score += 1;

    // Prefer lossless / higher quality formats in ties
    if (ext == 'FLAC') score += 3;
    if (ext == 'M4A' || ext == 'AAC') score += 2;
    if (ext == 'MP3') score += 1;

    return DuplicateSongCandidate(
      song: song,
      fileSizeBytes: size,
      fileExists: exists,
      fileFormat: ext,
      completenessScore: score,
    );
  }
}

class DuplicateGroup {
  final String groupId;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final DuplicateMatchReason matchReason;
  final String reasonDescription;
  final List<DuplicateSongCandidate> candidates;
  final int recommendedKeepSongId;

  DuplicateGroup({
    required this.groupId,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.matchReason,
    required this.reasonDescription,
    required this.candidates,
    required this.recommendedKeepSongId,
  });
}
