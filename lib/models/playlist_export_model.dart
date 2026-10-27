import 'dart:convert';
import '../models/song_model.dart';
import '../models/playlist_model.dart';

class PlaylistExportPackage {
  final String format;
  final int version;
  final String name;
  final String? description;
  final String createdAt;
  final List<Map<String, dynamic>> songs;

  PlaylistExportPackage({
    this.format = 'mymusic-playlist',
    this.version = 1,
    required this.name,
    this.description,
    required this.createdAt,
    required this.songs,
  });

  factory PlaylistExportPackage.fromPlaylist(PlaylistModel playlist) {
    final songsList = playlist.songs
        .map(
          (s) => {
            'title': s.title,
            'artist_name': s.artistName ?? 'Unknown Artist',
            'album_title': s.albumTitle ?? 'Unknown Album',
            'genre_name': s.genreName ?? '',
            'duration': s.duration,
            'audio_path': s.audioPath,
            'file_path': s.filePath ?? s.audioPath,
            'track_hash': s.trackHash,
          },
        )
        .toList();

    return PlaylistExportPackage(
      name: playlist.name,
      description: playlist.description,
      createdAt: DateTime.now().toIso8601String(),
      songs: songsList,
    );
  }

  factory PlaylistExportPackage.fromJson(Map<String, dynamic> json) {
    final plJson = json['playlist'] is Map<String, dynamic>
        ? json['playlist'] as Map<String, dynamic>
        : json;
    final songsList =
        (plJson['songs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return PlaylistExportPackage(
      format: json['format'] as String? ?? 'mymusic-playlist',
      version: json['version'] as int? ?? 1,
      name:
          plJson['name'] as String? ??
          plJson['title'] as String? ??
          'Imported Playlist',
      description: plJson['description'] as String?,
      createdAt:
          plJson['created_at'] as String? ?? DateTime.now().toIso8601String(),
      songs: songsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'format': format,
      'version': version,
      'playlist': {
        'name': name,
        'description': description,
        'created_at': createdAt,
        'songs': songs,
      },
    };
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Exports playlist to standard M3U / M3U8 string format
  String toM3uString() {
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#PLAYLIST:$name');
    for (final song in songs) {
      final duration = song['duration'] ?? 0;
      final artist = song['artist_name'] ?? 'Unknown Artist';
      final title = song['title'] ?? 'Unknown Track';
      final path = song['file_path'] ?? song['audio_path'] ?? '';
      buffer.writeln('#EXTINF:$duration,$artist - $title');
      buffer.writeln(path);
    }
    return buffer.toString();
  }
}

class PlaylistImportResult {
  final String playlistName;
  final String? description;
  final int totalTracks;
  final int matchedCount;
  final int missingCount;
  final List<SongModel> matchedSongs;

  PlaylistImportResult({
    required this.playlistName,
    this.description,
    required this.totalTracks,
    required this.matchedCount,
    required this.missingCount,
    required this.matchedSongs,
  });
}
