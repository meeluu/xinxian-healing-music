# 心弦 · Mureka API 接入调研与计划（后续候选方案）

> ⚠️ **状态：后续候选 provider，当前不接入**（fix1 修订于 2026-07-18）
>
> 上一版（P4-comfort-song-design-1）曾把 Mureka 写成下一主线，现修正为：
> - **当前主线继续使用 MiniMax**（账户已充值，单首约 0.25 元，成本更可控，真实调用失败需继续排查）
> - **Mureka 降级为后续候选 provider**（最低充值 200 元，测试成本偏高，暂不接入）
> - 本文档保留作为后续候选方案的调研资料，**不删除**
> - 后期如果预算允许、且 MiniMax 确实无法修复，再切换或新增 Mureka

> 版本：`v1.0.0 · P4-comfort-song-design-1-fix1 · 2026-07-18`
> 范围：本文档为**后续候选方案调研**，当前不实现 `mureka_music provider`，不真实调用 Mureka API，不写入任何 API Key，不产生费用，不改 D1 schema，不改前端代码。
> 前置文档：
> - [comfort-song-product-flow.md](comfort-song-product-flow.md)（新主流程产品设计）
> - [ai-music-provider-adapter-design.md](ai-music-provider-adapter-design.md)（P4.4-1 provider adapter 设计）

---

## 一、背景

### 1.1 为什么调研 Mureka（后续候选，非当前主线）

MiniMax Music-2.0 在 P4.4-5 完成了真实调用分支代码实现（受 `MUSIC_GENERATION_REAL_CALLS_ENABLED` + `manualTest` 双重保护），但**真实调用测试仍失败**（详见 README 6.8.19 小节）。失败原因可能涉及鉴权、请求体格式、模型可用性等多方面。

**fix1 修订**：上一版曾据此把 Mureka 写成下一主线，但调研后发现 Mureka **最低充值 200 元**，测试成本偏高。考虑到 MiniMax 账户已充值、单首成本更低、代码已稳定，**当前决定继续排查 MiniMax，不切换到 Mureka**。Mureka 保留为后续候选 provider，本文档作为调研资料保留。

如果未来出现以下情况，再考虑切换或新增 Mureka：
- MiniMax 真实调用排查后仍无法修复
- 项目预算允许同时维护两个供应商
- 新主流程（困惑解惑 → 歌词 → AI 歌曲）确实需要 Mureka 的「歌词生成歌曲」原生能力

### 1.2 本批目标

1. 梳理 Mureka 官方 API 能力
2. 设计心弦使用 Mureka 的推荐路径
3. 设计环境变量与 provider 切换
4. 设计 fallback 策略
5. 拆分下一步代码任务

### 1.3 重要约束（本批遵守）

- ❌ 暂不真实调用 Mureka API
- ❌ 不写入 `MUREKA_API_KEY` 到代码 / README / wrangler.toml
- ❌ 不产生费用
- ❌ 不改 D1 schema
- ❌ 不改前端代码
- ❌ 当前不实现 `mureka_music provider` 骨架代码
- ✅ 本文档只作为后续候选方案调研资料保留
- ✅ MiniMax 是当前主线 provider，继续排查真实调用失败问题
- ✅ README 和版本号必须同步

---

## 二、Mureka 官方 API 能力梳理

### 2.1 API server 与鉴权

- **API server**：`https://api.mureka.ai`
- **鉴权方式**：`Authorization: Bearer MUREKA_API_KEY`
- **API Key 管理位置**：Cloudflare Dashboard → Pages → Settings → Environment variables → **Secret**（与 `MINIMAX_API_KEY` / `REPLICATE_API_TOKEN` / `STABLE_AUDIO_API_KEY` 同策略）

### 2.2 可用能力

