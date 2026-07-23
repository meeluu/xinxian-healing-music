# P6-quota-guard-1 实施计划：生成次数与成本保护最小版 + 文档整理

## Summary

本批在 P4-song-result-experience-1（已上线验收）之后，完成两件事：
1. **浏览器本地额度保护**：防止 realCallsEnabled 开启后用户误点/多点/重复生成导致 MiniMax 成本失控。默认每天最多 1 次成功生成，仅约束「把困惑写成一首歌」里的「生成这首歌（实验）」+「重新生成」，不影响「快速舒缓一下」固定曲库。
2. **README 与文档体系整理**：让后来接手的人能快速看懂项目状态，新增 `docs/ROADMAP.md`，审计 docs/ 过时内容。

硬约束：`MUSIC_GENERATION_REAL_CALLS_ENABLED` 保持 `"false"`、`manualTest=true` 保护保留、不新增自动调用/轮询/重试、不引入新依赖、不做 R2/付费/用户系统/4090、不使用医疗化表达。

> **本批不部署上线**（用户规格「四、验证」仅列 analyze/test/build/verify，无 wrangler deploy）。

## Current State Analysis（经亲自核实，非代理推断）

### 已完成（A1/A2/A3 主体，前序会话已落地）
- ✅ `lib/pipeline/local/local_generation_quota_service.dart`：完整实现。`dailyLimit=1`，`key='xinxian.generation.quota'`，同步方法 `getTodayUsage()`/`canGenerateToday()`/`todayRemaining`/`recordSuccessfulGeneration()`/`resetIfNewDay()`，`DateTime Function() now` 时钟注入，JSON `{"date":"yyyy-MM-dd","count":N}` 持久化，损坏回退 `{今天,0}`。
- ✅ `lib/pipeline/services.dart`：L4 import + L49-54 `LocalGenerationQuotaService? generationQuotaService;`（nullable，permissive 降级）。
- ✅ `lib/main.dart`：L8 import + L200-214 第 9 步装配（独立 try/catch）+ L238-241 自检汇总。
- ✅ `lib/screens/comfort_lyrics_screen.dart`：
  - L9 import services.dart
  - L116-125 `int? _quotaRemaining` 字段（null=降级/0=用完/>0=可用）
  - L157-158 initState 调 `_refreshQuotaState()`
  - L173-193 `_refreshQuotaState()`（null→降级，否则 resetIfNewDay + 读 todayRemaining）
  - L755-798 `_buildGenerateSongButton` 已重写为 Column（额度提示 + `quotaExhausted` 禁用）
  - L800-854 `_buildQuotaHint()`（remaining>0 显示「今日还可生成 N 首」；==0 显示卡片「今日体验次数已用完」+ 副提示）
  - L864-865 `_onGenerateSongPressed` guard `if (_quotaRemaining == 0) return;`
  - L1216-1217 `_onRegenerateSongPressed` guard `if (_quotaRemaining == 0) return;`
  - L1047-1050 `_callGenerateMusicApi` 成功分支（playableUrl != null 的 setState 之后）调用 `recordSuccessfulGeneration()` + `_refreshQuotaState()`

### 未完成（本批要做的）
- ❌ **A3 收尾**：`_buildSongActionButtons`（L1414-1475）里「重新生成」OutlinedButton（L1454-1469）`onPressed` 仍为 `_onRegenerateSongPressed`，**未设 null 禁用 + 按钮区无额度提示**。方法内已有 guard，但 UI 态未同步。
- ❌ **A4 测试**：`test/local_generation_quota_service_test.dart` 不存在（需新建）；`test/comfort_lyrics_screen_test.dart` 文件头注释（L20-25）明确「结果区未纳入 widget 测试，需 API mock」，**无额度测试 group**。
- ❌ **B 版本号**：
  - `lib/config/app_version.dart`：milestone=`P4-AI-Music-v1.0`（L21）、buildLabel=`P4-song-result-experience-1`（L56），**未改 P6**；buildDate 已是 `2026-07-23`（L59）。
  - `functions/api/health.js`：`BUILD_LABEL='P4-song-result-experience-1'`（L51），**未改 P6**。
  - `scripts/verify-provider-adapter.mjs`：测试 63（L1434-1439）断言 `=== 'P4-song-result-experience-1'`，**未改 P6**。**且测试 45（L933）有 `assert.ok(d.buildLabel.indexOf('P4-') === 0, ...)`，buildLabel 改 P6 后此断言会失败，必须同步改。**
