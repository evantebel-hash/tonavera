import '../core/config/api_config.dart';
import 'youtube_model.dart';

class SongModel {
  final int id;
  final int artistId;
  final int? albumId;
  final int? genreId;
  final String title;
  final int duration; // in seconds
  final String audioPath;
  final String? filePath;
  final String? cover;
  final String? lyrics;
  final String? artistName;
  final String? albumTitle;
  final String? genreName;
  final String source;
  final String? provider;
  final String? sourceId;
  final String? metadataSource;
  final DateTime? importedAt;
  final bool isFavorite;
  final DateTime? playedAt;

  SongModel({
    required this.id,
    required this.artistId,
    this.albumId,
    this.genreId,
    required this.title,
    required this.duration,
    required this.audioPath,
    this.filePath,
    this.cover,
    this.lyrics,
    this.artistName,
    this.albumTitle,
    this.genreName,
    this.source = 'catalog',
    this.provider,
    this.sourceId,
    this.metadataSource,
    this.importedAt,
    this.isFavorite = false,
    this.playedAt,
  });

  String get trackHash {
    final normTitle = _normalizeString(title);
    final normArtist = _normalizeString(artistName ?? '');
    final normAlbum = _normalizeString(albumTitle ?? '');
    return '$normTitle|$normArtist|$normAlbum|$duration';
  }

  static String _normalizeString(String str) {
    return str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool get isYouTube => source == 'youtube';
  bool get isSpotify => source == 'spotify';
  bool get isOnline => isYouTube || isSpotify;
  bool get isLocal => !isOnline && (source == 'local' || filePath != null);

  factory SongModel.fromYouTubeVideo(
    YouTubeVideo video, {
    String? localCoverPath,
  }) {
    final numericId = video.id ?? (video.videoId.hashCode.abs());
    return SongModel(
      id: numericId,
      artistId: 0,
      title: video.title,
      duration: video.durationSeconds,
      audioPath: video.videoId,
      cover: localCoverPath ?? video.thumbnailUrl,
      artistName: video.channelName ?? 'YouTube',
      albumTitle: video.albumName ?? 'YouTube Music',
      source: 'youtube',
    );
  }

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: int.parse(json['id'].toString()),
      artistId: json['artist_id'] != null
          ? int.parse(json['artist_id'].toString())
          : 0,
      albumId: json['album_id'] != null
          ? int.parse(json['album_id'].toString())
          : null,
      genreId: json['genre_id'] != null
          ? int.parse(json['genre_id'].toString())
          : null,
      title: json['title'] ?? '',
      duration: int.parse((json['duration'] ?? 0).toString()),
      audioPath: json['audio_path'] ?? '',
      filePath: json['file_path'],
      cover: _parseCoverUrl(json['cover']),
      lyrics: json['lyrics'],
      artistName: json['artist_name'],
      albumTitle: json['album_title'],
      genreName: json['genre_name'],
      source:
          json['source'] ?? (json['file_path'] != null ? 'local' : 'catalog'),
      provider: json['provider'],
      sourceId: json['source_id'],
      metadataSource: json['metadata_source'],
      importedAt: json['imported_at'] != null
          ? DateTime.tryParse(json['imported_at'].toString())
          : null,
      isFavorite:
          json['is_favorite'] == true ||
          json['is_favorite'] == 1 ||
          json['favorited_at'] != null,
      playedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
    );
  }

  static String? _parseCoverUrl(dynamic coverData) {
    if (coverData == null || coverData.toString().isEmpty) return null;
    final coverStr = coverData.toString();
    if (coverStr.startsWith('http://') || coverStr.startsWith('https://')) {
      return coverStr;
    }

    // Check if it's a local file path
    if (coverStr.startsWith('file://') ||
        coverStr.contains('mymusic_artwork_cache') ||
        RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(coverStr) ||
        coverStr.startsWith('/')) {
      return coverStr;
    }

    // Check if the cover path already includes 'uploads/'
    if (coverStr.contains('uploads/')) {
      return '${ApiConfig.baseUrl.replaceAll('/api', '')}/$coverStr';
    }

    // Otherwise, assume it's in public/uploads/covers/
    return '${ApiConfig.baseUrl.replaceAll('/api', '')}/uploads/covers/$coverStr';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'artist_id': artistId,
      'album_id': albumId,
      'genre_id': genreId,
      'title': title,
      'duration': duration,
      'audio_path': audioPath,
      'file_path': filePath,
      'cover': cover,
      'lyrics': lyrics,
      'artist_name': artistName,
      'album_title': albumTitle,
      'genre_name': genreName,
      'source': source,
      'provider': provider,
      'source_id': sourceId,
      'metadata_source': metadataSource,
      'imported_at': importedAt?.toIso8601String(),
      'is_favorite': isFavorite,
      'started_at': playedAt?.toIso8601String(),
    };
  }

  SongModel copyWith({
    int? id,
    int? artistId,
    int? albumId,
    int? genreId,
    String? title,
    int? duration,
    String? audioPath,
    String? filePath,
    String? cover,
    String? lyrics,
    String? artistName,
    String? albumTitle,
    String? genreName,
    String? source,
    String? provider,
    String? sourceId,
    String? metadataSource,
    DateTime? importedAt,
    bool? isFavorite,
    DateTime? playedAt,
  }) {
    return SongModel(
      id: id ?? this.id,
      artistId: artistId ?? this.artistId,
      albumId: albumId ?? this.albumId,
      genreId: genreId ?? this.genreId,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      audioPath: audioPath ?? this.audioPath,
      filePath: filePath ?? this.filePath,
      cover: cover ?? this.cover,
      lyrics: lyrics ?? this.lyrics,
      artistName: artistName ?? this.artistName,
      albumTitle: albumTitle ?? this.albumTitle,
      genreName: genreName ?? this.genreName,
      source: source ?? this.source,
      provider: provider ?? this.provider,
      sourceId: sourceId ?? this.sourceId,
      metadataSource: metadataSource ?? this.metadataSource,
      importedAt: importedAt ?? this.importedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      playedAt: playedAt ?? this.playedAt,
    );
  }
}
