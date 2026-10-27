enum SpotifyEntityType {
  track,
  album,
  artist,
  playlist,
  unknown;

  /// Returns the lowercase canonical string identifier for the entity type.
  String get name {
    switch (this) {
      case SpotifyEntityType.track:
        return 'track';
      case SpotifyEntityType.album:
        return 'album';
      case SpotifyEntityType.artist:
        return 'artist';
      case SpotifyEntityType.playlist:
        return 'playlist';
      case SpotifyEntityType.unknown:
        return 'unknown';
    }
  }

  /// Converts a string into a [SpotifyEntityType] safely.
  static SpotifyEntityType fromString(String? val) {
    if (val == null) return SpotifyEntityType.unknown;
    final lower = val.trim().toLowerCase();
    switch (lower) {
      case 'track':
        return SpotifyEntityType.track;
      case 'album':
        return SpotifyEntityType.album;
      case 'artist':
        return SpotifyEntityType.artist;
      case 'playlist':
        return SpotifyEntityType.playlist;
      default:
        return SpotifyEntityType.unknown;
    }
  }
}

class SpotifyParsedUrl {
  final SpotifyEntityType type;
  final String id;
  final String originalUrl;
  final String canonicalUrl;

  const SpotifyParsedUrl({
    required this.type,
    required this.id,
    required this.originalUrl,
    required this.canonicalUrl,
  });

  bool get isValid => type != SpotifyEntityType.unknown && id.isNotEmpty;

  @override
  String toString() =>
      'SpotifyParsedUrl(type: $type, id: $id, canonicalUrl: $canonicalUrl)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotifyParsedUrl &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id;

  @override
  int get hashCode => type.hashCode ^ id.hashCode;
}

class SpotifyUrlParser {
  // Matches:
  // - https://open.spotify.com/track/{id}
  // - https://open.spotify.com/intl-es/track/{id}?si=...
  // - http://open.spotify.com/album/{id}
  // - spotify:track:{id}
  static final RegExp _webUrlRegex = RegExp(
    r'^(?:https?:\/\/)?(?:open\.)?spotify\.com\/(?:intl-[a-zA-Z-]+\/)?(track|album|artist|playlist)\/([a-zA-Z0-9]+)',
    caseSensitive: false,
  );

  static final RegExp _uriRegex = RegExp(
    r'^spotify:(track|album|artist|playlist):([a-zA-Z0-9]+)',
    caseSensitive: false,
  );

  /// Parses an input string (URL or URI) into a [SpotifyParsedUrl].
  /// Returns null if the string is empty, invalid, or malformed.
  static SpotifyParsedUrl? parse(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Check Spotify URI format: spotify:track:xxxx
    final uriMatch = _uriRegex.firstMatch(trimmed);
    if (uriMatch != null) {
      final typeStr = uriMatch.group(1)?.toLowerCase();
      final id = uriMatch.group(2) ?? '';
      final type = _mapEntityType(typeStr);
      if (type != SpotifyEntityType.unknown && id.isNotEmpty) {
        return SpotifyParsedUrl(
          type: type,
          id: id,
          originalUrl: trimmed,
          canonicalUrl: 'https://open.spotify.com/${type.name}/$id',
        );
      }
    }

    // Check Spotify Web URL format
    final webMatch = _webUrlRegex.firstMatch(trimmed);
    if (webMatch != null) {
      final typeStr = webMatch.group(1)?.toLowerCase();
      final id = webMatch.group(2) ?? '';
      final type = _mapEntityType(typeStr);
      if (type != SpotifyEntityType.unknown && id.isNotEmpty) {
        return SpotifyParsedUrl(
          type: type,
          id: id,
          originalUrl: trimmed,
          canonicalUrl: 'https://open.spotify.com/${type.name}/$id',
        );
      }
    }

    return null;
  }

  /// Checks whether the given string is a valid Spotify URL or URI.
  static bool isValid(String? input) {
    final parsed = parse(input);
    return parsed != null && parsed.isValid;
  }

  static SpotifyEntityType _mapEntityType(String? typeStr) {
    switch (typeStr) {
      case 'track':
        return SpotifyEntityType.track;
      case 'album':
        return SpotifyEntityType.album;
      case 'artist':
        return SpotifyEntityType.artist;
      case 'playlist':
        return SpotifyEntityType.playlist;
      default:
        return SpotifyEntityType.unknown;
    }
  }
}
