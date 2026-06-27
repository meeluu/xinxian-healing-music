import 'package:flutter/material.dart';

/// 统一的响应式页面骨架。
///
/// 结构：
///   Scaffold
///     └─ (背景渐变 Container，可选)        // 渐变铺满整屏（含状态栏后）
///        └─ SafeArea                      // 内容避开刘海/状态栏/手势条
///           └─ Align(alignment)           // 水平居中（默认 topCenter）
///              └─ ConstrainedBox(maxWidth)
///                 └─ SingleChildScrollView
///                    └─ Padding           // 横向安全边距 24
///                       └─ child
///
/// - 宽屏：主体被限制在 [maxWidth] 内并水平居中，两侧留白，不贴左。
/// - 窄屏：maxWidth 大于屏宽，主体撑满，两侧保留 24 横向安全边距。
/// - 需要垂直居中的页面（如解析动画页）传入 alignment: Alignment.center。
class CenteredPageScaffold extends StatelessWidget {
  /// 主体最大宽度，所有页面统一。
  static const double maxWidth = 760;

  final PreferredSizeWidget? appBar;
  final Widget child;

  /// 背景渐变。传入后渐变会铺满整屏（含状态栏区域），内容仍受 SafeArea 保护。
  final Gradient? backgroundGradient;

  /// 主体对齐方式，默认 topCenter（内容从顶部开始，可滚动）。
  final Alignment alignment;

  /// 主体内边距，默认横向 24（窄屏安全边距）、纵向 20。
  final EdgeInsets padding;

  const CenteredPageScaffold({
    super.key,
    this.appBar,
    required this.child,
    this.backgroundGradient,
    this.alignment = Alignment.topCenter,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
  });

  @override
  Widget build(BuildContext context) {
    final centered = Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    // 有渐变时：渐变 Container 铺满整屏，SafeArea 在其内部保护内容。
    // 无渐变时：Scaffold 背景色 + SafeArea 直接包内容。
    final body = backgroundGradient == null
        ? SafeArea(child: centered)
        : Container(
            decoration: BoxDecoration(gradient: backgroundGradient!),
            child: SafeArea(child: centered),
          );

    return Scaffold(
      appBar: appBar,
      // 有 AppBar 时 Scaffold 会自动把顶部 padding 移除，SafeArea 不会再叠加；
      // 无 AppBar 时 SafeArea 负责避开状态栏。
      body: body,
    );
  }
}
