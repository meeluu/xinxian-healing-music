# P4-playback-experience-2 实施计划

> AI 歌曲独立播放页 + 本地舒缓播放模式增强

## 摘要

本批次解决两个播放体验问题：
1. **AI 歌曲生成后停留在歌词页内嵌播放** → 改为生成成功后跳转到独立播放页 `GeneratedSongPlayerScreen`。
2. **本地纯音乐定时关闭时单曲播完即停**（3 分钟曲目 + 5 分钟定时 → 3 分钟停止）→ 新增 4 种播放模式，定时关闭期间强制持续播放至倒计时结束。

严格遵守约束：不修改 `MUSIC_GENERATION_REAL_CALLS_ENABLED`、不开启真实 MiniMax 调用、不暴露 API Key、"快速舒缓一下"仍只用本地 assets、不夸大未实现功能。

---

## 现状分析（Phase 1 探索结论）

### 1. AI 歌曲生成流程现状（[comfort_lyrics_screen.dart](file:///d:/xinxian_healing_music/lib/screens/comfort_lyrics_screen.dart)）

- `_callGenerateMusicApi`（L1323-1444）：调用 `/api/generate-music`，成功后调用 `_initGeneratedAudioPlayer(playableUrl, provider)` 初始化内嵌播放器，并 `setState(() => _generatedAudioUrl = playableUrl)`。
- 结果区分支（L839-851）：`_generatedAudioUrl != null` → 渲染 `_buildSongResultSection()`（内嵌播放区，L1636-1732）。
- 内嵌播放区包含：标题、副文案、`_buildPlayControl()`（圆形播放/暂停按钮 + 状态文案 + `SleepTimerButton`，L1808-1865）、歌词展示、`_buildSongActionButtons()`（重新播放/编辑歌词/重新生成，L1875-1944）、`_buildSootheCta()`（引导本地舒缓）。
- 相关字段：`_generatedAudioPlayer`、`_generatedPlayerStateSub`、`_isPlayingGenerated`、`_generatedAudioUrl`、`_storageWarning`、`_musicErrorHint`、`_generatingMusic`。
- 相关方法：`_initGeneratedAudioPlayer`（L1455）、`_toggleGeneratedAudio`（L1488）、`_replayGeneratedSong`（L1548）、`_returnToEditLyrics`（L1570）、`_onRegenerateSongPressed`（L1587）、`_generateSongTitle`（L1528）、`_mapStyleToTargetState`（L1512）。
- dispose（L192-204）：清理 `_generatedPlayerStateSub` 和 `_generatedAudioPlayer`。
- **`generated_song_player_screen.dart` 不存在，需新建。**

### 2. 本地播放页现状（[player_screen.dart](file:///d:/xinxian_healing_music/lib/screens/player_screen.dart)）

