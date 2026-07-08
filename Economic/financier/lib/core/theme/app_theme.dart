import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final baseTextTheme = isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      textTheme: GoogleFonts.interTextTheme(baseTextTheme).copyWith(
        displayLarge: GoogleFonts.poppins(textStyle: baseTextTheme.displayLarge),
        displayMedium: GoogleFonts.poppins(textStyle: baseTextTheme.displayMedium),
        displaySmall: GoogleFonts.poppins(textStyle: baseTextTheme.displaySmall),
        headlineLarge: GoogleFonts.poppins(textStyle: baseTextTheme.headlineLarge),
        headlineMedium: GoogleFonts.poppins(textStyle: baseTextTheme.headlineMedium),
        headlineSmall: GoogleFonts.poppins(textStyle: baseTextTheme.headlineSmall),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: isLight ? Colors.white : AppColors.surfaceDark,
        foregroundColor: isLight ? Colors.black87 : Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: base.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 8,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(),
      ),
      dividerTheme: DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: base.outlineVariant.withValues(alpha: 0.5),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
