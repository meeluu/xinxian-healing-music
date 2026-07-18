// 心弦 · 困惑解惑 + 歌词生成 LLM 网关（Cloudflare Pages Function）
//
// 职责：接收前端 POST /api/comfort-lyrics，调用 LLM 生成：
//   1. comfortInterpretation — 温和解惑文本（复述 + 重新框架 + 小行动）
//   2. lyricDraft — 中文歌词草稿（主歌/副歌结构，适合被唱）
//   3. songPrompt — 后续 AI 音乐生成的风格提示（不含用户隐私）
//   4. safetyNotes — 安全检查备注
//
// 任何异常都返回 fallback，绝不返回 502，不让前端卡死。
//
// 兼容性：复用 analyze-mood.js 的 OpenAI-compatible LLM 配置：
//   OPENAI_API_KEY    — 必填
//   OPENAI_BASE_URL   — 可选，默认 https://api.openai.com/v1
//   OPENAI_MODEL      — 可选，默认 gpt-4o-mini
//   ENABLE_LLM        — 可选，设为 'false' 时禁用 LLM 走 fallback
//
// 安全：API Key 只从 context.env 读取，不硬编码，不打印，不返回给前端。
// 隐私：用户 storyText 仅在本次请求中用于 LLM 调用，不存储、不记录到日志。
//
// 文案规范：
// - 禁用医疗化：治疗 / 治愈 / 治疗焦虑 / 治疗失眠 / 治好你的焦虑
// - 禁用玄学：命中注定 / 天意 / 神的安排 / 算准 / 神谕 / 命运注定
// - 禁用空话：一切都会好的 / 加油 / 你是最棒的
// - 禁用说教：你应该 / 你必须 / 你这样下去会
// - 使用：也许 / 可以试着 / 听起来你 / 这首歌想陪你看见

// ─── CORS 白名单（与 analyze-mood.js 一致）─────────────────────
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

function fallback(reason, origin, extra) {
  const payload = {
    ok: false,
    source: 'fallback',
    reason: reason,
    comfortInterpretation: '',
    lyricDraft: '',
    songPrompt: '',
    safetyNotes: 'fallback_mode',
  };
  if (extra && typeof extra === 'object') {
    Object.keys(extra).forEach(function (k) { payload[k] = extra[k]; });
  }
  return jsonResponse(payload, 200, origin);
}

// ─── System Prompt（困惑解惑 + 歌词生成）────────────────────────
// 严格避免医疗化 / 玄学化 / 说教 / 空话，使用温和推测 + 具象共情 + 微小行动。
const SYSTEM_PROMPT = [
  '你是一个温和的心理陪伴者，同时也是一位词作者。用户会输入一段中文困惑/事件/情绪描述，你需要完成两件事：',
  '1. 用温和的方式帮他「解惑」——不是给建议清单，而是像陪伴者一样重新框架他的处境',
  '2. 基于这段解惑，写一首中文歌词草稿，适合被唱出来',
  '',
  '只输出一个 JSON 对象，不要输出任何 Markdown、解释、代码块标记或多余文字。',
  '',
  '输出 JSON 字段：',
  '- comfortInterpretation：温和解惑文本（150-300 字，2-4 段）',
  '  · 第 1 段：复述用户处境的核心，让他感到被听见（用"听起来你…"开头）',
  '  · 第 2 段：给出非评判性理解，帮他重新解释处境（用"也许…"开头）',
  '  · 第 3 段：指向一个小的可执行行动，不强制、不空话（用"可以试着…"开头）',
  '  · 不要承诺治疗，不要说教，不要使用"你应该/你必须"',
  '- lyricDraft：中文歌词草稿（80-150 字，含「主歌」「副歌」「尾声」标记）',
  '  · 主歌：具象化用户处境（1-2 个具体意象）',
  '  · 副歌：承认情绪 + 给一个微小的行动意象',
  '  · 尾声：留白，不强行升华',
  '  · 不要像建议清单，要像一首歌',
  '  · 不要出现"心弦/本产品/AI"等元指涉',
  '- songPrompt：后续 AI 音乐生成的风格提示（英文，20-40 字）',
  '  · 简短描述曲风、情绪、速度、乐器',
  '  · 不包含用户原文隐私细节',
  '  · 不包含医疗化词汇（不要 heal/cure/treatment/therapy）',
  '- safetyNotes：安全检查备注（中文，10-30 字）',
  '  · 如果未检测到自伤/自杀线索，返回"未检测到风险线索"',
  '  · 如果检测到敏感词，返回"已过滤敏感表达"',
  '',
  '文案规范（必须严格遵守）：',
  '1. 禁用医疗化表达：不要使用「治疗/治愈/治好你的焦虑/治疗失眠/疗法」',
  '2. 禁用玄学表达：不要使用「命中注定/天意/神的安排/算准/神谕/命运注定」',
  '3. 禁用空话：不要使用「一切都会好的/加油/你是最棒的/会好起来的」',
  '4. 禁用说教：不要使用「你应该/你必须/你这样下去会/你需要」',
  '5. 鼓励使用：也许/可以试着/听起来你/这首歌想陪你看见/想哭也没关系',
  '6. 解惑文本用第二人称「你」，歌词可以用第一人称「我」或第二人称「你」',
  '7. 不做医疗诊断，不判断疾病',
  '8. 如果用户输入含自伤/自杀线索，safetyNotes 标注，解惑文本温和引导寻求专业帮助',
  '9. 输出必须是纯 JSON 对象，不要代码块标记，不要任何解释文字',
].join('\n');

