# 心弦 · 困惑解惑 → 歌词 → AI 歌曲生成 主流程设计

> 版本：`v1.0.0 · P4-comfort-song-design-1-fix1 · 2026-07-18`
> 范围：本批只做**产品流程设计、数据模型草案、文案规范、与旧流程的关系界定**。**暂不写代码，不改 D1 schema，不调用真实 AI 音乐 API，不接入付费模块，不做社交 Agent。**
> 前置文档：
> - [ai-music-provider-adapter-design.md](ai-music-provider-adapter-design.md)（P4.4-1 provider adapter 设计）
> - [mureka-api-integration-plan.md](mureka-api-integration-plan.md)（Mureka API 接入调研，**后续候选方案**，暂不接入）

> **fix1 修订说明（2026-07-18）**：上一版把 Mureka 写成下一主线，现修正为——**当前主线继续使用 MiniMax**（账户已充值，成本更可控，真实调用失败需继续排查）；**Mureka 降级为后续候选 provider**（最低充值 200 元，测试成本偏高，暂不接入）。新产品主流程（困惑解惑 → 歌词 → AI 歌曲生成）保持不变。

---

## 一、背景与产品洞察

### 1.1 老师反馈

指导老师指出，当前心弦的"识别情绪 → 生成符合情绪的音乐"链路信息维度太单一：只把用户复杂处境压缩成情绪标签、valence、arousal、intensity 等少量维度。这种压缩丢失了用户处境的具体性，难以让用户感到"被理解"。

### 1.2 用户真实需求

用户描述最近的困惑、痛苦、愧疚、压力时，他需要的不仅仅是"一段匹配情绪的纯音乐"，而是：

1. **被理解**：有人/有系统听懂了他处境里具体卡在哪里
2. **被解释**：得到一个温和、不评判的视角，帮他重新看待这件事
3. **被安慰**：得到一段非空话、非套话的陪伴性回应
4. **被重新带回行动**：从情绪反刍中松开一点，回到"可以试着做点什么"的状态

### 1.3 古今中外的心理舒缓机制

这种"听见困惑 → 给出安慰 → 重新带回行动"的叙事结构并不新，它在古今中外有多种形态：

| 形态 | 机制 | 心弦能否借鉴 |
|---|---|---|
| 古代问天 / 占卜 | 把困惑说出来 → 得到一个"解释" → 心里安定 | 借鉴叙事结构，**不借鉴玄学包装** |
| 牧师 / 神父倾听 | 忏悔 → 被接纳 → 得到指引 | 借鉴倾听与接纳，**不引入宗教** |
| 算命师安慰 | 说出困境 → 被解读为"劫数将过" → 安心 | **明确拒绝**算准 / 命运注定话术 |
| 心理咨询师 | 倾诉 → 重新框架化 → 行动实验 | 借鉴温和重新框架，**不做诊断/治疗** |
| 民间老者劝慰 | 讲出难处 → 被共情 → 一句话点醒 | 借鉴"一句话点醒"的克制感 |

### 1.4 心弦的定位

心弦要用**现代、合规、非玄学**的方式完成"叙事性心理舒缓"：

- ✅ 可以做：情绪支持、音乐陪伴、心理舒缓、温和开导、自我理解
- ❌ 不做：医疗诊断、心理治疗、治疗焦虑、治疗失眠
- ❌ 不做：算命、神谕、命运注定、玄学预言
- ❌ 不做：把 LLM 输出包装成"命中注定 / 神的旨意 / 天意如此"

---

## 二、新主流程

### 2.1 流程总览

```
用户输入困惑/事件/情绪
  ↓
LLM 生成「温和解惑」（comfortInterpretation）
  ↓
LLM 生成歌词草稿（lyricDraft）
  ↓
用户确认 / 微调歌词
  ↓
AI 音乐 API 生成歌曲（Mureka 歌词生成歌曲）
  ↓
播放
  ↓
用户反馈
  ↓
（后续阶段）付费转化 / 社交 Agent
```

### 2.2 每一步的设计意图

#### 步骤 1：用户输入困惑/事件/情绪

- 用户输入最近发生的一件事 / 一个困惑 / 一种情绪
- 输入框文案不引导"描述情绪"，而是引导"说说最近发生了什么 / 卡在哪里"
- 保留旧流程的示例 chip，但示例从"我很难过"扩展为"和室友闹翻了，不知道该不该先低头"

