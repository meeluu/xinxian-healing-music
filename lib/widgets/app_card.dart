import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

/// 轻量卡片：白色背景、浅蓝灰边框、极轻阴影。
///
/// M6.1 修复：移除 MouseRegion + hover setState。
///
/// 原实现用 `MouseRegion + onEnter/onExit + setState(_hover)` 实现 hover 上浮，
/// 这是 Flutter Web debug 下 `mouse_tracker.dart:199` 断言的经典触发模式：
/// hover 时 setState 导致重建，MouseRegion 在重建期间被重新挂载，
/// mouse tracker 内部状态不一致触发断言循环。
///
/// 改为静态卡片（无 hover 反馈），更稳定。卡片视觉风格保持不变。
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
