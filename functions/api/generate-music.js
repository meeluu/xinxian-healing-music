// 心弦 · AI 音乐生成任务创建（Cloudflare Pages Function · P4.4-2 provider adapter）
//
// 职责：接收前端 POST /api/generate-music，通过 provider factory 选择 provider 创建任务。
//
// Provider 选择：
// - MUSIC_GENERATION_PROVIDER=mock（默认）→ MockProvider
// - MUSIC_GENERATION_PROVIDER=stable_audio + 无 Key → 降级 MockProvider
// - MUSIC_GENERATION_PROVIDER=stable_audio + 有 Key → StableAudioProvider 骨架（不发真实请求）
//
// 隐私：
// - 不接收用户心境原文，只接收脱敏 generationPrompt
// - 不存储 prompt 到 D1（本批不迁移 schema）
//
// 安全：
// - CORS 白名单
// - 输入校验 + prompt 长度限制 + 关键词过滤
// - 任何异常都返回 200 + ok:false + fallbackTrack，绝不 502

import { jsonResponse, validateInput, getFallbackTrack, VALID_TARGET_STATES, allowedOrigin } from './_music/music-generation-utils.js';
import { createProvider } from './_music/provider-factory.js';

// ─── Cloudflare Pages Function 入口 ───────────────────────────
export async function onRequestPost(context) {
    var request = context.request;
    var env = context.env || {};
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
            }, 200, origin, 'POST, OPTIONS');
        }

        // 输入校验
        var validation = validateInput(body);
        if (!validation.ok) {
            var fallbackState = (body && typeof body.targetState === 'string' && VALID_TARGET_STATES.indexOf(body.targetState) !== -1)
                ? body.targetState
                : 'sleep';
            return jsonResponse({
                ok: false,
                reason: validation.reason,
                fallbackTrack: getFallbackTrack(fallbackState),
            }, 200, origin, 'POST, OPTIONS');
        }

        // 通过 provider factory 选择 provider 并创建任务
        var provider = createProvider(env);
        var result = provider.createJob(validation);

        return jsonResponse(result, 200, origin, 'POST, OPTIONS');
    } catch (topErr) {
        console.error('[generate-music] handler 顶层异常:', topErr && topErr.message);
        return jsonResponse({
            ok: false,
            reason: 'internal_error',
            fallbackTrack: getFallbackTrack('sleep'),
        }, 200, origin, 'POST, OPTIONS');
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
