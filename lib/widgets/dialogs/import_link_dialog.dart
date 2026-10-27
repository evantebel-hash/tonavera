import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/import_metadata_provider.dart';
import '../../services/metadata/spotify_url_parser.dart';
import '../app_image.dart';

/// Modal dialog for importing music metadata from supported links (Spotify, YouTube Music).
/// Strictly adheres to V3.5 Obsidian Emerald design tokens and user flow:
/// 1. Enter/Paste link
/// 2. Validate & fetch official preview
/// 3. Confirm import with option to overwrite
/// 4. Atomic commit to local SQLite database
class ImportLinkDialog extends StatefulWidget {
  final String? initialUrl;

  const ImportLinkDialog({super.key, this.initialUrl});

  static Future<bool?> show(BuildContext context, {String? initialUrl}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => ImportLinkDialog(initialUrl: initialUrl),
    );
  }

  @override
  State<ImportLinkDialog> createState() => _ImportLinkDialogState();
}

class _ImportLinkDialogState extends State<ImportLinkDialog> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ImportMetadataProvider>(
        context,
        listen: false,
      );
      provider.reset();
      if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
        provider.resolveUrl(widget.initialUrl!.trim());
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _urlController.text = data.text!.trim();
      if (mounted) {
        Provider.of<ImportMetadataProvider>(
          context,
          listen: false,
        ).resolveUrl(_urlController.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ImportMetadataProvider>(
      builder: (context, provider, child) {
        return Dialog(
          backgroundColor: V35Tokens.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: V35Tokens.brLg,
            side: BorderSide(color: V35Tokens.borderSubtle),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.all(V35Tokens.space20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: V35Tokens.accentDeep.withValues(alpha: 0.25),
                          borderRadius: V35Tokens.brSm,
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          color: V35Tokens.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: V35Tokens.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Impor Metadata dari Tautan',
                              style: V35Tokens.title.copyWith(
                                fontWeight: FontWeight.w700,
                                color: V35Tokens.textPrimary,
                              ),
                            ),
                            Text(
                              'Spotify (Track, Album, Playlist, Artist) atau YouTube Music',
                              style: V35Tokens.caption.copyWith(
                                color: V35Tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: Icon(
                          Icons.close_rounded,
                          color: V35Tokens.textMuted,
                          size: 20,
                        ),
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                  const SizedBox(height: V35Tokens.space16),

                  // --- INPUT FIELD & PASTE BUTTON ---
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: V35Tokens.body.copyWith(
                            color: V35Tokens.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Tempel tautan Spotify atau YouTube di sini...',
                            hintStyle: V35Tokens.body.copyWith(
                              color: V35Tokens.textMuted,
                            ),
                            filled: true,
                            fillColor: V35Tokens.bgVoid,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: V35Tokens.space16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: V35Tokens.brMd,
                              borderSide: BorderSide(
                                color: V35Tokens.borderSubtle,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: V35Tokens.brMd,
                              borderSide: BorderSide(
                                color: V35Tokens.borderSubtle,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: V35Tokens.brMd,
                              borderSide: BorderSide(color: V35Tokens.accent),
                            ),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              provider.resolveUrl(val.trim());
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: V35Tokens.space8),
                      IconButton(
                        onPressed: _pasteFromClipboard,
                        style: IconButton.styleFrom(
                          backgroundColor: V35Tokens.bgElevated,
                          shape: RoundedRectangleBorder(
                            borderRadius: V35Tokens.brMd,
                            side: BorderSide(color: V35Tokens.borderSubtle),
                          ),
                        ),
                        icon: const Icon(Icons.content_paste_rounded, size: 18),
                        tooltip: 'Tempel dari Clipboard',
                      ),
                      const SizedBox(width: V35Tokens.space4),
                      ElevatedButton(
                        onPressed: provider.status == ImportStatus.resolving
                            ? null
                            : () {
                                if (_urlController.text.trim().isNotEmpty) {
                                  provider.resolveUrl(
                                    _urlController.text.trim(),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: V35Tokens.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: V35Tokens.brMd,
                          ),
                        ),
                        child: provider.status == ImportStatus.resolving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Periksa',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V35Tokens.space16),

                  // --- CONTENT BODY ---
                  Expanded(child: _buildDialogContent(context, provider)),

                  // --- FOOTER BUTTONS ---
                  if (provider.status == ImportStatus.previewReady) ...[
                    const Divider(color: V35Tokens.borderSubtle),
                    const SizedBox(height: V35Tokens.space8),
                    Row(
                      children: [
                        Checkbox(
                          value: provider.overwriteExisting,
                          onChanged: (val) =>
                              provider.overwriteExisting = val ?? false,
                          activeColor: V35Tokens.accent,
                          checkColor: Colors.black,
                        ),
                        Expanded(
                          child: Text(
                            'Timpa metadata yang sudah ada di database lokal jika ditemukan duplikat',
                            style: V35Tokens.caption.copyWith(
                              color: V35Tokens.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: V35Tokens.space12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'Batal',
                            style: V35Tokens.secondary.copyWith(
                              color: V35Tokens.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: V35Tokens.space12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final ok = await provider.commitImport();
                            if (ok && context.mounted) {
                              // Refresh catalog
                              Provider.of<CatalogProvider>(
                                context,
                                listen: false,
                              ).fetchCatalogData();
                            }
                          },
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text(
                            'Simpan ke Database Lokal',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: V35Tokens.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: V35Tokens.brMd,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (provider.status == ImportStatus.success) ...[
                    const Divider(color: V35Tokens.borderSubtle),
                    const SizedBox(height: V35Tokens.space12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: V35Tokens.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: V35Tokens.brMd,
                          ),
                        ),
                        child: const Text(
                          'Selesai',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogContent(
    BuildContext context,
    ImportMetadataProvider provider,
  ) {
    if (provider.status == ImportStatus.resolving) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: V35Tokens.accent),
            const SizedBox(height: V35Tokens.space16),
            Text(
              'Mengambil metadata dari sumber resmi...',
              style: V35Tokens.body.copyWith(color: V35Tokens.textMuted),
            ),
          ],
        ),
      );
    }

    if (provider.status == ImportStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(V35Tokens.space16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: V35Tokens.space12),
              Text(
                provider.errorMessage ?? 'Gagal memproses metadata.',
                style: V35Tokens.body.copyWith(color: V35Tokens.textPrimary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (provider.status == ImportStatus.importing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: V35Tokens.accent),
            const SizedBox(height: V35Tokens.space16),
            Text(
              'Menyimpan relasi Artis, Album, dan Lagu ke SQLite...',
              style: V35Tokens.body.copyWith(color: V35Tokens.textMuted),
            ),
          ],
        ),
      );
    }

    if (provider.status == ImportStatus.success) {
      final summary = provider.importSummary ?? {};
      return Center(
        child: Container(
          padding: const EdgeInsets.all(V35Tokens.space20),
          decoration: BoxDecoration(
            color: V35Tokens.bgVoid,
            borderRadius: V35Tokens.brMd,
            border: Border.all(color: V35Tokens.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: V35Tokens.accent,
                size: 48,
              ),
              const SizedBox(height: V35Tokens.space12),
              Text(
                'Metadata Berhasil Disimpan!',
                style: V35Tokens.title.copyWith(
                  fontWeight: FontWeight.w700,
                  color: V35Tokens.textPrimary,
                ),
              ),
              const SizedBox(height: V35Tokens.space8),
              Text(
                '${summary['songsCreated'] ?? 0} Lagu Baru Ditambahkan\n'
                '${summary['songsUpdated'] ?? 0} Lagu Diperbarui\n'
                '${summary['albumsCreated'] ?? 0} Album Dibuat\n'
                '${summary['artistsCreated'] ?? 0} Artis Terdaftar',
                style: V35Tokens.secondary.copyWith(
                  color: V35Tokens.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (provider.status == ImportStatus.previewReady &&
        provider.previewResult != null) {
      final res = provider.previewResult!;
      final bool isMulti = res.trackList.isNotEmpty;
      final tracks = isMulti ? res.trackList : [res];

      return Container(
        decoration: BoxDecoration(
          color: V35Tokens.bgVoid,
          borderRadius: V35Tokens.brMd,
          border: Border.all(color: V35Tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview header card
            Padding(
              padding: const EdgeInsets.all(V35Tokens.space12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: (res.type == SpotifyEntityType.artist)
                        ? BorderRadius.circular(28)
                        : V35Tokens.brSm,
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: AppImage(
                        imagePath: (res.type == SpotifyEntityType.artist)
                            ? res.effectiveArtistArtworkUrl
                            : (res.type == SpotifyEntityType.album
                                  ? res.effectiveAlbumArtworkUrl
                                  : (res.effectiveTrackArtworkUrl ??
                                        res.artworkUrl)),
                        fit: BoxFit.cover,
                        defaultIcon: (res.type == SpotifyEntityType.artist)
                            ? Icons.person_rounded
                            : Icons.album_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: V35Tokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildAttributionBadge(res.effectiveProvider),
                            const SizedBox(width: 6),
                            _buildTypeBadge(res.typeString.toUpperCase()),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          res.title,
                          style: V35Tokens.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: V35Tokens.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          res.displayArtist.isNotEmpty
                              ? res.displayArtist
                              : 'Unknown Artist',
                          style: V35Tokens.caption.copyWith(
                            color: V35Tokens.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isMulti)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: V35Tokens.bgElevated,
                        borderRadius: V35Tokens.brSm,
                      ),
                      child: Text(
                        '${tracks.length} Trek',
                        style: V35Tokens.caption.copyWith(
                          color: V35Tokens.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: V35Tokens.borderSubtle, height: 1),

            // Track list scroll view
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: tracks.length,
                separatorBuilder: (context, index) => const Divider(
                  color: V35Tokens.borderSubtle,
                  height: 1,
                  indent: 52,
                ),
                itemBuilder: (context, idx) {
                  final t = tracks[idx];
                  // Strict track artwork priority: specific track artwork -> album artwork (if album) -> neutral fallback
                  final String? trackPreviewArt =
                      t.effectiveTrackArtworkUrl ??
                      (res.type == SpotifyEntityType.album
                          ? res.effectiveAlbumArtworkUrl
                          : null);
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    leading: ClipRRect(
                      borderRadius: V35Tokens.brSm,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: AppImage(
                          imagePath: trackPreviewArt,
                          fit: BoxFit.cover,
                          defaultIcon: Icons.music_note_rounded,
                        ),
                      ),
                    ),
                    title: Text(
                      t.title,
                      style: V35Tokens.body.copyWith(
                        fontSize: 13,
                        color: V35Tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      t.displayArtist.isNotEmpty
                          ? t.displayArtist
                          : res.displayArtist,
                      style: V35Tokens.caption.copyWith(
                        fontSize: 11,
                        color: V35Tokens.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: t.duration != null && t.duration! > 0
                        ? Text(
                            '${(t.duration! ~/ 60)}:${(t.duration! % 60).toString().padLeft(2, '0')}',
                            style: V35Tokens.mono.copyWith(
                              fontSize: 11,
                              color: V35Tokens.textMuted,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Default idle state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hub_outlined, color: V35Tokens.textMuted, size: 48),
          const SizedBox(height: V35Tokens.space12),
          Text(
            'Masukkan tautan musik publik di atas',
            style: V35Tokens.body.copyWith(color: V35Tokens.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Contoh: https://open.spotify.com/album/...\natau https://music.youtube.com/watch?v=...',
            style: V35Tokens.caption.copyWith(
              color: V35Tokens.textMuted,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAttributionBadge(String provider) {
    final bool isSpotify = provider.toLowerCase() == 'spotify';
    final Color badgeColor = isSpotify
        ? const Color(0xFF1DB954)
        : const Color(0xFFFF0000);
    final String label = isSpotify ? 'Spotify' : 'YouTube Music';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: V35Tokens.bgElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type,
        style: V35Tokens.mono.copyWith(
          fontSize: 10,
          color: V35Tokens.textMuted,
        ),
      ),
    );
  }
}
