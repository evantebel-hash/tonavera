import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/playlist_model.dart';

/// Reusable dialog/bottom sheet for picking one or multiple playlists.
class PlaylistPickerDialog extends StatefulWidget {
  final List<PlaylistModel> playlists;
  final int selectedSongCount;
  final bool allowMultiplePlaylists;

  const PlaylistPickerDialog({
    super.key,
    required this.playlists,
    required this.selectedSongCount,
    this.allowMultiplePlaylists = true,
  });

  static Future<List<int>?> show(
    BuildContext context, {
    required List<PlaylistModel> playlists,
    required int selectedSongCount,
    bool allowMultiplePlaylists = true,
  }) {
    return showDialog<List<int>>(
      context: context,
      builder: (ctx) => PlaylistPickerDialog(
        playlists: playlists,
        selectedSongCount: selectedSongCount,
        allowMultiplePlaylists: allowMultiplePlaylists,
      ),
    );
  }

  @override
  State<PlaylistPickerDialog> createState() => _PlaylistPickerDialogState();
}

class _PlaylistPickerDialogState extends State<PlaylistPickerDialog> {
  final Set<int> _selectedPlaylistIds = <int>{};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredPlaylists = widget.playlists.where((p) {
      if (p.isSmart)
        return false; // Exclude smart playlists from manual insertions
      if (_searchQuery.trim().isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.playlist_add_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tambahkan ${widget.selectedSongCount} Lagu ke Playlist',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari playlist...',
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: filteredPlaylists.isEmpty
            ? const Center(
                child: Text(
                  'Tidak ada playlist yang tersedia.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.builder(
                itemCount: filteredPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = filteredPlaylists[index];
                  final isChecked = _selectedPlaylistIds.contains(playlist.id);

                  return CheckboxListTile(
                    activeColor: AppColors.primary,
                    checkColor: Colors.white,
                    value: isChecked,
                    title: Text(
                      playlist.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${playlist.songs.length} lagu',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          if (!widget.allowMultiplePlaylists) {
                            _selectedPlaylistIds.clear();
                          }
                          _selectedPlaylistIds.add(playlist.id!);
                        } else {
                          _selectedPlaylistIds.remove(playlist.id);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _selectedPlaylistIds.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedPlaylistIds.toList()),
          child: Text(
            'Tambahkan (${_selectedPlaylistIds.length})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
