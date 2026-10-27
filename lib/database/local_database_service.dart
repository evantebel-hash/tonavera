import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._internal();
  LocalDatabaseService._internal();

  Database? _database;

  void setDatabaseForTesting(Database db) {
    _database = db;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await init();
    return _database!;
  }

  Future<Database> init() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath = '';
    if (Platform.isAndroid || Platform.isIOS) {
      dbPath = await getDatabasesPath();
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      dbPath = docDir.path;
    }

    final path = join(dbPath, 'mymusic_local.db');

    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> createSchema(Database db) async {
    await _onCreate(db, 8);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        artist_id INTEGER,
        album_id INTEGER,
        genre_id INTEGER,
        artist_name TEXT,
        album_title TEXT,
        genre_name TEXT,
        duration INTEGER DEFAULT 0,
        audio_path TEXT NOT NULL UNIQUE,
        file_path TEXT,
        cover TEXT,
        source TEXT DEFAULT 'local',
        provider TEXT,
        source_id TEXT,
        metadata_source TEXT,
        imported_at TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE artists (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        image TEXT,
        bio TEXT,
        spotify_id TEXT,
        youtube_id TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE albums (
        id INTEGER PRIMARY KEY,
        artist_id INTEGER,
        title TEXT NOT NULL,
        cover TEXT,
        release_year INTEGER,
        spotify_id TEXT,
        youtube_id TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE genres (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        cover TEXT,
        visibility TEXT DEFAULT 'private',
        playlist_type TEXT DEFAULT 'normal',
        smart_config TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_songs (
        playlist_id INTEGER NOT NULL,
        song_id INTEGER NOT NULL,
        position_order INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, song_id),
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE favorites (
        song_id INTEGER PRIMARY KEY,
        created_at TEXT,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE listening_histories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        duration_played INTEGER DEFAULT 0,
        completed INTEGER DEFAULT 0,
        skipped INTEGER DEFAULT 0,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE player_states (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        current_song_id INTEGER,
        position_seconds INTEGER DEFAULT 0,
        is_playing INTEGER DEFAULT 0,
        is_shuffle INTEGER DEFAULT 0,
        repeat_mode TEXT DEFAULT 'off',
        volume REAL DEFAULT 1.0,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE player_queues (
        position_order INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER NOT NULL,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_uuid TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at_utc TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        entity_name TEXT PRIMARY KEY,
        last_sync_timestamp_utc TEXT,
        sync_status TEXT DEFAULT 'IDLE'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT,
        avatar TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lyrics_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER NOT NULL UNIQUE,
        source TEXT NOT NULL,
        plain_lyrics TEXT,
        synced_lyrics TEXT,
        language TEXT,
        fetched_at TEXT NOT NULL,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lh_started_at ON listening_histories(started_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lh_song_id ON listening_histories(song_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lh_song_started ON listening_histories(song_id, started_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_songs_provider_source ON songs(provider, source_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_artists_spotify_id ON artists(spotify_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_albums_spotify_id ON albums(spotify_id)',
    );

    await _createYouTubeTables(db);
  }

  static Future<void> _createYouTubeTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS youtube_videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        video_id TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        channel_id TEXT,
        channel_name TEXT,
        thumbnail_url TEXT,
        duration_seconds INTEGER DEFAULT 0,
        published_at TEXT,
        description TEXT,
        source_url TEXT,
        view_count INTEGER DEFAULT 0,
        fetched_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS youtube_playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        channel_id TEXT,
        channel_name TEXT,
        thumbnail_url TEXT,
        description TEXT,
        item_count INTEGER DEFAULT 0,
        source_url TEXT,
        fetched_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS youtube_playlist_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id TEXT NOT NULL,
        video_id TEXT NOT NULL,
        position_order INTEGER NOT NULL,
        title TEXT,
        channel_name TEXT,
        thumbnail_url TEXT,
        duration_seconds INTEGER DEFAULT 0,
        unavailable INTEGER DEFAULT 0,
        fetched_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS youtube_search_cache (
        query TEXT PRIMARY KEY,
        results_json TEXT NOT NULL,
        fetched_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS hybrid_playlist_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'local',
        song_id INTEGER,
        youtube_video_id TEXT,
        position_order INTEGER NOT NULL,
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_yt_video_id ON youtube_videos(video_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_yt_playlist_id ON youtube_playlists(playlist_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_yt_pi_playlist_id ON youtube_playlist_items(playlist_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          entity_uuid TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0,
          last_error TEXT,
          created_at_utc TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_metadata (
          entity_name TEXT PRIMARY KEY,
          last_sync_timestamp_utc TEXT,
          sync_status TEXT DEFAULT 'IDLE'
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          email TEXT,
          avatar TEXT,
          created_at TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE playlists ADD COLUMN playlist_type TEXT DEFAULT \'normal\'',
        );
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE playlists ADD COLUMN smart_config TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS lyrics_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          song_id INTEGER NOT NULL UNIQUE,
          source TEXT NOT NULL,
          plain_lyrics TEXT,
          synced_lyrics TEXT,
          language TEXT,
          fetched_at TEXT NOT NULL,
          updated_at TEXT,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lh_started_at ON listening_histories(started_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lh_song_id ON listening_histories(song_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lh_song_started ON listening_histories(song_id, started_at)',
      );
    }
    if (oldVersion < 7) {
      await _createYouTubeTables(db);
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE songs ADD COLUMN provider TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE songs ADD COLUMN source_id TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE songs ADD COLUMN metadata_source TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE songs ADD COLUMN imported_at TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE artists ADD COLUMN spotify_id TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE artists ADD COLUMN youtube_id TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE albums ADD COLUMN spotify_id TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE albums ADD COLUMN youtube_id TEXT');
      } catch (_) {}
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_songs_provider_source ON songs(provider, source_id)',
        );
      } catch (_) {}
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_artists_spotify_id ON artists(spotify_id)',
        );
      } catch (_) {}
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_albums_spotify_id ON albums(spotify_id)',
        );
      } catch (_) {}
    }
  }
}
