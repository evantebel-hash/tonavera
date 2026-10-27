import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../models/duplicate_group_model.dart';
import '../repositories/local_music_repository.dart';
import '../providers/player_provider.dart';

class DuplicateDetectorService {
  final LocalMusicRepository _repository;

  DuplicateDetectorService({LocalMusicRepository? repository})
    : _repository = repository ?? LocalMusicRepository();

  static String _normalize(String str) {
    return str.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Scans songs list and groups duplicate candidates according to multi-level rules.
  List<DuplicateGroup> detectDuplicates(List<SongModel> songs) {
    if (songs.length < 2) return [];

    final groups = <DuplicateGroup>[];
    final processedSongIds = <int>{};

    // 1. Group by exact TrackHash
    final trackHashBuckets = <String, List<SongModel>>{};
    for (final song in songs) {
      final normTitle = _normalize(song.title);
      if (normTitle.isEmpty || normTitle == 'unknown title') {
        if (song.duration <= 0 ||
            song.artistName == null ||
            song.artistName!.isEmpty ||
            song.artistName == 'Unknown Artist') {
          continue;
        }
      }
      final hash = song.trackHash;
      if (hash.isNotEmpty) {
        trackHashBuckets.putIfAbsent(hash, () => []).add(song);
      }
    }

    for (final entry in trackHashBuckets.entries) {
      final bucket = entry.value;
      if (bucket.length >= 2) {
        final candidates = bucket.map(DuplicateSongCandidate.fromSong).toList();
        candidates.sort(
          (a, b) => b.completenessScore.compareTo(a.completenessScore),
        );
        final recommendedId = candidates.first.song.id;

        final first = bucket.first;
        groups.add(
          DuplicateGroup(
            groupId: 'trackhash_${entry.key}',
            title: first.title,
            artist: first.artistName ?? 'Unknown Artist',
            album: first.albumTitle ?? 'Unknown Album',
            duration: first.duration,
            matchReason: DuplicateMatchReason.trackHash,
            reasonDescription:
                'Same trackHash (Identik title, artist, album, dan durasi)',
            candidates: candidates,
            recommendedKeepSongId: recommendedId,
          ),
        );

        for (final s in bucket) {
          processedSongIds.add(s.id);
        }
      }
    }

    // 2. Group remaining songs by Normalized Metadata Signature (Title + Artist + Album + Duration)
    final remainingSongs = songs
        .where((s) => !processedSongIds.contains(s.id))
        .toList();
    final metadataBuckets = <String, List<SongModel>>{};

    for (final song in remainingSongs) {
      final normTitle = _normalize(song.title);
      final normArtist = _normalize(song.artistName ?? '');
      final normAlbum = _normalize(song.albumTitle ?? '');
      if (normTitle.isEmpty || normTitle == 'unknown title') continue;

      final key = '$normTitle|$normArtist|$normAlbum|${song.duration}';
      metadataBuckets.putIfAbsent(key, () => []).add(song);
    }

    for (final entry in metadataBuckets.entries) {
      final bucket = entry.value;
      if (bucket.length >= 2) {
        final candidates = bucket.map(DuplicateSongCandidate.fromSong).toList();
        candidates.sort(
          (a, b) => b.completenessScore.compareTo(a.completenessScore),
        );
        final recommendedId = candidates.first.song.id;

        final first = bucket.first;
        groups.add(
          DuplicateGroup(
            groupId: 'meta_exact_${first.id}',
            title: first.title,
            artist: first.artistName ?? 'Unknown Artist',
            album: first.albumTitle ?? 'Unknown Album',
            duration: first.duration,
            matchReason: DuplicateMatchReason.metadataExact,
            reasonDescription:
                'Same title, artist, album, dan durasi yang dinormalisasi',
            candidates: candidates,
            recommendedKeepSongId: recommendedId,
          ),
        );

        for (final s in bucket) {
          processedSongIds.add(s.id);
        }
      }
    }

    // 3. Group remaining songs with same Title + Artist and matching Duration (duration > 0)
    final secondarySongs = songs
        .where((s) => !processedSongIds.contains(s.id))
        .toList();
    final strongBuckets = <String, List<SongModel>>{};

    for (final song in secondarySongs) {
      final normTitle = _normalize(song.title);
      final normArtist = _normalize(song.artistName ?? '');
      if (normTitle.isEmpty || normTitle == 'unknown title') continue;
      if (normArtist.isEmpty || normArtist == 'unknown artist') continue;
      if (song.duration <= 0) continue;

      final key = '$normTitle|$normArtist|${song.duration}';
      strongBuckets.putIfAbsent(key, () => []).add(song);
    }

    for (final entry in strongBuckets.entries) {
      final bucket = entry.value;
      if (bucket.length >= 2) {
        final candidates = bucket.map(DuplicateSongCandidate.fromSong).toList();
        candidates.sort(
          (a, b) => b.completenessScore.compareTo(a.completenessScore),
        );
        final recommendedId = candidates.first.song.id;

        final first = bucket.first;
        groups.add(
          DuplicateGroup(
            groupId: 'meta_strong_${first.id}',
            title: first.title,
            artist: first.artistName ?? 'Unknown Artist',
            album: first.albumTitle ?? 'Unknown Album',
            duration: first.duration,
            matchReason: DuplicateMatchReason.metadataStrong,
            reasonDescription: 'Same title, artist, dan durasi lagu',
            candidates: candidates,
            recommendedKeepSongId: recommendedId,
          ),
        );

        for (final s in bucket) {
          processedSongIds.add(s.id);
        }
      }
    }

    return groups;
  }

  /// Checks if a given song is currently active/playing in PlayerProvider.
  bool isSongActiveInPlayer(SongModel song, PlayerProvider? player) {
    if (player == null) return false;
    final curSong = player.currentSong;
    if (curSong == null) return false;
    if (curSong.id == song.id) return true;
    final pathA = (song.filePath ?? song.audioPath)
        .replaceAll('\\', '/')
        .toLowerCase();
    final pathB = (curSong.filePath ?? curSong.audioPath)
        .replaceAll('\\', '/')
        .toLowerCase();
    return pathA == pathB;
  }

  /// Safely deletes a duplicate candidate file and cleans up SQLite while preserving references on songToKeep.
  Future<void> deleteDuplicateCandidate({
    required SongModel songToDelete,
    required SongModel songToKeep,
    PlayerProvider? player,
  }) async {
    // 1. Playback safety check
    if (isSongActiveInPlayer(songToDelete, player)) {
      throw Exception(
        'Lagu "${songToDelete.title}" sedang diputar oleh player. Harap hentikan atau lewati pemutaran sebelum menghapus.',
      );
    }

    // 2. Remove from player queue if present
    if (player != null) {
      final queueIndex = player.queue.indexWhere(
        (s) => s.id == songToDelete.id,
      );
      if (queueIndex != -1) {
        player.removeFromQueue(queueIndex);
      }
    }

    // 3. Physical file deletion
    final targetPath = songToDelete.filePath ?? songToDelete.audioPath;
    final file = File(targetPath);
    if (file.existsSync()) {
      try {
        await file.delete();
        debugPrint('[DuplicateDetector] Physical file deleted: $targetPath');
      } catch (e) {
        debugPrint('[DuplicateDetector] Error deleting physical file: $e');
        throw Exception(
          'Gagal menghapus file fisik di "$targetPath". File mungkin berstatus Read-Only atau sedang dikunci oleh proses lain.',
        );
      }
    } else {
      debugPrint(
        '[DuplicateDetector] Physical file not found on disk, cleaning database entry: $targetPath',
      );
    }

    // 4. Preserve favorites on songToKeep
    try {
      final favorites = await _repository.getFavorites();
      final wasFavorite = favorites.any((f) => f.id == songToDelete.id);
      final isKeepFavorite = favorites.any((f) => f.id == songToKeep.id);
      if (wasFavorite && !isKeepFavorite) {
        await _repository.addFavorite(songToKeep.id);
      }
    } catch (e) {
      debugPrint('[DuplicateDetector] Warning during favorite remapping: $e');
    }

    // 5. Preserve playlist presence on songToKeep
    try {
      final playlists = await _repository.getPlaylists();
      for (final pl in playlists) {
        if (pl.id == null) continue;
        final containsDeleted = pl.songs.any((s) => s.id == songToDelete.id);
        final containsKeep = pl.songs.any((s) => s.id == songToKeep.id);
        if (containsDeleted && !containsKeep) {
          await _repository.addSongToPlaylist(pl.id!, songToKeep.id);
        }
      }
    } catch (e) {
      debugPrint('[DuplicateDetector] Warning during playlist remapping: $e');
    }

    // 6. Delete DB record
    await _repository.deleteSong(songToDelete.id);
    debugPrint(
      '[DuplicateDetector] Database record deleted for song ID ${songToDelete.id}',
    );
  }
}
