import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_pipeline_factory.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/home_screen.dart';
import 'package:xinxian_healing_music/screens/plan_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// 解析动画页：柔和呼吸 + 扩散波纹，模拟"情绪被缓慢接住"。
///
/// 流程：
/// 1. 播放 4 行文案动画（约 2.25s）
/// 2. 动画播完后若方案尚未返回，显示加载指示器
/// 3. 方案生成成功 → 跳转方案页
/// 4. 方案生成失败 → 显示友好错误态（重试 / 返回首页），不暴露内部异常
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

  /// 动画播完后、方案尚未返回时为 true，UI 显示加载指示器。
  bool _loadingPlan = false;

  /// pipeline.run 抛异常后为 true，UI 切换为错误态。
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _startFlow();
  }

  /// 启动解析流程：播放动画 → 加载方案 → 跳转 / 错误态。
  ///
  /// 任何异常都 catch，不让用户卡在动画页。错误态提供"重试"和"返回首页"。
  void _startFlow() {
    Future(() async {
      for (var i = 0; i < _lines.length; i++) {
        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        setState(() => _lineIndex = i);
      }
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      // 动画播完，方案还在生成：显示加载指示器
      setState(() => _loadingPlan = true);
      try {
        final plan = await activePipeline.run(widget.moodText);
        if (!mounted) return;
        // 会话开始：plan 产出后记录 moodText + plan 快照
        sessionRecorder.begin(
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
      } catch (_) {
        // 任何异常都不让用户卡在动画页：显示友好错误态
        if (!mounted) return;
        setState(() {
          _loadingPlan = false;
          _error = true;
        });
      }
    });
  }

  /// 重试：重置状态后重新走完整流程。
  void _retry() {
    setState(() {
      _error = false;
      _loadingPlan = false;
      _lineIndex = 0;
    });
    _startFlow();
  }

  /// 返回首页：清空路由栈回到 HomeScreen。
  void _backHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
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
      child: _error ? _buildError() : _buildProgress(),
    );
  }

  /// 正常 + 加载态：呼吸圆 + 文案 / 加载指示器。
  ///
  /// 响应式尺寸：根据可用宽高较小者的 55% 计算呼吸圆区域，限制 180-260。
  /// 小屏 / 横屏时自动缩小，避免溢出；内容超出时可滚动。
  Widget _buildProgress() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 600.0;
        final availW = constraints.maxWidth;
        final minDim = availW < availH ? availW : availH;
        // 呼吸圆区域：屏幕较小维度的 55%，限制 180-260
        final area = (minDim * 0.55).clamp(180.0, 260.0);
        // 内部元素按比例缩放（基于 260 基准）
        final rippleBase = area * 0.577; // 150/260
        final rippleExpansion = area * 0.423; // 110/260
        final coreSize = area * 0.5; // 130/260
        final iconSize = area * 0.208; // 54/260
        final blurRadius = area * 0.154; // 40/260

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: availH),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 呼吸圆 + 扩散波纹
                  SizedBox(
                    width: area,
                    height: area,
                    child: AnimatedBuilder(
                      animation: _breath,
                      builder: (context, _) {
                        final t = _breath.value; // 0..1..0
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // 外层波纹（随呼吸扩散、淡出）
                            _ripple(
                              t,
                              baseSize: rippleBase,
                              expansion: rippleExpansion,
                              phase: 0.0,
                            ),
                            _ripple(
                              t,
                              baseSize: rippleBase,
                              expansion: rippleExpansion,
                              phase: 0.33,
                            ),
                            _ripple(
                              t,
                              baseSize: rippleBase,
                              expansion: rippleExpansion,
                              phase: 0.66,
                            ),
                            // 中心呼吸圆
                            Opacity(
                              opacity: 0.65 + t * 0.35,
                              child: Transform.scale(
                                scale: 0.86 + t * 0.14,
                                child: Container(
                                  width: coreSize,
                                  height: coreSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.primary.withValues(
                                          alpha: 0.55,
                                        ),
                                        AppColors.teal.withValues(alpha: 0.25),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: blurRadius,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.spa_rounded,
                                    size: iconSize,
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
                  // 动画播完后显示加载指示器，否则显示当前文案
                  if (_loadingPlan)
                    Column(
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '还在整理适合你的音乐方案…',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    )
                  else
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
            ),
          ),
        );
      },
    );
  }

  /// 错误态：友好提示 + 重试 + 返回首页，不暴露内部异常。
  Widget _buildError() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.apricot.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppColors.apricotDeep,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '生成方案失败，请稍后重试',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('重试', style: TextStyle(fontSize: 15)),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(200, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _backHome,
            child: const Text(
              '返回首页',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 单圈扩散波纹：根据呼吸进度 t 与相位 phase 计算半径与透明度。
  Widget _ripple(
    double t, {
    required double baseSize,
    required double expansion,
    required double phase,
  }) {
    final p = (t + phase) % 1.0; // 0..1
    final size = baseSize + p * expansion;
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
