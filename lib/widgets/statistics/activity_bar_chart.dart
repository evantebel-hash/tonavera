import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/listening_statistics_model.dart';

class ActivityBarChart extends StatelessWidget {
  final Map<String, DailyListeningActivityModel> monthlyActivity;
  final int year;
  final int month;

  const ActivityBarChart({
    super.key,
    required this.monthlyActivity,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    int maxSeconds = 1;
    for (final act in monthlyActivity.values) {
      if (act.totalSeconds > maxSeconds) {
        maxSeconds = act.totalSeconds;
      }
    }

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: V35Tokens.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: V35Tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Aktivitas Harian Bulan Ini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: V35Tokens.textPrimary,
                    ),
                  ),
                  Text(
                    'Max ${_formatMinutes(maxSeconds)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: V35Tokens.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: daysInMonth,
                  separatorBuilder: (ctx, idx) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final dateStr =
                        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                    final activity = monthlyActivity[dateStr];
                    final seconds = activity?.totalSeconds ?? 0;
                    final heightFactor = (seconds / maxSeconds).clamp(
                      0.05,
                      1.0,
                    );

                    return Tooltip(
                      message:
                          '$day ${_getMonthName(month)}: ${_formatMinutes(seconds)} (${activity?.totalPlays ?? 0} putaran)',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 14,
                            height: 80 * heightFactor,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: seconds > 0
                                    ? [V35Tokens.accent, V35Tokens.accentBright]
                                    : const [
                                        V35Tokens.borderSubtle,
                                        V35Tokens.borderSubtle,
                                      ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 10,
                              color: seconds > 0
                                  ? V35Tokens.textPrimary
                                  : V35Tokens.textMuted,
                              fontWeight: seconds > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatMinutes(int seconds) {
    final mins = seconds ~/ 60;
    if (mins < 60) return '$mins mnt';
    final hours = mins ~/ 60;
    final rem = mins % 60;
    return '${hours}j ${rem}m';
  }

  String _getMonthName(int month) {
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
    return months[month - 1];
  }
}