#### 步骤 2：LLM 生成「温和解惑」（comfortInterpretation）

- 类似一个温和的陪伴者，用 2-4 段话回应：
  1. 复述用户处境的核心（让他感到被听见）
  2. 给出一个温和的重新框架（不评判、不说教）
  3. 指向一个可以试着做的小动作（不强制、不空话）
- **文案规范**：
  - 使用"也许 / 可以试着 / 听起来你 / 这首歌想陪你看见"
  - 禁用"你应该 / 你必须 / 你这样下去会 / 你这是病"
  - 禁用"我能算准 / 神谕 / 命运注定 / 天意如此"
- 这一步的产出 `comfortInterpretation` 会作为歌词生成的语义输入

#### 步骤 3：LLM 生成歌词草稿（lyricDraft）

- 基于 `comfortInterpretation` 生成中文歌词草稿
- 歌词结构：主歌 + 副歌 + 主歌 + 副歌 + 尾声（控制在 1-2 分钟演唱时长）
- 歌词风格：温暖、克制、不说教、不空话
- **歌词禁用词**：
  - 医疗化：治愈 / 治疗 / 疗愈疾病 / 治好你的焦虑
  - 玄学：命中注定 / 天意 / 神的安排 / 算准
  - 空话：一切都会好的 / 加油 / 你是最棒的
- **歌词鼓励方向**：
  - 具象化用户的处境（"你站在宿舍楼下没按门铃"）
  - 承认情绪的合理性（"想哭也没关系"）
  - 给一个微小的行动意象（"明天先把杯子洗干净"）

#### 步骤 4：用户确认 / 微调歌词

- 用户可以看到歌词草稿
- 用户可以：
  - 直接确认
  - 编辑歌词（限制字符数，过滤敏感词）
  - 重新生成（限制重试次数，避免刷接口）
- 这一步让用户有"这首歌是我自己参与做的"的参与感，是叙事性心理舒缓的关键

#### 步骤 5：AI 音乐 API 生成歌曲

- 调用 Mureka「歌词生成歌曲」接口
- 传入：歌词 + 风格提示（基于 targetState）+ 音色偏好
- 异步任务：创建 → 轮询 → 成功 / 失败 / 超时
- 成功：返回 audioUrl，前端播放
- 失败 / 超时：fallback 到预置音频（保留旧流程的 fallback 策略）

#### 步骤 6：播放

- 播放页展示：歌曲标题、歌词（可滚动高亮）、解惑文案摘要、audioUrl 播放器
- 播放完成后温和 CTA："这首歌陪你听完了吗？记录一下感受"

#### 步骤 7：用户反馈

- 沿用现有反馈页结构（评分 + 状态评分 + 文字反馈）
- 新增字段：
  - 歌词是否被编辑过（`lyricEdited: boolean`）
  - 解惑文案是否有帮助（`comfortHelpful: 1-5`）
- 云端采集仍遵循两层同意机制

#### 步骤 8：后续付费转化 / 社交 Agent（本批不做）

- 付费模块：高品质生成 / 多版本选择 / 下载 / 分享（**本批不做**，明确为后续阶段）
- 社交 Agent：把这首歌 + 解惑故事变成可分享的"心境卡片"或对话式 Agent（**本批不做**）

### 2.3 与旧流程的关系

| 维度 | 旧流程（P1-P4.4） | 新流程（P4 新方向） |
|---|---|---|
| 输入 | 心境描述（偏情绪） | 困惑/事件/情绪（偏处境） |
| 中间产物 | MoodProfile（情绪画像） | comfortInterpretation（温和解惑）+ lyricDraft（歌词） |
| 音乐形态 | 纯音乐 / 预置音频 | 带歌词的 AI 生成歌曲 |
| 用户参与度 | 被动接受匹配 | 主动确认/微调歌词 |
| 心理机制 | 情绪匹配（被动舒缓） | 叙事性心理舒缓（主动重构） |
| fallback | 预置音频 | 预置音频（保留） |
| 保留状态 | ✅ 保留为「快速模式」 | 作为 P4 之后主体验 |

