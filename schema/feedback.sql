-- 心弦 · M7 云端反馈数据采集 · D1 建表 DDL
--
-- 用法：
--   npx wrangler d1 execute xinxian-feedback --remote --file=./schema/feedback.sql
--   npx wrangler d1 execute xinxian-feedback --local --file=./schema/feedback.sql  （本地预览）
--
-- 设计要点：
-- - 主键 listeningSessionId（upsert 语义：重复提交覆盖）
-- - 所有非主键字段允许 NULL，方便 schema 演进
-- - 不采集用户心境原文（moodText），只采集结构化情绪标签和参数
-- - 文字反馈 freeTextFeedback 受前端独立同意开关控制，可为 NULL
-- - schemaVersion 字段预留，未来迁移用
-- - 索引覆盖消融实验常用筛选维度（variant / targetState / analyzerMode / createdAt）

CREATE TABLE IF NOT EXISTS feedback (
  -- 标识
  sessionId          TEXT NOT NULL,
  listeningSessionId TEXT PRIMARY KEY,
  createdAt          TEXT NOT NULL,

  -- 实验分组
  experimentVariant  TEXT,
  analyzerMode       TEXT,

  -- 情绪画像（结构化，非原文）
  targetState        TEXT,
  emotionTags        TEXT,
  valence            REAL,
  arousal            REAL,
  intensity          REAL,

  -- 音频与方案
  musicTitle         TEXT,
  audioAssetId       TEXT,
  audioAssetTitle    TEXT,
  bpm                INTEGER,
  brainwaveTarget    TEXT,
  noiseLayer         TEXT,

  -- 用户反馈评分
  relaxationScore    INTEGER,
  emotionMatchScore  INTEGER,
  calmnessScore      INTEGER,
  willingToContinue  INTEGER,

  -- 文字反馈（可选，受独立开关控制）
  freeTextFeedback   TEXT,

  -- 元数据
  clientVersion      TEXT,
  userAgent          TEXT,
  source             TEXT NOT NULL,
  schemaVersion      INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_feedback_variant  ON feedback(experimentVariant);
CREATE INDEX IF NOT EXISTS idx_feedback_target   ON feedback(targetState);
CREATE INDEX IF NOT EXISTS idx_feedback_analyzer ON feedback(analyzerMode);
CREATE INDEX IF NOT EXISTS idx_feedback_created  ON feedback(createdAt);
