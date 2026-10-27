import 'song_model.dart';

class YouTubeVideo {
  final int? id;
  final String videoId;
  final String title;
  final String? channelId;
  final String? channelName;
  final String? albumName;
  final String? thumbnailUrl;
  final int durationSeconds;
  final String? publishedAt;
  final String? description;
  final String sourceUrl;
  final int viewCount;
  final DateTime fetchedAt;
  final DateTime? updatedAt;

  YouTubeVideo({
    this.id,
    required this.videoId,
    required this.title,
    this.channelId,
    this.channelName,
    this.albumName,
    this.thumbnailUrl,
    this.durationSeconds = 0,
    this.publishedAt,
    this.description,
    String? sourceUrl,
    this.viewCount = 0,
    DateTime? fetchedAt,
    this.updatedAt,
  }) : sourceUrl = sourceUrl ?? 'https://www.youtube.com/watch?v=$videoId',
       fetchedAt = fetchedAt ?? DateTime.now();

  factory YouTubeVideo.fromMap(Map<String, dynamic> map) {
    final vId = map['video_id']?.toString() ?? map['videoId']?.toString() ?? '';
    return YouTubeVideo(
      id: map['id'] as int?,
      videoId: vId,
      title: map['title']?.toString() ?? 'Untitled Video',
      channelId: map['channel_id']?.toString() ?? map['channelId']?.toString(),
      channelName:
          map['channel_name']?.toString() ??
          map['channelName']?.toString() ??
          'YouTube Channel',
      thumbnailUrl:
          map['thumbnail_url']?.toString() ?? map['thumbnailUrl']?.toString(),
      durationSeconds:
          map['duration_seconds'] as int? ?? map['duration'] as int? ?? 0,
      publishedAt:
          map['published_at']?.toString() ?? map['publishedAt']?.toString(),
      description: map['description']?.toString(),
      sourceUrl:
          map['source_url']?.toString() ??
          'https://www.youtube.com/watch?v=$vId',
      viewCount: map['view_count'] as int? ?? map['viewCount'] as int? ?? 0,
      fetchedAt: map['fetched_at'] != null
          ? DateTime.tryParse(map['fetched_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'video_id': videoId,
      'title': title,
      'channel_id': channelId,
      'channel_name': channelName,
      'thumbnail_url': thumbnailUrl,
      'duration_seconds': durationSeconds,
      'published_at': publishedAt,
      'description': description,
      'source_url': sourceUrl,
      'view_count': viewCount,
      'fetched_at': fetchedAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class YouTubePlaylist {
  final int? id;
  final String playlistId;
  final String title;
  final String? channelId;
  final String? channelName;
  final String? thumbnailUrl;
  final String? description;
  final int itemCount;
  final String sourceUrl;
  final DateTime fetchedAt;
  final DateTime? updatedAt;
  final List<YouTubePlaylistItem> items;

  YouTubePlaylist({
    this.id,
    required this.playlistId,
    required this.title,
    this.channelId,
    this.channelName,
    this.thumbnailUrl,
    this.description,
    this.itemCount = 0,
    String? sourceUrl,
    DateTime? fetchedAt,
    this.updatedAt,
    this.items = const [],
  }) : sourceUrl =
           sourceUrl ?? 'https://www.youtube.com/playlist?list=$playlistId',
       fetchedAt = fetchedAt ?? DateTime.now();

  factory YouTubePlaylist.fromMap(
    Map<String, dynamic> map, {
    List<YouTubePlaylistItem> items = const [],
  }) {
    final pId =
        map['playlist_id']?.toString() ?? map['playlistId']?.toString() ?? '';
    return YouTubePlaylist(
      id: map['id'] as int?,
      playlistId: pId,
      title: map['title']?.toString() ?? 'YouTube Playlist',
      channelId: map['channel_id']?.toString() ?? map['channelId']?.toString(),
      channelName:
          map['channel_name']?.toString() ??
          map['channelName']?.toString() ??
          'YouTube',
      thumbnailUrl:
          map['thumbnail_url']?.toString() ?? map['thumbnailUrl']?.toString(),
      description: map['description']?.toString(),
      itemCount: map['item_count'] as int? ?? items.length,
      sourceUrl:
          map['source_url']?.toString() ??
          'https://www.youtube.com/playlist?list=$pId',
      fetchedAt: map['fetched_at'] != null
          ? DateTime.tryParse(map['fetched_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'playlist_id': playlistId,
      'title': title,
      'channel_id': channelId,
      'channel_name': channelName,
      'thumbnail_url': thumbnailUrl,
      'description': description,
      'item_count': itemCount,
      'source_url': sourceUrl,
      'fetched_at': fetchedAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class YouTubePlaylistItem {
  final int? id;
  final String playlistId;
  final String videoId;
  final int position;
  final String title;
  final String? channelName;
  final String? thumbnailUrl;
  final int durationSeconds;
  final bool unavailable;
  final DateTime fetchedAt;

  YouTubePlaylistItem({
    this.id,
    required this.playlistId,
    required this.videoId,
    required this.position,
    required this.title,
    this.channelName,
    this.thumbnailUrl,
    this.durationSeconds = 0,
    this.unavailable = false,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  factory YouTubePlaylistItem.fromMap(Map<String, dynamic> map) {
    return YouTubePlaylistItem(
      id: map['id'] as int?,
      playlistId: map['playlist_id']?.toString() ?? '',
      videoId: map['video_id']?.toString() ?? '',
      position: map['position_order'] as int? ?? map['position'] as int? ?? 0,
      title: map['title']?.toString() ?? 'Track',
      channelName: map['channel_name']?.toString(),
      thumbnailUrl: map['thumbnail_url']?.toString(),
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      unavailable: map['unavailable'] == 1 || map['unavailable'] == true,
      fetchedAt: map['fetched_at'] != null
          ? DateTime.tryParse(map['fetched_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'playlist_id': playlistId,
      'video_id': videoId,
      'position_order': position,
      'title': title,
      'channel_name': channelName,
      'thumbnail_url': thumbnailUrl,
      'duration_seconds': durationSeconds,
      'unavailable': unavailable ? 1 : 0,
      'fetched_at': fetchedAt.toIso8601String(),
    };
  }
}

enum HybridSourceType { local, youtube }

class HybridPlaylistItem {
  final int? id;
  final int playlistId;
  final HybridSourceType sourceType;
  final int? songId;
  final String? youtubeVideoId;
  final int position;
  final SongModel? localSong;
  final YouTubeVideo? youtubeVideo;

  HybridPlaylistItem({
    this.id,
    required this.playlistId,
    required this.sourceType,
    this.songId,
    this.youtubeVideoId,
    required this.position,
    this.localSong,
    this.youtubeVideo,
  });

  bool get isLocal => sourceType == HybridSourceType.local;
  bool get isYouTube => sourceType == HybridSourceType.youtube;

  String get displayTitle => isLocal
      ? (localSong?.title ?? 'Unknown Local Track')
      : (youtubeVideo?.title ?? 'Unknown YouTube Track');
  String get displaySubtitle => isLocal
      ? (localSong?.artistName ?? 'Local Artist')
      : (youtubeVideo?.channelName ?? 'YouTube Channel');
  String? get displayThumbnail =>
      isLocal ? localSong?.cover : youtubeVideo?.thumbnailUrl;
}
