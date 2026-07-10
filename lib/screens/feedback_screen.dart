import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/config/app_version.dart';
import 'package:xinxian_healing_music/models/cloud_feedback_payload.dart';
import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_feedback_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_text_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/home_screen.dart';
import 'package:xinxian_healing_music/screens/history_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/utils/user_agent_helper.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';
import 'package:xinxian_healing_music/widgets/cloud_feedback_consent_dialog.dart';

/// 反馈表单页：评分 + 紧绷度前后 + 文字反馈 → 柔和淡入感谢页 → 回首页。
class FeedbackScreen extends StatefulWidget {
  final HealingMusicPlan plan;
  const FeedbackScreen({super.key, required this.plan});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 0;
  double _before = 0.5;
  double _after = 0.5;
  final TextEditingController _note = TextEditingController();
  bool _submitted = false;
  // M7：文字反馈上传勾选框，仅在用户已同意云端采集时显示。
  // 勾选后本次提交的文字反馈会上传到云端（受 cloudTextConsentService 控制）。
  bool _shareTextFeedback = false;

  @override
  void initState() {
    super.initState();
    // 初始化勾选状态：若用户此前已同意上传文字反馈，则默认勾选
    final textConsent = cloudTextConsentService;
    _shareTextFeedback = textConsent?.isAccepted ?? false;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _tensionLabel(double v) {
    if (v < 0.2) return '很放松';
    if (v < 0.45) return '较放松';
    if (v < 0.65) return '一般';
    if (v < 0.85) return '较紧绷';
    return '很紧绷';
  }

  @override
  Widget build(BuildContext context) {
    return CenteredPageScaffold(
      appBar: AppBar(
        title: const Text('体验反馈'),
        automaticallyImplyLeading: !_submitted,
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      // 提交后切换内容时用柔和淡入，关闭顶层入场动效避免重复
      animateEnter: !_submitted,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 480),
        switchInCurve: Curves.easeOutCubic,
        child: _submitted
            ? _buildThanks(Key('thanks'))
            : _buildForm(Key('form')),
      ),
    );
  }

  Widget _buildForm(Key key) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '方案：${widget.plan.templateName}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),

