# P5-music-metadata-foundation-1 实施计划

## Context（为什么做这个改动）

「快速舒缓一下」流程进入疗愈方案页后，"为什么推荐这段音乐"区域显示的音乐时长 / 音乐参数没有和每一首本地音乐严格对应：

- **时长写死**：`plan_screen.dart:136` 显示 `'${plan.durationMinutes} 分钟'`，这是 plan 级「推荐聆听时长」（由情绪模板派生，15–30 分钟），与实际音频文件时长无关，所有音频共用同一时长。
- **参数非 per-asset**：折叠的「音乐参数」卡（BPM / 频率 / 脑波 / 和声 / 噪声 / 乐器）全部来自 `plan.features`（由情绪画像派生的算法目标参数），不反映具体 AudioAsset 的实际特征。
- **AudioAsset.durationSeconds 全为 0**：`AudioAssetCatalog` 的 5 首音频 + fallback 的 `durationSeconds` 都是 0（未知），无 per-asset 音乐特征结构。

后续每首音乐会有自己的真实参数。本批先把结构打好：为 AudioAsset 增加 `MusicProfile` 元数据，让方案页时长 / 参数与具体音频绑定，不大改推荐算法、不扩充内容库、不碰 AI 歌曲链路。

## 数据流现状（已核实）

`StockAudioGenerator`（stock_audio_generator.dart:30-41）已从 AudioAsset 复制 `assetPath/title/durationSeconds` → `PassthroughPostProcessor`（passthrough_post_processor.dart:23-24）透传到 `ProcessedAudio` → `plan.audio`。所以 **`plan.audio.durationSeconds` / `plan.audio.title` 已可用**，只是 plan_screen 没用 durationSeconds（用了 plan.durationMinutes）。

`player_screen.dart:284-294` 已有按 `assetPath` 查 AudioAsset 的先例，plan_screen 可复用此模式。

真实 mp3 时长（已用 Shell.Application COM 读取，作 calibrated 真值，非占位）：
- sleep_01: 211s（3:31）| regulate_01: 243s（4:03）| soothe_01: 185s（3:05）| focus_01: 188s（3:08）| energize_01: 169s（2:49）| fallback=sleep_01.mp3 → 211s

## 实施方案

### 1. 新增 `lib/models/music_profile.dart`

```dart
/// 音乐参数校准状态。
enum MusicParameterStatus {
  /// 初步占位推断，待后续用真实音乐参数校准。
  preliminary,
  /// 已校准（后续真实参数接入后使用）。
  calibrated,
}

/// 单首本地音乐的声音特征元数据（P5-music-metadata-foundation-1）。
///
/// 与 AudioAsset 绑定，供方案页「为什么推荐这段音乐」展示 per-asset 声音特征。
/// 当前值为基于已有 brainwaveTag/noiseTags/instruments 的初步推断，
/// [parameterStatus] 标为 [MusicParameterStatus.preliminary]，后续逐首校准。
class MusicProfile {
  final String tempo;         // 节奏描述，如 '慢速'
  final String texture;       // 声音特征，如 '低频 Pad 与柔和钢琴铺底'
  final String energyCurve;   // 起伏描述，如 '低起伏'
  final String suitableScene; // 适合场景，如 '睡前舒缓'
  final MusicParameterStatus parameterStatus;
  const MusicProfile({
    required this.tempo,
    required this.texture,
    required this.energyCurve,
    required this.suitableScene,
    this.parameterStatus = MusicParameterStatus.preliminary,
  });
}
```

### 2. 扩展 `lib/data/audio_asset_catalog.dart`

- 给 `AudioAsset` 增加字段 `final MusicProfile? musicProfile;`（可选，旧构造兼容）。
- 给 5 首音频 + fallback 填入 **真实 `durationSeconds`**（211/243/185/188/169/211）+ **preliminary `musicProfile`**（基于已有 brainwaveTag/noiseTags/instruments/description 推断，标 preliminary）。例：
  ```dart
  AudioAsset(
    id: 'sleep_01', assetPath: 'music/sleep_01.mp3',
    title: '夜色舒缓 · Theta 入眠',
    targetStates: [TargetState.sleep], brainwaveTag: 'Theta',
    noiseTags: ['雨声', '粉红噪音', '低频环境音'],
    instruments: ['低频 Pad', '手碟', '柔和钢琴'],
    durationSeconds: 211, // 真实测量的文件时长
    description: '雨声与低频 Pad 配合，辅助睡前舒缓、降低唤醒度。',
    musicProfile: MusicProfile(
      tempo: '慢速', texture: '低频 Pad 与柔和钢琴铺底',
      energyCurve: '低起伏', suitableScene: '睡前舒缓',
      parameterStatus: MusicParameterStatus.preliminary,
    ),
  )
  ```
- 新增 `static AudioAsset? findByAssetPath(String assetPath)`（与 `findById` 并列，供 plan_screen 按 `plan.audio.assetPath` 查表）。

### 3. 扩展 `lib/utils/recommendation_reason.dart`（保持 `buildRecommendationReason` / `goalLabelFor` 签名不变，不破坏 player_screen 共用）

新增纯函数 helper（便于单测）：
- `String formatAssetDuration(int durationSeconds)` → 0 时返回 `'时长待补充'`；否则 `约 X 分 YY 秒`（如 `约 3 分 31 秒`）。
- `String buildSoundCharacteristics(MusicProfile? profile)` → profile 为空或字段空返回 `'声音特征：参数待补充'`；否则 `声音特征：慢速、低频 Pad 与柔和钢琴铺底、低起伏`（tempo+texture+energyCurve 用顿号拼接）。
- `String buildListeningSuggestion(TargetState ts, String? suitableScene)` → 按 targetState 生成建议文案，引用 suitableScene，如 `建议：适合睡前舒缓，可配合定时关闭循环播放到设定时间。`（非医疗化表达）。
- `String buildPreliminaryNote(MusicProfile? profile)` → profile?.parameterStatus == preliminary 时返回 `音乐参数为初步版本，后续会持续校准`，否则空串。

