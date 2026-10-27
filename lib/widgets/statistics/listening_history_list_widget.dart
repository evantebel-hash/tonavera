import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/listening_history_model.dart';

class ListeningHistoryListWidget extends StatelessWidget {
  final List<ListeningHistoryModel> history;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final VoidCallback onClearHistory;

  const ListeningHistoryListWidget({
    super.key,
    required this.history,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: const [
            Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Belum Ada Riwayat Pemutaran',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Lagu yang Anda putar akan otomatis tercatat di sini.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final grouped = _groupByDate(history);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Riwayat Pemutaran (${history.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: onClearHistory,
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
                size: 18,
              ),
              label: const Text(
                'Hapus Riwayat',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: grouped.length,
          itemBuilder: (context, groupIdx) {
            final group = grouped[groupIdx];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 4.0,
                  ),
                  child: Text(
                    group.header,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.5),
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: group.items.length,
                    separatorBuilder: (ctx, idx) =>
                        const Divider(color: AppColors.divider, height: 1),
                    itemBuilder: (context, itemIdx) {
                      final item = group.items[itemIdx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 40,
                            height: 40,
                            color: AppColors.card,
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${item.artistName} • ${_formatSeconds(item.durationPlayed)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (item.completed) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Selesai',
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else if (item.skipped) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Dilewati',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Text(
                          '${item.startedAt.hour.toString().padLeft(2, '0')}:${item.startedAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
        if (hasMore) ...[
          const SizedBox(height: 12),
          Center(
            child: isLoadingMore
                ? const CircularProgressIndicator(color: AppColors.primary)
                : OutlinedButton(
                    onPressed: onLoadMore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Muat Lebih Banyak'),
                  ),
          ),
        ],
      ],
    );
  }

  List<_HistoryDateGroup> _groupByDate(List<ListeningHistoryModel> list) {
    final groups = <_HistoryDateGroup>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String currentHeader = '';
    List<ListeningHistoryModel> currentList = [];

    for (final item in list) {
      final itemDate = DateTime(
        item.startedAt.year,
        item.startedAt.month,
        item.startedAt.day,
      );
      String header;
      if (itemDate == today) {
        header = 'Hari Ini';
      } else if (itemDate == yesterday) {
        header = 'Kemarin';
      } else {
        header =
            '${itemDate.day} ${_getMonthName(itemDate.month)} ${itemDate.year}';
      }

      if (header != currentHeader) {
        if (currentList.isNotEmpty) {
          groups.add(
            _HistoryDateGroup(header: currentHeader, items: currentList),
          );
        }
        currentHeader = header;
        currentList = [item];
      } else {
        currentList.add(item);
      }
    }

    if (currentList.isNotEmpty) {
      groups.add(_HistoryDateGroup(header: currentHeader, items: currentList));
    }

    return groups;
  }

  String _getMonthName(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return months[m - 1];
  }

  String _formatSeconds(int seconds) {
    final mins = seconds ~/ 60;
    final rem = seconds % 60;
    return '${mins}m ${rem}d';
  }
}

class _HistoryDateGroup {
  final String header;
  final List<ListeningHistoryModel> items;

  _HistoryDateGroup({required this.header, required this.items});
}
