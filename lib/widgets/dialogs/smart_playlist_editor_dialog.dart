import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/smart_playlist_model.dart';
import '../../models/song_model.dart';
import '../../repositories/local_music_repository.dart';
import '../../services/smart_playlist_service.dart';

class SmartPlaylistEditorDialog extends StatefulWidget {
  final String? initialName;
  final String? initialDescription;
  final SmartPlaylistConfig? initialConfig;
  final bool isEditing;

  const SmartPlaylistEditorDialog({
    super.key,
    this.initialName,
    this.initialDescription,
    this.initialConfig,
    this.isEditing = false,
  });

  @override
  State<SmartPlaylistEditorDialog> createState() =>
      _SmartPlaylistEditorDialogState();
}

class _SmartPlaylistEditorDialogState extends State<SmartPlaylistEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late SmartRuleLogic _logic;
  late SmartSortOption _sort;
  int? _limit;
  late List<SmartPlaylistRule> _rules;

  List<SongModel> _previewSongs = [];
  bool _isLoadingPreview = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialName ?? 'Smart Playlist',
    );
    _descController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    final cfg = widget.initialConfig;
    _logic = cfg?.logic ?? SmartRuleLogic.all;
    _sort = cfg?.sort ?? SmartSortOption.titleAsc;
    _limit = cfg?.limit;
    _rules = cfg != null && cfg.rules.isNotEmpty
        ? List.from(cfg.rules)
        : [
            SmartPlaylistRule(
              field: SmartRuleField.favorite,
              operator: SmartRuleOperator.isTrue,
              value: 'true',
            ),
          ];

    _updatePreview();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _updatePreview() async {
    setState(() => _isLoadingPreview = true);
    try {
      final config = SmartPlaylistConfig(
        logic: _logic,
        rules: _rules,
        sort: _sort,
        limit: _limit,
      );
      final repo = LocalMusicRepository();
      final allSongs = await repo.getAllSongs();
      final favs = await repo.getFavorites();
      final favIds = favs.map((e) => e.id).toSet();
      final mapped = allSongs
          .map((s) => s.copyWith(isFavorite: favIds.contains(s.id)))
          .toList();

      final filtered = SmartPlaylistService.filterSongs(
        allSongs: mapped,
        config: config,
      );
      if (mounted) {
        setState(() {
          _previewSongs = filtered;
          _isLoadingPreview = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  void _addRule() {
    setState(() {
      _rules.add(
        SmartPlaylistRule(
          field: SmartRuleField.genre,
          operator: SmartRuleOperator.contains,
          value: '',
        ),
      );
    });
    _updatePreview();
  }

  void _removeRule(int index) {
    if (_rules.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 aturan untuk Smart Playlist.'),
        ),
      );
      return;
    }
    setState(() {
      _rules.removeAt(index);
    });
    _updatePreview();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600;

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isCompact ? size.width * 0.95 : 680,
        height: size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.isEditing
                      ? 'Edit Smart Playlist'
                      : 'Buat Smart Playlist Baru',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 8),

            // Scrollable Config & Rules
            Expanded(
              child: ListView(
                children: [
                  // Playlist Name
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Playlist',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi (Opsional)',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),

                  // Logic selector (ALL vs ANY)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Cocokkan Lagu:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<SmartRuleLogic>(
                          value: _logic,
                          dropdownColor: AppColors.surface,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(
                              value: SmartRuleLogic.all,
                              child: Text(
                                'SEMUA aturan (AND)',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                            DropdownMenuItem(
                              value: SmartRuleLogic.any,
                              child: Text(
                                'SALAH SATU aturan (OR)',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _logic = val);
                              _updatePreview();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rules list
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Aturan Kriteria:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addRule,
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        label: const Text(
                          'Tambah Aturan',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ..._rules.asMap().entries.map((entry) {
                    final index = entry.key;
                    final rule = entry.value;
                    return _buildRuleCard(index, rule);
                  }),
                  const SizedBox(height: 16),

                  // Sort & Limit
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Urutkan:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              DropdownButton<SmartSortOption>(
                                value: _sort,
                                isExpanded: true,
                                dropdownColor: AppColors.surface,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(
                                    value: SmartSortOption.titleAsc,
                                    child: Text('Judul (A-Z)'),
                                  ),
                                  DropdownMenuItem(
                                    value: SmartSortOption.titleDesc,
                                    child: Text('Judul (Z-A)'),
                                  ),
                                  DropdownMenuItem(
                                    value: SmartSortOption.artistAsc,
                                    child: Text('Artis (A-Z)'),
                                  ),
                                  DropdownMenuItem(
                                    value: SmartSortOption.albumAsc,
                                    child: Text('Album (A-Z)'),
                                  ),
                                  DropdownMenuItem(
                                    value: SmartSortOption.playCountDesc,
                                    child: Text('Jumlah Putar (Tertinggi)'),
                                  ),
                                  DropdownMenuItem(
                                    value: SmartSortOption.durationDesc,
                                    child: Text('Durasi (Terlama)'),
                                  ),
                                  DropdownMenuItem(
                                    value: SmartSortOption.durationAsc,
                                    child: Text('Durasi (Terpendek)'),
                                  ),
                                  DropdownMenuItem(
                                    value: SmartSortOption.random,
                                    child: Text('Acak (Random)'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _sort = val);
                                    _updatePreview();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Batas Maksimal:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              DropdownButton<int?>(
                                value: _limit,
                                isExpanded: true,
                                dropdownColor: AppColors.surface,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text('Tanpa Batas'),
                                  ),
                                  DropdownMenuItem(
                                    value: 10,
                                    child: Text('10 lagu'),
                                  ),
                                  DropdownMenuItem(
                                    value: 25,
                                    child: Text('25 lagu'),
                                  ),
                                  DropdownMenuItem(
                                    value: 50,
                                    child: Text('50 lagu'),
                                  ),
                                  DropdownMenuItem(
                                    value: 100,
                                    child: Text('100 lagu'),
                                  ),
                                ],
                                onChanged: (val) {
                                  setState(() => _limit = val);
                                  _updatePreview();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Preview Matched Count
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.music_note_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isLoadingPreview
                              ? 'Menghitung lagu yang cocok...'
                              : '${_previewSongs.length} lagu cocok saat ini',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 8),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama playlist tidak boleh kosong.'),
                        ),
                      );
                      return;
                    }
                    final config = SmartPlaylistConfig(
                      logic: _logic,
                      rules: _rules,
                      sort: _sort,
                      limit: _limit,
                    );
                    Navigator.of(context).pop({
                      'name': name,
                      'description': _descController.text.trim(),
                      'config': config,
                    });
                  },
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: Text(
                    widget.isEditing
                        ? 'Simpan Perubahan'
                        : 'Buat Smart Playlist',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
      ),
    );
  }

  Widget _buildRuleCard(int index, SmartPlaylistRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Field dropdown
              Expanded(
                flex: 3,
                child: DropdownButton<SmartRuleField>(
                  value: rule.field,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: SmartRuleField.title,
                      child: Text('Judul'),
                    ),
                    DropdownMenuItem(
                      value: SmartRuleField.artist,
                      child: Text('Artis'),
                    ),
                    DropdownMenuItem(
                      value: SmartRuleField.album,
                      child: Text('Album'),
                    ),
                    DropdownMenuItem(
                      value: SmartRuleField.genre,
                      child: Text('Genre'),
                    ),
                    DropdownMenuItem(
                      value: SmartRuleField.favorite,
                      child: Text('Favorit'),
                    ),
                    DropdownMenuItem(
                      value: SmartRuleField.playCount,
                      child: Text('Jumlah Putar'),
                    ),
                    DropdownMenuItem(
                      value: SmartRuleField.duration,
                      child: Text('Durasi (detik)'),
                    ),
                    DropdownMenuItem(
                      value: SmartRuleField.format,
                      child: Text('Format (mp3/flac/m4a)'),
                    ),
                    DropdownMenuItem(
                      value: SmartRuleField.lastPlayed,
                      child: Text('Terakhir Diputar'),
                    ),
                  ],
                  onChanged: (field) {
                    if (field != null) {
                      setState(() {
                        SmartRuleOperator defaultOp =
                            SmartRuleOperator.contains;
                        String defaultVal = '';
                        if (field == SmartRuleField.favorite) {
                          defaultOp = SmartRuleOperator.isTrue;
                          defaultVal = 'true';
                        } else if (field == SmartRuleField.playCount ||
                            field == SmartRuleField.duration) {
                          defaultOp = SmartRuleOperator.greaterThanOrEqual;
                          defaultVal = '10';
                        } else if (field == SmartRuleField.lastPlayed) {
                          defaultOp = SmartRuleOperator.withinLastNDays;
                          defaultVal = '7';
                        }
                        _rules[index] = SmartPlaylistRule(
                          field: field,
                          operator: defaultOp,
                          value: defaultVal,
                        );
                      });
                      _updatePreview();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Operator dropdown
              Expanded(
                flex: 3,
                child: DropdownButton<SmartRuleOperator>(
                  value: rule.operator,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  underline: const SizedBox(),
                  items: _getAvailableOperators(rule.field),
                  onChanged: (op) {
                    if (op != null) {
                      setState(() {
                        _rules[index] = SmartPlaylistRule(
                          field: rule.field,
                          operator: op,
                          value: rule.value,
                        );
                      });
                      _updatePreview();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Remove Rule Button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () => _removeRule(index),
              ),
            ],
          ),

          // Value input row if required
          if (rule.operator != SmartRuleOperator.isTrue &&
              rule.operator != SmartRuleOperator.isFalse) ...[
            const SizedBox(height: 6),
            TextFormField(
              initialValue: rule.value,
              decoration: InputDecoration(
                hintText: rule.field == SmartRuleField.lastPlayed
                    ? 'Contoh: 7 (hari)'
                    : rule.field == SmartRuleField.playCount
                    ? 'Contoh: 5'
                    : 'Nilai pencarian...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.card,
                border: const OutlineInputBorder(),
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              onChanged: (v) {
                _rules[index] = SmartPlaylistRule(
                  field: rule.field,
                  operator: rule.operator,
                  value: v,
                );
                _updatePreview();
              },
            ),
          ],
        ],
      ),
    );
  }

  List<DropdownMenuItem<SmartRuleOperator>> _getAvailableOperators(
    SmartRuleField field,
  ) {
    if (field == SmartRuleField.favorite) {
      return const [
        DropdownMenuItem(
          value: SmartRuleOperator.isTrue,
          child: Text('adalah YA'),
        ),
        DropdownMenuItem(
          value: SmartRuleOperator.isFalse,
          child: Text('adalah TIDAK'),
        ),
      ];
    }
    if (field == SmartRuleField.playCount ||
        field == SmartRuleField.duration ||
        field == SmartRuleField.year) {
      return const [
        DropdownMenuItem(
          value: SmartRuleOperator.greaterThanOrEqual,
          child: Text('>= (minimal)'),
        ),
        DropdownMenuItem(
          value: SmartRuleOperator.greaterThan,
          child: Text('> (lebih dari)'),
        ),
        DropdownMenuItem(
          value: SmartRuleOperator.equals,
          child: Text('= (sama dengan)'),
        ),
        DropdownMenuItem(
          value: SmartRuleOperator.lessThanOrEqual,
          child: Text('<= (maksimal)'),
        ),
        DropdownMenuItem(
          value: SmartRuleOperator.lessThan,
          child: Text('< (kurang dari)'),
        ),
      ];
    }
    if (field == SmartRuleField.lastPlayed) {
      return const [
        DropdownMenuItem(
          value: SmartRuleOperator.withinLastNDays,
          child: Text('dalam N hari'),
        ),
      ];
    }
    return const [
      DropdownMenuItem(
        value: SmartRuleOperator.contains,
        child: Text('mengandung'),
      ),
      DropdownMenuItem(
        value: SmartRuleOperator.equals,
        child: Text('sama dengan'),
      ),
      DropdownMenuItem(
        value: SmartRuleOperator.startsWith,
        child: Text('dimulai dengan'),
      ),
      DropdownMenuItem(
        value: SmartRuleOperator.endsWith,
        child: Text('diakhiri dengan'),
      ),
      DropdownMenuItem(
        value: SmartRuleOperator.notEquals,
        child: Text('tidak sama dengan'),
      ),
    ];
  }
}
