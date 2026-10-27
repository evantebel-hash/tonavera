import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'favorites_screen.dart';
import 'local_music_screen.dart';
import 'downloads_screen.dart';
import 'duplicate_music_screen.dart';
import '../playlist/playlist_list_screen.dart';
import '../../services/import_folder_service.dart';
import '../youtube/youtube_playlist_screen.dart';
import '../spotify/spotify_discovery_screen.dart';
import '../catalog/artists_screen.dart';
import '../catalog/albums_screen.dart';
import '../../widgets/dialogs/import_link_dialog.dart';

/// V3.5 Obsidian Emerald Library Screen.
///
/// Features:
/// - Dedicated music collection hub
/// - Modular Obsidian surface tiles with distinctive iconography
/// - Preserves 100% of routes (Local, Downloads, Import, Duplicates, YouTube, Spotify, Playlists, Favorites).
/// - Includes "Impor Metadata dari Tautan" hub tile.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: V35Tokens.space20,
                vertical: V35Tokens.space16,
              ),
              child: ListView(
                children: [
                  // --- HEADER ---
                  Text(
                    'Koleksi Saya',
                    style: V35Tokens.display.copyWith(
                      fontSize: 26.0,
                      fontWeight: FontWeight.w700,
                      color: V35Tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kelola musik lokal, unduhan, dan daftar putar Anda',
                    style: V35Tokens.secondary.copyWith(
                      color: V35Tokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: V35Tokens.space20),

                  // 1. Import Metadata from Link (NEW)
                  _buildHubTile(
                    icon: Icons.link_rounded,
                    iconColor: const Color(0xFF10B981), // Emerald
                    title: 'Impor Metadata dari Tautan',
                    subtitle:
                        'Impor lagu, album, atau playlist dari Spotify & YouTube Music',
                    onTap: () {
                      ImportLinkDialog.show(context);
                    },
                  ),

                  // 2. Local Music
                  _buildHubTile(
                    icon: Icons.folder_special_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Lagu Terunduh / Lokal',
                    subtitle: 'Musik lokal dari penyimpanan perangkat Anda',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LocalMusicScreen(),
                        ),
                      );
                    },
                  ),

                  // 3. Download Manager
                  _buildHubTile(
                    icon: Icons.download_for_offline_rounded,
                    iconColor: const Color(0xFF38BDF8), // Sky blue
                    title: 'Download Manager',
                    subtitle: 'Kelola antrean & riwayat unduhan musik',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DownloadsScreen(),
                        ),
                      );
                    },
                  ),

                  // 4. Import Folder
                  _buildHubTile(
                    icon: Icons.create_new_folder_rounded,
                    iconColor: const Color(0xFFF59E0B), // Amber
                    title: 'Impor Folder ke Playlist',
                    subtitle: 'Buat playlist otomatis dari direktori audio',
                    onTap: () {
                      ImportFolderService.importFolder(context);
                    },
                  ),

                  // 5. Duplicate Music Cleaner
                  _buildHubTile(
                    icon: Icons.copy_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Pembersih Lagu Duplikat',
                    subtitle:
                        'Deteksi & rapikan duplikat trackHash & audio identik',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DuplicateMusicScreen(),
                        ),
                      );
                    },
                  ),

                  // 6. YouTube Online Playlists
                  _buildHubTile(
                    icon: Icons.featured_play_list_rounded,
                    iconColor: const Color(0xFFEF4444), // Red
                    title: 'YouTube Online Playlists',
                    subtitle:
                        'Kelola & simpan playlist publik YouTube (Local Cache)',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const YouTubePlaylistScreen(),
                        ),
                      );
                    },
                  ),

                  // 7. Spotify Discovery & Import
                  _buildHubTile(
                    icon: Icons.hub_rounded,
                    iconColor: const Color(0xFF10B981), // Emerald
                    title: 'Spotify Discovery & Import',
                    subtitle:
                        'Eksplorasi lagu, album, atau playlist publik Spotify',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SpotifyDiscoveryScreen(),
                        ),
                      );
                    },
                  ),

                  // 8. Katalog Artis
                  _buildHubTile(
                    icon: Icons.person_rounded,
                    iconColor: V35Tokens.accent,
                    title: 'Katalog Artis',
                    subtitle: 'Jelajahi semua artis dan diskografi album',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ArtistsScreen(),
                        ),
                      );
                    },
                  ),

                  // 9. Katalog Album
                  _buildHubTile(
                    icon: Icons.album_rounded,
                    iconColor: const Color(0xFFA78BFA), // Lavender
                    title: 'Katalog Album',
                    subtitle: 'Jelajahi seluruh koleksi album terdaftar',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AlbumsScreen()),
                      );
                    },
                  ),

                  // --- USER SPECIFIC (FAVORITES & PLAYLISTS) ---
                  if (auth.isAuthenticated) ...[
                    _buildHubTile(
                      icon: Icons.favorite_rounded,
                      iconColor: const Color(0xFFF43F5E), // Rose
                      title: 'Lagu Favorit',
                      subtitle: 'Semua lagu yang Anda tandai dengan hati',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FavoritesScreen(),
                          ),
                        );
                      },
                    ),
                    _buildHubTile(
                      icon: Icons.playlist_play_rounded,
                      iconColor: V35Tokens.accent,
                      title: 'Playlist Saya',
                      subtitle: 'Daftar putar pribadi yang Anda buat',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PlaylistListScreen(),
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    // Unauthenticated CTA Card
                    Container(
                      margin: const EdgeInsets.only(top: V35Tokens.space12),
                      padding: const EdgeInsets.all(V35Tokens.space20),
                      decoration: BoxDecoration(
                        color: V35Tokens.bgSurface,
                        borderRadius: V35Tokens.brLg,
                        border: Border.all(color: V35Tokens.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: V35Tokens.accentDeep.withValues(
                                alpha: 0.2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 24,
                              color: V35Tokens.accent,
                            ),
                          ),
                          const SizedBox(height: V35Tokens.space12),
                          Text(
                            'Masuk untuk Mengakses Playlist & Favorit',
                            style: V35Tokens.title.copyWith(
                              fontWeight: FontWeight.w700,
                              color: V35Tokens.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Simpan lagu favorit, buat playlist kustom, dan sinkronkan data musik Anda.',
                            style: V35Tokens.secondary.copyWith(
                              color: V35Tokens.textMuted,
                              fontSize: 12.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: V35Tokens.space16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: V35Tokens.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: V35Tokens.space24,
                                vertical: V35Tokens.space12,
                              ),
                              shape: const RoundedRectangleBorder(
                                borderRadius: V35Tokens.brMd,
                              ),
                            ),
                            child: Text(
                              'Masuk / Daftar',
                              style: V35Tokens.mono.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: V35Tokens.space32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHubTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: V35Tokens.space8),
      decoration: BoxDecoration(
        color: V35Tokens.bgSurface,
        borderRadius: V35Tokens.brMd,
        border: Border.all(color: V35Tokens.borderSubtle, width: 1.0),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: V35Tokens.space16,
          vertical: 4.0,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: V35Tokens.brSm,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: V35Tokens.title.copyWith(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: V35Tokens.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: V35Tokens.secondary.copyWith(
            fontSize: 12.0,
            color: V35Tokens.textMuted,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: V35Tokens.textMuted,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}
