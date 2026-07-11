-- 心弦 · 反馈数据分析常用 SQL 查询（M8 建立，P3-Web-v1.0 第一批扩展）
--
-- 用法：
--   1. 单条查询：复制 SQL 内容执行
--      npx wrangler d1 execute xinxian-feedback --remote --command "SELECT ..."
--   2. 整文件执行（会依次执行所有语句，适合本地预览）：
--      npx wrangler d1 execute xinxian-feedback --remote --file=./scripts/feedback-queries.sql
--   3. 图形化界面：
--      Cloudflare Dashboard → Storage & Databases → D1 SQL Database
--      → xinxian-feedback → Console / Query
--   4. PowerShell 辅助脚本（P3 新增）：
--      ./scripts/query-feedback.ps1              # 基础统计
--      ./scripts/query-feedback.ps1 -Recent      # 最近反馈
--      ./scripts/query-feedback.ps1 -ByTargetState
--      ./scripts/query-feedback.ps1 -LowRating
--      ./scripts/query-feedback.ps1 -Notes
--
-- 数据库：xinxian-feedback（D1 / SQLite）
-- 表：feedback（25 字段，主键 listeningSessionId，M7 建立）
-- createdAt 格式：ISO8601 字符串，如 2026-06-28T10:00:00.000Z
--   提取日期用 substr(createdAt, 1, 10)
--
-- 字段语义（P3-Web-v1.0 第一批确认）：
--   relaxationScore  1-5（从 FeedbackRecord.rating 映射，5 = 最放松）
--   calmnessScore    0-100（从 tensionAfter×100 派生，100 = 状态最好；P2-Web-v1.0 fix2 起语义统一为"值越大状态越好"）
--   targetState      sleep / regulate / soothe / focus / energize（五类）
--   audioAssetId     脱敏文件名（如 sleep_01.mp3），不含路径前缀
--   freeTextFeedback 用户文字反馈，仅在用户单独勾选同意时上传，可为 NULL
--
-- ⚠️ improvement 指标限制：
--   D1 schema 未存储 tensionBefore / tensionAfter 原始值，只有派生的 calmnessScore。
--   因此当前不能直接计算 improvement = after - before。
--   只能用 calmnessScore（体验后状态）作为近似指标，或后续 P3 扩展补齐派生字段。
--
-- 隐私要点：
-- - moodText（心境原文）不存在于 D1，M7 设计就不上传
-- - freeTextFeedback 仅在用户单独勾选同意时上传，可为 NULL
-- - 本文件中标注 [隐私敏感] 的查询返回文字原文，仅供项目组内部分析
-- - 文字反馈原文不得直接放入公开报告 / PPT / 答辩材料，只使用聚合统计或脱敏摘要
-- - 查询结果含 sessionId / userAgent 等，仅用于分析，不公开发布
-- ════════════════════════════════════════════════════════════════
-- 查询 1：总反馈数
-- 用途：项目验收、答辩首页数据
-- ════════════════════════════════════════════════════════════════
SELECT COUNT(*) AS total_feedback
FROM feedback;
-- ════════════════════════════════════════════════════════════════
-- 查询 2：targetState 分布
-- 用途：了解 5 类目标状态（sleep/regulate/soothe/focus/energize）的使用分布
-- ════════════════════════════════════════════════════════════════
SELECT COALESCE(targetState, '(null)') AS target_state,
  COUNT(*) AS count,
  ROUND(
    COUNT(*) * 100.0 / (
      SELECT COUNT(*)
      FROM feedback
    ),
    1
  ) AS percentage
FROM feedback
GROUP BY targetState
ORDER BY count DESC;
-- ════════════════════════════════════════════════════════════════
-- 查询 3：audioAssetId 平均评分
-- 用途：评估不同音频素材的用户反馈差异，为后续音频优化提供依据
-- 字段说明：
--   relaxationScore  1-5（从 rating 映射，5 = 最放松）
--   calmnessScore    0-100（从 tensionAfter*100 映射，100 = 状态最好）
-- ════════════════════════════════════════════════════════════════
SELECT COALESCE(audioAssetId, '(null)') AS audio_asset_id,
  COUNT(*) AS count,
  ROUND(AVG(relaxationScore), 2) AS avg_relaxation_score,
  ROUND(AVG(calmnessScore), 2) AS avg_calmness_score,
  MIN(relaxationScore) AS min_relaxation,
  MAX(relaxationScore) AS max_relaxation
