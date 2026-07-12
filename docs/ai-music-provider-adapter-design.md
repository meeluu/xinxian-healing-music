# 心弦 · AI 音乐生成 Provider Adapter 设计（P4-AI-Music-v1.0 第四批第一步）

> 版本：`v1.0.0 · P4-provider-design-1 · 2026-07-12`
> 范围：本批只做 **provider adapter 架构设计、Stable Audio 接入草案、环境变量设计、成本/安全控制设计**。**暂不调用真实 Stable Audio API，不写死 API Key，不产生付费调用，不改 D1 schema，不改前端播放主流程。**
> 前置文档：
> - [ai-music-generation-research.md](ai-music-generation-research.md)（P4.1 调研 + P4.1-fix 复核）
> - [ai-music-generation-poc-design.md](ai-music-generation-poc-design.md)（P4.2 PoC 设计）

---

## 一、背景

### 1.1 P4 进度回顾

| 批次 | 内容 | 状态 |
|---|---|---|
| P4.1 | AI 音乐生成服务选型调研 | ✅ 已完成 |
| P4.1-fix | 供应商可用性与版权/API 复核 | ✅ 已完成 |
| P4.2 | 最小 PoC 接入设计 | ✅ 已完成 |
| P4.3 | mock/adapter 最小闭环实现 | ✅ 已完成（P4-mock-1-fix2） |
| **P4.4-1（本批）** | **Provider adapter 与密钥/成本控制设计** | ✅ 本批交付 |
| P4.4-2 | 真实 Stable Audio API 接入（需人工注册 + credits + API Key） | ⏳ 下一步 |
| P4.5 | DSP 后处理 + 成本与安全控制 + 预生成缓存 | ⏳ 计划中 |

### 1.2 前置结论

- **主方案**：Stable Audio 3.0 API（platform.stability.ai）
- **备选**：MusicGen via Replicate（CC-BY-NC 4.0 非商业，仅 fallback）
- **mock provider**：P4.3 已实现，继续保留为默认
- **预置音频**：永久保留，作为生成失败/超时/未接入时的最终 fallback
- **P4 真正 AI 音乐生成是必做项**，本批是接入前的工程准备设计

### 1.3 本批目标

在 P4.3 mock/adapter 闭环已稳定的基础上，为真实 Stable Audio 接入做工程准备：

1. Provider adapter 架构设计（mock vs stable_audio 切换机制）
2. Stable Audio 接入草案（endpoint / payload / 错误码映射 / 超时策略）
3. 环境变量设计（provider 选择 / API Key / 成本限制）
4. 成本控制设计（每日限制 / 单次限制 / 超时强制 fallback）
5. 安全与隐私设计（脱敏 / 日志 / API Key 隔离）
6. D1/R2 准备方案（migration 草案 / R2 路径 / 生命周期）

### 1.4 重要约束（本批遵守）

- 暂不调用真实 Stable Audio API
- 不写死任何 API Key
- 不产生付费调用
- mock provider 继续保留
- 预置音频 fallback 必须继续保留
- 不改现有播放主流程
- 不使用「治疗 / 治愈 / 治疗焦虑 / 治疗失眠」等医疗化表达
- 不改 D1 schema（只设计，不迁移）

---

## 二、当前 P4.3 mock 状态

### 2.1 已实现的架构

```
PlanScreen
  └─ 「生成专属音乐（实验）」按钮
      └─ MusicGenerationScreen
          └─ 3 秒 Future.delayed 本地模拟
              └─ succeeded → 用户点击「播放这段音乐」→ PlayerScreen
              └─ failed → 用户点击「播放预置音乐」→ PlayerScreen
```

### 2.2 后端 mock Functions（已实现但 P4.3-fix2 后前端未调用）

| 文件 | 说明 |
|---|---|
| `functions/api/generate-music.js` | 无状态 mock，返回 jobId + fallbackTrack，CORS + 输入校验 + prompt 过滤 |
| `functions/api/music-status.js` | 无状态 mock，jobId 编码时间戳，4 秒后 90% succeeded / 10% failed |

### 2.3 前端服务层（已实现但 P4.3-fix2 后 MusicGenerationScreen 未调用）

