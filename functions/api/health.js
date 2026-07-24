// 心弦 · 健康检查端点（Cloudflare Pages Function）
//
// 职责：返回服务可用性 + 版本 + 时间戳 + 非敏感诊断字段，用于快速判断 Functions 是否正常部署。
// 不访问 D1，不访问 LLM；仅读取非敏感 env 变量用于诊断（不读取任何 API Key 值）。
//
// 设计：
// - GET /api/health → 200 + { ok, service, version, timestamp, diagnostics }
// - OPTIONS /api/health → 204（CORS 预检）
// - 任何异常都返回 200 + ok:false，绝不返回 502
//
// P4 第四批新增 diagnostics 字段（用于排查 provider=mock 等问题）：
// - musicProvider：env.MUSIC_GENERATION_PROVIDER || 'mock'
// - realCallsEnabled：env.MUSIC_GENERATION_REAL_CALLS_ENABLED === 'true'
// - hasMinimaxKey：!!env.MINIMAX_API_KEY（仅 true/false，不泄露 Key 值）
// - buildLabel：与本文件常量同步（用于确认线上部署的代码版本）
//
// P4-generated-audio-playback-1 新增 diagnostics 字段（用于排查 R2 落地问题）：
// - hasR2Bucket：!!env.GENERATED_MUSIC_BUCKET（R2 binding 是否配置，不泄露 bucket 名）
//
// 安全：
// - 不返回任何 API Key 值，只返回 hasXxxKey: true/false
// - 不返回 env 中的其他敏感字段
// - diagnostics 只用于排查 provider 选择 / 真实调用开关 / Key 配置状态 / R2 配置状态

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

// P4 第四批：buildLabel 与前端 lib/config/app_version.dart 同步维护
// 用于 /api/health 诊断：确认线上部署的代码版本
// P4 MiniMax 真实生成链路受控测试：同步更新为 P4-minimax-real-test-1
// P4 生成音频落地播放链路：同步更新为 P4-generated-audio-playback-1
// P4 临时音频播放闭环：同步更新为 P4-temp-audio-playback-1
// P4 临时音频播放闭环代码审计清理：同步更新为 P4-temp-audio-playback-1-cleanup
// P4 生成歌曲结果页体验优化：同步更新为 P4-song-result-experience-1
// P6 本地额度保护：同步更新为 P6-quota-guard-1
// P4-conversation-song-flow-1：多轮困惑理解 + 更贴合困境的歌词 + 纯音乐本地舒缓 + 定时关闭
// P4-conversation-song-flow-1-fix1：LLM 动态追问 + 歌词贴合度增强 + 加载文案分阶段
// P4-conversation-song-flow-1-fix2：low_energy 场景 + lowEnergy 追问问题对齐 + 歌词低能量指引
// P4-playback-experience-2：AI 歌曲独立播放页 + 本地舒缓播放模式增强（4 种模式 + 定时强制持续播放）
// P4-player-seek-bugfix-1：修复快速舒缓播放页首次进入拖动进度条回到 0 秒的问题（_pendingSeek 防回弹 + completedFlag 分离重播/继续）
const BUILD_LABEL = 'P4-player-seek-bugfix-1';

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

/// 构造非敏感诊断字段（P4 第四批新增）
/// 只读取 env 中的非敏感配置 + Key 是否存在（不读取 Key 值）
/// 导出用于测试（verify-provider-adapter.mjs）
/// P4-generated-audio-playback-1：新增 hasR2Bucket 字段（R2 binding 是否配置）
export function buildDiagnostics(env) {
  env = env || {};
  return {
    musicProvider: env.MUSIC_GENERATION_PROVIDER || 'mock',
    realCallsEnabled: env.MUSIC_GENERATION_REAL_CALLS_ENABLED === 'true',
    hasMinimaxKey: !!env.MINIMAX_API_KEY,
    hasReplicateToken: !!env.REPLICATE_API_TOKEN,
    hasStableAudioKey: !!env.STABLE_AUDIO_API_KEY,
    hasR2Bucket: !!env.GENERATED_MUSIC_BUCKET,
    buildLabel: BUILD_LABEL,
  };
}

// ─── GET /api/health ─────────────────────────────────────────
// 不访问 D1 / LLM；仅读取非敏感 env 用于诊断（不读取任何 API Key 值）
export async function onRequestGet(context) {
  const { request, env } = context;
  const origin = request.headers.get('Origin');
  try {
    return jsonResponse({
      ok: true,
      service: SERVICE_NAME,
      version: SERVICE_VERSION,
      timestamp: new Date().toISOString(),
      diagnostics: buildDiagnostics(env),
    }, 200, origin);
  } catch (err) {
    // 任何异常都返回 200 + ok:false，绝不 502
    console.error('[health] 异常:', err && err.message);
    return jsonResponse({
      ok: false,
      service: SERVICE_NAME,
      version: SERVICE_VERSION,
      timestamp: new Date().toISOString(),
      diagnostics: buildDiagnostics(env),
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
