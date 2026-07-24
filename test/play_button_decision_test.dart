import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:xinxian_healing_music/utils/play_button_decision.dart';

/// P4-player-seek-bugfix-1 回归测试。
///
/// 本批修复的核心 bug：歌曲播完后用户手动拖动进度条到中间位置，再点击播放
/// 按钮，会被 `_toggle()` 强制 `seek(Duration.zero)` 回到 0 秒从头重播。
///
/// 修复方式：把 `_toggle()` 的决策提取为纯函数 [decidePlayButtonAction]，
/// 引入 `completedFlag`（用户可见完成态，手动 seek 时被宿主清空）：
/// - `completed + completedFlag=true` → replayFromStart（真正重播意图）
/// - `completed + completedFlag=false` → play（用户已 seek，从该处继续，不回 0）
/// - 非 completed + playing → pause
/// - 非 completed + 未播放 → play
///
/// just_audio 的 `AudioPlayer` 在 widget test 中难以稳定 mock（依赖平台通道），
/// 因此这里只测纯函数决策逻辑；播放器实际 seek 行为由手动验收覆盖。
void main() {
  group('decidePlayButtonAction', () {
    test('completed + completedFlag=true → replayFromStart（自然播完点击重播）',
        () {
      expect(
        decidePlayButtonAction(
          processingState: ProcessingState.completed,
          playing: false,
          completedFlag: true,
        ),
        PlayButtonAction.replayFromStart,
      );
    });

    test(
        'P4-player-seek-bugfix-1 核心：completed + completedFlag=false → play'
        '（用户已手动 seek 到中间，不回 0）', () {
      // 场景：歌曲播完 → 用户拖到 1:20 → completedFlag 被清空 → 点击播放
      // 期望：从 1:20 继续，而非 seek(0) 重头播
      expect(
        decidePlayButtonAction(
          processingState: ProcessingState.completed,
          playing: false,
          completedFlag: false,
        ),
        PlayButtonAction.play,
      );
    });

    test('非 completed + playing → pause（播放中点击暂停）', () {
      expect(
        decidePlayButtonAction(
          processingState: ProcessingState.ready,
          playing: true,
          completedFlag: false,
        ),
        PlayButtonAction.pause,
      );
    });

    test('非 completed + 未播放 → play（首次播放 / 暂停后继续）', () {
      expect(
        decidePlayButtonAction(
          processingState: ProcessingState.ready,
          playing: false,
          completedFlag: false,
        ),
        PlayButtonAction.play,
      );
    });

    test('idle 态 + 未播放 → play（首次进入，加载完成未播放）', () {
      expect(
        decidePlayButtonAction(
          processingState: ProcessingState.idle,
          playing: false,
          completedFlag: false,
        ),
        PlayButtonAction.play,
      );
    });

    test('buffering 态 + playing=true → pause（缓冲中但仍在播放态）', () {
      expect(
        decidePlayButtonAction(
          processingState: ProcessingState.buffering,
          playing: true,
          completedFlag: false,
        ),
        PlayButtonAction.pause,
      );
    });

    test('completed + completedFlag=true 即使 playing=true 也走 replay（边界）',
        () {
      // 边界：理论上 completed 时 playing 通常为 false，但即使 playing=true
      // 仍应以 replayFromStart 优先（completedFlag=true 表示用户未手动 seek）
      expect(
        decidePlayButtonAction(
          processingState: ProcessingState.completed,
          playing: true,
          completedFlag: true,
        ),
        PlayButtonAction.replayFromStart,
      );
    });

    test('定时强制循环态不影响决策：completed+seek 后仍 play 不回 0', () {
      // 场景：定时关闭强制单曲循环中，歌曲播完一轮进入 completed，
      // 但用户曾手动 seek（completedFlag=false），点击播放不应回 0
      expect(
        decidePlayButtonAction(
          processingState: ProcessingState.completed,
          playing: false,
          completedFlag: false,
        ),
        PlayButtonAction.play,
      );
    });
  });

  group('PlayButtonAction 覆盖完整性', () {
    test('三种动作均可被返回', () {
      final actions = <PlayButtonAction>{
        decidePlayButtonAction(
          processingState: ProcessingState.completed,
          playing: false,
          completedFlag: true,
        ),
        decidePlayButtonAction(
          processingState: ProcessingState.ready,
          playing: true,
          completedFlag: false,
        ),
        decidePlayButtonAction(
          processingState: ProcessingState.ready,
          playing: false,
          completedFlag: false,
        ),
      };
      expect(actions, containsAll(PlayButtonAction.values));
    });
  });
}
