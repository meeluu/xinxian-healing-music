// 心弦 · 困惑解惑 + 歌词生成 LLM 网关（Cloudflare Pages Function）
//
// 职责：接收前端 POST /api/comfort-lyrics，调用 LLM 生成：
//   1. comfortInterpretation — 温和解惑文本（4 段：复述 / 重新框架 / 小行动 / 过渡到歌）
//   2. lyricDraft — 中文歌词草稿（画面感 + 重复 hook + 主歌/副歌/尾声）
//   3. songPrompt — 后续 AI 音乐生成的风格提示（英文，明确 vocal/mood/tempo/instrumentation）
//   4. safetyNotes — 安全检查备注
//
// 任何异常都返回 fallback，绝不返回 502，不让前端卡死。
//
// P4 新方向第二批（P4-comfort-lyrics-2）优化点：
// - SYSTEM_PROMPT 结构化：4 段解惑 + 歌词质量要求 + 场景识别 + songPrompt 明确要素
// - detectScene：本地场景识别（学业/关系/压力/愧疚/默认），用于 fallback
// - sanitizeText 扩展：新增「你必须/你应该/这说明你/你需要治疗/一定会好/命运安排/宇宙/上天/神明」等禁用词
// - localFallback 5 场景：每个场景有独立的 comfortInterpretation + lyricDraft + songPrompt
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
// 文案规范（第二批强化）：
// - 禁用医疗化：治疗 / 治愈 / 治疗焦虑 / 治疗失眠 / 治好你的焦虑 / 疗法 / 疗效
// - 禁用玄学：命中注定 / 天意 / 神的安排 / 算准 / 神谕 / 命运注定 / 命运安排 / 宇宙 / 上天 / 神明
// - 禁用空话：一切都会好的 / 加油 / 你是最棒的 / 会好起来的 / 一定会好
// - 禁用说教：你应该 / 你必须 / 你这样下去会 / 你需要 / 这说明你 / 你需要治疗
// - 推荐：听起来你正在 / 也许这件事最重的地方不是…而是… / 可以先把目标放小一点 / 这首歌不急着推你往前

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
    scene: 'default',
  };
  if (extra && typeof extra === 'object') {
    Object.keys(extra).forEach(function (k) { payload[k] = extra[k]; });
  }
  return jsonResponse(payload, 200, origin);
}

