// 心弦 · LLM 情绪解析网关（OpenAI-compatible）
//
// 职责：接收前端 POST /api/analyze-mood，调用 LLM 解析心境文本，
// 返回标准化 MoodProfile JSON。任何异常都返回 fallback，绝不返回 502。
//
// 兼容性：支持任何 OpenAI-compatible API（OpenAI / DeepSeek / Moonshot / Together 等），
// 通过环境变量切换：
//   OPENAI_API_KEY    — 必填，API Key（不强制 sk- 前缀，兼容各家格式）
//   OPENAI_BASE_URL   — 可选，默认 https://api.openai.com/v1
//   OPENAI_MODEL      — 可选，默认 gpt-4o-mini（DeepSeek 用 deepseek-chat）
//
// 安全：API Key 只从环境变量读取，不硬编码，不打印，不返回给前端。
// 隐私：用户心境文本仅在本次请求中用于 LLM 调用，不存储、不记录到日志。
//
// 编码：所有响应统一 UTF-8，通过 jsonResponse() helper 返回。
// 容错：handler 外层有 try/catch 兜底，require 懒加载，绝不因内部异常返回 502。

// ─── OpenAI SDK 懒加载（避免顶层 require 失败导致整个 Function 崩溃）───
let _OpenAI = null;
function getOpenAI() {
  if (_OpenAI) return _OpenAI;
  try {
    _OpenAI = require('openai');
  } catch (err) {
    console.error('[analyze-mood] require("openai") 失败:', err.message);
    throw new Error('openai_module_unavailable');
  }
  return _OpenAI;
}

// ─── 统一响应 helper（确保所有响应都带 charset=utf-8）──────────
function jsonResponse(payload, statusCode = 200) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
    body: JSON.stringify(payload),
  };
}

function fallback(reason, extra) {
  const payload = {
    ok: false,
    source: 'fallback',
    reason: reason,
    mood: null,
  };
  if (extra && typeof extra === 'object') {
    Object.keys(extra).forEach(function (k) { payload[k] = extra[k]; });
  }
  return jsonResponse(payload);
}

// ─── System Prompt（强化版）─────────────────────────────────────
const SYSTEM_PROMPT = [
  '你是一个情绪解析助手。用户会输入一段中文心境描述，你需要严格根据原文内容分析其情绪状态，只输出一个 JSON 对象，不要输出任何 Markdown、解释、代码块标记或多余文字。',
  '',
  '输出 JSON 字段：',
  '- tags：3-5 个中文情绪标签（数组），如"焦虑""紧绷""思绪过载""失眠""压力"',
  '- valence：情绪效价，-1.0（极消极）到 1.0（极积极）',
  '- arousal：唤醒度，0.0（极平静）到 1.0（极激越）',
  '- intensity：情绪强度，0.0 到 1.0',
  '- targetState：期望调节目标，只能是以下之一：relax / sleep / focus / company / regulate',
  '- dominantNeed：主导需求（中文短句，不允许为 null），如"快速入眠""情绪降温""缓解焦虑"',
  '- summary：一句话情绪摘要（中文，15-30 字），用第二人称，如"你正承受较大压力，思绪难以停歇"',
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
  '3. 只有原文确实平淡、无情绪倾向时，才输出：valence=0.2, arousal=0.4, targetState=relax, tags=["平衡"], summary="状态相对平稳"',
  '4. 不使用医学术语，用"辅助放松""情绪调节""睡前舒缓""正念陪伴"等温和表述',
  '5. 不做医疗诊断，不判断疾病',
  '6. summary 用温和、共情的语气',
  '7. 输出必须是纯 JSON 对象，不要代码块标记，不要任何解释文字',
].join('\n');

// ─── 限流（内存计数器，同一实例存活期间有效）─────────────────
var RATE_LIMIT_PER_MIN = 10;
var _hits = new Map();

function isRateLimited(ip) {
  var now = Date.now();
  var arr = (_hits.get(ip) || []).filter(function (t) { return now - t < 60000; });
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
  var text = body.text;
  if (typeof text !== 'string' || text.length === 0) {
    return { ok: false, reason: 'invalid_input' };
  }
  if (text.length > 500) {
    return { ok: false, reason: 'invalid_input' };
  }
  return { ok: true, text: text };
}

