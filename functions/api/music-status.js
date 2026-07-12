// 心弦 · AI 音乐生成任务状态查询（Cloudflare Pages Function · P4.4-2 provider adapter）
//
// 职责：接收前端 GET /api/music-status?id=xxx，通过 provider factory 查询任务状态。
//
// Provider 选择与 generate-music.js 一致（基于环境变量）。
// Mock provider：无状态，通过 jobId 中编码的时间戳计算已耗时。
// StableAudioProvider 骨架：返回 fallback（不发真实请求）。

import { jsonResponse, inferTargetState, getFallbackTrack, allowedOrigin } from './_music/music-generation-utils.js';
import { createProvider } from './_music/provider-factory.js';

// ─── Cloudflare Pages Function 入口 ───────────────────────────
export async function onRequestGet(context) {
  var request = context.request;
  var env = context.env || {};
  var origin = request.headers.get('Origin');
  try {
    var url = new URL(request.url);
    var jobId = url.searchParams.get('id');

    if (!jobId || typeof jobId !== 'string' || jobId.length > 200) {
      return jsonResponse({
        ok: false,
        reason: 'invalid_job_id',
        fallbackTrack: getFallbackTrack('sleep'),
      }, 200, origin, 'GET, OPTIONS');
    }

    var targetState = inferTargetState(request.url);

    // 通过 provider factory 选择 provider 并查询状态
    var provider = createProvider(env);
    var result = provider.getStatus(jobId, targetState);

    return jsonResponse(result, 200, origin, 'GET, OPTIONS');
  } catch (topErr) {
    console.error('[music-status] handler 顶层异常:', topErr && topErr.message);
    return jsonResponse({
      ok: false,
      reason: 'internal_error',
      fallbackTrack: getFallbackTrack('sleep'),
    }, 200, origin, 'GET, OPTIONS');
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
