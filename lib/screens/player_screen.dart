import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:xinxian_healing_music/data/audio_asset_catalog.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/feedback_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/utils/audio_seek_readiness.dart';
import 'package:xinxian_healing_music/utils/audio_asset_uri.dart';
import 'package:xinxian_healing_music/utils/play_button_decision.dart';
import 'package:xinxian_healing_music/utils/recommendation_reason.dart';
import 'package:xinxian_healing_music/utils/seek_progress_guard.dart';
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
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  bool _loading = true;
  bool _error = false;
  bool _audioReadyForSeek = false;
  Duration? _lastDurationForSeek;
  ProcessingState _lastProcessingStateForSeek = ProcessingState.idle;
  bool _loggedFirstDuration = false;
  int _positionDebugCount = 0;
  int _lastDebugPositionSecond = -1;
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
      final previousState = _lastProcessingStateForSeek;
      _lastProcessingStateForSeek = state.processingState;
      if (previousState != state.processingState) {
        _debugFirstSeek(
          'player-state',
          processingState: state.processingState,
          playing: state.playing,
        );
      }
      if (state.playing) {
        if (!_visualizer.isAnimating) _visualizer.repeat(reverse: true);
      } else {
        if (_visualizer.isAnimating) _visualizer.stop();
      }
      final completed = state.processingState == ProcessingState.completed;
      final readyForSeek = AudioSeekReadiness.canSeek(
        duration: _lastDurationForSeek,
        processingState: state.processingState,
      );
      if (completed != _completed || readyForSeek != _audioReadyForSeek) {
        setState(() {
          _completed = completed;
          _audioReadyForSeek = readyForSeek;
        });
        _debugFirstSeek(
          'ready-update-from-state',
          duration: _lastDurationForSeek,
          processingState: state.processingState,
          playing: state.playing,
          readyForSeek: readyForSeek,
        );
      }
    });
    _durationSub = _player.durationStream.listen((duration) {
      _lastDurationForSeek = duration;
      if (!_loggedFirstDuration &&
          duration != null &&
          duration > Duration.zero) {
        _loggedFirstDuration = true;
        _debugFirstSeek(
          'duration-first-non-null',
          duration: duration,
          processingState: _player.playerState.processingState,
          playing: _player.playing,
        );
      }
      final readyForSeek = AudioSeekReadiness.canSeek(
        duration: duration,
        processingState: _player.playerState.processingState,
      );
      if (readyForSeek != _audioReadyForSeek && mounted) {
        setState(() => _audioReadyForSeek = readyForSeek);
        _debugFirstSeek(
          'ready-update-from-duration',
          duration: duration,
          processingState: _player.playerState.processingState,
          playing: _player.playing,
          readyForSeek: readyForSeek,
        );
      }
    });
    _positionSub = _player.positionStream.listen((position) {
      final second = position.inSeconds;
      final shouldLog =
          _positionDebugCount < 6 ||
          (second != _lastDebugPositionSecond && second <= 3) ||
          (!_audioReadyForSeek && position > Duration.zero);
      if (shouldLog) {
        _positionDebugCount += 1;
        _lastDebugPositionSecond = second;
        _debugFirstSeek(
          'position-stream',
          position: position,
          duration: _player.duration,
          buffered: _player.bufferedPosition,
          processingState: _player.playerState.processingState,
          playing: _player.playing,
          readyForSeek: _audioReadyForSeek,
        );
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
    _debugFirstSeek(
      'init-start',
      position: _player.position,
      duration: _player.duration,
      buffered: _player.bufferedPosition,
      processingState: _player.playerState.processingState,
      playing: _player.playing,
      readyForSeek: _audioReadyForSeek,
    );
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
      _lastDurationForSeek = _player.duration;
      final readyForSeek = AudioSeekReadiness.canSeek(
        duration: _lastDurationForSeek,
        processingState: _player.playerState.processingState,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _audioReadyForSeek = readyForSeek;
      });
      _debugFirstSeek(
        'init-complete',
        position: _player.position,
        duration: _lastDurationForSeek,
        buffered: _player.bufferedPosition,
        processingState: _player.playerState.processingState,
        playing: _player.playing,
        readyForSeek: readyForSeek,
      );
    } catch (err) {
      _debugFirstSeek('init-error', error: err);
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
    if (mounted && _audioReadyForSeek) {
      setState(() => _audioReadyForSeek = false);
    }
    _debugFirstSeek(
      'set-audio-sources-before',
      sourceCount: sources.length,
      mode: mode.name,
      position: _player.position,
      duration: _player.duration,
      buffered: _player.bufferedPosition,
      processingState: _player.playerState.processingState,
      playing: _player.playing,
    );
    // setAudioSources 替代已废弃的 ConcatenatingAudioSource：
    // - 单曲模式：1 个元素 + initialIndex=0
    // - 列表模式：同类全部 + initialIndex=当前曲索引
    await _player.setAudioSources(
      sources,
      initialIndex: mode.useList ? _currentIndex : 0,
      initialPosition: initialPosition,
    );
    _debugFirstSeek(
      'set-audio-sources-after',
      sourceCount: sources.length,
      mode: mode.name,
      position: _player.position,
      duration: _player.duration,
      buffered: _player.bufferedPosition,
      processingState: _player.playerState.processingState,
      playing: _player.playing,
    );
    await _player.setLoopMode(mode.loopMode);
    _lastDurationForSeek = _player.duration;
    final readyForSeek = AudioSeekReadiness.canSeek(
      duration: _lastDurationForSeek,
      processingState: _player.playerState.processingState,
    );
    if (mounted && readyForSeek != _audioReadyForSeek) {
      setState(() => _audioReadyForSeek = readyForSeek);
      _debugFirstSeek(
        'ready-update-after-set-source',
        position: _player.position,
        duration: _lastDurationForSeek,
        buffered: _player.bufferedPosition,
        processingState: _player.playerState.processingState,
        playing: _player.playing,
        readyForSeek: readyForSeek,
      );
    }
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
      _audioReadyForSeek = false;
    });
    _lastDurationForSeek = null;
    _loggedFirstDuration = false;
    await _initAudio();
  }

  Future<void> _toggle() async {
    if (_loading || _error) return;
    final state = _player.playerState;
    // P4-player-seek-bugfix-1：用纯函数决定动作，把"自然播完→点击重播"和
    // "用户手动 seek 后点击继续"两条路径分开。
    // completedFlag=_completed：用户手动拖动进度条时会被 _onUserSeek 清空，
    // 因此 completed 状态下若 _completed=false，点击播放只 play() 不 seek(0)，
    // 避免拖到中间后点击播放被强制回到 0 秒。
    final action = decidePlayButtonAction(
      processingState: state.processingState,
      playing: state.playing,
      completedFlag: _completed,
    );
    try {
      switch (action) {
        case PlayButtonAction.replayFromStart:
          await _player.seek(Duration.zero);
          await _player.play();
          if (_completed) setState(() => _completed = false);
          break;
        case PlayButtonAction.play:
          await _player.play();
          // completed 但用户已 seek（_completed 已清空）：收回 CTA，从 seek 位置继续
          if (_completed) setState(() => _completed = false);
          break;
        case PlayButtonAction.pause:
          await _player.pause();
          break;
      }
    } catch (_) {
      // 播放过程中出错：标记错误态，提供重试入口
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  /// 用户手动拖动进度条 seek 后的回调（P4-player-seek-bugfix-1）。
  ///
  /// 清除 [_completed]，使下次点击播放按钮走 [PlayButtonAction.play]（从 seek
  /// 位置继续），而非 [PlayButtonAction.replayFromStart]（seek(0) 重头播）。
  /// 即使 just_audio 的 processingState 仍残留 completed，_completed=false 也能
  /// 阻止 _toggle() 进入 seek(Duration.zero) 分支。
  void _onUserSeek() {
    if (_completed) setState(() => _completed = false);
  }

  @override
  void dispose() {
    // 上报聆听进度到会话记录器（在释放播放器前读取 position）
    sessionRecorder.updateListening(widget.plan.sessionId, _player.position);
    _stateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _player.dispose();
    _visualizer.dispose();
    super.dispose();
  }

  void _debugFirstSeek(
    String phase, {
    Duration? position,
    Duration? duration,
    Duration? buffered,
    ProcessingState? processingState,
    bool? playing,
    bool? readyForSeek,
    int? sourceCount,
    String? mode,
    Object? error,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[DEBUG-FIRST-SEEK] $phase '
      'position=${position?.inMilliseconds}ms '
      'duration=${duration?.inMilliseconds}ms '
      'buffered=${buffered?.inMilliseconds}ms '
      'processingState=$processingState '
      'playing=$playing '
      'readyForSeek=$readyForSeek '
      'sourceCount=$sourceCount '
      'mode=$mode '
      'error=${error == null ? 'none' : error.runtimeType}',
    );
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
          // P4-player-seek-bugfix-1：onSeekStart 在用户拖动结束时清空 _completed，
          // 避免下次点击播放走 seek(0) 重播分支。
          _ProgressSection(
            player: _player,
            fmt: _fmt,
            enabled: !_error,
            readyForSeek: _audioReadyForSeek,
            onSeekStart: _onUserSeek,
          ),

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
/// 拖动逻辑（M6.1 修复 + P4-player-seek-bugfix-2 防回弹）：
/// - `onChanged`：只更新临时 [_dragValue]，不调用 `player.seek`，
///   避免拖动时频繁 seek 导致 Web 端 30 分钟音频被重置回 0。
/// - `onChangeEnd`：拖动结束才调用一次 `player.seek`，目标位置 clamp
///   在 `0..total` 之间；同时触发 [onSeekStart] 让宿主清空完成态。
/// - 拖动期间 slider 显示 [_dragValue]，不跟随 positionStream，避免抖动。
/// - **P4-player-seek-bugfix-2**：先设置 [_pendingSeek]，再 await `player.seek`。
///   只有 positionStream / seek 后 position 确认到达目标，或 3 秒兜底窗口到期，
///   才清空 pending。避免 Web 首次 seek 尚未完成时被 positionStream 的 0 拉回。
/// - seek 后显式恢复 seek 前播放状态：播放中继续播放，暂停中保持暂停。
/// - duration 未加载完成时禁用拖动（`onChanged: null`）。
class _ProgressSection extends StatefulWidget {
  final AudioPlayer player;
  final String Function(Duration) fmt;
  final bool enabled;
  final bool readyForSeek;

  /// 用户拖动结束 seek 后的回调（P4-player-seek-bugfix-1）。
  /// 宿主用以清空 _completed，避免下次点击播放走 seek(0) 重播分支。
  final VoidCallback? onSeekStart;

  const _ProgressSection({
    required this.player,
    required this.fmt,
    required this.enabled,
    required this.readyForSeek,
    this.onSeekStart,
  });

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  /// 拖动期间的临时 slider 值（0..1）。
  /// null 表示未在拖动，slider 跟随 positionStream / [_pendingSeek]。
  /// 非 null 表示用户正在拖动，slider 显示临时值，不跟随 positionStream。
  double? _dragValue;

  /// 拖动结束后的 seek 目标值（0..1）。
  ///
  /// P4-player-seek-bugfix-1：在 positionStream 确认到达目标前，slider 持续
  /// 显示该值，避免因 seek 异步未完成、positionStream 仍发射旧位置（首次进入
  /// 时旧位置≈0）导致 slider 视觉回弹到 0 秒。
  double? _pendingSeek;

  /// 当前 pending seek 的真实目标时间，用于 seek 完成后和 positionStream 校验。
  Duration? _pendingSeekTarget;

  /// seek 兜底计时器：若 positionStream 长时间未确认到达目标（如 seek 失败、
  /// 音频未播放时 positionStream 不活跃），3 秒后才交还控制权给 positionStream。
  Timer? _pendingSeekGuard;

  /// 单调递增 token，避免较早 seek 的异步回调清掉较晚 seek 的 pending 状态。
  int _seekToken = 0;
  bool? _lastLoggedCanDrag;
  bool? _lastLoggedReadyForSeek;
  ProcessingState? _lastLoggedSliderState;
  int? _lastLoggedSliderDurationMs;
  double? _lastLoggedDragValue;

  @override
  void dispose() {
    _pendingSeekGuard?.cancel();
    super.dispose();
  }

  /// positionStream 当前位置是否已追上 [_pendingSeek] 目标（容差内）。
  ///
  /// 容差取 `总时长 2%` 与 `300ms` 的较大者，兼容正向/反向 seek：
  /// - 正向 seek（如 0:10→1:20）：position 从小变大，到达 1:20 附近即清空
  /// - 反向 seek（如 2:00→0:30）：position 从大变小，到达 0:30 附近即清空
  bool _positionReachedTarget(Duration pos, Duration total) {
    final target = _pendingSeekTarget;
    if (target == null) return false;
    return SeekProgressGuard.positionReachedTarget(
      position: pos,
      target: target,
      total: total,
    );
  }

  void _debugSeek(
    String phase, {
    Duration? target,
    Duration? before,
    Duration? after,
    Duration? total,
    bool? playing,
    ProcessingState? processingState,
    Object? error,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[DEBUG-SEEK-2] $phase '
      'target=${target?.inMilliseconds}ms '
      'before=${before?.inMilliseconds}ms '
      'after=${after?.inMilliseconds}ms '
      'duration=${total?.inMilliseconds}ms '
      'playing=$playing '
      'processingState=$processingState '
      'error=${error == null ? 'none' : error.runtimeType}',
    );
  }

  void _debugFirstSeek(
    String phase, {
    double? value,
    bool? canDrag,
    Duration? target,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    ProcessingState? processingState,
    bool? playing,
    bool? readyForSeek,
    bool? loadingOrBuffering,
    Object? error,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[DEBUG-FIRST-SEEK] $phase '
      'value=$value '
      'canDrag=$canDrag '
      'target=${target?.inMilliseconds}ms '
      'position=${position?.inMilliseconds}ms '
      'duration=${duration?.inMilliseconds}ms '
      'buffered=${buffered?.inMilliseconds}ms '
      'processingState=$processingState '
      'playing=$playing '
      'readyForSeek=$readyForSeek '
      'loadingOrBuffering=$loadingOrBuffering '
      'error=${error == null ? 'none' : error.runtimeType}',
    );
  }

  void _debugSliderEnabledIfChanged({
    required bool canDrag,
    required Duration total,
  }) {
    final state = widget.player.playerState.processingState;
    final durationMs = total.inMilliseconds;
    if (_lastLoggedCanDrag == canDrag &&
        _lastLoggedReadyForSeek == widget.readyForSeek &&
        _lastLoggedSliderState == state &&
        _lastLoggedSliderDurationMs == durationMs) {
      return;
    }
    _lastLoggedCanDrag = canDrag;
    _lastLoggedReadyForSeek = widget.readyForSeek;
    _lastLoggedSliderState = state;
    _lastLoggedSliderDurationMs = durationMs;
    _debugFirstSeek(
      'slider-enabled',
      canDrag: canDrag,
      position: widget.player.position,
      duration: total,
      buffered: widget.player.bufferedPosition,
      processingState: state,
      playing: widget.player.playing,
      readyForSeek: widget.readyForSeek,
      loadingOrBuffering:
          state == ProcessingState.loading ||
          state == ProcessingState.buffering,
    );
  }

  void _clearPendingSeek() {
    _pendingSeekGuard?.cancel();
    _pendingSeekGuard = null;
    _pendingSeek = null;
    _pendingSeekTarget = null;
  }

  void _schedulePendingFallback({
    required int token,
    required Duration target,
    required Duration total,
  }) {
    _pendingSeekGuard?.cancel();
    _pendingSeekGuard = Timer(SeekProgressGuard.pendingSeekFallbackDelay, () {
      if (!mounted || token != _seekToken) return;
      final current = widget.player.position;
      final reached = SeekProgressGuard.positionReachedTarget(
        position: current,
        target: target,
        total: total,
      );
      _debugSeek(
        reached ? 'fallback-reached' : 'fallback-release',
        target: target,
        after: current,
        total: total,
        playing: widget.player.playing,
        processingState: widget.player.playerState.processingState,
      );
      if (mounted) {
        setState(_clearPendingSeek);
      }
    });
  }

  void _schedulePostSeekCheck({
    required int token,
    required Duration target,
    required Duration total,
  }) {
    Timer(SeekProgressGuard.postSeekCheckDelay, () {
      if (!mounted || token != _seekToken || _pendingSeekTarget == null) {
        return;
      }
      final current = widget.player.position;
      if (!SeekProgressGuard.positionReachedTarget(
        position: current,
        target: target,
        total: total,
      )) {
        _debugSeek(
          'post-check-pending',
          target: target,
          after: current,
          total: total,
          playing: widget.player.playing,
          processingState: widget.player.playerState.processingState,
        );
        return;
      }
      _debugSeek(
        'post-check-reached',
        target: target,
        after: current,
        total: total,
        playing: widget.player.playing,
        processingState: widget.player.playerState.processingState,
      );
      setState(_clearPendingSeek);
    });
  }

  Future<void> _handleSeekEnd(double value, Duration total) async {
    final target = SeekProgressGuard.targetFromSliderValue(
      value: value,
      total: total,
    );
    final token = ++_seekToken;
    final wasPlaying = widget.player.playing;
    final before = widget.player.position;
    final beforeState = widget.player.playerState.processingState;

    setState(() {
      _dragValue = null;
      _pendingSeek = value.clamp(0.0, 1.0);
      _pendingSeekTarget = target;
    });
    widget.onSeekStart?.call();
    _schedulePendingFallback(token: token, target: target, total: total);
    _debugSeek(
      'start',
      target: target,
      before: before,
      total: total,
      playing: wasPlaying,
      processingState: beforeState,
    );
    _debugFirstSeek(
      'seek-before',
      value: value,
      target: target,
      position: before,
      duration: total,
      buffered: widget.player.bufferedPosition,
      processingState: beforeState,
      playing: wasPlaying,
      readyForSeek: widget.readyForSeek,
      loadingOrBuffering:
          beforeState == ProcessingState.loading ||
          beforeState == ProcessingState.buffering,
    );

    try {
      await widget.player.seek(target);
      if (!mounted || token != _seekToken) return;

      if (wasPlaying && !widget.player.playing) {
        await widget.player.play();
      } else if (!wasPlaying && widget.player.playing) {
        await widget.player.pause();
      }

      if (!mounted || token != _seekToken) return;
      final after = widget.player.position;
      final afterState = widget.player.playerState.processingState;
      final reached = SeekProgressGuard.positionReachedTarget(
        position: after,
        target: target,
        total: total,
      );
      _debugSeek(
        reached ? 'complete-reached' : 'complete-pending',
        target: target,
        before: before,
        after: after,
        total: total,
        playing: widget.player.playing,
        processingState: afterState,
      );
      _debugFirstSeek(
        'seek-after',
        value: value,
        target: target,
        position: after,
        duration: total,
        buffered: widget.player.bufferedPosition,
        processingState: afterState,
        playing: widget.player.playing,
        readyForSeek: widget.readyForSeek,
        loadingOrBuffering:
            afterState == ProcessingState.loading ||
            afterState == ProcessingState.buffering,
      );
      if (reached) {
        setState(_clearPendingSeek);
      } else {
        _schedulePostSeekCheck(token: token, target: target, total: total);
      }
    } catch (err) {
      _debugSeek(
        'error',
        target: target,
        before: before,
        after: widget.player.position,
        total: total,
        playing: widget.player.playing,
        processingState: widget.player.playerState.processingState,
        error: err,
      );
      final state = widget.player.playerState.processingState;
      _debugFirstSeek(
        'seek-error',
        value: value,
        target: target,
        position: widget.player.position,
        duration: total,
        buffered: widget.player.bufferedPosition,
        processingState: state,
        playing: widget.player.playing,
        readyForSeek: widget.readyForSeek,
        loadingOrBuffering:
            state == ProcessingState.loading ||
            state == ProcessingState.buffering,
        error: err,
      );
      // Keep pending visible until the fallback window expires; that avoids an
      // immediate snap to a stale 0 position while the browser audio element
      // may still settle after reporting an error.
    }
  }

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
            // P4-player-seek-bugfix-1：positionStream 到达目标后清空 _pendingSeek，
            // 交还控制权给 positionStream（用 if 避免 build 中无谓 setState）。
            if (_pendingSeek != null && _positionReachedTarget(pos, total)) {
              _clearPendingSeek();
            }
            // 优先级：拖动中 > seek 待确认 > positionStream 实时值
            final displayValue = _dragValue ?? _pendingSeek ?? value;
            final canDrag =
                widget.enabled && widget.readyForSeek && totalMs > 0;
            _debugSliderEnabledIfChanged(canDrag: canDrag, total: total);
            return Column(
              children: [
                Slider(
                  value: displayValue,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.cardBorder,
                  thumbColor: AppColors.primary,
                  onChangeStart: canDrag
                      ? (v) {
                          _lastLoggedDragValue = v;
                          _debugFirstSeek(
                            'slider-change-start',
                            value: v,
                            canDrag: canDrag,
                            position: widget.player.position,
                            duration: total,
                            buffered: widget.player.bufferedPosition,
                            processingState:
                                widget.player.playerState.processingState,
                            playing: widget.player.playing,
                            readyForSeek: widget.readyForSeek,
                          );
                        }
                      : null,
                  onChanged: canDrag
                      ? (v) {
                          if (_lastLoggedDragValue == null ||
                              (v - _lastLoggedDragValue!).abs() >= 0.05) {
                            _lastLoggedDragValue = v;
                            _debugFirstSeek(
                              'slider-changed',
                              value: v,
                              canDrag: canDrag,
                              position: widget.player.position,
                              duration: total,
                              buffered: widget.player.bufferedPosition,
                              processingState:
                                  widget.player.playerState.processingState,
                              playing: widget.player.playing,
                              readyForSeek: widget.readyForSeek,
                            );
                          }
                          setState(() => _dragValue = v);
                        }
                      : null,
                  onChangeEnd: canDrag
                      ? (v) {
                          _debugFirstSeek(
                            'slider-change-end',
                            value: v,
                            canDrag: canDrag,
                            position: widget.player.position,
                            duration: total,
                            buffered: widget.player.bufferedPosition,
                            processingState:
                                widget.player.playerState.processingState,
                            playing: widget.player.playing,
                            readyForSeek: widget.readyForSeek,
                          );
                          _handleSeekEnd(v, total);
                        }
                      : null,
                ),
                if (widget.enabled && !widget.readyForSeek) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '音频正在准备中…',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
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
