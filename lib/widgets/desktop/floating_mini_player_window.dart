import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_theme.dart';
import '../../core/theme/v35_accent.dart';
import '../app_image.dart';

/// Standalone Flutter application entry point for the secondary Mini Player window.
class MiniPlayerStandaloneApp extends StatelessWidget {
  final String windowId;

  const MiniPlayerStandaloneApp({super.key, required this.windowId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, activeAccent, child) {
        return MaterialApp(
          title: 'TONAVERA Mini Player',
          debugShowCheckedModeBanner: false,
          theme: V35Theme.darkTheme,
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: FloatingMiniPlayerWindowView(windowId: windowId),
          ),
        );
      },
    );
  }
}

/// The compact independent floating Mini Player window view (480 x 125 px).
class FloatingMiniPlayerWindowView extends StatefulWidget {
  final String windowId;

  const FloatingMiniPlayerWindowView({super.key, required this.windowId});

  @override
  State<FloatingMiniPlayerWindowView> createState() =>
      _FloatingMiniPlayerWindowViewState();
}

class _FloatingMiniPlayerWindowViewState
    extends State<FloatingMiniPlayerWindowView>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _desktopChannel = MethodChannel(
    'com.mymusic.desktop/integration',
  );
  static const WindowMethodChannel _multiChannel = WindowMethodChannel(
    'com.mymusic.mini_player_channel',
    mode: ChannelMode.bidirectional,
  );

  // Playback state synchronized with the main application
  bool _isPlaying = false;
  String _title = 'Tidak Ada Lagu';
  String _artist = 'TONAVERA';
  String? _coverUrl;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isFavorite = false;
  bool _isMoreMenuOpen = false;

  late final AnimationController _rotationController;
  Timer? _positionTicker;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    _initWindow();
    _setupChannelListener();
    _requestInitialState();
  }

  Future<void> _initWindow() async {
    try {
      // 1. Make window frameless
      await _desktopChannel.invokeMethod('makeFrameless');
      // 2. Set Always On Top so it floats above other desktop windows
      await _desktopChannel.invokeMethod('setAlwaysOnTop', true);
      // 3. Set desired compact desktop window size (480 x 125)
      const windowW = 480;
      const windowH = 125;
      await _desktopChannel.invokeMethod('setWindowSize', {
        'width': windowW,
        'height': windowH,
      });

      // 4. Position at bottom-right area of the screen with subtle margin
      final screenInfo = await _desktopChannel.invokeMethod<Map>(
        'getScreenSize',
      );
      if (screenInfo != null) {
        final screenW = (screenInfo['width'] as num?)?.toInt() ?? 1920;
        final screenH = (screenInfo['height'] as num?)?.toInt() ?? 1080;
        final posX = (screenW - windowW - 24).clamp(10, screenW - windowW);
        final posY = (screenH - windowH - 48).clamp(10, screenH - windowH);
        await _desktopChannel.invokeMethod('setWindowPosition', {
          'x': posX,
          'y': posY,
        });
      }
    } catch (e) {
      debugPrint('FloatingMiniPlayerWindow: init error: $e');
    }
  }

  void _setupChannelListener() {
    _multiChannel.setMethodCallHandler((call) async {
      if (call.method == 'updateState' && call.arguments is Map) {
        final data = call.arguments as Map;
        _applyState(data);
        if (data['theme'] is Map) {
          _applyTheme(data['theme'] as Map);
        }
      } else if (call.method == 'updateTheme' && call.arguments is Map) {
        _applyTheme(call.arguments as Map);
      }
    });
  }

  Future<void> _requestInitialState() async {
    try {
      final res = await _multiChannel.invokeMethod('getPlaybackState');
      if (res is Map && mounted) {
        _applyState(res);
        if (res['theme'] is Map) {
          _applyTheme(res['theme'] as Map);
        }
      }
    } catch (_) {}
  }

  void _applyTheme(Map map) {
    final baseInt = map['base'] as int?;
    final brightInt = map['bright'] as int?;
    final deepInt = map['deep'] as int?;
    if (baseInt != null && brightInt != null && deepInt != null) {
      final modeStr = map['mode'] as String? ?? 'preset';
      final mode = AccentMode.values.firstWhere(
        (m) => m.name == modeStr,
        orElse: () => AccentMode.preset,
      );
      final palette = V35AccentPalette(
        id: map['id'] as String? ?? 'custom',
        name: map['name'] as String? ?? 'Custom',
        mode: mode,
        base: Color(baseInt),
        bright: Color(brightInt),
        deep: Color(deepInt),
      );
      V35Accent.notifier.value = palette;
    }
  }

  void _applyState(Map data) {
    if (!mounted) return;
    setState(() {
      _isPlaying = data['isPlaying'] == true;
      _title = (data['title'] as String?)?.isNotEmpty == true
          ? data['title'] as String
          : 'Tidak Ada Lagu';
      _artist = (data['artist'] as String?)?.isNotEmpty == true
          ? data['artist'] as String
          : 'TONAVERA';
      _coverUrl = data['cover'] as String?;
      _isFavorite = data['isFavorite'] == true;

      final durMs = (data['durationMs'] as num?)?.toInt() ?? 0;
      final posMs = (data['positionMs'] as num?)?.toInt() ?? 0;
      _duration = Duration(milliseconds: durMs);
      _position = Duration(milliseconds: posMs);
    });

    if (_isPlaying) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
      _startPositionTicker();
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
      _positionTicker?.cancel();
    }
  }

  void _startPositionTicker() {
    _positionTicker?.cancel();
    _positionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPlaying && mounted && _duration > Duration.zero) {
        if (_position < _duration) {
          setState(() {
            _position += const Duration(seconds: 1);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _positionTicker?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  // --- User Actions routed back to the Main Player ---

  Future<void> _togglePlayPause() async {
    try {
      await _multiChannel.invokeMethod('togglePlayPause');
    } catch (_) {}
  }

  Future<void> _next() async {
    try {
      await _multiChannel.invokeMethod('next');
    } catch (_) {}
  }

  Future<void> _previous() async {
    try {
      await _multiChannel.invokeMethod('previous');
    } catch (_) {}
  }

  Future<void> _seek(Duration pos) async {
    try {
      await _multiChannel.invokeMethod('seek', {
        'position': pos.inMilliseconds,
      });
      setState(() => _position = pos);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    setState(() => _isFavorite = !_isFavorite);
    try {
      await _multiChannel.invokeMethod('toggleFavorite');
    } catch (_) {}
  }

  Future<void> _addToQueue() async {
    try {
      await _multiChannel.invokeMethod('addToQueue');
    } catch (_) {}
  }

  Future<void> _openQueue() async {
    try {
      await _multiChannel.invokeMethod('openQueue');
    } catch (_) {}
  }

  Future<void> _openFullPlayer() async {
    try {
      await _multiChannel.invokeMethod('openFullPlayer');
    } catch (_) {}
  }

  Future<void> _closeMiniPlayer() async {
    setState(() => _isMoreMenuOpen = false);
    _rotationController.stop();
    _positionTicker?.cancel();
    try {
      await _multiChannel.invokeMethod('onMiniPlayerClosed');
    } catch (_) {}
    try {
      await _desktopChannel.invokeMethod('hideWindow');
    } catch (_) {}
  }

  void _startWindowDrag() {
    _desktopChannel.invokeMethod('startDrag');
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, activeAccent, _) {
        final progress = _duration.inMilliseconds > 0
            ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(
                0.0,
                1.0,
              )
            : 0.0;

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (_isMoreMenuOpen &&
                event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              setState(() => _isMoreMenuOpen = false);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) {
              if (_isMoreMenuOpen) setState(() => _isMoreMenuOpen = false);
              _startWindowDrag();
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              margin: const EdgeInsets.symmetric(
                horizontal: 2.0,
                vertical: 0.0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xF4111518),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.70),
                    blurRadius: 20.0,
                    spreadRadius: 1.0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Stack(
                  children: [
                    // Main Mini Player content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 6.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // TOP SECTION: Compact Cover + Overlapping Vinyl on left, Song info & Controls on right
                          Expanded(
                            child: Row(
                              children: [
                                // 1. ALBUM ARTWORK (76x76) + OVERLAPPING VINYL RECORD (~78x78)
                                _buildCoverAndVinylCluster(),

                                const SizedBox(width: 12.0),

                                // 2. SONG METADATA + CONTROLS
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Top Row: Title, Artist, and Action Buttons (♡, •••, ×)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _title,
                                                  style: V35Tokens.heading
                                                      .copyWith(
                                                        fontSize: 14.0,
                                                        height: 1.15,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white,
                                                        letterSpacing: -0.2,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2.0),
                                                Text(
                                                  _artist,
                                                  style: V35Tokens.caption
                                                      .copyWith(
                                                        fontSize: 11.5,
                                                        height: 1.15,
                                                        color:
                                                            V35Tokens.textMuted,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Actions: Favorite, More, and Subtle Compact Close Button
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildIconButton(
                                                icon: _isFavorite
                                                    ? Icons.favorite_rounded
                                                    : Icons
                                                          .favorite_border_rounded,
                                                size: 16,
                                                buttonSize: 22,
                                                color: _isFavorite
                                                    ? activeAccent.base
                                                    : V35Tokens.textMuted,
                                                tooltip: _isFavorite
                                                    ? 'Favorit'
                                                    : 'Tambah ke Favorit',
                                                onPressed: _toggleFavorite,
                                              ),
                                              const SizedBox(width: 2.0),
                                              _buildIconButton(
                                                icon: Icons.more_horiz_rounded,
                                                size: 16,
                                                buttonSize: 22,
                                                color: _isMoreMenuOpen
                                                    ? activeAccent.base
                                                    : V35Tokens.textMuted,
                                                tooltip: 'Opsi',
                                                onPressed: () {
                                                  setState(
                                                    () => _isMoreMenuOpen =
                                                        !_isMoreMenuOpen,
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 4.0),
                                              // Subtle compact close icon
                                              _buildIconButton(
                                                icon: Icons.close_rounded,
                                                size: 14,
                                                buttonSize: 20,
                                                color: V35Tokens.textMuted
                                                    .withValues(alpha: 0.65),
                                                hoverColor: Colors.white
                                                    .withValues(alpha: 0.12),
                                                tooltip: 'Tutup Mini Player',
                                                onPressed: _closeMiniPlayer,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 3.0),

                                      // Playback Controls Row: Skip Previous, Play/Pause, Skip Next
                                      Row(
                                        children: [
                                          _buildIconButton(
                                            icon: Icons.skip_previous_rounded,
                                            size: 18,
                                            buttonSize: 26,
                                            tooltip: 'Lagu Sebelumnya',
                                            onPressed: _previous,
                                          ),
                                          const SizedBox(width: 6.0),
                                          _buildPlayPauseButton(activeAccent),
                                          const SizedBox(width: 6.0),
                                          _buildIconButton(
                                            icon: Icons.skip_next_rounded,
                                            size: 18,
                                            buttonSize: 26,
                                            tooltip: 'Lagu Berikutnya',
                                            onPressed: _next,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 2.0),

                          // BOTTOM PROGRESS BAR & TIMESTAMPS
                          _buildProgressBar(progress, activeAccent),
                        ],
                      ),
                    ),

                    // More Menu Contextual Overlay
                    if (_isMoreMenuOpen) ...[
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _isMoreMenuOpen = false),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        top: 24.0,
                        right: 18.0,
                        child: _buildMoreMenuPopup(activeAccent),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds compact album artwork (76x76) overlapping the physical vinyl record (~78x78)
  Widget _buildCoverAndVinylCluster() {
    const double artSize = 76.0;
    const double vinylSize = 78.0;
    const double vinylShift = 26.0;

    return SizedBox(
      width: artSize + vinylShift,
      height: vinylSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          // Vinyl Record partially overlapping behind (in RepaintBoundary for 60fps rotation)
          Positioned(
            left: vinylShift,
            top: 0,
            child: RepaintBoundary(
              child: _StandAloneVinylDisc(
                size: vinylSize,
                imageUrl: _coverUrl,
                rotationController: _rotationController,
              ),
            ),
          ),

          // Album Artwork (in front with smooth shadow and rounded corners)
          Positioned(
            left: 0,
            top: (vinylSize - artSize) / 2,
            child: Container(
              width: artSize,
              height: artSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 10.0,
                    spreadRadius: 1.0,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: AppImage(
                  imagePath: _coverUrl,
                  width: artSize,
                  height: artSize,
                  cacheWidth: 160,
                  cacheHeight: 160,
                  fit: BoxFit.cover,
                  defaultIcon: Icons.album_rounded,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact circular focal play/pause button (~40x40)
  Widget _buildPlayPauseButton(V35AccentPalette activeAccent) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _togglePlayPause,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activeAccent.base,
            boxShadow: [
              BoxShadow(
                color: activeAccent.base.withValues(alpha: 0.35),
                blurRadius: 10.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 20,
              color: V35Tokens.bgVoid,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required double size,
    double buttonSize = 26,
    required VoidCallback? onPressed,
    String? tooltip,
    Color? color,
    Color? hoverColor,
  }) {
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: IconButton(
        icon: Icon(icon, size: size),
        color: color ?? V35Tokens.textMuted,
        hoverColor: hoverColor,
        padding: EdgeInsets.zero,
        splashRadius: buttonSize / 2,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildProgressBar(double progress, V35AccentPalette activeAccent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Seekable Track (thin 2.5px bar with compact hit target)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _handleSeekGesture(details.localPosition.dx),
          onHorizontalDragUpdate: (details) =>
              _handleSeekGesture(details.localPosition.dx),
          child: Container(
            height: 6,
            padding: const EdgeInsets.symmetric(vertical: 1.75),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Inactive Track
                    Container(
                      height: 2.5,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    // Active Adaptive Accent Progress Track
                    Container(
                      height: 2.5,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        color: activeAccent.base,
                        borderRadius: BorderRadius.circular(1.5),
                        boxShadow: [
                          BoxShadow(
                            color: activeAccent.base.withValues(alpha: 0.40),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        // Timestamps (compact 9.0px font with controlled line-height)
        Padding(
          padding: const EdgeInsets.only(top: 1.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(
                  fontSize: 9.0,
                  height: 1.1,
                  color: V35Tokens.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(
                  fontSize: 9.0,
                  height: 1.1,
                  color: V35Tokens.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact contextual More menu popup matching obsidian dark design language
  Widget _buildMoreMenuPopup(V35AccentPalette activeAccent) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 160.0,
        decoration: BoxDecoration(
          color: const Color(0xF7161A1D),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.70),
              blurRadius: 14.0,
              spreadRadius: 1.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMoreMenuItem(
              icon: Icons.queue_music_rounded,
              label: 'Add to Queue',
              activeAccent: activeAccent,
              onTap: () {
                setState(() => _isMoreMenuOpen = false);
                _addToQueue();
              },
            ),
            _buildMoreMenuItem(
              icon: _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: _isFavorite ? activeAccent.base : null,
              label: _isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              activeAccent: activeAccent,
              onTap: () {
                setState(() => _isMoreMenuOpen = false);
                _toggleFavorite();
              },
            ),
            _buildMoreMenuItem(
              icon: Icons.playlist_play_rounded,
              label: 'Open Queue',
              activeAccent: activeAccent,
              onTap: () {
                setState(() => _isMoreMenuOpen = false);
                _openQueue();
              },
            ),
            _buildMoreMenuItem(
              icon: Icons.open_in_full_rounded,
              label: 'Open Full Player',
              activeAccent: activeAccent,
              onTap: () {
                setState(() => _isMoreMenuOpen = false);
                _openFullPlayer();
              },
            ),
            _buildMoreMenuItem(
              icon: Icons.visibility_off_rounded,
              label: 'Hide Mini Player',
              activeAccent: activeAccent,
              onTap: () {
                setState(() => _isMoreMenuOpen = false);
                _closeMiniPlayer();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreMenuItem({
    required IconData icon,
    Color? iconColor,
    required String label,
    required V35AccentPalette activeAccent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: activeAccent.base.withValues(alpha: 0.14),
      splashColor: activeAccent.base.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(4.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
        child: Row(
          children: [
            Icon(icon, size: 13.0, color: iconColor ?? V35Tokens.textMuted),
            const SizedBox(width: 7.0),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSeekGesture(double localDx) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final totalWidth =
        box.size.width - 24.0; // minus 12px horizontal padding on both sides
    if (totalWidth > 0 && _duration > Duration.zero) {
      final ratio = (localDx / totalWidth).clamp(0.0, 1.0);
      _seek(Duration(milliseconds: (ratio * _duration.inMilliseconds).round()));
    }
  }
}

/// Standalone vinyl disc with smooth procedural grooves and sheen
class _StandAloneVinylDisc extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final AnimationController rotationController;

  const _StandAloneVinylDisc({
    required this.size,
    required this.imageUrl,
    required this.rotationController,
  });

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: rotationController,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Realistic Grooves and Anisotropic Highlight
            CustomPaint(
              size: Size(size, size),
              painter: _StandAloneVinylPainter(),
            ),

            // Center Record Label
            Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: AppImage(
                  imagePath: imageUrl,
                  width: size * 0.36,
                  height: size * 0.36,
                  cacheWidth: 60,
                  cacheHeight: 60,
                  fit: BoxFit.cover,
                  defaultIcon: Icons.music_note_rounded,
                ),
              ),
            ),

            // Spindle Hole
            Container(
              width: size * 0.08,
              height: size * 0.08,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0A0C0E),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vinyl Painter rendering concentric micro-grooves and radial sheen
class _StandAloneVinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Vinyl base disc
    final discPaint = Paint()
      ..color = const Color(0xFF131518)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, discPaint);

    // 2. Anisotropic radial sheen reflections
    final sheenPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.50, 0.75, 1.0],
        transform: const GradientRotation(math.pi / 4),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, sheenPaint);

    // 3. Concentric micro-grooves
    final groovePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    const int grooveCount = 6;
    final double minGrooveR = radius * 0.42;
    final double maxGrooveR = radius * 0.94;
    final double step = (maxGrooveR - minGrooveR) / grooveCount;

    for (int i = 0; i <= grooveCount; i++) {
      canvas.drawCircle(center, minGrooveR + (i * step), groovePaint);
    }

    // Outer rim highlight
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, radius - 0.5, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
