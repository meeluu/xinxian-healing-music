import 'package:flutter/material.dart';

/// 心弦 Demo 浅色疗愈配色方案。
///
/// 风格：安静、干净、柔和、可信赖。
/// 避免大面积深黑/深蓝/强对比；以雾白为底，柔和湖蓝为主色，
/// 杏色 / 浅紫 / 青绿作克制点缀。
class AppColors {
  AppColors._();

  // —— 背景层 ——
  static const Color bgBase = Color(0xFFF7FAFC); // 雾白
  static const Color bgBlue = Color(0xFFEEF6FB); // 浅雾蓝
  static const Color bgMint = Color(0xFFF1FAF7); // 极浅青绿

  // —— 主色 ——
  static const Color primary = Color(0xFF6BAED6); // 柔和湖蓝
  static const Color primaryDeep = Color(0xFF4A93C2);
  static const Color teal = Color(0xFF7CC7B8); // 青绿
  static const Color tealDeep = Color(0xFF4FA391);

  // —— 强调点缀 ——
  static const Color apricot = Color(0xFFF4C7A1); // 杏色
  static const Color apricotDeep = Color(0xFFD99A66);
  static const Color lavender = Color(0xFFB8A7E8); // 浅紫

  // —— 文字 ——
  static const Color textPrimary = Color(0xFF243447); // 深灰蓝
  static const Color textSecondary = Color(0xFF64748B); // 次要灰
  static const Color textMuted = Color(0xFF94A3B8); // 弱化

  // —— 卡片 ——
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFDCE7F0); // 浅蓝灰边框
  static const Color cardShadow = Color(0x140A2336); // 极轻阴影

  // —— 默认柔和背景渐变 ——
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgBlue, bgBase],
  );
}
