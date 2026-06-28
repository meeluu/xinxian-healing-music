import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

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
      builder: (_) => LlmConsentDialog(barrierDismissible: barrierDismissible),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // barrierDismissible=false 时禁止系统返回键关闭弹窗
      canPop: barrierDismissible,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.tealDeep, size: 22),
            SizedBox(width: 8),
            Text(
              'AI 解析隐私说明',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '心弦提供两种情绪解析方式：',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            SizedBox(height: 12),
            _Bullet(text: '开启 AI 解析后，你输入的心境文本会发送到 AI 服务用于情绪解析'),
            _Bullet(text: '解析结果和历史记录仍然保存在本设备，不上传服务器'),
            _Bullet(text: '本功能仅用于辅助情绪调节和音乐推荐，不提供医疗诊断'),
            _Bullet(text: '你可以随时在"解析设置"中切换为仅使用本地解析'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '仅使用本地解析',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('同意 AI 解析'),
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
