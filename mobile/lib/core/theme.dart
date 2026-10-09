import 'package:flutter/material.dart';

/// StockFlow's visual system: warm paper neutrals, one deep spruce accent,
/// amber for "low" and red for "out". Calm enough for long shifts on a
/// warehouse floor; numbers carry the weight, chrome stays quiet.
abstract final class AppTheme {
  static const fontFamily = 'IBMPlexSans';
  static const radius = 14.0;
  static const tabular = [FontFeature.tabularFigures()];

  static const _light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1F5C4A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCEBE4),
    onPrimaryContainer: Color(0xFF0F3428),
    secondary: Color(0xFF4E5D57),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE6EDE9),
    onSecondaryContainer: Color(0xFF22312B),
    tertiary: Color(0xFF8F5300),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFBEBD0),
    onTertiaryContainer: Color(0xFF573200),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFDE6E3),
    onErrorContainer: Color(0xFF7A1A12),
    surface: Color(0xFFF6F5F1),
    onSurface: Color(0xFF17201C),
    onSurfaceVariant: Color(0xFF5A6560),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF0EFEA),
    surfaceContainerHigh: Color(0xFFEAE9E3),
    surfaceContainerHighest: Color(0xFFE4E3DC),
    outline: Color(0xFFC9C7BF),
    outlineVariant: Color(0xFFE5E3DC),
    inverseSurface: Color(0xFF2A302D),
    onInverseSurface: Color(0xFFF1F2EF),
    inversePrimary: Color(0xFF8FD1B8),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8FD1B8),
    onPrimary: Color(0xFF00382A),
    primaryContainer: Color(0xFF1C4A3C),
    onPrimaryContainer: Color(0xFFCDEBDD),
    secondary: Color(0xFFB4C4BC),
    onSecondary: Color(0xFF1F2D27),
    secondaryContainer: Color(0xFF2A3631),
    onSecondaryContainer: Color(0xFFD3E2DA),
    tertiary: Color(0xFFF2BC6B),
    onTertiary: Color(0xFF462A00),
    tertiaryContainer: Color(0xFF4A3110),
    onTertiaryContainer: Color(0xFFFBDDB0),
    error: Color(0xFFFFA89E),
    onError: Color(0xFF5F120B),
    errorContainer: Color(0xFF5A1C16),
    onErrorContainer: Color(0xFFFFD9D4),
    surface: Color(0xFF111513),
    onSurface: Color(0xFFE6EAE7),
    onSurfaceVariant: Color(0xFFA3ADA8),
    surfaceContainerLowest: Color(0xFF0C0F0E),
    surfaceContainerLow: Color(0xFF181D1B),
    surfaceContainer: Color(0xFF1C2220),
    surfaceContainerHigh: Color(0xFF232A27),
    surfaceContainerHighest: Color(0xFF2B3330),
    outline: Color(0xFF46504B),
    outlineVariant: Color(0xFF2C3431),
    inverseSurface: Color(0xFFE6EAE7),
    onInverseSurface: Color(0xFF1C2220),
    inversePrimary: Color(0xFF1F5C4A),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static ThemeData get light => _build(_light);
  static ThemeData get dark => _build(_dark);

  static ThemeData _build(ColorScheme s) {
    final base = ThemeData(
      colorScheme: s,
      fontFamily: fontFamily,
      useMaterial3: true,
    );
    final t = base.textTheme;
    final text = t.copyWith(
      headlineLarge: t.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w500),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final hairline = BorderSide(color: s.outlineVariant);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: s.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: text.titleLarge?.copyWith(
          color: s.onSurface,
          fontSize: 24,
        ),
      ),
      cardTheme: CardThemeData(
        color: s.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: hairline),
      ),
      dividerTheme: DividerThemeData(
        color: s.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
        titleTextStyle: text.bodyLarge?.copyWith(
          color: s.onSurface,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: text.bodySmall?.copyWith(color: s.onSurfaceVariant),
        iconColor: s.onSurfaceVariant,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        prefixIconColor: s.onSurfaceVariant,
        suffixIconColor: s.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: s.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: s.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: s.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: s.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: s.error, width: 1.6),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(s.surfaceContainerLowest),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStatePropertyAll(hairline.copyWith(color: s.outline)),
        shape: WidgetStatePropertyAll(controlShape),
        constraints: const BoxConstraints(minHeight: 50),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        hintStyle: WidgetStatePropertyAll(
          text.bodyLarge?.copyWith(color: s.onSurfaceVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: controlShape,
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: controlShape,
          side: BorderSide(color: s.outline),
          foregroundColor: s.onSurface,
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: s.primary,
        foregroundColor: s.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: text.labelLarge?.copyWith(fontSize: 15),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: s.surfaceContainerLowest,
        selectedColor: s.onSurface,
        checkmarkColor: s.surface,
        side: BorderSide(color: s.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: text.labelLarge?.copyWith(color: s.onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: s.surface),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        showCheckmark: false,
        iconTheme: IconThemeData(color: s.onSurfaceVariant, size: 18),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: s.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: s.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? s.onSurface
                : s.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? s.onPrimaryContainer
                : s.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: s.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: s.onInverseSurface),
        shape: controlShape,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: s.primary,
        linearTrackColor: s.primaryContainer,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: s.onSurface,
          selectedForegroundColor: s.surface,
          side: BorderSide(color: s.outline),
          shape: controlShape,
        ),
      ),
    );
  }
}

/// Section heading used above grouped content.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
