# 心弦 · AI 音乐生成服务选型调研（P4-AI-Music-v1.0 第一批）

> 版本：`v1.0.0 · P4-research-1 · 2026-07-12`
> 范围：本批只做技术调研与方案设计，**不接入代码、不调用付费生成接口、不改现有播放逻辑、不改 D1 schema、不改 Cloudflare Functions**。
> 定位：为 P4 后续批次（P4.2 起的真实接入）提供选型依据与架构草图。

---

## 一、背景与目标

### 1.1 背景

心弦当前（P3-data-3 / v1.0.0）已完成「自然语言 → AI 情绪解析 → 音乐参数映射 → **本地预置音频** 播放 → 用户反馈」的完整闭环，但音频侧始终使用 `music/` 目录下的 5 类预置 mp3 素材（`sleep_01.mp3` / `regulate_01.mp3` / `soothe_01.mp3` / `focus_01.mp3` / `energize_01.mp3`），由 `AudioAssetCatalog` 按 targetState 4 级匹配算法选择，**并非实时 AI 生成音频**。

M5 阶段的 `EmotionToMusicPlanMapper` 已经在 `HealingMusicPlan.generationPrompt` 字段中预留了文本提示词数据通道，P4 的目标就是把这个通道接通到真实 AI 音乐生成模型。

### 1.2 目标

- 调研可用于「根据用户心境生成无歌词、疗愈/放松/专注/睡前场景音乐」的 AI 音乐生成方案
- 对比商业 API 与开源自部署两条路径
- 输出候选方案对比表 + 推荐 Top 2 + 不推荐方案
- 输出 P4 推荐技术路线与接入架构草图
- 识别风险与待确认问题，给出 P4.2 下一步任务建议

### 1.3 重要约束（P4 第一批）

- **不接入真实 API Key**
- **不写死任何第三方密钥**
- **不调用付费生成接口**
- **不改现有预置音频播放逻辑**
- **不改 D1 schema**
- **不改 Cloudflare Functions**
- **不做医疗化表达**，不写「治疗焦虑 / 治疗失眠 / 治愈」
- **保留预置音频作为未来 fallback 方案**

---

## 二、心弦的音乐生成需求

### 2.1 场景与 targetState 对应

心弦的 5 类 targetState 直接对应 5 类音乐生成场景：

| targetState | 场景语义 | 音乐特征期望 |
|---|---|---|
| `sleep` | 睡前舒缓 | 极慢 BPM（40-60）、长持续音、低频脉冲、无节奏起伏 |
| `regulate` | 情绪调节 | 中慢 BPM（60-80）、和声色彩柔和、有呼吸感的动态 |
| `soothe` | 正念陪伴 | 慢 BPM（60-70）、空灵 Pad、自然环境声、留白 |
| `focus` | 专注恢复 | 中速 BPM（80-100）、极简动机重复、无歌词无突变 |
| `energize` | 温和充能 | 中快 BPM（100-120）、明亮和声、轻打击乐、不喧闹 |

### 2.2 硬性需求

1. **必须支持纯音乐 / 无歌词**：心弦定位为辅助情绪调节与正念陪伴工具，不生成带人声歌词的内容
2. **必须支持文本 prompt 输入**：复用 M5 已生成的 `generationPrompt`
3. **必须支持中英文 prompt**：用户心境输入为中文，`generationPrompt` 由 LLM 生成英文描述（M5 现状），需两者兼容
4. **必须支持时长控制**：心弦推荐时长在 3-8 分钟，生成模型需能指定或接近该时长
5. **必须可商用 / 无版权诉讼风险**：心弦已部署至正式域名 `xinxian-music.xyz`，输出素材需可合法播放
6. **必须支持异步生成 + 后端任务**：生成耗时通常 30s-6min，不能阻塞前端
7. **必须可降级到预置音频**：失败时无缝 fallback，用户体验不受影响

### 2.3 加分项（非必须）

- 支持风格 / BPM / 情绪 / 乐器 / 环境声等结构化控制参数
- 支持旋律引导（melody conditioning），用一段参考旋律生成变体
- 支持移动端推理（为 P5 移动端 App 预留）
- 训练数据完全授权，无版权诉讼历史
- 有官方 API（不依赖第三方 wrapper）
- 成本可控（单次生成 < $0.10）

---

## 三、候选方案对比表

调研覆盖以下 7 类主流方案（截至 2026-07）：

### 3.1 总览对比

