import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'services/mymusic_audio_handler.dart';
import 'services/audio/android_diagnostic_logger.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/history_provider.dart';
import 'providers/listening_statistics_provider.dart';
import 'providers/youtube_provider.dart';
import 'providers/spotify_provider.dart';
import 'providers/import_metadata_provider.dart';
import 'core/auth/auth_gate.dart';

import 'database/local_database_service.dart';
import 'services/one_time_migration_service.dart';
import 'core/theme/v35_accent.dart';
import 'core/theme/v35_theme.dart';

import 'widgets/desktop/floating_mini_player_window.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global uncaught error capture for Android diagnostic inspection
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (Platform.isAndroid) {
      AndroidDiagnosticLogger.instance.recordError(
        'UNCAUGHT_FLUTTER_ERROR',
        details.exceptionAsString(),
        details.stack,
      );
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[CRASH_GUARD] Uncaught asynchronous error: $error\n$stack');
    if (Platform.isAndroid) {
      AndroidDiagnosticLogger.instance.recordError(
        'UNCAUGHT_ASYNC_ERROR',
        error,
        stack,
      );
    }
    return true; // prevent hard crash if possible
  };

  // If invoked as a secondary desktop multi-window, launch the Mini Player Standalone App
  if (args.isNotEmpty && args.first == 'multi_window') {
    final windowId = args.length > 1 ? args[1] : '0';
    await V35Accent.init();
    runApp(MiniPlayerStandaloneApp(windowId: windowId));
    return;
  }

  if (Platform.isAndroid) {
    await AudioService.init(
      builder: () => MyMusicAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.mymusic.channel.audio',
        androidNotificationChannelName: 'MyMusic Playback',
        androidNotificationOngoing: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: true,
        androidResumeOnClick: true,
        fastForwardInterval: Duration(seconds: 10),
        rewindInterval: Duration(seconds: 10),
      ),
    );
  }
  await LocalDatabaseService.instance.init();
  await OneTimeMigrationService.migrateIfNeeded();
  await V35Accent.init();
  runApp(const MyMusicApp());
}

class MyMusicApp extends StatelessWidget {
  const MyMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..checkAuthStatus(),
        ),
        ChangeNotifierProvider(
          create: (_) => CatalogProvider()..fetchCatalogData(),
        ),
        ChangeNotifierProvider(
          create: (_) => PlayerProvider()..restorePlayerState(),
        ),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(
          create: (_) => ListeningStatisticsProvider()..fetchAll(),
        ),
        ChangeNotifierProvider(
          create: (_) => YouTubeProvider()..fetchSavedPlaylists(),
        ),
        ChangeNotifierProvider(create: (_) => SpotifyProvider()),
        ChangeNotifierProvider(create: (_) => ImportMetadataProvider()),
      ],
      child: ValueListenableBuilder<V35AccentPalette>(
        valueListenable: V35Accent.notifier,
        builder: (context, activeAccent, child) {
          return MaterialApp(
            title: 'TONAVERA',
            debugShowCheckedModeBanner: false,
            theme: V35Theme.darkTheme,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