// ─── 输入校验 ──────────────────────────────────────────────────
// 导出供验证脚本（scripts/verify-comfort-lyrics.mjs）直接测试，
// 不影响 Cloudflare Pages Functions 运行时（只识别 onRequest* 命名导出）。
export function validateInput(body) {
  if (!body || typeof body !== 'object') {
    return { ok: false, reason: 'invalid_input' };
  }
  var storyText = body.storyText;
  if (typeof storyText !== 'string' || storyText.trim().length === 0) {
    return { ok: false, reason: 'invalid_input' };
  }
  if (storyText.length > 1000) {
    return { ok: false, reason: 'input_too_long' };
  }
  var sessionId = body.sessionId;
  if (typeof sessionId !== 'string' || sessionId.length === 0) {
    sessionId = '';
  }
  var targetStyle = body.targetStyle;
  var validStyles = ['gentle_pop', 'ambient_ballad', 'acoustic_warm', 'soft_piano'];
  if (typeof targetStyle !== 'string' || validStyles.indexOf(targetStyle) === -1) {
    targetStyle = 'gentle_pop';
  }
  var language = body.language;
  if (typeof language !== 'string' || language.length === 0) {
    language = 'zh-CN';
  }
  return {
    ok: true,
    storyText: storyText,
    sessionId: sessionId,
    targetStyle: targetStyle,
    language: language,
  };
}

// ─── 乱码检测（与 analyze-mood.js 一致）─────────────────────────
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

// ─── 医疗化 / 玄学化词汇检测 ───────────────────────────────────
// 用于过滤 LLM 输出中的禁用表达，检测到则替换为温和表达。
var MEDICAL_PATTERNS = [
  /治疗焦虑/g, /治疗失眠/g, /治好你的焦虑/g, /治好你的失眠/g,
  /治愈你的/g, /疗法/g, /疗效/g,
];
var MYSTIC_PATTERNS = [
  /命中注定/g, /天意/g, /神的安排/g, /算准/g, /神谕/g, /命运注定/g,
];
var EMPTY_TALK_PATTERNS = [
  /一切都会好的/g, /加油哦/g, /你是最棒的/g, /会好起来的/g,
];

export function sanitizeText(text) {
  if (typeof text !== 'string') return text;
  var sanitized = text;
  var flagged = false;
  MEDICAL_PATTERNS.forEach(function (p) {
    if (p.test(sanitized)) {
      sanitized = sanitized.replace(p, '辅助舒缓');
      flagged = true;
    }
  });
  MYSTIC_PATTERNS.forEach(function (p) {
    if (p.test(sanitized)) {
      sanitized = sanitized.replace(p, '也许');
      flagged = true;
    }
  });
  EMPTY_TALK_PATTERNS.forEach(function (p) {
    if (p.test(sanitized)) {
      sanitized = sanitized.replace(p, '可以试着');
      flagged = true;
    }
  });
  return { text: sanitized, flagged: flagged };
}