| 方案 | 类型 | 官方 API | 纯音乐 | 中文 prompt | 时长控制 | 风格/BPM/情绪控制 | 生成耗时 | 单次成本 | 版权/商用风险 | Cloudflare Pages 适用性 | 移动端适用性 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Suno v5.5** | 商业平台 | ❌ 无官方（仅第三方 wrapper） | ✅ `make_instrumental` | ✅ | 最长 5-8 min | 风格/情绪强 | ~30s-1min | $0.03-0.15（第三方） | ⚠️ 高（UMG/Sony 诉讼中，输出版权归用户但 AI 作品美国无版权保护） | ⚠️ 需异步轮询，第三方 wrapper 不稳定 | 仅 Web |
| **Udio v4** | 商业平台 | ❌ 无官方 API | ✅ instrumental 模式 | ✅ 50+ 语言 | 最长 10 min | 强（inpainting/stems） | ~1-2min | 平台订阅 $10-30/mo | ⚠️ 中（UMG/WMG 已和解授权，Sony 仍诉讼中） | ❌ 无 API，无法程序化调用 | 仅 Web |
| **Stable Audio 3.0** | 商业 + 开源权重 | ✅ 官方 API（platform.stability.ai） | ✅ 仅纯音乐 | ⚠️ 英文为主 | ✅ 精确到秒，最长 6+ min | ✅ 风格/时长/LoRA | ~10-30s | 按秒计费（约 $0.01-0.05/分钟） | ✅ 低（训练数据 100% AudioSparx 授权，无诉讼） | ✅ 同步 + 异步 webhook | ✅ Small 模型可移动端 |
| **MusicGen / AudioCraft**（Meta） | 开源 + Replicate | ❌ 无官方（Replicate/HF/自部署） | ✅ 仅纯音乐 | ⚠️ 英文为主 | ✅ 可指定 duration | ✅ 文本 + melody conditioning | 30s-6min | Replicate ~$0.052-0.074/run | ⚠️ 中（代码 MIT，权重 CC-BY-NC 4.0 **非商业**） | ✅ Replicate API 异步 | ❌ 需 16GB+ VRAM |
| **ElevenLabs Music** | 商业 API | ✅ 官方 + FAL.AI | ✅ `force_instrumental` | ⚠️ 英文 | ✅ 按分钟 | ⚠️ 仅 prompt 文本 | <25s | $0.80/min（较贵） | ⚠️ 中（训练数据未完全公开） | ✅ FAL.AI 异步 | 仅 Web |
| **MiniMax Music 2.5** | 商业 API | ✅ FAL.AI | ✅ `[Instrumental]` tag | ✅ 中文友好 | ⚠️ 50-76s 较短 | ⚠️ 仅 prompt | ~10-20s | $0.035/gen（最便宜） | ⚠️ 中（训练数据未公开） | ✅ FAL.AI 异步 | 仅 Web |
| **Google Lyria 3 / RealTime** | 商业 API | ⚠️ 受限（Vertex AI 邀请制） | ✅ RealTime 仅器乐 | ✅ | ⚠️ RealTime 流式 | ⚠️ 仅 prompt | RealTime 实时 | 未公开 | ⚠️ 中（训练数据未公开） | ⚠️ WebSocket 不适合 Pages Functions | ❌ |

### 3.2 详细说明

#### 3.2.1 Suno v5.5（2026-03 发布）

- **优势**：质量标杆，ELO 1293 分；44.1kHz 立体声；支持 `make_instrumental` 纯音乐模式；中英文 prompt 都支持；时长最长 8 分钟
- **劣势**：**无官方 API**，必须通过第三方 wrapper（sunoapi.org / PiAPI / AIML API / CometAPI / Unifically）调用，法律风险高；训练数据诉讼未结（Warner 已和解，UMG/Sony 仍诉讼中）；AI 生成作品在美国无版权保护；Terms 禁止用于竞争性音乐生成产品
- **定价**：第三方 $0.03-0.15/generation；平台订阅 Pro $10/mo（500 首）、Premier $30/mo（2000 首）
- **适合心弦**：❌ 不推荐主用。无官方 API + 诉讼风险 + 第三方 wrapper 不稳定，不适合高校竞赛 Demo 的长期可维护性

#### 3.2.2 Udio v4（2026）

- **优势**：48kHz 立体声（音质最高）；最长 10 分钟；UMG/WMG 已和解授权；inpainting / stem separation / style transfer 等专业控制
- **劣势**：**无官方 API**，无法程序化调用；Sony 诉讼未结；主要面向制作人手动编辑，不适合自动化集成
- **适合心弦**：❌ 不推荐。无 API 是硬伤，无法接入 Pipeline

#### 3.2.3 Stable Audio 3.0（2026-05 发布）⭐

- **优势**：**有官方 API**（platform.stability.ai）；**训练数据 100% 授权**（AudioSparx），无版权诉讼历史；支持精确时长控制（秒级）；开源权重（Small/Medium 在 HuggingFace）；Community License（年营收 <$1M 免费）；支持 LoRA 微调；Small 模型 341M 参数可在移动端 Arm CPU 运行；四档模型（Small SFX / Small / Medium / Large）按需选择
- **劣势**：仅纯音乐（无心弦不需要的人声，反而契合需求）；prompt 以英文为主，中文需翻译；Large 模型需企业授权
- **定价**：按秒计费，约 $0.01-0.05/分钟；自部署免费（需 GPU）
- **适合心弦**：✅ **强推荐为主选方案**。官方 API + 授权数据 + 时长精确控制 + 移动端可推理，完美匹配心弦需求

#### 3.2.4 MusicGen / AudioCraft（Meta，2023-2024）

