import 'package:flutter/material.dart';
import 'v35_tokens.dart';

/// V3.5 Obsidian Emerald theme definition for MyMusic.
///
/// Designed to be adopted incrementally without altering global app state prematurely.
abstract final class V35Theme {
  /// Primary ThemeData configured for Obsidian Emerald styling.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: V35Tokens.bgBase,
      canvasColor: V35Tokens.bgVoid,
      primaryColor: V35Tokens.accent,

      // -----------------------------------------------------------------------
      // COLOR SCHEME
      // -----------------------------------------------------------------------
      colorScheme: ColorScheme.dark(
        primary: V35Tokens.accent,
        primaryContainer: V35Tokens.accentDeep,
        secondary: V35Tokens.accentBright,
        secondaryContainer: V35Tokens.bgElevated,
        surface: V35Tokens.bgSurface,
        error: const Color(0xFFEF4444),
        onPrimary: V35Tokens.bgVoid,
        onSecondary: V35Tokens.bgVoid,
        onSurface: V35Tokens.textPrimary,
        onError: Colors.white,
        outline: V35Tokens.borderSubtle,
        outlineVariant: V35Tokens.borderCard,
      ),

      // -----------------------------------------------------------------------
      // APP BAR
      // -----------------------------------------------------------------------
      appBarTheme: const AppBarTheme(
        backgroundColor: V35Tokens.bgVoid,
        foregroundColor: V35Tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: V35Tokens.heading,
        iconTheme: IconThemeData(
          color: V35Tokens.textPrimary,
          size: V35Tokens.iconLg,
        ),
      ),

      // -----------------------------------------------------------------------
      // CARD
      // -----------------------------------------------------------------------
      cardTheme: CardThemeData(
        color: V35Tokens.bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: V35Tokens.brLg,
          side: const BorderSide(color: V35Tokens.borderSubtle, width: 1.0),
        ),
      ),

      // -----------------------------------------------------------------------
      // DIALOG
      // -----------------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: V35Tokens.bgElevated,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: V35Tokens.brXl,
          side: const BorderSide(color: V35Tokens.borderCard, width: 1.0),
        ),
        titleTextStyle: V35Tokens.heading,
        contentTextStyle: V35Tokens.body,
      ),

      // -----------------------------------------------------------------------
      // BOTTOM SHEET
      // -----------------------------------------------------------------------
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: V35Tokens.bgElevated,
        modalBackgroundColor: V35Tokens.bgElevated,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(V35Tokens.radiusXl),
          ),
        ),
        dragHandleColor: V35Tokens.textMuted,
        dragHandleSize: Size(36, 4),
        showDragHandle: true,
      ),

      // -----------------------------------------------------------------------
      // INPUT DECORATION
      // -----------------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: V35Tokens.bgElevated,
        hintStyle: V35Tokens.secondary.copyWith(color: V35Tokens.textMuted),
        labelStyle: V35Tokens.body.copyWith(color: V35Tokens.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: V35Tokens.space16,
          vertical: V35Tokens.space12,
        ),
        border: OutlineInputBorder(
          borderRadius: V35Tokens.brMd,
          borderSide: const BorderSide(
            color: V35Tokens.borderSubtle,
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: V35Tokens.brMd,
          borderSide: const BorderSide(
            color: V35Tokens.borderSubtle,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: V35Tokens.brMd,
          borderSide: BorderSide(color: V35Tokens.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: V35Tokens.brMd,
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
        ),
      ),

      // -----------------------------------------------------------------------
      // DIVIDER
      // -----------------------------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: V35Tokens.borderSubtle,
        thickness: 1.0,
        space: 1.0,
      ),

      // -----------------------------------------------------------------------
      // ELEVATED BUTTON
      // -----------------------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: V35Tokens.accent,
          foregroundColor: V35Tokens.bgVoid,
          elevation: 0,
          textStyle: V35Tokens.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(
            horizontal: V35Tokens.space20,
            vertical: V35Tokens.space12,
          ),
          shape: RoundedRectangleBorder(borderRadius: V35Tokens.brFull),
        ),
      ),

      // -----------------------------------------------------------------------
      // TEXT BUTTON
      // -----------------------------------------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: V35Tokens.accentBright,
          textStyle: V35Tokens.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(
            horizontal: V35Tokens.space12,
            vertical: V35Tokens.space8,
          ),
          shape: RoundedRectangleBorder(borderRadius: V35Tokens.brMd),
        ),
      ),

      // -----------------------------------------------------------------------
      // ICON BUTTON
      // -----------------------------------------------------------------------
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: V35Tokens.textSecondary,
          hoverColor: V35Tokens.bgElevated,
          highlightColor: V35Tokens.bgHighlight,
          padding: const EdgeInsets.all(V35Tokens.space8),
        ),
      ),

      // -----------------------------------------------------------------------
      // CHIP
      // -----------------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: V35Tokens.bgSurface,
        disabledColor: const Color(0x7F171B1E),
        selectedColor: V35Tokens.accent,
        secondarySelectedColor: V35Tokens.accentDeep,
        padding: const EdgeInsets.symmetric(
          horizontal: V35Tokens.space12,
          vertical: V35Tokens.space4,
        ),
        labelStyle: V35Tokens.body.copyWith(color: V35Tokens.textPrimary),
        secondaryLabelStyle: V35Tokens.body.copyWith(color: V35Tokens.bgVoid),
        brightness: Brightness.dark,
        shape: RoundedRectangleBorder(
          borderRadius: V35Tokens.brFull,
          side: const BorderSide(color: V35Tokens.borderSubtle, width: 1.0),
        ),
        side: const BorderSide(color: V35Tokens.borderSubtle, width: 1.0),
      ),

      // -----------------------------------------------------------------------
      // SLIDER
      // -----------------------------------------------------------------------
      sliderTheme: SliderThemeData(
        trackHeight: 3.0,
        activeTrackColor: V35Tokens.accent,
        inactiveTrackColor: V35Tokens.bgHighlight,
        thumbColor: V35Tokens.textPrimary,
        overlayColor: V35Tokens.accent.withValues(alpha: 0.16),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 6.0,
          pressedElevation: 4.0,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
      ),

      // -----------------------------------------------------------------------
      // TEXT THEME
      // -----------------------------------------------------------------------
      textTheme: const TextTheme(
        displayLarge: V35Tokens.display,
        displayMedium: V35Tokens.heading,
        headlineMedium: V35Tokens.title,
        bodyLarge: V35Tokens.body,
        bodyMedium: V35Tokens.secondary,
        labelSmall: V35Tokens.caption,
      ),
    );
  }
}