| 文件 | 说明 |
|---|---|
| `lib/pipeline/music_generation/music_generation_models.dart` | 数据模型（Request/Response/Phase 枚举） |
| `lib/pipeline/music_generation/music_generation_service.dart` | HTTP 封装（createJob/getStatus/pollUntilComplete），maxPollDuration 15s |

### 2.4 P4.3-fix2 后的简化

P4.3-fix2 将 `MusicGenerationScreen` 简化为纯 3 秒 `Future.delayed` 本地模拟，不再调用 `createJob`/`pollUntilComplete`。这是因为：

1. 本地开发无 Cloudflare Pages Functions，HTTP 调用必然失败
2. mock 阶段最终播放的都是预置音频，不需要真实后端
3. 简化后页面更稳定，不会因网络/HTTP/解析异常导致空白或卡死

**P4.4-2 接入真实 API 时**，需要恢复 `MusicGenerationScreen` 对 `MusicGenerationService` 的调用，并通过 provider adapter 切换到 `stable_audio`。

---

## 三、Provider Adapter 架构

### 3.1 设计目标

| 目标 | 说明 |
|---|---|
| 可切换 | 通过环境变量控制 provider，无需改代码 |
| 可降级 | stable_audio 不可用时自动 fallback 到 mock，再 fallback 到预置音频 |
| 可扩展 | 未来可新增 MusicGen / ElevenLabs 等 provider |
| 安全 | API Key 只在 Cloudflare env，不泄露到前端 |
| 零中断 | 任何 provider 故障都不影响用户播放预置音频 |

### 3.2 Provider 接口定义

```
                     MusicGenerationProvider（接口）
                     ├─ createJob(request) → JobResponse
                     ├─ getStatus(jobId) → StatusResponse
                     └─ providerName → String
                           │
              ┌────────────┴────────────┐
              │                         │
     MockProvider               StableAudioProvider
     (P4.3 已实现)               (P4.4-2 实现)
     ├─ 无状态 mock              ├─ 调用 Stability API
     ├─ 4s 后 90% 成功           ├─ 异步任务轮询
     └─ 返回预置音频 URL         └─ 下载音频 → 上传 R2
```

### 3.3 Provider 选择逻辑

```
                    请求进入 /api/generate-music
                              │
                    ┌─────────▼──────────┐
                    │ 读取环境变量        │
                    │ MUSIC_GENERATION_   │
                    │ PROVIDER            │
                    └─────────┬──────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
          "mock"          "stable_audio"   未设置/其他
                │             │             │
                ▼             ▼             ▼
          MockProvider  StableAudioProvider  MockProvider
                              │
                    ┌─────────▼──────────┐
                    │ 检查 STABLE_AUDIO_  │
                    │ API_KEY 是否存在    │
                    └─────────┬──────────┘
                              │
                    ┌─────────┼─────────┐
                    │         │         │
                  有 Key    无 Key     Key 为空
                    │         │         │
                    ▼         ▼         ▼
              StableAudio   Mock     Mock
              Provider      Provider  Provider
```

**核心原则**：
- `MUSIC_GENERATION_PROVIDER` 未设置时，默认为 `mock`
- 设置为 `stable_audio` 但 `STABLE_AUDIO_API_KEY` 缺失时，自动降级为 `mock`
- 任何 provider 异常都返回 `fallbackTrack`，不返回 5xx

### 3.4 Cloudflare Pages Function 中的 Provider 注入

```javascript
// functions/api/generate-music.js（P4.4-2 改造方向）

// Provider 工厂（P4.4-2 实现）
function createProvider(env) {
  const providerName = env.MUSIC_GENERATION_PROVIDER || 'mock';

  if (providerName === 'stable_audio') {
    if (!env.STABLE_AUDIO_API_KEY) {
      // API Key 缺失，降级到 mock
      console.log('[music-gen] STABLE_AUDIO_API_KEY missing, fallback to mock');
      return new MockProvider(env);
    }
    return new StableAudioProvider(env);
  }

  return new MockProvider(env);
}

export async function onRequestPost(context) {
  const { request, env } = context;
  const provider = createProvider(env);
  // ... 调用 provider.createJob(request)
}
```

### 3.5 MockProvider（P4.3 已实现，保留不变）

| 特性 | 当前实现 |
|---|---|
| 状态管理 | 无状态（jobId 编码时间戳） |
| 成功概率 | 90% succeeded / 10% failed |
| 生成耗时 | 4 秒（基于 jobId 时间戳计算） |
| audioUrl | 返回预置音频路径（与 fallbackTrack 相同） |
| 依赖 | 无 D1 / 无 R2 / 无外部 API |

