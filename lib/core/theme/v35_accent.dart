import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/song_model.dart';
import '../../services/artwork_color_service.dart';

/// Operational modes for the V3.5 Adaptive Accent Color System.
enum AccentMode { preset, custom, dynamicArtwork }

/// Representation of an immutable preset accent with three derived tonal depths.
class AccentPreset {
  final String id;
  final String name;
  final Color base;
  final Color bright;
  final Color deep;

  const AccentPreset({
    required this.id,
    required this.name,
    required this.base,
    required this.bright,
    required this.deep,
  });

  // ---------------------------------------------------------------------------
  // BUILT-IN PRESETS SPECIFIED BY PHASE 7F
  // ---------------------------------------------------------------------------
  static const AccentPreset amber = AccentPreset(
    id: 'amber',
    name: 'Amber',
    base: Color(0xFFF59E0B),
    bright: Color(0xFFFBBF24),
    deep: Color(0xFFD97706),
  );

  static const AccentPreset gold = AccentPreset(
    id: 'gold',
    name: 'Gold',
    base: Color(0xFFD4AF37),
    bright: Color(0xFFF4D35E),
    deep: Color(0xFFA88918),
  );

  static const AccentPreset copper = AccentPreset(
    id: 'copper',
    name: 'Copper',
    base: Color(0xFFC2410C),
    bright: Color(0xFFEA580C),
    deep: Color(0xFF9A3412),
  );

  static const AccentPreset electricBlue = AccentPreset(
    id: 'electric_blue',
    name: 'Electric Blue',
    base: Color(0xFF3B82F6),
    bright: Color(0xFF60A5FA),
    deep: Color(0xFF2563EB),
  );

  static const AccentPreset cyan = AccentPreset(
    id: 'cyan',
    name: 'Cyan',
    base: Color(0xFF06B6D4),
    bright: Color(0xFF22D3EE),
    deep: Color(0xFF0891B2),
  );

  static const AccentPreset violet = AccentPreset(
    id: 'violet',
    name: 'Violet',
    base: Color(0xFF8B5CF6),
    bright: Color(0xFFA78BFA),
    deep: Color(0xFF7C3AED),
  );

  static const AccentPreset fuchsia = AccentPreset(
    id: 'fuchsia',
    name: 'Fuchsia',
    base: Color(0xFFD946EF),
    bright: Color(0xFFE879F9),
    deep: Color(0xFFC026D3),
  );

  static const AccentPreset ruby = AccentPreset(
    id: 'ruby',
    name: 'Ruby',
    base: Color(0xFFE11D48),
    bright: Color(0xFFFB7185),
    deep: Color(0xFFBE123C),
  );

  static const AccentPreset platinum = AccentPreset(
    id: 'platinum',
    name: 'Platinum',
    base: Color(0xFFCBD5E1),
    bright: Color(0xFFF1F5F9),
    deep: Color(0xFF94A3B8),
  );

  static const AccentPreset emerald = AccentPreset(
    id: 'emerald',
    name: 'Emerald',
    base: Color(0xFF10B981),
    bright: Color(0xFF34D399),
    deep: Color(0xFF059669),
  );

  static const List<AccentPreset> all = [
    amber,
    gold,
    copper,
    electricBlue,
    cyan,
    violet,
    fuchsia,
    ruby,
    platinum,
    emerald,
  ];

  static const List<AccentPreset> values = all;

  static AccentPreset findById(String id) {
    return all.firstWhere(
      (p) => p.id.toLowerCase() == id.toLowerCase(),
      orElse: () => amber,
    );
  }
}

/// Active accent palette encapsulating active tones and current mode.
class V35AccentPalette {
  final String id;
  final String name;
  final AccentMode mode;
  final Color base;
  final Color bright;
  final Color deep;

  const V35AccentPalette({
    required this.id,
    required this.name,
    required this.mode,
    required this.base,
    required this.bright,
    required this.deep,
  });

