<#
.SYNOPSIS
  心弦 · D1 反馈数据查询辅助脚本（P3-Web-v1.0 第一批）

.DESCRIPTION
  封装常用的 wrangler d1 execute 命令，快速查看 Cloudflare D1 xinxian-feedback 数据库的反馈数据。
  不写入任何敏感信息，不修改远程 D1 数据，只读查询。

  内部调用：
    npx wrangler d1 execute xinxian-feedback --remote --command "..."

  前置条件：
  1. 已安装 Node.js + npx
  2. 已登录 wrangler（npx wrangler login）或配置了 CLOUDFLARE_API_TOKEN
  3. D1 数据库 xinxian-feedback 已建表（schema/feedback.sql）

.PARAMETER Recent
  查看最近 20 条反馈（不含文字原文）

.PARAMETER ByTargetState
  按 targetState 分组聚合：反馈数量 + 平均评分 + 平均 calmnessScore

.PARAMETER ByAudio
  按 audioAssetId 分组聚合：反馈数量 + 平均评分

.PARAMETER LowRating
  查看低评分反馈列表（relaxationScore <= 2）

.PARAMETER HighRating
  查看高评分反馈列表（relaxationScore >= 4）

.PARAMETER Notes
  查看文字反馈原文列表（[隐私敏感] 仅供内部分析）

.PARAMETER Daily
  按日期分组查看反馈数量趋势

.PARAMETER TextRatio
  查看文字反馈占比

.PARAMETER Local
  使用 --local 查询本地 D1 副本（默认 --remote 查询线上数据库）

.EXAMPLE
  # 基础统计（默认）：总反馈数 + 总体平均评分
  .\scripts\query-feedback.ps1

.EXAMPLE
  # 查看最近 20 条反馈
  .\scripts\query-feedback.ps1 -Recent

.EXAMPLE
  # 按 targetState 聚合
  .\scripts\query-feedback.ps1 -ByTargetState

.EXAMPLE
  # 查看低评分反馈
  .\scripts\query-feedback.ps1 -LowRating

.EXAMPLE
  # 查看文字反馈原文（隐私敏感）
  .\scripts\query-feedback.ps1 -Notes

.EXAMPLE
  # 查询本地 D1 副本（调试用）
  .\scripts\query-feedback.ps1 -Recent -Local

.NOTES
  字段语义：
    relaxationScore  1-5（5 = 最放松）
    calmnessScore    0-100（100 = 状态最好）
    targetState      sleep / regulate / soothe / focus / energize

  当前不能直接计算 improvement（D1 未存 tensionBefore/tensionAfter 原始值）。

  fix1（2026-07-11）：所有 SQL 改用 here-string @" ... "@ 避免 <= / >= / 单引号被 PowerShell 解析坏。
#>

[CmdletBinding()]
param(
  [switch]$Recent,
  [switch]$ByTargetState,
  [switch]$ByAudio,
  [switch]$LowRating,
  [switch]$HighRating,
  [switch]$Notes,
  [switch]$Daily,
  [switch]$TextRatio,
  [switch]$Local
)

# 选择查询目标：--local 或 --remote
$target = if ($Local) { '--local' } else { '--remote' }

# 数据库名称
$dbName = 'xinxian-feedback'

function Invoke-D1Query {
  param(
    [string]$Title,
    [string]$Sql
  )
  Write-Host ""
  Write-Host "==========================================" -ForegroundColor Cyan
  Write-Host " $Title" -ForegroundColor Cyan
  Write-Host "==========================================" -ForegroundColor Cyan
  Write-Host ""
  # 压缩 here-string 中的换行和多余空白为单空格，避免 wrangler --command 解析异常
  $compactSql = ($Sql -replace '\s+', ' ').Trim()
  # 使用 --command 执行单条 SQL
  npx wrangler d1 execute $dbName $target --command $compactSql
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] wrangler d1 execute 失败，退出码 $LASTEXITCODE" -ForegroundColor Red
  }
  Write-Host ""
}

# 如果没有任何参数，执行默认基础统计
$noSwitch = -not ($Recent -or $ByTargetState -or $ByAudio -or $LowRating -or $HighRating -or $Notes -or $Daily -or $TextRatio)

if ($noSwitch) {
  # 默认：总反馈数 + 总体平均评分（查询 1 + 查询 9 合并展示）
  $sqlBasic = @"
SELECT COUNT(*) AS total_feedback,
       ROUND(AVG(relaxationScore), 2) AS avg_relaxation_score,
       ROUND(AVG(calmnessScore), 2) AS avg_calmness_score,
       MIN(relaxationScore) AS min_relaxation,
       MAX(relaxationScore) AS max_relaxation
FROM feedback
WHERE relaxationScore IS NOT NULL;
"@
  Invoke-D1Query -Title "基础统计：总反馈数 + 平均评分" -Sql $sqlBasic

  # 同时展示 targetState 分布概览
  $sqlDist = @"
SELECT COALESCE(targetState, '(null)') AS target_state,
       COUNT(*) AS count,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM feedback), 1) AS percentage
