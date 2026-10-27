import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/player_provider.dart';
import 'settings_detail_dialog.dart';

class SleepTimerDialog extends StatefulWidget {
  const SleepTimerDialog({super.key});

  static void show(BuildContext context) {
    SettingsDetailDialog.show(
      context: context,
      icon: Icons.timer_rounded,
      title: 'Sleep Timer',
      subtitle: 'Matikan musik secara otomatis setelah waktu tertentu',
      maxWidth: 460,
      maxHeight: 560,
      child: const SleepTimerContent(),
    );
  }

  @override
  State<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
  @override
  Widget build(BuildContext context) {
    return SettingsDetailDialog(
      icon: Icons.timer_rounded,
      title: 'Sleep Timer',
      subtitle: 'Matikan musik secara otomatis setelah waktu tertentu',
      maxWidth: 460,
      maxHeight: 560,
      child: const SleepTimerContent(),
    );
  }
}

class SleepTimerContent extends StatefulWidget {
  const SleepTimerContent({super.key});

  @override
  State<SleepTimerContent> createState() => _SleepTimerContentState();
}

class _SleepTimerContentState extends State<SleepTimerContent> {
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _showCustomMinutesDialog(BuildContext context, PlayerProvider player) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Custom Sleep Timer',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: _customController,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Jumlah menit (misal: 25)',
              hintStyle: TextStyle(color: AppColors.textMuted),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final mins = int.tryParse(_customController.text.trim());
                if (mins != null && mins > 0) {
                  player.setSleepTimer(Duration(minutes: mins));
                  Navigator.pop(dialogCtx);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Simpan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final presetMinutes = [15, 30, 45, 60];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active status card if timer is running
        if (player.isSleepTimerActive) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Timer Sedang Berjalan',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        player.sleepTimerFormatted,
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    player.cancelSleepTimer();
                  },
                  child: const Text(
                    'Matikan',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Stop after current song switch tile
        Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: SwitchListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'Stop setelah lagu saat ini selesai',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Berhenti otomatis begitu lagu yang sedang diputar berakhir',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: player.stopAfterCurrentSong,
              activeThumbColor: AppColors.primary,
              onChanged: (val) {
                player.setSleepTimer(null, stopAfterCurrent: val);
              },
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Text(
          'PILIH DURASI TIMER',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),

        Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                ListTile(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  leading: const Icon(
                    Icons.timer_off_outlined,
                    color: AppColors.textMuted,
                  ),
                  title: const Text(
                    'Off (Matikan Timer)',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  trailing: !player.isSleepTimerActive
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    player.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                ),
                const Divider(
                  color: AppColors.divider,
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                for (final mins in presetMinutes) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.access_time_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      '$mins Menit',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      player.setSleepTimer(Duration(minutes: mins));
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(
                    color: AppColors.divider,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                ],
                ListTile(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  leading: const Icon(
                    Icons.edit_calendar_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Custom Menit...',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () => _showCustomMinutesDialog(context, player),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Footer button
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Selesai',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
