import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/player_provider.dart';
import 'settings_detail_dialog.dart';

class CrossfadeDialog extends StatelessWidget {
  const CrossfadeDialog({super.key});

  static void show(BuildContext context) {
    SettingsDetailDialog.show(
      context: context,
      icon: Icons.shuffle_on_outlined,
      title: 'Crossfade',
      subtitle: 'Transisi halus antar lagu',
      maxWidth: 460,
      maxHeight: 460,
      child: const CrossfadeContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailDialog(
      icon: Icons.shuffle_on_outlined,
      title: 'Crossfade',
      subtitle: 'Transisi halus antar lagu',
      maxWidth: 460,
      maxHeight: 460,
      child: const CrossfadeContent(),
    );
  }
}

class CrossfadeContent extends StatelessWidget {
  const CrossfadeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Menggabungkan transisi antar lagu dengan memudarkan lagu saat ini dan memunculkan lagu berikutnya secara mulus.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Durasi Crossfade:',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      player.crossfadeDuration == 0
                          ? 'Matikan (0 detik)'
                          : '${player.crossfadeDuration} detik',
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.divider,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: player.crossfadeDuration.toDouble(),
                  min: 0,
                  max: 12,
                  divisions: 12,
                  label: '${player.crossfadeDuration}s',
                  onChanged: (val) {
                    player.setCrossfadeDuration(val.toInt());
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Footer Button
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
