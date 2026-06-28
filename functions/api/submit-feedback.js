// 心弦 · M7 云端反馈数据采集（Cloudflare Pages Function）
//
// 职责：接收前端 POST /api/submit-feedback，将匿名反馈写入 Cloudflare D1。
// 任何异常都返回 200 + ok:false，绝不返回 502，前端 fire-and-forget 无感。
//
// 隐私：
// - 不采集用户心境原文（moodText），只接收结构化情绪标签和参数
// - 文字反馈 freeTextFeedback 由前端独立同意开关控制，可为 null
// - 不采集 IP 地址，不记录到日志
// - 字段白名单：未知字段直接丢弃
//
// 安全：
// - 主键 upsert（INSERT ... ON CONFLICT DO UPDATE），重复提交覆盖
// - 长度限制：freeTextFeedback 最多 2000 字符，emotionTags 最多 20 个
// - 不做鉴权（匿名），M7.0 不加频控（额度充足，后续可加）
//
// 依赖：D1 binding `xinxian_feedback`（在 wrangler.toml 配置）

// ─── 统一响应 helper（与 analyze-mood.js 一致）──────────────
function jsonResponse(payload, statusCode = 200) {
  return new Response(JSON.stringify(payload), {
    status: statusCode,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });
}

function fallback(reason) {
  return jsonResponse({ ok: false, received: false, reason: reason });
}

// ─── 字段白名单 + 类型规范化 ──────────────────────────────────
// 只接受这些字段，未知字段直接丢弃。所有字段允许 null/undefined。
var ALLOWED_FIELDS = {
  sessionId: 'string',
  listeningSessionId: 'string',
  createdAt: 'string',
  experimentVariant: 'string',
  analyzerMode: 'string',
  targetState: 'string',
  emotionTags: 'object', // array
  valence: 'number',
  arousal: 'number',
  intensity: 'number',
  musicTitle: 'string',
  audioAssetId: 'string',
  audioAssetTitle: 'string',
  bpm: 'number',
  brainwaveTarget: 'string',
  noiseLayer: 'string',
  relaxationScore: 'number',
  emotionMatchScore: 'number',
  calmnessScore: 'number',
  willingToContinue: 'number',
  freeTextFeedback: 'string',
  clientVersion: 'string',
  userAgent: 'string',
  source: 'string',
  schemaVersion: 'number',
};

function sanitize(input) {
  if (!input || typeof input !== 'object') return null;
  var out = {};
  var keys = Object.keys(ALLOWED_FIELDS);
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i];
    var expected = ALLOWED_FIELDS[k];
    var v = input[k];
    if (v === undefined || v === null) continue;
    // 类型检查（array 用 typeof 'object'，需额外校验）
    if (expected === 'object') {
      if (!Array.isArray(v)) continue;
    } else if (typeof v !== expected) {
      continue;
    }
    out[k] = v;
  }
  return out;
}

// ─── 长度限制 ────────────────────────────────────────────────
function clampLengths(payload) {
  if (typeof payload.freeTextFeedback === 'string' && payload.freeTextFeedback.length > 2000) {
    payload.freeTextFeedback = payload.freeTextFeedback.slice(0, 2000);
  }
  if (Array.isArray(payload.emotionTags)) {
    payload.emotionTags = payload.emotionTags.slice(0, 20);
  }
  if (typeof payload.userAgent === 'string' && payload.userAgent.length > 500) {
    payload.userAgent = payload.userAgent.slice(0, 500);
  }
  return payload;
}

