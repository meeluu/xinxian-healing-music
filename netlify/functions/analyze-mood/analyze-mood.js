// 心弦 · LLM 情绪解析网关
//
// 职责：接收前端 POST /api/analyze-mood，调用 LLM（OpenAI）解析心境文本，
// 返回标准化 MoodProfile JSON。LLM 失败 / Key 缺失 / JSON 解析失败时
// 返回 fallback 信号，前端 MoodAnalyzerGateway 自行降级到 Mock。
//
// 安全：OPENAI_API_KEY 只从环境变量读取，不硬编码，不返回给前端。
// 隐私：用户心境文本仅在本次请求中用于 LLM 调用，不存储、不记录到日志。

const OpenAI = require('openai');

// ─── System Prompt ─────────────────────────────────────────────
const SYSTEM_PROMPT = `你是一个情绪解析助手。用户会输入一段中文心境描述，你需要分析其情绪状态，输出结构化 JSON。不要输出任何 JSON 以外的内容。

分析维度：
- tags：3-5 个情绪标签（中文，如"焦虑""紧绷""思绪过载"）
- valence：情绪效价，-1.0（极消极）到 1.0（极积极）
- arousal：唤醒度，0.0（极平静）到 1.0（极激越）
- intensity：情绪强度，0.0 到 1.0
- targetState：期望调节目标，枚举值之一：relax / sleep / focus / company / regulate
- dominantNeed：主导需求（中文短句，可空），如"快速入眠""情绪降温"
- summary：一句话情绪摘要（中文，15-30 字），用第二人称，如"你正承受较大压力，思绪难以停歇"

规则：
- 空文本或无意义输入：valence=0.2, arousal=0.4, targetState=relax, tags=["平衡"], summary="状态相对平稳"
- 不使用医学术语，用"辅助放松""情绪调节""睡前舒缓""正念陪伴"等温和表述
- 不做医疗诊断，不判断疾病
- summary 用温和、共情的语气`;

// ─── 限流（内存计数器，同一实例存活期间有效）─────────────────
const RATE_LIMIT_PER_MIN = 10;
const _hits = new Map(); // ip → [timestamp, ...]

function isRateLimited(ip) {
  const now = Date.now();
  const arr = (_hits.get(ip) || []).filter((t) => now - t < 60_000);
  if (arr.length >= RATE_LIMIT_PER_MIN) {
    _hits.set(ip, arr);
    return true;
  }
  arr.push(now);
  _hits.set(ip, arr);
  return false;
}

// ─── 输入校验 ──────────────────────────────────────────────────
function validateInput(body) {
  if (!body || typeof body !== 'object') {
    return { ok: false, reason: 'invalid_input' };
  }
  const text = body.text;
  if (typeof text !== 'string' || text.length === 0) {
    return { ok: false, reason: 'invalid_input' };
  }
  if (text.length > 500) {
    return { ok: false, reason: 'invalid_input' };
  }
  return { ok: true, text };
}

// ─── 输出校验 + 规范化 ────────────────────────────────────────
const VALID_TARGET_STATES = ['relax', 'sleep', 'focus', 'company', 'regulate'];

function normalizeMood(raw) {
  if (!raw || typeof raw !== 'object') return null;

  // tags
  let tags = raw.tags;
  if (!Array.isArray(tags)) tags = ['平衡'];
  tags = tags.filter((t) => typeof t === 'string' && t.length > 0).slice(0, 5);
  if (tags.length === 0) tags = ['平衡'];

  // 数值字段 clamp
  const clamp = (v, min, max, dflt) => {
    const n = typeof v === 'number' && Number.isFinite(v) ? v : dflt;
    return Math.max(min, Math.min(max, n));
  };
  const valence = clamp(raw.valence, -1.0, 1.0, 0.2);
  const arousal = clamp(raw.arousal, 0.0, 1.0, 0.4);
  const intensity = clamp(raw.intensity, 0.0, 1.0, 0.3);

  // targetState 枚举校验
  const ts = typeof raw.targetState === 'string' ? raw.targetState : '';
  const targetState = VALID_TARGET_STATES.includes(ts) ? ts : 'relax';

  // dominantNeed 可空
  const dominantNeed =
    typeof raw.dominantNeed === 'string' && raw.dominantNeed.length > 0
      ? raw.dominantNeed.slice(0, 20)
      : null;

  // summary
  const summary =
    typeof raw.summary === 'string' && raw.summary.length > 0
      ? raw.summary.slice(0, 60)
      : '状态相对平稳';

  return {
    tags,
    valence,
    arousal,
    intensity,
    targetState,
    dominantNeed,
    summary,
  };
}

// ─── LLM 调用 ─────────────────────────────────────────────────
async function callLlm(apiKey, userText) {
  const client = new OpenAI({ apiKey, timeout: 6000 });
  const resp = await client.chat.completions.create({
    model: 'gpt-4o-mini',
    response_format: { type: 'json_object' },
    temperature: 0.3,
    max_tokens: 300,
    messages: [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: userText },
    ],
  });
  const content = resp.choices?.[0]?.message?.content;
  if (!content) throw new Error('LLM 返回空内容');
  return JSON.parse(content);
}

// ─── Netlify Function 入口 ────────────────────────────────────
exports.handler = async (event) => {
  // CORS（同域调用不需要，但预留本地 netlify dev 跨端口调试用）
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  // 预检
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers, body: '' };
  }
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ ok: false, source: 'fallback', reason: 'method_not_allowed', mood: null }),
    };
  }

  // 解析 body
  let body;
  try {
    body = JSON.parse(event.body || '{}');
  } catch (_) {
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ ok: false, source: 'fallback', reason: 'json_parse_failed', mood: null }),
    };
  }

  // 输入校验
  const validation = validateInput(body);
  if (!validation.ok) {
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ ok: false, source: 'fallback', reason: validation.reason, mood: null }),
    };
  }

  // 限流
  const ip = event.headers['client-ip'] || event.headers['x-forwarded-for'] || 'unknown';
  if (isRateLimited(ip)) {
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ ok: false, source: 'fallback', reason: 'rate_limited', mood: null, retryAfter: 60 }),
    };
  }

  // API Key 检查
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey || !apiKey.startsWith('sk-')) {
    console.error('[analyze-mood] OPENAI_API_KEY 缺失或格式错误');
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ ok: false, source: 'fallback', reason: 'no_api_key', mood: null }),
    };
  }

  // 调用 LLM
  try {
    const rawMood = await callLlm(apiKey, validation.text);
    const mood = normalizeMood(rawMood);
    if (!mood) {
      console.error('[analyze-mood] LLM 返回数据无法规范化');
      return {
        statusCode: 200,
        headers,
        body: JSON.stringify({ ok: false, source: 'fallback', reason: 'llm_output_invalid', mood: null }),
      };
    }
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ ok: true, source: 'llm', mood }),
    };
  } catch (err) {
    // 判断超时 vs 其他错误
    const reason = err instanceof OpenAI.APIConnectionTimeoutError ||
                   err instanceof OpenAI.APITimeoutError
      ? 'llm_timeout'
      : 'llm_error';
    console.error(`[analyze-mood] LLM 调用失败 (${reason}):`, err.message);
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ ok: false, source: 'fallback', reason, mood: null }),
    };
  }
};
