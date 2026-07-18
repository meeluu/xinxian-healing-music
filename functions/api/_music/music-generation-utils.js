// 心弦 · AI 音乐生成共享工具（P4.4-2 provider adapter）
//
// 从 generate-music.js / music-status.js 抽出的公共逻辑：
// - CORS 白名单 + jsonResponse
// - 预置音频映射
// - Prompt 关键词过滤
// - 输入校验
// - jobId 生成 / 解析
// - 进度估算
//
// 本模块不依赖 Cloudflare 特有 API（Response 是 Web 标准），
// 可在 Node.js 18+ 或 Cloudflare Pages Functions 中使用。

// ─── CORS 白名单 ─────────────────────────────────────────────
export function allowedOrigin(origin) {
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

// ─── 统一 JSON 响应 ──────────────────────────────────────────
export function jsonResponse(payload, statusCode, origin, methods) {
  var headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Methods': methods || 'GET, POST, OPTIONS',
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
export var FALLBACK_TRACKS = {
  sleep: { audioAssetId: 'sleep_01', audioAssetTitle: '夜色舒缓 · Theta 入眠', audioUrl: '/assets/music/sleep_01.mp3' },
  regulate: { audioAssetId: 'regulate_01', audioAssetTitle: '降频调节 · Alpha 平复', audioUrl: '/assets/music/regulate_01.mp3' },
  soothe: { audioAssetId: 'soothe_01', audioAssetTitle: '温柔安抚 · 情绪陪伴', audioUrl: '/assets/music/soothe_01.mp3' },
  focus: { audioAssetId: 'focus_01', audioAssetTitle: '稳定聚焦 · Low Beta 节奏', audioUrl: '/assets/music/focus_01.mp3' },
  energize: { audioAssetId: 'energize_01', audioAssetTitle: '温和充能 · 自然回暖', audioUrl: '/assets/music/energize_01.mp3' },
};

export function getFallbackTrack(targetState) {
  return FALLBACK_TRACKS[targetState] || FALLBACK_TRACKS.sleep;
}

// ─── 有效 targetState 列表 ────────────────────────────────────
export var VALID_TARGET_STATES = ['sleep', 'regulate', 'soothe', 'focus', 'energize'];

// ─── Prompt 关键词过滤 ────────────────────────────────────────
export var FORBIDDEN_KEYWORDS = [
  'cure', 'treat', 'therapy', 'heal', 'anxiety relief', 'insomnia treatment',
  'suicide', 'self-harm', 'violence', 'kill',
];

export function isPromptForbidden(prompt) {
  if (typeof prompt !== 'string') return true;
  var lower = prompt.toLowerCase();
  for (var i = 0; i < FORBIDDEN_KEYWORDS.length; i++) {
    if (lower.indexOf(FORBIDDEN_KEYWORDS[i]) !== -1) return true;
  }
  return false;
}

// ─── 输入校验 ─────────────────────────────────────────────────
export function validateInput(body) {
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
    durationSeconds = 300;
  }
  // P4.4-5: manualTest 字段透传（仅用于 MiniMax 真实调用测试双重保护）
  // 默认 false；前端正常请求不会携带此字段，只有手动 curl 测试时显式传入 true
  var manualTest = body.manualTest === true;
  return {
    ok: true,
    sessionId: sessionId,
    targetState: targetState,
    prompt: prompt,
    durationSeconds: Math.round(durationSeconds),
    manualTest: manualTest,
  };
}

// ─── 生成 jobId（编码时间戳，供无状态计算进度）─────────────────
export function generateJobId() {
  var timestamp = Date.now().toString(36);
  var random = Math.random().toString(36).substring(2, 10);
  return 'job_' + timestamp + '_' + random;
}

// ─── 从 jobId 解析创建时间戳 ──────────────────────────────────
export function parseJobTimestamp(jobId) {
  if (typeof jobId !== 'string' || jobId.indexOf('job_') !== 0) return null;
  var parts = jobId.split('_');
  if (parts.length < 3) return null;
  var ts = parseInt(parts[1], 36);
  if (!Number.isFinite(ts) || ts <= 0) return null;
  return ts;
}

// ─── 从 URL 推断 targetState ──────────────────────────────────
export function inferTargetState(url) {
  try {
    var params = new URL(url).searchParams;
    var ts = params.get('targetState');
    if (ts && VALID_TARGET_STATES.indexOf(ts) !== -1) {
      return ts;
    }
  } catch (_) {}
  return 'sleep';
}

// ─── 进度估算 ─────────────────────────────────────────────────
export function estimateProgress(elapsedMs) {
  if (elapsedMs < 2000) return 10 + Math.round((elapsedMs / 2000) * 50);
  if (elapsedMs < 4000) return 60 + Math.round(((elapsedMs - 2000) / 2000) * 30);
  if (elapsedMs < 5000) return 90 + Math.round(((elapsedMs - 4000) / 1000) * 5);
  return 95;
}
