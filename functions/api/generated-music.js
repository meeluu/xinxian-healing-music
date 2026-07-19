// 心弦 · 生成音频读取端点（Cloudflare Pages Function · P4-generated-audio-playback-1）
//
// 职责：从 R2 读取 MiniMax 生成并落地的音频文件，以 audio/mpeg 流式返回给前端播放。
//
// 请求格式：
//   GET /api/generated-music?key=generated-music/20260719/{sessionId}-{traceId}.mp3
//   OPTIONS /api/generated-music（CORS 预检）
//
// 响应：
//   200 + audio/mpeg binary（成功）
//   404 + JSON（key 不存在 / R2 未配置 / 入参缺失）
//   500 + JSON（其他异常）
//
// 设计原则：
// - R2 object 不公开访问（私有 bucket），统一通过本端点代理读取
// - 受 CORS 白名单保护，避免被任意站点滥用
// - 不在日志中打印完整 key 值（只打印 keyLength）
// - 不允许列目录 / 不允许遍历（只接受 query param 中的单个 key）
// - key 必须以 generated-music/ 前缀开头，避免读到其他目录
//
// 安全：
// - 不暴露 R2 bucket 名 / binding 名到响应
// - key 路径校验：必须以 'generated-music/' 开头，且只允许 a-zA-Z0-9_-/. 字符
// - 不读取 query param 之外的其他字段
// - 异常时返回友好错误，不泄露 R2 内部错误细节
//
// 缓存策略：
// - 生成音频为静态资源，允许浏览器 / CDN 缓存（max-age=86400，1 天）
// - 但 must-revalidate：如果 R2 中文件被删除，下次请求应重新拉取

import { allowedOrigin } from './_music/music-generation-utils.js';

/// 校验 storageKey 是否合法
/// 规则：
/// 1. 必须是字符串且非空
/// 2. 必须以 'generated-music/' 开头（防止路径穿越 / 读取其他目录）
/// 3. 只允许 a-zA-Z0-9 _ - / . 字符
/// 4. 长度 ≤ 200（防御性限制）
/// 返回 true 表示合法
function isValidStorageKey(key) {
  if (typeof key !== 'string' || key.length === 0 || key.length > 200) {
    return false;
  }
  if (key.indexOf('generated-music/') !== 0) {
    return false;
  }
  // 只允许安全字符（防止 ../ / ..%2F 等路径穿越）
  if (!/^[a-zA-Z0-9_\-\/\.]+$/.test(key)) {
    return false;
  }
  // 防止 ../ 穿越
  if (key.indexOf('..') !== -1) {
    return false;
  }
  return true;
}

/// 统一 JSON 响应（带 CORS）
function jsonResponse(payload, statusCode, origin, methods) {
  var headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Methods': methods || 'GET, OPTIONS',
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

// ─── GET /api/generated-music ────────────────────────────────
// 从 R2 读取生成音频并以 audio/mpeg 流式返回
export async function onRequestGet(context) {
  var request = context.request;
  var env = context.env || {};
  var origin = request.headers.get('Origin');

  try {
    // 1. 检查 R2 binding 是否配置
    var r2Bucket = env.GENERATED_MUSIC_BUCKET;
    if (!r2Bucket) {
      console.error('[generated-music] R2 binding 未配置：GENERATED_MUSIC_BUCKET 缺失');
      return jsonResponse({
        ok: false,
        reason: 'r2_not_configured',
        errorMessage: '音频存储尚未配置',
      }, 503, origin);
    }

    // 2. 解析 query param
    var url = new URL(request.url);
    var key = url.searchParams.get('key');
    if (!key) {
      return jsonResponse({
        ok: false,
        reason: 'missing_key',
        errorMessage: '音频地址缺失',
      }, 400, origin);
    }

    // 3. 校验 key 合法性
    if (!isValidStorageKey(key)) {
      console.error('[generated-music] 非法 storageKey', { keyLength: key.length });
      return jsonResponse({
        ok: false,
        reason: 'invalid_key',
        errorMessage: '音频地址不合法',
      }, 400, origin);
    }

    // 4. 从 R2 读取
    var object = await r2Bucket.get(key);
    if (!object) {
      console.log('[generated-music] R2 对象不存在', { keyLength: key.length });
      return jsonResponse({
        ok: false,
        reason: 'not_found',
        errorMessage: '音频已不存在或已过期',
      }, 404, origin);
    }

    // 5. 流式返回音频
    // R2 object body 是 ReadableStream，直接传给 Response（避免一次性读入内存）
    var headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('Content-Type', 'audio/mpeg');
    headers.set('Cache-Control', 'public, max-age=86400, must-revalidate');
    headers.set('Content-Length', object.size);
    headers.set('Accept-Ranges', 'bytes');
    var allowed = allowedOrigin(origin);
    if (allowed) {
      headers.set('Access-Control-Allow-Origin', allowed);
      headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
      headers.set('Access-Control-Allow-Headers', 'Content-Type');
    }

    console.log('[generated-music] 返回音频', {
      keyLength: key.length,
      size: object.size,
      hasBody: !!object.body,
      // 不打印 key 完整值
    });

    return new Response(object.body, {
      status: 200,
      headers: headers,
    });
  } catch (err) {
    console.error('[generated-music] 读取异常:', err && err.name, err && err.message);
    return jsonResponse({
      ok: false,
      reason: 'internal_error',
      errorMessage: '音频读取失败，请稍后再试',
    }, 500, origin);
  }
}

// ─── CORS 预检 ───────────────────────────────────────────────
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