        // 评分
        const Text(
          '整体体验评分',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () => setState(() => _rating = i),
                icon: Icon(
                  i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 40,
                ),
                color: i <= _rating
                    ? const Color(0xFFE7A86A)
                    : const Color(0xFFCBD5E1),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // 紧绷度前后
        const Text(
          '感受一下你的紧绷度变化',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '拖动两条滑块，记录体验前后的状态',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _TensionSlider(
          label: '体验前',
          value: _before,
          activeColor: const Color(0xFFE7A86A),
          onChanged: (v) => setState(() => _before = v),
          textLabel: _tensionLabel(_before),
        ),
        const SizedBox(height: 12),
        _TensionSlider(
          label: '体验后',
          value: _after,
          activeColor: AppColors.teal,
          onChanged: (v) => setState(() => _after = v),
          textLabel: _tensionLabel(_after),
        ),
        const SizedBox(height: 24),

        // 文字反馈
        const Text(
          '想说点什么（可选）',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: '这段旋律让你想到了什么？身体有什么感受？',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.4,
              ),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        // M7：文字反馈上传勾选框，仅在已同意云端采集时显示。
        // 默认不上传文字反馈，用户需主动勾选；勾选状态会持久化到 cloudTextConsentService。
        if (_canShareTextFeedback) ...[
          const SizedBox(height: 8),
          _ShareTextCheckbox(
            value: _shareTextFeedback,
            onChanged: (v) => setState(() => _shareTextFeedback = v ?? false),
          ),
        ],
        const SizedBox(height: 28),

        FilledButton.icon(
          onPressed: _rating == 0 ? null : _submitFeedback,
          icon: const Icon(Icons.send_rounded, size: 20),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('提交反馈'),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _footerText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  /// 底部说明文案：根据云端采集同意状态动态切换。
  String get _footerText {
    final consent = cloudFeedbackConsentService;
    if (consent == null || !consent.isAccepted) {
      return '心弦 · 记录仅保存在本设备';
    }
    return '心弦 · 匿名反馈已开启';
  }

  /// 是否显示"同意上传文字反馈"勾选框。
  /// 仅当云端采集已同意且文字同意服务可用时显示。
  bool get _canShareTextFeedback {
    final consent = cloudFeedbackConsentService;
    final textConsent = cloudTextConsentService;
    return consent != null && consent.isAccepted && textConsent != null;
  }

  /// 提交反馈：本地保存 → 首次弹出云端同意弹窗 → fire-and-forget 云端上传。
  Future<void> _submitFeedback() async {
    // 首次提交：若云端采集同意状态为 unknown，弹出同意弹窗请用户选择。
    // 用户拒绝或弹窗装配失败时，仅保存本地，不上传云端。
    final consent = cloudFeedbackConsentService;
    if (consent != null && consent.needsPrompt && mounted) {
      final accepted = await CloudFeedbackConsentDialog.show(
        context,
        barrierDismissible: false,
      );
      if (!mounted) return;
      if (accepted == true) {
        await consent.setStatus(CloudFeedbackConsentStatus.accepted);
      } else {
        // accepted == false（用户点"仅保存在本设备"）
        await consent.setStatus(CloudFeedbackConsentStatus.declined);
      }
      setState(() {});
    }

    final noteText = _note.text.trim().isEmpty ? null : _note.text.trim();
    final record = FeedbackRecord(
      sessionId: widget.plan.sessionId,
      rating: _rating,
      tensionBefore: _before,
      tensionAfter: _after,
      note: noteText,
      completed: false,
      createdAt: DateTime.now(),
    );

    // 1. 本地保存（核心路径，必须成功）
    await feedbackRepository.save(record);
    sessionRecorder.attachFeedback(widget.plan.sessionId, record);

    // 2. 持久化文字反馈勾选状态（便于下次默认勾选）
    final textConsent = cloudTextConsentService;
    if (textConsent != null) {
      final newStatus = _shareTextFeedback
          ? CloudTextConsentStatus.accepted
          : CloudTextConsentStatus.declined;
      await textConsent.setStatus(newStatus);
    }

    // 3. fire-and-forget 云端上传
    // 不 await：上传失败/超时不影响 UI 流程；上传器内部已 catch 所有异常。
    // 若用户未填文字或未勾选上传文字，uploader 会根据 textConsent 状态剥离 freeTextFeedback。
    _fireCloudUpload(record);

    if (!mounted) return;
    setState(() => _submitted = true);
  }

  /// 触发云端上传（fire-and-forget）。
  ///
  /// 不 await 调用结果，任何异常由 [HttpCloudFeedbackUploader] 内部 catch。
  /// 此处仅 debugPrint 防御性日志，确保上传失败不影响本地体验。
  void _fireCloudUpload(FeedbackRecord record) {
    // 同步读取当前 consent 状态（已被 _submitFeedback 更新过）
    final consent = cloudFeedbackConsentService;
    if (consent == null || !consent.isAccepted) {
      debugPrint('[M7] cloud upload skipped: consent not accepted');
      return;
    }

    try {
      final payload = CloudFeedbackPayload.fromFeedback(
        record: record,
        plan: widget.plan,
        clientVersion: AppVersion.versionName,
        userAgent: getUserAgent(),
      );
      // 不 await：fire-and-forget
      cloudFeedbackUploader.upload(payload);
    } catch (e) {
      // 防御性 catch：理论上不应抛出，但确保万无一失
      debugPrint('[M7] cloud upload trigger failed: $e');
    }
  }

  Widget _buildThanks(Key key) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.teal.withValues(alpha: 0.15),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 56,
            color: AppColors.teal,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '感谢你的反馈',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '你的感受已被听见。\n愿这一段旋律，陪你慢慢回到自己。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('回到首页'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
          },
          child: const Text(
            '查看历史记录',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _TensionSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color activeColor;
  final ValueChanged<double> onChanged;
  final String textLabel;

  const _TensionSlider({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
    required this.textLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              textLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: activeColor,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
          inactiveColor: AppColors.cardBorder,
          min: 0.0,
          max: 1.0,
        ),
      ],
    );
  }
}

/// M7：文字反馈上传勾选框。
///
/// 仅在已同意云端采集时显示。勾选后本次提交的文字反馈会上传到云端，
/// 受 [CloudTextConsentService] 独立同意开关控制。默认不勾选。
class _ShareTextCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _ShareTextCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '同时上传本次文字反馈（可选，默认不上传）',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
