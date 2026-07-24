import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

/// 定时关闭按钮（P4-conversation-song-flow-1）。
///
/// 自包含 StatefulWidget，接收 [AudioPlayer] 实例，封装全部定时逻辑。
/// 支持：关闭、5/10/15/30 分钟、播放完当前音频。
/// 到时间自动暂停播放；UI 轻量，不挤压播放按钮。
///
/// 定时只控制播放，不影响生成；不新增后台任务；dispose 清理 timer。
///
/// P4-playback-experience-2 新增 [onForceLoopStart] / [onForceLoopEnd] 回调：
/// 进入倒计时模式（5/10/15/30 分钟）时触发 [onForceLoopStart]，让宿主页面
/// 强制切到单曲循环，避免单曲播完后定时未结束时音乐提前停止。
/// 退出倒计时（到时间 / 用户取消 / 切到关闭或本曲结束）时触发 [onForceLoopEnd]，
/// 让宿主恢复用户原本选择的播放模式。
/// `endOfTrack` 模式本身就是"本曲结束停止"，不触发强制循环。
///
/// 使用：
/// ```dart
/// SleepTimerButton(
///   player: _player,
///   onForceLoopStart: _onForceLoopStart,
///   onForceLoopEnd: _onForceLoopEnd,
/// )
/// ```
class SleepTimerButton extends StatefulWidget {
  final AudioPlayer player;

  /// 进入倒计时模式时触发（宿主应强制单曲循环）。
  final VoidCallback? onForceLoopStart;

  /// 退出倒计时模式时触发（宿主应恢复原播放模式）。
  final VoidCallback? onForceLoopEnd;

  const SleepTimerButton({
    super.key,
    required this.player,
    this.onForceLoopStart,
    this.onForceLoopEnd,
  });

  @override
  State<SleepTimerButton> createState() => _SleepTimerButtonState();
}

/// 定时模式。
enum _SleepTimerMode { off, min5, min10, min15, min30, endOfTrack }

class _SleepTimerButtonState extends State<SleepTimerButton> {
  _SleepTimerMode _mode = _SleepTimerMode.off;
  Timer? _timer;
  StreamSubscription<ProcessingState>? _stateSub;

  /// 剩余秒数（仅 minute 模式有效），用于显示倒计时。
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  /// 是否为倒计时模式（5/10/15/30 分钟）。
  /// `off` 和 `endOfTrack` 不算倒计时，不触发强制循环。
  bool _isCountdownMode(_SleepTimerMode m) =>
      m == _SleepTimerMode.min5 ||
      m == _SleepTimerMode.min10 ||
      m == _SleepTimerMode.min15 ||
      m == _SleepTimerMode.min30;

  /// 切换定时模式：取消现有定时，按新模式启动。
  ///
  /// P4-playback-experience-2：在倒计时 ↔ 非倒计时切换时触发强制循环回调。
  void _setMode(_SleepTimerMode mode) {
    final oldMode = _mode;
    final wasCountdown = _isCountdownMode(oldMode);
    final isNewCountdown = _isCountdownMode(mode);

    _timer?.cancel();
    _stateSub?.cancel();
    setState(() {
      _mode = mode;
      _remainingSeconds = 0;
    });

    // 进入倒计时 → 通知宿主强制单曲循环
    if (!wasCountdown && isNewCountdown) {
      widget.onForceLoopStart?.call();
    } else if (wasCountdown && !isNewCountdown) {
      // 退出倒计时 → 通知宿主恢复原模式
      widget.onForceLoopEnd?.call();
    }

    switch (mode) {
      case _SleepTimerMode.off:
        break;
      case _SleepTimerMode.min5:
        _startCountdown(5 * 60);
        break;
      case _SleepTimerMode.min10:
        _startCountdown(10 * 60);
        break;
      case _SleepTimerMode.min15:
        _startCountdown(15 * 60);
        break;
      case _SleepTimerMode.min30:
        _startCountdown(30 * 60);
        break;
      case _SleepTimerMode.endOfTrack:
        _listenEndOfTrack();
        break;
    }
  }

  /// 倒计时模式：每秒减 1，到 0 时暂停播放。
  void _startCountdown(int seconds) {
    _remainingSeconds = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remainingSeconds -= 1);
      if (_remainingSeconds <= 0) {
        t.cancel();
        _onTimerFired();
      }
    });
  }

  /// 本曲结束后关闭：监听 processingStateStream，completed 时暂停。
  void _listenEndOfTrack() {
    _stateSub = widget.player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (!mounted) return;
        _onTimerFired();
      }
    });
  }

  /// 定时触发：暂停播放并重置为关闭态。
  ///
  /// P4-playback-experience-2：若之前是倒计时模式，触发 [onForceLoopEnd]
  /// 让宿主恢复原播放模式（虽然播放已被暂停，但模式状态需要复位）。
  void _onTimerFired() {
    final wasCountdown = _isCountdownMode(_mode);
    try {
      widget.player.pause();
    } catch (_) {
      // 播放器异常不影响 UI 状态重置
    }
    if (!mounted) return;
    setState(() {
      _mode = _SleepTimerMode.off;
      _remainingSeconds = 0;
    });
    // 倒计时到时间 → 通知宿主恢复原模式
    if (wasCountdown) {
      widget.onForceLoopEnd?.call();
    }
  }

  /// 当前定时状态文本（用于按钮展示）。
  String get _statusText {
    switch (_mode) {
      case _SleepTimerMode.off:
        return '定时关闭';
      case _SleepTimerMode.min5:
      case _SleepTimerMode.min10:
      case _SleepTimerMode.min15:
      case _SleepTimerMode.min30:
        final m = (_remainingSeconds / 60).ceil();
        return '定时关闭：$m 分钟';
      case _SleepTimerMode.endOfTrack:
        return '本曲结束后关闭';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SleepTimerMode>(
      onSelected: _setMode,
      tooltip: '定时关闭',
      itemBuilder: (context) => const [
        PopupMenuItem(value: _SleepTimerMode.off, child: Text('关闭')),
        PopupMenuItem(value: _SleepTimerMode.min5, child: Text('5 分钟')),
        PopupMenuItem(value: _SleepTimerMode.min10, child: Text('10 分钟')),
        PopupMenuItem(value: _SleepTimerMode.min15, child: Text('15 分钟')),
        PopupMenuItem(value: _SleepTimerMode.min30, child: Text('30 分钟')),
        PopupMenuItem(
          value: _SleepTimerMode.endOfTrack,
          child: Text('播放完当前音频'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _mode == _SleepTimerMode.off
              ? const Color(0xFFE6F1F9)
              : AppColors.lavender.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _mode == _SleepTimerMode.off
                ? Colors.transparent
                : AppColors.lavender.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 14,
              color: _mode == _SleepTimerMode.off
                  ? AppColors.primary
                  : AppColors.lavender,
            ),
            const SizedBox(width: 4),
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 11,
                color: _mode == _SleepTimerMode.off
                    ? AppColors.primaryDeep
                    : AppColors.lavender,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
