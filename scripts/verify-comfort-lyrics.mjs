// 心弦 · 困惑解惑 + 歌词生成 API 验证脚本（P4 新方向第一批 / 第二批 / fix1）
//
// 用途：验证 functions/api/comfort-lyrics.js 的核心逻辑：
//   - validateInput：输入校验（含 fix1 mode 参数）
//   - sanitizeText：医疗化/玄学化/空话/说教 词汇过滤
//   - detectScene：本地场景识别（5 类）
//   - normalizeResult：LLM 输出校验 + 规范化
//   - localFallback：本地 fallback 文案（5 场景独立模板）
//   - classifyConcern：fix1 追问兜底 6 分类（lowEnergy/eventConflict/anxietyStress/guiltRegret/loneliness/unknown）
//   - localFollowUpFallback：fix1 追问本地兜底问题库
//   - normalizeFollowUpQuestions：fix1 追问 LLM 输出规范化
//
// 不依赖 Cloudflare 运行时，可在 Node.js 18+ 直接运行。
// 不真实调用 LLM API，避免产生费用。
//
// 运行方式：
//   node scripts/verify-comfort-lyrics.mjs
//
// 验证内容（P4 第二批 35 项 + fix1 22 项 = 57 项）：

import assert from 'assert';
import {
  validateInput,
  sanitizeText,
  detectScene,
  normalizeResult,
  localFallback,
  classifyConcern,
  localFollowUpFallback,
  normalizeFollowUpQuestions,
} from '../functions/api/comfort-lyrics.js';

var passed = 0;
var failed = 0;

async function test(name, fn) {
  try {
    await fn();
    passed++;
    console.log('  ✅ ' + name);
  } catch (err) {
    failed++;
    console.log('  ❌ ' + name);
    console.log('     ' + (err && err.message ? err.message : err));
  }
}

console.log('\n🔍 Comfort-Lyrics API 验证（P4 第二批 + fix1）\n');

// ─── validateInput ──────────────────────────────────────────
console.log('─ validateInput ─');

await test('1. 非 object → invalid_input', () => {
  assert.strictEqual(validateInput(null).ok, false);
  assert.strictEqual(validateInput(null).reason, 'invalid_input');
  assert.strictEqual(validateInput('string').ok, false);
  assert.strictEqual(validateInput(123).ok, false);
});

await test('2. storyText 缺失 → invalid_input', () => {
  assert.strictEqual(validateInput({}).ok, false);
  assert.strictEqual(validateInput({ sessionId: 'x' }).ok, false);
});

await test('3. storyText 空串 → invalid_input', () => {
  assert.strictEqual(validateInput({ storyText: '' }).ok, false);
});

await test('4. storyText 仅空白 → invalid_input', () => {
  assert.strictEqual(validateInput({ storyText: '   \n\t  ' }).ok, false);
});

await test('5. storyText 超过 1000 字 → input_too_long', () => {
  var long = 'a'.repeat(1001);
  var r = validateInput({ storyText: long });
  assert.strictEqual(r.ok, false);
  assert.strictEqual(r.reason, 'input_too_long');
});

await test('6. 正常输入 → ok:true + 透传字段', () => {
  var r = validateInput({ storyText: '最近工作压力大' });
  assert.strictEqual(r.ok, true);
  assert.strictEqual(r.storyText, '最近工作压力大');
});

await test('7. sessionId 缺失 → 默认空串', () => {
  var r = validateInput({ storyText: 'x' });
  assert.strictEqual(r.ok, true);
  assert.strictEqual(r.sessionId, '');
});

await test('8. targetStyle 非法 → 默认 gentle_pop', () => {
  var r = validateInput({ storyText: 'x', targetStyle: 'rock' });
  assert.strictEqual(r.targetStyle, 'gentle_pop');
  // 合法值透传
  var r2 = validateInput({ storyText: 'x', targetStyle: 'soft_piano' });
  assert.strictEqual(r2.targetStyle, 'soft_piano');
});

await test('9. language 缺失 → 默认 zh-CN', () => {
  var r = validateInput({ storyText: 'x' });
  assert.strictEqual(r.language, 'zh-CN');
});

