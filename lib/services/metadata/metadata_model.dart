import '../../models/song_model.dart';
import 'spotify_url_parser.dart';

class ArtistMetadataInfo {
  final String name;
  final String?
  id; // provider artist id (e.g. Spotify artist ID or YouTube channel ID)
  final String? provider;
  final String? artworkUrl;

  const ArtistMetadataInfo({
    required this.name,
    this.id,
    this.provider,
    this.artworkUrl,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'provider': provider,
    'artworkUrl': artworkUrl,
  };

  factory ArtistMetadataInfo.fromJson(Map<String, dynamic> json) =>
      ArtistMetadataInfo(
        name: json['name'] as String? ?? '',
        id: json['id'] as String?,
        provider: json['provider'] as String?,
        artworkUrl: json['artworkUrl'] as String?,
      );

  @override
  String toString() =>
      'ArtistMetadataInfo(name: $name, id: $id, provider: $provider)';
}

class MusicMetadataResult {
  final String? provider; // 'spotify' | 'youtube' | 'local'
  final String?
  sourceId; // e.g. spotify track/album ID or youtube video/playlist ID
  final String? sourceUrl;
  final String? spotifyId;
  final String title;
  final String? artist;
  final List<String> artists;
  final List<ArtistMetadataInfo> artistList;
  final String? album;
  final String? albumArtist;
  final int? duration; // In seconds
  final String? releaseDate;

  /// Entity-specific artwork URLs
  final String? artistArtworkUrl; // Artist profile photo
  final String? albumArtworkUrl; // Album or single cover
  final String? trackArtworkUrl; // Specific track artwork if distinct

  /// Legacy / unified artwork accessor for backwards compatibility
  final String? artworkUrl;

  final String? spotifyUrl;
  final String? isrc;
  final String? genre;
  final bool? explicit;
  final int? popularity;
  final String? audioPreviewUrl;
  final SpotifyEntityType type;
  final List<MusicMetadataResult> trackList;

  const MusicMetadataResult({
    this.provider,
    this.sourceId,
    this.sourceUrl,
    this.spotifyId,
    required this.title,
    this.artist,
    this.artists = const [],
    this.artistList = const [],
    this.album,
    this.albumArtist,
    this.duration,
    this.releaseDate,
    this.artistArtworkUrl,
    this.albumArtworkUrl,
    this.trackArtworkUrl,
    this.artworkUrl,
    this.spotifyUrl,
    this.isrc,
    this.genre,
    this.explicit,
    this.popularity,
    this.audioPreviewUrl,
    this.type = SpotifyEntityType.track,
    this.trackList = const [],
  });

  String get effectiveProvider =>
      provider ?? (spotifyId != null ? 'spotify' : 'unknown');
  String get effectiveSourceId => sourceId ?? spotifyId ?? '';
  String? get effectiveSourceUrl => sourceUrl ?? spotifyUrl;

  /// Resolved track artwork following strict priority:
  /// 1. Specific track artwork
  /// 2. Album / single artwork
  /// (Never artist profile artwork)
  String? get effectiveTrackArtworkUrl {
    final trk = trackArtworkUrl?.trim();
    if (trk != null && trk.isNotEmpty) return trk;
    final alb = albumArtworkUrl?.trim();
    if (alb != null && alb.isNotEmpty) return alb;
    // Fallback to generic artworkUrl ONLY IF it was not explicitly marked as an artist entity
    if (type != SpotifyEntityType.artist) {
      final art = artworkUrl?.trim();
      if (art != null && art.isNotEmpty) return art;
    }
    return null;
  }

  /// Resolved album artwork: only album cover or non-artist artworkUrl
  String? get effectiveAlbumArtworkUrl {
    final alb = albumArtworkUrl?.trim();
    if (alb != null && alb.isNotEmpty) return alb;
    if (type == SpotifyEntityType.album) {
      final art = artworkUrl?.trim();
      if (art != null && art.isNotEmpty) return art;
    }
    return null;
  }

  /// Resolved artist artwork: only artist profile image
  String? get effectiveArtistArtworkUrl {
    final artImg = artistArtworkUrl?.trim();
    if (artImg != null && artImg.isNotEmpty) return artImg;
    if (type == SpotifyEntityType.artist) {
      final art = artworkUrl?.trim();
      if (art != null && art.isNotEmpty) return art;
    }
    return null;
  }

  /// Formats all artists into a single comma-separated string if primary artist is not set.
  String get displayArtist {
    if (artist != null && artist!.trim().isNotEmpty) {
      return artist!.trim();
    }
    if (artists.isNotEmpty) {
      return artists.join(', ');
    }
    if (artistList.isNotEmpty) {
      return artistList
          .map((a) => a.name)
          .where((n) => n.trim().isNotEmpty)
          .join(', ');
    }
    return '';
  }