- ❌ **C1 README**（224KB，结构已较完整，定向更新而非重写）：
  - L83-87 「2.1 当前阶段」仍是 `P4-minimax-real-test-1` / 构建日期 2026-07-19，**严重过时**。
  - L97-111 「2.3 已具备能力」未提 P4 新方向（困惑写歌）/MiniMax/audioDataUrl，**过时**。
  - L2850-2861 「十、当前仍是 Mock」称「真正 AI 音乐生成尚未接入（P4 必做）」，**过时**（MiniMax 已接入）。
  - L2865-2873 「十一、后续路线图」P4 标「🔜 进行中（mock 闭环完成，真实接入待 P4.4）」，**过时**；P6 标「用户系统与跨设备」，**与本批 P6-quota-guard-1 编号冲突**，需重定义。
  - L2889+ 「十三、变更记录」13.5 P4 需补 P4 后续批次 + P6。
  - 需新增「6.18 P6-quota-guard-1」章节；目录（L13-43）同步。
- ❌ **C2 ROADMAP**：`docs/ROADMAP.md` 不存在（需新建）。docs/ 现有 5 个 md：`ai-music-generation-poc-design.md` / `ai-music-generation-research.md` / `ai-music-provider-adapter-design.md` / `comfort-song-product-flow.md` / `mureka-api-integration-plan.md`。
- ❌ **C3 docs 审计**：`mureka-api-integration-plan.md` 与项目记忆「不调用 Mureka API」冲突，需标「历史调研，未采用」。

## Proposed Changes

### Part A — 额度保护收尾

#### A3.1 `lib/screens/comfort_lyrics_screen.dart`：`_buildSongActionButtons` 加额度禁用 + 提示
**What**：修改 L1414-1475 的 `_buildSongActionButtons`：
1. 在 Column children 顶部（「重新播放」按钮之前）加额度提示：`if (_quotaRemaining != null && _quotaRemaining == 0) ...[ _buildQuotaHint(), const SizedBox(height: 10), ]`。仅在结果区且额度用完时提示（成功生成后额度即用完，此为最常见场景）。
2. 「重新生成」OutlinedButton（L1454-1469）：`onPressed` 改为 `(_quotaRemaining == 0) ? null : _onRegenerateSongPressed`，使额度用完时按钮变灰禁用。
3. 「重新播放」「编辑歌词」**不动**（不受额度影响）。

**Why**：计划文件要求「结果区重新生成按钮同样受 `_quotaRemaining == 0` 禁用 + 额度提示」。方法内 guard 已是双保险，UI 禁用是用户可感知的反馈。

**How**：用 Edit 替换 L1414-1475 整个方法体。保持现有样式（lavender/apricotDeep/primary）不变，仅加提示 + 改 onPressed。

#### A4.1 新建 `test/local_generation_quota_service_test.dart`（纯 service 单元测试）
**What**：参照 `test/cloud_feedback_consent_service_test.dart` 范本（`_FakePreferencesPort` 内存 Map + `SharedPreferences.setMockInitialValues({})` + `SharedPrefsAdapter` + 可注入时钟）。覆盖用户规格 6 项 + 持久化/损坏容错/key 隔离：
1. 初始可生成（canGenerateToday=true, todayRemaining=1, getTodayUsage=0）
2. 成功后次数 +1（recordSuccessfulGeneration → usage=1, remaining=0, canGenerate=false）
3. 达上限后不可生成
4. 失败不计数（service 无 failure 入口，验证「不调用 record 即不变」+ resetIfNewDay 同日 no-op 不减计数）
5. 跨天重置（注入 now=明天 → resetIfNewDay 后 usage=0, remaining=1；再 record → usage=1）
6. 重新播放不计数（service 无 replay 入口，验证「重新播放不触发 record」由调用方保证，service 层验证只有 record 自增）
7. 持久化 + 重启保留（create 两次读回同一 count）
8. 损坏 JSON 容错（setString 乱码 → create 回退 {今天,0}）
9. key 隔离（key='xinxian.generation.quota' 不与其他 consent key 冲突）

