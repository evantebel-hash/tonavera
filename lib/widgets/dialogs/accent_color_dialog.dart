import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../providers/player_provider.dart';

/// Modal dialog allowing users to configure the Adaptive Accent Color System.
///
/// Features:
/// - 10 Curated presets with tonal depth previews
/// - Custom Color mode with instant HSL derivation
/// - Dynamic Artwork extraction mode backed by ArtworkColorService
/// - Clean V3.5 Obsidian glassmorphism surface
class AccentColorDialog extends StatefulWidget {
  const AccentColorDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const AccentColorDialog(),
    );
  }

  @override
  State<AccentColorDialog> createState() => _AccentColorDialogState();
}

class _AccentColorDialogState extends State<AccentColorDialog> {
  late Color _customColor;
  double _hueValue = 38.0; // Default Amber hue ~38

  @override
  void initState() {
    super.initState();
    _customColor = V35Accent.current.base;
    _hueValue = HSLColor.fromColor(_customColor).hue;
  }

  void _onHueChanged(double hue) {
    setState(() {
      _hueValue = hue;
      _customColor = HSLColor.fromAHSL(1.0, hue, 0.85, 0.50).toColor();
    });
    V35Accent.setCustomColor(_customColor);
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context, listen: false);

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, activeAccent, child) {
        return Dialog(
          backgroundColor: V35Tokens.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: V35Tokens.brXl,
            side: const BorderSide(color: V35Tokens.borderCard, width: 1.0),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dialog Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: activeAccent.base.withValues(alpha: 0.15),
                          borderRadius: V35Tokens.brSm,
                        ),
                        child: Icon(
                          Icons.palette_rounded,
                          color: activeAccent.base,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Warna Aksen (Accent Color)',
                              style: TextStyle(
                                color: V35Tokens.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              activeAccent.mode == AccentMode.dynamicArtwork
                                  ? 'Mode: Ikuti Sampul Album'
                                  : 'Aktif: ${activeAccent.name}',
                              style: const TextStyle(
                                color: V35Tokens.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: V35Tokens.textSecondary,
                        ),
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: V35Tokens.borderSubtle),

                // Scrollable Content
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    children: [
                      // SECTION 1: PRESET PALETTES
                      _buildSectionLabel('PILIHAN PRESET (10 WARNA)'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: AccentPreset.all.map((preset) {
                          final isSelected =
                              activeAccent.mode == AccentMode.preset &&
                              activeAccent.id == preset.id;
                          return _buildPresetTile(preset, isSelected);
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // SECTION 2: DYNAMIC ARTWORK
                      _buildSectionLabel('WARNA DINAMIS DARI MUSIK'),
                      const SizedBox(height: 10),
                      _buildDynamicArtworkCard(player, activeAccent),

                      const SizedBox(height: 24),

                      // SECTION 3: CUSTOM COLOR
                      _buildSectionLabel('WARNA KUSTOM (CUSTOM)'),
                      const SizedBox(height: 10),
                      _buildCustomColorCard(activeAccent),
                    ],
                  ),
                ),

                const Divider(height: 1, color: V35Tokens.borderSubtle),

                // Dialog Footer
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Selesai',
                          style: TextStyle(
                            color: activeAccent.bright,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: V35Tokens.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildPresetTile(AccentPreset preset, bool isSelected) {
    return Material(
      color: isSelected
          ? preset.base.withValues(alpha: 0.15)
          : V35Tokens.bgElevated,
      borderRadius: V35Tokens.brMd,
      child: InkWell(
        borderRadius: V35Tokens.brMd,
        onTap: () {
          V35Accent.setPreset(preset);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: V35Tokens.brMd,
            border: Border.all(
              color: isSelected ? preset.base : V35Tokens.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: preset.base,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: preset.base.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                preset.name,
                style: TextStyle(
                  color: isSelected
                      ? V35Tokens.textPrimary
                      : V35Tokens.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_rounded, color: preset.base, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicArtworkCard(
    PlayerProvider player,
    V35AccentPalette activeAccent,
  ) {
    final isDynamic = activeAccent.mode == AccentMode.dynamicArtwork;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDynamic
            ? activeAccent.base.withValues(alpha: 0.12)
            : V35Tokens.bgElevated,
        borderRadius: V35Tokens.brMd,
        border: Border.all(
          color: isDynamic ? activeAccent.base : V35Tokens.borderSubtle,
          width: isDynamic ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDynamic
                  ? activeAccent.base.withValues(alpha: 0.25)
                  : V35Tokens.bgSurface,
              borderRadius: V35Tokens.brSm,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: isDynamic ? activeAccent.base : V35Tokens.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ikuti Sampul Album (Dynamic Artwork)',
                  style: TextStyle(
                    color: V35Tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ekstrak warna aksen otomatis dari cover lagu yang sedang diputar',
                  style: TextStyle(color: V35Tokens.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: isDynamic,
            activeThumbColor: activeAccent.base,
            onChanged: (enabled) {
              if (enabled) {
                V35Accent.setDynamicArtworkMode(
                  currentSong: player.currentSong,
                );
              } else {
                V35Accent.setPreset(AccentPreset.amber);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomColorCard(V35AccentPalette activeAccent) {
    final isCustom = activeAccent.mode == AccentMode.custom;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCustom
            ? activeAccent.base.withValues(alpha: 0.12)
            : V35Tokens.bgElevated,
        borderRadius: V35Tokens.brMd,
        border: Border.all(
          color: isCustom ? activeAccent.base : V35Tokens.borderSubtle,
          width: isCustom ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _customColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _customColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Spektrum Warna (Hue Slider)',
                  style: TextStyle(
                    color: isCustom
                        ? V35Tokens.textPrimary
                        : V35Tokens.textSecondary,
                    fontSize: 13,
                    fontWeight: isCustom ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              // Derived Tones Preview Bar
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: activeAccent.bright,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: activeAccent.base,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: activeAccent.deep,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Gradient track for hue picker
          Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayColor: _customColor.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _hueValue,
              min: 0,
              max: 360,
              onChanged: _onHueChanged,
            ),
          ),
        ],
      ),
    );
  }
}
