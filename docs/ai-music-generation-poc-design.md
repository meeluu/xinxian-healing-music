# 心弦 · AI 音乐生成最小 PoC 接入设计（P4-AI-Music-v1.0 第二批）

> 版本：`v1.0.0 · P4-design-1 · 2026-07-12`
> 范围：本批只做**架构设计、接口设计、数据结构设计、任务拆分**。**暂不调用真实 Stable Audio API，不写死 API Key，不实际生成付费音频，不改 D1 schema，不改 Cloudflare Functions，不改前端播放逻辑。**
> 前置文档：[ai-music-generation-research.md](ai-music-generation-research.md)（P4.1 调研 + P4.1-fix 复核）

---

## 一、背景

### 1.1 P4 进度回顾

| 批次 | 内容 | 状态 |
|---|---|---|
| P4.1 | AI 音乐生成服务选型调研 | ✅ 已完成 |
| P4.1-fix | 供应商可用性与版权/API 复核 | ✅ 已完成 |
| **P4.2（本批）** | **最小 PoC 接入设计** | ✅ 本批交付 |
| P4.3 | 最小 mock/adapter 实现（不接真实 API） | 🔜 下一步 |
| P4.4 | 真实 Stable Audio API 接入（需人工注册账号 + credits） | ⏳ 计划中 |
| P4.5 | DSP 后处理 + 成本与安全控制 | ⏳ 计划中 |

### 1.2 前置结论（来自 P4.1 / P4.1-fix）

- **主方案**：Stable Audio 3.0 Large API（platform.stability.ai）
- **备选**：MusicGen via Replicate（CC-BY-NC 4.0 非商业，仅 fallback）
- **预置音频**：永久保留，作为生成失败/超时/未接入时的最终 fallback
- **P4 真正 AI 音乐生成是必做项**，但本批仍是 PoC **设计**，不是正式接入

### 1.3 本批目标

基于 P4.1 / P4.1-fix 的调研结果，设计最小可行接入方案：

1. 后端接口设计（Cloudflare Pages Functions）
2. 任务状态流设计
3. 数据存储设计（D1 表 + R2 路径，不立即迁移）
4. Prompt 映射设计（5 类 targetState → Stable Audio prompt）
5. 前端流程设计（最小 UI 流程）
6. 成本与安全控制设计（不实现）
7. P4.3 实施任务拆分

### 1.4 重要约束（本批遵守）

- 暂不调用真实 Stable Audio API
- 不写死任何 API Key
- 不实际生成付费音频
- 不改 D1 schema（只设计，不迁移）
- 不改 Cloudflare Functions（只设计，不实现）
- 不改前端播放逻辑（只设计，不实现）
- 不做医疗化表达
- 保留预置音频作为 fallback

---

## 二、P4.2 目标

### 2.1 设计目标

| 目标 | 说明 |
|---|---|
| 接口设计 | 定义 `/api/generate-music` 和 `/api/music-status` 的请求/响应格式 |
| 状态流设计 | 定义生成任务的 6 个状态及前端展示策略 |
| D1 设计 | 设计 `music_generation_jobs` 表结构（不立即迁移） |
| R2 设计 | 设计生成音频的存储路径与生命周期 |
| Prompt 映射 | 5 类 targetState → Stable Audio 中英 prompt 模板 |
| 前端流程 | 最小 UI 流程：创建 job → 轮询 → 播放/fallback |
| 成本与安全 | 限流、超时、内容过滤、清理策略（设计不实现） |
| 任务拆分 | P4.3 实施的详细任务列表 |

### 2.2 非目标（本批不做）

- ❌ 不调用真实 Stable Audio API
- ❌ 不写 Pages Function 代码
- ❌ 不改 D1 schema
- ❌ 不改前端代码
- ❌ 不实际生成音频
- ❌ 不接入 API Key

---

## 三、接口设计

### 3.1 POST /api/generate-music

创建音乐生成任务，返回 jobId 与 fallback 预置音频信息。

#### 3.1.1 请求

```
POST /api/generate-music
Content-Type: application/json
Origin: https://xinxian-music.xyz
```

```json
{
  "sessionId": "sess_abc123",
  "targetState": "sleep",
  "generationPrompt": "ambient sleep music, theta waves, soft piano, rain texture, no vocals, 8 minutes",
  "durationSeconds": 480,
  "moodProfile": {
    "valence": -0.3,
    "arousal": 0.2,
    "intensity": 0.7,
    "tags": ["紧绷", "思绪过载"]
  },
  "clientVersion": "v1.0.0"
}
```

