/// Piggybank's visual identity, "Ledger Pocket" (visual rework, 2026-10):
/// Ledger's forest green on warm paper with Pocket's soft, rounded shapes.
/// Every value comes from `docs/visual-rework/04-visual-spec.md` §1 via
/// [AppTokens]; see DESIGN.md's "Revision — 2026-10" note for the history.
library;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// Money and percentage figures: Plus Jakarta Sans with tabular figures, so
/// amounts in a column align digit for digit (spec §1.5).
TextStyle moneyTextStyle(BuildContext context, {double? fontSize, FontWeight? fontWeight, Color? color}) {
  return GoogleFonts.plusJakartaSans(
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
    final t = isDark ? AppTokens.dark : AppTokens.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      primaryContainer: t.primaryContainer,
      onPrimaryContainer: t.onPrimaryContainer,
      secondary: t.primary,
      onSecondary: t.onPrimary,
      secondaryContainer: t.primaryContainer,
      onSecondaryContainer: t.onPrimaryContainer,
      error: t.danger,
      onError: isDark ? t.onPrimary : t.surface,
      errorContainer: t.dangerContainer,
      onErrorContainer: t.onDangerContainer,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.muted,
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surface,
      surfaceContainerHigh: t.surfaceRaised,
      surfaceContainerHighest: t.sunk,
      outline: t.outline,
      outlineVariant: t.outline.withValues(alpha: 0.3),
      inverseSurface: t.ink,
      onInverseSurface: t.bg,
      inversePrimary: t.primaryContainer,
      shadow: const Color(0xFF1E5B3E),
      scrim: t.ink,
    );

    // Spec §1.5: Plus Jakarta Sans for display, headline, title and money;
    // Nunito Sans for body, label and overline.
    final body = GoogleFonts.nunitoSansTextTheme();
    TextStyle? jakarta(TextStyle? s, double size, double height, FontWeight w, {double tracking = 0}) =>
        GoogleFonts.plusJakartaSans(
          textStyle: s,
          fontSize: size,
          height: height / size,
          fontWeight: w,
          letterSpacing: tracking,
        );
    TextStyle? nunito(TextStyle? s, double size, double height, FontWeight w, {double tracking = 0}) =>
        s?.copyWith(fontSize: size, height: height / size, fontWeight: w, letterSpacing: tracking);

    final textTheme = body
        .copyWith(
          displayLarge: jakarta(body.displayLarge, 40, 44, FontWeight.w800, tracking: -0.4),
          displayMedium: jakarta(body.displayMedium, 40, 44, FontWeight.w800, tracking: -0.4),
          displaySmall: jakarta(body.displaySmall, 40, 44, FontWeight.w800, tracking: -0.4),
          headlineLarge: jakarta(body.headlineLarge, 28, 34, FontWeight.w800),
          headlineMedium: jakarta(body.headlineMedium, 28, 34, FontWeight.w800),
          headlineSmall: jakarta(body.headlineSmall, 24, 30, FontWeight.w800),
          titleLarge: jakarta(body.titleLarge, 20, 26, FontWeight.w700),
          titleMedium: jakarta(body.titleMedium, 16, 22, FontWeight.w700),
          titleSmall: jakarta(body.titleSmall, 16, 22, FontWeight.w700),
          bodyLarge: nunito(body.bodyLarge, 16, 24, FontWeight.w400),
          bodyMedium: nunito(body.bodyMedium, 14, 20, FontWeight.w400),
          bodySmall: nunito(body.bodySmall, 14, 20, FontWeight.w400),
          labelLarge: nunito(body.labelLarge, 14, 20, FontWeight.w600),
          labelMedium: nunito(body.labelMedium, 14, 20, FontWeight.w600),
          // The overline role ("LEFT TO SPEND · OCTOBER"): 12/16/700, +6 %.
          labelSmall: nunito(body.labelSmall, 12, 16, FontWeight.w700, tracking: 0.72),
        )
        .apply(bodyColor: t.ink, displayColor: t.ink);

    const pill = StadiumBorder();
    final pillInput = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      textTheme: textTheme,
      extensions: [
        t,
        AppSemanticColors(
          success: t.positive,
          danger: t.danger,
          textMuted: t.muted,
          accentChipBg: t.primaryContainer,
          dangerChipBg: t.dangerContainer,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      // Depth comes from AppCard's tinted shadow (light) or the tonal
      // surface (dark), not Material elevation (spec §1.6).
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.sunk,
        // Material's default is one line, which cut helpers like "Leave
        // empty to use the income Piggybank has reco…" on a phone.
        helperMaxLines: 2,
        errorMaxLines: 2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: pillInput,
        enabledBorder: pillInput,
        focusedBorder: pillInput.copyWith(borderSide: BorderSide(color: t.primary, width: 2)),
        errorBorder: pillInput.copyWith(borderSide: BorderSide(color: t.danger)),
        focusedErrorBorder: pillInput.copyWith(borderSide: BorderSide(color: t.danger, width: 2)),
        labelStyle: TextStyle(color: t.muted),
        floatingLabelStyle: TextStyle(color: t.primary),
        hintStyle: TextStyle(color: t.muted),
        helperStyle: TextStyle(color: t.muted),
        errorStyle: TextStyle(color: t.danger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          shape: pill,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          elevation: 0,
          shape: pill,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.primary,
          side: BorderSide(color: t.outline),
          shape: pill,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: t.primary, shape: pill, textStyle: textTheme.labelLarge),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.primary,
        foregroundColor: t.onPrimary,
        shape: pill,
        elevation: isDark ? 0 : 3,
        highlightElevation: isDark ? 0 : 4,
        extendedTextStyle: textTheme.labelLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: t.primaryContainer,
        indicatorShape: pill,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? t.onPrimaryContainer : t.muted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => textTheme.labelMedium!.copyWith(
            fontSize: 12,
            color: s.contains(WidgetState.selected) ? t.ink : t.muted,
          ),
        ),
      ),
      // M7: radius 28 top, 4 × 32 handle, scrim ink @ 40 %.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surfaceRaised,
        modalBackgroundColor: t.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
        showDragHandle: true,
        dragHandleColor: t.outline,
        dragHandleSize: const Size(32, 4),
        modalBarrierColor: t.ink.withValues(alpha: 0.4),
      ),
      // M17: radius 24.
      dialogTheme: DialogThemeData(
        backgroundColor: t.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
        barrierColor: t.ink.withValues(alpha: 0.4),
      ),
      // M38: a floating ink pill above the nav.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: t.bg),
        actionTextColor: isDark ? t.primary : t.primaryContainer,
        shape: pill,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      chipTheme: ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: t.outline)),
        backgroundColor: t.surface,
        selectedColor: t.primary,
        checkmarkColor: t.onPrimary,
        labelStyle: textTheme.labelLarge?.copyWith(color: t.ink),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: t.onPrimary),
        side: BorderSide(color: t.outline),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: t.sunk,
          foregroundColor: t.muted,
          selectedBackgroundColor: t.surface,
          selectedForegroundColor: t.ink,
          side: BorderSide.none,
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      // M28: thumb and track colours.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.onPrimary : t.outline),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.primary : t.sunk),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : t.outline,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.primary : null),
        checkColor: WidgetStatePropertyAll(t.onPrimary),
        side: BorderSide(color: t.outline, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.primary : t.outline),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.sunk,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 8,
        borderRadius: BorderRadius.circular(999),
      ),
      // M12: indicator in primary on surface.
      tabBarTheme: TabBarThemeData(labelColor: t.ink, unselectedLabelColor: t.muted, indicatorColor: t.primary),
      listTileTheme: ListTileThemeData(iconColor: t.muted, textColor: t.ink),
      iconTheme: IconThemeData(color: t.ink),
      dividerTheme: DividerThemeData(color: t.outline.withValues(alpha: 0.3), space: 1, thickness: 1),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(999)),
        textStyle: textTheme.labelMedium?.copyWith(color: t.bg, fontSize: 12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _ReducedMotionAwarePageTransitionsBuilder(),
          TargetPlatform.iOS: _ReducedMotionAwarePageTransitionsBuilder(),
          TargetPlatform.linux: _ReducedMotionAwarePageTransitionsBuilder(),
          TargetPlatform.macOS: _ReducedMotionAwarePageTransitionsBuilder(),
          TargetPlatform.windows: _ReducedMotionAwarePageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Upgrades every push/pop route transition (both go_router's default page
/// wrapper and the plain `Navigator.push(MaterialPageRoute(...))` calls used
/// throughout `placeholder_screens.dart`) from the platform-default slide to
/// a shared-axis (horizontal) transition — one theme-level change, no
/// per-route edits needed, since `MaterialPageRoute` reads
/// `Theme.of(context).pageTransitionsTheme`.
///
/// The animation *type* comes from `SharedAxisPageTransitionsBuilder`
/// (`package:animations`); the `animations` package doesn't expose reduced-
/// motion awareness itself, so it's added here, matching how every other
/// animation in this app already checks `context.reducedMotion`.
///
/// Note: the transition *duration* is owned by the underlying route (Flutter
/// hardcodes `MaterialPageRoute.transitionDuration` at 300ms) — a
/// `PageTransitionsBuilder` can change the transition's visual style but not
/// its timing without subclassing `MaterialPageRoute` itself, which is out of
/// scope for a single theme-level change. `AppMotion.pageTransition` (250ms)
/// is used instead for the tab-switch fade in `app_shell.dart`, which this
/// app does fully control.
class _ReducedMotionAwarePageTransitionsBuilder extends PageTransitionsBuilder {
  const _ReducedMotionAwarePageTransitionsBuilder();

  static const _delegate = SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.horizontal);

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context != null && MediaQuery.disableAnimationsOf(context)) return child;
    return _delegate.buildTransitions<T>(route, context, animation, secondaryAnimation, child);
  }
}

/// Success/danger/muted/chip-background roles kept under their original
/// names so the ~34 widgets that read them carry over unchanged; the values
/// now come from [AppTokens]. New code reads `context.tokens` directly.
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
