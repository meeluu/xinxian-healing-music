# P4-dynamic-followup-depth-1：把困惑写成一首歌 — 动态 2-4 轮追问

## Context

"把困惑写成一首歌"流程当前固定追问 3 轮：后端 `follow_up_questions` mode 一次性返回 2-3 个问题（`normalizeFollowUpQuestions` 硬上限 3），前端 `fetchFollowUpQuestions` 再 `take(3)`，按 `questions.length` 逐个展示。问题：用户输入完整时 3 轮啰嗦；输入模糊（"很烦""很累"）时 3 轮又不够。

本批改为**动态 2-4 轮**，采用用户确认的**混合架构**：首轮批量生成 2 个核心问题 → 用户答完第 2 轮后，根据原始输入+已有回答调用一次后端判定是否追加 1-2 个 → 总轮数 2-4。最多 2 次后端 LLM 调用（不每轮强制调），第 2 轮后必须允许"先写成歌"提前生成。

**约束**：不改 `MUSIC_GENERATION_REAL_CALLS_ENABLED` / 不开真实 MiniMax / 不改 MiniMax 生成链路 / 不改快速舒缓本地音乐链路 / 不新增账号·数据库·D1 schema / 不医疗化表达 / 不把 R2·历史歌曲·分享·付费·用户系统·4090 写成已完成。

---

## 关键决策

| 决策点 | 选择 |
|---|---|
| 后端 LLM 调用次数 | 最多 2 次（initial + more），不每轮调 |
| 总轮数 | 2-4（initial 固定 2 + more 0-2） |
| 后端契约扩展 | `follow_up_questions` mode 加 `stage`('initial' 默认 / 'more') + `answers` 字段；stage 缺省 'initial' 向后兼容 |
| initial 返回结构 | `{ questions:[...2], suggestedQuestionCount:2\|3\|4, canGenerateAfter:2, reason }` |
| more 返回结构 | `{ needMore:bool, questions:[...0-2], reason }` |
| 进度文案 | 去掉固定总数分母（more 前总轮数未知），改为"第 N 个问题 · 可以只写几个字，也可以跳过" |
| "先写成歌"入口 | loadingFollowUpMore 阶段独立按钮 + Q3/Q4 阶段 outlined 按钮文案变为"先写成歌"；Q1/Q2 仍为"跳过追问，直接生成"（始终可用） |
| more 失败/超时降级 | needMore=false + 空 questions → 2 轮即可生成 |
| suggestedQuestionCount 与 more 不一致 | suggestedQuestionCount 仅 UI 参考，以 more 实际返回为准 |

---

## 一、后端改动（`functions/api/comfort-lyrics.js`）

1. **`validateInput`**（L208-L285）：新增 `stage`('initial' 缺省 / 'more'，非法→'initial') + `answers`(stage='more' 用，过滤非字符串→`slice(0,2)`→每项≤500 字)。
2. **`FOLLOW_UP_PROMPT`**（L172-L203）：输出结构改为 `{ questions:[...2], suggestedQuestionCount, canGenerateAfter:2, reason }`；硬性要求 questions **恰好 2 条**；suggestedQuestionCount 基于原文复杂度建议 2/3/4；canGenerateAfter 始终 2。其余规则（基于原文/不医疗化/低能量不用"这件事里"开头）不变。
3. **新增 `FOLLOW_UP_MORE_PROMPT`**：输入原始 storyText + 已有 2 回答，输出 `{ needMore:bool, questions:[...0-2], reason }`；needMore=true 时 questions 1-2 条、needMore=false 时必须 `[]`；禁止医疗化/审问/重复 initial 语义。
4. **`normalizeFollowUpQuestions`**（L532-L553）：签名加 `maxQuestions=4`，`slice(0,maxQuestions)`（从 3 放宽到 4）；其余不变。
5. **新增 `normalizeFollowUpMore(raw)`**：校验 needMore(bool) + questions(数组)；`slice(0,2)` + 医疗化过滤；**一致性约束**：needMore=true 但 questions 空 → 强制 needMore=false；needMore=false → 强制 questions=[]。返回 `{needMore, questions}` 或 null。
6. **`localFollowUpFallback`**（L467-L476）：加 `options.stage` 参数；stage='initial' 返回前 2 条（从 3 改 2）；stage='more' 返回 `{category, questions:[]}`。
7. **新增 `localFollowUpMoreFallback(storyText, answers)`**：恒定 `{needMore:false, questions:[], reason:'fallback'}`。
8. **新增 `callLlmForFollowUpMore(config, storyText, answers)`**：8s 超时，temperature 0.5，用 FOLLOW_UP_MORE_PROMPT，user content 拼装原始输入+回答。
9. **`follow_up_questions` mode 分支**（L924-L959）：按 `validation.stage` 分流。initial 调 `callLlmForFollowUpQuestions`→`normalizeFollowUpQuestions(raw,4)`→失败走 `localFollowUpFallback(stage:'initial')`，返回含 suggestedQuestionCount/canGenerateAfter。more 调 `callLlmForFollowUpMore`→`normalizeFollowUpMore`→失败走 `localFollowUpMoreFallback`，返回 `{ok, source, needMore, questions}`。
10. **ENABLE_LLM='false'/无 key 分支**（L869-L922）：initial 走 fallback 返 2 题 + canGenerateAfter:2；more 走 fallback 返 needMore:false。