- **优势**：完全开源；Replicate 上 ~$0.052/run；支持 melody conditioning（旋律引导）；small/medium/large/melody 多档；纯函数式 Python API 易集成
- **劣势**：**权重 CC-BY-NC 4.0 非商业许可**（心弦已商用部署，需谨慎）；2024 年后无重大更新，质量明显低于 Suno/Udio/Stable Audio；自部署需 16GB+ VRAM GPU；仅英文 prompt
- **定价**：Replicate $0.052-0.074/run；自部署免费（需 GPU 硬件）
- **适合心弦**：⚠️ **备选方案**。非商业许可限制是硬伤，但若仅用于高校竞赛 Demo 阶段（非商业用途）可作 fallback，长期不推荐

#### 3.2.5 ElevenLabs Music（via FAL.AI）

- **优势**：API-first，FAL.AI 异步调用；`force_instrumental` 标志；44.1kHz/192kbps；<25s 生成
- **劣势**：$0.80/min 偏贵（8 分钟约 $6.4）；时长控制按分钟；训练数据未公开
- **适合心弦**：⚠️ 成本偏高，作为备选

#### 3.2.6 MiniMax Music 2.5（via FAL.AI）

- **优势**：$0.035/gen 最便宜；中文友好；`[Instrumental]` tag 支持纯音乐
- **劣势**：单次输出 50-76s 偏短，需多次拼接才能达到心弦 3-8 分钟需求；训练数据未公开
- **适合心弦**：⚠️ 时长不足是硬伤

#### 3.2.7 Google Lyria 3 / RealTime

- **优势**：RealTime 支持 WebSocket 实时器乐流式生成，创新性最强；Lyria 3（2026-02）支持人声
- **劣势**：Vertex AI 邀请制，未公开定价；WebSocket 不适合 Cloudflare Pages Functions 同步请求模型；训练数据未公开
- **适合心弦**：❌ 可用性不足，不适合当前阶段

---

## 四、推荐方案 Top 2

### 🥇 Top 1：Stable Audio 3.0（官方 API）

**推荐理由**：

1. **官方 API 稳定可用**：platform.stability.ai 提供 REST API + 异步 webhook，与心弦「Flutter Web → Pages Function → AI Provider」架构天然契合
2. **版权风险最低**：训练数据 100% 来自 AudioSparx 授权库，无任何诉讼历史，适合已部署至正式域名的 Demo
3. **纯音乐原生支持**：Stable Audio 定位就是 instrumental / SFX 生成，无心弦不需要的人声，无需额外 `instrumental` 标志
4. **时长精确控制**：可指定到秒，完美匹配心弦 3-8 分钟推荐时长（M5 `recommendationDuration`）
5. **移动端可推理**：Stable Audio Open Small（341M）可在 Arm CPU 运行，为 P5 移动端 App 预留路径
6. **开源权重 + Community License**：年营收 <$1M 免费，高校竞赛 Demo 完全适用；可自部署降低长期成本
7. **LoRA 微调能力**：未来可用心弦积累的反馈数据微调专属风格模型

**风险**：英文 prompt 为主，需在 `EmotionToMusicPlanMapper` 中确保 `generationPrompt` 为英文（M5 现状已满足）；Large 模型需企业授权（Demo 阶段用 Medium 即可）。

### 🥈 Top 2：MusicGen / AudioCraft（Replicate API）

**推荐理由**：

1. **完全开源可控**：代码 MIT，可自部署避免长期 API 依赖
2. **Replicate API 成本低**：~$0.052/run，适合 Demo 阶段高频迭代
3. **melody conditioning 独有能力**：可用一段参考旋律引导生成，未来可做「用户哼唱 → 变体生成」扩展
4. **纯音乐原生支持**：与 Stable Audio 一样不生成人声
5. **Python API 易集成**：Replicate 提供 REST + webhook，与 Pages Functions 异步模型兼容

**风险**：**权重 CC-BY-NC 4.0 非商业许可**是硬伤——心弦虽是高校竞赛 Demo，但已部署至正式域名且未来可能商业化，长期使用需替换或寻求商业授权；2024 年后无更新，质量低于 Stable Audio 3.0。

---

## 五、不推荐方案及原因

| 方案 | 不推荐原因 |
|---|---|
| **Suno v5.5** | 无官方 API，依赖第三方 wrapper（法律 + 稳定性双重风险）；UMG/Sony 诉讼未结；AI 生成作品在美国无版权保护；Terms 禁止用于竞争性音乐产品。高校 Demo 不应建立在不稳定第三方 wrapper 上。 |
| **Udio v4** | 无官方 API，无法程序化调用；主要面向制作人手动编辑；Sony 诉讼未结。 |
| **ElevenLabs Music** | $0.80/min 成本过高（8 分钟约 $6.4），不适合 Demo 阶段高频迭代；训练数据未公开。 |
| **MiniMax Music 2.5** | 单次输出 50-76 秒，无法满足心弦 3-8 分钟需求，需多次拼接增加复杂度。 |
| **Google Lyria 3 / RealTime** | Vertex AI 邀请制，未公开定价；WebSocket 流式不适合 Pages Functions 同步请求模型；可用性不足。 |

---

## 六、推荐的 P4 技术路线

### 6.1 总体路线