// ─── sanitizeText（P4 第二批扩展：新增说教类）──────────────
console.log('─ sanitizeText ─');

await test('10. 检测「治疗焦虑」 → 替换为「辅助舒缓」+ flagged=true', () => {
  var r = sanitizeText('这首歌能治疗焦虑，让你平静。');
  assert.strictEqual(r.flagged, true);
  assert.strictEqual(r.text.includes('治疗焦虑'), false);
  assert.strictEqual(r.text.includes('辅助舒缓'), true);
});

await test('11. 检测「命中注定」 → 替换为「也许」+ flagged=true', () => {
  var r = sanitizeText('这是命中注定的安排。');
  assert.strictEqual(r.flagged, true);
  assert.strictEqual(r.text.includes('命中注定'), false);
  assert.strictEqual(r.text.includes('也许'), true);
});

await test('12. 检测「一切都会好的」 → 替换为「可以试着」+ flagged=true', () => {
  var r = sanitizeText('别担心，一切都会好的。');
  assert.strictEqual(r.flagged, true);
  assert.strictEqual(r.text.includes('一切都会好的'), false);
  assert.strictEqual(r.text.includes('可以试着'), true);
});

await test('13. 检测「你必须」 → 替换为「可以试着」+ flagged=true（P4 第二批新增）', () => {
  var r = sanitizeText('你必须立刻振作起来。');
  assert.strictEqual(r.flagged, true);
  assert.strictEqual(r.text.includes('你必须'), false);
  assert.strictEqual(r.text.includes('可以试着'), true);
});

await test('14. 检测「你应该」 → 替换为「可以试着」+ flagged=true（P4 第二批新增）', () => {
  var r = sanitizeText('你应该学会放下。');
  assert.strictEqual(r.flagged, true);
  assert.strictEqual(r.text.includes('你应该'), false);
  assert.strictEqual(r.text.includes('可以试着'), true);
});

await test('15. 检测「这说明你」 → 替换为「可以试着」+ flagged=true（P4 第二批新增）', () => {
  var r = sanitizeText('这说明你根本不在意。');
  assert.strictEqual(r.flagged, true);
  assert.strictEqual(r.text.includes('这说明你'), false);
  assert.strictEqual(r.text.includes('可以试着'), true);
});

await test('16. 检测「你需要治疗」 → 替换为「可以试着」+ flagged=true（P4 第二批新增）', () => {
  // 注意：不含「焦虑/失眠」，避免被 MEDICAL_PATTERNS 先替换导致「你需要治疗」无法匹配
  var r = sanitizeText('你需要治疗，请尽快就医。');
  assert.strictEqual(r.flagged, true);
  assert.strictEqual(r.text.includes('你需要治疗'), false);
  assert.strictEqual(r.text.includes('可以试着'), true);
});

await test('17. 正常文本 → 不替换 + flagged=false', () => {
  var original = '听起来你最近不容易，可以试着给自己倒杯水。';
  var r = sanitizeText(original);
  assert.strictEqual(r.flagged, false);
  assert.strictEqual(r.text, original);
});

await test('18. 非字符串 → 原样返回', () => {
  assert.strictEqual(sanitizeText(null), null);
  assert.strictEqual(sanitizeText(undefined), undefined);
  assert.strictEqual(sanitizeText(123), 123);
});

// ─── detectScene（P4 第二批新增）─────────────────────────────
console.log('─ detectScene ─');

await test('19. 学业关键词 → academic_failure', () => {
  assert.strictEqual(detectScene('我考试挂科了'), 'academic_failure');
  assert.strictEqual(detectScene('考研没考上'), 'academic_failure');
  assert.strictEqual(detectScene('毕业论文答辩没过'), 'academic_failure');
  assert.strictEqual(detectScene('高考落榜'), 'academic_failure');
});

await test('20. 关系关键词 → relationship_conflict', () => {
  assert.strictEqual(detectScene('和妈妈吵架了'), 'relationship_conflict');
  assert.strictEqual(detectScene('男朋友要分手'), 'relationship_conflict');
  assert.strictEqual(detectScene('朋友已读不回'), 'relationship_conflict');
  assert.strictEqual(detectScene('和室友冷战'), 'relationship_conflict');
});

