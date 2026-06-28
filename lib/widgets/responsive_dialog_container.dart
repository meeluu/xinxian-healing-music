import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

/// 通用响应式弹窗容器，供 LLM 同意弹窗、关于弹窗、解析设置弹窗复用。
///
/// 解决移动端（特别是微信内置 / QQ 浏览器）弹窗渲染异常问题：
/// - 默认 [AlertDialog] 的 `insetPadding` 在窄屏上会让弹窗过窄
/// - 默认 [AlertDialog] 内容区无滚动，内容多时会 overflow 静默裁剪
/// - 默认 [AlertDialog] 的 actions 在窄屏上换行异常，按钮被推出可视区
/// - 某些移动端浏览器对 Material 3 AlertDialog 渲染不稳定
///
/// 本容器完全自建布局，不依赖 [AlertDialog]：
/// 1. 外层 [SafeArea] 保证不被状态栏 / 导航栏遮挡
/// 2. [Center] 居中 + `insetPadding: EdgeInsets.zero` 取消默认 inset
/// 3. 宽度：移动端 `screenWidth - 32`，桌面端 `maxWidth 520`
/// 4. 高度：`maxHeight: screenHeight * 0.85`，内容区 [SingleChildScrollView]
/// 5. 按钮区固定在底部（[footer]），不随内容滚动
/// 6. 文字颜色与背景对比度足够（白底 + [AppColors.textPrimary]）
class ResponsiveDialogContainer extends StatelessWidget {
  /// 弹窗标题（顶部）。
  final Widget? title;

  /// 弹窗主体内容（可滚动区域）。
  final Widget child;

  /// 底部按钮区（固定不滚动）。
  final Widget? footer;

  /// 内容区内边距。
  final EdgeInsetsGeometry contentPadding;

  /// 标题区内边距。
  final EdgeInsetsGeometry titlePadding;

  /// 底部按钮区内边距。
  final EdgeInsetsGeometry footerPadding;

  /// 桌面端最大宽度（默认 520）。
  final double desktopMaxWidth;

  /// 移动端宽度阈值（小于此值视为移动端，默认 600）。
  final double mobileBreakpoint;

  /// 高度系数（弹窗最大高度 = 屏幕高度 × 此值，默认 0.85）。
  final double maxHeightFactor;

  const ResponsiveDialogContainer({
    super.key,
    this.title,
    required this.child,
    this.footer,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 12, 24, 16),
    this.titlePadding = const EdgeInsets.fromLTRB(24, 20, 24, 0),
    this.footerPadding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.desktopMaxWidth = 520,
    this.mobileBreakpoint = 600,
    this.maxHeightFactor = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isMobile = screenWidth < mobileBreakpoint;

    // 移动端：屏幕宽度 - 32（左右各 16 边距）
    // 桌面端：520
    final dialogWidth = isMobile ? screenWidth - 32 : desktopMaxWidth;
    // 最大高度：屏幕高度 × 0.85，留 15% 给状态栏 / 导航栏 / 遮罩呼吸空间
    final dialogMaxHeight = screenHeight * maxHeightFactor;

    return Center(
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: dialogMaxHeight,
          ),
          child: Material(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题区（固定不滚动）
                if (title != null)
                  Padding(padding: titlePadding, child: title),
                // 内容区（可滚动）
                Flexible(
                  child: SingleChildScrollView(
                    padding: contentPadding,
                    child: child,
                  ),
                ),
                // 底部按钮区（固定不滚动）
                if (footer != null)
                  Padding(padding: footerPadding, child: footer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹窗底部按钮区：水平排列，移动端自动换行，按钮等宽。
///
/// 解决 [AlertDialog.actions] 在窄屏上换行异常、按钮被推出可视区的问题。
class DialogButtonBar extends StatelessWidget {
  final List<Widget> children;

  const DialogButtonBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.length <= 1) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: children,
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          // 每个按钮占据可用空间的等分，保证移动端按钮文字完整可见
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
