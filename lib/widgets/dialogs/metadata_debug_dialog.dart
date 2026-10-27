import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audiotags/audiotags.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/metadata_normalizer.dart';
import '../../models/song_model.dart';
import '../../services/tag_editor_service.dart';

class MetadataDebugDialog extends StatefulWidget {
  final SongModel song;

  const MetadataDebugDialog({super.key, required this.song});

  static void show(BuildContext context, SongModel song) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(width: 600, child: MetadataDebugDialog(song: song)),
      ),
    );
  }

  @override
  State<MetadataDebugDialog> createState() => _MetadataDebugDialogState();
}

class _MetadataDebugDialogState extends State<MetadataDebugDialog> {
  bool _isLoading = true;
  Tag? _rawTag;
  NormalizedSongMetadata? _normalized;
  bool _readable = false;
  bool _writable = false;

  @override
  void initState() {
    super.initState();
    _inspectMetadata();
  }

  Future<void> _inspectMetadata() async {
    final targetPath = widget.song.filePath ?? widget.song.audioPath;
    final file = File(targetPath);
    _readable = file.existsSync();
    _writable = TagEditorService.isFormatSupported(targetPath);

    if (_readable) {
      try {
        _rawTag = await AudioTags.read(targetPath);
      } catch (e) {
        debugPrint('Debug inspect read error: $e');
      }
    }

    _normalized = NormalizedSongMetadata.fromTag(
      _rawTag,
      fallbackTitle: widget.song.title,
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetPath = widget.song.filePath ?? widget.song.audioPath;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bug_report_rounded,
                color: Colors.orangeAccent,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Text(
                'Metadata Diagnostic Inspector',
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
          const Divider(color: AppColors.divider),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('FILE SYSTEM'),
                    _buildInfoRow('File Path', targetPath),
                    _buildInfoRow(
                      'Readable',
                      _readable ? 'YES' : 'NO (File not found)',
                    ),
                    _buildInfoRow(
                      'Writable Tag Format',
                      _writable
                          ? 'YES'
                          : 'NO (Format unsupported for direct ID3 write)',
                    ),

                    const SizedBox(height: 16),
                    _buildSectionHeader('RAW AUDIO METADATA (AUDIO TAGS)'),
                    _buildInfoRow('Title', _rawTag?.title ?? '(null)'),
                    _buildInfoRow(
                      'Track Artist',
                      _rawTag?.trackArtist ?? '(null)',
                    ),
                    _buildInfoRow(
                      'Album Artist',
                      _rawTag?.albumArtist ?? '(null)',
                    ),
                    _buildInfoRow('Album', _rawTag?.album ?? '(null)'),
                    _buildInfoRow('Genre', _rawTag?.genre ?? '(null)'),
                    _buildInfoRow(
                      'Year',
                      _rawTag?.year?.toString() ?? '(null)',
                    ),
                    _buildInfoRow(
                      'Track #',
                      _rawTag?.trackNumber?.toString() ?? '(null)',
                    ),
                    _buildInfoRow(
                      'Disc #',
                      _rawTag?.discNumber?.toString() ?? '(null)',
                    ),
                    _buildInfoRow(
                      'Embedded Pictures',
                      '${_rawTag?.pictures.length ?? 0} picture(s)',
                    ),

                    const SizedBox(height: 16),
                    _buildSectionHeader(
                      'NORMALIZED METADATA (SYSTEM OF TRUTH)',
                    ),
                    _buildInfoRow('title', _normalized?.title ?? ''),
                    _buildInfoRow('artist', _normalized?.artist ?? ''),
                    _buildInfoRow(
                      'normalizedArtist',
                      _normalized?.normalizedArtist ?? '',
                    ),
                    _buildInfoRow('album', _normalized?.album ?? ''),
                    _buildInfoRow(
                      'albumArtist',
                      _normalized?.albumArtist ?? '',
                    ),

                    const SizedBox(height: 16),
                    _buildSectionHeader('LOCAL DATABASE RECORD'),
                    _buildInfoRow('DB ID', widget.song.id.toString()),
                    _buildInfoRow('artist_id', widget.song.artistId.toString()),
                    _buildInfoRow(
                      'album_id',
                      widget.song.albumId?.toString() ?? 'null',
                    ),
                    _buildInfoRow(
                      'artist_name',
                      widget.song.artistName ?? 'null',
                    ),
                    _buildInfoRow(
                      'album_title',
                      widget.song.albumTitle ?? 'null',
                    ),
                    _buildInfoRow('cover path', widget.song.cover ?? 'null'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
