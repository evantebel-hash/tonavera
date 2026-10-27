import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import '../../services/metadata/metadata_model.dart';
import '../../services/metadata/metadata_service.dart';
import '../../services/metadata/spotify_url_parser.dart';

class SpotifyImportChoice {
  final MusicMetadataResult metadata;
  final Uint8List? artworkBytes;
  final bool overwriteExisting;

  SpotifyImportChoice({
    required this.metadata,
    this.artworkBytes,
    required this.overwriteExisting,
  });
}

class SpotifyImportDialog extends StatefulWidget {
  final String? initialUrl;

  const SpotifyImportDialog({super.key, this.initialUrl});

  static Future<SpotifyImportChoice?> show(
    BuildContext context, {
    String? initialUrl,
  }) {
    return showDialog<SpotifyImportChoice>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 520,
          child: SpotifyImportDialog(initialUrl: initialUrl),
        ),
      ),
    );
  }

  @override
  State<SpotifyImportDialog> createState() => _SpotifyImportDialogState();
}

class _SpotifyImportDialogState extends State<SpotifyImportDialog> {
  late TextEditingController _urlController;
  bool _isLoading = false;
  String? _errorMessage;
  MusicMetadataResult? _fetchedMetadata;
  Uint8List? _fetchedArtworkBytes;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _fetchMetadata();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
        _errorMessage = null;
      });
      _fetchMetadata();
    }
  }

  Future<void> _fetchMetadata() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Masukkan URL atau URI Spotify.');
      return;
    }

    if (!SpotifyUrlParser.isValid(url)) {
      setState(
        () => _errorMessage =
            'Format URL Spotify tidak valid. Contoh: https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fetchedMetadata = null;
      _fetchedArtworkBytes = null;
    });

    try {
      final result = await MetadataService.instance.fetchSpotifyMetadata(url);
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Tidak dapat mengambil metadata dari Spotify. Periksa URL atau koneksi internet.';
        });
        return;
      }

      Uint8List? artworkBytes;
      if (result.artworkUrl != null && result.artworkUrl!.isNotEmpty) {
        try {
          final res = await http
              .get(Uri.parse(result.artworkUrl!))
              .timeout(const Duration(seconds: 8));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            artworkBytes = res.bodyBytes;
          }
        } catch (e) {
          debugPrint('Failed to download Spotify artwork: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _fetchedMetadata = result;
          _fetchedArtworkBytes = artworkBytes;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Terjadi kesalahan: $e';
        });
      }
    }
  }

  void _applyChoice(bool overwrite) {
    if (_fetchedMetadata == null) return;
    Navigator.of(context).pop(
      SpotifyImportChoice(
        metadata: _fetchedMetadata!,
        artworkBytes: _fetchedArtworkBytes,
        overwriteExisting: overwrite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.music_note_rounded,
                color: Color(0xFF1DB954),
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text(
                'Import Metadata Spotify',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tempel tautan lagu atau album Spotify untuk memperbarui metadata dan sampul album.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'https://open.spotify.com/track/...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1DB954)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _fetchMetadata(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.paste_rounded,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Tempel dari Clipboard',
                onPressed: _pasteFromClipboard,
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: _isLoading ? null : _fetchMetadata,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Cari',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_fetchedMetadata != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _fetchedArtworkBytes != null
                        ? Image.memory(
                            _fetchedArtworkBytes!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            color: AppColors.surface,
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fetchedMetadata!.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fetchedMetadata!.displayArtist,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_fetchedMetadata!.album != null &&
                            _fetchedMetadata!.album!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Album: ${_fetchedMetadata!.album!}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (_fetchedMetadata!.releaseYear != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Tahun: ${_fetchedMetadata!.releaseYear!}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _applyChoice(false),
                  child: const Text('Isi Bagian Kosong (Aman)'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _applyChoice(true),
                  child: const Text('Ganti Semua Data'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