**重要决策**：
- 旧流程**不删除**，保留为"快速模式"（用户只想快速听一段舒缓音乐时使用）
- 新流程作为 P4 之后的**主体验**（用户想被听见、被安慰时使用）
- 两个流程共用：sessionId 体系 / 反馈采集 / 历史记录 / fallback 预置音频
- 两个流程不共用：中间产物（MoodProfile vs comfortInterpretation + lyricDraft）

---

## 三、数据模型草案

### 3.1 新增数据结构（D1 草案，本批不迁移）

```sql
-- comfort_song_sessions 表（草案，本批不创建）
CREATE TABLE comfort_song_sessions (
  listeningSessionId TEXT PRIMARY KEY,        -- 与现有 sessionId 体系一致
  originalUserStory TEXT NOT NULL,            -- 用户输入的困惑/事件/情绪原文（仅本地，不上传云端）
  comfortInterpretation TEXT NOT NULL,        -- LLM 生成的温和解惑
  lyricDraft TEXT NOT NULL,                   -- LLM 生成的歌词草稿
  lyricEdited INTEGER DEFAULT 0,              -- 用户是否编辑过歌词（0/1）
  lyricFinal TEXT,                            -- 用户确认/微调后的最终歌词
  songPrompt TEXT,                            -- 传给 Mureka 的风格提示
  provider TEXT NOT NULL,                     -- mureka_music / minimax_music / mock
  generationStatus TEXT NOT NULL,             -- queued / generating / succeeded / failed / fallback
  audioUrl TEXT,                              -- Mureka 返回的音频 URL
  fallbackTrackId TEXT,                       -- fallback 预置音频 ID
  comfortHelpful INTEGER,                     -- 用户对解惑文案的评价 1-5
  consentComfortUpload INTEGER DEFAULT 0,     -- 是否同意上传解惑文案（独立同意）
  consentLyricUpload INTEGER DEFAULT 0,       -- 是否同意上传歌词（独立同意）
  clientVersion TEXT,
  createdAt INTEGER NOT NULL,
  schemaVersion INTEGER NOT NULL DEFAULT 2
);
```

### 3.2 字段说明

| 字段 | 类型 | 说明 | 云端上传策略 |
|---|---|---|---|
| `originalUserStory` | TEXT | 用户原文 | **默认不上传**（与 moodText 同策略），独立同意 |
| `comfortInterpretation` | TEXT | LLM 解惑文案 | 独立同意 `consentComfortUpload` |
| `lyricDraft` | TEXT | LLM 歌词草稿 | 独立同意 `consentLyricUpload` |
| `lyricEdited` | INTEGER | 是否编辑过 | 可上传（无敏感内容） |
| `lyricFinal` | TEXT | 最终歌词 | 独立同意 `consentLyricUpload` |
| `songPrompt` | TEXT | 风格提示 | 可上传（无敏感内容） |
| `provider` | TEXT | 生成 provider | 可上传 |
| `generationStatus` | TEXT | 生成状态 | 可上传 |
| `audioUrl` | TEXT | 音频 URL | 可上传（Mureka URL 有时效，建议只存 provider + jobId） |
| `fallbackTrackId` | TEXT | fallback 音频 ID | 可上传 |
| `comfortHelpful` | INTEGER | 解惑评价 | 可上传 |
| `consentComfortUpload` | INTEGER | 解惑上传同意 | 可上传 |
| `consentLyricUpload` | INTEGER | 歌词上传同意 | 可上传 |

### 3.3 三层同意机制（比旧流程多一层）

旧流程：`CloudFeedbackConsentService`（总开关）+ `CloudTextConsentService`（文字反馈独立开关）

新流程：`CloudFeedbackConsentService`（总开关）+ `CloudTextConsentService`（文字反馈）+ `CloudStoryConsentService`（解惑+歌词独立开关，默认 declined）

- 用户原文 `originalUserStory` **永远不上传云端**，只在本地存储
- 解惑文案和歌词需要用户**单独勾选**才上传
- 上传的解惑/歌词仅供项目组内部分析，不公开

### 3.4 本地持久化

- `ListeningSession` 扩展 `comfortSong` 子对象（可选字段）
- 旧流程的 session 不含 `comfortSong`，向前兼容
- 本地最多保留 100 条（沿用旧策略）
- `schemaVersion` 从 1 升级到 2，旧数据自动补 `comfortSong: null`

---

## 四、文案规范

