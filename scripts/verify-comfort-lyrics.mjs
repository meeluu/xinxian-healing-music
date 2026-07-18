// 心弦 · 困惑解惑 + 歌词生成 API 验证脚本（P4 新方向第一批 / 第二批）
//
// 用途：验证 functions/api/comfort-lyrics.js 的核心逻辑：
//   - validateInput：输入校验
//   - sanitizeText：医疗化/玄学化/空话/说教 词汇过滤
//   - detectScene：本地场景识别（5 类）
//   - normalizeResult：LLM 输出校验 + 规范化
//   - localFallback：本地 fallback 文案（5 场景独立模板）
//
// 不依赖 Cloudflare 运行时，可在 Node.js 18+ 直接运行。
// 不真实调用 LLM API，避免产生费用。
//
// 运行方式：
//   node scripts/verify-comfort-lyrics.mjs
//
// 验证内容（P4 第二批，32 项）：
// 1.  validateInput 非 object → invalid_input
// 2.  validateInput storyText 缺失 → invalid_input
// 3.  validateInput storyText 空串 → invalid_input
// 4.  validateInput storyText 仅空白 → invalid_input
// 5.  validateInput storyText 超过 1000 字 → input_too_long
// 6.  validateInput 正常输入 → ok:true + 透传字段
// 7.  validateInput sessionId 缺失 → 默认空串
// 8.  validateInput targetStyle 非法 → 默认 gentle_pop
// 9.  validateInput language 缺失 → 默认 zh-CN
// 10. sanitizeText 检测「治疗焦虑」 → 替换为「辅助舒缓」+ flagged=true
// 11. sanitizeText 检测「命中注定」 → 替换为「也许」+ flagged=true
// 12. sanitizeText 检测「一切都会好的」 → 替换为「可以试着」+ flagged=true
// 13. sanitizeText 检测「你必须」 → 替换为「可以试着」+ flagged=true（P4 第二批新增）
// 14. sanitizeText 检测「你应该」 → 替换为「可以试着」+ flagged=true（P4 第二批新增）
// 15. sanitizeText 检测「这说明你」 → 替换为「可以试着」+ flagged=true（P4 第二批新增）
// 16. sanitizeText 检测「你需要治疗」 → 替换为「可以试着」+ flagged=true（P4 第二批新增）
// 17. sanitizeText 正常文本 → 不替换 + flagged=false
// 18. sanitizeText 非字符串 → 原样返回
// 19. detectScene 学业关键词 → academic_failure
// 20. detectScene 关系关键词 → relationship_conflict
// 21. detectScene 工作关键词 → work_pressure
// 22. detectScene 愧疚关键词 → guilt_regret
// 23. detectScene 无匹配 → default
// 24. normalizeResult 非 object → null
// 25. normalizeResult 缺 comfortInterpretation → null
// 26. normalizeResult comfortInterpretation 无中文 → null
// 27. normalizeResult 正常输入 → 规范化字段 + scene 校验
// 28. normalizeResult songPrompt 缺失 → 使用默认英文提示
// 29. normalizeResult safetyNotes 缺失 → 使用默认中文提示
// 30. normalizeResult scene 非法 → 回退 default
// 31. localFallback 5 场景返回结构完整 + 歌词结构标记
// 32. localFallback 5 场景 songPrompt 为英文且不含医疗化词汇
// 33. localFallback 5 场景文案不含任何禁用词汇（医疗/玄学/空话/说教）
// 34. localFallback 5 场景 songPrompt 不含用户隐私原句
// 35. localFallback 不同场景返回不同 comfortInterpretation

import assert from 'assert';
import {
  validateInput,
  sanitizeText,
  detectScene,
  normalizeResult,
  localFallback,
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

console.log('\n🔍 Comfort-Lyrics API 验证（P4 第二批）\n');

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

// ─── localFallback（P4 第二批：5 场景独立模板）──────────────
console.log('─ localFallback ─');

const SCENES = [
  'academic_failure',
  'relationship_conflict',
  'work_pressure',
  'guilt_regret',
  'default',
];

const SCENE_STORIES = {
  academic_failure: '我考研没考上，感觉努力都白费了',
  relationship_conflict: '和妈妈大吵一架，她已读不回我',
  work_pressure: '工作压力太大，天天加班到深夜',
  guilt_regret: '我对不起他，当时不该说那些话',
  default: '今晚睡不着，脑子里停不下来',
};

await test('31. 5 场景返回结构完整 + 歌词结构标记', () => {
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

// ─── 结果汇总 ───────────────────────────────────────────────
console.log('\n────────────────────────────────');
console.log('✅ 通过: ' + passed + ' / ❌ 失败: ' + failed);
console.log('────────────────────────────────\n');

if (failed > 0) {
  process.exit(1);
}