FROM feedback
GROUP BY targetState
ORDER BY count DESC;
"@
  Invoke-D1Query -Title "targetState 分布概览" -Sql $sqlDist

  # 同时展示文字反馈占比
  $sqlText = @"
SELECT COUNT(*) AS total,
       SUM(CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN 1 ELSE 0 END) AS has_text,
       ROUND(SUM(CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS text_percentage
FROM feedback;
"@
  Invoke-D1Query -Title "文字反馈占比" -Sql $sqlText

  Write-Host "提示：使用 -Recent / -ByTargetState / -ByAudio / -LowRating / -HighRating / -Notes / -Daily / -TextRatio 查看更多维度" -ForegroundColor Yellow
  Write-Host "示例：.\scripts\query-feedback.ps1 -Recent" -ForegroundColor Yellow
  return
}

# 查看最近 20 条反馈
if ($Recent) {
  $sql = @"
SELECT listeningSessionId,
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
"@
  Invoke-D1Query -Title "最近 20 条反馈" -Sql $sql
}

# 按 targetState 分组聚合
if ($ByTargetState) {
  $sql = @"
SELECT COALESCE(targetState, '(null)') AS target_state,
       COUNT(*) AS count,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM feedback), 1) AS percentage,
       ROUND(AVG(relaxationScore), 2) AS avg_relaxation,
       ROUND(AVG(calmnessScore), 2) AS avg_calmness,
       MIN(relaxationScore) AS min_relaxation,
       MAX(relaxationScore) AS max_relaxation
FROM feedback
WHERE relaxationScore IS NOT NULL
GROUP BY targetState
ORDER BY count DESC;
"@
  Invoke-D1Query -Title "按 targetState 分组：数量 + 平均评分 + 平均 calmnessScore" -Sql $sql
}

# 按 audioAssetId 分组聚合
if ($ByAudio) {
  $sql = @"
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
"@
  Invoke-D1Query -Title "按 audioAssetId 分组：数量 + 平均评分" -Sql $sql
}

# 低评分反馈列表
if ($LowRating) {
  $sql = @"
SELECT substr(createdAt, 1, 19) AS created_at,
       targetState,
       audioAssetId,
       relaxationScore,
       calmnessScore,
       experimentVariant,
       analyzerMode,
       CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN '(有)' ELSE '(无)' END AS has_text
FROM feedback
WHERE relaxationScore IS NOT NULL AND relaxationScore <= 2
ORDER BY relaxationScore ASC, createdAt DESC;
"@
  Invoke-D1Query -Title "低评分反馈列表（relaxationScore <= 2）" -Sql $sql
}

# 高评分反馈列表
if ($HighRating) {
  $sql = @"
SELECT substr(createdAt, 1, 19) AS created_at,
       targetState,
       audioAssetId,
       relaxationScore,
       calmnessScore,
       experimentVariant,
       analyzerMode,
       CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN '(有)' ELSE '(无)' END AS has_text
FROM feedback
WHERE relaxationScore IS NOT NULL AND relaxationScore >= 4
ORDER BY relaxationScore DESC, createdAt DESC;
"@
  Invoke-D1Query -Title "高评分反馈列表（relaxationScore >= 4）" -Sql $sql
}

# 文字反馈原文列表 [隐私敏感]
if ($Notes) {
  Write-Host ""
  Write-Host "==========================================" -ForegroundColor Red
  Write-Host " ⚠️  隐私敏感查询：文字反馈原文" -ForegroundColor Red
  Write-Host " 仅供项目组内部分析，不得复制到公开报告 / PPT / 答辩材料" -ForegroundColor Red
  Write-Host "==========================================" -ForegroundColor Red
  $sql = @"
SELECT substr(createdAt, 1, 19) AS created_at,
       targetState,
       relaxationScore,
       calmnessScore,
       freeTextFeedback
FROM feedback
WHERE freeTextFeedback IS NOT NULL AND freeTextFeedback != ''
ORDER BY createdAt DESC
LIMIT 50;
"@
  Invoke-D1Query -Title "文字反馈原文（最多 50 条）" -Sql $sql
}

# 按日期分组
if ($Daily) {
  $sql = @"
SELECT substr(createdAt, 1, 10) AS date,
       COUNT(*) AS count
FROM feedback
GROUP BY substr(createdAt, 1, 10)
ORDER BY date DESC;
"@
  Invoke-D1Query -Title "每日反馈数量趋势" -Sql $sql
}

# 文字反馈占比
if ($TextRatio) {
  $sql = @"
SELECT COUNT(*) AS total,
       SUM(CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN 1 ELSE 0 END) AS has_text,
       ROUND(SUM(CASE WHEN freeTextFeedback IS NOT NULL AND freeTextFeedback != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS text_percentage
FROM feedback;
"@
  Invoke-D1Query -Title "文字反馈占比" -Sql $sql
}
