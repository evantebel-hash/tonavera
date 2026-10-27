import 'dart:convert';

import '../models/playlist_export_model.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../repositories/local_music_repository.dart';

class PlaylistExportImportService {
  static final PlaylistExportImportService instance =
      PlaylistExportImportService._internal();
  final LocalMusicRepository _repository;

  PlaylistExportImportService({LocalMusicRepository? repository})
    : _repository = repository ?? LocalMusicRepository();

  PlaylistExportImportService._internal()
    : _repository = LocalMusicRepository();

  /// Exports a playlist to MyMusic JSON format string
  String exportToJson(PlaylistModel playlist) {
    final pkg = PlaylistExportPackage.fromPlaylist(playlist);
    return pkg.toJsonString();
  }

  /// Exports a playlist to standard M3U format string
  String exportToM3u(PlaylistModel playlist) {
    final pkg = PlaylistExportPackage.fromPlaylist(playlist);
    return pkg.toM3uString();
  }

  /// Parses and matches a playlist import file (JSON or M3U) against local library songs
  Future<PlaylistImportResult> parseAndMatchImport(
    String content, {
    String? filename,
  }) async {
    final allSongs = await _repository.getAllSongs();
    return parsePlaylistContent(
      content,
      filename ?? 'imported_playlist',
      allSongs,
    );
  }

  /// Parses playlist content string against provided local songs list
  PlaylistImportResult parsePlaylistContent(
    String content,
    String filename,
    List<SongModel> localSongs,
  ) {
    final isM3u =
        filename.endsWith('.m3u') ||
        filename.endsWith('.m3u8') ||
        content.trim().startsWith('#EXTM3U');

    if (isM3u) {
      return _parseM3u(content, localSongs);
    } else {
      return _parseJson(content, localSongs);
    }
  }

  PlaylistImportResult _parseJson(String content, List<SongModel> localSongs) {
    final Map<String, dynamic> decoded = json.decode(content);
    final pkg = PlaylistExportPackage.fromJson(decoded);

    final matched = <SongModel>[];
    int missingCount = 0;

    for (final songMap in pkg.songs) {
      final match = _findBestMatch(songMap, localSongs);
      if (match != null) {
        if (!matched.any((s) => s.id == match.id)) {
          matched.add(match);
        }
      } else {
        missingCount++;
      }
    }

    return PlaylistImportResult(
      playlistName: pkg.name,
      description: pkg.description,
      totalTracks: pkg.songs.length,
      matchedCount: matched.length,
      missingCount: missingCount,
      matchedSongs: matched,
    );
  }

  PlaylistImportResult _parseM3u(String content, List<SongModel> localSongs) {
    final lines = LineSplitter.split(content).map((l) => l.trim()).toList();
    String playlistName = 'Imported M3U Playlist';
    final matched = <SongModel>[];
    int totalCount = 0;
    int missingCount = 0;

    String currentArtist = '';
    String currentTitle = '';

    for (final line in lines) {
      if (line.isEmpty) continue;

      if (line.startsWith('#PLAYLIST:')) {
        playlistName = line.substring(10).trim();
      } else if (line.startsWith('#EXTINF:')) {
        final commaIdx = line.indexOf(',');
        if (commaIdx != -1) {
          final info = line.substring(commaIdx + 1).trim();
          final parts = info.split(' - ');
          if (parts.length >= 2) {
            currentArtist = parts[0].trim();
            currentTitle = parts.sublist(1).join(' - ').trim();
          } else {
            currentTitle = info;
          }
        }
      } else if (!line.startsWith('#')) {
        // File path line
        totalCount++;
        final path = line;
        final songMap = {
          'title': currentTitle,
          'artist_name': currentArtist,
          'audio_path': path,
          'file_path': path,
        };

        final match = _findBestMatch(songMap, localSongs);
        if (match != null) {
          if (!matched.any((s) => s.id == match.id)) {
            matched.add(match);
          }
        } else {
          missingCount++;
        }

        currentArtist = '';
        currentTitle = '';
      }
    }

    return PlaylistImportResult(
      playlistName: playlistName,
      totalTracks: totalCount,
      matchedCount: matched.length,
      missingCount: missingCount,
      matchedSongs: matched,
    );
  }

  /// 4-tier robust song matching strategy:
  /// 1. Stable trackHash match
  /// 2. Exact audioPath / filePath match
  /// 3. Normalized Title + Artist match
  /// 4. Title exact match
  SongModel? _findBestMatch(
    Map<String, dynamic> target,
    List<SongModel> localSongs,
  ) {
    final targetHash = target['track_hash']?.toString();
    final targetPath = (target['file_path'] ?? target['audio_path'] ?? '')
        .toString()
        .toLowerCase();
    final targetTitle = (target['title'] ?? '').toString().trim().toLowerCase();
    final targetArtist = (target['artist_name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    // 1. Check hash
    if (targetHash != null && targetHash.isNotEmpty) {
      for (final s in localSongs) {
        if (s.trackHash == targetHash) return s;
      }
    }

    // 2. Check path
    if (targetPath.isNotEmpty) {
      for (final s in localSongs) {
        if (s.audioPath.toLowerCase() == targetPath ||
            (s.filePath != null && s.filePath!.toLowerCase() == targetPath)) {
          return s;
        }
      }
    }

    // 3. Check Title + Artist
    if (targetTitle.isNotEmpty && targetArtist.isNotEmpty) {
      for (final s in localSongs) {
        final sTitle = s.title.trim().toLowerCase();
        final sArtist = (s.artistName ?? '').trim().toLowerCase();
        if (sTitle == targetTitle && sArtist == targetArtist) return s;
      }
    }

    // 4. Check Title exact match
    if (targetTitle.isNotEmpty) {
      for (final s in localSongs) {
        if (s.title.trim().toLowerCase() == targetTitle) return s;
      }
    }

    return null;
  }

  /// Saves the imported playlist into the local SQLite database
  Future<int> commitImport(PlaylistImportResult importResult) async {
    final playlistId = await _repository.createPlaylist(
      importResult.playlistName,
      description:
          importResult.description ?? 'Imported on ${DateTime.now().toLocal()}',
    );

    final songIds = importResult.matchedSongs.map((s) => s.id).toList();
    if (songIds.isNotEmpty) {
      await _repository.addSongsToPlaylist(playlistId, songIds);
    }

    return playlistId;
  }
}
