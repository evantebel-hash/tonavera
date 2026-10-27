import 'package:flutter_test/flutter_test.dart';
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
  late SongModel songD;
  late SongModel songE;

  setUp(() {
    player = PlayerProvider();
    songA = createTestSong(1, 'Song A');
    songB = createTestSong(2, 'Song B');
    songC = createTestSong(3, 'Song C');
    songD = createTestSong(4, 'Song D');
    songE = createTestSong(5, 'Song E');
  });

  test('CASE 1: Move A to after D in [A,B,C,D,E]', () {
    final playlist = [songA, songB, songC, songD, songE];
    player.setQueueForTest(playlist, initialIndex: 0);

    // Reorder A (index 0) to after D (index 3, Flutter passes newIndex = 4)
    player.reorderQueue(0, 4);

    final queueTitles = player.queue.map((s) => s.title).toList();
    expect(queueTitles, ['Song B', 'Song C', 'Song D', 'Song A', 'Song E']);
  });

  test('CASE 2: Move A to after D with Current = C', () {
    final playlist = [songA, songB, songC, songD, songE];
    player.setQueueForTest(playlist, initialIndex: 2); // Current = C (index 2)

    player.reorderQueue(0, 4); // Move A to after D

    final queueTitles = player.queue.map((s) => s.title).toList();
    expect(queueTitles, ['Song B', 'Song C', 'Song D', 'Song A', 'Song E']);
    expect(player.currentSong?.title, 'Song C');
    expect(player.currentIndex, 1);
  });

  test('CASE 3: Move D to before A with Current = C', () {
    final playlist = [songA, songB, songC, songD, songE];
    player.setQueueForTest(playlist, initialIndex: 2); // Current = C (index 2)

    player.reorderQueue(3, 0); // Move D (index 3) to before A (index 0)

    final queueTitles = player.queue.map((s) => s.title).toList();
    expect(queueTitles, ['Song D', 'Song A', 'Song B', 'Song C', 'Song E']);
    expect(player.currentSong?.title, 'Song C');
    expect(player.currentIndex, 3);
  });

  test('CASE 4: Move C to after E with Current = C', () {
    final playlist = [songA, songB, songC, songD, songE];
    player.setQueueForTest(playlist, initialIndex: 2); // Current = C (index 2)

    player.reorderQueue(2, 5); // Move C (index 2) to after E (index 4, newIndex = 5)

    final queueTitles = player.queue.map((s) => s.title).toList();
    expect(queueTitles, ['Song A', 'Song B', 'Song D', 'Song E', 'Song C']);
    expect(player.currentSong?.title, 'Song C');
    expect(player.currentIndex, 4);
  });

  test('CASE 5: Remove A from [A,B,C,D] with Current = C', () {
    final playlist = [songA, songB, songC, songD];
    player.setQueueForTest(playlist, initialIndex: 2); // Current = C (index 2)

    player.removeFromQueue(0); // Remove A

    final queueTitles = player.queue.map((s) => s.title).toList();
    expect(queueTitles, ['Song B', 'Song C', 'Song D']);
    expect(player.currentSong?.title, 'Song C');
    expect(player.currentIndex, 1);
  });

  test('CASE 6: Next song follows new queue order after reorder', () {
    final playlist = [songA, songB, songC, songD, songE];
    player.setQueueForTest(playlist, initialIndex: 0); // Current = A (index 0)

    // Move D to after A -> [A, D, B, C, E]
    player.reorderQueue(3, 1);

    final queueTitles = player.queue.map((s) => s.title).toList();
    expect(queueTitles, ['Song A', 'Song D', 'Song B', 'Song C', 'Song E']);

    // Next song should be D (index 1)
    final nextIndex = player.currentIndex + 1;
    expect(player.queue[nextIndex].title, 'Song D');
  });
}
