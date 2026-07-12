import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/config/app_version.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/pipeline/music_generation/music_generation_models.dart';
import 'package:xinxian_healing_music/pipeline/music_generation/music_generation_service.dart';
import 'package:xinxian_healing_music/screens/player_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// AI 音乐生成进度页（P4.3 mock 阶段）。
///
/// 用户在方案页点击「生成专属音乐（实验）」后进入本页。
/// 流程：创建 job → 轮询状态 → 成功进入播放器 / 失败 fallback 预置音频。
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
  late final MusicGenerationService _service;
  late final AnimationController _breathController;

  /// 当前生成阶段
  MusicGenerationPhase _phase = MusicGenerationPhase.queued;

  /// 进度百分比（0-100）
  int _progress = 5;

  /// 是否正在处理中
  bool _busy = true;

  /// 错误/状态提示文案（可选，覆盖 phase.displayText）
  String? _hint;

  @override
  void initState() {
    super.initState();
    _service = MusicGenerationService();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _breathController.repeat(reverse: true);
    // 延迟到首帧绘制后再发起请求
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startGeneration();
    });
  }

  @override
  void dispose() {
    _breathController.dispose();
    _service.dispose();
    super.dispose();
  }

  /// 启动生成流程
  Future<void> _startGeneration() async {
    final plan = widget.plan;

    // 构造请求（不上传心境原文）
    final request = MusicGenerationRequest(
      sessionId: plan.sessionId,
      targetState: plan.mood.targetState.name,
      generationPrompt: _extractGenerationPrompt(plan),
      durationSeconds: plan.durationMinutes * 60,
      clientVersion: AppVersion.versionName,
    );

    // 创建 job
    final genResp = await _service.createJob(request);

    if (!genResp.ok || genResp.jobId == null) {
      // 创建失败 → 直接 fallback 到播放器
      if (mounted) {
        setState(() {
          _phase = MusicGenerationPhase.fallback;
          _busy = false;
          _hint = '生成服务暂不可用，已为你切换到预置音乐';
        });
        _navigateToPlayer(delayed: true);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _phase = MusicGenerationPhase.generating;
        _progress = 10;
      });
    }

    // 轮询状态
    final finalStatus = await _service.pollUntilComplete(
      jobId: genResp.jobId!,
      targetState: plan.mood.targetState.name,
      onProgress: (status) {
        if (mounted) {
          setState(() {
            _progress = status.progress;
            if (status.status == 'generating' && _phase != MusicGenerationPhase.generating) {
              _phase = MusicGenerationPhase.generating;
            }
          });
        }
      },
    );

    if (!mounted) return;

    // 处理终态
    if (finalStatus.isSucceeded) {
      setState(() {
        _phase = MusicGenerationPhase.succeeded;
        _progress = 100;
        _busy = false;
      });
      // 短暂展示成功后进入播放器
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) _navigateToPlayer();
    } else {
      setState(() {
        _phase = MusicGenerationPhase.failed;
        _busy = false;
      });
      // 短暂展示失败提示后进入播放器（fallback 预置音频）
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) _navigateToPlayer();
    }
  }

  /// 从 plan 提取 generationPrompt
  ///
  /// M5 的 generationPrompt 存在于 MusicPlanDraft，但 HealingMusicPlan
  /// 聚合根中没有直接暴露。P4.3 mock 阶段使用 features 字段构造简化 prompt。
  /// P4.4 将从 plan 中直接获取完整 generationPrompt。
  String _extractGenerationPrompt(HealingMusicPlan plan) {
    // 构造简化英文 prompt（基于 features）
    final parts = <String>[
      'instrumental ambient music',
      'no vocals, no lyrics',
      plan.features.bpm > 0 ? 'tempo ${plan.features.bpm} BPM' : 'slow tempo',
      plan.features.brainwave.isNotEmpty
          ? plan.features.brainwave
          : 'calm',
      plan.features.harmony.isNotEmpty ? plan.features.harmony : 'gentle harmony',
      if (plan.features.noiseLayer.isNotEmpty) plan.features.noiseLayer,
      '${plan.durationMinutes} minutes',
    ];
    return parts.join(', ');
  }

  /// 进入播放器（播放预置音频）
  void _navigateToPlayer({bool delayed = false}) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          plan: widget.plan,
          moodText: widget.moodText,
        ),
      ),
    );
  }

  /// 用户主动取消
  void _cancelGeneration() {
    _service.dispose();
    if (mounted) {
      Navigator.of(context).pop();
    }
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
          // 实验功能标签
          Container(
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
          ),
          const SizedBox(height: 40),

          // 呼吸圆动画
          _BreathingCircle(
            controller: _breathController,
            active: _busy,
          ),
          const SizedBox(height: 36),

          // 状态文案
          Text(
            _hint ?? _phase.displayText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: _phase == MusicGenerationPhase.failed
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          // 进度条
          if (_busy) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress / 100.0,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_progress%',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],

          // 失败时显示重试/直接播放按钮
          if (_phase == MusicGenerationPhase.failed) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _navigateToPlayer,
              icon: const Icon(Icons.play_circle_rounded),
              label: const Text('直接播放预置音乐'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],

          const Spacer(),

          // 底部说明
          Text(
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
}

/// 呼吸圆动画组件（复用 AnalysisScreen 呼吸圆风格）。
class _BreathingCircle extends StatelessWidget {
  final AnimationController controller;
  final bool active;

  const _BreathingCircle({
    required this.controller,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = controller.value;
        // 呼吸缩放：0.85 - 1.15
        final scale = active ? (0.85 + value * 0.30) : 1.0;
        return Transform.scale(
          scale: scale,
          child: child,
        );
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