// ─── System Prompt（P4 新方向第二批：结构化 + 场景化）──────────────
// 严格避免医疗化 / 玄学化 / 说教 / 空话，要求 LLM 输出像温和陪伴者而不是心理咨询诊断。
const SYSTEM_PROMPT = [
  '你是一个温和的词作者陪伴者，不是心理咨询师，不是诊断医生。用户会输入一段中文困惑/事件/情绪描述，你需要完成两件事：',
  '1. 用温和的方式帮他「解惑」——像陪伴者一样帮他重新理解处境，不是给建议清单，不是分析报告',
  '2. 基于这段解惑，写一首中文歌词草稿，适合被唱出来，有画面感和重复 hook',
  '',
  '只输出一个 JSON 对象，不要输出任何 Markdown、解释、代码块标记或多余文字。',
  '',
  '──────── 输出 JSON 字段 ────────',
  '',
  '- scene：识别用户困惑的叙事场景类型，只能是以下五个之一：',
  '  · academic_failure（学业失败 / 挂科 / 考研受挫 / 高考失利 / 成绩焦虑）',
  '  · relationship_conflict（争吵 / 关系冲突 / 分手 / 冷战 / 亲情摩擦）',
  '  · work_pressure（工作压力 / 加班 / 项目崩溃 / 职场疲惫 / deadline）',
  '  · guilt_regret（愧疚 / 后悔 / 觉得自己错了 / 伤害了别人 / 没做到）',
  '  · default（不属于以上四类的孤独 / 迷茫 / 睡前焦虑 / 自我怀疑 / 低落）',
  '',
  '- comfortInterpretation：温和解惑文本（180-320 字，4 段）',
  '  · 第 1 段：复述处境，让用户感到「被听见」。用「听起来你正在……」开头，不要分析、不要总结',
  '  · 第 2 段：重新框架化痛苦，不否定痛苦，也不夸大。用「也许这件事最重的地方不是……而是……」开头',
  '  · 第 3 段：给一个很小的、今天就能做的行动，不强制、不空话。用「可以先把目标放小一点……」开头',
  '  · 第 4 段（结尾一句）：自然过渡到「这首歌想陪你……」，不要说教，不要承诺结果',
  '  · 不要写成「分析报告」「咨询诊断」「建议清单」',
  '  · 不要使用「你必须 / 你应该 / 这说明你 / 你需要治疗 / 一定会好 / 命运安排」',
  '',
  '- lyricDraft：中文歌词草稿（90-180 字，含「主歌」「副歌」「尾声」标记）',
  '  · 【主歌】：具体画面感，不要抽象。用夜色 / 桌面 / 消息 / 路灯 / 风 / 没说出口的话等具象意象',
  '  · 【副歌】：核心安慰 hook，可重复 1-2 句，便于被唱。例：「今晚先别赶路，让风替你轻轻说完」',
  '  · 【尾声】：留白，不强行升华，不强行打气。可以是一句很轻的独白',
  '  · 不要写成建议清单（不要每句都是「你要 / 你可以 / 你应该」）',
  '  · 不要鸡汤（不要「一切都会好的 / 加油 / 你是最棒的 / 会好起来的」）',
  '  · 不要过度抽象（不要「黑暗之后是光明 / 时间会治愈一切」）',
  '  · 不要出现「心弦 / 本产品 / AI」等元指涉',
  '  · 风格参考（不要照抄，学习语气）：',
  '    「我把没说完的话，放进慢慢亮起的窗」',
  '    「不是所有跌倒，都要马上给出答案」',
  '    「今晚先别赶路，让风替你轻轻说完」',
  '',
  '- songPrompt：后续 AI 音乐生成的风格提示（英文，30-60 字）',
  '  · 明确包含：vocal style / mood / tempo / instrumentation / arrangement',
  '  · 适合歌曲生成（含人声）而不是纯音乐',
  '  · 不包含用户原文隐私细节',
  '  · 不包含医疗化词汇（不要 heal/cure/treatment/therapy）',
  '  · 参考：「gentle mandarin ballad, warm vocal melody, soft piano and acoustic guitar, slow tempo, intimate and comforting mood, clean arrangement」',
  '',
  '- safetyNotes：安全检查备注（中文，10-30 字）',
  '  · 未检测到自伤/自杀线索：返回「未检测到风险线索」',
  '  · 检测到敏感词：返回「已过滤敏感表达」',
  '',
  '──────── 文案规范（必须严格遵守）────────',
  '1. 禁用医疗化：「治疗 / 治愈 / 治好你的焦虑 / 治疗失眠 / 疗法 / 疗效」',
  '2. 禁用玄学：「命中注定 / 天意 / 神的安排 / 算准 / 神谕 / 命运注定 / 命运安排 / 宇宙 / 上天 / 神明告诉你」',
  '3. 禁用空话：「一切都会好的 / 加油 / 你是最棒的 / 会好起来的 / 一定会好」',
  '4. 禁用说教：「你应该 / 你必须 / 你这样下去会 / 你需要 / 这说明你 / 你需要治疗」',
  '5. 推荐使用：「听起来你正在 / 也许这件事最重的地方不是…而是 / 可以先把目标放小一点 / 这首歌不急着推你往前，只先陪你站稳一点 / 想哭也没关系」',
  '6. 解惑用第二人称「你」，歌词可以用第一人称「我」或第二人称「你」',
  '7. 不做医疗诊断，不判断疾病',
  '8. 如果用户输入含自伤/自杀线索，safetyNotes 标注，解惑文本温和引导寻求专业帮助',
  '9. 输出必须是纯 JSON 对象，不要代码块标记，不要任何解释文字',
  '',
  '──────── 场景识别指引 ────────',
  '根据 storyText 自动选择叙事角度：',
  '- 学业场景：侧重「目标暂时没达到 ≠ 你这个人不行」，意象可用书本 / 走廊 / 模拟卷 / 录取通知',
  '- 关系场景：侧重「没说出口的话比争吵更重」，意象可用消息框 / 已读未回 / 关上的门 / 没接的电话',
  '- 工作场景：侧重「累不是因为你不够强」，意象可用桌面 / 屏幕光 / 末班车 / 没关的灯',
  '- 愧疚场景：侧重「做错了不等于你是错的」，意象可用没寄出的道歉 / 改不了的昨天 / 想拨没拨的电话',
  '- 默认场景：侧重「现在不需要找到答案」，意象可用夜色 / 风 / 没亮的窗 / 还没醒的城市',
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

// ─── 医疗化 / 玄学化 / 空话 / 说教 词汇检测（P4 第二批扩展）──────
// 用于过滤 LLM 输出中的禁用表达，检测到则替换为温和表达。
var MEDICAL_PATTERNS = [
  /治疗焦虑/g, /治疗失眠/g, /治好你的焦虑/g, /治好你的失眠/g,
  /治愈你的/g, /疗法/g, /疗效/g,
];
var MYSTIC_PATTERNS = [
  /命中注定/g, /天意/g, /神的安排/g, /算准/g, /神谕/g, /命运注定/g,
  /命运安排/g, /宇宙告诉你/g, /上天告诉你/g, /神明告诉你/g,
];
var EMPTY_TALK_PATTERNS = [
  /一切都会好的/g, /加油哦/g, /你是最棒的/g, /会好起来的/g, /一定会好/g,
];
// P4 第二批新增：禁用说教表达
var LECTURING_PATTERNS = [
  /你必须/g, /你应该/g, /你需要治疗/g, /这说明你/g,
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
  // 说教类词汇替换：把「你必须 / 你应该」替换为「可以试着」
  LECTURING_PATTERNS.forEach(function (p) {
    if (p.test(sanitized)) {
      sanitized = sanitized.replace(p, '可以试着');
      flagged = true;
    }
  });
  return { text: sanitized, flagged: flagged };
}

// ─── 场景识别（本地，用于 fallback）──────────────────────────────
// LLM 路径下 scene 由 LLM 自己判断；fallback 路径下用本地关键词匹配。
// 5 类：academic_failure / relationship_conflict / work_pressure / guilt_regret / default
export function detectScene(storyText) {
  if (typeof storyText !== 'string' || storyText.length === 0) return 'default';
  var lower = storyText.toLowerCase();
  // 学业/失败
  var academicKeywords = ['考试', '挂科', '成绩', '考研', '高考', '学业', '录取', '复习', '模拟卷', '落榜', '没考上', '挂了', '挂了科', '学分', '毕业论文', '答辩'];
  for (var i = 0; i < academicKeywords.length; i++) {
    if (storyText.indexOf(academicKeywords[i]) !== -1) return 'academic_failure';
  }
  // 关系/争吵
  var relationshipKeywords = ['吵架', '分手', '亲人', '父母', '妈妈', '爸爸', '朋友', '冷战', '关系', '男朋友', '女朋友', '对象', '伴侣', '恋人', '同事', '室友', '已读不回', '没回消息', '说了重话'];
  for (var j = 0; j < relationshipKeywords.length; j++) {
    if (storyText.indexOf(relationshipKeywords[j]) !== -1) return 'relationship_conflict';
  }
  // 工作压力
  var workKeywords = ['工作', '加班', '压力', '项目', 'deadline', '截止', '老板', '上司', '同事', 'kpi', '绩效', '996', '通勤', '任务', '开会'];
  for (var k = 0; k < workKeywords.length; k++) {
    if (lower.indexOf(workKeywords[k]) !== -1 || storyText.indexOf(workKeywords[k]) !== -1) return 'work_pressure';
  }
  // 愧疚/后悔
  var guiltKeywords = ['对不起', '后悔', '愧疚', '错了', '伤害', '辜负', '没能', '没做到', '我害了', '都是我的错', '自责', '内疚'];
  for (var m = 0; m < guiltKeywords.length; m++) {
    if (storyText.indexOf(guiltKeywords[m]) !== -1) return 'guilt_regret';
  }
  // 默认：孤独 / 迷茫 / 睡前焦虑 / 自我怀疑 / 低落
  return 'default';
}

// ─── 输出校验 + 规范化 ─────────────────────────────────────────
export function normalizeResult(raw) {
  if (!raw || typeof raw !== 'object') return null;

  var comfortInterpretation = raw.comfortInterpretation;
  if (typeof comfortInterpretation !== 'string' || comfortInterpretation.length === 0) return null;
  if (looksGarbled(comfortInterpretation)) return null;
  if (!hasChinese(comfortInterpretation)) return null;
  // 医疗化/玄学化/说教过滤
  var comfortSanitized = sanitizeText(comfortInterpretation);
  comfortInterpretation = comfortSanitized.text.slice(0, 1000);

  var lyricDraft = raw.lyricDraft;
  if (typeof lyricDraft !== 'string' || lyricDraft.length === 0) return null;
  if (looksGarbled(lyricDraft)) return null;
  if (!hasChinese(lyricDraft)) return null;
  var lyricSanitized = sanitizeText(lyricDraft);
  lyricDraft = lyricSanitized.text.slice(0, 800);

  var songPrompt = raw.songPrompt;
  if (typeof songPrompt !== 'string' || songPrompt.length === 0) {
    songPrompt = 'gentle mandarin ballad, warm vocal melody, soft piano and acoustic guitar, slow tempo, intimate and comforting mood, clean arrangement';
  } else {
    songPrompt = songPrompt.slice(0, 200);
  }

  var safetyNotes = raw.safetyNotes;
  if (typeof safetyNotes !== 'string' || safetyNotes.length === 0) {
    safetyNotes = '未检测到风险线索';
  } else {
    safetyNotes = safetyNotes.slice(0, 80);
  }

  // scene 校验：必须是 5 类之一
  var validScenes = ['academic_failure', 'relationship_conflict', 'work_pressure', 'guilt_regret', 'default'];
  var scene = raw.scene;
  if (typeof scene !== 'string' || validScenes.indexOf(scene) === -1) {
    scene = 'default';
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
    scene: scene,
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
        temperature: 0.75,
        max_tokens: 1000,
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

// ─── 本地 fallback（LLM 失败时使用，P4 第二批：5 场景）──────────
// 不依赖 LLM，根据 detectScene 选择对应的温和解惑 + 歌词草稿。
// 每个 scene 都有独立的 comfortInterpretation + lyricDraft，避免模板味太重。
export function localFallback(storyText, targetStyle) {
  var scene = detectScene(storyText);
  var tpl = FALLBACK_TEMPLATES[scene] || FALLBACK_TEMPLATES.default;
  return {
    comfortInterpretation: tpl.comfortInterpretation,
    lyricDraft: tpl.lyricDraft,
    songPrompt: tpl.songPrompt,
    safetyNotes: 'fallback_mode（' + scene + '，LLM 不可用，使用本地场景模板）',
    scene: scene,
  };
}

// ─── 5 场景 fallback 模板 ────────────────────────────────────────
// 每个 scene 的 comfortInterpretation 严格按 4 段结构（复述 / 重新框架 / 小行动 / 过渡到歌）。
// lyricDraft 含「主歌」「副歌」「尾声」+ 具象画面 + 重复 hook。
// songPrompt 为英文，明确 vocal / mood / tempo / instrumentation。
var FALLBACK_TEMPLATES = {
  // 学业失败 / 挂科
  academic_failure: {
    comfortInterpretation: [
      '听起来你正在为一场没考好的试、或者一个没达到的学业目标难过。那种感觉不只是「失分」，更像突然不太确定自己之前那些努力去了哪里。',
      '也许这件事最重的地方不是分数本身，而是你把它当成了对自己整个人的评价。一张卷子没办法替你下结论，你也从来没被一次考试完整定义过。',
      '可以先把目标放小一点。今晚不要去想下学期怎么补、要不要重修，先把今天没吃完的饭吃完，把没睡够的觉补一段。',
      '这首歌不急着推你往前，只先陪你站稳一点。',
    ].join('\n\n'),
    lyricDraft: [
      '【主歌】',
      '走廊的灯还没关',
      '模拟卷摊在桌上没人收',
      '你写错的那一题',
      '其实不重要，重要的是你太累了',
      '',
      '【副歌】',
      '不是所有跌倒，都要马上给出答案',
      '今晚先别赶路，让风替你轻轻说完',
      '不是所有跌倒，都要马上给出答案',
      '错的不是你这个人，是这一次的卷面',
      '',
      '【尾声】',
      '明天的复习计划，明天再写。',
    ].join('\n'),
    songPrompt: 'gentle mandarin ballad, warm vocal melody, soft piano and acoustic guitar, slow tempo, intimate and comforting mood, clean arrangement',
  },
  // 关系冲突 / 争吵
  relationship_conflict: {
    comfortInterpretation: [
      '听起来你正在一段关系里难过。可能是一次争吵，也可能是没说出口的话堵在胸口，让你一边生气一边又觉得委屈。',
      '也许这件事最重的地方不是谁对谁错，而是你们之间有些东西还没被听懂。吵出来的话往往是冰山一角，水面下藏着没说出口的在乎。',
      '可以先把目标放小一点。今晚不用逼自己立刻原谅谁、或者想清楚怎么说。可以先给自己倒一杯水，把那条没发出去的消息先存草稿。',
      '这首歌不急着推你往前，只先陪你站稳一点。',
    ].join('\n\n'),
    lyricDraft: [
      '【主歌】',
      '消息框亮了又暗',
      '已读两个字比沉默更难',
      '你关上门，又回头看了一眼',
      '其实你不是想赢，是想被听见',
      '',
      '【副歌】',
      '我把没说完的话，放进慢慢亮起的窗',
      '今晚先别赶路，让风替你轻轻说完',
      '我把没说完的话，放进慢慢亮起的窗',
      '不是不爱你，是先让自己喘一段',
      '',
      '【尾声】',
      '那条没发的消息，今晚先不发。',
    ].join('\n'),
    songPrompt: 'gentle mandarin ballad, breathy vocal, fingerstyle guitar and soft pads, slow tempo, bittersweet and tender mood, minimal arrangement',
  },
  // 工作压力 / 疲惫
  work_pressure: {
    comfortInterpretation: [
      '听起来你正在被一件事压着，可能是项目，可能是 deadline，可能是加班太久之后的那种钝钝的累。你说不清哪里最难受，但全身都在说「停一下」。',
      '也许这件事最重的地方不是任务本身，而是你把「我必须撑住」当成了唯一选项。累不是因为你不够强，是因为你撑得太久没让自己歇。',
      '可以先把目标放小一点。今晚不用把所有未读邮件清完，不用把明天的会议预演第三遍。可以先把屏幕调暗一格，把手机放远一点。',
      '这首歌不急着推你往前，只先陪你站稳一点。',
    ].join('\n\n'),
    lyricDraft: [
      '【主歌】',
      '屏幕的光映在你脸上',
      '末班车开走了你也没看',
      '桌面上的杯子早就凉了',
      '你还在等一个不会来的「现在可以走了」',
      '',
      '【副歌】',
      '今晚先别赶路，让风替你轻轻说完',
      '累不是因为你不够强，是你撑得太长',
      '今晚先别赶路，让风替你轻轻说完',
      '不是所有事，都要今晚做完',
      '',
      '【尾声】',
      '明天的事，明天再认得它。',
    ].join('\n'),
    songPrompt: 'warm mandarin ballad, soft male or female vocal, gentle piano with subtle synth pads, slow tempo, late night comforting mood, spacious arrangement',
  },
  // 愧疚 / 后悔
  guilt_regret: {
    comfortInterpretation: [
      '听起来你正在为一件已经过去的事责怪自己。可能是说错的话、没做到的承诺、或者一个你以为可以做得更好的选择。愧疚一直绕着你转，不肯走。',
      '也许这件事最重的地方不是「我错了」，而是「我在乎」。会愧疚，恰恰说明你对那个人、那件事有过真心。做错了不等于你是错的。',
      '可以先把目标放小一点。今晚不用逼自己立刻原谅自己，也不用现在就去找对方道歉。可以先承认「我那时候没做好」，然后允许自己停在这里一会儿。',
      '这首歌不急着推你往前，只先陪你站稳一点。',
    ].join('\n\n'),
    lyricDraft: [
      '【主歌】',
      '昨天那句话又回来了',
      '想拨的电话停在拨号界面',
      '你没寄出的道歉',
      '和没改掉的昨天并排躺着',
      '',
      '【副歌】',
      '不是所有跌倒，都要马上给出答案',
      '做错了不等于你是错的，只是这一次没做好',
      '不是所有跌倒，都要马上给出答案',
      '今晚先别赶路，让风替你轻轻说完',
      '',
      '【尾声】',
      '想道歉的人，明天再练习开口。',
    ].join('\n'),
    songPrompt: 'gentle mandarin ballad, soft intimate vocal, acoustic guitar and warm piano, slow tempo, reflective and forgiving mood, sparse arrangement',
  },
  // 默认：孤独 / 迷茫 / 睡前焦虑 / 自我怀疑 / 低落
  default: {
    comfortInterpretation: [
      '听起来你正在一段说不太清楚的状态里。没有具体的事，但就是有点沉、有点空、有点停不下来地想这想那。这种说不清的低落，本身就已经够重了。',
      '也许这件事最重的地方不是「我哪里不对」，而是「我现在确实需要停一下」。不是所有不舒服都需要立刻被解释清楚，有些时候只是累了，不是错了。',
      '可以先把目标放小一点。今晚不用想清楚人生方向，不用复盘今天每一句话。可以先关掉一盏灯，把窗户打开一条缝，让外面的声音替你想一会儿。',
      '这首歌不急着推你往前，只先陪你站稳一点。',
    ].join('\n\n'),
    lyricDraft: [
      '【主歌】',
      '夜色慢慢盖下来',
      '没亮的窗和还没醒的城市',
      '你坐在那里没说话',
      '风把心事吹得有些远',
      '',
      '【副歌】',
      '想哭也没关系，我在听',
      '今晚先别赶路，让风替你轻轻说完',
      '想哭也没关系，我在听',
      '不用急着好起来，这首歌想陪你看见自己',
      '',
      '【尾声】',
      '天快亮了，你不用一个人。',
    ].join('\n'),
    songPrompt: 'gentle mandarin ballad, soft breathy vocal, fingerstyle guitar and warm pads, slow tempo, late night intimate mood, clean arrangement',
  },
};

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
        scene: fb.scene,
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
        scene: fb.scene,
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
          scene: fb.scene,
        }, 200, origin);
      }
      return jsonResponse({
        ok: true,
        source: 'llm',
        comfortInterpretation: result.comfortInterpretation,
        lyricDraft: result.lyricDraft,
        songPrompt: result.songPrompt,
        safetyNotes: result.safetyNotes,
        scene: result.scene,
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
        scene: fb.scene,
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
