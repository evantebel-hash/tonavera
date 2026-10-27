import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/widgets/dialogs/equalizer_dialog.dart';
import 'package:mymusic/widgets/dialogs/sleep_timer_dialog.dart';
import 'package:mymusic/widgets/dialogs/playback_speed_dialog.dart';
import 'package:mymusic/widgets/dialogs/crossfade_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EqualizerDialog builds correctly inside SettingsDetailDialog', (WidgetTester tester) async {
    final player = PlayerProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerProvider>.value(
        value: player,
        child: const MaterialApp(
          home: Scaffold(
            body: EqualizerDialog(),
          ),
        ),
      ),
    );

    expect(find.text('Equalizer'), findsOneWidget);
    expect(find.text('Preset:'), findsOneWidget);
    expect(find.text('60 Hz'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
  });

  testWidgets('SleepTimerDialog builds correctly inside SettingsDetailDialog', (WidgetTester tester) async {
    final player = PlayerProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerProvider>.value(
        value: player,
        child: const MaterialApp(
          home: Scaffold(
            body: SleepTimerDialog(),
          ),
        ),
      ),
    );

    expect(find.text('Sleep Timer'), findsOneWidget);
    expect(find.text('Off (Matikan Timer)'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
  });

  testWidgets('PlaybackSpeedDialog builds correctly inside SettingsDetailDialog', (WidgetTester tester) async {
    final player = PlayerProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerProvider>.value(
        value: player,
        child: const MaterialApp(
          home: Scaffold(
            body: PlaybackSpeedDialog(),
          ),
        ),
      ),
    );

    expect(find.text('Kecepatan Putar'), findsOneWidget);
    expect(find.text('1.0x (Normal)'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
  });

  testWidgets('CrossfadeDialog builds correctly inside SettingsDetailDialog', (WidgetTester tester) async {
    final player = PlayerProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerProvider>.value(
        value: player,
        child: const MaterialApp(
          home: Scaffold(
            body: CrossfadeDialog(),
          ),
        ),
      ),
    );

    expect(find.text('Crossfade'), findsOneWidget);
    expect(find.text('Durasi Crossfade:'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
  });
}
