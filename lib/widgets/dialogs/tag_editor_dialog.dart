import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/song_model.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/tag_editor_service.dart';
import 'metadata_debug_dialog.dart';
import 'spotify_import_dialog.dart';

class TagEditorDialog extends StatefulWidget {
  final SongModel song;
  final Function(SongModel updatedSong)? onSaved;

  const TagEditorDialog({super.key, required this.song, this.onSaved});

  static void show(
    BuildContext context, {
    required SongModel song,
    Function(SongModel updatedSong)? onSaved,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 720,
            child: TagEditorDialog(song: song, onSaved: onSaved),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.88,
              child: TagEditorDialog(song: song, onSaved: onSaved),
            ),
          ),
        ),
      );
    }
  }

  @override
  State<TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<TagEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _albumArtistController;
  late TextEditingController _genreController;
  late TextEditingController _yearController;
  late TextEditingController _trackController;
  late TextEditingController _discController;
  late TextEditingController _composerController;
  late TextEditingController _commentController;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFormatSupported = true;

  Uint8List? _artworkBytes;
  String? _artworkMime;
  bool _removeArtwork = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(
      text: widget.song.artistName ?? '',
    );
    _albumController = TextEditingController(
      text: widget.song.albumTitle ?? '',
    );
    _albumArtistController = TextEditingController();
    _genreController = TextEditingController(text: widget.song.genreName ?? '');
    _yearController = TextEditingController();
    _trackController = TextEditingController();
    _discController = TextEditingController();
    _composerController = TextEditingController();
    _commentController = TextEditingController();

    _loadExistingTags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _albumArtistController.dispose();
    _genreController.dispose();
    _yearController.dispose();
    _trackController.dispose();
    _discController.dispose();
    _composerController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingTags() async {
    final targetPath = widget.song.filePath ?? widget.song.audioPath;
    _isFormatSupported = TagEditorService.isFormatSupported(targetPath);

    final tag = await TagEditorService.readTags(targetPath);
    if (tag != null && mounted) {
      setState(() {
        if (tag.title != null && tag.title!.isNotEmpty)
          _titleController.text = tag.title!;
        if (tag.trackArtist != null && tag.trackArtist!.isNotEmpty)
          _artistController.text = tag.trackArtist!;
        if (tag.album != null && tag.album!.isNotEmpty)
          _albumController.text = tag.album!;
        if (tag.albumArtist != null && tag.albumArtist!.isNotEmpty)
          _albumArtistController.text = tag.albumArtist!;
        if (tag.genre != null && tag.genre!.isNotEmpty)
          _genreController.text = tag.genre!;
        if (tag.year != null) _yearController.text = tag.year.toString();
        if (tag.trackNumber != null)
          _trackController.text = tag.trackNumber.toString();
        if (tag.discNumber != null)
          _discController.text = tag.discNumber.toString();

        if (tag.pictures.isNotEmpty) {
          _artworkBytes = Uint8List.fromList(tag.pictures.first.bytes);
          _artworkMime = tag.pictures.first.mimeType?.name;
        }
      });
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickArtwork() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null) {
          final file = File(path);
          final bytes = await file.readAsBytes();
          final ext = path.split('.').last.toLowerCase();
          setState(() {
            _artworkBytes = bytes;
            _artworkMime = ext == 'png' ? 'image/png' : 'image/jpeg';
            _removeArtwork = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking artwork: $e');
    }
  }

  Future<void> _openSpotifyImport() async {
    final choice = await SpotifyImportDialog.show(context);
    if (choice == null || !mounted) return;

    final meta = choice.metadata;
    final overwrite = choice.overwriteExisting;

    setState(() {
      if (overwrite) {
        if (meta.title.isNotEmpty) _titleController.text = meta.title;
        if (meta.displayArtist.isNotEmpty)
          _artistController.text = meta.displayArtist;
        if (meta.album != null && meta.album!.isNotEmpty)
          _albumController.text = meta.album!;
        if (meta.albumArtist != null && meta.albumArtist!.isNotEmpty)
          _albumArtistController.text = meta.albumArtist!;
        if (meta.genre != null && meta.genre!.isNotEmpty)
          _genreController.text = meta.genre!;
        if (meta.releaseYear != null)
          _yearController.text = meta.releaseYear.toString();
        if (choice.artworkBytes != null && choice.artworkBytes!.isNotEmpty) {
          _artworkBytes = choice.artworkBytes;
          _artworkMime = 'image/jpeg';
          _removeArtwork = false;
        }
      } else {
        if (_titleController.text.trim().isEmpty ||
            _titleController.text.toLowerCase() == 'unknown title') {
          if (meta.title.isNotEmpty) _titleController.text = meta.title;
        }
        if (_artistController.text.trim().isEmpty ||
            _artistController.text.toLowerCase() == 'unknown artist') {
          if (meta.displayArtist.isNotEmpty)
            _artistController.text = meta.displayArtist;
        }
        if (_albumController.text.trim().isEmpty ||
            _albumController.text.toLowerCase() == 'unknown album') {
          if (meta.album != null && meta.album!.isNotEmpty)
            _albumController.text = meta.album!;
        }
        if (_albumArtistController.text.trim().isEmpty &&
            meta.albumArtist != null &&
            meta.albumArtist!.isNotEmpty) {
          _albumArtistController.text = meta.albumArtist!;
        }
        if (_genreController.text.trim().isEmpty &&
            meta.genre != null &&
            meta.genre!.isNotEmpty) {
          _genreController.text = meta.genre!;
        }
        if (_yearController.text.trim().isEmpty && meta.releaseYear != null) {
          _yearController.text = meta.releaseYear.toString();
        }
        if ((_artworkBytes == null || _artworkBytes!.isEmpty) &&
            choice.artworkBytes != null &&
            choice.artworkBytes!.isNotEmpty) {
          _artworkBytes = choice.artworkBytes;
          _artworkMime = 'image/jpeg';
          _removeArtwork = false;
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Metadata Spotify diterapkan: ${meta.title}'),
          backgroundColor: const Color(0xFF1DB954),
        ),
      );
    }
  }

  Future<void> _saveMetadata() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final yearVal = int.tryParse(_yearController.text.trim());
      final trackVal = int.tryParse(_trackController.text.trim());
      final discVal = int.tryParse(_discController.text.trim());

      final updatedSong = await TagEditorService.saveMetadata(
        song: widget.song,
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        album: _albumController.text.trim(),
        albumArtist: _albumArtistController.text.trim(),
        genre: _genreController.text.trim(),
        year: yearVal,
        trackNumber: trackVal,
        discNumber: discVal,
        composer: _composerController.text.trim(),
        comment: _commentController.text.trim(),
        newArtworkBytes: _artworkBytes,
        newArtworkMime: _artworkMime,
        removeArtwork: _removeArtwork,
      );

      if (mounted) {
        Provider.of<PlayerProvider>(
          context,
          listen: false,
        ).updateSongMetadata(updatedSong);
        try {
          Provider.of<CatalogProvider>(
            context,
            listen: false,
          ).fetchCatalogData();
        } catch (_) {}
        widget.onSaved?.call(updatedSong);

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadata lagu berhasil diperbarui!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving metadata: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan metadata: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Text(
                'Edit Metadata Lagu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.auto_fix_high_rounded,
                  color: Color(0xFF1DB954),
                ),
                tooltip: 'Import Metadata dari Spotify URL',
                onPressed: _openSpotifyImport,
              ),
              IconButton(
                icon: const Icon(
                  Icons.bug_report_rounded,
                  color: Colors.orangeAccent,
                ),
                tooltip: 'Diagnostic Inspector',
                onPressed: () => MetadataDebugDialog.show(context, widget.song),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_isFormatSupported)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Format file ini tidak mendukung penulisan ID3 tag fisik secara langsung.',
                      style: TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: isDesktop
                      ? _buildDesktopLayout()
                      : _buildMobileLayout(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveMetadata,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Metadata'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkSection() {
    return Column(
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _artworkBytes != null && !_removeArtwork
                ? Image.memory(_artworkBytes!, fit: BoxFit.cover)
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.album_rounded,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No Cover',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickArtwork,
              icon: const Icon(Icons.image_search_rounded, size: 16),
              label: const Text('Ganti Cover', style: TextStyle(fontSize: 12)),
            ),
            if (_artworkBytes != null && !_removeArtwork) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                tooltip: 'Hapus Artwork',
                onPressed: () {
                  setState(() => _removeArtwork = true);
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 180, child: _buildArtworkSection()),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              _buildTextField(
                _titleController,
                'Judul (Title)',
                Icons.title_rounded,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _artistController,
                      'Artis (Artist)',
                      Icons.person_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _albumArtistController,
                      'Album Artist',
                      Icons.person_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _albumController,
                      'Album',
                      Icons.album_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _genreController,
                      'Genre',
                      Icons.style_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _yearController,
                      'Tahun (Year)',
                      Icons.calendar_today_rounded,
                      isNumeric: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _trackController,
                      'Track #',
                      Icons.format_list_numbered_rounded,
                      isNumeric: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _discController,
                      'Disc #',
                      Icons.disc_full_rounded,
                      isNumeric: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _composerController,
                'Komposer (Composer)',
                Icons.music_note_rounded,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _commentController,
                'Komentar (Comment)',
                Icons.comment_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildArtworkSection(),
        const SizedBox(height: 16),
        _buildTextField(_titleController, 'Judul (Title)', Icons.title_rounded),
        const SizedBox(height: 12),
        _buildTextField(
          _artistController,
          'Artis (Artist)',
          Icons.person_rounded,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _albumArtistController,
          'Album Artist',
          Icons.person_outline_rounded,
        ),
        const SizedBox(height: 12),
        _buildTextField(_albumController, 'Album', Icons.album_rounded),
        const SizedBox(height: 12),
        _buildTextField(_genreController, 'Genre', Icons.style_rounded),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                _yearController,
                'Tahun',
                Icons.calendar_today_rounded,
                isNumeric: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTextField(
                _trackController,
                'Track #',
                Icons.format_list_numbered_rounded,
                isNumeric: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTextField(
                _discController,
                'Disc #',
                Icons.disc_full_rounded,
                isNumeric: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _composerController,
          'Komposer',
          Icons.music_note_rounded,
        ),
        const SizedBox(height: 12),
        _buildTextField(_commentController, 'Komentar', Icons.comment_rounded),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumeric = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      validator: (val) {
        if (isNumeric && val != null && val.trim().isNotEmpty) {
          final parsed = int.tryParse(val.trim());
          if (parsed == null || parsed < 0) {
            return 'Angka tidak valid';
          }
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