### 3.6 StableAudioProvider（P4.4-2 实现，本批只设计）

| 特性 | 设计方案 |
|---|---|
| 状态管理 | D1 `music_generation_jobs` 表持久化 |
| API 调用 | POST Stability API → 轮询结果 → 下载 → 上传 R2 |
| audioUrl | R2 URL（`https://r2.xinxian-music.xyz/generated-music/...`） |
| 依赖 | D1 + R2 + `STABLE_AUDIO_API_KEY` |

---

## 四、Stable Audio 接入草案

### 4.1 API Endpoint（占位，P4.4-2 实测确认）

| 项目 | 值 |
|---|---|
| Base URL | `https://api.stability.ai` |
| 创建任务 | `POST /v2/audio/stable-audio-3.0` |
| 查询结果 | `GET /v2/results/{task_id}` |
| 认证 | `Authorization: Bearer ${STABLE_AUDIO_API_KEY}` |
| Content-Type | `multipart/form-data`（或 `application/json`，P4.4-2 实测确认） |

> ⚠️ 以上 endpoint 基于 P4.1 调研文档推断，**P4.4-2 实施前必须人工登录 platform.stability.ai 确认实际 API 文档**。

### 4.2 请求 Payload 结构（草案）

```json
{
  "prompt": "ambient sleep music, instrumental, no vocals, no lyrics, very slow tempo 45-60 BPM, theta and delta brainwave frequencies, sustained low drone, soft piano with long reverb, gentle rain texture, no percussion, no sudden changes, peaceful, dreamlike, minimal melody",
  "duration_seconds": 480,
  "output_format": "mp3",
  "sample_rate": 44100,
  "bitrate": 192000
}
```

**字段说明**：

| 字段 | 类型 | 说明 |
|---|---|---|
| `prompt` | string | 英文 prompt（来自 P4.2 Prompt 映射，已脱敏，无医疗化表达） |
| `duration_seconds` | number | 请求时长（秒），范围 30-360（Stable Audio 最长 6 分钟） |
| `output_format` | string | `mp3`（just_audio Web 兼容性最佳） |
| `sample_rate` | number | 44100（CD 音质） |
| `bitrate` | number | 192000（192kbps，平衡质量与文件大小） |

**时长限制**：
- Stable Audio 3.0 最长支持 6 分钟（360 秒）
- 心弦 M5 推荐时长 3-8 分钟（180-480 秒）
- **P4.4-2 需要将 duration 限制在 30-360 秒**，超过 360 秒截断为 360 秒

### 4.3 Response 解析策略

```json
// 创建任务响应（预期）
{
  "task_id": "task_abc123",
  "status": "processing"
}
```

```json
// 查询结果响应（预期）
{
  "task_id": "task_abc123",
  "status": "succeeded",
  "result": {
    "audio_url": "https://api.stability.ai/v2/results/task_abc123/audio.mp3"
  }
}
```

> ⚠️ 实际 response 结构以 P4.4-2 实测为准。

**解析策略**：
1. 创建任务 → 提取 `task_id`，存入 D1 `music_generation_jobs.id`
2. 轮询结果 → 检查 `status`
3. 成功 → 下载 `result.audio_url` → 上传 R2 → 更新 D1 `audio_url`
4. 失败 → 记录 `error_code` → 返回 fallbackTrack

### 4.4 错误码映射

| Stability API 错误 | HTTP 状态码 | 映射到心弦 errorCode | 前端处理 |
|---|---|---|---|
| 认证失败（API Key 无效） | 401 | `api_auth_failed` | fallback 到预置音频 |
| 速率限制 | 429 | `api_rate_limited` | fallback 到预置音频 |
| 内容被拒绝 | 400 | `content_rejected` | fallback 到预置音频 |
| 服务器错误 | 500/502/503 | `api_server_error` | fallback 到预置音频 |
| 请求超时 | — | `api_timeout` | fallback 到预置音频 |
| 音频下载失败 | — | `audio_download_failed` | fallback 到预置音频 |
| R2 上传失败 | — | `r2_upload_failed` | fallback 到预置音频 |
| 未知错误 | — | `internal_error` | fallback 到预置音频 |

