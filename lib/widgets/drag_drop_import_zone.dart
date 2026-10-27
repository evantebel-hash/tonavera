import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class DragDropImportZone extends StatefulWidget {
  final VoidCallback onPickFiles;
  final VoidCallback onPickFolder;
  final bool isImporting;

  const DragDropImportZone({
    super.key,
    required this.onPickFiles,
    required this.onPickFolder,
    this.isImporting = false,
  });

  @override
  State<DragDropImportZone> createState() => _DragDropImportZoneState();
}

class _DragDropImportZoneState extends State<DragDropImportZone> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: _isHovered
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? AppColors.primary : AppColors.divider,
            width: _isHovered ? 1.5 : 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDesktop
                            ? 'Impor & Drag-Drop Musik'
                            : 'Impor File Musik Lokal',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Dukungan: MP3 • FLAC • M4A • WAV • OGG • AAC • OPUS',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.isImporting
                          ? null
                          : widget.onPickFolder,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('Folder'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                        side: const BorderSide(color: Colors.orangeAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: widget.isImporting ? null : widget.onPickFiles,
                      icon: const Icon(
                        Icons.audio_file_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Pilih File',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