FROM feedback
WHERE relaxationScore IS NOT NULL
GROUP BY audioAssetId
ORDER BY count DESC;
-- ════════════════════════════════════════════════════════════════
-- 查询 4：最近 20 条反馈
-- 用途：快速查看最新反馈趋势，排查异常
-- 隐私说明：不返回 freeTextFeedback 原文，仅显示是否有文字反馈
-- ════════════════════════════════════════════════════════════════
SELECT listeningSessionId,
  substr(createdAt, 1, 19) AS created_at,
  targetState,
  experimentVariant,
  analyzerMode,
  audioAssetId,
  relaxationScore,
  calmnessScore,
  CASE
    WHEN freeTextFeedback IS NOT NULL
    AND freeTextFeedback != '' THEN '(有)'
    ELSE '(无)'
  END AS has_text,
  clientVersion
FROM feedback
ORDER BY createdAt DESC
LIMIT 20;
-- ════════════════════════════════════════════════════════════════
-- 查询 5：每日反馈数量
-- 用途：查看反馈增长趋势，识别活跃时段
-- ════════════════════════════════════════════════════════════════
SELECT substr(createdAt, 1, 10) AS date,
  COUNT(*) AS count
FROM feedback
GROUP BY substr(createdAt, 1, 10)
ORDER BY date DESC;
-- ════════════════════════════════════════════════════════════════
-- 查询 6：freeTextFeedback 非空数量
-- 用途：衡量用户深度参与度（愿意写文字反馈的比例）
-- ════════════════════════════════════════════════════════════════
SELECT COUNT(*) AS total,
  SUM(
    CASE
      WHEN freeTextFeedback IS NOT NULL
      AND freeTextFeedback != '' THEN 1
      ELSE 0
    END
  ) AS has_text,
  ROUND(
    SUM(
      CASE
        WHEN freeTextFeedback IS NOT NULL
        AND freeTextFeedback != '' THEN 1
        ELSE 0
      END
    ) * 100.0 / COUNT(*),
    1
  ) AS text_percentage
FROM feedback;
-- ════════════════════════════════════════════════════════════════
-- 查询 7：实验分组统计 experimentVariant / analyzerMode
-- 用途：为 M8 消融实验（custom / generic / control 三组对比）准备基线数据
-- 说明：当前阶段所有记录均为 custom + mock/llm，三组对比需待实验分组启用后
-- ════════════════════════════════════════════════════════════════
SELECT COALESCE(experimentVariant, '(null)') AS variant,
  COALESCE(analyzerMode, '(null)') AS analyzer_mode,
  COUNT(*) AS count,
  ROUND(AVG(relaxationScore), 2) AS avg_relaxation,
  ROUND(AVG(calmnessScore), 2) AS avg_calmness
FROM feedback
GROUP BY experimentVariant,
  analyzerMode
ORDER BY variant,
  analyzer_mode;
-- ════════════════════════════════════════════════════════════════
-- 查询 8 [隐私敏感]：文字反馈原文查看
-- 用途：内部分析用户真实感受，发现产品改进点
--
-- ⚠️ 隐私警告 ⚠️
-- 此查询返回用户文字反馈原文，仅供项目组内部分析使用：
--   - 不得复制到公开报告 / PPT / 答辩材料
--   - 不得在公开场合展示原文
--   - 报告中只使用聚合统计或脱敏摘要（如"用户反馈集中在放松/入睡主题"）
--   - 使用后建议清除终端历史
-- ════════════════════════════════════════════════════════════════
SELECT substr(createdAt, 1, 19) AS created_at,
  targetState,
  relaxationScore,
  calmnessScore,
  freeTextFeedback
FROM feedback
WHERE freeTextFeedback IS NOT NULL
  AND freeTextFeedback != ''