| 能力 | endpoint（推测） | 用途 | 心弦是否使用 |
|---|---|---|---|
| 歌词生成 | `/v1/lyrics/generate` | 根据主题/情绪生成歌词 | ❌ 心弦用本项目 LLM 生成中文歌词，不调用 Mureka 歌词生成 |
| 歌词生成歌曲 | `/v1/songs/lyric-to-song` | 传入歌词 + 风格提示，生成带人声的歌曲 | ✅ **主线使用** |
| 提示词生成歌曲 | `/v1/songs/text-to-song` | 传入文字提示，生成歌曲（含歌词） | ⚠️ 备选，不作为主线 |
| 纯音乐生成 | `/v1/songs/instrumental` | 传入风格提示，生成纯音乐 | ⚠️ 旧流程可用，但旧流程已有预置音频 fallback |
| 查询任务 | `/v1/songs/{task_id}` | 查询异步任务状态 | ✅ **主线使用** |

> **注意**：以上 endpoint 为基于 Mureka 官方文档的推测路径，真实接入时需以 Mureka 官方文档为准。本批不真实调用，不验证 endpoint 准确性。

### 2.3 心弦推荐使用路径

```
心弦新主流程
  步骤 1：用户输入困惑/事件/情绪
  步骤 2：本项目 LLM（DeepSeek）生成「温和解惑」comfortInterpretation
  步骤 3：本项目 LLM（DeepSeek）生成中文歌词 lyricDraft
  步骤 4：用户确认/微调歌词 → lyricFinal
  步骤 5：调用 Mureka「歌词生成歌曲」/v1/songs/lyric-to-song
         ├─ 传入：lyricFinal + songPrompt（基于 targetState 的风格提示）
         ├─ 返回：task_id
         └─ 异步任务
  步骤 6：轮询 Mureka「查询任务」/v1/songs/{task_id}
         ├─ status: processing / succeeded / failed
         └─ succeeded → 返回 audioUrl
  步骤 7：前端播放 audioUrl
  步骤 8：失败/超时 → fallback 到预置音频
```

### 2.4 为什么不调用 Mureka 歌词生成

心弦选择用本项目 LLM（DeepSeek）生成歌词，而不是调用 Mureka 歌词生成，原因：

1. **可控性**：心弦的歌词需要严格遵守文案规范（禁用医疗化 / 玄学 / 空话），本项目 LLM 可以通过 Prompt 精细控制
2. **一致性**：歌词需要基于 `comfortInterpretation`（解惑文案）生成，与解惑文案语义一致，Mureka 歌词生成无法接收心弦的解惑文案作为输入
3. **成本**：Mureka 歌词生成可能额外收费，本项目 LLM 已有 DeepSeek API 配额
4. **可调试**：本项目 LLM 失败可 fallback 到本地关键词解析，Mureka 歌词生成失败只能 fallback 到预置音频

### 2.5 推荐请求体草案（歌词生成歌曲）

> ⚠️ 以下请求体为基于 Mureka 官方文档的草案，真实接入时需以官方文档为准。

```json
{
  "lyrics": "（用户确认后的中文歌词）",
  "prompt": "warm acoustic, gentle vocal, slow tempo, comforting mood",
  "voice": "（待确认：Mureka 是否提供音色选择）",
  "duration_seconds": 90,
  "audio_format": "mp3"
}
```

### 2.6 推荐响应结构草案

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "task_id": "task_xxx",
    "status": "processing"
  }
}
```

查询任务响应草案：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "task_id": "task_xxx",
    "status": "succeeded",
    "audio_url": "https://cdn.mureka.ai/...",
    "duration": 88.5
  }
}
```

---

## 三、环境变量设计

### 3.1 非敏感变量（wrangler.toml [vars] 管理）

```toml
# Mureka provider 选择（非敏感，可入 wrangler.toml）
MUSIC_GENERATION_PROVIDER = "mureka_music"
MUSIC_GENERATION_REAL_CALLS_ENABLED = "false"

# Mureka 模型参数（非敏感）
MUREKA_SONG_MODEL = "（待确认，真实接入时填入）"
MUSIC_GENERATION_MAX_DURATION_SECONDS = "120"
```

### 3.2 敏感凭证（Cloudflare Dashboard Secret 管理）

