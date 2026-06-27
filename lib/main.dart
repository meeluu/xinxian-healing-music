import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/screens/home_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

void main() {
  runApp(const XinXianApp());
}

class XinXianApp extends StatelessWidget {
  const XinXianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '心弦 · 疗愈音乐',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE6F1F9),
          onPrimaryContainer: AppColors.primaryDeep,
          secondary: AppColors.teal,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFE7F4EF),
          onSecondaryContainer: AppColors.tealDeep,
          surface: AppColors.cardBg,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          surfaceContainerHighest: const Color(0xFFF0F5F9),
          error: const Color(0xFFE07A6B),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgBase,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.cardBorder,
        thumbColor: AppColors.primary,
        overlayColor: Color(0x1F6BAED6),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEEF4FA),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        side: const BorderSide(color: AppColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