await test('21. 工作关键词 → work_pressure', () => {
  assert.strictEqual(detectScene('工作压力太大'), 'work_pressure');
  assert.strictEqual(detectScene('天天加班到深夜'), 'work_pressure');
  assert.strictEqual(detectScene('deadline 快到了'), 'work_pressure');
  assert.strictEqual(detectScene('KPI 完不成'), 'work_pressure');
});

await test('22. 愧疚关键词 → guilt_regret', () => {
  assert.strictEqual(detectScene('我对不起他'), 'guilt_regret');
  assert.strictEqual(detectScene('后悔当时没说'), 'guilt_regret');
  assert.strictEqual(detectScene('都是我的错'), 'guilt_regret');
  assert.strictEqual(detectScene('我伤害了她'), 'guilt_regret');
});

// fix2：新增 low_energy 场景检测
await test('22b. 低能量关键词 → low_energy（fix2 新增）', () => {
  assert.strictEqual(detectScene('最近总是提不起劲，感觉很疲惫、很空'), 'low_energy');
  assert.strictEqual(detectScene('什么都不想做，很累'), 'low_energy');
  assert.strictEqual(detectScene('感觉麻木，没动力'), 'low_energy');
  assert.strictEqual(detectScene('没精神，不想动'), 'low_energy');
});

await test('22c. low_energy 不覆盖具体事件场景（fix2 优先级）', () => {
  // 含工作关键词 + 低能量词 → 仍为 work_pressure（事件优先于状态）
  assert.strictEqual(detectScene('工作太累了，提不起劲'), 'work_pressure');
  // 含愧疚关键词 + 低能量词 → 仍为 guilt_regret
  assert.strictEqual(detectScene('对不起，我太累了'), 'guilt_regret');
});

await test('23. 无匹配 → default', () => {
  assert.strictEqual(detectScene('今晚睡不着，脑子里停不下来'), 'default');
  assert.strictEqual(detectScene('感觉自己很迷茫'), 'default');
  assert.strictEqual(detectScene('一个人有点孤独'), 'default');
  assert.strictEqual(detectScene(''), 'default');
});

// ─── normalizeResult ────────────────────────────────────────
console.log('─ normalizeResult ─');

await test('24. 非 object → null', () => {
  assert.strictEqual(normalizeResult(null), null);
  assert.strictEqual(normalizeResult(undefined), null);
  assert.strictEqual(normalizeResult('string'), null);
});

await test('25. 缺 comfortInterpretation → null', () => {
  assert.strictEqual(normalizeResult({ lyricDraft: '歌词' }), null);
  assert.strictEqual(normalizeResult({ comfortInterpretation: '' }), null);
});

await test('26. comfortInterpretation 无中文 → null', () => {
  // 全英文应被拒绝（要求中文输出）
  assert.strictEqual(
    normalizeResult({
      comfortInterpretation: 'You seem stressed lately.',
      lyricDraft: '【主歌】\nsome lyric',
    }),
    null,
  );
});

await test('27. 正常输入 → 规范化字段 + scene 校验', () => {
  var r = normalizeResult({
    comfortInterpretation: '听起来你最近压力很大。也许你不需要立刻找到答案。',
    lyricDraft: '【主歌】\n你站在夜色里没说话\n\n【副歌】\n也许明天先把杯子洗干净',
    songPrompt: 'gentle pop, acoustic guitar, slow tempo',
    safetyNotes: '未检测到风险线索',
    scene: 'work_pressure',
  });
  assert.ok(r, 'normalizeResult 应返回对象');
  assert.ok(r.comfortInterpretation.includes('听起来你'));
  assert.ok(r.lyricDraft.includes('【主歌】'));
  assert.ok(r.songPrompt.includes('gentle pop'));
  assert.strictEqual(r.safetyNotes, '未检测到风险线索');
  assert.strictEqual(r.scene, 'work_pressure');
});