**Why**：用户规格「6. 可测试性」明确要求，且 service 是本批核心逻辑，必须可回归。

**How**：Write 新文件。用 `_FakePreferencesPort`（内存 Map）注入，时钟用闭包变量控制（`DateTime fixedTime` + `() => fixedTime`）模拟跨天。不依赖 Flutter binding（纯 dart 逻辑）。setUp 调 `SharedPreferences.setMockInitialValues({})` 防污染。

#### A4.2 `test/comfort_lyrics_screen_test.dart`：文件头注释补 P6 说明
**What**：在 L20-25 注释段后追加 P6-quota-guard-1 说明：「额度保护逻辑由 `local_generation_quota_service_test.dart` 在 service 层完整覆盖；额度 UI 集成（按钮禁用/提示）需 mock 全局 `generationQuotaService` + 触发结果区，与 P4 结果区测试同样需 API mock，本批留待后续。」

**Why**：如实说明测试边界，不假装覆盖。用户规格只要求 service 单元测试。

**How**：Edit 追加注释，不改现有测试用例。

### Part B — 版本号同步

#### B.1 `lib/config/app_version.dart`
- L21 `milestone`：`P4-AI-Music-v1.0` → `P6-Quota-v1.0`
- L56 `buildLabel`：`P4-song-result-experience-1` → `P6-quota-guard-1`
- L59 `buildDate`：保持 `2026-07-23`
- L24 `versionName`：保持 `v1.0.0`
- L62 `deployTarget`：保持 `Cloudflare Pages`
- L54 注释约定补一行：`/// - P{N}-quota-guard-{n}：P 阶段第 n 批本地额度保护与成本安全`

#### B.2 `functions/api/health.js`
- L51 `BUILD_LABEL`：`'P4-song-result-experience-1'` → `'P6-quota-guard-1'`
- L50 注释补一行：`// P6 本地额度保护：同步更新为 P6-quota-guard-1`

#### B.3 `scripts/verify-provider-adapter.mjs`
- L1434-1439 测试 63：断言 `'P4-song-result-experience-1'` → `'P6-quota-guard-1'`，注释同步
- **L933 测试 45**：`assert.ok(d.buildLabel.indexOf('P4-') === 0, 'buildLabel 应以 P4- 开头')` → 改为 `assert.ok(d.buildLabel.indexOf('P6-') === 0, 'buildLabel 应以 P6- 开头')`（否则 buildLabel 改 P6 后此断言失败）

### Part C — 文档整理

#### C1. README.md 定向更新（不重写，224KB 风险高）
**策略**：现有结构（一~十三章）已基本符合用户期望，定向更新过时点 + 新增 P6 章节 + 同步路线图/变更记录，不破坏历史记录。

1. **L83-87「2.1 当前阶段」**：更新为 `P6-Quota-v1.0 / P6-quota-guard-1`，构建日期 `2026-07-23`，上一阶段补 P4-song-result-experience-1 已上线。
2. **L97-111「2.3 已具备能力」**：追加 P4 新方向（困惑解惑→歌词→AI 歌曲）、MiniMax 真实调用打通（默认 REAL_CALLS=false）、audioDataUrl 临时播放闭环、生成歌曲结果页体验、P6 本地额度保护。
3. **新增「6.18 P6-quota-guard-1：本地额度保护 + 文档整理」章节**（接 6.17 之后，L2628 之前）：含目标 / 额度规则（每日 1 次、计数规则、UI 提示、防重复点击）/ 成本安全（realCallsEnabled 保持 false）/ 新增文件清单 / 明确不做 / 验证。**在此章节内给出清晰的「已完成 / 未完成」对照**（用户规格二.2 要求）。
4. **L2850-2861「十、当前仍是 Mock」**：修正「真正 AI 音乐生成尚未接入」→ MiniMax 已接入但默认 REAL_CALLS=false（受控实验）；R2 持久化/历史生成歌曲/分享链接/用户系统/付费仍为未完成。
5. **L2865-2873「十一、后续路线图」**：重定义 P6 = 额度保护与成本安全（P6-quota-guard-1 首批完成）+ 后续用户系统；P4 标「✅ 已完成（MiniMax 打通 + audioDataUrl 临时播放 + 结果页体验 + 额度保护）」；补 P5/P6/P7/长期（4090/自有模型/增长 Agent）分阶段，每阶段「不做什么」。
6. **L2889+「十三、变更记录」**：13.5 P4 补 song-result-experience-1；新增「13.6 P6-Quota-v1.0」记录 P6-quota-guard-1。
7. **L13-43 目录**：补 6.18 条目。

