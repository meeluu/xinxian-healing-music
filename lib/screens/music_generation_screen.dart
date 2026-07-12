import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/pipeline/music_generation/music_generation_models.dart';
import 'package:xinxian_healing_music/screens/player_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// AI 音乐生成进度页（P4.3 mock 阶段）。
///
/// 用户在方案页点击「生成专属音乐（实验）」后进入本页。
///
/// P4-mock-1-fix2 修复：
/// - 移除 Spacer（在 SingleChildScrollView 无界高度下抛布局异常导致空白）
/// - 简化为纯 3 秒 Future.delayed 本地模拟，不调用 createJob/pollUntilComplete
/// - _phase 初始即 generating，首帧立即显示生成中 UI
/// - 关闭按钮用 maybePop，不检查任何状态，永远可点击
///
/// 实验功能说明：
/// - 明确标注「实验功能」
/// - 不承诺治疗效果
/// - 失败时温和提示，不吓人
/// - 预置音频始终可用，零中断
class MusicGenerationScreen extends StatefulWidget {
  final HealingMusicPlan plan;
  final String moodText;

  const MusicGenerationScreen({
    super.key,
    required this.plan,
    required this.moodText,
  });

  @override
  State<MusicGenerationScreen> createState() => _MusicGenerationScreenState();
}

class _MusicGenerationScreenState extends State<MusicGenerationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;

  /// 当前生成阶段（初始就是 generating，首帧立即显示生成中 UI）
  MusicGenerationPhase _phase = MusicGenerationPhase.generating;

  /// 是否正在处理中
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _breathController.repeat(reverse: true);
    // 延迟到首帧绘制后再启动模拟生成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startMockGeneration();
    });
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  /// 本地模拟生成（最简实现，3 秒后成功）
  ///
  /// P4-mock-1-fix2：不再调用 createJob/pollUntilComplete，
  /// 纯 Future.delayed 模拟，避免任何网络/HTTP/解析异常。
  /// P4.4 接入真实 API 时再恢复 service 调用。
  Future<void> _startMockGeneration() async {
    try {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      setState(() {
        _phase = MusicGenerationPhase.succeeded;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = MusicGenerationPhase.failed;
        _busy = false;
      });
    }
  }

  /// 用户点击按钮后进入播放器（传入完整 plan，不传空数据）
  void _navigateToPlayer() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen(plan: widget.plan, moodText: widget.moodText),
      ),
    );
  }

  /// 用户点击关闭按钮（永远可用，不检查任何状态）
  void _cancelGeneration() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return CenteredPageScaffold(
      appBar: AppBar(
        title: const Text('生成专属音乐'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _cancelGeneration,
          tooltip: '取消生成',
        ),
      ),
      animateEnter: false,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 实验功能标签（所有状态都显示）
          _buildExperimentBadge(),
          const SizedBox(height: 40),

          // 呼吸圆动画（所有状态都显示）
          _BreathingCircle(controller: _breathController, active: _busy),
          const SizedBox(height: 36),

          // —— 根据状态显示不同文案和按钮 ——
          if (_busy) ...[
            const Text(
              '正在准备专属音乐片段',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '这是实验功能，当前使用 mock 生成流程',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // 进度条（indeterminate，简单稳定，不需要更新 progress 值）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          ] else if (_phase == MusicGenerationPhase.succeeded) ...[
            const Text(
              '专属音乐片段已准备好',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '这是实验功能，当前使用 mock 生成流程',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // 注意：Column 中嵌套全宽 Button 需要 CrossAxisAlignment.stretch
            // 但外层 Column 是 center，这里用 Align 包一层
            Align(
              alignment: Alignment.center,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _navigateToPlayer,
                    icon: const Icon(Icons.play_circle_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '播放这段音乐',
                        style: TextStyle(fontSize: 15, letterSpacing: 0.5),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _navigateToPlayer,
                    icon: const Icon(Icons.music_note_rounded, size: 18),
                    label: const Text('改用预置音乐', style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDeep,
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // failed / fallback
            const Text(
              '这次专属生成没有完成，已为你切换到合适的预置音乐。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.center,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _navigateToPlayer,
                    icon: const Icon(Icons.play_circle_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '播放预置音乐',
                        style: TextStyle(fontSize: 15, letterSpacing: 0.5),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          // 底部说明（所有状态都显示）
          const Text(
            '当前为实验阶段的 mock 生成，未接入真实 AI 音乐生成 API。\n生成结果与预置音频相同，仅用于验证链路。',
            textAlign: TextAlign.center,
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

  /// 实验功能标签
  Widget _buildExperimentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF4E3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF4C7A1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_rounded, size: 14, color: AppColors.apricotDeep),
          const SizedBox(width: 6),
          Text(
            '实验功能',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.apricotDeep,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 呼吸圆动画组件（复用 AnalysisScreen 呼吸圆风格）。
class _BreathingCircle extends StatelessWidget {
  final AnimationController controller;
  final bool active;

  const _BreathingCircle({required this.controller, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = controller.value;
        // 呼吸缩放：0.85 - 1.15
        final scale = active ? (0.85 + value * 0.30) : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.3),
              AppColors.primary.withValues(alpha: 0.1),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              active ? Icons.auto_awesome_rounded : Icons.check_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }
}
