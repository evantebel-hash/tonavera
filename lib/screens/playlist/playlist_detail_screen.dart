import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/playlist_model.dart';
import '../../models/smart_playlist_model.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../repositories/local_music_repository.dart';
import '../../services/smart_playlist_service.dart';
import '../../widgets/dialogs/smart_playlist_editor_dialog.dart';
import '../../controllers/multi_select_controller.dart';
import '../../widgets/selection_action_bar.dart';
import '../../widgets/dialogs/playlist_picker_dialog.dart';
import '../../services/download_service.dart';
import '../../widgets/v35/v35_track_row.dart';
import '../../widgets/v35/v35_empty_state.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final PlaylistModel playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final LocalMusicRepository _repo = LocalMusicRepository();
  final MultiSelectController _selectController = MultiSelectController();
  late SmartPlaylistService _smartService;
  late PlaylistModel _currentPlaylist;
  List<SongModel> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentPlaylist = widget.playlist;
    _smartService = SmartPlaylistService(repository: _repo);
    _selectController.addListener(_onSelectionChanged);
    _fetchPlaylistSongs();
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

  Future<void> _fetchPlaylistSongs() async {
    if (_currentPlaylist.id == null) return;
    setState(() => _isLoading = true);
    try {
      if (_currentPlaylist.isSmart) {
        final matchedSongs = await _smartService.evaluateSmartPlaylist(
          _currentPlaylist,
        );
        setState(() {
          _songs = matchedSongs;
        });
      } else {
        final songs = await _repo.getPlaylistSongs(_currentPlaylist.id!);
        setState(() {
          _songs = songs;
        });
      }
    } catch (e) {
      debugPrint('Error fetch playlist detail: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editSmartRules() async {
    if (!_currentPlaylist.isSmart || _currentPlaylist.id == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SmartPlaylistEditorDialog(
        initialName: _currentPlaylist.name,
        initialDescription: _currentPlaylist.description,
        initialConfig: _currentPlaylist.smartConfig,
        isEditing: true,
      ),
    );

    if (result != null && result['name'] != null) {
      try {
        await _repo.updateSmartPlaylist(
          playlistId: _currentPlaylist.id!,
          name: result['name'],
          description: result['description'],
          config: result['config'],
        );
        final updated = await _repo.getPlaylistById(_currentPlaylist.id!);
        if (updated != null) {
          setState(() {
            _currentPlaylist = updated;
          });
        }
        _fetchPlaylistSongs();
      } catch (e) {
        debugPrint('Error update smart playlist: $e');
      }
    }
  }

  Future<void> _showAddSongDialog() async {
    try {
      final allAvailableSongs = await _repo.getAllSongs();
      final existingIds = _songs.map((s) => s.id).toSet();
      // Filter out songs that are already in the playlist
      final candidateSongs = allAvailableSongs
          .where((s) => !existingIds.contains(s.id))
          .toList();

      if (!mounted) return;

      if (candidateSongs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua lagu lokal sudah ada di dalam playlist ini.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      final selectedSongIds = await showModalBottomSheet<List<int>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: V35Tokens.bgSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final selected = <int>{};
          String query = '';

          return StatefulBuilder(
            builder: (context, setModalState) {
              final filtered = candidateSongs.where((s) {
                if (query.trim().isEmpty) return true;
                final q = query.trim().toLowerCase();
                final titleMatch = s.title.toLowerCase().contains(q);
                final artistMatch = (s.artistName ?? '').toLowerCase().contains(
                  q,
                );
                return titleMatch || artistMatch;
              }).toList();

              final allFilteredSelected =
                  filtered.isNotEmpty &&
                  filtered.every((s) => selected.contains(s.id));

              return DraggableScrollableSheet(
                initialChildSize: 0.75,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: V35Tokens.textMuted.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pilih Lagu untuk Ditambahkan',
                              style: V35Tokens.heading.copyWith(
                                fontSize: 18,
                                color: V35Tokens.textPrimary,
                              ),
                            ),
                            if (filtered.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    if (allFilteredSelected) {
                                      for (final s in filtered) {
                                        selected.remove(s.id);
                                      }
                                    } else {
                                      for (final s in filtered) {
                                        selected.add(s.id);
                                      }
                                    }
                                  });
                                },
                                icon: Icon(
                                  allFilteredSelected
                                      ? Icons.deselect_rounded
                                      : Icons.select_all_rounded,
                                  size: 18,
                                  color: V35Tokens.accent,
                                ),
                                label: Text(
                                  allFilteredSelected
                                      ? 'Batal Semua'
                                      : 'Pilih Semua',
                                  style: TextStyle(
                                    color: V35Tokens.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          style: const TextStyle(
                            color: V35Tokens.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Cari judul lagu atau nama artis...',
                            hintStyle: const TextStyle(
                              color: V35Tokens.textMuted,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: V35Tokens.textMuted,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: V35Tokens.bgVoid,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: V35Tokens.borderSubtle,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: V35Tokens.borderSubtle,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: V35Tokens.accent),
                            ),
                          ),
                          onChanged: (val) => setModalState(() => query = val),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Tidak ada lagu yang cocok.',
                                    style: TextStyle(
                                      color: V35Tokens.textSecondary,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: filtered.length,
                                  itemBuilder: (c, index) {
                                    final song = filtered[index];
                                    final isChecked = selected.contains(
                                      song.id,
                                    );

                                    return CheckboxListTile(
                                      activeColor: V35Tokens.accent,
                                      checkColor: Colors.black,
                                      value: isChecked,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                      title: Text(
                                        song.title,
                                        style: const TextStyle(
                                          color: V35Tokens.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        song.artistName ?? 'Unknown Artist',
                                        style: const TextStyle(
                                          color: V35Tokens.textSecondary,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onChanged: (val) {
                                        setModalState(() {
                                          if (val == true) {
                                            selected.add(song.id);
                                          } else {
                                            selected.remove(song.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: V35Tokens.borderSubtle,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: V35Tokens.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: V35Tokens.accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: selected.isEmpty
                                    ? null
                                    : () => Navigator.of(
                                        ctx,
                                      ).pop(selected.toList()),
                                icon: const Icon(
                                  Icons.playlist_add_check_rounded,
                                  color: Colors.black,
                                ),
                                label: Text(
                                  'Tambahkan (${selected.length})',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );

      if (selectedSongIds != null &&
          selectedSongIds.isNotEmpty &&
          widget.playlist.id != null) {
        final addedCount = await _repo.addSongsToPlaylist(
          widget.playlist.id!,
          selectedSongIds,
        );
        await _fetchPlaylistSongs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Berhasil menambahkan $addedCount lagu ke "${widget.playlist.name}".',
              ),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetch songs for modal: $e');
    }
  }

  Future<void> _removeSongFromPlaylist(int songId) async {
    try {
      if (widget.playlist.id != null) {
        await _repo.removeSongFromPlaylist(widget.playlist.id!, songId);
        _fetchPlaylistSongs();
      }
    } catch (e) {
      debugPrint('Error remove song from playlist: $e');
    }
  }

  Future<void> _bulkAddToOtherPlaylists() async {
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
            content: Text('Gagal menambahkan lagu: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _bulkRemoveFromPlaylist() async {
    final selectedIds = _selectController.selectedIds.toList();
    if (selectedIds.isEmpty ||
        _currentPlaylist.id == null ||
        _currentPlaylist.isSmart)
      return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V35Tokens.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: V35Tokens.borderSubtle),
        ),
        title: Text(
          'Hapus Lagu dari Playlist',
          style: V35Tokens.heading.copyWith(
            fontSize: 18,
            color: V35Tokens.textPrimary,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus ${selectedIds.length} lagu dari "${_currentPlaylist.name}"?',
          style: V35Tokens.body.copyWith(
            color: V35Tokens.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: V35Tokens.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final removedCount = await _repo.removeSongsFromPlaylist(
          _currentPlaylist.id!,
          selectedIds,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$removedCount lagu berhasil dihapus dari playlist.',
              ),
              backgroundColor: AppColors.primary,
            ),
          );
          _selectController.clear();
          await _fetchPlaylistSongs();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus lagu dari playlist: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _downloadSelectedSongs() async {
    final selectedIds = _selectController.selectedIds.toSet();
    final selectedSongs = _songs
        .where((s) => selectedIds.contains(s.id))
        .toList();
    if (selectedSongs.isEmpty) return;

    final downloadableSongs = selectedSongs
        .where((s) => DownloadService.isDownloadableSource(s))
        .toList();

    if (downloadableSongs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lagu yang dipilih tidak memiliki sumber audio langsung yang dapat diunduh.',
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }

    int enqueuedCount = 0;
    for (final song in downloadableSongs) {
      final res = await DownloadService.instance.enqueueDownload(song);
      if (res != null) enqueuedCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$enqueuedCount dari ${selectedSongs.length} lagu terpilih ditambahkan ke antrean Download Manager.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      _selectController.clear();
    }
  }

  Future<void> _downloadAllSongs() async {
    if (_songs.isEmpty) return;

    final downloadableSongs = _songs
        .where((s) => DownloadService.isDownloadableSource(s))
        .toList();

    if (downloadableSongs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Playlist ini tidak memiliki sumber audio langsung yang dapat diunduh.',
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V35Tokens.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: V35Tokens.borderSubtle),
        ),
        title: Text(
          'Unduh Playlist?',
          style: V35Tokens.heading.copyWith(
            fontSize: 18,
            color: V35Tokens.textPrimary,
          ),
        ),
        content: Text(
          '${downloadableSongs.length} dari ${_songs.length} lagu dapat diunduh ke penyimpanan lokal.\n\nApakah Anda ingin memasukkan lagu ke antrean Download Manager?',
          style: V35Tokens.body.copyWith(
            color: V35Tokens.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: V35Tokens.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: V35Tokens.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Unduh Sekarang',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      int count = 0;
      for (final song in downloadableSongs) {
        final res = await DownloadService.instance.enqueueDownload(song);
        if (res != null) count++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count lagu ditambahkan ke Download Manager.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final isSmart = _currentPlaylist.isSmart;
    final visibleSongIds = _songs.map((s) => s.id).toList();

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
                    onAddToPlaylist: _bulkAddToOtherPlaylists,
                    onRemoveFromPlaylist: isSmart
                        ? null
                        : _bulkRemoveFromPlaylist,
                    onDownload: _downloadSelectedSongs,
                    removeTooltip: 'Hapus dari Playlist ini',
                  )
                : AppBar(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _currentPlaylist.name,
                            style: V35Tokens.heading.copyWith(
                              fontSize: 18,
                              color: V35Tokens.textPrimary,
                            ),
                          ),
                        ),
                        if (isSmart)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.amberAccent.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: const Text(
                              'SMART',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    actions: [
                      if (isSmart) ...[
                        IconButton(
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: V35Tokens.accent,
                          ),
                          tooltip: 'Segarkan Kriteria',
                          onPressed: _fetchPlaylistSongs,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.tune_rounded,
                            color: Colors.amberAccent,
                          ),
                          tooltip: 'Edit Aturan Smart',
                          onPressed: _editSmartRules,
                        ),
                      ] else ...[
                        IconButton(
                          icon: Icon(
                            Icons.add_rounded,
                            color: V35Tokens.accent,
                            size: 28,
                          ),
                          tooltip: 'Tambah Lagu',
                          onPressed: _showAddSongDialog,
                        ),
                      ],
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
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: V35Tokens.bgSurface,
                        borderRadius: V35Tokens.brXl,
                        border: Border.all(
                          color: isSmart
                              ? Colors.amberAccent.withValues(alpha: 0.4)
                              : V35Tokens.borderSubtle,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: isSmart
                                      ? Colors.amber.withValues(alpha: 0.15)
                                      : V35Tokens.accent.withValues(
                                          alpha: 0.15,
                                        ),
                                  borderRadius: V35Tokens.brLg,
                                  border: Border.all(
                                    color: isSmart
                                        ? Colors.amberAccent.withValues(
                                            alpha: 0.3,
                                          )
                                        : V35Tokens.accent.withValues(
                                            alpha: 0.3,
                                          ),
                                  ),
                                ),
                                child: Icon(
                                  isSmart
                                      ? Icons.auto_awesome_rounded
                                      : Icons.playlist_play_rounded,
                                  color: isSmart
                                      ? Colors.amberAccent
                                      : V35Tokens.accent,
                                  size: 38,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentPlaylist.name,
                                      style: V35Tokens.heading.copyWith(
                                        fontSize: 22,
                                        color: V35Tokens.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_songs.length} lagu ${isSmart ? 'cocok secara otomatis' : ''}',
                                      style: V35Tokens.secondary.copyWith(
                                        color: V35Tokens.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_songs.isNotEmpty) ...[
                                IconButton(
                                  icon: Icon(
                                    Icons.download_for_offline_rounded,
                                    color: V35Tokens.accent,
                                    size: 28,
                                  ),
                                  tooltip: 'Unduh Playlist',
                                  onPressed: _downloadAllSongs,
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    player.playSong(
                                      _songs.first,
                                      playlist: _songs,
                                      context: context,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 22,
                                  ),
                                  label: const Text(
                                    'Putar',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: V35Tokens.accent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: V35Tokens.brMd,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (isSmart &&
                              _currentPlaylist.smartConfig != null &&
                              _currentPlaylist
                                  .smartConfig!
                                  .rules
                                  .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(
                              color: V35Tokens.borderSubtle,
                              height: 1,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Kriteria: ${_currentPlaylist.smartConfig!.rules.map((r) => r.humanReadableDescription).join(' ${_currentPlaylist.smartConfig!.logic == SmartRuleLogic.all ? 'DAN' : 'ATAU'} ')}',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Playlist Songs List
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _songs.isEmpty
                          ? V35EmptyState(
                              icon: isSmart
                                  ? Icons.search_off_rounded
                                  : Icons.playlist_remove_rounded,
                              title: isSmart
                                  ? 'Belum Ada Lagu yang Memenuhi Kriteria'
                                  : 'Playlist Ini Masih Kosong',
                              description: isSmart
                                  ? 'Belum ada lagu lokal yang cocok dengan kriteria Smart Playlist saat ini.'
                                  : 'Tambahkan lagu dari pustaka lokal Anda untuk mulai mendengarkan.',
                              primaryActionLabel: isSmart
                                  ? 'Ubah Aturan Kriteria'
                                  : 'Tambah Lagu',
                              onPrimaryAction: isSmart
                                  ? _editSmartRules
                                  : _showAddSongDialog,
                            )
                          : isSmart
                          ? ListView.builder(
                              itemCount: _songs.length,
                              itemBuilder: (context, index) {
                                final song = _songs[index];
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
                                        playlist: _songs,
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
                                      : null,
                                );
                              },
                            )
                          : ReorderableListView.builder(
                              buildDefaultDragHandles:
                                  !_selectController.isSelectionMode,
                              itemCount: _songs.length,
                              // ignore: deprecated_member_use
                              onReorder: (oldIndex, newIndex) async {
                                setState(() {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  final item = _songs.removeAt(oldIndex);
                                  _songs.insert(newIndex, item);
                                });
                                if (_currentPlaylist.id != null) {
                                  await _repo.reorderPlaylistSongs(
                                    _currentPlaylist.id!,
                                    _songs.map((s) => s.id).toList(),
                                  );
                                }
                              },
                              itemBuilder: (context, index) {
                                final song = _songs[index];
                                final isCurrent =
                                    player.currentSong?.id == song.id;
                                final isSelected = _selectController.isSelected(
                                  song.id,
                                );

                                return Container(
                                  key: ValueKey('pl_song_${song.id}_$index'),
                                  child: V35TrackRow(
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
                                          playlist: _songs,
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
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: Colors.redAccent,
                                                  size: 20,
                                                ),
                                                tooltip: 'Hapus dari Playlist',
                                                onPressed: () =>
                                                    _removeSongFromPlaylist(
                                                      song.id,
                                                    ),
                                              ),
                                              ReorderableDragStartListener(
                                                index: index,
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 4.0,
                                                  ),
                                                  child: Icon(
                                                    Icons.drag_handle_rounded,
                                                    color: V35Tokens.textMuted,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
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
