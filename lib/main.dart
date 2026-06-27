import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinxian_healing_music/pipeline/local/local_feedback_repository.dart';
import 'package:xinxian_healing_music/pipeline/local/local_listening_session_recorder.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/home_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

void main() async {
  // shared_preferences 是平台插件，需要初始化 binding
  WidgetsFlutterBinding.ensureInitialized();

  // 尝试装配 shared_preferences 本地持久化实现；
  // 失败时（隐私模式 / 平台不支持 / 损坏）保持默认 mock 内存态，Demo 仍可用。
  try {
    final prefs = await SharedPreferences.getInstance();
    sessionRecorder = await LocalListeningSessionRecorder.create(prefs);
    feedbackRepository = await LocalFeedbackRepository.create(prefs);
  } catch (_) {
    // 保持 services.dart 中默认的 mock 实现
  }

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
      builder: (context, child) {
        // 移动端浏览器/系统字体缩放会被 Flutter Web 隐式拾取并放大所有文字
        // （Text 组件内部使用 MediaQuery.textScalerOf），导致行距与 chip 高度异常巨大。
        // 这里将 textScaler 限制在 [1.0, 1.2]：
        // - 桌面端默认 1.0，clamp 后不变，布局完全不受影响。
        // - 移动端过大缩放被限制在 1.2，恢复正常的行距与组件密度，
        //   同时保留 1.2 倍以内的无障碍放大，不完全禁用辅助功能。
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context).clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child!,
        );
      },
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
        surfaceTintColor: Colors.transparent,
        labelStyle: const TextStyle(color: AppColors.chipLabelText),
        side: const BorderSide(color: AppColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
