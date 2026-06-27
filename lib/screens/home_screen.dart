import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/screens/analysis_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/breathing_halo.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';
import 'package:xinxian_healing_music/widgets/mood_input_field.dart';

/// 首页：输入当前心境描述。
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
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
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
          const Text(
            'Demo 版本 · 全部参数由本地模板生成，不接真实 AI',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }
}