**字段说明**：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `sessionId` | string | ✅ | 心弦会话 ID（贯穿 MoodInput → Plan → Feedback） |
| `targetState` | string | ✅ | sleep / regulate / soothe / focus / energize |
| `generationPrompt` | string | ✅ | M5 `EmotionToMusicPlanMapper` 生成的英文提示词 |
| `durationSeconds` | number | ✅ | 推荐时长（秒），范围 180-480 |
| `moodProfile` | object | ❌ | 情绪画像（valence/arousal/intensity/tags），用于成本日志与未来优化 |
| `clientVersion` | string | ❌ | 客户端版本号 |

**隐私约束**：
- ❌ 不上传 `moodText`（用户心境原文）
- ✅ `generationPrompt` 已是 M5 脱敏的英文描述
- ✅ `moodProfile.tags` 是 LLM 提取的情绪标签，非原文

#### 3.1.2 响应（成功创建）

```json
{
  "ok": true,
  "jobId": "job_20260712_abc123",
  "status": "queued",
  "fallbackTrack": {
    "audioAssetId": "sleep_01",
    "audioAssetTitle": "睡前舒缓 · Theta 入眠",
    "audioUrl": "/assets/music/sleep_01.mp3"
  },
  "estimatedSeconds": 45,
  "provider": "stable-audio-3.0-large",
  "createdAt": "2026-07-12T10:00:00.000Z"
}
```

**字段说明**：

| 字段 | 类型 | 说明 |
|---|---|---|
| `ok` | boolean | 是否成功创建 job |
| `jobId` | string | 生成任务唯一 ID，用于后续轮询 |
| `status` | string | 初始状态，固定为 `queued` |
| `fallbackTrack` | object | **立即返回**预置音频信息，前端可先播放 fallback，生成完成后再切换 |
| `estimatedSeconds` | number | 预计生成耗时（秒），用于前端进度展示 |
| `provider` | string | 生成供应商标识 |
| `createdAt` | string | ISO8601 创建时间 |

#### 3.1.3 响应（失败创建 / 限流）

```json
{
  "ok": false,
  "reason": "rate_limited",
  "fallbackTrack": {
    "audioAssetId": "sleep_01",
    "audioAssetTitle": "睡前舒缓 · Theta 入眠",
    "audioUrl": "/assets/music/sleep_01.mp3"
  }
}
```

**失败原因枚举**：

| reason | 说明 | 前端处理 |
|---|---|---|
| `rate_limited` | 超过每日/每 IP 生成次数限制 | 直接播放 fallbackTrack |
| `invalid_prompt` | prompt 含禁用内容 | 直接播放 fallbackTrack |
| `duration_out_of_range` | 时长不在 180-480 秒 | 直接播放 fallbackTrack |
| `service_unavailable` | 生成服务暂未启用（P4.3 mock 阶段） | 直接播放 fallbackTrack |
| `internal_error` | 未知错误 | 直接播放 fallbackTrack |

**关键设计**：**所有失败都返回 fallbackTrack**，前端永远有音频可播，用户体验零中断。

### 3.2 GET /api/music-status?id=xxx

查询生成任务状态。

#### 3.2.1 请求

```
GET /api/music-status?id=job_20260712_abc123
Origin: https://xinxian-music.xyz
```

#### 3.2.2 响应

```json
{
  "ok": true,
  "jobId": "job_20260712_abc123",
  "status": "succeeded",
  "audioUrl": "https://r2.xinxian-music.xyz/generated-music/2026/07/job_20260712_abc123.mp3",
  "fallbackTrack": {
    "audioAssetId": "sleep_01",
    "audioAssetTitle": "睡前舒缓 · Theta 入眠",
    "audioUrl": "/assets/music/sleep_01.mp3"
  },
  "errorCode": null,
  "progress": 100,
  "elapsedSeconds": 42
}
```

**字段说明**：

| 字段 | 类型 | 说明 |
|---|---|---|
| `ok` | boolean | 查询是否成功 |
| `jobId` | string | 任务 ID |
| `status` | string | 见状态流设计（第四节） |
| `audioUrl` | string\|null | 生成成功时返回 R2 音频 URL，否则 null |
| `fallbackTrack` | object | 始终返回，状态为 failed/fallback 时前端使用 |
| `errorCode` | string\|null | 失败时的错误码 |
| `progress` | number | 0-100 进度百分比（估算） |
| `elapsedSeconds` | number | 已耗时（秒） |

### 3.3 POST /api/music-cancel（可选，P4.4+）

取消生成任务。P4.2 只设计，不实现。

```json
// 请求
{ "jobId": "job_20260712_abc123" }

// 响应
{ "ok": true, "status": "cancelled" }
```

### 3.4 接口约束

