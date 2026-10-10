/// "Ledger Pocket" design tokens: colour, space, radius and depth, per
/// `docs/visual-rework/04-visual-spec.md` §1. Widgets read colours from here
/// (or from the [ColorScheme] built on them), never raw hex.
library;

import 'package:flutter/material.dart';

/// Category families for row tiles and chart series (spec §1.3). Identity is
/// carried by the icon and label too, never by colour alone.
enum CategoryFamily { forest, ochre, clay, sage, neutral }

/// Every colour role in spec §1.1 (light) and §1.2 (dark).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.sunk,
    required this.ink,
    required this.muted,
    required this.outline,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.positive,
    required this.danger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.hero,
    required this.heroInk,
    required this.heroSecondary,
    required this.heroBar,
    required this.heroTrack,
    required this.tiles,
    required this.tileIcons,
    required this.chartSeries,
  });

  final Color bg;
  final Color surface;

  /// Sheets, menus and the FAB container in dark mode, where depth is tonal
  /// instead of a shadow. Equals [surface] in light mode.
  final Color surfaceRaised;
  final Color sunk;
  final Color ink;
  final Color muted;

  /// Lines and UI boundaries only, never text.
  final Color outline;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color positive;

  /// Over budget, delete and log out only.
  final Color danger;
  final Color dangerContainer;
  final Color onDangerContainer;
  final Color hero;
  final Color heroInk;
  final Color heroSecondary;
  final Color heroBar;
  final Color heroTrack;

  /// Tile fill and icon colour per [CategoryFamily], in enum order.
  final List<Color> tiles;
  final List<Color> tileIcons;

  /// Chart series in order: forest, ochre, clay, sage.
  final List<Color> chartSeries;

  Color categoryTile(CategoryFamily f) => tiles[f.index];
  Color categoryIcon(CategoryFamily f) => tileIcons[f.index];

  static const light = AppTokens(
    bg: Color(0xFFF7F4EC),
    surface: Color(0xFFFFFDF8),
    surfaceRaised: Color(0xFFFFFDF8),
    sunk: Color(0xFFEFEADF),
    ink: Color(0xFF1A1F1A),
    muted: Color(0xFF595E54),
    outline: Color(0xFF8C8A7C),
    primary: Color(0xFF1E5B3E),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCEBDD),
    onPrimaryContainer: Color(0xFF123A27),
    positive: Color(0xFF1E6B44),
    danger: Color(0xFFA8322D),
    dangerContainer: Color(0xFFF6E1DC),
    onDangerContainer: Color(0xFF7A1F1B),
    hero: Color(0xFFDCEBDD),
    heroInk: Color(0xFF123A27),
    heroSecondary: Color(0xFF3D6150),
    heroBar: Color(0xFF1E5B3E),
    heroTrack: Color(0xFFC4DCC8),
    tiles: [Color(0xFFDCEBDD), Color(0xFFF3E6CC), Color(0xFFF2DED3), Color(0xFFE2ECE5), Color(0xFFEFEADF)],
    tileIcons: [Color(0xFF1E5B3E), Color(0xFF8A5E14), Color(0xFF8A4A2E), Color(0xFF3F6B4E), Color(0xFF595E54)],
    chartSeries: [Color(0xFF1E5B3E), Color(0xFFB9822E), Color(0xFF9A5B3F), Color(0xFF6E9579)],
  );

  static const dark = AppTokens(
    bg: Color(0xFF121512),
    surface: Color(0xFF1A1E1A),
    surfaceRaised: Color(0xFF222722),
    sunk: Color(0xFF0E110E),
    ink: Color(0xFFECEAE2),
    muted: Color(0xFFA7ACA2),
    outline: Color(0xFF6E7469),
    primary: Color(0xFF8FCBA4),
    onPrimary: Color(0xFF0E2A1C),
    primaryContainer: Color(0xFF24402F),
    onPrimaryContainer: Color(0xFFC6E6CF),
    positive: Color(0xFF8FCBA4),
    danger: Color(0xFFF2A49B),
    dangerContainer: Color(0xFF4A2421),
    onDangerContainer: Color(0xFFF8D5CF),
    hero: Color(0xFF1F3A2A),
    heroInk: Color(0xFFECEAE2),
    heroSecondary: Color(0xFFA9C9B4),
    heroBar: Color(0xFF8FCBA4),
    heroTrack: Color(0xFF2C4A38),
    tiles: [Color(0xFF24402F), Color(0xFF3D3220), Color(0xFF3E2A22), Color(0xFF26332B), Color(0xFF262A26)],
    tileIcons: [Color(0xFF8FCBA4), Color(0xFFE3B866), Color(0xFFE0A283), Color(0xFFA9C9B4), Color(0xFFA7ACA2)],
    chartSeries: [Color(0xFF8FCBA4), Color(0xFFE3B866), Color(0xFFE0A283), Color(0xFFA9C9B4)],
  );

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? sunk,
    Color? ink,
    Color? muted,
    Color? outline,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? positive,
    Color? danger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? hero,
    Color? heroInk,
    Color? heroSecondary,
    Color? heroBar,
    Color? heroTrack,
    List<Color>? tiles,
    List<Color>? tileIcons,
    List<Color>? chartSeries,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      sunk: sunk ?? this.sunk,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      outline: outline ?? this.outline,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      positive: positive ?? this.positive,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      hero: hero ?? this.hero,
      heroInk: heroInk ?? this.heroInk,
      heroSecondary: heroSecondary ?? this.heroSecondary,
      heroBar: heroBar ?? this.heroBar,
      heroTrack: heroTrack ?? this.heroTrack,
      tiles: tiles ?? this.tiles,
      tileIcons: tileIcons ?? this.tileIcons,
      chartSeries: chartSeries ?? this.chartSeries,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> l(List<Color> a, List<Color> b) => [for (var i = 0; i < a.length; i++) c(a[i], b[i])];
    return AppTokens(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      sunk: c(sunk, other.sunk),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      outline: c(outline, other.outline),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryContainer: c(primaryContainer, other.primaryContainer),
      onPrimaryContainer: c(onPrimaryContainer, other.onPrimaryContainer),
      positive: c(positive, other.positive),
      danger: c(danger, other.danger),
      dangerContainer: c(dangerContainer, other.dangerContainer),
      onDangerContainer: c(onDangerContainer, other.onDangerContainer),
      hero: c(hero, other.hero),
      heroInk: c(heroInk, other.heroInk),
      heroSecondary: c(heroSecondary, other.heroSecondary),
      heroBar: c(heroBar, other.heroBar),
      heroTrack: c(heroTrack, other.heroTrack),
      tiles: l(tiles, other.tiles),
      tileIcons: l(tileIcons, other.tileIcons),
      chartSeries: l(chartSeries, other.chartSeries),
    );
  }
}