ORDER BY createdAt DESC
LIMIT 50;
-- ════════════════════════════════════════════════════════════════
-- 附录：CSV 导出方式
-- ════════════════════════════════════════════════════════════════
-- 方式 1：wrangler --json 输出 + jq 转 CSV（需安装 jq）
-- npx wrangler d1 execute xinxian-feedback --remote ^
--   --command "SELECT substr(createdAt,1,10) AS date, targetState, audioAssetId, relaxationScore, calmnessScore FROM feedback ORDER BY createdAt DESC" ^
--   --json | jq -r ".[0].results | (.[0] | keys) as $keys | ($keys | @csv), (.[] | [.$keys[]] | @csv)" > feedback_export.csv
--
-- 方式 2：Cloudflare Dashboard → D1 → Console 执行 SQL → 复制结果到 Excel/CSV
--
-- 方式 3：wrangler --json 输出后用 Python 脚本转 CSV（适合大批量）
-- npx wrangler d1 execute xinxian-feedback --remote --command "SELECT * FROM feedback" --json > feedback_raw.json
-- 然后用 Python 解析 feedback_raw.json 转为 CSV
-- ════════════════════════════════════════════════════════════════
-- 附录 B：M8.1 消融实验分组分析（custom / generic / control 三组对比）
-- ════════════════════════════════════════════════════════════════
--
-- 背景：
--   M8.1 引入 HashExperimentAssigner，按 sessionId hash 稳定分流到
--   custom / generic / control 三组（默认配比 1:1:1）。
--   分组字段 experimentVariant 已存在于 D1 feedback 表（M7 建立，含索引）。
--
--   ⚠️ 重要：M8.1 保守 MVP 阶段，generic / control 组仍走 custom 的完整
--   推荐流程（不改变音频匹配），仅记录分组标签。
--   真正的音频旁路（generic 固定 soothe_01 / control 固定 sleep_01）
--   留到 M8.2。M8.1 数据可作为"分组记录基线"，与 M8.2 上线后的数据对齐。
--
--   ⚠️ 实验期过滤：
--   M8.1 上线前所有记录 experimentVariant 均为 'custom'（来自 MockExperimentAssigner）。
--   分析时必须用 WHERE createdAt >= '<M8.1 上线日期>' 过滤，
--   否则历史 custom 数据会稀释实验信号。
--   示例：WHERE createdAt >= '2026-07-10'
--
-- 隐私说明：
--   - experimentVariant 仅用于匿名体验效果分析，不关联用户身份
--   - 不采集用户心境原文，不基于原文分组
--   - 不做医疗效果结论，只描述主观反馈差异
-- ─── B1：每组反馈数 + 平均 relaxationScore / calmnessScore ───────
-- 用途：核心对比表，报告首页
-- 替换 '2026-07-10' 为 M8.1 实际上线日期
SELECT COALESCE(experimentVariant, '(null)') AS variant,
  COUNT(*) AS count,
  ROUND(AVG(relaxationScore), 2) AS avg_relaxation,
  ROUND(AVG(calmnessScore), 2) AS avg_calmness
FROM feedback
WHERE createdAt >= '2026-07-10'
GROUP BY experimentVariant
ORDER BY variant;
-- ─── B2：每组 targetState 分布 ─────────────────────────────────
-- 用途：观察各组用户实际落到的目标状态
-- M8.1 保守 MVP：三组 targetState 分布应基本一致（因推荐逻辑未变）
-- M8.2 启用音频旁路后：generic 应全部 soothe，control 应全部 sleep
SELECT COALESCE(experimentVariant, '(null)') AS variant,
  COALESCE(targetState, '(null)') AS target_state,
  COUNT(*) AS count
FROM feedback
WHERE createdAt >= '2026-07-10'
GROUP BY experimentVariant,
  targetState
ORDER BY variant,
  target_state;
-- ─── B3：每组 audioAssetId 分布 ────────────────────────────────
-- 用途：验证分组是否生效（M8.1 三组应基本一致；M8.2 后应有差异）
SELECT COALESCE(experimentVariant, '(null)') AS variant,
  COALESCE(audioAssetId, '(null)') AS audio_asset_id,
  COUNT(*) AS count