### 4.1 禁用表达

| 类型 | 禁用示例 | 原因 |
|---|---|---|
| 医疗化 | 治愈 / 治疗 / 治好你的焦虑 / 治疗失眠 | 医疗承诺，合规风险 |
| 玄学 | 命中注定 / 天意 / 神的安排 / 算准 / 神谕 | 包装虚假能力 |
| 空话 | 一切都会好的 / 加油 / 你是最棒的 | 不具体，无陪伴感 |
| 说教 | 你应该 / 你必须 / 你这样下去会 | 评判性，反陪伴感 |
| 过度承诺 | 这首歌能让你好起来 / 听完就不难过了 | 医疗化暗示 |

### 4.2 鼓励表达

| 类型 | 鼓励示例 | 原因 |
|---|---|---|
| 温和推测 | 也许 / 可以试着 / 听起来你 / 可能是 | 不评判，留余地 |
| 具象共情 | 你站在宿舍楼下没按门铃 / 你盯着聊天框看了很久 | 让用户感到被看见 |
| 承认合理 | 想哭也没关系 / 这种感觉是正常的 | 不否定情绪 |
| 微小行动 | 明天先把杯子洗干净 / 今晚试着把手机放远一点 | 可执行，不空泛 |
| 陪伴感 | 这首歌想陪你看见 / 我在这听一会儿 | 不解决，但同在 |

### 4.3 歌词文案规范

- 主歌：具象化用户处境（不超过 2 个具体意象，避免堆砌）
- 副歌：承认情绪 + 给一个微小的行动意象
- 尾声：留白，不强行升华
- 字数控制：总字数 80-150 字（对应 1-2 分钟演唱）
- 不出现"心弦 / 本产品 / AI"等元指涉

---

## 五、与 AI 音乐 provider 的关系

### 5.1 当前主线 provider：MiniMax

**当前主线继续使用 MiniMax**（`minimax_music`）。理由：

- MiniMax 账户已充值，单首成本约 0.25 元，**成本更可控**
- P4.4-4 / P4.4-5 已完成骨架 + 真实调用分支代码（受 `MUSIC_GENERATION_REAL_CALLS_ENABLED` + `manualTest` 双重保护）
- 真实调用测试虽然上一轮失败，但**应继续排查并推进**，不放弃
- 代码已稳定，31 项验证脚本测试通过

**MiniMax 真实调用失败排查方向**（下一步任务）：
- 鉴权 header 格式（`Authorization: Bearer {key}`）
- 请求体字段名 / 结构是否符合 Music-2.0 官方文档
- `model` 值是否准确（`music-2.0`）
- 账户是否有 Music-2.0 模型权限
- 区域 / 网络是否可达 `api.minimax.chat`
- Cloudflare Pages Function 是否正确读取 `MINIMAX_API_KEY` Secret

### 5.2 后续候选 provider：Mureka

**Mureka 降级为后续候选 provider，当前不接入**。理由：

- Mureka **最低充值 200 元**，当前测试成本偏高
- 预算不允许同时维护两个真实调用供应商
- Mureka 调研文档保留（[mureka-api-integration-plan.md](mureka-api-integration-plan.md)），不删除
- 后期如果预算允许、且 MiniMax 确实无法修复，再切换或新增 Mureka

**Mureka 的潜在优势**（保留为后续候选的理由）：
- 原生支持「歌词生成歌曲」，更匹配新流程
- 支持中文歌词
- 返回 audioUrl（CDN URL），不像 MiniMax 返回 audioHex 需要转码
- 有任务查询接口，适合异步生成

### 5.3 新流程的 provider 路径

```
新流程（困惑解惑 → 歌词 → 歌曲）
  └─ 当前主线 provider: minimax_music
      ├─ 真实调用：POST /v1/music_generation（model: music-2.0）
      ├─ 返回：audioHex（需后端转码或前端解码）
      └─ fallback：预置音频（旧流程的 fallback 策略）
  └─ 后续候选 provider: mureka_music（暂不接入）
      ├─ 真实调用：歌词生成歌曲 /v1/songs/lyric-to-song（推测路径）
      ├─ 返回：audioUrl（CDN URL，可直接播放）
      └─ fallback：预置音频

旧流程（情绪 → 纯音乐）
  └─ provider: mock / minimax_music / stable_audio / replicate_musicgen
```

