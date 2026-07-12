// 心弦 · AI 音乐生成任务创建（Cloudflare Pages Function · P4.3 mock）
//
// 职责：接收前端 POST /api/generate-music，创建音乐生成任务。
// P4.3 阶段为 mock 实现：不调用真实 Stable Audio API，不产生付费调用。
// 返回 jobId + fallbackTrack，前端可立即播放预置音频，同时轮询生成状态。
//
// 隐私：
// - 不接收用户心境原文（moodText），只接收脱敏的 generationPrompt
// - 不存储 prompt 到 D1（P4.3 不迁移 schema）
// - jobId 编码创建时间戳，music-status.js 据此无状态计算进度
//
// 安全：
// - CORS 白名单（与 analyze-mood / submit-feedback 一致）
// - 输入校验 + prompt 长度限制 + 关键词过滤
// - 任何异常都返回 200 + ok:false + fallbackTrack，绝不 502
//
// P4.4 将替换为真实 Stable Audio API 调用（需人工注册账号 + API Key）。

// ─── CORS 白名单 ─────────────────────────────────────────────
function allowedOrigin(origin) {
  if (typeof origin !== 'string' || origin.length === 0) {
    return 'https://xinxian-music.xyz';
  }
  if (origin === 'https://xinxian-music.xyz') return origin;
  if (origin === 'https://www.xinxian-music.xyz') return origin;
  if (origin === 'https://xinxian-healing-music.pages.dev') return origin;
  if (/^https:\/\/[a-z0-9-]+\.xinxian-healing-music\.pages\.dev$/.test(origin)) return origin;
  if (/^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)) return origin;
  return null;
}

function jsonResponse(payload, statusCode, origin) {
  var headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  var allowed = allowedOrigin(origin);
  if (allowed) {
    headers['Access-Control-Allow-Origin'] = allowed;
  }
  return new Response(JSON.stringify(payload), {
    status: statusCode || 200,
    headers: headers,
  });
}

// ─── 预置音频映射（与前端 AudioAssetCatalog 一致）──────────────
// music-status.js 成功时返回对应的预置音频 URL 作为 mock "生成结果"。
var FALLBACK_TRACKS = {
  sleep: { audioAssetId: 'sleep_01', audioAssetTitle: '夜色舒缓 · Theta 入眠', audioUrl: '/assets/music/sleep_01.mp3' },
  regulate: { audioAssetId: 'regulate_01', audioAssetTitle: '降频调节 · Alpha 平复', audioUrl: '/assets/music/regulate_01.mp3' },
  soothe: { audioAssetId: 'soothe_01', audioAssetTitle: '温柔安抚 · 情绪陪伴', audioUrl: '/assets/music/soothe_01.mp3' },
  focus: { audioAssetId: 'focus_01', audioAssetTitle: '稳定聚焦 · Low Beta 节奏', audioUrl: '/assets/music/focus_01.mp3' },
  energize: { audioAssetId: 'energize_01', audioAssetTitle: '温和充能 · 自然回暖', audioUrl: '/assets/music/energize_01.mp3' },
};

function getFallbackTrack(targetState) {
  return FALLBACK_TRACKS[targetState] || FALLBACK_TRACKS.sleep;
}

// ─── Prompt 关键词过滤 ────────────────────────────────────────
// 拒绝含医疗化/暴力/自残关键词的 prompt，保持心弦定位。
var FORBIDDEN_KEYWORDS = [
  'cure', 'treat', 'therapy', 'heal', 'anxiety relief', 'insomnia treatment',
  'suicide', 'self-harm', 'violence', 'kill',
];

function isPromptForbidden(prompt) {
  if (typeof prompt !== 'string') return true;
  var lower = prompt.toLowerCase();
  for (var i = 0; i < FORBIDDEN_KEYWORDS.length; i++) {
    if (lower.indexOf(FORBIDDEN_KEYWORDS[i]) !== -1) return true;
  }
  return false;
}

