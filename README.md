# 心弦 XinXian

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
| **M8** | 反馈数据分析与导出：新增 `scripts/feedback-queries.sql`（8 条常用 D1 查询 + CSV 导出方式），采用"Wrangler SQL + Cloudflare D1 Console"轻量方案，暂不做公开管理后台；文档化查询命令与 D1 Console 图形化入口；隐私策略明确文字反馈原文不得用于公开材料 | ✅ 已完成 |
| **M8.1** | 消融对比实验设计与分组记录（保守 MVP）：新增 `HashExperimentAssigner`（`lib/pipeline/experiment/hash_experiment_assigner.dart`），按 sessionId FNV-1a hash 稳定分流到 custom / generic / control 三组（默认配比 1:1:1）；通过编译期常量 `ENABLE_EXPERIMENT` 控制（默认 false，零体验影响）；M8.1 保守 MVP 阶段不改变推荐结果，generic / control 组仍走 custom 完整流程，仅记录 `experimentVariant` 标签到 D1；新增 `test/hash_experiment_assigner_test.dart`（稳定性 + 1000 样本分布均匀性 + 自定义配比测试）；`scripts/feedback-queries.sql` 追加附录 B（6 条消融实验分组查询）；真正的音频旁路留到 M8.2 | ✅ 已完成 |

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

### P1-Web-v1.0 第三批产品化修复

第三批产品化修复聚焦历史记录数据完整性、移动端小屏适配与 Web 元信息补齐，不改 API、D1 schema、pipeline 与播放器核心逻辑。

**改动目的**：

1. 修复历史记录撤销删除时丢失原始 `startedAt` 时间戳的问题（原先撤销会以 `DateTime.now()` 重置时间，导致排序错乱）
2. 修复 `analysis_screen` 在移动端小屏（高度受限）时呼吸圆与文案溢出的问题，改为基于 `LayoutBuilder` 的响应式尺寸
3. 补齐 `index.html` 元信息（`description` / `theme-color`），改善 SEO 与移动端浏览器 UI 一致性
4. 历史记录空状态增加"创建第一条音乐方案" CTA，避免用户在空状态卡死

**涉及模块**：