| 约束 | 说明 |
|---|---|
| CORS | 与 `/api/analyze-mood` 共用白名单（仅心弦自有域名 + 本地开发） |
| 限流 | 每 IP 每分钟 5 次、每日 20 次（Cloudflare 限流规则） |
| 超时 | `generate-music` 创建请求 10s 超时；`music-status` 轮询 5s 超时 |
| 缓存 | `Cache-Control: no-store`（与 `/api/*` 一致） |
| API Key | `STABILITY_API_KEY` 从 Cloudflare env 读取，不泄露到前端 |
| 错误处理 | 任何异常都返回 200 + `ok:false` + fallbackTrack，绝不返回 5xx |

---

## 四、任务状态流设计

### 4.1 状态定义

| 状态 | 说明 | 后端动作 | 前端展示 |
|---|---|---|---|
| `queued` | 任务已入队，等待生成 | 写入 D1 job 记录 | 显示「已加入生成队列」+ 进度条 5% |
| `generating` | 正在调用 Stable Audio API 生成 | POST /v2/audio/stable-audio-3.0 | 显示「正在生成专属音乐...」+ 进度条 10-70% |
| `storing` | 生成完成，正在下载并上传 R2 | 下载音频 → 上传 R2 | 显示「正在准备音频...」+ 进度条 70-95% |
| `succeeded` | 生成成功，音频已上传 R2 | 更新 D1 job.audio_url | 进度条 100% → 自动切换播放 audioUrl |
| `failed` | 生成失败（API 错误/内容拒绝/超时） | 更新 D1 job.error_code | 显示「生成未成功，已为你播放预置音频」→ 播放 fallbackTrack |
| `fallback` | 主动降级（限流/服务未启用/P4.3 mock 阶段） | 不调用真实 API | 显示「正在播放预置音频」→ 播放 fallbackTrack |

### 4.2 状态流转图

```
                    POST /api/generate-music
                            │
                            ▼
                       ┌─────────┐
                       │ queued  │
                       └────┬────┘
                            │ (立即返回 jobId + fallbackTrack)
                            ▼
                    ┌──────────────┐
              ┌────→│  generating  │←────┐
              │     └──────┬───────┘     │
              │            │             │
              │     ┌──────▼───────┐     │
              │     │   storing    │     │
              │     └──────┬───────┘     │
              │            │             │
              │     ┌──────▼───────┐     │
              │     │  succeeded   │     │ (重试，P4.5+)
              │     └──────────────┘     │
              │                          │
              │     ┌──────────────┐     │
              └─────│   failed     │─────┘
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  fallback    │ (前端自动切换预置音频)
                    └──────────────┘
```

### 4.3 进度估算策略

由于 Stable Audio API 不提供实时进度，采用**基于耗时估算**的虚拟进度：

| 状态 | progress 值 | 说明 |
|---|---|---|
| `queued` | 5% | 固定值 |
| `generating` | 10-70% | 按 `elapsedSeconds / estimatedSeconds * 0.6 + 10` 线性增长，上限 70% |
| `storing` | 70-95% | 按 `elapsedSeconds - generatingTime` 估算，上限 95% |
| `succeeded` | 100% | 固定值 |
| `failed` / `fallback` | 保持当前值 | 不再增长 |

**关键设计**：进度永远不超过 95% 直到真正 `succeeded`，避免「100% 后卡住」的体验。

### 4.4 超时策略

| 超时点 | 时长 | 动作 |
|---|---|---|
| `queued` → `generating` 等待 | 30s | 自动转 `fallback` |
| `generating` 单次调用 | 60s | 自动转 `fallback` |
| `storing` 下载+上传 R2 | 30s | 自动转 `fallback` |
| 总耗时（queued → succeeded） | 120s | 强制转 `fallback` |
| 前端轮询间隔 | 3s | — |
| 前端最大轮询时长 | 150s | 停止轮询，播放 fallback |

---

## 五、数据存储设计

### 5.1 D1 表设计：music_generation_jobs

> ⚠️ **本批只设计，不迁移**。P4.3 实施阶段创建迁移脚本。

#### 5.1.1 表结构

