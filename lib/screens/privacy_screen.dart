import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// 隐私政策页面：本地静态文本，不请求后端。
///
/// 覆盖内容：
/// 1. 产品定位
/// 2. 本地存储
/// 3. AI 情绪解析
/// 4. 云端匿名反馈
/// 5. 文字反馈
/// 6. 数据用途
/// 7. 数据删除
/// 8. 联系方式
///
/// 适配移动端：使用 [CenteredPageScaffold] + AppBar + 可滚动内容。
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CenteredPageScaffold(
      appBar: AppBar(title: const Text('隐私政策')),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('一、产品定位'),
          _SectionBody(
            '心弦是一款情绪调节、睡前舒缓、正念放松和音乐陪伴工具。'
            '通过自然语言驱动的 AI 心境解析与音乐匹配，为用户提供温和的陪伴体验。'
            '心弦不提供医疗诊断或治疗建议，不能替代专业医疗咨询。'
            '如有心理健康方面的困扰，请寻求专业医生或心理咨询师的帮助。',
          ),
          _SectionTitle('二、本地存储'),
          _SectionBody(
            '心弦将以下数据保存在你的本地设备（浏览器 localStorage 或移动端本地存储）：\n'
            '· 历史聆听记录（心境文本、音乐方案、聆听时长、反馈评分）\n'
            '· 解析偏好设置（AI 解析 / 本地解析的选择）\n'
            '· 云端采集与文字反馈的同意状态\n'
            '这些数据不会自动上传到任何服务器。清除浏览器数据或卸载应用后，本地数据将被删除。',
          ),
          _SectionTitle('三、AI 情绪解析'),
          _SectionBody(
            '心弦提供两种情绪解析方式：\n'
            '· 本地解析：完全在设备上通过关键词规则完成，不发送任何数据到云端。\n'
            '· AI 解析：在你明确同意后，你输入的心境文本会发送到云端函数，'
            '再转发给 LLM（大语言模型）服务进行情绪解析。解析完成后，'
            '云端仅返回结构化的情绪画像（标签、效价、唤醒度等），不保留原文。\n\n'
            'API Key 和模型配置仅保存在云端函数的环境变量中，不在前端代码中暴露。'
            '你可以随时在"解析设置"中切换为仅使用本地解析。',
          ),
          _SectionTitle('四、云端匿名反馈'),
          _SectionBody(
            '在你同意云端匿名采集后，心弦会上传以下结构化数据到 Cloudflare D1 数据库：\n'
            '· 匿名会话标识（session / listeningSession，不关联身份）\n'
            '· 情绪标签与参数（如"焦虑"、放松度评分）\n'
            '· 疗愈方案与音频匹配信息（方案标题、音频标识）\n'
            '· 体验评分与紧绷度变化\n\n'
            '不上传的数据：心境原文、身份信息、账号、IP 地址。'
            '云端上传失败不影响本地反馈保存和用户体验。',
          ),
          _SectionTitle('五、文字反馈'),
          _SectionBody(
            '你在反馈页填写的文字反馈默认仅保存在本地设备，不会上传。'
            '只有当你主动勾选"同意上传文字反馈"选项时，本次提交的文字反馈才会随匿名数据一起上传到云端。'
            '每次提交都是独立的，不构成永久授权。',
          ),
          _SectionTitle('六、数据用途'),
          _SectionBody(
            '收集的匿名数据仅用于：\n'
            '· 体验优化与音乐推荐算法改进\n'
            '· 匿名统计与产品使用分析\n'
            '· 科研分析（如情绪调节工具的有效性研究）\n\n'
            '数据不会分享给第三方，也不会用于商业广告。',
          ),
          _SectionTitle('七、数据删除'),
          _SectionBody(
            '· 本地数据：你可以在"历史记录"页面删除单条记录或清空全部历史，操作即时生效。\n'
            '· 云端匿名数据：匿名反馈不直接关联身份信息，暂不支持按用户删除。'
            '如你希望删除特定会话的云端数据，可通过联系方式提供 session 标识，开发者将协助处理。\n\n'
            '本地删除历史记录不会联动删除已上传的云端匿名数据。',
          ),
          _SectionTitle('八、联系方式'),
          _SectionBody(
            '如需反馈问题、提出建议或处理数据相关请求，'
            '可通过项目页面或后续公开联系方式联系开发者。',
          ),
          SizedBox(height: 24),
          Text(
            '本政策可能随产品迭代更新，更新后将在应用内提示。',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 隐私政策小节标题。
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// 隐私政策小节正文（支持 \n 换行）。
class _SectionBody extends StatelessWidget {
  final String text;
  const _SectionBody(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.7,
      ),
    );
  }
}
