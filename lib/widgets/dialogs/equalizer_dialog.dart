import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../providers/player_provider.dart';
import 'settings_detail_dialog.dart';

class EqualizerDialog extends StatelessWidget {
  const EqualizerDialog({super.key});

  static void show(BuildContext context) {
    SettingsDetailDialog.show(
      context: context,
      icon: Icons.equalizer_rounded,
      title: 'Equalizer',
      subtitle: 'Audio & Harmonisasi',
      maxWidth: 520,
      maxHeight: 520,
      child: const EqualizerContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailDialog(
      icon: Icons.equalizer_rounded,
      title: 'Equalizer',
      subtitle: 'Audio & Harmonisasi',
      maxWidth: 520,
      maxHeight: 520,
      child: const EqualizerContent(),
    );
  }
}

class EqualizerContent extends StatelessWidget {
  const EqualizerContent({super.key});

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final bandLabels = ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz'];

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Switch & Header row inside content
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        player.equalizerEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: player.equalizerEnabled
                            ? V35Tokens.accent
                            : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        player.equalizerEnabled
                            ? 'Equalizer Aktif'
                            : 'Equalizer Nonaktif',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: player.equalizerEnabled,
                    onChanged: player.isEqualizerSupported
                        ? (val) => player.setEqualizerEnabled(val)
                        : null,
                    activeThumbColor: V35Tokens.accent,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Windows backend note if unsupported
            if (!player.isEqualizerSupported) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Equalizer tidak didukung oleh audio backend Windows pada platform ini.',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Preset selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Preset:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: player.equalizerPreset,
                      dropdownColor: AppColors.card,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: V35Tokens.accent,
                      ),
                      onChanged:
                          player.equalizerEnabled && player.isEqualizerSupported
                          ? (val) {
                              if (val != null) player.setEqualizerPreset(val);
                            }
                          : null,
                      items: PlayerProvider.eqPresets.keys.map((preset) {
                        return DropdownMenuItem<String>(
                          value: preset,
                          child: Text(preset),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Sliders for 5 bands
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.card.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.divider.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(5, (index) {
                  final currentVal = player.currentBands[index];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${currentVal > 0 ? "+" : ""}${currentVal.toStringAsFixed(1)} dB',
                        style: TextStyle(
                          color: player.equalizerEnabled
                              ? V35Tokens.accentBright
                              : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140,
                        width: 36,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                              activeTrackColor: V35Tokens.accent,
                              inactiveTrackColor: AppColors.divider,
                              thumbColor: V35Tokens.accent,
                            ),
                            child: Slider(
                              value: currentVal.clamp(-12.0, 12.0),
                              min: -12.0,
                              max: 12.0,
                              onChanged:
                                  player.equalizerEnabled &&
                                      player.isEqualizerSupported
                                  ? (val) =>
                                        player.setCustomBandValue(index, val)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bandLabels[index],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      player.equalizerEnabled && player.isEqualizerSupported
                      ? () => player.resetEqualizer()
                      : null,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: V35Tokens.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Selesai',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
