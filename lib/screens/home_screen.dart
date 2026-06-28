import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/config/app_version.dart';
import 'package:xinxian_healing_music/pipeline/llm/llm_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/analysis_screen.dart';
import 'package:xinxian_healing_music/screens/history_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/breathing_halo.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';
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

    // 首次进入：若同意状态为 unknown，弹窗请用户选择。
    // 用 addPostFrameCallback 避免在 build 阶段触发 dialog。
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptConsent());
  }

  void _maybePromptConsent() {
    final service = llmConsentService;
    if (!mounted || service == null) return;
    if (!service.needsPrompt) return;
    _showConsentDialog(firstTime: true);
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
      return 'Demo 版本 · 全部参数由本地模板生成';
    }
    switch (service.status) {
      case LlmConsentStatus.accepted:
        return '已开启 AI 解析 · 心境文本将发送到 AI 服务进行情绪解析';
      case LlmConsentStatus.declined:
        return '仅使用本地解析 · 全部参数由本地模板生成';
      case LlmConsentStatus.unknown:
        return 'Demo 版本 · 全部参数由本地模板生成';
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

  void _goAnalyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AnalysisScreen(moodText: text)));
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
          const SizedBox(height: 36),

          // 输入区
          const Text(
            '描述你此刻的心境',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          MoodInputField(controller: _controller, focusNode: _focus),

          const SizedBox(height: 16),
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

          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _hasText ? _goAnalyze : null,
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '生成专属疗愈方案',
                style: TextStyle(fontSize: 16, letterSpacing: 1),
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
          // 历史记录 + 解析设置 并排入口
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _showConsentDialog(firstTime: false),
                icon: const Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                label: Text(
                  _settingsLabel,
                  style: const TextStyle(
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
          // M6.1 修复：移除 TextButton 包裹，避免 Material hover 状态参与
          // mouse tracking。TextButton 的 Material hover 在 Flutter Web debug
          // 下可能与 mouse_tracker 交互触发断言。改为纯 Text 不参与 hit test，
          // 彻底规避。About 弹窗入口暂停，后续可在 AppBar info 图标恢复。
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

  /// "关于"对话框：展示完整版本信息 + 运行时状态。
  ///
  /// 运行时状态从全局 [sharedPrefsReady] / [webLocalStorageFallback] /
  /// [moodAnalyzerGateway] / [llmConsentService] 读取，反映 bootstrap 装配结果，
  /// 方便线上排查"为什么历史记录丢了 / 为什么没有 AI 解析"等问题。
  /// "关于"对话框入口（M6.1 暂停：版本号改为纯 Text 后不再触发）。
  /// 保留代码以便后续在 AppBar info 图标恢复入口。
  // ignore: unused_element
  void _showAboutDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(context: context, builder: (_) => const _AboutDialog());
    });
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
      footer: DialogButtonBar(
        children: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('关闭'),
          ),
        ],
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
