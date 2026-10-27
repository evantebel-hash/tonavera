import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/download_task_model.dart';
import '../../services/download_service.dart';
import '../../providers/player_provider.dart';
import '../../repositories/local_music_repository.dart';
import '../../widgets/dialogs/playlist_picker_dialog.dart';
import '../../widgets/v35/v35_action_sheet.dart';
import '../../widgets/v35/v35_empty_state.dart';
import '../../widgets/v35/v35_filter_pill.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  String _selectedFilter = 'all'; // 'all', 'active', 'completed', 'failed'

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes.clamp(1, double.maxFinite).toString().length - 1) ~/ 3;
    if (i >= suffixes.length) i = suffixes.length - 1;
    final num = bytes / (1 << (i * 10));
    return '${num.toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _handleShowCompletedOptions(BuildContext context, DownloadTask task) {
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final localSong = task.song.copyWith(
      source: 'local',
      audioPath: task.localPath ?? task.song.audioPath,
      filePath: task.localPath ?? task.song.audioPath,
    );

    V35ActionSheet.show(
      context: context,
      title: task.song.title,
      subtitle: task.song.artistName ?? 'Unknown Artist',
      headerLeading: ClipRRect(
        borderRadius: V35Tokens.brSm,
        child: task.song.cover != null
            ? Image.network(
                task.song.cover!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _fallbackCover(size: 44),
              )
            : _fallbackCover(size: 44),
      ),
      actions: [
        V35ActionItem(
          title: 'Putar Sekarang',
          icon: Icons.play_arrow_rounded,
          onTap: () {
            Navigator.pop(context);
            player.playSong(localSong);
          },
        ),
        V35ActionItem(
          title: 'Tambah ke Queue',
          icon: Icons.queue_music_rounded,
          onTap: () {
            Navigator.pop(context);
            player.addToQueue(localSong);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '"${task.song.title}" ditambahkan ke Queue.',
                  style: const TextStyle(color: V35Tokens.textPrimary),
                ),
                backgroundColor: V35Tokens.bgElevated,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        V35ActionItem(
          title: 'Tambah ke Playlist',
          icon: Icons.playlist_add_rounded,
          onTap: () async {
            Navigator.pop(context);
            final repo = LocalMusicRepository();
            final playlists = await repo.getPlaylists();
            if (!context.mounted) return;
            final chosen = await PlaylistPickerDialog.show(
              context,
              playlists: playlists,
              selectedSongCount: 1,
            );
            if (chosen != null && chosen.isNotEmpty) {
              final songId = await repo.insertOrUpdateSong(localSong);
              await repo.addSongsToMultiplePlaylists(chosen, [songId]);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Berhasil menambahkan "${task.song.title}" ke playlist.',
                      style: const TextStyle(color: V35Tokens.textPrimary),
                    ),
                    backgroundColor: V35Tokens.bgElevated,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        ),
        V35ActionItem(
          title: 'Hapus dari Riwayat',
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            DownloadService.instance.removeTask(task.id);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: DownloadService.instance,
      child: ValueListenableBuilder<V35AccentPalette>(
        valueListenable: V35Accent.notifier,
        builder: (context, accentPalette, child) {
          return Scaffold(
            backgroundColor: V35Tokens.bgVoid,
            appBar: AppBar(
              backgroundColor: V35Tokens.bgVoid,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: V35Tokens.textPrimary,
                ),
                tooltip: 'Kembali',
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Download Manager',
                style: TextStyle(
                  color: V35Tokens.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              centerTitle: false,
              actions: [
                Consumer<DownloadService>(
                  builder: (ctx, service, _) {
                    final hasCompleted = service.tasks.any(
                      (t) => t.status == DownloadStatus.completed,
                    );
                    if (!hasCompleted) return const SizedBox();
                    return IconButton(
                      icon: const Icon(
                        Icons.cleaning_services_rounded,
                        color: V35Tokens.textSecondary,
                        size: 20,
                      ),
                      tooltip: 'Bersihkan Riwayat Selesai',
                      onPressed: () => service.clearCompletedTasks(),
                    );
                  },
                ),
                const SizedBox(width: V35Tokens.space8),
              ],
            ),
            body: Consumer<DownloadService>(
              builder: (context, service, child) {
                final allTasks = service.tasks;
                if (allTasks.isEmpty) {
                  return const V35EmptyState(
                    icon: Icons.download_done_rounded,
                    title: 'Belum ada antrean download',
                    description:
                        'Lagu yang diunduh dari sumber yang didukung akan otomatis tampil dan terorganisir di sini.',
                  );
                }

                final activeTasks = allTasks
                    .where(
                      (t) =>
                          t.status == DownloadStatus.downloading ||
                          t.status == DownloadStatus.queued ||
                          t.status == DownloadStatus.paused,
                    )
                    .toList();
                final completedTasks = allTasks
                    .where((t) => t.status == DownloadStatus.completed)
                    .toList();
                final failedTasks = allTasks
                    .where(
                      (t) =>
                          t.status == DownloadStatus.failed ||
                          t.status == DownloadStatus.cancelled,
                    )
                    .toList();

                // Filter selection
                List<DownloadTask> displayedTasks;
                if (_selectedFilter == 'active') {
                  displayedTasks = activeTasks;
                } else if (_selectedFilter == 'completed') {
                  displayedTasks = completedTasks;
                } else if (_selectedFilter == 'failed') {
                  displayedTasks = failedTasks;
                } else {
                  displayedTasks = allTasks;
                }

                return Column(
                  children: [
                    // Filter Pill Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: V35Tokens.space16,
                        vertical: V35Tokens.space8,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            V35FilterPill(
                              label: 'Semua',
                              count: allTasks.length,
                              isSelected: _selectedFilter == 'all',
                              onTap: () =>
                                  setState(() => _selectedFilter = 'all'),
                            ),
                            const SizedBox(width: V35Tokens.space8),
                            V35FilterPill(
                              label: 'Aktif',
                              count: activeTasks.length,
                              isSelected: _selectedFilter == 'active',
                              onTap: () =>
                                  setState(() => _selectedFilter = 'active'),
                            ),
                            const SizedBox(width: V35Tokens.space8),
                            V35FilterPill(
                              label: 'Selesai',
                              count: completedTasks.length,
                              isSelected: _selectedFilter == 'completed',
                              onTap: () =>
                                  setState(() => _selectedFilter = 'completed'),
                            ),
                            if (failedTasks.isNotEmpty) ...[
                              const SizedBox(width: V35Tokens.space8),
                              V35FilterPill(
                                label: 'Gagal',
                                count: failedTasks.length,
                                isSelected: _selectedFilter == 'failed',
                                onTap: () =>
                                    setState(() => _selectedFilter = 'failed'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: V35Tokens.space8),

                    // Content list
                    Expanded(
                      child: displayedTasks.isEmpty
                          ? V35EmptyState(
                              icon: _selectedFilter == 'active'
                                  ? Icons.downloading_rounded
                                  : _selectedFilter == 'completed'
                                  ? Icons.cloud_done_rounded
                                  : Icons.error_outline_rounded,
                              title: 'Tidak ada item dalam kategori ini',
                              description:
                                  'Pilih filter lain untuk melihat unduhan lainnya.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                V35Tokens.space16,
                                V35Tokens.space4,
                                V35Tokens.space16,
                                V35Tokens.space48 +
                                    32, // miniplayer safe padding
                              ),
                              itemCount: displayedTasks.length,
                              itemBuilder: (ctx, index) {
                                final task = displayedTasks[index];
                                return _buildTaskCard(context, service, task);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    DownloadService service,
    DownloadTask task,
  ) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final isPaused = task.status == DownloadStatus.paused;
    final isQueued = task.status == DownloadStatus.queued;
    final isCompleted = task.status == DownloadStatus.completed;
    final isFailed =
        task.status == DownloadStatus.failed ||
        task.status == DownloadStatus.cancelled;

    Color borderColor = V35Tokens.borderSubtle;
    if (isDownloading) {
      borderColor = V35Tokens.accent.withValues(alpha: 0.5);
    } else if (isPaused) {
      borderColor = Colors.amberAccent.withValues(alpha: 0.4);
    } else if (isFailed) {
      borderColor = Colors.redAccent.withValues(alpha: 0.35);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: V35Tokens.space12),
      padding: const EdgeInsets.all(V35Tokens.space12),
      decoration: BoxDecoration(
        color: V35Tokens.bgSurface,
        borderRadius: V35Tokens.brMd,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Artwork
              ClipRRect(
                borderRadius: V35Tokens.brSm,
                child: task.song.cover != null
                    ? Image.network(
                        task.song.cover!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _fallbackCover(size: 48),
                      )
                    : _fallbackCover(size: 48),
              ),
              const SizedBox(width: V35Tokens.space12),

              // Title & Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: V35Tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            task.song.artistName ?? 'Unknown Artist',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: V35Tokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: V35Tokens.space8),
                        _buildStatusBadge(task),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              if (isDownloading)
                IconButton(
                  icon: Icon(
                    Icons.pause_circle_filled_rounded,
                    color: V35Tokens.accent,
                    size: 30,
                  ),
                  tooltip: 'Jeda Download',
                  onPressed: () => service.pauseDownload(task.id),
                )
              else if (isPaused || isFailed)
                IconButton(
                  icon: Icon(
                    Icons.play_circle_fill_rounded,
                    color: V35Tokens.accent,
                    size: 30,
                  ),
                  tooltip: isFailed ? 'Ulangi Download' : 'Lanjutkan Download',
                  onPressed: () => service.resumeDownload(task.id),
                )
              else if (isCompleted)
                IconButton(
                  icon: Icon(
                    Icons.play_circle_fill_rounded,
                    color: V35Tokens.accent,
                    size: 30,
                  ),
                  tooltip: 'Putar Sekarang',
                  onPressed: () {
                    final player = Provider.of<PlayerProvider>(
                      context,
                      listen: false,
                    );
                    final localSong = task.song.copyWith(
                      source: 'local',
                      audioPath: task.localPath ?? task.song.audioPath,
                      filePath: task.localPath ?? task.song.audioPath,
                    );
                    player.playSong(localSong);
                  },
                ),

              if (isCompleted)
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: V35Tokens.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Opsi',
                  onPressed: () => _handleShowCompletedOptions(context, task),
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: V35Tokens.textMuted,
                    size: 22,
                  ),
                  tooltip: 'Batalkan',
                  hoverColor: Colors.redAccent.withValues(alpha: 0.15),
                  onPressed: () => service.cancelDownload(task.id),
                ),
            ],
          ),

          // Progress indicator & statistics
          if (isDownloading || isPaused || isQueued) ...[
            const SizedBox(height: V35Tokens.space8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: isQueued ? null : task.progress,
                minHeight: 4,
                backgroundColor: V35Tokens.bgHighlight,
                valueColor: AlwaysStoppedAnimation(
                  isPaused ? Colors.amberAccent : V35Tokens.accent,
                ),
              ),
            ),
            const SizedBox(height: V35Tokens.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isQueued
                      ? 'Menunggu antrean...'
                      : isPaused
                      ? 'Dijeda'
                      : '${(task.progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isPaused
                        ? Colors.amberAccent
                        : V35Tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  task.totalBytes > 0
                      ? '${_formatBytes(task.bytesDownloaded)} / ${_formatBytes(task.totalBytes)}'
                      : _formatBytes(task.bytesDownloaded),
                  style: const TextStyle(
                    color: V35Tokens.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],

          // Error details
          if (task.error != null) ...[
            const SizedBox(height: V35Tokens.space8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Error: ${task.error}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(DownloadTask task) {
    String text;
    Color textColor;
    Color bgColor;

    switch (task.status) {
      case DownloadStatus.downloading:
        text = 'MENGUNDUH';
        textColor = V35Tokens.accent;
        bgColor = V35Tokens.accent.withValues(alpha: 0.15);
        break;
      case DownloadStatus.queued:
        text = 'ANTREAN';
        textColor = V35Tokens.textMuted;
        bgColor = V35Tokens.bgHighlight;
        break;
      case DownloadStatus.paused:
        text = 'DIJEDA';
        textColor = Colors.amberAccent;
        bgColor = Colors.amberAccent.withValues(alpha: 0.15);
        break;
      case DownloadStatus.completed:
        text = 'TERSIMPAN';
        textColor = V35Tokens.success;
        bgColor = V35Tokens.success.withValues(alpha: 0.12);
        break;
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        text = task.status == DownloadStatus.failed ? 'GAGAL' : 'BATAL';
        textColor = Colors.redAccent;
        bgColor = Colors.redAccent.withValues(alpha: 0.15);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _fallbackCover({double size = 48}) {
    return Container(
      width: size,
      height: size,
      color: V35Tokens.bgElevated,
      child: const Icon(
        Icons.music_note_rounded,
        color: V35Tokens.textMuted,
        size: 24,
      ),
    );
  }
}