FROM feedback
WHERE createdAt >= '2026-07-10'
GROUP BY experimentVariant,
  audioAssetId
ORDER BY variant,
  audio_asset_id;
-- ─── B4：每组 analyzerMode 分布（控制变量验证）─────────────────
-- 用途：确认三组内 llm / mock / fallback 分布一致，
--   避免 analyzerMode 混入干扰变量
SELECT COALESCE(experimentVariant, '(null)') AS variant,
  COALESCE(analyzerMode, '(null)') AS analyzer_mode,
  COUNT(*) AS count,
  ROUND(AVG(relaxationScore), 2) AS avg_relaxation,
  ROUND(AVG(calmnessScore), 2) AS avg_calmness
FROM feedback
WHERE createdAt >= '2026-07-10'
GROUP BY experimentVariant,
  analyzerMode
ORDER BY variant,
  analyzer_mode;
-- ─── B5：每组反馈提交率代理（含文字反馈占比）─────────────────────
-- 用途：M8.1 MVP 暂只看分子（每组反馈绝对数 + 文字反馈占比）
--   completionRatio 留待 M8.2 增加 D1 字段后补充
SELECT COALESCE(experimentVariant, '(null)') AS variant,
  COUNT(*) AS feedback_count,
  SUM(
    CASE
      WHEN freeTextFeedback IS NOT NULL
      AND freeTextFeedback != '' THEN 1
      ELSE 0
    END
  ) AS has_text_count,
  ROUND(
    SUM(
      CASE
        WHEN freeTextFeedback IS NOT NULL
        AND freeTextFeedback != '' THEN 1
        ELSE 0
      END
    ) * 100.0 / COUNT(*),
    1
  ) AS text_percentage
FROM feedback
WHERE createdAt >= '2026-07-10'
GROUP BY experimentVariant
ORDER BY variant;
-- ─── B6：最近实验反馈记录（最新 30 条）──────────────────────────
-- 用途：快速查看实验期最新反馈趋势，排查异常
SELECT experimentVariant,
  substr(createdAt, 1, 19) AS created_at,
  targetState,
  audioAssetId,
  relaxationScore,
  calmnessScore,
  CASE
    WHEN freeTextFeedback IS NOT NULL
    AND freeTextFeedback != '' THEN '(有)'
    ELSE '(无)'
  END AS has_text
FROM feedback
WHERE createdAt >= '2026-07-10'
ORDER BY createdAt DESC
LIMIT 30;
-- ════════════════════════════════════════════════════════════════
-- P3-Web-v1.0 第一批新增查询（基础运营指标）
--
-- 目标：快速查看反馈数据质量和基础运营指标
-- 不改 D1 schema，不改 submit-feedback API，不改前端 UI
-- ════════════════════════════════════════════════════════════════
-- ════════════════════════════════════════════════════════════════
-- 查询 9：总体平均评分（relaxationScore + calmnessScore）
-- 用途：项目验收首页核心指标，衡量整体反馈质量
-- 字段说明：
--   relaxationScore  1-5（5 = 最放松）
--   calmnessScore    0-100（100 = 状态最好）
-- ════════════════════════════════════════════════════════════════
SELECT COUNT(*) AS total_feedback,
  ROUND(AVG(relaxationScore), 2) AS avg_relaxation_score,
  ROUND(AVG(calmnessScore), 2) AS avg_calmness_score,
  MIN(relaxationScore) AS min_relaxation,
  MAX(relaxationScore) AS max_relaxation,
  MIN(calmnessScore) AS min_calmness,
  MAX(calmnessScore) AS max_calmness
FROM feedback
WHERE relaxationScore IS NOT NULL;
-- ════════════════════════════════════════════════════════════════
-- 查询 10：按 targetState 分组的反馈数量 + 平均评分 + 平均 calmnessScore
-- 用途：对比 5 类目标状态（sleep/regulate/soothe/focus/energize）的反馈质量差异
--   为后续音频优化和推荐策略调整提供依据
-- ════════════════════════════════════════════════════════════════
SELECT COALESCE(targetState, '(null)') AS target_state,
  COUNT(*) AS count,
  ROUND(
    COUNT(*) * 100.0 / (
      SELECT COUNT(*)
      FROM feedback
    ),
    1
  ) AS percentage,
  ROUND(AVG(relaxationScore), 2) AS avg_relaxation,
  ROUND(AVG(calmnessScore), 2) AS avg_calmness,
  MIN(relaxationScore) AS min_relaxation,
  MAX(relaxationScore) AS max_relaxation