  factory V35AccentPalette.fromPreset(AccentPreset preset) {
    return V35AccentPalette(
      id: preset.id,
      name: preset.name,
      mode: AccentMode.preset,
      base: preset.base,
      bright: preset.bright,
      deep: preset.deep,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is V35AccentPalette &&
        other.id == id &&
        other.mode == mode &&
        other.base == base &&
        other.bright == bright &&
        other.deep == deep;
  }

  @override
  int get hashCode => Object.hash(id, mode, base, bright, deep);
}

/// Central controller for the V3.5 Adaptive Accent Color System.
///
/// Features:
/// - Default fresh install: Amber (#F59E0B)
/// - Zero-dependency reactive ValueNotifier
/// - Stable HSL brightness and depth derivations
/// - Caching for Dynamic Artwork through ArtworkColorService
/// - Persistent settings via SharedPreferences
abstract final class V35Accent {
  static const String _prefMode = 'v35_accent_mode';
  static const String _prefPresetId = 'v35_accent_preset_id';
  static const String _prefCustomColor = 'v35_accent_custom_color';

  static final V35AccentPalette defaultAmber = V35AccentPalette.fromPreset(
    AccentPreset.amber,
  );

  /// Reactive notifier for UI reactivity.
  static final ValueNotifier<V35AccentPalette> notifier =
      ValueNotifier<V35AccentPalette>(defaultAmber);

  /// Active state accessors.
  static V35AccentPalette get current => notifier.value;
  static Color get base => notifier.value.base;
  static Color get bright => notifier.value.bright;
  static Color get deep => notifier.value.deep;
  static AccentMode get mode => notifier.value.mode;
  static Color get customColor => _customColor;
  static String get presetId => _presetId;
  static AccentPreset get preset => AccentPreset.findById(_presetId);

  // Cached state for dynamic artwork
  static String? _lastExtractedPath;
  static V35AccentPalette? _cachedArtworkPalette;
  static Color _customColor = const Color(0xFFF59E0B);
  static String _presetId = 'amber';

  /// Changes the operational mode.
  static Future<void> setMode(AccentMode newMode) async {
    switch (newMode) {
      case AccentMode.preset:
        await setPreset(AccentPreset.findById(_presetId));
        break;
      case AccentMode.custom:
        await setCustomColor(_customColor);
        break;
      case AccentMode.dynamicArtwork:
        await setDynamicArtworkMode();
        break;
    }
  }

  /// Initializes accent system from SharedPreferences.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_prefMode) ?? 'preset';
      _presetId = prefs.getString(_prefPresetId) ?? 'amber';
      final customInt = prefs.getInt(_prefCustomColor);
      if (customInt != null) {
        _customColor = Color(customInt);
      }