文案约束：不用「治疗/治愈/疗效」，用「舒缓/陪伴/放松/睡前聆听/情绪调节」。

### 4. 改造 `lib/screens/plan_screen.dart`「为什么推荐这段音乐」卡

- 在 build 中查表：`final asset = AudioAssetCatalog.findByAssetPath(plan.audio.assetPath) ?? AudioAssetCatalog.fallback;`
- 第 136 行 `_MetaTag` 时长：把 `'${plan.durationMinutes} 分钟'` 改为 `formatAssetDuration(asset.durationSeconds)`（per-asset 真实时长，0 时「时长待补充」）。
- reasonText 下方新增两行（来自 asset.musicProfile）：
  - `buildSoundCharacteristics(asset.musicProfile)`
  - `buildListeningSuggestion(plan.mood.targetState, asset.musicProfile?.suitableScene)`
- 若 `buildPreliminaryNote` 非空，显示一行小字 muted 注记「音乐参数为初步版本…」。
- 保留 `_goalLabel` MetaTag + 「推荐音频：plan.audio.title」。

### 5. 改造折叠「音乐参数」卡（混合策略，用户已确认）

按优先 AudioAsset metadata、缺失回退 plan.features：
- 脑波倾向：`asset.brainwaveTag` 非空则用，否则 `plan.features.brainwave`
- 噪声层：`asset.noiseTags` 非空则 `join('、')`，否则 `plan.features.noiseLayer`
- 推荐乐器：`asset.instruments` 非空则用，否则 `plan.features.instruments`
- BPM / 基准频率 / 和声色彩：asset 无此字段，保留 `plan.features.bpm / frequency / harmony`
- 卡片标题加副注「（脑波 / 噪声 / 乐器来自当前音频，BPM / 频率 / 和声为推荐目标）」以区分来源。不硬删 plan.features。

### 6. 版本号同步

- `lib/config/app_version.dart`：`buildLabel = P5-music-metadata-foundation-1`，`buildDate = 2026-07-24`，milestone/versionName/deployTarget 不变。
- `functions/api/health.js`：`BUILD_LABEL = P5-music-metadata-foundation-1`。
- `scripts/verify-provider-adapter.mjs`：buildLabel 断言同步。

### 7. 测试

- `test/audio_asset_catalog_test.dart`：新增断言——5 首 asset 的 `durationSeconds` 等于真实值（211/243/185/188/169）；`musicProfile` 非空且 `parameterStatus == preliminary`；`findByAssetPath('music/sleep_01.mp3')` 返回 sleep_01。
- `test/recommendation_reason_test.dart`（新建）：测 `formatAssetDuration`（0→待补充、211→约 3 分 31 秒）、`buildSoundCharacteristics`（null→参数待补充、正常→含 tempo/texture/energyCurve）、`buildListeningSuggestion`（各 targetState 非空且不含医疗词）、`buildPreliminaryNote`。

### 8. README / docs/ROADMAP.md 同步

更新当前版本与阶段为 P5-music-metadata-foundation-1；记录：为 AudioAsset 增加 MusicProfile + 真实 durationSeconds；方案页「为什么推荐这段音乐」时长 / 声音特征改为 per-asset；折叠「音乐参数」卡混合策略；参数标 preliminary；快速舒缓仍完全本地化；未做 R2/历史歌曲/分享/支付/用户系统/4090；未开启真实 MiniMax；未扩充内容库。

## 约束保持

- 不修改 `MUSIC_GENERATION_REAL_CALLS_ENABLED`，不真实调用 MiniMax，`manualTest=true` 三重门保留。
- 不改 AI 歌曲生成链路（不动 `music_generation_models.dart:52` 的 `durationSeconds: durationMinutes * 60`）。
- 快速舒缓仍只使用本地 `AudioAssetCatalog`，不调 `/api/generate-music`、不调 MiniMax。
- 不大改推荐算法（`EmotionToMusicPlanMapper` / `MusicFeatureTags` 不动，plan.features 保留作回退）。
- 不把 P5 内容库扩充写成已完成（仍 5 首，仅加元数据结构）。
- 不使用医疗化表达。

## 验证

- `flutter analyze`
- `flutter test`（含新增 catalog 断言 + recommendation_reason 测试）
- `flutter build web --release`
- `node scripts/verify-provider-adapter.mjs`
- `node scripts/verify-comfort-lyrics.mjs`
- 手动：快速舒缓 → 疗愈方案页 → 确认「为什么推荐这段音乐」显示 per-asset 真实时长（如 sleep 约 3 分 31 秒）+ 声音特征 + 建议；折叠「音乐参数」脑波/噪声/乐器来自 asset、BPM/频率/和声来自 plan.features；切换不同 targetState 各首时长不同。

## 关键文件清单

- 新增：`lib/models/music_profile.dart`、`test/recommendation_reason_test.dart`
- 修改：`lib/data/audio_asset_catalog.dart`、`lib/utils/recommendation_reason.dart`、`lib/screens/plan_screen.dart`、`lib/config/app_version.dart`、`functions/api/health.js`、`scripts/verify-provider-adapter.mjs`、`test/audio_asset_catalog_test.dart`、`README.md`、`docs/ROADMAP.md`
