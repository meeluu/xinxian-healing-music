# 心弦 XinXian

> AI 心境解析 + 个性化音乐陪伴 Web 应用

心弦是一款基于 Flutter Web 的情绪陪伴 Demo。用户输入当下心境后，系统通过 LLM 生成情绪画像与音乐参数，并播放匹配的本地音频素材，形成「自然语言 → AI 情绪解析 → 音乐方案 → 音频体验 → 用户反馈」的完整闭环。

- **正式体验地址**：[https://xinxian-music.xyz](https://xinxian-music.xyz)
- **当前版本**：`v1.0.0 · P4-comfort-lyrics-1 · Cloudflare Pages`
- **定位**：辅助情绪调节、睡前舒缓、正念陪伴、温和充能的轻量化工具，**不提供医疗诊断或治疗**，不替代专业心理咨询与医疗建议（详见[第十二章 免责声明](#十二免责声明)）

---

## 目录

1. [项目简介](#一项目简介)
2. [当前状态总览](#二当前状态总览)
3. [核心用户流程](#三核心用户流程)
4. [技术架构](#四技术架构)
5. [已完成里程碑](#五已完成里程碑)
6. [P2-Web-v1.0 收尾成果](#六p2-web-v10-收尾成果)
6.5. [P3-Web-v1.0 第一批：反馈数据查询脚本 + 基础统计](#六点五p3-web-v10-第一批反馈数据查询脚本--基础统计)
6.6. [P3-Web-v1.0 第二批：测试数据标记与查询隔离](#六点六p3-web-v10-第二批测试数据标记与查询隔离)
6.7. [P3-Web-v1.0 第三批：真实反馈采集准备](#六点七p3-web-v10-第三批真实反馈采集准备)
6.8. [P4-AI-Music-v1.0 第一批：AI 音乐生成服务选型调研](#六点八p4-ai-music-v10-第一批ai-音乐生成服务选型调研)
6.9. [P4 新方向：困惑解惑 → 歌词 → AI 歌曲生成](#六点九p4-新方向困惑解惑--歌词--ai-歌曲生成)
6.10. [P4 新方向第一批：困惑解惑 + 歌词生成 LLM 流程](#六点十p4-新方向第一批困惑解惑--歌词生成-llm-流程)
7. [数据与隐私](#七数据与隐私)
8. [环境变量与部署](#八环境变量与部署)
9. [本地开发与验证](#九本地开发与验证)
10. [当前仍是 Mock / Demo / 待产品化的部分](#十当前仍是-mock--demo--待产品化的部分)
11. [后续路线图](#十一后续路线图)
12. [免责声明](#十二免责声明)
13. [变更记录](#十三变更记录)

---

## 一、项目简介

### 1.1 心弦是什么

心弦（XinXian）是 Project Epsilon 下的高校竞赛 Demo，探索「自然语言 → 情绪画像 → 个性化音乐参数 → 音频体验」的自动化链路。用户只需输入真实心境描述，系统就会基于文本中的情绪线索生成对应的音乐情绪画像和音乐参数，为用户提供辅助情绪调节、睡前舒缓、正念放松和音乐陪伴体验。

当前阶段以 **Web Demo** 为主要体验入口，已部署至 Cloudflare Pages 正式域名。

### 1.2 目标用户与使用场景

目标用户：

- 18-30 岁学生与青年职场人
- 面临备考、加班、睡眠困扰、情绪低落、关系压力的人群
- 有正念冥想、睡前放松、自我情绪疏导需求的人群

典型场景：

- 睡前脑子停不下来，希望获得舒缓音频
- 备考或工作压力大，希望快速放松
- 情绪低落或内耗时，希望获得陪伴式音乐体验
- 想通过文字记录心境，并得到个性化音乐反馈

### 1.3 项目价值

- **社会价值**：为年轻人提供低门槛、轻量化的情绪陪伴和辅助放松入口，降低正念音乐体验的使用门槛
- **工程价值**：探索从自然语言到音乐参数再到音频体验的自动化链路，为个性化音频生成产品提供原型验证；前端零 API Key 泄露的同域网关架构可直接复用于其他 LLM 应用
- **科研价值**：后续可结合心理量表、用户反馈、生理数据，设计「通用音乐 vs 定制化音乐」的对比实验，量化个性化音乐对辅助情绪调节体验的影响
- **商业价值**：可拓展至睡前舒缓、正念冥想、校园心理支持、企业 EAP 员工关怀、AI 内容生成等场景

### 1.4 医疗免责（简述）

本项目定位为**情绪调节与正念放松辅助工具**，提供的音乐体验不具备医疗诊断或治疗功能，不替代专业心理咨询与医疗建议。完整免责声明见[第十二章](#十二免责声明)。

---

## 二、当前状态总览

### 2.1 当前阶段

- **阶段**：`P4-AI-Music-v1.0 进行中 / P4-comfort-song-design-1-fix1（新方向：困惑解惑 → 歌词 → AI 歌曲；主线 provider：MiniMax）`
- **版本号**：`v1.0.0 · P4-comfort-song-design-1-fix1 · Cloudflare Pages`（首页底部显示 `心弦 v1.0.0 · P4-comfort-song-design-1-fix1 · Cloudflare Pages`）
- **构建日期**：2026-07-18
- **部署目标**：Cloudflare Pages
- **上一阶段**：P3-Web-v1.0 已完成（`P3-data-3`，2026-07-11 第三批完成）；P2-Web-v1.0 已完成（`P2-stable`，2026-07-11 收尾验收通过）

### 2.2 当前部署架构

- **静态托管**：Cloudflare Pages（正式域名 `xinxian-music.xyz`）
- **后端网关**：Cloudflare Pages Functions（`/api/analyze-mood`、`/api/submit-feedback`、`/api/health`）
- **云端数据库**：Cloudflare D1 `xinxian-feedback`（`feedback` 表 25 字段，存储匿名结构化反馈）
- **LLM 服务**：DeepSeek OpenAI-compatible API（通过 Pages Functions 转发，前端零 API Key 泄露）

### 2.3 当前已具备能力

- Flutter Web 可运行 Demo，已部署至 Cloudflare Pages 正式域名，响应式适配桌面端与移动端
- 心境输入页 → AI 情绪解析动画页 → 疗愈方案展示页 → 真实本地音频播放页 → 用户反馈表单 → 历史记录页 完整闭环
- LLM 情绪解析（DeepSeek API）+ 本地关键词解析 fallback（LLM 失败或用户未同意时自动降级，用户无感知）
- `EmotionToMusicPlanMapper` 让 LLM 返回的 `tags` / `valence` / `arousal` / `intensity` / `targetState` / `dominantNeed` 真正参与 BPM、脑波、乐器、噪音层、和声、generationPrompt 生成
- `TargetStateResolver` 8 级优先级规则引擎处理自然语言意图冲突（如「备考压力大睡不着」→ sleep）
- 5 类 targetState（`sleep` / `regulate` / `soothe` / `focus` / `energize`）分别匹配本地预置音频
- 匿名云端反馈采集（Cloudflare D1）+ 两层同意机制（云端采集总开关 + 文字反馈独立开关）
- 反馈数据分析与导出（`scripts/feedback-queries.sql` 20 条基础查询 + 附录 B 消融实验 6 条 + 测试数据隔离过滤 + 真实反馈分析预检 + Wrangler SQL + Cloudflare D1 Console）
- PowerShell 辅助查询脚本（`scripts/query-feedback.ps1`，支持 `-Recent` / `-ByTargetState` / `-ByAudio` / `-LowRating` / `-HighRating` / `-Notes` / `-Daily` / `-TextRatio` / `-ExcludeTest` / `-OnlyTest` / `-MinVersion` / `-PreCheck` 参数，P3 第一批 + 第二批 + 第三批新增）
- 消融对比实验分组记录能力（`HashExperimentAssigner`，默认关闭，编译期常量控制）
- 历史记录本地持久化（shared_preferences + Web localStorage fallback，最多 100 条，支持查看 / 删除 / 清空 / 撤销删除）
- 隐私同意弹窗 + 解析设置入口（用户可随时切换 AI 解析 / 本地解析）
- PWA 基础缓存策略（`web/_headers` 控制各路径 Cache-Control，三路径线上已验证通过）
- Cloudflare 限流规则（`/api/analyze-mood` 已配置并 Active）

---

## 三、核心用户流程

当前 Demo 已实现完整体验闭环：

```
自然语言心境输入
  → AI 情绪画像生成（LLM / 本地 fallback）
  → 音乐参数映射
  → 疗愈音频播放
  → 用户反馈采集
  → 本地历史记录（+ 可选云端匿名上传）
```

### 3.1 详细步骤

1. **输入心境**：用户在首页输入当下心境描述（可点击示例 chip 快速填入）
2. **AI 解析**：
   - 首次点击「生成专属疗愈方案」时，若 LLM 服务已装配且尚未选择 AI 偏好，弹出 AI 同意弹窗
   - 用户同意 → 调用同域 `/api/analyze-mood`（由 DeepSeek API 解析）
   - 用户拒绝 / LLM 失败 → 自动 fallback 到本地关键词解析（Mock），用户无感知
3. **生成方案**：`EmotionToMusicPlanMapper` 基于 LLM 情绪画像生成音乐参数（BPM、基准频率、脑波倾向、推荐乐器、噪音层、和声色彩）；`TargetStateResolver` 修正意图冲突，输出最终 targetState
4. **展示方案**：方案页默认展示「为什么推荐这段音乐」+ 推荐理由 + 主要音乐目标 + 推荐时长 + 音频标题；技术参数默认折叠到「查看音乐参数」
5. **播放推荐音频**：`AudioAssetCatalog` 按 targetState 自动匹配本地预置音频（sleep / regulate / soothe / focus / energize 五类）；播放完成后显示温和 CTA「听完这段了吗？记录一下感受」
6. **提交反馈**：
   - 反馈页默认只突出评分 + 提交，状态评分 slider 和文字反馈折叠到「想多说一点？」
   - 状态评分语义：左 = 状态较差，右 = 状态很好
   - 未同意云端采集 → 默认只保存本地，不强制弹窗
   - 已同意云端采集 → fire-and-forget 上传匿名结构化数据到 D1，失败不影响本地
7. **历史记录与设置**：
   - 历史记录页支持查看 / 删除单条 / 清空全部 / 撤销删除（保留原始 startedAt）
   - 首页底部精简为「查看历史记录 + 设置」+ 版本号
   - 设置弹窗统一收纳：AI 解析设置 / 云端反馈采集 / 隐私政策 / 关于心弦

### 3.2 数据语义

| 字段 | 说明 |
|---|---|
| `tensionBefore` / `tensionAfter` | 字段名保持兼容，值范围 0.0–1.0，UI 语义为「值越大状态越好」 |
| `calmnessScore` | 派生公式 `(tensionAfter × 100).round()`，0-100，值越大 = 状态越好（[cloud_feedback_payload.dart](file:///d:/xinxian_healing_music/lib/models/cloud_feedback_payload.dart) L157） |
| `improvement` | 后续分析用 `after - before`，正值代表状态改善（D1 schema 未存储，P3 补齐派生） |
| D1 schema `calmnessScore INTEGER` | 字段存在，[schema/feedback.sql](file:///d:/xinxian_healing_music/schema/feedback.sql) L43 |
| `submit-feedback` API | 正常接收 `calmnessScore`，未破坏兼容 |

---

## 四、技术架构

### 4.1 整体架构

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
│  ├─ /api/health：健康检查，不访问 D1 / LLM / env         │
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

### 4.2 技术栈

- **前端框架**：Flutter 3.44+ / Dart 3.12+
- **音频播放**：just_audio
- **本地存储**：shared_preferences（含 Web localStorage fallback）
- **HTTP 客户端**：http
- **静态托管**：Cloudflare Pages
- **后端网关**：Cloudflare Pages Functions（ES Modules）
- **LLM 服务**：DeepSeek OpenAI-compatible API
- **云端数据库**：Cloudflare D1（SQLite，数据库 `xinxian-feedback`，存储匿名结构化反馈数据）
- **构建工具**：Flutter CLI / wrangler
- **音频素材**：本地 assets（`music/` 目录下 5 类预置音频，按 targetState 匹配；**非实时 AI 生成**）

### 4.3 Pipeline 分层架构

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

### 4.4 核心模块说明

#### EmotionToMusicPlanMapper（M5 核心映射层）

`lib/pipeline/mapper/emotion_to_music_plan_mapper.dart`，6 步算法：

1. 按 tags 关键词修正 targetState（失眠 → sleep、烦躁 → regulate、低落 → soothe、疲惫 → energize 等）
2. 按修正后的 targetState 取 5 套基础参数（BPM 范围 / 脑波目标 / 推荐乐器 / 噪音层 / 和声基础 / 推荐时长）
3. arousal 在 BPM 范围内插值（arousal 越高 BPM 越低）
4. valence 调整和声色彩（valence ≤ -0.5 低明度小调；valence ≥ 0.3 温暖大调）
5. intensity 调整动态描述
6. 组合文案（title / guidance / explanation / generationPrompt），统一使用「辅助放松 / 情绪调节 / 睡前舒缓 / 正念陪伴」措辞

关键设计：Mock 与 LLM 复用同一映射逻辑；纯函数无状态；5 类 targetState 向后兼容 `relax` / `company` 旧值；`generationPrompt` 仅生成文本提示词，为后续真实生成模型预留数据通道。

#### AudioAssetCatalog（M6 核心音频匹配层）

`lib/data/audio_asset_catalog.dart`，4 级匹配算法：

1. targetState 精确匹配（sleep → sleep_01.mp3 等）
2. brainwaveTarget 兜底匹配
3. noise/instruments 语义匹配
4. 最终 fallback 返回 `sleep_01.mp3`

关键设计：纯函数无状态；不暴露文件路径（UI 只展示音频标题）；Web 平台使用 `AudioSource.uri` 解决 just_audio asset 路径解析问题；**当前为本地预置音频，非实时生成**；后续真实生成模型接入时只需替换 `AudioGenerationPort` 实现，UI 与上层 pipeline 无需改动。

#### TargetStateResolver（M6.1 意图识别精修层）

`lib/pipeline/intent/target_state_resolver.dart`，8 级优先级规则：

1. 明确任务意图优先（写论文 / 学习 → focus）
2. 强信号失眠优先（睡不着 → sleep）
3. 强信号情绪宣泄（烦躁 / 愤怒 → regulate）
4. 强信号低落（难过 / 想哭 → soothe）
5. 强信号疲惫（没精神 → energize）
6. arousal / valence 分流
7. 信任 LLM 返回值
8. 最终 fallback 返回 sleep

关键设计：基于 `MoodProfile.sourceText` 原文做关键词匹配（不依赖 LLM tags）；sourceText 不持久化（避免历史记录泄露用户原文）；Mock 与 LLM 复用同一 resolver；31 条端到端测试覆盖。

#### CloudFeedbackUploader（M7 匿名云端反馈采集层）

`lib/pipeline/ports/cloud_feedback_uploader.dart` Port + `HttpCloudFeedbackUploader` 实现，与本地 `FeedbackRepository` 并存（非替换关系）。

- **D1 数据库**：`xinxian-feedback`，`feedback` 表 25 字段，主键 `listeningSessionId`，4 个索引
- **Pages Function**：`functions/api/submit-feedback.js`，字段白名单 + 长度限制 + D1 upsert + 三层 try/catch，绝不返回 502
- **两层同意机制**：`CloudFeedbackConsentService`（总开关）+ `CloudTextConsentService`（文字独立开关，默认 declined）
- **fire-and-forget**：6 秒超时，所有异常内部 catch，上传失败不影响本地反馈保存和用户体验
- **不上传心境原文**：`moodText` 不在 payload 中
- **本地删除不联动云端**：历史记录页删除仅操作本地仓储

### 4.5 API Key 零泄露设计

- 前端代码中**不包含任何 API Key、Base URL 或模型名**
- 前端只调用同域 `/api/analyze-mood`，由 Cloudflare Pages Functions 转发到 DeepSeek API
- API Key 仅保存在 Cloudflare 环境变量中，运行时通过 `context.env` 读取
- 即使前端代码被完全反编译，也无法获取 API Key

### 4.6 PWA / 缓存策略

通过 `web/_headers` 控制各路径 Cache-Control（**只新增缓存头策略，没有启用离线 PWA，没有手写 service worker**）：

| 路径 | Cache-Control | 理由 |
|---|---|---|
| `/` 和 `/index.html` | `no-cache, must-revalidate` | 必须总能拿到最新 `main.dart.js` 引用 |
| `/main.dart.js` | `no-cache, must-revalidate` | 代码核心，跟随 SW 内部 hash 校验 |
| `/flutter_bootstrap.js` | `no-cache, must-revalidate` | 引导脚本，变更频繁 |
| `/flutter.js` | `no-cache, must-revalidate` | Flutter 核心脚本 |
| `/flutter_service_worker.js` | `no-cache, must-revalidate` | SW 自身必须能更新，避免死锁 |
| `/manifest.json` | `max-age=3600, public` | 短缓存（1 小时） |
| `/assets/music/*` | `public, max-age=86400, must-revalidate` | 中长缓存（1 天）+ revalidate |
| `/canvaskit/*` | `max-age=604800, public` | 长缓存（7 天） |
| `/api/*` | `no-store` | API 绝不缓存 |

三路径（音频 / API / SW）线上已验证通过。

---

## 五、已完成里程碑

| 阶段 | 主要成果 | 状态 |
|---|---|---|
| **M1** | Pipeline 架构整理：抽象核心模型与 Port（MoodAnalyzerPort / MusicFeatureExtractorPort / AudioGenerationPort / AudioPostProcessorPort / FeedbackRepository / ExperimentAssigner），HealingMusicPlan 重构为聚合根，UI 通过 HealingPipeline 编排器获取方案 | ✅ 已完成 |
| **M2** | ListeningSession 与实验分组结构：引入会话生命周期记录，sessionId 贯穿全链路，ExperimentVariant 支持 custom / generic / control 三组扩展点 | ✅ 已完成 |
| **M3** | 本地持久化历史记录：ListeningSession 与 FeedbackRecord 通过 shared_preferences + JSON 保存到用户本地设备（最多 100 条），新增历史记录页支持查看 / 删除 / 清空 | ✅ 已完成 |
| **M4** | LLM 情绪解析网关 + Cloudflare Pages Functions + 正式域名部署：接入 DeepSeek OpenAI-compatible API 实现真实 AI 情绪解析，前端零 API Key 泄露，已完成正式域名 9 步全流程验收 | ✅ 已完成 |
| **M5** | LLM 情绪画像驱动音乐方案映射：新增 `EmotionToMusicPlanMapper`，让 LLM 返回的 tags / valence / arousal / intensity / targetState / dominantNeed 真正参与 BPM、脑波、乐器、噪音层、和声、generationPrompt 生成；Mock 与 LLM 复用同一映射逻辑；支持 5 类 targetState | ✅ 已完成 |
| **M6** | 多音频资源与情绪匹配播放：新增 `AudioAssetCatalog` 按 targetState 4 级匹配算法选择本地音频；5 类 targetState 分别匹配预置音频；播放页与方案页展示音频标题而不暴露文件路径 | ✅ 已完成 |
| **M6.1** | targetState 意图识别精修：新增 `TargetStateResolver` 8 级优先级规则引擎处理意图冲突；31 条端到端测试覆盖 5 类 targetState + 6 类冲突场景 | ✅ 已完成 |
| **M7.0** | 匿名云端反馈采集：Cloudflare D1 数据库 `xinxian-feedback`（feedback 表 25 字段）+ Pages Functions `/api/submit-feedback`；`CloudFeedbackUploader` Port；两层同意机制；fire-and-forget 上传；不上传心境原文 | ✅ 已完成 |
| **M8** | 反馈数据分析与导出：`scripts/feedback-queries.sql`（8 条常用 D1 查询 + CSV 导出方式），采用 Wrangler SQL + Cloudflare D1 Console 轻量方案 | ✅ 已完成 |
| **M8.1** | 消融对比实验设计与分组记录（保守 MVP）：`HashExperimentAssigner` 按 sessionId FNV-1a hash 稳定分流；编译期常量 `ENABLE_EXPERIMENT` 控制（默认 false，零体验影响）；仅记录 `experimentVariant` 标签，不改推荐结果 | ✅ 已完成 |
| **P1-Web-v1.0** | Web 产品化修复：history restore 完整链路 / analysis_screen 响应式 / index.html 元信息 / `/api/health` 健康检查 / D1 写入超时保护 / CORS 白名单 / targetState 枚举统一 / PWA 缓存策略 / Cloudflare 限流规则（analyze-mood 已配置 Active） | ✅ 已完成 |
| **P2-Web-v1.0** | Web 体验优化（4 批 + 4 fix）：首次弹窗时机优化 / 方案页去技术化 / 推荐理由场景化 / 反馈页降成本 / 状态评分语义修正 / 首页设置入口整理；版本号同步到 `P2-stable` | ✅ 已完成 / 可关闭 |
| **P3-Web-v1.0 第一批** | 反馈数据查询脚本 + 基础统计：`scripts/feedback-queries.sql` 新增查询 9-12（总体平均评分 / targetState 聚合 / 低评分列表 / 高评分列表）；新增 `scripts/query-feedback.ps1` PowerShell 辅助脚本（8 个参数）；不改 D1 schema / API / 前端 UI | 🔜 进行中 |
| **P3-Web-v1.0 第一批 fix1** | 修复 `query-feedback.ps1` PowerShell 5.1 ParserError：所有 SQL 改用 here-string `@" ... "@` 避免单引号 / `<=` / `>=` 被解析坏；文件转存为 UTF-8 with BOM 解决中文乱码导致的 here-string 标记失效 | ✅ 已完成 |
| **P3-Web-v1.0 第二批** | 测试数据标记与查询隔离：`query-feedback.ps1` 新增 `-ExcludeTest` / `-OnlyTest` 参数；`feedback-queries.sql` 新增查询 13-16（测试数据占比 / 排除测试数据统计 / 仅测试数据统计 / 测试数据明细）；保守识别规则（clientVersion v0.x / sessionId 含 test / 文字反馈含测试词）；不改 D1 schema / 不删除远程数据 | 🔜 进行中 |
| **P3-Web-v1.0 第三批** | 真实反馈采集准备：`query-feedback.ps1` 新增 `-MinVersion` / `-PreCheck` 参数；`feedback-queries.sql` 新增查询 17-20（真实反馈数量+门槛 / clientVersion 分布 / 日期分布 / targetState 分布）；建立分析门槛（<30 只看链路 / 30-100 方向性观察 / >100 分组优化）；当前真实反馈=0，不基于测试数据优化推荐 | 🔜 进行中 |

---

## 六、P2-Web-v1.0 收尾成果

P2 阶段聚焦真实用户第一次进入网站、开始解析、进入播放页、提交反馈的体验优化。**只改 UI 文案、弹窗触发时机、版本号**，不改 API / D1 schema / pipeline / 音频匹配逻辑，不删除任何隐私保护，不引入新依赖。

### 6.1 首次弹窗时机优化（第一批）

**问题**：首次进入首页立刻弹出 LLM 同意弹窗，用户还没看到产品价值就被迫选择。

**修复**：[home_screen.dart](file:///d:/xinxian_healing_music/lib/screens/home_screen.dart) `initState` 移除 `addPostFrameCallback(_maybePromptConsent)`，改为用户第一次点击「生成专属疗愈方案」时检查 `llmConsentService.needsPrompt`，若仍为 `unknown` 才弹出 `LlmConsentDialog`，弹窗结束后继续跳转。已选择过（accepted / declined）或服务未装配时直接跳转。

**隐私保护保留**：`LlmConsentService` 三态逻辑不变；首次弹窗仍为 `barrierDismissible: false` 必须做选择；用户拒绝时仍自动 fallback 到 mock 本地解析；「解析设置」入口仍可随时切换。

### 6.2 方案页去技术化（第二批）

**问题**：方案页默认铺开 BPM / 频率 / 脑波 / 噪声层等技术参数，用户先看到技术细节而不是「为什么推荐」。

**修复**：[plan_screen.dart](file:///d:/xinxian_healing_music/lib/screens/plan_screen.dart) 从 `StatelessWidget` 改为 `StatefulWidget`，新增 `_showParams` 状态（默认 `false`）。新增「为什么推荐这段音乐」卡片（推荐理由 + 主要音乐目标 + 推荐时长 + 推荐音频标题）；「音乐参数」卡片改为可展开（默认只显示「查看音乐参数」入口）。[player_screen.dart](file:///d:/xinxian_healing_music/lib/screens/player_screen.dart) 移除 5 个技术参数 chip，替换为主要音乐目标的简短文案胶囊。

**技术参数数据全部保留**，只改变默认展示层级。

### 6.3 推荐理由场景化（第二批 fix1）

**问题**：第二批推荐理由只按 `targetState` 使用静态模板，缺少对用户输入场景的回应。

**修复**：新增共享 helper [recommendation_reason.dart](file:///d:/xinxian_healing_music/lib/utils/recommendation_reason.dart)，`buildRecommendationReason(plan, moodText)` 合并 `moodText` + `mood.summary` + `tags` + `dominantNeed`，按场景关键词优先匹配（睡眠 > 专注 > 低能量 > 冲突 > 疲惫放松），未命中 fallback 到 targetState 模板。方案页与播放页共用 helper，避免两页说法冲突。

### 6.4 反馈页降成本（第三批）

**问题**：反馈页默认铺开评分 + 状态评分 + 文字反馈，首次填写成本高。

**修复**：[feedback_screen.dart](file:///d:/xinxian_healing_music/lib/screens/feedback_screen.dart) 新增 `_showMore` 状态（默认折叠），默认只突出评分 + 提交，状态评分 slider 和文字反馈折叠到「想多说一点？」展开区。[player_screen.dart](file:///d:/xinxian_healing_music/lib/screens/player_screen.dart) 新增 `_completed` 状态，播放完成后显示温和 CTA「听完这段了吗？记录一下感受」+「写反馈」按钮，重播时收回 CTA。

**未同意云端采集时**：移除提交瞬间的 `CloudFeedbackConsentDialog.show` 强制弹窗，默认只保存本地反馈，不打断用户。用户可在设置中主动开启云端反馈采集。

### 6.5 状态评分语义修正（第三批 fix1 / fix2 / fix3）

**问题**：反馈页 slider 语义不直观（「紧绷度」体验前拉到右边 = 很紧绷、体验后拉到左边 = 很放松，方向不统一）；`calmnessScore` 派生公式与 UI 语义不一致；文案略口语化。

**修复**：

| fix | 改动 | 涉及文件 |
|---|---|---|
| fix1 | slider 语义统一为「状态评分」（左 = 状态较差，右 = 状态很好）；模块标题「紧绷度变化」→「状态变化」；底层字段 `tensionBefore`/`tensionAfter` 保持兼容 | [feedback_screen.dart](file:///d:/xinxian_healing_music/lib/screens/feedback_screen.dart) |
| fix2 | `calmnessScore` 派生公式 `(1-tensionAfter)×100` → `tensionAfter×100`（值越大 = 状态越好）；更新测试预期值 + 新增 before=0.2/after=0.8 语义验证 | [cloud_feedback_payload.dart](file:///d:/xinxian_healing_music/lib/models/cloud_feedback_payload.dart)、[feedback-queries.sql](file:///d:/xinxian_healing_music/scripts/feedback-queries.sql)、[cloud_feedback_payload_test.dart](file:///d:/xinxian_healing_music/test/cloud_feedback_payload_test.dart) |
| fix3 | slider 动态文案中性化：不太好/有点低落/还可以/挺好/很好 → 状态较差/状态偏低/状态平稳/状态较好/状态很好；副标题改为「左侧表示状态较差，右侧表示状态较好」 | [feedback_screen.dart](file:///d:/xinxian_healing_music/lib/screens/feedback_screen.dart) |

**数据语义保持不变**：`before` / `after` 字段名、值范围（0.0–1.0）、默认值（0.5）不变；`calmnessScore` 公式 `tensionAfter × 100`；D1 schema 未改动；`submit-feedback` API payload 未改动。

### 6.6 首页设置入口整理（第四批 + fix1）

**问题**：首页底部 4 个入口（历史记录 / 解析设置 / 云端采集 / 隐私政策）分散，不够清爽。

**修复**：[home_screen.dart](file:///d:/xinxian_healing_music/lib/screens/home_screen.dart) 底部从 4 个 TextButton 精简为 2 个（查看历史记录 + 设置）+ 版本号文本。新增 `_showSettingsDialog()` 使用 `ResponsiveDialogContainer` 弹出统一设置弹窗，收纳：AI 解析设置 / 云端反馈采集 / 隐私政策 / 关于心弦。复用原有逻辑，不删除任何现有功能。

**fix1 回归修复**：第四批上线后发现点击「设置」只显示黑色遮罩不显示内容。根因是 `DialogButtonBar(children: [FilledButton(...)])` 单 child 触发 `BoxConstraints forces an infinite width` 断言。修复：footer 改为 `Align(alignment: centerRight, child: FilledButton)`；4 个 `_SettingsTile` 的 `onTap` 改为 `Future.microtask(() => ...)` 避免 dialog 叠加触发布局异常。

### 6.7 P2-stable 验证结果

P2 阶段（第一批 ~ 第四批 fix1）9 个子项全部 ✅ 代码与 README 一致，核心用户路径 14 项手动验收清单完整，数据语义 6 项核对通过，版本号同步到 `P2-stable`。

验证命令（P2 收尾阶段执行）：

- `flutter analyze`：No issues found! (ran in 50.4s)
- `flutter test`：197 passed + 5 skipped（All tests passed!）
- `flutter build web --release`：√ Built `build\web` (50.8s)

### 6.8 P2 修复记录摘要

| 批次 | 摘要 | buildLabel |
|---|---|---|
| 第一批 | 首次 AI 同意弹窗延后到点击「生成方案」时触发；播放页 / 解析页去技术化文案 | `P2-ui-1` |
| 第二批 | 方案页技术参数默认折叠；「为什么推荐这段音乐」卡片；播放页去技术参数 chip | `P2-ui-2` |
| 第二批 fix1 | `recommendation_reason.dart` 共享 helper，优先按用户输入场景生成文案 | `P2-ui-2-fix1` |
| 第三批 | 播放完成反馈 CTA；反馈页默认低成本填写；未同意云端采集不强制弹窗 | `P2-ui-3` |
| 第三批 fix1 | slider 语义统一为状态评分（左差右好）；字段名保持兼容 | `P2-ui-3-fix1` |
| 第三批 fix2 | `calmnessScore = tensionAfter × 100`；improvement 用 after-before | `P2-ui-3-fix2` |
| 第三批 fix3 | slider 文案中性化（状态较差/偏低/平稳/较好/很好） | `P2-ui-3-fix3` |
| 第四批 | 首页底部精简为「查看历史记录 + 设置」+ 版本号；设置弹窗收纳四项 | `P2-ui-4` |
| 第四批 fix1 | 设置弹窗 footer 改为 `Align`；子入口点击用 `Future.microtask` + `mounted` | `P2-ui-4-fix1` |
| 收尾验收 | P2 全部 9 子项核对通过；版本号同步到 `P2-stable` | `P2-stable` |

---

## 六点五、P3-Web-v1.0 第一批：反馈数据查询脚本 + 基础统计

P3 第一批聚焦反馈数据查询能力建设，让项目能从 Cloudflare D1 `feedback` 表中快速查看反馈数据质量和基础运营指标。**只改脚本和 SQL，不改前端 UI、不改 D1 schema、不改 `submit-feedback` API、不修改远程 D1 数据**。

### 6.5.1 D1 schema 与字段确认

读取 `schema/feedback.sql` / `scripts/feedback-queries.sql` / [cloud_feedback_payload.dart](file:///d:/xinxian_healing_music/lib/models/cloud_feedback_payload.dart) 确认：

| 字段 | 类型 | 语义 | 来源 |
|---|---|---|---|
| `relaxationScore` | INTEGER | 1-5（5 = 最放松） | 从 `FeedbackRecord.rating` 映射 |
| `calmnessScore` | INTEGER | 0-100（100 = 状态最好） | 从 `tensionAfter × 100` 派生（P2 fix2 起语义统一为"值越大状态越好"） |
| `targetState` | TEXT | sleep / regulate / soothe / focus / energize | 五类 |
| `audioAssetId` | TEXT | 脱敏文件名（如 `sleep_01.mp3`） | 不含路径前缀 |
| `freeTextFeedback` | TEXT | 用户文字反馈 | 仅在用户单独勾选同意时上传，可为 NULL |

**⚠️ improvement 指标限制**：D1 schema **未存储** `tensionBefore` / `tensionAfter` 原始值，只有派生的 `calmnessScore`（= `tensionAfter × 100`）。因此当前**不能直接计算 improvement = after - before**，只能用 `calmnessScore`（体验后状态）作为近似指标，或后续 P3 扩展补齐 `tensionBefore` D1 字段 / 新增 `improvement` 派生字段。

### 6.5.2 新增 / 整理的 SQL 查询

在 [scripts/feedback-queries.sql](file:///d:/xinxian_healing_music/scripts/feedback-queries.sql) 中保留 M8 原有查询 1-8 + 附录 B（B1-B6），**新增查询 9-12**：

| 查询 | 用途 | 状态 |
|---|---|---|
| 查询 1 | 总反馈数 | M8 已有 |
| 查询 2 | targetState 分布（数量 + 百分比） | M8 已有 |
| 查询 3 | audioAssetId 平均评分对比 | M8 已有 |
| 查询 4 | 最近 20 条反馈 | M8 已有 |
| 查询 5 | 每日反馈数量趋势 | M8 已有 |
| 查询 6 | 文字反馈占比 | M8 已有 |
| 查询 7 | 实验分组统计 | M8 已有 |
| 查询 8 [隐私敏感] | 文字反馈原文查看 | M8 已有 |
| **查询 9** | **总体平均评分（relaxationScore + calmnessScore + 区间）** | **P3 新增** |
| **查询 10** | **按 targetState 分组：数量 + 平均评分 + 平均 calmnessScore + 区间** | **P3 新增** |
| **查询 11** | **低评分反馈列表（relaxationScore ≤ 2）** | **P3 新增** |
| **查询 12** | **高评分反馈列表（relaxationScore ≥ 4）** | **P3 新增** |
| 附录 B1-B6 | 消融实验分组分析 | M8.1 已有 |

同时更新文件头部注释，新增字段语义说明、improvement 指标限制说明、PowerShell 脚本用法引用，并在文件末尾新增"P3 指标分析能力说明"段落（✅ 当前可分析指标 13 项 + ❌ 当前还缺的指标 4 项）。

### 6.5.3 PowerShell 辅助脚本

新增 [scripts/query-feedback.ps1](file:///d:/xinxian_healing_music/scripts/query-feedback.ps1)，封装 `wrangler d1 execute` 命令：

```powershell
# 基础统计（默认）：总反馈数 + 平均评分 + targetState 分布 + 文字反馈占比
.\scripts\query-feedback.ps1

# 查看最近 20 条反馈
.\scripts\query-feedback.ps1 -Recent

# 按 targetState 聚合（数量 + 平均评分 + 平均 calmnessScore）
.\scripts\query-feedback.ps1 -ByTargetState

# 按 audioAssetId 聚合（数量 + 平均评分）
.\scripts\query-feedback.ps1 -ByAudio

# 低评分反馈列表（relaxationScore <= 2）
.\scripts\query-feedback.ps1 -LowRating

# 高评分反馈列表（relaxationScore >= 4）
.\scripts\query-feedback.ps1 -HighRating

# 文字反馈原文 [隐私敏感]
.\scripts\query-feedback.ps1 -Notes

# 每日反馈数量趋势
.\scripts\query-feedback.ps1 -Daily

# 文字反馈占比
.\scripts\query-feedback.ps1 -TextRatio

# 查询本地 D1 副本（调试用，默认 --remote）
.\scripts\query-feedback.ps1 -Recent -Local
```

**前置条件**：已安装 Node.js + npx；已登录 wrangler（`npx wrangler login`）或配置了 `CLOUDFLARE_API_TOKEN`；D1 数据库 `xinxian-feedback` 已建表。

**安全说明**：脚本只读查询，不写入任何敏感信息，不修改远程 D1 数据。`-Notes` 参数查询文字反馈原文，标注为隐私敏感，仅供项目组内部分析。

### 6.5.4 当前可分析的反馈指标

✅ **当前可分析**（13 项）：

1. 总反馈数
2. targetState 分布（数量 + 百分比）
3. audioAssetId 平均评分对比
4. 最近 20 条反馈趋势
5. 每日反馈数量趋势
6. 文字反馈占比
7. 实验分组统计（custom / generic / control）
8. 文字反馈原文查看 [隐私敏感]
9. 总体平均评分（relaxationScore + calmnessScore + 区间）
10. 按 targetState 分组的反馈质量对比
11. 低评分反馈列表（relaxationScore ≤ 2）
12. 高评分反馈列表（relaxationScore ≥ 4）
13. 消融实验分组分析 B1-B6

❌ **当前还缺的指标**（需扩展 D1 schema 或派生字段）：

- **improvement（体验前后状态改善量 = after - before）**：D1 schema 未存储 `tensionBefore` / `tensionAfter` 原始值，只有派生的 `calmnessScore`（= `tensionAfter × 100`）。当前只能用 `calmnessScore` 作为"体验后状态"近似指标，无法计算"改善量"。后续 P3 扩展可补齐 `tensionBefore` D1 字段，或新增 `improvement` 派生字段
- **completionRatio（聆听完成率）**：D1 schema 无此字段，需 M8.2 / P3 后续扩展补齐
- **emotionMatchScore / willingToContinue**：D1 schema 已有字段，但前端当前未收集（M7.0 留空），数据均为 NULL
- **用户身份 / 跨设备聚合**：心弦为匿名 Demo，无用户系统，无法按用户聚合

### 6.5.5 验证结果

本批只改 SQL / PowerShell 脚本 / 版本号 / README，未改 Flutter 业务逻辑代码，但按规范仍运行验证命令：

- `flutter analyze`：No issues found! (ran in 39.6s)
- `flutter test`：197 passed + 5 skipped（All tests passed!）

PowerShell 脚本语法静态检查：脚本使用标准 `param()` + `switch` 参数 + `function` 定义，符合 PowerShell 5.1+ 语法；未执行远程 D1 查询（避免影响线上数据）。

### 6.5.6 fix1：修复 query-feedback.ps1 PowerShell 5.1 ParserError

**现象**：运行 `.\scripts\query-feedback.ps1` 时 PowerShell 5.1 报 ParserError：

- `参数列表中缺少参量`
- `表达式或语句中包含意外的标记`
- `"<"运算符是为将来使用而保留`
- 错误位置集中在 `$sql = "SELECT COALESCE(targetState, '(null)')..."`、`relaxationScore <= 2` 等 SQL 字符串附近

**根因**（两层问题）：

1. **字符串解析问题**：原 SQL 使用双引号字符串 `"..."`，其中包含单引号 `'(null)'`、`<=` / `>=` 运算符和中文 Title，被 PowerShell 解析器误判
2. **文件编码问题**：Write 工具保存为 UTF-8 无 BOM，PowerShell 5.1（Windows PowerShell）默认按 ANSI/GBK 解码，中文字符 UTF-8 多字节序列被错误解析，破坏 here-string `@" ... "@` 标记，导致 `FROM` 等关键字被当作 PowerShell 关键字

**修复**：

1. 所有 SQL 字符串改用 PowerShell here-string `@" ... "@`，避免单引号 / `<=` / `>=` 被解析坏
2. 在 `Invoke-D1Query` 函数中新增 `$compactSql = ($Sql -replace '\s+', ' ').Trim()`，将 here-string 中的换行和多余空白压缩为单空格，避免 wrangler `--command` 参数解析异常
3. 文件转存为 **UTF-8 with BOM**（`EF BB BF`），解决 PowerShell 5.1 中文乱码问题

**验证**：使用 `[System.Management.Automation.Language.Parser]::ParseFile()` 静态语法检查通过，无 parser 错误（token count: 456）；BOM 字节验证 `EF BB BF` 通过。

---

## 六点六、P3-Web-v1.0 第二批：测试数据标记与查询隔离

### 6.6.1 背景

当前 D1 `feedback` 表中的反馈大多是开发者测试时随便填写的数据，不是真实用户反馈，**不能用于推荐质量判断**。本批在不破坏现有 schema 的前提下，建立测试数据识别与分析过滤机制。

**核心原则**：

- 不改 D1 schema（不加字段、不迁移）
- 不删除远程 D1 数据（不执行 DELETE / UPDATE）
- 只做查询层过滤和文档说明
- 默认查询行为保持"全部数据"，正式分析时建议使用 `-ExcludeTest`

### 6.6.2 测试数据识别规则（保守策略）

满足以下**任一条件**即视为测试数据：

| 规则 | 条件 | 理由 |
|---|---|---|
| 1 | `clientVersion LIKE 'v0.%'` | v0.x.x 为 M4-M8 阶段开发版本，v1.0.0 起为 P3 正式版 |
| 2 | `sessionId LIKE '%test%' OR listeningSessionId LIKE '%test%'` | sessionId 含 test 字样 |
| 3 | `freeTextFeedback LIKE '%test%' OR '%测试%' OR '%随便%'` | 文字反馈含明显测试词 |

**不会被视为测试数据的情况**：

- 低评分（relaxationScore ≤ 2）——低评分可能是真实用户不满，不自动视为测试
- `analyzerMode = mock`——mock 是用户未同意 AI 解析时的正常 fallback，不自动视为测试
- 规则保守，可能漏判部分测试数据，但**不会误判真实用户数据**

### 6.6.3 PowerShell 脚本新增参数

[scripts/query-feedback.ps1](file:///d:/xinxian_healing_music/scripts/query-feedback.ps1) 新增两个过滤参数：

```powershell
# 排除测试数据（正式分析推荐）
.\scripts\query-feedback.ps1 -ExcludeTest

# 只看测试数据（反向排查用）
.\scripts\query-feedback.ps1 -OnlyTest

# 排除测试数据 + 按 targetState 聚合
.\scripts\query-feedback.ps1 -ByTargetState -ExcludeTest

# 排除测试数据 + 查看最近反馈
.\scripts\query-feedback.ps1 -Recent -ExcludeTest
```

**参数行为**：

- `-ExcludeTest`：所有查询自动追加 `AND NOT (测试条件)`，只返回真实用户反馈
- `-OnlyTest`：所有查询自动追加 `AND (测试条件)`，只返回测试数据（与 `-ExcludeTest` 互斥，同时传时 `-ExcludeTest` 优先）
- 默认（都不传）：返回全部数据，但脚本启动时会提示"正式分析时建议加 -ExcludeTest"
- `-ExcludeTest` / `-OnlyTest` 是过滤修饰符，不触发特定查询；单独传时执行默认基础统计（带过滤）

**默认基础统计新增"测试数据占比概览"**：无论是否传过滤参数，默认路径都会额外显示一个测试数据 vs 真实数据的占比总览（不受过滤影响），帮助快速判断当前数据质量。

### 6.6.4 SQL 查询新增

[scripts/feedback-queries.sql](file:///d:/xinxian_healing_music/scripts/feedback-queries.sql) 新增查询 13-16：

| 查询 | 用途 |
|---|---|
| 查询 13 | 测试数据占比总览（全部数据，不过滤）—— total / test_data / real_data / test_percentage |
| 查询 14 | 排除测试数据后的基础统计（真实用户反馈）—— 对应 `-ExcludeTest` |
| 查询 15 | 仅测试数据的基础统计（反向排查用）—— 对应 `-OnlyTest` |
| 查询 16 | 测试数据明细（含 test_reason 字段标注命中规则）—— 排查误判 |

### 6.6.5 ⚠️ 数据使用声明

**当前 D1 中的反馈数据大多为开发者测试时填写，不能作为真实用户结论。**

- 不要把当前评分（relaxationScore / calmnessScore 平均值）当成真实用户反馈质量
- 不要在答辩 / 报告中直接引用当前 D1 数据作为产品效果证据
- 后续正式分析应使用 `-ExcludeTest` 或查询 14
- 如果测试数据占比很高（>80%），说明当前 D1 数据主要是开发测试，应等真实用户数据积累后再分析
- 定期跑查询 16 排查是否有真实数据被误判为测试数据

### 6.6.6 验证结果

本批只改 SQL / PowerShell 脚本 / 版本号 / README，未改 Flutter 业务逻辑代码，但按规范仍运行验证命令：

- PowerShell 静态语法检查（Parser API）：通过
- `flutter analyze`：No issues found!
- `flutter test`：全部通过

---

## 六点七、P3-Web-v1.0 第三批：真实反馈采集准备

### 6.7.1 背景

P3 第二批已确认当前 D1 中 7 条反馈均为开发/验收测试数据，真实用户反馈为 **0**。下一步不应基于测试评分优化推荐，而应让后续真实反馈更容易被识别、更适合分析。

本批建立"真实反馈采集准备"机制：优先做轻量标记和分析准备，不做账号系统，不做复杂埋点。

### 6.7.2 真实反馈分析门槛

| 真实反馈数 | 分析策略 | 说明 |
|---|---|---|
| **< 30** | 只看链路 | 只确认反馈采集链路是否完整（提交 → D1 写入 → 查询可读），**不下推荐质量结论** |
| **30-100** | 方向性观察 | 可看趋势（哪个 targetState / audioAssetId 评分更高），但样本量不足，不做统计显著性判断 |
| **> 100** | 分组优化 | 可以开始基于 targetState / audioAssetId 做分组优化判断，结合消融实验数据做推荐策略调整 |

**当前状态**：真实反馈数 = **0**，远未达到分析门槛。后续收集真实反馈前，不基于测试数据优化推荐。

### 6.7.3 新增脚本参数

[scripts/query-feedback.ps1](file:///d:/xinxian_healing_music/scripts/query-feedback.ps1) 新增两个参数：

**`-MinVersion`**（版本过滤）：

```powershell
# 只看 v1.0.0 之后的反馈（排除 v0.x 开发版本）
.\scripts\query-feedback.ps1 -ExcludeTest -MinVersion v1.0.0

# 版本过滤 + 按 targetState 聚合
.\scripts\query-feedback.ps1 -ByTargetState -ExcludeTest -MinVersion v1.0.0
```

- 字符串比较（`clientVersion >= 'v1.0.0'`），适用于 semver 版本号
- 可与 `-ExcludeTest` / `-OnlyTest` 自由组合
- 独立于测试数据过滤，追加到 WHERE 子句末尾

**`-PreCheck`**（真实反馈分析预检）：

```powershell
# 一键查看真实反馈数量 + 门槛达成情况
.\scripts\query-feedback.ps1 -PreCheck
```

- 始终排除测试数据（不受 `-ExcludeTest` / `-OnlyTest` 影响）
- 显示 4 项预检数据：
  1. 真实反馈数量 + 分析门槛阶段（<30 / 30-100 / >100）
  2. clientVersion 分布（真实反馈来自哪些版本）
  3. 日期分布（真实反馈收集趋势）
  4. targetState 分布 + 平均评分（真实反馈按目标状态分组）
- 支持 `-MinVersion` 组合：`.\scripts\query-feedback.ps1 -PreCheck -MinVersion v1.0.0`

### 6.7.4 新增 SQL 查询

[scripts/feedback-queries.sql](file:///d:/xinxian_healing_music/scripts/feedback-queries.sql) 新增查询 17-20：

| 查询 | 用途 | 对应参数 |
|---|---|---|
| 查询 17 | 真实反馈数量 + 分析门槛判断（CASE 返回当前阶段） | `-PreCheck` |
| 查询 18 | 真实反馈的 clientVersion 分布 | `-PreCheck` |
| 查询 19 | 真实反馈的日期分布 | `-PreCheck` |
| 查询 20 | 真实反馈的 targetState 分布 + 平均评分 | `-PreCheck` |

### 6.7.5 当前真实反馈数

通过 `-PreCheck` 实际查询 D1 确认：

```
real_feedback_count: 0
analysis_stage: 未达门槛（<30）：只看链路，不下结论
```

**结论**：当前 D1 中 7 条反馈全部为测试数据，真实用户反馈为 0。后续正式分析必须使用 `-ExcludeTest`，且在真实反馈数达到 30 条前不下推荐质量结论。

### 6.7.6 验证结果

- PowerShell 静态语法检查（Parser API）：通过（696 tokens，0 errors）
- BOM 验证：通过（EF BB BF）
- 参数定义验证：ExcludeTest / OnlyTest / MinVersion / PreCheck 全部定义
- `query-feedback.ps1 -PreCheck` 实际运行：成功连接 D1，返回 `real_feedback_count: 0`
- `flutter analyze`：No issues found!
- `flutter test`：全部通过

---

### 6.8 P4-AI-Music-v1.0 第一批：AI 音乐生成服务选型调研

> 版本：`v1.0.0 · P4-research-1-fix1 · 2026-07-12`
> 完整调研文档：[docs/ai-music-generation-research.md](docs/ai-music-generation-research.md)（含 P4.1 调研 + P4.1-fix 供应商可用性复核）

#### 6.8.1 目标与范围

P4 的核心目标是**真正接入 AI 音乐生成**，将 `AudioGenerationPort` 从本地预置音频替换为真实 AI 生成模型。本批（第一批）只做技术调研与方案设计，**不接入代码、不调用付费 API、不改现有播放逻辑、不改 D1 schema、不改 Cloudflare Functions**，为 P4.2 起的实际接入提供选型依据与架构草图。

#### 6.8.2 调研覆盖方案

| 方案 | 类型 | 官方 API | 纯音乐 | 版权风险 |
|---|---|---|---|---|
| Suno v5.5 | 商业平台 | ❌ 无官方（第三方 wrapper） | ✅ | ⚠️ 高（诉讼中） |
| Udio v4 | 商业平台 | ❌ 无官方 API | ✅ | ⚠️ 中（部分和解） |
| **Stable Audio 3.0** | 商业 + 开源权重 | ✅ 官方 API | ✅ | ✅ 低（100% 授权数据） |
| MusicGen / AudioCraft | 开源 + Replicate | ❌ 无官方 | ✅ | ⚠️ 中（CC-BY-NC 非商业） |
| ElevenLabs Music | 商业 API | ✅ FAL.AI | ✅ | ⚠️ 中 |
| MiniMax Music 2.5 | 商业 API | ✅ FAL.AI | ✅ | ⚠️ 中 |
| Google Lyria 3 | 商业 API | ⚠️ 邀请制 | ✅ | ⚠️ 中 |

#### 6.8.3 推荐 Top 2

1. **🥇 Stable Audio 3.0（主选）**：官方 API + 训练数据 100% 授权（AudioSparx）+ 纯音乐原生 + 时长精确到秒 + Small 模型可移动端推理 + Community License（<$1M 年营收免费）
2. **🥈 MusicGen / AudioCraft（备选）**：完全开源 + Replicate ~$0.052/run + melody conditioning 独有能力；但权重 CC-BY-NC 4.0 非商业许可是硬伤，仅作 Demo 阶段备选

#### 6.8.4 不推荐方案

- **Suno v5.5**：无官方 API + 第三方 wrapper 不稳定 + 诉讼风险
- **Udio v4**：无官方 API，无法程序化调用
- **ElevenLabs Music**：$0.80/min 成本过高
- **MiniMax Music 2.5**：单次输出 50-76s 过短，需拼接
- **Google Lyria 3**：邀请制 + WebSocket 不适合 Pages Functions

#### 6.8.5 推荐接入路线

```
P4.1（本批，已完成）：技术调研 + 方案设计 + 架构草图
P4.2：Stable Audio 3.0 官方 API 接入（异步任务 + R2 存储 + fallback 预置）
P4.3：DSP 后处理接入（白噪音 / 粉红噪音 / EQ / 淡入淡出）
P4.4：成本与安全控制（限流 + 内容过滤 + R2 生命周期）
P4.5（可选）：MusicGen 二级 fallback
```

#### 6.8.6 接入架构草图

```
Flutter Web → Pages Function /api/generate-music → Stable Audio API（异步）
                                  ↓
            Pages Function /api/music-status/{taskId}（轮询）
                                  ↓ 完成则下载 → 上传 R2 → 返回 audioUrl
                                  ↓ 失败/超时 → fallback 到预置音频
            just_audio 播放 R2 URL 或预置音频
                                  ↓
            反馈页正常采集（audioAssetId 标记 gen_ 或预置名，D1 schema 不变）
```

#### 6.8.7 重要约束（本批遵守）

- 不接入真实 API Key
- 不写死任何第三方密钥
- 不调用付费生成接口
- 不改现有预置音频播放逻辑
- 不改 D1 schema
- 不改 Cloudflare Functions
- 不做医疗化表达（统一「辅助情绪调节 / 睡前舒缓 / 正念陪伴 / 温和充能」措辞）
- 保留预置音频作为未来 fallback 方案

#### 6.8.8 验证结果

- `flutter analyze`：通过（本批只新增文档 + 版本号，未改业务逻辑，未运行 test/build）
- 交付物：`docs/ai-music-generation-research.md` + README 同步 + `app_version.dart` 版本号更新

#### 6.8.9 P4.1-fix 供应商可用性复核（2026-07-12）

在 P4.1 调研基础上，对推荐方案做二次复核，确认以下关键结论（详见调研文档第十二章）：

- **Stable Audio 3.0 Large API 已确认可用**：Stability AI 官方 2026-05-20 release notes 明确发布 API；入口 platform.stability.ai；Large 模型（2.7B 参数）仅 API/企业授权，不开源；Small/Medium 开源权重
- **授权边界澄清**：Community License 允许商用（年营收 <$1M 免费，高校 Demo 适用）；Stable Audio Open 旧版 1.0 为 Research/Non-Commercial，不可混用
- **定价模型**：1 credit = $0.01，新用户 25 免费 credits，pay-per-use 无订阅要求
- **MusicGen 复核**：权重仍为 CC-BY-NC 4.0 非商业，仅作 P4.5 可选二级 fallback；Replicate ~$0.067/run
- **不推荐方案维持原判**：Suno/Udio 无官方 API；ElevenLabs 成本过高；MiniMax 时长不足；Lyria 邀请制
- **最终建议**：主方案 Stable Audio 3.0 Large API；备选 MusicGen（仅 fallback，需声明非商业）；暂不接入 Suno/Udio/ElevenLabs/MiniMax/Lyria/Stable Audio Open 旧版
- **待人工确认**：账号注册、25 免费 credits 到账、单次生成 credit 成本、速率限制、异步任务方式、输出格式、Community License 全文审阅等 10 项（详见调研文档 12.6 节）
- **下一步**：P4.2 最小 PoC（人工注册 + 用免费 credits 验证生成流程），**当前尚未接入真实生成**

#### 6.8.10 P4.2 最小 PoC 接入设计（2026-07-12）

在 P4.1 调研与 P4.1-fix 复核基础上，完成最小可行接入的**架构设计**（详见 [docs/ai-music-generation-poc-design.md](docs/ai-music-generation-poc-design.md)）：

- **接口设计**：`POST /api/generate-music`（创建 job + 立即返回 fallbackTrack）+ `GET /api/music-status?id=xxx`（轮询状态）+ 可选 `POST /api/music-cancel`
- **状态流设计**：queued → generating → storing → succeeded / failed / fallback，含进度估算与超时策略（总 120s 超时）
- **D1 设计**：`music_generation_jobs` 表（15 字段 + 4 索引，通过 session_id 关联 feedback 表，**不立即迁移**）
- **R2 设计**：bucket `xinxian-music-gen`，路径 `generated-music/{yyyy}/{mm}/{jobId}.mp3`，30 天生命周期
- **Prompt 映射**：5 类 targetState（sleep/soothe/regulate/focus/energize）→ 英文 prompt 模板，纯音乐/无歌词/无医疗化表达
- **前端流程**：方案页新增「生成专属音乐（实验）」入口（默认折叠）→ 生成进度页（呼吸圆+进度条）→ 成功播放生成音频 / 失败 fallback 预置音频
- **Fallback 策略**：所有失败/超时/限流都返回 fallbackTrack，前端零中断
- **成本与安全**：每 IP 每日 20 次、每 session 1 次、prompt 内容过滤、API Key 仅在 Cloudflare env（设计不实现）
- **P4.3 任务拆分**：15 项任务（D1 迁移 / 2 个 Pages Function / Mock 生成器 / Prompt 映射器 / 前端 4 项 / 数据串联 / 限流 / 过滤 / 测试 / 验证 / README 同步）
- **下一步**：P4.3 最小 mock/adapter 实现（不接真实 API），**当前尚未接入真实生成**

#### 6.8.11 P4.3 mock/adapter 最小闭环实现（2026-07-12）

在 P4.2 PoC 设计基础上，实现不调用真实付费 API 的最小可运行闭环（详见 [docs/ai-music-generation-poc-design.md](docs/ai-music-generation-poc-design.md)）：

**已实现**：
- ✅ 后端 mock 接口 `functions/api/generate-music.js`：创建生成任务，返回 `jobId` + `fallbackTrack` + `provider:"mock"`；输入校验 + prompt 关键词过滤 + CORS + 异常保护
- ✅ 后端 mock 接口 `functions/api/music-status.js`：无状态查询，通过 jobId 编码的时间戳计算进度；4 秒后 90% succeeded / 10% failed
- ✅ 前端服务层 `lib/pipeline/music_generation/`：`MusicGenerationService`（createJob + getStatus + pollUntilComplete）+ 数据模型（Request/Response/FallbackTrack/Phase）
- ✅ 前端 UI `lib/screens/music_generation_screen.dart`：呼吸圆动画 + 进度条 + 状态文案（queued/generating/succeeded/failed）+ 实验功能标签 + fallback 自动进入播放器
- ✅ 方案页入口 `lib/screens/plan_screen.dart`：新增「生成专属音乐（实验）」OutlinedButton，不阻塞原有「进入疗愈播放」
- ✅ 单元测试 `test/music_generation_service_test.dart`：models 序列化 + service createJob/getStatus/pollUntilComplete + 网络异常 fallback

**状态文案**（不承诺治疗效果，失败不吓人）：
- queued：「已加入生成队列」
- generating：「正在为这次心境整理音乐方向」
- succeeded：「专属音乐已生成」
- failed：「这次专属生成没有完成，已为你切换到合适的预置音乐」

**Fallback 策略**：所有失败/超时/网络异常都自动进入 PlayerScreen 播放预置音频，用户零中断

**未做事项**：
- ❌ 未接入真实 Stable Audio API（P4.4）
- ❌ 未改 D1 schema（P4.3 不迁移 music_generation_jobs 表）
- ❌ 未改现有预置音频匹配和播放逻辑
- ❌ 未接入 API Key
- ❌ 未产生付费调用

**当前状态**：mock 闭环可运行，生成结果与预置音频相同（仅验证链路），**P4 真正 AI 音乐生成仍是后续必做项**

#### 6.8.12 P4.3 mock/adapter 最小闭环 fix1：交互修复（2026-07-12）

修复 P4.3 mock 生成流程的用户体验问题：点击「生成专属音乐（实验）」后直接进入播放器并卡住。

**根因**：
- `MusicGenerationScreen` 在 `createJob` 失败时（本地开发无 Functions）立即 `pushReplacement` 到 PlayerScreen，用户看不清生成页
- 成功/失败后 800ms/1500ms 自动跳转，用户来不及识别状态
- 轮询超时 150 秒过长，mock 阶段不需要

**已修复**：
- ✅ 移除所有自动跳转逻辑，用户手动点击按钮才进入播放器
- ✅ `createJob` 失败时本地模拟 3-4 秒生成过程（mock 阶段最终都是预置音频），让用户看到完整生成流程
- ✅ 成功后显示「播放这段音乐」+「改用预置音乐」两个按钮
- ✅ 失败后显示「播放预置音乐」按钮 + 温和文案
- ✅ 生成中显示「这是实验功能，当前使用 mock 生成流程」副文案
- ✅ `MusicGenerationService` 超时调整：`maxPollDuration` 150s → 15s，`pollInterval` 3s → 2s
- ✅ AppBar 关闭按钮始终可用，不会卡死

**未做事项**：
- ❌ 未接入真实 Stable Audio API（P4.4）
- ❌ 未改 D1 schema
- ❌ 未改现有预置音频匹配和播放逻辑
- ❌ 未产生付费调用

**当前状态**：mock 生成流程可理解、可操作、不卡死，**P4 真正 AI 音乐生成仍是后续必做项**

#### 6.8.13 P4.3 mock/adapter 最小闭环 fix2：生成页空白与关闭按钮修复（2026-07-12）

修复 P4.3 fix1 遗留问题：生成页主体空白、关闭按钮不可点击。

**根因**：
- `CenteredPageScaffold` 内部使用 `SingleChildScrollView`，给子级的高度约束是无界的
- `MusicGenerationScreen` 的 `Column` 中使用了 `Spacer()`（内部是 `Expanded`），在无界高度约束下抛出 `RenderFlex children have non-zero flex but the height constraints are unbounded` 布局异常
- 布局异常导致整个 Column 渲染失败，页面空白
- body 渲染抛异常后，widget tree 的 hit-test 链受影响，关闭按钮点击无响应

**已修复**：
- ✅ 移除 `Spacer()`，改用 `SizedBox(height: 32)` 固定间距
- ✅ `_phase` 初始值改为 `generating`，首帧立即显示生成中 UI，绝不空白
- ✅ 简化为纯 3 秒 `Future.delayed` 本地模拟，不调用 `createJob`/`pollUntilComplete`，避免任何网络/HTTP/解析异常
- ✅ 关闭按钮改用 `Navigator.of(context).maybePop()`，不检查任何状态，永远可点击
- ✅ 进度条改为 indeterminate（不确定进度），不需要更新 progress 值，更简单稳定
- ✅ 新增 `test/music_generation_screen_test.dart`（3 个 widget test：初始文案、3 秒后成功按钮、关闭按钮 pop）

**未做事项**：
- ❌ 未接入真实 Stable Audio API（P4.4）
- ❌ 未改 D1 schema
- ❌ 未改现有预置音频匹配和播放逻辑
- ❌ 未产生付费调用

**当前状态**：生成页首帧即有内容、关闭按钮永远可点击、3 秒后显示成功按钮，**P4 真正 AI 音乐生成仍是后续必做项**

#### 6.8.14 P4.4-1 Provider Adapter 与密钥/成本控制设计（2026-07-12）

在 P4.3 mock/adapter 闭环已稳定的基础上，为真实 Stable Audio 接入做工程准备。本批只做设计，不实际调用付费 API。

**新增文档**：[`docs/ai-music-provider-adapter-design.md`](docs/ai-music-provider-adapter-design.md)（12 章节）

**设计内容**：
- Provider adapter 架构：`MockProvider`（P4.3 已实现）+ `StableAudioProvider`（P4.4-2 实现），通过环境变量 `MUSIC_GENERATION_PROVIDER=mock|stable_audio` 切换
- Provider 选择逻辑：未设置默认 mock；设为 stable_audio 但 API Key 缺失时自动降级到 mock
- Stable Audio 接入草案：endpoint `POST /v2/audio/stable-audio-3.0`、payload 结构、response 解析、8 类错误码映射、5 层超时策略
- 环境变量设计：`MUSIC_GENERATION_PROVIDER`、`STABLE_AUDIO_API_KEY`、`MUSIC_GENERATION_DAILY_LIMIT`（默认 20）、`MUSIC_GENERATION_MAX_DURATION`（默认 180s）、`R2_BUCKET_NAME` 等
- 成本控制：每会话 1 次、每日 20 次、单次最大 180 秒、每日成本上限 $1.0、免费 credits 监控
- 安全与隐私：不上传 moodText、prompt 禁止医疗化表达、API Key 只在 Cloudflare env、日志脱敏
- D1 migration 草案：`music_generation_jobs` 表（15 字段 + 5 索引，本批不执行）
- R2 准备：bucket `xinxian-music-gen`、路径 `generated-music/{yyyy}/{mm}/{jobId}.mp3`、30 天生命周期
- Fallback 链：stable_audio 失败 → mock → 预置音频

**当前状态**：
- ✅ mock provider 仍是默认，未接入真实 Stable Audio API
- ✅ 未产生付费调用
- ✅ 未改 D1 schema / 未改前端播放主流程
- ✅ P4.4-2 实施清单 15 项任务已拆分（含 8 项需人工确认的前置条件）
- **P4 真正 AI 音乐生成仍是后续必做项**

#### 6.8.15 P4.4-2 Provider Adapter 代码骨架实现（2026-07-12）

基于 [P4.4-1 设计文档](docs/ai-music-provider-adapter-design.md)，实现后端 provider adapter 代码骨架，让 `/api/generate-music` 和 `/api/music-status` 支持 provider 选择。本批仍不调用真实 Stable Audio API。

**新增文件**：
- `functions/api/_music/music-generation-utils.js` — 共享工具（CORS / 校验 / fallback / jobId 生成与解析 / 进度估算）
- `functions/api/_music/providers/mock-provider.js` — MockProvider（从 P4.3 抽出，无状态，4s 后 90% 成功）
- `functions/api/_music/providers/stable-audio-provider.js` — StableAudioProvider 骨架（不发真实请求，返回 `provider_disabled` + fallback）
- `functions/api/_music/provider-factory.js` — Provider 工厂（根据 `MUSIC_GENERATION_PROVIDER` + `STABLE_AUDIO_API_KEY` 选择 provider）
- `scripts/verify-provider-adapter.mjs` — Node.js 验证脚本（10 个测试）

**修改文件**：
- `functions/api/generate-music.js` — 重构为使用 provider factory
- `functions/api/music-status.js` — 重构为使用 provider factory

**Provider 选择逻辑**：

| `MUSIC_GENERATION_PROVIDER` | `STABLE_AUDIO_API_KEY` | 实际 provider |
|---|---|---|
| 未设置 / `mock` | — | MockProvider |
| `stable_audio` | 缺失 | MockProvider（降级） |
| `stable_audio` | 有值 | StableAudioProvider 骨架（返回 `not_implemented` + fallback） |
| 未知值 | — | MockProvider + warning |

**验证结果**：
- ✅ `node scripts/verify-provider-adapter.mjs` — 10/10 passed
- ✅ mock provider 仍是默认
- ✅ 未配置 API Key 自动降级 mock
- ✅ stable_audio 有 Key 也不发真实请求（骨架阶段）
- ✅ API 响应结构完全兼容前端
- ✅ 前端 UI 不变（仍用 P4.3-fix2 的稳定 3 秒本地 mock）

**未做事项**：
- ❌ 未调用真实 Stable Audio API
- ❌ 未产生付费调用
- ❌ 未改 D1 schema
- ❌ 未配置 R2 bucket
- ❌ 未改前端主流程
- **下一步才是 API Key / 平台配置 / 真实请求灰度**

#### 6.8.16 P4.4-3 Replicate MusicGen Provider 骨架（2026-07-13）

在 P4.4-2 provider adapter 骨架基础上，新增 `replicate_musicgen` provider 和真实调用安全开关。

**新增文件**：
- `functions/api/_music/providers/replicate-musicgen-provider.js` — ReplicateMusicGenProvider 骨架

**修改文件**：
- `functions/api/_music/provider-factory.js` — 支持 `replicate_musicgen` provider 选择
- `scripts/verify-provider-adapter.mjs` — 新增 8 个测试（共 18 个）

**Cloudflare Pages 已配置环境变量**：
- `REPLICATE_API_TOKEN`（Secret）— Replicate API Token
- `MUSIC_GENERATION_PROVIDER=replicate_musicgen`
- `MUSIC_GENERATION_REAL_CALLS_ENABLED=false`

**Provider 选择逻辑**：

| `MUSIC_GENERATION_PROVIDER` | `REPLICATE_API_TOKEN` | `MUSIC_GENERATION_REAL_CALLS_ENABLED` | 实际 provider |
|---|---|---|---|
| 未设置 / `mock` | — | — | MockProvider |
| `replicate_musicgen` | 缺失 | — | MockProvider（降级） |
| `replicate_musicgen` | 有值 | `false` / 未设置 | `replicate_musicgen_disabled` |
| `replicate_musicgen` | 有值 | `true` | `replicate_musicgen_not_implemented`（仍不发请求） |

**安全保证**：
- ✅ `MUSIC_GENERATION_REAL_CALLS_ENABLED=false` 时绝对不调用 Replicate API
- ✅ 即使 `MUSIC_GENERATION_REAL_CALLS_ENABLED=true`，本批也不真实 fetch Replicate，只返回 `not_implemented` + fallback
- ✅ 不打印 token 值，只记录 `apiTokenConfigured: true/false`
- ✅ Token 只在 Cloudflare Secret 中，不写入代码 / README
- ✅ mock provider 继续可用
- ✅ 未改 D1 schema / 未配置 R2 / 未上传真实音频

**验证结果**：
- ✅ `node scripts/verify-provider-adapter.mjs` — 18/18 passed
- ✅ 不会产生付费调用
- ✅ 下一步才是极小额度真实调用测试

#### 6.8.17 P4.4-4 MiniMax Music Provider 骨架与 wrangler.toml 迁移（2026-07-13）

在 P4.4-3 基础上，新增 `minimax_music` provider，并将非敏感环境变量迁移到 `wrangler.toml` 管理。主线 provider 从 Replicate 调整为 MiniMax。

**新增文件**：
- `functions/api/_music/providers/minimax-music-provider.js` — MiniMaxMusicProvider 骨架

**修改文件**：
- `wrangler.toml` — 新增非敏感变量 `MUSIC_GENERATION_PROVIDER = "minimax_music"` + `MUSIC_GENERATION_REAL_CALLS_ENABLED = "false"`
- `functions/api/_music/provider-factory.js` — 支持 `minimax_music` provider 选择
- `scripts/verify-provider-adapter.mjs` — 新增 8 个测试（共 26 个）

**环境变量管理分工**：

| 变量 | 管理位置 | 说明 |
|---|---|---|
| `MUSIC_GENERATION_PROVIDER` | `wrangler.toml` [vars] | 非敏感，当前值 `minimax_music` |
| `MUSIC_GENERATION_REAL_CALLS_ENABLED` | `wrangler.toml` [vars] | 非敏感，当前值 `false` |
| `MINIMAX_API_KEY` | Cloudflare Dashboard Secret | 敏感，不写入 wrangler.toml / 代码 / README |
| `REPLICATE_API_TOKEN` | Cloudflare Dashboard Secret | 敏感（P4.4-3 保留） |
| `STABLE_AUDIO_API_KEY` | Cloudflare Dashboard Secret | 敏感（P4.4-2 保留） |

**Provider 选择逻辑**：

| `MUSIC_GENERATION_PROVIDER` | `MINIMAX_API_KEY` | `MUSIC_GENERATION_REAL_CALLS_ENABLED` | 实际 provider |
|---|---|---|---|
| 未设置 / `mock` | — | — | MockProvider |
| `minimax_music` | 缺失 | — | MockProvider（降级） |
| `minimax_music` | 有值 | `false` / 未设置 | `minimax_music_disabled` |
| `minimax_music` | 有值 | `true` | `minimax_music_not_implemented`（仍不发请求） |

**安全保证**：
- ✅ `MUSIC_GENERATION_REAL_CALLS_ENABLED=false` 时绝对不调用 MiniMax API
- ✅ 即使 `=true`，本批也不真实 fetch MiniMax，只返回 `not_implemented` + fallback
- ✅ 不打印 API Key 值，只记录 `apiKeyConfigured: true/false`
- ✅ `MINIMAX_API_KEY` 只在 Cloudflare Secret 中，不写入 wrangler.toml / 代码 / README
- ✅ mock provider 继续可用
- ✅ replicate_musicgen / stable_audio provider 保留不回归
- ✅ 未改 D1 schema / 未配置 R2 / 未上传真实音频

**验证结果**：
- ✅ `node scripts/verify-provider-adapter.mjs` — 26/26 passed
- ✅ 不会产生付费调用
- ✅ 下一步才是极小额度真实调用测试

#### 6.8.18 P4.4-5 MiniMax Music-2.0 极小额度真实调用测试（2026-07-13）

在 P4.4-4 骨架基础上，实现 MiniMax Music-2.0 真实调用分支，但受**双重开关保护**，默认仍关闭，只允许手动 curl 测试。前端仍未开放真实生成。

**修改文件**：
- `wrangler.toml` — 新增非敏感变量 `MINIMAX_MUSIC_MODEL = "music-2.0"` + `MUSIC_GENERATION_MAX_DURATION_SECONDS = "120"`
- `functions/api/_music/providers/minimax-music-provider.js` — 实现 `_callMiniMax` 真实调用分支（受双重保护）
- `functions/api/_music/music-generation-utils.js` — `validateInput` 透传 `manualTest` 字段
- `functions/api/generate-music.js` — `createJob` 调用改为 `await`（兼容 async 真实调用）
- `functions/api/_music/provider-factory.js` — 注释更新（P4.4-5 双重保护说明）
- `scripts/verify-provider-adapter.mjs` — 32 个测试（新增 6 个 MiniMax 真实调用分支测试 + 安全验证）

**MiniMax Music-2.0 真实调用双重保护**：

| 保护层 | 变量 / 标志 | 管理位置 | 默认值 | 作用 |
|---|---|---|---|---|
| 第 1 道 | `MUSIC_GENERATION_REAL_CALLS_ENABLED` | `wrangler.toml` [vars] | `false` | 总开关，false 时直接返回 fallback |
| 第 2 道 | `manualTest`（请求体字段）| 手动 curl 显式传入 | `false` | 即使总开关 true，无 manualTest 仍返回 fallback |
| 凭证 | `MINIMAX_API_KEY` | Cloudflare Dashboard Secret | — | 缺失时 ProviderFactory 降级 MockProvider |

**Provider 行为矩阵**：

| `MUSIC_GENERATION_REAL_CALLS_ENABLED` | `MINIMAX_API_KEY` | `manualTest` | 行为 | provider |
|---|---|---|---|---|
| `false` / 未设置 | — | — | 不发请求，返回 fallback | `minimax_music_disabled` |
| `true` | 缺失 | — | ProviderFactory 降级 MockProvider | `mock` |
| `true` | 有值 | `false` / 未传 | 不发请求，返回 fallback | `minimax_music_manual_test_required` |
| `true` | 有值 | `true` | **真实 POST `/v1/music_generation`**，返回 ok:true + 元数据 | `minimax_music` |

**MiniMax API 调用参数**：
- endpoint：`https://api.minimax.chat/v1/music_generation`
- method：POST
- model：`music-2.0`
- audio_setting：`{ format: "mp3", sample_rate: 44100, bitrate: 256000 }`
- prompt：按 targetState 预置短 prompt（非医疗化表达，纯音乐，no vocals）
- lyrics：不传（控制时长 < 2 分钟；Music-2.0 lyrics 可选）
- 鉴权：`Authorization: Bearer {MINIMAX_API_KEY}`（不打印 key 值）

**返回结果处理（真实调用成功时）**：
- 返回 `ok: true` / `provider: "minimax_music"` / `status: "succeeded"`
- 返回 `audioHexLength`（不返回完整 hex，避免巨大响应）
- 返回 `musicDuration` / `traceId` / `fallbackTrack`
- 不返回 `audioPreviewBase64`（避免巨大响应）
- 日志只记录 `audioHexLength` / `musicDuration` / `traceId`，不记录完整 hex

**时长控制说明**：
- MiniMax Music-2.0 API 本身不强制 `duration` 参数，不伪造不存在的参数
- 通过短 prompt + 不传 lyrics 控制目标时长 < 2 分钟
- `MUSIC_GENERATION_MAX_DURATION_SECONDS = "120"` 仅作内部约束，不发送给 API
- README 写明：Music-2.0 本批以"短生成测试"为目标，时长不是硬性 API 参数

**错误处理（真实调用失败时全部 fallback）**：
- HTTP 错误（非 2xx）→ `http_error_{status}` + `minimax_music_http_error`
- MiniMax 业务错误（`base_resp.status_code !== 0`）→ `minimax_error_{code}` + `minimax_music_api_error`
- 请求超时（55s AbortController）→ `request_timeout` + `minimax_music_timeout`
- 网络异常 → `request_failed` + `minimax_music_request_failed`

**安全保证**：
- ✅ `MUSIC_GENERATION_REAL_CALLS_ENABLED=false` 时绝对不调用 MiniMax API
- ✅ 即使 `=true`，无 `manualTest: true` 仍不发请求
- ✅ 不打印 `MINIMAX_API_KEY` 值，只记录 `apiKeyConfigured: true/false`
- ✅ 不打印完整 audioHex，只记录 `audioHexLength`
- ✅ 不保存生成音频到 D1 / R2 / 文件系统
- ✅ `MINIMAX_API_KEY` 只在 Cloudflare Secret 中，不写入 wrangler.toml / 代码 / README
- ✅ mock / replicate_musicgen / stable_audio provider 不回归
- ✅ 未改 D1 schema / 未配置 R2 / 未改前端播放主流程

**成本说明**：
- MiniMax Music-2.0 官方价格约 0.25 元/首（以控制台实际扣费为准）
- 本批只允许手动 curl 测试一次，不循环调用
- 验证脚本使用 mock fetch 注入，不产生真实网络请求和费用

**前端影响**：
- ❌ 前端仍未开放真实生成入口
- ❌ 前端请求默认不携带 `manualTest` 字段（`validateInput` 默认 `false`）
- ✅ 前端主流程仍使用 P4.3-fix2 稳定的 3 秒本地 mock
- ✅ 即使误触达真实调用分支，无 `manualTest: true` 也不会发请求

**验证结果**：
- ✅ `node scripts/verify-provider-adapter.mjs` — 32/32 passed（含 mock fetch 注入测试，不产生真实调用）
- ✅ 测试脚本不真实调用 MiniMax API（使用 `global.fetch` 注入）
- ✅ 默认配置 `MUSIC_GENERATION_REAL_CALLS_ENABLED=false` 不产生费用
- ✅ 下一步（P4.4-6）才是前端接入与正式开放

**手动 curl 测试命令**（需先在 Cloudflare Dashboard 临时开启 `MUSIC_GENERATION_REAL_CALLS_ENABLED=true`）：

```bash
curl -X POST https://xinxian-music.xyz/api/generate-music \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "manual-test-001",
    "targetState": "sleep",
    "generationPrompt": "ambient sleep music, instrumental, no vocals, slow tempo",
    "durationSeconds": 120,
    "manualTest": true
  }'
```

预期返回（真实调用成功）：
```json
{
  "ok": true,
  "provider": "minimax_music",
  "status": "succeeded",
  "audioHexLength": 1234567,
  "musicDuration": 45.5,
  "traceId": "...",
  "fallbackTrack": { ... }
}
```

测试完成后请立即在 Cloudflare Dashboard 将 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 改回 `false`。

#### 6.8.19 P4.4-6 MiniMax 真实调用测试失败与方向调整（2026-07-18，fix1 修订）

P4.4-5 完成真实调用分支代码后，手动 curl 真实调用 MiniMax Music-2.0 API 仍失败。失败可能涉及鉴权、请求体格式、模型可用性等多方面。

**fix1 修订**：上一版（P4-comfort-song-design-1）曾据此把 Mureka 写成下一主线，现修正为——**当前主线继续使用 MiniMax**（账户已充值，成本更可控，真实调用失败需继续排查）；**Mureka 降级为后续候选 provider**（最低充值 200 元，测试成本偏高，暂不接入）。

**MiniMax 当前状态**：
- ✅ P4.4-4 骨架代码已完成（`minimax-music-provider.js`，受双重保护）
- ✅ P4.4-5 真实调用分支代码已实现（`_callMiniMax`，受 `manualTest` + `REAL_CALLS` 双重保护）
- ❌ 真实调用测试仍失败
- ⚠️ **fix1 修订：继续作为当前主线排查，不放弃**（上一版曾写"暂不作为下一主线继续硬调试"，现修正）
- ✅ **MiniMax 代码保留**，不删除（`MUSIC_GENERATION_PROVIDER=minimax_music` 仍可切换回去）

**不删除 MiniMax 代码的理由**：
- 骨架与真实调用分支代码已稳定，验证脚本 31 项测试通过
- 失败原因可能不在代码层面（可能是账号 / 模型可用性 / 区域限制）
- MiniMax 账户已充值，单首成本约 0.25 元，成本更可控
- 未来若排查修复，可快速重新启用

**MiniMax 真实调用失败排查方向**（下一批任务）：
- 鉴权 header 格式（`Authorization: Bearer {key}`）
- 请求体字段名 / 结构是否符合 Music-2.0 官方文档
- `model` 值是否准确（`music-2.0`）
- 账户是否有 Music-2.0 模型权限
- 区域 / 网络是否可达 `api.minimax.chat`
- Cloudflare Pages Function 是否正确读取 `MINIMAX_API_KEY` Secret

**方向调整**：
- **当前主线继续使用 MiniMax**（fix1 修订）
- **Mureka 降级为后续候选 provider**（最低充值 200 元，暂不接入）
- 新方向不再是"情绪 → 纯音乐"，而是"困惑解惑 → 歌词 → AI 歌曲"（详见 6.9 章节）

---

### 6.9 P4 新方向：困惑解惑 → 歌词 → AI 歌曲生成（2026-07-18）

指导老师指出，当前"识别情绪 → 生成符合情绪的音乐"信息维度太单一，只把用户复杂处境压缩成情绪标签、valence、arousal 等少量维度。新方向是：用户描述最近的困惑/痛苦/愧疚/压力后，系统先像温和的心理陪伴者一样帮他解惑，再把这段解惑内容转成歌词，最后用 AI 音乐生成 API 生成一首能安慰他的歌曲。

**新增文档**：
- [docs/comfort-song-product-flow.md](docs/comfort-song-product-flow.md) — 产品流程设计（新主流程 / 数据模型草案 / 文案规范 / 与旧流程关系）
- [docs/mureka-api-integration-plan.md](docs/mureka-api-integration-plan.md) — Mureka API 接入调研（能力梳理 / 推荐路径 / 环境变量 / fallback / 成本 / 任务拆分）

**新主流程**：

```
用户输入困惑/事件/情绪
  → LLM 生成「温和解惑」（comfortInterpretation）
  → LLM 生成歌词草稿（lyricDraft）
  → 用户确认/微调歌词
  → AI 音乐 API 生成歌曲（当前主线 provider：MiniMax）
  → 播放
  → 反馈
  → （后续阶段）付费转化 / 社交 Agent
```

**与旧流程的关系**：
- 旧流程（情绪识别 → 纯音乐/预置音乐）：**保留**为「快速模式」
- 新流程（困惑解惑 → 歌词歌曲）：作为 P4 之后**主体验**
- 两个流程共用：sessionId / 反馈采集 / 历史记录 / fallback 预置音频
- 两个流程不共用：中间产物（MoodProfile vs comfortInterpretation + lyricDraft）

**当前 API 主线：MiniMax**（fix1 修订）：
- MiniMax 账户已充值，单首成本约 0.25 元，**成本更可控**
- P4.4-4 / P4.4-5 已完成 `minimax_music` provider 骨架 + 真实调用分支代码
- 真实调用测试虽然上一轮失败，但**应继续排查并推进**，不放弃
- MiniMax 真实调用失败需排查方向：鉴权 header / 请求体格式 / `model` 值 / 账户权限 / 网络可达性 / Cloudflare Secret 读取
- 代码已稳定，31 项验证脚本测试通过
- `MINIMAX_API_KEY` 只放 Cloudflare Secret，不写入 wrangler.toml / 代码 / README

**Mureka：后续候选 provider**（fix1 修订，暂不接入）：
- 上一版（P4-comfort-song-design-1）曾把 Mureka 写成下一主线，现修正为**后续候选**
- 原因：Mureka **最低充值 200 元**，当前测试成本偏高
- Mureka 官方 API 支持歌词生成歌曲 / 提示词生成歌曲 / 纯音乐 / 任务查询（API server `https://api.mureka.ai`，鉴权 `Bearer MUREKA_API_KEY`）
- Mureka 的潜在优势：原生支持歌词生成歌曲 / 支持中文歌词 / 返回 audioUrl（无需转码）/ 有任务查询接口
- **当前仍未真实调用 Mureka API**，调研文档保留为后续候选方案
- 后期如果预算允许、且 MiniMax 确实无法修复，再切换或新增 Mureka
- `MUREKA_API_KEY` 不写入 wrangler.toml / 代码 / README

**文案规范**：
- ✅ 可以使用：情绪支持 / 音乐陪伴 / 心理舒缓 / 温和开导 / 自我理解 / 也许 / 可以试着 / 这首歌想陪你看见
- ❌ 禁用医疗化：治疗 / 治愈 / 治疗焦虑 / 治疗失眠 / 治好你的焦虑
- ❌ 禁用玄学：命中注定 / 天意 / 神的安排 / 算准 / 神谕 / 命运注定
- ❌ 禁用空话：一切都会好的 / 加油 / 你是最棒的
- ❌ 禁用说教：你应该 / 你必须 / 你这样下去会

**明确不做的边界**：
- ❌ 本批不做：mureka_music provider 代码 / 真实调用 Mureka / D1 schema 迁移 / 前端 UI
- ❌ **付费模块**（高品质生成 / 多版本选择 / 下载 / 分享）：明确是**后续阶段**，不是当前阶段
- ❌ **社交 Agent**（心境卡片 / 对话 Agent / 小红书抖音分享）：明确是**后续阶段**，不是当前阶段
- ❌ 心理量表 / 生理数据采集：后续科研方向，不进主流程

**下一步计划**（fix1 修订）：
1. **P4 新方向第一批代码**：先做「解惑文本 + 歌词生成」本地/LLM 流程（用 DeepSeek LLM，不依赖真实 AI 音乐生成）
2. **P4 MiniMax 修复**：排查线上为什么仍返回 `provider=mock`（检查 Secret 读取 / 鉴权 / 请求体 / `model` 值 / 账户权限 / 网络可达性）
3. **暂不做 Mureka**：Mureka 最低充值 200 元，暂不接入，保留为后续候选
4. **暂不做付费模块**：明确是后续阶段
5. **暂不做社交 Agent**：明确是后续阶段

> 详细的 Mureka 后续候选方案任务拆分见 [docs/mureka-api-integration-plan.md](docs/mureka-api-integration-plan.md) 第七章（当前不执行）。

---

### 6.10 P4 新方向第一批：困惑解惑 + 歌词生成 LLM 流程（2026-07-18）

承接 6.9 P4 新方向设计，本批落地"用户输入困惑/事件 → LLM 温和解惑 → LLM 生成歌词草稿"的核心体验，**不依赖真实 AI 音乐生成 API**。MiniMax 真实生成继续作为后续排查任务，不阻塞本批。

**核心交付**：

1. **新增后端 API** `functions/api/comfort-lyrics.js`：
   - 输入：`storyText` / `sessionId` / `targetStyle`（`gentle_pop` / `ambient_ballad` / `acoustic_warm` / `soft_piano`）/ `language`（默认 `zh-CN`）
   - 输出：`ok` / `source: "llm" | "fallback"` / `comfortInterpretation` / `lyricDraft` / `songPrompt` / `safetyNotes`
   - 复用 `analyze-mood.js` 的 OpenAI-compatible LLM 配置（`OPENAI_API_KEY` / `OPENAI_BASE_URL` / `OPENAI_MODEL` / `ENABLE_LLM`），原生 fetch + AbortController 15s 超时，temperature 0.7，max_tokens 800
   - 完整 try/catch 兜底，任何异常都返回 fallback，**绝不返回 502，不让前端卡死**
   - 关键内部函数 `validateInput` / `sanitizeText` / `normalizeResult` / `localFallback` 已 `export`，供验证脚本直接测试

2. **LLM Prompt 设计**（避免医疗化 / 玄学化 / 说教 / 空话）：
   - `comfortInterpretation`（150-300 字，2-4 段）：第 1 段用"听起来你…"复述处境；第 2 段用"也许…"重新框架；第 3 段用"可以试着…"指向一个小的可执行行动
   - `lyricDraft`（80-150 字）：含「主歌」「副歌」「尾声」标记；主歌具象化处境，副歌承认情绪 + 微小行动意象，尾声留白不强行升华
   - `songPrompt`（英文 20-40 字）：简短描述曲风 / 情绪 / 速度 / 乐器，**不含用户原文隐私细节**，**不含 heal/cure/treatment/therapy 等医疗化词汇**
   - `safetyNotes`：未检测到风险线索时返回"未检测到风险线索"；检测到敏感词时返回"已过滤敏感表达"

3. **后端 sanitizeText 过滤**：
   - 医疗化词汇（治疗焦虑 / 治疗失眠 / 治好你的焦虑 / 治愈你的 / 疗法 / 疗效）→ 替换为「辅助舒缓」
   - 玄学化词汇（命中注定 / 天意 / 神的安排 / 算准 / 神谕 / 命运注定）→ 替换为「也许」
   - 空话词汇（一切都会好的 / 加油哦 / 你是最棒的 / 会好起来的）→ 替换为「可以试着」
   - 检测到违规词汇时 `safetyNotes` 自动追加"已过滤敏感表达"标注

4. **fallback 策略**：
   - 后端 `localFallback(storyText, targetStyle)`：LLM 失败时返回通用温和解惑 + 歌词草稿（按 targetStyle 选择 songPrompt）
   - 前端 `ComfortLyricsService._localFallback`：网络完全不可达时再兜底一次，与后端 fallback 文案一致
   - 双层 fallback 确保用户在任何情况下都能看到一段温和的解惑 + 歌词草稿

5. **前端最小入口**：
   - 首页「生成专属疗愈方案」按钮下方新增 `OutlinedButton`：「把困惑写成一首歌」（与快速模式并列，作为新主流程入口）
   - 新页面 `lib/screens/comfort_lyrics_screen.dart`：输入困惑 → 选择曲风（4 选 1）→ 点击「生成解惑与歌词草稿」→ 显示来源标记 + 温和解惑卡片 + 歌词草稿卡片 + 曲风提示卡片 + 后续提示「下一步将用于生成专属歌曲。当前版本仅生成歌词草稿，暂不调用真实 AI 音乐生成」+ 「再写一首」重置按钮

6. **新增/修改文件清单**：
   - `functions/api/comfort-lyrics.js`（新增）：后端 LLM API + fallback + sanitizeText
   - `lib/models/comfort_lyrics_result.dart`（新增）：前端数据模型
   - `lib/pipeline/llm/comfort_lyrics_service.dart`（新增）：前端 Service（调用 /api/comfort-lyrics，失败返回本地 fallback）
   - `lib/screens/comfort_lyrics_screen.dart`（新增）：前端页面
   - `lib/screens/home_screen.dart`（修改）：新增「把困惑写成一首歌」入口 + `_goComfortLyrics` 方法
   - `lib/config/app_version.dart`（修改）：`buildLabel` → `P4-comfort-lyrics-1`
   - `scripts/verify-comfort-lyrics.mjs`（新增）：后端核心逻辑验证脚本（25 项测试）
   - `test/comfort_lyrics_result_test.dart`（新增）：数据模型测试
   - `test/comfort_lyrics_service_test.dart`（新增）：Service fallback 测试
   - `test/comfort_lyrics_screen_test.dart`（新增）：页面不空白 / 按钮状态 / 切换曲风 / 重置测试

7. **明确不做**：
   - ❌ 本批**不调用 MiniMax API**（`MUSIC_GENERATION_REAL_CALLS_ENABLED` 保持 `false`）
   - ❌ 本批**不调用 Mureka API**（Mureka 仍是后续候选，暂不接入）
   - ❌ 本批**不生成真实音频**（前端主流程仍使用 P4.3-fix2 稳定的本地预置音频）
   - ❌ 本批**不改 D1 schema**
   - ❌ 本批**不改付费模块**（明确是后续阶段）
   - ❌ 本批**不做社交 Agent**（明确是后续阶段）
   - ❌ 本批**不写入任何 API Key**（`OPENAI_API_KEY` / `MINIMAX_API_KEY` / `MUREKA_API_KEY` 均只放 Cloudflare Secret）

8. **后续任务（不阻塞本批）**：
   - **MiniMax 真实调用排查**：仍是后续任务，需检查 Secret 读取 / 鉴权 header / 请求体格式 / `model` 值 / 账户权限 / 网络可达性
   - **Mureka**：仍是后续候选 provider，最低充值 200 元，暂不接入
   - **真实歌曲生成**：等 MiniMax 修复或 Mureka 接入后再接入新流程的"AI 音乐生成"环节

9. **验证**：
   - `node scripts/verify-comfort-lyrics.mjs`：25 项测试全部通过（validateInput / sanitizeText / normalizeResult / localFallback / 文案规范）
   - `flutter analyze` / `flutter test` / `flutter build web --release`：见 [第九章 本地开发与验证](#九本地开发与验证)

---

## 七、数据与隐私

### 7.1 心境文本处理

- 用户心境文本**仅在本次请求中用于 LLM 调用**，不在服务端存储、不记录到日志
- `moodText` **不上传到云端 D1**，D1 中无此字段
- `MoodProfile.sourceText` 仅在当次 pipeline 运行中使用，不写入 ListeningSession JSON，避免历史记录泄露用户原文
- LLM 解析需要用户明确同意（首次弹窗 / 解析设置入口）
- 用户未同意时，自动使用本地关键词解析（Mock），不调用 LLM
- LLM 调用失败时，自动 fallback 到本地解析，用户无感知
- 前端不包含任何 API Key / Base URL / 模型名，所有敏感信息仅保存在 Cloudflare 环境变量中

### 7.2 本地存储

- 聆听记录与反馈数据**默认仅保存在用户本地设备**（Web 端为浏览器 localStorage / 移动端为应用本地存储）
- 本地最多保留最近 100 条 ListeningSession 与 FeedbackRecord，超出按时间最旧的自动裁剪
- 用户可在「历史记录」页随时删除单条记录或清空全部记录
- 清除浏览器数据 / 卸载应用后，本地记录将丢失
- 浏览器隐私 / 无痕模式下本地持久化可能不可用，应用会回退到内存态运行（重启后丢失），不影响 Demo 体验

### 7.3 云端匿名反馈采集（M7）

M7.0 新增可选的云端匿名反馈采集能力，**默认关闭**，需用户主动同意后才会启用：

- **不上传心境原文**：用户输入的 `moodText` 心境文本不会上传到云端，仅上传结构化参数（情绪标签 / valence / arousal / intensity / targetState / 体验评分 / 状态评分等）
- **文字反馈独立同意**：`freeTextFeedback`（用户手写的文字反馈）默认不上传，需用户在反馈页单独勾选「同时上传本次文字反馈」才上传，且勾选状态独立于云端采集总开关持久化
- **两层同意机制**：`CloudFeedbackConsentService`（云端采集总开关）+ `CloudTextConsentService`（文字反馈独立开关，默认 declined），两者均可在首页「云端采集」入口随时切换
- **fire-and-forget**：云端上传失败不影响本地反馈保存和用户体验，不重试、不报错
- **本地删除不联动云端**：在历史记录页删除单条 / 清空全部仅操作本地仓储，不会删除云端匿名记录
- **匿名 sessionId**：云端数据通过 `listeningSessionId`（UUID）关联，不包含用户身份信息
- **可随时关闭**：用户可随时在首页「云端采集」入口切换为关闭，关闭后不再上传新反馈（已上传的匿名数据保留用于科研分析）

### 7.4 D1 存储内容

`feedback` 表 25 字段（[schema/feedback.sql](file:///d:/xinxian_healing_music/schema/feedback.sql)），主键 `listeningSessionId`，4 个索引（targetState / experimentVariant / createdAt / analyzerMode）。存储内容包括：

- 会话标识：`sessionId` / `listeningSessionId` / `createdAt`
- 实验分组：`experimentVariant`（custom / generic / control）
- 解析来源：`analyzerMode`（mock / llm / fallback）
- 情绪参数：`targetState` / `emotionTags` / `valence` / `arousal` / `intensity`
- 方案信息：`musicTitle` / `audioAssetId`（脱敏文件名）/ `audioAssetTitle` / `bpm` / `brainwaveTarget` / `noiseLayer`
- 反馈评分：`relaxationScore`（1-5）/ `calmnessScore`（0-100，值越大 = 状态越好）
- 文字反馈：`freeTextFeedback`（仅在用户单独勾选时上传）
- 元数据：`clientVersion` / `userAgent` / `source` / `schemaVersion`

**不存储**：`moodText`（心境原文）、用户身份信息、`tensionBefore` / `tensionAfter` 原始值（仅存派生的 `calmnessScore`）。

### 7.5 Web 端 localStorage 按 origin 隔离

Flutter Web 的 `shared_preferences` 底层使用浏览器 `localStorage`，**按 origin 隔离**：

- `https://xinxian-music.xyz` 与 `https://www.xinxian-music.xyz` 是不同 origin，历史记录不共享
- `https://xinxian-healing-music.pages.dev` 与每次部署生成的 `https://xxxx.xinxian-healing-music.pages.dev` 是不同 origin，历史记录不共享
- AI 解析的同意状态（accepted/declined）也按 origin 隔离

因此验证体验时请**始终使用正式域名**：[https://xinxian-music.xyz](https://xinxian-music.xyz)

### 7.6 反馈数据分析与导出（M8）

采用**轻量方案**（Wrangler SQL + Cloudflare D1 Console），不新增后台 API、不新增管理页面：

- `scripts/feedback-queries.sql` 包含 8 条常用查询：总反馈数 / targetState 分布 / audioAssetId 平均评分 / 最近 20 条反馈 / 每日反馈数量 / freeTextFeedback 非空数量 / 实验分组统计 / 文字反馈原文查看（隐私敏感）
- 支持 CSV 导出（wrangler `--json` + jq / D1 Console 复制 / Python 脚本）
- 隐私策略：`moodText` 不存在于 D1；文字反馈原文仅供项目组内部分析，不得用于公开报告 / PPT；报告中只使用聚合统计或脱敏摘要

**为什么暂不做公开管理后台**：当前数据量小（< 1000 条）；避免暴露 admin API 增加攻击面；D1 数据库仅管理员通过 wrangler / Dashboard 访问；D1 Console 表格截图 + CSV 导出足以支撑验收和答辩。

---

## 八、环境变量与部署

### 8.1 环境变量

在 Cloudflare Pages Dashboard → 项目 → Settings → Environment variables 中配置：

| 变量名 | 说明 | 示例 |
|---|---|---|
| `OPENAI_API_KEY` | LLM API Key（必填，**不提交到代码仓库**） | `sk-...` |
| `OPENAI_BASE_URL` | OpenAI-compatible API 地址 | `https://api.deepseek.com` |
| `OPENAI_MODEL` | 模型名 | `deepseek-chat` |
| `ENABLE_LLM` | 是否启用 LLM（设为 `false` 时强制 fallback 到本地解析） | `true` |

> **安全说明**：`OPENAI_API_KEY` 仅保存在 Cloudflare 环境变量中，不写入 `wrangler.toml`、不提交到 Git 仓库、不打印到日志、不返回给前端。本地开发时使用 `.dev.vars` 文件（已加入 `.gitignore`）。

### 8.2 Cloudflare D1 binding

D1 binding 名 `xinxian_feedback`，通过 `wrangler.toml` 配置，绑定到数据库 `xinxian-feedback`。

### 8.3 部署命令

```bash
# 1. 构建 Flutter Web 产物（会自动复制 web/_redirects / web/_headers 到 build/web/）
flutter build web --release

# 2. 部署到 production 分支（绑定到正式域名 xinxian-music.xyz）
npx wrangler pages deploy build/web \
  --project-name=xinxian-healing-music \
  --branch=main \
  --commit-dirty=true
```

### 8.4 正式域名

- **正式体验地址**：[https://xinxian-music.xyz](https://xinxian-music.xyz)
- **Cloudflare Pages 测试站稳定域名**：[https://xinxian-healing-music.pages.dev](https://xinxian-healing-music.pages.dev)
- 每次 `wrangler pages deploy` 还会生成临时部署域名（形如 `https://<commit-hash>.xinxian-healing-music.pages.dev`），**仅用于预览某次部署**，不要用于日常体验（localStorage 按 origin 隔离，历史记录不共享）

### 8.5 启用消融实验分组（可选）

```bash
# 默认构建（不启用实验，线上默认）
flutter build web --release

# 启用消融实验分组记录
flutter build web --release --dart-define=ENABLE_EXPERIMENT=true
```

- **默认 false**：`HashExperimentAssigner` 恒返回 `custom`，用户体验与 M8 完全一致
- **`ENABLE_EXPERIMENT=true`**：新会话按 sessionId hash 稳定分流到三组，`experimentVariant` 字段写入 D1
- **编译期常量**：零依赖、零新 API、零运行时配置；切换需重新部署

---

## 九、本地开发与验证

### 9.1 环境要求

已安装 Flutter SDK（建议 3.12+），Web 端运行需配置 Chrome 浏览器。

### 9.2 安装依赖

```bash
flutter pub get
```

### 9.3 静态检查与单元测试

```bash
flutter analyze
flutter test
```

### 9.4 以 Web 端运行 Demo（推荐）

```bash
flutter run -d chrome
```

### 9.5 构建 Web 产物

```bash
flutter build web --release
```

### 9.6 本地预览（读取 `.dev.vars` 中的环境变量）

```bash
npx wrangler pages dev build/web
```

### 9.7 API 健康检查

```bash
# 健康检查（GET，无 body）
curl https://xinxian-music.xyz/api/health
# 预期返回
# { "ok": true, "service": "xinxian-functions", "version": "v1", "timestamp": "2026-..." }

# 验证 /api/analyze-mood
curl -X POST https://xinxian-music.xyz/api/analyze-mood \
  -H "Content-Type: application/json" \
  -d '{"text":"最近备考压力很大，晚上睡不着"}'
# 预期返回 { "ok": true, "source": "llm", "mood": {...} } 或 fallback 响应
```

### 9.8 D1 查询命令

```bash
# 总反馈数
npx wrangler d1 execute xinxian-feedback --remote --command "SELECT COUNT(*) FROM feedback"

# targetState 分布
npx wrangler d1 execute xinxian-feedback --remote --command "SELECT targetState, COUNT(*) AS count FROM feedback GROUP BY targetState ORDER BY count DESC"

# 最近 20 条反馈（不含文字原文）
npx wrangler d1 execute xinxian-feedback --remote --command "SELECT listeningSessionId, substr(createdAt,1,19) AS created_at, targetState, relaxationScore, calmnessScore FROM feedback ORDER BY createdAt DESC LIMIT 20"

# 整文件执行（本地预览全部查询）
npx wrangler d1 execute xinxian-feedback --remote --file=./scripts/feedback-queries.sql
```

### 9.9 启动自检日志

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

### 9.10 Android 构建兼容性说明

Android 构建当前存在**上游插件与 Gradle 9 的兼容性问题**，暂不作为初赛阻塞项：

- 项目使用 Flutter 3.44.4 stable，其模板生成的 Android 工具链为 Gradle 9.1.0 + Android Gradle Plugin 9.0.1 + Kotlin 2.3.20
- 依赖 `just_audio`（及其传递依赖 `audio_session`）的 Android 构建脚本自带旧版 AGP 8.5.2，该版本内部引用了 `org.gradle.util.VersionNumber`，而该类在 Gradle 9.0 中已被移除，导致 Android 构建时报 `NoClassDefFoundError: org/gradle/util/VersionNumber`
- `just_audio` / `audio_session` 已是当前最新版本，暂无可升级的修复版本，属于上游插件尚未适配新版 Gradle 的不兼容
- 该问题**仅影响 Android 构建，完全不影响 Web Demo 的构建与体验**

Web 与 Android 的构建链路相互独立：Android 的 Gradle 配置不参与 `flutter build web`，Web 产物中已正确包含全部音频资源。

---

## 十、当前仍是 Mock / Demo / 待产品化的部分

当前版本是初赛可体验 Demo，以下模块暂时使用本地模拟或简化实现（均已按可替换方式组织，Port 抽象 + 工厂装配，后续可逐步替换为真实服务，UI 代码无需改动）：

- **真正 AI 音乐生成尚未接入（P4 必做）**：当前使用本地预置音频素材（`sleep_01.mp3` / `regulate_01.mp3` / `soothe_01.mp3` / `focus_01.mp3` / `energize_01.mp3` 共 5 类），由 `AudioAssetCatalog` 按 targetState 自动匹配，不同情绪对应不同音频；但仍为预置素材，**非实时 AI 生成音频**（M5 的 `generationPrompt` 仅生成文本提示词，为后续真实生成模型预留数据通道）
- **DSP 后处理尚未接入**：`AudioPostProcessorPort` 当前为 Passthrough 直通，未实现白噪音 / 粉红噪音 / EQ / 淡入淡出等真实 DSP
- **完整 ListeningSession 仍仅保存在本地**：匿名结构化反馈数据（体验评分 / 状态评分 / 情绪参数等）可上传至 Cloudflare D1，但完整 ListeningSession（含心境原文）未上传至云端
- **历史记录目前是浏览器本地存储**：基于 shared_preferences（Web 端为 localStorage），按 origin 隔离，清除浏览器数据后丢失
- **用户系统尚未接入**：无账号 / 跨设备同步
- **反馈数据可视化尚未完成**：当前采用 Wrangler SQL + D1 Console 轻量方案，无公开管理后台 / Dashboard
- **移动端 App 尚未发布**：Android 构建存在上游插件兼容性问题，暂不作为初赛阻塞项

> **已真实接入（非 Mock）**：LLM 情绪解析（M4 DeepSeek API）、LLM 画像驱动音乐参数映射（M5 `EmotionToMusicPlanMapper`）、多音频匹配（M6 `AudioAssetCatalog`）、targetState 意图识别精修（M6.1 `TargetStateResolver`）、匿名云端反馈采集（M7.0 D1 + Pages Functions）。

---

## 十一、后续路线图

| 阶段 | 计划内容 | 状态 |
|---|---|---|
| **P3-Web-v1.0**（已完成） | 数据与反馈运营：第一批已完成反馈数据查询脚本 + 基础统计（查询 9-12 + PowerShell 脚本）；第二批测试数据标记与查询隔离（`-ExcludeTest` / `-OnlyTest`）；第三批真实反馈采集准备（`-MinVersion` / `-PreCheck` + 分析门槛 <30/30-100/>100）；后续可基于 D1 已采集数据深化反馈分析；M8.2 消融对比实验音频旁路落地；反馈数据可视化轻量方案 | ✅ 已完成（三批交付） |
| **P4-AI-Music-v1.0**（必做） | 真正 AI 音乐生成接入（**产品核心升级，非可选项**）：将 `AudioGenerationPort` 从本地预置音频替换为真实 AI 音乐生成模型，按 `generationPrompt` 实时生成个性化音频；DSP 后处理（白噪音 / 粉红噪音 / EQ / 淡入淡出）接入；异步生成任务；音频存储；fallback 到预置音频；成本与安全控制。**第一批已完成技术调研，第 1.5 批已完成供应商可用性复核，第二批已完成 PoC 设计，第三批已完成 mock/adapter 最小闭环实现**（详见 [docs/ai-music-generation-research.md](docs/ai-music-generation-research.md) 与 [docs/ai-music-generation-poc-design.md](docs/ai-music-generation-poc-design.md)）：已实现 mock 生成接口（`/api/generate-music` + `/api/music-status`）+ 前端实验入口 + fallback 到预置音频；**当前仍未接入真实 Stable Audio API，不会产生付费调用；下一步 P4.4 接入真实 API（需人工注册账号）** | 🔜 进行中（mock 闭环完成，真实接入待 P4.4） |
| **P5-Mobile-v1.0** | 移动端 App 准备：解决 Android 构建上游插件与 Gradle 9 兼容性问题；Android/iOS 原生打包与发布流程 | ⏳ 计划中 |
| **P6** | 用户系统与跨设备：可选登录 / 跨端历史同步 | ⏳ 计划中 |
| **P7** | 正式发布与运营：反馈数据可视化公开管理后台；正式发布与运营 | ⏳ 计划中 |

---

## 十二、免责声明

本项目为高校竞赛 Demo 原型，定位为**情绪调节与正念放松辅助工具**：

- **不提供医疗诊断或治疗**
- **不替代专业心理咨询或医疗建议**
- 定位为辅助情绪调节、睡前舒缓、正念放松、音乐陪伴
- 报告与答辩材料统一使用「用户主观反馈差异 / 体验偏好 / 放松度评分」措辞，不写「治疗焦虑 / 改善失眠」等医疗效果声明
- 如有严重情绪困扰或睡眠障碍，请及时寻求专业医师帮助

---

## 十三、变更记录

### 13.1 M 阶段（架构与核心能力）

| 日期 | 版本 | 阶段 | 摘要 |
|---|---|---|---|
| 2026-早期 | v0.1.x | M1 | Pipeline 架构整理：抽象核心模型与 Port，HealingMusicPlan 重构为聚合根 |
| 2026-早期 | v0.2.x | M2 | ListeningSession 与实验分组结构：sessionId 贯穿全链路 |
| 2026-早期 | v0.3.x | M3 | 本地持久化历史记录：shared_preferences + JSON，最多 100 条 |
| 2026-早期 | v0.4.x | M4 | LLM 情绪解析网关 + Cloudflare Pages Functions + 正式域名部署；正式域名 9 步全流程验收通过 |
| 2026-早期 | v0.5.x | M5 | LLM 情绪画像驱动音乐方案映射：`EmotionToMusicPlanMapper`，5 类 targetState |
| 2026-早期 | v0.6.x | M6 | 多音频资源与情绪匹配播放：`AudioAssetCatalog` 4 级匹配算法 |
| 2026-早期 | v0.6.1 | M6.1 | targetState 意图识别精修：`TargetStateResolver` 8 级优先级规则，31 条端到端测试 |
| 2026-早期 | v0.7.0 | M7.0 | 匿名云端反馈采集：Cloudflare D1 + Pages Functions + 两层同意机制 |
| 2026-早期 | v0.8.0 | M8 | 反馈数据分析与导出：`scripts/feedback-queries.sql` + Wrangler SQL 轻量方案 |
| 2026-早期 | v0.8.1 | M8.1 | 消融对比实验分组记录（保守 MVP）：`HashExperimentAssigner` + `ENABLE_EXPERIMENT` 编译期常量 |

### 13.2 P1-Web-v1.0（Web 产品化修复）

| 日期 | 阶段 | 摘要 |
|---|---|---|
| 2026-早期 | P1 第三批 | history restore 完整链路（保留原始 startedAt）；analysis_screen 响应式（180-260 clamp）；index.html 元信息；历史空状态 CTA |
| 2026-早期 | P1 第四批 | `/api/health` 健康检查端点；D1 写入 5000ms 超时保护；CORS 白名单（正式域名 + Pages 预览 + localhost） |
| 2026-早期 | P1 小质量修复 | targetState 枚举统一：prompt 强化 + `normalizeMood` 旧值归一（`relax` / `company` → `soothe`） |
| 2026-早期 | P1 限流规则 | Cloudflare Dashboard 配置 `/api/analyze-mood` 限流（Block，10 次/分钟，Active）；`/api/submit-feedback` 未配置（Free 计划上限 1/1） |
| 2026-早期 | P1 PWA / 缓存 | `web/_headers` 缓存头策略；三路径（音频 / API / SW）线上验证通过 |
| 2026-早期 | P1 收尾验收 | 文档与代码 / 线上配置一致性核对；核心线上流程手动验收清单；P1 全部可关闭 |

### 13.3 P2-Web-v1.0（Web 体验优化）

| 日期 | 版本 | 阶段 | 摘要 |
|---|---|---|---|
| 2026-07-10 | v0.9.0 / P2-ui-1 | P2 第一批 | 首次 AI 同意弹窗延后到点击「生成方案」时触发；播放页 / 解析页去技术化文案 |
| 2026-07-10 | v0.9.0 / P2-ui-2 | P2 第二批 | 方案页技术参数默认折叠；「为什么推荐这段音乐」卡片；播放页去技术参数 chip |
| 2026-07-10 | v0.9.0 / P2-ui-2-fix1 | P2 第二批 fix1 | `recommendation_reason.dart` 共享 helper，优先按用户输入场景生成文案 |
| 2026-07-10 | v0.9.0 / P2-ui-3 | P2 第三批 | 播放完成反馈 CTA；反馈页默认低成本填写；未同意云端采集不强制弹窗 |
| 2026-07-11 | v0.9.0 / P2-ui-3-fix1 | P2 第三批 fix1 | slider 语义统一为状态评分（左差右好）；字段名保持兼容 |
| 2026-07-11 | v0.9.0 / P2-ui-3-fix2 | P2 第三批 fix2 | `calmnessScore = tensionAfter × 100`；improvement 用 after-before |
| 2026-07-11 | v0.9.0 / P2-ui-3-fix3 | P2 第三批 fix3 | slider 文案中性化（状态较差/偏低/平稳/较好/很好） |
| 2026-07-11 | v0.9.0 / P2-ui-4 | P2 第四批 | 首页底部精简为「查看历史记录 + 设置」+ 版本号；设置弹窗收纳四项 |
| 2026-07-11 | v0.9.0 / P2-ui-4-fix1 | P2 第四批 fix1 | 修复设置弹窗只显示遮罩不显示内容（`DialogButtonBar` 单 child 无限宽断言）；子入口点击用 `Future.microtask` |
| 2026-07-11 | v0.9.0 / P2-stable | P2 收尾验收 | P2 全部 9 子项核对通过；核心用户路径 14 项手动验收清单完整；数据语义 6 项核对通过；版本号同步到 `P2-stable` |

### 13.4 P3-Web-v1.0（数据与反馈运营）

| 日期 | 版本 | 阶段 | 摘要 |
|---|---|---|---|
| 2026-07-11 | v1.0.0 / P3-data-1 | P3 第一批 | 反馈数据查询脚本 + 基础统计：`scripts/feedback-queries.sql` 新增查询 9-12（总体平均评分 / targetState 聚合 / 低评分列表 / 高评分列表）；新增 `scripts/query-feedback.ps1` PowerShell 辅助脚本（8 个参数）；确认 improvement 指标限制（D1 未存 tensionBefore）；不改 D1 schema / API / 前端 UI |
| 2026-07-11 | v1.0.0 / P3-data-1-fix1 | P3 第一批 fix1 | 修复 `query-feedback.ps1` PowerShell 5.1 ParserError：所有 SQL 改用 here-string `@" ... "@`；新增 `$compactSql` 压缩空白；文件转存为 UTF-8 with BOM 解决中文乱码；只改脚本 / 版本号 / README |
| 2026-07-11 | v1.0.0 / P3-data-2 | P3 第二批 | 测试数据标记与查询隔离：`query-feedback.ps1` 新增 `-ExcludeTest` / `-OnlyTest` 参数；`feedback-queries.sql` 新增查询 13-16；保守识别规则（clientVersion v0.x / sessionId 含 test / 文字反馈含测试词）；不改 D1 schema / 不删除远程数据 |
| 2026-07-11 | v1.0.0 / P3-data-3 | P3 第三批 | 真实反馈采集准备：`query-feedback.ps1` 新增 `-MinVersion` / `-PreCheck` 参数；`feedback-queries.sql` 新增查询 17-20（真实反馈数量+门槛 / clientVersion 分布 / 日期分布 / targetState 分布）；建立分析门槛（<30 只看链路 / 30-100 方向性观察 / >100 分组优化）；当前真实反馈=0 |

### 13.5 P4-AI-Music-v1.0（AI 音乐生成接入）

| 日期 | 版本 | 阶段 | 摘要 |
|---|---|---|---|
| 2026-07-12 | v1.0.0 / P4-research-1 | P4 第一批 | AI 音乐生成服务选型调研：新增 `docs/ai-music-generation-research.md`（覆盖 Suno/Udio/Stable Audio/MusicGen/ElevenLabs/MiniMax/Lyria 7 类方案）；推荐 Top 2（Stable Audio 3.0 主选 + MusicGen 备选）；输出接入架构草图（Flutter Web → Pages Function → Stable Audio API → R2 → Player）；不接入代码 / 不调用付费 API / 不改播放逻辑 / 不改 D1 schema / 不改 Functions；保留预置音频作 fallback；只运行 `flutter analyze`（未改业务逻辑） |
| 2026-07-12 | v1.0.0 / P4-research-1-fix1 | P4 第 1.5 批 | 供应商可用性与版权/API 复核：确认 Stable Audio 3.0 Large API 已于 2026-05-20 官方发布（platform.stability.ai）；修正模型家族描述（Large 2.7B 仅 API/企业授权，Small/Medium 开源权重）；澄清 Community License 允许商用（年营收 <$1M 免费）vs Stable Audio Open 旧版非商用；确认 MusicGen CC-BY-NC 4.0 仍非商业仅作 fallback；维持 Suno/Udio/ElevenLabs/MiniMax/Lyria 不推荐判断；列出 10 项待人工确认事项；下一步 P4.2 最小 PoC |
| 2026-07-12 | v1.0.0 / P4-design-1 | P4 第二批 | 最小 PoC 接入设计：新增 `docs/ai-music-generation-poc-design.md`（13 章节）；设计 `/api/generate-music` + `/api/music-status` 接口；设计 6 状态流（queued/generating/storing/succeeded/failed/fallback）+ 进度估算 + 超时策略；设计 D1 `music_generation_jobs` 表（15 字段 + 4 索引，不立即迁移）；设计 R2 路径 `generated-music/{yyyy}/{mm}/{jobId}.mp3` + 30 天生命周期；5 类 targetState 英文 prompt 模板（纯音乐/无歌词/无医疗化表达）；前端最小 UI 流程 + 轮询逻辑；fallback 策略（所有失败零中断）；P4.3 任务拆分 15 项；不接真实 API / 不写代码 / 不改 D1 / 不改 Functions；只运行 `flutter analyze` |
| 2026-07-12 | v1.0.0 / P4-mock-1 | P4 第三批 | mock/adapter 最小闭环实现：新增 `functions/api/generate-music.js`（mock 创建任务 + 输入校验 + prompt 过滤 + CORS）+ `functions/api/music-status.js`（无状态查询 + 时间戳进度 + 90% 成功 / 10% 失败）；新增 `lib/pipeline/music_generation/`（models + service，封装 createJob/getStatus/pollUntilComplete + 网络异常 fallback）；新增 `lib/screens/music_generation_screen.dart`（呼吸圆 + 进度条 + 状态文案 + 实验标签 + 自动进入播放器）；修改 `lib/screens/plan_screen.dart`（新增「生成专属音乐（实验）」按钮）；新增 `test/music_generation_service_test.dart`（10 条测试）；不改 D1 schema / 不改预置音频逻辑 / 不接真实 API / 不产生付费调用 |
| 2026-07-12 | v1.0.0 / P4-mock-1-fix1 | P4 第三批 fix1 | mock 生成流程交互修复：移除 `MusicGenerationScreen` 所有自动跳转逻辑，改为用户手动点击按钮进入播放器；`createJob` 失败时本地模拟 3-4 秒生成过程（mock 阶段最终都是预置音频）；成功后显示「播放这段音乐」+「改用预置音乐」按钮；失败后显示「播放预置音乐」按钮；`MusicGenerationService` 超时调整 `maxPollDuration` 150s → 15s、`pollInterval` 3s → 2s；未接入真实 Stable Audio API / 未改 D1 schema / 未改预置音频逻辑 / 未产生付费调用 |
| 2026-07-12 | v1.0.0 / P4-mock-1-fix2 | P4 第三批 fix2 | 生成页空白与关闭按钮修复：根因是 `Column` 中 `Spacer()` 在 `SingleChildScrollView` 无界高度约束下抛布局异常导致页面空白；移除 `Spacer()` 改用 `SizedBox` 固定间距；`_phase` 初始值改为 `generating` 确保首帧有内容；简化为纯 3 秒 `Future.delayed` 本地模拟，不再调用 `createJob`/`pollUntilComplete`；关闭按钮改用 `maybePop` 永远可点击；进度条改为 indeterminate；新增 `test/music_generation_screen_test.dart`（3 个 widget test）；未接入真实 Stable Audio API / 未改 D1 schema / 未改预置音频逻辑 / 未产生付费调用 |
| 2026-07-12 | v1.0.0 / P4-provider-design-1 | P4 第四批第一步 | Provider adapter 与密钥/成本控制设计：新增 `docs/ai-music-provider-adapter-design.md`（12 章节）；设计 MockProvider + StableAudioProvider 双 provider 架构 + 环境变量切换逻辑；Stable Audio 接入草案（endpoint / payload / response / 8 类错误码映射 / 5 层超时策略）；8 个环境变量设计（`MUSIC_GENERATION_PROVIDER` / `STABLE_AUDIO_API_KEY` / `MUSIC_GENERATION_DAILY_LIMIT` 等）；成本控制矩阵（每会话 1 次 / 每日 20 次 / 单次 180s / 每日 $1 上限）；安全与隐私设计（不上传 moodText / API Key 只在 Cloudflare env / 日志脱敏）；D1 migration 草案（15 字段 + 5 索引，不执行）；R2 准备方案；P4.4-2 实施清单 15 项任务 + 8 项人工确认前置条件；未接入真实 Stable Audio API / 未产生付费调用 / 未改 D1 schema / 未改前端播放主流程 |
| 2026-07-12 | v1.0.0 / P4-provider-skeleton-1 | P4 第四批第二步 | Provider adapter 代码骨架实现：新增 `functions/api/_music/music-generation-utils.js`（共享工具）+ `providers/mock-provider.js`（从 P4.3 抽出）+ `providers/stable-audio-provider.js`（骨架，不发真实请求）+ `provider-factory.js`（环境变量选择）；重构 `generate-music.js` + `music-status.js` 使用 provider factory；新增 `scripts/verify-provider-adapter.mjs`（10 个 Node.js 测试）；Provider 选择：默认 mock / stable_audio 无 Key 降级 mock / stable_audio 有 Key 返回 `not_implemented` + fallback；API 响应结构完全兼容前端；前端 UI 不变（仍用 P4.3-fix2 稳定 3 秒本地 mock）；未调用真实 Stable Audio API / 未产生付费调用 / 未改 D1 schema / 未改前端主流程 |
| 2026-07-13 | v1.0.0 / P4-replicate-skeleton-1 | P4 第四批第三步 | Replicate MusicGen Provider 骨架与真实调用安全开关：新增 `functions/api/_music/providers/replicate-musicgen-provider.js`（骨架，不发真实请求）；修改 `provider-factory.js` 支持 `replicate_musicgen` provider 选择 + `MUSIC_GENERATION_REAL_CALLS_ENABLED` 安全开关；更新 `scripts/verify-provider-adapter.mjs`（18 个测试）；Provider 行为：无 Token 降级 mock / 有 Token + REAL_CALLS=false 返回 `replicate_musicgen_disabled` / 有 Token + REAL_CALLS=true 返回 `replicate_musicgen_not_implemented`（仍不发请求）；Cloudflare 已配置 `REPLICATE_API_TOKEN`（Secret）/ `MUSIC_GENERATION_PROVIDER=replicate_musicgen` / `MUSIC_GENERATION_REAL_CALLS_ENABLED=false`；不打印 token / 不写入代码 / 未改 D1 schema / 未配置 R2 / 未产生付费调用 |
| 2026-07-13 | v1.0.0 / P4-minimax-skeleton-1 | P4 第四批第四步 | MiniMax Music Provider 骨架与 wrangler.toml 迁移：新增 `functions/api/_music/providers/minimax-music-provider.js`（骨架，不发真实请求）；修改 `provider-factory.js` 支持 `minimax_music` provider 选择；修改 `wrangler.toml` 新增非敏感变量 `MUSIC_GENERATION_PROVIDER="minimax_music"` + `MUSIC_GENERATION_REAL_CALLS_ENABLED="false"`；更新 `scripts/verify-provider-adapter.mjs`（26 个测试）；主线 provider 从 Replicate 调整为 MiniMax；Provider 行为：无 Key 降级 mock / 有 Key + REAL_CALLS=false 返回 `minimax_music_disabled` / 有 Key + REAL_CALLS=true 返回 `minimax_music_not_implemented`（仍不发请求）；`MINIMAX_API_KEY` 只在 Cloudflare Secret 中 / 不写入 wrangler.toml / 不打印 / 未改 D1 schema / 未配置 R2 / 未产生付费调用 |
| 2026-07-13 | v1.0.0 / P4-minimax-realtest-1 | P4 第四批第五步 | MiniMax Music-2.0 极小额度真实调用测试：实现 `minimax-music-provider.js` `_callMiniMax` 真实调用分支（POST `/v1/music_generation`，model `music-2.0`，mp3/44100/256000）；双重保护：`MUSIC_GENERATION_REAL_CALLS_ENABLED=true` + 请求体 `manualTest=true` 才真实调用，否则返回 fallback；修改 `wrangler.toml` 新增 `MINIMAX_MUSIC_MODEL="music-2.0"` + `MUSIC_GENERATION_MAX_DURATION_SECONDS="120"`；修改 `music-generation-utils.js` `validateInput` 透传 `manualTest` 字段；修改 `generate-music.js` `createJob` 改为 `await`；更新 `scripts/verify-provider-adapter.mjs`（31 个测试，含 mock fetch 注入测试不产生真实调用）；返回 `audioHexLength` / `musicDuration` / `traceId`，不返回完整 hex；不打印 API Key / 不保存到 D1/R2/文件系统；默认 `MUSIC_GENERATION_REAL_CALLS_ENABLED=false` 不产生费用；前端仍未开放真实生成；只允许手动 curl 测试一次 |
| 2026-07-18 | v1.0.0 / P4-comfort-song-design-1 | P4 新方向设计 | 困惑解惑 → 歌词 → AI 歌曲生成主流程设计与 Mureka 路线切换：新增 `docs/comfort-song-product-flow.md`（产品流程设计：新主流程 / 数据模型草案 / 文案规范 / 与旧流程关系 / 三层同意机制）；新增 `docs/mureka-api-integration-plan.md`（Mureka API 调研：能力梳理 / 推荐路径 / 环境变量 / fallback / 成本 / 任务拆分）；README 新增 6.8.19（MiniMax 真实调用失败记录，保留为备选 provider 不删除）+ 6.9（P4 新方向章节）；MiniMax 真实调用测试仍失败，暂不继续硬调试，代码保留为备选；Mureka 为下一主线候选（API server `https://api.mureka.ai`，鉴权 `Bearer MUREKA_API_KEY`，支持歌词生成歌曲）；本批只做文档与版本号，不写代码 / 不真实调用 Mureka / 不改 D1 / 不接入付费模块 / 不做社交 Agent；文案规范禁用医疗化与玄学表达；旧流程保留为「快速模式」，新流程作为 P4 之后主体验 |
| 2026-07-18 | v1.0.0 / P4-comfort-song-design-1-fix1 | P4 新方向设计 fix1 修订 | 修正上一版把 Mureka 写成下一主线的表述：**当前主线继续使用 MiniMax**（账户已充值，单首约 0.25 元，成本更可控，真实调用失败需继续排查）；**Mureka 降级为后续候选 provider**（最低充值 200 元，测试成本偏高，暂不接入）；修改 `docs/comfort-song-product-flow.md` 第五章（与 AI 音乐 provider 的关系：MiniMax 主线 / Mureka 后续候选）；修改 `docs/mureka-api-integration-plan.md` 顶部标注为「后续候选方案，当前不接入」+ 1.3 约束 + 第七章任务拆分（mureka_music 相关任务标注为后续候选不执行）；README 6.8.19 修正方向调整表述（MiniMax 继续作为当前主线排查，不放弃）+ 6.9 修正 Mureka 表述（后续候选，暂不接入）+ 新增下一步计划（解惑+歌词本地/LLM 流程 / MiniMax 修复 / 暂不做 Mureka / 暂不做付费 / 暂不做社交 Agent）；不删除 Mureka 调研文档 / 不删除 MiniMax provider 代码 / 不真实调用任何 API / 不改 D1 / 不改前端 UI / 不写入任何 API Key |
| 2026-07-18 | v1.0.0 / P4-comfort-lyrics-1 | P4 新方向第一批 | 困惑解惑 + 歌词生成 LLM 流程代码实现：新增后端 API `functions/api/comfort-lyrics.js`（OpenAI-compatible LLM 调用 + 15s 超时 + 完整 try/catch 兜底 + sanitizeText 过滤医疗化/玄学化/空话词汇 + localFallback）；新增前端数据模型 `lib/models/comfort_lyrics_result.dart` + Service `lib/pipeline/llm/comfort_lyrics_service.dart`（双层 fallback：后端 fallback + 前端 fallback）+ 页面 `lib/screens/comfort_lyrics_screen.dart`（输入困惑 → 选择 4 种曲风 → 显示温和解惑 + 歌词草稿 + 曲风提示 + 后续提示）；修改 `lib/screens/home_screen.dart` 在主按钮下方新增「把困惑写成一首歌」OutlinedButton 入口；新增 `scripts/verify-comfort-lyrics.mjs`（25 项后端核心逻辑测试：validateInput / sanitizeText / normalizeResult / localFallback / 文案规范）；新增 3 个 flutter test 文件（数据模型 / Service fallback / 页面不空白）；LLM Prompt 严格避免医疗化/玄学化/说教/空话，要求输出含「主歌」「副歌」「尾声」结构的歌词草稿；本批**不调用 MiniMax** / **不调用 Mureka** / **不生成真实音频** / **不改 D1 schema** / **不改付费模块** / **不做社交 Agent** / **不写入任何 API Key**；MiniMax 真实调用排查仍是后续任务 |

### 13.6 项目结构

```
lib/
├── main.dart                      # 应用入口、主题配置、bootstrapServices 装配
├── config/                        # 配置
│   └── app_version.dart           # 应用版本信息单一来源
├── data/                          # 静态数据目录
│   └── audio_asset_catalog.dart   # 本地音频资源目录 + 按 targetState 4 级匹配算法
├── models/                        # 数据模型
│   ├── cloud_feedback_payload.dart # 云端上传 payload 模型 + fromFeedback 工厂
│   └── comfort_lyrics_result.dart # P4 新方向第一批：困惑解惑+歌词生成结果模型
├── pipeline/                      # Translation Pipeline（M1-M7 核心架构）
│   ├── healing_pipeline.dart      # Pipeline 编排器
│   ├── services.dart              # 全局服务实例
│   ├── ports/                     # Port 抽象接口
│   ├── intent/                    # M6.1 自然语言意图识别精修
│   │   └── target_state_resolver.dart
│   ├── mapper/                    # M5 情绪画像 → 音乐方案映射层
│   │   └── emotion_to_music_plan_mapper.dart
│   ├── mock/                      # Mock 实现
│   ├── experiment/                # M8.1 消融实验分组
│   │   └── hash_experiment_assigner.dart
│   ├── consent/                   # M7 同意服务
│   ├── cloud/                     # M7 云端上传实现
│   ├── local/                     # 本地持久化实现
│   └── llm/                       # LLM 接入（M4 + P4 新方向第一批）
│       └── comfort_lyrics_service.dart # P4 新方向第一批：调用 /api/comfort-lyrics + 双层 fallback
├── screens/                       # 核心页面
│   ├── home_screen.dart           # 心境输入页（P4 新方向第一批：新增「把困惑写成一首歌」入口）
│   ├── analysis_screen.dart       # 情绪解析动画页
│   ├── plan_screen.dart           # 疗愈方案展示页
│   ├── player_screen.dart         # 音频播放页
│   ├── feedback_screen.dart       # 用户反馈页
│   ├── history_screen.dart        # 历史记录页
│   ├── privacy_screen.dart        # 隐私政策页
│   └── comfort_lyrics_screen.dart # P4 新方向第一批：困惑解惑+歌词生成页面
├── theme/                         # 配色与主题
├── utils/                         # 工具函数
│   ├── audio_asset_uri.dart       # Web / 非 Web 平台 AudioSource 路径解析
│   ├── user_agent_helper.dart     # Web 端获取 navigator.userAgent
│   └── recommendation_reason.dart # P2 推荐理由场景化 helper
└── widgets/                       # 通用组件

functions/
└── api/
    ├── analyze-mood.js            # Cloudflare Pages Function（LLM 网关）
    ├── comfort-lyrics.js          # P4 新方向第一批：困惑解惑+歌词生成 LLM 网关（含 sanitizeText + fallback）
    ├── submit-feedback.js         # D1 upsert + 字段白名单 + 长度限制
    └── health.js                  # 健康检查端点

schema/
└── feedback.sql                   # D1 建表 DDL（feedback 表 25 字段 + 4 索引）

scripts/
└── feedback-queries.sql           # 常用 D1 查询脚本（12 条查询 + 附录 B 消融实验查询，P3 扩展至 12 条）
    query-feedback.ps1             # PowerShell 辅助查询脚本（P3 新增，8 个参数封装 wrangler 命令）
    verify-provider-adapter.mjs    # P4 第四批：provider adapter 验证脚本（31 个测试）
    verify-comfort-lyrics.mjs      # P4 新方向第一批：comfort-lyrics API 验证脚本（25 个测试）

docs/
└── ai-music-generation-research.md  # P4 第一批 AI 音乐生成服务选型调研文档（P4 新增）
    ai-music-generation-poc-design.md # P4 第二批 AI 音乐生成最小 PoC 接入设计文档（P4 新增）
    ai-music-provider-adapter-design.md # P4 第四批第一步 provider adapter 设计文档（P4 新增）
    comfort-song-product-flow.md     # P4 新方向：困惑解惑→歌词→AI 歌曲生成 产品流程设计（P4 新方向新增）
    mureka-api-integration-plan.md   # P4 新方向：Mureka API 接入调研与计划（P4 新方向新增）

web/
├── index.html                     # Flutter Web 入口模板
├── _headers                       # PWA 缓存头策略
├── _redirects                     # SPA 路由 fallback
└── manifest.json

music/
├── sleep_01.mp3                   # 睡前舒缓类音频（targetState = sleep）
├── regulate_01.mp3                # 情绪调节类音频（targetState = regulate）
├── soothe_01.mp3                  # 正念陪伴类音频（targetState = soothe）
├── focus_01.mp3                   # 专注恢复类音频（targetState = focus）
├── energize_01.mp3                # 温和充能类音频（targetState = energize）
└── music_01.mp3                   # 早期预置音频（M6 前的 fallback，已不再匹配使用）

wrangler.toml                      # Cloudflare Pages 配置（D1 binding xinxian_feedback）
```
