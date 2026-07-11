# 心弦 XinXian

> AI 心境解析 + 个性化音乐陪伴 Web 应用

心弦是一款基于 Flutter Web 的情绪陪伴 Demo。用户输入当下心境后，系统通过 LLM 生成情绪画像与音乐参数，并播放匹配的本地音频素材，形成「自然语言 → AI 情绪解析 → 音乐方案 → 音频体验 → 用户反馈」的完整闭环。

- **正式体验地址**：[https://xinxian-music.xyz](https://xinxian-music.xyz)
- **当前版本**：`v0.9.0 · P2-stable · Cloudflare Pages`
- **定位**：辅助情绪调节、睡前舒缓、正念陪伴、温和充能的轻量化工具，**不提供医疗诊断或治疗**，不替代专业心理咨询与医疗建议（详见[第十二章 免责声明](#十二免责声明)）

---

## 目录

1. [项目简介](#一项目简介)
2. [当前状态总览](#二当前状态总览)
3. [核心用户流程](#三核心用户流程)
4. [技术架构](#四技术架构)
5. [已完成里程碑](#五已完成里程碑)
6. [P2-Web-v1.0 收尾成果](#六p2-web-v10-收尾成果)
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

- **阶段**：`P2-Web-v1.0 已完成 / P2-stable`
- **版本号**：`v0.9.0 · P2-stable · Cloudflare Pages`（首页底部显示 `心弦 v0.9.0 · P2-stable · Cloudflare Pages`）
- **构建日期**：2026-07-11
- **部署目标**：Cloudflare Pages

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
- 反馈数据分析与导出（`scripts/feedback-queries.sql` + Wrangler SQL + Cloudflare D1 Console）
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
| **P3-Web-v1.0**（下一阶段） | 数据与反馈运营：基于 D1 已采集数据深化反馈分析（calmnessScore 分布 / targetState 命中 / 音频匹配效果）；补齐 improvement 派生指标（after-before，正值代表状态改善，P3 补齐 D1 端派生）；M8.2 消融对比实验音频旁路落地（generic 固定 `soothe_01.mp3`、control 固定 `sleep_01.mp3`，真正改变推荐结果）；反馈数据可视化轻量方案；可选补 `completionRatio` D1 字段 | 🔜 下一阶段 |
| **P4-AI-Music-v1.0**（必做） | 真正 AI 音乐生成接入（**产品核心升级，非可选项**）：将 `AudioGenerationPort` 从本地预置音频替换为真实 AI 音乐生成模型（如 MusicGen / Suno API），按 `generationPrompt` 实时生成个性化音频；DSP 后处理（白噪音 / 粉红噪音 / EQ / 淡入淡出）接入；异步生成任务；音频存储；fallback 到预置音频；成本与安全控制 | ⏳ 计划中 |
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

### 13.4 项目结构

```
lib/
├── main.dart                      # 应用入口、主题配置、bootstrapServices 装配
├── config/                        # 配置
│   └── app_version.dart           # 应用版本信息单一来源
├── data/                          # 静态数据目录
│   └── audio_asset_catalog.dart   # 本地音频资源目录 + 按 targetState 4 级匹配算法
├── models/                        # 数据模型
│   └── cloud_feedback_payload.dart # 云端上传 payload 模型 + fromFeedback 工厂
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
│   └── llm/                       # LLM 接入（M4）
├── screens/                       # 核心页面
│   ├── home_screen.dart           # 心境输入页
│   ├── analysis_screen.dart       # 情绪解析动画页
│   ├── plan_screen.dart           # 疗愈方案展示页
│   ├── player_screen.dart         # 音频播放页
│   ├── feedback_screen.dart       # 用户反馈页
│   ├── history_screen.dart        # 历史记录页
│   └── privacy_screen.dart        # 隐私政策页
├── theme/                         # 配色与主题
├── utils/                         # 工具函数
│   ├── audio_asset_uri.dart       # Web / 非 Web 平台 AudioSource 路径解析
│   ├── user_agent_helper.dart     # Web 端获取 navigator.userAgent
│   └── recommendation_reason.dart # P2 推荐理由场景化 helper
└── widgets/                       # 通用组件

functions/
└── api/
    ├── analyze-mood.js            # Cloudflare Pages Function（LLM 网关）
    ├── submit-feedback.js         # D1 upsert + 字段白名单 + 长度限制
    └── health.js                  # 健康检查端点

schema/
└── feedback.sql                   # D1 建表 DDL（feedback 表 25 字段 + 4 索引）

scripts/
└── feedback-queries.sql           # 常用 D1 查询脚本（8 条查询 + 附录 B 消融实验查询）

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
