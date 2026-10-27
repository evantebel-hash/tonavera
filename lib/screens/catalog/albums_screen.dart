import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/album_model.dart';
import '../../repositories/local_music_repository.dart';
import '../../widgets/v35/v35_media_card.dart';
import 'album_detail_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final LocalMusicRepository _repo = LocalMusicRepository();
  List<AlbumModel> _albums = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getAlbums();
      if (mounted) setState(() => _albums = list);
    } catch (e) {
      debugPrint('[AlbumsScreen] Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, activeAccent, child) {
        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Daftar Album',
              style: V35Tokens.heading.copyWith(
                fontSize: 18,
                color: V35Tokens.textPrimary,
              ),
            ),
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: V35Tokens.accent),
                )
              : _albums.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada album yang tersimpan.',
                    style: V35Tokens.body.copyWith(color: V35Tokens.textMuted),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(V35Tokens.space16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _albums.length,
                  itemBuilder: (context, index) {
                    final album = _albums[index];
                    return V35MediaCard(
                      title: album.title,
                      subtitle: album.artistName ?? 'Album',
                      artworkPath: album.cover,
                      aspectRatio: 1.0,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AlbumDetailScreen(album: album),
                          ),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
