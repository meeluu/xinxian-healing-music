// 心弦 · LLM 情绪解析网关（Cloudflare Pages Function）
//
// 职责：接收前端 POST /api/analyze-mood，调用 LLM 解析心境文本，
// 返回标准化 MoodProfile JSON。任何异常都返回 fallback，绝不返回 502。
//
// 兼容性：支持任何 OpenAI-compatible API（OpenAI / DeepSeek / Moonshot / Together 等），
// 通过环境变量切换：
//   OPENAI_API_KEY    — 必填，API Key（不强制 sk- 前缀，兼容各家格式）
//   OPENAI_BASE_URL   — 可选，默认 https://api.openai.com/v1
//   OPENAI_MODEL      — 可选，默认 gpt-4o-mini（DeepSeek 用 deepseek-chat）
//   ENABLE_LLM        — 可选，设为 'false' 时禁用 LLM 走 fallback
//
// 安全：API Key 只从 context.env 读取，不硬编码，不打印，不返回给前端。
// 隐私：用户心境文本仅在本次请求中用于 LLM 调用，不存储、不记录到日志。
//
// 编码：所有响应统一 UTF-8，通过 jsonResponse() helper 返回。
// 容错：handler 外层有 try/catch 兜底，绝不因内部异常返回 502。
//
// 与 Netlify 版的差异：
// - 入口从 exports.handler 改为 export async function onRequestPost(context)
// - 环境变量从 process.env 改为 context.env
// - 响应从 { statusCode, headers, body } 改为 new Response(...)
// - LLM 调用从 openai SDK 改为原生 fetch（消除 Workers 兼容风险）
// - 移除内存限流（Workers 跨请求无状态；改用 Cloudflare Dashboard 速率限制规则）

// ─── CORS 白名单 ─────────────────────────────────────────────
// 仅允许心弦自有域名与本地开发地址，避免被任意站点滥用。
function allowedOrigin(origin) {
  if (typeof origin !== 'string' || origin.length === 0) {
    // curl / PowerShell 等无 Origin 的客户端：回退到正式域名，
    // 方便命令行测试（不阻塞请求，但浏览器跨域读仍受 CORS 限制）
    return 'https://xinxian-music.xyz';
  }
  if (origin === 'https://xinxian-music.xyz') return origin;
  if (origin === 'https://www.xinxian-music.xyz') return origin;
  if (origin === 'https://xinxian-healing-music.pages.dev') return origin;
  if (/^https:\/\/[a-z0-9-]+\.xinxian-healing-music\.pages\.dev$/.test(origin)) return origin;
  if (/^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)) return origin;
  return null;
}