// ─── 输入校验 ─────────────────────────────────────────────────
var VALID_TARGET_STATES = ['sleep', 'regulate', 'soothe', 'focus', 'energize'];

function validateInput(body) {
  if (!body || typeof body !== 'object') {
    return { ok: false, reason: 'invalid_payload' };
  }
  var sessionId = body.sessionId;
  if (typeof sessionId !== 'string' || sessionId.length === 0 || sessionId.length > 100) {
    return { ok: false, reason: 'invalid_session_id' };
  }
  var targetState = body.targetState;
  if (VALID_TARGET_STATES.indexOf(targetState) === -1) {
    return { ok: false, reason: 'invalid_target_state' };
  }
  var prompt = body.generationPrompt;
  if (typeof prompt !== 'string' || prompt.length === 0 || prompt.length > 500) {
    return { ok: false, reason: 'invalid_prompt' };
  }
  if (isPromptForbidden(prompt)) {
    return { ok: false, reason: 'invalid_prompt' };
  }
  var durationSeconds = body.durationSeconds;
  if (typeof durationSeconds !== 'number' || durationSeconds < 60 || durationSeconds > 600) {
    durationSeconds = 300; // 默认 5 分钟
  }
  return {
    ok: true,
    sessionId: sessionId,
    targetState: targetState,
    prompt: prompt,
    durationSeconds: Math.round(durationSeconds),
  };
}

// ─── 生成 jobId（编码时间戳，供 music-status.js 无状态计算）─────
// 格式：job_{base36_timestamp}_{8位随机}
// music-status.js 解析 timestamp 部分即可计算已耗时。
function generateJobId() {
  var timestamp = Date.now().toString(36);
  var random = Math.random().toString(36).substring(2, 10);
  return 'job_' + timestamp + '_' + random;
}

// ─── Cloudflare Pages Function 入口 ───────────────────────────
export async function onRequestPost(context) {
  var request = context.request;
  var origin = request.headers.get('Origin');
  try {
    // 解析 body
    var body;
    try {
      body = await request.json();
    } catch (_) {
      return jsonResponse({
        ok: false,
        reason: 'json_parse_failed',
        fallbackTrack: getFallbackTrack('sleep'),
      }, 200, origin);
    }

    // 输入校验
    var validation = validateInput(body);
    if (!validation.ok) {
      // 校验失败也返回 fallbackTrack（尽力推断 targetState）
      var fallbackState = (body && typeof body.targetState === 'string' && VALID_TARGET_STATES.indexOf(body.targetState) !== -1)
        ? body.targetState
        : 'sleep';
      return jsonResponse({
        ok: false,
        reason: validation.reason,
        fallbackTrack: getFallbackTrack(fallbackState),
      }, 200, origin);
    }

    // P4.3 mock：不调用真实 API，直接返回 queued 状态
    var jobId = generateJobId();
    var fallbackTrack = getFallbackTrack(validation.targetState);

    return jsonResponse({
      ok: true,
      jobId: jobId,
      status: 'queued',
      fallbackTrack: fallbackTrack,
      estimatedSeconds: 5, // mock 预计 5 秒完成
      provider: 'mock',
      createdAt: new Date().toISOString(),
    }, 200, origin);
  } catch (topErr) {
    // 最后防线：任何未预期的异常都返回 fallback，绝不 502
    console.error('[generate-music] handler 顶层异常:', topErr && topErr.message);
    return jsonResponse({
      ok: false,
      reason: 'internal_error',
      fallbackTrack: getFallbackTrack('sleep'),
    }, 200, origin);
  }
}

// ─── CORS 预检 ────────────────────────────────────────────────
export async function onRequestOptions(context) {
  var request = context.request;
  var origin = request.headers.get('Origin');
  var headers = {
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  var allowed = allowedOrigin(origin);
  if (allowed) {
    headers['Access-Control-Allow-Origin'] = allowed;
  }
  return new Response(null, { status: 204, headers: headers });
}