### 5.4 不真实调用任何 AI 音乐 API 的边界（本批）

- ❌ 本批不真实调用 MiniMax API（继续排查，但不在本批真实测试）
- ❌ 本批不真实调用 Mureka API
- ❌ 不写入 `MINIMAX_API_KEY` / `MUREKA_API_KEY`
- ❌ 不产生费用
- ✅ 只做产品设计 + 文档修正
- ✅ 下一步（P4 新方向第一批代码）先做「解惑文本 + 歌词生成」本地/LLM 流程，不依赖真实 AI 音乐生成
- ✅ 下一步（P4 MiniMax 修复）排查线上为什么仍返回 `provider=mock`

---

## 六、后续阶段边界（明确不做）

| 后续阶段 | 是否本批做 | 说明 |
|---|---|---|
| 困惑解惑 → 歌词 → AI 歌曲 主流程代码 | ❌ 本批不做 | 本批只设计，下一批开始写代码 |
| MiniMax 真实调用失败排查 | ❌ 本批不做 | 下一批任务，继续排查线上 `provider=mock` 问题 |
| mureka_music provider 骨架 | ❌ 后续候选 | Mureka 最低充值 200 元，暂不接入；MiniMax 修复无望时再考虑 |
| mureka_music 真实调用测试 | ❌ 后续候选 | 同上 |
| 付费模块（高品质 / 多版本 / 下载） | ❌ 后续阶段 | 明确不是当前阶段 |
| 社交 Agent（心境卡片 / 对话 Agent） | ❌ 后续阶段 | 明确不是当前阶段 |
| 小红书 / 抖音 分享 Agent | ❌ 后续阶段 | 明确不是当前阶段 |
| 心理量表 / 生理数据采集 | ❌ 后续阶段 | 科研方向，不进主流程 |

---

## 七、风险与待确认

### 7.1 合规风险

| 风险 | 应对 |
|---|---|
| LLM 解惑文案误判为医疗建议 | Prompt 严格限制 + 关键词过滤 + 免责声明 |
| 用户输入含自伤/自杀线索 | 关键词检测 + 温和引导专业求助热线（不诊断） |
| 歌词含敏感内容 | LLM 输出过滤 + 用户编辑再过滤 |
| 玄学包装诱惑 | 文案规范明令禁止，Prompt 显式排除 |

### 7.2 待确认事项

1. Mureka「歌词生成歌曲」是否支持纯中文歌词（待真实调用测试）
2. Mureka 生成一首歌的实际耗时（影响前端轮询策略）
3. Mureka 单首成本（影响每日限额设计）
4. 解惑文案 + 歌词的 LLM 调用是合并一次还是分两次（影响成本和延迟）
5. 用户编辑歌词的字符数上限（影响 Mureka 输入限制）
6. 解惑文案是否需要"重新生成"按钮（影响交互复杂度）

---

## 八、本批交付清单

| 交付物 | 状态 |
|---|---|
| `docs/comfort-song-product-flow.md`（本文档，fix1 修订） | ✅ 本批交付 |
| `docs/mureka-api-integration-plan.md`（Mureka 调研，标注为后续候选） | ✅ 本批修订 |
| README 修正主线表述（Mureka → MiniMax） | ✅ 本批交付 |
| README 记录 MiniMax 真实调用失败仍需排查 | ✅ 本批交付 |
| 版本号 → `P4-comfort-song-design-1-fix1` | ✅ 本批交付 |
| MiniMax 真实调用失败排查 | ❌ 下一批任务 |
| 困惑解惑 + 歌词生成 本地/LLM 流程代码 | ❌ 下一批任务 |
| 新流程前端 UI | ❌ 下一批之后 |
| D1 schema 迁移 | ❌ 下一批之后 |
| mureka_music provider 骨架代码 | ❌ 后续候选（暂不接入） |
| Mureka 真实调用测试 | ❌ 后续候选（暂不接入） |

---

## 九、版本与约束

- 版本：`v1.0.0 · P4-comfort-song-design-1-fix1 · 2026-07-18`
- 本批只做文档修正与版本号同步
- 不写代码 / 不改 D1 / 不调用真实 API / 不接入付费 / 不做社交 Agent
- 不使用医疗化表达
- 不使用玄学表达
- README 和版本号必须同步