| 变量 | 管理位置 | 说明 |
|---|---|---|
| `MUREKA_API_KEY` | Cloudflare Dashboard Secret | **不写入 wrangler.toml / 代码 / README** |
| `MINIMAX_API_KEY` | Cloudflare Dashboard Secret | 保留（MiniMax 保留为备选 provider） |
| `REPLICATE_API_TOKEN` | Cloudflare Dashboard Secret | 保留（replicate_musicgen 保留） |
| `STABLE_AUDIO_API_KEY` | Cloudflare Dashboard Secret | 保留（stable_audio 保留） |

### 3.3 环境变量切换前后对比

| 变量 | P4.4-5 值 | P4 新方向值 | 说明 |
|---|---|---|---|
| `MUSIC_GENERATION_PROVIDER` | `minimax_music` | `mureka_music` | 主线 provider 切换 |
| `MUSIC_GENERATION_REAL_CALLS_ENABLED` | `false` | `false` | 仍关闭，不真实调用 |
| `MINIMAX_MUSIC_MODEL` | `music-2.0` | 保留 | MiniMax 保留为备选 |
| `MUREKA_SONG_MODEL` | — | 新增 | Mureka 模型名（待确认） |

> **注意**：本批只设计，不修改 wrangler.toml 的 `MUSIC_GENERATION_PROVIDER` 值。下一批实现 mureka_music provider 骨架时再切换。

---

## 四、Provider 适配方案

### 4.1 新增 mureka_music provider

新增文件：`functions/api/_music/providers/mureka-music-provider.js`

### 4.2 ProviderFactory 扩展

ProviderFactory 支持 5 个 provider：
- `mock`（默认）
- `stable_audio`
- `replicate_musicgen`
- `minimax_music`（备选保留）
- `mureka_music`（**新主线**）

### 4.3 行为矩阵（草案，下一批实现）

| `MUSIC_GENERATION_PROVIDER` | `MUREKA_API_KEY` | `MUSIC_GENERATION_REAL_CALLS_ENABLED` | `manualTest` | 行为 | provider |
|---|---|---|---|---|---|
| `mureka_music` | 缺失 | — | — | 降级 MockProvider | `mock` |
| `mureka_music` | 有值 | `false` / 未设置 | — | 不发请求，返回 fallback | `mureka_music_disabled` |
| `mureka_music` | 有值 | `true` | `false` / 未传 | 不发请求，返回 fallback | `mureka_music_manual_test_required` |
| `mureka_music` | 有值 | `true` | `true` | **真实 POST `/v1/songs/lyric-to-song`** | `mureka_music` |

### 4.4 与 MiniMax provider 的对称设计

mureka_music provider 设计与 minimax-music-provider.js 对称：
- 双重保护：`MUSIC_GENERATION_REAL_CALLS_ENABLED` + `manualTest`
- 错误处理：HTTP 错误 / 业务错误 / 超时 / 网络异常 全部 fallback
- 不打印 API Key
- 不保存音频到长期存储
- 返回 `audioUrl`（Mureka 直接返回 URL，不像 MiniMax 返回 hex）

### 4.5 关键差异：Mureka 返回 audioUrl，MiniMax 返回 audioHex

| 维度 | MiniMax | Mureka |
|---|---|---|
| 返回格式 | `data.audio` 为 hex 编码音频 | `data.audio_url` 为 CDN URL |
| 前端播放 | 需要后端转码/中转 | 直接用 audioUrl |
| 存储成本 | 需要存 R2 | 不需要存 R2（用 Mureka CDN URL） |
| URL 时效 | 无（hex 直接可用） | 有时效（建议只存 provider + jobId） |

---

## 五、Fallback 策略

### 5.1 三层 fallback

```
第 1 层：Mureka 真实调用成功 → 播放 audioUrl
  ↓ 失败/超时
第 2 层：Mureka fallback → 预置音频（按 targetState 匹配）
  ↓ 预置音频也不可用（极少）
第 3 层：纯文字陪伴 → 展示歌词 + 解惑文案，不播放音频
```

### 5.2 Fallback 触发条件

