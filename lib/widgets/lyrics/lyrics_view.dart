import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/lyric_line.dart';
import '../../models/lyrics_model.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../services/lrc_parser.dart';
import '../../services/lyrics_service.dart';
import '../v35/v35_empty_state.dart';

/// V3.5 Obsidian Emerald kinetic karaoke lyrics presentation.
///
/// Preserves exact underlying [LyricsService] fetching, caching,
/// [LrcParser] synchronization, auto-scrolling, manual scrolling detection,
/// and line seeking without touching lyrics or playback logic.
class LyricsView extends StatefulWidget {
  final SongModel song;
  final bool isCompact;

  const LyricsView({super.key, required this.song, this.isCompact = false});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final LyricsService _lyricsService = LyricsService.instance;
  final ScrollController _scrollController = ScrollController();

  LyricsState _state = const LyricsState(status: LyricsLoadingStatus.idle);
  int _currentActiveIndex = -1;
  bool _userScrolledManually = false;
  DateTime _lastUserScrollTime = DateTime.fromMillisecondsSinceEpoch(0);

  PlayerProvider? _playerProvider;
  bool _isScrolling = false;
  final Map<int, GlobalKey> _itemKeys = {};
  DateTime _lastDiagnosticTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = Provider.of<PlayerProvider>(context);
    if (_playerProvider != player) {
      _playerProvider?.removeListener(_onPlayerChanged);
      _playerProvider = player;
      _playerProvider?.addListener(_onPlayerChanged);
    }
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _currentActiveIndex = -1;
      _userScrolledManually = false;
      _itemKeys.clear();
      _lastDiagnosticTime = DateTime.fromMillisecondsSinceEpoch(0);
      _loadLyrics();
    }
  }

  @override
  void dispose() {
    _playerProvider?.removeListener(_onPlayerChanged);
    _playerProvider = null;
    _scrollController.dispose();
    super.dispose();
  }

  void _onPlayerChanged() {
    if (!mounted || _playerProvider == null) return;
    _updateActiveLine(_playerProvider!.position);
  }

  Future<void> _loadLyrics({bool forceRefresh = false}) async {
    setState(() {
      _state = LyricsState(
        status: LyricsLoadingStatus.loading,
        songId: widget.song.id,
      );
    });

    final res = await _lyricsService.getLyricsForSong(
      widget.song,
      forceRefresh: forceRefresh,
    );

    if (mounted && res.songId == widget.song.id) {
      if (kDebugMode && res.lyrics != null) {
        final syncedStr = res.lyrics!.syncedLyrics;
        final details = syncedStr != null
            ? LrcParser.parseWithDetails(syncedStr)
            : null;
        debugPrint(
          '[LyricsLoaded] Track: "${widget.song.title}" by "${widget.song.artistName}" | '
          'AudioSource: ${widget.song.source} | AudioDur: ${widget.song.duration}s | '
          'LyricsSource: ${res.lyrics!.source.name} | Synced: ${res.lyrics!.isSynced} | '
          'LinesCount: ${res.lyrics!.parsedLines.length} | '
          'LrcOffset: ${details?.offsetMs ?? 0}ms',
        );
      }

      setState(() {
        _state = res;
      });
      // Evaluate initial active line if player position is already available
      if (_playerProvider != null) {
        _updateActiveLine(_playerProvider!.position);
      }
    }
  }

  void _updateActiveLine(Duration currentPos) {
    final lyrics = _state.lyrics;
    if (lyrics == null || !lyrics.isSynced || lyrics.parsedLines.isEmpty)
      return;

    final activeIndex = LrcParser.findActiveLineIndex(
      lyrics.parsedLines,
      currentPos,
    );

    // Periodic minimal diagnostic log (at most once every 3 seconds)
    if (kDebugMode && _playerProvider != null) {
      final now = DateTime.now();
      if (now.difference(_lastDiagnosticTime).inMilliseconds >= 3000) {
        _lastDiagnosticTime = now;
        final currentLine =
            (activeIndex >= 0 && activeIndex < lyrics.parsedLines.length)
            ? lyrics.parsedLines[activeIndex]
            : null;
        final leadMs = currentLine != null
            ? currentPos.inMilliseconds - currentLine.startTime.inMilliseconds
            : 0;
        debugPrint(
          '[LyricsDiag] Source: ${widget.song.source} | '
          'Track: "${widget.song.title}" | '
          'Pos: ${currentPos.inMilliseconds}ms | '
          'LineIdx: $activeIndex | '
          'LineStart: ${currentLine?.startTime.inMilliseconds ?? 0}ms | '
          'Lead: ${leadMs}ms | '
          'Playing: ${_playerProvider?.isPlaying ?? false}',
        );
      }
    }

    if (activeIndex != _currentActiveIndex) {
      if (activeIndex >= 0) {
        final prevIndex = _currentActiveIndex;
        if (kDebugMode) {
          final line = lyrics.parsedLines[activeIndex];
          final nextLine = activeIndex + 1 < lyrics.parsedLines.length
              ? lyrics.parsedLines[activeIndex + 1]
              : null;
          final leadDiffMs =
              currentPos.inMilliseconds - line.startTime.inMilliseconds;
          debugPrint(
            '[LyricsSync] LineTransition: $prevIndex -> $activeIndex | '
            'Source: ${widget.song.source} | '
            'Track: "${widget.song.title}" | Pos: ${currentPos.inMilliseconds}ms | '
            'LineStart: ${line.startTime.inMilliseconds}ms (pos - start = ${leadDiffMs}ms) | '
            'Text: "${line.text}"'
            '${nextLine != null ? ' | NextStart: ${nextLine.startTime.inMilliseconds}ms' : ''}',
          );
        }

        setState(() {
          _currentActiveIndex = activeIndex;
        });

        // Auto-scroll only if the user hasn't scrolled manually within the last 4 seconds
        final timeSinceUserScroll = DateTime.now()
            .difference(_lastUserScrollTime)
            .inSeconds;
        if (!_userScrolledManually || timeSinceUserScroll > 4) {
          _scrollToActiveLine();
        }
      } else {
        // Position is before the first lyric line (intro / seek back to start)
        setState(() {
          _currentActiveIndex = -1;
        });
        if (_scrollController.hasClients &&
            (!_userScrolledManually ||
                DateTime.now().difference(_lastUserScrollTime).inSeconds > 4)) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
  }

  void _scrollToActiveLine() {
    if (!_scrollController.hasClients ||
        _currentActiveIndex < 0 ||
        _isScrolling) {
      return;
    }

    double targetOffset;
    final itemKey = _itemKeys[_currentActiveIndex];
    final itemContext = itemKey?.currentContext;

    if (itemContext != null && itemContext.findRenderObject() is RenderBox) {
      // Measure actual rendered position of the item relative to the Scrollable viewport
      final itemBox = itemContext.findRenderObject() as RenderBox;
      final scrollBox =
          _scrollController.position.context.notificationContext
                  ?.findRenderObject()
              as RenderBox?;

      if (scrollBox != null) {
        final itemOffsetInViewport = itemBox
            .localToGlobal(Offset.zero, ancestor: scrollBox)
            .dy;
        final viewportHeight = scrollBox.size.height;
        final itemHeight = itemBox.size.height;

        // Calculate offset required to place this item comfortably centered in the viewport
        final desiredItemTop = (viewportHeight - itemHeight) / 2.0;
        final diff = itemOffsetInViewport - desiredItemTop;
        targetOffset = (_scrollController.offset + diff).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
      } else {
        // Fallback using cumulative estimated line height
        targetOffset = ((_currentActiveIndex * 54.0) - 140.0).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
      }
    } else {
      // Item not rendered or off-screen, fall back to safe estimated offset
      targetOffset = ((_currentActiveIndex * 54.0) - 140.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
    }

    final currentOffset = _scrollController.offset;

    if (kDebugMode) {
      debugPrint(
        '[LyricsScroll] Animating to index: $_currentActiveIndex | '
        'TargetOffset: ${targetOffset.toStringAsFixed(1)} | '
        'CurrentOffset: ${currentOffset.toStringAsFixed(1)} | '
        'HasExactContext: ${itemContext != null} | '
        'MaxScroll: ${_scrollController.position.maxScrollExtent.toStringAsFixed(1)}',
      );
    }

    // If already at or very close to target offset, skip animation
    if ((currentOffset - targetOffset).abs() < 1.0) {
      if (_userScrolledManually) {
        setState(() {
          _userScrolledManually = false;
        });
      }
      return;
    }

    _isScrolling = true;
    _scrollController
        .animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted) {
            _isScrolling = false;
          }
        });

    if (_userScrolledManually) {
      setState(() {
        _userScrolledManually = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: V35Tokens.bgSurface,
            borderRadius: V35Tokens.brLg,
            border: Border.all(color: V35Tokens.borderSubtle, width: 1.0),
          ),
          child: Column(
            children: [
              // Header & Source Badge
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: V35Tokens.space16,
                  vertical: V35Tokens.space12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lyrics_rounded,
                          color: V35Tokens.accent,
                          size: 20,
                        ),
                        const SizedBox(width: V35Tokens.space8),
                        Text(
                          'LIRIK LAGU',
                          style: V35Tokens.mono.copyWith(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: V35Tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(width: V35Tokens.space8),
                        if (_state.lyrics != null)
                          _buildSourceBadge(_state.lyrics!.source),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: V35Tokens.textMuted,
                      ),
                      tooltip: 'Segarkan Lirik Online',
                      splashRadius: 18,
                      onPressed: () => _loadLyrics(forceRefresh: true),
                    ),
                  ],
                ),
              ),
              Container(height: 1.0, color: V35Tokens.borderSubtle),

              // Main Content
              Expanded(
                child: Stack(
                  children: [
                    _buildBody(player),
                    if (_userScrolledManually &&
                        _state.isSynced &&
                        _currentActiveIndex >= 0)
                      Positioned(
                        bottom: V35Tokens.space16,
                        right: V35Tokens.space16,
                        child: FloatingActionButton.extended(
                          onPressed: _scrollToActiveLine,
                          backgroundColor: V35Tokens.accent,
                          elevation: 4.0,
                          icon: const Icon(
                            Icons.vertical_align_center_rounded,
                            size: 18,
                            color: Colors.black,
                          ),
                          label: Text(
                            'Lirik Aktif',
                            style: V35Tokens.mono.copyWith(
                              color: Colors.black,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(PlayerProvider player) {
    switch (_state.status) {
      case LyricsLoadingStatus.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: V35Tokens.accent,
                ),
              ),
              const SizedBox(height: V35Tokens.space16),
              Text(
                'Memuat lirik lagu...',
                style: V35Tokens.body.copyWith(
                  color: V35Tokens.textMuted,
                  fontSize: 13.0,
                ),
              ),
            ],
          ),
        );

      case LyricsLoadingStatus.notFound:
        return V35EmptyState(
          icon: Icons.music_off_outlined,
          title: 'Lirik Tidak Ditemukan',
          description:
              _state.message ??
              'Lirik belum tersedia untuk lagu ini di database lokal maupun daring.',
          primaryActionLabel: 'Cari Ulang di LRCLIB',
          onPrimaryAction: () => _loadLyrics(forceRefresh: true),
        );

      case LyricsLoadingStatus.offline:
      case LyricsLoadingStatus.error:
        return V35EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Lirik Belum Tersedia Offline',
          description:
              _state.message ??
              'Periksa koneksi internet untuk mengunduh lirik.',
          primaryActionLabel: 'Coba Lagi',
          onPrimaryAction: () => _loadLyrics(forceRefresh: true),
        );

      case LyricsLoadingStatus.loaded:
        final lyrics = _state.lyrics!;
        if (lyrics.isSynced && lyrics.parsedLines.isNotEmpty) {
          return _buildSyncedLyricsList(lyrics.parsedLines, player);
        } else {
          return _buildPlainLyricsView(lyrics.plainLyrics ?? '');
        }

      case LyricsLoadingStatus.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSyncedLyricsList(List<LyricLine> lines, PlayerProvider player) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll is UserScrollNotification) {
          _userScrolledManually = true;
          _lastUserScrollTime = DateTime.now();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: V35Tokens.space20,
          vertical: V35Tokens.space24,
        ),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final isActive = index == _currentActiveIndex;
          final key = _itemKeys.putIfAbsent(index, () => GlobalKey());

          return GestureDetector(
            key: key,
            onTap: () {
              player.seek(line.startTime);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 14.0,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? V35Tokens.accentDeep.withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: V35Tokens.brMd,
                border: Border.all(
                  color: isActive
                      ? V35Tokens.accent.withValues(alpha: 0.45)
                      : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: Text(
                line.text,
                style: TextStyle(
                  fontSize: isActive ? 18.5 : 14.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? V35Tokens.accent : V35Tokens.textMuted,
                  height: 1.4,
                  letterSpacing: isActive ? 0.2 : 0.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlainLyricsView(String plainText) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: V35Tokens.space24,
        vertical: V35Tokens.space20,
      ),
      child: SelectableText(
        plainText.isEmpty ? 'Lirik kosong.' : plainText,
        style: V35Tokens.body.copyWith(
          fontSize: 15.0,
          height: 1.8,
          color: V35Tokens.textPrimary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSourceBadge(LyricsSource source) {
    String label;
    Color color;

    switch (source) {
      case LyricsSource.embedded:
        label = 'EMBEDDED';
        color = const Color(0xFF10B981); // Semantic Green
        break;
      case LyricsSource.cache:
        label = 'CACHED';
        color = const Color(0xFF38BDF8); // Sky blue
        break;
      case LyricsSource.lrclib:
        label = 'LRCLIB';
        color = const Color(0xFF34D399); // Mint
        break;
      case LyricsSource.localAi:
        label = 'LOCAL AI';
        color = const Color(0xFFF59E0B); // Amber
        break;
      case LyricsSource.unknown:
        label = 'LOCAL';
        color = V35Tokens.textMuted;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: V35Tokens.brSm,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: V35Tokens.mono.copyWith(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