```
P4.1（本批，已完成）：技术调研 + 方案设计 + 架构草图
        ↓
P4.2：Stable Audio 3.0 官方 API 接入
        ├─ 新增 /api/generate-music Pages Function（异步任务提交）
        ├─ 新增 /api/music-status/{taskId}（轮询任务状态）
        ├─ 新增 Cloudflare R2 bucket 存储生成音频
        ├─ AudioGenerationPort 新增 StableAudioGenerator 实现
        └─ 失败自动 fallback 到 AudioAssetCatalog 预置音频
        ↓
P4.3：DSP 后处理接入
        ├─ AudioPostProcessorPort 从 Passthrough 替换为真实 DSP
        └─ 白噪音 / 粉红噪音 / EQ / 淡入淡出
        ↓
P4.4：成本与安全控制
        ├─ 每用户/每 IP 生成频次限流
        ├─ generationPrompt 长度限制 + 内容安全过滤
        ├─ R2 存储生命周期策略（自动清理 30 天前音频）
        └─ 生成失败率监控 + 告警
        ↓
P4.5：MusicGen 备选链路（可选）
        └─ 作为 Stable Audio 故障时的二级 fallback
```

### 6.2 关键设计原则

1. **预置音频永久保留**：`music/` 目录 5 类 mp3 不删除，作为生成失败时的最终 fallback，保证用户体验零中断
2. **Port 抽象不变**：`AudioGenerationPort` 接口不动，只新增实现类，UI 与上层 Pipeline 零改动（M1 架构红利）
3. **异步优先**：所有生成请求走异步任务模式（提交 → 轮询 → 完成），前端显示生成进度动画
4. **成本可控**：单次生成预算 < $0.10；超时 60s 未返回则 fallback 到预置音频
5. **隐私不变**：不上传用户心境原文给音乐生成 API，只传 `generationPrompt`（M5 已脱敏的英文描述）
6. **不做医疗化表达**：生成 prompt 模板统一使用「辅助放松 / 情绪调节 / 睡前舒缓 / 正念陪伴」措辞

---

## 七、接入架构草图

### 7.1 目标架构（P4.2 起实现）

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Web 前端                                           │
│  ├─ 心境输入 → AI 情绪解析 → 方案展示                       │
│  ├─ 点击播放 → 显示「生成中」动画                           │
│  ├─ 轮询 /api/music-status/{taskId}（每 3s）                │
│  └─ 生成完成 → 播放 R2 音频 URL / 失败 fallback 预置音频    │
└───────────────────────┬─────────────────────────────────────┘
                        │ 1. POST /api/generate-music
                        │    body: { generationPrompt, duration, targetState }
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Cloudflare Pages Functions（后端 API 网关）                │
│  ├─ /api/generate-music：                                   │
│  │    ├─ 鉴权 + 限流 + prompt 内容安全过滤                  │
│  │    ├─ 调用 Stable Audio API（异步提交）                  │
│  │    ├─ 返回 { taskId, status: 'pending', estimatedSec }   │
│  │    └─ API Key 从 env 读取，不泄露到前端                  │
│  ├─ /api/music-status/{taskId}：                            │
│  │    ├─ 查询 Stable Audio 任务状态                         │
│  │    ├─ 完成则下载音频 → 上传到 R2                         │
│  │    ├─ 返回 { status, audioUrl? }（R2 公开 URL 或签名）   │
│  │    └─ 超时 60s 仍未完成 → 返回 failed，前端 fallback     │
│  └─ /api/analyze-mood / submit-feedback / health：不变     │
└───────────┬───────────────────────────┬─────────────────────┘
            │                           │
            ▼                           ▼
┌───────────────────────┐   ┌─────────────────────────────┐
│  Stable Audio API     │   │  Cloudflare R2              │
│  platform.stability.ai│   │  bucket: xinxian-music-gen  │
│  ├─ POST /v2/generate │   │  ├─ /{sessionId}.mp3         │
│  │   (异步任务)       │   │  ├─ 公开读 / 私有签名 URL    │
│  ├─ GET /v2/result/   │   │  └─ 30 天生命周期自动清理    │
│  │   {id}             │   └─────────────────────────────┘
│  └─ API Key 从 env    │
└───────────────────────┘
            
            （可选 P4.5 二级 fallback）
            ▼
┌───────────────────────┐   ┌─────────────────────────────┐
│  Replicate API        │   │  Cloudflare D1（不变）       │
│  replicate.com        │   │  feedback 表 25 字段        │
│  ├─ meta/musicgen     │   │  ├─ 新增字段：无（P4 不改）  │
│  ├─ 异步 webhook      │   │  └─ audioAssetId 仍记录      │
│  └─ ~$0.052/run       │       「generated」或预置名      │
└───────────────────────┘   └─────────────────────────────┘
```

### 7.2 数据流时序

```
用户点击播放
  → Flutter 调 POST /api/generate-music { prompt, duration, targetState }
  → Pages Function 调 Stable Audio 异步提交，返回 taskId
  → Flutter 每 3s 轮询 GET /api/music-status/{taskId}
  → Pages Function 查 Stable Audio 任务状态
      ├─ pending/processing → 返回 { status: 'processing' }
      ├─ succeeded → 下载音频 → 上传 R2 → 返回 { status: 'done', audioUrl }
      └─ failed / 超 60s → 返回 { status: 'failed' }
  → Flutter 收到 audioUrl → 播放 just_audio
  → Flutter 收到 failed → fallback 到 AudioAssetCatalog 预置音频
  → 反馈页正常采集（audioAssetId 标记为「generated」或预置名）