// ─── 输出校验 + 规范化 ─────────────────────────────────────────
export function normalizeResult(raw) {
  if (!raw || typeof raw !== 'object') return null;

  var comfortInterpretation = raw.comfortInterpretation;
  if (typeof comfortInterpretation !== 'string' || comfortInterpretation.length === 0) return null;
  if (looksGarbled(comfortInterpretation)) return null;
  if (!hasChinese(comfortInterpretation)) return null;
  // 医疗化/玄学化过滤
  var comfortSanitized = sanitizeText(comfortInterpretation);
  comfortInterpretation = comfortSanitized.text.slice(0, 800);

  var lyricDraft = raw.lyricDraft;
  if (typeof lyricDraft !== 'string' || lyricDraft.length === 0) return null;
  if (looksGarbled(lyricDraft)) return null;
  if (!hasChinese(lyricDraft)) return null;
  var lyricSanitized = sanitizeText(lyricDraft);
  lyricDraft = lyricSanitized.text.slice(0, 600);

  var songPrompt = raw.songPrompt;
  if (typeof songPrompt !== 'string' || songPrompt.length === 0) {
    songPrompt = 'gentle acoustic, slow tempo, warm mood, no vocals';
  } else {
    songPrompt = songPrompt.slice(0, 120);
  }

  var safetyNotes = raw.safetyNotes;
  if (typeof safetyNotes !== 'string' || safetyNotes.length === 0) {
    safetyNotes = '未检测到风险线索';
  } else {
    safetyNotes = safetyNotes.slice(0, 80);
  }

  // 如果检测到医疗化/玄学化词汇被过滤，在 safetyNotes 标注
  if (comfortSanitized.flagged || lyricSanitized.flagged) {
    safetyNotes = '已过滤敏感表达（' + safetyNotes + '）';
  }

  return {
    comfortInterpretation: comfortInterpretation,
    lyricDraft: lyricDraft,
    songPrompt: songPrompt,
    safetyNotes: safetyNotes,
  };
}

// ─── LLM 配置 ──────────────────────────────────────────────────
function buildLlmConfig(env) {
  return {
    apiKey: env.OPENAI_API_KEY || '',
    baseURL: env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
    model: env.OPENAI_MODEL || 'gpt-4o-mini',
  };
}

// ─── 超时判断 ──────────────────────────────────────────────────
function isTimeoutError(err) {
  if (!err) return false;
  var name = err.name || '';
  var msg = err.message || '';
  if (name === 'AbortError') return true;
  if (/timeout/i.test(name)) return true;
  if (/timeout/i.test(msg)) return true;
  if (/abort/i.test(msg)) return true;
  return false;
}

