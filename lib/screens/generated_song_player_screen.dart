import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';
import 'package:xinxian_healing_music/widgets/sleep_timer_button.dart';

/// AI 生成歌曲的元数据（P4-playback-experience-2）。
///
/// 由 [ComfortLyricsScreen] 在 /api/generate-music 成功后构造，传给
/// [GeneratedSongPlayerScreen] 做独立播放。当前仅用 [playableUrl] 临时播放，
/// 不依赖 R2，不做历史歌曲 / 分享链接 / 永久保存。
///
/// 字段：
/// - [playableUrl]：可播放 URL（generatedAudioUrl 相对路径或 audioDataUrl base64）
/// - [title]：歌曲标题（按 targetState 本地规则生成）
/// - [comfortInterpretation]："给现在的你"温和解惑文案
/// - [lyricDraft]：歌词草稿（用户可能编辑过）
/// - [targetState]：目标状态（sleep/regulate/soothe/focus/energize，用于 goalLabel）
class GeneratedSongMeta {
  final String playableUrl;
  final String title;
  final String comfortInterpretation;
  final String lyricDraft;
  final String targetState;

  const GeneratedSongMeta({
    required this.playableUrl,
    required this.title,
    required this.comfortInterpretation,
    required this.lyricDraft,
    required this.targetState,
  });
}

/// AI 生成歌曲独立播放页（P4-playback-experience-2）。
///
/// 从「把困惑写成一首歌」生成成功后跳转至此，专门播放这首生成歌曲。
/// 不在歌词页内嵌播放，提供更清晰的播放体验。
///
/// 展示：歌曲标题 / "给现在的你" / 歌词 / 播放暂停 / 进度条 / 当前时间·总时长 /
/// 重新播放 / 返回 / 定时关闭 / 单曲循环开关。
///
/// 音频源：只用 [GeneratedSongMeta.playableUrl] 临时播放（data: URL 或绝对 URL），
/// 不依赖 R2，不做永久保存。
///
/// 失败处理：加载失败显示温和错误提示 + 返回歌词页入口，不白屏 / 不卡死。
///
/// 约束：不暴露 API Key；无医疗化文案；maxWidth 760 居中响应式。
class GeneratedSongPlayerScreen extends StatefulWidget {
  final GeneratedSongMeta meta;

  const GeneratedSongPlayerScreen({super.key, required this.meta});

  @override
  State<GeneratedSongPlayerScreen> createState() =>
      _GeneratedSongPlayerScreenState();
}