- **会话恢复抽象**：`ListeningSessionRecorder` 新增 `restore(ListeningSession)` 抽象方法，支持完整还原会话（含原始 `startedAt`）
- **本地持久化实现**：`LocalListeningSessionRecorder` / `MockListeningSessionRecorder` 实现 `restore`，内部走 `_upsert` 语义
- **历史记录撤销逻辑**：[history_screen.dart](file:///d:/xinxian_healing_music/lib/screens/history_screen.dart) 撤销操作从"重新 begin"改为调用 `restore(session)`，完整保留原始 `startedAt` / `listenedDuration` / `feedback`
- **解析动画页响应式**：[analysis_screen.dart](file:///d:/xinxian_healing_music/lib/screens/analysis_screen.dart) 使用 `LayoutBuilder` 按可用宽高较小者的 55% 计算呼吸圆区域，限制 180-260，超出时可滚动
- **Web 元信息**：[index.html](file:///d:/xinxian_healing_music/web/index.html) 新增 `<meta name="description">` 与 `<meta name="theme-color">`
- **单元测试**：[local_storage_test.dart](file:///d:/xinxian_healing_music/test/local_storage_test.dart) 新增 `restore 恢复已删除会话时保留原始 startedAt` 测试（含重启后一致性验证）

**验证结果**：

- `flutter analyze`：No issues found! (ran in 2.9s)
- `flutter test`：196 passed + 5 skipped（含新增 restore 测试）
- `flutter build web --release`：√ Built `build\web` (29.0s)

**当前状态（未改动）**：

- `functions/api/*.js`（API 协议不变）
- `schema/feedback.sql` / D1 schema（零迁移）
- pipeline 核心逻辑（推荐链路不变）
- 播放器核心逻辑（本批未改）
- 未引入新依赖

### P1-Web-v1.0 第四批产品化修复

第四批产品化修复聚焦 Cloudflare Pages Functions 的稳定性、安全边界与可运维性，新增健康检查端点、D1 写入超时保护与 CORS 白名单。不改 API 协议、D1 schema、前端调用方式与 Flutter 页面逻辑。

**改动目的**：

1. 新增 `/api/health` 健康检查端点，用于快速判断 Functions 是否正常部署，便于运维监控
2. `submit-feedback` 对 D1 写入增加 5000ms 显式超时保护，超时返回 fallback 不抛未捕获异常
3. 收紧 CORS 边界：将 `Access-Control-Allow-Origin` 从无脑 `*` 改为白名单逻辑（正式域名 + Cloudflare 预览域名 + 本地开发），保留 curl / PowerShell 命令行测试可用性

**涉及模块**：

- **新增健康检查**：[functions/api/health.js](file:///d:/xinxian_healing_music/functions/api/health.js) — `GET /api/health` 返回 `{ ok, service, version, timestamp }`，不访问 D1 / LLM / env，支持 OPTIONS 预检
- **D1 超时保护**：[functions/api/submit-feedback.js](file:///d:/xinxian_healing_music/functions/api/submit-feedback.js) — 新增 `withTimeout(promise, ms, reason)` helper，用 `Promise.race` 让 D1 INSERT 在 5000ms 内必须完成
- **CORS 白名单**：[functions/api/analyze-mood.js](file:///d:/xinxian_healing_music/functions/api/analyze-mood.js) + [submit-feedback.js](file:///d:/xinxian_healing_music/functions/api/submit-feedback.js) + [health.js](file:///d:/xinxian_healing_music/functions/api/health.js) — 三个文件统一引入 `allowedOrigin(origin)` 函数

**CORS 允许来源**：

| 来源 | 说明 |
|---|---|
| `https://xinxian-music.xyz` | 正式域名 |
| `https://www.xinxian-music.xyz` | 正式域名 www 子域 |
| `https://xinxian-healing-music.pages.dev` | Cloudflare Pages 主预览域名 |
| `https://*.xinxian-healing-music.pages.dev` | Cloudflare Pages 分支 / 部署预览域名 |
| `http://localhost:*` / `http://127.0.0.1:*` | 本地开发 |
| 无 Origin（curl / PowerShell） | 回退到正式域名，不阻塞命令行测试 |

**D1 超时保护实现**：

用 `Promise.race` 让 D1 INSERT 与 5000ms 定时器竞争。超时只触发 Promise 层面的 reject，D1 实际操作可能仍在后台执行（Workers 有自己的执行时限，5 秒超时基本不会触发，仅作兜底）。超时后返回 `{ ok: false, received: false, reason: 'db_timeout' }`，不抛未捕获异常，不影响前端本地保存。

**测试命令**：

```bash
# 健康检查（GET，无 body）
curl https://xinxian-music.xyz/api/health

# 预期返回
# { "ok": true, "service": "xinxian-functions", "version": "v1", "timestamp": "2026-..." }
```

**验证结果**：

- `node --check functions/api/health.js`：通过
- `node --check functions/api/submit-feedback.js`：通过
- `node --check functions/api/analyze-mood.js`：通过
- `flutter analyze`：No issues found! (ran in 3.3s)
- `flutter test`：196 passed + 5 skipped（与第三批一致，无回归）
- `flutter build web --release`：√ Built `build\web` (27.6s)

**当前状态（未改动）**：

- `schema/feedback.sql` / D1 schema（零迁移）
- 前端 API 调用方式（`HttpCloudFeedbackUploader` 6 秒超时不变，本次只改 Pages Function 端）
- Flutter 页面逻辑
- LLM prompt
- `wrangler.toml` 模型配置
- 未引入新依赖

### P1-Web-v1.0 小质量修复：targetState 枚举统一

线上测试 `/api/analyze-mood` 时发现 LLM 偶发返回 `targetState: "relax"` 旧值，但项目音乐匹配主线只使用五类：`sleep / regulate / soothe / focus / energize`。本次修复在后端将枚举统一到五类，不改 API 结构、不改前端、不改音乐匹配主逻辑。

**改动目的**：

1. 强化 System Prompt：明确 `targetState` 只能是五个之一，禁止 `relax` / `company` 旧值，并增加归一规则说明
2. `normalizeMood` 增加旧值归一：LLM 偶发返回 `relax` / `company` 时映射为 `soothe`，不触发 fallback，保留其他字段

**涉及模块**：

- [functions/api/analyze-mood.js](file:///d:/xinxian_healing_music/functions/api/analyze-mood.js)
  - `SYSTEM_PROMPT`：枚举改为 `sleep / regulate / soothe / focus / energize`，新增"targetState 归一规则"段落，平淡输入默认 `soothe`
  - `normalizeMood`：`VALID_TARGET_STATES` 改为五类；`relax` / `company` 归一为 `soothe`；其他非法值 fallback 为 `soothe`

**targetState 归一规则（写入 prompt）**：

| 用户输入特征 | targetState |
|---|---|
| 睡不着 / 想睡觉 / 入眠困难 / 失眠 | `sleep` |
| 压力大 / 焦虑 / 情绪波动 / 需要稳定下来 / 紧绷 | `regulate` |
| 想放松一下 / 有点累 / 想舒缓 / 低落 / 难过 / 想被安慰 | `soothe` |
| 想学习 / 想专注 / 工作效率 / 集中注意力 | `focus` |
| 没精神 / 想提振 / 刚睡醒很困 / 提不起劲 | `energize` |

**旧值归一逻辑**：

- LLM 返回 `relax` → 归一为 `soothe`（语义最接近"正念陪伴 / 想放松"）
- LLM 返回 `company` → 归一为 `soothe`（旧 `company` 语义已并入 `soothe`）
- LLM 返回其他非法值 → fallback 为 `soothe`（与 prompt 平淡输入默认一致）
- 归一不触发 fallback，保留 `tags` / `summary` / `valence` 等其他字段

**验证结果**：

- `node --check functions/api/analyze-mood.js`：通过
- `flutter analyze`：No issues found! (ran in 3.2s)
- `flutter test`：196 passed + 5 skipped（无回归）
- `flutter build web --release`：√ Built `build\web` (27.0s)

**当前状态（未改动）**：

- Flutter 前端页面（`TargetStateResolver` / `EmotionToMusicPlanMapper` 已在 M6.1 支持五类）
- D1 schema
- `functions/api/submit-feedback.js`
- `wrangler.toml` 模型配置
- 音频资源
- 音乐匹配主逻辑（`AudioAssetCatalog` 已按五类 targetState 匹配）
- 不改变 API 响应 JSON 结构

### P1-Web-v1.0 限流规则配置记录（Cloudflare Dashboard）

> **说明**：本节记录 Cloudflare Dashboard 中已配置的 Rate Limiting Rule。规则在 Cloudflare 边缘节点生效，不修改本项目代码。当前状态：**analyze-mood 规则已配置并 Active**；submit-feedback 规则因 Free 计划限流规则数量上限（1/1）未配置，列为后续可选。

**目的**：降低 `/api/analyze-mood` 被滥用导致 LLM 额度消耗的风险。

**配置入口**：Cloudflare Dashboard → 选择域名 `xinxian-music.xyz` → Security → WAF → Rate limiting rules → Create rule

**规则 1：/api/analyze-mood（已配置）**

| 项 | 值 |
|---|---|
| Rule name | `xinxian-analyze-mood-limit` |
| 匹配条件 | `http.host` equals `xinxian-music.xyz` AND `http.request.uri.path` equals `/api/analyze-mood` AND `http.request.method` equals `POST` |
| 阈值 | 同一 IP 1 分钟 10 次 |
| 当前 Action | **Block**（Free 计划当前使用，超过阈值直接拦截请求） |
| 状态 | Active |
| 后续可选 | 若套餐升级支持 Managed Challenge，可切换为 Managed Challenge（真人可通过验证码，误伤可恢复） |

当前使用 Block 的说明：Free 计划限流规则 Action 选项有限，当前选择 Block 直接拦截超阈值请求。Block 对脚本滥用有明确阻断效果；误伤真人用户时需等待统计窗口（1 分钟）过期后自动恢复。心弦前端已有 LLM 失败 fallback 到 mock 分析的逻辑，被 Block 时用户仍可正常使用（降级为本地解析模式）。

**规则 2：/api/submit-feedback（未配置，后续可选）**

| 项 | 值 |
|---|---|
| 状态 | 未配置 |
| 原因 | Cloudflare Free 计划限流规则数量上限为 1 条（当前已用 1/1 配置 analyze-mood） |
| 后续可选配置 | Rule name: `xinxian-submit-feedback-limit`；匹配条件同规则 1 但路径改为 `/api/submit-feedback`；阈值：同一 IP 1 分钟 30 次；Action: Block 或 Managed Challenge |

30 次而非 10 次的原因：反馈是本地保存 + 异步上传，撤销删除 + 重新反馈可能触发多次，30 次/分钟对正常用户绰绰有余。如套餐升级解锁更多规则数量，可补配置此规则。

**/api/health 限流建议**：不需要限流。该端点不访问 D1 / LLM / env，几乎零成本，用于运维监控和状态页探活，限流会导致监控误报。

**配置测试**：配置后等待 ~1 分钟传播，用 PowerShell 连续发送 11 次 analyze-mood 请求，前 10 次返回 200 + JSON，第 11 次应返回 403（Block 动作直接拦截）。等待 1 分钟后应自动恢复。

**前端兼容性**：心弦前端已有 LLM 失败 fallback 到 mock 分析的逻辑，被限流时用户仍可正常使用（降级为本地解析模式）。

### P1-Web-v1.0 PWA / 缓存策略最小实施

> **说明**：本节记录 PWA / 缓存策略的最小实施方案。**只新增 `web/_headers` 缓存头策略，没有启用离线 PWA，没有手写 service worker**。保留 Flutter 默认 SW 机制，通过 Cloudflare Pages `_headers` 控制各路径缓存行为。

**实施背景**：之前出现过浏览器缓存 / Service Worker 导致线上页面不是最新的问题。根因是 `_headers` 缺失导致缓存策略不可控。本次通过显式 Cache-Control 头解决，不引入离线逻辑。

**新增文件**：[web/_headers](file:///d:/xinxian_healing_music/web/_headers)

**各路径 Cache-Control 策略**：

| 路径 | Cache-Control | 理由 |
|---|---|---|
| `/` 和 `/index.html` | `no-cache, must-revalidate` | 必须总能拿到最新 `main.dart.js` 引用 |
| `/main.dart.js` | `no-cache, must-revalidate` | 代码核心，跟随 SW 内部 hash 校验 |
| `/flutter_bootstrap.js` | `no-cache, must-revalidate` | 引导脚本，变更频繁 |
| `/flutter.js` | `no-cache, must-revalidate` | Flutter 核心脚本 |
| `/flutter_service_worker.js` | `no-cache, must-revalidate` | SW 自身必须能更新，避免死锁 |
| `/manifest.json` | `max-age=3600, public` | 短缓存（1 小时） |
| `/assets/music/*` | `public, max-age=86400, must-revalidate` | 中长缓存（1 天）+ revalidate，体积大少变更 |
| `/canvaskit/*` | `max-age=604800, public` | 长缓存（7 天），跟随 Flutter 版本 |
| 其他 assets（字体/shaders） | Cloudflare 默认缓存 | 移除 `/assets/*` 通用规则，避免覆盖音频规则 |
| `/api/*` | `no-store` | API 绝不缓存 |

**明确未做的事项**：

- **没有启用离线 PWA**：心弦核心功能依赖 `/api/analyze-mood`（LLM 调用），无网络时只能 fallback 到 mock 分析，离线 PWA 价值有限
- **没有手写 service worker**：保留 Flutter 默认 `flutter_service_worker.js`，未替换或增强
- **没有修改 Flutter 页面**：前端逻辑未改
- **没有修改 API**：API 协议未改
- **没有修改 D1 schema**

**build 验证**：

- `flutter build web --release` 后 `build/web/_headers` 存在（Flutter build 自动复制 `web/_headers` 到 `build/web/`）
- 部署到 Cloudflare Pages 后，`_headers` 会自动生效

**部署后验证方式**：

```powershell
# 检查各路径响应头
curl -I https://xinxian-music.xyz/index.html
# 预期：cache-control: no-cache, must-revalidate

curl -I https://xinxian-music.xyz/flutter_service_worker.js
# 预期：cache-control: no-cache, must-revalidate

curl -I https://xinxian-music.xyz/assets/music/sleep_01.mp3
# 预期：cache-control: max-age=86400, public, must-revalidate

curl -I https://xinxian-music.xyz/api/health
# 预期：cache-control: no-store
```

**第一次线上验证结果**（部分规则未达预期）：

| 路径 | 预期 | 实际 | 状态 |
|---|---|---|---|
| `/api/health` | `no-store` | `no-store` | ✅ 生效 |
| `/index.html` | `no-cache, must-revalidate` | 基本正常 | ✅ 生效 |
| `/flutter_service_worker.js` | `no-cache, must-revalidate` | `max-age=14400, must-revalidate` | ❌ 未生效 |
| `/assets/music/sleep_01.mp3` | `max-age=86400, must-revalidate` | `max-age=14400, must-revalidate` | ❌ 未生效 |

**第一次修正原因**：

1. `/assets/music/*.mp3` 使用扩展名通配 `*.mp3`，Cloudflare Pages 可能不支持"目录 + 扩展名通配"组合 → 改为 `/assets/music/*`
2. `/assets/*` 通用规则在 `/assets/music/*` 之后，可能覆盖音频规则 → 移除 `/assets/*` 通用规则，非 music 的 assets 使用 Cloudflare 默认缓存
3. `/flutter_service_worker.js` 保持单独配置不变，待二次验证确认是否为 Cloudflare Pages 对 `.js` 文件的默认缓存策略覆盖

**第三次线上验证结果**（全部通过）：

| 路径 | 实际响应头 | Cf-Cache-Status | 结论 |
|---|---|---|---|
| `/assets/music/sleep_01.mp3` | `Cache-Control: public, max-age=86400, must-revalidate` | MISS / 后续 HIT | ✅ 音频缓存策略已生效 |
| `/api/health` | `Cache-Control: no-store` | DYNAMIC | ✅ API 不缓存策略已生效 |
| `/flutter_service_worker.js` | `Cache-Control: no-cache, must-revalidate, no-cache, must-revalidate` | DYNAMIC | ✅ SW 不走边缘缓存目标已达成 |

**flutter_service_worker.js 说明**：

- 通过 Cloudflare Cache Rule + `_headers` 达到不走边缘缓存目标
- `Cache-Control` 出现重复值（`no-cache, must-revalidate, no-cache, must-revalidate`），语义一致，可接受
- 后续可选清理为单值，但不影响功能

> **状态：已验证通过**。三条核心路径（音频 / API / SW）缓存策略均已生效。

**本次实施未修改的内容**（明确说明）：

- **没有修改 service worker 逻辑**：保留 Flutter 默认 `flutter_service_worker.js`，未替换或增强
- **没有新增离线缓存逻辑**：未启用离线 PWA，未手写 service worker
- **没有修改 Flutter 页面**：前端逻辑未改
- **没有修改 API**：API 协议未改
- **没有修改 D1 schema**

**验证结果**（本地 build）：

- `flutter analyze`：No issues found! (ran in 43.1s)
- `flutter test`：196 passed + 5 skipped（无回归）
- `flutter build web --release`：√ Built `build\web` (42.2s)
- `build/web/_headers` 存在

### P1-Web-v1.0 收尾验收清单

> **说明**：本节为 P1-Web-v1.0 阶段收尾总验收记录。**只核对文档与代码/线上配置一致性，不做功能开发**，未修改 Flutter 业务代码、`functions/api/*.js`、`schema/feedback.sql`、`web/_headers` 与 `wrangler.toml`。未验证或未实现的内容均未写成已完成。

#### A. 文档与代码 / 线上配置一致性核对

| 验收项 | README 章节 | 实际代码 / 配置 | 一致性 |
|---|---|---|---|
| history restore 完整链路 | P1-Web-v1.0 第三批产品化修复 | [history_screen.dart](file:///d:/xinxian_healing_music/lib/screens/history_screen.dart) `sessionRecorder.restore(session)` + [listening_session_recorder.dart](file:///d:/xinxian_healing_music/lib/pipeline/ports/listening_session_recorder.dart) 抽象方法 + [local_listening_session_recorder.dart](file:///d:/xinxian_healing_music/lib/pipeline/local/local_listening_session_recorder.dart) `_upsert` 实现 | ✅ 一致 |
| analysis_screen 响应式 | 同上 | [analysis_screen.dart](file:///d:/xinxian_healing_music/lib/screens/analysis_screen.dart) `LayoutBuilder` + 180-260 clamp + `SingleChildScrollView` + try/catch 错误态 | ✅ 一致 |
| index.html 元信息 | 同上 | [index.html](file:///d:/xinxian_healing_music/web/index.html) `<meta name="description">` + `<meta name="theme-color" content="#6BAED6">` | ✅ 一致 |
| 隐私政策页面 | P1-Web-v1.0 第二批（README 散见各处） | [privacy_screen.dart](file:///d:/xinxian_healing_music/lib/screens/privacy_screen.dart) 8 小节静态文本 | ✅ 一致 |
| `/api/health` 端点 | P1-Web-v1.0 第四批产品化修复 | [functions/api/health.js](file:///d:/xinxian_healing_music/functions/api/health.js) `onRequestGet` + `onRequestOptions`，返回 `{ ok, service, version, timestamp }`，不访问 D1 / LLM / env | ✅ 一致 |
| D1 写入超时保护 | 同上 | [functions/api/submit-feedback.js](file:///d:/xinxian_healing_music/functions/api/submit-feedback.js) `withTimeout` + `D1_TIMEOUT_MS = 5000` + `Promise.race` | ✅ 一致 |
| CORS 白名单 | 同上 | 三个 `functions/api/*.js` 统一 `allowedOrigin(origin)`，覆盖正式域名 / Pages 预览 / localhost | ✅ 一致 |
| targetState 枚举统一 | P1-Web-v1.0 小质量修复 | [analyze-mood.js](file:///d:/xinxian_healing_music/functions/api/analyze-mood.js) `VALID_TARGET_STATES` 五类 + `relax` / `company` → `soothe` + prompt 归一规则 | ✅ 一致 |
| 限流规则 `/api/analyze-mood` | P1-Web-v1.0 限流规则配置记录 | Cloudflare Dashboard（不在代码仓库内）：`xinxian-analyze-mood-limit`，Block，10 次/分钟，Active | ✅ 一致（已配置） |
| 限流规则 `/api/submit-feedback` | 同上 | Cloudflare Free 计划规则上限 1/1，未配置 | 🔶 后续可选（与 README 一致） |
| PWA / 缓存策略 | P1-Web-v1.0 PWA / 缓存策略最小实施 | [web/_headers](file:///d:/xinxian_healing_music/web/_headers) 各路径 Cache-Control，三路径线上已验证通过 | ✅ 一致 |
| `schema/feedback.sql` | M7.0 / 第四批（多处引用未改动声明） | 25 字段 + 主键 `listeningSessionId` + upsert + 4 索引，本阶段未迁移 | ✅ 一致（本批未改） |

#### B. 核心线上流程手动验收清单

| 验收项 | 验证方式 | 预期结果 | 状态 |
|---|---|---|---|
| `/api/health` | `curl https://xinxian-music.xyz/api/health` | `200` + `{ ok:true, service:"xinxian-functions", version:"v1", timestamp:... }` | ✅ 端点已部署，可验收 |
| `/api/analyze-mood` | `POST` 心境文本（含合法 `text` 字段） | `200` + `{ ok:true, source:"llm"\|"fallback", mood:{...} }`，targetState 必为五类之一 | ✅ 端点已部署，可验收 |
| `/api/submit-feedback` | `POST` 反馈数据（含 `listeningSessionId` / `createdAt` / `source`） | `200` + `{ ok:true, received:true }` 或 `{ ok:false, received:false, reason:... }` fallback | ✅ 端点已部署，可验收 |
| D1 `feedback` 表记录数 | `npx wrangler d1 execute xinxian-feedback --remote --command "SELECT COUNT(*) AS total FROM feedback"` | 返回总反馈数 | ✅ 表与索引已就绪，可验收 |
| 首页到播放页完整流程 | 浏览器走"心境输入 → 解析 → 方案 → 播放" | 完整闭环可走通，无卡死 | ✅ M4 已 9 步验收（沿用） |
| 反馈提交 | 反馈页提交 → 本地保存 → 异步上传（需同意） | 本地必定保存；云端上传失败不影响本地 | ✅ 链路已就绪，可验收 |
| PWA / 缓存策略三路径 | `curl -I` 检查三路径响应头 | 音频 `max-age=86400` / API `no-store` / SW `no-cache, must-revalidate` | ✅ 三路径已线上验证通过 |

> 说明：本清单只列出"具备验收条件"的项目；具体每次回归是否通过，由验收人在执行时记录。`/api/analyze-mood` 限流为 Block 动作，连续测试请预留 1 分钟统计窗口。

#### C. P1 当前可关闭的项目

| 项目 | 状态 | 关闭依据 |
|---|---|---|
| P1-Web-v1.0 第三批产品化修复 | ✅ 可关闭 | history restore / analysis_screen 响应式 / index.html 元信息 / 历史空状态 CTA 均已实施并通过 `flutter analyze` + `flutter test` + `flutter build web --release` |
| P1-Web-v1.0 第四批产品化修复 | ✅ 可关闭 | `/api/health` / D1 超时 / CORS 白名单均已实施，`node --check` 与 flutter 三件套通过 |
| P1-Web-v1.0 targetState 枚举统一 | ✅ 可关闭 | prompt 强化 + `normalizeMood` 旧值归一，`node --check` + flutter 三件套通过 |
| P1-Web-v1.0 PWA / 缓存策略 | ✅ 可关闭 | `web/_headers` 已实施，三路径线上验证通过 |
| P1-Web-v1.0 限流规则（analyze-mood） | ✅ 可关闭 | Cloudflare Dashboard 已配置并 Active |

#### D. 仍建议保留到下一阶段的项目

| 项目 | 当前状态 | 保留原因 |
|---|---|---|
| 完整离线 PWA / SW 更新提示 UI | 🔶 后续可选 | 本阶段未启用离线 PWA，未手写 service worker，未做 SW 更新提示 UI；保留 Flutter 默认 SW 机制 |
| `/api/submit-feedback` 限流规则 | 🔶 后续可选 | Cloudflare Free 计划限流规则数量上限 1/1（已用于 analyze-mood）；待套餐升级后补配置 |
| `/api/analyze-mood` 限流 Action 切换为 Managed Challenge | 🔶 后续可选 | Free 计划当前仅 Block；Managed Challenge 需套餐升级支持 |
| `flutter_service_worker.js` Cache-Control 重复值清理为单值 | 🔶 后续可选 | 当前为 `no-cache, must-revalidate, no-cache, must-revalidate`，语义一致不影响功能 |
| M8.2 消融对比实验音频旁路 | 🔜 下一阶段 | M8.1 仅记录 `experimentVariant` 标签，未改变推荐结果；音频旁路按计划留到 M8.2 |
| M9 AI 音乐生成模型接入 | ⏳ 计划中 | 当前仍为本地预置音频，非实时 AI 生成 |

#### E. 本次验收未修改的内容（明确说明）

- **没有修改 Flutter 业务代码**：`lib/` 下所有文件保持原状
- **没有修改 `functions/api/*.js`**：`analyze-mood.js` / `submit-feedback.js` / `health.js` 保持原状
- **没有修改 `schema/feedback.sql`**：D1 schema 零迁移
- **没有修改 `web/_headers`**：缓存头策略保持上一轮最终验证通过版本
- **没有修改 `wrangler.toml`**：模型配置 / D1 binding / 环境变量保持原状
- **没有修改 Cloudflare Dashboard 配置**：限流规则 / Cache Rule 保持上一轮已配置状态
- **仅新增本 README 章节**："P1-Web-v1.0 收尾验收清单"，其余章节保持原状

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
- **M8：反馈数据分析与导出**（`scripts/feedback-queries.sql` + Cloudflare D1 Console）
  - 新增 `scripts/feedback-queries.sql`，包含 8 条常用 D1 查询：总反馈数 / targetState 分布 / audioAssetId 平均评分 / 最近 20 条反馈 / 每日反馈数量 / freeTextFeedback 非空数量 / 实验分组统计 / 文字反馈原文查看（隐私敏感）
  - 采用"Wrangler SQL + Cloudflare D1 Console"轻量方案，暂不做公开管理后台
  - 支持 CSV 导出（wrangler `--json` + jq / D1 Console 复制 / Python 脚本）
  - 隐私策略：`moodText` 不存在于 D1；文字反馈原文仅供项目组内部分析，不得用于公开报告 / PPT
- **M8.1：消融对比实验设计与分组记录（保守 MVP）**（`HashExperimentAssigner` + `ENABLE_EXPERIMENT` 编译期开关）
  - 新增 `HashExperimentAssigner`（`lib/pipeline/experiment/hash_experiment_assigner.dart`），按 sessionId FNV-1a hash 稳定分流到 custom / generic / control 三组（默认配比 1:1:1）
  - FNV-1a 32-bit 纯算法实现，跨平台跨版本确定性一致，无第三方依赖；同 sessionId 多次调用结果稳定
  - 通过编译期常量 `ENABLE_EXPERIMENT` 控制：默认 false，恒返回 `custom`，线上不传 `--dart-define` 时用户体验与 M8 完全一致
  - 启用方式：`flutter build web --release --dart-define=ENABLE_EXPERIMENT=true`
  - **保守 MVP 边界**：M8.1 只打通"分组记录能力"，generic / control 组仍走 custom 的完整推荐流程（不改变 `StockAudioGenerator` 与 `HealingPipeline` 推荐逻辑），仅记录 `experimentVariant` 标签到 D1；真正的音频旁路留到 M8.2
  - 新增 `test/hash_experiment_assigner_test.dart`：覆盖 enabled=false 回退、稳定性、1000 样本分布均匀性（每组占比 20%-50% 且不为 0）、自定义配比、边界场景
  - `scripts/feedback-queries.sql` 追加附录 B（6 条消融实验分组查询）：每组反馈数 + 平均评分 / targetState 分布 / audioAssetId 分布 / analyzerMode 分布 / 反馈提交率代理 / 最近实验反馈记录
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
| **M8** | 反馈数据分析与导出：`scripts/feedback-queries.sql` 常用 SQL 查询 + Cloudflare D1 Console 图形化入口 + CSV 导出方式，采用 Wrangler SQL 轻量方案，暂不做公开管理后台                                                                                                  | ✅ 已完成 |
| **M8.1** | 消融对比实验分组记录（保守 MVP）：`HashExperimentAssigner` 按 sessionId FNV-1a hash 稳定分流到 custom / generic / control 三组（默认 1:1:1），编译期常量 `ENABLE_EXPERIMENT` 控制启用（默认 false 零体验影响），M8.1 仅记录分组标签不改推荐逻辑，音频旁路留到 M8.2 | ✅ 已完成 |
| **M8.2**（下一阶段） | 消融对比实验音频旁路：在 `StockAudioGenerator` 按 `experimentVariant` 分流，generic 固定 `soothe_01.mp3`、control 固定 `sleep_01.mp3`，真正改变推荐结果；可选补 `completionRatio` D1 字段 | 🔜 下一阶段 |
| **M9**             | AI 音乐生成模型接入：将 `AudioGenerationPort` 从本地预置音频替换为真实 AI 音乐生成模型（如 MusicGen / Suno API），按 `generationPrompt` 实时生成个性化音频                                              | ⏳ 计划中   |
| **P1-Web-v1.0**（部分完成） | Cloudflare Dashboard 限流规则：`/api/analyze-mood` 已配置（Block，10 次/分钟，Active）；`/api/submit-feedback` 未配置（Free 计划规则上限 1/1，后续可选）。详见下方专门章节 | 🔶 部分完成 |
| **P1-Web-v1.0** | PWA / 缓存策略：`web/_headers` 缓存头策略已实施并验证通过（音频 / API / SW 三路径全部生效）；完整离线 PWA / SW 更新提示为后续可选 | ✅ 已完成 |

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

scripts/
└── feedback-queries.sql           # M8 常用 D1 查询脚本（8 条查询 + CSV 导出方式 + 隐私警告）

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

## 十六、反馈数据分析与导出（M8）

M7.0 已将匿名结构化反馈写入 Cloudflare D1 `feedback` 表，M8 提供轻量数据分析能力，用于项目验收、比赛答辩和后续实验分析。

### 当前方案：Wrangler SQL + Cloudflare D1 Console

M8 采用**轻量方案**，通过 Wrangler CLI 或 Cloudflare Dashboard 图形化界面执行 SQL 查询，不新增后台 API、不新增管理页面。

**为什么暂不做公开管理后台**：

- **数据量小**：当前处于初赛 Demo 阶段，反馈数据量 < 1000 条，手动 SQL 完全够用
- **避免暴露 admin API**：公开管理 API 需要 ADMIN_TOKEN 保护，增加攻击面和 token 泄露风险
- **降低安全风险**：D1 数据库仅管理员通过 wrangler / Dashboard 访问，不存在未授权访问问题
- **足够支持验收和答辩**：D1 Console 表格截图 + CSV 导出足以支撑"数据闭环已跑通"的论证
- **不过度工程**：当前阶段做管理后台属于过早优化，后续数据量增大或需频繁查询时再升级

### 常用查询命令

查询脚本已脚本化到 `scripts/feedback-queries.sql`，包含 8 条常用查询 + CSV 导出方式。

**单条查询**（最常用）：

```bash
# 总反馈数
npx wrangler d1 execute xinxian-feedback --remote --command "SELECT COUNT(*) FROM feedback"

# targetState 分布
npx wrangler d1 execute xinxian-feedback --remote --command "SELECT targetState, COUNT(*) AS count FROM feedback GROUP BY targetState ORDER BY count DESC"

# 最近 20 条反馈（不含文字原文）
npx wrangler d1 execute xinxian-feedback --remote --command "SELECT listeningSessionId, substr(createdAt,1,19) AS created_at, targetState, relaxationScore, calmnessScore FROM feedback ORDER BY createdAt DESC LIMIT 20"
```

**整文件执行**（本地预览全部查询）：

```bash
npx wrangler d1 execute xinxian-feedback --remote --file=./scripts/feedback-queries.sql
```

### Cloudflare Dashboard 图形化入口

不熟悉命令行的项目成员可通过 Cloudflare Dashboard 图形化界面执行查询：

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 左侧导航 → **Storage & Databases** → **D1 SQL Database**
3. 选择数据库 **xinxian-feedback**
4. 点击 **Console** / **Query** 标签
5. 粘贴 SQL 语句 → **Execute** → 查看结果表格
6. 可直接复制结果到 Excel / CSV

### CSV 导出

```bash
# 方式 1：wrangler --json + jq 转 CSV（需安装 jq）
npx wrangler d1 execute xinxian-feedback --remote \
  --command "SELECT substr(createdAt,1,10) AS date, targetState, audioAssetId, relaxationScore, calmnessScore FROM feedback ORDER BY createdAt DESC" \
  --json | jq -r ".[0].results | (.[0] | keys) as $keys | ($keys | @csv), (.[] | [.$keys[]] | @csv)" > feedback_export.csv

# 方式 2：Cloudflare Dashboard → D1 → Console 执行 SQL → 复制结果到 Excel → 另存为 CSV
```

### 查询清单

`scripts/feedback-queries.sql` 包含以下查询：

| 编号 | 查询 | 用途 |
|---|---|---|
| 1 | 总反馈数 | 项目验收首页数据 |
| 2 | targetState 分布 | 了解 5 类目标状态使用分布 |
| 3 | audioAssetId 平均评分 | 评估不同音频素材的反馈差异 |
| 4 | 最近 20 条反馈 | 快速查看最新反馈趋势 |
| 5 | 每日反馈数量 | 查看反馈增长趋势 |
| 6 | freeTextFeedback 非空数量 | 衡量用户深度参与度 |
| 7 | 实验分组统计 | 为 M8.1 消融实验准备基线数据 |
| 8 [隐私敏感] | 文字反馈原文查看 | 内部分析用户真实感受 |

### 隐私说明

- **`moodText` 不存在于 D1**：M7 设计就不上传心境原文，D1 中无此字段
- **`freeTextFeedback` 只在用户单独勾选时上传**：默认不上传，需用户主动勾选"同时上传本次文字反馈"
- **文字反馈原文不得直接放入公开报告 / PPT**：`scripts/feedback-queries.sql` 中查询 8 标注 `[隐私敏感]`，仅供项目组内部分析使用
- **报告中只使用聚合统计或脱敏摘要**：如"用户反馈集中在放松 / 入睡主题"，不展示原文
- **查询结果含 sessionId / userAgent 等**：仅用于分析，不公开发布
- **`experimentVariant` 用于匿名体验分析**（M8.1 新增）：记录用户所在的实验分组（custom / generic / control），基于 sessionId hash 稳定生成，不关联用户身份，不基于心境原文分组；详见十七章

## 十七、消融对比实验设计与分组记录（M8.1）

### 17.1 目标

设计适合"心弦"当前阶段的轻量消融实验，比较不同音乐推荐策略下用户主观反馈的差异，服务项目报告与答辩。指标基于 D1 现有字段（`relaxationScore` / `calmnessScore` / `targetState` / `audioAssetId` / 反馈提交数），**不做医疗效果声明**，只描述主观反馈和体验偏好。

### 17.2 当前方案：保守 MVP

M8.1 采用**保守 MVP**策略，只打通"分组记录能力"，不改变线上用户体验：

| 维度 | M8.1（当前） | M8.2（下一阶段） |
|---|---|---|
| 是否启用分组 | 默认关闭，编译期常量控制 | 默认开启或常开 |
| `experimentVariant` 写入 | `enabled=true` 时按 hash 分流到三组 | 同 M8.1 |
| 推荐结果是否改变 | **否**，generic / control 仍走 custom 完整流程 | 是，generic 固定 `soothe_01`、control 固定 `sleep_01` |
| D1 schema | 不改 | 可选补 `completionRatio` 字段 |
| 用户体验 | 零影响 | generic / control 用户体验轻微变化 |

### 17.3 分组设计

三组定义：

| 组别 | `experimentVariant` | M8.1 推荐策略 | M8.2 推荐策略（计划） |
|---|---|---|---|
| **custom**（个性化组） | `custom` | 完整 LLM + mapper + catalog | 同 M8.1 |
| **generic**（通用舒缓组） | `generic` | 仍走 custom 完整流程（仅标签不同） | 固定 `soothe_01.mp3` + soothe 基线参数 |
| **control**（中性对照组） | `control` | 仍走 custom 完整流程（仅标签不同） | 固定 `sleep_01.mp3` + sleep 基线参数 |

### 17.4 分组分配策略

- **方式**：sessionId FNV-1a 32-bit hash 稳定分流
- **默认配比**：1:1:1（custom : generic : control）
- **稳定性**：同一 sessionId 多次调用结果一致（FNV-1a 纯函数，跨平台跨版本确定性一致）
- **用户感知**：UI 不显示分组信息，避免霍桑效应
- **启用方式**：编译期常量，零依赖

为什么选 FNV-1a 而非 `String.hashCode`：
- `String.hashCode` 在不同平台 / Dart 版本下实现可能不同，跨进程跨版本不可保证一致
- FNV-1a 是公开标准算法，对相同输入在任何环境都产生相同 32 位结果
- 分布均匀性已由 `test/hash_experiment_assigner_test.dart` 1000 样本验证（每组占比 20%-50% 且不为 0）

### 17.5 启用方式

```bash
# 默认构建（不启用实验，线上默认）
flutter build web --release

# 启用消融实验分组记录
flutter build web --release --dart-define=ENABLE_EXPERIMENT=true
```

- **默认 false**：`HashExperimentAssigner` 恒返回 `custom`，用户体验与 M8 完全一致
- **`ENABLE_EXPERIMENT=true`**：新会话按 sessionId hash 稳定分流到三组，`experimentVariant` 字段写入 D1
- **编译期常量**：零依赖、零新 API、零运行时配置；切换需重新部署

### 17.6 代码影响范围

新增文件：

| 文件 | 作用 |
|---|---|
| `lib/pipeline/experiment/hash_experiment_assigner.dart` | FNV-1a hash 稳定分组分配器 |
| `test/hash_experiment_assigner_test.dart` | 稳定性 + 1000 样本分布均匀性 + 自定义配比 + 边界测试 |

修改文件：

| 文件 | 改动 |
|---|---|
| `lib/pipeline/mock/mock_pipeline_factory.dart` | `MockExperimentAssigner` 替换为 `HashExperimentAssigner(enabled: experimentEnabled)`；新增 `experimentEnabled` 编译期常量 |
| `scripts/feedback-queries.sql` | 追加附录 B（6 条消融实验分组查询） |
| `lib/config/app_version.dart` | 版本号更新为 v0.8.1 / M8.1 / M8.1-dev |

**不修改**（保守 MVP 边界）：
- `schema/feedback.sql`（`experimentVariant` 字段已存在，零迁移）
- `functions/api/submit-feedback.js`（`experimentVariant` 已在白名单）
- `lib/pipeline/mock/stock_audio_generator.dart`（不改音频匹配）
- `lib/pipeline/healing_pipeline.dart`（不改推荐链路）
- `lib/screens/feedback_screen.dart`（UI 不显示分组）
- `lib/models/cloud_feedback_payload.dart`（已映射 `plan.variant.name`）
- `lib/models/experiment_variant.dart`（枚举已有三值）

### 17.7 SQL 分析方案

`scripts/feedback-queries.sql` 附录 B 提供 6 条消融实验分组查询：

| 查询 | 用途 |
|---|---|
| B1 | 每组反馈数 + 平均 relaxationScore / calmnessScore（核心对比表） |
| B2 | 每组 targetState 分布（M8.1 三组应基本一致；M8.2 后应有差异） |
| B3 | 每组 audioAssetId 分布（验证分组是否生效） |
| B4 | 每组 analyzerMode 分布（控制变量验证，避免 LLM/mock 混淆） |
| B5 | 每组反馈提交率代理（含文字反馈占比） |
| B6 | 最近实验反馈记录（最新 30 条，趋势排查） |

**⚠️ 实验期过滤**：M8.1 上线前所有记录 `experimentVariant` 均为 `custom`（来自 `MockExperimentAssigner`）。分析时必须用 `WHERE createdAt >= '<M8.1 上线日期>'` 过滤，否则历史 custom 数据会稀释实验信号。

### 17.8 隐私与伦理说明

- **`experimentVariant` 用于匿名体验分析**：基于 sessionId hash 稳定生成，不关联用户身份
- **不基于心境原文分组**：`moodText` 不存在于 D1，分组仅依赖 sessionId
- **用户不被告知分组**：心弦是匿名 Demo，非临床试验；三组方案均为温和疗愈音频，无劣质对照组；符合 A/B 测试行业惯例
- **不做医疗效果结论**：报告与答辩材料统一使用"用户主观反馈差异 / 体验偏好 / 放松度评分"措辞，不写"治疗焦虑 / 改善失眠"
- **control 组体验保障**：M8.1 阶段 control 组仍走 custom 完整推荐流程，体验与 custom 组一致；M8.2 启用音频旁路后，control 组听到 `sleep_01.mp3`（温和白噪音 + 低频 Pad），非劣质音频

## 十八、免责声明

本项目为高校竞赛 Demo 原型，定位为情绪调节与正念放松辅助工具，提供的音乐体验不具备医疗诊断或治疗功能，不替代专业心理咨询与医疗建议。如有严重情绪困扰或睡眠障碍，请及时寻求专业医师帮助。
