import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/screens/privacy_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/responsive_dialog_container.dart';

/// LLM 隐私同意弹窗。
///
/// 文案说明：
/// - 开启 AI 解析后，心境文本会发送到 AI 服务用于情绪解析
/// - 解析结果和历史记录仍保存在本设备
/// - 仅用于辅助情绪调节和音乐推荐，不提供医疗诊断
/// - 可选择仅使用本地解析
///
/// 两个按钮：
/// - "仅使用本地解析"（对应 declined）
/// - "同意 AI 解析"（对应 accepted）
///
/// 首次进入首页时 [show] 不可关闭背景（必须做选择）；
/// "解析设置"入口再次调用时可传 [barrierDismissible] 允许关闭。
///
/// 移动端适配（M5 修复）：
/// - 使用 [ResponsiveDialogContainer] 替代 [AlertDialog]，避免窄屏渲染异常
/// - 内容区可滚动，按钮区固定底部，保证 360px 宽手机完整可见
class LlmConsentDialog extends StatelessWidget {
  final bool barrierDismissible;

  const LlmConsentDialog({super.key, this.barrierDismissible = false});

  /// 弹出弹窗并返回用户选择。
  /// - true：同意 AI 解析
  /// - false：仅使用本地解析
  /// - null：关闭弹窗未选择（仅 [barrierDismissible] = true 时可能）
  static Future<bool?> show(
    BuildContext context, {
    bool barrierDismissible = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      // insetPadding: EdgeInsets.zero 取消 AlertDialog 默认 inset，
      // 改由 ResponsiveDialogContainer 内部 SafeArea + ConstrainedBox 控制尺寸
      builder: (_) => PopScope(
        canPop: barrierDismissible,
        child: LlmConsentDialog(barrierDismissible: barrierDismissible),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveDialogContainer(
      title: const Row(
        children: [
          Icon(Icons.shield_rounded, color: AppColors.tealDeep, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI 解析隐私说明',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      footer: DialogButtonBar(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('仅使用本地解析', style: TextStyle(fontSize: 14)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('同意 AI 解析', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '心弦提供两种情绪解析方式：',
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          const _Bullet(text: '开启 AI 解析后，你输入的心境文本会发送到 AI 服务用于情绪解析'),
          const _Bullet(text: '解析结果和历史记录仍然保存在本设备，不上传服务器'),
          const _Bullet(text: '本功能仅用于辅助情绪调节和音乐推荐，不提供医疗诊断'),
          const _Bullet(text: '你可以随时在"解析设置"中切换为仅使用本地解析'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              child: const Text('查看隐私政策', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