  /// Returns release year if releaseDate contains a valid 4-digit year.
  int? get releaseYear {
    if (releaseDate == null) return null;
    final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(releaseDate!);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Merges this metadata with an existing [SongModel].
  /// By default ([overwriteExisting] = false), existing non-empty values in [SongModel]
  /// are strictly preserved. Only missing or empty values are filled in.
  SongModel mergeIntoSong(
    SongModel existingSong, {
    bool overwriteExisting = false,
  }) {
    if (!overwriteExisting) {
      final hasTitle =
          existingSong.title.trim().isNotEmpty &&
          existingSong.title.toLowerCase() != 'unknown title';
      final hasArtist =
          existingSong.artistName != null &&
          existingSong.artistName!.trim().isNotEmpty &&
          existingSong.artistName!.toLowerCase() != 'unknown artist';
      final hasAlbum =
          existingSong.albumTitle != null &&
          existingSong.albumTitle!.trim().isNotEmpty &&
          existingSong.albumTitle!.toLowerCase() != 'unknown album';
      final hasCover =
          existingSong.cover != null && existingSong.cover!.trim().isNotEmpty;
      final hasGenre =
          existingSong.genreName != null &&
          existingSong.genreName!.trim().isNotEmpty;

      final resolvedTrackCover =
          effectiveTrackArtworkUrl ??
          (artworkUrl?.isNotEmpty == true ? artworkUrl : null);
      return existingSong.copyWith(
        title: hasTitle
            ? existingSong.title
            : (title.isNotEmpty ? title : existingSong.title),
        artistName: hasArtist
            ? existingSong.artistName
            : (displayArtist.isNotEmpty
                  ? displayArtist
                  : existingSong.artistName),
        albumTitle: hasAlbum
            ? existingSong.albumTitle
            : (album?.isNotEmpty == true ? album : existingSong.albumTitle),
        genreName: hasGenre
            ? existingSong.genreName
            : (genre?.isNotEmpty == true ? genre : existingSong.genreName),
        cover: hasCover
            ? existingSong.cover
            : (resolvedTrackCover ?? existingSong.cover),
      );
    } else {
      final resolvedTrackCover =
          effectiveTrackArtworkUrl ??
          (artworkUrl?.isNotEmpty == true ? artworkUrl : null);
      return existingSong.copyWith(
        title: title.isNotEmpty ? title : existingSong.title,
        artistName: displayArtist.isNotEmpty
            ? displayArtist
            : existingSong.artistName,
        albumTitle: (album != null && album!.isNotEmpty)
            ? album
            : existingSong.albumTitle,
        genreName: (genre != null && genre!.isNotEmpty)
            ? genre
            : existingSong.genreName,
        cover: (resolvedTrackCover != null && resolvedTrackCover.isNotEmpty)
            ? resolvedTrackCover
            : existingSong.cover,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'sourceId': sourceId,
      'sourceUrl': sourceUrl,
      'spotifyId': spotifyId,
      'title': title,
      'artist': artist,
      'artists': artists,
      'artistList': artistList.map((a) => a.toJson()).toList(),
      'album': album,
      'albumArtist': albumArtist,
      'duration': duration,
      'releaseDate': releaseDate,
      'artistArtworkUrl': artistArtworkUrl,
      'albumArtworkUrl': albumArtworkUrl,
      'trackArtworkUrl': trackArtworkUrl,
      'artworkUrl': artworkUrl,
      'spotifyUrl': spotifyUrl,
      'isrc': isrc,
      'genre': genre,
      'explicit': explicit,
      'popularity': popularity,
      'audioPreviewUrl': audioPreviewUrl,
      'type': type.name,
      'trackList': trackList.map((t) => t.toJson()).toList(),
    };
  }

  /// Returns canonical lowercase entity type string (e.g. 'track', 'album', 'artist', 'playlist').
  String get typeString => type.name;

  factory MusicMetadataResult.fromJson(Map<String, dynamic> json) {
    return MusicMetadataResult(
      provider: json['provider'] as String?,
      sourceId: json['sourceId'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      spotifyId: json['spotifyId'] as String?,
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      artists:
          (json['artists'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      artistList:
          (json['artistList'] as List<dynamic>?)
              ?.map(
                (e) => ArtistMetadataInfo.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      album: json['album'] as String?,
      albumArtist: json['albumArtist'] as String?,
      duration: json['duration'] as int?,
      releaseDate: json['releaseDate'] as String?,
      artistArtworkUrl: json['artistArtworkUrl'] as String?,
      albumArtworkUrl: json['albumArtworkUrl'] as String?,
      trackArtworkUrl: json['trackArtworkUrl'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      spotifyUrl: json['spotifyUrl'] as String?,
      isrc: json['isrc'] as String?,
      genre: json['genre'] as String?,
      explicit: json['explicit'] as bool?,
      popularity: json['popularity'] as int?,
      audioPreviewUrl: json['audioPreviewUrl'] as String?,
      type: SpotifyEntityType.fromString(json['type']?.toString()),
      trackList:
          (json['trackList'] as List<dynamic>?)
              ?.map(
                (e) => MusicMetadataResult.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }

  @override
  String toString() {
    return 'MusicMetadataResult(title: $title, artist: $artist, album: $album, spotifyId: $spotifyId, type: $type)';
  }
}
