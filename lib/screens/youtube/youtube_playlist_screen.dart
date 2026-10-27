import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/youtube_provider.dart';
import '../../providers/playlist_provider.dart';
import 'youtube_playlist_detail_screen.dart';

class YouTubePlaylistScreen extends StatefulWidget {
  const YouTubePlaylistScreen({super.key});

  @override
  State<YouTubePlaylistScreen> createState() => _YouTubePlaylistScreenState();
}

class _YouTubePlaylistScreenState extends State<YouTubePlaylistScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<YouTubeProvider>(
        context,
        listen: false,
      ).fetchSavedPlaylists();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showImportDialog() {
    _urlController.clear();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Impor Playlist YouTube'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Masukkan URL atau ID Playlist YouTube Publik:'),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'https://youtube.com/playlist?list=...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_isImporting) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Mengambil metadata playlist...'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isImporting ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: _isImporting
                    ? null
                    : () async {
                        final input = _urlController.text.trim();
                        if (input.isEmpty) return;

                        setDialogState(() => _isImporting = true);
                        final ytProvider = Provider.of<YouTubeProvider>(
                          context,
                          listen: false,
                        );
                        final res = await ytProvider.importPlaylist(input);
                        setDialogState(() => _isImporting = false);

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          if (res != null) {
                            try {
                              Provider.of<PlaylistProvider>(
                                context,
                                listen: false,
                              ).fetchPlaylists();
                            } catch (_) {}
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Playlist "${res.title}" berhasil diimpor! (${res.items.length} track)',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            final errMessage =
                                ytProvider.playlistImportError ??
                                'Playlist tidak dapat diakses atau URL tidak valid.';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errMessage),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                child: const Text('Impor'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ytProvider = Provider.of<YouTubeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'YouTube Online Playlists',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => ytProvider.fetchSavedPlaylists(),
          ),
        ],
      ),
      body: ytProvider.isLoadingPlaylists
          ? const Center(child: CircularProgressIndicator())
          : ytProvider.savedPlaylists.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.playlist_play_rounded,
                      size: 64,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum Ada Online YouTube Playlist',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Impor playlist YouTube publik via URL untuk menyimpannya ke cache SQLite lokal.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _showImportDialog,
                      icon: const Icon(Icons.add_link_rounded),
                      label: const Text('Impor Playlist Sekarang'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ytProvider.savedPlaylists.length,
              itemBuilder: (context, index) {
                final pl = ytProvider.savedPlaylists[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: pl.thumbnailUrl != null
                          ? Image.network(
                              pl.thumbnailUrl!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.2,
                                    ),
                                    child: const Icon(
                                      Icons.featured_play_list_rounded,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              child: const Icon(
                                Icons.featured_play_list_rounded,
                                color: Colors.redAccent,
                              ),
                            ),
                    ),
                    title: Text(
                      pl.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${pl.itemCount} Tracks • ${pl.channelName ?? "YouTube"} • Saved in Cache',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                          onPressed: () =>
                              ytProvider.deletePlaylist(pl.playlistId),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => YouTubePlaylistDetailScreen(
                            playlistId: pl.playlistId,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showImportDialog,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Impor Playlist'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
