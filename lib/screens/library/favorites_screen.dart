import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../repositories/local_music_repository.dart';
import '../../widgets/song_tile.dart';
import '../../controllers/multi_select_controller.dart';
import '../../widgets/selection_action_bar.dart';
import '../../widgets/dialogs/playlist_picker_dialog.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final LocalMusicRepository _repo = LocalMusicRepository();
  final MultiSelectController _selectController = MultiSelectController();
  List<SongModel> _favoriteSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectController.addListener(_onSelectionChanged);
    _fetchFavorites();
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
                'Berhasil menambahkan ${selectedIds.length} lagu favorit ke ${chosenPlaylistIds.length} playlist ($totalAdded penambahan baru).',
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

  Future<void> _fetchFavorites() async {
    setState(() => _isLoading = true);
    try {
      final favorites = await _repo.getFavorites();
      setState(() {
        _favoriteSongs = favorites;
      });
    } catch (e) {
      debugPrint('Error fetch favorites: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final visibleSongIds = _favoriteSongs.map((s) => s.id).toList();

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
                title: const Text('Lagu Favorit Saya'),
                backgroundColor: Colors.transparent,
                elevation: 0,
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
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.25),
                        AppColors.card,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Koleksi Favorit',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_favoriteSongs.length} lagu tersimpan dalam daftar favorit',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_favoriteSongs.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () {
                            player.playSong(
                              _favoriteSongs.first,
                              playlist: _favoriteSongs,
                              context: context,
                            );
                          },
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Putar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Favorites list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _favoriteSongs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.favorite_border_rounded,
                                size: 64,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Belum ada lagu favorit.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tekan ikon hati ❤️ pada lagu yang Anda sukai.',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _favoriteSongs.length,
                          itemBuilder: (context, index) {
                            final song = _favoriteSongs[index];
                            final isCurrent = player.currentSong?.id == song.id;
                            final isSelected = _selectController.isSelected(
                              song.id,
                            );

                            return SongTile(
                              song: song,
                              isPlaying: isCurrent && player.isPlaying,
                              isSelected: isSelected,
                              isSelectionMode:
                                  _selectController.isSelectionMode,
                              onLongPress: () {
                                _selectController.startSelection(
                                  song.id,
                                  index: index,
                                );
                              },
                              onTap: () {
                                final handled = _selectController.handleItemTap(
                                  id: song.id,
                                  index: index,
                                  visibleIds: visibleSongIds,
                                );
                                if (!handled) {
                                  player.playSong(
                                    song,
                                    playlist: _favoriteSongs,
                                    context: context,
                                  );
                                }
                              },
                              trailing: _selectController.isSelectionMode
                                  ? Checkbox(
                                      activeColor: AppColors.primary,
                                      value: isSelected,
                                      onChanged: (_) {
                                        _selectController.toggleSelection(
                                          song.id,
                                          index: index,
                                        );
                                      },
                                    )
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.favorite_rounded,
                                        color: AppColors.accent,
                                      ),
                                      onPressed: () async {
                                        await player.toggleFavorite(song);
                                        _fetchFavorites();
                                      },
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
  }
}