// ─── 统一响应 helper（确保所有响应都带 charset=utf-8）──────────
function jsonResponse(payload, statusCode, origin) {
  const headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
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

function fallback(reason, extra, origin) {
  const payload = {
    ok: false,
    source: 'fallback',
    reason: reason,
    mood: null,
  };
  if (extra && typeof extra === 'object') {
    Object.keys(extra).forEach(function (k) { payload[k] = extra[k]; });
  }
  return jsonResponse(payload, 200, origin);
}

// ─── System Prompt（强化版，从 Netlify 版原样搬迁）──────────────
const SYSTEM_PROMPT = [
  '你是一个情绪解析助手。用户会输入一段中文心境描述，你需要严格根据原文内容分析其情绪状态，只输出一个 JSON 对象，不要输出任何 Markdown、解释、代码块标记或多余文字。',
  '',
  '输出 JSON 字段：',
  '- tags：3-5 个中文情绪标签（数组），如"焦虑""紧绷""思绪过载""失眠""压力"',
  '- valence：情绪效价，-1.0（极消极）到 1.0（极积极）',
  '- arousal：唤醒度，0.0（极平静）到 1.0（极激越）',
  '- intensity：情绪强度，0.0 到 1.0',
  '- targetState：期望调节目标，只能是以下五个之一：sleep / regulate / soothe / focus / energize。不允许输出 relax / company 等旧值',
  '- dominantNeed：主导需求（中文短句，不允许为 null），如"快速入眠""情绪降温""缓解焦虑"',
  '- summary：一句话情绪摘要（中文，15-30 字），用第二人称，如"你正承受较大压力，思绪难以停歇"',
  '',
  'targetState 归一规则（必须严格遵守）：',
  '- "睡不着 / 想睡觉 / 入眠困难 / 失眠" → sleep',
  '- "压力大 / 焦虑 / 情绪波动 / 需要稳定下来 / 紧绷" → regulate',
  '- "想放松一下 / 有点累 / 想舒缓 / 低落 / 难过 / 想被安慰" → soothe',
  '- "想学习 / 想专注 / 工作效率 / 集中注意力" → focus',
  '- "没精神 / 想提振 / 刚睡醒很困 / 提不起劲" → energize',
  '',
  '判断规则（必须严格遵守）：',
  '1. 必须根据用户原文的实际内容判断，不要默认"平衡"。',
  '2. 如果原文提到"压力""备考""焦虑""紧绷""睡不着""失眠""脑子停不下来""思绪过载"等：',
  '   - tags 必须包含"焦虑""压力""失眠""思绪过载"中的至少 2 个',
  '   - valence 必须 < 0（消极）',
  '   - arousal 必须 >= 0.65',
  '   - intensity 必须 >= 0.65',
  '   - targetState 优先 sleep（含"睡不着/失眠"）或 regulate（含"压力/焦虑/紧绷"）',
  '   - dominantNeed 不能为 null，应如"快速入眠""缓解焦虑""情绪降温"',
  '   - summary 必须呼应原文，不能用"状态相对平稳"等中性表述',
  '3. 只有原文确实平淡、无情绪倾向时，才输出：valence=0.2, arousal=0.4, targetState=soothe, tags=["平衡"], summary="状态相对平稳"',
  '4. 不使用医学术语，用"辅助放松""情绪调节""睡前舒缓""正念陪伴"等温和表述',
  '5. 不做医疗诊断，不判断疾病',
  '6. summary 用温和、共情的语气',
  '7. 输出必须是纯 JSON 对象，不要代码块标记，不要任何解释文字',
].join('\n');

// ─── 输入校验（从 Netlify 版原样搬迁）─────────────────────────
function validateInput(body) {
  if (!body || typeof body !== 'object') {
    return { ok: false, reason: 'invalid_input' };
  }
  var text = body.text;
  if (typeof text !== 'string' || text.length === 0) {
    return { ok: false, reason: 'invalid_input' };
  }
  if (text.length > 500) {
    return { ok: false, reason: 'invalid_input' };
  }
  return { ok: true, text: text };
}

// ─── 乱码检测（从 Netlify 版原样搬迁）─────────────────────────
// 检测 UTF-8 被错误按 Latin-1 解码后产生的乱码模式。
// 典型特征：å / è / ã / ç 等高字节字符后跟 ASCII 小写字母。
var MOJIBAKE_PATTERN = /[\u00C0-\u00FF][a-z]/;
var CJK_PATTERN = /[\u4E00-\u9FFF]/;

function looksGarbled(str) {
  if (typeof str !== 'string') return false;
  if (str.indexOf('\uFFFD') !== -1) return true;
  if (MOJIBAKE_PATTERN.test(str)) return true;
  return false;
}

function hasChinese(str) {
  return typeof str === 'string' && CJK_PATTERN.test(str);
}

// ─── 输出校验 + 规范化（严格版，从 Netlify 版原样搬迁）──────────
// P1 小质量修复：targetState 标准枚举统一为五类
// sleep / regulate / soothe / focus / energize
// 历史旧值 relax / company 在 normalizeMood 中归一为 soothe
var VALID_TARGET_STATES = ['sleep', 'regulate', 'soothe', 'focus', 'energize'];

function normalizeMood(raw) {
  if (!raw || typeof raw !== 'object') return null;

  // ── tags：严格校验，不兜底"平衡" ──
  var tags = raw.tags;
  if (!Array.isArray(tags)) return null;
  tags = tags.filter(function (t) {
    return typeof t === 'string' && t.length > 0 && !looksGarbled(t);
  }).slice(0, 5);
  tags = tags.filter(function (t) { return hasChinese(t); });
  if (tags.length === 0) return null;

  // ── 数值字段 clamp ──
  function clamp(v, min, max, dflt) {
    var n = typeof v === 'number' && Number.isFinite(v) ? v : dflt;
    return Math.max(min, Math.min(max, n));
  }
  var valence = clamp(raw.valence, -1.0, 1.0, 0.2);
  var arousal = clamp(raw.arousal, 0.0, 1.0, 0.4);
  var intensity = clamp(raw.intensity, 0.0, 1.0, 0.3);

  // ── targetState 枚举校验 + 旧值归一 ──
  // LLM 偶发仍返回 relax / company 旧值时，归一为 soothe（语义最接近"正念陪伴"），
  // 不触发 fallback，保留 tags / summary 等其他字段。
  // 其他非法值才 fallback 到 soothe（与 prompt 平淡输入默认一致）。
  var ts = typeof raw.targetState === 'string' ? raw.targetState : '';
  var targetState;
  if (ts === 'relax' || ts === 'company') {
    targetState = 'soothe';
  } else if (VALID_TARGET_STATES.indexOf(ts) !== -1) {
    targetState = ts;
  } else {
    targetState = 'soothe';
  }

  // ── dominantNeed：允许 null，但如果有值必须不乱码 ──
  var dominantNeed = null;
  if (typeof raw.dominantNeed === 'string' && raw.dominantNeed.length > 0) {
    if (looksGarbled(raw.dominantNeed)) return null;
    dominantNeed = raw.dominantNeed.slice(0, 20);
  }

  // ── summary：严格校验 ──
  var rawSummary = raw.summary;
  if (typeof rawSummary !== 'string' || rawSummary.length === 0) return null;
  if (looksGarbled(rawSummary)) return null;
  if (!hasChinese(rawSummary)) return null;
  var summary = rawSummary.slice(0, 60);

  return {
    tags: tags,
    valence: valence,
    arousal: arousal,
    intensity: intensity,
    targetState: targetState,
    dominantNeed: dominantNeed,
    summary: summary,
  };
}

// ─── LLM 配置（从 context.env 读取，非 process.env）──────────
function buildLlmConfig(env) {
  return {
    apiKey: env.OPENAI_API_KEY || '',
    baseURL: env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
    model: env.OPENAI_MODEL || 'gpt-4o-mini',
  };
}

// ─── 安全判断超时/中断错误（不依赖 instanceof）──────────────────
function isTimeoutError(err) {
  if (!err) return false;
  var name = err.name || '';
  var msg = err.message || '';
  if (name === 'AbortError') return true; // AbortController 超时中断
  if (name === 'APIConnectionTimeoutError') return true;
  if (name === 'APITimeoutError') return true;
  if (/timeout/i.test(name)) return true;
  if (/timeout/i.test(msg)) return true;
  if (/abort/i.test(msg)) return true;
  return false;
}

// ─── LLM 调用（原生 fetch，不依赖 openai SDK）──────────────────
// 用 AbortController 实现超时控制，超时后 abort 触发 AbortError。
async function callLlm(config, userText) {
  const controller = new AbortController();
  const timeoutId = setTimeout(function () { controller.abort(); }, 8000);
  try {
    const resp = await fetch(config.baseURL + '/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + config.apiKey,
      },
      body: JSON.stringify({
        model: config.model,
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: userText },
        ],
        temperature: 0.3,
        max_tokens: 300,
        response_format: { type: 'json_object' },
      }),
      signal: controller.signal,
    });
    if (!resp.ok) {
      throw new Error('llm_http_' + resp.status);
    }
    const data = await resp.json();
    const content = data && data.choices && data.choices[0] && data.choices[0].message && data.choices[0].message.content;
    if (!content) throw new Error('LLM 返回空内容');
    return JSON.parse(content);
  } finally {
    clearTimeout(timeoutId);
  }
}

