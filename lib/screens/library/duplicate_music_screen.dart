import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/duplicate_group_model.dart';
import '../../models/song_model.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/player_provider.dart';
import '../../repositories/local_music_repository.dart';
import '../../services/duplicate_detector_service.dart';
import '../../widgets/app_image.dart';

class DuplicateMusicScreen extends StatefulWidget {
  const DuplicateMusicScreen({super.key});

  @override
  State<DuplicateMusicScreen> createState() => _DuplicateMusicScreenState();
}

class _DuplicateMusicScreenState extends State<DuplicateMusicScreen> {
  final LocalMusicRepository _repo = LocalMusicRepository();
  late final DuplicateDetectorService _detectorService;

  List<SongModel> _allSongs = [];
  List<DuplicateGroup> _duplicateGroups = [];
  final Map<String, int> _selectedKeepPerGroup = {}; // groupId -> songId

  bool _isLoading = true;
  String? _errorMessage;
  int _selectedGroupIndex = 0;
  bool _isProcessingDelete = false;

  @override
  void initState() {
    super.initState();
    _detectorService = DuplicateDetectorService(repository: _repo);
    _scanForDuplicates();
  }

  Future<void> _scanForDuplicates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final songs = await _repo.getAllSongs();
      final groups = _detectorService.detectDuplicates(songs);