```sql
-- 心弦 · AI 音乐生成任务记录表（P4.2 设计，P4.3 迁移）
-- 数据库：xinxian-feedback（复用现有 D1）
-- 说明：记录每次 AI 音乐生成任务的状态、成本、音频 URL

CREATE TABLE IF NOT EXISTS music_generation_jobs (
  id              TEXT PRIMARY KEY,           -- job ID，格式 job_{yyyyMMdd}_{random}
  session_id      TEXT NOT NULL,              -- 心弦会话 ID（关联 feedback 表 listeningSessionId）
  target_state    TEXT NOT NULL,              -- sleep / regulate / soothe / focus / energize
  prompt          TEXT NOT NULL,              -- 发送给 Stable Audio 的英文 prompt
  provider        TEXT NOT NULL DEFAULT 'stable-audio-3.0-large',  -- 生成供应商
  status          TEXT NOT NULL DEFAULT 'queued',  -- queued/generating/storing/succeeded/failed/fallback
  audio_url       TEXT,                       -- 生成成功后的 R2 音频 URL
  fallback_audio_asset_id TEXT,               -- fallback 预置音频 ID（如 sleep_01）
  error_code      TEXT,                       -- 失败时的错误码
  cost_estimate   REAL DEFAULT 0,             -- 预估成本（USD）
  duration_seconds INTEGER NOT NULL,          -- 请求时长（秒）
  actual_duration_seconds INTEGER,            -- 实际生成时长（秒）
  client_version  TEXT,                       -- 客户端版本号
  created_at      TEXT NOT NULL,              -- ISO8601 创建时间
  updated_at      TEXT NOT NULL,              -- ISO8601 更新时间
  completed_at    TEXT                        -- ISO8601 完成时间（succeeded/failed/fallback）
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_music_jobs_session_id ON music_generation_jobs(session_id);
CREATE INDEX IF NOT EXISTS idx_music_jobs_status ON music_generation_jobs(status);
CREATE INDEX IF NOT EXISTS idx_music_jobs_created_at ON music_generation_jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_music_jobs_target_state ON music_generation_jobs(target_state);
```

#### 5.1.2 字段语义

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | TEXT PK | job ID，格式 `job_{yyyyMMdd}_{8位随机}`，便于排序与去重 |
| `session_id` | TEXT | 关联 `feedback.listeningSessionId`，可串联「生成任务 → 用户反馈」 |
| `target_state` | TEXT | sleep / regulate / soothe / focus / energize |
| `prompt` | TEXT | 发送给 Stable Audio 的完整英文 prompt（脱敏后，不含用户原文） |
| `provider` | TEXT | `stable-audio-3.0-large` / `musicgen-large` / `mock`（P4.3） |
| `status` | TEXT | 任务当前状态 |
| `audio_url` | TEXT | R2 音频 URL，仅 succeeded 时有值 |
| `fallback_audio_asset_id` | TEXT | fallback 使用的预置音频 ID |
| `error_code` | TEXT | 失败错误码：`api_timeout` / `api_error` / `content_rejected` / `r2_upload_failed` / `rate_limited` |
| `cost_estimate` | REAL | 预估成本（USD），基于 Stability API credit 单价 |
| `duration_seconds` | INTEGER | 请求时长（180-480） |
| `actual_duration_seconds` | INTEGER | 实际生成音频时长（可能略短于请求） |
| `client_version` | TEXT | 客户端版本，用于版本过滤 |
| `created_at` | TEXT | ISO8601，如 `2026-07-12T10:00:00.000Z` |
| `updated_at` | TEXT | 每次状态变更时更新 |
| `completed_at` | TEXT | 进入终态（succeeded/failed/fallback）时设置 |

#### 5.1.3 与现有 feedback 表的关系

```
music_generation_jobs.session_id  ←→  feedback.listeningSessionId
```

- **不建立外键约束**（D1/SQLite 性能考虑，逻辑关联即可）
- 反馈数据分析时可通过 `JOIN music_generation_jobs ON session_id = listeningSessionId` 串联：
  - 该次会话是「生成音频」还是「预置音频」？
  - 生成音频 vs 预置音频的用户反馈差异（消融实验扩展）
- `feedback.audioAssetId` 字段复用：生成成功时值为 `gen_{jobId}`，fallback 时值为预置名（如 `sleep_01`）

### 5.2 R2 存储设计

#### 5.2.1 Bucket 配置

| 配置项 | 值 |
|---|---|
| Bucket 名称 | `xinxian-music-gen` |
| 访问方式 | 私有读 + 签名 URL（P4.4） / 公开读（P4.3 PoC 简化） |
| 区域 | Cloudflare R2 自动 |
| 生命周期 | 30 天后自动删除（P4.4 配置） |

#### 5.2.2 存储路径

```
generated-music/{yyyy}/{mm}/{jobId}.mp3
```

**示例**：
```
generated-music/2026/07/job_20260712_abc123.mp3
```

**路径设计理由**：
- `{yyyy}/{mm}` 按年月分目录，便于生命周期清理与批量导出
- `{jobId}` 作为文件名，保证唯一性，便于从 D1 查询反查文件
- `.mp3` 格式（44.1kHz / 192kbps），just_audio Web 兼容性好

#### 5.2.3 生命周期策略

| 策略 | 说明 |
|---|---|
| 30 天后自动删除 | R2 lifecycle rule，按 `generated-music/` 前缀 |
| 热门音频缓存（P4.5+） | 按 targetState 预生成 5 个缓存音频，长期保留 |
| 清理日志 | D1 `music_generation_jobs` 记录保留（不删），仅 R2 文件清理 |

#### 5.2.4 访问控制

| 阶段 | 策略 |
|---|---|
| P4.3 PoC | R2 公开读，URL 直接返回 |
| P4.4 正式 | R2 私有读，Pages Function 生成签名 URL（有效期 1 小时） |
| P4.5+ | 可选 CDN 缓存 + 防盗链 |

