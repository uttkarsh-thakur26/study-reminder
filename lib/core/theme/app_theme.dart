import 'package:flutter/material.dart';

/// Spacing scale. Everything lines up on multiples of 4.
abstract final class Gap {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class Radii {
  static const s = 10.0;
  static const m = 14.0;
  static const l = 20.0;
  static const xl = 28.0;
}

/// Accent colours the user can pick in Settings.
const accentChoices = <({String name, Color color})>[
  (name: 'Indigo', color: Color(0xFF5B5BD6)),
  (name: 'Teal', color: Color(0xFF0F9D8A)),
  (name: 'Sky', color: Color(0xFF0B84D8)),
  (name: 'Violet', color: Color(0xFF8B5CF6)),
  (name: 'Rose', color: Color(0xFFE11D63)),
  (name: 'Amber', color: Color(0xFFD97706)),
  (name: 'Emerald', color: Color(0xFF16A34A)),
];

/// Width at which layouts switch from phone to desktop arrangement.
const wideBreakpoint = 720.0;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideBreakpoint;

/// The app's theme from [accent]. With [pureBlack], the dark theme sits on
/// black, with surfaces just above it, which OLED screens show for less.
ThemeData buildTheme(
  Color accent,
  Brightness brightness, {
  bool pureBlack = false,
}) {
  final dark = brightness == Brightness.dark;
  var scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
  );
  if (dark && pureBlack) {
    Color lift(double amount) =>
        Color.lerp(Colors.black, scheme.surfaceContainer, amount)!;
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: lift(0.45),
      surfaceContainer: lift(0.65),
      surfaceContainerHigh: lift(0.85),
      surfaceContainerHighest: scheme.surfaceContainerHigh,
    );
  }
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  final text = base.textTheme;

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.l),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: dark ? 0.35 : 0.6),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.l),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(
        alpha: dark ? 0.6 : 0.7,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.l,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.m),
        ),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.m),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.m),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.m),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.s),
      ),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 1,
      highlightElevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.l),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: scheme.surfaceContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      labelType: NavigationRailLabelType.none,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.m),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      space: 1,
      thickness: 1,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