| 条件 | 行为 |
|---|---|
| `MUREKA_API_KEY` 缺失 | ProviderFactory 降级 MockProvider |
| `MUSIC_GENERATION_REAL_CALLS_ENABLED=false` | 返回 `mureka_music_disabled` + fallback |
| 无 `manualTest` | 返回 `mureka_music_manual_test_required` + fallback |
| Mureka HTTP 错误 | 返回 `http_error_{status}` + fallback |
| Mureka 业务错误 | 返回 `mureka_error_{code}` + fallback |
| 请求超时（55s） | 返回 `request_timeout` + fallback |
| 网络异常 | 返回 `request_failed` + fallback |
| 任务查询失败 | 返回 `task_query_failed` + fallback |
| 任务状态 `failed` | 返回 `task_failed` + fallback |

### 5.3 Fallback 时的用户体验

- 前端不展示错误详情，只展示"这首歌暂时没生成好，先听这段陪你"
- 歌词和解惑文案仍然展示（即使没有 AI 歌曲，文字陪伴也有价值）
- 用户可以重试（限制重试次数）

---

## 六、成本与充值注意事项

### 6.1 Mureka 定价（待确认）

- Mureka 官方定价需以官网为准（本批不真实调用，不产生费用）
- 推测按首计费，价格区间可能与 MiniMax（0.25 元/首）相近
- **充值前必须确认**：计费方式 / 每首价格 / 是否有最低充值 / 是否有免费额度

### 6.2 成本控制设计（沿用 P4.4-1 设计）

| 维度 | 限制 | 说明 |
|---|---|---|
| 每会话 | 1 次生成 | 同一 sessionId 只允许 1 次 Mureka 真实调用 |
| 每日 | 20 次 | 全局每日上限，超过返回 fallback |
| 单次时长 | ≤ 120s | `MUSIC_GENERATION_MAX_DURATION_SECONDS` |
| 每日预算 | ¥5 | 超预算返回 fallback |
| 超时 | 55s | AbortController 强制中断 |

### 6.3 充值注意事项

- 充值前先在 Mureka 官网确认定价
- 充值金额建议从小开始（¥10-50 试水）
- 充值后先在 Cloudflare Dashboard Secret 配置 `MUREKA_API_KEY`
- 再用 `manualTest: true` 手动 curl 测试一次
- 测试成功后再考虑开放前端真实生成

---

## 七、下一步代码任务拆分（fix1 修订：Mureka 暂不接入）

> ⚠️ **fix1 修订说明**：以下任务拆分中的 mureka_music 相关任务**当前不执行**，保留作为后续候选方案的任务清单。当前主线是继续排查 MiniMax 真实调用失败问题。

### 7.0 当前主线任务（fix1 修订后）

| 任务 | 说明 | 状态 |
|---|---|---|
| MiniMax 真实调用失败排查 | 排查线上为什么仍返回 `provider=mock`，检查 Secret 读取 / 鉴权 / 请求体 | ❌ 下一批 |
| 困惑解惑 + 歌词生成 本地/LLM 流程 | 先做「解惑文本 + 歌词生成」不依赖真实 AI 音乐生成 | ❌ 下一批 |
| 暂不做 Mureka | Mureka 最低充值 200 元，暂不接入 | ⏸️ 后续候选 |
| 暂不做付费模块 | 明确是后续阶段 | ⏸️ 后续阶段 |
| 暂不做社交 Agent | 明确是后续阶段 | ⏸️ 后续阶段 |

### 7.1 Mureka 相关任务（后续候选，当前不执行）

> 以下任务**当前不执行**，保留作为后续候选方案的任务清单。只有当 MiniMax 确实无法修复、且预算允许时才考虑执行。