---

## 六、Prompt 映射设计

### 6.1 映射原则

1. **纯音乐 / instrumental**：所有 prompt 包含 `instrumental, no vocals, no lyrics`
2. **无医疗化表达**：不使用 `healing` / `therapy` / `cure` / `treatment` / `anxiety relief` / `insomnia treatment`
3. **控制节奏**：通过 BPM 关键词（`slow tempo` / `mid tempo`）
4. **控制情绪**：通过情绪关键词（`calm` / `peaceful` / `focused` / `gentle energizing`）
5. **控制乐器**：明确指定乐器（`soft piano` / `ambient pads` / `acoustic guitar`）
6. **控制环境声**：可选添加（`rain texture` / `ocean waves` / `forest ambient`）
7. **控制时长**：通过 `durationSeconds` 参数传递，不写入 prompt 文本
8. **优先英文**：Stable Audio 英文 prompt 效果最佳

### 6.2 5 类 targetState Prompt 映射

#### 6.2.1 sleep（睡前舒缓）

**中文语义**：辅助入眠，极慢节奏，低频脉冲，无起伏

**英文 prompt 模板**：
```
ambient sleep music, instrumental, no vocals, no lyrics,
very slow tempo 45-60 BPM, theta and delta brainwave frequencies,
sustained low drone, soft piano with long reverb,
gentle rain texture, no percussion, no sudden changes,
peaceful, dreamlike, minimal melody, 8 minutes
```

**音乐参数**：
- BPM：45-60
- 脑波：Theta / Delta
- 乐器：soft piano, ambient pads, low drone
- 环境声：rain texture
- 和声：sustained minor, no progression

#### 6.2.2 soothe（正念陪伴）

**中文语义**：正念冥想，空灵 Pad，留白，自然声

**英文 prompt 模板**：
```
mindfulness meditation music, instrumental, no vocals, no lyrics,
slow tempo 60-70 BPM, ethereal pads, singing bowls,
sparse melody with long pauses, ocean wave texture,
open harmony, no rhythm section, spacious, contemplative,
gentle breathing pace, 6 minutes
```

**音乐参数**：
- BPM：60-70
- 脑波：Alpha
- 乐器：ethereal pads, singing bowls, soft chimes
- 环境声：ocean waves
- 和声：open fifths, suspended chords

#### 6.2.3 regulate（情绪调节）

**中文语义**：情绪降温，中慢节奏，和声色彩柔和过渡

**英文 prompt 模板**：
```
emotional regulation music, instrumental, no vocals, no lyrics,
mid-slow tempo 60-80 BPM, warm piano with cello,
gentle harmonic progression from minor to major,
soft string pads, light percussion with brushes,
gradual dynamic build, hopeful, comforting,
forest ambient texture, 5 minutes
```

**音乐参数**：
- BPM：60-80
- 脑波：Alpha / low Beta
- 乐器：warm piano, cello, soft strings, brushed percussion
- 环境声：forest ambient
- 和声：minor → major progression

#### 6.2.4 focus（专注恢复）

**中文语义**：专注背景，极简动机重复，无歌词无突变

**英文 prompt 模板**：
```
focus background music, instrumental, no vocals, no lyrics,
mid tempo 80-100 BPM, minimal repetitive motif,
clean electric piano, subtle synth arpeggio,
steady but unobtrusive rhythm, no dynamic surprises,
neutral emotion, clear, organized, structured,
no ambient texture, 5 minutes
```

**音乐参数**：
- BPM：80-100
- 脑波：Beta
- 乐器：electric piano, synth arpeggio, light percussion
- 环境声：无（保持清晰）
- 和声：static, repetitive

#### 6.2.5 energize（温和充能）

**中文语义**：温和提升能量，明亮和声，轻打击乐，不喧闹

**英文 prompt 模板**：
```
gentle energizing music, instrumental, no vocals, no lyrics,
mid-upbeat tempo 100-120 BPM, bright acoustic guitar,
warm major harmony, light hand percussion,
uplifting but not aggressive, morning sunshine feel,
soft brass accents, steady groove,
subtle bird song texture, 4 minutes
```

**音乐参数**：
- BPM：100-120
- 脑波：Beta / low Gamma
- 乐器：acoustic guitar, light percussion, soft brass
- 环境声：bird song
- 和声：bright major

### 6.3 动态参数注入

Prompt 模板中的数值会根据 `MoodProfile` 动态调整：

| MoodProfile 字段 | 影响 |
|---|---|
| `arousal` 高（>0.6） | BPM 取范围上限，减少环境声 |
| `arousal` 低（<0.3） | BPM 取范围下限，增加环境声 |
| `valence` 低（<-0.3） | 和声偏 minor，乐器减少 |
| `valence` 高（>0.3） | 和声偏 major，乐器丰富 |
| `intensity` 高（>0.7） | 动态范围增大，情感更浓 |

