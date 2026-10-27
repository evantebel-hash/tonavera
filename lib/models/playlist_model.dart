import 'song_model.dart';
import 'smart_playlist_model.dart';

class PlaylistModel {
  final int? id;
  final int? userId;
  final String name;
  final String? description;
  final String? cover;
  final String visibility;
  final String? ownerName;
  final String playlistType; // 'normal' or 'smart'
  final SmartPlaylistConfig? smartConfig;
  final List<SongModel> songs;

  PlaylistModel({
    this.id,
    this.userId,
    required this.name,
    this.description,
    this.cover,
    this.visibility = 'private',
    this.ownerName,
    this.playlistType = 'normal',
    this.smartConfig,
    this.songs = const [],
  });

  bool get isSmart => playlistType == 'smart';

  factory PlaylistModel.fromJson(
    Map<String, dynamic> json, {
    List<SongModel> songs = const [],
  }) {
    final type = json['playlist_type']?.toString() ?? 'normal';
    SmartPlaylistConfig? cfg;
    if (json['smart_config'] != null &&
        json['smart_config'].toString().isNotEmpty) {
      cfg = SmartPlaylistConfig.fromJsonString(json['smart_config'].toString());
    }

    return PlaylistModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      userId: json['user_id'] != null
          ? int.tryParse(json['user_id'].toString())
          : null,
      name: json['name'] ?? '',
      description: json['description'],
      cover: json['cover'],
      visibility: json['visibility'] ?? 'private',
      ownerName: json['owner_name'],
      playlistType: type,
      smartConfig: cfg,
      songs: songs,
    );
  }

  PlaylistModel copyWith({
    int? id,
    int? userId,
    String? name,
    String? description,
    String? cover,
    String? visibility,
    String? ownerName,
    String? playlistType,
    SmartPlaylistConfig? smartConfig,
    List<SongModel>? songs,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      cover: cover ?? this.cover,
      visibility: visibility ?? this.visibility,
      ownerName: ownerName ?? this.ownerName,
      playlistType: playlistType ?? this.playlistType,
      smartConfig: smartConfig ?? this.smartConfig,
      songs: songs ?? this.songs,
    );
  }
}