await test('28. songPrompt 缺失 → 使用默认英文提示', () => {
  var r = normalizeResult({
    comfortInterpretation: '听起来你最近不容易。',
    lyricDraft: '【主歌】\n你站在夜色里没说话',
  });
  assert.ok(r.songPrompt.length > 0);
  assert.ok(r.songPrompt.includes('gentle'));
  // 默认提示应含 vocal / mood / tempo / instrumentation 要素
  assert.ok(r.songPrompt.includes('vocal'), '默认 songPrompt 应含 vocal');
  assert.ok(r.songPrompt.includes('tempo'), '默认 songPrompt 应含 tempo');
});

await test('29. safetyNotes 缺失 → 使用默认中文提示', () => {
  var r = normalizeResult({
    comfortInterpretation: '听起来你最近不容易。',
    lyricDraft: '【主歌】\n你站在夜色里没说话',
  });
  assert.strictEqual(r.safetyNotes, '未检测到风险线索');
});

await test('30. scene 非法 → 回退 default', () => {
  var r = normalizeResult({
    comfortInterpretation: '听起来你最近不容易。',
    lyricDraft: '【主歌】\n你站在夜色里没说话',
    scene: 'invalid_scene',
  });
  assert.strictEqual(r.scene, 'default');
  // scene 缺失也应回退 default
  var r2 = normalizeResult({
    comfortInterpretation: '听起来你最近不容易。',
    lyricDraft: '【主歌】\n你站在夜色里没说话',
  });
  assert.strictEqual(r2.scene, 'default');
});

// ─── localFallback（P4 第二批：5 场景 + fix2 新增 low_energy = 6 场景）──
console.log('─ localFallback ─');

const SCENES = [
  'academic_failure',
  'relationship_conflict',
  'work_pressure',
  'guilt_regret',
  'low_energy',
  'default',
];

const SCENE_STORIES = {
  academic_failure: '我考研没考上，感觉努力都白费了',
  relationship_conflict: '和妈妈大吵一架，她已读不回我',
  work_pressure: '工作压力太大，天天加班到深夜',
  guilt_regret: '我对不起他，当时不该说那些话',
  low_energy: '最近总是提不起劲，感觉很疲惫、很空',
  default: '今晚睡不着，脑子里停不下来',
};

await test('31. 6 场景返回结构完整 + 歌词结构标记', () => {
  SCENES.forEach(function (scene) {
    var story = SCENE_STORIES[scene];
    var r = localFallback(story, 'gentle_pop');
    assert.ok(typeof r.comfortInterpretation === 'string', scene + ': comfortInterpretation 应为 string');
    assert.ok(r.comfortInterpretation.length > 50, scene + ': comfortInterpretation 应有足够长度');
    assert.ok(typeof r.lyricDraft === 'string', scene + ': lyricDraft 应为 string');
    assert.ok(r.lyricDraft.length > 0, scene + ': lyricDraft 不应为空');
    assert.ok(typeof r.songPrompt === 'string', scene + ': songPrompt 应为 string');
    assert.ok(r.songPrompt.length > 0, scene + ': songPrompt 不应为空');
    assert.ok(typeof r.safetyNotes === 'string', scene + ': safetyNotes 应为 string');
    assert.ok(r.safetyNotes.length > 0, scene + ': safetyNotes 不应为空');
    // 歌词结构标记
    assert.ok(r.lyricDraft.includes('【主歌】'), scene + ': lyricDraft 应含【主歌】');
    assert.ok(r.lyricDraft.includes('【副歌】'), scene + ': lyricDraft 应含【副歌】');
    assert.ok(r.lyricDraft.includes('【尾声】'), scene + ': lyricDraft 应含【尾声】');
    // scene 字段
    assert.strictEqual(r.scene, scene, scene + ': scene 应匹配');
  });
});

