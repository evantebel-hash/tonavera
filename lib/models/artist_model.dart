class ArtistModel {
  final int id;
  final String name;
  final String? image;
  final String? bio;
  final String? spotifyId;
  final String? youtubeId;

  ArtistModel({
    required this.id,
    required this.name,
    this.image,
    this.bio,
    this.spotifyId,
    this.youtubeId,
  });

  factory ArtistModel.fromJson(Map<String, dynamic> json) {
    return ArtistModel(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      image: json['image'],
      bio: json['bio'],
      spotifyId: json['spotify_id'],
      youtubeId: json['youtube_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'bio': bio,
      'spotify_id': spotifyId,
      'youtube_id': youtubeId,
    };
  }

  ArtistModel copyWith({
    int? id,
    String? name,
    String? image,
    String? bio,
    String? spotifyId,
    String? youtubeId,
  }) {
    return ArtistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      image: image ?? this.image,
      bio: bio ?? this.bio,
      spotifyId: spotifyId ?? this.spotifyId,
      youtubeId: youtubeId ?? this.youtubeId,
    );
  }
}