- 单曲播放：`_initAudio`（L67-86）用 `AudioAssetUriResolver.resolveAudioSource(widget.plan.audio.assetPath)` 设置单一 `AudioSource.uri`，无 `ConcatenatingAudioSource`，无 `LoopMode` 设置（默认 `off`，播完即停）。
- 无 `PlayMode` 枚举，无播放模式切换 UI。
- `SleepTimerButton(player: _player)`（L287）未传任何回调。
- `_toggle`（L97-116）：completed 时 seek(0)+play，否则 play/pause。
- dispose（L119-126）：`sessionRecorder.updateListening(widget.plan.sessionId, _player.position)` 后释放。
- 子组件：`_Visualizer`、`_PlayButton`、`_ProgressSection`（带拖动逻辑）。
- 入口：[plan_screen.dart](file:///d:/xinxian_healing_music/lib/screens/plan_screen.dart) L325-328 `PlayerScreen(plan: plan, moodText: widget.moodText)`。

### 3. 定时关闭现状（[sleep_timer_button.dart](file:///d:/xinxian_healing_music/lib/widgets/sleep_timer_button.dart)）

- 模式：`off / min5 / min10 / min15 / min30 / endOfTrack`。
- `_setMode`（L47-73）：切换模式，启动倒计时或监听 `processingState == completed`。
- `_onTimerFired`（L102-113）：`player.pause()` + 重置为 off。
- **问题**：倒计时模式下，若播放模式为单曲播放（LoopMode.off），单曲播完 `processingState` 变 `completed`，just_audio 停止，但倒计时未结束 → 音乐提前停止。当前无任何机制强制持续播放。
- **无 `onForceLoopStart` / `onForceLoopEnd` 回调。**

### 4. 版本号现状

- [app_version.dart](file:///d:/xinxian_healing_music/lib/config/app_version.dart) L57：`buildLabel = 'P4-conversation-song-flow-1-fix2'`，L60：`buildDate = '2026-07-23'`。
- [health.js](file:///d:/xinxian_healing_music/functions/api/health.js) L55：`BUILD_LABEL = 'P4-conversation-song-flow-1-fix2'`。
- [verify-provider-adapter.mjs](file:///d:/xinxian_healing_music/scripts/verify-provider-adapter.mjs) L1434-1438：`assert.strictEqual(d.buildLabel, 'P4-conversation-song-flow-1-fix2')`。

### 5. 测试现状

- [comfort_lyrics_screen_test.dart](file:///d:/xinxian_healing_music/test/comfort_lyrics_screen_test.dart)（681 行）：无测试覆盖内嵌播放区成功路径（L411-431 测试只验证费用确认对话框出现，不点确认）。L36 docstring 提及 `_buildSongResultSection`。
- 无 `generated_song_player_screen_test.dart`。
- 无 `player_screen` 播放模式测试。
- 无 `sleep_timer_button` 回调测试。

### 6. 关键决策（已与用户确认）

- **本地播放列表组成**：按当前 `targetState` 过滤 `AudioAssetCatalog.assets`（当前每类 1 首）。用户后续会在每类内添加更多音乐，过滤式列表自动扩展。
  - 1 首时：单曲播放/顺序播放都 = 播一次即停（行为正确）；单曲循环/列表循环都 = 循环当前曲。
  - 未来 N 首时：列表循环/顺序播放自动生效。

---

## 实施方案

### 决策：播放模式与 just_audio LoopMode 映射

| 模式 | 音频源 | LoopMode | 行为（1 首时） | 行为（N 首时） |
|------|--------|----------|----------------|----------------|
| 单曲播放 | 仅当前曲（单一 AudioSource） | off | 播一次停止 ✓ | 播当前曲一次停止 ✓ |
| 单曲循环 | 仅当前曲（单一 AudioSource） | one | 循环当前曲 ✓ | 循环当前曲 ✓ |
| 列表循环 | ConcatenatingAudioSource（同类全部） | all | 循环当前曲 ✓ | 列表末尾回到第一首 ✓ |
| 顺序播放 | ConcatenatingAudioSource（同类全部） | off | 播一次停止 ✓ | 播完列表末尾停止 ✓ |

- 切换模式时：捕获 `position` + `playing` 状态 → 重建对应音频源 → `setAudioSource(src, initialPosition: pos)` → 设 LoopMode → 恢复播放态。
- "仅当前曲"用单一 `AudioSource.uri`；"列表"用 `ConcatenatingAudioSource`。这样"单曲播放"在多曲时也能正确停止（不自动进下一曲）。
- 默认模式：**单曲循环**（最符合"舒缓持续陪伴"场景，且避免 1 首曲目播完即停的尴尬）。

### 决策：定时关闭强制持续播放

- `SleepTimerButton` 新增 `onForceLoopStart` / `onForceLoopEnd` 回调。
- 进入倒计时模式（min5/10/15/30）时触发 `onForceLoopStart`：PlayerScreen 保存当前 `_playMode` 到 `_preForceMode`，强制切到**单曲循环**（LoopMode.one + 单一 AudioSource），保证音乐持续。
- 退出倒计时（到时间触发 / 用户取消 / 切到 off / 切到 endOfTrack）时触发 `onForceLoopEnd`：恢复 `_preForceMode`。
- `endOfTrack` 模式本身就是"本曲结束停止"，不触发强制循环。

---

### 文件 1：新建 [lib/screens/generated_song_player_screen.dart](file:///d:/xinxian_healing_music/lib/screens/generated_song_player_screen.dart)

**职责**：AI 生成歌曲独立播放页。接收生成歌曲元数据，自行管理 `AudioPlayer`，展示完整播放体验。

**构造参数**（通过 `_GeneratedSongMeta` 风格的具名参数传入）：
- `playableUrl`（String，必填）：可播放 URL（generatedAudioUrl 或 audioDataUrl）。
- `title`（String，必填）：歌曲标题（来自 `_generateSongTitle`）。
- `comfortInterpretation`（String，必填）："给现在的你"文案。
- `lyricDraft`（String，必填）：歌词。
- `targetState`（String?）：目标状态（用于 goalLabel 展示，可选）。

**展示内容**（按用户要求）：
- AppBar 标题 + 返回按钮（`automaticallyImplyLeading: true`）。
- 歌曲标题（大字、字间距）。
- "给现在的你"（`comfortInterpretation`，可选中）。
- 歌词（`lyricDraft`，SelectableText，带卡片背景）。
- 播放/暂停按钮（复用 player_screen 的 `_PlayButton` 风格，但简化为独立实现）。
- 进度条 + 当前时间/总时长（复用 `_ProgressSection` 拖动逻辑风格）。
- 重新播放按钮。
- 单曲循环开关（AI 歌曲页只支持单曲播放/单曲循环/定时关闭）。
- 定时关闭入口（`SleepTimerButton`，带 `onForceLoopStart`/`onForceLoopEnd` 强制单曲循环）。

**音频加载逻辑**（迁移自 `_initGeneratedAudioPlayer` L1455-1485）：
- `playableUrl.startsWith('data:')` / `http` / `https` → `Uri.parse`；否则 `Uri.base.resolve`。
- `AudioSource.uri(absoluteUri)` + `LoopMode.one`（默认单曲循环，适合舒缓体验）。
- 加载失败：`_error = true`，显示温和错误提示 + "返回歌词页"按钮（`Navigator.pop`）。
- 不白屏/卡死：加载中显示 loading，失败显示错误态 + 返回入口。

**状态管理**：
- `_loading` / `_error` / `_isPlaying` / `_completed` / `_loopMode`（one/off）。
- `playerStateStream` 监听驱动 UI。
- dispose 释放 `_player`。

**不依赖 R2**：只用传入的 `playableUrl` 临时播放，不做历史/分享/永久保存。

**约束**：`CenteredPageScaffold` + maxWidth 760 居中；无医疗化文案；不放 API Key。

---

### 文件 2：修改 [lib/widgets/sleep_timer_button.dart](file:///d:/xinxian_healing_music/lib/widgets/sleep_timer_button.dart)

**变更**：新增 `onForceLoopStart` / `onForceLoopEnd` 回调，在倒计时模式切换时触发。

- `SleepTimerButton` 新增字段：
  ```dart
  final VoidCallback? onForceLoopStart;
  final VoidCallback? onForceLoopEnd;
  ```
  并加入构造参数。
- `_setMode` 修改：记录 `oldMode`，判断 `wasCountdown = _isCountdownMode(oldMode)`、`isNewCountdown = _isCountdownMode(mode)`。
  - `wasCountdown && !isNewCountdown` → `widget.onForceLoopEnd?.call()`（退出倒计时）。
  - `!wasCountdown && isNewCountdown` → `widget.onForceLoopStart?.call()`（进入倒计时）。
- 新增私有 helper `_isCountdownMode(_SleepTimerMode m)`：`m == min5 || min10 || min15 || min30`（`off` 和 `endOfTrack` 不算倒计时）。
- `_onTimerFired`（到时间触发）已在 `setState` 前将 `_mode` 设为 `off`，需在重置前判断旧模式是倒计时 → 调用 `onForceLoopEnd`。调整：在 `_onTimerFired` 开头记录 `wasCountdown = _isCountdownMode(_mode)`，重置后若 `wasCountdown` 调用 `widget.onForceLoopEnd?.call()`。
- UI 不变（保留现有 PopupMenu + 倒计时显示）。

---

### 文件 3：修改 [lib/screens/player_screen.dart](file:///d:/xinxian_healing_music/lib/screens/player_screen.dart)

**变更**：新增 4 种播放模式 + 播放列表 + 定时强制循环。

#### 3.1 新增 PlayMode 枚举（文件顶部）

```dart
enum PlayMode {
  singlePlay,   // 单曲播放：播完停止
  singleLoop,   // 单曲循环：播完重播
  listLoop,     // 列表循环：列表末尾回到第一首
  sequential,   // 顺序播放：列表末尾停止
}

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
}
```

#### 3.2 State 字段新增

- `PlayMode _playMode = PlayMode.singleLoop;`（默认单曲循环）
- `PlayMode? _preForceMode;`（定时强制循环前的模式，null 表示未在强制态）
- `bool _switchingMode = false;`（模式切换中，防抖）
- `List<AudioAsset> _playlistTracks = [];`（当前 targetState 同类曲目列表）
- `int _currentIndex = 0;`（当前曲在列表中的索引）

#### 3.3 _initAudio 改造

- 读取 `widget.plan.mood.targetState`，从 `AudioAssetCatalog.assets` 过滤 `targetStates.contains(targetState)` 得到 `_playlistTracks`。
- 若 `_playlistTracks` 为空，回退 `[widget.plan.audio]`。
- `_currentIndex` = `_playlistTracks.indexOf(widget.plan.audio)`，找不到则 0。
- 调用 `_applyPlayMode(_playMode, initialPosition: Duration.zero)` 构建音频源。

#### 3.4 新增 _applyPlayMode / _buildAudioSource

```dart
AudioSource _buildAudioSource(PlayMode mode) {
  final resolver = AudioAssetUriResolver.resolveAudioSource;
  if (mode == PlayMode.singlePlay || mode == PlayMode.singleLoop) {
    // 单曲：仅当前曲
    return resolver(_playlistTracks[_currentIndex].assetPath);
  }
  // 列表：同类全部
  final cl = ConcatenatingAudioSource(
    useLazyPreparation: true,
    children: _playlistTracks
        .map((a) => resolver(a.assetPath) as AudioSource)
        .toList(),
  );
  return cl;
}

Future<void> _applyPlayMode(PlayMode mode, {Duration? initialPosition}) async {
  final src = _buildAudioSource(mode);
  await _player.setAudioSource(src, initialPosition: initialPosition);
  await _player.setLoopMode(mode.loopMode); // 见下 extension
  // ConcatenatingAudioSource 需要定位到当前曲
  if (mode == PlayMode.listLoop || mode == PlayMode.sequential) {
    await _player.seek(initialPosition ?? Duration.zero, index: _currentIndex);
  }
}
```

LoopMode 映射（加到 PlayModeX extension）：
```dart
LoopMode get loopMode => const {
  PlayMode.singlePlay: LoopMode.off,
  PlayMode.singleLoop: LoopMode.one,
  PlayMode.listLoop: LoopMode.all,
  PlayMode.sequential: LoopMode.off,  // 列表 off = 顺序播完停止
}[this]!;
```

#### 3.5 新增 _setPlayMode（用户切换模式）

- 防抖：`if (newMode == _playMode || _switchingMode) return;`
- 若在定时强制态（`_preForceMode != null`）：只更新 `_playMode` 记录，不实际切换源（强制态结束后再应用）；或直接提示"定时关闭期间暂不可切换"。**采用前者**：更新 `_preForceMode`，实际源保持单曲循环。
- 否则：捕获 `pos = _player.position`、`wasPlaying = _player.playing` → `_applyPlayMode(newMode, initialPosition: pos)` → 若 `wasPlaying` 调 `play()` → `setState` 更新 `_playMode`、`_completed = false`。
- try/catch 防御，失败不卡死。

#### 3.6 定时强制循环回调

```dart
void _onForceLoopStart() {
  if (_preForceMode != null) return; // 已在强制态
  _preForceMode = _playMode;
  // 强制切到单曲循环（保留进度）
  _applyPlayMode(PlayMode.singleLoop, initialPosition: _player.position)
      .then((_) { if (_player.playing == false && _wasPlayingBeforeForce) _player.play(); });
}
void _onForceLoopEnd() {
  final restore = _preForceMode;
  _preForceMode = null;
  if (restore == null) return;
  _applyPlayMode(restore, initialPosition: _player.position);
}
```

- `SleepTimerButton` 调用处传入两个回调。
- 强制态期间 `_playMode` 显示保持用户原选择（UI 仍显示原模式 chip），但实际 LoopMode 为 one。可在模式按钮旁加小字"定时中·循环"提示。

#### 3.7 播放模式 UI

- 在进度条下方、定时按钮上方新增 `_buildPlayModeButton()`：`PopupMenuButton<PlayMode>` + 当前模式 icon + label。
- 强制态时按钮 disabled（或允许选但只记到 `_preForceMode`），旁边显示"定时中"小标。

#### 3.8 _toggle 调整

- completed 时：seek(0) + play（重播当前曲），重置 `_completed`。行为不变，兼容所有模式。

#### 3.9 dispose 不变

- 仍 `sessionRecorder.updateListening(widget.plan.sessionId, _player.position)` + 释放。

---

### 文件 4：修改 [lib/screens/comfort_lyrics_screen.dart](file:///d:/xinxian_healing_music/lib/screens/comfort_lyrics_screen.dart)

**变更**：移除内嵌播放器，生成成功后跳转 `GeneratedSongPlayerScreen`；缓存元数据支持返回后重新进入。

#### 4.1 新增 _GeneratedSongMeta 结构体（文件内私有）

```dart
class _GeneratedSongMeta {
  final String playableUrl;
  final String title;
  final String comfortInterpretation;
  final String lyricDraft;
  final String targetState;
  const _GeneratedSongMeta({
    required this.playableUrl,
    required this.title,
    required this.comfortInterpretation,
    required this.lyricDraft,
    required this.targetState,
  });
}
```

#### 4.2 字段调整

- **删除**：`_generatedAudioPlayer`、`_generatedPlayerStateSub`、`_isPlayingGenerated`（内嵌播放器相关）。
- **保留**：`_generatingMusic`、`_musicErrorHint`、`_storageWarning`、`_quotaRemaining`。
- **新增**：`_GeneratedSongMeta? _generatedSongMeta;`（缓存最近一次成功生成的歌曲元数据，null 表示未生成）。
- `_generatedAudioUrl` 改为用 `_generatedSongMeta != null` 判断"已生成"。

#### 4.3 _callGenerateMusicApi 成功分支改造（L1406-1423）

拿到 `playableUrl` 后：
```dart
final targetState = _mapStyleToTargetState(_targetStyle);
final meta = _GeneratedSongMeta(
  playableUrl: playableUrl,
  title: _generateSongTitle(targetState),
  comfortInterpretation: result.comfortInterpretation,
  lyricDraft: lyrics,
  targetState: targetState,
);
await generationQuotaService?.recordSuccessfulGeneration();
await _refreshQuotaState();
if (!mounted) return;
setState(() {
  _generatingMusic = false;
  _generatedSongMeta = meta;
  _storageWarning = null;
  _musicErrorHint = null;
});
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => GeneratedSongPlayerScreen(meta: meta),
));
```
- **不再**调用 `_initGeneratedAudioPlayer`。
- 计数规则不变（仅成功且拿到可播放音频才计数）。

#### 4.4 结果区分支调整（L839-851）

```dart
if (_generatedSongMeta != null) ...[
  _buildGeneratedSongEntry(),  // 轻量入口卡片
  const SizedBox(height: 14),
] else if (_musicErrorHint != null) ...[
  _buildMusicErrorSection(),
  ...
] else if (_storageWarning != null) ...[
  _buildStorageWarningHint(),
  ...
] else ...[
  _buildGenerateSongButton(),
  ...
]
```

#### 4.5 新增 _buildGeneratedSongEntry（替换 _buildSongResultSection）

轻量入口卡片，告知"已生成"并提供重新进入播放页的入口：
- 标题"这首歌已经生成好了"
- 副文案"点击下面按钮进入播放页，可以播放、看歌词、定时关闭"
- 按钮"进入播放页"→ `Navigator.push(GeneratedSongPlayerScreen(meta: _generatedSongMeta!))`
- 保留"编辑歌词"入口（`_returnToEditLyrics`）
- 保留"重新生成"入口（`_onRegenerateSongPressed`，需额度确认）
- 保留 `_buildSootheCta()`（引导本地舒缓）

#### 4.6 删除内嵌播放相关方法

- 删除 `_initGeneratedAudioPlayer`（L1455-1485）。
- 删除 `_toggleGeneratedAudio`（L1488-1504）。
- 删除 `_replayGeneratedSong`（L1548-1564）。
- 删除 `_buildSongResultSection`（L1636-1732）。
- 删除 `_buildPlayControl`（L1808-1865）。
- 删除 `_buildSongActionButtons`（L1875-1944）中的"重新播放"按钮（保留编辑/重新生成逻辑，整合到 `_buildGeneratedSongEntry`）。

#### 4.7 _reset / dispose 调整

- `_reset`：`_generatedSongMeta = null` 替代 `_generatedAudioUrl = null`、`_isPlayingGenerated = false`；移除 `_generatedAudioPlayer?.stop()/dispose()`。
- `dispose`：移除 `_generatedPlayerStateSub?.cancel()` 和 `_generatedAudioPlayer?.dispose()`。
- `_goToSoothe`：移除 `_generatedAudioPlayer?.pause()`（播放器已在独立页管理，返回时独立页已 dispose）。

#### 4.8 import 调整

- 新增 `import 'package:xinxian_healing_music/screens/generated_song_player_screen.dart';`。
- 若删除后不再用 `just_audio` 的 `AudioPlayer`/`ProcessingState`，移除对应 import（需检查 `_mapStyleToTargetState` 等是否还用）。**保留检查**：`comfort_lyrics_screen` 删除内嵌播放后应不再需要 `just_audio` import，移除以保持干净。

#### 4.9 文档注释更新

- 文件头 docstring（L26-34）更新："生成成功后跳转到独立播放页 `GeneratedSongPlayerScreen`，不在页面内嵌播放"。
- `_buildResult` docstring 同步。

---

### 文件 5：修改 [lib/config/app_version.dart](file:///d:/xinxian_healing_music/lib/config/app_version.dart)

- L57：`static const String buildLabel = 'P4-playback-experience-2';`
- L60：`static const String buildDate = '2026-07-24';`
- milestone / versionName / deployTarget 保持不变。
- 在 buildLabel 约定注释区新增一条：`/// - P{N}-playback-experience-{n}：P 阶段第 n 批播放体验优化（AI 歌曲独立播放页 + 本地播放模式增强）`。

---

### 文件 6：修改 [functions/api/health.js](file:///d:/xinxian_healing_music/functions/api/health.js)

- L55：`const BUILD_LABEL = 'P4-playback-experience-2';`
- L52-54 注释区新增：
  ```js
  // P4-playback-experience-2：AI 歌曲独立播放页 + 本地舒缓播放模式增强（4 种模式 + 定时强制持续播放）
  ```

---

### 文件 7：修改 [scripts/verify-provider-adapter.mjs](file:///d:/xinxian_healing_music/scripts/verify-provider-adapter.mjs)

- L1434-1438：测试名与断言更新为 `P4-playback-experience-2`：
  ```js
  // 测试 63: buildLabel 已更新为 P4-playback-experience-2
  // P4-playback-experience-2：AI 歌曲独立播放页 + 本地舒缓播放模式增强（realCallsEnabled 保持 false）
  await test('buildLabel 已更新为 P4-playback-experience-2', () => {
    const d = buildDiagnostics({});
    assert.strictEqual(d.buildLabel, 'P4-playback-experience-2');
  });
  ```

---

### 文件 8：修改 [test/comfort_lyrics_screen_test.dart](file:///d:/xinxian_healing_music/test/comfort_lyrics_screen_test.dart)

- L36-38 docstring：更新为"生成成功后跳转 `GeneratedSongPlayerScreen`，歌词页保留轻量入口卡片"。
- 现有测试（L411-431）只验证费用确认对话框，不触发成功路径，**无需改动**。
- 新增 1 个测试：mock `/api/generate-music` 返回 `ok:true + audioDataUrl`，点击"生成这首歌（实验）"→ 确认 → 验证跳转到 `GeneratedSongPlayerScreen`（`find.byType`）且歌词页显示"这首歌已经生成好了"入口卡片。
- 新增 1 个测试：生成成功后返回歌词页，点击"进入播放页"可再次进入 `GeneratedSongPlayerScreen`（验证 meta 缓存）。

---

### 文件 9：新建 [test/generated_song_player_screen_test.dart](file:///d:/xinxian_healing_music/test/generated_song_player_screen_test.dart)

- 测试 loading 态、error 态（playableUrl 无效）、播放/暂停按钮存在、进度条存在、返回按钮存在、定时关闭入口存在、单曲循环开关存在。
- 用 mock data URL（`data:audio/wav;base64,...` 极小片段）或 fake，不依赖真实音频解码。
- 验证 `comfortInterpretation` 和 `lyricDraft` 正确展示。

---

### 文件 10：修改 [README.md](file:///d:/xinxian_healing_music/README.md) + [docs/ROADMAP.md](file:///d:/xinxian_healing_music/docs/ROADMAP.md)

**README** 新增/更新章节：
1. AI 歌曲生成成功后跳转到独立播放页 `GeneratedSongPlayerScreen`。
2. 当前 AI 歌曲仍使用 `audioDataUrl` 临时播放，不依赖 R2。
3. 快速舒缓仍然只使用本地 assets 音乐。
4. 本地播放新增 4 种模式：单曲播放 / 单曲循环 / 列表循环 / 顺序播放（当前每类 1 首，后续扩展）。
5. 定时关闭开启后会保证音乐持续播放到定时时间结束（强制单曲循环，结束后恢复原模式）。
6. 本批未做：R2、历史歌曲、分享链接、支付、用户系统、4090 部署。
7. 本批未开启真实 MiniMax 调用（`MUSIC_GENERATION_REAL_CALLS_ENABLED` 保持 false）。
8. 版本号同步到 `P4-playback-experience-2`。

**ROADMAP** 同步标记 P4-playback-experience-2 批次完成项与未完成项。

---

## 假设与决策

1. **默认播放模式 = 单曲循环**：最符合舒缓陪伴场景，避免 1 首曲目播完即停。
2. **播放列表按 targetState 过滤**：当前每类 1 首，用户后续扩展时列表模式自动生效（用户已确认）。
3. **AI 歌曲页默认单曲循环**：一首生成歌曲循环播放，适合沉浸聆听；提供切换单曲播放的开关。
4. **定时强制循环用单曲循环（LoopMode.one）**：最简单可靠，保证倒计时期间持续有声音。
5. **模式切换保留进度**：通过 `setAudioSource(src, initialPosition: pos)` 实现。
6. **不引入新第三方依赖**：仅用已有的 `just_audio`（`ConcatenatingAudioSource`、`LoopMode` 已内置）。
7. **`MUSIC_GENERATION_REAL_CALLS_ENABLED` 不动**：前端不接触该开关，`manualTest: true` 保护不变。
8. **`comfort_lyrics_screen` 移除 `just_audio` import**：删除内嵌播放器后不再需要（实施时复核）。

---

## 验证步骤

### 自动化验证

```powershell
flutter analyze
flutter test
flutter build web --release
node scripts/verify-provider-adapter.mjs
node scripts/verify-comfort-lyrics.mjs
```

### 手动验收（Web）

1. 进入"把困惑写成一首歌"，输入困惑 → 生成歌词。
2. 模拟生成歌曲成功（`MUSIC_GENERATION_REAL_CALLS_ENABLED=false` 时走 fallback，需在安全条件下手动验证跳转逻辑；或用 mock 测试覆盖）。
3. 确认生成成功后跳转到 `GeneratedSongPlayerScreen`。
4. 确认新播放页：播放/暂停、拖动进度、返回、定时关闭入口、单曲循环开关均可用。
5. 返回歌词页，确认显示"这首歌已经生成好了"入口卡片，可再次进入播放页。
6. 进入"快速舒缓一下"，确认播放本地音乐（非 MiniMax）。
7. 切换 4 种播放模式，确认模式按钮显示当前模式。
8. 开启 5 分钟定时关闭（配合短曲目），确认曲目播完后不停止、继续循环。
9. 等待定时到达（或缩短验证），确认自动停止。
10. 取消定时关闭，确认播放模式恢复为用户原选择。

### 完成汇报项

- 修改文件清单。
- AI 歌曲生成成功后跳转页面：`GeneratedSongPlayerScreen`。
- 新播放页展示：标题 / "给现在的你" / 歌词 / 播放暂停 / 进度条 / 当前时间·总时长 / 重新播放 / 返回 / 定时关闭 / 单曲循环开关。
- 快速舒缓播放模式：单曲播放 / 单曲循环 / 列表循环 / 顺序播放。
- 定时关闭防提前停止：倒计时启动时强制单曲循环，结束/取消时恢复原模式。
- 快速舒缓仍完全本地化：是（仅 `AudioAssetCatalog` 本地 assets，不调 `/api/generate-music`、不调 MiniMax）。
- 版本号：`P4-playback-experience-2`（buildDate 2026-07-24）。
- README/docs 同步：是。
- 验证命令：flutter analyze / test / build web --release / verify 脚本全部通过。