```

### 7.3 关键约束映射

| 心弦约束 | 架构落点 |
|---|---|
| 前端零 API Key | Stable Audio Key 仅在 Pages Function env |
| 不改 D1 schema | `audioAssetId` 字段复用，值为 `gen_{sessionId}` 或预置文件名 |
| 保留预置音频 fallback | `AudioGenerationPort` 实现类内部 try/catch → `StockAudioGenerator` |
| 不上传心境原文 | 只传 `generationPrompt`（M5 已脱敏英文描述） |
| 成本可控 | 单次 60s 超时 + 每用户/IP 限流 + R2 30 天清理 |
| 移动端可扩展 | Stable Audio Small 模型未来可端侧推理 |

---

## 八、风险与待确认问题

### 8.1 技术风险

| 风险 | 等级 | 缓解措施 |
|---|---|---|
| Stable Audio API 响应慢（>60s） | 中 | 60s 超时 fallback 预置音频；预生成常用 targetState 缓存 |
| Cloudflare Pages Functions CPU 时限（Free 10ms / Paid 30s） | 高 | 异步任务模式，Function 只做提交 + 状态查询，不阻塞等待生成完成 |
| R2 存储成本累积 | 低 | 30 天生命周期自动清理；按 sessionId 命名便于追踪 |
| 生成音频质量不稳定 | 中 | 同一 prompt 预生成多版本取最佳；用户反馈数据驱动 prompt 优化 |
| 中文 prompt 翻译失真 | 低 | M5 `generationPrompt` 已为英文；翻译质量在 P4.2 测试验证 |

### 8.2 法律与合规风险

| 风险 | 等级 | 缓解措施 |
|---|---|---|
| Stable Audio 训练数据争议 | 低 | AudioSparx 100% 授权，无诉讼历史；Community License 明确 |
| 生成内容版权归属 | 低 | Stable Audio Community License 明确输出归用户所有 |
| 用户 prompt 含侵权内容 | 低 | Pages Function 内容安全过滤 + 关键词黑名单 |
| 音乐生成被滥用（批量下载） | 中 | 每用户/IP 限流 + 人机验证（可选） |

### 8.3 待确认问题（P4.2 前需确认）

1. **Stable Audio API 定价细节**：按秒还是按次？是否有 Demo/教育优惠？Free tier 额度？
2. **Cloudflare Pages Functions 异步任务最佳实践**：是否需要 Cloudflare Queues 或 Durable Objects？还是单纯轮询足够？
3. **R2 公开读 vs 签名 URL**：公开读成本更低但音频可被遍历，签名 URL 更安全但增加 Function 调用
4. **生成音频格式**：MP3 还是 WAV？码率？just_audio Web 兼容性？
5. **预生成缓存策略**：5 类 targetState 是否预生成一批缓存，命中则秒播，未命中再实时生成？
6. **MusicGen 非商业许可边界**：高校竞赛 Demo 是否算非商业？是否需在 README/About 显式声明？
7. **Cloudflare 限流规则扩展**：当前 Free 计划已用 1 条限流（analyze-mood），生成 API 限流如何配置？

---

## 九、下一步 P4.2 任务建议

### 9.1 P4.2 核心任务：Stable Audio API 接入

| 任务 | 说明 |
|---|---|
| 1. 申请 Stable Audio API Key | 注册 platform.stability.ai，确认 Free tier 额度与定价 |
| 2. 新增 Pages Function `/api/generate-music` | 异步提交生成任务，返回 taskId |
| 3. 新增 Pages Function `/api/music-status/{taskId}` | 轮询任务状态，完成则下载 + 上传 R2 |
| 4. 配置 Cloudflare R2 bucket | `xinxian-music-gen`，30 天生命周期 |
| 5. 新增 `StableAudioGenerator` 实现 `AudioGenerationPort` | 失败 fallback 到 `StockAudioGenerator` |
| 6. 前端播放页改造 | 显示生成进度动画；轮询逻辑；完成播放 R2 URL / 失败播放预置 |
| 7. 反馈数据兼容 | `audioAssetId` 标记 `gen_{sessionId}` 或预置名，D1 schema 不变 |
| 8. 限流 + 内容安全 | `/api/generate-music` 限流；prompt 关键词过滤 |
| 9. 环境变量配置 | `STABILITY_API_KEY`、`R2_BUCKET` 等写入 Cloudflare env |
| 10. 验证 | flutter analyze + flutter test + flutter build web --release + 线上全流程验收 |

### 9.2 P4.3 及以后（规划）

- **P4.3 DSP 后处理**：`AudioPostProcessorPort` 从 Passthrough 替换为真实 DSP（白噪音 / 粉红噪音 / EQ / 淡入淡出）
- **P4.4 成本与安全**：预生成缓存 + 限流监控 + R2 清理策略
- **P4.5（可选）MusicGen 二级 fallback**：Replicate API 作为 Stable Audio 故障时的备选

### 9.3 验证策略

- 本批（P4.1）：只新增文档 + 版本号，运行 `flutter analyze`（未改业务逻辑，可不运行 test/build）
- P4.2 起：完整 `flutter analyze` + `flutter test` + `flutter build web --release` + 线上手动验收

---

## 十、参考资料

### 10.1 商业平台

- Suno 官网：https://suno.com/
- Udio 官网：https://www.udio.com/
- Stable Audio 官网：https://www.stableaudio.com/
- Stable Audio 开发者平台：https://platform.stability.ai/
- ElevenLabs Music：https://elevenlabs.io/music
- MiniMax Music（via FAL.AI）：https://fal.ai/models/fal-ai/minimax-music
- Google Lyria：https://deepmind.google/models/lyria/

### 10.2 开源模型

- Meta AudioCraft / MusicGen：https://github.com/facebookresearch/audiocraft
- MusicGen on HuggingFace：https://huggingface.co/facebook/musicgen-large
- Stable Audio Open：https://huggingface.co/stabilityai/stable-audio-open-1.0
- MusicGen on Replicate：https://replicate.com/meta/musicgen

### 10.3 对比评测

- TeamDay「Best AI Music Generation Models 2026」：https://www.teamday.ai/blog/best-ai-music-models-2026
- eesel「8 best Suno alternatives in 2026」：https://www.eesel.ai/blog/suno-alternatives
- Neuronad「Suno vs Udio」：https://neuronad.com/udio-vs-suno/

### 10.4 法律与版权

- RIAA 诉 Suno/Udio 案件：https://www.riaa.com/record-companies-bring-landmark-cases-for-responsible-ai-againstsuno-and-udio/
- Stable Audio Community License：https://stability.ai/license
- MusicGen 权重许可 CC-BY-NC 4.0：https://github.com/facebookresearch/audiocraft/blob/main/LICENSE_weights

---

## 十一、本批交付清单

| 交付物 | 路径 | 状态 |
|---|---|---|
| 调研文档 | `docs/ai-music-generation-research.md` | ✅ 本文件 |
| README 同步 | `README.md` 第十一章 P4 路线图 + 文档链接 | ✅ |
| 版本号同步 | `lib/config/app_version.dart` → `P4-research-1` | ✅ |
| 验证 | `flutter analyze` 通过 | ✅ |
| 业务代码改动 | 无（本批只新增文档 + 版本号） | ✅ |
| D1 schema 改动 | 无 | ✅ |
| Cloudflare Functions 改动 | 无 | ✅ |
| 预置音频改动 | 无（永久保留作 fallback） | ✅ |

---

## 十二、P4.1-fix：供应商可用性复核（2026-07-12）

> 版本：`v1.0.0 · P4-research-1-fix1 · 2026-07-12`
> 目标：在正式进入 P4.2 接入前，复核 P4.1 推荐方案的 API 可用性、授权、成本和接入风险。**只做文档复核，不写接入代码，不调用真实 API。**

### 12.1 复核背景

P4.1 调研推荐 Stable Audio 3.0 为主选方案、MusicGen 为备选。但在正式进入 P4.2 接入设计前，需对以下关键问题做二次确认：

- Stable Audio 3.0 是否真有可公开申请的官方 API？还是仅发布论文/权重？
- Stable Audio 开源权重与 hosted API 的授权边界如何？
- MusicGen 权重 CC-BY-NC 4.0 是否允许高校竞赛 Demo 使用？
- Suno/Udio 等不推荐方案状态是否变化？

### 12.2 Stable Audio 复核结论

#### 12.2.1 官方 API 确认存在

✅ **Stability AI 官方 release notes（2026-05-20）明确**：

> "Today we are releasing an API for Stable Audio 3.0, our most advanced AI audio generation model that produces high-quality, coherent musical tracks up to six minutes long at 44.1kHz stereo."

- **API 入口**：platform.stability.ai（开发者控制台）
- **可用模型**：Stable Audio 3.0 **Large**（2.7B 参数）通过 API 提供
- **输出规格**：44.1kHz 立体声，最长 6 分钟
- **特性**：audio-to-audio（上传样本变换）、text-to-audio
- **训练数据**：100% AudioSparx 授权库，honoring opt-out requests

#### 12.2.2 模型家族与开源边界（修正 P4.1 描述）

P4.1 对 Stable Audio 3.0 模型家族的描述需修正细化：

| 模型 | 参数量 | 最长时长 | 开源权重 | 部署方式 |
|---|---|---|---|---|
| Stable Audio 3.0 Small SFX | 4.59 亿 | 2 分钟 | ✅ HuggingFace | 移动端/笔记本（音效） |
| Stable Audio 3.0 Small Music | 4.59 亿 | 2 分钟 | ✅ HuggingFace | 移动端/笔记本（音乐） |
| Stable Audio 3.0 Medium | 14 亿 | 6 分 20 秒 | ✅ HuggingFace | 云端 GPU |
| Stable Audio 3.0 Large | 27 亿 | 6 分 20 秒 | ❌ 不开源 | **仅 API / 企业授权** |

**关键修正**：
- P4.1 称「Small 模型 341M 参数」——实际为 4.59 亿（459M），已修正
- P4.1 未明确区分 Large 是 API-only、Small/Medium 是开源权重——已补充
- **心弦 P4.2 接入应走 API 路径（Large 模型）**，而非自部署开源权重（Small/Medium 自部署需 GPU 且质量低于 Large）

#### 12.2.3 授权条款复核

✅ **Stability AI Community License（适用 Stable Audio 3.0 全家族）**：

- **输出版权归用户所有**，可分发、可商用
- **年营收 < $1M 免费**（高校竞赛 Demo 完全适用）
- **年营收 ≥ $1M 需 Enterprise License**（含法律赔偿 indemnification）
- Stability AI 已与环球音乐、华纳音乐签约，训练数据全部授权

⚠️ **重要警告（来自 aipedia.wiki 复核）**：

> "Do not treat open weights as blanket commercial coverage. The Community License has a revenue threshold, Stable Audio 3.0 Large is API/enterprise, and organizations should confirm live license, indemnity, and deployment terms before shipping."

即：开源权重 ≠ 无条件商用，仍需检查 Community License 条款；Large 模型仅 API/企业授权，不能自部署。

#### 12.2.4 Stable Audio Open（旧版）授权差异

⚠️ **P4.1 未区分 Stable Audio 3.0 与 Stable Audio Open（旧 1.0）的授权差异**，需补充：

| 版本 | 授权 | 商用条件 |
|---|---|---|
| **Stable Audio 3.0**（2026-05） | Stability AI Community License | 年营收 <$1M 免费商用 |
| **Stable Audio Open 1.0**（旧版） | Research / Non-Commercial | Limited Commercial 需单独授权 |
| **Stable Audio 2.5**（hosted） | Pro/Studio 订阅 | Pro $11.99/mo 起，含商用 |

**结论**：心弦 P4.2 应使用 **Stable Audio 3.0 Large API**，而非旧版 Stable Audio Open 自部署。

#### 12.2.5 定价复核

✅ **Stability AI API 定价模型**：

- 1 credit = $0.01
- 新用户 25 免费 credits
- Stable Audio 3.0 Large API 按 credit 计费（具体 per-generation credit 数需在控制台确认）
- 无订阅要求，pay-per-use

**对比 hosted 订阅**：
- Pro $11.99/mo：含商用、更长时长、更高质量
- Studio $29.99/mo：最长 90 秒/次、优先处理

**心弦建议**：P4.2 走 API 路径（pay-per-use），用 25 免费 credits 做 PoC，验证后再决定是否充值。

#### 12.2.6 适合性确认

| 心弦需求 | Stable Audio 3.0 Large API 是否满足 |
|---|---|
| 纯音乐/无歌词 | ✅ 原生 instrumental，不生成人声 |
| 文本 prompt 输入 | ✅ text-to-audio |
| 中英文 prompt | ⚠️ 英文为主，中文需翻译（M5 generationPrompt 已为英文） |
| 时长控制（3-8 分钟） | ✅ 最长 6 分钟，可接受 |
| 可商用 | ✅ Community License（<$1M 免费） |
| 异步任务 | ✅ API 支持异步 |
| 移动端扩展 | ✅ Small 模型可移动端（P5 储能） |

### 12.3 MusicGen / AudioCraft 复核结论

#### 12.3.1 权重许可证确认

✅ **MusicGen 权重许可证仍为 CC-BY-NC 4.0（非商业）**，未变化：

- 代码：MIT License
- 模型权重：CC-BY-NC 4.0（Creative Commons Attribution-NonCommercial 4.0）
- **明确禁止商业用途**

**对心弦的影响**：
- 心弦已部署至正式域名 `xinxian-music.xyz`，定位为高校竞赛 Demo 但已公开可访问
- 是否算「商业用途」存在灰色地带：无直接收费 ≠ 非商业（品牌曝光、竞赛获奖等可能被视为商业利益）
- **保守判断：MusicGen 不适合作为心弦主方案，仅可作为纯研究/Demo 阶段的离线备选**

#### 12.3.2 Replicate API 成本与限制

✅ **Replicate 上 MusicGen 调用成本确认**：

- `meta/musicgen`：约 $0.067/run（Nvidia A100 80GB，48 秒平均）
- `pollinations/music-gen`：约 $0.074/run（Nvidia T4，6 分钟平均）
- 约 14-19 runs/$1

**输出限制**：
- 最长时长：通常 30 秒-2 分钟（受 VRAM 限制）
- 采样率：32kHz（低于 Stable Audio 3.0 的 44.1kHz）
- 质量明显低于 Stable Audio 3.0 / Suno v5.5（2024 年后无更新）

#### 12.3.3 适用场景定位

⚠️ **MusicGen 最终定位**：

- ✅ **适合**：纯研究/Demo 阶段的离线备选、melody conditioning 实验性功能验证
- ❌ **不适合**：心弦 P4.2 主方案（非商业许可 + 质量低 + 时长短）
- ⚠️ **仅作 P4.5 可选二级 fallback**：当 Stable Audio API 故障时，**短暂**切换到 Replicate MusicGen，但需在 README/About 显式声明「非商业用途」

### 12.4 不推荐方案复核

| 方案 | 复核结论 | 状态变化 |
|---|---|---|
| **Suno v5.5** | 仍无官方 API，仅第三方 wrapper（sunoapi.org/PiAPI/AIML API）；UMG/Sony 诉讼未结；AI 生成作品美国无版权保护 | ❌ 维持不推荐 |
| **Udio v4** | 仍无官方 API；Sony 诉讼未结；主要面向制作人手动编辑 | ❌ 维持不推荐 |
| **ElevenLabs Music** | $0.80/min 成本仍过高（8 分钟约 $6.4）；训练数据未公开 | ❌ 维持不推荐 |
| **MiniMax Music 2.5** | 单次输出 50-76 秒仍过短，需多次拼接；训练数据未公开 | ❌ 维持不推荐 |
| **Google Lyria 3** | 仍为 Vertex AI 邀请制；WebSocket 不适合 Pages Functions | ❌ 维持不推荐 |

**结论**：P4.1 的不推荐方案判断全部成立，无需调整。

### 12.5 最终接入建议

#### 12.5.1 主方案（P4.2 接入）

**🥇 Stable Audio 3.0 Large API（platform.stability.ai）**

- ✅ 官方 API 已确认可用（2026-05-20 发布）
- ✅ Community License 允许商用（年营收 <$1M 免费，高校 Demo 适用）
- ✅ 训练数据 100% 授权，无诉讼风险
- ✅ 纯音乐原生支持，不生成人声
- ✅ 最长 6 分钟，满足心弦 3-8 分钟需求（接近上限）
- ✅ 44.1kHz 立体声
- ✅ 异步任务 + audio-to-audio
- ✅ Small 模型可移动端推理（P5 储能）

#### 12.5.2 备选方案（P4.5 可选）

**🥈 MusicGen via Replicate API**

- ⚠️ 仅作 Stable Audio API 故障时的**短暂**二级 fallback
- ⚠️ 权重 CC-BY-NC 4.0 非商业，需在 README/About 显式声明「非商业用途」
- ⚠️ 质量低于 Stable Audio 3.0，时长通常 30 秒-2 分钟
- ⚠️ 2024 年后无更新，长期可能被弃用

#### 12.5.3 暂不接入方案

- ❌ Suno v5.5（无官方 API）
- ❌ Udio v4（无官方 API）
- ❌ ElevenLabs Music（成本过高）
- ❌ MiniMax Music 2.5（时长不足）
- ❌ Google Lyria 3（邀请制，架构不匹配）
- ❌ Stable Audio Open 1.0 旧版自部署（授权限制 + 质量低于 3.0）
- ❌ Stable Audio 3.0 Small/Medium 自部署（需 GPU + 质量低于 Large API）

### 12.6 仍需人工注册/控制台确认的事项

P4.2 正式接入前，以下事项需人工在 Stability AI 控制台或邮件确认：

| 事项 | 确认方式 | 优先级 |
|---|---|---|
| 1. Stability AI 账号注册 | platform.stability.ai 注册 | 高 |
| 2. 25 免费 credits 到账 | 注册后检查账户 | 高 |
| 3. Stable Audio 3.0 Large API 单次生成 credit 成本 | 控制台 pricing 页或 API 文档 | 高 |
| 4. API 速率限制（requests per minute） | 控制台或 API 文档 | 高 |
| 5. API 异步任务支持方式（同步/异步/webhook） | API 文档 | 高 |
| 6. API 输出音频格式（MP3/WAV/码率） | API 文档 | 中 |
| 7. Community License 全文审阅 | stability.ai/license | 中 |
| 8. 高校竞赛 Demo 是否需特殊声明 | Stability AI 商务邮箱 | 低 |
| 9. 中文 prompt 支持程度 | 实际调用测试（P4.2 PoC 阶段） | 中 |
| 10. 生成音频是否含水印 | API 文档或实际测试 | 中 |

### 12.7 P4.1-fix 交付清单

| 交付物 | 路径 | 状态 |
|---|---|---|
| 复核文档 | `docs/ai-music-generation-research.md` 第十二章 | ✅ 本节 |
| README 同步 | `README.md` P4 状态更新为「第一批调研 + 1.5 复核完成」 | ✅ |
| 版本号同步 | `lib/config/app_version.dart` → `P4-research-1-fix1` | ✅ |
| 验证 | `flutter analyze` 通过 | ✅ |
| 业务代码改动 | 无（本批只更新文档 + 版本号） | ✅ |
| API Key 接入 | 无（不接入真实 API Key） | ✅ |
| 付费接口调用 | 无（不调用付费生成接口） | ✅ |

### 12.8 下一步

- **P4.2**：Stable Audio 3.0 Large API 最小 PoC（人工注册账号 + 用 25 免费 credits 验证生成流程）
- **P4.3**：完整接入设计（Pages Function + R2 + fallback）
- **P4.4**：DSP 后处理
- **P4.5**：成本与安全控制（可选 MusicGen 二级 fallback）

**明确声明**：截至 P4.1-fix（2026-07-12），心弦**尚未接入任何真实 AI 音乐生成 API**，当前播放仍为本地预置音频。P4 真正 AI 音乐生成仍为必做项。

---

> **免责声明**：本调研文档仅作技术选型参考，不构成法律建议。各方案许可条款与定价可能随时变化，P4.2 实际接入前需重新核对各方案最新条款。心弦定位为辅助情绪调节与正念陪伴工具，**不提供医疗诊断或治疗**，音乐生成不写「治疗焦虑 / 治疗失眠 / 治愈」等医疗化措辞。