**关键原则**：所有错误码都不泄露 provider 原始敏感信息（如 API Key、内部错误详情），只返回脱敏的 errorCode。

### 4.5 超时策略

| 超时点 | 时长 | 动作 |
|---|---|---|
| Stability API 创建请求 | 10s | 返回 `api_timeout`，fallback |
| Stability API 生成等待 | 60s | 返回 `api_timeout`，fallback |
| 音频下载（Stability → Pages Function） | 30s | 返回 `audio_download_failed`，fallback |
| R2 上传 | 15s | 返回 `r2_upload_failed`，fallback |
| 总耗时（createJob → succeeded） | 90s | 强制 fallback |
| 前端轮询间隔 | 3s | — |
| 前端最大轮询时长 | 15s（P4.3-fix1 调整） | fallback 到预置音频 |

> 注：P4.3-fix1 已将前端 `maxPollDuration` 从 150s 调整为 15s。P4.4-2 接入真实 API后可能需要调大（建议 30-60s），因为 Stable Audio 生成需 10-30s。

### 4.6 Fallback 策略

```
StableAudioProvider 调用
    │
    ├─ 成功 → 返回 R2 audioUrl
    │
    └─ 失败/超时/异常
        │
        ├─ 记录 errorCode 到 D1
        │
        └─ 返回 fallbackTrack（预置音频）
            │
            └─ 前端播放预置音频，用户无感知
```

**Fallback 链**：
1. `stable_audio` provider 成功 → 播放 R2 生成音频
2. `stable_audio` provider 失败 → 播放预置音频
3. `stable_audio` provider 不可用（无 API Key）→ 自动降级到 `mock` provider
4. `mock` provider 不可用（网络错误）→ 播放预置音频
5. 所有都不可用 → 播放预置音频

---

## 五、环境变量设计

### 5.1 环境变量清单

| 变量名 | 必填 | 默认值 | 说明 |
|---|---|---|---|
| `MUSIC_GENERATION_PROVIDER` | ❌ | `mock` | Provider 选择：`mock` / `stable_audio` |
| `STABLE_AUDIO_API_KEY` | ⚠️ 条件必填 | — | Stability AI API Key，`provider=stable_audio` 时必填 |
| `MUSIC_GENERATION_DAILY_LIMIT` | ❌ | `20` | 每日全局生成次数上限 |
| `MUSIC_GENERATION_SESSION_LIMIT` | ❌ | `1` | 每会话生成次数上限 |
| `MUSIC_GENERATION_MAX_DURATION` | ❌ | `180` | 单次最大时长（秒），Stable Audio 最长 360 |
| `R2_BUCKET_NAME` | ⚠️ 条件必填 | — | R2 bucket 名，`provider=stable_audio` 时必填 |
| `R2_PUBLIC_BASE_URL` | ❌ | — | R2 公开访问基址（P4.4-2 简化用公开读，P4.5 改签名 URL） |
| `STABLE_AUDIO_API_BASE` | ❌ | `https://api.stability.ai` | Stability API 基址（可覆盖用于测试） |

### 5.2 环境变量配置位置

| 环境 | 配置方式 |
|---|---|
| Cloudflare Pages 生产 | Dashboard → Settings → Environment variables |
| Cloudflare Pages 预览 | Dashboard → Settings → Environment variables（Preview） |
| 本地开发 | `.dev.vars` 文件（`wrangler` 读取，不入 Git） |

### 5.3 `.dev.vars` 示例（不入 Git）

```bash
# .dev.vars（本地开发用，不提交到 Git）
MUSIC_GENERATION_PROVIDER=mock
# STABLE_AUDIO_API_KEY=sk-xxx  # 本地开发不配置，自动降级到 mock
MUSIC_GENERATION_DAILY_LIMIT=5
```

### 5.4 安全约束

| 约束 | 说明 |
|---|---|
| API Key 不入 Git | `.dev.vars` 在 `.gitignore` 中 |
| API Key 不泄露到前端 | Pages Function 只在服务端读取 `env.STABLE_AUDIO_API_KEY`，响应中不包含 |
| API Key 不打印到日志 | `console.log` 中只打印 `***` 脱敏 |
| 错误响应不泄露内部信息 | errorCode 是脱敏枚举，不含 provider 原始错误详情 |

---

## 六、成本控制设计

