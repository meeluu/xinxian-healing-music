import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/config/app_version.dart';
import 'package:xinxian_healing_music/models/cloud_feedback_payload.dart';
import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_text_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/home_screen.dart';
import 'package:xinxian_healing_music/screens/history_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/utils/user_agent_helper.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// 反馈表单页：评分 + 状态评分前后 + 文字反馈 → 柔和淡入感谢页 → 回首页。
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
  // P2-Web-v1.0 第三批：状态评分 slider 和文字反馈默认折叠，降低首次填写成本。
  bool _showMore = false;

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

  /// P2-Web-v1.0 第三批 fix1：slider 语义统一为"状态评分"。
  /// 左边 = 状态不好，右边 = 状态好。底层字段 before/after 保持不变。
  String _stateLabel(double v) {
    if (v <= 0.0) return '不太好';
    if (v < 0.25) return '不太好';
    if (v < 0.5) return '有点低落';
    if (v < 0.75) return '还可以';
    if (v < 1.0) return '挺好';
    return '很好';
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

        // 评分（默认突出显示）
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
        const SizedBox(height: 20),

        // P2-Web-v1.0 第三批：状态评分 slider + 文字反馈折叠到"想多说一点？"
        // 默认折叠，降低首次填写成本；展开后显示两个 slider 和文本框。
        InkWell(
          onTap: () => setState(() => _showMore = !_showMore),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '想多说一点？',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _showMore ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _showMore
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 状态评分前后（P2-Web-v1.0 第三批 fix1：紧绷度 → 状态评分）
                const Text(
                  '感受一下你的状态变化',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '左边是不太好，右边是很好',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _TensionSlider(
                  label: '体验前',
                  value: _before,
                  activeColor: const Color(0xFFE7A86A),
                  onChanged: (v) => setState(() => _before = v),
                  textLabel: _stateLabel(_before),
                ),
                const SizedBox(height: 12),
                _TensionSlider(
                  label: '体验后',
                  value: _after,
                  activeColor: AppColors.teal,
                  onChanged: (v) => setState(() => _after = v),
                  textLabel: _stateLabel(_after),
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
                if (_canShareTextFeedback) ...[
                  const SizedBox(height: 8),
                  _ShareTextCheckbox(
                    value: _shareTextFeedback,
                    onChanged: (v) =>
                        setState(() => _shareTextFeedback = v ?? false),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // rating==0 时在提交按钮附近显示清楚提示
        if (_rating == 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '请先选择一个评分',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.apricotDeep),
            ),
          ),
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

  /// 是否已同意云端反馈采集（用于感谢页提示文案）。
  bool get _cloudAccepted => cloudFeedbackConsentService?.isAccepted ?? false;

  /// 提交反馈：本地保存 → fire-and-forget 云端上传（仅已同意时）。
  ///
  /// P2-Web-v1.0 第三批：不再在提交瞬间强制弹出云端采集同意弹窗。
  /// 未同意（unknown / declined）时默认只保存本地反馈，不打断用户。
  /// 用户可在设置中主动开启云端反馈采集，开启后此处自动走云端上传。
  Future<void> _submitFeedback() async {
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
    // 仅当用户已在设置中同意云端采集时才会上传，否则 _fireCloudUpload 内部跳过。
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
        // P2-Web-v1.0 第三批：未同意云端采集时提示本地保存 + 设置入口引导。
        if (!_cloudAccepted) ...[
          const SizedBox(height: 12),
          const Text(
            '已保存在本地。你也可以在设置中开启云端反馈，帮助我们改进推荐。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
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
