// 心弦 · AI 音乐生成任务状态查询（Cloudflare Pages Function · P4.3 mock）
//
// 职责：接收前端 GET /api/music-status?id=xxx，返回生成任务状态。
// P4.3 阶段为 mock 实现：无状态，通过 jobId 中编码的时间戳计算已耗时。
//
// Mock 状态流：
// - 0-2s   → generating（进度 10-60%）
// - 2-4s   → generating（进度 60-90%）
// - 4-5s   → 随机 succeeded（80%）或 failed（20%）
// - >5s    → succeeded（mock 最终都会成功，除非随机到 failed）
//
// succeeded 时返回预置音频 URL 作为 mock "生成结果"（provider: "mock"）
// failed 时返回 fallbackTrack，前端自动切换预置音频
//
// P4.4 将替换为真实 Stable Audio API 任务查询。

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
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
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

// ─── 预置音频映射（与 generate-music.js 一致）──────────────────
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

// ─── 从 jobId 解析创建时间戳 ──────────────────────────────────
// jobId 格式：job_{base36_timestamp}_{random}
function parseJobTimestamp(jobId) {
  if (typeof jobId !== 'string' || jobId.indexOf('job_') !== 0) return null;
  var parts = jobId.split('_');
  if (parts.length < 3) return null;
  var ts = parseInt(parts[1], 36);
  if (!Number.isFinite(ts) || ts <= 0) return null;
  return ts;
}

// ─── 从 jobId 推断 targetState（编码在 query 参数或默认 sleep）──
// 前端轮询时会带上 targetState 作为 query 参数，便于 mock 返回正确音频。
function inferTargetState(url) {
  try {
    var params = new URL(url).searchParams;
    var ts = params.get('targetState');
    if (ts && ['sleep', 'regulate', 'soothe', 'focus', 'energize'].indexOf(ts) !== -1) {
      return ts;
    }
  } catch (_) {}
  return 'sleep';
}

// ─── 进度估算 ─────────────────────────────────────────────────
function estimateProgress(elapsedMs) {
  if (elapsedMs < 2000) return 10 + Math.round((elapsedMs / 2000) * 50); // 10-60%
  if (elapsedMs < 4000) return 60 + Math.round(((elapsedMs - 2000) / 2000) * 30); // 60-90%
  if (elapsedMs < 5000) return 90 + Math.round(((elapsedMs - 4000) / 1000) * 5); // 90-95%
  return 95; // 不超过 95 直到真正 succeeded
}

// ─── Cloudflare Pages Function 入口 ───────────────────────────
export async function onRequestGet(context) {
  var request = context.request;
  var origin = request.headers.get('Origin');
  try {
    var url = new URL(request.url);
    var jobId = url.searchParams.get('id');

    if (!jobId || typeof jobId !== 'string' || jobId.length > 200) {
      return jsonResponse({
        ok: false,
        reason: 'invalid_job_id',
        fallbackTrack: getFallbackTrack('sleep'),
      }, 200, origin);
    }

    var createdAt = parseJobTimestamp(jobId);
    if (!createdAt) {
      return jsonResponse({
        ok: false,
        reason: 'invalid_job_id',
        fallbackTrack: getFallbackTrack('sleep'),
      }, 200, origin);
    }

    var targetState = inferTargetState(request.url);
    var elapsedMs = Date.now() - createdAt;
    var elapsedSeconds = Math.max(0, Math.round(elapsedMs / 1000));
    var progress = estimateProgress(elapsedMs);
    var fallbackTrack = getFallbackTrack(targetState);

    // Mock 状态机
    if (elapsedMs < 4000) {
      // 0-4s：generating
      return jsonResponse({
        ok: true,
        jobId: jobId,
        status: 'generating',
        audioUrl: null,
        fallbackTrack: fallbackTrack,
        errorCode: null,
        progress: progress,
        elapsedSeconds: elapsedSeconds,
        provider: 'mock',
      }, 200, origin);
    }

    // 4-5s：90% 概率 succeeded，10% 概率 failed（模拟真实失败场景）
    // 使用 jobId 的随机部分作为种子，保证同一 jobId 多次查询结果一致
    var randomPart = jobId.split('_')[2] || '0';
    var seed = 0;
    for (var i = 0; i < randomPart.length; i++) {
      seed = (seed * 31 + randomPart.charCodeAt(i)) % 100;
    }
    var isSuccess = seed >= 10; // 90% 成功

    if (isSuccess) {
      // succeeded：返回预置音频 URL 作为 mock "生成结果"
      // 注意：mock 阶段 audioUrl 与 fallbackTrack 相同（都是预置音频）
      // P4.4 接入真实 API 后 audioUrl 将是 R2 上的生成音频
      return jsonResponse({
        ok: true,
        jobId: jobId,
        status: 'succeeded',
        audioUrl: fallbackTrack.audioUrl,
        fallbackTrack: fallbackTrack,
        errorCode: null,
        progress: 100,
        elapsedSeconds: elapsedSeconds,
        provider: 'mock',
      }, 200, origin);
    } else {
      // failed：返回 fallbackTrack
      return jsonResponse({
        ok: true,
        jobId: jobId,
        status: 'failed',
        audioUrl: null,
        fallbackTrack: fallbackTrack,
        errorCode: 'mock_random_failure',
        progress: progress,
        elapsedSeconds: elapsedSeconds,
        provider: 'mock',
      }, 200, origin);
    }
  } catch (topErr) {
    console.error('[music-status] handler 顶层异常:', topErr && topErr.message);
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
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  var allowed = allowedOrigin(origin);
  if (allowed) {
    headers['Access-Control-Allow-Origin'] = allowed;
  }
  return new Response(null, { status: 204, headers: headers });
}