// ─── D1 INSERT（upsert 语义）──────────────────────────────────
async function insertFeedback(db, p) {
  // emotionTags 数组转 JSON 字符串存储
  var tagsJson = Array.isArray(p.emotionTags) ? JSON.stringify(p.emotionTags) : null;

  var stmt = db.prepare(
    'INSERT INTO feedback (' +
      'sessionId, listeningSessionId, createdAt, ' +
      'experimentVariant, analyzerMode, ' +
      'targetState, emotionTags, valence, arousal, intensity, ' +
      'musicTitle, audioAssetId, audioAssetTitle, bpm, brainwaveTarget, noiseLayer, ' +
      'relaxationScore, emotionMatchScore, calmnessScore, willingToContinue, ' +
      'freeTextFeedback, clientVersion, userAgent, source, schemaVersion' +
    ') VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24, ?25) ' +
    'ON CONFLICT(listeningSessionId) DO UPDATE SET ' +
      'sessionId = excluded.sessionId, ' +
      'createdAt = excluded.createdAt, ' +
      'experimentVariant = excluded.experimentVariant, ' +
      'analyzerMode = excluded.analyzerMode, ' +
      'targetState = excluded.targetState, ' +
      'emotionTags = excluded.emotionTags, ' +
      'valence = excluded.valence, ' +
      'arousal = excluded.arousal, ' +
      'intensity = excluded.intensity, ' +
      'musicTitle = excluded.musicTitle, ' +
      'audioAssetId = excluded.audioAssetId, ' +
      'audioAssetTitle = excluded.audioAssetTitle, ' +
      'bpm = excluded.bpm, ' +
      'brainwaveTarget = excluded.brainwaveTarget, ' +
      'noiseLayer = excluded.noiseLayer, ' +
      'relaxationScore = excluded.relaxationScore, ' +
      'emotionMatchScore = excluded.emotionMatchScore, ' +
      'calmnessScore = excluded.calmnessScore, ' +
      'willingToContinue = excluded.willingToContinue, ' +
      'freeTextFeedback = excluded.freeTextFeedback, ' +
      'clientVersion = excluded.clientVersion, ' +
      'userAgent = excluded.userAgent, ' +
      'source = excluded.source, ' +
      'schemaVersion = excluded.schemaVersion'
  );

  await stmt.bind(
    p.sessionId || null,
    p.listeningSessionId || null,
    p.createdAt || null,
    p.experimentVariant || null,
    p.analyzerMode || null,
    p.targetState || null,
    tagsJson,
    typeof p.valence === 'number' ? p.valence : null,
    typeof p.arousal === 'number' ? p.arousal : null,
    typeof p.intensity === 'number' ? p.intensity : null,
    p.musicTitle || null,
    p.audioAssetId || null,
    p.audioAssetTitle || null,
    typeof p.bpm === 'number' ? Math.round(p.bpm) : null,
    p.brainwaveTarget || null,
    p.noiseLayer || null,
    typeof p.relaxationScore === 'number' ? Math.round(p.relaxationScore) : null,
    typeof p.emotionMatchScore === 'number' ? Math.round(p.emotionMatchScore) : null,
    typeof p.calmnessScore === 'number' ? Math.round(p.calmnessScore) : null,
    typeof p.willingToContinue === 'number' ? Math.round(p.willingToContinue) : null,
    p.freeTextFeedback || null,
    p.clientVersion || null,
    p.userAgent || null,
    p.source || 'web',
    typeof p.schemaVersion === 'number' ? Math.round(p.schemaVersion) : 1
  ).run();
}

// ─── Cloudflare Pages Function 入口 ───────────────────────────
export async function onRequestPost(context) {
  const { request, env } = context;
  try {
    // D1 binding 检查
    var db = env.xinxian_feedback;
    if (!db) {
      console.error('[submit-feedback] D1 binding xinxian_feedback 未配置');
      return fallback('db_not_configured');
    }

    // 解析 body
    var body;
    try {
      body = await request.json();
    } catch (_) {
      return fallback('json_parse_failed');
    }

    // 字段白名单 + 类型规范化
    var payload = sanitize(body);
    if (!payload) {
      return fallback('invalid_payload');
    }

    // 必填字段校验
    if (!payload.listeningSessionId || !payload.createdAt || !payload.source) {
      return fallback('missing_required_fields');
    }

    // 长度限制
    payload = clampLengths(payload);

    // 写入 D1
    try {
      await insertFeedback(db, payload);
      return jsonResponse({ ok: true, received: true });
    } catch (dbErr) {
      console.error('[submit-feedback] D1 INSERT 失败:', dbErr && dbErr.message);
      return fallback('db_insert_failed');
    }
  } catch (topErr) {
    // 最后防线：任何未预期异常都返回 fallback，绝不 502
    console.error('[submit-feedback] handler 顶层异常:', topErr && topErr.message);
    return fallback('unknown_error');
  }
}

// ─── CORS 预检 ────────────────────────────────────────────────
export async function onRequestOptions() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });
}
