import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:xinxian_healing_music/data/audio_asset_catalog.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/feedback_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/utils/audio_asset_uri.dart';
import 'package:xinxian_healing_music/utils/recommendation_reason.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';
import 'package:xinxian_healing_music/widgets/sleep_timer_button.dart';

/// 本地播放模式（P4-playback-experience-2）。
///
/// - [singlePlay] 单曲播放：当前曲播完即停（LoopMode.off + 单一源）
/// - [singleLoop] 单曲循环：当前曲播完重播（LoopMode.one + 单一源）
/// - [listLoop] 列表循环：列表末尾回到第一首（LoopMode.all + 同类全部）
/// - [sequential] 顺序播放：列表末尾停止（LoopMode.off + 同类全部）
///
/// 播放列表按当前 targetState 过滤 [AudioAssetCatalog.assets]：
/// 当前每类 1 首，未来每类添加更多曲目后列表模式自动生效。
enum PlayMode { singlePlay, singleLoop, listLoop, sequential }

extension PlayModeX on PlayMode {
  String get label => const {
    PlayMode.singlePlay: '单曲播放',
    PlayMode.singleLoop: '单曲循环',
    PlayMode.listLoop: '列表循环',
    PlayMode.sequential: '顺序播放',
  }[this]!;

  IconData get icon => const {
    PlayMode.singlePlay: Icons.play_circle_outline_rounded,
    PlayMode.singleLoop: Icons.repeat_one_rounded,
    PlayMode.listLoop: Icons.repeat_rounded,
    PlayMode.sequential: Icons.low_priority_rounded,
  }[this]!;

  /// 映射到 just_audio LoopMode。
  /// 顺序播放用 LoopMode.off（列表播完停止）；单曲播放也用 off（单一源播完停止）。
  LoopMode get loopMode => const {
    PlayMode.singlePlay: LoopMode.off,
    PlayMode.singleLoop: LoopMode.one,
    PlayMode.listLoop: LoopMode.all,
    PlayMode.sequential: LoopMode.off,
  }[this]!;

  /// 是否使用列表音频源（ConcatenatingAudioSource）。
  /// 单曲模式用单一源，避免播完自动进下一曲。
  bool get useList => this == PlayMode.listLoop || this == PlayMode.sequential;
}