**不改动**：`comfort_song` 分支、`callLlm`、`normalizeResult`、歌词生成链路。

---

## 二、前端 service（`lib/pipeline/llm/comfort_lyrics_service.dart`）

1. **新增 model 文件 `lib/models/follow_up_result.dart`**：
   - `FollowUpInitialResult{questions, suggestedQuestionCount, canGenerateAfter, source, reason?}` + fromJson
   - `FollowUpMoreResult{needMore, questions, source, reason?}` + fromJson
2. **`fetchFollowUpQuestions`**（L106-L149）：返回类型 `List<String>` → `FollowUpInitialResult`；请求体加 `'stage':'initial'`；解析 questions→`slice(0,2)`、suggestedQuestionCount(clamp 2-4)、canGenerateAfter(缺省 2)；失败走 `_localFollowUpFallback` 构造 fallback 结果。
3. **新增 `fetchFollowUpMore({storyText, answers})`**：请求体 `{mode:'follow_up_questions', stage:'more', answers}`，12s 超时；解析 needMore/questions(→slice 0,2)；失败返回 `FollowUpMoreResult(needMore:false, questions:[], source:'fallback')`，绝不抛异常。
4. **`_localFollowUpFallback`**（L155-L159）：改为 `take(2)`（常量本身保留 3 条不动）。

**不改动**：`generate()` 方法、comfort_song 链路。

---

## 三、前端 screen（`lib/screens/comfort_lyrics_screen.dart`）

1. **`_ConversationPhase`**（L126-L134）：加 `loadingFollowUpMore`。流转：input→loadingFollowUp→followUp(Q1,Q2)→loadingFollowUpMore→followUp(追加 Q3/Q4) 或 done→done。
2. **新增状态字段**：`_maxQuestions=4`、`_canGenerateAfter=2`、`_suggestedQuestionCount`、`_moreInFlight`。
3. **`_startFollowUp`**（L267-L312）：调 `fetchFollowUpQuestions` 拿 `FollowUpInitialResult`，设 `_dynamicQuestions=result.questions`、`_suggestedQuestionCount`；空列表兜底 2 个固定问题。
4. **`_recordAnswerAndAdvance`**（L314-L339）重构：入口加 `if(_phase!=followUp) return` 守卫；push 答案后，若 `_followUpIndex < length-1` → 递增聚焦下一题；否则若 `_followUpAnswers.length==2 && !_moreInFlight` → 触发 `_triggerFollowUpMore()`；否则 → done+_generate。
5. **新增 `_triggerFollowUpMore()`**：切 loadingFollowUpMore + `_moreInFlight=true`；调 `fetchFollowUpMore`；防迟到（`if(_phase!=loadingFollowUpMore) return`）；needMore=true 且 questions 非空 → append（`clamp(0, _maxQuestions-length)` 截断）+ 推进 followUp；否则 → done+_generate。
6. **`_skipAndGenerate`**（L344-L350）：扩展——若 `_moreInFlight` 置 false（让迟到响应被忽略）；复用于"跳过/先写成歌"两处。
7. **`_buildFollowUpCard`**（L520-L727）：
   - 进度文案（L577-L584）→ `'第 ${_followUpIndex+1} 个问题 · 可以只写几个字，也可以跳过'`（去掉总数分母）
   - outlined 按钮文案：`_followUpAnswers.length >= _canGenerateAfter` ? '先写成歌' : '跳过追问，直接生成'
   - filled 按钮：最后一轮 '生成歌词'，否则 '继续'
8. **新增 `_buildLoadingFollowUpMore()`**：spinner + 文案"正在想是不是还要再问一两个…" + "先写成歌" OutlinedButton（调 `_skipAndGenerate`）。
9. **`_reset`**：清空 `_suggestedQuestionCount`、`_moreInFlight`。

