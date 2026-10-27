import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/listening_statistics_model.dart';
import '../../models/listening_history_model.dart';

class ListeningCalendarWidget extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, DailyListeningActivityModel> monthlyActivity;
  final DateTime? selectedDate;
  final List<ListeningHistoryModel> selectedDateHistory;
  final Function(int year, int month) onMonthChanged;
  final Function(DateTime date) onDateSelected;

  const ListeningCalendarWidget({
    super.key,
    required this.year,
    required this.month,
    required this.monthlyActivity,
    this.selectedDate,
    required this.selectedDateHistory,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month navigation header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.textPrimary,
                ),
                onPressed: () {
                  if (month == 1) {
                    onMonthChanged(year - 1, 12);
                  } else {
                    onMonthChanged(year, month - 1);
                  }
                },
              ),
              Text(
                '${_getMonthName(month)} $year',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textPrimary,
                ),
                onPressed: () {
                  if (month == 12) {
                    onMonthChanged(year + 1, 1);
                  } else {
                    onMonthChanged(year, month + 1);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Day of week headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _WeekdayHeader('Sen'),
              _WeekdayHeader('Sel'),
              _WeekdayHeader('Rab'),
              _WeekdayHeader('Kam'),
              _WeekdayHeader('Jum'),
              _WeekdayHeader('Sab'),
              _WeekdayHeader('Min'),
            ],
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 weeks * 7 days
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - (startWeekday - 1);
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox.shrink();
              }

              final day = dayOffset + 1;
              final cellDate = DateTime(year, month, day);
              final dateStr =
                  '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final activity = monthlyActivity[dateStr];
              final seconds = activity?.totalSeconds ?? 0;
              final isSelected =
                  selectedDate != null &&
                  selectedDate!.year == year &&
                  selectedDate!.month == month &&
                  selectedDate!.day == day;

              final color = _getIntensityColor(seconds, isSelected);

              return InkWell(
                onTap: () => onDateSelected(cellDate),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : Border.all(
                            color: AppColors.divider.withValues(alpha: 0.2),
                          ),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected || seconds > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (seconds > 0
                                  ? Colors.white
                                  : AppColors.textMuted),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Aktivitas: ',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              _LegendItem(color: AppColors.surface, label: '0m'),
              const SizedBox(width: 8),
              _LegendItem(
                color: AppColors.primary.withValues(alpha: 0.3),
                label: '<15m',
              ),
              const SizedBox(width: 8),
              _LegendItem(
                color: AppColors.primary.withValues(alpha: 0.6),
                label: '<60m',
              ),
              const SizedBox(width: 8),
              _LegendItem(color: AppColors.primary, label: '60m+'),
            ],
          ),

          if (selectedDate != null) ...[
            const Divider(color: AppColors.divider, height: 28),
            Text(
              'Detail Aktivitas: ${selectedDate!.day} ${_getMonthName(selectedDate!.month)} ${selectedDate!.year}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (selectedDateHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'Tidak ada riwayat pemutaran pada tanggal ini.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: selectedDateHistory.length.clamp(0, 10),
                itemBuilder: (context, idx) {
                  final item = selectedDateHistory[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(
                      Icons.music_note_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${item.artistName} • ${_formatSeconds(item.durationPlayed)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
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
          ],
        ],
      ),
    );
  }

  Color _getIntensityColor(int seconds, bool isSelected) {
    if (isSelected) return AppColors.primary;
    if (seconds == 0) return AppColors.surface;
    if (seconds < 900) return AppColors.primary.withValues(alpha: 0.3);
    if (seconds < 3600) return AppColors.primary.withValues(alpha: 0.6);
    return AppColors.primary;
  }

  String _getMonthName(int m) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[m - 1];
  }

  String _formatSeconds(int seconds) {
    final mins = seconds ~/ 60;
    final rem = seconds % 60;
    return '${mins}m ${rem}d';
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String title;
  const _WeekdayHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
