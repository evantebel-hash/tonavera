import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../repositories/local_music_repository.dart';
import '../../services/music_import_service.dart';
import '../../widgets/drag_drop_import_zone.dart';
import '../../controllers/multi_select_controller.dart';
import '../../widgets/selection_action_bar.dart';
import '../../widgets/dialogs/playlist_picker_dialog.dart';
import '../../widgets/dialogs/import_link_dialog.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../widgets/v35/v35_track_row.dart';
import '../../widgets/v35/v35_empty_state.dart';
import '../../widgets/dialogs/android_diagnostic_dialog.dart';

class LocalMusicScreen extends StatefulWidget {
  const LocalMusicScreen({super.key});

  @override
  State<LocalMusicScreen> createState() => _LocalMusicScreenState();
}

class _LocalMusicScreenState extends State<LocalMusicScreen> {
  final LocalMusicRepository _repo = LocalMusicRepository();
  final MultiSelectController _selectController = MultiSelectController();
  List<SongModel> _localSongs = [];
  bool _isLoading = true;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _selectController.addListener(_onSelectionChanged);
    _fetchLocalSongs();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _selectController.removeListener(_onSelectionChanged);
    _selectController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocalSongs() async {
    setState(() => _isLoading = true);
    try {
      final songs = await _repo.getAllSongs();
      // Only show songs that have a physical local file or are explicitly local files
      setState(() {
        _localSongs = songs.where((s) {
          final isMetadataOnly =
              s.source == 'spotify' ||
              s.source == 'youtube' ||
              s.provider != null ||
              s.metadataSource != null ||
              s.audioPath.startsWith('http://') ||
              s.audioPath.startsWith('https://') ||
              s.audioPath.startsWith('meta_') ||
              s.audioPath.startsWith('spotify:') ||
              s.audioPath.startsWith('youtube:');
          return !isMetadataOnly;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error fetch local songs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final paths = result.files
          .map((f) => f.path)
          .whereType<String>()
          .toList();
      if (paths.isEmpty) return;

      await _executeImport(paths);
    } catch (e) {
      debugPrint('Error pick files: $e');
    }
  }

  Future<void> _importFolder() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null || selectedDirectory.isEmpty) return;

      await _executeImport([selectedDirectory]);
    } catch (e) {
      debugPrint('Error pick folder: $e');
    }
  }

  Future<void> _executeImport(List<String> paths) async {
    setState(() => _isImporting = true);

    final service = MusicImportService(repository: _repo);
    ImportProgressUpdate? latestProgress;

    // Show Non-blocking Progress Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final p = latestProgress;
          final processed = p?.processedFiles ?? 0;
          final total = p?.totalFiles ?? paths.length;
          final percent = total > 0 ? (processed / total) : 0.0;

          return AlertDialog(
            backgroundColor: V35Tokens.bgElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: V35Tokens.borderSubtle),
            ),
            title: Row(
              children: [
                Icon(Icons.file_download_outlined, color: V35Tokens.accent),
                const SizedBox(width: 8),
                Text(
                  'Mengimpor Musik...',
                  style: V35Tokens.heading.copyWith(
                    color: V35Tokens.textPrimary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? percent : null,
                    backgroundColor: V35Tokens.bgSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(V35Tokens.accent),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Proses: $processed / $total file',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: V35Tokens.textPrimary,
                  ),
                ),
                if (p != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'File: ${p.currentFile}',
                    style: const TextStyle(
                      color: V35Tokens.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Berhasil: ${p.importedCount} | Duplikat: ${p.skippedDuplicates} | Format Lain: ${p.unsupportedCount}',
                    style: const TextStyle(
                      color: V35Tokens.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  service.cancelImport();
                },
                child: const Text(
                  'Batalkan',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          );
        },
      ),
    );

    final summary = await service.importPaths(
      paths: paths,
      onProgress: (p) {
        latestProgress = p;
      },
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close progress dialog
      setState(() => _isImporting = false);

      final msg = summary.cancelled
          ? 'Impor dibatalkan. ${summary.importedCount} lagu berhasil disimpan.'
          : '${summary.importedCount} lagu berhasil diimpor (${summary.skippedDuplicates} duplikat dilewati).';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: summary.importedCount > 0
              ? AppColors.primary
              : Colors.orangeAccent,
        ),
      );

      await _fetchLocalSongs();
    }
  }

  Future<void> _deleteLocalSong(SongModel song) async {
    try {
      await _repo.deleteSong(song.id);
      setState(() {
        _localSongs.removeWhere((s) => s.id == song.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lagu lokal berhasil dihapus')),
        );
      }
    } catch (e) {
      debugPrint('Error delete local song: $e');
    }
  }

  Future<void> _bulkAddToPlaylist() async {
    final selectedIds = _selectController.selectedIds.toList();
    if (selectedIds.isEmpty) return;

    try {
      final playlists = await _repo.getPlaylists();
      if (!mounted) return;

      final chosenPlaylistIds = await PlaylistPickerDialog.show(
        context,
        playlists: playlists,
        selectedSongCount: selectedIds.length,
      );

      if (chosenPlaylistIds != null && chosenPlaylistIds.isNotEmpty) {
        final results = await _repo.addSongsToMultiplePlaylists(
          chosenPlaylistIds,
          selectedIds,
        );
        final totalAdded = results.values.fold<int>(
          0,
          (sum, count) => sum + count,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Berhasil menambahkan ${selectedIds.length} lagu ke ${chosenPlaylistIds.length} playlist ($totalAdded penambahan baru).',
              ),
              backgroundColor: AppColors.primary,
            ),
          );
          _selectController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan lagu ke playlist: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final visibleSongIds = _localSongs.map((s) => s.id).toList();

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        return PopScope(
          canPop: !_selectController.isSelectionMode,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_selectController.isSelectionMode) {
              _selectController.clear();
            }
          },
          child: Scaffold(
            appBar: _selectController.isSelectionMode
                ? SelectionActionBar(
                    controller: _selectController,
                    visibleSongIds: visibleSongIds,
                    onAddToPlaylist: _bulkAddToPlaylist,
                  )
                : AppBar(
                    title: Text(
                      'Lagu Terunduh / Lokal',
                      style: V35Tokens.heading.copyWith(
                        fontSize: 18,
                        color: V35Tokens.textPrimary,
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    actions: [
                      IconButton(
                        icon: Icon(Icons.link_rounded, color: V35Tokens.accent),
                        tooltip: 'Impor dari Tautan',
                        onPressed: () async {
                          final imported = await ImportLinkDialog.show(context);
                          if (imported == true && mounted) {
                            _fetchLocalSongs();
                          }
                        },
                      ),
                      if (!kIsWeb && Platform.isAndroid)
                        IconButton(
                          icon: const Icon(
                            Icons.bug_report_rounded,
                            color: Colors.amberAccent,
                          ),
                          tooltip: 'Diagnostik Playback',
                          onPressed: () =>
                              AndroidDiagnosticDialog.show(context),
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: V35Tokens.accent,
                        ),
                        tooltip: 'Segarkan',
                        onPressed: _fetchLocalSongs,
                      ),
                    ],
                  ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Import Action Zone
                    DragDropImportZone(
                      onPickFiles: _importFiles,
                      onPickFolder: _importFolder,
                      isImporting: _isImporting,
                    ),
                    const SizedBox(height: 20),

                    // Title bar & Play all
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daftar Lagu Lokal (${_localSongs.length})',
                          style: V35Tokens.heading.copyWith(
                            fontSize: 18,
                            color: V35Tokens.textPrimary,
                          ),
                        ),
                        if (_localSongs.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              player.playSong(
                                _localSongs.first,
                                playlist: _localSongs,
                                context: context,
                              );
                            },
                            icon: Icon(
                              Icons.play_circle_fill_rounded,
                              color: V35Tokens.accent,
                              size: 22,
                            ),
                            label: Text(
                              'Putar Semua',
                              style: TextStyle(
                                color: V35Tokens.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Song list or empty state
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _localSongs.isEmpty
                          ? V35EmptyState(
                              icon: Icons.music_off_rounded,
                              title: 'Belum Ada Lagu Lokal',
                              description:
                                  'Pilih file musik atau folder dari perangkat untuk mulai mendengarkan.',
                              primaryActionLabel: 'Impor File Musik',
                              onPrimaryAction: _importFiles,
                              secondaryActionLabel: 'Pilih Folder',
                              onSecondaryAction: _importFolder,
                            )
                          : ListView.builder(
                              itemCount: _localSongs.length,
                              itemBuilder: (context, index) {
                                final song = _localSongs[index];
                                final isCurrent =
                                    player.currentSong?.id == song.id;
                                final isSelected = _selectController.isSelected(
                                  song.id,
                                );

                                return V35TrackRow(
                                  index: index + 1,
                                  title: song.title,
                                  artist: song.artistName ?? 'Unknown Artist',
                                  album: song.albumTitle,
                                  duration: song.duration > 0
                                      ? '${(song.duration ~/ 60)}:${(song.duration % 60).toString().padLeft(2, '0')}'
                                      : null,
                                  artworkPath: song.cover,
                                  isPlaying: isCurrent && player.isPlaying,
                                  isSelected: isSelected,
                                  onTap: () {
                                    final handled = _selectController
                                        .handleItemTap(
                                          id: song.id,
                                          index: index,
                                          visibleIds: visibleSongIds,
                                        );
                                    if (!handled) {
                                      player.playSong(
                                        song,
                                        playlist: _localSongs,
                                        context: context,
                                      );
                                    }
                                  },
                                  onLongPress: () {
                                    _selectController.startSelection(
                                      song.id,
                                      index: index,
                                    );
                                  },
                                  trailing: _selectController.isSelectionMode
                                      ? Checkbox(
                                          activeColor: V35Tokens.accent,
                                          checkColor: Colors.black,
                                          value: isSelected,
                                          onChanged: (_) {
                                            _selectController.toggleSelection(
                                              song.id,
                                              index: index,
                                            );
                                          },
                                        )
                                      : PopupMenuButton<String>(
                                          color: V35Tokens.bgElevated,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: V35Tokens.brMd,
                                            side: const BorderSide(
                                              color: V35Tokens.borderSubtle,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.more_vert_rounded,
                                            color: V35Tokens.textMuted,
                                          ),
                                          onSelected: (val) {
                                            if (val == 'delete') {
                                              _deleteLocalSong(song);
                                            } else if (val == 'queue') {
                                              player.addToQueue(song);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Lagu ditambahkan ke Queue',
                                                  ),
                                                ),
                                              );
                                            } else if (val == 'play_next') {
                                              player.playNext(song);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Lagu dijadwalkan setelah lagu saat ini',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                              value: 'queue',
                                              child: Text(
                                                'Tambah ke Queue',
                                                style: TextStyle(
                                                  color: V35Tokens.textPrimary,
                                                ),
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'play_next',
                                              child: Text(
                                                'Putar Selanjutnya',
                                                style: TextStyle(
                                                  color: V35Tokens.textPrimary,
                                                ),
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text(
                                                'Hapus dari Lokal',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