#### C2. 新建 `docs/ROADMAP.md`
**What**：分阶段路线图（用户规格二.4）。结构：
- 当前阶段：P6-quota-guard-1
- 短期目标：安全小范围内测（额度保护已就位，realCallsEnabled 保持 false）
- 中期目标：R2 持久化 / 历史生成歌曲 / 分享链接 / 用户系统 / 付费会员
- 长期目标：4090 后端迁移 / 自有音乐模型替换 MiniMax / 小红书社交 Agent
- 每阶段「不做什么」
- 明确「Cloudflare 是当前验证环境，4090 是后续迁移方向」
- 中文、无医疗化表达、不暴露密钥

#### C3. docs/ 审计标注（小范围，不删历史）
- `docs/mureka-api-integration-plan.md`：顶部加标注「⚠️ 历史调研文档，未采用。项目决策：不调用 Mureka API（见 project_memory）。当前状态见 README.md 与 docs/ROADMAP.md。」
- 其余 4 个 md（ai-music-generation-* / comfort-song-product-flow）：快速 grep 检查是否有「R2 本阶段必需」「Cloudflare 唯一后端」「完整付费已完成」「医疗化表达」等过时内容；有则加历史标注，无则不动。不删历史记录。

### 验证（Part D）
1. `flutter analyze`（无 error/warning）
2. `flutter test`（含新 service 单元测试，全绿）
3. `flutter build web --release`（构建成功）
4. `node scripts/verify-provider-adapter.mjs`（含 buildLabel=P6-quota-guard-1 断言，全绿）

## Assumptions & Decisions

1. **README 定向更新而非全量重写**：224KB 重写 diff 巨大、易出错，且现有结构合理。用户「允许小范围修正」「不要只追加流水账」→ 定向更新过时点 + 新增 P6 章节 + 同步路线图。已在 6.18 章节内给出「已完成/未完成」清晰对照满足规格二.2。
2. **screen 额度 UI 测试不强制**：用户规格「6. 可测试性」只列 service 层 6 项单元测试。screen 额度 UI 需 mock 全局 service + 触发结果区（需 API mock），与 P4 结果区测试同因。本批以 service 单元测试为主，screen 文件头注释说明边界。
3. **路线图 P6 重定义**：原 README 路线图 P6=「用户系统」，与本批 P6-quota-guard-1 编号冲突。重定义 P6=「额度保护与成本安全（首批）+ 后续用户系统」，用户系统顺延。在 ROADMAP 与 README 路线图统一。
4. **本批不部署上线**：用户规格「四、验证」无 wrangler deploy。额度保护是防御性功能，realCallsEnabled 仍 false，不急着上线。
5. **verify 脚本测试 45 必须同步改**：L933 `indexOf('P4-')===0` 会因 buildLabel 改 P6 失败，是易漏点，已在 B.3 明确。
6. **降级策略**：service 未装配（存储全不可用）时 `_quotaRemaining=null`，UI 跳过额度限制（permissive 降级）。因 realCallsEnabled=false + mock 模式下成本风险近零。已在 service 文档注释与 services.dart 注释说明。

## 汇报项映射（完成后回报）
- 修改的代码文件 / 修改的 md 文档 / 是否新增 ROADMAP.md / 每日额度规则 / 计数行为 / 按钮提示变化 / realCallsEnabled 是否 false / 版本号最终显示 / 新增测试 / 验证命令结果 / README 组织 / 路线图分阶段 —— 均对应上述 Part A/B/C/D。