class _GeneratedSongPlayerScreenState extends State<GeneratedSongPlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _visualizer;
  StreamSubscription<PlayerState>? _stateSub;

  bool _loading = true;
  bool _error = false;
  bool _completed = false;

  /// 用户选择的循环模式：true=单曲循环（LoopMode.one，默认），
  /// false=单曲播放（LoopMode.off，播完停止）。
  bool _loopEnabled = true;

  /// 定时强制循环前的用户选择（null 表示未在强制态）。
  /// 倒计时期间强制单曲循环，结束/取消后恢复 [_loopEnabled]。
  bool? _preForceLoop;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _visualizer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _stateSub = _player.playerStateStream.listen((state) {
      if (state.playing) {
        if (!_visualizer.isAnimating) _visualizer.repeat(reverse: true);
      } else {
        if (_visualizer.isAnimating) _visualizer.stop();
      }
      final completed = state.processingState == ProcessingState.completed;
      if (completed != _completed) {
        if (mounted) setState(() => _completed = completed);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initAudio();
    });
  }

  Future<void> _initAudio() async {
    try {
      final uri = _resolveUri(widget.meta.playableUrl);
      await _player.setAudioSource(AudioSource.uri(uri));
      // 默认单曲循环，适合舒缓沉浸聆听
      await _player.setLoopMode(_loopEnabled ? LoopMode.one : LoopMode.off);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  /// 解析 playableUrl：
  /// - data: / http: / https: → 直接 Uri.parse
  /// - 相对路径（如 /api/generated-music?key=...）→ Uri.base.resolve
  Uri _resolveUri(String playableUrl) {
    if (playableUrl.startsWith('data:') ||
        playableUrl.startsWith('http://') ||
        playableUrl.startsWith('https://')) {
      return Uri.parse(playableUrl);
    }
    return Uri.base.resolve(playableUrl);
  }

  Future<void> _toggle() async {
    if (_loading || _error) return;
    final state = _player.playerState;
    try {
      if (state.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
        await _player.play();
        if (_completed && mounted) setState(() => _completed = false);
      } else if (state.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  /// 重新播放：从头开始（不扣费，不再次调用 MiniMax）。
  Future<void> _replay() async {
    if (_loading || _error) return;
    try {
      await _player.seek(Duration.zero);
      await _player.play();
      if (_completed && mounted) setState(() => _completed = false);
    } catch (_) {
      // 忽略单次操作异常
    }
  }

  /// 切换单曲循环开关。
  Future<void> _toggleLoop() async {
    if (_loading || _error) return;
    final newLoop = !_loopEnabled;
    setState(() => _loopEnabled = newLoop);
    try {
      await _player.setLoopMode(newLoop ? LoopMode.one : LoopMode.off);
    } catch (_) {
      // 忽略单次操作异常
    }
  }

  /// 定时关闭强制循环：进入倒计时时强制单曲循环。
  void _onForceLoopStart() {
    if (_preForceLoop != null) return; // 已在强制态
    _preForceLoop = _loopEnabled;
    if (!_loopEnabled) {
      setState(() => _loopEnabled = true);
      _player.setLoopMode(LoopMode.one).catchError((_) {});
    }
  }

  /// 定时关闭结束：恢复用户原选择。
  void _onForceLoopEnd() {
    final restore = _preForceLoop;
    _preForceLoop = null;
    if (restore == null) return;
    if (restore != _loopEnabled) {
      setState(() => _loopEnabled = restore);
      _player
          .setLoopMode(restore ? LoopMode.one : LoopMode.off)
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
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
    final meta = widget.meta;
    return CenteredPageScaffold(
      appBar: AppBar(
        title: const Text('AI 生成歌曲'),
        automaticallyImplyLeading: true,
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 歌曲标题
          Text(
            meta.title,
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
            '根据你刚才写下的内容生成，适合现在慢慢听一遍。',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // 可视化 + 播放按钮
          RepaintBoundary(
            child: _Visualizer(
              controller: _visualizer,
              child: _PlayButton(
                loading: _loading,
                error: _error,
                player: _player,
                onTap: _toggle,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 状态行
          if (_error)
            _buildErrorState()
          else if (_completed)
            _buildCompletedHint()
          else
            const Text(
              '点击中央按钮开始播放',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),

          const SizedBox(height: 20),

          // 进度条 + 时长
          _ProgressSection(player: _player, fmt: _fmt, enabled: !_error),

          // 重新播放 + 单曲循环开关
          if (!_error && !_loading) ...[
            const SizedBox(height: 14),
            _buildActionRow(),
          ],

          // 定时关闭
          if (!_error) ...[
            const SizedBox(height: 14),
            Center(
              child: SleepTimerButton(
                player: _player,
                onForceLoopStart: _onForceLoopStart,
                onForceLoopEnd: _onForceLoopEnd,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 给现在的你
          _SectionCard(
            icon: Icons.favorite_border_rounded,
            title: '给现在的你',
            child: SelectableText(
              meta.comfortInterpretation,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.75,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 歌词
          _SectionCard(
            icon: Icons.music_note_rounded,
            title: '歌词',
            child: SelectableText(
              meta.lyricDraft,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 返回歌词页
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('返回歌词页', style: TextStyle(fontSize: 14)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 错误态：温和提示 + 重试 + 返回。
  Widget _buildErrorState() {
    return Column(
      children: [
        const Text(
          '音频暂时无法加载',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.apricotDeep,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '可以稍后再试，或返回歌词页',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _error = false;
              _loading = true;
            });
            _initAudio();
          },
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('重试加载'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(160, 40),
            foregroundColor: AppColors.primaryDeep,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  /// 播放完成提示（单曲播放模式下播完停止时显示）。
  Widget _buildCompletedHint() {
    return const Text(
      '听完了，可以点中央按钮再听一遍',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// 重新播放 + 单曲循环开关。
  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _replay,
            icon: const Icon(Icons.replay_rounded, size: 16),
            label: const Text('重新播放', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleLoop,
            icon: Icon(
              _loopEnabled ? Icons.repeat_one_rounded : Icons.play_circle_outline_rounded,
              size: 16,
              color: _loopEnabled ? AppColors.lavender : AppColors.textMuted,
            ),
            label: Text(
              _loopEnabled ? '单曲循环' : '单曲播放',
              style: TextStyle(
                fontSize: 13,
                color: _loopEnabled ? AppColors.lavender : AppColors.textSecondary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              foregroundColor:
                  _loopEnabled ? AppColors.lavender : AppColors.textSecondary,
              side: BorderSide(
                color: _loopEnabled
                    ? AppColors.lavender.withValues(alpha: 0.5)
                    : AppColors.cardBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 呼吸光圈 + 中间播放按钮（与本地播放页一致的视觉风格）。
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
          final t = controller.value;
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

/// 播放/暂停/重播按钮。
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

/// 进度条 + 当前时间 / 总时长（与本地播放页一致的拖动逻辑）。
class _ProgressSection extends StatefulWidget {
  final AudioPlayer player;
  final String Function(Duration) fmt;
  final bool enabled;

  const _ProgressSection({
    required this.player,
    required this.fmt,
    required this.enabled,
  });

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: widget.player.durationStream,
      builder: (context, durSnap) {
        final total = durSnap.data ?? Duration.zero;
        final totalMs = total.inMilliseconds.toDouble();
        return StreamBuilder<Duration>(
          stream: widget.player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            double value = 0;
            if (totalMs > 0) {
              value = (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
            }
            final displayValue = _dragValue ?? value;
            final canDrag = widget.enabled && totalMs > 0;
            return Column(
              children: [
                Slider(
                  value: displayValue,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.cardBorder,
                  thumbColor: AppColors.primary,
                  onChanged: canDrag
                      ? (v) {
                          setState(() => _dragValue = v);
                        }
                      : null,
                  onChangeEnd: canDrag
                      ? (v) {
                          final targetMs = (v * totalMs).round().clamp(
                                0,
                                total.inMilliseconds,
                              );
                          widget.player.seek(Duration(milliseconds: targetMs));
                          setState(() => _dragValue = null);
                        }
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.fmt(pos),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        totalMs > 0 ? widget.fmt(total) : '--:--',
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

/// 通用小节卡片：图标 + 标题 + 内容。
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