### 6.4 Prompt 安全过滤

在发送给 Stable Audio 前，Pages Function 做以下过滤：

| 过滤规则 | 处理 |
|---|---|
| 包含医疗关键词（`heal` / `cure` / `treat` / `therapy` / `anxiety` / `insomnia`） | 替换为中性词 |
| 包含自残/暴力关键词 | 拒绝，返回 `invalid_prompt` |
| 长度 > 500 字符 | 截断到 500 |
| 包含用户原文片段 | 拒绝（不应出现，M5 已脱敏） |

---

## 七、前端流程设计

### 7.1 最小 UI 流程

#### 7.1.1 方案页（PlanScreen）

在现有方案页底部新增「生成专属音乐（实验）」入口：

```
┌─────────────────────────────────┐
│  疗愈方案展示                    │
│  ├─ 为什么推荐这段音乐           │
│  ├─ 推荐理由                     │
│  ├─ 主要音乐目标                 │
│  ├─ 推荐时长                     │
│  ├─ 音频标题                     │
│  └─ 查看音乐参数（折叠）          │
│                                 │
│  ┌─────────────────────────────┐ │
│  │  ▶ 播放预置音频              │ │  ← 现有按钮，不变
│  └─────────────────────────────┘ │
│                                 │
│  ┌─────────────────────────────┐ │
│  │  ✨ 生成专属音乐（实验）     │ │  ← P4.3 新增（可折叠/默认收起）
│  └─────────────────────────────┘ │
└─────────────────────────────────┘
```

#### 7.1.2 生成进度页（MusicGenerationScreen，P4.3 新增）

点击「生成专属音乐」后，**保持预置音频可播**，同时显示生成进度：

```
┌─────────────────────────────────┐
│  ← 返回方案                      │
│                                 │
│       ✨ 正在生成专属音乐        │
│                                 │
│      ┌─────────────────┐        │
│      │   ◌ 呼吸圆动画    │        │  ← 复用 AnalysisScreen 呼吸圆
│      └─────────────────┘        │
│                                 │
│      ━━━━━━━━━░░░░░░ 65%        │  ← 进度条
│      正在生成专属音乐...          │
│      预计还需 15 秒              │
│                                 │
│  ┌─────────────────────────────┐ │
│  │  ▶ 先听预置音频（可选）       │ │  ← fallbackTrack 立即可播
│  └─────────────────────────────┘ │
└─────────────────────────────────┘
```

#### 7.1.3 生成完成

```
┌─────────────────────────────────┐
│  ← 返回方案                      │
│                                 │
│       ✨ 专属音乐已生成          │
│                                 │
│  ┌─────────────────────────────┐ │
│  │  ▶ 播放生成音频              │ │  ← 播放 audioUrl
│  └─────────────────────────────┘ │
│                                 │
│  ┌─────────────────────────────┐ │
│  │  改听预置音频                 │ │  ← 可切换回 fallback
│  └─────────────────────────────┘ │
└─────────────────────────────────┘
```

#### 7.1.4 生成失败 / 超时

