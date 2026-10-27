import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/player_provider.dart';
import '../../core/theme/v35_accent.dart';

/// Service managing Windows Desktop Native Integration:
/// 5.1 Global Media Keys
/// 5.2 Mini Player Window Mode & Multi-Window Floating Player
/// 5.3 System Tray & Minimize-to-Tray
/// 5.4 Drag & Drop Global Files Hook
class DesktopIntegrationService {
  static const MethodChannel _channel = MethodChannel(
    'com.mymusic.desktop/integration',
  );
  static const WindowMethodChannel _multiChannel = WindowMethodChannel(
    'com.mymusic.mini_player_channel',
    mode: ChannelMode.bidirectional,
  );

  static final DesktopIntegrationService instance =
      DesktopIntegrationService._internal();

  DesktopIntegrationService._internal();

  bool _initialized = false;
  bool _accentListenerAttached = false;
  PlayerProvider? _playerProvider;
  void Function(List<String> paths)? _onFilesDroppedCallback;
  VoidCallback? _onToggleMiniPlayerCallback;
  VoidCallback? _onOpenQueueCallback;
  VoidCallback? _onOpenFullPlayerCallback;
  WindowController? _miniPlayerWindowController;

  // Settings
  bool _globalMediaKeysEnabled = true;
  bool _systemTrayEnabled = true;
  bool _minimizeToTrayEnabled = false;
  bool _alwaysOnTop = false;
  bool _isMiniPlayerMode = false;
  final ValueNotifier<bool> miniPlayerNotifier = ValueNotifier<bool>(false);

  // Test mode flag
  bool isTestMode = false;

  // Getters
  bool get isDesktop => !kIsWeb && Platform.isWindows;
  bool get globalMediaKeysEnabled => _globalMediaKeysEnabled;
  bool get systemTrayEnabled => _systemTrayEnabled;
  bool get minimizeToTrayEnabled => _minimizeToTrayEnabled;
  bool get alwaysOnTop => _alwaysOnTop;
  bool get isMiniPlayerMode => _isMiniPlayerMode;

  // Prefs keys
  static const String keyMediaKeys = 'desktop_global_media_keys';
  static const String keySystemTray = 'desktop_system_tray';
  static const String keyMinimizeToTray = 'desktop_minimize_to_tray';
  static const String keyAlwaysOnTop = 'desktop_always_on_top';
  static const String keyMiniPlayerMode = 'desktop_mini_player_mode';

  // Throttle state broadcasting
  DateTime _lastBroadcastTime = DateTime.fromMillisecondsSinceEpoch(0);
  int? _lastSongId;
  bool? _lastIsPlaying;
  bool? _lastIsFavorite;

  /// Initializes the desktop integration with SharedPreferences and PlayerProvider
  Future<void> init({PlayerProvider? playerProvider}) async {
    if (!isDesktop) return;

    _playerProvider = playerProvider;
    _attachPlayerListener();
    _setupCrossWindowChannel();

    if (!_accentListenerAttached) {
      V35Accent.notifier.addListener(_broadcastThemeToMiniPlayer);
      _accentListenerAttached = true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _globalMediaKeysEnabled = prefs.getBool(keyMediaKeys) ?? true;
      _systemTrayEnabled = prefs.getBool(keySystemTray) ?? true;
      _minimizeToTrayEnabled = prefs.getBool(keyMinimizeToTray) ?? false;
      _alwaysOnTop = prefs.getBool(keyAlwaysOnTop) ?? false;
      _isMiniPlayerMode = prefs.getBool(keyMiniPlayerMode) ?? false;
      miniPlayerNotifier.value = _isMiniPlayerMode;

      if (!_initialized) {
        _channel.setMethodCallHandler(_handleNativeMethodCall);
        _initialized = true;
      }

      await _applySettingsToNative();

      // Prewarm Mini Player window asynchronously without blocking main UI
      if (isDesktop && !isTestMode) {
        Future.delayed(const Duration(milliseconds: 2000), () {
          _prewarmMiniPlayerWindow();
        });
      }
    } catch (e) {
      debugPrint('DesktopIntegrationService: Init error: $e');
    }
  }