### 6.1 成本控制矩阵

| 控制点 | 设计值 | 实施方式 | 实施批次 |
|---|---|---|---|
| 每日全局生成上限 | 20 次/日 | D1 查询当天 `COUNT(*)`，超过返回 `rate_limited` | P4.4-2 |
| 每会话生成上限 | 1 次/会话 | D1 查询 `session_id` 去重 | P4.4-2 |
| 每 IP 限流 | 5 次/分钟 | Cloudflare 限流规则（与 `/api/analyze-mood` 共用） | P4.4-2 |
| 单次最大时长 | 180 秒 | `MUSIC_GENERATION_MAX_DURATION` 环境变量 | P4.4-2 |
| 单次生成超时 | 90 秒 | 总耗时超时强制 fallback | P4.4-2 |
| 免费 credits 监控 | 25 credits | D1 `cost_estimate` 累计，接近上限告警 | P4.4-2 |
| 每日成本上限 | $1.0/日 | D1 `cost_estimate` 累计，超过自动转 mock | P4.5 |

### 6.2 成本估算

| 项目 | 估算 |
|---|---|
| Stable Audio 3.0 单次生成成本 | $0.01-0.05/分钟（按秒计费） |
| 180 秒生成成本 | $0.03-0.15 |
| 每日 20 次上限成本 | $0.60-3.00 |
| 25 免费 credits 可生成次数 | 约 3-8 次（取决于 credit 与秒数换算） |
| R2 存储成本 | $0.015/GB/月（Cloudflare R2 免费额度 10GB） |
| R2 操作成本 | Class A $4.50/百万次，Class B $0.36/百万次 |

> ⚠️ 以上成本基于 P4.1 调研文档估算，**P4.4-2 实施前必须人工登录 platform.stability.ai 确认实际定价**。

### 6.3 成本日志

D1 `music_generation_jobs.cost_estimate` 字段记录每次生成预估成本：

```sql
-- 每日成本统计（P4.5 实现）
SELECT
  DATE(created_at) as date,
  COUNT(*) as generation_count,
  SUM(cost_estimate) as daily_cost
FROM music_generation_jobs
WHERE provider = 'stable-audio-3.0'
  AND status = 'succeeded'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

### 6.4 成本超限处理

```
请求进入 /api/generate-music
    │
    ├─ 检查每日全局生成次数
    │   └─ 超过 MUSIC_GENERATION_DAILY_LIMIT → 返回 rate_limited + fallbackTrack
    │
    ├─ 检查每会话生成次数
    │   └─ 超过 MUSIC_GENERATION_SESSION_LIMIT → 返回 rate_limited + fallbackTrack
    │
    ├─ 检查每日成本累计
    │   └─ 超过 $1.0/日 → 自动降级到 mock provider
    │
    └─ 检查免费 credits 剩余
        └─ 接近上限（<5 credits）→ 告警日志，继续服务
        └─ 用尽 → 自动降级到 mock provider
```

---

## 七、安全与隐私设计

### 7.1 心境原文保护

| 控制点 | 设计 |
|---|---|
| 不上传 moodText | 前端 `MusicGenerationRequest` 不包含用户心境原文 |
| 上传脱敏 generationPrompt | M5 `EmotionToMusicPlanMapper` 生成的英文 prompt，已脱敏 |
| moodProfile 只含结构化数据 | valence/arousal/intensity/tags，不含原文 |
| D1 不存储用户原文 | `music_generation_jobs.prompt` 是英文脱敏 prompt |

### 7.2 Prompt 安全过滤

| 过滤规则 | 处理 |
|---|---|
| 医疗关键词（`heal`/`cure`/`treat`/`therapy`/`anxiety`/`insomnia`） | 替换为中性词 |
| 自残/暴力关键词 | 拒绝，返回 `invalid_prompt` |
| 长度 > 500 字符 | 截断到 500 |
| 包含用户原文片段 | 拒绝（不应出现，M5 已脱敏） |

> P4.3 `generate-music.js` 已实现 `FORBIDDEN_KEYWORDS` 过滤。

### 7.3 API Key 安全

| 控制点 | 设计 |
|---|---|
| API Key 只在 Cloudflare env | `env.STABLE_AUDIO_API_KEY`，前端代码不包含 |
| API Key 不入 Git | `.dev.vars` 在 `.gitignore` 中 |
| API Key 不打印到日志 | `console.log` 中脱敏为 `sk-***` |
| API Key 不返回给前端 | 响应中不包含 `apiKey` 字段 |
| API Key 不传递给第三方 | 只在 Pages Function 内部使用 |

### 7.4 错误响应安全

| 控制点 | 设计 |
|---|---|
| 不泄露 provider 原始错误 | errorCode 是脱敏枚举（如 `api_server_error`，不含 Stability 内部错误详情） |
| 不泄露 API Key | 错误响应中不包含任何 Key 信息 |
| 不泄露内部路径 | 错误响应中不包含文件路径、D1 表名等 |
| 不泄露其他用户数据 | 每个 jobId 只能查询自己的状态 |

### 7.5 日志安全

```javascript
// ✅ 安全的日志
console.log('[music-gen] createJob:', { sessionId, targetState, provider });
console.log('[music-gen] API Key configured:', !!env.STABLE_AUDIO_API_KEY);

