import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mymusic/database/local_database_service.dart';
import 'package:mymusic/repositories/local_music_repository.dart';
import 'package:mymusic/services/metadata/metadata_model.dart';
import 'package:mymusic/services/metadata/spotify_url_parser.dart';
import 'package:mymusic/services/metadata/spotify_metadata_provider.dart';
import 'package:mymusic/services/metadata/youtube_metadata_provider.dart';
import 'package:mymusic/services/youtube/youtube_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('1. URL Detection & Parsers', () {
    test('Spotify URLs: track, album, artist, playlist, and URI format', () {
      final track = SpotifyUrlParser.parse('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT');
      expect(track, isNotNull);
      expect(track!.type, SpotifyEntityType.track);
      expect(track.id, '4cOdK2wGLETKBW3PvgPWqT');

      final album = SpotifyUrlParser.parse('https://open.spotify.com/album/1DFixLWuPkv3KT3TnV35m3');
      expect(album, isNotNull);
      expect(album!.type, SpotifyEntityType.album);
      expect(album.id, '1DFixLWuPkv3KT3TnV35m3');

      final artist = SpotifyUrlParser.parse('https://open.spotify.com/artist/06HL4z0CvFAxyc27GXpf02');
      expect(artist, isNotNull);
      expect(artist!.type, SpotifyEntityType.artist);
      expect(artist.id, '06HL4z0CvFAxyc27GXpf02');

      final playlist = SpotifyUrlParser.parse('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M');
      expect(playlist, isNotNull);
      expect(playlist!.type, SpotifyEntityType.playlist);

      final uri = SpotifyUrlParser.parse('spotify:track:4cOdK2wGLETKBW3PvgPWqT');
      expect(uri, isNotNull);
      expect(uri!.type, SpotifyEntityType.track);
      expect(uri.id, '4cOdK2wGLETKBW3PvgPWqT');
    });

    test('YouTube Music URLs: video, watch URL, playlist/album, short URL', () {
      final musicWatch = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(musicWatch.type, YouTubeLinkType.video);
      expect(musicWatch.videoId, 'dQw4w9WgXcQ');

      final ytWatch = YouTubeParser.parseLinkOrQuery('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(ytWatch.type, YouTubeLinkType.video);
      expect(ytWatch.videoId, 'dQw4w9WgXcQ');

      final short = YouTubeParser.parseLinkOrQuery('https://youtu.be/dQw4w9WgXcQ');
      expect(short.type, YouTubeLinkType.video);
      expect(short.videoId, 'dQw4w9WgXcQ');

      final playlist = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/playlist?list=OLAK5uy_k123456');
      expect(playlist.type, YouTubeLinkType.playlist);
      expect(playlist.playlistId, 'OLAK5uy_k123456');
    });

    test('Invalid or unsupported links are rejected cleanly', () {
      final invalidSp = SpotifyUrlParser.parse('https://example.com/track/123');
      expect(invalidSp, isNull);

      final query = YouTubeParser.parseLinkOrQuery('some random query without url');
      expect(query.type, YouTubeLinkType.textSearch);
    });
  });

  group('2. YouTubeMetadataProvider via oEmbed and InnerTube', () {
    test('Fetches video metadata via mock oEmbed', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'www.youtube.com' && request.url.path == '/oembed') {
          return http.Response(
            '{"title": "Radiohead - Creep", "author_name": "Radiohead", "thumbnail_url": "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final provider = YouTubeMetadataProvider(client: mockClient);
      final meta = await provider.fetchMetadata('https://music.youtube.com/watch?v=dQw4w9WgXcQ');

      expect(meta, isNotNull);
      expect(meta!.provider, 'youtube');
      expect(meta.sourceId, 'dQw4w9WgXcQ');
      expect(meta.title, 'Creep');
      expect(meta.artist, 'Radiohead');
      expect(meta.artworkUrl, 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
    });

    test('Handles oEmbed network failure gracefully with fallback thumbnail', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final provider = YouTubeMetadataProvider(client: mockClient);
      final meta = await provider.fetchMetadata('https://music.youtube.com/watch?v=dQw4w9WgXcQ');

      expect(meta, isNotNull);
      expect(meta!.provider, 'youtube');
      expect(meta.sourceId, 'dQw4w9WgXcQ');
      expect(meta.artworkUrl, contains('dQw4w9WgXcQ'));
    });
  });

  group('3. Database Migration v7 -> v8 & Schema Validation', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 8,
        onCreate: (d, v) => LocalDatabaseService.createSchema(d),
      );
      LocalDatabaseService.instance.setDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('New tables have provider, source_id, imported_at, and indexes', () async {
      final songColumns = await db.rawQuery('PRAGMA table_info(songs)');
      final columnNames = songColumns.map((c) => c['name'] as String).toList();

      expect(columnNames, contains('provider'));
      expect(columnNames, contains('source_id'));
      expect(columnNames, contains('metadata_source'));
      expect(columnNames, contains('imported_at'));

      final artistColumns = await db.rawQuery('PRAGMA table_info(artists)');
      final artistColNames = artistColumns.map((c) => c['name'] as String).toList();
      expect(artistColNames, contains('spotify_id'));
      expect(artistColNames, contains('youtube_id'));

      final albumColumns = await db.rawQuery('PRAGMA table_info(albums)');
      final albumColNames = albumColumns.map((c) => c['name'] as String).toList();
      expect(albumColNames, contains('spotify_id'));
      expect(albumColNames, contains('youtube_id'));
    });
  });

  group('4. Transactional Import, Relational Integrity & Deduplication', () {
    late Database db;
    late LocalMusicRepository repo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 8,
        onCreate: (d, v) => LocalDatabaseService.createSchema(d),
      );
      LocalDatabaseService.instance.setDatabaseForTesting(db);
      repo = LocalMusicRepository();
    });

    tearDown(() async {
      await db.close();
    });

    test('Imports track metadata and correctly links Artist -> Album -> Song', () async {
      const metadata = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'track_123',
        sourceUrl: 'https://open.spotify.com/track/track_123',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        artists: ['Queen'],
        album: 'A Night at the Opera',
        duration: 354,
        releaseDate: '1975-11-21',
        artworkUrl: 'https://example.com/cover.jpg',
      );

      final result = await repo.importMetadata(metadata: metadata, overwriteExisting: false);
      expect(result['songsCreated'], 1);
      expect(result['artistsCreated'], 1);
      expect(result['albumsCreated'], 1);

      // Verify Artist: track artwork must NOT be set as artist image (Bug 1 fix)
      final artists = await repo.getArtists();
      expect(artists.length, 1);
      expect(artists.first.name, 'Queen');
      expect(artists.first.image, isNull);

      // Verify Album
      final albums = await repo.getAlbums();
      expect(albums.length, 1);
      expect(albums.first.title, 'A Night at the Opera');
      expect(albums.first.cover, 'https://example.com/cover.jpg');
      expect(albums.first.artistId, artists.first.id);
      expect(albums.first.releaseYear, 1975);

      // Verify Song
      final songs = await repo.getSongs();
      expect(songs.length, 1);
      expect(songs.first.title, 'Bohemian Rhapsody');
      expect(songs.first.cover, 'https://example.com/cover.jpg');
      expect(songs.first.artistId, artists.first.id);
      expect(songs.first.albumId, albums.first.id);
      expect(songs.first.provider, 'spotify');
      expect(songs.first.sourceId, 'track_123');
    });

    test('Deduplication: re-importing same track by provider+sourceId does not duplicate', () async {
      const metadata = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'track_123',
        sourceUrl: 'https://open.spotify.com/track/track_123',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        duration: 354,
        artworkUrl: 'https://example.com/cover.jpg',
      );

      // First import
      await repo.importMetadata(metadata: metadata, overwriteExisting: false);

      // Second import with overwrite = false
      final result2 = await repo.importMetadata(metadata: metadata, overwriteExisting: false);
      expect(result2['songsCreated'], 0);

      final songs = await repo.getSongs();
      expect(songs.length, 1);
      final artists = await repo.getArtists();
      expect(artists.length, 1);
      final albums = await repo.getAlbums();
      expect(albums.length, 1);
    });

    test('Imports multi-track album atomically in single transaction', () async {
      const albumMeta = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'album_999',
        sourceUrl: 'https://open.spotify.com/album/album_999',
        title: 'OK Computer',
        artist: 'Radiohead',
        artists: ['Radiohead'],
        artworkUrl: 'https://example.com/ok_computer.jpg',
        type: SpotifyEntityType.album,
        releaseDate: '1997-05-21',
        trackList: [
          MusicMetadataResult(
            provider: 'spotify',
            sourceId: 'track_01',
            title: 'Airbag',
            artist: 'Radiohead',
            album: 'OK Computer',
            duration: 284,
            artworkUrl: 'https://example.com/ok_computer.jpg',
          ),
          MusicMetadataResult(
            provider: 'spotify',
            sourceId: 'track_02',
            title: 'Paranoid Android',
            artist: 'Radiohead',
            album: 'OK Computer',
            duration: 383,
            artworkUrl: 'https://example.com/ok_computer.jpg',
          ),
        ],
      );

      final res = await repo.importMetadata(metadata: albumMeta);
      expect(res['songsCreated'], 2);
      expect(res['albumsCreated'], 1);
      expect(res['artistsCreated'], 1);

      final albumTracks = await repo.getSongsByAlbumId(1);
      expect(albumTracks.length, 2);
      expect(albumTracks.map((s) => s.title), containsAll(['Airbag', 'Paranoid Android']));
    });

    test('Re-import with overwriteExisting = true updates fields without duplicating records', () async {
      const initialMeta = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'track_999',
        sourceUrl: 'https://open.spotify.com/track/track_999',
        title: 'Original Title',
        artist: 'Original Artist',
        album: 'Original Album',
        duration: 180,
      );

      await repo.importMetadata(metadata: initialMeta, overwriteExisting: false);
      var song = (await repo.getSongs()).first;
      expect(song.title, 'Original Title');
      expect(song.duration, 180);

      // Re-import with updated title and duration, overwrite = true
      const updatedMeta = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'track_999',
        sourceUrl: 'https://open.spotify.com/track/track_999',
        title: 'Remastered Title',
        artist: 'Original Artist',
        album: 'Original Album',
        duration: 210,
        artworkUrl: 'https://example.com/remastered.jpg',
      );

      final updateRes = await repo.importMetadata(metadata: updatedMeta, overwriteExisting: true);
      expect(updateRes['songsUpdated'], 1);
      expect(updateRes['songsCreated'], 0);

      final allSongs = await repo.getSongs();
      expect(allSongs.length, 1);
      expect(allSongs.first.title, 'Remastered Title');
      expect(allSongs.first.duration, 210);
      expect(allSongs.first.cover, 'https://example.com/remastered.jpg');
    });

    test('Two different tracks with the same title under different artists do not collide', () async {
      const trackArtistA = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'track_a1',
        title: 'Stay',
        artist: 'Artist A',
        album: 'Album A',
        duration: 190,
      );

      const trackArtistB = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'track_b1',
        title: 'Stay',
        artist: 'Artist B',
        album: 'Album B',
        duration: 210,
      );

      await repo.importMetadata(metadata: trackArtistA);
      await repo.importMetadata(metadata: trackArtistB);

      final allSongs = await repo.getSongs();
      expect(allSongs.length, 2);
      expect(allSongs[0].artistName, isNot(equals(allSongs[1].artistName)));
      expect(allSongs[0].audioPath, isNot(equals(allSongs[1].audioPath)));
    });
  });

  group('5. Edge Cases: Partial Responses, Errors & Pagination Limits', () {
    test('Spotify Embed HTML parser handles missing artist/album gracefully', () {
      const partialHtml = '''
        <!DOCTYPE html>
        <html>
        <head>
          <script id="__NEXT_DATA__" type="application/json">
          {
            "props": {
              "pageProps": {
                "state": {
                  "data": {
                    "entity": {
                      "name": "Untitled Single",
                      "duration": 120000,
                      "trackList": []
                    }
                  }
                }
              }
            }
          }
          </script>
        </head>
        </html>
      ''';

      final parsedUrl = SpotifyUrlParser.parse('https://open.spotify.com/track/unknown_track')!;
      final result = SpotifyMetadataProvider.parseEmbedHtml(partialHtml, parsedUrl);

      expect(result, isNotNull);
      expect(result!.title, 'Untitled Single');
      expect(result.duration, 120);
      expect(result.artist, isNull);
    });

    test('YouTubeMetadataProvider handles network timeout without throwing unhandled exceptions', () async {
      final slowClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response('Timeout', 504);
      });

      final provider = YouTubeMetadataProvider(
        client: slowClient,
        timeout: const Duration(milliseconds: 50),
      );

      final result = await provider.fetchMetadata('https://music.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(result, isNotNull);
      expect(result!.sourceId, 'dQw4w9WgXcQ');
      expect(result.artworkUrl, contains('dQw4w9WgXcQ'));
    });
  });

  group('6. Full Spotify Pipeline: Parsing -> Metadata Conversion -> SQLite Storage', () {
    late Database db;
    late LocalMusicRepository repo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 8,
        onCreate: (d, v) => LocalDatabaseService.createSchema(d),
      );
      LocalDatabaseService.instance.setDatabaseForTesting(db);
      repo = LocalMusicRepository();
    });

    tearDown(() async {
      await db.close();
    });

    test('Pipeline for Spotify Artist URL: parsing -> mock embed -> SQLite', () async {
      final parsed = SpotifyUrlParser.parse('https://open.spotify.com/artist/06HL4z0CvFAxyc27GXpf02');
      expect(parsed, isNotNull);
      expect(parsed!.type, SpotifyEntityType.artist);
      expect(parsed.type.name, 'artist');
      expect(parsed.canonicalUrl, 'https://open.spotify.com/artist/06HL4z0CvFAxyc27GXpf02');

      const mockArtistHtml = '''
        <html>
        <head>
          <script id="__NEXT_DATA__" type="application/json">
          {
            "props": {
              "pageProps": {
                "state": {
                  "data": {
                    "entity": {
                      "name": "Taylor Swift",
                      "visualIdentity": {
                        "image": [{"url": "https://example.com/taylor.jpg", "maxWidth": 640}]
                      },
                      "trackList": [
                        {
                          "title": "Anti-Hero",
                          "subtitle": "Taylor Swift",
                          "duration": 200000,
                          "uri": "spotify:track:0V3wPSX9ygBnKi895g6MW2",
                          "visualIdentity": {
                            "image": [{"url": "https://example.com/antihero.jpg"}]
                          }
                        }
                      ]
                    }
                  }
                }
              }
            }
          }
          </script>
        </head>
        </html>
      ''';

      final meta = SpotifyMetadataProvider.parseEmbedHtml(mockArtistHtml, parsed);
      expect(meta, isNotNull);
      expect(meta!.type, SpotifyEntityType.artist);
      expect(meta.type.name, 'artist');
      expect(meta.typeString, 'artist');
      expect(meta.title, 'Taylor Swift');
      expect(meta.trackList.length, 1);
      expect(meta.trackList.first.title, 'Anti-Hero');
      expect(meta.trackList.first.type, SpotifyEntityType.track);
      expect(meta.trackList.first.type.name, 'track');

      // Store in SQLite
      final summary = await repo.importMetadata(metadata: meta);
      expect(summary['artistsCreated'], 1);
      expect(summary['songsCreated'], 1);

      final artists = await repo.getArtists();
      expect(artists.length, 1);
      expect(artists.first.name, 'Taylor Swift');
      expect(artists.first.image, 'https://example.com/taylor.jpg');

      final songs = await repo.getSongs();
      expect(songs.length, 1);
      expect(songs.first.title, 'Anti-Hero');
      expect(songs.first.artistId, artists.first.id);
    });

    test('Pipeline for Spotify Track URL: parsing -> mock embed -> SQLite', () async {
      final parsed = SpotifyUrlParser.parse('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT');
      expect(parsed, isNotNull);
      expect(parsed!.type, SpotifyEntityType.track);
      expect(parsed.type.name, 'track');

      const mockTrackHtml = '''
        <html>
        <head>
          <script id="__NEXT_DATA__" type="application/json">
          {
            "props": {
              "pageProps": {
                "state": {
                  "data": {
                    "entity": {
                      "name": "Never Gonna Give You Up",
                      "artists": [{"name": "Rick Astley"}],
                      "duration": 213000,
                      "visualIdentity": {
                        "image": [{"url": "https://example.com/rick.jpg", "maxWidth": 300}]
                      }
                    }
                  }
                }
              }
            }
          }
          </script>
        </head>
        </html>
      ''';

      final meta = SpotifyMetadataProvider.parseEmbedHtml(mockTrackHtml, parsed);
      expect(meta, isNotNull);
      expect(meta!.type, SpotifyEntityType.track);
      expect(meta.title, 'Never Gonna Give You Up');
      expect(meta.artist, 'Rick Astley');

      final summary = await repo.importMetadata(metadata: meta);
      expect(summary['songsCreated'], 1);
      expect(summary['artistsCreated'], 1);

      final songs = await repo.getSongs();
      expect(songs.length, 1);
      expect(songs.first.title, 'Never Gonna Give You Up');
    });

    test('Pipeline for Spotify Album URL: parsing -> mock embed -> SQLite', () async {
      final parsed = SpotifyUrlParser.parse('https://open.spotify.com/album/4aawyAB9vmqN3uQ7FjRGTy');
      expect(parsed, isNotNull);
      expect(parsed!.type, SpotifyEntityType.album);
      expect(parsed.type.name, 'album');

      const mockAlbumHtml = '''
        <html>
        <head>
          <script id="__NEXT_DATA__" type="application/json">
          {
            "props": {
              "pageProps": {
                "state": {
                  "data": {
                    "entity": {
                      "name": "Cyndi Lauper Album",
                      "artists": [{"name": "Cyndi Lauper"}],
                      "visualIdentity": {
                        "image": [{"url": "https://example.com/cyndi.jpg", "maxWidth": 640}]
                      },
                      "trackList": [
                        {
                          "title": "Girls Just Want to Have Fun",
                          "subtitle": "Cyndi Lauper",
                          "duration": 230000,
                          "uri": "spotify:track:cyndi_01"
                        }
                      ]
                    }
                  }
                }
              }
            }
          }
          </script>
        </head>
        </html>
      ''';

      final meta = SpotifyMetadataProvider.parseEmbedHtml(mockAlbumHtml, parsed);
      expect(meta, isNotNull);
      expect(meta!.type, SpotifyEntityType.album);
      expect(meta.trackList.length, 1);
      expect(meta.trackList.first.artworkUrl, 'https://example.com/cyndi.jpg');

      final summary = await repo.importMetadata(metadata: meta);
      expect(summary['albumsCreated'], 1);
      expect(summary['songsCreated'], 1);

      final albums = await repo.getAlbums();
      expect(albums.first.title, 'Cyndi Lauper Album');
    });

    test('Pipeline for Spotify Playlist URL: parsing -> mock embed -> SQLite', () async {
      final parsed = SpotifyUrlParser.parse('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M');
      expect(parsed, isNotNull);
      expect(parsed!.type, SpotifyEntityType.playlist);
      expect(parsed.type.name, 'playlist');

      const mockPlaylistHtml = '''
        <html>
        <head>
          <script id="__NEXT_DATA__" type="application/json">
          {
            "props": {
              "pageProps": {
                "state": {
                  "data": {
                    "entity": {
                      "name": "Today's Top Hits",
                      "subtitle": "Spotify",
                      "visualIdentity": {
                        "image": [{"url": "https://example.com/tth.jpg", "maxWidth": 640}]
                      },
                      "trackList": [
                        {
                          "title": "Hit Track 1",
                          "subtitle": "Popular Artist",
                          "duration": 180000,
                          "uri": "spotify:track:hit_01",
                          "visualIdentity": {
                            "image": [{"url": "https://example.com/hit_01.jpg"}]
                          }
                        }
                      ]
                    }
                  }
                }
              }
            }
          }
          </script>
        </head>
        </html>
      ''';

      final meta = SpotifyMetadataProvider.parseEmbedHtml(mockPlaylistHtml, parsed);
      expect(meta, isNotNull);
      expect(meta!.type, SpotifyEntityType.playlist);
      expect(meta.trackList.length, 1);
      expect(meta.trackList.first.artworkUrl, 'https://example.com/hit_01.jpg');

      final summary = await repo.importMetadata(metadata: meta);
      expect(summary['songsCreated'], 1);
      expect(summary['artistsCreated'], 1);
    });
  });

  group('7. BUG 1 Verification: Artwork Separation & Entity Priority', () {
    late Database db;
    late LocalMusicRepository repo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 8,
        onCreate: (d, v) => LocalDatabaseService.createSchema(d),
      );
      LocalDatabaseService.instance.setDatabaseForTesting(db);
      repo = LocalMusicRepository();
    });

    tearDown(() async {
      await db.close();
    });

    test('Artist photo is distinct from album cover and track cover; track does not adopt artist photo', () async {
      const artistUrl = 'https://example.com/artist_profile.jpg';
      const albumCoverUrl = 'https://example.com/album_cover.jpg';
      const trackCoverUrl = 'https://example.com/track_specific.jpg';

      const metadata = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'track_art_test',
        title: 'Solo Track',
        artist: 'Solo Artist',
        album: 'Solo Album',
        artistArtworkUrl: artistUrl,
        albumArtworkUrl: albumCoverUrl,
        trackArtworkUrl: trackCoverUrl,
        type: SpotifyEntityType.track,
      );

      await repo.importMetadata(metadata: metadata);

      final artists = await repo.getArtists();
      final albums = await repo.getAlbums();
      final songs = await repo.getSongs();

      expect(artists.length, 1);
      expect(artists.first.image, isNull, reason: 'Track import should not overwrite or set artist avatar with track artwork');

      expect(albums.length, 1);
      expect(albums.first.cover, albumCoverUrl);

      expect(songs.length, 1);
      expect(songs.first.cover, trackCoverUrl);
    });

    test('Track without specific artwork falls back to album cover, NEVER artist profile photo', () async {
      const artistPhoto = 'https://example.com/artist_face.jpg';
      const albumCover = 'https://example.com/album_sleeve.jpg';

      const metadata = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'album_art_inherit',
        title: 'Master Album',
        artist: 'Lead Musician',
        artistArtworkUrl: artistPhoto,
        albumArtworkUrl: albumCover,
        type: SpotifyEntityType.album,
        trackList: [
          MusicMetadataResult(
            provider: 'spotify',
            sourceId: 'track_inherit_1',
            title: 'Track 1',
            artist: 'Lead Musician',
            album: 'Master Album',
            albumArtworkUrl: albumCover,
            type: SpotifyEntityType.track,
          ),
        ],
      );

      await repo.importMetadata(metadata: metadata);

      final albums = await repo.getAlbums();
      final songs = await repo.getSongs();

      expect(albums.first.cover, albumCover);
      expect(songs.first.cover, albumCover);
      expect(songs.first.cover, isNot(equals(artistPhoto)));
    });

    test('Album and track without any artwork have safe null fallback without crashing', () async {
      const metadata = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'track_no_art',
        title: 'Ghost Song',
        artist: 'Ghost Artist',
        album: 'Ghost Album',
        type: SpotifyEntityType.track,
      );

      final result = await repo.importMetadata(metadata: metadata);
      expect(result['songsCreated'], 1);

      final song = (await repo.getSongs()).first;
      expect(song.cover, isNull);

      final album = (await repo.getAlbums()).first;
      expect(album.cover, isNull);
    });

    test('Re-import does not overwrite album cover with artist profile picture', () async {
      // 1. Initial import with valid album cover
      const initialAlbum = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'album_initial',
        title: 'Epic Album',
        artist: 'Epic Artist',
        albumArtworkUrl: 'https://example.com/real_album_cover.jpg',
        type: SpotifyEntityType.album,
        trackList: [
          MusicMetadataResult(
            provider: 'spotify',
            sourceId: 'trk_001',
            title: 'Epic Song',
            artist: 'Epic Artist',
            album: 'Epic Album',
            albumArtworkUrl: 'https://example.com/real_album_cover.jpg',
            type: SpotifyEntityType.track,
          ),
        ],
      );
      await repo.importMetadata(metadata: initialAlbum);

      // 2. Later import artist profile
      const artistImport = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'artist_profile_import',
        title: 'Epic Artist',
        artist: 'Epic Artist',
        artistArtworkUrl: 'https://example.com/artist_headshot.jpg',
        type: SpotifyEntityType.artist,
        trackList: [
          MusicMetadataResult(
            provider: 'spotify',
            sourceId: 'trk_001',
            title: 'Epic Song',
            artist: 'Epic Artist',
            type: SpotifyEntityType.track,
          ),
        ],
      );
      await repo.importMetadata(metadata: artistImport, overwriteExisting: true);

      final albums = await repo.getAlbums();
      final songs = await repo.getSongs();
      final artists = await repo.getArtists();

      expect(artists.first.image, 'https://example.com/artist_headshot.jpg');
      expect(albums.first.cover, 'https://example.com/real_album_cover.jpg', reason: 'Album cover must NOT be overwritten by artist headshot');
      expect(songs.first.cover, 'https://example.com/real_album_cover.jpg', reason: 'Song cover must NOT be overwritten by artist headshot');
    });
  });

  group('8. BUG 2 Verification: Collaborations & Duplicate Artist Prevention', () {
    late Database db;
    late LocalMusicRepository repo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 8,
        onCreate: (d, v) => LocalDatabaseService.createSchema(d),
      );
      LocalDatabaseService.instance.setDatabaseForTesting(db);
      repo = LocalMusicRepository();
    });

    tearDown(() async {
      await db.close();
    });

    test('Single artist track creates single artist and song correctly', () async {
      const metadata = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'solo_001',
        title: 'Solo Work',
        artist: 'Adele',
        artists: ['Adele'],
        artistList: [
          ArtistMetadataInfo(name: 'Adele', id: 'sp_adele', provider: 'spotify'),
        ],
        type: SpotifyEntityType.track,
      );

      final res = await repo.importMetadata(metadata: metadata);
      expect(res['artistsCreated'], 1);
      expect(res['songsCreated'], 1);

      final artists = await repo.getArtists();
      expect(artists.length, 1);
      expect(artists.first.name, 'Adele');
      expect(artists.first.spotifyId, 'sp_adele');
    });

    test('Track with two artists and "feat." parses individual artists without compound artist entity', () async {
      const metadata = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'collab_feat_001',
        title: 'Starboy',
        artist: 'The Weeknd feat. Daft Punk',
        type: SpotifyEntityType.track,
      );

      final res = await repo.importMetadata(metadata: metadata);
      expect(res['artistsCreated'], 2, reason: 'Must create The Weeknd and Daft Punk as separate entities, NOT "The Weeknd feat. Daft Punk"');
      expect(res['songsCreated'], 1);

      final artists = await repo.getArtists();
      final artistNames = artists.map((a) => a.name).toList();
      expect(artistNames, containsAll(['The Weeknd', 'Daft Punk']));
      expect(artistNames, isNot(contains('The Weeknd feat. Daft Punk')));

      // Song preserves display artist string
      final songs = await repo.getSongs();
      expect(songs.first.artistName, 'The Weeknd feat. Daft Punk');
      // Song primary artist points to The Weeknd
      final primaryArtist = artists.firstWhere((a) => a.name == 'The Weeknd');
      expect(songs.first.artistId, primaryArtist.id);
    });

    test('Track with multiple collaborators having provider IDs resolves without duplication', () async {
      const metadata = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'multi_id_001',
        title: 'Collab Anthem',
        artist: 'Primary Artist',
        artists: ['Primary Artist', 'Featured Singer', 'Guest DJ'],
        artistList: [
          ArtistMetadataInfo(name: 'Primary Artist', id: 'id_prim', provider: 'spotify'),
          ArtistMetadataInfo(name: 'Featured Singer', id: 'id_sing', provider: 'spotify'),
          ArtistMetadataInfo(name: 'Guest DJ', id: 'id_dj', provider: 'spotify'),
        ],
        type: SpotifyEntityType.track,
      );

      final res1 = await repo.importMetadata(metadata: metadata);
      expect(res1['artistsCreated'], 3);
      expect(res1['songsCreated'], 1);

      final artists = await repo.getArtists();
      expect(artists.length, 3);
      expect(artists.map((a) => a.spotifyId), containsAll(['id_prim', 'id_sing', 'id_dj']));

      // Re-import the same track: must be completely idempotent
      final res2 = await repo.importMetadata(metadata: metadata, overwriteExisting: false);
      expect(res2['artistsCreated'], 0);
      expect(res2['songsCreated'], 0);

      final allArtists = await repo.getArtists();
      expect(allArtists.length, 3);
      final allSongs = await repo.getSongs();
      expect(allSongs.length, 1);
    });

    test('Band names with compound words like "Simon & Garfunkel" or "AC/DC" are not blindly split without collab keywords', () async {
      const metadata = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'band_001',
        title: 'The Sound of Silence',
        artist: 'Simon & Garfunkel',
        type: SpotifyEntityType.track,
      );

      final res = await repo.importMetadata(metadata: metadata);
      expect(res['artistsCreated'], 1);

      final artists = await repo.getArtists();
      expect(artists.length, 1);
      expect(artists.first.name, 'Simon & Garfunkel');
    });

    test('Song with different collaborator formatting (e.g. feat vs ft) deduplicates safely', () async {
      // First import with 'feat.'
      const meta1 = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'sp_track_collab_dup',
        title: 'Unity',
        artist: 'Alan Walker feat. Sabrina Carpenter',
        type: SpotifyEntityType.track,
      );
      await repo.importMetadata(metadata: meta1);

      // Re-import with 'ft.'
      const meta2 = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'sp_track_collab_dup',
        title: 'Unity',
        artist: 'Alan Walker ft. Sabrina Carpenter',
        type: SpotifyEntityType.track,
      );
      final res = await repo.importMetadata(metadata: meta2, overwriteExisting: true);

      expect(res['songsCreated'], 0);
      expect(res['songsUpdated'], 1);
      expect(res['artistsCreated'], 0);

      final songs = await repo.getSongs();
      expect(songs.length, 1);
      final artists = await repo.getArtists();
      expect(artists.map((a) => a.name), containsAll(['Alan Walker', 'Sabrina Carpenter']));
    });
  });

  group('9. YouTube Channel & Artist Profile Import Tests', () {
    late Database db;
    late LocalMusicRepository repo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 8,
        onCreate: (d, v) => LocalDatabaseService.createSchema(d),
      );
      LocalDatabaseService.instance.setDatabaseForTesting(db);
      repo = LocalMusicRepository();
    });

    tearDown(() async {
      await db.close();
    });

    test('YouTubeParser parses artist profile handles and strips tracking parameters like ?si=...', () {
      // 1. music.youtube.com/@handle with ?si=
      final musicYt = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/@ricchiepoveriofficial?si=Sf0TccxAeGd3zNKn');
      expect(musicYt.type, YouTubeLinkType.channel);
      expect(musicYt.channelHandle, '@ricchiepoveriofficial');

      // 2. youtube.com/@handle
      final standardYt = YouTubeParser.parseLinkOrQuery('https://youtube.com/@coldplay');
      expect(standardYt.type, YouTubeLinkType.channel);
      expect(standardYt.channelHandle, '@coldplay');

      // 3. www.youtube.com/@handle with trailing slash
      final wwwYt = YouTubeParser.parseLinkOrQuery('https://www.youtube.com/@queen/');
      expect(wwwYt.type, YouTubeLinkType.channel);
      expect(wwwYt.channelHandle, '@queen');

      // 4. Raw handle string
      final rawHandle = YouTubeParser.parseLinkOrQuery('@taylorswift');
      expect(rawHandle.type, YouTubeLinkType.channel);
      expect(rawHandle.channelHandle, '@taylorswift');

      // 5. Channel ID URL
      final channelIdUrl = YouTubeParser.parseLinkOrQuery('https://www.youtube.com/channel/UC-9-kyTW8ZkZNDHQJ6FgpwQ');
      expect(channelIdUrl.type, YouTubeLinkType.channel);
      expect(channelIdUrl.channelId, 'UC-9-kyTW8ZkZNDHQJ6FgpwQ');
    });

    test('Distinguishes video, playlist, channel, and Spotify URLs without rejection', () {
      final video = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(video.type, YouTubeLinkType.video);

      final playlist = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/playlist?list=PL123456');
      expect(playlist.type, YouTubeLinkType.playlist);

      final channel = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/@ricchiepoveriofficial');
      expect(channel.type, YouTubeLinkType.channel);

      final spotify = SpotifyUrlParser.parse('https://open.spotify.com/artist/06HL4z0CvFAxyc27GXpf02');
      expect(spotify, isNotNull);
      expect(spotify!.type, SpotifyEntityType.artist);
    });


    test('YouTubeMetadataProvider resolves artist metadata and public uploads via YouTube Data API v3 when uploads playlist exists', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'www.googleapis.com' && request.url.path == '/youtube/v3/channels') {
          expect(request.url.queryParameters['forHandle'], 'ricchiepoveriofficial');
          expect(request.url.queryParameters['key'], 'TEST_YOUTUBE_API_KEY');
          return http.Response(
            '''
            {
              "items": [
                {
                  "id": "UC_RICCHI_ID",
                  "snippet": {
                    "title": "Ricchi e Poveri Official",
                    "description": "Official YouTube Channel of Ricchi e Poveri",
                    "thumbnails": {
                      "high": {
                        "url": "https://yt3.ggpht.com/ricchiepoveri_high.jpg"
                      }
                    }
                  },
                  "contentDetails": {
                    "relatedPlaylists": {
                      "uploads": "UU_RICCHI_UPLOADS_ID"
                    }
                  }
                }
              ]
            }
            ''',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.host == 'www.googleapis.com' && request.url.path == '/youtube/v3/playlistItems') {
          expect(request.url.queryParameters['playlistId'], 'UU_RICCHI_UPLOADS_ID');
          return http.Response(
            '''
            {
              "items": [
                {
                  "contentDetails": {"videoId": "yt_song_001"},
                  "snippet": {
                    "title": "Sara Perche Ti Amo (Official Video)",
                    "thumbnails": {
                      "high": {"url": "https://i.ytimg.com/vi/yt_song_001/hqdefault.jpg"}
                    }
                  }
                }
              ]
            }
            ''',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final provider = YouTubeMetadataProvider(
        client: mockClient,
        apiKey: 'TEST_YOUTUBE_API_KEY',
      );

      final result = await provider.fetchMetadata('https://music.youtube.com/@ricchiepoveriofficial?si=Sf0TccxAeGd3zNKn');
      expect(result, isNotNull);
      expect(result!.provider, 'youtube');
      expect(result.sourceId, 'UC_RICCHI_ID');
      expect(result.title, 'Ricchi e Poveri Official');
      expect(result.artist, 'Ricchi e Poveri Official');
      expect(result.type, SpotifyEntityType.artist);
      expect(result.artistArtworkUrl, 'https://yt3.ggpht.com/ricchiepoveri_high.jpg');
      expect(result.trackList.length, 1);
      expect(result.trackList.first.title, 'Sara Perche Ti Amo');
      expect(result.trackList.first.album, 'Unggahan Publik');
      expect(result.trackList.first.trackArtworkUrl, 'https://i.ytimg.com/vi/yt_song_001/hqdefault.jpg');
    });

    test('YouTubeMetadataProvider handles multiple videos and pagination (nextPageToken) correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'www.googleapis.com' && request.url.path == '/youtube/v3/channels') {
          return http.Response(
            '''
            {
              "items": [
                {
                  "id": "UC_PAGINATION_ID",
                  "snippet": {
                    "title": "Pagination Artist",
                    "thumbnails": {"high": {"url": "https://yt3.ggpht.com/pag_high.jpg"}}
                  },
                  "contentDetails": {
                    "relatedPlaylists": {"uploads": "UU_PAGE_UPLOADS"}
                  }
                }
              ]
            }
            ''',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.host == 'www.googleapis.com' && request.url.path == '/youtube/v3/playlistItems') {
          final pageToken = request.url.queryParameters['pageToken'];
          if (pageToken == null || pageToken.isEmpty) {
            // First page returns video 1 & video 2 with nextPageToken
            return http.Response(
              '''
              {
                "nextPageToken": "PAGE_TWO_TOKEN",
                "items": [
                  {
                    "contentDetails": {"videoId": "vid_page_1"},
                    "snippet": {
                      "title": "Track One",
                      "thumbnails": {"high": {"url": "https://i.ytimg.com/vi/vid_page_1/hqdefault.jpg"}}
                    }
                  },
                  {
                    "contentDetails": {"videoId": "vid_page_2"},
                    "snippet": {
                      "title": "Private video",
                      "thumbnails": {"high": {"url": "https://i.ytimg.com/vi/vid_page_2/hqdefault.jpg"}}
                    }
                  }
                ]
              }
              ''',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          } else if (pageToken == 'PAGE_TWO_TOKEN') {
            // Second page returns video 3 without nextPageToken
            return http.Response(
              '''
              {
                "items": [
                  {
                    "contentDetails": {"videoId": "vid_page_3"},
                    "snippet": {
                      "title": "Track Three (Remix)",
                      "thumbnails": {"high": {"url": "https://i.ytimg.com/vi/vid_page_3/hqdefault.jpg"}}
                    }
                  }
                ]
              }
              ''',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
        }
        return http.Response('Not Found', 404);
      });

      final provider = YouTubeMetadataProvider(
        client: mockClient,
        apiKey: 'TEST_KEY',
      );

      final result = await provider.fetchMetadata('https://music.youtube.com/@paginationartist?si=xyz123');
      expect(result, isNotNull);
      expect(result!.trackList.length, 2); // vid_page_1 and vid_page_3 (vid_page_2 skipped as 'Private video')
      expect(result.trackList[0].sourceId, 'vid_page_1');
      expect(result.trackList[0].title, 'Track One');
      expect(result.trackList[1].sourceId, 'vid_page_3');
      expect(result.trackList[1].title, 'Track Three (Remix)');
    });

    test('YouTubeMetadataProvider handles channel without songs (empty uploads)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'www.googleapis.com' && request.url.path == '/youtube/v3/channels') {
          return http.Response(
            '''
            {
              "items": [
                {
                  "id": "UC_EMPTY_CHANNEL",
                  "snippet": {
                    "title": "Empty Artist",
                    "thumbnails": {"high": {"url": "https://yt3.ggpht.com/empty.jpg"}}
                  },
                  "contentDetails": {
                    "relatedPlaylists": {"uploads": "UU_EMPTY_UPLOADS"}
                  }
                }
              ]
            }
            ''',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.host == 'www.googleapis.com' && request.url.path == '/youtube/v3/playlistItems') {
          return http.Response(
            '{"items": []}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final provider = YouTubeMetadataProvider(
        client: mockClient,
        apiKey: 'TEST_KEY',
      );

      final result = await provider.fetchMetadata('https://music.youtube.com/@emptyartist');
      expect(result, isNotNull);
      expect(result!.title, 'Empty Artist');
      expect(result.trackList, isEmpty);
    });

    test('YouTubeMetadataProvider safely falls back to web channel metadata when API key is not configured', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'www.youtube.com' && request.url.path == '/@ricchiepoveriofficial') {
          return http.Response(
            '''
            <!DOCTYPE html>
            <html>
            <head>
              <meta property="og:title" content="Ricchi e Poveri - YouTube">
              <meta property="og:image" content="https://yt3.ggpht.com/ricchiepoveri_og.jpg">
            </head>
            <body></body>
            </html>
            ''',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        } else if (request.url.host == 'music.youtube.com' && request.url.path == '/youtubei/v1/search') {
          return http.Response('{"contents": {}}', 200, headers: {'content-type': 'application/json'});
        } else if (request.url.host == 'www.youtube.com' && request.url.path == '/results') {
          return http.Response('<html></html>', 200);
        }
        return http.Response('Not Found', 404);
      });

      // No API key provided (default compile-time empty string)
      final provider = YouTubeMetadataProvider(
        client: mockClient,
        apiKey: '',
      );

      final result = await provider.fetchMetadata('https://music.youtube.com/@ricchiepoveriofficial?si=Sf0TccxAeGd3zNKn');
      expect(result, isNotNull);
      expect(result!.provider, 'youtube');
      expect(result.title, 'Ricchi e Poveri');
      expect(result.artist, 'Ricchi e Poveri');
      expect(result.type, SpotifyEntityType.artist);
      expect(result.artistArtworkUrl, 'https://yt3.ggpht.com/ricchiepoveri_og.jpg');
    });

    test('YouTubeMetadataProvider handles network failure gracefully without crashing', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Network Error', 500);
      });

      final provider = YouTubeMetadataProvider(
        client: mockClient,
        apiKey: '',
      );

      final result = await provider.fetchMetadata('https://music.youtube.com/@ricchiepoveriofficial?si=Sf0TccxAeGd3zNKn');
      expect(result, isNotNull);
      expect(result!.provider, 'youtube');
      expect(result.title, 'ricchiepoveriofficial');
      expect(result.type, SpotifyEntityType.artist);
      expect(result.trackList, isEmpty);
    });

    test('LocalMusicRepository imports YouTube artist with songs and public upload album correctly', () async {
      const channelMetadata = MusicMetadataResult(
        provider: 'youtube',
        sourceId: 'UC_RICCHI_ID',
        sourceUrl: 'https://music.youtube.com/@ricchiepoveriofficial',
        title: 'Ricchi e Poveri Official',
        artist: 'Ricchi e Poveri Official',
        artists: ['Ricchi e Poveri Official'],
        artistArtworkUrl: 'https://yt3.ggpht.com/ricchiepoveri_high.jpg',
        type: SpotifyEntityType.artist,
        trackList: [
          MusicMetadataResult(
            provider: 'youtube',
            sourceId: 'yt_song_001',
            sourceUrl: 'https://music.youtube.com/watch?v=yt_song_001',
            title: 'Sara Perche Ti Amo',
            artist: 'Ricchi e Poveri Official',
            artists: ['Ricchi e Poveri Official'],
            album: 'Unggahan Publik',
            trackArtworkUrl: 'https://i.ytimg.com/vi/yt_song_001/hqdefault.jpg',
            type: SpotifyEntityType.track,
          ),
        ],
      );

      final summary = await repo.importMetadata(metadata: channelMetadata);
      expect(summary['artistsCreated'], 1);
      expect(summary['songsCreated'], 1);
      expect(summary['albumsCreated'], 1);

      // Verify Artist
      final artists = await repo.getArtists();
      expect(artists.length, 1);
      expect(artists.first.name, 'Ricchi e Poveri Official');
      expect(artists.first.youtubeId, 'UC_RICCHI_ID');
      expect(artists.first.image, 'https://yt3.ggpht.com/ricchiepoveri_high.jpg');

      // Verify Album
      final albums = await repo.getAlbumsByArtistId(artists.first.id);
      expect(albums.length, 1);
      expect(albums.first.title, 'Unggahan Publik');

      // Verify Song
      final songs = await repo.getSongsByArtistId(artists.first.id);
      expect(songs.length, 1);
      expect(songs.first.title, 'Sara Perche Ti Amo');
      expect(songs.first.cover, 'https://i.ytimg.com/vi/yt_song_001/hqdefault.jpg');
      expect(songs.first.cover, isNot(equals(artists.first.image)), reason: 'Track artwork must not equal artist profile photo');
    });

    test('LocalMusicRepository imports standalone YouTube artist without songs when trackList is empty', () async {
      const channelMetadata = MusicMetadataResult(
        provider: 'youtube',
        sourceId: 'UC_RICCHI_ID',
        sourceUrl: 'https://music.youtube.com/@ricchiepoveriofficial',
        title: 'Ricchi e Poveri Official',
        artist: 'Ricchi e Poveri Official',
        artists: ['Ricchi e Poveri Official'],
        artistArtworkUrl: 'https://yt3.ggpht.com/ricchiepoveri_high.jpg',
        type: SpotifyEntityType.artist,
        trackList: [],
      );

      final summary = await repo.importMetadata(metadata: channelMetadata);
      expect(summary['artistsCreated'], 1);
      expect(summary['songsCreated'], 0);
      expect(summary['albumsCreated'], 0);
    });

    test('Spotify artist import does not pollute artists catalog with collaborators', () async {
      // Artist profile import for "Ed Sheeran" featuring a song with "Justin Bieber"
      const artistProfileImport = MusicMetadataResult(
        provider: 'spotify',
        sourceId: 'sp_ed_sheeran',
        title: 'Ed Sheeran',
        artist: 'Ed Sheeran',
        artists: ['Ed Sheeran'],
        artistArtworkUrl: 'https://example.com/ed_sheeran.jpg',
        type: SpotifyEntityType.artist,
        trackList: [
          MusicMetadataResult(
            provider: 'spotify',
            sourceId: 'sp_track_idc',
            title: "I Don't Care",
            artist: 'Ed Sheeran & Justin Bieber',
            artists: ['Ed Sheeran', 'Justin Bieber'],
            artistList: [
              ArtistMetadataInfo(name: 'Ed Sheeran', id: 'sp_ed_sheeran', provider: 'spotify'),
              ArtistMetadataInfo(name: 'Justin Bieber', id: 'sp_justin_bieber', provider: 'spotify'),
            ],
            album: 'No.6 Collaborations Project',
            albumArtworkUrl: 'https://example.com/no6_cover.jpg',
            trackArtworkUrl: 'https://example.com/no6_cover.jpg',
            type: SpotifyEntityType.track,
          ),
        ],
      );

      final summary = await repo.importMetadata(metadata: artistProfileImport);
      expect(summary['artistsCreated'], 1, reason: 'Only Ed Sheeran should be created as artist in catalog');
      expect(summary['songsCreated'], 1);

      // Verify artists in catalog
      final artists = await repo.getArtists();
      expect(artists.length, 1);
      expect(artists.first.name, 'Ed Sheeran');
      expect(artists.first.spotifyId, 'sp_ed_sheeran');

      // Verify song keeps full collaborative credits in artistName
      final songs = await repo.getSongsByArtistId(artists.first.id);
      expect(songs.length, 1);
      expect(songs.first.title, "I Don't Care");
      expect(songs.first.artistName, contains('Justin Bieber'));
      expect(songs.first.artistId, artists.first.id);

      // Re-importing same artist with overwriteExisting = false must be completely idempotent
      final reimportSummary = await repo.importMetadata(metadata: artistProfileImport, overwriteExisting: false);
      expect(reimportSummary['artistsCreated'], 0);
      expect(reimportSummary['songsCreated'], 0);
      final allArtists = await repo.getArtists();
      expect(allArtists.length, 1);
    });
  });
}



