-- 心弦 · M8 反馈数据分析常用 SQL 查询
--
-- 用法：
--   1. 单条查询：复制 SQL 内容执行
--      npx wrangler d1 execute xinxian-feedback --remote --command "SELECT ..."
--   2. 整文件执行（会依次执行所有语句，适合本地预览）：
--      npx wrangler d1 execute xinxian-feedback --remote --file=./scripts/feedback-queries.sql
--   3. 图形化界面：
--      Cloudflare Dashboard → Storage & Databases → D1 SQL Database
--      → xinxian-feedback → Console / Query
--
-- 数据库：xinxian-feedback（D1 / SQLite）
-- 表：feedback（25 字段，主键 listeningSessionId，M7 建立）
-- createdAt 格式：ISO8601 字符串，如 2026-06-28T10:00:00.000Z
--   提取日期用 substr(createdAt, 1, 10)
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
SELECT COUNT(*) AS total_feedback FROM feedback;


-- ════════════════════════════════════════════════════════════════
-- 查询 2：targetState 分布
-- 用途：了解 5 类目标状态（sleep/regulate/soothe/focus/energize）的使用分布
-- ════════════════════════════════════════════════════════════════
SELECT
  COALESCE(targetState, '(null)') AS target_state,
  COUNT(*) AS count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM feedback), 1) AS percentage
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
SELECT
  COALESCE(audioAssetId, '(null)') AS audio_asset_id,
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
SELECT
  listeningSessionId,
  substr(createdAt, 1, 19) AS created_at,
  targetState,
  experimentVariant,
  analyzerMode,
  audioAssetId,
  relaxationScore,
  calmnessScore,
  CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN '(有)' ELSE '(无)' END AS has_text,
  clientVersion
FROM feedback
ORDER BY createdAt DESC
LIMIT 20;


-- ════════════════════════════════════════════════════════════════
-- 查询 5：每日反馈数量
-- 用途：查看反馈增长趋势，识别活跃时段
-- ════════════════════════════════════════════════════════════════
SELECT
  substr(createdAt, 1, 10) AS date,
  COUNT(*) AS count
FROM feedback
GROUP BY substr(createdAt, 1, 10)
ORDER BY date DESC;


-- ════════════════════════════════════════════════════════════════
-- 查询 6：freeTextFeedback 非空数量
-- 用途：衡量用户深度参与度（愿意写文字反馈的比例）
-- ════════════════════════════════════════════════════════════════
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN 1 ELSE 0 END) AS has_text,
  ROUND(
    SUM(CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
    1
  ) AS text_percentage
FROM feedback;


-- ════════════════════════════════════════════════════════════════
-- 查询 7：实验分组统计 experimentVariant / analyzerMode
-- 用途：为 M8 消融实验（custom / generic / control 三组对比）准备基线数据
-- 说明：当前阶段所有记录均为 custom + mock/llm，三组对比需待实验分组启用后
-- ════════════════════════════════════════════════════════════════
SELECT
  COALESCE(experimentVariant, '(null)') AS variant,
  COALESCE(analyzerMode, '(null)') AS analyzer_mode,
  COUNT(*) AS count,
  ROUND(AVG(relaxationScore), 2) AS avg_relaxation,
  ROUND(AVG(calmnessScore), 2) AS avg_calmness
FROM feedback
GROUP BY experimentVariant, analyzerMode
ORDER BY variant, analyzer_mode;


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
SELECT
  substr(createdAt, 1, 19) AS created_at,
  targetState,
  relaxationScore,
  calmnessScore,
  freeTextFeedback
FROM feedback
WHERE freeTextFeedback IS NOT NULL AND freeTextFeedback != ''
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
SELECT
  COALESCE(experimentVariant, '(null)') AS variant,
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
SELECT
  COALESCE(experimentVariant, '(null)') AS variant,
  COALESCE(targetState, '(null)') AS target_state,
  COUNT(*) AS count
FROM feedback
WHERE createdAt >= '2026-07-10'
GROUP BY experimentVariant, targetState
ORDER BY variant, target_state;


-- ─── B3：每组 audioAssetId 分布 ────────────────────────────────
-- 用途：验证分组是否生效（M8.1 三组应基本一致；M8.2 后应有差异）
SELECT
  COALESCE(experimentVariant, '(null)') AS variant,
  COALESCE(audioAssetId, '(null)') AS audio_asset_id,
  COUNT(*) AS count
FROM feedback
WHERE createdAt >= '2026-07-10'
GROUP BY experimentVariant, audioAssetId
ORDER BY variant, audio_asset_id;


-- ─── B4：每组 analyzerMode 分布（控制变量验证）─────────────────
-- 用途：确认三组内 llm / mock / fallback 分布一致，
--   避免 analyzerMode 混入干扰变量
SELECT
  COALESCE(experimentVariant, '(null)') AS variant,
  COALESCE(analyzerMode, '(null)') AS analyzer_mode,
  COUNT(*) AS count,
  ROUND(AVG(relaxationScore), 2) AS avg_relaxation,
  ROUND(AVG(calmnessScore), 2) AS avg_calmness
FROM feedback
WHERE createdAt >= '2026-07-10'
GROUP BY experimentVariant, analyzerMode
ORDER BY variant, analyzer_mode;


-- ─── B5：每组反馈提交率代理（含文字反馈占比）─────────────────────
-- 用途：M8.1 MVP 暂只看分子（每组反馈绝对数 + 文字反馈占比）
--   completionRatio 留待 M8.2 增加 D1 字段后补充
SELECT
  COALESCE(experimentVariant, '(null)') AS variant,
  COUNT(*) AS feedback_count,
  SUM(CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN 1 ELSE 0 END) AS has_text_count,
  ROUND(
    SUM(CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
    1
  ) AS text_percentage
FROM feedback
WHERE createdAt >= '2026-07-10'
GROUP BY experimentVariant
ORDER BY variant;


-- ─── B6：最近实验反馈记录（最新 30 条）──────────────────────────
-- 用途：快速查看实验期最新反馈趋势，排查异常
SELECT
  experimentVariant,
  substr(createdAt, 1, 19) AS created_at,
  targetState,
  audioAssetId,
  relaxationScore,
  calmnessScore,
  CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN '(有)' ELSE '(无)' END AS has_text
FROM feedback
WHERE createdAt >= '2026-07-10'
ORDER BY createdAt DESC
LIMIT 30;
