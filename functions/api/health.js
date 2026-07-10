// 心弦 · 健康检查端点（Cloudflare Pages Function）
//
// 职责：返回服务可用性 + 版本 + 时间戳，用于快速判断 Functions 是否正常部署。
// 不访问 D1，不访问 LLM，不依赖环境变量。
//
// 设计：
// - GET /api/health → 200 + { ok, service, version, timestamp }
// - OPTIONS /api/health → 204（CORS 预检）
// - 任何异常都返回 200 + ok:false，绝不返回 502
//
// 用途：
// - Cloudflare 部署后快速验证 Functions 是否生效
// - 运维监控 / 状态页探活
// - 不暴露任何敏感信息（无 env / 无 D1 / 无 LLM）

// ─── CORS 白名单 ─────────────────────────────────────────────
// 仅允许心弦自有域名与本地开发地址，避免被任意站点滥用。
function allowedOrigin(origin) {
  if (typeof origin !== 'string' || origin.length === 0) {
    // curl / PowerShell 等无 Origin 的客户端：回退到正式域名，
    // 方便命令行测试与浏览器直接访问 /api/health
    return 'https://xinxian-music.xyz';
  }
  if (origin === 'https://xinxian-music.xyz') return origin;
  if (origin === 'https://www.xinxian-music.xyz') return origin;
  if (origin === 'https://xinxian-healing-music.pages.dev') return origin;
  if (/^https:\/\/[a-z0-9-]+\.xinxian-healing-music\.pages\.dev$/.test(origin)) return origin;
  if (/^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)) return origin;
  return null;
}

const SERVICE_NAME = 'xinxian-functions';
const SERVICE_VERSION = 'v1';

// ─── 统一响应 helper ──────────────────────────────────────────
function jsonResponse(payload, statusCode, origin) {
  const headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  const allowed = allowedOrigin(origin);
  if (allowed) {
    headers['Access-Control-Allow-Origin'] = allowed;
  }
  return new Response(JSON.stringify(payload), {
    status: statusCode || 200,
    headers: headers,
  });
}

// ─── GET /api/health ─────────────────────────────────────────
// 不访问 D1 / LLM / env，仅返回静态信息 + 时间戳。
export async function onRequestGet(context) {
  const { request } = context;
  const origin = request.headers.get('Origin');
  try {
    return jsonResponse({
      ok: true,
      service: SERVICE_NAME,
      version: SERVICE_VERSION,
      timestamp: new Date().toISOString(),
    }, 200, origin);
  } catch (err) {
    // 任何异常都返回 200 + ok:false，绝不 502
    console.error('[health] 异常:', err && err.message);
    return jsonResponse({
      ok: false,
      service: SERVICE_NAME,
      version: SERVICE_VERSION,
      timestamp: new Date().toISOString(),
    }, 200, origin);
  }
}

// ─── CORS 预检 ───────────────────────────────────────────────
export async function onRequestOptions(context) {
  const { request } = context;
  const origin = request.headers.get('Origin');
  const headers = {
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  const allowed = allowedOrigin(origin);
  if (allowed) {
    headers['Access-Control-Allow-Origin'] = allowed;
  }
  return new Response(null, { status: 204, headers: headers });
}