await test('32. 5 场景 songPrompt 为英文且不含医疗化词汇', () => {
  SCENES.forEach(function (scene) {
    var story = SCENE_STORIES[scene];
    var r = localFallback(story, 'gentle_pop');
    var lower = r.songPrompt.toLowerCase();
    // 英文检测：应不含中文字符
    assert.ok(!/[\u4E00-\u9FFF]/.test(r.songPrompt), scene + ': songPrompt 应为纯英文');
    // 不含医疗化英文词汇
    assert.ok(!lower.includes('heal'), scene + ': songPrompt 不应含 heal');
    assert.ok(!lower.includes('cure'), scene + ': songPrompt 不应含 cure');
    assert.ok(!lower.includes('treatment'), scene + ': songPrompt 不应含 treatment');
    assert.ok(!lower.includes('therapy'), scene + ': songPrompt 不应含 therapy');
    // 应含 vocal / tempo / instrumentation 要素（P4 第二批要求）
    assert.ok(lower.includes('vocal'), scene + ': songPrompt 应含 vocal');
    assert.ok(lower.includes('tempo'), scene + ': songPrompt 应含 tempo');
    // 应含乐器或编曲要素
    assert.ok(
      lower.includes('guitar') || lower.includes('piano') || lower.includes('synth'),
      scene + ': songPrompt 应含乐器要素',
    );
  });
});

await test('33. 5 场景文案不含任何禁用词汇（医疗/玄学/空话/说教）', () => {
  var bannedAll = [
    // 医疗化
    '治疗焦虑', '治疗失眠', '治好你的焦虑', '治好你的失眠', '治愈你的', '疗法', '疗效',
    // 玄学化
    '命中注定', '天意', '神的安排', '算准', '神谕', '命运注定', '命运安排',
    '宇宙告诉你', '上天告诉你', '神明告诉你',
    // 空话
    '一切都会好的', '加油哦', '你是最棒的', '会好起来的', '一定会好',
    // 说教（P4 第二批新增）
    '你必须', '你应该', '你需要治疗', '这说明你',
  ];
  SCENES.forEach(function (scene) {
    var story = SCENE_STORIES[scene];
    var r = localFallback(story, 'gentle_pop');
    bannedAll.forEach(function (w) {
      assert.ok(
        !r.comfortInterpretation.includes(w),
        scene + ': comfortInterpretation 不应含禁用词: ' + w,
      );
      assert.ok(
        !r.lyricDraft.includes(w),
        scene + ': lyricDraft 不应含禁用词: ' + w,
      );
    });
  });
});

await test('34. 5 场景 songPrompt 不含用户隐私原句', () => {
  SCENES.forEach(function (scene) {
    var story = SCENE_STORIES[scene];
    var r = localFallback(story, 'gentle_pop');
    // songPrompt 是英文风格描述，不应包含用户中文原文片段
    // 抽取用户原文中的中文关键词，验证 songPrompt 不含这些词
    var sensitiveFragments = ['考研', '妈妈', '加班', '对不起', '睡不着'];
    sensitiveFragments.forEach(function (frag) {
      assert.ok(
        !r.songPrompt.includes(frag),
        scene + ': songPrompt 不应含用户隐私原句: ' + frag,
      );
    });
  });
});

await test('35. 不同场景返回不同 comfortInterpretation', () => {
  var results = SCENES.map(function (scene) {
    return localFallback(SCENE_STORIES[scene], 'gentle_pop').comfortInterpretation;
  });
  // 两两比较应不同
  for (var i = 0; i < results.length; i++) {
    for (var j = i + 1; j < results.length; j++) {
      assert.notStrictEqual(
        results[i],
        results[j],
        '场景 ' + SCENES[i] + ' 和 ' + SCENES[j] + ' 的 comfortInterpretation 不应相同',
      );
    }
  }
});

// ─── P4-conversation-song-flow-1-fix1：classifyConcern + localFollowUpFallback ──
console.log('─ fix1: classifyConcern + localFollowUpFallback ─');

await test('36. classifyConcern 低能量 → lowEnergy（优先级最高）', () => {
  assert.strictEqual(classifyConcern('最近总是提不起劲'), 'lowEnergy');
  assert.strictEqual(classifyConcern('感觉很疲惫'), 'lowEnergy');
  assert.strictEqual(classifyConcern('很空，什么都不想做'), 'lowEnergy');
  assert.strictEqual(classifyConcern('没动力，不想动'), 'lowEnergy');
  assert.strictEqual(classifyConcern('麻木，没精神'), 'lowEnergy');
});

await test('37. classifyConcern 事件冲突 → eventConflict', () => {
  assert.strictEqual(classifyConcern('和妈妈吵架了'), 'eventConflict');
  assert.strictEqual(classifyConcern('朋友和我闹翻了'), 'eventConflict');
  assert.strictEqual(classifyConcern('被批评了'), 'eventConflict');
});