FROM feedback
WHERE relaxationScore IS NOT NULL
GROUP BY targetState
ORDER BY count DESC;
-- ════════════════════════════════════════════════════════════════
-- 查询 11：低评分反馈列表（relaxationScore <= 2）
-- 用途：发现体验问题，定位需要改进的音频 / 场景
-- 隐私说明：不返回 freeTextFeedback 原文，仅显示是否有文字反馈
-- ════════════════════════════════════════════════════════════════
SELECT substr(createdAt, 1, 19) AS created_at,
  targetState,
  audioAssetId,
  relaxationScore,
  calmnessScore,
  experimentVariant,
  analyzerMode,
  CASE
    WHEN freeTextFeedback IS NOT NULL
    AND freeTextFeedback != '' THEN '(有)'
    ELSE '(无)'
  END AS has_text
FROM feedback
WHERE relaxationScore IS NOT NULL
  AND relaxationScore <= 2
ORDER BY relaxationScore ASC,
  createdAt DESC;
-- ════════════════════════════════════════════════════════════════
-- 查询 12：高评分反馈列表（relaxationScore >= 4）
-- 用途：识别表现优秀的音频 / 场景，为后续推荐策略优化提供正向依据
-- 隐私说明：不返回 freeTextFeedback 原文，仅显示是否有文字反馈
-- ════════════════════════════════════════════════════════════════
SELECT substr(createdAt, 1, 19) AS created_at,
  targetState,
  audioAssetId,
  relaxationScore,
  calmnessScore,
  experimentVariant,
  analyzerMode,
  CASE
    WHEN freeTextFeedback IS NOT NULL
    AND freeTextFeedback != '' THEN '(有)'
    ELSE '(无)'
  END AS has_text
FROM feedback
WHERE relaxationScore IS NOT NULL
  AND relaxationScore >= 4
ORDER BY relaxationScore DESC,
  createdAt DESC;
-- ════════════════════════════════════════════════════════════════
-- P3 指标分析能力说明
-- ════════════════════════════════════════════════════════════════
--
-- ✅ 当前可分析指标：
--   1. 总反馈数（查询 1）
--   2. targetState 分布（查询 2）
--   3. audioAssetId 平均评分对比（查询 3）
--   4. 最近 20 条反馈趋势（查询 4）
--   5. 每日反馈数量趋势（查询 5）
--   6. 文字反馈占比（查询 6）
--   7. 实验分组统计（查询 7）
--   8. 文字反馈原文查看 [隐私敏感]（查询 8）
--   9. 总体平均评分 + 区间（查询 9，P3 新增）
--   10. 按 targetState 分组的反馈质量对比（查询 10，P3 新增）
--   11. 低评分反馈列表（查询 11，P3 新增）
--   12. 高评分反馈列表（查询 12，P3 新增）
--   13. 消融实验分组分析 B1-B6（附录 B）
--
-- ❌ 当前还缺的指标（需扩展 D1 schema 或派生字段）：
--   - improvement（体验前后状态改善量 = after - before）：
--     D1 schema 未存储 tensionBefore / tensionAfter 原始值，只有派生的 calmnessScore（= tensionAfter × 100）。
--     当前只能用 calmnessScore 作为"体验后状态"近似指标，无法计算"改善量"。
--     后续 P3 扩展可补齐 tensionBefore D1 字段，或新增 improvement 派生字段。
--   - completionRatio（聆听完成率）：
--     D1 schema 无此字段，需 M8.2 / P3 后续扩展补齐。
--   - emotionMatchScore / willingToContinue：
--     D1 schema 已有字段，但前端当前未收集（M7.0 留空），数据均为 NULL。
--   - 用户身份 / 跨设备聚合：
--     心弦为匿名 Demo，无用户系统，无法按用户聚合。