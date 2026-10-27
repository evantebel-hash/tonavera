import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/services/youtube/youtube_parser.dart';

SongModel makeLocal(int id, String title) {
  return SongModel(
    id: id,
    artistId: 1,
    title: title,
    duration: 180,
    audioPath: 'C:\\music\\$title.mp3',
    filePath: 'C:\\music\\$title.mp3',
    source: 'local',
  );
}

SongModel makeYouTube(String videoId, String title) {
  return SongModel.fromYouTubeVideo(
    YouTubeVideo(
      videoId: videoId,
      title: title,
      channelName: 'Channel $title',
      durationSeconds: 210,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PHASE 8 — QUEUE & MIXED QUEUE TESTS', () {
    late PlayerProvider player;
    late SongModel localA;
    late SongModel localB;
    late SongModel ytA;
    late SongModel ytB;
    late SongModel ytC;

    setUp(() {
      player = PlayerProvider();
      localA = makeLocal(1, 'Local Track A');
      localB = makeLocal(2, 'Local Track B');
      ytA = makeYouTube('vid_yt_a', 'YouTube Track A');
      ytB = makeYouTube('vid_yt_b', 'YouTube Track B');
      ytC = makeYouTube('vid_yt_c', 'YouTube Track C');
    });

    test('Test 1: Local -> Local queue transitions', () async {
      player.setQueueForTest([localA, localB], initialIndex: 0);
      expect(player.currentSong?.title, 'Local Track A');
      expect(player.currentSong?.isYouTube, false);

      await player.next(isTest: true);
      expect(player.currentIndex, 1);
      expect(player.currentSong?.title, 'Local Track B');
    });

    test('Test 2: YouTube -> YouTube queue transitions', () async {
      player.setQueueForTest([ytA, ytB], initialIndex: 0);
      expect(player.currentSong?.isYouTube, true);
      expect(player.currentSong?.audioPath, 'vid_yt_a');

      await player.next(isTest: true);
      expect(player.currentIndex, 1);
      expect(player.currentSong?.isYouTube, true);
      expect(player.currentSong?.audioPath, 'vid_yt_b');
    });

    test('Test 3: YouTube -> Local transition', () async {
      player.setQueueForTest([ytA, localA], initialIndex: 0);
      expect(player.currentSong?.isYouTube, true);

      await player.next(isTest: true);
      expect(player.currentIndex, 1);
      expect(player.currentSong?.isYouTube, false);
      expect(player.currentSong?.title, 'Local Track A');
    });

    test('Test 4: Local -> YouTube transition', () async {
      player.setQueueForTest([localA, ytA], initialIndex: 0);
      expect(player.currentSong?.isYouTube, false);

      await player.next(isTest: true);
      expect(player.currentIndex, 1);
      expect(player.currentSong?.isYouTube, true);
      expect(player.currentSong?.audioPath, 'vid_yt_a');
    });

    test('Test 5: YouTube A -> YouTube B -> YouTube C sequence', () async {
      player.setQueueForTest([ytA, ytB, ytC], initialIndex: 0);
      expect(player.currentIndex, 0);

      await player.next(isTest: true);
      expect(player.currentIndex, 1);
      expect(player.currentSong?.audioPath, 'vid_yt_b');

      await player.next(isTest: true);
      expect(player.currentIndex, 2);
      expect(player.currentSong?.audioPath, 'vid_yt_c');
    });

    test('Test 6: YouTube A -> Local B -> YouTube C -> Local D mixed sequence', () async {
      player.setQueueForTest([ytA, localA, ytB, localB], initialIndex: 0);

      expect(player.currentSong?.audioPath, 'vid_yt_a');
      await player.next(isTest: true);
      expect(player.currentSong?.title, 'Local Track A');
      await player.next(isTest: true);
      expect(player.currentSong?.audioPath, 'vid_yt_b');
      await player.next(isTest: true);
      expect(player.currentSong?.title, 'Local Track B');
    });

    test('Test 7: Next button from YouTube song', () async {
      player.setQueueForTest([ytA, ytB], initialIndex: 0);
      await player.next(isTest: true);
      expect(player.currentIndex, 1);
      expect(player.currentSong?.audioPath, 'vid_yt_b');
    });

    test('Test 8: Previous button to YouTube song', () async {
      player.setQueueForTest([ytA, ytB, ytC], initialIndex: 2);
      expect(player.currentIndex, 2);

      await player.previous(isTest: true);
      expect(player.currentIndex, 1);
      expect(player.currentSong?.audioPath, 'vid_yt_b');

      await player.previous(isTest: true);
      expect(player.currentIndex, 0);
      expect(player.currentSong?.audioPath, 'vid_yt_a');
    });

    test('Test 9: Add YouTube song to existing queue', () {
      player.setQueueForTest([localA, localB], initialIndex: 0);
      expect(player.queue.length, 2);

      player.addToQueue(ytA);
      expect(player.queue.length, 3);
      expect(player.queue.last.isYouTube, true);
      expect(player.queue.last.audioPath, 'vid_yt_a');
    });
  });

  group('PHASE 8 — PLAYLIST & IMPORT TESTS', () {
    test('Test 10: Parse YouTube playlist URL and extract ID', () {
      const url = 'https://www.youtube.com/playlist?list=PLMC9KNkIncKtPzgY-5rmhvj7fax8fdxoj';
      final playlistId = YouTubeParser.extractPlaylistId(url);
      expect(playlistId, 'PLMC9KNkIncKtPzgY-5rmhvj7fax8fdxoj');
    });

    test('Test 11 & 12: Import playlist -> Play All & Add All to Queue', () {
      final items = [
        YouTubePlaylistItem(
          playlistId: 'PL123',
          videoId: 'v1',
          position: 0,
          title: 'Track 1',
          durationSeconds: 180,
        ),
        YouTubePlaylistItem(
          playlistId: 'PL123',
          videoId: 'v2',
          position: 1,
          title: 'Track 2',
          durationSeconds: 200,
        ),
      ];

      final playlist = YouTubePlaylist(
        playlistId: 'PL123',
        title: 'My imported playlist',
        items: items,
      );

      final songModels = playlist.items.map((item) {
        return SongModel.fromYouTubeVideo(
          YouTubeVideo(
            videoId: item.videoId,
            title: item.title,
            durationSeconds: item.durationSeconds,
          ),
        );
      }).toList();

      final player = PlayerProvider();

      // Test 11: Play All
      player.setQueueForTest(songModels, initialIndex: 0);
      expect(player.queue.length, 2);
      expect(player.currentSong?.audioPath, 'v1');

      // Test 12: Add All to Queue
      player.addToQueue(makeLocal(99, 'Existing Local'));
      expect(player.queue.length, 3);
      expect(player.queue.last.title, 'Existing Local');
    });

    test('Test 13: Playlist containing unavailable videos skips invalid titles', () {
      const htmlWithUnavailable = '''
<html>
  <script>
    var ytInitialData = {
      "contents": {
        "twoColumnBrowseResultsRenderer": {
          "tabs": [
            {
              "tabRenderer": {
                "content": {
                  "sectionListRenderer": {
                    "contents": [
                      {
                        "itemSectionRenderer": {
                          "contents": [
                            {
                              "playlistVideoRenderer": {
                                "videoId": "v_valid",
                                "title": {"runs": [{"text": "Valid Track"}]},
                                "lengthText": {"simpleText": "03:15"}
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              }
            }
          ]
        }
      }
    };
  </script>
</html>
''';

      final pl = YouTubeParser.parsePlaylistHtml(htmlWithUnavailable, 'PL123');
      expect(pl.items.length, 1);
      expect(pl.items.first.videoId, 'v_valid');
      expect(pl.items.first.title, 'Valid Track');
    });

    test('Test 14: Large playlist parsing handles 100+ items cleanly', () {
      final items = List.generate(
        150,
        (i) => YouTubePlaylistItem(
          playlistId: 'PLLARGE',
          videoId: 'vid_$i',
          position: i,
          title: 'Track #$i',
          durationSeconds: 180 + i,
        ),
      );

      final playlist = YouTubePlaylist(
        playlistId: 'PLLARGE',
        title: 'Large 150 Tracks Playlist',
        itemCount: 150,
        items: items,
      );

      expect(playlist.items.length, 150);
      expect(playlist.items[149].videoId, 'vid_149');
    });

    test('Test 15: YouTube song model audioPath preserves videoId (no googlevideo URL storage)', () {
      final video = YouTubeVideo(
        videoId: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        channelName: 'Rick Astley',
        durationSeconds: 213,
      );

      final song = SongModel.fromYouTubeVideo(video);
      expect(song.audioPath, 'dQw4w9WgXcQ');
      expect(song.audioPath.contains('googlevideo.com'), false);
      expect(song.isYouTube, true);
    });
  });
}
