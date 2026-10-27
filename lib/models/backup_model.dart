class BackupManifest {
  final int backupVersion;
  final int schemaVersion;
  final String appVersion;
  final String createdAt;
  final String platform;
  final String checksum;
  final Map<String, bool> contains;

  BackupManifest({
    this.backupVersion = 1,
    this.schemaVersion = 6,
    this.appVersion = '1.0.0+1',
    required this.createdAt,
    required this.platform,
    required this.checksum,
    required this.contains,
  });

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    final containsMap =
        (json['contains'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as bool),
        ) ??
        {
          'library': true,
          'playlists': true,
          'favorites': true,
          'history': true,
          'playerState': true,
        };

    return BackupManifest(
      backupVersion: json['backupVersion'] as int? ?? 1,
      schemaVersion: json['schemaVersion'] as int? ?? 6,
      appVersion: json['appVersion'] as String? ?? '1.0.0+1',
      createdAt: json['createdAt'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      checksum: json['checksum'] as String? ?? '',
      contains: containsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backupVersion': backupVersion,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'createdAt': createdAt,
      'platform': platform,
      'checksum': checksum,
      'contains': contains,
    };
  }
}

class BackupPackage {
  final BackupManifest manifest;
  final List<Map<String, dynamic>> songs;
  final List<Map<String, dynamic>> artists;
  final List<Map<String, dynamic>> albums;
  final List<Map<String, dynamic>> genres;
  final List<Map<String, dynamic>> playlists;
  final List<Map<String, dynamic>> playlistSongs;
  final List<Map<String, dynamic>> favorites;
  final List<Map<String, dynamic>> listeningHistories;
  final Map<String, dynamic>? playerState;
  final List<Map<String, dynamic>> playerQueues;

  BackupPackage({
    required this.manifest,
    required this.songs,
    required this.artists,
    required this.albums,
    required this.genres,
    required this.playlists,
    required this.playlistSongs,
    required this.favorites,
    required this.listeningHistories,
    this.playerState,
    required this.playerQueues,
  });

  factory BackupPackage.fromJson(Map<String, dynamic> json) {
    return BackupPackage(
      manifest: BackupManifest.fromJson(
        json['manifest'] as Map<String, dynamic>? ?? {},
      ),
      songs:
          (json['songs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      artists:
          (json['artists'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [],
      albums:
          (json['albums'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [],
      genres:
          (json['genres'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [],
      playlists:
          (json['playlists'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [],
      playlistSongs:
          (json['playlistSongs'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [],
      favorites:
          (json['favorites'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [],
      listeningHistories:
          (json['listeningHistories'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [],
      playerState: json['playerState'] as Map<String, dynamic>?,
      playerQueues:
          (json['playerQueues'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'manifest': manifest.toJson(),
      'songs': songs,
      'artists': artists,
      'albums': albums,
      'genres': genres,
      'playlists': playlists,
      'playlistSongs': playlistSongs,
      'favorites': favorites,
      'listeningHistories': listeningHistories,
      'playerState': playerState,
      'playerQueues': playerQueues,
    };
  }

  String calculateChecksum() {
    final content = '$songs$playlists$favorites$listeningHistories';
    int hash = 0;
    for (int i = 0; i < content.length; i++) {
      hash = (31 * hash + content.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}
