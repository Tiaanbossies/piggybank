/// Piggybank's visual identity, per DESIGN.md — rewritten 2026-08-16 to match
/// 9 delivered UI mockups (mostly white/black, one green accent), superseding
/// the original warm-cream/terracotta written-spec version. See DESIGN.md's
/// "Revision — 2026-08-16" header for what changed and why.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mostly white/black + one green accent, per DESIGN.md § Colour. Dark values
/// are inferred (no dark mockup was delivered) — see DESIGN.md's revision note.
abstract final class AppColors {
  // Light
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF111812);
  static const lightTextMuted = Color(0xFF6B7280);
  static const lightBorder = Color(0xFFEDEFEA);
  static const lightAccent = Color(0xFF1F8A4C);
  static const lightAccentChipBg = Color(0xFFE4F5EA);
  static const lightSuccess = Color(0xFF1F8A4C);
  static const lightDanger = Color(0xFFD64545);
  static const lightDangerChipBg = Color(0xFFFCE8E8);
  static const heroGradientStart = Color(0xFF6FBE8C);
  static const heroGradientEnd = Color(0xFF227A4E);

  // Dark (inferred, unconfirmed — see DESIGN.md revision note)
  static const darkBackground = Color(0xFF0F1412);
  static const darkSurface = Color(0xFF181F1B);
  static const darkTextPrimary = Color(0xFFF2F5F1);
  static const darkTextMuted = Color(0xFF9AA69E);
  static const darkBorder = Color(0xFF28322C);
  static const darkAccent = Color(0xFF3FC876);
  static const darkAccentChipBg = Color(0xFF17301F);
  static const darkSuccess = Color(0xFF3FC876);
  static const darkDanger = Color(0xFFE8685F);
  static const darkDangerChipBg = Color(0xFF3A1F1F);
}

/// Money/percentage figures render in the same UI sans as everything else now
/// (DESIGN.md § Typography) — the mockups don't use a distinct mono face.
/// Tabular figures are kept for column alignment; the typeface is not.
TextStyle moneyTextStyle(BuildContext context, {double? fontSize, FontWeight? fontWeight, Color? color}) {
  return GoogleFonts.manrope(
    fontSize: fontSize,
    fontWeight: fontWeight ?? FontWeight.w700,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final accentChipBg = isDark ? AppColors.darkAccentChipBg : AppColors.lightAccentChipBg;
    final dangerChipBg = isDark ? AppColors.darkDangerChipBg : AppColors.lightDangerChipBg;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      error: isDark ? AppColors.darkDanger : AppColors.lightDanger,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      outline: border,
    );

    // DESIGN.md § Typography specifies a 28/22/17/15/13sp scale for
    // display/title/body-large/body/caption. Material's default titleLarge
    // (22) already matches "title" exactly, so it's left alone. displaySmall
    // is the one role that visibly diverges (Material default: 36) and has
    // exactly one call site (login_screen.dart's title) — corrected here so
    // the doc and the code are provably the same value. The remaining tiers
    // (body-large/body/caption) map onto ~90 call sites across the app using
    // Material's broader default role set (titleMedium/bodyMedium/bodySmall/
    // etc.) for purposes DESIGN.md's 5-tier scale doesn't individually cover
    // (card titles, footnotes, subtitles) — left as Material defaults rather
    // than reassigned blind, since a change that broad can't be visually
    // verified without a mockup-matched device pass.
    final baseText = GoogleFonts.manropeTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    final textTheme = baseText.copyWith(displaySmall: baseText.displaySmall?.copyWith(fontSize: 28));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1),
      extensions: [
        AppSemanticColors(
          success: isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
          danger: isDark ? AppColors.darkDanger : AppColors.lightDanger,
          textMuted: textMuted,
          accentChipBg: accentChipBg,
          dangerChipBg: dangerChipBg,
        ),
      ],
    );
  }
}

/// Success/danger/muted/chip-background tokens that don't map onto Material's
/// ColorScheme roles. `accentChipBg`/`dangerChipBg` back the icon-chip and
/// percentage-pill components (DESIGN.md § Signature components).
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.danger,
    required this.textMuted,
    required this.accentChipBg,
    required this.dangerChipBg,
  });

  final Color success;
  final Color danger;
  final Color textMuted;
  final Color accentChipBg;
  final Color dangerChipBg;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? danger,
    Color? textMuted,
    Color? accentChipBg,
    Color? dangerChipBg,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      danger: danger ?? this.danger,
      textMuted: textMuted ?? this.textMuted,
      accentChipBg: accentChipBg ?? this.accentChipBg,
      dangerChipBg: dangerChipBg ?? this.dangerChipBg,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentChipBg: Color.lerp(accentChipBg, other.accentChipBg, t)!,
      dangerChipBg: Color.lerp(dangerChipBg, other.dangerChipBg, t)!,
    );
  }
}