// ─── 乱码检测 ──────────────────────────────────────────────────
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

// ─── 输出校验 + 规范化（严格版）────────────────────────────────
var VALID_TARGET_STATES = ['relax', 'sleep', 'focus', 'company', 'regulate'];

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

  // ── targetState 枚举校验 ──
  var ts = typeof raw.targetState === 'string' ? raw.targetState : '';
  var targetState = VALID_TARGET_STATES.indexOf(ts) !== -1 ? ts : 'relax';

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

// ─── LLM 配置 ─────────────────────────────────────────────────
function buildLlmConfig() {
  return {
    apiKey: process.env.OPENAI_API_KEY || '',
    baseURL: process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
    model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
  };
}

// ─── 安全判断超时错误（不依赖 instanceof，避免 SDK 导出不一致）──
function isTimeoutError(err) {
  if (!err) return false;
  var name = err.name || '';
  var msg = err.message || '';
  if (name === 'APIConnectionTimeoutError') return true;
  if (name === 'APITimeoutError') return true;
  if (/timeout/i.test(name)) return true;
  if (/timeout/i.test(msg)) return true;
  return false;
}

// ─── LLM 调用 ─────────────────────────────────────────────────
async function callLlm(config, userText) {
  var OpenAI = getOpenAI(); // 懒加载，失败抛异常由上层 catch
  var client = new OpenAI({
    apiKey: config.apiKey,
    baseURL: config.baseURL,
    timeout: 6000,
  });
  var resp = await client.chat.completions.create({
    model: config.model,
    response_format: { type: 'json_object' },
    temperature: 0.3,
    max_tokens: 300,
    messages: [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: userText },
    ],
  });
  var content = resp && resp.choices && resp.choices[0] && resp.choices[0].message && resp.choices[0].message.content;
  if (!content) throw new Error('LLM 返回空内容');
  return JSON.parse(content);
}

// ─── Netlify Function 入口 ────────────────────────────────────
// 整个 handler 体用 try/catch 兜底，任何未捕获异常都返回 fallback，绝不 502。
exports.handler = async function (event) {
  try {
    // 预检
    if (event.httpMethod === 'OPTIONS') {
      return {
        statusCode: 204,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        },
        body: '',
      };
    }
    if (event.httpMethod !== 'POST') {
      return fallback('method_not_allowed');
    }

    // 解析 body
    var body;
    try {
      body = JSON.parse(event.body || '{}');
    } catch (_) {
      return fallback('json_parse_failed');
    }

    // 输入校验
    var validation = validateInput(body);
    if (!validation.ok) {
      return fallback(validation.reason);
    }

    // 限流
    var ip = (event.headers && (event.headers['client-ip'] || event.headers['x-forwarded-for'])) || 'unknown';
    if (isRateLimited(ip)) {
      return fallback('rate_limited', { retryAfter: 60 });
    }

    // 构建 LLM 配置
    var config = buildLlmConfig();

    // API Key 检查
    if (!config.apiKey) {
      console.error('[analyze-mood] OPENAI_API_KEY 未配置');
      return fallback('no_api_key');
    }

    // 调用 LLM
    try {
      var rawMood = await callLlm(config, validation.text);
      var mood = normalizeMood(rawMood);
      if (!mood) {
        console.error('[analyze-mood] LLM 返回数据无法规范化（tags/summary 缺失或乱码）');
        return fallback('llm_output_invalid');
      }
      return jsonResponse({ ok: true, source: 'llm', mood: mood });
    } catch (err) {
      var reason = isTimeoutError(err) ? 'llm_timeout' : 'llm_error';
      console.error('[analyze-mood] LLM 调用失败 (' + reason + '):', err && err.message);
      return fallback(reason);
    }
  } catch (topErr) {
    // 最后防线：任何未预期的异常都返回 fallback，绝不 502
    console.error('[analyze-mood] handler 顶层异常:', topErr && topErr.message);
    return fallback('llm_error');
  }
};
