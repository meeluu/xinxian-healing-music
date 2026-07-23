# P6-quota-guard-1 收尾计划：验证 + 最终汇报

> 本计划基于前序会话（已丢失上下文）的执行成果。Phase 1 探索已亲自核实：
> **所有代码与文档修改均已落地完成**，仅剩 4 项验证命令与 11 项最终汇报。

## 一、当前状态分析（Phase 1 已核实）

### 已完成并核实的修改

| 类别 | 文件 | 状态 |
|---|---|---|
| 额度 service | `lib/pipeline/local/local_generation_quota_service.dart` | ✅ 完整（dailyLimit=1, key='xinxian.generation.quota', 时钟注入, 损坏容错, 唯一自增入口 recordSuccessfulGeneration） |
| 服务注册 | `lib/pipeline/services.dart` L49-54 | ✅ `generationQuotaService` nullable 全局变量 |
| 启动装配 | `lib/main.dart` L200-214 + L238-241 | ✅ 第 9 步独立 try/catch 装配 + 自检汇总 |
| UI 集成 | `lib/screens/comfort_lyrics_screen.dart` | ✅ 10 处全部在位（字段 L116-125 / initState L157-158 / _refreshQuotaState L173-193 / _buildGenerateSongButton L755-798 / _buildQuotaHint L800-854 / _onGenerateSongPressed guard L864-865 / 成功分支计数 L1047-1050 / _onRegenerateSongPressed guard L1216-1217 / _buildSongActionButtons L1409-1486） |
| service 测试 | `test/local_generation_quota_service_test.dart` | ✅ 9 个测试（基本规则 6 + 持久化容错 4 + key 隔离 1） |
| screen 测试 | `test/comfort_lyrics_screen_test.dart` L26-32 | ✅ 文件头补 P6 说明 |
| 版本号-前端 | `lib/config/app_version.dart` L21/L55/L57 | ✅ milestone=P6-Quota-v1.0, buildLabel=P6-quota-guard-1, buildDate=2026-07-23 |
| 版本号-后端 | `functions/api/health.js` L51-52 | ✅ BUILD_LABEL='P6-quota-guard-1' |
| 验证脚本 | `scripts/verify-provider-adapter.mjs` L933/L1434-1438 | ✅ 测试45 P6- 前缀 + 测试63 精确匹配 |
| 路线图 | `docs/ROADMAP.md` | ✅ 新建，分阶段 + 不做什么 + 速查表 + 风险 |
| README | `README.md` | ✅ 定向更新 7 处（目录 L34 / 当前阶段 L85-89 / 能力 L114-118 / 6.18 章节 L2634-2709 / Mock 修正 L2860 / 路线图 L2872-2885 / 变更记录 L2959/L3060-3064） |
| 历史文档 | `docs/mureka-api-integration-plan.md` L9-11 | ✅ 2026-07-23 标注 |
| 硬约束 | `wrangler.toml` L60 | ✅ MUSIC_GENERATION_REAL_CALLS_ENABLED = "false" 保持 |

### 验证进度（前序会话记录，需复核）

- ⏳ `flutter analyze` — 前序记录通过（No issues found, 42.7s），需复核
- ⏳ `node scripts/verify-provider-adapter.mjs` — 前序记录通过（64 passed），需复核
- ❌ `flutter test` — 未运行（含新 service 单元测试，必须全绿）
- ❌ `flutter build web --release` — 未运行

## 二、剩余工作（Part D 验证 + 最终汇报）

### Step 1：运行 4 项验证命令（按顺序，前序已通过的也复核）

在 `d:\xinxian_healing_music` 目录下：

1. **`flutter analyze`**
   - 期望：No issues found
   - timeout：180000ms
   - 失败处理：按提示修复后重跑

2. **`flutter test`**
   - 期望：全部通过（含新增 `test/local_generation_quota_service_test.dart` 9 个测试）
   - timeout：360000ms（首次编译较慢）
   - 失败处理：
     - 若新 service 测试失败 → 检查 _FakePreferencesPort / 时钟闭包 / 断言
     - 若现有测试受版本号/注释变更影响 → 修正测试断言
     - 修复后重跑直到全绿

3. **`node scripts/verify-provider-adapter.mjs`**
   - 期望：64 passed, 0 failed（含 buildLabel=P6-quota-guard-1 断言）
   - timeout：60000ms
   - 失败处理：检查测试45（P6- 前缀）/ 测试63（精确匹配）断言

4. **`flutter build web --release`**
   - 期望：构建成功，输出 `build/web`
   - timeout：600000ms（构建较慢）
   - 失败处理：按编译错误修复后重跑

> 并行策略：1 和 3 可并行（独立工具链）；2 必须在 1 通过后单独跑；4 在 1/2 通过后跑。
> 实际执行时先并行跑 1+3，再跑 2，最后跑 4。

### Step 2：最终汇报（11 项）

验证全部通过后，按用户规格返回最终汇报，覆盖：

1. 修改了哪些代码文件
2. 修改了哪些 md 文档
3. 是否新增 ROADMAP.md
4. 每日额度规则是什么
5. 哪些行为计数/不计数
6. 按钮和提示如何变化
7. realCallsEnabled 是否仍为 false
8. 版本号最终显示什么
9. 新增了哪些测试
10. 所有验证命令是否通过
11. README 现在如何组织 + 后续路线图怎么分阶段

## 三、假设与决策

- **不重新做已完成的工作**：Phase 1 已核实所有代码/文档修改在位，本计划只做验证 + 汇报，不重复编辑。
- **前序验证结果不直接采信**：因上下文丢失，flutter analyze 与 node verify 即使前序记录通过也重新复核，确保结果可信。
- **本批不部署上线**：与用户硬约束一致，仅本地验证，不执行 `wrangler pages deploy`。
- **若验证发现缺陷**：仅修复阻塞性问题（测试失败 / 构建失败），不新增功能、不改额度规则、不动文档结构。
- **PowerShell 环境**：用 `;` 分隔命令，不使用 `&&` / `cd /d`；用 Read/Grep 工具而非 cat/grep。

## 四、验证标准

全部满足才算本批完成：
- [ ] `flutter analyze` → No issues found
- [ ] `flutter test` → All tests passed（含 9 个新 service 测试）
- [ ] `node scripts/verify-provider-adapter.mjs` → 64 passed, 0 failed
- [ ] `flutter build web --release` → 构建成功
- [ ] 最终汇报 11 项全部覆盖