await test('38. classifyConcern 焦虑压力 → anxietyStress', () => {
  assert.strictEqual(classifyConcern('最近很焦虑'), 'anxietyStress');
  assert.strictEqual(classifyConcern('睡不着，心慌'), 'anxietyStress');
  assert.strictEqual(classifyConcern('压力太大了'), 'anxietyStress');
});

await test('39. classifyConcern 愧疚后悔 → guiltRegret', () => {
  assert.strictEqual(classifyConcern('我很后悔'), 'guiltRegret');
  assert.strictEqual(classifyConcern('对不起他'), 'guiltRegret');
  assert.strictEqual(classifyConcern('都是我的错'), 'guiltRegret');
});

await test('40. classifyConcern 孤独 → loneliness', () => {
  assert.strictEqual(classifyConcern('感觉很孤独'), 'loneliness');
  assert.strictEqual(classifyConcern('没人理解我'), 'loneliness');
  assert.strictEqual(classifyConcern('想有人陪'), 'loneliness');
});

await test('41. classifyConcern 无匹配 → unknown', () => {
  assert.strictEqual(classifyConcern('今天天气不错'), 'unknown');
  assert.strictEqual(classifyConcern(''), 'unknown');
  assert.strictEqual(classifyConcern(undefined), 'unknown');
});

await test('42. classifyConcern lowEnergy 优先级高于其他分类', () => {
  // 同时含 lowEnergy 和其他分类关键词时，应优先返回 lowEnergy
  assert.strictEqual(classifyConcern('很累，和妈妈吵架了'), 'lowEnergy');
  assert.strictEqual(classifyConcern('提不起劲，很焦虑'), 'lowEnergy');
});

await test('43. localFollowUpFallback 返回 { category, questions }', () => {
  var r = localFollowUpFallback('最近工作压力很大');
  assert.ok(typeof r.category === 'string');
  assert.ok(Array.isArray(r.questions));
  assert.ok(r.questions.length >= 2 && r.questions.length <= 3);
  r.questions.forEach(function (q) {
    assert.ok(typeof q === 'string' && q.length > 0);
  });
});

await test('44. localFollowUpFallback lowEnergy 问题不含「这件事」', () => {
  var lowEnergyInputs = [
    '最近总是提不起劲，感觉很疲惫、很空',
    '什么都不想做，很累',
    '感觉麻木，没动力',
  ];
  lowEnergyInputs.forEach(function (input) {
    var r = localFollowUpFallback(input);
    assert.strictEqual(r.category, 'lowEnergy');
    r.questions.forEach(function (q) {
      assert.ok(
        !q.includes('这件事'),
        'lowEnergy 问题不应包含「这件事」: ' + q + ' (input: ' + input + ')',
      );
    });
  });
});

await test('45. localFollowUpFallback eventConflict 问题可含事件导向措辞', () => {
  var r = localFollowUpFallback('和妈妈吵架了');
  assert.strictEqual(r.category, 'eventConflict');
  // eventConflict 兜底第 1 问应含「最让你难受」
  assert.ok(r.questions[0].includes('最让你难受'), 'eventConflict 第 1 问应含「最让你难受」');
});

await test('46. localFollowUpFallback 6 分类问题数量均为 3', () => {
  var inputs = [
    '提不起劲',       // lowEnergy
    '和妈妈吵架了',   // eventConflict
    '很焦虑',         // anxietyStress
    '我很后悔',       // guiltRegret
    '感觉很孤独',     // loneliness
    '今天天气不错',   // unknown
  ];
  inputs.forEach(function (input) {
    var r = localFollowUpFallback(input);
    assert.strictEqual(r.questions.length, 3, input + ' 应返回 3 个问题');
  });
});

