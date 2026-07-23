# P4-conversation-song-flow-1-fix1 实施计划

## Context（背景与目标）

P4-conversation-song-flow-1 已上线，但发现三个体验问题需修复：

1. **追问是固定模板**：`_followUpQuestions`（comfort_lyrics_screen.dart L191-L207）是 3 个硬编码问题，对所有用户套同一套。例如用户输入"提不起劲、疲惫、很空"（一种状态），系统却问"这件事里，最让你放不下的是哪一部分？"（假设是某件具体事）——不匹配。
2. **歌词贴合度不够**：后端 SYSTEM_PROMPT L106 反而要求"用夜色/桌面/消息/路灯等具象意象"，导致 LLM 编造用户没说过的窗台/手机/枕头边，而非承接用户真实困境。
3. **加载文案不分阶段**：`_buildLoadingHint`（L515-L540）只有一句"正在陪你把这件事重新看一遍…"，在生成追问、生成歌词、生成 AI 歌曲阶段都一样。

**目标**：追问改为 LLM 根据用户输入动态生成（失败有本地 6 分类兜底）；歌词 prompt 强化承接用户输入；加载文案分 4 阶段；不部署、不真实调用 MiniMax。

**快速舒缓流程已确认纯本地化**（首页→AnalysisScreen→PlanScreen→PlayerScreen 播放本地 assets，不调用 /api/generate-music，不扣额度，MusicGenerationScreen 已删除无残留），本批无需改动，仅做核查记录。

---

## 设计决策

### 决策 1：后端 mode 扩展（不新建接口）
在 `/api/comfort-lyrics` 增加 `mode` 参数：
- `mode="follow_up_questions"`：只生成 2-3 个追问，返回 `{ ok, source, questions: string[] }`
- `mode="comfort_song"` 或缺省：生成 comfortInterpretation + lyricDraft + songPrompt（当前逻辑，向后兼容）

### 决策 2：动态问题全部开放式，移除快速选项 chips
当前 Q2/Q3 有预设快速选项（安慰/释怀/力量 等）。改为 LLM 动态生成后，所有问题都是开放式自由输入。理由：① 更"不像心理测评"；② 用户示例追问都是开放式的；③ 实现简单可靠。**同时移除前端 `_desiredFeeling`/`_comfortDirection` 字段**，所有回答统一计入 `_followUpAnswers` 传给后端（后端 `generate()` 保留这些命名参数默认空串，保持兼容）。

### 决策 3：本地兜底分类镜像到前后端两端
后端 `classifyConcern` + `localFollowUpFallback`（用于 onRequestPost 降级）+ 前端 `_classifyConcern` + `_localFollowUpFallback`（用于 service 网络失败降级）。两端关键词与问题文案保持一致。`lowEnergy` 分类优先级最高，避免在用户没力气时还问"这件事里"。

---

## 实施步骤

### 步骤 1：后端 `functions/api/comfort-lyrics.js`

**1a. 修改 SYSTEM_PROMPT（L106 泛泛意象问题）**
- L106 当前：`'  · 【主歌】：具体画面感，不要抽象。用夜色 / 桌面 / 消息 / 路灯 / 风 / 没说出口的话等具象意象'`
- 改为：`'  · 【主歌】：承接用户在 storyText / 追问回答中提到的具体困境（人物/场景/物件/关系），意象化处理。不要编造用户没说过的具体场景（窗台/手机/枕头边），意象必须服务于用户困境，让用户第一段就感觉「这是在写我」'`
- L144 当前：`'   · 把用户提到的具体场景/物件/关系转化为歌词意象（如「没发出去的消息」「没关的屏幕」）'`
- 改为：`'   · 把用户在 storyText / 追问回答中提到的具体场景/物件/关系意象化，但不要引入用户未提及的具体物件'`
- L153 后追加：`'6. lyricDraft 必须显式承接 initialConcern 核心词或同义表达，不能脱离用户语境写泛化歌词'`、`'7. 副歌必须有一句容易记住的陪伴话（hook），可重复 1-2 句，但不要过度鸡汤'`

**1b. 新增 `FOLLOW_UP_PROMPT` 常量**（L163 后）
独立 prompt，要求 LLM 基于用户原文生成 2-3 个简短追问，输出 `{ "questions": ["...","...","..."] }`。硬性规则：问题基于用户具体内容、≤25 字、低压力、不医疗化、不用"为什么"、低能量类不用"这件事里"开头、允许跳过。

