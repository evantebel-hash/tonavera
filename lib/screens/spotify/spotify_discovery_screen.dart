import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/spotify_provider.dart';
import '../../repositories/local_music_repository.dart';
import '../../services/metadata/metadata_model.dart';
import '../../services/metadata/spotify_url_parser.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialogs/playlist_picker_dialog.dart';

class SpotifyDiscoveryScreen extends StatefulWidget {
  final String? initialQuery;

  const SpotifyDiscoveryScreen({super.key, this.initialQuery});

  @override
  State<SpotifyDiscoveryScreen> createState() => _SpotifyDiscoveryScreenState();
}

class _SpotifyDiscoveryScreenState extends State<SpotifyDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTrackIds = {};
  bool _isSelectionMode = false;
  int _selectedCategoryTab =
      0; // 0: Tracks, 1: Albums, 2: Playlists, 3: Artists

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<SpotifyProvider>(
          context,
          listen: false,
        ).executeSearch(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      final text = data.text!.trim();
      _searchController.text = text;
      if (mounted) {
        Provider.of<SpotifyProvider>(
          context,
          listen: false,
        ).executeSearch(text);
      }
    }
  }

  void _openInBrowser(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isAndroid) {
        await Process.run('am', [
          'start',
          '-a',
          'android.intent.action.VIEW',
          '-d',
          url,
        ]);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Buka URL: $url')));
      }
    }
  }

  String _getTrackId(MusicMetadataResult t) =>
      t.spotifyId ?? '${t.title}|${t.displayArtist}';

  void _toggleSelect(MusicMetadataResult t) {
    final id = _getTrackId(t);
    setState(() {
      if (_selectedTrackIds.contains(id)) {
        _selectedTrackIds.remove(id);
        if (_selectedTrackIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedTrackIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll(List<MusicMetadataResult> tracks) {
    setState(() {
      _selectedTrackIds.addAll(tracks.map(_getTrackId));
      _isSelectionMode = true;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTrackIds.clear();
      _isSelectionMode = false;
    });
  }

  List<MusicMetadataResult> _getSelectedTracks(
    List<MusicMetadataResult> allTracks,
  ) {
    return allTracks
        .where((t) => _selectedTrackIds.contains(_getTrackId(t)))
        .toList();
  }

  Future<void> _handleAddToLibrary(
    BuildContext context,
    List<MusicMetadataResult> selectedTracks,
    SpotifyProvider spotify, {
    String? defaultPlaylistTitle,
  }) async {
    if (selectedTracks.isEmpty) return;

    final repo = LocalMusicRepository();
    try {
      final playlists = await repo.getPlaylists();
      if (!context.mounted) return;

      final chosen = await PlaylistPickerDialog.show(
        context,
        playlists: playlists,
        selectedSongCount: selectedTracks.length,
      );

      if (chosen != null && chosen.isNotEmpty) {
        if (!context.mounted) return;
        await spotify.addTracksToLibrary(
          context,
          selectedTracks,
          targetPlaylistIds: chosen,
        );
      } else if (chosen != null && chosen.isEmpty) {
        if (!context.mounted) return;
        await spotify.addTracksToLibrary(
          context,
          selectedTracks,
          playlistTitle: defaultPlaylistTitle,
        );
      }
    } catch (e) {
      if (context.mounted) {
        await spotify.addTracksToLibrary(
          context,
          selectedTracks,
          playlistTitle: defaultPlaylistTitle,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spotify = Provider.of<SpotifyProvider>(context);
    final entity = spotify.currentEntity;
    final tracks = spotify.tracks;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSelectionMode) {
          _clearSelection();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSelectionMode
              ? Text(
                  '${_selectedTrackIds.length} Dipilih',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : const Row(
                  children: [
                    Icon(
                      Icons.stream_rounded,
                      color: Color(0xFF1DB954),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Spotify Discovery',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: _isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clearSelection,
                )
              : null,
          actions: [
            if (_isSelectionMode) ...[
              TextButton(
                onPressed: () => _selectAll(tracks),
                child: const Text(
                  'Pilih Semua',
                  style: TextStyle(color: Color(0xFF1DB954)),
                ),
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            // Search / URL Input Field
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari musik atau paste link Spotify...',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF1DB954),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  spotify.searchWithDebounce('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {});
                        spotify.searchWithDebounce(val);
                      },
                      onSubmitted: (val) {
                        spotify.executeSearch(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.paste_rounded,
                      color: Color(0xFF1DB954),
                    ),
                    tooltip: 'Paste Link Spotify',
                    onPressed: _pasteFromClipboard,
                  ),
                ],
              ),
            ),

            // Category Filter Chips (Lagu, Album, Playlist, Artis) when available
            if (!spotify.isSearching &&
                (spotify.albums.isNotEmpty ||
                    spotify.playlists.isNotEmpty ||
                    spotify.artists.isNotEmpty))
              Container(
                height: 38,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ChoiceChip(
                      label: Text('Lagu (${tracks.length})'),
                      selected: _selectedCategoryTab == 0,
                      selectedColor: const Color(0xFF1DB954),
                      labelStyle: TextStyle(
                        color: _selectedCategoryTab == 0
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedCategoryTab = 0),
                    ),
                    const SizedBox(width: 8),
                    if (spotify.albums.isNotEmpty) ...[
                      ChoiceChip(
                        label: Text('Album (${spotify.albums.length})'),
                        selected: _selectedCategoryTab == 1,
                        selectedColor: const Color(0xFF1DB954),
                        labelStyle: TextStyle(
                          color: _selectedCategoryTab == 1
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategoryTab = 1),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (spotify.playlists.isNotEmpty) ...[
                      ChoiceChip(
                        label: Text('Playlist (${spotify.playlists.length})'),
                        selected: _selectedCategoryTab == 2,
                        selectedColor: const Color(0xFF1DB954),
                        labelStyle: TextStyle(
                          color: _selectedCategoryTab == 2
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategoryTab = 2),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (spotify.artists.isNotEmpty)
                      ChoiceChip(
                        label: Text('Artis (${spotify.artists.length})'),
                        selected: _selectedCategoryTab == 3,
                        selectedColor: const Color(0xFF1DB954),
                        labelStyle: TextStyle(
                          color: _selectedCategoryTab == 3
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategoryTab = 3),
                      ),
                  ],
                ),
              ),

            // Progress Banner during batch resolution
            if (spotify.isResolving && spotify.resolvingProgress != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: const Color(0xFF1DB954).withAlpha(40),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1DB954),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        spotify.resolvingProgress!,
                        style: const TextStyle(
                          color: Color(0xFF1DB954),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Content Area
            Expanded(
              child: spotify.isSearching
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF1DB954)),
                          SizedBox(height: 12),
                          Text(
                            'Mencari di Spotify...',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : spotify.searchError != null &&
                        tracks.isEmpty &&
                        spotify.albums.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          spotify.searchError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                    )
                  : tracks.isEmpty &&
                        spotify.albums.isEmpty &&
                        spotify.playlists.isEmpty &&
                        spotify.artists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_music_rounded,
                            size: 64,
                            color: AppColors.textMuted.withAlpha(100),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Cari lagu atau paste tautan Spotify (Track, Album, Playlist)',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : _selectedCategoryTab == 1
                  ? ListView.builder(
                      itemCount: spotify.albums.length,
                      itemBuilder: (ctx, i) => _buildEntityCard(
                        context: ctx,
                        entity: spotify.albums[i],
                        spotify: spotify,
                      ),
                    )
                  : _selectedCategoryTab == 2
                  ? ListView.builder(
                      itemCount: spotify.playlists.length,
                      itemBuilder: (ctx, i) => _buildEntityCard(
                        context: ctx,
                        entity: spotify.playlists[i],
                        spotify: spotify,
                      ),
                    )
                  : _selectedCategoryTab == 3
                  ? ListView.builder(
                      itemCount: spotify.artists.length,
                      itemBuilder: (ctx, i) => _buildEntityCard(
                        context: ctx,
                        entity: spotify.artists[i],
                        spotify: spotify,
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        // Album / Playlist Header if direct URL import or selected entity
                        if (entity != null &&
                            entity.type != SpotifyEntityType.track)
                          SliverToBoxAdapter(
                            child: _buildEntityHeader(
                              context,
                              entity,
                              tracks,
                              spotify,
                            ),
                          ),

                        // Track List
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final track = tracks[index];
                              final id = _getTrackId(track);
                              final isSelected = _selectedTrackIds.contains(id);
                              final isResolving = spotify.isTrackResolving(
                                track,
                              );

                              return _buildTrackTile(
                                context: context,
                                track: track,
                                index: index,
                                isSelected: isSelected,
                                isResolving: isResolving,
                                spotify: spotify,
                                tracks: tracks,
                              );
                            }, childCount: tracks.length),
                          ),
                        ),
                      ],
                    ),
            ),

            // Selection Bottom Action Bar
            if (_isSelectionMode && _selectedTrackIds.isNotEmpty)
              _buildSelectionBar(context, spotify, tracks),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityCard({
    required BuildContext context,
    required MusicMetadataResult entity,
    required SpotifyProvider spotify,
  }) {
    final isArtist = entity.type == SpotifyEntityType.artist;
    final typeTitle = entity.type == SpotifyEntityType.album
        ? 'Album'
        : entity.type == SpotifyEntityType.playlist
        ? 'Playlist'
        : 'Artis';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(isArtist ? 25 : 8),
          child: entity.artworkUrl != null
              ? Image.network(
                  entity.artworkUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 50,
                    height: 50,
                    color: AppColors.surface,
                    child: Icon(
                      isArtist ? Icons.person_rounded : Icons.album_rounded,
                      color: Colors.white54,
                    ),
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  color: AppColors.surface,
                  child: Icon(
                    isArtist ? Icons.person_rounded : Icons.album_rounded,
                    color: Colors.white54,
                  ),
                ),
        ),
        title: Text(
          entity.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          entity.displayArtist.isNotEmpty
              ? '$typeTitle • ${entity.displayArtist}'
              : typeTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textMuted,
        ),
        onTap: () {
          if (isArtist) {
            _searchController.text = entity.title;
            setState(() => _selectedCategoryTab = 0);
            spotify.executeSearch(entity.title);
          } else {
            setState(() => _selectedCategoryTab = 0);
            spotify.selectEntity(entity);
          }
        },
      ),
    );
  }

  Widget _buildEntityHeader(
    BuildContext context,
    MusicMetadataResult entity,
    List<MusicMetadataResult> tracks,
    SpotifyProvider spotify,
  ) {
    final typeLabel = entity.type == SpotifyEntityType.album
        ? 'SPOTIFY ALBUM'
        : entity.type == SpotifyEntityType.playlist
        ? 'SPOTIFY PLAYLIST'
        : 'SPOTIFY ARTIST';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1DB954).withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AppImage(
              imagePath: entity.artworkUrl,
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              defaultIcon: Icons.album_rounded,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeLabel,
                    style: const TextStyle(
                      color: Color(0xFF1DB954),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entity.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entity.displayArtist.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entity.displayArtist,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${tracks.length} track',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text(
                        'Putar Semua',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => spotify.playTracks(context, tracks),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.queue_music_rounded, size: 18),
                      label: const Text(
                        '+ Antrean',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () =>
                          spotify.addTracksToQueue(context, tracks),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.playlist_add_rounded, size: 18),
                      label: const Text(
                        '+ Library',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _handleAddToLibrary(
                        context,
                        tracks,
                        spotify,
                        defaultPlaylistTitle: entity.title,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile({
    required BuildContext context,
    required MusicMetadataResult track,
    required int index,
    required bool isSelected,
    required bool isResolving,
    required SpotifyProvider spotify,
    required List<MusicMetadataResult> tracks,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF1DB954).withAlpha(35)
            : AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: isSelected ? Border.all(color: const Color(0xFF1DB954)) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: _isSelectionMode
            ? Checkbox(
                value: isSelected,
                activeColor: const Color(0xFF1DB954),
                onChanged: (_) => _toggleSelect(track),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AppImage(
                  imagePath: track.artworkUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  defaultIcon: Icons.music_note_rounded,
                ),
              ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                track.displayArtist.isNotEmpty
                    ? track.displayArtist
                    : 'Spotify Track',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            if (track.duration != null && track.duration! > 0)
              Text(
                '${track.duration! ~/ 60}:${(track.duration! % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelect(track);
          } else {
            spotify.playTracks(context, tracks, startIndex: index);
          }
        },
        onLongPress: () {
          _toggleSelect(track);
        },
        trailing: isResolving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1DB954),
                ),
              )
            : PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                color: AppColors.card,
                onSelected: (choice) {
                  if (choice == 'play') {
                    spotify.playTrack(context, track);
                  } else if (choice == 'queue') {
                    spotify.addTrackToQueue(context, track);
                  } else if (choice == 'library') {
                    _handleAddToLibrary(context, [track], spotify);
                  } else if (choice == 'download') {
                    spotify.downloadTrack(context, track);
                  } else if (choice == 'browser') {
                    _openInBrowser(track.spotifyUrl);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'play',
                    child: Row(
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFF1DB954),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text('Putar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'queue',
                    child: Row(
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text('Tambah ke Antrean'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'library',
                    child: Row(
                      children: [
                        Icon(
                          Icons.playlist_add_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text('Simpan ke Library'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(
                          Icons.download_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text('Download'),
                      ],
                    ),
                  ),
                  if (track.spotifyUrl != null)
                    const PopupMenuItem(
                      value: 'browser',
                      child: Row(
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text('Buka di Spotify'),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildSelectionBar(
    BuildContext context,
    SpotifyProvider spotify,
    List<MusicMetadataResult> tracks,
  ) {
    final selectedTracks = _getSelectedTracks(tracks);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text(
                  'Putar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  spotify.playTracks(context, selectedTracks);
                  _clearSelection();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.queue_music_rounded,
                color: Color(0xFF1DB954),
              ),
              tooltip: 'Tambah ke Antrean',
              onPressed: () {
                spotify.addTracksToQueue(context, selectedTracks);
                _clearSelection();
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                Icons.playlist_add_rounded,
                color: Color(0xFF1DB954),
              ),
              tooltip: 'Simpan ke Library',
              onPressed: () {
                _handleAddToLibrary(context, selectedTracks, spotify);
                _clearSelection();
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                Icons.download_rounded,
                color: Color(0xFF1DB954),
              ),
              tooltip: 'Download',
              onPressed: () {
                spotify.downloadTracks(context, selectedTracks);
                _clearSelection();
              },
            ),
          ],
        ),
      ),
    );
  }
}
