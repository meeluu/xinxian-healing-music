import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/screens/feedback_screen.dart';
import 'package:xinxian_healing_music/widgets/param_chip.dart';

/// 播放页：使用 just_audio 播放本地音频。
///
/// Web 端浏览器有自动播放限制，因此只在用户点击播放按钮时调用 play()，
/// 该调用发生在用户手势中，可正常触发播放。
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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _visualizer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _player.setAudioSource(AudioSource.asset(widget.plan.audioAsset));
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
    final theme = Theme.of(context);
    final plan = widget.plan;
    return Scaffold(
      appBar: AppBar(title: const Text('疗愈播放'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 模板标题
                Text(
                  plan.templateName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.guidance,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),

                // 可视化 + 播放按钮
                _Visualizer(
                  controller: _visualizer,
                  color: theme.colorScheme.primary,
                  child: _PlayButton(
                    loading: _loading,
                    error: _error != null,
                    player: _player,
                    onTap: _toggle,
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  )
                else
                  Text(
                    '点击按钮开始播放（浏览器需用户手势触发）',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // 进度条 + 时长
                _ProgressSection(
                  player: _player,
                  fmt: _fmt,
                  enabled: _error == null,
                ),

                const SizedBox(height: 28),

                // 参数 chips
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ParamChip(
                      label: 'BPM',
                      value: '${plan.bpm}',
                      icon: Icons.favorite_rounded,
                    ),
                    ParamChip(
                      label: '频率',
                      value: plan.frequency,
                      icon: Icons.graphic_eq_rounded,
                    ),
                    ParamChip(
                      label: '脑波',
                      value: plan.brainwave,
                      icon: Icons.waves_rounded,
                    ),
                    ParamChip(
                      label: '乐器',
                      value: plan.instruments.join(' / '),
                      icon: Icons.music_note_rounded,
                    ),
                    ParamChip(
                      label: '噪声层',
                      value: plan.noiseLayer,
                      icon: Icons.cloud_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedbackScreen(plan: plan),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rate_review_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('完成体验，去反馈'),
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
        ),
      ),
    );
  }
}

/// 呼吸光圈 + 中间播放按钮。
class _Visualizer extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final Widget child;

  const _Visualizer({
    required this.controller,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // 外圈
              Container(
                width: 200 + t * 40,
                height: 200 + t * 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.15 + (1 - t) * 0.25),
                    width: 1.5,
                  ),
                ),
              ),
              // 中圈
              Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.35),
                      color.withValues(alpha: 0.08),
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

/// 播放/暂停/重播按钮，跟随 playerStateStream 切换图标。
class _PlayButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final completed = state?.processingState == ProcessingState.completed;
        final disabled = error;
        IconData icon;
        if (completed) {
          icon = Icons.replay_rounded;
        } else if (playing) {
          icon = Icons.pause_rounded;
        } else {
          icon = Icons.play_arrow_rounded;
        }
        return IconButton.filled(
          onPressed: disabled ? null : onTap,
          icon: Icon(icon, size: 40),
          iconSize: 40,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            minimumSize: const Size(80, 80),
          ),
        );
      },
    );
  }
}

/// 进度条 + 当前时间 / 总时长。
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
    final theme = Theme.of(context);
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
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      Text(
                        totalMs > 0 ? fmt(total) : '--:--',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
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
