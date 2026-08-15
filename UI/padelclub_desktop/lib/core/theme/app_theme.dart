import 'package:flutter/material.dart';

abstract final class PadelColors {
  static const green = Color(0xFF10B981);
  static const greenDark = Color(0xFF087F5B);
  static const greenSoft = Color(0xFFE7F8F1);
  static const blue = Color(0xFF2563EB);
  static const blueDark = Color(0xFF1D4ED8);
  static const blueSoft = Color(0xFFEAF1FF);
  static const canvas = Color(0xFFF7F9FC);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const text = Color(0xFF172033);
  static const textMuted = Color(0xFF778195);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFFF4D6);
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0xFFFFE4E6);
}

abstract final class PadelSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class PadelRadii {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
}

abstract final class PadelTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: PadelColors.green,
          brightness: Brightness.light,
        ).copyWith(
          primary: PadelColors.green,
          secondary: PadelColors.blue,
          surface: PadelColors.surface,
          error: PadelColors.danger,
        );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(PadelRadii.medium),
      borderSide: const BorderSide(color: PadelColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PadelColors.canvas,
      dividerColor: PadelColors.border,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.dragged)
              ? PadelColors.greenDark
              : PadelColors.greenDark.withValues(alpha: 0.68);
        }),
        thickness: const WidgetStatePropertyAll(10),
        radius: const Radius.circular(8),
        crossAxisMargin: 2,
        mainAxisMargin: 6,
        minThumbLength: 54,
        interactive: true,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: PadelColors.text,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        headlineSmall: TextStyle(
          color: PadelColors.text,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          color: PadelColors.text,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: PadelColors.text),
        bodySmall: TextStyle(color: PadelColors.textMuted),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: PadelColors.text,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: PadelColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PadelRadii.large),
          side: const BorderSide(color: PadelColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PadelColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: PadelColors.textMuted, fontSize: 13),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: PadelColors.blue, width: 1.5),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: PadelColors.danger),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: PadelColors.danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PadelColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PadelRadii.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PadelColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PadelRadii.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PadelColors.text,
          minimumSize: const Size(0, 42),
          side: const BorderSide(color: PadelColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PadelRadii.small),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PadelColors.blue,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PadelColors.surface,
        selectedColor: PadelColors.blue,
        disabledColor: PadelColors.canvas,
        side: const BorderSide(color: PadelColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PadelRadii.small),
        ),
        labelStyle: const TextStyle(
          color: PadelColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: PadelColors.surface,
        indicatorColor: PadelColors.greenSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? PadelColors.greenDark
                : PadelColors.textMuted,
            size: 23,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? PadelColors.greenDark
                : PadelColors.textMuted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
    );
  }
}
