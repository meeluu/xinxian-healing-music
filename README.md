# 0心弦 XinXian

## Project Epsilon：自然语言驱动的定制化疗愈音乐生成系统

心弦是一款基于 Flutter 的跨端 AI 疗愈音乐 Demo，支持 Web 网页端与移动端 App。用户输入当下心境后，系统通过 LLM 生成情绪画像、音乐参数，并播放匹配的本地疗愈音频素材，形成"自然语言 → AI 情绪解析 → 音乐方案 → 音频体验 → 用户反馈"的完整闭环。

> **正式体验地址**：[https://xinxian-music.xyz](https://xinxian-music.xyz)
>
> 初赛 Demo 当前以 Web 端体验为主。

## 当前进度 / Milestones

| 阶段         | 内容                                                                                                                                                                                                                                                                                                                                                          | 状态      |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| **M1** | Pipeline 架构整理：抽象核心模型与 Port（MoodAnalyzerPort / MusicFeatureExtractorPort / AudioGenerationPort / AudioPostProcessorPort / FeedbackRepository / ExperimentAssigner），HealingMusicPlan 重构为聚合根，UI 通过 HealingPipeline 编排器获取方案                                                                                                        | ✅ 已完成 |
| **M2** | ListeningSession 与实验分组结构：引入会话生命周期记录，sessionId 贯穿全链路，ExperimentVariant 支持 custom / generic / control 三组扩展点                                                                                                                                                                                                                     | ✅ 已完成 |
| **M3** | 本地持久化历史记录：ListeningSession 与 FeedbackRecord 通过 shared_preferences + JSON 保存到用户本地设备（最多 100 条），新增历史记录页支持查看 / 删除 / 清空                                                                                                                                                                                                 | ✅ 已完成 |
| **M4** | LLM 情绪解析网关 + Cloudflare Pages Functions + 正式域名部署：接入 DeepSeek OpenAI-compatible API 实现真实 AI 情绪解析，前端零 API Key 泄露，已完成正式域名 9 步全流程验收                                                                                                                                                                                    | ✅ 已完成 |
| **M5** | LLM 情绪画像驱动音乐方案映射：新增 `EmotionToMusicPlanMapper`，让 LLM 返回的 `tags` / `valence` / `arousal` / `intensity` / `targetState` / `dominantNeed` 真正参与 BPM、脑波目标、乐器、噪音层、和声色彩、generationPrompt 生成；Mock 分析与 LLM 分析复用同一套映射逻辑；支持 5 类 targetState（sleep / regulate / soothe / focus / energize） | ✅ 已完成 |
| **M6** | 多音频资源与情绪匹配播放：新增 `AudioAssetCatalog`（`lib/data/audio_asset_catalog.dart`），按 `targetState` 4 级匹配算法（targetState → brainwave → noise/instruments → fallback）从本地音频目录中选择对应音频；5 类 targetState（sleep / regulate / soothe / focus / energize）已分别匹配本地预置音频；`StockAudioGenerator` 改为通过 catalog 匹配而非固定路径；`GeneratedAudio` / `ProcessedAudio` 新增 `title` / `durationSeconds` 字段，播放页与方案页展示音频标题而不暴露文件路径 | ✅ 已完成 |
| **M6.1** | targetState 意图识别精修：新增 `TargetStateResolver`（`lib/pipeline/intent/target_state_resolver.dart`）8 级优先级规则引擎，处理自然语言中的意图冲突；`MoodProfile` 新增 `sourceText` 字段携带用户原文供意图修正使用；`MockMoodAnalyzer` / `EmotionToMusicPlanMapper` / `LlmMoodAnalyzer` 均委托 resolver 完成最终 targetState 决策；支持冲突输入识别（如"备考压力大，晚上睡不着"→ sleep、"想专注学习"→ focus、"刚睡醒但没精神"→ energize）；新增 31 条端到端测试覆盖 5 类 targetState + 6 类冲突场景 | ✅ 已完成 |
| **M7.0** | 匿名云端反馈采集：新增 Cloudflare D1 数据库 `xinxian-feedback`（`feedback` 表 25 字段）+ Pages Functions `/api/submit-feedback`（字段白名单 + 长度限制 + upsert + 三层 try/catch）；前端新增 `CloudFeedbackUploader` Port 与 `HttpCloudFeedbackUploader` 实现，与本地 `FeedbackRepository` 并存；两层同意机制（`CloudFeedbackConsentService` 总开关 + `CloudTextConsentService` 文字独立开关）；fire-and-forget 上传，失败不影响本地体验；不上传心境原文 `moodText`，文字反馈需用户单独勾选才上传；历史记录页顶部提示条；首页"云端采集"入口可随时切换 | ✅ 已完成 |

### M4 正式域名验收记录

以下 9 步全流程已在正式域名 `https://xinxian-music.xyz` 验证通过：

1. 输入心境
2. AI 解析（调用 Cloudflare Pages Functions → DeepSeek API）
3. 生成方案
4. 播放音乐
5. 提交反馈
6. 查看历史记录
7. 刷新页面
8. 再查看历史记录
9. 历史仍然存在

## 一、项目背景

当下 18-30 岁青年群体普遍面临备考压力、职场焦虑、睡眠困扰、情绪低落、精神内耗等心理亚健康问题。传统心理咨询存在时间、经济和心理门槛，而通用歌单、白噪音 App、脑波音频产品大多采用固定内容推荐，难以匹配用户当下具体而细腻的情绪状态。

心弦希望探索一种更个性化的情绪陪伴方式：用户只需要输入真实心境描述，系统就能根据文本中的情绪线索生成对应的音乐情绪画像和疗愈音乐参数，为用户提供辅助情绪调节、睡前舒缓、正念放松和音乐陪伴体验。

> 注意：本项目定位为情绪调节与正念放松辅助工具，不替代专业医疗、心理诊断或心理治疗。

## 二、目标用户与使用场景

目标用户：

- 18-30 岁学生与青年职场人
- 面临备考、加班、睡眠困扰、情绪低落、关系压力的人群
- 有正念冥想、睡前放松、自我情绪疏导需求的人群

典型场景：

- 睡前脑子停不下来，希望获得舒缓音频
- 备考或工作压力大，希望快速放松
- 情绪低落或内耗时，希望获得陪伴式音乐体验
- 想通过文字记录心境，并得到个性化音乐反馈

## 三、Demo 功能流程

当前初赛 Demo 已实现完整体验闭环：

1. 用户输入心境描述
2. AI 情绪解析（调用同域 `/api/analyze-mood` 网关，由 DeepSeek API 解析；用户未同意时回退本地关键词解析）
3. 生成情绪画像（tags / valence / arousal / intensity / targetState / dominantNeed / summary）
4. 生成疗愈音乐参数（BPM、基准频率、脑波倾向、推荐乐器、噪音层、和声色彩）
5. 展示方案
6. 按 targetState 匹配并播放本地音频素材（sleep / regulate / soothe / focus / energize 五类，由 `AudioAssetCatalog` 自动选择）
7. 用户提交体验反馈
8. 会话写入本地存储，刷新后历史记录仍在

流程示意：

```
自然语言心境输入
  → AI 情绪画像生成（LLM / 本地 fallback）
  → 音乐参数映射
  → 疗愈音频播放
  → 用户反馈采集
  → 本地历史记录
```

## 四、当前已实现能力

- Flutter Web 可运行 Demo，已部署至 Cloudflare Pages 正式域名
- 响应式页面布局，适配桌面端和移动端宽度
- 心境输入页
- AI 情绪解析动画页（LLM 解析 + 本地 fallback）
- 疗愈方案展示页
- 真实本地音频播放页
- 用户反馈表单
- 历史记录页（查看 / 删除单条 / 清空全部）
- 6 套情绪模板（M1-M4 Mock 解析模板，M5 后由 mapper 统一接管映射）
- LLM 情绪解析网关（Cloudflare Pages Functions + DeepSeek API）
- 本地关键词解析 fallback（LLM 失败或用户未同意时自动降级）
- **M5：LLM 情绪画像驱动音乐方案映射**（`EmotionToMusicPlanMapper`）
  - LLM 返回的 `tags` / `valence` / `arousal` / `intensity` / `targetState` / `dominantNeed` 真正参与 BPM、脑波目标、乐器、噪音层、和声色彩、generationPrompt 生成
  - 5 类 targetState：`sleep` / `regulate` / `soothe` / `focus` / `energize`
  - Mock 分析与 LLM 分析复用同一套映射逻辑，体验一致
  - arousal 越高 BPM 越低；valence 越低和声越偏小调；intensity 越高动态越少
- **M6：多音频资源与情绪匹配播放**（`AudioAssetCatalog`）
  - 按 `targetState` 4 级匹配算法（targetState → brainwave → noise/instruments → fallback）从本地音频目录自动选择对应音频
  - 5 类 targetState 已分别匹配本地预置音频：`sleep_01.mp3` / `regulate_01.mp3` / `soothe_01.mp3` / `focus_01.mp3` / `energize_01.mp3`
  - `StockAudioGenerator` 改为通过 catalog 匹配而非固定路径，不同情绪对应不同音频
  - 播放页与方案页展示音频标题，不暴露文件路径
  - 当前仍是本地预置音频，非实时 AI 生成音频
- **M6.1：targetState 意图识别精修**（`TargetStateResolver`）
  - 8 级优先级规则引擎，处理自然语言中的意图冲突，让最终 targetState 更贴合用户真实需求
  - `MoodProfile` 新增 `sourceText` 字段携带用户原文供意图修正使用（不持久化，向后兼容）
  - `MockMoodAnalyzer` / `EmotionToMusicPlanMapper` / `LlmMoodAnalyzer` 均委托 resolver 完成最终 targetState 决策
  - 支持冲突输入识别，例如：
    - "备考压力大，晚上睡不着" → sleep（强信号失眠优先）
    - "想专注学习" → focus
    - "刚睡醒但没精神" → energize
    - "焦虑但需要写论文" → focus（明确任务意图优先于焦虑情绪）
- **M7.0：匿名云端反馈采集**（`CloudFeedbackUploader` + Cloudflare D1）
  - 新增 Cloudflare D1 数据库 `xinxian-feedback`，`feedback` 表 25 字段，主键 `listeningSessionId`，支持 upsert 重复提交覆盖
  - 新增 Pages Functions `/api/submit-feedback`：字段白名单 + 长度限制（`freeTextFeedback` ≤ 2000 字符）+ 三层 try/catch + 绝不返回 502
  - 前端新增 `CloudFeedbackUploader` Port 与 `HttpCloudFeedbackUploader` 实现，与本地 `FeedbackRepository` 并存（非替换关系）
  - 两层同意机制：`CloudFeedbackConsentService`（云端采集总开关）+ `CloudTextConsentService`（文字反馈独立开关，默认 declined）
  - fire-and-forget 上传：6 秒超时，所有异常内部 catch，上传失败不影响本地反馈保存和用户体验
  - 首页新增"云端采集"入口，可随时切换开关；反馈页首次提交时弹出同意弹窗
  - 历史记录页顶部提示条：云端采集已开启时显示采集范围说明
  - 字段映射：`relaxationScore` ← rating（1-5），`calmnessScore` ← (1-tensionAfter)×100（0-100），`audioAssetId` 从 assetPath 提取文件名脱敏
- BPM、432Hz、Alpha / Theta 等音乐参数展示
- 推荐乐器、和声色彩、噪音层展示
- 基于 `just_audio` 的本地音频播放
- 播放 / 暂停、进度条、时长显示、播放完成重播
- 浅色疗愈风 UI 与轻量动效
- 浏览器本地存储保存历史记录（shared_preferences + Web localStorage fallback）
- 隐私同意弹窗 + 解析设置入口（用户可随时切换 AI 解析 / 本地解析）

## 五、技术架构

### 整体架构

```
┌─────────────────────────────────────────────────────────┐
│  Flutter Web 前端（build/web 静态产物）                  │
│  ├─ 心境输入 → AI 解析 → 方案展示 → 播放 → 反馈          │
│  ├─ shared_preferences / window.localStorage 本地存储    │
│  ├─ MoodAnalyzerGateway（LLM + Mock 自动 fallback）      │
│  ├─ TargetStateResolver（M6.1 意图识别精修）             │
│  ├─ EmotionToMusicPlanMapper（M5 情绪画像 → 音乐参数）   │
│  ├─ AudioAssetCatalog（M6 targetState → 本地音频匹配）   │
│  └─ CloudFeedbackUploader（M7 匿名反馈云端采集）         │
└───────────────────────┬─────────────────────────────────┘
                        │ 同域 POST /api/analyze-mood
                        │ 同域 POST /api/submit-feedback（M7）
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Cloudflare Pages Functions（后端 API 网关）             │
│  ├─ /api/analyze-mood：接收前端请求，调用 LLM，          │
│  │  返回标准化 MoodProfile，任何异常自动 fallback        │
│  ├─ /api/submit-feedback（M7）：字段白名单 + 长度限制    │
│  │  + D1 upsert，绝不返回 502                            │
│  └─ API Key 仅从环境变量读取，不泄露到前端               │
└───────────┬───────────────────────┬─────────────────────┘
            │ OpenAI-compatible API │ D1 binding
            ▼                       ▼
┌───────────────────────┐ ┌─────────────────────────────┐
│  DeepSeek API          │ │  Cloudflare D1（M7）        │
│  ├─ model: deepseek    │ │  ├─ database: xinxian-      │
│  │  -chat              │ │  │   feedback               │
│  └─ 输出 JSON：tags /  │ │  └─ feedback 表（25 字段）  │
│    valence / arousal   │ │     主键 listeningSessionId │
└───────────────────────┘ └─────────────────────────────┘
```

### 各层说明

1. **前端应用**：Flutter Web，构建为静态产物部署在 Cloudflare Pages
2. **静态托管**：Cloudflare Pages，提供 CDN 加速与 SPA 路由 fallback（`_redirects`）
3. **后端 API 网关**：Cloudflare Pages Functions（`functions/api/analyze-mood.js` + `functions/api/submit-feedback.js`），作为同域 BFF 层，隐藏 LLM API Key 并提供匿名反馈上传入口
4. **LLM 情绪解析**：DeepSeek OpenAI-compatible API，输入用户心境文本，输出标准化 MoodProfile JSON
5. **云端反馈数据库（M7）**：Cloudflare D1（SQLite），数据库 `xinxian-feedback`，`feedback` 表 25 字段，存储匿名结构化反馈数据，支持 upsert 重复提交覆盖
6. **本地存储**：浏览器 localStorage（shared_preferences / WebLocalStoragePrefs fallback），保存历史记录、AI 解析同意状态、云端采集同意状态，按 origin 隔离
7. **音频体验**：本地预置 5 类音频素材（sleep / regulate / soothe / focus / energize），由 `AudioAssetCatalog` 按 targetState 自动匹配，基于 `just_audio` 播放（Web 端使用 `AudioSource.uri` 解决 asset 路径解析问题）

### Pipeline 分层架构

```
MoodInput（自然语言心境文本）
  → MoodAnalyzerPort（LLM / Mock，输出 MoodProfile，含 sourceText 原文）
  → TargetStateResolver（M6.1：8 级优先级规则，修正意图冲突，输出最终 targetState）
  → EmotionToMusicPlanMapper（M5：情绪画像 → 音乐方案草稿）
  → MusicFeatureExtractorPort（调用 mapper，输出 MusicFeatureTags）
  → AudioGenerationPort（StockAudioGenerator + AudioAssetCatalog，M6：按 targetState 匹配本地音频）
  → AudioPostProcessorPort（Passthrough，直通）
  → HealingMusicPlan（聚合根，包含完整方案）
  → ListeningSessionRecorder（记录会话生命周期）
  → FeedbackRepository（采集用户反馈）
```

sessionId 在 `HealingPipeline.run(text)` 入口生成，依次写入 MoodInput → HealingMusicPlan → FeedbackRecord → ListeningSession，保证一次体验的输入、方案、聆听时长、反馈可被同一条 sessionId 串联。

### EmotionToMusicPlanMapper（M5 核心映射层）

M5 之前，`MusicFeatureExtractorPort` 用 `(valence, arousal)` 最近邻匹配 6 个固定模板，LLM 返回的 `tags` / `targetState` / `intensity` / `dominantNeed` 仅做展示，未真正参与音乐参数生成。M5 新增 `EmotionToMusicPlanMapper`（`lib/pipeline/mapper/emotion_to_music_plan_mapper.dart`）作为独立映射层，6 步算法：

1. **按 tags 关键词修正 targetState**：失眠类强信号 → `sleep`；烦躁 / 愤怒 → `regulate`；焦虑 / 压力按 `arousal` 分流到 `regulate` 或 `sleep`；疲惫 / 内耗按 `valence` 分流到 `soothe` 或 `energize`；低落 / 难过 → `soothe`；无强信号时信任 LLM 返回值
2. **按修正后的 targetState 取 5 套基础参数**：BPM 范围 / 脑波目标 / 推荐乐器 / 噪音层 / 和声基础 / 推荐时长
3. **arousal 在 BPM 范围内插值**：arousal 越高 BPM 越低（`bpm = low + (1 - arousal) × (high - low)`），高唤醒时音乐更平稳
4. **valence 调整和声色彩**：valence ≤ -0.5 → 低明度小调；valence ≥ 0.3 → 温暖大调；中间区间保留基础和声
5. **intensity 调整动态描述**：intensity ≥ 0.7 → 稳定低动态；0.4-0.7 → 温和中动态；< 0.4 → 自然流动，写入 `generationPrompt`
6. **组合文案**：生成 `title` / `guidance` / `explanation` / `generationPrompt`，统一使用"辅助放松 / 情绪调节 / 睡前舒缓 / 正念陪伴"措辞，不夸大医疗效果

**关键设计**：

- **Mock 与 LLM 复用同一映射逻辑**：`RuleBasedFeatureExtractor` 和 `MockPlanMetaResolver` 都调用 `EmotionToMusicPlanMapper`，Mock 解析和 LLM 解析走完全相同的映射路径，保证体验一致性
- **纯函数无状态**：mapper 是单例纯函数，多次调用结果一致，任何字段缺失 / 越界都不抛异常，自动 fallback 到默认方案
- **5 类 targetState**：`sleep`（睡前舒缓）/ `regulate`（情绪调节）/ `soothe`（正念陪伴）/ `focus`（专注恢复）/ `energize`（温和充能），向后兼容 M1-M4 的 `relax` / `company` 旧值
- **不接真实生成模型**：`generationPrompt` 仅生成文本提示词；M6 已实现按 targetState 匹配本地多音频资源，后续真实生成模型可沿用同一数据通道

### AudioAssetCatalog（M6 核心音频匹配层）

M6 之前，`StockAudioGenerator` 固定返回 `music/music_01.mp3`，所有情绪共用同一首音频。M6 新增 `AudioAssetCatalog`（`lib/data/audio_asset_catalog.dart`）作为独立的音频资源目录与匹配层，4 级匹配算法：

1. **targetState 精确匹配**：sleep → sleep_01.mp3、regulate → regulate_01.mp3、soothe → soothe_01.mp3、focus → focus_01.mp3、energize → energize_01.mp3
2. **brainwaveTarget 兜底匹配**：若 targetState 未命中，按脑波目标（delta / theta / alpha / beta / gamma）选择相近类别
3. **noise/instruments 语义匹配**：按方案中的噪音层与乐器标签做语义近似匹配
4. **最终 fallback**：兜底返回 `sleep_01.mp3`，保证任何输入都有可播放音频

**关键设计**：

- **纯函数无状态**：catalog 是单例纯函数，多次调用结果一致，任何字段缺失都不抛异常，自动 fallback 到 sleep_01.mp3
- **不暴露文件路径**：`GeneratedAudio` / `ProcessedAudio` 新增 `title` / `durationSeconds` 字段，UI 层只展示音频标题（如"睡前舒缓·sleep_01"），不展示文件路径
- **Web 平台适配**：`AudioAssetUriResolver`（`lib/utils/audio_asset_uri.dart`）在 Web 端使用 `AudioSource.uri(Uri.parse('assets/music/xxx.mp3'))`，非 Web 端使用 `AudioSource.asset(...)`，解决 just_audio 在 Flutter Web 上的 asset 路径解析问题
- **本地预置音频，非实时生成**：当前音频目录下的 5 个 mp3 文件为预置素材，非 AI 实时生成；后续真实生成模型接入时只需替换 `AudioGenerationPort` 实现，UI 与上层 pipeline 无需改动
- **向后兼容**：旧的 `music_01.mp3` 仍保留在目录中，但 M6 起不再被 catalog 匹配使用

### TargetStateResolver（M6.1 意图识别精修层）

M5 的 `EmotionToMusicPlanMapper` 第 1 步按 tags 关键词修正 targetState，但修正规则较粗，遇到冲突输入时容易误判（如"备考压力大，晚上睡不着"会被识别为 regulate 而非 sleep）。M6.1 新增 `TargetStateResolver`（`lib/pipeline/intent/target_state_resolver.dart`）作为独立的意图识别精修层，8 级优先级规则：

1. **明确任务意图优先**：如"写论文 / 学习 / 备考任务"等明确任务描述 → focus
2. **强信号失眠优先**：如"睡不着 / 失眠 / 没法入睡" → sleep
3. **强信号情绪宣泄**：如"烦躁 / 愤怒 / 想发火" → regulate
4. **强信号低落**：如"难过 / 低落 / 想哭" → soothe
5. **强信号疲惫**：如"没精神 / 没力气 / 刚睡醒" → energize
6. **arousal / valence 分流**：无强信号时按 MoodProfile 数值分流
7. **信任 LLM 返回值**：以上都未命中时信任 LLM 返回的 targetState
8. **最终 fallback**：兜底返回 sleep

**关键设计**：

- **纯函数无状态**：resolver 是单例纯函数，多次调用结果一致
- **基于 sourceText 修正**：`MoodProfile` 新增 `sourceText` 字段携带用户原文，resolver 基于原文做关键词匹配，不依赖 LLM 返回的 tags（避免 LLM tags 误差影响意图识别）
- **不持久化 sourceText**：sourceText 仅在当次 pipeline 运行中使用，不写入 ListeningSession JSON，避免历史记录泄露用户原文；旧历史记录 fromJson 时自动回退为空字符串
- **Mock 与 LLM 复用同一 resolver**：`MockMoodAnalyzer` / `EmotionToMusicPlanMapper` / `LlmMoodAnalyzer` 均委托 resolver 完成最终 targetState 决策，保证体验一致性
- **向后兼容**：M1-M4 的 `relax` → `regulate`，`company` → `soothe`，旧值自动映射到新分类
- **31 条端到端测试**：5 类 targetState 各 5 条 + 6 类冲突场景，覆盖"备考压力大睡不着 / 想专注学习 / 刚睡醒没精神 / 焦虑但需写论文"等典型冲突输入

### CloudFeedbackUploader（M7 匿名云端反馈采集层）

M7.0 之前，用户反馈仅保存在本地浏览器，无法用于跨设备聚合分析。M7.0 新增 `CloudFeedbackUploader` Port（`lib/pipeline/ports/cloud_feedback_uploader.dart`）与 `HttpCloudFeedbackUploader` 实现，与本地 `FeedbackRepository` 并存（非替换关系），在用户提交反馈后 fire-and-forget 上传匿名结构化数据到 Cloudflare D1。

**D1 数据库**：`xinxian-feedback`，`feedback` 表 25 字段（schema 见 `schema/feedback.sql`），主键 `listeningSessionId`，4 个索引（targetState / experimentVariant / createdAt / analyzerMode）。D1 binding 名 `xinxian_feedback`，通过 `wrangler.toml` 配置。

**Pages Function**：`functions/api/submit-feedback.js`，复用 `analyze-mood.js` 的 `jsonResponse` / `fallback` / 三层 try/catch 模板：
- 字段白名单 `sanitize()`：未知字段丢弃
- 长度限制 `clampLengths()`：`freeTextFeedback` ≤ 2000 字符、`emotionTags` ≤ 20 个、`userAgent` ≤ 500 字符
- D1 upsert：`INSERT ... ON CONFLICT(listeningSessionId) DO UPDATE SET ...`，重复提交覆盖
- 绝不返回 502，任何异常都返回 200 + `ok:false`

**两层同意机制**：
- `CloudFeedbackConsentService`（`lib/pipeline/consent/cloud_feedback_consent_service.dart`）：云端采集总开关，三态 unknown / accepted / declined，key = `xinxian.cloud.feedback.consent`
- `CloudTextConsentService`（`lib/pipeline/consent/cloud_text_consent_service.dart`）：文字反馈独立开关，默认 declined（比云端采集更保守），key = `xinxian.cloud.feedback.text.consent`，unknown 视为不同意
- 两个服务均镜像 `LlmConsentService` 的异步工厂 + 损坏回退 + fire-and-forget 持久化模式

**字段映射**（`CloudFeedbackPayload.fromFeedback`）：
- `relaxationScore` ← `record.rating`（1-5）
- `calmnessScore` ← `((1 - record.tensionAfter) × 100).round()`（0-100）
- `audioAssetId` ← 从 `plan.audio.assetPath` 提取文件名脱敏（如 `assets/music/sleep_01.mp3` → `sleep_01.mp3`）
- `emotionTags` ← `plan.mood.tags`
- `freeTextFeedback` ← `record.note`（仅在 `CloudTextConsentService.isAccepted` 时上传，否则 uploader 内部剥离）

**关键设计**：

- **不上传心境原文**：`moodText` 不在 payload 中，仅上传结构化参数（tags / valence / arousal / intensity / targetState）
- **文字反馈独立同意**：默认不上传 `freeTextFeedback`，用户需在反馈页单独勾选"同时上传本次文字反馈"才上传；勾选状态持久化到 `CloudTextConsentService`
- **fire-and-forget**：6 秒超时，所有异常内部 catch + debugPrint，上传失败不重试、不影响本地反馈保存和用户体验
- **本地+云端双写**：本地 `FeedbackRepository.save()` 是核心路径必须成功；云端 `CloudFeedbackUploader.upload()` 是附加路径可失败
- **本地删除不联动云端**：历史记录页删除单条 / 清空全部仅操作本地仓储，不调用云端删除 API
- **Pipeline 不参与云端持久化**：`CloudFeedbackUploader` 独立于 `HealingPipeline`，由 `FeedbackScreen._submitFeedback()` 在本地保存后触发
- **触发时机**：用户点击"提交反馈"后，在 `feedbackRepository.save()` + `sessionRecorder.attachFeedback()` 之后调用 `_fireCloudUpload()`
- **UI 入口**：首页"云端采集"按钮可随时切换总开关；反馈页首次提交时若 `needsPrompt` 弹出同意弹窗；历史记录页顶部提示条（云端采集已开启时显示）

### 关键设计：API Key 零泄露

- 前端代码中**不包含任何 API Key、Base URL 或模型名**
- 前端只调用同域 `/api/analyze-mood`，由 Cloudflare Pages Functions 转发到 DeepSeek API
- API Key 仅保存在 Cloudflare 环境变量中，运行时通过 `context.env` 读取
- 即使前端代码被完全反编译，也无法获取 API Key

## 六、环境变量

在 Cloudflare Pages Dashboard → 项目 → Settings → Environment variables 中配置：

| 变量名              | 说明                                                      | 示例                         |
| ------------------- | --------------------------------------------------------- | ---------------------------- |
| `OPENAI_API_KEY`  | LLM API Key（必填，**不提交到代码仓库**）           | `sk-...`                   |
| `OPENAI_BASE_URL` | OpenAI-compatible API 地址                                | `https://api.deepseek.com` |
| `OPENAI_MODEL`    | 模型名                                                    | `deepseek-chat`            |
| `ENABLE_LLM`      | 是否启用 LLM（设为 `false` 时强制 fallback 到本地解析） | `true`                     |

> 安全说明：`OPENAI_API_KEY` 仅保存在 Cloudflare 环境变量中，不写入 `wrangler.toml`、不提交到 Git 仓库、不打印到日志、不返回给前端。本地开发时使用 `.dev.vars` 文件（已加入 `.gitignore`）。

## 七、当前仍为 Mock / Demo 的部分

当前版本是初赛可体验 Demo，以下模块暂时使用本地模拟或简化实现：

- **AI 音乐生成模型尚未接入**：当前使用本地预置音频素材（`sleep_01.mp3` / `regulate_01.mp3` / `soothe_01.mp3` / `focus_01.mp3` / `energize_01.mp3` 共 5 类），由 `AudioAssetCatalog` 按 targetState 自动匹配，不同情绪对应不同音频；但仍为预置素材，**非实时 AI 生成音频**（M5 的 `generationPrompt` 仅生成文本提示词，为后续真实生成模型预留数据通道）
- **DSP 后处理尚未接入**：AudioPostProcessorPort 当前为 Passthrough 直通，未实现白噪音 / 粉红噪音 / EQ / 淡入淡出等真实 DSP
- **云端数据库已部分接入（M7.0）**：匿名结构化反馈数据（体验评分 / 紧张度 / 情绪参数等）可上传至 Cloudflare D1，但完整 ListeningSession（含心境原文）仍仅保存在本地，未上传至云端
- **历史记录目前是浏览器本地存储**：基于 shared_preferences（Web 端为 localStorage），按 origin 隔离，清除浏览器数据后丢失
- **情绪解析已有 LLM 真实接入（M4）**：DeepSeek API 返回完整 `MoodProfile`
- **音乐参数映射已有 LLM 画像驱动（M5）**：`EmotionToMusicPlanMapper` 让 LLM 返回的 `tags` / `valence` / `arousal` / `intensity` / `targetState` / `dominantNeed` 真正参与 BPM、脑波、乐器、噪音层、和声、generationPrompt 生成（不再使用最近邻模板匹配）
- **多音频匹配已有真实接入（M6）**：`AudioAssetCatalog` 按 targetState 匹配 5 类本地预置音频，不同情绪对应不同音频
- **targetState 意图识别已有精修规则（M6.1）**：`TargetStateResolver` 8 级优先级规则处理冲突输入，让最终 targetState 更贴合用户真实需求

这些模块均已按可替换方式组织（Port 抽象 + 工厂装配），后续可以逐步替换为真实 AI 服务和后端能力，UI 代码无需改动。

## 八、后续计划

| 阶段                     | 计划内容                                                                                                                                                                                           | 状态        |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **M7.0** | 匿名云端反馈采集：Cloudflare D1 + Pages Functions `/api/submit-feedback`，两层同意机制，fire-and-forget 上传，不上传心境原文，文字反馈需单独勾选                                                                                                  | ✅ 已完成 |
| **M7.1**（下一阶段） | 云端反馈数据聚合与可视化：基于 D1 `feedback` 表做 SQL 聚合分析（按 targetState / experimentVariant 分组统计），提供 CSV 导出或简易数据看板，为 M8 消融实验提供数据基础                                                                    | 🔜 下一阶段 |
| **M8**             | 消融对比实验与数据分析：启用 ExperimentVariant（custom / generic / control）三组对比，量化个性化音乐对辅助情绪调节体验的影响                                                                       | ⏳ 计划中   |
| **M9**             | AI 音乐生成模型接入：将 `AudioGenerationPort` 从本地预置音频替换为真实 AI 音乐生成模型（如 MusicGen / Suno API），按 `generationPrompt` 实时生成个性化音频                                              | ⏳ 计划中   |

## 九、项目价值

社会价值：
为年轻人提供低门槛、轻量化的情绪陪伴和辅助放松入口，降低正念音乐体验的使用门槛。

工程价值：
探索从自然语言到音乐参数再到音频体验的自动化链路，为个性化音频生成产品提供原型验证；前端零 API Key 泄露的同域网关架构可直接复用于其他 LLM 应用。

科研价值：
后续可结合心理量表、用户反馈、生理数据，设计"通用音乐 vs 定制化音乐"的对比实验，量化个性化音乐对辅助情绪调节体验的影响。

商业价值：
可拓展至睡前舒缓、正念冥想、校园心理支持、企业 EAP 员工关怀、AI 内容生成等场景。

## 十、技术栈

- **前端框架**：Flutter 3.44+ / Dart 3.12+
- **音频播放**：just_audio
- **本地存储**：shared_preferences（含 Web localStorage fallback）
- **HTTP 客户端**：http
- **静态托管**：Cloudflare Pages
- **后端网关**：Cloudflare Pages Functions（ES Modules）
- **LLM 服务**：DeepSeek OpenAI-compatible API
- **云端数据库（M7）**：Cloudflare D1（SQLite，数据库 `xinxian-feedback`，存储匿名结构化反馈数据）
- **构建工具**：Flutter CLI / wrangler
- **音频素材**：本地 assets（`music/` 目录下 5 类预置音频：`sleep_01.mp3` / `regulate_01.mp3` / `soothe_01.mp3` / `focus_01.mp3` / `energize_01.mp3`，按 targetState 匹配；非实时 AI 生成）

## 十一、运行方式

环境要求：已安装 Flutter SDK（建议 3.12+），Web 端运行需配置 Chrome 浏览器。

安装依赖：

```bash
flutter pub get
```

静态检查与单元测试：

```bash
flutter analyze
flutter test
```

以 Web 端运行 Demo（推荐）：

```bash
flutter run -d chrome
```

构建 Web 产物：

```bash
flutter build web --release
```

以移动端运行（需连接模拟器或真机）：

```bash
flutter run
```

## 十二、项目结构

```
lib/
├── main.dart                      # 应用入口、主题配置、bootstrapServices 装配（M7 新增 cloud consent/uploader 装配）
├── config/                        # 配置（M5 新增）
│   └── app_version.dart           # 应用版本信息单一来源
├── data/                          # 静态数据目录（M6 新增）
│   └── audio_asset_catalog.dart   # 本地音频资源目录 + 按 targetState 4 级匹配算法
├── models/                        # 数据模型（MoodInput / MoodProfile / HealingMusicPlan / ListeningSession / FeedbackRecord / MusicPlanDraft）
│   └── cloud_feedback_payload.dart # M7 云端上传 payload 模型 + fromFeedback 工厂
├── pipeline/                      # Translation Pipeline（M1-M7 核心架构）
│   ├── healing_pipeline.dart      # Pipeline 编排器
│   ├── services.dart              # 全局服务实例（M7 新增 cloudFeedbackConsentService / cloudTextConsentService / cloudFeedbackUploader）
│   ├── ports/                     # Port 抽象接口
│   │   └── cloud_feedback_uploader.dart  # M7 云端上传 Port 抽象
│   ├── intent/                    # M6.1 自然语言意图识别精修
│   │   └── target_state_resolver.dart         # 8 级优先级规则，处理冲突输入（如"备考压力大睡不着"→sleep）
│   ├── mapper/                    # M5 情绪画像 → 音乐方案映射层
│   │   └── emotion_to_music_plan_mapper.dart  # 6 步算法：tags 修正 → 5 套基础参数 → arousal 插值 → valence 和声 → intensity 动态 → 组合文案
│   ├── mock/                      # Mock 实现（MockMoodAnalyzer / RuleBasedFeatureExtractor / StockAudioGenerator 等）
│   ├── consent/                   # M7 同意服务（镜像 LlmConsentService 范式）
│   │   ├── cloud_feedback_consent_service.dart  # 云端采集总开关（三态 unknown/accepted/declined）
│   │   └── cloud_text_consent_service.dart      # 文字反馈独立开关（默认 declined）
│   ├── cloud/                     # M7 云端上传实现
│   │   ├── http_cloud_feedback_uploader.dart    # 生产实现（6 秒超时 + fire-and-forget + 同意前置检查 + 文字剥离）
│   │   └── mock_cloud_feedback_uploader.dart    # 测试用 Mock 实现
│   ├── local/                     # 本地持久化实现
│   │   ├── preferences_port.dart          # PreferencesPort 抽象 + SharedPrefsAdapter
│   │   ├── web_preferences_factory.dart   # 条件导入入口（Web localStorage fallback）
│   │   ├── web_preferences_factory_web.dart   # Web 实现（dart:html）
│   │   ├── local_listening_session_recorder.dart
│   │   └── local_feedback_repository.dart
│   └── llm/                       # LLM 接入（M4）
│       ├── llm_mood_analyzer.dart         # 调用同域 /api/analyze-mood
│       ├── mood_analyzer_gateway.dart     # LLM + Mock 自动 fallback
│       └── llm_consent_service.dart       # AI 解析同意状态持久化
├── screens/                       # 核心页面
│   ├── home_screen.dart           # 心境输入页（M7 新增"云端采集"入口）
│   ├── analysis_screen.dart       # 情绪解析动画页
│   ├── plan_screen.dart           # 疗愈方案展示页
│   ├── player_screen.dart         # 音频播放页
│   ├── feedback_screen.dart       # 用户反馈页（M7 新增云端上传触发 + 文字勾选 + 文案动态化）
│   └── history_screen.dart        # 历史记录页（M7 新增云端采集提示条）
├── theme/                         # 配色与主题
├── utils/                         # 工具函数（M6 / M7 新增）
│   ├── audio_asset_uri.dart       # Web / 非 Web 平台 AudioSource 路径解析
│   └── user_agent_helper.dart     # M7 条件导入入口（Web 端获取 navigator.userAgent）
└── widgets/                       # 通用组件（卡片、芯片、输入框、呼吸光晕、同意弹窗、ResponsiveDialogContainer 等）
    └── cloud_feedback_consent_dialog.dart  # M7 云端采集同意弹窗

functions/
└── api/
    ├── analyze-mood.js            # Cloudflare Pages Function（LLM 网关）
    └── submit-feedback.js         # M7 Cloudflare Pages Function（D1 upsert + 字段白名单 + 长度限制）

schema/
└── feedback.sql                   # M7 D1 建表 DDL（feedback 表 25 字段 + 4 索引）

web/
├── index.html                     # Flutter Web 入口模板
├── _redirects                     # SPA 路由 fallback
└── manifest.json

music/
├── sleep_01.mp3                   # 睡前舒缓类音频（targetState = sleep）
├── regulate_01.mp3                # 情绪调节类音频（targetState = regulate）
├── soothe_01.mp3                  # 正念陪伴类音频（targetState = soothe）
├── focus_01.mp3                   # 专注恢复类音频（targetState = focus）
├── energize_01.mp3                # 温和充能类音频（targetState = energize）
└── music_01.mp3                   # 早期预置音频（M6 前的 fallback，已不再匹配使用）

wrangler.toml                      # Cloudflare Pages 配置（M7 新增 D1 binding xinxian_feedback）
```

## 十三、平台支持与初赛提交说明

### 当前初赛以 Web Demo 为主

初赛提交以 **Web Demo** 为主要体验入口，已部署至 **Cloudflare Pages** 正式域名：[https://xinxian-music.xyz](https://xinxian-music.xyz)

执行 `flutter build web --release` 后，产物位于 `build/web/`，通过 `wrangler pages deploy` 部署到 Cloudflare Pages。

部署后建议验证的体验闭环：心境输入 → AI 情绪解析 → 疗愈方案 → 进入播放页 → 点击播放按钮听到音频 → 进度条推进 → 完成体验去反馈 → 刷新页面后历史记录仍在。

### Android 构建兼容性说明

Android 构建当前存在**上游插件与 Gradle 9 的兼容性问题**，暂不作为初赛阻塞项：

- 项目使用 Flutter 3.44.4 stable，其模板生成的 Android 工具链为 Gradle 9.1.0 + Android Gradle Plugin 9.0.1 + Kotlin 2.3.20。
- 依赖 `just_audio`（及其传递依赖 `audio_session`）的 Android 构建脚本自带旧版 AGP 8.5.2，该版本内部引用了 `org.gradle.util.VersionNumber`，而该类在 Gradle 9.0 中已被移除，导致 Android 构建时报 `NoClassDefFoundError: org/gradle/util/VersionNumber`。
- `just_audio` / `audio_session` 已是当前最新版本，暂无可升级的修复版本，属于上游插件尚未适配新版 Gradle 的不兼容。
- 该问题**仅影响 Android 构建，完全不影响 Web Demo 的构建与体验**，Web 端音频播放、UI、动效均正常。

### Web / Android 互不影响

Web 与 Android 的构建链路相互独立：Android 的 Gradle 配置不参与 `flutter build web`，Web 产物中已正确包含全部音频资源（`build/web/assets/music/` 下 5 类 targetState 音频）。因此 Android 暂时无法构建不会影响初赛 Web Demo 的提交与体验。

## 十四、隐私与本地存储说明

- 本应用的聆听记录与反馈数据**默认仅保存在用户本地设备**（Web 端为浏览器 localStorage / 移动端为应用本地存储）。
- 本地最多保留最近 100 条 ListeningSession 与 FeedbackRecord，超出按时间最旧的自动裁剪。
- 用户可在「历史记录」页随时删除单条记录或清空全部记录。
- 清除浏览器数据 / 卸载应用后，本地记录将丢失。
- 浏览器隐私 / 无痕模式下本地持久化可能不可用，应用会回退到内存态运行（重启后丢失），不影响 Demo 体验。

### 云端匿名反馈采集说明（M7）

M7.0 新增可选的云端匿名反馈采集能力，**默认关闭**，需用户主动同意后才会启用：

- **不上传心境原文**：用户输入的 `moodText` 心境文本不会上传到云端，仅上传结构化参数（情绪标签 / valence / arousal / intensity / targetState / 体验评分 / 紧张度等）
- **文字反馈独立同意**：`freeTextFeedback`（用户手写的文字反馈）默认不上传，需用户在反馈页单独勾选"同时上传本次文字反馈"才上传，且勾选状态独立于云端采集总开关持久化
- **两层同意机制**：`CloudFeedbackConsentService`（云端采集总开关）+ `CloudTextConsentService`（文字反馈独立开关，默认 declined），两者均可在首页"云端采集"入口随时切换
- **fire-and-forget**：云端上传失败不影响本地反馈保存和用户体验，不重试、不报错
- **本地删除不联动云端**：在历史记录页删除单条 / 清空全部仅操作本地仓储，不会删除云端匿名记录
- **匿名 sessionId**：云端数据通过 `listeningSessionId`（UUID）关联，不包含用户身份信息
- **可随时关闭**：用户可随时在首页"云端采集"入口切换为关闭，关闭后不再上传新反馈（已上传的匿名数据保留用于科研分析）

### Web 端 localStorage 按 origin 隔离（重要）

Flutter Web 的 `shared_preferences` 底层使用浏览器 `localStorage`，**按 origin 隔离**：

- `https://xinxian-music.xyz` 与 `https://www.xinxian-music.xyz` 是不同 origin，历史记录不共享。
- `https://xinxian-healing-music.pages.dev` 与每次部署生成的 `https://xxxx.xinxian-healing-music.pages.dev` 是不同 origin，历史记录不共享。
- 同理，AI 解析的同意状态（accepted/declined）也按 origin 隔离，不同子域名下需要重新选择。

因此验证体验时请**始终使用正式域名**：[https://xinxian-music.xyz](https://xinxian-music.xyz)

### AI 解析隐私说明

- 用户心境文本仅在本次请求中用于 LLM 调用，**不在服务端存储、不记录到日志**
- LLM 解析需要用户明确同意（首次弹窗 / 解析设置入口）
- 用户未同意时，自动使用本地关键词解析（Mock），不调用 LLM
- LLM 调用失败时，自动 fallback 到本地解析，用户无感知
- 前端不包含任何 API Key / Base URL / 模型名，所有敏感信息仅保存在 Cloudflare 环境变量中

## 十五、Cloudflare Pages 部署说明

### 正式域名

正式体验地址：[https://xinxian-music.xyz](https://xinxian-music.xyz)

Cloudflare Pages 测试站稳定域名：[https://xinxian-healing-music.pages.dev](https://xinxian-healing-music.pages.dev)

每次 `wrangler pages deploy` 还会生成一个临时部署域名（形如 `https://<commit-hash>.xinxian-healing-music.pages.dev`），**仅用于预览某次部署**，不要用于日常体验（localStorage 按 origin 隔离，历史记录不共享）。

### 本地测试

```bash
# 1. 构建 Flutter Web 产物
flutter build web --release

# 2. 用 wrangler 本地预览（读取 .dev.vars 中的环境变量）
npx wrangler pages dev build/web
```

### 部署到 Cloudflare Pages

```bash
# 1. 构建 Flutter Web 产物（会自动复制 web/_redirects 到 build/web/）
flutter build web --release

# 2. 部署到 production 分支（绑定到正式域名 xinxian-music.xyz）
npx wrangler pages deploy build/web \
  --project-name=xinxian-healing-music \
  --branch=main \
  --commit-dirty=true
```

### 验证 /api/analyze-mood

```bash
curl -X POST https://xinxian-music.xyz/api/analyze-mood \
  -H "Content-Type: application/json" \
  -d '{"text":"最近备考压力很大，晚上睡不着"}'
```

预期返回 `{ "ok": true, "source": "llm", "mood": {...} }` 或 fallback 响应（`{ "ok": false, "source": "fallback", ... }`）。

### 验证 /api/submit-feedback（M7）

在站点上提交反馈后（需先在首页"云端采集"入口同意匿名上传），可通过 wrangler 查看 D1 数据库中的记录数：

```bash
npx wrangler d1 execute xinxian-feedback --remote --command "SELECT COUNT(*) FROM feedback"
```

预期返回 `count > 0`，表示匿名反馈已成功写入 D1。

查看最近 5 条匿名反馈（不含心境原文）：

```bash
npx wrangler d1 execute xinxian-feedback --remote --command "SELECT listeningSessionId, targetState, relaxationScore, calmnessScore, createdAt FROM feedback ORDER BY createdAt DESC LIMIT 5"
```

### 启动自检日志

App 启动时会在浏览器 Console 输出以下自检日志（仅 debugPrint，不影响 UI）：

```
[Startup] ===== 自检汇总 =====
[Startup] SharedPreferences ready: true
[Startup] webLocalStorageFallback: false
[Startup] storage type: SharedPrefsAdapter
[Startup] sessionRecorder type: LocalListeningSessionRecorder
[Startup] llmConsentService status: LlmConsentStatus.unknown
[Startup] activePipeline analyzer mode: gateway
[Startup] cloudFeedbackConsentService status: CloudFeedbackConsentStatus.unknown
[Startup] cloudTextConsentService status: CloudTextConsentStatus.unknown
[Startup] cloudFeedbackUploader type: HttpCloudFeedbackUploader
[Startup] ======================
```

关键指标：

- `SharedPreferences ready: true` 或 `webLocalStorageFallback: true`：存储层可用
- `llmConsentService status` 不为 `null`：同意状态服务装配成功
- `activePipeline analyzer mode: gateway`：LLM 网关已激活（不是 `mock`）
- `cloudFeedbackConsentService status` 不为 `null`：M7 云端采集同意服务装配成功
- `cloudFeedbackUploader type: HttpCloudFeedbackUploader`：M7 云端上传器已装配为 HTTP 实现（非 Mock）

## 十六、免责声明

本项目为高校竞赛 Demo 原型，定位为情绪调节与正念放松辅助工具，提供的音乐体验不具备医疗诊断或治疗功能，不替代专业心理咨询与医疗建议。如有严重情绪困扰或睡眠障碍，请及时寻求专业医师帮助。