      switch (modeStr) {
        case 'custom':
          notifier.value = deriveCustom(_customColor);
          break;
        case 'dynamic':
          // Start with fallback Amber or last cached until a song is loaded
          notifier.value = V35AccentPalette(
            id: 'dynamic',
            name: 'Dynamic Artwork',
            mode: AccentMode.dynamicArtwork,
            base: defaultAmber.base,
            bright: defaultAmber.bright,
            deep: defaultAmber.deep,
          );
          break;
        case 'preset':
        default:
          final preset = AccentPreset.findById(_presetId);
          notifier.value = V35AccentPalette.fromPreset(preset);
          break;
      }
    } catch (e) {
      debugPrint('V35Accent.init error: $e, falling back to Amber default.');
      notifier.value = defaultAmber;
    }
  }

  /// Sets an active preset.
  static Future<void> setPreset(AccentPreset preset) async {
    _presetId = preset.id;
    final palette = V35AccentPalette.fromPreset(preset);
    notifier.value = palette;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefMode, 'preset');
      await prefs.setString(_prefPresetId, preset.id);
    } catch (e) {
      debugPrint('V35Accent.setPreset save error: $e');
    }
  }

  /// Derives bright and deep tones from a single custom base color.
  static V35AccentPalette deriveCustom(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    final bright = hsl
        .withLightness((hsl.lightness + 0.14).clamp(0.0, 0.95))
        .toColor();
    final deep = hsl
        .withLightness((hsl.lightness - 0.14).clamp(0.05, 1.0))
        .toColor();

    return V35AccentPalette(
      id: 'custom',
      name: 'Custom',
      mode: AccentMode.custom,
      base: baseColor,
      bright: bright,
      deep: deep,
    );
  }

  /// Sets a custom color and persists it.
  static Future<void> setCustomColor(Color color) async {
    _customColor = color;
    final palette = deriveCustom(color);
    notifier.value = palette;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefMode, 'custom');
      await prefs.setInt(_prefCustomColor, color.toARGB32());
    } catch (e) {
      debugPrint('V35Accent.setCustomColor save error: $e');
    }
  }

  /// Activates Dynamic Artwork mode.
  static Future<void> setDynamicArtworkMode({SongModel? currentSong}) async {
    final palette = V35AccentPalette(
      id: 'dynamic',
      name: 'Dynamic Artwork',
      mode: AccentMode.dynamicArtwork,
      base: _cachedArtworkPalette?.base ?? defaultAmber.base,
      bright: _cachedArtworkPalette?.bright ?? defaultAmber.bright,
      deep: _cachedArtworkPalette?.deep ?? defaultAmber.deep,
    );
    notifier.value = palette;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefMode, 'dynamic');
    } catch (e) {
      debugPrint('V35Accent.setDynamicArtworkMode save error: $e');
    }

    if (currentSong != null) {
      await updateFromArtwork(currentSong.cover ?? currentSong.audioPath);
    }
  }

  /// Reacts when song changes in dynamic mode without excessive recomputation.
  static void onSongChanged(SongModel? song) {
    if (notifier.value.mode != AccentMode.dynamicArtwork) return;
    updateFromArtwork(song?.cover ?? song?.audioPath);
  }

  /// Extracts accent from song artwork and applies accessible tonal boundaries.
  static Future<void> updateFromArtwork(String? imagePath) async {
    if (notifier.value.mode != AccentMode.dynamicArtwork) return;

    if (imagePath == null || imagePath.trim().isEmpty) {
      _applyFallbackArtwork();
      return;
    }

    final key = imagePath.trim();
    if (key == _lastExtractedPath && _cachedArtworkPalette != null) {
      notifier.value = _cachedArtworkPalette!;
      return;
    }

    _lastExtractedPath = key;

    try {
      final palette = await ArtworkColorService.instance.extractPalette(key);
      final raw = palette.accentColor;

      // Accessibility contrast check
      var hsl = HSLColor.fromColor(raw);
      if (hsl.lightness < 0.40) {
        hsl = hsl.withLightness(0.55);
      } else if (hsl.lightness > 0.82) {
        hsl = hsl.withLightness(0.70);
      }
      if (hsl.saturation < 0.35) {
        hsl = hsl.withSaturation(0.60);
      }

      final baseColor = hsl.toColor();
      final brightColor = hsl
          .withLightness((hsl.lightness + 0.14).clamp(0.0, 0.95))
          .toColor();
      final deepColor = hsl
          .withLightness((hsl.lightness - 0.14).clamp(0.05, 1.0))
          .toColor();

      _cachedArtworkPalette = V35AccentPalette(
        id: 'dynamic',
        name: 'Dynamic Artwork',
        mode: AccentMode.dynamicArtwork,
        base: baseColor,
        bright: brightColor,
        deep: deepColor,
      );

      notifier.value = _cachedArtworkPalette!;
    } catch (e) {
      debugPrint(
        'V35Accent.updateFromArtwork error: $e, using Amber fallback.',
      );
      _applyFallbackArtwork();
    }
  }

  static void _applyFallbackArtwork() {
    _cachedArtworkPalette = V35AccentPalette(
      id: 'dynamic',
      name: 'Dynamic Artwork',
      mode: AccentMode.dynamicArtwork,
      base: defaultAmber.base,
      bright: defaultAmber.bright,
      deep: defaultAmber.deep,
    );
    notifier.value = _cachedArtworkPalette!;
  }
}