// ─── Cloudflare Pages Function 入口 ───────────────────────────
// 整个 handler 体用 try/catch 兜底，任何未捕获异常都返回 fallback，绝不 502。
export async function onRequestPost(context) {
  const { request, env } = context;
  const origin = request.headers.get('Origin');
  try {
    // 解析 body
    let body;
    try {
      body = await request.json();
    } catch (_) {
      return fallback('json_parse_failed', null, origin);
    }

    // 输入校验
    const validation = validateInput(body);
    if (!validation.ok) {
      return fallback(validation.reason, null, origin);
    }

    // LLM 功能开关：未设置或非 'false' 时开启，显式 'false' 时关闭
    if (env.ENABLE_LLM === 'false') {
      return fallback('llm_disabled', null, origin);
    }

    // 构建 LLM 配置
    const config = buildLlmConfig(env);

    // API Key 检查
    if (!config.apiKey) {
      console.error('[analyze-mood] OPENAI_API_KEY 未配置');
      return fallback('no_api_key', null, origin);
    }

    // 调用 LLM
    try {
      const rawMood = await callLlm(config, validation.text);
      const mood = normalizeMood(rawMood);
      if (!mood) {
        console.error('[analyze-mood] LLM 返回数据无法规范化（tags/summary 缺失或乱码）');
        return fallback('llm_output_invalid', null, origin);
      }
      return jsonResponse({ ok: true, source: 'llm', mood: mood }, 200, origin);
    } catch (err) {
      const reason = isTimeoutError(err) ? 'llm_timeout' : 'llm_error';
      console.error('[analyze-mood] LLM 调用失败 (' + reason + '):', err && err.message);
      return fallback(reason, null, origin);
    }
  } catch (topErr) {
    // 最后防线：任何未预期的异常都返回 fallback，绝不 502
    console.error('[analyze-mood] handler 顶层异常:', topErr && topErr.message);
    return fallback('llm_error', null, origin);
  }
}

// ─── CORS 预检 ────────────────────────────────────────────────
export async function onRequestOptions(context) {
  const { request } = context;
  const origin = request.headers.get('Origin');
  const headers = {
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  const allowed = allowedOrigin(origin);
  if (allowed) {
    headers['Access-Control-Allow-Origin'] = allowed;
  }
  return new Response(null, { status: 204, headers: headers });
}
