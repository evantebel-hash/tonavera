import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/widgets/v35/v35_track_actions.dart';
import 'package:mymusic/widgets/v35/v35_track_row.dart';

SongModel createTestSong(int id, String title, {String path = 'test.mp3'}) {
  return SongModel(
    id: id,
    artistId: 1,
    title: title,
    duration: 180,
    artistName: 'Test Artist',
    albumTitle: 'Test Album',
    audioPath: path,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V3.5 Track Context Actions — Queue Semantics', () {
    late PlayerProvider player;
    late SongModel songA;
    late SongModel songB;
    late SongModel songC;
    late SongModel songD;
    late SongModel songX;

    setUp(() {
      player = PlayerProvider();
      songA = createTestSong(1, 'Song A');
      songB = createTestSong(2, 'Song B');
      songC = createTestSong(3, 'Song C');
      songD = createTestSong(4, 'Song D');
      songX = createTestSong(99, 'Song X');
    });

    test('Putar Berikutnya: Inserts immediately after currently playing song', () {
      // Queue: [A, B (current), C, D]
      player.setQueueForTest([songA, songB, songC, songD], initialIndex: 1);
      expect(player.currentSong?.title, 'Song B');
      expect(player.currentIndex, 1);

      // Play Next X
      player.playNext(songX);

      // Expected queue: [A, B (current), X, C, D]
      final titles = player.queue.map((s) => s.title).toList();
      expect(titles, ['Song A', 'Song B', 'Song X', 'Song C', 'Song D']);
      // Still playing B, current index unchanged
      expect(player.currentSong?.title, 'Song B');
      expect(player.currentIndex, 1);
    });

    test('Tambah ke Antrean: Appends to end of existing queue without interrupting playback', () {
      // Queue: [A, B (current), C]
      player.setQueueForTest([songA, songB, songC], initialIndex: 1);
      expect(player.currentSong?.title, 'Song B');

      // Add to Queue X
      player.addToQueue(songX);

      // Expected queue: [A, B (current), C, X]
      final titles = player.queue.map((s) => s.title).toList();
      expect(titles, ['Song A', 'Song B', 'Song C', 'Song X']);
      // Playback untouched
      expect(player.currentSong?.title, 'Song B');
      expect(player.currentIndex, 1);
    });
  });

  group('V3.5 Track Context Actions — Sheet UI & Interaction', () {
    testWidgets('V35TrackRow renders more button and triggers callback', (tester) async {
      bool morePressed = false;
      final song = createTestSong(1, 'Melody 1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: V35TrackRow(
              title: song.title,
              artist: song.artistName,
              duration: '3:00',
              onMore: () {
                morePressed = true;
              },
            ),
          ),
        ),
      );

      final moreButton = find.byIcon(Icons.more_vert_rounded);
      expect(moreButton, findsOneWidget);

      await tester.tap(moreButton);
      await tester.pump();
      expect(morePressed, isTrue);
    });

    testWidgets('V35TrackActions.show renders minimum required actions', (tester) async {
      final player = PlayerProvider();
      final song = createTestSong(10, 'Bohemian Rhapsody');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  V35TrackActions.show(ctx, song: song, player: player);
                },
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      // Verify the minimum required actions are rendered
      expect(find.text('Putar Berikutnya'), findsOneWidget);
      expect(find.text('Tambah ke Antrean'), findsOneWidget);
      expect(find.text('Edit Metadata'), findsOneWidget);
      // Verify additional existing actions
      expect(find.text('Tambah ke Playlist'), findsOneWidget);

      // Tap Putar Berikutnya and check that sheet dismisses
      await tester.tap(find.text('Putar Berikutnya'));
      await tester.pumpAndSettle();

      expect(find.text('Putar Berikutnya'), findsNothing);
      expect(player.queue.contains(song), isTrue);
    });
  });
}
