import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/responsive_dialog_container.dart';

/// 云端匿名反馈采集同意弹窗（M7 新增）。
///
/// 文案说明：
/// - 采集匿名情绪标签和参数（不含心境原文）
/// - 采集疗愈方案与音频匹配信息
/// - 采集体验评分
/// - 不采集心境原文、身份信息、IP 地址
/// - 数据匿名存储在 Cloudflare D1，仅用于产品优化和科研分析
/// - 可随时在"解析设置"中关闭
///
/// 两个按钮：
/// - "仅保存在本设备"（对应 declined）
/// - "同意匿名上传"（对应 accepted）
///
/// 首次提交反馈时触发（由 [FeedbackScreen] 调用）；
/// "解析设置"入口再次调用时可传 [barrierDismissible] 允许关闭。
///
/// 移动端适配：复用 [ResponsiveDialogContainer]（与 [LlmConsentDialog] 一致）。
class CloudFeedbackConsentDialog extends StatelessWidget {
  final bool barrierDismissible;

  const CloudFeedbackConsentDialog({super.key, this.barrierDismissible = false});

  /// 弹出弹窗并返回用户选择。
  /// - true：同意匿名上传
  /// - false：仅保存在本设备
  /// - null：关闭弹窗未选择（仅 [barrierDismissible] = true 时可能）
  static Future<bool?> show(
    BuildContext context, {
    bool barrierDismissible = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => PopScope(
        canPop: barrierDismissible,
        child: CloudFeedbackConsentDialog(barrierDismissible: barrierDismissible),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveDialogContainer(
      title: const Row(
        children: [
          Icon(Icons.cloud_outlined, color: AppColors.tealDeep, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '匿名反馈采集说明',
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
            child: const Text('仅保存在本设备', style: TextStyle(fontSize: 14)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('同意匿名上传', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '心弦希望收集匿名的反馈数据，用于改进音乐推荐和支持科研分析。',
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          SizedBox(height: 14),
          Text(
            '我们会采集：',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          _Bullet(text: '情绪标签与参数（如"焦虑"、放松度评分，不含心境原文）'),
          _Bullet(text: '疗愈方案与音频匹配信息（方案标题、音频标识）'),
          _Bullet(text: '你的体验评分与紧绷度变化'),
          SizedBox(height: 12),
          Text(
            '我们不会采集：',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          _Bullet(text: '你的心境原文（仅保留在本设备）'),
          _Bullet(text: '你的身份信息或账号（本应用无登录系统）'),
          _Bullet(text: '你的 IP 地址'),
          SizedBox(height: 12),
          Text(
            '数据匿名存储在 Cloudflare D1 数据库，仅用于产品优化和科研分析，'
            '不会分享给第三方。文字反馈默认不上传，需在反馈页单独勾选。'
            '你可以随时在"解析设置"中关闭云端采集，关闭后反馈仍保存在本设备。',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
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
                fontSize: 12,
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