**1c. `validateInput` 增加 mode 校验**（L234 return 前）
```js
var mode = body.mode;
var validModes = ['follow_up_questions', 'comfort_song'];
if (typeof mode !== 'string' || validModes.indexOf(mode) === -1) {
  mode = 'comfort_song';
}
// return 对象加 mode: mode
```

**1d. 新增 `classifyConcern(storyText)`**（detectScene 之后，约 L329）
6 分类关键词匹配，lowEnergy 优先级最高。关键词列表见决策 3。

**1e. 新增 `localFollowUpFallback(storyText)`**
返回 `{ category, questions }`，6 分类 × 3 问题。

**1f. 新增 `FOLLOW_UP_FALLBACK_QUESTIONS` 常量**
6 分类的固定问题（lowEnergy/eventConflict/anxietyStress/guiltRegret/loneliness/unknown）。

**1g. 新增 `normalizeFollowUpQuestions(raw)`**
校验 questions 字段：字符串数组、长度 2-3、每条 ≤30 字、过滤医疗化词汇。失败返回 null。

**1h. 新增 `callLlmForFollowUpQuestions(config, userText)`**（callLlm 之后）
复用 fetch + AbortController，用 FOLLOW_UP_PROMPT，超时 8s，temperature 0.7，max_tokens 400。

**1i. `onRequestPost` 增加 mode 分支**（L667 API Key 检查通过后）
```js
if (validation.mode === 'follow_up_questions') {
  try {
    const raw = await callLlmForFollowUpQuestions(config, validation.storyText);
    const questions = normalizeFollowUpQuestions(raw);
    if (!questions) { /* 走 localFollowUpFallback */ }
    return jsonResponse({ ok: true, source: 'llm', questions: questions }, 200, origin);
  } catch (err) { /* 走 localFollowUpFallback */ }
}
// 否则走现有 comfort_song 分支（不变）
```
ENABLE_LLM=false 或 apiKey 缺失时，追问模式也走 localFollowUpFallback。

### 步骤 2：前端 `lib/pipeline/llm/comfort_lyrics_service.dart`

**2a. 新增 `fetchFollowUpQuestions({storyText, sessionId, language})`**
POST 到 /api/comfort-lyrics，body 含 `mode: 'follow_up_questions'`。失败（网络/非200/解析失败/questions<2）调 `_localFollowUpFallback`，绝不抛异常。

**2b. 新增 `_localFollowUpFallback(storyText)` + `_classifyConcern(storyText)` + `_followUpFallbackQuestions` 常量**
镜像后端 6 分类关键词与问题文案，保证语义一致。

### 步骤 3：前端 `lib/screens/comfort_lyrics_screen.dart`

**3a. 状态字段调整**
- `_ConversationPhase` 增加 `loadingFollowUp`（input→loadingFollowUp→followUp→done）
- 新增 `bool _loadingFollowUp`、`List<String> _dynamicQuestions`
- 移除 `_desiredFeeling`、`_comfortDirection`、静态 `_followUpQuestions` 常量、`_FollowUpQuestion` 类

**3b. `_startFollowUp` 改为异步**
- 先切 `loadingFollowUp` 阶段 + `_loadingFollowUp=true`
- 调 `_service.fetchFollowUpQuestions(storyText: story)` 拿动态问题
- 防御性兜底：空列表用 unknown 3 问题
- 切 `followUp` 阶段 + 聚焦输入框

**3c. `_recordAnswerAndAdvance` 简化**
所有回答统一 push 到 `_followUpAnswers`（去掉 index 0/1/2 → 不同字段的映射）。最后一轮进 done 调 `_generate`。

**3d. `_generate` 调整**
只传 `followUpAnswers`（不再传 desiredFeeling/comfortDirection）。

**3e. `_buildFollowUpCard` 改造**（L550-L762）
- `final q = _followUpQuestions[_followUpIndex]` → `final prompt = _dynamicQuestions[_followUpIndex]`
- 移除 hint（用通用"写几个字就好，也可以不写"）
- 移除快速选项 chips（q.options）
- 进度文案 `第 N / ${_dynamicQuestions.length} 个问题`

**3f. `_buildLoadingHint(String message)` 分阶段化**
接受文案参数。调用点：
- `loadingFollowUp` 阶段：`'正在根据你的文字整理几个更贴近的问题...'`
- `done` 阶段 `_loading`：`'正在整理你的文字，写成一首更贴近你的歌...'`