  Future<void> _prewarmMiniPlayerWindow() async {
    if (!isDesktop || isTestMode) return;
    try {
      if (_miniPlayerWindowController == null) {
        _miniPlayerWindowController = await WindowController.create(
          const WindowConfiguration(
            arguments: 'mini_player',
            hiddenAtLaunch: true,
          ),
        );
        await _miniPlayerWindowController?.hide();
      }
    } catch (e) {
      debugPrint('DesktopIntegrationService: Prewarm error: $e');
    }
  }

  void _attachPlayerListener() {
    _playerProvider?.removeListener(_broadcastStateToMiniPlayer);
    _playerProvider?.addListener(_broadcastStateToMiniPlayer);
  }

  void _setupCrossWindowChannel() {
    if (isTestMode) return;
    try {
      _multiChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'getPlaybackState':
            return {
              'isPlaying': _playerProvider?.isPlaying ?? false,
              'title': _playerProvider?.currentSong?.title ?? 'Tidak Ada Lagu',
              'artist': _playerProvider?.currentSong?.artistName ?? 'TONAVERA',
              'cover': _playerProvider?.currentSong?.cover,
              'durationMs': _playerProvider?.duration.inMilliseconds ?? 0,
              'positionMs': _playerProvider?.position.inMilliseconds ?? 0,
              'isFavorite': _playerProvider?.currentSong?.isFavorite ?? false,
              'theme': {
                'id': V35Accent.current.id,
                'name': V35Accent.current.name,
                'mode': V35Accent.current.mode.name,
                'base': V35Accent.current.base.toARGB32(),
                'bright': V35Accent.current.bright.toARGB32(),
                'deep': V35Accent.current.deep.toARGB32(),
              },
            };
          case 'togglePlayPause':
            await _playerProvider?.togglePlayPause();
            _broadcastStateToMiniPlayer(force: true);
            return true;
          case 'next':
            await _playerProvider?.next();
            _broadcastStateToMiniPlayer(force: true);
            return true;
          case 'previous':
            await _playerProvider?.previous();
            _broadcastStateToMiniPlayer(force: true);
            return true;
          case 'seek':
            if (call.arguments is Map) {
              final posMs = (call.arguments['position'] as num?)?.toInt() ?? 0;
              await _playerProvider?.seek(Duration(milliseconds: posMs));
              _broadcastStateToMiniPlayer(force: true);
            }
            return true;
          case 'toggleFavorite':
            if (_playerProvider?.currentSong != null) {
              await _playerProvider?.toggleFavorite(
                _playerProvider!.currentSong!,
              );
              _broadcastStateToMiniPlayer(force: true);
            }
            return true;
          case 'addToQueue':
            if (_playerProvider?.currentSong != null) {
              _playerProvider!.addToQueue(_playerProvider!.currentSong!);
              return true;
            }
            return false;
          case 'openQueue':
            await restoreWindow();
            _onOpenQueueCallback?.call();
            return true;
          case 'openFullPlayer':
            await restoreWindow();
            _onOpenFullPlayerCallback?.call();
            return true;
          case 'onMiniPlayerClosed':
            _isMiniPlayerMode = false;
            miniPlayerNotifier.value = false;
            // DO NOT null out _miniPlayerWindowController!
            // Retain the cached engine/window so reopening is 0ms instant!
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(keyMiniPlayerMode, false);
            _onToggleMiniPlayerCallback?.call();
            return true;
        }
        return null;
      });
    } catch (_) {}
  }

  void _broadcastStateToMiniPlayer({bool force = false}) {
    if (!isDesktop || isTestMode) return;

    final currentSong = _playerProvider?.currentSong;
    final isPlaying = _playerProvider?.isPlaying ?? false;
    final isFavorite = currentSong?.isFavorite ?? false;
    final now = DateTime.now();

    final stateChanged =
        currentSong?.id != _lastSongId ||
        isPlaying != _lastIsPlaying ||
        isFavorite != _lastIsFavorite;

    if (!force &&
        !stateChanged &&
        now.difference(_lastBroadcastTime).inMilliseconds < 1000) {
      // Throttled: Mini player advances its own local 1s ticker smoothly
      return;
    }

    _lastSongId = currentSong?.id;
    _lastIsPlaying = isPlaying;
    _lastIsFavorite = isFavorite;
    _lastBroadcastTime = now;

    try {
      _multiChannel.invokeMethod('updateState', {
        'isPlaying': isPlaying,
        'title': currentSong?.title ?? 'Tidak Ada Lagu',
        'artist': currentSong?.artistName ?? 'TONAVERA',
        'cover': currentSong?.cover,
        'durationMs': _playerProvider?.duration.inMilliseconds ?? 0,
        'positionMs': _playerProvider?.position.inMilliseconds ?? 0,
        'isFavorite': isFavorite,
        'theme': {
          'id': V35Accent.current.id,
          'name': V35Accent.current.name,
          'mode': V35Accent.current.mode.name,
          'base': V35Accent.current.base.toARGB32(),
          'bright': V35Accent.current.bright.toARGB32(),
          'deep': V35Accent.current.deep.toARGB32(),
        },
      });
    } catch (_) {}
  }

  void _broadcastThemeToMiniPlayer() {
    if (!isDesktop || isTestMode) return;
    try {
      final current = V35Accent.current;
      _multiChannel.invokeMethod('updateTheme', {
        'id': current.id,
        'name': current.name,
        'mode': current.mode.name,
        'base': current.base.toARGB32(),
        'bright': current.bright.toARGB32(),
        'deep': current.deep.toARGB32(),
      });
    } catch (_) {}
  }

  void updatePlayerProvider(PlayerProvider player) {
    _playerProvider = player;
    _attachPlayerListener();
  }

  void setFilesDroppedCallback(void Function(List<String> paths)? callback) {
    _onFilesDroppedCallback = callback;
  }

  void setToggleMiniPlayerCallback(VoidCallback? callback) {
    _onToggleMiniPlayerCallback = callback;
  }

  void setOpenQueueCallback(VoidCallback? callback) {
    _onOpenQueueCallback = callback;
  }

  void setOpenFullPlayerCallback(VoidCallback? callback) {
    _onOpenFullPlayerCallback = callback;
  }

  Future<void> _applySettingsToNative() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod(
        'setGlobalMediaKeysEnabled',
        _globalMediaKeysEnabled,
      );
      await _channel.invokeMethod('setSystemTrayEnabled', {
        'enabled': _systemTrayEnabled,
        'tooltip': 'TONAVERA — Local-First Music Player',
      });
      await _channel.invokeMethod('setMinimizeToTray', _minimizeToTrayEnabled);
      await _channel.invokeMethod('setAlwaysOnTop', _alwaysOnTop);
    } catch (e) {
      debugPrint('DesktopIntegrationService: Apply settings error: $e');
    }
  }

  // --- Setting Mutators ---

  Future<void> setGlobalMediaKeysEnabled(bool enabled) async {
    _globalMediaKeysEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyMediaKeys, enabled);
    if (isDesktop) {
      try {
        await _channel.invokeMethod('setGlobalMediaKeysEnabled', enabled);
      } catch (_) {}
    }
  }

  Future<void> setSystemTrayEnabled(bool enabled) async {
    _systemTrayEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keySystemTray, enabled);
    if (isDesktop) {
      try {
        await _channel.invokeMethod('setSystemTrayEnabled', {
          'enabled': enabled,
          'tooltip': 'TONAVERA',
        });
      } catch (_) {}
    }
  }

  Future<void> setMinimizeToTray(bool enabled) async {
    _minimizeToTrayEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyMinimizeToTray, enabled);
    if (isDesktop) {
      try {
        await _channel.invokeMethod('setMinimizeToTray', enabled);
      } catch (_) {}
    }
  }

  Future<void> setAlwaysOnTop(bool enabled) async {
    _alwaysOnTop = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyAlwaysOnTop, enabled);
    if (isDesktop) {
      try {
        await _channel.invokeMethod('setAlwaysOnTop', enabled);
      } catch (_) {}
    }
  }

  Future<void> setMiniPlayerMode(bool isMini) async {
    _isMiniPlayerMode = isMini;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyMiniPlayerMode, isMini);

    miniPlayerNotifier.value = isMini;
    _onToggleMiniPlayerCallback?.call();

    // The Mini Player MUST NOT resize or minimize the main MyMusic application.
    // The main window stays at its current size, position, and layout completely intact.
    // On desktop, it opens/shows a separate floating Mini Player window.
    if (isDesktop && !isTestMode) {
      try {
        if (isMini) {
          _miniPlayerWindowController ??= await WindowController.create(
            const WindowConfiguration(
              arguments: 'mini_player',
              hiddenAtLaunch: false,
            ),
          );
          await _miniPlayerWindowController?.show();
          _broadcastStateToMiniPlayer(force: true);
        } else {
          if (_miniPlayerWindowController != null) {
            try {
              await _miniPlayerWindowController?.hide();
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('DesktopIntegrationService: setMiniPlayerMode error: $e');
      }
    }
  }

  Future<void> restoreWindow() async {
    if (isDesktop) {
      try {
        await _channel.invokeMethod('restoreWindow');
      } catch (_) {}
    }
  }

  Future<void> hideWindow() async {
    if (isDesktop) {
      try {
        await _channel.invokeMethod('hideWindow');
      } catch (_) {}
    }
  }

  Future<void> minimizeWindow() async {
    if (isDesktop) {
      try {
        await _channel.invokeMethod('minimizeWindow');
      } catch (_) {}
    }
  }

  Future<void> closeApp() async {
    if (isDesktop) {
      try {
        await _miniPlayerWindowController?.hide();
      } catch (_) {}
      try {
        await _channel.invokeMethod('closeApp');
      } catch (_) {}
    } else {
      exit(0);
    }
  }

  // --- Native Method Handler ---
  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    final player = _playerProvider;
    switch (call.method) {
      case 'onMediaKeyAction':
        final action = call.arguments as String?;
        if (action != null && player != null) {
          _handleMediaKeyAction(action, player);
        }
        break;

      case 'onWindowEvent':
        final event = call.arguments as String?;
        if (event == 'show') {
          await restoreWindow();
        } else if (event == 'showMiniPlayer') {
          _onToggleMiniPlayerCallback?.call();
        }
        break;

      case 'onFilesDropped':
        final rawList = call.arguments as List<dynamic>?;
        if (rawList != null && rawList.isNotEmpty) {
          final paths = rawList.map((e) => e.toString()).toList();
          _onFilesDroppedCallback?.call(paths);
        }
        break;

      default:
        debugPrint(
          'DesktopIntegrationService: Unhandled method: ${call.method}',
        );
    }
  }

  void _handleMediaKeyAction(String action, PlayerProvider player) {
    switch (action) {
      case 'playPause':
        if (!isTestMode) {
          player.togglePlayPause();
        }
        break;
      case 'next':
        player.next(isTest: isTestMode);
        break;
      case 'previous':
        player.previous(isTest: isTestMode);
        break;
      case 'volumeUp':
        player.setVolume((player.volume + 0.05).clamp(0.0, 1.0));
        break;
      case 'volumeDown':
        player.setVolume((player.volume - 0.05).clamp(0.0, 1.0));
        break;
      case 'mute':
      case 'toggleMute':
        player.toggleMute();
        break;
    }
  }
}