extension AppTokensContext on BuildContext {
  /// The current theme's [AppTokens]. Every [ThemeData] built by `AppTheme`
  /// carries one; outside it (a bare test harness) this falls back to light.
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}

/// The 4 pt spacing scale (spec §1.6).
abstract final class AppSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;

  static const double gutter = 16;
  static const double cardPad = 20;
  static const double rowGap = 12;

  /// Always larger than any gap inside a section (S5).
  static const double sectionGap = 24;

  /// Bottom padding for every scrollable under a FAB (S11).
  static const double fabInset = 88;
}

/// Corner radii (spec §1.6). Inputs, chips, buttons, the FAB and banners are
/// full pills: use [StadiumBorder].
abstract final class AppRadius {
  static const double card = 24;
  static const double sheet = 28;
  static const double tile = 14;

  static const cardAll = BorderRadius.all(Radius.circular(card));
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
  static const tileAll = BorderRadius.all(Radius.circular(tile));
}

/// Forest-tinted shadows in light mode; none in dark, where depth is tonal
/// (spec §1.6).
abstract final class AppShadows {
  static const _forest = Color(0xFF1E5B3E);

  /// Cards and the hero.
  static List<BoxShadow> level1(Brightness b) => b == Brightness.dark
      ? const []
      : [BoxShadow(color: _forest.withValues(alpha: 0.08), offset: const Offset(0, 4), blurRadius: 16)];

  /// The FAB, sheets and menus.
  static List<BoxShadow> level2(Brightness b) => b == Brightness.dark
      ? const []
      : [BoxShadow(color: _forest.withValues(alpha: 0.12), offset: const Offset(0, 8), blurRadius: 24)];
}
