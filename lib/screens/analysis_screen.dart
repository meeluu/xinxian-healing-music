import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_pipeline_factory.dart';
import 'package:xinxian_healing_music/screens/plan_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// 解析动画页：柔和呼吸 + 扩散波纹，模拟"情绪被缓慢接住"。
/// 1.8s 后跳转方案页。
class AnalysisScreen extends StatefulWidget {
  final String moodText;
  const AnalysisScreen({super.key, required this.moodText});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  final List<String> _lines = ['正在聆听你的心声…', '解析情绪画像…', '匹配音乐参数…', '生成疗愈方案…'];
  int _lineIndex = 0;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    Future(() async {
      for (var i = 0; i < _lines.length; i++) {
        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        setState(() => _lineIndex = i);
      }
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      final plan = await mockPipeline.run(widget.moodText);
      if (!mounted) return;
      // 会话开始：plan 产出后记录 moodText + plan 快照
      mockSessionRecorder.begin(
        sessionId: plan.sessionId,
        moodText: widget.moodText,
        plan: plan,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PlanScreen(moodText: widget.moodText, plan: plan),
        ),
      );
    });
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CenteredPageScaffold(
      backgroundGradient: RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [AppColors.bgBlue, AppColors.bgBase],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 呼吸圆 + 扩散波纹
          SizedBox(
            width: 260,
            height: 260,
            child: AnimatedBuilder(
              animation: _breath,
              builder: (context, _) {
                final t = _breath.value; // 0..1..0
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // 外层波纹（随呼吸扩散、淡出）
                    _ripple(t, baseSize: 150, phase: 0.0),
                    _ripple(t, baseSize: 150, phase: 0.33),
                    _ripple(t, baseSize: 150, phase: 0.66),
                    // 中心呼吸圆
                    Opacity(
                      opacity: 0.65 + t * 0.35,
                      child: Transform.scale(
                        scale: 0.86 + t * 0.14,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.55),
                                AppColors.teal.withValues(alpha: 0.25),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 40,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.spa_rounded,
                            size: 54,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 40),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              _lines[_lineIndex],
              key: ValueKey(_lineIndex),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单圈扩散波纹：根据呼吸进度 t 与相位 phase 计算半径与透明度。
  Widget _ripple(double t, {required double baseSize, required double phase}) {
    final p = (t + phase) % 1.0; // 0..1
    final size = baseSize + p * 110;
    final opacity = (1 - p) * 0.35;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: opacity),
          width: 1.2,
        ),
      ),
    );
  }
}