**3g. AI 歌曲按钮文案**（L1179）
`_generatingMusic ? '正在生成这首歌…'` → `'正在生成这首歌，请保持页面打开…'`

**3h. `_reset` / `_skipAndGenerate` 同步**
`_reset` 清理 `_dynamicQuestions=[]`、`_loadingFollowUp=false`。`_skipAndGenerate` 保留（仍可从 followUp 阶段跳过）。

### 步骤 4：`lib/screens/analysis_screen.dart`
L237 加载文案 `'AI 正在理解你的状态，再等一下…'` → `'正在为你选择一段适合此刻的纯音乐...'`

### 步骤 5：版本号同步
- `lib/config/app_version.dart`：`buildLabel` → `'P4-conversation-song-flow-1-fix1'`（milestone 保持 P4-AI-Music-v1.0，buildDate 保持 2026-07-23）
- `functions/api/health.js`：`BUILD_LABEL` → `'P4-conversation-song-flow-1-fix1'`
- `scripts/verify-provider-adapter.mjs`：buildLabel 断言改为 `'P4-conversation-song-flow-1-fix1'`

### 步骤 6：测试更新

**6a. `test/comfort_lyrics_screen_test.dart`**
- 现有"开始理解→followUp"用例：`tap` 后补 `pumpAndSettle` 等异步兜底完成，断言改为兜底问题文案
- 现有"3 轮回答"用例：每轮 `enterText` 自由文本 + 点"继续"/"生成歌词"（不再点 chip）
- `generateLyrics` 辅助函数：`tap('开始理解')` 后补 `pumpAndSettle` 等兜底，再点"跳过追问，直接生成"
- 新增：输入"提不起劲"命中 lowEnergy 兜底问题 `'今天最没力气的是什么时刻？'`
- 新增：loadingFollowUp 阶段断言 `'正在根据你的文字整理几个更贴近的问题...'`

**6b. `test/comfort_lyrics_service_test.dart`**
新增 `fetchFollowUpQuestions` group：网络失败返回非空 List、lowEnergy 命中、eventConflict 命中、不含医疗化词汇。

**6c. `scripts/verify-comfort-lyrics.mjs`**
新增 group：mode 缺省/透传/非法回退、classifyConcern 6 分类、localFollowUpFallback 结构与文案、normalizeFollowUpQuestions 校验、兜底不含"这件事里"措辞（lowEnergy 关键检查）。

### 步骤 7：README / ROADMAP 同步
- README 6.19 章节追加 fix1 子节：LLM 动态追问 + 本地 6 分类兜底 + 歌词贴合度增强 + 加载文案分阶段 + 快速舒缓纯本地化核查确认
- 写清楚："给现在的你"和歌词由 LLM 生成、音频由 MiniMax 生成、快速舒缓只用本地 assets 音乐
- 变更记录表追加一行
- 不写成医疗能力、不把 R2/付费/4090 写成已完成

---

## 关键约束（必须遵守）
- `MUSIC_GENERATION_REAL_CALLS_ENABLED` 保持 `"false"`（本批不动 wrangler.toml / provider adapter / MiniMax 链路）
- `manualTest=true` 三重门保护保留
- P6 本地额度保护保留（不动 LocalGenerationQuotaService）
- 不新增第三方依赖
- 不使用医疗化表达（治疗/治愈/诊断/疗法）
- 快速舒缓流程不动（已确认纯本地）

---

## 验证步骤

按依赖顺序执行：
1. `node scripts/verify-comfort-lyrics.mjs` — 验证后端 mode/classify/fallback/normalize
2. `node scripts/verify-provider-adapter.mjs` — 验证 buildLabel=P4-conversation-song-flow-1-fix1
3. `flutter analyze` — 无 issues
4. `flutter test` — 全部通过（含新增多轮动态追问测试）
5. `flutter build web --release` — 构建成功

**不部署、不真实调用 MiniMax。**

---

## 完成后汇报项
- 输入分类规则（6 类关键词）
- lowEnergy 示例会问什么
- 歌词 prompt 如何保证贴合用户输入
- 快速舒缓是否确认纯本地音乐
- 是否还有纯音乐 AI 生成残留
- 加载页文案如何分阶段
- realCallsEnabled 是否仍为 false
- 版本号最终显示什么
- 验证命令是否通过