---

## 四、边界情况处理

| 情况 | 处理 |
|---|---|
| more 返回 needMore=true 但 questions 空 | normalizeFollowUpMore 强制 needMore=false |
| more 返回 questions>2 | slice(0,2) |
| 追加后总数会超 4 | 前端 `clamp(0, _maxQuestions-length)`，若 0 直接 done |
| 第 3 轮答完后 | 不再调 LLM；有 Q4→进 Q4，否则 done |
| 第 4 轮答完后 | 必然 done |
| loadingFollowUpMore 期间用户点"先写成歌" | `_moreInFlight=false`+phase=done+generate；迟到响应被 phase 检查忽略 |
| initial 返回 <2 题 | service 走 _localFollowUpFallback |
| initial 返回 >2 题 | service slice(0,2) |
| more 网络失败/超时 | service 返 needMore=false+空 → 2 轮生成 |
| 连续快速点"继续" | _recordAnswerAndAdvance 入口 phase 守卫 |
| 老前端调新后端（不发 stage） | stage 缺省 'initial'，正常工作 |

---

## 五、测试与 verify 更新

### `test/comfort_lyrics_service_test.dart`
- 既有 fix1 group：返回类型断言改 `FollowUpInitialResult`，fallback 问题数断言从 3 改 2。
- 新增 `fetchFollowUpMore 本地兜底` group：网络失败返 needMore=false+空、source='fallback'、不抛异常。
- 新增 `FollowUpInitialResult 结构` group：suggestedQuestionCount 在 2-4、canGenerateAfter 恒 2。

### `test/comfort_lyrics_screen_test.dart`
- L105-L124："第 1 / 3" → "第 1 个问题"。
- L146-L181：3 轮测试改为"答 2 轮→自动触发 more 兜底→done 生成"。
- 新增：进度文案不再显示固定总数；loadingFollowUpMore 阶段"先写成歌"按钮；Q2 后提前生成路径。

### `scripts/verify-comfort-lyrics.mjs`
- import 新增 `normalizeFollowUpMore`、`localFollowUpMoreFallback`。
- 既有：localFollowUpFallback 问题数 3→2；normalizeFollowUpQuestions 最多 3→4（保留 maxQuestions=3 旧测试 + 新增 maxQuestions=4 测试）。
- 新增 group：`validateInput stage/answers`、`normalizeFollowUpMore`（含一致性约束/医疗化过滤）、`localFollowUpMoreFallback`、`localFollowUpFallback stage 参数`。

### `scripts/verify-provider-adapter.mjs`
- buildLabel 断言 → `'P4-dynamic-followup-depth-1'`；前缀检查已通用化（上批已改 `P{n}-`）。

---

## 六、版本号同步

- `lib/config/app_version.dart`：`buildLabel='P4-dynamic-followup-depth-1'`，buildDate=2026-07-24，注释约定加 `P{N}-dynamic-followup-{n}` 一行。milestone/versionName/deployTarget 不变。
- `functions/api/health.js`：`BUILD_LABEL='P4-dynamic-followup-depth-1'` + 注释。
- `scripts/verify-provider-adapter.mjs`：buildLabel 断言同步。
- **不改动**：上批 P5-music-metadata-foundation-1 作为历史注释留在 audio_asset_catalog/music_profile/plan_screen/recommendation_reason 等文件中。

---

## 七、验证步骤

1. `node scripts/verify-comfort-lyrics.mjs` — 后端纯逻辑（现有+新增，预期全过）
2. `node scripts/verify-provider-adapter.mjs` — buildLabel + provider 断言
3. `flutter analyze` — no issues
4. `flutter test test/comfort_lyrics_service_test.dart test/comfort_lyrics_screen_test.dart` — 改动测试
5. `flutter test` — 全量回归
6. `flutter build web --release` — 编译成功

---

## 八、实现顺序

1. 后端纯逻辑层（prompt/normalize/fallback/validateInput stage）+ verify-comfort-lyrics.mjs 同步跑通
2. 后端 HTTP 层（callLlmForFollowUpMore + mode 分支）
3. 前端 model 类（follow_up_result.dart）
4. 前端 service（fetchFollowUpQuestions 改造 + fetchFollowUpMore + fallback take(2)）+ service 测试
5. 前端 screen（状态机/字段/_startFollowUp/_recordAnswerAndAdvance/_triggerFollowUpMore/按钮文案/loadingMore widget/_reset）+ screen 测试
6. 版本号同步
7. 全量验证 1-6
