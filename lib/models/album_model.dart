class AlbumModel {
  final int id;
  final int artistId;
  final String title;
  final String? cover;
  final String? releaseDate;
  final int? releaseYear;
  final String? artistName;
  final String? spotifyId;
  final String? youtubeId;

  AlbumModel({
    required this.id,
    required this.artistId,
    required this.title,
    this.cover,
    this.releaseDate,
    this.releaseYear,
    this.artistName,
    this.spotifyId,
    this.youtubeId,
  });

  factory AlbumModel.fromJson(Map<String, dynamic> json) {
    return AlbumModel(
      id: int.parse(json['id'].toString()),
      artistId: json['artist_id'] != null
          ? int.parse(json['artist_id'].toString())
          : 0,
      title: json['title'] ?? '',
      cover: json['cover'],
      releaseDate: json['release_date']?.toString(),
      releaseYear: json['release_year'] != null
          ? int.tryParse(json['release_year'].toString())
          : null,
      artistName: json['artist_name'],
      spotifyId: json['spotify_id'],
      youtubeId: json['youtube_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'artist_id': artistId,
      'title': title,
      'cover': cover,
      'release_date': releaseDate,
      'release_year': releaseYear,
      'artist_name': artistName,
      'spotify_id': spotifyId,
      'youtube_id': youtubeId,
    };
  }

  AlbumModel copyWith({
    int? id,
    int? artistId,
    String? title,
    String? cover,
    String? releaseDate,
    int? releaseYear,
    String? artistName,
    String? spotifyId,
    String? youtubeId,
  }) {
    return AlbumModel(
      id: id ?? this.id,
      artistId: artistId ?? this.artistId,
      title: title ?? this.title,
      cover: cover ?? this.cover,
      releaseDate: releaseDate ?? this.releaseDate,
      releaseYear: releaseYear ?? this.releaseYear,
      artistName: artistName ?? this.artistName,
      spotifyId: spotifyId ?? this.spotifyId,
      youtubeId: youtubeId ?? this.youtubeId,
    );
  }
}
