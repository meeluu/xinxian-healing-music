import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

/// 统一的响应式页面骨架（浅色疗愈风）。
///
/// 结构：
///   Scaffold
///     └─ 背景渐变 Container（默认柔和 bgBlue→bgBase，可覆盖）
///        └─ SafeArea
///           └─ [_EnterAnim]（fade in + slide up，440ms easeOutCubic）
///              └─ Align(alignment)
///                 └─ ConstrainedBox(maxWidth 760)
///                    └─ SingleChildScrollView
///                       └─ Padding(横向 24)
///                          └─ child
///
/// - 宽屏：主体被限制在 [maxWidth] 内并水平居中，两侧留白。
/// - 窄屏：maxWidth 大于屏宽，主体撑满，两侧保留 24 横向安全边距。
/// - 所有页面默认带入场动效；如需自行做 stagger，可传 animateEnter: false。
class CenteredPageScaffold extends StatelessWidget {
  static const double maxWidth = 760;

  final PreferredSizeWidget? appBar;
  final Widget child;
  final Gradient? backgroundGradient;
  final Alignment alignment;
  final EdgeInsets padding;
  final bool animateEnter;

  const CenteredPageScaffold({
    super.key,
    this.appBar,
    required this.child,
    this.backgroundGradient,
    this.alignment = Alignment.topCenter,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    this.animateEnter = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (animateEnter) {
      content = _EnterAnim(child: content);
    }

    final body = Container(
      decoration: BoxDecoration(
        gradient: backgroundGradient ?? AppColors.bgGradient,
      ),
      child: SafeArea(child: content),
    );

    return Scaffold(
      appBar: appBar,
      body: body,
    );
  }
}

/// 全局页面入场动效：fade in + 轻微 slide up。
/// 仅 paint-time 变换，不影响布局。
class _EnterAnim extends StatelessWidget {
  final Widget child;
  const _EnterAnim({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 440),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
