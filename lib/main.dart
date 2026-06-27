import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/screens/home_screen.dart';

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
      theme: _buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6E8FB2),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0F1626),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: colorScheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
    );
  }
}