// ─── LLM 调用（原生 fetch + AbortController 超时）────────────────
// 解惑 + 歌词生成需要更长超时（比 analyze-mood 的 8s 更长）
async function callLlm(config, userText, targetStyle) {
  const controller = new AbortController();
  const timeoutId = setTimeout(function () { controller.abort(); }, 15000);
  try {
    var userContent = '用户困惑：' + userText + '\n（期望曲风：' + targetStyle + '）';
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
          { role: 'user', content: userContent },
        ],
        temperature: 0.7,
        max_tokens: 800,
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

// ─── 本地 fallback（LLM 失败时使用）──────────────────────────────
// 不依赖 LLM，返回通用的温和解惑 + 歌词草稿。
export function localFallback(storyText, targetStyle) {
  // 根据用户输入长度选择不同的 fallback 文案
  var comfortInterpretation = [
    '听起来你最近承受了一些不容易的事，谢谢你愿意把它说出来。',
    '也许现在的你不需要立刻找到答案，也不需要把所有事都理清楚。先允许自己停一下，就停在这里。',
    '可以试着给自己倒一杯水，或者把窗户打开透透气。很小的一步，就够了。',
  ].join('\n\n');

  var lyricDraft = [
    '【主歌】',
    '你站在夜色里没说话',
    '风把心事吹得有些远',
    '想哭也没关系，我在听',
    '',
    '【副歌】',
    '也许明天先把杯子洗干净',
    '也许今晚试着把手机放远一点',
    '不用急着好起来',
    '这首歌想陪你看见自己',
    '',
    '【尾声】',
    '天快亮了，你不用一个人。',
  ].join('\n');

  var songPromptMap = {
    gentle_pop: 'gentle pop, acoustic guitar, slow tempo, warm mood, no vocals',
    ambient_ballad: 'ambient ballad, soft pads, slow tempo, calming, no vocals',
    acoustic_warm: 'warm acoustic, fingerstyle guitar, slow tempo, comforting, no vocals',
    soft_piano: 'soft piano, gentle melody, slow tempo, peaceful, no vocals',
  };

  return {
    comfortInterpretation: comfortInterpretation,
    lyricDraft: lyricDraft,
    songPrompt: songPromptMap[targetStyle] || songPromptMap.gentle_pop,
    safetyNotes: 'fallback_mode（LLM 不可用，使用本地模板）',
  };
}

// ─── Cloudflare Pages Function 入口 ───────────────────────────
export async function onRequestPost(context) {
  const { request, env } = context;
  const origin = request.headers.get('Origin');
  try {
    // 解析 body
    let body;
    try {
      body = await request.json();
    } catch (_) {
      return fallback('json_parse_failed', origin);
    }

    // 输入校验
    const validation = validateInput(body);
    if (!validation.ok) {
      return fallback(validation.reason, origin);
    }

    // LLM 功能开关
    if (env.ENABLE_LLM === 'false') {
      const fb = localFallback(validation.storyText, validation.targetStyle);
      return jsonResponse({
        ok: false,
        source: 'fallback',
        reason: 'llm_disabled',
        comfortInterpretation: fb.comfortInterpretation,
        lyricDraft: fb.lyricDraft,
        songPrompt: fb.songPrompt,
        safetyNotes: fb.safetyNotes,
      }, 200, origin);
    }

    // 构建 LLM 配置
    const config = buildLlmConfig(env);

    // API Key 检查
    if (!config.apiKey) {
      console.error('[comfort-lyrics] OPENAI_API_KEY 未配置');
      const fb = localFallback(validation.storyText, validation.targetStyle);
      return jsonResponse({
        ok: false,
        source: 'fallback',
        reason: 'no_api_key',
        comfortInterpretation: fb.comfortInterpretation,
        lyricDraft: fb.lyricDraft,
        songPrompt: fb.songPrompt,
        safetyNotes: fb.safetyNotes,
      }, 200, origin);
    }

    // 调用 LLM
    try {
      const rawResult = await callLlm(config, validation.storyText, validation.targetStyle);
      const result = normalizeResult(rawResult);
      if (!result) {
        console.error('[comfort-lyrics] LLM 返回数据无法规范化');
        const fb = localFallback(validation.storyText, validation.targetStyle);
        return jsonResponse({
          ok: false,
          source: 'fallback',
          reason: 'llm_output_invalid',
          comfortInterpretation: fb.comfortInterpretation,
          lyricDraft: fb.lyricDraft,
          songPrompt: fb.songPrompt,
          safetyNotes: fb.safetyNotes,
        }, 200, origin);
      }
      return jsonResponse({
        ok: true,
        source: 'llm',
        comfortInterpretation: result.comfortInterpretation,
        lyricDraft: result.lyricDraft,
        songPrompt: result.songPrompt,
        safetyNotes: result.safetyNotes,
      }, 200, origin);
    } catch (err) {
      const reason = isTimeoutError(err) ? 'llm_timeout' : 'llm_error';
      console.error('[comfort-lyrics] LLM 调用失败 (' + reason + '):', err && err.message);
      const fb = localFallback(validation.storyText, validation.targetStyle);
      return jsonResponse({
        ok: false,
        source: 'fallback',
        reason: reason,
        comfortInterpretation: fb.comfortInterpretation,
        lyricDraft: fb.lyricDraft,
        songPrompt: fb.songPrompt,
        safetyNotes: fb.safetyNotes,
      }, 200, origin);
    }
  } catch (topErr) {
    console.error('[comfort-lyrics] handler 顶层异常:', topErr && topErr.message);
    return fallback('llm_error', origin);
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
