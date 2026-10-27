import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/artist_model.dart';
import '../../repositories/local_music_repository.dart';
import '../../widgets/v35/v35_media_card.dart';
import 'artist_detail_screen.dart';

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  final LocalMusicRepository _repo = LocalMusicRepository();
  List<ArtistModel> _artists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtists();
  }

  Future<void> _loadArtists() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getArtists();
      if (mounted) setState(() => _artists = list);
    } catch (e) {
      debugPrint('[ArtistsScreen] Error: $e');
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
              'Daftar Artis',
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
              : _artists.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada artis yang tersimpan.',
                    style: V35Tokens.body.copyWith(color: V35Tokens.textMuted),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(V35Tokens.space16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _artists.length,
                  itemBuilder: (context, index) {
                    final artist = _artists[index];
                    return V35MediaCard(
                      title: artist.name,
                      subtitle: 'Artis',
                      artworkPath: artist.image,
                      isCircular: true,
                      aspectRatio: 1.0,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArtistDetailScreen(artist: artist),
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
