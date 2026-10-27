import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/playlist_model.dart';
import '../../repositories/local_music_repository.dart';
import 'playlist_detail_screen.dart';
import '../../widgets/dialogs/smart_playlist_editor_dialog.dart';

class PlaylistListScreen extends StatefulWidget {
  const PlaylistListScreen({super.key});

  @override
  State<PlaylistListScreen> createState() => _PlaylistListScreenState();
}

class _PlaylistListScreenState extends State<PlaylistListScreen> {
  final LocalMusicRepository _repo = LocalMusicRepository();
  List<PlaylistModel> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlaylists();
  }

  Future<void> _fetchPlaylists() async {
    setState(() => _isLoading = true);
    try {
      final playlists = await _repo.getAllPlaylists();
      setState(() {
        _playlists = playlists;
      });
    } catch (e) {
      debugPrint('Error fetch playlists: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreatePlaylistDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Buat Playlist Baru',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Playlist',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (Opsional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                final createdId = await _repo.createPlaylist(
                  name,
                  description: descController.text.trim(),
                );
                if (createdId > 0) {
                  _fetchPlaylists();
                }
              } catch (e) {
                debugPrint('Error create playlist: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: V35Tokens.accent),
            child: const Text(
              'Simpan',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlaylist(PlaylistModel playlist) async {
    try {
      if (playlist.id != null) {
        await _repo.deletePlaylist(playlist.id!);
        _fetchPlaylists();
      }
    } catch (e) {
      debugPrint('Error delete playlist: $e');
    }
  }

  Future<void> _showCreateOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.playlist_add_rounded,
                  color: V35Tokens.accent,
                  size: 28,
                ),
                title: const Text(
                  'Buat Playlist Normal',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Pilih lagu-lagu secara manual',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreatePlaylistDialog();
                },
              ),
              const Divider(color: AppColors.divider),
              ListTile(
                leading: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.amberAccent,
                  size: 28,
                ),
                title: const Text(
                  'Buat Smart Playlist',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Kumpulkan lagu otomatis berdasarkan aturan/kriteria',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreateSmartPlaylistDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateSmartPlaylistDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const SmartPlaylistEditorDialog(),
    );

    if (result != null && result['name'] != null) {
      try {
        await _repo.createSmartPlaylist(
          name: result['name'],
          description: result['description'],
          config: result['config'],
        );
        _fetchPlaylists();
      } catch (e) {
        debugPrint('Error create smart playlist: $e');
      }
    }
  }

  Future<void> _editSmartPlaylist(PlaylistModel playlist) async {
    if (!playlist.isSmart || playlist.id == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SmartPlaylistEditorDialog(
        initialName: playlist.name,
        initialDescription: playlist.description,
        initialConfig: playlist.smartConfig,
        isEditing: true,
      ),
    );

    if (result != null && result['name'] != null) {
      try {
        await _repo.updateSmartPlaylist(
          playlistId: playlist.id!,
          name: result['name'],
          description: result['description'],
          config: result['config'],
        );
        _fetchPlaylists();
      } catch (e) {
        debugPrint('Error update smart playlist: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Playlist Saya'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.add_rounded,
                  color: V35Tokens.accent,
                  size: 28,
                ),
                onPressed: _showCreateOptions,
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
                children: [
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: V35Tokens.accent,
                            ),
                          )
                        : _playlists.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.playlist_play_rounded,
                                  size: 64,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum ada playlist.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _showCreateOptions,
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.black,
                                  ),
                                  label: const Text(
                                    'Buat Playlist Baru',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: V35Tokens.accent,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _playlists.length,
                            itemBuilder: (context, index) {
                              final pl = _playlists[index];
                              final isSmart = pl.isSmart;
                              return ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isSmart
                                        ? Colors.amber.withValues(alpha: 0.15)
                                        : AppColors.card,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSmart
                                        ? Border.all(
                                            color: Colors.amberAccent
                                                .withValues(alpha: 0.5),
                                          )
                                        : null,
                                  ),
                                  child: Icon(
                                    isSmart
                                        ? Icons.auto_awesome_rounded
                                        : Icons.music_note,
                                    color: isSmart
                                        ? Colors.amberAccent
                                        : V35Tokens.accent,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pl.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (isSmart)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'SMART',
                                          style: TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  pl.description?.isNotEmpty == true
                                      ? pl.description!
                                      : (isSmart
                                            ? 'Koleksi dinamis otomatis'
                                            : 'Playlist manual'),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: AppColors.textMuted,
                                  ),
                                  onSelected: (val) {
                                    if (val == 'delete') {
                                      _deletePlaylist(pl);
                                    } else if (val == 'edit_smart') {
                                      _editSmartPlaylist(pl);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    if (isSmart)
                                      const PopupMenuItem(
                                        value: 'edit_smart',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.tune_rounded,
                                              size: 18,
                                              color: Colors.amberAccent,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Ubah Aturan Smart',
                                              style: TextStyle(
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.redAccent,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Hapus Playlist',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) => PlaylistDetailScreen(
                                            playlist: pl,
                                          ),
                                        ),
                                      )
                                      .then((_) => _fetchPlaylists());
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
