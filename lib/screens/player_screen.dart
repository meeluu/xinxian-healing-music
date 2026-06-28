import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/feedback_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/utils/audio_asset_uri.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';
import 'package:xinxian_healing_music/widgets/param_chip.dart';

/// 播放页：使用 just_audio 播放本地音频，浅色疗愈风。
///
/// 播放时呼吸可视化缓慢起伏，暂停时动画停止；按钮点击有轻微缩放反馈。
/// Web 端浏览器自动播放限制：只在用户点击播放按钮时调用 play()。
class PlayerScreen extends StatefulWidget {
  final HealingMusicPlan plan;
  final String moodText;

  const PlayerScreen({super.key, required this.plan, required this.moodText});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _visualizer;
  StreamSubscription<PlayerState>? _stateSub;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _visualizer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    // 播放状态驱动可视化：播放时起伏，暂停/完成时停止
    _stateSub = _player.playerStateStream.listen((state) {
      if (state.playing) {
        if (!_visualizer.isAnimating) _visualizer.repeat(reverse: true);
      } else {
        if (_visualizer.isAnimating) _visualizer.stop();
      }
    });
    // 延迟到首帧绘制后再加载音频：
    // 路由转场期间不与音频加载（setAudioSource 会触发浏览器拉取/解码音频）
    // 竞争主线程，避免进入播放页时掉帧卡顿。首帧先用 _loading 态渲染完整 UI。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initAudio();
    });
  }

  Future<void> _initAudio() async {
    try {
      // 统一调用 AudioAssetUriResolver：
      // Web 下用 AudioSource.uri 指向 assets/<key>，避免 just_audio 的
      // AudioSource.asset 在 Flutter Web 报 "asset does not exist"。
      // 非 Web 下继续用 AudioSource.asset 走 AssetBundle。
      await _player.setAudioSource(
        AudioAssetUriResolver.resolveAudioSource(widget.plan.audio.assetPath),
      );
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '音频加载失败：$e';
      });
    }
  }

  Future<void> _toggle() async {
    if (_loading || _error != null) return;
    final state = _player.playerState;
    if (state.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      await _player.play();
    } else if (state.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  @override
  void dispose() {
    // 上报聆听进度到会话记录器（在释放播放器前读取 position）
    sessionRecorder.updateListening(widget.plan.sessionId, _player.position);
    _stateSub?.cancel();
    _player.dispose();
    _visualizer.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return CenteredPageScaffold(
      appBar: AppBar(title: const Text('疗愈播放')),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            plan.templateName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            plan.guidance,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          // M6：显示当前播放音频名（不暴露文件路径）
          if (plan.audio.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '当前音频：${plan.audio.title}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
          const SizedBox(height: 32),

          // 可视化 + 播放按钮
          // RepaintBoundary 隔离播放可视化动画，避免动画期间整页重绘。
          RepaintBoundary(
            child: _Visualizer(
              controller: _visualizer,
              child: _PlayButton(
                loading: _loading,
                error: _error != null,
                player: _player,
                onTap: _toggle,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.apricotDeep,
              ),
            )
          else
            const Text(
              '点击按钮开始播放（浏览器需用户手势触发）',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),

          const SizedBox(height: 24),

          // 进度条 + 时长（柔和蓝绿）
          _ProgressSection(player: _player, fmt: _fmt, enabled: _error == null),

          const SizedBox(height: 28),

          // 参数 chips
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              ParamChip(
                label: 'BPM',
                value: '${plan.features.bpm}',
                icon: Icons.favorite_rounded,
              ),
              ParamChip(
                label: '频率',
                value: plan.features.frequency,
                icon: Icons.graphic_eq_rounded,
              ),
              ParamChip(
                label: '脑波',
                value: plan.features.brainwave,
                icon: Icons.waves_rounded,
              ),
              ParamChip(
                label: '乐器',
                value: plan.features.instruments.join(' / '),
                icon: Icons.music_note_rounded,
              ),
              ParamChip(
                label: '噪声层',
                value: plan.features.noiseLayer,
                icon: Icons.cloud_rounded,
              ),
            ],
          ),

          const SizedBox(height: 32),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FeedbackScreen(plan: plan)),
              );
            },
            icon: const Icon(Icons.rate_review_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('完成体验，去反馈'),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFFE6F1F9),
              foregroundColor: AppColors.primaryDeep,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 呼吸光圈 + 中间播放按钮。控制器由外部传入（播放状态联动）。
class _Visualizer extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _Visualizer({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value; // 播放时 0..1..0；暂停时定格
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 210 + t * 36,
                height: 210 + t * 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(
                      alpha: 0.12 + (1 - t) * 0.18,
                    ),
                    width: 1.5,
                  ),
                ),
              ),
              Container(
                width: 176,
                height: 176,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.30 + t * 0.10),
                      AppColors.teal.withValues(alpha: 0.10),
                    ],
                  ),
                ),
              ),
              child,
            ],
          );
        },
      ),
    );
  }
}

/// 播放/暂停/重播按钮，跟随 playerStateStream 切换图标，点击有缩放反馈。
class _PlayButton extends StatefulWidget {
  final bool loading;
  final bool error;
  final AudioPlayer player;
  final VoidCallback onTap;

  const _PlayButton({
    required this.loading,
    required this.error,
    required this.player,
    required this.onTap,
  });

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primary,
        ),
      );
    }
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: StreamBuilder<PlayerState>(
          stream: widget.player.playerStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final playing = state?.playing ?? false;
            final completed =
                state?.processingState == ProcessingState.completed;
            final disabled = widget.error;
            IconData icon;
            if (completed) {
              icon = Icons.replay_rounded;
            } else if (playing) {
              icon = Icons.pause_rounded;
            } else {
              icon = Icons.play_arrow_rounded;
            }
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.teal, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: disabled ? null : widget.onTap,
                icon: Icon(icon, size: 40, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  highlightColor: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 进度条 + 当前时间 / 总时长。柔和蓝绿。
class _ProgressSection extends StatelessWidget {
  final AudioPlayer player;
  final String Function(Duration) fmt;
  final bool enabled;

  const _ProgressSection({
    required this.player,
    required this.fmt,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durSnap) {
        final total = durSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final totalMs = total.inMilliseconds.toDouble();
            double value = 0;
            if (totalMs > 0) {
              value = (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
            }
            return Column(
              children: [
                Slider(
                  value: value,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.cardBorder,
                  thumbColor: AppColors.primary,
                  onChanged: enabled && totalMs > 0
                      ? (v) {
                          player.seek(
                            Duration(milliseconds: (v * totalMs).round()),
                          );
                        }
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        fmt(pos),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        totalMs > 0 ? fmt(total) : '--:--',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
