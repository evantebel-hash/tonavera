import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/providers/player_provider.dart';

SongModel createTestSong(int id, String title) {
  return SongModel(
    id: id,
    artistId: 1,
    title: title,
    duration: 180,
    artistName: 'Test Artist',
    albumTitle: 'Test Album',
    audioPath: 'test.mp3',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerProvider player;
  late SongModel songA;
  late SongModel songB;
  late SongModel songC;

  setUp(() {
    player = PlayerProvider();
    songA = createTestSong(1, 'Song A');
    songB = createTestSong(2, 'Song B');
    songC = createTestSong(3, 'Song C');
  });

  test('Repeat OFF mode test', () {
    player.setQueueForTest([songA, songB, songC], initialIndex: 0);
    player.setRepeatMode(AppRepeatMode.off);

    expect(player.repeatMode, AppRepeatMode.off);
    expect(player.loopMode, LoopMode.off);
  });

  test('Repeat ONE mode test', () {
    player.setQueueForTest([songA, songB, songC], initialIndex: 0);
    player.setRepeatMode(AppRepeatMode.one);

    expect(player.repeatMode, AppRepeatMode.one);
    expect(player.loopMode, LoopMode.one);
  });

  test('Repeat FOREVER mode test', () {
    player.setQueueForTest([songA, songB, songC], initialIndex: 0);
    player.setRepeatMode(AppRepeatMode.forever);

    expect(player.repeatMode, AppRepeatMode.forever);
    expect(player.loopMode, LoopMode.all);
  });

  test('Repeat COUNT 3x decrement and completion test', () async {
    player.setQueueForTest([songA, songB], initialIndex: 0);
    player.setRepeatMode(AppRepeatMode.count, count: 3);

    expect(player.repeatMode, AppRepeatMode.count);
    expect(player.targetRepeatCount, 3);
    expect(player.remainingRepeatCount, 3);

    // 1st next() call -> 1st repeat (remaining: 2)
    await player.next(isTest: true);
    expect(player.currentSong?.title, 'Song A');
    expect(player.remainingRepeatCount, 2);

    // 2nd next() call -> 2nd repeat (remaining: 1)
    await player.next(isTest: true);
    expect(player.currentSong?.title, 'Song A');
    expect(player.remainingRepeatCount, 1);

    // 3rd next() call -> 3rd repeat (remaining: 0)
    await player.next(isTest: true);
    expect(player.currentSong?.title, 'Song A');
    expect(player.remainingRepeatCount, 0);

    // 4th next() call -> proceed to Song B!
    await player.next(isTest: true);
    expect(player.currentSong?.title, 'Song B');
    expect(player.remainingRepeatCount, 3);
  });

  test('Next obeys repeat count N times before advancing to next song', () async {
    player.setQueueForTest([songA, songB, songC], initialIndex: 0);
    player.setRepeatMode(AppRepeatMode.count, count: 2);

    expect(player.remainingRepeatCount, 2);

    await player.next(isTest: true); // 1st repeat
    expect(player.currentSong?.title, 'Song A');
    expect(player.remainingRepeatCount, 1);

    await player.next(isTest: true); // 2nd repeat
    expect(player.currentSong?.title, 'Song A');
    expect(player.remainingRepeatCount, 0);

    await player.next(isTest: true); // Now advances to Song B
    expect(player.currentSong?.title, 'Song B');
    expect(player.remainingRepeatCount, 2);
  });

  test('Manual Previous resets repeat count for new song', () async {
    player.setQueueForTest([songA, songB, songC], initialIndex: 1); // Current = B
    player.setRepeatMode(AppRepeatMode.count, count: 3);

    await player.previous(isTest: true); // Go to songA

    expect(player.currentSong?.title, 'Song A');
    expect(player.remainingRepeatCount, 3);
  });

  test('Shuffle + Repeat interaction test', () {
    player.setQueueForTest([songA, songB, songC], initialIndex: 0);
    player.setRepeatMode(AppRepeatMode.count, count: 2);
    player.toggleShuffle();

    expect(player.isShuffle, isTrue);
    expect(player.repeatMode, AppRepeatMode.count);
    expect(player.targetRepeatCount, 2);
  });

  test('Queue reorder + Repeat interaction test', () {
    player.setQueueForTest([songA, songB, songC], initialIndex: 0);
    player.setRepeatMode(AppRepeatMode.count, count: 3);

    player.reorderQueue(2, 0); // Move C to start

    expect(player.repeatMode, AppRepeatMode.count);
    expect(player.targetRepeatCount, 3);
    expect(player.currentSong?.title, 'Song A');
  });

  test('Queue remove + Repeat interaction test', () {
    player.setQueueForTest([songA, songB, songC], initialIndex: 1); // Current = B
    player.setRepeatMode(AppRepeatMode.count, count: 3);

    player.removeFromQueue(0); // Remove A

    expect(player.repeatMode, AppRepeatMode.count);
    expect(player.currentSong?.title, 'Song B');
    expect(player.currentIndex, 0);
  });
}
