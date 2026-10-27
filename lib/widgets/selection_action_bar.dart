import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/multi_select_controller.dart';

/// Selection Action Bar displayed at the top or bottom during selection mode.
class SelectionActionBar extends StatelessWidget
    implements PreferredSizeWidget {
  final MultiSelectController controller;
  final List<int> visibleSongIds;
  final VoidCallback onAddToPlaylist;
  final VoidCallback? onRemoveFromPlaylist;
  final VoidCallback? onDownload;
  final String? removeTooltip;

  const SelectionActionBar({
    super.key,
    required this.controller,
    required this.visibleSongIds,
    required this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
    this.onDownload,
    this.removeTooltip,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isSelectionMode) {
          return const SizedBox.shrink();
        }

        final count = controller.selectedCount;
        final allSelected =
            visibleSongIds.isNotEmpty &&
            visibleSongIds.every((id) => controller.isSelected(id));

        return AppBar(
          backgroundColor: AppColors.card,
          elevation: 4,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
            tooltip: 'Batalkan Seleksi (Esc)',
            onPressed: () => controller.clear(),
          ),
          title: Text(
            '$count dipilih',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                color: AppColors.primary,
              ),
              tooltip: allSelected ? 'Deselect All' : 'Select All',
              onPressed: () {
                if (allSelected) {
                  controller.deselectAll();
                } else {
                  controller.selectAll(visibleSongIds);
                }
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.playlist_add_rounded,
                color: AppColors.primary,
              ),
              tooltip: 'Tambahkan ke Playlist',
              onPressed: count > 0 ? onAddToPlaylist : null,
            ),
            if (onDownload != null)
              IconButton(
                icon: const Icon(
                  Icons.download_rounded,
                  color: AppColors.primary,
                ),
                tooltip: 'Unduh Lagu Terpilih',
                onPressed: count > 0 ? onDownload : null,
              ),
            if (onRemoveFromPlaylist != null)
              IconButton(
                icon: const Icon(
                  Icons.playlist_remove_rounded,
                  color: Colors.redAccent,
                ),
                tooltip: removeTooltip ?? 'Hapus dari Playlist',
                onPressed: count > 0 ? onRemoveFromPlaylist : null,
              ),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }
}
