import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../app_image.dart';
import 'v35_empty_state.dart';

/// Reusable Queue panel and bottom sheet for MyMusic V3.5 Obsidian Emerald UI.
///
/// Features:
/// - Desktop right-docked panel or Mobile modal bottom sheet
/// - Pinned 'Now Playing' card with emerald visualizer indicator
/// - Reorderable 'Next Up' list with drag handles and individual remove buttons
/// - Clear queue action with confirmation
/// - Pure presentation: binds directly to existing PlayerProvider without logic duplication
class V35QueuePanel extends StatelessWidget {
  final VoidCallback? onClose;
  final bool isBottomSheet;

  const V35QueuePanel({super.key, this.onClose, this.isBottomSheet = false});

  /// Static helper to display the Queue as a responsive modal bottom sheet.
  static Future<void> showBottomSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(V35Tokens.radiusXl),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
            ),
            child: V35QueuePanel(
              isBottomSheet: true,
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '--:--';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _confirmClearQueue(BuildContext context, PlayerProvider player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V35Tokens.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: V35Tokens.brXl,
          side: const BorderSide(color: V35Tokens.borderCard),
        ),
        title: Text(
          'Hapus Antrean?',
          style: V35Tokens.heading.copyWith(fontSize: 18),
        ),
        content: Text(
          'Semua lagu dalam daftar antrean akan dikosongkan.',
          style: V35Tokens.secondary.copyWith(color: V35Tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Batal',
              style: V35Tokens.body.copyWith(color: V35Tokens.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: V35Tokens.brFull),
            ),
            onPressed: () {
              player.clearQueue();
              Navigator.of(ctx).pop();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        return Consumer<PlayerProvider>(
          builder: (context, player, child) {
            final queue = player.queue;
            final currentSong = player.currentSong;
            final currentIndex = player.currentIndex;

            return Container(
              decoration: BoxDecoration(
                color: isBottomSheet
                    ? V35Tokens.bgElevated
                    : V35Tokens.bgSurface,
                border: isBottomSheet
                    ? const Border(
                        top: BorderSide(
                          color: V35Tokens.borderCard,
                          width: 1.0,
                        ),
                      )
                    : const Border(
                        left: BorderSide(
                          color: V35Tokens.borderSubtle,
                          width: 1.0,
                        ),
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mobile Drag Handle Indicator
                  if (isBottomSheet)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 4),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: V35Tokens.textMuted.withValues(alpha: 0.4),
                          borderRadius: V35Tokens.brFull,
                        ),
                      ),
                    ),

                  // Header Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: V35Tokens.space16,
                      vertical: V35Tokens.space12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Antrean Lagu',
                                style: V35Tokens.heading.copyWith(
                                  fontSize: 17,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${queue.length} lagu dalam daftar',
                                style: V35Tokens.caption.copyWith(
                                  color: V35Tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Clear Queue Action
                        if (queue.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_sweep_rounded,
                              size: 20,
                            ),
                            color: V35Tokens.textMuted,
                            tooltip: 'Hapus Semua Antrean',
                            hoverColor: V35Tokens.bgHighlight,
                            onPressed: () =>
                                _confirmClearQueue(context, player),
                          ),

                        // Close Panel Action
                        if (onClose != null)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: V35Tokens.textMuted,
                            tooltip: 'Tutup Antrean',
                            hoverColor: V35Tokens.bgHighlight,
                            onPressed: onClose,
                          ),
                      ],
                    ),
                  ),

                  const Divider(color: V35Tokens.borderSubtle, height: 1),

                  // Body Content: Empty State OR Populated Queue
                  if (queue.isEmpty)
                    const Expanded(
                      child: V35EmptyState(
                        icon: Icons.queue_music_rounded,
                        title: 'Antrean Kosong',
                        description:
                            'Tidak ada lagu dalam antrean. Putar lagu atau pilih Tambah ke Queue untuk mendengarkan.',
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: V35Tokens.space8,
                        ),
                        children: [
                          // --- NOW PLAYING SECTION ---
                          if (currentSong != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: V35Tokens.space16,
                                vertical: V35Tokens.space8,
                              ),
                              child: Text(
                                'SEDANG DIPUTAR',
                                style: V35Tokens.caption.copyWith(
                                  color: V35Tokens.accentBright,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            _buildNowPlayingTile(currentSong, player),
                            const SizedBox(height: V35Tokens.space12),
                            const Divider(
                              color: V35Tokens.borderSubtle,
                              height: 1,
                            ),
                          ],

                          // --- NEXT IN QUEUE HEADER ---
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              V35Tokens.space16,
                              V35Tokens.space12,
                              V35Tokens.space16,
                              V35Tokens.space8,
                            ),
                            child: Text(
                              'DAFTAR PUTAR BERIKUTNYA',
                              style: V35Tokens.caption.copyWith(
                                color: V35Tokens.textMuted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),

                          // --- REORDERABLE TRACK LIST ---
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            itemCount: queue.length,
                            // ignore: deprecated_member_use
                            onReorder: (oldIndex, newIndex) {
                              player.reorderQueue(oldIndex, newIndex);
                            },
                            itemBuilder: (context, index) {
                              final song = queue[index];
                              final isCurrent = index == currentIndex;

                              return _buildQueueItemTile(
                                context: context,
                                song: song,
                                index: index,
                                isCurrent: isCurrent,
                                player: player,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // NOW PLAYING HIGHLIGHT TILE
  // ===========================================================================
  Widget _buildNowPlayingTile(SongModel song, PlayerProvider player) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: V35Tokens.space12),
      padding: const EdgeInsets.all(V35Tokens.space8),
      decoration: BoxDecoration(
        color: V35Tokens.accentDeep.withValues(alpha: 0.12),
        borderRadius: V35Tokens.brMd,
        border: Border.all(
          color: V35Tokens.accent.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: V35Tokens.brSm,
            child: SizedBox(
              width: 44,
              height: 44,
              child: AppImage(
                imagePath: song.cover,
                width: 44,
                height: 44,
                defaultIcon: Icons.music_note_rounded,
              ),
            ),
          ),
          const SizedBox(width: V35Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song.title,
                  style: V35Tokens.body.copyWith(
                    color: V35Tokens.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  song.artistName ?? 'Unknown Artist',
                  style: V35Tokens.secondary.copyWith(
                    fontSize: 12.0,
                    color: V35Tokens.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: V35Tokens.space8),
          Icon(Icons.equalizer_rounded, color: V35Tokens.accent, size: 20),
        ],
      ),
    );
  }

  // ===========================================================================
  // REORDERABLE QUEUE ITEM TILE
  // ===========================================================================
  Widget _buildQueueItemTile({
    required BuildContext context,
    required SongModel song,
    required int index,
    required bool isCurrent,
    required PlayerProvider player,
  }) {
    return Material(
      key: ValueKey('v35_queue_${song.id}_$index'),
      color: isCurrent
          ? V35Tokens.bgHighlight.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          player.playQueueIndex(index, context: context);
          if (isBottomSheet) {
            Navigator.of(context).pop();
          }
        },
        hoverColor: V35Tokens.bgHighlight.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: V35Tokens.space12,
            vertical: V35Tokens.space4,
          ),
          child: Row(
            children: [
              // Track Index / Status Icon
              SizedBox(
                width: 24,
                child: Center(
                  child: isCurrent
                      ? Icon(
                          Icons.volume_up_rounded,
                          size: 16,
                          color: V35Tokens.accent,
                        )
                      : Text(
                          '${index + 1}',
                          style: V35Tokens.mono.copyWith(
                            color: V35Tokens.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: V35Tokens.space8),

              // Thumbnail Artwork
              ClipRRect(
                borderRadius: V35Tokens.brSm,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: AppImage(
                    imagePath: song.cover,
                    width: 36,
                    height: 36,
                    defaultIcon: Icons.music_note_rounded,
                  ),
                ),
              ),
              const SizedBox(width: V35Tokens.space8),

              // Song Title & Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      style: V35Tokens.body.copyWith(
                        color: isCurrent
                            ? V35Tokens.accent
                            : V35Tokens.textPrimary,
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 13.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artistName ?? 'Unknown Artist',
                      style: V35Tokens.secondary.copyWith(
                        color: V35Tokens.textMuted,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Duration Label
              if (song.duration > 0) ...[
                const SizedBox(width: V35Tokens.space8),
                Text(
                  _formatDuration(song.duration),
                  style: V35Tokens.mono.copyWith(
                    color: V35Tokens.textMuted,
                    fontSize: 11.0,
                  ),
                ),
              ],

              // Remove from Queue Action
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: V35Tokens.textMuted,
                ),
                tooltip: 'Hapus dari antrean',
                splashRadius: 16,
                padding: const EdgeInsets.all(V35Tokens.space4),
                constraints: const BoxConstraints(),
                onPressed: () => player.removeFromQueue(index),
              ),
              const SizedBox(width: V35Tokens.space4),

              // Reorder Drag Handle
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(V35Tokens.space4),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    size: 18,
                    color: V35Tokens.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