      setState(() {
        _allSongs = songs;
        _duplicateGroups = groups;
        _selectedKeepPerGroup.clear();
        for (final g in groups) {
          _selectedKeepPerGroup[g.groupId] = g.recommendedKeepSongId;
        }
        if (_selectedGroupIndex >= groups.length) {
          _selectedGroupIndex = groups.isNotEmpty ? 0 : 0;
        }
      });
    } catch (e) {
      debugPrint('Error scanning duplicates: $e');
      setState(() {
        _errorMessage = 'Gagal memindai pustaka musik: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openFileLocation(String filePath) {
    try {
      if (Platform.isWindows) {
        Process.run('explorer.exe', ['/select,', filePath]);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lokasi file: $filePath')));
      }
    } catch (e) {
      debugPrint('Error opening file location: $e');
    }
  }

  Future<void> _confirmAndKeepSelected(DuplicateGroup group) async {
    final keepSongId =
        _selectedKeepPerGroup[group.groupId] ?? group.recommendedKeepSongId;
    final keepCandidate = group.candidates.firstWhere(
      (c) => c.song.id == keepSongId,
    );
    final candidatesToDelete = group.candidates
        .where((c) => c.song.id != keepSongId)
        .toList();

    if (candidatesToDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua file di grup ini sudah dipertahankan.'),
        ),
      );
      return;
    }

    int totalBytesToDelete = 0;
    for (final c in candidatesToDelete) {
      totalBytesToDelete += (c.fileSizeBytes ?? 0);
    }
    final totalSizeMb = (totalBytesToDelete / (1024 * 1024)).toStringAsFixed(1);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V35Tokens.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: V35Tokens.borderSubtle),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Konfirmasi Hapus Duplikat',
                style: V35Tokens.heading.copyWith(
                  color: V35Tokens.textPrimary,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File yang dipilih akan dipertahankan:\n• ${keepCandidate.song.title} (${keepCandidate.song.filePath ?? keepCandidate.song.audioPath})',
                style: TextStyle(
                  color: V35Tokens.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${candidatesToDelete.length} file berikut akan DIHAPUS PERMANEN dari perangkat ($totalSizeMb MB):',
                style: V35Tokens.heading.copyWith(
                  color: V35Tokens.textPrimary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: V35Tokens.bgVoid,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: V35Tokens.borderSubtle),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidatesToDelete.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: V35Tokens.borderSubtle, height: 8),
                  itemBuilder: (context, i) {
                    final c = candidatesToDelete[i];
                    return Text(
                      '🗑 ${c.song.filePath ?? c.song.audioPath} (${c.fileSizeFormatted})',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'PERINGATAN: File fisik yang dihapus mungkin tidak dapat dipulihkan. Pastikan Anda mempertahankan file yang benar.',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: V35Tokens.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Hapus File Duplikat',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessingDelete = true);
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final catalog = Provider.of<CatalogProvider>(context, listen: false);

    int deletedCount = 0;
    String? lastError;

    for (final c in candidatesToDelete) {
      try {
        await _detectorService.deleteDuplicateCandidate(
          songToDelete: c.song,
          songToKeep: keepCandidate.song,
          player: player,
        );
        deletedCount++;
      } catch (e) {
        lastError = e.toString();
        debugPrint('Error deleting candidate: $e');
      }
    }

    if (mounted) {
      setState(() => _isProcessingDelete = false);
      if (deletedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$deletedCount file duplikat berhasil dihapus dan dibersihkan!',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        try {
          await catalog.fetchCatalogData();
        } catch (_) {}
        await _scanForDuplicates();
      } else if (lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lastError), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _ignoreGroup(DuplicateGroup group) {
    setState(() {
      _duplicateGroups.removeWhere((g) => g.groupId == group.groupId);
      if (_selectedGroupIndex >= _duplicateGroups.length) {
        _selectedGroupIndex = _duplicateGroups.isNotEmpty
            ? _duplicateGroups.length - 1
            : 0;
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Grup duplikat dilewati.')));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Pembersih Lagu Duplikat',
              style: V35Tokens.heading.copyWith(
                fontSize: 18,
                color: V35Tokens.textPrimary,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: V35Tokens.accent),
                tooltip: 'Pindai Ulang',
                onPressed: _isLoading ? null : _scanForDuplicates,
              ),
            ],
          ),
          body: _buildBody(isDesktop),
        );
      },
    );
  }

  Widget _buildBody(bool isDesktop) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Memindai pustaka untuk lagu duplikat...',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Memeriksa trackHash & tanda tangan metadata secara lokal',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Tidak dapat memindai pustaka Anda',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _scanForDuplicates,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  'Coba Lagi',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_allSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 16),
            Text(
              'Tidak ada musik yang tersedia untuk dipindai',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Impor file lagu lokal terlebih dahulu untuk menggunakan fitur ini.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_duplicateGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 72,
              color: Colors.greenAccent,
            ),
            SizedBox(height: 16),
            Text(
              'Pustaka Bersih! Tidak Ditemukan Lagu Duplikat',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Semua lagu di pustaka lokal Anda unik berdasarkan judul, artis, dan durasi.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildDesktopLayout() {
    final selectedGroup = _duplicateGroups[_selectedGroupIndex];

    return Row(
      children: [
        // Left Column: List of Duplicate Groups
        SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ditemukan ${_duplicateGroups.length} Grup Duplikat',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_allSongs.length} lagu total',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.divider, height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: _duplicateGroups.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.divider, height: 1),
                  itemBuilder: (context, index) {
                    final g = _duplicateGroups[index];
                    final isSelected = index == _selectedGroupIndex;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: AppImage(
                            imagePath: g.candidates.first.song.cover,
                            width: 44,
                            height: 44,
                            defaultIcon: Icons.music_note_rounded,
                          ),
                        ),
                      ),
                      title: Text(
                        g.title,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primaryLight
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${g.artist} • ${g.candidates.length} file',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            g.reasonDescription,
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() => _selectedGroupIndex = index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(color: AppColors.divider, width: 1),

        // Right Column: Group Details & File Selection
        Expanded(child: _buildGroupDetailPanel(selectedGroup)),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _duplicateGroups.length,
      itemBuilder: (context, index) {
        final g = _duplicateGroups[index];
        return Card(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.divider),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: AppImage(
                          imagePath: g.candidates.first.song.cover,
                          width: 52,
                          height: 52,
                          defaultIcon: Icons.music_note_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${g.artist} • ${g.album}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.amberAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Alasan: ${g.reasonDescription}',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pilih file yang ingin dipertahankan:',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...g.candidates.map((c) => _buildCandidateTile(g, c)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _ignoreGroup(g),
                      child: const Text(
                        'Lewati',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isProcessingDelete
                          ? null
                          : () => _confirmAndKeepSelected(g),
                      icon: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Pertahankan Terpilih',
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
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupDetailPanel(DuplicateGroup group) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: AppImage(
                    imagePath: group.candidates.first.song.cover,
                    width: 72,
                    height: 72,
                    defaultIcon: Icons.music_note_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.artist} • ${group.album} • ${_formatDuration(group.duration)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Alasan Deteksi: ${group.reasonDescription}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Daftar File Duplikat (Pilih satu file terbaik untuk dipertahankan):',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // List of candidates
          Expanded(
            child: ListView.builder(
              itemCount: group.candidates.length,
              itemBuilder: (context, i) {
                final candidate = group.candidates[i];
                return _buildCandidateTile(group, candidate);
              },
            ),
          ),

          const SizedBox(height: 16),
          // Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _ignoreGroup(group),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                child: const Text(
                  'Lewati Grup Ini',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isProcessingDelete
                    ? null
                    : () => _confirmAndKeepSelected(group),
                icon: _isProcessingDelete
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                label: Text(
                  _isProcessingDelete
                      ? 'Memproses...'
                      : 'Pertahankan Pilihan & Hapus Sisanya',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateTile(
    DuplicateGroup group,
    DuplicateSongCandidate candidate,
  ) {
    final selectedKeepId =
        _selectedKeepPerGroup[group.groupId] ?? group.recommendedKeepSongId;
    final isSelected = candidate.song.id == selectedKeepId;
    final isRecommended = candidate.song.id == group.recommendedKeepSongId;
    final filePath = candidate.song.filePath ?? candidate.song.audioPath;
    final fileName = filePath.contains(Platform.pathSeparator)
        ? filePath.split(Platform.pathSeparator).last
        : filePath;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? V35Tokens.accent.withValues(alpha: 0.1)
            : V35Tokens.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? V35Tokens.accent : V35Tokens.borderSubtle,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: RadioListTile<int>(
        value: candidate.song.id,
        // ignore: deprecated_member_use
        groupValue: selectedKeepId,
        activeColor: V35Tokens.accent,
        // ignore: deprecated_member_use
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _selectedKeepPerGroup[group.groupId] = val;
            });
          }
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                fileName,
                style: V35Tokens.heading.copyWith(
                  fontSize: 13,
                  color: V35Tokens.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRecommended)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: const Text(
                  'Direkomendasikan',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              filePath,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Format: ${candidate.fileFormat}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Ukuran: ${candidate.fileSizeFormatted}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Durasi: ${_formatDuration(candidate.song.duration)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.folder_open_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Buka di Explorer / Folder',
                  onPressed: () => _openFileLocation(filePath),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
