# 心弦 XinXian

> AI 心境解析 + 个性化音乐陪伴 Web 应用

心弦是一款基于 Flutter Web 的情绪陪伴 Demo。用户输入当下心境后，系统通过 LLM 生成情绪画像与音乐参数，并播放匹配的本地音频素材，形成「自然语言 → AI 情绪解析 → 音乐方案 → 音频体验 → 用户反馈」的完整闭环。

- **正式体验地址**：[https://xinxian-music.xyz](https://xinxian-music.xyz)
- **当前版本**：`v1.0.0 · P4-playback-experience-2 · Cloudflare Pages`
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
6.11. [P4 新方向第二批：解惑文本与歌词质量优化](#六点十一p4-新方向第二批解惑文本与歌词质量优化)
6.12. [P4 新方向第三批：歌词确认与编辑 + 后续生成按钮占位](#六点十二p4-新方向第三批歌词确认与编辑--后续生成按钮占位)
6.13. [P4 新方向第四批：MiniMax 歌曲生成灰度接入](#六点十三p4-新方向第四批minimax-歌曲生成灰度接入)
6.14. [P4 前端结构调整第一批：首页双主线重构](#六点十四p4-前端结构调整第一批首页双主线重构)
6.15. [P4 MiniMax 真实生成链路受控测试](#六点十五p4-minimax-真实生成链路受控测试)
6.16. [P4 生成音频落地播放链路](#六点十六p4-生成音频落地播放链路)
6.17. [P4 临时音频播放闭环](#六点十七p4-临时音频播放闭环)
6.18. [P6-quota-guard-1：本地额度保护 + 文档整理](#六点十八p6-quota-guard-1本地额度保护--文档整理)
6.19. [P4-conversation-song-flow-1：多轮困惑理解 + 歌词增强 + 纯音乐本地舒缓 + 定时关闭](#六点十九p4-conversation-song-flow-1多轮困惑理解--歌词增强--纯音乐本地舒缓--定时关闭)
6.20. [P4-conversation-song-flow-1-fix1：LLM 动态追问 + 歌词贴合度增强 + 加载文案分阶段](#六点二十p4-conversation-song-flow-1-fix1llm-动态追问--歌词贴合度增强--加载文案分阶段)
6.21. [P4-conversation-song-flow-1-fix2：low_energy 场景 + lowEnergy 追问问题对齐 + 歌词低能量指引 + 快速舒缓纯本地化复核](#六点二十一p4-conversation-song-flow-1-fix2low_energy-场景--lowenergy-追问问题对齐--歌词低能量指引--快速舒缓纯本地化复核)
6.22. [P4-playback-experience-2：AI 歌曲独立播放页 + 本地舒缓播放模式增强](#六点二十二p4-playback-experience-2ai-歌曲独立播放页--本地舒缓播放模式增强)
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

- **阶段**：`P4-AI-Music-v1.0 / P4-playback-experience-2（AI 歌曲生成成功后跳转独立播放页 + 本地舒缓播放模式增强 + 定时关闭持续播放保证；P4 歌曲生成链路已打通并上线，默认 REAL_CALLS=false）`
- **版本号**：`v1.0.0 · P4-playback-experience-2 · Cloudflare Pages`（首页底部显示 `心弦 v1.0.0 · P4-playback-experience-2 · Cloudflare Pages`）
- **构建日期**：2026-07-24
- **部署目标**：Cloudflare Pages
- **上一阶段**：P4-conversation-song-flow-1-fix2 已上线（low_energy 场景 + lowEnergy 追问问题对齐 + 歌词低能量指引 + 快速舒缓纯本地化复核，2026-07-24 部署）；P4-conversation-song-flow-1-fix1 已完成（LLM 动态追问 + 歌词贴合度增强 + 快速舒缓纯本地化核查 + 加载文案分阶段，2026-07-23）；P4-conversation-song-flow-1 已上线（多轮困惑理解 + 纯音乐本地舒缓 + 定时关闭，2026-07-23）；P6-quota-guard-1 已完成（本地额度保护与文档整理，2026-07-23）；P4-song-result-experience-1 已上线（2026-07-23）；P3-Web-v1.0 已完成（`P3-data-3`）；P2-Web-v1.0 已完成（`P2-stable`）

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
- P4 新方向「把困惑写成一首歌」：困惑解惑 → 歌词生成（LLM）→ AI 歌曲生成（MiniMax）→ 页内试听完整链路
- MiniMax Music-2.0 真实调用链路已打通（受三重门保护，`MUSIC_GENERATION_REAL_CALLS_ENABLED` 默认 `false`，仅手动 curl 测试时临时开启）
- audioDataUrl 临时播放闭环：MiniMax 返回 audioHex → base64 dataUrl → just_audio 页内播放（不依赖 R2，已线上真实试听验证）
- 生成歌曲结果页体验：歌曲标题（本地规则生成）+ 播放控件 + 歌词展示 + 重新播放 / 编辑歌词 / 重新生成操作
- P6 本地额度保护：浏览器本地每日生成次数限制（默认每天 1 次成功生成），失败 / 取消 / 重新播放不计数，跨天自动重置

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

### 6.11 P4 新方向第二批：解惑文本与歌词质量优化（2026-07-18）

承接 6.10 P4 新方向第一批，本批优化"把困惑写成一首歌"的输出质量，让它更像一个**温和、可信、能安慰用户的歌词疗愈产品**，而不是普通情绪分析或建议清单。本批**不调用 MiniMax / Mureka，不生成真实音频，只优化 LLM prompt、fallback 文案、前端展示与测试**。

#### 6.11.1 解惑文本质量优化

`comfortInterpretation` 从第一批的"2-4 段自由结构"升级为**严格 4 段结构**，更像温和陪伴者而非分析报告：

1. **第 1 段：复述处境**——用「听起来你正在……」开头，让用户感到「被听见」，不分析、不总结
2. **第 2 段：重新框架化痛苦**——用「也许这件事最重的地方不是……而是……」开头，不否定痛苦，也不夸大
3. **第 3 段：给一个很小的行动**——用「可以先把目标放小一点……」开头，不强制、不空话，今天就能做
4. **第 4 段（结尾一句）：自然过渡到歌**——用「这首歌不急着推你往前，只先陪你站稳一点」收尾，不说教、不承诺结果

**禁用表达**（在第一批医疗化/玄学化/空话基础上新增说教类）：
- 你必须 / 你应该 / 这说明你 / 你需要治疗 / 一定会好 / 命运安排 / 宇宙告诉你 / 上天告诉你 / 神明告诉你

**推荐表达**：
- 听起来你正在…… / 也许这件事最重的地方不是……而是…… / 可以先把目标放小一点…… / 这首歌不急着推你往前，只先陪你站稳一点 / 想哭也没关系

#### 6.11.2 歌词质量优化

`lyricDraft` 从第一批的"含结构标记"升级为**画面感 + 重复 hook + 严格三段结构**：

- **【主歌】**：具体画面感，用夜色 / 桌面 / 消息 / 路灯 / 风 / 没说出口的话等具象意象，不抽象
- **【副歌】**：核心安慰 hook，可重复 1-2 句便于被唱。例：「今晚先别赶路，让风替你轻轻说完」
- **【尾声】**：留白，不强行升华，不强行打气，可以是一句很轻的独白

**禁用**：建议清单式（每句都是「你要 / 你可以」）/ 鸡汤（「一切都会好的 / 加油」）/ 过度抽象（「黑暗之后是光明」）/ 元指涉（「心弦 / 本产品 / AI」）

**风格参考**（学习语气，不照抄）：
- 我把没说完的话，放进慢慢亮起的窗
- 不是所有跌倒，都要马上给出答案
- 今晚先别赶路，让风替你轻轻说完

#### 6.11.3 songPrompt 优化

`songPrompt` 从第一批的"简短曲风描述"升级为**明确包含 5 要素的英文风格提示**，更适合歌曲生成（含人声）：

- **vocal style**：warm vocal melody / breathy vocal / soft intimate vocal / soft male or female vocal
- **mood**：intimate and comforting / bittersweet and tender / late night comforting / reflective and forgiving / late night intimate
- **tempo**：slow tempo
- **instrumentation**：soft piano and acoustic guitar / fingerstyle guitar and soft pads / gentle piano with subtle synth pads / acoustic guitar and warm piano / fingerstyle guitar and warm pads
- **arrangement**：clean arrangement / minimal arrangement / spacious arrangement / sparse arrangement

参考示例：`gentle mandarin ballad, warm vocal melody, soft piano and acoustic guitar, slow tempo, intimate and comforting mood, clean arrangement`

约束：英文 / 不含用户隐私原句 / 不含 heal/cure/treatment/therapy 等医疗化词汇

#### 6.11.4 场景识别（新增）

后端 `detectScene(storyText)` 本地关键词匹配 5 类场景，用于 fallback 路径选择对应模板（LLM 路径下 scene 由 LLM 自己判断）：

| 场景 | scene 值 | 关键词示例 | 叙事侧重 |
|---|---|---|---|
| 学业失败 / 挂科 | `academic_failure` | 考试 / 挂科 / 考研 / 高考 / 落榜 / 答辩 | 目标暂时没达到 ≠ 你这个人不行 |
| 关系冲突 / 争吵 | `relationship_conflict` | 吵架 / 分手 / 妈妈 / 朋友 / 已读不回 / 室友 | 没说出口的话比争吵更重 |
| 工作压力 / 疲惫 | `work_pressure` | 工作 / 加班 / deadline / 老板 / kpi / 996 | 累不是因为你不够强 |
| 愧疚 / 后悔 | `guilt_regret` | 对不起 / 后悔 / 愧疚 / 辜负 / 都是我的错 | 做错了不等于你是错的 |
| 默认（孤独/迷茫/睡前焦虑） | `default` | （以上都不匹配） | 现在不需要找到答案 |

前端 `ComfortLyricsService._detectScene` 与后端 `detectScene` 关键词完全一致，确保双层 fallback 场景识别结果相同。

#### 6.11.5 fallback 文案优化（5 场景独立模板）

第一批 fallback 只有一套通用模板；本批为 5 场景分别准备独立模板，每个含独立的 `comfortInterpretation`（严格 4 段）+ `lyricDraft`（含主歌/副歌/尾声 + 重复 hook + 场景意象）+ `songPrompt`（英文 5 要素）：

- **学业场景**：意象用模拟卷 / 走廊 / 复习计划；hook「不是所有跌倒，都要马上给出答案」
- **关系场景**：意象用消息框 / 已读 / 关上的门；hook「我把没说完的话，放进慢慢亮起的窗」
- **工作场景**：意象用屏幕光 / 末班车 / 没关的灯；hook「累不是因为你不够强，是你撑得太长」
- **愧疚场景**：意象用没寄出的道歉 / 想拨的电话；hook「做错了不等于你是错的，只是这一次没做好」
- **默认场景**：意象用夜色 / 没亮的窗 / 还没醒的城市；hook「想哭也没关系，我在听」

后端 `FALLBACK_TEMPLATES` 与前端 `_fallbackTemplates` 内容完全一致。

#### 6.11.6 前端展示优化

`ComfortLyricsScreen` 结果区从"开发调试工具感"优化为"产品化温柔感"：

| 优化项 | 第一批 | 第二批 |
|---|---|---|
| 解惑卡片标题 | 温和解惑 | **给现在的你** |
| 歌词卡片标题 | 歌词草稿 | **写成歌的话** |
| songPrompt 展示 | 独立卡片，直接显示 | **折叠弱化**：默认收起，标题改为「后续生成参数」，点击展开 |
| 场景标记 | 无 | **新增**：显示场景标签（学业受挫 / 关系摩擦 / 压力疲惫 / 愧疚后悔 / 此刻心境），让用户感到"被听懂" |
| 来源标记 | 单独显示 | 与场景标记组合显示（本地模板 / AI 生成 + 场景标签） |

songPrompt 折叠使用 `AnimatedCrossFade` 实现 200ms 平滑展开/收起动画，默认收起，避免技术参数干扰产品体验。后续提示「下一步将用于生成专属歌曲。当前版本仅生成歌词草稿，暂不调用真实 AI 音乐生成」保留不变。

#### 6.11.7 后端 sanitizeText 扩展

在第一批医疗化/玄学化/空话过滤基础上新增**说教类过滤**（`LECTURING_PATTERNS`）：

- 你必须 / 你应该 / 你需要治疗 / 这说明你 → 替换为「可以试着」

检测到任何违规词汇时 `safetyNotes` 自动追加"已过滤敏感表达"标注。

#### 6.11.8 新增/修改文件清单

- `functions/api/comfort-lyrics.js`（修改）：SYSTEM_PROMPT 结构化（4 段解惑 + 歌词质量要求 + songPrompt 5 要素 + 场景识别指引）；新增 `detectScene`；`sanitizeText` 新增 `LECTURING_PATTERNS`；`FALLBACK_TEMPLATES` 扩展为 5 场景；`callLlm` temperature 0.7→0.75，max_tokens 800→1000；所有响应新增 `scene` 字段
- `lib/models/comfort_lyrics_result.dart`（修改）：新增 `scene` 字段（默认 `default`），`fromJson` 解析 scene
- `lib/pipeline/llm/comfort_lyrics_service.dart`（修改）：新增 `_detectScene` + `_fallbackTemplates`（5 场景，与后端一致）；`_localFallback` 按 scene 选择模板并设置 `scene` 字段
- `lib/screens/comfort_lyrics_screen.dart`（修改）：标题改名（温和解惑→给现在的你 / 歌词草稿→写成歌的话）；songPrompt 折叠弱化（`_buildSongPromptCard` + `AnimatedCrossFade` + `_songPromptExpanded` 状态）；新增 `_sceneLabels` + `_buildBadges`（来源 + 场景组合标记）
- `lib/config/app_version.dart`（修改）：`buildLabel` → `P4-comfort-lyrics-2`
- `scripts/verify-comfort-lyrics.mjs`（修改）：25 项 → 35 项，新增 `detectScene` 5 场景测试 + 说教类 sanitizeText 测试 + 5 场景 fallback 结构/英文/禁用词/隐私/差异化测试
- `test/comfort_lyrics_result_test.dart`（修改）：新增 scene 字段解析测试（3 项）
- `test/comfort_lyrics_service_test.dart`（修改）：`targetStyle 切换` 组改为`场景识别`组（7 项）；文案规范组扩展说教类禁用词 + 5 场景遍历检测
- `test/comfort_lyrics_screen_test.dart`（修改）：标题测试更新（温和解惑→给现在的你 / 歌词草稿→写成歌的话）；新增 songPrompt 折叠/展开测试 + 场景标记测试 + 结果区完整结构测试
- `README.md`（修改）：新增 6.11 章节 + 13.5 变更记录 + 顶部版本号 + 2.1 当前阶段

#### 6.11.9 明确不做

- ❌ 本批**不调用 MiniMax API**（`MUSIC_GENERATION_REAL_CALLS_ENABLED` 保持 `false`）
- ❌ 本批**不调用 Mureka API**（Mureka 仍是后续候选，暂不接入）
- ❌ 本批**不生成真实音频**（前端主流程仍使用本地预置音频）
- ❌ 本批**不改 D1 schema**
- ❌ 本批**不改付费模块**（明确是后续阶段）
- ❌ 本批**不做社交 Agent**（明确是后续阶段）
- ❌ 本批**不写入任何 API Key**（`OPENAI_API_KEY` / `MINIMAX_API_KEY` / `MUREKA_API_KEY` 均只放 Cloudflare Secret）
- ❌ 本批**不使用医疗化表达**（治疗焦虑 / 治疗失眠 / 治愈 / 疗法 / 疗效 全部禁用）
- ❌ 本批**不包装成玄学 / 算命 / 宗教神谕**（命中注定 / 天意 / 神谕 / 命运安排 / 宇宙 / 上天 / 神明 全部禁用）

#### 6.11.10 验证

- `node scripts/verify-comfort-lyrics.mjs`：35 项测试全部通过（validateInput 9 项 + sanitizeText 9 项 + detectScene 5 项 + normalizeResult 7 项 + localFallback 5 项）
- `flutter analyze`：No issues found
- `flutter test`：全部通过（含 comfort_lyrics_result_test 20 项 + comfort_lyrics_service_test 19 项 + comfort_lyrics_screen_test 13 项）
- `flutter build web --release`：见 [第九章 本地开发与验证](#九本地开发与验证)

---

### 6.12 P4 新方向第三批：歌词确认与编辑 + 后续生成按钮占位（2026-07-18）

承接 6.11 P4 新方向第二批，本批让"把困惑写成一首歌"流程从"生成结果展示"升级为**"用户可以确认/微调歌词，并准备进入 AI 歌曲生成"**。本批**不调用 MiniMax / Mureka，不生成真实音频，只做歌词确认、编辑、状态保存和后续生成入口占位**。

#### 6.12.1 歌词确认与编辑

在结果页 `写成歌的话` 区域增加完整的编辑闭环：

- **编辑入口**：歌词卡片右上角新增「编辑歌词」TextButton（仅展示态显示）
- **编辑态**：点击后歌词变为可编辑多行 TextField（minLines 6 / maxLines 14），原 SelectableText 隐藏
- **字数提示**：编辑框下方实时显示当前字数（`ValueListenableBuilder<TextEditingValue>` 监听，不强制限制长度）
- **温和质量提醒**：编辑框下方显示「建议保留主歌、副歌、尾声结构，后续更适合生成歌曲。」（淡紫色提示框，非技术说明，不暴露 API 细节）
- **保存歌词**：FilledButton，点击后把编辑内容写入 `_editedLyric`，退出编辑态，展示态显示新歌词
- **取消编辑**：OutlinedButton，点击后退出编辑态，不修改 `_editedLyric`，恢复编辑前展示内容
- **自动聚焦**：进入编辑态后自动聚焦到编辑框（`addPostFrameCallback` + `requestFocus`），光标定位到末尾

#### 6.12.2 「生成这首歌」占位按钮

在结果区底部（后续提示之后、再写一首之前）新增主按钮：

- **文案**：「生成这首歌（即将开放）」
- **样式**：FilledButton.icon，淡紫色背景（`AppColors.lavender`），区别于生成解惑按钮
- **当前行为**：点击后弹出浮动 SnackBar 提示「歌曲生成正在准备中，当前版本先支持歌词确认。」（2 秒后自动消失）
- **编辑态禁用**：编辑歌词时该按钮 disabled，避免与歌词编辑冲突

明确不做：
- ❌ 不调用任何音乐 API（MiniMax / Mureka）
- ❌ 不进入播放器
- ❌ 不产生费用

#### 6.12.3 状态管理

页面状态清晰，避免边界情况导致数据错乱：

| 状态规则 | 实现 |
|---|---|
| 生成结果后才能编辑歌词 | 「编辑歌词」按钮仅在 `_result != null` 的结果区显示 |
| 编辑时不能重复点击生成解惑 | 生成按钮 `onPressed` 条件加 `!_isEditing`，编辑态时为 null |
| 编辑时「生成这首歌」按钮禁用 | 占位按钮 `onPressed: _isEditing ? null : _showGenerateSongHint` |
| 保存后 `lyricDraft` 使用编辑后内容 | 展示歌词 `final displayLyric = _editedLyric ?? result.lyricDraft` |
| `songPrompt` 保持原结果不变 | 编辑只改 `_editedLyric`，`result.songPrompt` 不受影响 |
| 点击「再写一首」清空编辑状态 | `_reset()` 中 `_isEditing = false; _editedLyric = null; _editingController.clear()` |
| 重新生成时清空上一次编辑状态 | `_generate()` 进入时 `_isEditing = false; _editedLyric = null` |
| 再次进入编辑态，编辑框初始内容为上次保存内容 | `_startEdit(currentLyric)` 传入 `displayLyric`（含已保存编辑） |

#### 6.12.4 新增/修改文件清单

- `lib/screens/comfort_lyrics_screen.dart`（修改）：新增编辑状态字段（`_isEditing` / `_editingController` / `_editingFocus` / `_editedLyric`）；`dispose` 释放编辑控制器；`_generate` / `_reset` 清空编辑状态；生成按钮编辑态禁用；`_buildResult` 歌词卡片改用 `_buildLyricCard` + 新增 `_buildGenerateSongButton`；新增 `_buildLyricCard`（展示/编辑双模式）+ `_startEdit` / `_saveEdit` / `_cancelEdit` + `_buildGenerateSongButton` / `_showGenerateSongHint`
- `lib/config/app_version.dart`（修改）：`buildLabel` → `P4-lyrics-edit-1`，新增 `P{N}-lyrics-edit-{n}` 约定说明
- `test/comfort_lyrics_screen_test.dart`（修改）：新增 10 项 P4 第三批测试（编辑按钮可见 / 编辑态结构 / 保存显示新歌词 / 取消恢复旧歌词 / 占位按钮弹 SnackBar 不触发 API / 编辑态生成按钮禁用 / 编辑态占位按钮禁用 / 再写一首清空编辑状态 / 二次编辑初始内容 / 结果区完整结构）；修复第一批「点击生成按钮后显示加载状态」测试（`findsOneWidget` → `findsWidgets`，因新增占位按钮）
- `README.md`（修改）：新增 6.12 章节 + 13.5 变更记录 + 顶部版本号 + 2.1 当前阶段

后端 `functions/api/comfort-lyrics.js`、前端 `comfort_lyrics_service.dart`、`comfort_lyrics_result.dart` 本批**未修改**（编辑功能纯前端，不涉及 LLM 重生成）。`scripts/verify-comfort-lyrics.mjs` 本批**未修改**（后端逻辑不变，35 项测试仍全部通过）。

#### 6.12.5 明确不做

- ❌ 本批**不调用 MiniMax API**（`MUSIC_GENERATION_REAL_CALLS_ENABLED` 保持 `false`）
- ❌ 本批**不调用 Mureka API**（Mureka 仍是后续候选，暂不接入）
- ❌ 本批**不生成真实音频**（前端主流程仍使用本地预置音频，「生成这首歌」按钮仅弹提示）
- ❌ 本批**不改 D1 schema**
- ❌ 本批**不改付费模块**（明确是后续阶段）
- ❌ 本批**不做社交 Agent**（明确是后续阶段）
- ❌ 本批**不写入任何 API Key**
- ❌ 本批**不使用医疗化表达**
- ❌ 本批**不包装成玄学 / 算命 / 宗教神谕**

#### 6.12.6 验证

- `node scripts/verify-comfort-lyrics.mjs`：35 项测试全部通过（后端未改，回归通过）
- `flutter analyze`：No issues found
- `flutter test`：全部通过（含 comfort_lyrics_screen_test 23 项，新增 10 项 P4 第三批测试）
- `flutter build web --release`：见 [第九章 本地开发与验证](#九本地开发与验证)

---

### 6.13 P4 新方向第四批：MiniMax 歌曲生成灰度接入（2026-07-19）

承接 6.12 P4 新方向第三批，本批把「生成这首歌」按钮从占位提示**升级为 MiniMax 歌曲生成灰度入口**。但必须保持强安全控制，避免误扣费。本批**实现真实调用入口，但默认不自动开放给所有用户**。

#### 6.13.1 当前策略

- **主线 provider**：MiniMax（账户已充值，单首约 0.25 元，成本可控）
- **Mureka**：暂不接入，作为后续候选（最低充值 200 元，测试成本偏高）
- **4090 服务器**：暂不部署，只在 README 记录为后续自托管 worker 方向（不替换当前 Cloudflare 后端）
- **产品链路优先级**：先用 MiniMax 跑通完整产品链路，等链路全部跑通后再考虑部署到 8×4090 服务器
- **不做付费模块**、**不做社交 Agent**

#### 6.13.2 provider=mock 排查结论

线上 `/api/generate-music` 仍返回 `provider=mock` 的根因排查：

| 检查项 | 现状 | 结论 |
|---|---|---|
| `wrangler.toml` `MUSIC_GENERATION_PROVIDER` | `minimax_music` | ✅ 正确 |
| `wrangler.toml` `MUSIC_GENERATION_REAL_CALLS_ENABLED` | 原为 `"true"`，本批改回 `"false"` | ⚠️ 违反"默认 false"约束，已修正 |
| 线上是否部署含 MiniMax provider 版本 | 已部署（P4.4-5 已合并） | ✅ |
| `MINIMAX_API_KEY` 在 Cloudflare Production Secret | 未在 wrangler.toml（正确） | **疑似未在 Dashboard Secret 配置** |
| provider factory 缺 key 行为 | 降级 MockProvider | **provider=mock 根因** |
| `/api/generate-music` 读取 env | `context.env` | ✅ 正确 |

**根因**：`functions/api/_music/provider-factory.js` 当 `providerName === 'minimax_music'` 且 `!hasMinimaxKey` 时降级为 `MockProvider`。即使 `REAL_CALLS_ENABLED=true`，缺 Key 也会被 factory 降级。**最可能原因是 `MINIMAX_API_KEY` 未在 Cloudflare Production Secret 配置**（或配置在错误环境）。

**排查方法**：访问 `/api/health`，查看 `diagnostics.hasMinimaxKey` 字段（本批新增，详见 6.13.3）。

#### 6.13.3 安全诊断字段（/api/health）

在 `/api/health` 响应中新增 `diagnostics` 非敏感字段，用于排查 provider 选择 / 真实调用开关 / Key 配置状态：

```json
{
  "ok": true,
  "service": "xinxian-functions",
  "version": "v1",
  "timestamp": "2026-07-19T...Z",
  "diagnostics": {
    "musicProvider": "minimax_music",
    "realCallsEnabled": false,
    "hasMinimaxKey": false,
    "hasReplicateToken": false,
    "hasStableAudioKey": false,
    "buildLabel": "P4-minimax-song-gray-1"
  }
}
```

**安全保证**：
- 只返回 `hasXxxKey: true/false`，**不返回任何 API Key 值**
- 不返回 env 中的其他敏感字段
- 不访问 D1 / LLM
- `buildLabel` 与前端 `lib/config/app_version.dart` 同步维护（用于确认线上部署的代码版本）

#### 6.13.4 三重门灰度策略

真实调用设计为**三重门 + Key 配置**，四者同时满足才真实调用 MiniMax API：

| 门 | 配置位置 | 默认值 | 说明 |
|---|---|---|---|
| 门1: `MUSIC_GENERATION_PROVIDER=minimax_music` | `wrangler.toml` | `minimax_music` | provider 入口判断 |
| 门2: `MUSIC_GENERATION_REAL_CALLS_ENABLED=true` | `wrangler.toml` | `false` | 真实调用总开关，手动测试时临时改 true |
| 门3: 请求体 `manualTest=true` | curl 手动传入 | 不传 | 前端默认不带，只手动 curl 测试时传入 |
| Key: `MINIMAX_API_KEY` 存在 | Cloudflare Dashboard Secret | — | 缺失则 factory 降级 MockProvider |

**前端默认不带 `manualTest`**，本批**不加前端灰度开关**。真实调用只通过手动 curl 触发。

#### 6.13.5 「生成这首歌」按钮接入方式

`ComfortLyricsScreen` 的「生成这首歌（即将开放）」按钮本批**保持灰度入口**：

- **默认仍显示为灰度入口**：文案不变，淡紫色 FilledButton
- **点击行为**：弹出浮动 SnackBar 提示「歌曲生成正在准备中，当前先支持歌词确认。」（2 秒后消失）
- **不调用 `/api/generate-music`**：前端本批不发起任何音乐生成请求
- **不传 `manualTest`**：前端默认不带灰度标记
- **不产生费用**：没有任何自动扣费路径
- **编辑态禁用**：编辑歌词时按钮 disabled

后续批次再考虑开放前端灰度开关（仅开发/测试可见）。真实调用通过手动 curl 触发。

#### 6.13.6 MiniMax 请求体适配

进入真实调用分支（三重门全部通过）后，MiniMax provider 的请求体构造：

| 字段 | 来源 | 说明 |
|---|---|---|
| `model` | `MINIMAX_MUSIC_MODEL` env | `music-2.0` |
| `prompt` | `validated.songPrompt`（优先）/ `PROMPTS_BY_TARGET_STATE[targetState]`（回退） | LLM 生成的英文风格提示 |
| `lyrics` | `validated.lyrics`（如果存在） | 用户编辑后的歌词 `_editedLyric ?? result.lyricDraft` |
| `audio_setting` | 固定 | `mp3 / 44100 / 256000` |

**安全与隐私**：
- ❌ **不传用户原始困惑全文**（`storyText` 不进入 MiniMax 请求，`validateInput` 不透传该字段）
- ❌ **不打印完整歌词到日志**（只打印 `lyricsLength` / `songPromptLength`）
- ❌ **不返回完整 `audioHex` 到前端**（只返回 `audioHexLength` / `musicDuration` / `traceId` / `status`）
- ✅ 时长 < 2 分钟（`MUSIC_GENERATION_MAX_DURATION_SECONDS=120`）
- ✅ `lyrics` 长度上限 2000 字符（超过截断）
- ✅ `songPrompt` 长度上限 500 字符（超过截断）
- ✅ `lyrics` / `songPrompt` 经过 `isPromptForbidden` 过滤（避免医疗化/玄学化表达）
- ✅ 真正播放音频下一批处理（本批只返回元数据摘要）

#### 6.13.7 手动 curl 测试方式

在 Cloudflare Dashboard 配置 `MINIMAX_API_KEY` Secret 后，临时将 `wrangler.toml` 中 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 改为 `"true"` 并部署，然后：

```bash
# 真实调用测试（会产生费用，约 0.25 元/次）
curl -X POST https://xinxian-music.xyz/api/generate-music \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "manual-test-gray",
    "targetState": "soothe",
    "generationPrompt": "ambient music, no vocals",
    "durationSeconds": 120,
    "manualTest": true,
    "lyrics": "【主歌】\n夜色慢慢盖下来\n【副歌】\n想哭也没关系，我在听",
    "songPrompt": "gentle mandarin ballad, soft breathy vocal, fingerstyle guitar, slow tempo"
  }'
```

测试完成后**立即将 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 改回 `"false"` 并重新部署**，避免线上持续可被调用。

#### 6.13.8 新增/修改文件清单

- `wrangler.toml`（修改）：`MUSIC_GENERATION_REAL_CALLS_ENABLED` 从 `"true"` 改回 `"false"`；新增三重门保护注释
- `functions/api/health.js`（修改）：新增 `diagnostics` 非敏感诊断字段（`musicProvider` / `realCallsEnabled` / `hasMinimaxKey` / `hasReplicateToken` / `hasStableAudioKey` / `buildLabel`）；导出 `buildDiagnostics` 用于测试；`BUILD_LABEL` 常量与前端 `app_version.dart` 同步
- `functions/api/_music/music-generation-utils.js`（修改）：`validateInput` 新增 `lyrics` / `songPrompt` 可选字段（长度限制 + `isPromptForbidden` 过滤）
- `functions/api/_music/providers/minimax-music-provider.js`（修改）：`_callMiniMax` 使用 `validated.lyrics` + `validated.songPrompt`；`_buildPrompt` 优先用 `validated.songPrompt`，回退到 `PROMPTS_BY_TARGET_STATE`；日志只打印长度不打印内容；返回 `lyricsLength` / `songPromptSource` 摘要字段；更新行为矩阵注释为三重门
- `functions/api/_music/provider-factory.js`（修改）：更新注释为 P4 第四批三重门；`minimax_music` 分支日志增加 `hint` 提示
- `lib/screens/comfort_lyrics_screen.dart`（修改）：`_buildGenerateSongButton` / `_showGenerateSongHint` 注释更新为 P4 第四批状态（按钮行为不变，保持灰度入口）
- `scripts/verify-provider-adapter.mjs`（修改）：新增 14 项 P4 第四批测试（lyrics/songPrompt 解析 / 超长截断 / 禁止关键词 / 透传到 requestBody / 缺字段回退 / 不传 storyText / 日志不泄露歌词 / 不调用 Mureka / health 诊断字段 / 不泄露 Key 值），共 46 项测试
- `lib/config/app_version.dart`（修改）：`buildLabel` → `P4-minimax-song-gray-1`，`buildDate` → `2026-07-19`，新增 `P{N}-minimax-song-gray-{n}` 约定说明
- `README.md`（修改）：新增 6.13 章节 + 顶部版本号 + 2.1 当前阶段 + 变更记录

后端 `functions/api/generate-music.js` / `functions/api/music-status.js` 本批**未修改**（已正确读取 env + 透传 manualTest）。前端 `comfort_lyrics_service.dart` / `comfort_lyrics_result.dart` 本批**未修改**（按钮不调用 API，无需新增字段）。

#### 6.13.9 明确不做

- ❌ 本批**不开放前端真实调用**（按钮保持灰度入口，只 SnackBar 提示）
- ❌ 本批**不调用 Mureka API**（Mureka 仍是后续候选，暂不接入）
- ❌ 本批**不部署 4090 服务器**（只在 README 记录为后续自托管 worker 方向）
- ❌ 本批**不改 D1 schema**（只用前端临时状态或现有 mock/status 结构）
- ❌ 本批**不做付费模块**（明确是后续阶段）
- ❌ 本批**不做社交 Agent**（明确是后续阶段）
- ❌ 本批**不写入任何 API Key**（`MINIMAX_API_KEY` 只在 Cloudflare Dashboard Secret 中）
- ❌ 本批**不打印 `MINIMAX_API_KEY`**（日志只打印 `apiKeyConfigured: true/false`）
- ❌ 本批**不使用医疗化 / 玄学化表达**
- ❌ 本批**不返回完整 `audioHex` 到前端**（只返回 `audioHexLength` 摘要）
- ❌ 本批**不实现真实音频播放**（下一批处理）

#### 6.13.10 验证

- `node scripts/verify-provider-adapter.mjs`：45 项测试全部通过（含 14 项 P4 第四批新增）
- `node scripts/verify-comfort-lyrics.mjs`：35 项测试全部通过（后端未改，回归通过）
- `flutter analyze`：No issues found
- `flutter test`：全部通过（前端按钮行为未变，P4 第三批测试无回归）
- `flutter build web --release`：见 [第九章 本地开发与验证](#九本地开发与验证)

#### 6.13.11 后续路线（不在本批实现）

- **下一批**：真实音频播放（解析 `audioHex` / 接入播放器 / 播放控制）
- **后续候选**：前端灰度开关（仅开发/测试可见，普通用户仍只看到提示）
- **后续候选**：Mureka API 接入（最低充值 200 元，成本偏高，暂缓）
- **后续方向**：8×4090 自托管音乐生成 worker（不替换 Cloudflare 后端，作为 worker 节点）

---

### 6.14 P4 前端结构调整第一批：首页双主线重构（2026-07-19）

承接 6.13 P4 新方向第四批（MiniMax 歌曲生成灰度接入），本批重构首页信息架构，让用户一进入首页就能清楚选择两条路径。项目已从「情绪识别 → 舒缓音乐推荐」扩展为「困惑解惑 → 歌词生成 → 后续 AI 歌曲生成」，因此前端首页需要重新整理，避免功能入口堆叠。**新的产品主线突出「把困惑写成一首歌」，原来的情绪配乐流程保留为「快速舒缓一下」**。

本批**只调整前端结构和文案，不调用 MiniMax/Mureka，不生成真实音频，不改后端 API，不改 D1 schema**。

#### 6.14.1 首页双主线结构

`HomeScreen` 从「单一心境输入 + 主按钮 + 弱化入口」重构为**双主线并列结构**：

| 主线 | 标题 | 副文案 | 按钮 | 点击行为 | 视觉权重 |
|---|---|---|---|---|---|
| 第一主线 | 把困惑写成一首歌 | 说说最近卡住你的事，让它先变成一段温和的歌词。 | 开始写歌 | 进入 `ComfortLyricsScreen` | 高（lavender 边框卡片） |
| 第二主线 | 快速舒缓一下 | 不想多说也可以，直接生成一段适合现在的舒缓音乐方案。 | 快速生成方案 | 走原有心境输入/分析流程 | 中（朴素区域） |

- **第一主线**用带 lavender 边框的卡片突出（`_PrimaryEntryCard`），与 `ComfortLyricsScreen` 生成按钮色调呼应
- **第二主线**保留原有 `MoodInputField` + 示例 chips + 分析按钮，朴素区域不抢戏
- 两条路径并列，用户一进入首页就能清楚选择

#### 6.14.2 首页底部入口整理

首页底部只保留：
- `查看历史记录`
- `设置`
- 版本号弱展示（小字 muted 色）

隐私政策 / 关于心弦 / AI 解析设置 / 云端反馈采集 继续放在设置弹窗中（P2-Web-v1.0 第四批已有逻辑，本批不改动）。

#### 6.14.3 ComfortLyricsScreen 文案优化

- 输入区标题：`写下你的困惑` → `先说说卡住你的事`（更温和、更像产品体验）
- 结果区文案保持不变（`给现在的你` / `写成歌的话` / `后续生成参数` 默认折叠，P4 第二批已优化）
- 编辑歌词功能保持现有行为（P4 第三批）
- `生成这首歌（即将开放）` 保留，不调用 API（P4 第四批灰度入口）

#### 6.14.4 文案风格

整体文案温和、像产品体验、不医疗化、不玄学化、不承诺治疗效果：

- ✅ 推荐表达：`陪你整理` / `写成一首歌` / `先站稳一点` / `快速舒缓` / `适合现在的音乐`
- ❌ 禁用表达：`治疗` / `治愈` / `诊断` / `疗法` / `命中注定` / `神谕` / `算准`

#### 6.14.5 移动端适配

- 首页两个主入口在移动端垂直堆叠，不拥挤
- 按钮高度稳定（第一主线 48 / 第二主线 50）
- 文案不溢出（副文案用 `height: 1.5` 行高 + 简短表达）
- 不出现卡片套卡片（第一主线是单层卡片，内部不再嵌套卡片）
- 不出现大面积空白（双主线紧凑布局）
- 文本不遮挡按钮（Column 垂直排列，无 Stack 重叠）

#### 6.14.6 新增/修改文件清单

- `lib/screens/home_screen.dart`（修改）：
  - `build` 方法重构为双主线结构（第一主线卡片 + 第二主线朴素区域）
  - 原「生成专属疗愈方案」按钮文案改为「快速生成方案」
  - 原「把困惑写成一首歌」OutlinedButton 升级为 `_PrimaryEntryCard` 卡片
  - 新增 `_PrimaryEntryCard` 私有 widget（lavender 边框卡片 + 图标 + 标题 + 副文案 + FilledButton）
  - 底部入口（历史记录 + 设置 + 版本号）保持不变
  - 设置弹窗逻辑保持不变
- `lib/screens/comfort_lyrics_screen.dart`（修改）：输入区标题 `写下你的困惑` → `先说说卡住你的事`
- `test/widget_test.dart`（修改）：现有测试文案断言 `生成专属疗愈方案` → `快速生成方案`；新增 2 项 P4 前端结构调整第一批测试（双主线可见 / 点击开始写歌进入 ComfortLyricsScreen）
- `lib/config/app_version.dart`（修改）：`buildLabel` → `P4-home-structure-1`，新增 `P{N}-home-structure-{n}` 约定说明
- `README.md`（修改）：新增 6.14 章节 + 顶部版本号 + 2.1 当前阶段 + 变更记录

后端 `functions/api/*` 本批**未修改**。`lib/screens/analysis_screen.dart` / `plan_screen.dart` / `player_screen.dart` 本批**未修改**（快速舒缓流程仍走原路径）。

#### 6.14.7 明确不做

- ❌ 本批**不调用 MiniMax / Mureka**
- ❌ 本批**不生成真实音频**
- ❌ 本批**不改 Cloudflare Functions**
- ❌ 本批**不改 D1 schema**
- ❌ 本批**不做付费模块**
- ❌ 本批**不做社交 Agent**
- ❌ 本批**不写入任何 API Key**
- ❌ 本批**不使用医疗化 / 玄学化表达**
- ❌ 本批**不改原快速舒缓流程的 AnalysisScreen / PlanScreen / PlayerScreen**（保留原路径）

#### 6.14.8 验证

- `node scripts/verify-comfort-lyrics.mjs`：35 项测试全部通过（后端未改，回归通过）
- `flutter analyze`：No issues found
- `flutter test`：全部通过（含新增 2 项 P4 前端结构调整第一批测试 + 原 comfort_lyrics_screen_test 23 项不回归）
- `flutter build web --release`：见 [第九章 本地开发与验证](#九本地开发与验证)

---

### 6.15 P4 MiniMax 真实生成链路受控测试（2026-07-19）

承接 6.14 P4 前端结构调整第一批（首页双主线重构），本批在不开放前端自动扣费、不接入用户正式入口的前提下，完善 MiniMax Music-2.0 真实生成链路返回信息，并准备手动 curl 测试流程。**本批只做受控手动真实调用测试，前端没有开放正式扣费入口，仓库默认 `MUSIC_GENERATION_REAL_CALLS_ENABLED=false`**。

#### 6.15.1 当前策略

- **provider**：`MUSIC_GENERATION_PROVIDER = "minimax_music"`（wrangler.toml，保持不变）
- **真实调用总开关**：`MUSIC_GENERATION_REAL_CALLS_ENABLED = "false"`（wrangler.toml，仓库默认 false，**测试时手动改 true，测完改回 false**）
- **请求体保护**：`manualTest === true`（curl 手动传入，前端默认不传，**不允许移除**）
- **API Key**：`MINIMAX_API_KEY` 在 Cloudflare Production Secret 中配置（已确认 hasMinimaxKey=true）
- **三重门保护**：只有 `provider=minimax_music` + `REAL_CALLS_ENABLED=true` + `manualTest=true` + `Key 存在` 四者同时满足才真实调用 MiniMax API，避免误扣费
- **前端不开放真实调用**：「生成这首歌」按钮仍为灰度入口（点击只弹 SnackBar 提示，不调用 `/api/generate-music`）

#### 6.15.2 完善后的 MiniMax 返回信息

`minimax-music-provider.js` `_callMiniMax` / `_fallbackResponse` 补齐安全诊断字段，**不泄露 API Key / 不泄露 MiniMax 原始错误细节 / 不泄露 errText / 不泄露 status_msg / 不泄露 err.message**：

| 字段 | 类型 | 来源 | 说明 |
|---|---|---|---|
| `provider` | string | 内部 | 真实成功为 `minimax_music`；fallback 为 `minimax_music_disabled` / `minimax_music_http_error` 等 |
| `status` | string | 内部 | `succeeded` / `fallback` |
| `jobId` | null | 内部 | MiniMax 同步接口无 jobId（固定 null） |
| `taskId` | string\|null | `data.data.task_id` / `data.task_id` | MiniMax 同步接口通常无，兼容字段 |
| `traceId` | string\|null | `data.trace_id` | MiniMax 返回的 trace_id |
| `requestId` | string\|null | `data.request_id` | MiniMax 返回的 request_id（与 trace_id 互为补充） |
| `audioHexLength` | number | `data.data.audio.length` | audio hex 长度（不返回完整 hex） |
| `audioUrl` | string\|null | `data.data.audio_url` | MiniMax 返回 URL 时透传（便于后续接入 R2 / 在线播放） |
| `audioUrlLength` | number | `audioUrl.length` | audioUrl 长度 |
| `musicDuration` | number | `data.data.music_duration` | 时长（秒） |
| `lyricsLength` | number | 内部 | 请求歌词长度（不返回完整歌词） |
| `songPromptSource` | string | 内部 | `user_song_prompt` / `preset_by_target_state` |
| `fallbackTrack` | object | 内部 | 预置音频 fallback（始终返回，便于前端无中断播放） |
| `estimatedSeconds` | number | 内部 | `Math.round(musicDuration)` |
| `errorCode` | string | 内部 | fallback 时与 `reason` 一致（如 `http_error_401` / `minimax_error_1001` / `request_timeout`） |
| `errorMessage` | string | 内部 | fallback 时返回**安全映射**消息（如 `minimax_http_error` / `minimax_business_error`），**不泄露原始错误内容** |
| `createdAt` | string | 内部 | ISO 时间戳 |

#### 6.15.3 errorMessage 安全映射规则

`_mapErrorMessage(reason, extra)` 根据 reason 返回内部友好消息，**extra 中的原始值（httpStatus / minimaxStatusCode / errorName）仅用于映射，不进入响应**：

| reason | errorMessage | 说明 |
|---|---|---|
| `http_error_*` | `minimax_http_error` | HTTP 错误，不返回 statusText / errText |
| `minimax_error_*` | `minimax_business_error` | MiniMax 业务错误，不返回 status_msg |
| `request_timeout` | `minimax_request_timeout` | 超时（55s） |
| `request_failed` | `minimax_request_failed` | fetch 异常，不返回 err.message |
| `provider_disabled` | `minimax_real_calls_disabled` | REAL_CALLS_ENABLED=false |
| `api_key_missing` | `minimax_api_key_missing` | MINIMAX_API_KEY 缺失 |
| `manual_test_required` | `manual_test_required` | 请求体未携带 manualTest=true |
| `not_implemented` | `not_implemented` | 其他未实现分支 |

#### 6.15.4 手动 curl 测试请求

使用 Music-2.0 模型，时长 ≤ 120 秒，请求体**必须包含 `manualTest=true`**：

```bash
# 真实调用测试（会产生费用，约 0.25 元/次）
# 前置：wrangler.toml 中 MUSIC_GENERATION_REAL_CALLS_ENABLED 临时改为 "true" 并部署
curl -X POST https://xinxian-music.xyz/api/generate-music \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "manual-minimax-test-001",
    "targetState": "sleep",
    "generationPrompt": "ambient sleep music, instrumental, no vocals, slow tempo, gentle texture, warm and calming",
    "lyrics": "今晚先把心放轻\n不用急着回答所有问题\n让呼吸慢慢落下来\n明天再继续也可以",
    "durationSeconds": 120,
    "manualTest": true
  }'
```

**预期成功响应**（MiniMax 返回 audio hex）：

```json
{
  "ok": true,
  "provider": "minimax_music",
  "status": "succeeded",
  "jobId": null,
  "taskId": null,
  "traceId": "<MiniMax trace_id>",
  "requestId": null,
  "audioHexLength": <hex 字节数>,
  "audioUrl": null,
  "audioUrlLength": 0,
  "musicDuration": <秒>,
  "lyricsLength": 42,
  "songPromptSource": "preset_by_target_state",
  "fallbackTrack": { ... },
  "estimatedSeconds": <秒>,
  "createdAt": "<ISO>"
}
```

**预期 fallback 响应**（REAL_CALLS=false 或 manualTest 缺失）：

```json
{
  "ok": false,
  "reason": "provider_disabled",
  "errorCode": "provider_disabled",
  "errorMessage": "minimax_real_calls_disabled",
  "jobId": null,
  "taskId": null,
  "traceId": null,
  "requestId": null,
  "status": "fallback",
  "fallbackTrack": { ... },
  "estimatedSeconds": 0,
  "provider": "minimax_music_disabled",
  "createdAt": "<ISO>"
}
```

#### 6.15.5 手动测试完整流程

1. **临时开启真实调用**：将 `wrangler.toml` 中 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 从 `"false"` 改为 `"true"`（**不提交到 git**）
2. **部署到 Cloudflare**：`wrangler pages deploy build/web --project-name=xinxian-healing-music`
3. **验证 health 状态**：`curl https://xinxian-music.xyz/api/health` 确认 `realCallsEnabled=true` / `hasMinimaxKey=true`
4. **执行 curl 测试**：按 6.15.4 的请求体调用 `/api/generate-music`（必须包含 `manualTest=true`）
5. **观察响应**：记录 `provider` / `status` / `taskId` / `traceId` / `requestId` / `audioUrl` / `audioHexLength` / `musicDuration`
6. **测试完成后立即关闭真实调用**：将 `wrangler.toml` 中 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 改回 `"false"`
7. **重新部署**：`wrangler pages deploy build/web --project-name=xinxian-healing-music`
8. **再次验证 health**：`curl https://xinxian-music.xyz/api/health` 确认 `realCallsEnabled=false` / `hasMinimaxKey=true`

#### 6.15.6 新增/修改文件清单

- `functions/api/_music/providers/minimax-music-provider.js`（修改）：
  - 顶部注释新增 P4-minimax-real-test-1 字段说明（audioUrl / taskId / requestId / errorMessage / errorCode）
  - `_callMiniMax` 补齐 `audioUrl` / `taskId` / `requestId` 字段提取（兼容 `data.data.audio_url` / `data.data.task_id` / `data.task_id` / `data.request_id`）
  - 成功响应返回 `audioUrl` / `audioUrlLength` / `taskId` / `requestId` 字段
  - `_fallbackResponse` 新增第四个参数 `extra`（用于 errorMessage 映射，不进入响应）
  - `_fallbackResponse` 返回字段新增 `errorCode`（与 `reason` 一致）/ `errorMessage`（安全映射）/ `taskId` / `traceId` / `requestId`（null）
  - 新增 `_mapErrorMessage(reason, extra)` 方法：根据 reason 返回内部友好消息，不泄露 MiniMax 原始错误细节
  - HTTP 错误 / 业务错误 / 超时 / fetch 异常调用 `_fallbackResponse` 时传入 `extra`（httpStatus / minimaxStatusCode / errorName）
- `wrangler.toml`（修改）：`MUSIC_GENERATION_REAL_CALLS_ENABLED` 注释新增 P4-minimax-real-test-1 手动测试流程说明（**保持 `"false"`**，仓库默认安全）
- `functions/api/health.js`（修改）：`BUILD_LABEL` 常量同步为 `P4-minimax-real-test-1`
- `lib/config/app_version.dart`（修改）：`buildLabel` → `P4-minimax-real-test-1`，新增 `P{N}-minimax-real-test-{n}` 约定说明
- `scripts/verify-provider-adapter.mjs`（修改）：
  - 测试 24（MiniMax disabled）`errorCode` 断言从 `'not_implemented'` 改为 `'provider_disabled'`，新增 `errorMessage` / `taskId` / `traceId` / `requestId` 断言
  - 测试 25（manual_test_required）新增 `errorCode` / `errorMessage` 断言
  - 测试 26（成功）新增 `audioUrl` / `audioUrlLength` / `taskId` / `requestId` 断言
  - 测试 27/28/29（HTTP 错误 / 业务错误 / fetch 异常）新增 `errorMessage` / `errorCode` 断言
  - 新增测试 47-53（P4-minimax-real-test-1）：audioUrl 解析 / taskId 解析 / requestId 解析 / HTTP 错误 errorMessage 不泄露 errText / 业务错误 errorMessage 不泄露 status_msg / fetch 异常 errorMessage 不泄露 err.message / fallback 响应包含 taskId/traceId/requestId 字段
- `README.md`（修改）：新增 6.15 章节 + 顶部版本号 + 2.1 当前阶段 + 13.5 变更记录

后端 `functions/api/generate-music.js` / `functions/api/music-status.js` / `functions/api/_music/music-generation-utils.js` 本批**未修改**（已正确透传 env + manualTest + lyrics/songPrompt）。前端 `lib/screens/*` 本批**未修改**（按钮保持灰度入口）。

#### 6.15.7 明确不做

- ❌ 本批**不开放前端真实调用**（按钮保持灰度入口，只 SnackBar 提示）
- ❌ 本批**不调用 Mureka API**（Mureka 仍是后续候选，暂不接入）
- ❌ 本批**不部署 4090 服务器**（只在 README 记录为后续自托管 worker 方向）
- ❌ 本批**不改 D1 schema**（只用前端临时状态或现有 mock/status 结构）
- ❌ 本批**不做付费模块**（明确是后续阶段）
- ❌ 本批**不做社交 Agent**（明确是后续阶段）
- ❌ 本批**不写入任何 API Key**（`MINIMAX_API_KEY` 只在 Cloudflare Dashboard Secret 中）
- ❌ 本批**不打印 `MINIMAX_API_KEY`**（日志只打印 `apiKeyConfigured: true/false`）
- ❌ 本批**不使用医疗化 / 玄学化表达**
- ❌ 本批**不返回完整 `audioHex` 到前端**（只返回 `audioHexLength` 摘要）
- ❌ 本批**不实现真实音频播放**（拿到 `audioUrl` 或 `audioHex` 后的播放逻辑是下一批处理）
- ❌ 本批**不实现 R2 持久化存储**（生成音频不保存到 D1 / R2 / 文件系统）
- ❌ 本批**不实现 MiniMax 异步任务轮询**（Music-2.0 同步接口，POST 一次拿到结果）
- ❌ 本批**不允许移除 `manualTest` 保护**（三重门之一，保留防止误扣费）

#### 6.15.8 测试期间的安全保证

- **仓库默认 `REAL_CALLS_ENABLED=false`**：即使本批代码被部署到线上，也不会产生费用（三重门第 2 道关闭）
- **`manualTest=true` 必须显式传入**：前端默认不携带此字段，只有手动 curl 测试时才会传入
- **测试期间的 `true` 状态只在本地或临时部署中存在**：不应提交到 git，测试完成后立即改回 `false`
- **`/api/health` 诊断字段**：`realCallsEnabled` / `hasMinimaxKey` 可随时验证线上状态，便于确认测试完成后已恢复 false

#### 6.15.9 后续路线（不在本批实现）

- **下一批**：真实音频播放（解析 `audioHex` / `audioUrl` → 接入 just_audio 播放器 / 播放控制）
- **后续候选**：前端灰度开关（仅开发/测试可见，普通用户仍只看到提示）
- **后续候选**：R2 持久化存储（生成音频保存到 R2，避免重复生成）
- **后续候选**：Mureka API 接入（最低充值 200 元，成本偏高，暂缓）
- **后续方向**：8×4090 自托管音乐生成 worker（不替换 Cloudflare 后端，作为 worker 节点）

#### 6.15.10 验证

- `node scripts/verify-provider-adapter.mjs`：52 项测试全部通过（含 7 项 P4-minimax-real-test-1 新增）
- `node scripts/verify-comfort-lyrics.mjs`：35 项测试全部通过（后端 comfort-lyrics 未改，回归通过）
- `flutter analyze`：No issues found
- `flutter test`：全部通过（前端按钮行为未变，无回归）
- `flutter build web --release`：见 [第九章 本地开发与验证](#九本地开发与验证)

> **手动 curl 真实测试已完成**：详见 6.15.11 真实调用结果（2026-07-19 02:39 UTC）。真实调用成功，已拿到 `audioHexLength=1022098`（约 512KB mp3），`realCallsEnabled` 测完已恢复 `false`。

#### 6.15.11 真实调用结果（2026-07-19 02:39 UTC）

本批已完成一次受控真实调用测试，验证「歌词/提示词 → MiniMax Music-2.0 → 返回生成结果」后端链路可行。

**测试时间**：2026-07-19 02:39 UTC（北京时间 10:39）

**测试请求**（按 6.15.4 测试体）：

```json
{
  "sessionId": "manual-minimax-test-001",
  "targetState": "sleep",
  "generationPrompt": "ambient sleep music, instrumental, no vocals, slow tempo, gentle texture, warm and calming",
  "lyrics": "今晚先把心放轻\n不用急着回答所有问题\n让呼吸慢慢落下来\n明天再继续也可以",
  "durationSeconds": 120,
  "manualTest": true
}
```

**实际返回 JSON**（已脱敏，不含 API Key）：

```json
{
  "ok": true,
  "provider": "minimax_music",
  "status": "succeeded",
  "jobId": null,
  "taskId": null,
  "traceId": "06ab6bd351ff28a4d8dbb6cefddee5fe",
  "requestId": null,
  "audioHexLength": 1022098,
  "audioUrl": null,
  "audioUrlLength": 0,
  "musicDuration": 0,
  "lyricsLength": 36,
  "songPromptSource": "preset_by_target_state",
  "fallbackTrack": {
    "audioAssetId": "sleep_01",
    "audioAssetTitle": "夜色舒缓 · Theta 入眠",
    "audioUrl": "/assets/music/sleep_01.mp3"
  },
  "estimatedSeconds": 0,
  "createdAt": "2026-07-19T02:39:42.989Z"
}
```

**关键字段解读**：

| 字段 | 实际值 | 说明 |
|---|---|---|
| `ok` | `true` | ✅ MiniMax 真实调用成功 |
| `provider` | `minimax_music` | ✅ 真实调用了 MiniMax（非 mock） |
| `status` | `succeeded` | ✅ 调用成功 |
| `jobId` | `null` | MiniMax 同步接口无 jobId（符合预期） |
| `taskId` | `null` | MiniMax 同步接口未返回 task_id 字段 |
| `traceId` | `06ab6bd351ff28a4d8dbb6cefddee5fe` | ✅ 拿到 MiniMax trace_id（用于排查） |
| `requestId` | `null` | MiniMax 响应未返回 request_id 字段 |
| `audioHexLength` | `1022098` | ✅ **拿到真实音频数据**（hex 长度约 1MB，对应约 512KB mp3） |
| `audioUrl` | `null` | MiniMax 返回 audio hex 而非 audio_url（符合 Music-2.0 同步接口行为） |
| `audioUrlLength` | `0` | 无 audioUrl |
| `musicDuration` | `0` | ⚠️ MiniMax 响应未返回 music_duration 字段（或返回 0），后续可从前端播放器实际播放时长获取 |
| `lyricsLength` | `36` | ✅ 歌词长度正确（4 行中文 + 换行 = 36 字符） |
| `songPromptSource` | `preset_by_target_state` | 请求体传的是 `generationPrompt` 字段，未传 `songPrompt`，所以回退到 `PROMPTS_BY_TARGET_STATE.sleep` |
| `errorCode` | 未返回（成功响应无 errorCode） | ✅ 无错误 |
| `errorMessage` | 未返回（成功响应无 errorMessage） | ✅ 无错误 |

**结论**：

- ✅ **MiniMax 真实调用链路可行**：歌词/提示词 → MiniMax Music-2.0 → 返回 audio hex 全链路打通
- ✅ **拿到了真实音频数据**：`audioHexLength=1022098`（约 512KB mp3），可用于后续播放
- ✅ **拿到了 traceId**：便于后续问题排查
- ⚠️ **未拿到 audioUrl**：MiniMax Music-2.0 同步接口返回 audio hex 而非 URL，后续若需 URL 形式需自行上传到 R2 并生成 URL
- ⚠️ **musicDuration=0**：MiniMax 响应未返回 music_duration 字段，后续可从前端播放器实际播放时长获取
- ℹ️ **本次调用产生真实费用**：约 0.25 元（MiniMax Music-2.0 单次调用计费）
- ℹ️ **请求体 `generationPrompt` 未作为 `songPrompt` 传入**：当前 `minimax-music-provider.js` 使用 `validated.songPrompt` 字段，请求体的 `generationPrompt` 不会自动映射为 `songPrompt`，所以回退到 `PROMPTS_BY_TARGET_STATE.sleep`。这是预期行为（`generationPrompt` 用于 mock provider，`songPrompt` 用于真实 provider），但后续可考虑在 `_buildPrompt` 中也兼容 `generationPrompt` 字段

**测试后状态**：

- `wrangler.toml` 已改回 `MUSIC_GENERATION_REAL_CALLS_ENABLED = "false"`
- 已重新部署到 Cloudflare Pages
- `/api/health` 确认：`realCallsEnabled=false` / `hasMinimaxKey=true` / `musicProvider=minimax_music` / `buildLabel=P4-minimax-real-test-1`
- 仓库默认安全，线上不会持续可被调用产生费用

**未完成（不在本批实现）**：

- ❌ R2 持久化存储（生成音频未保存到 R2，每次调用都重新生成）
- ❌ 在线播放（拿到 `audioHex` 后的播放逻辑是下一批处理）
- ❌ 付费模块（明确是后续阶段）
- ❌ `audioHex` → base64 → just_audio 播放链路（下一批）
- ❌ `musicDuration` 从前端播放器获取实际时长（下一批）
- ❌ `generationPrompt` → `songPrompt` 字段映射优化（下一批可选）

---

### 6.16 P4 生成音频落地播放链路

**版本**：`v1.0.0 / P4-generated-audio-playback-1`
**日期**：2026-07-19
**前置**：6.15 P4 MiniMax 真实生成链路受控测试已完成，确认 MiniMax Music-2.0 同步接口返回 `audioHexLength=1022098` / `audioUrl=null`（返回 hex 而非 URL）。

#### 6.16.1 本批目标

完成「MiniMax 返回 audioHex → 后端生成可播放音频资源 → 前端能播放这首 AI 生成歌曲」的第一版闭环。

具体目标：

1. **后端音频处理**：MiniMax 返回 audio hex → 转 Uint8Array → 上传到 R2 → 返回 `generatedAudioUrl`
2. **R2 存储接入**：新增 `GENERATED_MUSIC_BUCKET` binding，bucket 名 `xinxian-generated-music`
3. **可播放 URL**：通过 `/api/generated-music?key={storageKey}` 代理读取 R2（无需 R2 公开访问）
4. **前端播放入口**：`ComfortLyricsScreen` 「生成这首歌（实验）」受控入口 + 费用确认 + 内嵌播放区
5. **API 字段兼容**：不破坏现有 `/api/generate-music` 格式，`fallbackTrack` 保留，mock provider 正常工作
6. **版本号同步**：`buildLabel` → `P4-generated-audio-playback-1`

#### 6.16.2 重要约束（本批严格遵守）

- 继续使用 MiniMax，**不切换 Mureka / Replicate / 4090**
- `MUSIC_GENERATION_REAL_CALLS_ENABLED` 默认**必须保持 `false`**
- `manualTest=true` 保护**不能移除**（三重门之一）
- **不暴露 `MINIMAX_API_KEY`**（前端不持有任何凭证）
- **不允许前端正式入口自动扣费**（必须用户主动点击 + 确认对话框）
- **不做付费模块 / 不做社交 Agent / 不做完整用户系统**
- **不使用「治疗 / 治愈 / 诊断 / 疗法」等医疗化表达**
- **不把 `audioHex` 原文返回给前端作为长期方案**（避免巨大响应 + 避免长期暴露）
- **R2 binding 不存在时返回清楚错误，不崩溃**

#### 6.16.3 MiniMax audioHex 是如何转成音频资源的

**问题**：MiniMax Music-2.0 同步接口返回 `data.data.audio` 为 hex 字符串（如 `"ff fb 90 ..."`），**不返回 `audio_url`**。

**本批处理流程**：

```
MiniMax 响应 (data.data.audio: hex string)
    ↓
minimax-music-provider.js _callMiniMax()
    ↓
_hexToBytes(audioHex) → Uint8Array (mp3 二进制)
    ↓
_buildStorageKey(sessionId, traceId) → "generated-music/{yyyyMMdd}/{sessionId}-{traceId}.mp3"
    ↓
R2 put(storageKey, audioBytes, { httpMetadata: { contentType: 'audio/mpeg' } })
    ↓
返回 generatedAudioUrl = "/api/generated-music?key=" + encodeURIComponent(storageKey)
    ↓
前端 just_audio AudioSource.uri(Uri.base.resolve(generatedAudioUrl)) 播放
```

**三种情况处理**：

| 情况 | 触发条件 | 响应字段 | 前端表现 |
|---|---|---|---|
| 1. MiniMax 直接返回 audioUrl | `audioUrl.length > 0` | `storageProvider='minimax_direct'` / `generatedAudioUrl=audioUrl` | 直接播放 MiniMax URL |
| 2. 有 audioHex + R2 已配置 | `audioHex.length > 0 && r2Bucket` | `storageProvider='r2'` / `storageKey` / `generatedAudioUrl='/api/generated-music?key=...'` | 播放代理 URL |
| 3. 有 audioHex + R2 未配置 | `audioHex.length > 0 && !r2Bucket` | `storageProvider='none'` / `storageWarning='r2_not_configured'` | 提示"音乐已生成并保存，播放地址配置后可试听" |
| 4. R2 上传失败 | `r2Bucket.put()` 抛异常 | `storageProvider='none'` / `storageWarning='r2_upload_failed'` | 提示"音乐已生成并保存，播放地址配置后可试听" |

**关键安全点**：

- 响应**只返回 `audioHexLength`**，不返回完整 `audioHex`（避免巨大响应 + 避免长期暴露）
- 日志只打印 `storageKeyLength`，不打印 `storageKey` 完整值
- 日志只打印 `audioBytesLength`，不打印音频内容
- R2 object 默认私有，不开放公开访问，统一通过 `/api/generated-music` 受控代理读取

#### 6.16.4 是否接入 R2 + R2 bucket/binding 名称

**已接入**（代码层面），但 **bucket 需要手动创建**（Cloudflare Dashboard 或 wrangler CLI）。

| 项目 | 值 |
|---|---|
| R2 binding 名 | `GENERATED_MUSIC_BUCKET` |
| R2 bucket 名 | `xinxian-generated-music` |
| wrangler.toml 配置 | `[[r2_buckets]]` 段已新增 |
| 后端访问方式 | `env.GENERATED_MUSIC_BUCKET.put(key, body, options)` / `env.GENERATED_MUSIC_BUCKET.get(key)` |
| object key 格式 | `generated-music/{yyyyMMdd}/{sessionId}-{traceId}.mp3` |
| content-type | `audio/mpeg` |
| 公开访问 | **未开启**（私有 bucket，统一通过 `/api/generated-music` 代理读取） |

**创建 R2 bucket 命令**（如尚未创建）：

```bash
npx wrangler r2 bucket create xinxian-generated-music
```

或登录 [Cloudflare Dashboard → R2](https://dash.cloudflare.com/) 手动创建。

**如果 R2 bucket 尚未创建**：

- `wrangler.toml` 中的 `[[r2_buckets]]` 配置不会生效，但**不会导致部署失败**
- 后端代码检测 `env.GENERATED_MUSIC_BUCKET` 不存在时返回 `storageWarning='r2_not_configured'`
- 前端提示"音乐已生成并保存，播放地址配置后可试听"
- **不影响其他流程**（MiniMax 调用本身成功，`ok=true`）

#### 6.16.5 前端如何播放生成歌曲

**入口**：`ComfortLyricsScreen` 底部「生成这首歌（实验）」按钮

**流程**：

```
1. 用户点击「生成这首歌（实验）」按钮
   ↓
2. 弹出费用确认对话框（必须用户主动确认，不允许跳过）
   "这会发起一次 AI 音乐生成，可能产生调用费用。
    生成大约需要 30–60 秒，请保持页面打开。"
   [取消] [确认生成]
   ↓
3. 用户点击「确认生成」→ 调用 /api/generate-music
   请求体：{ sessionId, targetState, generationPrompt, lyrics, songPrompt, durationSeconds: 120, manualTest: true }
   ↓
4. 后端响应处理：
   - ok:true + generatedAudioUrl → 初始化 just_audio AudioPlayer，显示播放区
   - ok:true + storageWarning=r2_not_configured → 显示"音乐已生成并保存，播放地址配置后可试听"
   - ok:false → 显示"生成没有完成，请稍后再试"
   ↓
5. 拿到 generatedAudioUrl 后，内嵌播放区显示：
   - 标题行："你的 AI 生成歌曲" + "AI 生成 · {targetState}" 标签
   - 圆形播放/暂停按钮
   - 文案："点击播放，听一下这首属于你的歌"
   ↓
6. 用户点击播放按钮 → just_audio 加载 /api/generated-music?key=... → 播放 mp3 流
```

**关键设计点**：

- **不进入 PlayerScreen**：避免构造完整 `HealingMusicPlan`，使用简洁内嵌播放区
- **manualTest=true 必传**：受后端三重门保护，`realCallsEnabled=false` 时仍返回 fallback
- **播放器懒加载**：仅在拿到 `generatedAudioUrl` 后初始化 `AudioPlayer`
- **资源释放**：`_reset()` 或页面 `dispose()` 时停止播放 + 释放播放器
- **不影响"快速舒缓一下"固定曲库播放链路**：本批只修改 `ComfortLyricsScreen`，不动 `PlayerScreen`

#### 6.16.6 当前是否能播放？卡点是什么？

**代码层面已完整闭环**：MiniMax audioHex → R2 → /api/generated-music → 前端 just_audio 播放。

**线上能否播放取决于**：

| 卡点 | 当前状态 | 解决方式 |
|---|---|---|
| 1. R2 bucket 是否已创建 | ⚠️ **需手动创建** | `npx wrangler r2 bucket create xinxian-generated-music` |
| 2. `MUSIC_GENERATION_REAL_CALLS_ENABLED` 是否为 `true` | ❌ **默认 `false`**（仓库安全默认） | 手动临时改 `true` + 部署 + 测试 + 改回 `false` |
| 3. `MINIMAX_API_KEY` 是否在 Cloudflare Secret 配置 | ✅ 已配置（6.15 已确认 `hasMinimaxKey=true`） | — |
| 4. `manualTest=true` 是否传入 | ✅ 前端调用时自动传入 | — |

**结论**：

- **代码已就绪**：前端 + 后端 + R2 链路全部实现，62 项测试通过
- **线上默认不可播放**：因为 `realCallsEnabled=false`（仓库默认安全）
- **如需真实播放**：需手动临时改 `realCallsEnabled=true` + 创建 R2 bucket + 部署 + 前端点击"生成这首歌（实验）"+ 费用确认
- **测试完成后立即改回 `false`**：避免线上持续可被调用产生费用

#### 6.16.7 新增/修改文件清单

**新增文件**：

- `functions/api/generated-music.js`：从 R2 读取音频流端点（GET `/api/generated-music?key=...`）
  - 校验 storageKey 合法性（必须以 `generated-music/` 开头，禁止 `..` 路径穿越）
  - 流式返回 audio/mpeg binary（不一次性读入内存）
  - 受 CORS 白名单保护，不公开 R2 bucket 名

**修改文件**：

- `functions/api/_music/providers/minimax-music-provider.js`：
  - constructor 新增 `this.r2Bucket = this.env.GENERATED_MUSIC_BUCKET || null`
  - `_callMiniMax` 成功分支新增 R2 上传逻辑（三种情况处理）
  - 新增 `_hexToBytes(hex)` 辅助方法（hex 字符串 → Uint8Array）
  - 新增 `_buildStorageKey(sessionId, traceId)` 辅助方法（生成 R2 object key）
  - 返回字段新增 `storageProvider` / `storageKey` / `generatedAudioUrl` / `storageWarning`

- `wrangler.toml`：
  - 新增 `[[r2_buckets]]` 段：`binding = "GENERATED_MUSIC_BUCKET"` / `bucket_name = "xinxian-generated-music"`
  - 新增 R2 binding 注释说明（创建命令 / 安全注意事项 / 缺失时行为）

- `functions/api/health.js`：
  - `BUILD_LABEL` 同步为 `P4-generated-audio-playback-1`
  - `buildDiagnostics` 新增 `hasR2Bucket` 字段（不泄露 bucket 名，只返回 true/false）

- `lib/config/app_version.dart`：
  - `buildLabel` → `P4-generated-audio-playback-1`
  - 新增 `P{N}-generated-audio-playback-{n}` 约定说明

- `lib/screens/comfort_lyrics_screen.dart`：
  - 顶部新增 `dart:convert` / `http` / `just_audio` import
  - 新增 AI 生成歌曲状态字段（`_generatingMusic` / `_generatedAudioUrl` / `_storageWarning` / `_musicErrorHint` / `_generatedMusicMeta` / `_generatedAudioPlayer` / `_generatedPlayerStateSub` / `_isPlayingGenerated`）
  - `dispose()` 新增播放器资源释放
  - `_reset()` 新增清空 AI 生成歌曲状态 + 停止/释放播放器
  - `_buildGenerateSongButton()` 改为受控实验入口（文案"生成这首歌（实验）" + 调用 `_onGenerateSongPressed`）
  - 新增 `_onGenerateSongPressed()`（点击 → 费用确认对话框 → 调用 API）
  - 新增 `_showGenerateSongConfirmDialog()`（费用确认对话框，必须用户主动确认）
  - 新增 `_callGenerateMusicApi()`（调用 /api/generate-music，处理三种响应情况）
  - 新增 `_initGeneratedAudioPlayer(url, provider)`（初始化 just_audio AudioPlayer）
  - 新增 `_toggleGeneratedAudio()`（切换播放/暂停）
  - 新增 `_mapStyleToTargetState(style)`（曲风 → targetState 映射）
  - 新增 `_encodeGenerateMusicBody(...)`（编码请求体，含 manualTest=true）
  - 新增 `_buildGeneratedSongPlayer()`（内嵌播放区 widget）
  - 新增 `_buildMusicErrorHint()`（错误提示卡片）
  - 新增 `_buildStorageWarningHint()`（存储警告提示卡片）
  - 新增顶层辅助函数 `_jsonEncode(data)` / `_decodeJson(body)`
  - `_buildNextStepHint()` 文案更新（明确告知可点击"生成这首歌（实验）"）

- `scripts/verify-provider-adapter.mjs`：
  - 新增 10 项 P4-generated-audio-playback-1 测试（测试 54-63）
  - 新增 `createMockR2Bucket()` 辅助函数
  - 共 62 项测试全部通过

#### 6.16.8 明确不做（本批不实现）

- ❌ **不做付费模块**（明确是后续阶段）
- ❌ **不做社交 Agent / 小红书 Agent**
- ❌ **不做完整用户系统**
- ❌ **不切换 Mureka / Replicate / 不部署 4090**
- ❌ **不使用「治疗 / 治愈 / 诊断 / 疗法」等医疗化表达**
- ❌ **不把 `audioHex` 原文返回给前端**（避免巨大响应 + 避免长期暴露）
- ❌ **不开放 R2 bucket 公开访问**（统一通过 `/api/generated-music` 受控代理）
- ❌ **不允许跳过费用确认对话框**（防止误触扣费）
- ❌ **不修改"快速舒缓一下"固定曲库播放链路**（不影响 PlayerScreen / 预置音频）
- ❌ **不修改 D1 schema**（本批不涉及数据库变更）
- ❌ **不实现 R2 生命周期策略**（后续可配置 30 天自动清理）
- ❌ **不实现 musicDuration 准确返回**（MiniMax 响应未返回该字段，前端播放器可获取实际时长）

#### 6.16.9 安全保证

- ✅ `MUSIC_GENERATION_REAL_CALLS_ENABLED` 默认保持 `false`（仓库默认安全）
- ✅ `manualTest=true` 保护保留（三重门之一，前端调用时必传）
- ✅ `MINIMAX_API_KEY` 不暴露（前端不持有任何凭证，只在 Cloudflare Secret）
- ✅ 不把 `audioHex` 原文返回前端（只返回 `audioHexLength`）
- ✅ 不在日志打印 `storageKey` 完整值（只打印 `storageKeyLength`）
- ✅ R2 bucket 默认私有（不开放公开访问，统一通过 `/api/generated-music` 代理）
- ✅ `/api/generated-music` 受 CORS 白名单保护（只允许心弦自有域名 + 本地开发）
- ✅ storageKey 路径校验（必须以 `generated-music/` 开头，禁止 `..` 路径穿越）
- ✅ 费用确认对话框（用户必须主动确认才能调用 API，不允许跳过）
- ✅ MiniMax 失败时不导致前端白屏（统一显示"生成没有完成，请稍后再试"）

#### 6.16.10 验证

**Node.js 验证脚本**（62 项测试全部通过）：

```bash
node scripts/verify-provider-adapter.mjs
```

测试覆盖：

- Provider factory 选择逻辑（mock / stable_audio / replicate_musicgen / minimax_music）
- MiniMax 三重门保护（REAL_CALLS / apiKey / manualTest）
- MiniMax 真实调用成功 + R2 上传（mock fetch + mock R2 bucket）
- MiniMax 真实调用成功 + R2 未配置（storageWarning=r2_not_configured）
- MiniMax 真实调用成功 + R2 上传失败（storageWarning=r2_upload_failed）
- MiniMax 真实调用成功 + 直接返回 audioUrl（storageProvider=minimax_direct）
- storageKey 格式正确（`generated-music/{yyyyMMdd}/{sessionId}-{traceId}.mp3`）
- _hexToBytes 正确转换 hex 为 bytes
- _buildStorageKey 边界处理（traceId 为空时仍生成合法 key）
- 响应不包含完整 audioHex（避免长期暴露）
- health buildDiagnostics 返回 hasR2Bucket 字段（不泄露 bucket 名）
- buildLabel 已更新为 P4-generated-audio-playback-1

**Flutter 验证**：

```bash
flutter analyze      # 静态分析
flutter test         # 单元测试 + widget 测试
flutter build web --release   # Web 构建产物
```

#### 6.16.11 真实调用 + 在线播放验证（待用户手动执行）

**前置条件**：

1. R2 bucket 已创建：`npx wrangler r2 bucket create xinxian-generated-music`
2. `wrangler.toml` `MUSIC_GENERATION_REAL_CALLS_ENABLED` 临时改为 `"true"`
3. `wrangler pages deploy build/web --project-name=xinxian-healing-music`
4. `/api/health` 确认 `realCallsEnabled=true` / `hasMinimaxKey=true` / `hasR2Bucket=true`

**真实调用 + 播放流程**：

1. 访问 [https://xinxian-music.xyz](https://xinxian-music.xyz)
2. 进入「把困惑写成一首歌」页面
3. 输入困惑 + 选择曲风 + 点击「生成解惑与歌词草稿」
4. （可选）编辑歌词 + 保存
5. 点击「生成这首歌（实验）」按钮
6. 在费用确认对话框中点击「确认生成」
7. 等待 30–60 秒（前端显示 loading）
8. 拿到 `generatedAudioUrl` 后显示播放区
9. 点击播放按钮 → 听到 AI 生成歌曲

**测试后恢复**：

1. `wrangler.toml` `MUSIC_GENERATION_REAL_CALLS_ENABLED` 改回 `"false"`
2. `wrangler pages deploy build/web --project-name=xinxian-healing-music`
3. `/api/health` 确认 `realCallsEnabled=false` / `hasMinimaxKey=true` / `hasR2Bucket=true` / `buildLabel=P4-generated-audio-playback-1`

---

### 6.17 P4 临时音频播放闭环（P4-temp-audio-playback-1）

**版本**：`v1.0.0 / P4-temp-audio-playback-1`（构建日期 2026-07-23）

#### 6.17.1 目标

在 6.16（R2 落地方案）基础上，**先跑通产品核心链路**，不依赖 R2：

> 用户输入困惑 → 生成解惑 → 生成歌词 → MiniMax 生成歌曲 → 页面直接播放

上一批已证明 MiniMax Music-2.0 真实调用成功（`provider=minimax_music` / `status=succeeded` / `audioHexLength=1022098` / `audioUrl=null`）。本批解决"audioHex 如何变成前端可播放音频"的问题，**暂不做 R2 持久化**。

#### 6.17.2 关键约束

- **暂不依赖 Cloudflare R2**：不要求创建 `xinxian-generated-music` bucket，不要求绑定 `GENERATED_MUSIC_BUCKET`
- R2 逻辑保留（作为后续持久化方案），但 **R2 缺失不能导致播放失败**
- `MUSIC_GENERATION_REAL_CALLS_ENABLED` 默认仍为 `"false"`
- `manualTest=true` 三重门保护不移除
- 前端不暴露 `MINIMAX_API_KEY`
- 不做付费模块 / 用户系统 / 4090 部署 / 社交 Agent
- 不使用"治疗 / 治愈 / 诊断 / 疗法"等医疗化表达
- 不把完整 `audioHex` 原文返回前端，不把完整 `audioDataUrl` 打印进日志

#### 6.17.3 audioHex → 前端可播放音频的转换方案

MiniMax 同步接口返回 audio hex（非 URL），后端转换为可播放资源的三种优先级：

| 优先级 | 触发条件 | 返回字段 | 说明 |
|---|---|---|---|
| 1 | MiniMax 直接返回 `audio_url` | `generatedAudioUrl=audioUrl` | 无需转换，直接用 MiniMax CDN URL |
| 2 | 有 audioHex + R2 已配置且上传成功 | `generatedAudioUrl=/api/generated-music?key=...` | R2 持久化路径，不返回 audioDataUrl（节省响应体） |
| 3 | 有 audioHex + R2 未配置 / 上传失败 | `audioDataUrl=data:audio/mpeg;base64,...` | **本批核心方案**：base64 dataUrl 临时播放 |

**本批核心改动**：优先级 3 新增 `audioDataUrl` 字段。当 R2 不可用时，后端将 audioHex 转 base64 dataUrl 直接返回前端，前端用 just_audio 的 `AudioSource.uri` 加载 `data:` URL 播放，**不依赖 R2**。

#### 6.17.4 后端改动（minimax-music-provider.js）

1. 新增 `_bytesToBase64(bytes)` 辅助方法：
   - 将 `Uint8Array` 转 base64 字符串（分块处理，每 32KB，避免 `String.fromCharCode.apply` 栈溢出）
   - 使用 Web 标准 `btoa` API（Cloudflare Workers / 浏览器 / Node 16+ 均支持）
2. 修改 `_callMiniMax` 成功分支的存储逻辑：
   - 情况 1（MiniMax 直接返回 audioUrl）：保持现状，`generatedAudioUrl=audioUrl`
   - 情况 2（有 audioHex + R2 已配置）：上传 R2 → `generatedAudioUrl`；上传失败 → 回退 `audioDataUrl` + `storageWarning=r2_upload_failed`
   - 情况 3（有 audioHex + R2 未配置）：生成 `audioDataUrl`（**不再返回 `storageWarning=r2_not_configured`**，本批不视为错误）
3. 返回字段新增：`audioDataUrl` / `audioBase64Length` / `contentType`
4. R2 上传成功时不返回 `audioDataUrl`（节省响应体，只用 `generatedAudioUrl`）

#### 6.17.5 前端改动（comfort_lyrics_screen.dart）

1. `_callGenerateMusicApi` 响应处理新增 `audioDataUrl` 字段：
   - 优先用 `generatedAudioUrl`（R2 路径或 MiniMax 直返 URL）
   - 回退到 `audioDataUrl`（base64 dataUrl 临时播放）
   - 都没有 → 显示"音乐已经生成，但暂时无法播放，请稍后再试"
2. `_initGeneratedAudioPlayer` 支持 `data:` URL：
   - `data:` / `http://` / `https://` 开头 → 直接 `Uri.parse`
   - 相对路径（如 `/api/generated-music?key=...`）→ `Uri.base.resolve`
   - just_audio Web 端底层为 HTML5 audio 元素，原生支持 `data:` URL

#### 6.17.6 已完成 / 未完成

**已完成**：
- ✅ 后端 `_bytesToBase64` + 存储逻辑调整（R2 未配置/失败时回退 audioDataUrl）
- ✅ 前端 `audioDataUrl` 播放支持 + `data:` URL 兼容
- ✅ 版本号同步（`app_version.dart` + `health.js` → `P4-temp-audio-playback-1`）
- ✅ 验证脚本更新（64 项测试全部通过）
- ✅ `flutter analyze` / `flutter test`（273 passed）/ `flutter build web --release` 通过

**未完成（后续批次）**：
- ⏳ R2 持久化（历史歌曲、分享链接、跨会话回放）
- ⏳ 付费模块 / 用户系统
- ⏳ 4090 自托管音乐生成 worker
- ⏳ 小红书 / 社交 Agent

#### 6.17.7 安全

- 不打印 API Key 值，只打印 `apiKeyConfigured: true/false`
- 不打印完整 `audioHex` / `audioDataUrl` / `storageKey` 完整值（只打印长度）
- 不泄露 MiniMax 原始错误细节（`status_msg` / `errText`），统一映射为内部 `errorCode` + 安全 `errorMessage`
- 响应不包含完整 `audioHex` 原文（只返回 `audioHexLength` + `audioDataUrl` base64 编码形式）
- `manualTest=true` 保护不移除，前端请求体仍携带 `manualTest=true`
- `MUSIC_GENERATION_REAL_CALLS_ENABLED` 默认保持 `"false"`，真实测试时手动临时改 `true`

#### 6.17.8 文件清单

| 文件 | 改动 |
|---|---|
| `functions/api/_music/providers/minimax-music-provider.js` | 新增 `_bytesToBase64` + 修改存储逻辑（R2 未配置/失败时回退 audioDataUrl）+ 返回字段新增 `audioDataUrl` / `audioBase64Length` / `contentType` |
| `lib/screens/comfort_lyrics_screen.dart` | `_callGenerateMusicApi` 支持 `audioDataUrl` + `_initGeneratedAudioPlayer` 支持 `data:` URL |
| `lib/config/app_version.dart` | `buildLabel` → `P4-temp-audio-playback-1`，`buildDate` → `2026-07-23` |
| `functions/api/health.js` | `BUILD_LABEL` → `P4-temp-audio-playback-1` |
| `scripts/verify-provider-adapter.mjs` | 修改测试 55/56 + 新增 audioDataUrl 相关测试（64 项全部通过） |
| `README.md` | 新增 6.17 章节 + 顶部版本号 + 13.5 变更记录 |

#### 6.17.9 验证

```bash
node scripts/verify-provider-adapter.mjs   # 64 passed, 0 failed
flutter analyze                             # exit code 0
flutter test                                # 273 passed, 5 skipped, 0 failed
flutter build web --release                 # exit code 0
```

#### 6.17.10 线上试听前置条件

本批**不需要**创建 R2 bucket，但线上试听仍需手动开启真实调用：

1. `wrangler.toml` 临时将 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 改为 `"true"`
2. 确认 Cloudflare Production Secret 中已配置 `MINIMAX_API_KEY`
3. `flutter build web --release`
4. `wrangler pages deploy build/web --project-name=xinxian-healing-music`
5. 前端「把困惑写成一首歌」→ 生成歌词 → 点击「生成这首歌（实验）」→ 确认费用 → 等待 30-60 秒 → 页面内嵌播放
6. 测试完成后立即将 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 改回 `"false"` 并重新部署
7. `/api/health` 确认 `realCallsEnabled=false` / `hasMinimaxKey=true` / `buildLabel=P4-temp-audio-playback-1`

#### 6.17.11 线上真实试听结果（2026-07-23）

**结论：线上真实试听成功，前端可播放 AI 生成歌曲。**

执行流程：
1. 临时将 `wrangler.toml` `MUSIC_GENERATION_REAL_CALLS_ENABLED` 改为 `"true"`
2. 临时注释掉 `wrangler.toml` 中 `[[r2_buckets]]` R2 binding（因 `xinxian-generated-music` bucket 不存在会导致部署失败）
3. `flutter build web --release` + `wrangler pages deploy` 部署到线上
4. `/api/health` 确认 `realCallsEnabled=true` / `hasMinimaxKey=true` / `hasR2Bucket=false` / `buildLabel=P4-temp-audio-playback-1`
5. 用户在 https://xinxian-music.xyz 手动测试：
   - 点击「把困惑写成一首歌」
   - 输入困惑 → 生成解惑与歌词草稿
   - 点击「生成这首歌（实验）」→ 确认费用弹窗 → 等待生成
   - **页面出现播放器，点击播放可听到 AI 生成歌曲** ✅
6. 测试完成后立即将 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 改回 `"false"` 并重新部署
7. `/api/health` 确认 `realCallsEnabled=false` / `hasMinimaxKey=true` / `buildLabel=P4-temp-audio-playback-1`

**验证要点**：
- ✅ 成功调用 MiniMax Music-2.0 API
- ✅ 使用 `audioDataUrl`（base64 dataUrl）临时播放，**不依赖 R2**
- ✅ 前端能播放 AI 生成歌曲
- ✅ `realCallsEnabled` 测试后已恢复 `false`
- ✅ 不影响"快速舒缓一下"固定曲库播放流程

**产品核心链路已跑通**：
> 用户输入困惑 → 生成解惑 → 生成歌词 → MiniMax 生成歌曲 → 页面直接播放

#### 6.17.12 代码审计与清理（P4-temp-audio-playback-1-cleanup）

线上试听验证通过后，对本批代码进行审计清理：

**审计结论**（全部通过）：
- ✅ R2 完全可选：R2 未配置/失败时走 `audioDataUrl` 兜底，不影响播放；`wrangler.toml` R2 binding 已注释（bucket 不存在时不阻断部署）
- ✅ 不返回完整 `audioHex` 给前端（只返回 `audioHexLength` + `audioDataUrl` base64 编码形式）
- ✅ 不在日志打印完整 `audioHex` / `audioDataUrl` / `storageKey`（只打印长度）
- ✅ 只保留必要诊断字段：`audioHexLength` / `audioBase64Length` / `contentType` / `traceId` / `provider` / `status`
- ✅ MiniMax 失败时返回 fallback，不白屏
- ✅ `manualTest=true` 安全保护保留
- ✅ `realCallsEnabled=false` 默认安全
- ✅ 不暴露 `MINIMAX_API_KEY`
- ✅ 文案合规（无"治疗/治愈/诊断/疗法/算命/神谕/命中注定"等违规表达）
- ✅ 无重复状态字段 / 无废弃方法 / 无未使用 import

**清理内容**：
- 更新 `comfort_lyrics_screen.dart` 顶部文档注释（反映 P4-temp-audio-playback-1 当前状态，移除"本批不接真实音乐生成"等过时描述）
- 更新 `_buildStorageWarningHint` 注释和文案（R2 未配置不再触发此卡片，文案改为"音乐已生成，但暂时无法播放，请稍后再试"）
- 版本号更新为 `P4-temp-audio-playback-1-cleanup`

**未清理（保留）**：
- R2 相关代码（`_hexToBytes` / `_buildStorageKey` / R2 上传逻辑）：作为后续 P5 持久化方案的基础，保留但可选
- `functions/api/generated-music.js`：R2 音频流代理端点，保留但仅在 R2 配置时可用
- `manualTest` 三重门保护：安全核心，不移除

#### 6.17.13 生成歌曲结果页体验优化（P4-song-result-experience-1）

P4-temp-audio-playback-1-cleanup 线上验证通过后，对本批「生成歌曲之后」的前端体验进行优化，让它更像一首完整的、属于用户自己的歌。

**本批范围（纯前端，不改后端真实调用策略）**：
- 不修改 `wrangler.toml` 中 `realCallsEnabled` 默认值，**仍保持 `false`**
- 不移除 `manualTest=true` 保护
- 不增加任何自动调用 MiniMax 的逻辑、不做后台轮询 / 自动重试
- 不做 R2 / 历史歌曲 / 分享链接 / 付费 / 用户系统 / 4090 部署

**生成成功结果区**（`comfort_lyrics_screen.dart` `_buildSongResultSection`）：
当 AI 歌曲生成成功并可播放后，展示一个更完整的结果区：
- 歌曲标题：**本地规则生成**（不新增 LLM 调用），根据 `targetState` 映射：
  - `sleep` → `今晚先慢下来`
  - `soothe` → `把心放轻一点`
  - `focus` → `慢慢回到这里`
  - `regulate` → `让心绪落下来`
  - `unknown/default` → `写给现在的你`
  - 后续可让 LLM 返回 `title` 字段替换此规则
- 副文案：`根据你刚才写下的内容生成，适合现在慢慢听一遍。`
- 播放区标题：`试听这首歌`（圆形播放/暂停按钮 + 状态文案）
- 歌词区标题：`歌词`（展示当前歌词，可选中复制）
- 状态文案：`已生成，可直接试听`
- 操作按钮：
  - `重新播放`：从头播放当前生成歌曲，**不再次调用 MiniMax，不扣费**
  - `编辑歌词`：回到歌词编辑状态，**不丢失当前歌词**
  - `重新生成`：**必须再次弹出费用确认**，因为会真实调用 MiniMax（可能产生费用）

**生成失败体验**（`_buildMusicErrorSection`）：
如果 MiniMax 调用失败或没有返回可播放音频：
- 不白屏，展示温和错误提示，保留歌词
- 错误标题：`这次音乐没有顺利生成`
- 副文案：`你可以稍后再试，或者先调整一下歌词。`
- 操作按钮：`重试生成`（需费用确认）/ `编辑歌词`

**页面结构**：保持当前主流程不变（输入困惑 → 生成解惑与歌词 → 编辑歌词 → 生成歌曲 → 播放歌曲），不改「快速舒缓一下」固定曲库流程。

**文案合规**：使用「音乐陪伴 / 情绪支持 / 放松 / 自我理解 / 温和开导 / 睡前舒缓」等表达，不使用「治疗 / 治愈 / 诊断 / 疗法 / 算命 / 神谕 / 命中注定」。

**修改文件**：
- `lib/screens/comfort_lyrics_screen.dart`（修改）：新增 `_generateSongTitle` / `_replayGeneratedSong` / `_returnToEditLyrics` / `_onRegenerateSongPressed`；用 `_buildSongResultSection`（含 `_buildPlayControl` / `_buildSongActionButtons`）替代原 `_buildGeneratedSongPlayer`；用 `_buildMusicErrorSection` 替代原 `_buildMusicErrorHint`；`_buildResult` 渲染逻辑改为「成功结果区 / 失败区 / 存储警告 / 入口按钮」if-else 链
- `lib/config/app_version.dart`（修改）：`buildLabel` → `P4-song-result-experience-1`，新增 `P{N}-song-result-experience-{n}` 约定说明
- `functions/api/health.js`（修改）：`BUILD_LABEL` → `P4-song-result-experience-1`
- `scripts/verify-provider-adapter.mjs`（修改）：测试 63 `buildLabel` 断言更新为 `P4-song-result-experience-1`
- `README.md`（修改）：新增本章节 + 顶部版本号 + 13.5 变更记录

**本批没有做**（作为后续事项，未实现）：
- R2 持久化存储 / 历史生成歌曲记录 / 分享链接
- 付费模块 / 用户系统 / 额度
- 4090 服务器部署
- LLM 返回 `title` 字段（本批用本地规则生成标题）
- `realCallsEnabled` 默认仍为 `false`，前端正式入口不会自动扣费

**部署验证（2026-07-23 已上线）**：
- `flutter build web --release` + `wrangler pages deploy build/web --project-name=xinxian-healing-music` 部署成功（45 文件 + Functions bundle）
- `/api/health` 验证：`buildLabel=P4-song-result-experience-1` / `realCallsEnabled=false` / `hasMinimaxKey=true` / `musicProvider=minimax_music` / `hasR2Bucket=false`
- 前端产物校验：线上 `main.dart.js` 包含 `P4-song-result-experience-1`、不含旧 `P4-temp-audio-playback-1-cleanup`，确认前端为最新构建（非缓存旧版）
- 浏览器验收：首页正常加载（不白屏）、「把困惑写成一首歌」入口卡片可见、控制台无报错
- **本次未进行真实 MiniMax 调用**：`realCallsEnabled` 全程保持 `false`，未临时打开真实调用开关，未触发任何真实生成
- 版本号说明：首页底部版本号文本为编译期常量插值（`心弦 v1.0.0 · P4-song-result-experience-1 · Cloudflare Pages`），已由 `main.dart.js` bundle 字符串校验确证；因 Flutter CanvasKit 画布内部滚动不响应浏览器原生滚动，截图未能直接捕捉底部小字

#### 6.17.14 后续计划（未实现，仅规划）

以下功能**尚未实现**，仅作为后续路线规划：

**P5：持久化存储**
- 可选 R2 或未来 4090 服务器存储
- 保存生成歌曲
- 历史生成记录
- 分享链接

**P6：用户与额度**
- 免费次数
- 生成次数限制
- 成本统计
- 失败不扣次数

**P7：4090 后端迁移准备**
- 抽象 provider
- 设计独立后端服务
- 设计音频存储服务

---

### 6.18 P6-quota-guard-1：本地额度保护 + 文档整理（2026-07-23）

#### 6.18.1 背景

P4-song-result-experience-1 已部署上线并验收通过（`buildLabel=P4-song-result-experience-1` / `realCallsEnabled=false` / MiniMax provider 已打通 / audioDataUrl 临时播放已验证 / 生成歌曲结果页体验已优化）。本批在不开真实调用、不做 R2 / 用户系统 / 付费 / 4090 的前提下，补上「成本失控」的最后一道本地闸门，并整理文档。

#### 6.18.2 额度保护规则

- **范围**：仅约束「把困惑写成一首歌」里的「生成这首歌（实验）」+「重新生成」；**不影响**「快速舒缓一下」固定曲库。
- **每日上限**：默认每天最多 1 次成功生成（`LocalGenerationQuotaService.dailyLimit = 1`）。
- **本地记录**：`SharedPreferences`（Web 端 localStorage fallback）单 key JSON `{"date":"yyyy-MM-dd","count":N}`，损坏回退 `{今天,0}`。
- **计数规则**（只有以下情况计数）：
  - ✅ 计数：`/api/generate-music` 返回成功且拿到可播放音频（`generatedAudioUrl` 或 `audioDataUrl`）→ `recordSuccessfulGeneration()`
  - ❌ 不计数：失败 / 取消费用确认 / 重新播放 / 返回编辑歌词 / 重新生成失败
- **跨天重置**：按本地日期 `yyyy-MM-dd`，新一天自动清零。
- **防重复点击**：生成请求进行中 `_generatingMusic=true` 禁用按钮；费用确认后立即进入 loading；不做自动重试。

#### 6.18.3 UI 提示

- 未使用：`今日还可生成 1 首`
- 已用完：`今日体验次数已用完` + 副提示「今天的 AI 生成体验次数已用完，可以先继续编辑歌词，明天再生成。」
- 已用完时：「生成这首歌（实验）」按钮 + 结果区「重新生成」按钮均禁用（onPressed=null）；「重新播放」「编辑歌词」不受影响。
- 服务未装配（存储全不可用）时：`_quotaRemaining=null`，跳过额度限制（permissive 降级），因 realCallsEnabled=false + mock 模式下成本风险近零。

#### 6.18.4 成本安全

- `wrangler.toml` 中 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 保持 `"false"`。
- 不打开真实调用，不移除 `manualTest=true` 保护，不新增任何自动调用 MiniMax 的逻辑，不做后台轮询，不做付费，不做用户系统，不做 R2，不做 4090 部署。

> **本地额度的定位（重要）**：P6 的浏览器本地额度只是**早期内测 / 误点保护**，**不是商业级防刷**——用户清除站点数据、更换浏览器、更换设备后即可绕过重置，不适合作为正式付费系统的唯一额度依据。后续商业化需要：云端用户系统 + 服务端额度校验 + 订单 / 支付记录 + 失败不扣次数 + 风控与异常请求限制。在云端额度核销上线前，真正的成本控制仍依赖 `MUSIC_GENERATION_REAL_CALLS_ENABLED=false` 这道后端总开关。

#### 6.18.5 新增 / 修改文件清单

新增：
- `lib/pipeline/local/local_generation_quota_service.dart`（额度 service）
- `test/local_generation_quota_service_test.dart`（service 单元测试）
- `docs/ROADMAP.md`（分阶段路线图）

修改：
- `lib/pipeline/services.dart`（注册 `generationQuotaService` 全局变量）
- `lib/main.dart`（`bootstrapServices` 第 9 步装配 + 自检汇总）
- `lib/screens/comfort_lyrics_screen.dart`（额度字段 / initState / `_refreshQuotaState` / 两个 guard / `_buildGenerateSongButton` / `_buildQuotaHint` / 成功分支计数 / `_buildSongActionButtons` 重新生成禁用）
- `lib/config/app_version.dart` / `functions/api/health.js` / `scripts/verify-provider-adapter.mjs`（版本号同步 + 测试断言）
- `test/comfort_lyrics_screen_test.dart`（文件头注释补 P6 说明 + 额度 UI widget 测试 3 项：可用时「今日还可生成 1 首」+ 按钮可用 / 用完时「今日体验次数已用完」+ 按钮禁用 / 未装配 permissive 降级）
- `README.md`（定向更新 + 本章节）
- `docs/mureka-api-integration-plan.md`（历史标注）

#### 6.18.6 已完成 / 未完成对照

**已完成（本批 + 累计）**：
- 固定曲库舒缓链路（「快速舒缓一下」）
- 反馈链路（本地 + D1 匿名云端）
- PWA / 缓存策略
- 困惑解惑与歌词生成（LLM）
- MiniMax 真实调用打通（默认 REAL_CALLS=false）
- audioDataUrl 临时播放闭环（已线上真实试听）
- 生成歌曲结果页体验
- **P6 本地额度保护（本批）**

**未完成（后续）**：
- R2 持久化（生成音频长期存储）
- 历史生成歌曲（回看 / 重听）
- 分享链接
- 用户系统（账号 / 跨设备同步）
- 支付 / 会员 / 额度购买
- 4090 后端迁移
- 本地 4090 音乐模型替换 MiniMax
- 小红书 / 社交增长 Agent

> 6.17.14 中 P5/P6/P7 的规划：P6「生成次数限制 / 失败不扣次数」已由本批落地（额度保护），其余（持久化 / 用户 / 4090）顺延至中期 / 长期，详见 [docs/ROADMAP.md](docs/ROADMAP.md)。

#### 6.18.7 本批明确不做

不部署上线 / 不打开真实调用 / 不移除 manualTest / 不新增自动调用 / 不做轮询 / 不做重试 / 不引入新依赖 / 不做 R2 / 不做付费 / 不做用户系统 / 不做 4090 / 不使用医疗化表达。

#### 6.18.8 验证

`flutter analyze` / `flutter test`（含新 service 单元测试）/ `flutter build web --release` / `node scripts/verify-provider-adapter.mjs`（含 `buildLabel=P6-quota-guard-1` 断言）。本批不部署上线。

---

### 6.19 P4-conversation-song-flow-1：多轮困惑理解 + 歌词增强 + 纯音乐本地舒缓 + 定时关闭（2026-07-23）

#### 6.19.1 定位

优化核心产品体验：不要只让用户输入一次，而是通过多轮温和对话更详细理解用户心情和处境，再生成更贴合困境的歌词。AI 歌曲生成后，用户可以选择是否进入「快速舒缓一下」的本地纯音乐播放。纯音乐以后不走 AI 音乐生成，只调用本地已有音乐。播放页新增定时关闭。

#### 6.19.2 多轮困惑理解

「把困惑写成一首歌」流程改为多轮理解：

- **input 阶段**：用户输入困惑 + 选择期望曲风 → 点击「开始理解」（原「生成解惑与歌词草稿」）
- **followUp 阶段**：2-3 轮温和追问（不立即调用 LLM）
  - Q1：`这件事里，最让你放不下的是哪一部分？`（开放式）
  - Q2：`如果这首歌只陪你说一句话，你希望它更像安慰、释怀，还是给你一点力量？`（带快速选项）
  - Q3：`你现在更想被理解，还是更想慢慢平静下来？`（带快速选项）
  - 每轮问题短、自然、低压力，不像心理测评问卷，不医疗化，不诊断
  - 用户可随时「跳过追问，直接生成」
- **done 阶段**：收集完多轮上下文后调用 LLM 生成

多轮数据结构（只存页面 state，不做长期保存）：

- `initialConcern`：原始困惑
- `followUpAnswers`：Q1 追问回答列表
- `desiredFeeling`：Q2 期望感觉（安慰/释怀/力量）
- `comfortDirection`：Q3 陪伴方向（被理解/平静下来）

**本批不做长期保存**：多轮数据只存在 ComfortLyricsScreen 的 state 中，页面销毁即丢失，不写入本地存储/云端。

#### 6.19.3 「给现在的你」部分

保持原结构，使用多轮对话上下文，但不大改。保持温和、具体、克制，不改成鸡汤或说教，不使用「治疗 / 治愈 / 诊断 / 疗法」等表达。

#### 6.19.4 「写成歌的话」歌词增强

歌词基于多轮上下文增强，更贴合用户困境：

- 歌词必须吸收用户多轮回答中的具体细节
- 不泛泛写「别难过，会过去」
- 把用户提到的具体场景/物件/关系转化为歌词意象（如「没发出去的消息」「没关的屏幕」）
- 隐私保护：不过度复述敏感细节，用意象化处理代替直白复述
- 歌词结构建议：
  - 第一段（主歌）：承接用户具体困境，用具象画面开场
  - 第二段（主歌或桥段）：温和转念，不否定痛苦
  - 副歌：给一句能记住的陪伴话（hook），可重复 1-2 句
  - 结尾（尾声）：回到平静或继续生活，不强行升华
- 歌词仍允许用户编辑和保存，后续 MiniMax 生成歌曲时使用编辑后的歌词

实现：`ComfortLyricsService.generate()` 新增 `followUpAnswers` / `desiredFeeling` / `comfortDirection` 参数；`functions/api/comfort-lyrics.js` 的 `validateInput` 新增多轮字段校验，`callLlm` 融入多轮上下文到 userContent，`SYSTEM_PROMPT` 增补歌词结构与意象化要求。

#### 6.19.5 纯音乐「快速舒缓一下」调整

- **纯音乐以后不走 AI 音乐生成**：「快速舒缓一下」只调用本地已有音乐 assets（`AudioAssetCatalog`），不走 `/api/generate-music`，不调用 MiniMax，不产生音乐生成费用
- **删除纯音乐 AI 生成入口**：`plan_screen.dart` 的「生成专属音乐（实验）」按钮已删除，`music_generation_screen.dart` 及其测试文件已删除
- **不删除 provider adapter**：「把困惑写成一首歌」的 MiniMax 歌曲生成功能保留，provider adapter 仍需要
- **AI 生成只用于「把困惑写成一首歌」**，「快速舒缓一下」使用本地纯音乐库
- **可扩展**：后续增加本地纯音乐只需在 `AudioAssetCatalog.assets` 列表添加新条目

#### 6.19.6 AI 歌曲后引导纯音乐

用户听完 AI 生成歌曲后，结果区末尾展示温和 CTA：

- 文案：`还想再安静一会儿吗？`
- 说明：`可以听一段不带歌词的纯音乐，让情绪慢慢落下来。`
- 按钮：`快速舒缓一下`
- 点击后跳转 `AnalysisScreen`，带默认心境文本（根据 `desiredFeeling` / `comfortDirection` 拼接），走现有「快速舒缓一下」本地纯音乐流程
- 不触发 MiniMax，不扣额度（额度只约束 AI 歌曲生成）

#### 6.19.7 播放页定时关闭

新增 `SleepTimerButton` 共享组件（`lib/widgets/sleep_timer_button.dart`），接入 `PlayerScreen` 和 ComfortLyricsScreen 的 AI 生成歌曲播放区：

- 定时选项：关闭、5 分钟、10 分钟、15 分钟、30 分钟、播放完当前音频
- 到时间后自动暂停播放
- UI 轻量（PopupMenuButton + 小图标），不挤压播放按钮
- 定时状态显示：`定时关闭：10 分钟` / `本曲结束后关闭` / `定时关闭`
- 用户可随时取消定时关闭（选「关闭」）
- 定时只控制播放，不影响生成；不新增后台任务；页面销毁时清理 timer

#### 6.19.8 额度与成本安全

- 保留 P6-quota-guard-1 的本地额度保护（`LocalGenerationQuotaService`）
- 额度只限制 AI 歌曲生成，不限制本地纯音乐
- 重新播放 AI 歌曲不计数
- 快速舒缓本地音乐不计数
- `wrangler.toml` 中 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 保持 `"false"`
- 不打开真实调用，不部署真实试听，不移除 `manualTest=true` 保护

#### 6.19.9 本批不做

- R2 持久化存储
- 历史歌曲列表
- 分享链接
- 付费系统
- 用户系统
- 4090 部署
- 真实 MiniMax 测试

#### 6.19.10 验证与部署

**本地验证**：`flutter analyze`（No issues found）/ `flutter test`（288 passed, 5 skipped，含 4 个多轮对话测试）/ `flutter build web --release`（Built build\web）/ `node scripts/verify-provider-adapter.mjs`（64 passed, 0 failed）。

**范围核对发现并修复**：部署前核对发现 `wrangler.toml` 中 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 前批线上试听测试遗留为 `"true"`（注释称已恢复 false 但实际未恢复），已改回 `"false"`，仓库默认安全。

**线上部署**（2026-07-23）：`wrangler pages deploy build/web --project-name=xinxian-healing-music` 部署成功。

**部署后 health 验证**（`GET https://xinxian-music.xyz/api/health`）：
- `buildLabel` = `P4-conversation-song-flow-1` ✅
- `realCallsEnabled` = `false` ✅
- `hasMinimaxKey` = `true` ✅
- `musicProvider` = `minimax_music` ✅

realCallsEnabled 保持 false / manualTest 保护保留 / P6 额度保护保留 / 本次未触发真实 MiniMax 调用。

### 6.20 P4-conversation-song-flow-1-fix1：LLM 动态追问 + 歌词贴合度增强 + 加载文案分阶段（2026-07-23）

#### 6.20.1 定位

P4-conversation-song-flow-1 上线后发现三类体验问题：多轮追问像固定问卷（不随用户输入变化）、歌词贴合度不够（泛泛写窗台/手机/夜色而非承接用户核心感受）、加载页文案不分阶段（一直显示「AI 正在理解你的状态」）。本批在不部署、不真实调用 MiniMax 的前提下修复这三点，并核查「快速舒缓一下」彻底纯本地化。

#### 6.20.2 生成链路确认

- 「给现在的你」由 LLM 生成（`/api/comfort-lyrics` → `comfortInterpretation`）
- 「写成歌的话」歌词由 LLM 生成（`/api/comfort-lyrics` → `lyricDraft`）
- AI 歌曲音频由 MiniMax 生成（`/api/generate-music`，受三重门保护，默认 REAL_CALLS=false）
- 「快速舒缓一下」只使用本地 assets 音乐（`AudioAssetCatalog`），不调用 `/api/generate-music`，不调用 MiniMax，不扣 P6 额度

#### 6.20.3 LLM 动态追问

扩展 `/api/comfort-lyrics`，新增 `mode` 参数：

- `mode = "follow_up_questions"`：只生成 2-3 个追问，不生成歌词
- `mode = "comfort_song"` 或默认：生成 `comfortInterpretation` + `lyricDraft` + `songPrompt`

追问输入：`initialConcern` / `targetStyle` / `language`。追问输出：`questions: string[]`。

追问要求（写入 `FOLLOW_UP_PROMPT`）：

- 必须基于用户具体文字生成，不能套模板
- 用户说的是低能量/疲惫/空（状态），不问「这件事里」（事件导向）
- 问题短、自然、低压力，允许跳过，不像心理测评，不医疗化
- 数量 2-3 个，每个不超过 25 字

示例：输入「最近总是提不起劲，感觉很疲惫、很空」→ 合理追问：`这种疲惫和空落感，通常在什么时候最明显？` / `你更像是身体累，还是心里没有力气？` / `如果这首歌陪你一会儿，你希望它让你慢慢休息，还是给你一点点重新开始的力气？`

#### 6.20.4 本地兜底追问（6 分类）

LLM 追问失败时，使用本地关键词分类兜底（前后端镜像实现）：

| 分类 | 触发关键词 | 兜底问题特征 |
|---|---|---|
| `lowEnergy`（优先级最高） | 提不起劲、疲惫、累、空、麻木、没动力、不想动 | 围绕疲惫/空落/身体累/心里没力气，**不含「这件事」** |
| `eventConflict` | 争吵、分手、被批评、失败、考试、工作事件、人际冲突 | 允许事件导向措辞（「最让你难受」） |
| `anxietyStress` | 焦虑、紧张、压力、心慌、担心、睡不着 | 围绕最担心的事 |
| `guiltRegret` | 后悔、愧疚、责备自己、做错事 | 围绕放不下 |
| `loneliness` | 孤独、没人理解、空落、想有人陪 | 围绕想被陪伴 |
| `unknown` | 无匹配 | 通用低压力问题 |

`lowEnergy` 优先级最高：只要命中低能量关键词，即使同时含其他类别词，也归 `lowEnergy`，避免对「提不起劲」误问「这件事里」。

#### 6.20.5 歌词贴合度增强

修改 `SYSTEM_PROMPT`，明确：

- 主歌必须承接用户在 `storyText` / 追问回答中提到的具体困境（人物/场景/物件/关系），意象化处理
- **不编造用户没说过的具体场景**（窗台/手机/枕头边），意象必须服务于用户困境
- 让用户第一段就感觉「这是在写我」
- 副歌给一句容易记住的陪伴话，不过度鸡汤
- 针对「提不起劲/疲惫/空」：围绕提不起劲、很累、空空的、什么都不想做、慢一点也可以、今天先不用变好；不强行写窗台/手机/枕头边

`callLlm` 调用时透传 `initialConcern` + `followUpAnswers`，确保 LLM 能吸收多轮上下文。

#### 6.20.6 「给现在的你」不大改

保持当前结构，使用多轮上下文轻微增强，不变成鸡汤，不说教，不医疗化。

#### 6.20.7 快速舒缓纯本地化核查

全局核查确认：

- 「快速舒缓一下」不调用 `/api/generate-music`、不调用 MiniMax、不扣 P6 额度
- 不存在「生成专属音乐（实验）」入口/文案
- 不存在 `MusicGenerationScreen` 路由/入口/残留 import
- 不保留纯音乐 AI 生成相关页面或测试
- 只使用本地 assets 音乐（`AudioAssetCatalog`）
- 后续新增纯音乐只扩展本地曲库配置，不走 AI 生成
- 「把困惑写成一首歌」的 MiniMax 歌曲生成能力保留，provider adapter 保留

#### 6.20.8 加载页文案分阶段

不同阶段显示不同文案，不再统一显示「AI 正在理解你的状态」：

| 阶段 | 文案 |
|---|---|
| 生成追问（loadingFollowUp） | `正在根据你的文字整理几个更贴近的问题…` |
| 生成「给现在的你」+ 歌词 | `正在整理你的文字，写成一首更贴近你的歌…` |
| 生成 AI 歌曲音频 | `正在生成这首歌，请保持页面打开…` |
| 快速舒缓本地音乐分析 | `正在为你选择一段适合此刻的纯音乐…` |

实现：`ComfortLyricsScreen._buildLoadingHint` 支持动态 message；`AnalysisScreen` 加载文案改为「正在为你选择一段适合此刻的纯音乐…」。

#### 6.20.9 版本号同步

- `lib/config/app_version.dart`：`milestone = P4-AI-Music-v1.0`、`versionName = v1.0.0`、`buildLabel = P4-conversation-song-flow-1-fix1`、`buildDate = 2026-07-23`、`deployTarget = Cloudflare Pages`
- `functions/api/health.js`：`BUILD_LABEL = P4-conversation-song-flow-1-fix1`
- `scripts/verify-provider-adapter.mjs`：`buildLabel` 断言同步

#### 6.20.10 本批不做

- 不部署上线、不真实调用 MiniMax
- 不做 R2 持久化 / 历史歌曲 / 分享链接 / 付费系统 / 用户系统 / 4090 部署
- 不删除「把困惑写成一首歌」的 MiniMax 歌曲生成能力与 provider adapter

#### 6.20.11 验证

`flutter analyze`（No issues found）/ `flutter test` / `flutter build web --release` / `node scripts/verify-provider-adapter.mjs` / `node scripts/verify-comfort-lyrics.mjs`（57 项：P4 第二批 35 项 + fix1 22 项）。

realCallsEnabled 保持 false / manualTest 保护保留 / P6 额度保护保留 / 不使用医疗化表达。

---

### 6.21 P4-conversation-song-flow-1-fix2：low_energy 场景 + lowEnergy 追问问题对齐 + 歌词低能量指引 + 快速舒缓纯本地化复核（2026-07-23）

#### 6.21.1 定位

fix1 上线后仍有一处不贴合：用户输入「最近总是提不起劲，感觉很疲惫、很空」（低能量 / 状态描述，不是具体事件）时，追问仍可能落入泛化模板或事件导向措辞；歌词也仍可能写出窗台 / 夜色等用户没提过的具象场景。本批在不部署、不真实调用 MiniMax 的前提下，新增 `low_energy` 场景分类、对齐 `lowEnergy` 兜底追问问题、为低能量场景写专属歌词指引与模板，并复核「快速舒缓一下」彻底纯本地化。

#### 6.21.2 生成链路确认（与 fix1 一致）

- 「给现在的你」由 LLM 生成（`/api/comfort-lyrics` → `comfortInterpretation`），不大改
- 「写成歌的话」歌词由 LLM 生成（`/api/comfort-lyrics` → `lyricDraft`），本批重点增强低能量场景贴合度
- AI 歌曲音频由 MiniMax 生成（`/api/generate-music`，受三重门保护，默认 REAL_CALLS=false）
- 「快速舒缓一下」只使用本地 assets 音乐（`AudioAssetCatalog`），不调用 `/api/generate-music`，不调用 MiniMax，不扣 P6 额度

#### 6.21.3 多轮追问仍调用 LLM（失败有本地兜底）

追问生成方式与 fix1 一致，未改变调用策略：

- 多轮追问由 LLM 根据用户原始输入动态生成（`/api/comfort-lyrics` 的 `mode=follow_up_questions`）
- LLM 失败时走本地兜底（`classifyConcern` 6 分类关键词匹配，前后端镜像）
- `lowEnergy` 优先级最高：只要命中低能量关键词（提不起劲 / 疲惫 / 累 / 空 / 麻木 / 没动力 / 不想动），即使同时含其他类别词，也归 `lowEnergy`，避免对「提不起劲」误问「这件事里」

#### 6.21.4 lowEnergy 兜底追问问题对齐

把 `lowEnergy` 兜底问题库从泛化版本改为贴合低能量状态，前后端镜像一致：

| 顺序 | 兜底问题 |
|---|---|
| 1 | `这种疲惫和空落感，通常什么时候最明显？` |
| 2 | `你更像是身体累，还是心里没力气？` |
| 3 | `想让这首歌陪你慢慢休息，还是给你一点重新开始的力气？` |

**不含「这件事里」**，围绕疲惫 / 空落 / 身体累 / 心里没力气 / 休息还是恢复力气。

#### 6.21.5 新增 low_energy 场景（歌词专属模板）

在 `detectScene` 与 `FALLBACK_TEMPLATES` 中新增 `low_energy` 场景（场景总数 5 → 6），用于 LLM 失败时的本地兜底歌词：

- `detectScene` 新增低能量关键词检测，优先级在具体事件场景（学业 / 关系 / 工作 / 愧疚）之后、`default` 之前
  - 含事件关键词 + 低能量词 → 仍归事件场景（事件优先于状态），避免误吞具体困境
- `low_energy` 模板歌词围绕：提不起劲、力气不知道去了哪里、不是偷懒是真的空了、今天先不用变好、慢一点也可以
- 副歌 hook：`慢一点也可以，我在这里`
- **不写窗台 / 手机 / 夜色 / 城市**等用户没提过的具象场景
- `SYSTEM_PROMPT` 同步新增 `low_energy` 场景选项与低能量歌词指引：围绕提不起劲 / 疲惫 / 空，不强行具象场景，副歌给温和陪伴话

#### 6.21.6 歌词如何使用原始输入与追问回答

LLM 调用时透传 `initialConcern` + `followUpAnswers`（与 fix1 一致）：

- 主歌必须承接用户在 `storyText` / 追问回答中提到的具体困境（人物 / 场景 / 物件 / 关系），意象化处理
- **不编造用户没说过的具体场景**（窗台 / 手机 / 枕头边 / 雨夜 / 房间），意象必须服务于用户困境
- 第一段让用户感觉「这首歌是在写我」
- 副歌给一句温和、有记忆点、能陪伴用户的句子
- 避免医疗化表达（不用「治疗」/「治愈」/「诊断」，不承诺疗效），使用「陪伴 / 理解 / 慢慢放松 / 情绪支持 / 给自己一点空间 / 先停下来也可以」

#### 6.21.7 快速舒缓纯本地化复核

再次全局核查确认（与 fix1 结论一致，本批未改变该链路）：

- 「快速舒缓一下」点击后跳转 `AnalysisScreen`，走本地 `AudioAssetCatalog` 纯音乐推荐与播放流程
- 不调用 `/api/generate-music`、不调用 MiniMax、不扣 P6 额度
- 不存在「生成专属音乐（实验）」入口 / 文案
- 不存在 `MusicGenerationScreen` 路由 / 入口 / 残留 import
- 后续新增纯音乐只扩展本地曲库配置，不走 AI 生成
- 「把困惑写成一首歌」的 MiniMax 歌曲生成能力与 provider adapter 保留

#### 6.21.8 加载文案分阶段（保持 fix1）

不同阶段仍显示不同文案，本批未改动：

| 阶段 | 文案 |
|---|---|
| 生成追问（loadingFollowUp） | `正在根据你的文字整理几个更贴近的问题…` |
| 生成「给现在的你」+ 歌词 | `正在整理你的文字，写成一首更贴近你的歌…` |
| 生成 AI 歌曲音频 | `正在生成这首歌，请保持页面打开…` |
| 快速舒缓本地音乐分析 | `正在为你选择一段适合此刻的纯音乐…` |

#### 6.21.9 版本号同步

- `lib/config/app_version.dart`：`milestone = P4-AI-Music-v1.0`、`versionName = v1.0.0`、`buildLabel = P4-conversation-song-flow-1-fix2`、`buildDate = 2026-07-23`、`deployTarget = Cloudflare Pages`
- `functions/api/health.js`：`BUILD_LABEL = P4-conversation-song-flow-1-fix2`
- `scripts/verify-provider-adapter.mjs`：`buildLabel` 断言同步

#### 6.21.10 本批不做

- 本批代码不真实调用 MiniMax，`manualTest=true` 三重门保护保留（`MUSIC_GENERATION_PROVIDER` + `MUSIC_GENERATION_REAL_CALLS_ENABLED` + 请求体 `manualTest=true` 三者同时满足才发真实请求）
- `MUSIC_GENERATION_REAL_CALLS_ENABLED` 是 Cloudflare Pages 环境变量，不在代码仓库中，由用户在 Dashboard 手动管理与确认
- 不做 R2 持久化 / 历史歌曲 / 分享链接 / 付费系统 / 用户系统 / 4090 部署
- 不删除「把困惑写成一首歌」的 MiniMax 歌曲生成能力与 provider adapter

#### 6.21.11 验证

`flutter analyze`（No issues found）/ `flutter test`（300 passed, 5 skipped）/ `flutter build web --release` / `node scripts/verify-provider-adapter.mjs`（64 passed）/ `node scripts/verify-comfort-lyrics.mjs`（59 passed：新增 low_energy 场景检测 + 6 场景模板结构验证 + low_energy 不覆盖事件场景优先级测试）。

manualTest 三重门保护保留 / P6 额度保护保留 / 不使用医疗化表达。

#### 6.21.12 部署上线（2026-07-24）

本批已部署至 Cloudflare Pages 正式域名（`xinxian-music.xyz`）：

- `flutter build web --release` → `wrangler pages deploy build/web --project-name=xinxian-healing-music`
- `/api/health` 验证（2026-07-24）：
  - `buildLabel = P4-conversation-song-flow-1-fix2` ✅
  - `musicProvider = minimax_music` ✅
  - `hasMinimaxKey = true` ✅
  - `realCallsEnabled` 为 Cloudflare 环境变量，由用户手动确认与管理（不在代码中）
- 线上「快速舒缓一下」只走本地 `AudioAssetCatalog`，不调 `/api/generate-music`、不调 MiniMax、不扣 P6 额度
- 线上「把困惑写成一首歌」AI 歌曲生成仍受三重门 + P6 本地额度保护

---

### 6.22 P4-playback-experience-2：AI 歌曲独立播放页 + 本地舒缓播放模式增强

#### 6.22.1 定位

fix2 上线后，「把困惑写成一首歌」生成 AI 歌曲成功后仍停留在歌词页内嵌播放，页面信息较多、播放体验不够清晰；「快速舒缓一下」本地纯音乐播放时，若用户设置 5 分钟定时关闭但单曲只有 3 分钟，音乐可能在 3 分钟就停止，体验不完整。本批在**不部署、不真实调用 MiniMax、不依赖 R2** 的前提下：

1. AI 歌曲生成成功后跳转到独立播放页 `GeneratedSongPlayerScreen`，不在歌词页内嵌播放
2. 本地舒缓播放页新增 4 种播放模式（单曲播放 / 单曲循环 / 列表循环 / 顺序播放）
3. 定时关闭开启后强制持续播放，保证音乐持续到用户设定时间结束

#### 6.22.2 生成链路确认（与 fix2 一致）

- 「给现在的你」由 LLM 生成（`/api/comfort-lyrics` → `comfortInterpretation`），不大改
- 「写成歌的话」歌词由 LLM 生成（`/api/comfort-lyrics` → `lyricDraft`），不大改
- AI 歌曲音频由 MiniMax 生成（`/api/generate-music`，受三重门保护，默认 REAL_CALLS=false）
- 「快速舒缓一下」只使用本地 assets 音乐（`AudioAssetCatalog`），不调用 `/api/generate-music`，不调用 MiniMax，不扣 P6 额度

#### 6.22.3 AI 歌曲独立播放页（GeneratedSongPlayerScreen）

新增 `lib/screens/generated_song_player_screen.dart`，从「把困惑写成一首歌」生成成功后跳转至此，专门播放这首生成歌曲，不在歌词页内嵌播放。

- **跳转时机**：用户点击「生成这首歌（实验）」→ 费用确认 → `/api/generate-music` 返回成功 + 拿到可播放 URL 后，自动 `Navigator.push` 到 `GeneratedSongPlayerScreen`
- **展示内容**：歌曲标题 / 副文案「根据你刚才写下的内容生成，适合现在慢慢听一遍。」/ 「给现在的你」温和解惑 / 歌词 / 播放·暂停 / 进度条（可拖动）/ 当前时间·总时长 / 重新播放 / 返回歌词页 / 定时关闭入口 / 单曲循环开关
- **不依赖 R2**：当前仍使用 `playableUrl`（`generatedAudioUrl` 相对路径或 `audioDataUrl` base64 dataUrl）临时播放，不做历史歌曲 / 分享链接 / 永久保存
- **失败处理**：`audioDataUrl` 不存在或播放失败时显示温和错误提示「音频暂时无法加载」+ 重试 + 返回歌词页，不白屏 / 不卡死
- **歌词页缓存**：`ComfortLyricsScreen` 缓存 `GeneratedSongMeta`（playableUrl / title / comfortInterpretation / lyricDraft / targetState），显示轻量入口卡片「这首歌已经生成好了」+「进入播放页」按钮，支持返回后重新进入播放页，不重复生成、不重复扣费
- **生成失败 / 用户取消 / 未生成成功**：不跳转、不扣成功额度，保持当前错误处理逻辑

#### 6.22.4 本地舒缓播放模式增强（PlayerScreen）

`lib/screens/player_screen.dart` 新增 4 种播放模式，默认单曲循环（最符合舒缓陪伴场景）：

| 模式 | 行为 | just_audio 实现 |
|---|---|---|
| 单曲播放 | 当前曲播完即停 | `LoopMode.off` + 单一源 |
| 单曲循环 | 当前曲播完重播 | `LoopMode.one` + 单一源 |
| 列表循环 | 列表末尾回到第一首 | `LoopMode.all` + 同类全部 |
| 顺序播放 | 列表末尾停止 | `LoopMode.off` + 同类全部 |

- **播放列表组成**：按当前 `targetState` 过滤 `AudioAssetCatalog.assets`（sleep / regulate / soothe / focus / energize 各 1 首）。当前每类 1 首，列表模式与单曲模式行为一致；后续每类添加更多曲目后，列表循环 / 顺序播放自动生效
- **模式切换**：`PopupMenuButton` 切换，切换时通过 `setAudioSources`（替代已废弃的 `ConcatenatingAudioSource`）重建音频源并保留播放进度，不中断当前播放
- **UI**：播放模式按钮 + 定时关闭按钮并排；定时强制态时按钮显示「定时中·循环」小标，提示当前为强制循环
- **不影响 AI 生成歌曲页**：AI 生成歌曲播放页只支持单曲播放 / 单曲循环 / 定时关闭，不涉及列表模式

#### 6.22.5 定时关闭持续播放保证

解决「单曲 3 分钟 + 定时 5 分钟 → 3 分钟就停」的体验问题：

- `lib/widgets/sleep_timer_button.dart` 新增 `onForceLoopStart` / `onForceLoopEnd` 回调
- 进入倒计时模式时触发 `onForceLoopStart`：强制切到单曲循环（保留进度），保证音乐持续播放
- 倒计时结束 / 用户取消定时触发 `onForceLoopEnd`：恢复用户原播放模式
- 定时强制态期间用户切换模式只更新缓存（`_preForceMode`），实际源保持单曲循环，强制态结束后再应用
- 到达定时时间后停止播放

**播放行为边界验证**：

| 场景 | 预期行为 |
|---|---|
| 单曲播放 + 不开定时 | 播完停止 |
| 单曲循环 | 播完自动重播 |
| 列表循环 | 播完当前曲进下一曲，末尾回到第一首 |
| 顺序播放 | 播完列表末尾后停止 |
| 开启 5 分钟定时 + 单曲 3 分钟 | 3 分钟时不停止，继续循环，5 分钟到达后停止 |
| 取消定时 | 停止倒计时，播放模式恢复正常，不影响当前播放 |

#### 6.22.6 版本号同步

- `lib/config/app_version.dart`：`milestone = P4-AI-Music-v1.0`、`versionName = v1.0.0`、`buildLabel = P4-playback-experience-2`、`buildDate = 2026-07-24`、`deployTarget = Cloudflare Pages`
- `functions/api/health.js`：`BUILD_LABEL = P4-playback-experience-2`
- `scripts/verify-provider-adapter.mjs`：`buildLabel` 断言同步

#### 6.22.7 本批不做

- 本批代码不真实调用 MiniMax，`manualTest=true` 三重门保护保留（`MUSIC_GENERATION_PROVIDER` + `MUSIC_GENERATION_REAL_CALLS_ENABLED` + 请求体 `manualTest=true` 三者同时满足才发真实请求）
- `MUSIC_GENERATION_REAL_CALLS_ENABLED` 是 Cloudflare Pages 环境变量，不在代码仓库中，由用户在 Dashboard 手动管理与确认
- 不做 R2 持久化 / 历史歌曲 / 分享链接 / 付费系统 / 用户系统 / 4090 部署
- AI 歌曲仍使用 `audioDataUrl` 临时播放，不依赖 R2

#### 6.22.8 验证

`flutter analyze`（No issues found）/ `flutter test`（310 passed, 5 skipped，新增 `test/generated_song_player_screen_test.dart` 10 项独立播放页静态 UI 测试）/ `flutter build web --release` / `node scripts/verify-provider-adapter.mjs`（64 passed）/ `node scripts/verify-comfort-lyrics.mjs`（59 passed）。

manualTest 三重门保护保留 / P6 额度保护保留 / 不使用医疗化表达 / 快速舒缓仍完全本地化。

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

- **「快速舒缓一下」仍为预置音频**：该主线使用本地预置音频素材（`sleep_01.mp3` / `regulate_01.mp3` / `soothe_01.mp3` / `focus_01.mp3` / `energize_01.mp3` 共 5 类），由 `AudioAssetCatalog` 按 targetState 自动匹配，**非实时 AI 生成音频**（M5 的 `generationPrompt` 仅生成文本提示词）。**注：「把困惑写成一首歌」主线已接入 MiniMax 真实 AI 生成（默认 REAL_CALLS=false，受三重门保护），详见 P4 章节；生成音频当前以 audioDataUrl 临时播放，尚未做 R2 持久化**
- **DSP 后处理尚未接入**：`AudioPostProcessorPort` 当前为 Passthrough 直通，未实现白噪音 / 粉红噪音 / EQ / 淡入淡出等真实 DSP
- **完整 ListeningSession 仍仅保存在本地**：匿名结构化反馈数据（体验评分 / 状态评分 / 情绪参数等）可上传至 Cloudflare D1，但完整 ListeningSession（含心境原文）未上传至云端
- **历史记录目前是浏览器本地存储**：基于 shared_preferences（Web 端为 localStorage），按 origin 隔离，清除浏览器数据后丢失
- **用户系统尚未接入**：无账号 / 跨设备同步
- **反馈数据可视化尚未完成**：当前采用 Wrangler SQL + D1 Console 轻量方案，无公开管理后台 / Dashboard
- **移动端 App 尚未发布**：Android 构建存在上游插件兼容性问题，暂不作为初赛阻塞项

> **已真实接入（非 Mock）**：LLM 情绪解析（M4 DeepSeek API）、LLM 画像驱动音乐参数映射（M5 `EmotionToMusicPlanMapper`）、多音频匹配（M6 `AudioAssetCatalog`）、targetState 意图识别精修（M6.1 `TargetStateResolver`）、匿名云端反馈采集（M7.0 D1 + Pages Functions）。

---

## 十一、后续路线图

> 详细分阶段路线见 [docs/ROADMAP.md](docs/ROADMAP.md)。下表为速查。

| 阶段 | 计划内容 | 状态 |
|---|---|---|
| **P3-Web-v1.0** | 数据与反馈运营：反馈查询脚本 + 测试数据隔离 + 真实反馈采集准备 | ✅ 已完成（三批交付） |
| **P4-AI-Music-v1.0** | AI 音乐生成接入：MiniMax Music-2.0 真实调用打通 + audioDataUrl 临时播放闭环 + 生成歌曲结果页体验（默认 REAL_CALLS=false，受三重门保护） | ✅ 已完成（已上线验收） |
| **P6-Quota-v1.0**（本批） | 本地额度保护与成本安全首批：浏览器每日生成次数限制（默认 1 次）+ service 单元测试 + 文档整理；realCallsEnabled 保持 false | ✅ 本批完成（未上线） |
| **中期** | R2 持久化 / 历史生成歌曲 / 分享链接 / 用户系统 / 付费会员额度购买 | ⏳ 计划中 |
| **长期** | 4090 后端迁移 / 自有音乐模型替换 MiniMax / 小红书社交增长 Agent | ⏳ 计划中 |

> 说明：原 P5（移动端）/ P7（运营后台）优先级后移；移动端 App 因 Android 上游插件兼容性问题暂不作为阻塞项。
> **Cloudflare 是当前验证环境，4090 是后续自托管迁移方向**；不调用 Mureka API（历史调研未采用）。

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
| 2026-07-18 | v1.0.0 / P4-comfort-lyrics-2 | P4 新方向第二批 | 解惑文本与歌词质量优化：`comfortInterpretation` 升级为严格 4 段结构（复述处境「听起来你正在……」/ 重新框架化痛苦「也许这件事最重的地方不是……而是……」/ 小行动「可以先把目标放小一点……」/ 过渡到歌「这首歌不急着推你往前，只先陪你站稳一点」）；`lyricDraft` 升级为画面感 + 重复 hook + 严格三段（【主歌】具象意象 / 【副歌】可重复 hook / 【尾声】留白不升华）；`songPrompt` 升级为明确含 vocal/mood/tempo/instrumentation/arrangement 5 要素的英文风格提示；新增 `detectScene` 本地场景识别（5 类：academic_failure/relationship_conflict/work_pressure/guilt_regret/default），fallback 按 scene 选择独立模板；`FALLBACK_TEMPLATES` 从 1 套通用模板扩展为 5 场景独立模板（学业用模拟卷意象 / 关系用消息框意象 / 工作用屏幕光意象 / 愧疚用没寄出的道歉意象 / 默认用夜色意象）；`sanitizeText` 新增 `LECTURING_PATTERNS`（你必须/你应该/你需要治疗/这说明你 → 替换「可以试着」）；前端 `ComfortLyricsScreen` 标题改名（温和解惑→给现在的你 / 歌词草稿→写成歌的话）+ songPrompt 折叠弱化（AnimatedCrossFade 默认收起，标题「后续生成参数」）+ 新增场景标记显示（学业受挫/关系摩擦/压力疲惫/愧疚后悔/此刻心境）；前端 Service `_localFallback` 修复 scene 字段未传递的 bug；`callLlm` temperature 0.7→0.75，max_tokens 800→1000；验证脚本 25 项→35 项（新增 detectScene 5 场景 + 说教类 sanitizeText + 5 场景 fallback 结构/英文/禁用词/隐私/差异化）；flutter test 新增 scene 字段解析 + 场景识别 + songPrompt 折叠/展开 + 场景标记测试；本批**不调用 MiniMax** / **不调用 Mureka** / **不生成真实音频** / **不改 D1 schema** / **不改付费模块** / **不做社交 Agent** / **不写入任何 API Key** / **不使用医疗化表达** / **不包装成玄学/算命/宗教神谕** |
| 2026-07-18 | v1.0.0 / P4-lyrics-edit-1 | P4 新方向第三批 | 歌词确认与编辑 + 后续生成按钮占位：`ComfortLyricsScreen` 歌词卡片（`写成歌的话`）新增编辑闭环——右上角「编辑歌词」TextButton → 点击进入编辑态（多行 TextField minLines 6 / maxLines 14 + 实时字数提示 `ValueListenableBuilder<TextEditingValue>` + 温和质量提醒「建议保留主歌、副歌、尾声结构，后续更适合生成歌曲。」）+「保存歌词」/「取消编辑」按钮（保存写入 `_editedLyric` 显示新歌词，取消恢复编辑前内容）；结果区底部新增「生成这首歌（即将开放）」淡紫色占位 FilledButton，点击弹浮动 SnackBar「歌曲生成正在准备中，当前版本先支持歌词确认。」；状态管理：新增 `_isEditing`/`_editingController`/`_editingFocus`/`_editedLyric` 字段，编辑态时生成解惑按钮和占位按钮均 disabled，`_generate`/`_reset` 清空编辑状态，`songPrompt` 保持原结果不变，二次进入编辑态初始内容为上次保存内容；新增 10 项 flutter test（编辑按钮可见 / 编辑态结构 / 保存显示新歌词 / 取消恢复旧歌词 / 占位按钮弹 SnackBar 不触发 API / 编辑态两按钮禁用 / 再写一首清空编辑状态 / 二次编辑初始内容 / 结果区完整结构），修复第一批「点击生成按钮后显示加载状态」测试（`findsOneWidget`→`findsWidgets`）；后端 API / Service / Model / 验证脚本本批未修改；本批**不调用 MiniMax** / **不调用 Mureka** / **不生成真实音频** / **不改 D1 schema** / **不改付费模块** / **不做社交 Agent** / **不写入任何 API Key** / **不使用医疗化表达** / **不包装成玄学/算命/宗教神谕** |
| 2026-07-19 | v1.0.0 / P4-minimax-song-gray-1 | P4 新方向第四批 | MiniMax 歌曲生成灰度接入：排查 `provider=mock` 根因——`provider-factory.js` 当 `minimax_music` + 缺 `MINIMAX_API_KEY` 时降级 MockProvider，即使 `REAL_CALLS_ENABLED=true` 也无效，最可能是 `MINIMAX_API_KEY` 未在 Cloudflare Production Secret 配置；`/api/health` 新增 `diagnostics` 非敏感诊断字段（`musicProvider` / `realCallsEnabled` / `hasMinimaxKey` / `hasReplicateToken` / `hasStableAudioKey` / `buildLabel`），只返回 `hasXxxKey: true/false` 不泄露 Key 值，导出 `buildDiagnostics` 用于测试；确立三重门灰度策略——门1 `MUSIC_GENERATION_PROVIDER=minimax_music`（wrangler.toml）+ 门2 `MUSIC_GENERATION_REAL_CALLS_ENABLED=true`（wrangler.toml，默认 false，本批从 true 改回 false）+ 门3 请求体 `manualTest=true`（curl 手动传入，前端默认不带）+ Key 配置，四者同时满足才真实调用；`wrangler.toml` `MUSIC_GENERATION_REAL_CALLS_ENABLED` 从 `"true"` 改回 `"false"` 并新增三重门注释；`music-generation-utils.js` `validateInput` 新增 `lyrics`（≤2000 字符）/ `songPrompt`（≤500 字符）可选字段 + `isPromptForbidden` 过滤；`minimax-music-provider.js` `_callMiniMax` 使用 `validated.lyrics` + `validated.songPrompt`，`_buildPrompt` 优先用 `validated.songPrompt` 回退到 `PROMPTS_BY_TARGET_STATE`，日志只打印 `lyricsLength` / `songPromptLength` 不打印内容，返回 `lyricsLength` / `songPromptSource` 摘要字段；不传用户原始困惑全文（`storyText` 不进入 MiniMax 请求）；不返回完整 `audioHex`（只返回 `audioHexLength` / `musicDuration` / `traceId`）；前端 `ComfortLyricsScreen` 「生成这首歌」按钮**保持灰度入口**（不调用 `/api/generate-music` / 不传 `manualTest` / 只 SnackBar 提示「歌曲生成正在准备中，当前先支持歌词确认。」/ 不产生费用）；`scripts/verify-provider-adapter.mjs` 新增 14 项 P4 第四批测试（lyrics/songPrompt 解析 / 超长截断 / 禁止关键词 / 透传 requestBody / 缺字段回退 / 不传 storyText / 日志不泄露歌词 / 不调用 Mureka / health 诊断字段 / 不泄露 Key 值），共 45 项；本批**不开放前端真实调用** / **不调用 Mureka** / **不部署 4090**（只在 README 记录为后续自托管 worker 方向）/ **不改 D1 schema** / **不做付费模块** / **不做社交 Agent** / **不写入任何 API Key** / **不打印 `MINIMAX_API_KEY`** / **不使用医疗化/玄学化表达** / **不返回完整 `audioHex`** / **不实现真实音频播放**（下一批处理） |
| 2026-07-19 | v1.0.0 / P4-home-structure-1 | P4 前端结构调整第一批 | 首页双主线重构：`HomeScreen` 从「单一心境输入 + 主按钮 + 弱化入口」重构为**双主线并列结构**——第一主线「把困惑写成一首歌」（lavender 边框卡片 + 图标 + 标题 + 副文案「说说最近卡住你的事，让它先变成一段温和的歌词。」+「开始写歌」FilledButton，点击进入 `ComfortLyricsScreen`）+ 第二主线「快速舒缓一下」（朴素区域 + 副文案「不想多说也可以，直接生成一段适合现在的舒缓音乐方案。」+ 保留原 `MoodInputField` + 示例 chips + 「快速生成方案」FilledButton，走原有心境输入/分析流程）；新增 `_PrimaryEntryCard` 私有 widget（单层卡片，不套卡片，lavender 色调与 `ComfortLyricsScreen` 生成按钮呼应）；原「生成专属疗愈方案」按钮文案改为「快速生成方案」；原「把困惑写成一首歌」OutlinedButton 升级为第一主线卡片；`ComfortLyricsScreen` 输入区标题「写下你的困惑」→「先说说卡住你的事」（更温和、更像产品体验）；底部入口保持「查看历史记录」+「设置」+ 版本号弱展示（隐私/关于/AI设置/云端反馈继续放在设置弹窗）；`widget_test.dart` 现有文案断言同步更新 + 新增 2 项测试（双主线可见 / 点击开始写歌进入 ComfortLyricsScreen 验证输入区标题）；移动端适配：两主线垂直堆叠不拥挤、按钮高度稳定（48/50）、文案不溢出（行高 1.5）、不出现卡片套卡片、不出现大面积空白、文本不遮挡按钮；本批**不调用 MiniMax/Mureka** / **不生成真实音频** / **不改 Cloudflare Functions** / **不改 D1 schema** / **不做付费模块** / **不做社交 Agent** / **不写入任何 API Key** / **不使用医疗化/玄学化表达** / **不改原快速舒缓流程的 AnalysisScreen/PlanScreen/PlayerScreen** |
| 2026-07-19 | v1.0.0 / P4-minimax-real-test-1 | P4 MiniMax 真实生成链路受控测试 | 完善 MiniMax Music-2.0 真实生成链路返回信息，准备手动 curl 测试流程：`minimax-music-provider.js` `_callMiniMax` 补齐 `audioUrl`（`data.data.audio_url`）/ `taskId`（`data.data.task_id` / `data.task_id`）/ `requestId`（`data.request_id`）字段提取，成功响应返回 `audioUrl` / `audioUrlLength` / `taskId` / `requestId`；`_fallbackResponse` 新增第四个参数 `extra`（用于 errorMessage 映射不进入响应）+ 返回字段新增 `errorCode`（与 `reason` 一致）/ `errorMessage`（安全映射）/ `taskId` / `traceId` / `requestId`（null）；新增 `_mapErrorMessage(reason, extra)` 方法根据 reason 返回内部友好消息（`http_error_*`→`minimax_http_error` / `minimax_error_*`→`minimax_business_error` / `request_timeout`→`minimax_request_timeout` / `request_failed`→`minimax_request_failed` / `provider_disabled`→`minimax_real_calls_disabled` / `api_key_missing`→`minimax_api_key_missing` / `manual_test_required`→`manual_test_required`），**不泄露 errText / status_msg / err.message 原始内容**；HTTP 错误 / 业务错误 / 超时 / fetch 异常调用 `_fallbackResponse` 时传入 `extra`（httpStatus / minimaxStatusCode / errorName）；`wrangler.toml` `MUSIC_GENERATION_REAL_CALLS_ENABLED` 注释新增 P4-minimax-real-test-1 手动测试流程（**保持 `"false"`** 仓库默认安全，测试时手动改 `true` 并部署，测完改回 `false` 再部署，curl `/api/health` 验证 `realCallsEnabled=false` / `hasMinimaxKey=true`）；`health.js` `BUILD_LABEL` 同步为 `P4-minimax-real-test-1`；`app_version.dart` `buildLabel` → `P4-minimax-real-test-1` + 新增 `P{N}-minimax-real-test-{n}` 约定说明；`verify-provider-adapter.mjs` 测试 24/25/26/27/28/29 断言更新（errorCode 与 reason 一致 + errorMessage 安全映射 + audioUrl/taskId/requestId 字段），新增测试 47-52（audioUrl 解析 / taskId 解析 / requestId 解析 / HTTP 错误 errorMessage 不泄露 errText / 业务错误 errorMessage 不泄露 status_msg / fetch 异常 errorMessage 不泄露 err.message / fallback 响应包含 taskId/traceId/requestId 字段，共 7 项），共 52 项测试；本批**不开放前端真实调用**（按钮保持灰度入口） / **不调用 Mureka** / **不部署 4090** / **不改 D1 schema** / **不做付费模块** / **不做社交 Agent** / **不写入任何 API Key** / **不打印 MINIMAX_API_KEY** / **不使用医疗化/玄学化表达** / **不返回完整 audioHex** / **不实现真实音频播放**（下一批处理）/ **不实现 R2 持久化存储** / **不允许移除 manualTest 保护**（三重门之一）；手动 curl 真实测试需用户在测试环境执行，仓库默认 `REAL_CALLS_ENABLED=false` 不产生费用；**真实调用已于 2026-07-19 02:39 UTC 完成测试**：临时改 `true` → 部署 → curl `/api/generate-music`（`manualTest=true`）→ 真实返回 `ok=true` / `provider=minimax_music` / `status=succeeded` / `traceId=06ab6bd351ff28a4d8dbb6cefddee5fe` / `audioHexLength=1022098`（约 512KB mp3）/ `audioUrl=null`（MiniMax 同步接口返回 hex 而非 URL）/ `musicDuration=0`（MiniMax 未返回该字段）/ `taskId=null` / `requestId=null`；测试完成后立即改回 `false` 并重新部署，`/api/health` 确认 `realCallsEnabled=false` / `hasMinimaxKey=true`；本次调用产生真实费用约 0.25 元；详见 6.15.11 真实调用结果 |
| 2026-07-19 | v1.0.0 / P4-generated-audio-playback-1 | P4 生成音频落地播放链路 | 完成「MiniMax audioHex → R2 → 前端播放」第一版闭环：新增 `functions/api/generated-music.js`（从 R2 读取音频流端点，`GET /api/generated-music?key=...`，校验 storageKey 路径合法性，流式返回 audio/mpeg，受 CORS 白名单保护）；修改 `minimax-music-provider.js` constructor 新增 `this.r2Bucket = this.env.GENERATED_MUSIC_BUCKET || null` + `_callMiniMax` 成功分支新增三种情况处理（MiniMax 直接返回 audioUrl → `storageProvider=minimax_direct` / 有 audioHex + R2 已配置 → `_hexToBytes` 转 Uint8Array + `_buildStorageKey` 生成 `generated-music/{yyyyMMdd}/{sessionId}-{traceId}.mp3` + `R2.put()` 上传 → `storageProvider=r2` / 有 audioHex + R2 未配置 → `storageWarning=r2_not_configured` / R2 上传失败 → `storageWarning=r2_upload_failed`）+ 新增辅助方法 `_hexToBytes(hex)`（hex→Uint8Array，处理奇数长度/空白字符/非 hex 字符）和 `_buildStorageKey(sessionId, traceId)`（生成 R2 object key，traceId 为空时用时间戳占位）+ 返回字段新增 `storageProvider` / `storageKey` / `generatedAudioUrl` / `storageWarning`（`generatedAudioUrl` 形如 `/api/generated-music?key=...`，前端通过 `Uri.base.resolve()` 解析为绝对 URL）；修改 `wrangler.toml` 新增 `[[r2_buckets]]` 段：`binding = "GENERATED_MUSIC_BUCKET"` / `bucket_name = "xinxian-generated-music"` + 详细注释（创建命令 `npx wrangler r2 bucket create xinxian-generated-music` / 安全注意事项 / 缺失时返回 `storageWarning=r2_not_configured` 不崩溃）；修改 `health.js` `BUILD_LABEL` → `P4-generated-audio-playback-1` + `buildDiagnostics` 新增 `hasR2Bucket` 字段（不泄露 bucket 名，只返回 true/false）；修改 `app_version.dart` `buildLabel` → `P4-generated-audio-playback-1` + 新增 `P{N}-generated-audio-playback-{n}` 约定说明；修改 `comfort_lyrics_screen.dart` 实现受控实验入口（顶部新增 `dart:convert` / `http` / `just_audio` import + 8 个 AI 生成歌曲状态字段 + `dispose()`/`_reset()` 释放播放器 + `_buildGenerateSongButton()` 文案改为「生成这首歌（实验）」 + 新增 `_onGenerateSongPressed()`/`_showGenerateSongConfirmDialog()`（**费用确认对话框，必须用户主动确认**）/`_callGenerateMusicApi()`（调用 /api/generate-music，请求体含 `manualTest=true`，处理三种响应：ok+url→初始化播放器 / ok+storageWarning→显示已保存提示 / !ok→显示"生成没有完成，请稍后再试"）/`_initGeneratedAudioPlayer()`/`_toggleGeneratedAudio()`/`_mapStyleToTargetState()`（曲风→targetState 映射：gentle_pop/soft_piano→soothe，ambient_ballad→sleep，acoustic_warm→regulate）/`_buildGeneratedSongPlayer()`（内嵌播放区：标题行 + 圆形播放/暂停按钮 + 文案）/`_buildMusicErrorHint()`/`_buildStorageWarningHint()` + 顶层辅助函数 `_jsonEncode`/`_decodeJson` + `_buildNextStepHint()` 文案更新）；修改 `verify-provider-adapter.mjs` 新增 10 项测试（测试 54-63：R2 已配置上传成功 / R2 未配置返回 storageWarning / R2 上传失败返回 storageWarning / MiniMax 直接返回 audioUrl 时 storageProvider=minimax_direct / storageKey 格式正确 / 响应不包含完整 audioHex / _hexToBytes 正确转换 / _buildStorageKey 边界处理 traceId 为空 / hasR2Bucket 字段不泄露 bucket 名 / buildLabel 已更新），共 **62 项测试全部通过**；本批**继续使用 MiniMax 不切换 Mureka/Replicate/4090** / **`MUSIC_GENERATION_REAL_CALLS_ENABLED` 默认保持 `false`** / **manualTest 保护不移除** / **不暴露 MINIMAX_API_KEY** / **不允许前端正式入口自动扣费**（必须用户主动点击 + 费用确认对话框）/ **不做付费模块/社交 Agent/完整用户系统** / **不使用医疗化表达** / **不把 audioHex 原文返回前端**（只返回 audioHexLength）/ **R2 bucket 默认私有不开放公开访问**（统一通过 /api/generated-music 代理）/ **R2 binding 不存在时返回清楚错误不崩溃** / **不改 D1 schema** / **不影响"快速舒缓一下"固定曲库播放链路**；详见 6.16 章节 |
| 2026-07-23 | v1.0.0 / P4-temp-audio-playback-1 | P4 临时音频播放闭环 | **暂不依赖 R2**，先跑通产品核心链路（用户输入困惑 → 生成解惑 → 生成歌词 → MiniMax 生成歌曲 → 页面直接播放）：修改 `minimax-music-provider.js` 新增 `_bytesToBase64(bytes)` 辅助方法（Uint8Array→base64，分块处理每 32KB 避免 `String.fromCharCode.apply` 栈溢出，使用 Web 标准 `btoa` API）+ `_callMiniMax` 成功分支存储逻辑调整（情况1 MiniMax 直接返回 audioUrl → `generatedAudioUrl=audioUrl` / 情况2 有 audioHex + R2 已配置 → 上传 R2 → `generatedAudioUrl=/api/generated-music?key=...`，上传失败 → 回退 `audioDataUrl` + `storageWarning=r2_upload_failed` / 情况3 有 audioHex + R2 未配置 → 生成 `audioDataUrl=data:audio/mpeg;base64,...`，**不再返回 `storageWarning=r2_not_configured`**，本批不视为错误）+ 返回字段新增 `audioDataUrl` / `audioBase64Length` / `contentType` + R2 上传成功时不返回 `audioDataUrl`（节省响应体）；修改 `comfort_lyrics_screen.dart` `_callGenerateMusicApi` 响应处理新增 `audioDataUrl` 字段（优先用 `generatedAudioUrl`，回退到 `audioDataUrl`，都没有 → 显示"音乐已经生成，但暂时无法播放，请稍后再试"）+ `_initGeneratedAudioPlayer` 支持 `data:` URL（`data:` / `http://` / `https://` 开头 → 直接 `Uri.parse`，相对路径 → `Uri.base.resolve`，just_audio Web 端底层 HTML5 audio 元素原生支持 data: URL）；修改 `app_version.dart` `buildLabel` → `P4-temp-audio-playback-1` / `buildDate` → `2026-07-23` + 新增 `P{N}-temp-audio-playback-{n}` 约定说明；修改 `health.js` `BUILD_LABEL` → `P4-temp-audio-playback-1`；修改 `verify-provider-adapter.mjs` 测试 55 调整（R2 未配置 → 返回 `audioDataUrl`，不再 `storageWarning=r2_not_configured`）+ 测试 56 调整（R2 上传失败 → `storageWarning=r2_upload_failed` + `audioDataUrl` 兜底）+ 测试 54/57 新增 `audioDataUrl=null` 断言（R2 成功/MiniMax 直返 URL 时不返回 audioDataUrl）+ 测试 63 更新 buildLabel + 新增测试 64/65（`_bytesToBase64` 正确转换 hex→bytes→base64 / audioDataUrl 路径下响应不包含完整 audioHex 原文），共 **64 项测试全部通过**；本批**暂不依赖 R2**（不要求创建 bucket / 不要求绑定 GENERATED_MUSIC_BUCKET，R2 逻辑保留作为后续持久化方案）/ **`MUSIC_GENERATION_REAL_CALLS_ENABLED` 默认保持 `false`** / **manualTest 保护不移除** / **不暴露 MINIMAX_API_KEY** / **不做付费模块/用户系统/4090 部署/社交 Agent** / **不使用医疗化表达** / **不把完整 audioHex 原文返回前端**（只返回 audioHexLength + audioDataUrl base64 编码形式）/ **不把完整 audioDataUrl 打印进日志** / **不改 D1 schema** / **不影响"快速舒缓一下"固定曲库播放链路**；详见 6.17 章节 |
| 2026-07-23 | v1.0.0 / P4-temp-audio-playback-1-cleanup | P4 临时音频播放闭环 - 线上试听验证 + 代码审计清理 | **线上真实试听成功**：临时开启 `realCallsEnabled=true` 部署后，用户在 https://xinxian-music.xyz 完成完整链路测试（输入困惑 → 生成解惑 → 生成歌词 → 点击「生成这首歌（实验）」→ 确认费用 → 等待生成 → **页面出现播放器，点击播放可听到 AI 生成歌曲**），使用 `audioDataUrl`（base64 dataUrl）临时播放，**不依赖 R2**；测试完成后立即恢复 `realCallsEnabled=false` 并重新部署，`/api/health` 确认安全；部署时发现 `wrangler.toml` 中 `[[r2_buckets]]` R2 binding 因 bucket 不存在导致部署失败，临时注释掉 R2 binding（本批不依赖 R2，后端走 audioDataUrl 兜底路径）；代码审计全部通过（R2 完全可选 / 不返回完整 audioHex / 不打印完整 audioDataUrl / 只保留必要诊断字段 / MiniMax 失败不白屏 / manualTest 保护保留 / realCallsEnabled=false 默认安全 / 文案合规无违规表达 / 无重复状态字段无废弃方法无未使用 import）；清理 `comfort_lyrics_screen.dart` 顶部过时文档注释（移除"本批不接真实音乐生成"等过时描述）+ `_buildStorageWarningHint` 注释和文案更新（R2 未配置不再触发此卡片，文案改为"音乐已生成，但暂时无法播放，请稍后再试"）；版本号 `buildLabel` → `P4-temp-audio-playback-1-cleanup`；新增 6.17.11 线上试听结果 + 6.17.12 代码审计清理 + 6.17.13 后续计划（P4下一批结果页体验优化 / P5 持久化存储 / P6 用户与额度 / P7 4090 后端迁移）；验证：node verify 64 passed / flutter analyze No issues / flutter test 273 passed / flutter build web 通过；**产品核心链路已跑通**；详见 6.17.11-6.17.13 |
| 2026-07-23 | v1.0.0 / P4-song-result-experience-1 | P4 生成歌曲结果页体验优化 | **纯前端体验优化**，不改后端真实调用策略（`realCallsEnabled` 默认仍为 `false`，`manualTest=true` 保护保留，不增加自动调用 MiniMax 逻辑 / 不做后台轮询 / 不做自动重试 / 不做 R2 / 不做付费 / 不做用户系统 / 不做 4090）；生成成功后展示完整结果区（`_buildSongResultSection`）：歌曲标题（**本地规则生成**，不新增 LLM 调用，按 `targetState` 映射：sleep→今晚先慢下来 / soothe→把心放轻一点 / focus→慢慢回到这里 / regulate→让心绪落下来 / default→写给现在的你）+ 副文案「根据你刚才写下的内容生成，适合现在慢慢听一遍。」+ 试听这首歌（播放控件）+ 歌词展示 + 状态「已生成，可直接试听」+ 操作按钮；操作按钮：`重新播放`（从头播放，**不再次调用 MiniMax，不扣费**）/ `编辑歌词`（回到编辑态，不丢失歌词）/ `重新生成`（**必须再次弹费用确认**，会真实调用 MiniMax）；生成失败体验（`_buildMusicErrorSection`）：不白屏，温和错误「这次音乐没有顺利生成」+ 副文案 + 保留歌词 + `重试生成`（需费用确认）/ `编辑歌词`；`_buildResult` 渲染逻辑改为「成功结果区 / 失败区 / 存储警告 / 入口按钮」if-else 链；文案合规（无治疗/治愈/诊断/疗法/算命/神谕/命中注定）；版本号 `buildLabel` → `P4-song-result-experience-1`（`app_version.dart` + `health.js` + `verify-provider-adapter.mjs` 测试 63 同步）；新增 6.17.13 章节，原后续计划重编号为 6.17.14；**本批未做** R2/历史/分享/付费/用户系统/4090/LLM title 字段；详见 6.17.13 |

### 13.6 P6-Quota-v1.0（本地额度保护）

| 日期 | 版本 | 阶段 | 摘要 |
|---|---|---|---|
| 2026-07-23 | v1.0.0 / P6-quota-guard-1 | P6 首批 | 本地额度保护与成本安全 + 文档整理：新增 `LocalGenerationQuotaService`（每日 1 次成功生成上限 / 同步方法 / 时钟注入 / JSON 持久化 / 损坏容错）+ service 单元测试（9 项）；`services.dart` 注册 nullable 全局变量 + `main.dart` 第 9 步装配（独立 try/catch + 自检）；`comfort_lyrics_screen.dart` 额度 UI 集成（`_quotaRemaining` 字段 / initState / `_refreshQuotaState` / 两个 guard / `_buildGenerateSongButton` Column 重写 / `_buildQuotaHint` / 成功分支计数 / `_buildSongActionButtons` 重新生成禁用）；版本号同步 `app_version.dart`(`milestone=P6-Quota-v1.0` / `buildLabel=P6-quota-guard-1`) + `health.js` + `verify-provider-adapter.mjs`(测试 45/63)；新增 `docs/ROADMAP.md`；README 定向更新（2.1 / 2.3 / 6.18 / 十 / 十一 / 十三 / 目录）；`docs/mureka-api-integration-plan.md` 历史标注。realCallsEnabled 保持 false / manualTest 保护保留 / 不部署上线 / 不做 R2/付费/用户系统/4090 / 不使用医疗化表达 |
| 2026-07-23 | v1.0.0 / P4-conversation-song-flow-1 | P4 多轮流程 | 多轮困惑理解 + 歌词增强 + 纯音乐本地舒缓 + 定时关闭：`comfort_lyrics_screen.dart` 改为 input→followUp→done 三阶段多轮对话流程（3 轮温和追问 + 跳过 + state 字段 `initialConcern`/`followUpAnswers`/`desiredFeeling`/`comfortDirection`，只存页面 state 不做长期保存）；`comfort_lyrics_service.dart` + `functions/api/comfort-lyrics.js` 多轮上下文校验 + LLM prompt 增强（歌词吸收具体细节 + 结构化要求 + 意象化隐私保护）；`plan_screen.dart` 删除「生成专属音乐（实验）」入口 + 删除 `music_generation_screen.dart` 及测试；新增「快速舒缓一下」CTA（跳转 AnalysisScreen 走本地纯音乐，不触发 MiniMax 不扣额度）；新增 `lib/widgets/sleep_timer_button.dart` 共享定时关闭组件（关闭/5/10/15/30 分钟/播放完当前音频）接入 PlayerScreen + ComfortLyricsScreen AI 歌曲播放区；版本号同步 `app_version.dart`(`milestone=P4-AI-Music-v1.0` / `buildLabel=P4-conversation-song-flow-1`) + `health.js` + `verify-provider-adapter.mjs`；测试文件全面更新适配多轮流程 + 新增 4 个多轮对话测试。realCallsEnabled 保持 false / manualTest 保护保留 / P6 额度保护保留 / 已部署上线（2026-07-23，health 验证 realCallsEnabled=false / buildLabel=P4-conversation-song-flow-1，未触发真实 MiniMax）/ 不做 R2/历史歌曲/分享/付费/用户系统/4090/真实 MiniMax 测试 / 不使用医疗化表达 |
| 2026-07-23 | v1.0.0 / P4-conversation-song-flow-1-fix1 | P4 多轮流程 fix1 | LLM 动态追问 + 歌词贴合度增强 + 快速舒缓纯本地化核查 + 加载文案分阶段：`functions/api/comfort-lyrics.js` 新增 `mode` 参数（`follow_up_questions` 只生成 2-3 个追问 / `comfort_song` 生成歌词）+ `FOLLOW_UP_PROMPT` 引导 LLM 基于用户文字动态生成追问 + `classifyConcern` 6 分类本地兜底（lowEnergy 优先级最高，eventConflict/anxietyStress/guiltRegret/loneliness/unknown）+ `localFollowUpFallback` 兜底问题库 + `normalizeFollowUpQuestions` 规范化；`SYSTEM_PROMPT` 修改：主歌承接用户具体困境，不编造未提及场景（窗台/手机/枕头边），意象服务于用户困境；`lib/pipeline/llm/comfort_lyrics_service.dart` 新增 `fetchFollowUpQuestions` + 本地 6 分类兜底（前后端镜像）；`comfort_lyrics_screen.dart` 新增 `loadingFollowUp` 阶段 + `_dynamicQuestions` + `_buildLoadingHint` 分阶段文案（生成追问/生成歌词/生成歌曲/快速舒缓本地分析各一句）+ 移除 `_loadingFollowUp`/`_desiredFeeling`/`_comfortDirection`/`_FollowUpQuestion`/`_FollowUpOptionChip` 冗余字段与类；`analysis_screen.dart` 加载文案改为「正在为你选择一段适合此刻的纯音乐…」；核查「快速舒缓一下」纯本地化（不调 generate-music/不调 MiniMax/不扣额度/无 MusicGenerationScreen 残留）；版本号同步 `app_version.dart`(`buildLabel=P4-conversation-song-flow-1-fix1`) + `health.js` + `verify-provider-adapter.mjs`；新增 `comfort_lyrics_service_test.dart` 8 项 fix1 测试 + `verify-comfort-lyrics.mjs` 22 项 fix1 测试。realCallsEnabled 保持 false / manualTest 保护保留 / P6 额度保护保留 / 不部署上线 / 不真实调用 MiniMax / 不使用医疗化表达 |
| 2026-07-23 | v1.0.0 / P4-conversation-song-flow-1-fix2 | P4 多轮流程 fix2 | low_energy 场景 + lowEnergy 追问问题对齐 + 歌词低能量指引 + 快速舒缓纯本地化复核：`functions/api/comfort-lyrics.js` 新增 `low_energy` 场景（场景总数 5→6）—— `detectScene` 添加低能量关键词检测（提不起劲/疲惫/累/空/麻木/没动力/不想动），优先级在具体事件场景之后、default 之前（含事件词+低能量词仍归事件场景）；`FALLBACK_TEMPLATES` 新增 `low_energy` 模板（歌词围绕提不起劲/力气不知道去了哪里/不是偷懒是真的空了/今天先不用变好，副歌 hook「慢一点也可以，我在这里」，不写窗台/手机/夜色/城市）；`FOLLOW_UP_FALLBACK_QUESTIONS.lowEnergy` 三问对齐为「这种疲惫和空落感，通常什么时候最明显？/ 你更像是身体累，还是心里没力气？/ 想让这首歌陪你慢慢休息，还是给你一点重新开始的力气？」（不含「这件事里」）；`SYSTEM_PROMPT` 新增 low_energy 场景选项与低能量歌词指引；`lib/pipeline/llm/comfort_lyrics_service.dart` 前后端镜像同步（low_energy 检测 + 模板 + 兜底问题库）；歌词生成仍透传 `initialConcern`+`followUpAnswers`，主歌承接用户困境、不编造未提及场景、副歌温和陪伴话、避免医疗化表达；复核「快速舒缓一下」纯本地化（跳转 AnalysisScreen 走 AudioAssetCatalog，不调 generate-music/不调 MiniMax/不扣额度/无「生成专属音乐（实验）」/无 MusicGenerationScreen 残留），加载文案分阶段保持 fix1；版本号同步 `app_version.dart`(`buildLabel=P4-conversation-song-flow-1-fix2`) + `health.js` + `verify-provider-adapter.mjs`；新增 `low_energy` 场景测试 + low_energy 不覆盖事件场景优先级测试 + 6 场景模板结构验证。manualTest 三重门保护保留 / P6 额度保护保留 / 不真实调用 MiniMax / 不使用医疗化表达 / 未做 R2/历史歌曲/分享/付费/用户系统/4090 |
| 2026-07-24 | v1.0.0 / P4-conversation-song-flow-1-fix2 部署上线 | P4 多轮流程 fix2 部署 | **已部署至 Cloudflare Pages 正式域名**：`flutter build web --release` → `wrangler pages deploy build/web --project-name=xinxian-healing-music`；`/api/health` 验证 `buildLabel=P4-conversation-song-flow-1-fix2` ✅ / `musicProvider=minimax_music` ✅ / `hasMinimaxKey=true` ✅；线上多轮追问已支持 low_energy 场景（LLM 动态生成 + 失败本地 6 分类兜底，lowEnergy 优先级最高，不含「这件事里」）；线上歌词由 LLM 生成并结合原始输入与追问回答；线上「快速舒缓一下」只走本地 AudioAssetCatalog 纯音乐（不调 generate-music / 不调 MiniMax / 不扣额度）；`realCallsEnabled` 为 Cloudflare 环境变量由用户手动管理（不在代码中），manualTest 三重门 + P6 额度保护保留；未做 R2/历史歌曲/分享链接/支付/用户系统/4090 |
| 2026-07-24 | v1.0.0 / P4-playback-experience-2 | P4 播放体验优化 | AI 歌曲独立播放页 + 本地舒缓播放模式增强：新增 `lib/screens/generated_song_player_screen.dart`（AI 歌曲生成成功后跳转至此独立播放，展示歌曲标题/给现在的你/歌词/播放暂停/进度条/重新播放/返回/定时关闭/单曲循环开关，不依赖 R2，使用 `playableUrl` 临时播放，失败显示温和错误提示+重试+返回不白屏）；`lib/screens/comfort_lyrics_screen.dart` 移除内嵌播放器，改为缓存 `GeneratedSongMeta` + 轻量入口卡片「这首歌已经生成好了」+「进入播放页」按钮（支持返回后重新进入不重复生成不重复扣费），生成失败/取消/未成功不跳转不扣额度；`lib/screens/player_screen.dart` 新增 4 种播放模式（单曲播放/单曲循环/列表循环/顺序播放，默认单曲循环），按 targetState 过滤 AudioAssetCatalog 同类曲目组成播放列表（当前每类 1 首，后续扩展自动生效），模式切换用 `setAudioSources`（替代已废弃 ConcatenatingAudioSource）保留进度不中断播放，PopupMenuButton UI + 定时强制态显示「定时中·循环」小标；`lib/widgets/sleep_timer_button.dart` 新增 `onForceLoopStart`/`onForceLoopEnd` 回调，进入倒计时强制单曲循环（保留进度），结束/取消恢复原模式，保证「单曲 3 分钟+定时 5 分钟」不会 3 分钟就停；版本号同步 `app_version.dart`(`buildLabel=P4-playback-experience-2`/`buildDate=2026-07-24`) + `health.js` + `verify-provider-adapter.mjs`；新增 `test/generated_song_player_screen_test.dart` 10 项独立播放页静态 UI 测试 + 更新 `comfort_lyrics_screen_test.dart` 头部注释。manualTest 三重门保护保留 / P6 额度保护保留 / 不真实调用 MiniMax / 不使用医疗化表达 / 快速舒缓仍完全本地化 / 未做 R2/历史歌曲/分享链接/支付/用户系统/4090；详见 6.22 章节 |

### 13.7 项目结构

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
│   ├── comfort_lyrics_screen.dart # P4 新方向第一批：困惑解惑+歌词生成页面
│   └── generated_song_player_screen.dart # P4-playback-experience-2：AI 歌曲独立播放页
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