// ❌ 不安全的日志（禁止）
console.log('[music-gen] API Key:', env.STABLE_AUDIO_API_KEY);
console.log('[music-gen] user moodText:', moodText);
console.log('[music-gen] Stability error:', error.response.data);
```

---

## 八、D1/R2 准备方案

### 8.1 D1 Migration 草案（本批不执行）

> ⚠️ 本批只设计，不迁移。P4.4-2 实施时创建迁移脚本。

```sql
-- 心弦 · AI 音乐生成任务记录表（P4.4-2 迁移）
-- 数据库：xinxian-feedback（复用现有 D1）
-- 设计来源：P4.2 PoC 设计文档 + P4.4-1 provider adapter 设计

CREATE TABLE IF NOT EXISTS music_generation_jobs (
  id              TEXT PRIMARY KEY,           -- job ID，格式 job_{yyyyMMdd}_{random}
  session_id      TEXT NOT NULL,              -- 心弦会话 ID
  target_state    TEXT NOT NULL,              -- sleep / regulate / soothe / focus / energize
  prompt          TEXT NOT NULL,              -- 发送给 Stable Audio 的英文 prompt（脱敏后）
  provider        TEXT NOT NULL DEFAULT 'mock',  -- mock / stable-audio-3.0
  status          TEXT NOT NULL DEFAULT 'queued',  -- queued/generating/storing/succeeded/failed/fallback
  audio_url       TEXT,                       -- 生成成功后的 R2 音频 URL
  fallback_audio_asset_id TEXT,               -- fallback 预置音频 ID
  error_code      TEXT,                       -- 失败时的错误码（第七节 4.4 错误码映射）
  cost_estimate   REAL DEFAULT 0,             -- 预估成本（USD）
  duration_seconds INTEGER NOT NULL,          -- 请求时长（秒）
  actual_duration_seconds INTEGER,            -- 实际生成时长（秒）
  client_version  TEXT,                       -- 客户端版本号
  client_ip_hash  TEXT,                       -- 客户端 IP 哈希（隐私保护，不存原始 IP）
  created_at      TEXT NOT NULL,              -- ISO8601 创建时间
  updated_at      TEXT NOT NULL,              -- ISO8601 更新时间
  completed_at    TEXT                        -- ISO8601 完成时间
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_music_jobs_session_id ON music_generation_jobs(session_id);
CREATE INDEX IF NOT EXISTS idx_music_jobs_status ON music_generation_jobs(status);
CREATE INDEX IF NOT EXISTS idx_music_jobs_created_at ON music_generation_jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_music_jobs_target_state ON music_generation_jobs(target_state);
CREATE INDEX IF NOT EXISTS idx_music_jobs_provider ON music_generation_jobs(provider);
```

**与 P4.2 设计的差异**：
- `provider` 默认值从 `stable-audio-3.0-large` 改为 `mock`
- 新增 `client_ip_hash` 字段（用于 IP 级别限流，不存储原始 IP）
- 新增 `idx_music_jobs_provider` 索引（按 provider 统计）

### 8.2 R2 Bucket 配置

| 配置项 | 值 |
|---|---|
| Bucket 名称 | `xinxian-music-gen` |
| 访问方式 | P4.4-2 公开读（简化），P4.5 改签名 URL |
| 区域 | Cloudflare R2 自动 |
| 生命周期 | 30 天后自动删除（`generated-music/` 前缀） |

### 8.3 R2 存储路径

```
generated-music/{yyyy}/{mm}/{jobId}.mp3
```

**示例**：`generated-music/2026/07/job_20260712_abc123.mp3`

**路径设计理由**：
- `{yyyy}/{mm}` 按年月分目录，便于生命周期清理
- `{jobId}` 作为文件名，保证唯一性，便于从 D1 反查
- `.mp3` 格式（44.1kHz / 192kbps），just_audio Web 兼容性好

### 8.4 Generated Audio 生命周期

| 阶段 | 策略 |
|---|---|
| 生成 | Stability API 返回音频 → Pages Function 下载 → 上传 R2 |
| 访问 | P4.4-2 公开读 URL；P4.5 签名 URL（1 小时有效） |
| 清理 | R2 lifecycle rule：`generated-music/` 前缀 30 天后自动删除 |
| D1 记录 | 不删除 D1 记录（仅 R2 文件清理），保留成本/统计分析数据 |

### 8.5 AudioUrl 返回策略

| Provider | audioUrl 来源 |
|---|---|
| mock | 预置音频路径（`/assets/music/sleep_01.mp3`） |
| stable_audio | R2 URL（`https://r2.xinxian-music.xyz/generated-music/...`） |
| fallback | 预置音频路径（同 mock） |

**签名 URL（P4.5）**：
- R2 私有读 + Pages Function 生成签名 URL（有效期 1 小时）
- 前端轮询 `music-status` 时，每次返回新的签名 URL
- 避免音频被外部站点盗链

---

## 九、Fallback 策略

### 9.1 Fallback 触发条件

| 条件 | 触发动作 |
|---|---|
| `MUSIC_GENERATION_PROVIDER` 未设置 | 使用 mock provider |
| `provider=stable_audio` 但 `STABLE_AUDIO_API_KEY` 缺失 | 自动降级到 mock provider |
| `provider=stable_audio` 但每日成本超限 | 自动降级到 mock provider |
| `provider=stable_audio` 但免费 credits 用尽 | 自动降级到 mock provider |
| Stability API 认证失败 | 返回 fallbackTrack |
| Stability API 速率限制 | 返回 fallbackTrack |
| Stability API 生成超时 | 返回 fallbackTrack |
| Stability API 内容拒绝 | 返回 fallbackTrack |
| R2 上传失败 | 返回 fallbackTrack |
| 任何未捕获异常 | 返回 fallbackTrack |

### 9.2 Fallback 音频选择

`fallbackTrack` 由 Pages Function 根据 `targetState` 选择，复用现有 `AudioAssetCatalog` 4 级匹配算法：

| targetState | fallbackTrack.audioAssetId |
|---|---|
| `sleep` | `sleep_01` |
| `regulate` | `regulate_01` |
| `soothe` | `soothe_01` |
| `focus` | `focus_01` |
| `energize` | `energize_01` |

### 9.3 Fallback 数据记录

| 状态 | D1 记录 |
|---|---|
| `succeeded` | `audio_url` 有值，`fallback_audio_asset_id` 为 null |
| `failed` | `audio_url` 为 null，`fallback_audio_asset_id` 有值，`error_code` 记录原因 |
| `fallback` | `audio_url` 为 null，`fallback_audio_asset_id` 有值，`error_code` 为 `service_unavailable` |

---

## 十、不做事项（本批明确不做）

| 不做项 | 原因 |
|---|---|
| ❌ 调用真实 Stable Audio API | 本批是设计，P4.4-2 才接入 |
| ❌ 写 StableAudioProvider 代码 | P4.4-2 实现 |
| ❌ 改 D1 schema | P4.4-2 迁移 |
| ❌ 配置 R2 bucket | P4.4-2 配置 |
| ❌ 接入 API Key | P4.4-2 人工注册后 |
| ❌ 实际生成音频 | P4.4-2 |
| ❌ 改前端播放主流程 | P4.4-2 仅改 MusicGenerationScreen |
| ❌ 改现有预置音频匹配逻辑 | 永久保留 |
| ❌ 签名 URL | P4.5 |
| ❌ 预生成缓存 | P4.5 |
| ❌ DSP 后处理 | P4.5 |

---

## 十一、P4.4 下一步实施清单

### 11.1 P4.4-2 目标

接入真实 Stable Audio API，实现 `StableAudioProvider`：

1. 人工注册 Stability AI 账号，获取 API Key
2. 确认 Stable Audio 3.0 API 实际 endpoint / payload / 定价
3. 配置 Cloudflare Pages 环境变量
4. 创建 D1 migration（`music_generation_jobs` 表）
5. 配置 R2 bucket（`xinxian-music-gen`）
6. 实现 `StableAudioProvider`（createJob + getStatus + R2 上传）
7. 恢复 `MusicGenerationScreen` 对 `MusicGenerationService` 的调用
8. 完整 fallback 测试
9. 成本与限流验证

### 11.2 P4.4-2 任务列表

| 编号 | 任务 | 说明 |
|---|---|---|
| T1 | 人工注册 | 注册 platform.stability.ai，获取 API Key，确认免费 credits |
| T2 | API 文档确认 | 确认 endpoint / payload / response 结构 / 定价 |
| T3 | 环境变量配置 | Cloudflare Pages Dashboard 配置 `STABLE_AUDIO_API_KEY` 等 |
| T4 | D1 迁移 | `schema/music_generation_jobs.sql`，创建表 + 索引 |
| T5 | R2 配置 | 创建 bucket `xinxian-music-gen`，配置 30 天生命周期 |
| T6 | StableAudioProvider | `functions/lib/stable-audio-provider.js`，实现 createJob + getStatus |
| T7 | Provider 工厂 | 修改 `generate-music.js` + `music-status.js`，接入 provider 选择逻辑 |
| T8 | R2 上传 | Pages Function 下载 Stability 音频 → 上传 R2 |
| T9 | 前端恢复 | `MusicGenerationScreen` 恢复调用 `MusicGenerationService` |
| T10 | 前端轮询调整 | `maxPollDuration` 从 15s 调整为 30-60s（适配真实 API 耗时） |
| T11 | 限流实现 | D1 查重（每会话 1 次）+ 每日全局上限 |
| T12 | 成本日志 | D1 `cost_estimate` 记录 |
| T13 | 测试 | 单元测试 + 集成测试 + 线上验证 |
| T14 | 验证 | flutter analyze + flutter test + flutter build web --release |
| T15 | README 同步 | P4.4-2 完成状态 |

### 11.3 P4.4-2 前置条件（需人工确认）

| 编号 | 确认项 | 状态 |
|---|---|---|
| C1 | Stability AI 账号注册 | ⏳ 待人工 |
| C2 | 25 免费 credits 到账 | ⏳ 待人工 |
| C3 | Stable Audio 3.0 API 实际 endpoint | ⏳ 待人工确认 |
| C4 | API 单次生成 credit 成本 | ⏳ 待人工确认 |
| C5 | API 速率限制 | ⏳ 待人工确认 |
| C6 | API 异步任务支持方式 | ⏳ 待人工确认 |
| C7 | API 输出音频格式 | ⏳ 待人工确认 |
| C8 | Community License 全文审阅 | ⏳ 待人工确认 |

---

## 十二、本批交付清单

| 交付物 | 路径 | 状态 |
|---|---|---|
| Provider adapter 设计文档 | `docs/ai-music-provider-adapter-design.md` | ✅ 本文件 |
| README 同步 | `README.md` P4.4-1 状态更新 + 文档链接 | ✅ |
| 版本号同步 | `lib/config/app_version.dart` → `P4-provider-design-1` | ✅ |
| 验证 | `flutter analyze` 通过 | ✅ |
| 业务代码改动 | 无（本批只新增文档 + 版本号） | ✅ |
| D1 schema 改动 | 无（只设计，不迁移） | ✅ |
| Cloudflare Functions 改动 | 无（只设计，不实现） | ✅ |
| 前端代码改动 | 无（只设计，不实现） | ✅ |
| API Key 接入 | 无 | ✅ |

---

> **免责声明**：本文档仅作接入设计参考，不构成法律建议。心弦定位为辅助情绪调节与正念陪伴工具，**不提供医疗诊断或治疗**，音乐生成不写「治疗焦虑 / 治疗失眠 / 治愈」等医疗化措辞。截至 P4.4-1（2026-07-12），心弦**尚未接入任何真实 AI 音乐生成 API**，当前播放仍为本地预置音频。P4 真正 AI 音乐生成仍为必做项。
