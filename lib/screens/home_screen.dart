import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/config/app_version.dart';
import 'package:xinxian_healing_music/pipeline/consent/cloud_feedback_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/llm/llm_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/analysis_screen.dart';
import 'package:xinxian_healing_music/screens/comfort_lyrics_screen.dart';
import 'package:xinxian_healing_music/screens/history_screen.dart';
import 'package:xinxian_healing_music/screens/privacy_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/breathing_halo.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';
import 'package:xinxian_healing_music/widgets/cloud_feedback_consent_dialog.dart';
import 'package:xinxian_healing_music/widgets/llm_consent_dialog.dart';
import 'package:xinxian_healing_music/widgets/mood_input_field.dart';
import 'package:xinxian_healing_music/widgets/responsive_dialog_container.dart';

/// 首页：输入当前心境描述。
///
/// M4B: 首次进入时弹出 AI 解析隐私同意弹窗（[LlmConsentDialog]），
/// 用户选择后持久化到 [LlmConsentService]；底部提供"解析设置"入口
/// 允许随时切换。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  static const List<String> _examples = [
    '备考压力大，晚上睡不着，脑子停不下来',
    '最近总是提不起劲，感觉很疲惫、很空',
    '和亲人吵架后很烦躁，静不下心',
  ];

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    // P2-Web-v1.0 第一批：不在首页初始化时自动弹出 LLM 同意弹窗。
    // 改为用户第一次点击"生成专属疗愈方案"时，若尚未选择过 AI 解析偏好，再弹出。
    // 这样用户能先看到产品首屏价值，再做隐私选择。
  }

  Future<void> _showConsentDialog({required bool firstTime}) async {
    final service = llmConsentService;
    if (service == null || !mounted) return;

    final accepted = await LlmConsentDialog.show(
      context,
      barrierDismissible: !firstTime,
    );
    if (!mounted) return;

    if (accepted == true) {
      await service.setStatus(LlmConsentStatus.accepted);
    } else if (accepted == false) {
      await service.setStatus(LlmConsentStatus.declined);
    }
    // accepted == null（用户关闭弹窗，仅非首次时可能）：不改变状态

    if (mounted) setState(() {});
  }

  /// 底部说明文案：根据同意状态动态切换。
  String get _footerText {
    final service = llmConsentService;
    if (service == null) {
      return '心弦 · 本地解析模式';
    }
    switch (service.status) {
      case LlmConsentStatus.accepted:
        return '心弦 · AI 解析模式';
      case LlmConsentStatus.declined:
        return '心弦 · 本地解析模式';
      case LlmConsentStatus.unknown:
        return '心弦 · 本地解析模式';
    }
  }

  /// "解析设置"按钮的当前标签。
  String get _settingsLabel {
    final service = llmConsentService;
    if (service != null && service.isAccepted) {
      return '解析设置 · AI';
    }
    return '解析设置 · 本地';
  }

  /// "云端采集"按钮的当前标签。
  /// M7：根据云端采集同意状态切换标签，便于用户快速识别当前状态。
  String get _cloudFeedbackLabel {
    final service = cloudFeedbackConsentService;
    if (service != null && service.isAccepted) {
      return '云端采集 · 已开启';
    }
    return '云端采集 · 已关闭';
  }

  /// 弹出云端采集同意弹窗（从"云端采集"入口触发，可关闭）。
  Future<void> _showCloudFeedbackConsentDialog() async {
    final service = cloudFeedbackConsentService;
    if (service == null || !mounted) return;

    final accepted = await CloudFeedbackConsentDialog.show(
      context,
      barrierDismissible: true,
    );
    if (!mounted) return;

    if (accepted == true) {
      await service.setStatus(CloudFeedbackConsentStatus.accepted);
    } else if (accepted == false) {
      await service.setStatus(CloudFeedbackConsentStatus.declined);
    }
    // accepted == null（用户关闭弹窗）：不改变状态

    if (mounted) setState(() {});
  }

  /// P2-Web-v1.0 第一批：用户第一次点击"生成专属疗愈方案"时，若 LLM 同意状态
  /// 仍为 unknown，先弹出 LLM 同意弹窗请用户选择；选择后继续原本跳转流程。
  /// 若已选择过（accepted / declined）或服务未装配，直接跳转。
  Future<void> _goAnalyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();

    // 首次触发解析时检查 AI 解析偏好
    final service = llmConsentService;
    if (service != null && service.needsPrompt && mounted) {
      await _showConsentDialog(firstTime: true);
      if (!mounted) return;
    }

    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AnalysisScreen(moodText: text)));
  }

  /// P4 新方向第一批：进入「把困惑写成一首歌」新流程。
  /// 与"生成专属疗愈方案"（快速模式）并列，作为新主流程的入口。
  /// 不依赖 LLM 同意状态（页面内部任何失败都走 fallback，不阻塞用户）。
  Future<void> _goComfortLyrics() async {
    FocusScope.of(context).unfocus();
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ComfortLyricsScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CenteredPageScaffold(
      backgroundGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.bgBlue, AppColors.bgBase],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 品牌区：呼吸光晕 + 图标
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const BreathingHalo(color: AppColors.lavender, size: 180),
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.teal.withValues(alpha: 0.9),
                        AppColors.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '心弦',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w400,
              letterSpacing: 8,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '自然语言驱动的疗愈音乐陪伴',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 28),

          // ── P4 前端结构调整第一批：首页双主线结构 ──
          // 第一主线：把困惑写成一首歌（产品新主线，卡片突出）
          // 第二主线：快速舒缓一下（原情绪配乐流程，朴素区域）
          // 两条路径并列，让用户一进入首页就能清楚选择。

          // ── 第一主入口：把困惑写成一首歌 ──
          // 用带边框的卡片突出，lavender 色调与 ComfortLyricsScreen 生成按钮呼应。
          _PrimaryEntryCard(
            icon: Icons.lyrics_rounded,
            title: '把困惑写成一首歌',
            subtitle: '说说最近卡住你的事，让它先变成一段温和的歌词。',
            buttonText: '开始写歌',
            onTap: _goComfortLyrics,
          ),

          const SizedBox(height: 18),

          // ── 第二主入口：快速舒缓一下 ──
          // 朴素区域（无卡片背景），保留原有心境输入 + 示例 + 分析流程。
          // 视觉权重低于第一主线，但不抢戏，保证可达性。
          const Text(
            '快速舒缓一下',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '不想多说也可以，直接生成一段适合现在的舒缓音乐方案。',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          MoodInputField(controller: _controller, focusNode: _focus),

          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ex in _examples)
                _ExampleChip(
                  label: ex,
                  onTap: () {
                    _controller.text = ex;
                    _controller.selection = TextSelection.collapsed(
                      offset: ex.length,
                    );
                  },
                ),
            ],
          ),

          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _hasText ? _goAnalyze : null,
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '快速生成方案',
                style: TextStyle(fontSize: 16, letterSpacing: 1),
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 14),
          Text(
            _footerText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          // P2-Web-v1.0 第四批：首页底部只保留"查看历史记录"和"设置"两个入口。
          // 解析设置 / 云端采集 / 隐私政策 / 关于心弦 统一收纳进设置弹窗，
          // 让首屏聚焦"输入心境 → 生成音乐方案"主路径。
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
                icon: const Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                label: const Text(
                  '查看历史记录',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              TextButton.icon(
                onPressed: _showSettingsDialog,
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                label: const Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 版本号小字：纯 Text，不可点击。
          // P2-Web-v1.0 第四批：版本号入口移至"设置 → 关于心弦"。
          Text(
            AppVersion.shortLine,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              letterSpacing: 0.3,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// P2-Web-v1.0 第四批：统一设置弹窗。
  /// 收纳 AI 解析设置 / 云端反馈采集 / 隐私政策 / 关于心弦 四个入口，
  /// 复用原有逻辑，不新增隐私/AI/云端反馈代码路径。
  ///
  /// P2-Web-v1.0 第四批 fix1 修复：
  /// - footer 不再用 `DialogButtonBar(children:[FilledButton])`（单 child 时
  ///   `Row` 主轴无限宽，`FilledButton` 的 `minimumSize: Size.fromHeight(44)`
  ///   触发 `BoxConstraints forces an infinite width` 异常，导致弹窗内容不可见），
  ///   改为 `Align(alignment: centerRight, child: FilledButton)`，由 `Align` 提供有限约束。
  /// - 子入口点击改为 `Navigator.pop()` 后用 `Future.microtask` 打开目标弹窗/页面，
  ///   避免在 dialog builder 调用栈内叠加新 dialog 触发布局异常。
  Future<void> _showSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ResponsiveDialogContainer(
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '设置',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        footer: Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('关闭'),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SettingsTile(
              icon: Icons.tune_rounded,
              title: 'AI 解析设置',
              subtitle: _settingsLabel,
              onTap: () {
                Navigator.of(dialogContext).pop();
                Future.microtask(() => _showConsentDialog(firstTime: false));
              },
            ),
            _SettingsTile(
              icon: Icons.cloud_outlined,
              title: '云端反馈采集',
              subtitle: _cloudFeedbackLabel,
              onTap: () {
                Navigator.of(dialogContext).pop();
                Future.microtask(_showCloudFeedbackConsentDialog);
              },
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: '隐私政策',
              onTap: () {
                Navigator.of(dialogContext).pop();
                Future.microtask(() {
                  if (!mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  );
                });
              },
            ),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: '关于心弦',
              subtitle: AppVersion.versionName,
              onTap: () {
                Navigator.of(dialogContext).pop();
                Future.microtask(() {
                  if (!mounted) return;
                  showDialog<void>(
                    context: context,
                    builder: (_) => const _AboutDialog(),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "关于"对话框：展示版本号、里程碑、部署平台、API 模式、本地存储状态。
class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    return ResponsiveDialogContainer(
      title: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '关于心弦',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      footer: Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('关闭'),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AboutInfoRow(label: '应用名称', value: AppVersion.appName),
          _AboutInfoRow(label: '当前版本', value: AppVersion.versionName),
          _AboutInfoRow(label: '里程碑阶段', value: AppVersion.milestone),
          _AboutInfoRow(label: '构建标签', value: AppVersion.buildLabel),
          _AboutInfoRow(label: '构建日期', value: AppVersion.buildDate),
          _AboutInfoRow(label: '部署平台', value: AppVersion.deployTarget),
          const Divider(height: 24, color: AppColors.cardBorder),
          _AboutInfoRow(label: 'API 模式', value: _apiModeLabel),
          _AboutInfoRow(label: 'AI 解析状态', value: _consentLabel),
          _AboutInfoRow(label: '本地存储状态', value: _storageLabel),
        ],
      ),
    );
  }

  /// API 模式：gateway（LLM + Mock 自动 fallback）或 mock（纯本地）。
  String get _apiModeLabel =>
      moodAnalyzerGateway != null ? 'gateway（LLM + 本地 fallback）' : 'mock（纯本地）';

  /// AI 解析同意状态。
  String get _consentLabel {
    final service = llmConsentService;
    if (service == null) return '未装配（mock）';
    switch (service.status) {
      case LlmConsentStatus.accepted:
        return '已同意 AI 解析';
      case LlmConsentStatus.declined:
        return '仅使用本地解析';
      case LlmConsentStatus.unknown:
        return '未选择（首次未弹窗）';
    }
  }

  /// 本地存储状态：综合 SharedPreferences / Web localStorage fallback / mock。
  String get _storageLabel {
    final prefsOk = sharedPrefsReady;
    final webFallback = webLocalStorageFallback;
    if (prefsOk == null) {
      return '未启动装配';
    }
    if (prefsOk) {
      return 'SharedPreferences 可用';
    }
    if (webFallback == true) {
      return 'Web localStorage fallback';
    }
    return '不可用（回退内存态）';
  }
}

/// "关于"对话框中的"标签：值"行。
class _AboutInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _AboutInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置弹窗中的列表项：图标 + 标题 + 副标题 + 右侧箭头，点击触发回调。
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// P4 前端结构调整第一批：第一主入口卡片「把困惑写成一首歌」。
///
/// 视觉权重高于第二主线（快速舒缓），用带边框的卡片 + lavender 色调突出。
/// 卡片为单层结构（内部不再嵌套卡片），避免卡片套卡片。
///
/// 文案规范：不医疗化 / 不玄学化，文字用实色（无渐变 / 无 ShaderMask）。
/// 按钮和图标保持静态（无浮动 / 呼吸动画），符合可读性与可点击性约束。
class _PrimaryEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  const _PrimaryEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.lavender.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.lavender.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题行：图标 + 标题
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lavender.withValues(alpha: 0.22),
                ),
                child: Icon(icon, size: 20, color: AppColors.tealDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 副文案
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          // 主按钮：lavender 色调，与 ComfortLyricsScreen 生成按钮呼应
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                buttonText,
                style: const TextStyle(fontSize: 15, letterSpacing: 1),
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppColors.lavender.withValues(alpha: 0.9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 首页示例心境 chip：纯实色文字，无 M3 表面着色 / 无渐变 / 无 ShaderMask。
///
/// 用 `Material` + `InkWell` + `Container` 手写，避免 `ActionChip` 在
/// Material 3 下的 surface tint / tonal 渲染导致文字看起来有深浅渐变。
/// 文字颜色固定为 [AppColors.chipLabelText]（#5B7088），背景固定浅蓝白实色。
class _ExampleChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExampleChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEEF4FA),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          // minHeight 44 保证 chip 在移动端不会被字体缩放撑得过高，
          // 同时提供稳定的可点击高度；不设 maxWidth，保留 Wrap 多 chip 换行布局。
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.chipLabelText,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
