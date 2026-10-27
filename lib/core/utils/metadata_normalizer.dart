import 'package:audiotags/audiotags.dart';

class NormalizedSongMetadata {
  final String title;
  final String artist;
  final String normalizedArtist;
  final String album;
  final String normalizedAlbum;
  final String albumArtist;
  final String genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final String? composer;
  final String? comment;
  final String? lyrics;
  final int duration;
  final List<Picture> pictures;

  NormalizedSongMetadata({
    required this.title,
    required this.artist,
    required this.normalizedArtist,
    required this.album,
    required this.normalizedAlbum,
    required this.albumArtist,
    required this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.composer,
    this.comment,
    this.lyrics,
    required this.duration,
    required this.pictures,
  });

  static String normalizeIdentity(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  factory NormalizedSongMetadata.fromTag(
    Tag? tag, {
    required String fallbackTitle,
  }) {
    if (tag == null) {
      final cleanTitle = fallbackTitle.trim().isNotEmpty
          ? fallbackTitle.trim()
          : 'Unknown Title';
      return NormalizedSongMetadata(
        title: cleanTitle,
        artist: 'Unknown Artist',
        normalizedArtist: normalizeIdentity('Unknown Artist'),
        album: 'Unknown Album',
        normalizedAlbum: normalizeIdentity('Unknown Album'),
        albumArtist: '',
        genre: '',
        duration: 0,
        pictures: const [],
      );
    }

    final rawTitle = tag.title?.trim() ?? '';
    final title = rawTitle.isNotEmpty
        ? rawTitle
        : (fallbackTitle.trim().isNotEmpty
              ? fallbackTitle.trim()
              : 'Unknown Title');

    final rawTrackArtist = tag.trackArtist?.trim() ?? '';
    final rawAlbumArtist = tag.albumArtist?.trim() ?? '';

    String artist = 'Unknown Artist';
    if (rawTrackArtist.isNotEmpty) {
      artist = rawTrackArtist;
    } else if (rawAlbumArtist.isNotEmpty) {
      artist = rawAlbumArtist;
    }

    final album = (tag.album?.trim().isNotEmpty == true)
        ? tag.album!.trim()
        : 'Unknown Album';
    final genre = (tag.genre?.trim().isNotEmpty == true)
        ? tag.genre!.trim()
        : '';

    return NormalizedSongMetadata(
      title: title,
      artist: artist,
      normalizedArtist: normalizeIdentity(artist),
      album: album,
      normalizedAlbum: normalizeIdentity(album),
      albumArtist: rawAlbumArtist,
      genre: genre,
      year: tag.year,
      trackNumber: tag.trackNumber,
      discNumber: tag.discNumber,
      lyrics: tag.lyrics,
      duration: tag.duration ?? 0,
      pictures: tag.pictures,
    );
  }
}
