import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../controllers/multi_select_controller.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/player_provider.dart';
import '../../repositories/local_music_repository.dart';
import '../../widgets/selection_action_bar.dart';
import '../../widgets/dialogs/playlist_picker_dialog.dart';
import '../../widgets/v35/v35_track_row.dart';
import '../../widgets/v35/v35_track_actions.dart';
import '../../widgets/v35/v35_empty_state.dart';
import '../youtube/youtube_search_screen.dart';
import '../spotify/spotify_discovery_screen.dart';

/// V3.5 Obsidian Emerald Search Screen.
///
/// Features:
/// - Ergonomic search field with instant clear and debounce
/// - Fast discovery shortcuts for Spotify and YouTube Music
/// - V35TrackRow result tiles with playing state indicator
/// - Seamless preservation of MultiSelectController batch playlist additions.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MultiSelectController _selectController = MultiSelectController();
  final LocalMusicRepository _repo = LocalMusicRepository();

  @override
  void initState() {
    super.initState();
    _selectController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _selectController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    Provider.of<CatalogProvider>(
      context,
      listen: false,
    ).fetchSongs(query: query);
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
              backgroundColor: V35Tokens.success,
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
    final catalog = Provider.of<CatalogProvider>(context);
    final visibleSongIds = catalog.songs.map((s) => s.id).toList();

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, _) {
        return PopScope(
          canPop: !_selectController.isSelectionMode,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_selectController.isSelectionMode) {
              _selectController.clear();
            }
          },
          child: Scaffold(
            backgroundColor: V35Tokens.bgVoid,
            appBar: _selectController.isSelectionMode
                ? SelectionActionBar(
                    controller: _selectController,
                    visibleSongIds: visibleSongIds,
                    onAddToPlaylist: _bulkAddToPlaylist,
                  )
                : null,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: V35Tokens.space16,
                  vertical: V35Tokens.space12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_selectController.isSelectionMode) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pencarian',
                            style: V35Tokens.display.copyWith(
                              fontSize: 26.0,
                              fontWeight: FontWeight.w700,
                              color: V35Tokens.textPrimary,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const SpotifyDiscoveryScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.hub_rounded,
                                  color: Color(0xFF1DB954),
                                  size: 18,
                                ),
                                label: const Text(
                                  'Spotify',
                                  style: TextStyle(color: Color(0xFF1DB954)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const YouTubeSearchScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.travel_explore_rounded,
                                  color: Color(0xFFFF0000),
                                  size: 18,
                                ),
                                label: const Text(
                                  'YouTube',
                                  style: TextStyle(color: Color(0xFFFF0000)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: V35Tokens.space16),
                    ],

                    // --- SEARCH TEXT FIELD ---
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: V35Tokens.body.copyWith(
                        color: V35Tokens.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari lagu, artis, atau album...',
                        hintStyle: V35Tokens.secondary.copyWith(
                          color: V35Tokens.textMuted,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: V35Tokens.accent,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: V35Tokens.textMuted,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: V35Tokens.bgSurface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: V35Tokens.space16,
                          vertical: V35Tokens.space12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: V35Tokens.brMd,
                          borderSide: const BorderSide(
                            color: V35Tokens.borderSubtle,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: V35Tokens.brMd,
                          borderSide: BorderSide(
                            color: V35Tokens.accent,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: V35Tokens.space16),

                    // --- RESULTS / EMPTY / LOADING ---
                    Expanded(
                      child: catalog.isLoading
                          ? Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: V35Tokens.accent,
                                ),
                              ),
                            )
                          : catalog.songs.isEmpty
                          ? V35EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'Tidak Ada Hasil',
                              description: _searchController.text.trim().isEmpty
                                  ? 'Ketik nama lagu, artis, atau album untuk mulai mencari.'
                                  : 'Tidak ditemukan lagu untuk "${_searchController.text}".',
                            )
                          : Consumer<PlayerProvider>(
                              builder: (context, player, child) {
                                return ListView.builder(
                                  itemCount: catalog.songs.length,
                                  itemBuilder: (context, index) {
                                    final song = catalog.songs[index];
                                    final isSelected = _selectController
                                        .isSelected(song.id);
                                    final isPlayingThis =
                                        player.currentSong?.id == song.id;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2.0,
                                      ),
                                      child: V35TrackRow(
                                        index: index + 1,
                                        title: song.title,
                                        artist: song.artistName,
                                        album: song.albumTitle,
                                        duration: _formatDuration(
                                          song.duration,
                                        ),
                                        artworkPath: song.cover,
                                        isSelected: isSelected,
                                        isPlaying: isPlayingThis,
                                        onLongPress: () {
                                          _selectController.startSelection(
                                            song.id,
                                            index: index,
                                          );
                                        },
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
                                              playlist: catalog.songs,
                                              context: context,
                                            );
                                          }
                                        },
                                        onMore:
                                            _selectController.isSelectionMode
                                            ? null
                                            : () => V35TrackActions.show(
                                                context,
                                                song: song,
                                                player: player,
                                              ),
                                        trailing:
                                            _selectController.isSelectionMode
                                            ? Checkbox(
                                                activeColor: V35Tokens.accent,
                                                checkColor: Colors.black,
                                                value: isSelected,
                                                onChanged: (_) {
                                                  _selectController
                                                      .toggleSelection(
                                                        song.id,
                                                        index: index,
                                                      );
                                                },
                                              )
                                            : null,
                                      ),
                                    );
                                  },
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