await test('47. localFollowUpFallback 问题不含医疗化词汇', () => {
  var inputs = [
    '提不起劲', '和妈妈吵架了', '很焦虑', '我很后悔', '感觉很孤独', '今天天气不错',
  ];
  var banned = ['治疗', '治愈', '疗法', '疗效', '症状', '抑郁', '焦虑症'];
  inputs.forEach(function (input) {
    var r = localFollowUpFallback(input);
    r.questions.forEach(function (q) {
      banned.forEach(function (w) {
        assert.ok(!q.includes(w), '问题不应含医疗化词汇 ' + w + ': ' + q);
      });
    });
  });
});

// ─── P4-conversation-song-flow-1-fix1：normalizeFollowUpQuestions ──
console.log('─ fix1: normalizeFollowUpQuestions ─');

await test('48. normalizeFollowUpQuestions 正常输入 → 返回字符串数组', () => {
  var r = normalizeFollowUpQuestions({
    questions: ['今天最累的是哪一段？', '现在最想让哪件事先停下来？'],
  });
  assert.ok(Array.isArray(r));
  assert.strictEqual(r.length, 2);
  r.forEach(function (q) {
    assert.ok(typeof q === 'string' && q.length > 0);
  });
});

await test('49. normalizeFollowUpQuestions 非 object → null', () => {
  assert.strictEqual(normalizeFollowUpQuestions(null), null);
  assert.strictEqual(normalizeFollowUpQuestions(undefined), null);
  assert.strictEqual(normalizeFollowUpQuestions('string'), null);
});

await test('50. normalizeFollowUpQuestions questions 非数组 → null', () => {
  assert.strictEqual(normalizeFollowUpQuestions({ questions: 'not array' }), null);
  assert.strictEqual(normalizeFollowUpQuestions({ questions: 123 }), null);
});

await test('51. normalizeFollowUpQuestions 少于 2 条 → null', () => {
  assert.strictEqual(normalizeFollowUpQuestions({ questions: ['只有一个问题'] }), null);
  assert.strictEqual(normalizeFollowUpQuestions({ questions: [] }), null);
});

await test('52. normalizeFollowUpQuestions 过滤非字符串 + 截断超长 + 最多 3 条', () => {
  var r = normalizeFollowUpQuestions({
    questions: [
      '问题1',
      123,
      '问题2',
      null,
      '问题3',
      '问题4',  // 超过 3 条应被截断
    ],
  });
  assert.ok(Array.isArray(r));
  assert.strictEqual(r.length, 3);
  assert.strictEqual(r[0], '问题1');
  assert.strictEqual(r[1], '问题2');
  assert.strictEqual(r[2], '问题3');
});

await test('53. normalizeFollowUpQuestions 过滤医疗化词汇', () => {
  var r = normalizeFollowUpQuestions({
    questions: ['你有没有治疗焦虑的需求？', '现在感觉怎么样？'],
  });
  assert.ok(r);
  // 「治疗焦虑」应被替换为「辅助舒缓」
  assert.ok(!r[0].includes('治疗焦虑'), '应过滤医疗化词汇');
  assert.ok(r[0].includes('辅助舒缓'), '应替换为辅助舒缓');
});

// ─── P4-conversation-song-flow-1-fix1：validateInput mode 参数 ──
console.log('─ fix1: validateInput mode ─');

await test('54. validateInput mode 缺失 → 默认 comfort_song', () => {
  var r = validateInput({ storyText: 'x' });
  assert.strictEqual(r.mode, 'comfort_song');
});

await test('55. validateInput mode=follow_up_questions → 透传', () => {
  var r = validateInput({ storyText: 'x', mode: 'follow_up_questions' });
  assert.strictEqual(r.mode, 'follow_up_questions');
});

await test('56. validateInput mode 非法 → 默认 comfort_song', () => {
  var r = validateInput({ storyText: 'x', mode: 'invalid_mode' });
  assert.strictEqual(r.mode, 'comfort_song');
});

await test('57. validateInput mode=comfort_song → 透传', () => {
  var r = validateInput({ storyText: 'x', mode: 'comfort_song' });
  assert.strictEqual(r.mode, 'comfort_song');
});

// ─── 结果汇总 ───────────────────────────────────────────────
console.log('\n────────────────────────────────');
console.log('✅ 通过: ' + passed + ' / ❌ 失败: ' + failed);
console.log('────────────────────────────────\n');

if (failed > 0) {
  process.exit(1);
}