| 任务 | 文件 | 说明 |
|---|---|---|
| 1. mureka_music provider 骨架 | `functions/api/_music/providers/mureka-music-provider.js` | 不真实调用，返回 fallback |
| 2. ProviderFactory 扩展 | `functions/api/_music/provider-factory.js` | 支持 mureka_music |
| 3. wrangler.toml 切换 | `wrangler.toml` | `MUSIC_GENERATION_PROVIDER = "mureka_music"` |
| 4. 验证脚本扩展 | `scripts/verify-provider-adapter.mjs` | 新增 mureka_music 测试 |
| 5. 版本号 | `lib/config/app_version.dart` | `P4-mureka-skeleton-1` |

### 7.2 Mureka 真实调用任务（后续候选，当前不执行）

| 任务 | 说明 |
|---|---|
| 6. mureka_music 真实调用分支 | 受 `manualTest` + `REAL_CALLS` 双重保护 |
| 7. 任务查询轮询 | `/v1/songs/{task_id}` 轮询逻辑 |
| 8. 验证脚本扩展 | mock fetch 注入测试 |
| 9. 版本号 | `P4-mureka-realtest-1` |

### 7.3 新主流程任务（与 Mureka 无关，可独立推进）

| 任务 | 说明 |
|---|---|
| 10. 困惑解惑 LLM Pages Function | `/api/comfort-interpret`（用 DeepSeek LLM，不依赖音乐 provider） |
| 11. 歌词生成 LLM Pages Function | `/api/generate-lyric`（用 DeepSeek LLM，不依赖音乐 provider） |
| 12. 新流程前端 UI | ComfortSongScreen |
| 13. D1 schema 迁移 | `comfort_song_sessions` 表 |
| 14. 三层同意机制 | `CloudStoryConsentService` |
| 15. 版本号 | `P4-comfort-song-mvp-1` |

### 7.4 真实音乐生成接入任务（依赖 MiniMax 修复或 Mureka 接入）

| 任务 | 说明 |
|---|---|
| 16. 真实调用测试 | `manualTest: true` 手动 curl（MiniMax 优先） |
| 17. 前端接入真实生成 | 用户主动点击触发 |
| 18. 反馈页扩展 | 新增 `lyricEdited` / `comfortHelpful` 字段 |
| 19. 版本号 | `P4-comfort-song-stable` |

---

## 八、风险与待确认

### 8.1 技术风险

| 风险 | 应对 |
|---|---|
| Mureka endpoint 路径不准确 | 真实接入前以官方文档为准 |
| Mureka 不支持纯中文歌词 | 真实调用测试时验证 |
| Mureka 生成耗时长（>55s） | 调整超时 + 异步轮询 |
| Mureka audioUrl 有时效 | 前端播放失败时 fallback 预置音频 |
| Mureka 计费方式不符预期 | 充值前确认，从小额开始 |

### 8.2 待确认事项

1. Mureka「歌词生成歌曲」endpoint 准确路径
2. Mureka 是否支持纯中文歌词
3. Mureka 单首生成耗时
4. Mureka 单首成本
5. Mureka audioUrl 时效
6. Mureka 是否提供音色选择
7. Mureka 是否有每日调用限额
8. Mureka 错误码完整列表

---

## 九、本批交付清单

| 交付物 | 状态 |
|---|---|
| `docs/mureka-api-integration-plan.md`（本文档，fix1 修订为后续候选） | ✅ 本批修订 |
| `docs/comfort-song-product-flow.md`（产品设计，fix1 修订主线为 MiniMax） | ✅ 本批修订 |
| README 修正主线表述（Mureka → MiniMax） | ✅ 本批交付 |
| 版本号 → `P4-comfort-song-design-1-fix1` | ✅ 本批交付 |
| mureka_music provider 骨架代码 | ❌ 后续候选（暂不接入） |
| Mureka 真实调用测试 | ❌ 后续候选（暂不接入） |

---

## 十、版本与约束

- 版本：`v1.0.0 · P4-comfort-song-design-1-fix1 · 2026-07-18`
- 本文档为后续候选方案调研，当前不实现 mureka_music provider
- 不写代码 / 不改 D1 / 不调用真实 API / 不接入付费 / 不做社交 Agent
- 不写入 `MUREKA_API_KEY`
- 不使用医疗化表达
- 不使用玄学表达
- README 和版本号必须同步
