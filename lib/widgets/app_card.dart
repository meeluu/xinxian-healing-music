import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

/// 轻量卡片：白色背景、浅蓝灰边框、极轻阴影。
///
/// Web 端 hover 时轻微上浮、边框变亮（克制，不影响布局）。
class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: _hover
            ? Matrix4.translationValues(0, -2, 0)
            : Matrix4.identity(),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: _hover
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.cardBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: _hover ? 20 : 12,
              offset: Offset(0, _hover ? 6 : 4),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
