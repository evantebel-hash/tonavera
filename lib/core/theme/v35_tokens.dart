import 'package:flutter/material.dart';
import 'v35_accent.dart';

/// Design tokens for MyMusic V3.5 Obsidian design system.
///
/// Principles:
/// - Base Canvas: Deep Obsidian (#0B0D0E - #171B1E)
/// - Adaptive Accents: Configurable palette (Amber, Gold, Electric Blue, Emerald, Custom, Dynamic Artwork)
/// - High scannability and contrast with slate white typography (#F8FAFC)
/// - 8-point spacing system
abstract final class V35Tokens {
  // ===========================================================================
  // 1. BACKGROUND & SURFACE COLORS (OBSIDIAN PALETTE)
  // ===========================================================================
  static const Color bgVoid = Color(
    0xFF0B0D0E,
  ); // Deep canvas / Root background
  static const Color bgBase = Color(0xFF111416); // App content background
  static const Color bgSurface = Color(
    0xFF171B1E,
  ); // Cards, sidebar, modal surfaces
  static const Color bgElevated = Color(
    0xFF1E2328,
  ); // Hovered items, dialogs, floating items
  static const Color bgHighlight = Color(
    0xFF262B30,
  ); // Active borders, pill highlight

  // ===========================================================================
  // 2. ADAPTIVE ACCENT COLORS (V3.5 ACTIVE ACCENT)
  // ===========================================================================
  /// Active accent base tone (Default: Amber #F59E0B)
  static Color get accent => V35Accent.base;

  /// Active accent bright tone (Default: Amber #FBBF24)
  static Color get accentBright => V35Accent.bright;

  /// Active accent deep tone (Default: Amber #D97706)
  static Color get accentDeep => V35Accent.deep;

  // Preset Emerald Constants (Phase 1 legacy palette & preset definition):
  static const Color emeraldPrimary = Color(0xFF10B981);
  static const Color emeraldGlow = Color(0xFF34D399);
  static const Color emeraldAccent = Color(0xFF4EDEA3);
  static const Color emeraldDark = Color(0xFF059669);

  // ===========================================================================
  // 2B. SEMANTIC COLORS (CONSTANT & PRESERVED)
  // ===========================================================================
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color youtubeRed = Color(0xFFFF0000);
  static const Color spotifyGreen = Color(0xFF1DB954);

  // ===========================================================================
  // 3. TEXT & CONTENT HIERARCHY
  // ===========================================================================
  static const Color textPrimary = Color(
    0xFFF8FAFC,
  ); // High emphasis, song titles, headings
  static const Color textSecondary = Color(
    0xFF94A3B8,
  ); // Medium emphasis, artist names, body
  static const Color textMuted = Color(
    0xFF64748B,
  ); // Low emphasis, timestamps, captions
  static const Color textDisabled = Color(
    0xFF475569,
  ); // Inactive / disabled states

  // ===========================================================================
  // 4. BORDERS & DIVIDERS
  // ===========================================================================
  static const Color borderSubtle = Color(
    0xFF1E2328,
  ); // Subtle dividers, card borders
  static const Color borderCard = Color(
    0xFF262B30,
  ); // Prominent containers, focused borders

  // ===========================================================================
  // 5. SPACING (8-POINT SYSTEM)
  // ===========================================================================
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // Insets helpers
  static const EdgeInsets insetsH8 = EdgeInsets.symmetric(horizontal: space8);
  static const EdgeInsets insetsH16 = EdgeInsets.symmetric(horizontal: space16);
  static const EdgeInsets insetsH24 = EdgeInsets.symmetric(horizontal: space24);
  static const EdgeInsets insetsV8 = EdgeInsets.symmetric(vertical: space8);
  static const EdgeInsets insetsV12 = EdgeInsets.symmetric(vertical: space12);
  static const EdgeInsets insetsV16 = EdgeInsets.symmetric(vertical: space16);
  static const EdgeInsets insetsAll8 = EdgeInsets.all(space8);
  static const EdgeInsets insetsAll12 = EdgeInsets.all(space12);
  static const EdgeInsets insetsAll16 = EdgeInsets.all(space16);
  static const EdgeInsets insetsAll24 = EdgeInsets.all(space24);

  // ===========================================================================
  // 6. CORNER RADII
  // ===========================================================================
  static const double radiusSm = 6.0; // Badges, small pills, tags
  static const double radiusMd = 10.0; // Input fields, buttons, track row hover
  static const double radiusLg = 14.0; // Cards, sheets
  static const double radiusXl = 16.0; // Dialogs, elevated panels
  static const double radiusFull = 999.0; // Play buttons, pill filters, avatars

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius brFull = BorderRadius.all(
    Radius.circular(radiusFull),
  );

  // ===========================================================================
  // 7. COMPONENT SIZES & METRICS
  // ===========================================================================
  static const double trackRowHeight = 56.0;
  static const double desktopPlaybarHeight = 84.0;
  static const double mobileMiniPlayerHeight = 64.0;
  static const double desktopSidebarWidth = 240.0;
  static const double desktopQueuePanelWidth = 320.0;
  static const double desktopBreakPoint = 1200.0;
  static const double tabletBreakPoint = 800.0;

  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  static const double artworkSm = 40.0;
  static const double artworkMd = 48.0;
  static const double artworkLg = 56.0;
  static const double artworkCard = 140.0;

  // ===========================================================================
  // 8. TYPOGRAPHY HIERARCHY (SAFE FALLBACK TYPOGRAPHY)
  // ===========================================================================
  static const TextStyle display = TextStyle(
    fontSize: 30.0,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.6,
    height: 1.2,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    letterSpacing: 0.0,
    height: 1.4,
  );

  static const TextStyle secondary = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0.0,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 0.2,
    height: 1.3,
  );

  static const TextStyle mono = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    color: textMuted,
    letterSpacing: 0.0,
    fontFamily: 'monospace',
    height: 1.2,
  );
}
