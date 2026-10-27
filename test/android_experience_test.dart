import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/providers/player_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 6 - Android Experience Unit Tests', () {
    final sampleSong1 = SongModel(
      id: 1,
      artistId: 101,
      title: 'Track One',
      artistName: 'Artist A',
      albumTitle: 'Album X',
      duration: 180,
      audioPath: '/storage/music/track1.mp3',
      filePath: '/storage/music/track1.mp3',
      source: 'local',
    );

    final sampleSong2 = SongModel(
      id: 2,
      artistId: 102,
      title: 'Track Two',
      artistName: 'Artist B',
      albumTitle: 'Album Y',
      duration: 240,
      audioPath: '/storage/music/track2.mp3',
      filePath: '/storage/music/track2.mp3',
      source: 'local',
    );

    test('6.5 Resume Settings & Defaults', () {
      final provider = PlayerProvider();
      expect(provider.resumePlaybackEnabled, true);
      expect(provider.pauseOnHeadphoneDisconnect, true);
      expect(provider.notificationPlayerEnabled, true);

      provider.setResumePlaybackEnabled(false);
      expect(provider.resumePlaybackEnabled, false);

      provider.setPauseOnHeadphoneDisconnect(false);
      expect(provider.pauseOnHeadphoneDisconnect, false);

      provider.setNotificationPlayerEnabled(false);
      expect(provider.notificationPlayerEnabled, false);
    });

    test('6.5 Queue Restoration & Navigation Alignment', () async {
      final provider = PlayerProvider();
      provider.setQueueForTest([sampleSong1, sampleSong2], initialIndex: 1);

      expect(provider.currentSong?.id, 2);
      expect(provider.currentIndex, 1);
      expect(provider.queue.length, 2);
    });

    test('6.3 Headset Disconnect Setting Toggle', () {
      final provider = PlayerProvider();
      expect(provider.pauseOnHeadphoneDisconnect, isTrue);
      provider.setPauseOnHeadphoneDisconnect(false);
      expect(provider.pauseOnHeadphoneDisconnect, isFalse);
    });
  });
}