/// 播放页：使用 just_audio 播放本地音频，浅色疗愈风。
///
/// 播放时呼吸可视化缓慢起伏，暂停时动画停止；按钮点击有轻微缩放反馈。
/// Web 端浏览器自动播放限制：只在用户点击播放按钮时调用 play()。
///
/// P4-playback-experience-2：支持 4 种播放模式（单曲播放 / 单曲循环 /
/// 列表循环 / 顺序播放），默认单曲循环。定时关闭开启后强制单曲循环，
/// 保证音乐持续播放到定时时间结束，结束/取消后恢复原模式。
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
  bool _error = false;
  // P2-Web-v1.0 第三批：播放完成后展示反馈 CTA，引导用户记录感受。
  // 重播（seek(0) + play）时重置为 false。
  bool _completed = false;

  // ─── P4-playback-experience-2：播放模式与播放列表状态 ───
  //
  // 当前播放模式（默认单曲循环，最符合舒缓陪伴场景）。
  PlayMode _playMode = PlayMode.singleLoop;

  /// 定时强制循环前的用户选择（null 表示未在强制态）。
  /// 倒计时期间强制单曲循环，结束/取消后恢复 [_playMode]。
  PlayMode? _preForceMode;

  /// 模式切换中防抖（避免连续点击导致音频源重建冲突）。
  bool _switchingMode = false;

  /// 当前 targetState 同类曲目列表（用于列表循环 / 顺序播放）。
  /// 当前每类 1 首，未来扩展后自动生效。
  List<AudioAsset> _playlistTracks = const [];

  /// 当前曲在 [_playlistTracks] 中的索引。
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _visualizer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    // 播放状态驱动可视化：播放时起伏，暂停/完成时停止
    // P2-Web-v1.0 第三批：同时跟踪 completed 状态以联动反馈 CTA。
    _stateSub = _player.playerStateStream.listen((state) {
      if (state.playing) {
        if (!_visualizer.isAnimating) _visualizer.repeat(reverse: true);
      } else {
        if (_visualizer.isAnimating) _visualizer.stop();
      }
      final completed = state.processingState == ProcessingState.completed;
      if (completed != _completed) {
        setState(() => _completed = completed);
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
    // 构建同类曲目播放列表：按当前 targetState 过滤 AudioAssetCatalog.assets
    final targetState = widget.plan.mood.targetState;
    final matched = AudioAssetCatalog.assets
        .where((a) => a.targetStates.contains(targetState))
        .toList();
    _playlistTracks = matched.isNotEmpty
        ? matched
        : [AudioAssetCatalog.fallback];
    // 按 assetPath 定位当前曲（plan.audio 是 ProcessedAudio，与 AudioAsset 不同类型）
    final currentAssetPath = widget.plan.audio.assetPath;
    _currentIndex = _playlistTracks.indexWhere(
      (a) => a.assetPath == currentAssetPath,
    );
    if (_currentIndex < 0) _currentIndex = 0;

    try {
      await _applyPlayMode(_playMode, initialPosition: Duration.zero);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      // 不暴露内部异常字符串给用户，统一显示友好文案
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  /// 根据 [mode] 构建音频源列表。
  ///
  /// - 单曲模式（singlePlay / singleLoop）：仅当前曲（1 个 AudioSource）
  /// - 列表模式（listLoop / sequential）：同类全部（多个 AudioSource）
  ///
  /// 返回 `List<AudioSource>`，统一交给 [AudioPlayer.setAudioSources] 装载。
  /// 单曲模式传 1 个元素的列表，列表模式传同类全部。
  List<AudioSource> _buildAudioSources(PlayMode mode) {
    final resolver = AudioAssetUriResolver.resolveAudioSource;
    if (!mode.useList) {
      return [resolver(_playlistTracks[_currentIndex].assetPath)];
    }
    return _playlistTracks.map((a) => resolver(a.assetPath)).toList();
  }

  /// 应用播放模式：构建音频源 + setAudioSources（保留进度）+ 设 LoopMode。
  ///
  /// [initialPosition] 用于模式切换时保留播放进度。
  /// 列表模式下通过 [initialIndex] 定位到当前曲。
  Future<void> _applyPlayMode(
    PlayMode mode, {
    Duration? initialPosition,
  }) async {
    final sources = _buildAudioSources(mode);
    // setAudioSources 替代已废弃的 ConcatenatingAudioSource：
    // - 单曲模式：1 个元素 + initialIndex=0
    // - 列表模式：同类全部 + initialIndex=当前曲索引
    await _player.setAudioSources(
      sources,
      initialIndex: mode.useList ? _currentIndex : 0,
      initialPosition: initialPosition,
    );
    await _player.setLoopMode(mode.loopMode);
  }

  /// 用户切换播放模式。
  ///
  /// - 防抖：模式相同或切换中直接返回。
  /// - 定时强制态：只更新 [_preForceMode] 记录，实际源保持单曲循环，
  ///   强制态结束后再应用新模式。
  /// - 正常态：捕获进度 + 播放状态 → 重建源 → 恢复播放。
  Future<void> _setPlayMode(PlayMode newMode) async {
    if (newMode == _playMode || _switchingMode) return;

    // 定时强制态：记录用户选择，待强制态结束后恢复
    if (_preForceMode != null) {
      setState(() => _preForceMode = newMode);
      return;
    }

    setState(() => _switchingMode = true);
    try {
      final pos = _player.position;
      final wasPlaying = _player.playing;
      await _applyPlayMode(newMode, initialPosition: pos);
      if (wasPlaying) await _player.play();
      if (!mounted) return;
      setState(() {
        _playMode = newMode;
        _switchingMode = false;
        _completed = false;
      });
    } catch (_) {
      // 切换失败不卡死，回滚切换态
      if (!mounted) return;
      setState(() => _switchingMode = false);
    }
  }

  /// 定时关闭强制循环：进入倒计时时强制单曲循环，保证音乐持续播放。
  void _onForceLoopStart() {
    if (_preForceMode != null) return; // 已在强制态
    final wasPlaying = _player.playing;
    setState(() => _preForceMode = _playMode);
    // 强制切到单曲循环（保留进度）
    _applyPlayMode(PlayMode.singleLoop, initialPosition: _player.position)
        .then((_) {
          if (wasPlaying && !_player.playing) {
            _player.play().catchError((_) {});
          }
        })
        .catchError((_) {});
  }

  /// 定时关闭结束：恢复用户原播放模式。
  void _onForceLoopEnd() {
    final restore = _preForceMode;
    _preForceMode = null;
    if (restore == null) return;
    if (restore == _playMode) return; // 本就是单曲循环，无需切换
    final wasPlaying = _player.playing;
    _applyPlayMode(restore, initialPosition: _player.position)
        .then((_) {
          if (wasPlaying && !_player.playing) {
            _player.play().catchError((_) {});
          }
        })
        .catchError((_) {});
    if (mounted) setState(() {});
  }

  /// 重试加载音频：重置错误态后重新初始化。
  Future<void> _retry() async {
    setState(() {
      _error = false;
      _loading = true;
    });
    await _initAudio();
  }

  Future<void> _toggle() async {
    if (_loading || _error) return;
    final state = _player.playerState;
    try {
      if (state.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
        await _player.play();
        // 重播时收回 CTA，回到播放中状态
        if (_completed) setState(() => _completed = false);
      } else if (state.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      // 播放过程中出错：标记错误态，提供重试入口
      if (!mounted) return;
      setState(() => _error = true);
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

  /// P4-playback-experience-2：播放模式按钮 + 定时关闭（并排）。
  ///
  /// - 播放模式：PopupMenuButton 切换单曲播放 / 单曲循环 / 列表循环 / 顺序播放
  /// - 定时关闭：SleepTimerButton，接入强制循环回调
  /// - 定时强制态时显示"定时中"小标，提示用户当前为强制循环
  Widget _buildPlaybackControls() {
    final inForce = _preForceMode != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 播放模式按钮
        PopupMenuButton<PlayMode>(
          onSelected: _setPlayMode,
          tooltip: '播放模式',
          itemBuilder: (context) => [
            for (final m in PlayMode.values)
              PopupMenuItem(
                value: m,
                child: Row(
                  children: [
                    Icon(m.icon, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(m.label),
                    if (m == _playMode && !inForce) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: inForce
                  ? AppColors.lavender.withValues(alpha: 0.12)
                  : const Color(0xFFE6F1F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: inForce
                    ? AppColors.lavender.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  inForce ? Icons.repeat_one_rounded : _playMode.icon,
                  size: 14,
                  color: inForce ? AppColors.lavender : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  inForce ? '定时中·循环' : _playMode.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: inForce ? AppColors.lavender : AppColors.primaryDeep,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 定时关闭
        SleepTimerButton(
          player: _player,
          onForceLoopStart: _onForceLoopStart,
          onForceLoopEnd: _onForceLoopEnd,
        ),
      ],
    );
  }

  /// P2-Web-v1.0 第二批 fix1：播放页只展示主要音乐目标的简短文案，
  /// 不再默认铺开 BPM / 频率 / 脑波 / 乐器 / 噪声层等技术参数。
  /// 与方案页共用 goalLabelFor，保证两页说法一致。
  String get _goalLabel => goalLabelFor(widget.plan.mood.targetState);

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
                error: _error,
                player: _player,
                onTap: _toggle,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_error)
            Column(
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
                  '请稍后重试',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('重试加载'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(160, 40),
                    foregroundColor: AppColors.primaryDeep,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            )
          else if (_completed)
            // P2-Web-v1.0 第三批：播放完成后的温和反馈 CTA。
            // 不打断现有 replay 按钮，只在原"点击中央按钮开始播放"位置
            // 自然引导用户记录感受。移动端按钮高度固定避免挤压播放控制区。
            Column(
              children: [
                const Text(
                  '听完这段了吗？记录一下感受',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedbackScreen(plan: plan),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('写反馈'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(140, 40),
                    foregroundColor: AppColors.primaryDeep,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            )
          else
            const Text(
              '点击中央按钮开始播放',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),

          const SizedBox(height: 24),

          // 进度条 + 时长（柔和蓝绿）
          _ProgressSection(player: _player, fmt: _fmt, enabled: !_error),

          // P4-playback-experience-2：播放模式选择 + 定时关闭（并排，轻量）
          if (!_error) ...[
            const SizedBox(height: 12),
            _buildPlaybackControls(),
          ],

          const SizedBox(height: 28),

          // P2-Web-v1.0 第二批：播放页不再默认展示 BPM / 频率 / 脑波 / 乐器 / 噪声层
          // 等技术参数 chip，改为只展示主要音乐目标的简短文案。
          // 技术参数可在方案页"查看音乐参数"折叠区查看。
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F1F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.spa_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  _goalLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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
///
/// 拖动逻辑（M6.1 修复）：
/// - `onChanged`：只更新临时 [_dragValue]，不调用 `player.seek`，
///   避免拖动时频繁 seek 导致 Web 端 30 分钟音频被重置回 0。
/// - `onChangeEnd`：拖动结束才调用一次 `player.seek`，目标位置 clamp
///   在 `0..total` 之间。
/// - 拖动期间 slider 显示 [_dragValue]，不跟随 positionStream，避免抖动。
/// - seek 后保持原播放状态（just_audio 的 seek 不会改变 playing/paused）。
/// - duration 未加载完成时禁用拖动（`onChanged: null`）。
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
  /// 拖动期间的临时 slider 值（0..1）。
  /// null 表示未在拖动，slider 跟随 positionStream。
  /// 非 null 表示用户正在拖动，slider 显示临时值，不跟随 positionStream。
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
            // 拖动期间显示临时值，避免 slider 抖动回旧位置
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
                          // 拖动结束才调用 seek（只一次），避免频繁 seek
                          // 导致 Web 端音频重置回 0。
                          final targetMs = (v * totalMs).round().clamp(
                            0,
                            total.inMilliseconds,
                          );
                          widget.player.seek(Duration(milliseconds: targetMs));
                          // 清除临时值，让 slider 重新跟随 positionStream。
                          // just_audio 的 seek 是异步的，positionStream 会在
                          // 几十~几百 ms 内更新到目标位置。seek 不会改变
                          // playing/paused 状态，原状态自动保持。
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
