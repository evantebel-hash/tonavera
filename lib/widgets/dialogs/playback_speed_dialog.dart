import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/player_provider.dart';
import 'settings_detail_dialog.dart';

class PlaybackSpeedDialog extends StatelessWidget {
  const PlaybackSpeedDialog({super.key});

  static void show(BuildContext context) {
    SettingsDetailDialog.show(
      context: context,
      icon: Icons.speed_rounded,
      title: 'Kecepatan Putar',
      subtitle: 'Atur kecepatan pemutaran audio',
      maxWidth: 440,
      maxHeight: 560,
      child: const PlaybackSpeedContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailDialog(
      icon: Icons.speed_rounded,
      title: 'Kecepatan Putar',
      subtitle: 'Atur kecepatan pemutaran audio',
      maxWidth: 440,
      maxHeight: 560,
      child: const PlaybackSpeedContent(),
    );
  }
}

class PlaybackSpeedContent extends StatelessWidget {
  const PlaybackSpeedContent({super.key});

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PILIH KECEPATAN PRESET',
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
                for (int i = 0; i < speeds.length; i++) ...[
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: i == 0 ? const Radius.circular(12) : Radius.zero,
                        bottom: i == speeds.length - 1
                            ? const Radius.circular(12)
                            : Radius.zero,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    title: Text(
                      speeds[i] == 1.0 ? '1.0x (Normal)' : '${speeds[i]}x',
                      style: TextStyle(
                        color: player.playbackSpeed == speeds[i]
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: player.playbackSpeed == speeds[i]
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    trailing: player.playbackSpeed == speeds[i]
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      player.setPlaybackSpeed(speeds[i]);
                    },
                  ),
                  if (i < speeds.length - 1)
                    const Divider(
                      color: AppColors.divider,
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Custom Speed Slider Card
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
                  const Text(
                    'Kustomisasi Presisi:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                      '${player.playbackSpeed.toStringAsFixed(2)}x',
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.divider,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: player.playbackSpeed.clamp(0.5, 2.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  onChanged: (val) {
                    player.setPlaybackSpeed(val);
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
