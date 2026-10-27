import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mymusic/core/theme/v35_accent.dart';
import 'package:mymusic/core/theme/v35_tokens.dart';
import 'package:mymusic/core/theme/v35_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await V35Accent.init();
  });

  group('Adaptive Accent Color System', () {
    test('Fresh install default accent is Amber', () {
      expect(V35Accent.mode, equals(AccentMode.preset));
      expect(V35Accent.preset, equals(AccentPreset.amber));
      expect(V35Accent.current.base, equals(const Color(0xFFF59E0B)));
      expect(V35Accent.current.bright, equals(const Color(0xFFFBBF24)));
      expect(V35Accent.current.deep, equals(const Color(0xFFD97706)));

      // V35Tokens reflects active accent
      expect(V35Tokens.accent, equals(const Color(0xFFF59E0B)));
      expect(V35Tokens.accentBright, equals(const Color(0xFFFBBF24)));
      expect(V35Tokens.accentDeep, equals(const Color(0xFFD97706)));
    });

    test('All 10 built-in presets are available with correct color values', () {
      expect(AccentPreset.values.length, equals(10));

      final amber = AccentPreset.amber;
      expect(amber.base, equals(const Color(0xFFF59E0B)));
      expect(amber.bright, equals(const Color(0xFFFBBF24)));
      expect(amber.deep, equals(const Color(0xFFD97706)));

      final gold = AccentPreset.gold;
      expect(gold.base, equals(const Color(0xFFD4AF37)));
      expect(gold.bright, equals(const Color(0xFFF4D35E)));
      expect(gold.deep, equals(const Color(0xFFA88918)));

      final copper = AccentPreset.copper;
      expect(copper.base, equals(const Color(0xFFC2410C)));
      expect(copper.bright, equals(const Color(0xFFEA580C)));
      expect(copper.deep, equals(const Color(0xFF9A3412)));

      final electricBlue = AccentPreset.electricBlue;
      expect(electricBlue.base, equals(const Color(0xFF3B82F6)));
      expect(electricBlue.bright, equals(const Color(0xFF60A5FA)));
      expect(electricBlue.deep, equals(const Color(0xFF2563EB)));

      final cyan = AccentPreset.cyan;
      expect(cyan.base, equals(const Color(0xFF06B6D4)));
      expect(cyan.bright, equals(const Color(0xFF22D3EE)));
      expect(cyan.deep, equals(const Color(0xFF0891B2)));

      final violet = AccentPreset.violet;
      expect(violet.base, equals(const Color(0xFF8B5CF6)));
      expect(violet.bright, equals(const Color(0xFFA78BFA)));
      expect(violet.deep, equals(const Color(0xFF7C3AED)));

      final fuchsia = AccentPreset.fuchsia;
      expect(fuchsia.base, equals(const Color(0xFFD946EF)));
      expect(fuchsia.bright, equals(const Color(0xFFE879F9)));
      expect(fuchsia.deep, equals(const Color(0xFFC026D3)));

      final ruby = AccentPreset.ruby;
      expect(ruby.base, equals(const Color(0xFFE11D48)));
      expect(ruby.bright, equals(const Color(0xFFFB7185)));
      expect(ruby.deep, equals(const Color(0xFFBE123C)));

      final platinum = AccentPreset.platinum;
      expect(platinum.base, equals(const Color(0xFFCBD5E1)));
      expect(platinum.bright, equals(const Color(0xFFF1F5F9)));
      expect(platinum.deep, equals(const Color(0xFF94A3B8)));

      final emerald = AccentPreset.emerald;
      expect(emerald.base, equals(const Color(0xFF10B981)));
      expect(emerald.bright, equals(const Color(0xFF34D399)));
      expect(emerald.deep, equals(const Color(0xFF059669)));
    });

    test('Selecting preset propagates to V35Accent and V35Tokens and persists', () async {
      await V35Accent.setPreset(AccentPreset.electricBlue);

      expect(V35Accent.mode, equals(AccentMode.preset));
      expect(V35Accent.preset, equals(AccentPreset.electricBlue));
      expect(V35Accent.current.base, equals(const Color(0xFF3B82F6)));
      expect(V35Tokens.accent, equals(const Color(0xFF3B82F6)));

      // Simulate app restart by re-initializing
      await V35Accent.init();
      expect(V35Accent.mode, equals(AccentMode.preset));
      expect(V35Accent.preset, equals(AccentPreset.electricBlue));
      expect(V35Tokens.accent, equals(const Color(0xFF3B82F6)));
    });

    test('Custom accent color generates base, bright, deep and persists', () async {
      const customColor = Color(0xFF9C27B0); // Purple
      await V35Accent.setCustomColor(customColor);

      expect(V35Accent.mode, equals(AccentMode.custom));
      expect(V35Accent.customColor, equals(customColor));
      expect(V35Accent.current.base, equals(customColor));

      // Bright and deep are generated and different from base
      expect(V35Accent.current.bright, isNot(equals(customColor)));
      expect(V35Accent.current.deep, isNot(equals(customColor)));

      // Ensure tokens reflect custom color
      expect(V35Tokens.accent, equals(customColor));

      // Test persistence across re-init
      await V35Accent.init();
      expect(V35Accent.mode, equals(AccentMode.custom));
      expect(V35Accent.customColor, equals(customColor));
      expect(V35Tokens.accent, equals(customColor));
    });

    test('Dynamic artwork mode activates and falls back to Amber when artwork is absent', () async {
      await V35Accent.setMode(AccentMode.dynamicArtwork);
      expect(V35Accent.mode, equals(AccentMode.dynamicArtwork));

      // Artwork null fallback
      await V35Accent.updateFromArtwork(null);
      expect(V35Accent.current.base, equals(AccentPreset.amber.base));
      expect(V35Tokens.accent, equals(AccentPreset.amber.base));

      // Artwork empty string fallback
      await V35Accent.updateFromArtwork('');
      expect(V35Accent.current.base, equals(AccentPreset.amber.base));
      expect(V35Tokens.accent, equals(AccentPreset.amber.base));
    });

    test('Semantic colors are preserved and untouched by accent changes', () async {
      await V35Accent.setPreset(AccentPreset.ruby);

      // Accent is ruby
      expect(V35Tokens.accent, equals(AccentPreset.ruby.base));

      // Semantic tokens remain constant
      expect(V35Tokens.error, equals(const Color(0xFFEF4444)));
      expect(V35Tokens.warning, equals(const Color(0xFFF59E0B)));
      expect(V35Tokens.success, equals(const Color(0xFF10B981)));
      expect(V35Tokens.youtubeRed, equals(const Color(0xFFFF0000)));
      expect(V35Tokens.spotifyGreen, equals(const Color(0xFF1DB954)));
      expect(V35Tokens.emeraldPrimary, equals(const Color(0xFF10B981)));
    });

    test('Accent change notifies ValueNotifier listeners synchronously', () async {
      int notifications = 0;
      V35AccentPalette? lastPalette;
      void listener() {
        notifications++;
        lastPalette = V35Accent.notifier.value;
      }

      V35Accent.notifier.addListener(listener);

      await V35Accent.setPreset(AccentPreset.cyan);
      expect(notifications, equals(1));
      expect(lastPalette?.base, equals(AccentPreset.cyan.base));

      await V35Accent.setPreset(AccentPreset.violet);
      expect(notifications, equals(2));
      expect(lastPalette?.base, equals(AccentPreset.violet.base));

      V35Accent.notifier.removeListener(listener);
    });

    test('ColorScheme.primary and V35Theme react dynamically to accent changes', () async {
      await V35Accent.setPreset(AccentPreset.cyan);
      final themeCyan = V35Theme.darkTheme;
      expect(themeCyan.colorScheme.primary, equals(AccentPreset.cyan.base));

      await V35Accent.setPreset(AccentPreset.ruby);
      final themeRuby = V35Theme.darkTheme;
      expect(themeRuby.colorScheme.primary, equals(AccentPreset.ruby.base));
    });

    testWidgets('Reactive widgets update accent color on notifier change without app restart', (tester) async {
      await V35Accent.setPreset(AccentPreset.amber);

      await tester.pumpWidget(
        ValueListenableBuilder<V35AccentPalette>(
          valueListenable: V35Accent.notifier,
          builder: (context, palette, _) {
            return MaterialApp(
              theme: V35Theme.darkTheme,
              home: Scaffold(
                body: Container(
                  key: const Key('accent_test_box'),
                  color: V35Tokens.accent,
                ),
              ),
            );
          },
        ),
      );

      // Initially amber
      Container box = tester.widget<Container>(find.byKey(const Key('accent_test_box')));
      expect(box.color, equals(AccentPreset.amber.base));

      // Switch to Cyan
      await V35Accent.setPreset(AccentPreset.cyan);
      await tester.pump();

      box = tester.widget<Container>(find.byKey(const Key('accent_test_box')));
      expect(box.color, equals(AccentPreset.cyan.base));

      // Switch to Violet
      await V35Accent.setPreset(AccentPreset.violet);
      await tester.pump();

      box = tester.widget<Container>(find.byKey(const Key('accent_test_box')));
      expect(box.color, equals(AccentPreset.violet.base));
    });
  });
}