```
┌─────────────────────────────────┐
│  ← 返回方案                      │
│                                 │
│    生成未成功，已为你播放预置音频  │
│                                 │
│  ┌─────────────────────────────┐ │
│  │  ▶ 播放预置音频              │ │  ← 自动播放 fallbackTrack
│  └─────────────────────────────┘ │
│                                 │
│  ┌─────────────────────────────┐ │
│  │  重新生成                    │ │  ← 可重试一次
│  └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### 7.2 前端轮询策略

```dart
// 伪代码（P4.3 实现）
Future<void> pollMusicStatus(String jobId) async {
  const pollInterval = Duration(seconds: 3);
  const maxPollDuration = Duration(seconds: 150);

  final startTime = DateTime.now();
  while (true) {
    final response = await http.get('/api/music-status?id=$jobId');
    final status = response['status'];

    // 更新 UI 进度
    updateProgress(response['progress']);

    if (status == 'succeeded') {
      // 切换播放生成音频
      playAudio(response['audioUrl']);
      return;
    }

    if (status == 'failed' || status == 'fallback') {
      // 播放预置音频
      playFallback(response['fallbackTrack']);
      return;
    }

    if (DateTime.now().difference(startTime) > maxPollDuration) {
      // 超时，播放预置音频
      playFallback(response['fallbackTrack']);
      return;
    }

    await Future.delayed(pollInterval);
  }
}
```

### 7.3 不阻塞原则

| 原则 | 说明 |
|---|---|
| 预置音频立即可播 | `generate-music` 响应即返回 `fallbackTrack`，用户无需等待 |
| 生成是可选实验 | 「生成专属音乐」入口默认折叠，用户可忽略 |
| 生成失败零中断 | 失败自动切换预置音频，用户无感知 |
| 返回方案页可继续播放 | 生成中可返回方案页，预置音频不受影响 |

---

## 八、Fallback 策略

### 8.1 Fallback 触发条件

| 条件 | 触发动作 |
|---|---|
| `generate-music` 返回 `ok:false` | 立即播放 `fallbackTrack` |
| `generate-music` 返回 `service_unavailable`（P4.3 mock 阶段） | 立即播放 `fallbackTrack` |
| 轮询 `music-status` 返回 `status:failed` | 播放 `fallbackTrack` |
| 轮询超时（150s） | 播放 `fallbackTrack` |
| Stable Audio API 返回内容拒绝 | 状态转 `failed`，播放 `fallbackTrack` |
| R2 上传失败 | 状态转 `failed`，播放 `fallbackTrack` |
| 用户主动取消 | 状态转 `cancelled`，播放 `fallbackTrack` |

### 8.2 Fallback 音频选择

`fallbackTrack` 由 Pages Function 根据 `targetState` 选择，复用现有 `AudioAssetCatalog` 4 级匹配算法：

| targetState | fallbackTrack.audioAssetId |
|---|---|
| `sleep` | `sleep_01` |
| `regulate` | `regulate_01` |
| `soothe` | `soothe_01` |
| `focus` | `focus_01` |
| `energize` | `energize_01` |

### 8.3 Fallback 数据记录

无论是否 fallback，D1 `music_generation_jobs` 都记录：

- `succeeded`：`audio_url` 有值，`fallback_audio_asset_id` 为 null
- `failed`/`fallback`：`audio_url` 为 null，`fallback_audio_asset_id` 有值，`error_code` 记录原因

这样后续可统计：生成成功率、各错误码分布、fallback 占比。

---

## 九、成本与安全控制设计（不实现）

### 9.1 成本控制

| 控制点 | 设计 | 实施批次 |
|---|---|---|
| 免费 credits 监控 | 25 免费 credits 用尽前告警 | P4.4 |
| 单次生成成本日志 | D1 `cost_estimate` 字段记录 | P4.3 |
| 每日成本上限 | 超过 $1/日 自动转 fallback | P4.5 |
| 预生成缓存 | 5 类 targetState 各预生成 1 个，命中则秒播 | P4.5 |
| R2 存储清理 | 30 天生命周期自动删除 | P4.4 |

### 9.2 安全控制

| 控制点 | 设计 | 实施批次 |
|---|---|---|
| 每 IP 限流 | 每分钟 5 次、每日 20 次 | P4.4（Cloudflare 限流规则） |
| 每 session 限流 | 每会话最多 1 次生成 | P4.3（D1 查重） |
| Prompt 内容过滤 | 医疗/暴力/自残关键词过滤 | P4.3 |
| 心境原文保护 | 不上传 moodText，只上传 generationPrompt | P4.3 |
| Prompt 长度限制 | 最大 500 字符 | P4.3 |
| API Key 隔离 | `STABILITY_API_KEY` 仅在 Cloudflare env | P4.4 |
| 签名 URL | R2 音频私有读 + 1 小时签名 | P4.4 |

### 9.3 成本日志结构

D1 `music_generation_jobs.cost_estimate` 记录每次生成预估成本：

```
cost_estimate = credits_used * $0.01
```

示例：Stable Audio 3.0 Large 一次生成约 5-10 credits，即 $0.05-0.10。

---

## 十、不做事项（本批明确不做）

| 不做项 | 原因 |
|---|---|
| ❌ 调用真实 Stable Audio API | 本批是设计，P4.4 才接入真实 API |
| ❌ 写 Pages Function 代码 | P4.3 实施 |
| ❌ 改 D1 schema | P4.3 迁移 |
| ❌ 改前端播放逻辑 | P4.3 实施 |
| ❌ 接入 API Key | P4.4 人工注册后 |
| ❌ 实际生成音频 | P4.4 |
| ❌ 接入 Replicate MusicGen | P4.5 可选 |
| ❌ DSP 后处理 | P4.5 |
| ❌ 签名 URL | P4.4 |
| ❌ 预生成缓存 | P4.5 |

---

## 十一、P4.3 实施任务拆分

### 11.1 P4.3 目标

实现**最小 mock/adapter**，不接真实 Stable Audio API：

- 新增 Pages Function `/api/generate-music`（返回 mock jobId + fallbackTrack）
- 新增 Pages Function `/api/music-status`（模拟状态流转，3-5 秒后返回 succeeded 或随机 failed）
- 新增 D1 迁移：`music_generation_jobs` 表
- 新增前端 `MusicGenerationScreen` + 轮询逻辑
- 新增 `AudioGenerationPort` 的 `StableAudioGenerator` 实现（P4.3 阶段返回 mock）
- 完整 fallback 到预置音频

### 11.2 任务列表

| 编号 | 任务 | 说明 |
|---|---|---|
| T1 | D1 迁移脚本 | `schema/music_generation_jobs.sql`，创建表 + 索引 |
| T2 | Pages Function: generate-music | `functions/api/generate-music.js`，接收请求、写 D1 job、返回 mock jobId + fallbackTrack |
| T3 | Pages Function: music-status | `functions/api/music-status.js`，查询 D1 job、模拟状态流转、返回状态 |
| T4 | Mock 生成器 | `StableAudioGenerator`（mock 模式），3-5 秒后随机 succeeded/failed |
| T5 | Prompt 映射器 | `StableAudioPromptMapper`，5 类 targetState → 英文 prompt（第六节） |
| T6 | 前端：MusicGenerationScreen | 生成进度页 UI，呼吸圆 + 进度条 + fallback 播放 |
| T7 | 前端：方案页入口 | 「生成专属音乐（实验）」按钮，默认折叠 |
| T8 | 前端：轮询逻辑 | `MusicGenerationPoller`，3s 间隔，150s 超时 |
| T9 | 前端：音频切换 | 生成成功切换 audioUrl，失败播放 fallbackTrack |
| T10 | 数据串联 | `feedback.audioAssetId` 标记 `gen_{jobId}` 或预置名 |
| T11 | 限流（基础） | 每 session 最多 1 次生成（D1 查重） |
| T12 | Prompt 过滤 | 医疗/暴力关键词过滤 |
| T13 | 测试 | 单元测试 + 集成测试 |
| T14 | 验证 | flutter analyze + flutter test + flutter build web --release |
| T15 | README 同步 | P4.3 完成状态 |

### 11.3 P4.4 及以后（规划）

| 批次 | 内容 |
|---|---|
| P4.4 | 真实 Stable Audio API 接入（需人工注册账号 + credits + API Key 配置） |
| P4.5 | DSP 后处理 + 成本与安全控制 + 预生成缓存 |
| P4.6（可选） | MusicGen via Replicate 二级 fallback |

---

## 十二、风险与待确认问题

### 12.1 技术风险

| 风险 | 等级 | 缓解措施 |
|---|---|---|
| Stable Audio API 实际响应时间未知 | 中 | P4.3 mock 阶段用 3-5s 模拟；P4.4 实测后调整 `estimatedSeconds` |
| Cloudflare Pages Functions CPU 时限 | 高 | 异步任务模式，Function 只做 D1 读写 + API 转发，不阻塞等待 |
| R2 公开读 vs 签名 URL 复杂度 | 中 | P4.3 用公开读简化，P4.4 改签名 URL |
| 生成音频质量不稳定 | 中 | 用户反馈数据驱动 prompt 优化；P4.5 预生成多版本取最佳 |
| 前端轮询对 Pages Functions 调用量 | 中 | 3s 间隔 + 150s 超时 = 最多 50 次调用/会话 |

### 12.2 待确认问题（P4.4 前需确认）

1. Stability AI 账号注册与 25 免费 credits 到账
2. Stable Audio 3.0 Large API 单次生成 credit 成本
3. API 速率限制
4. API 异步任务支持方式（同步/异步/webhook）
5. API 输出音频格式（MP3/WAV/码率）
6. Community License 全文审阅
7. 中文 prompt 支持程度（P4.4 PoC 实测）

---

## 十三、本批交付清单

| 交付物 | 路径 | 状态 |
|---|---|---|
| PoC 设计文档 | `docs/ai-music-generation-poc-design.md` | ✅ 本文件 |
| README 同步 | `README.md` P4.2 状态更新 + 文档链接 | ✅ |
| 版本号同步 | `lib/config/app_version.dart` → `P4-design-1` | ✅ |
| 验证 | `flutter analyze` 通过 | ✅ |
| 业务代码改动 | 无（本批只新增文档 + 版本号） | ✅ |
| D1 schema 改动 | 无（只设计，不迁移） | ✅ |
| Cloudflare Functions 改动 | 无（只设计，不实现） | ✅ |
| 前端代码改动 | 无（只设计，不实现） | ✅ |
| API Key 接入 | 无 | ✅ |

---

> **免责声明**：本文档仅作接入设计参考，不构成法律建议。心弦定位为辅助情绪调节与正念陪伴工具，**不提供医疗诊断或治疗**，音乐生成不写「治疗焦虑 / 治疗失眠 / 治愈」等医疗化措辞。截至 P4.2（2026-07-12），心弦**尚未接入任何真实 AI 音乐生成 API**，当前播放仍为本地预置音频。P4 真正 AI 音乐生成仍为必做项。
