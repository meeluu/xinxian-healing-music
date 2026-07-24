import 'package:just_audio/just_audio.dart';

/// 播放按钮点击后应执行的动作（P4-player-seek-bugfix-1）。
enum PlayButtonAction {
  /// 从头重新播放（仅当播放真正结束且用户未手动拖动进度条时）。
  replayFromStart,

  /// 从当前位置继续播放（用户手动 seek 后点击播放，或首次播放，或 completed
  /// 但 [decidePlayButtonAction] 的 completedFlag 已被手动 seek 清空时）。
  play,

  /// 暂停。
  pause,
}

/// 决定播放按钮点击后应执行的动作（纯函数，便于单测）。
///
/// P4-player-seek-bugfix-1 修复核心：
/// 之前 `_toggle()` 只要 `processingState == completed` 就 `seek(Duration.zero) +
/// play()`，导致用户在歌曲播完后手动拖动到中间位置、再点击播放时，会被强制
/// 回到 0 秒从头重播——与"拖到哪就从哪继续"的预期不符。
///
/// 修复后引入 [completedFlag]（用户可见的完成态标志，手动 seek 时会被宿主清空）：
/// - `completed + completedFlag=true` → [PlayButtonAction.replayFromStart]
///   （真正的"重播"意图：歌曲自然播完、用户没拖动，点击即重头开始）
/// - `completed + completedFlag=false` → [PlayButtonAction.play]
///   （用户已手动 seek 到中间，completedFlag 被清空，从该处继续，不回 0）
/// - 非 completed + playing → [PlayButtonAction.pause]
/// - 非 completed + 未播放 → [PlayButtonAction.play]
///
/// 这样把"播放自然结束 → 点击重播"和"用户手动 seek 后点击继续"两条路径分开，
/// 满足"只有点击重播或在 completed 状态点击播放按钮才允许回到 0"的需求。
PlayButtonAction decidePlayButtonAction({
  required ProcessingState processingState,
  required bool playing,
  required bool completedFlag,
}) {
  if (processingState == ProcessingState.completed) {
    return completedFlag
        ? PlayButtonAction.replayFromStart
        : PlayButtonAction.play;
  }
  return playing ? PlayButtonAction.pause : PlayButtonAction.play;
}
