// 心弦 · 困惑解惑 + 歌词生成 API 验证脚本（P4 新方向第一批）
//
// 用途：验证 functions/api/comfort-lyrics.js 的核心逻辑：
//   - validateInput：输入校验
//   - sanitizeText：医疗化/玄学化/空话词汇过滤
//   - normalizeResult：LLM 输出校验 + 规范化
//   - localFallback：本地 fallback 文案
//
// 不依赖 Cloudflare 运行时，可在 Node.js 18+ 直接运行。
// 不真实调用 LLM API，避免产生费用。
//
// 运行方式：
//   node scripts/verify-comfort-lyrics.mjs
//
// 验证内容（22 项）：
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
// 13. sanitizeText 正常文本 → 不替换 + flagged=false
// 14. sanitizeText 非字符串 → 原样返回
// 15. normalizeResult 非 object → null
// 16. normalizeResult 缺 comfortInterpretation → null
// 17. normalizeResult comfortInterpretation 无中文 → null
// 18. normalizeResult 正常输入 → 规范化字段
// 19. normalizeResult songPrompt 缺失 → 使用默认英文提示
// 20. normalizeResult safetyNotes 缺失 → 使用默认中文提示
// 21. localFallback 返回结构完整（4 字段）
// 22. localFallback 4 种 targetStyle 均返回对应 songPrompt

import assert from 'assert';
import {
  validateInput,
  sanitizeText,
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

console.log('\n🔍 Comfort-Lyrics API 验证\n');

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

// ─── sanitizeText ───────────────────────────────────────────
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

await test('13. 正常文本 → 不替换 + flagged=false', () => {
  var original = '听起来你最近不容易，可以试着给自己倒杯水。';
  var r = sanitizeText(original);
  assert.strictEqual(r.flagged, false);
  assert.strictEqual(r.text, original);
});

await test('14. 非字符串 → 原样返回', () => {
  assert.strictEqual(sanitizeText(null), null);
  assert.strictEqual(sanitizeText(undefined), undefined);
  assert.strictEqual(sanitizeText(123), 123);
});

// ─── normalizeResult ────────────────────────────────────────
console.log('─ normalizeResult ─');

await test('15. 非 object → null', () => {
  assert.strictEqual(normalizeResult(null), null);
  assert.strictEqual(normalizeResult(undefined), null);
  assert.strictEqual(normalizeResult('string'), null);
});

await test('16. 缺 comfortInterpretation → null', () => {
  assert.strictEqual(normalizeResult({ lyricDraft: '歌词' }), null);
  assert.strictEqual(normalizeResult({ comfortInterpretation: '' }), null);
});

await test('17. comfortInterpretation 无中文 → null', () => {
  // 全英文应被拒绝（要求中文输出）
  assert.strictEqual(
    normalizeResult({
      comfortInterpretation: 'You seem stressed lately.',
      lyricDraft: '【主歌】\nsome lyric',
    }),
    null,
  );
});

await test('18. 正常输入 → 规范化字段', () => {
  var r = normalizeResult({
    comfortInterpretation: '听起来你最近压力很大。也许你不需要立刻找到答案。',
    lyricDraft: '【主歌】\n你站在夜色里没说话\n\n【副歌】\n也许明天先把杯子洗干净',
    songPrompt: 'gentle pop, acoustic guitar, slow tempo',
    safetyNotes: '未检测到风险线索',
  });
  assert.ok(r, 'normalizeResult 应返回对象');
  assert.ok(r.comfortInterpretation.includes('听起来你'));
  assert.ok(r.lyricDraft.includes('【主歌】'));
  assert.ok(r.songPrompt.includes('gentle pop'));
  assert.strictEqual(r.safetyNotes, '未检测到风险线索');
});

await test('19. songPrompt 缺失 → 使用默认英文提示', () => {
  var r = normalizeResult({
    comfortInterpretation: '听起来你最近不容易。',
    lyricDraft: '【主歌】\n你站在夜色里没说话',
  });
  assert.ok(r.songPrompt.length > 0);
  assert.ok(r.songPrompt.includes('gentle'));
});

await test('20. safetyNotes 缺失 → 使用默认中文提示', () => {
  var r = normalizeResult({
    comfortInterpretation: '听起来你最近不容易。',
    lyricDraft: '【主歌】\n你站在夜色里没说话',
  });
  assert.strictEqual(r.safetyNotes, '未检测到风险线索');
});

// ─── localFallback ──────────────────────────────────────────
console.log('─ localFallback ─');

await test('21. 返回结构完整（4 字段）', () => {
  var r = localFallback('最近工作压力大', 'gentle_pop');
  assert.ok(typeof r.comfortInterpretation === 'string');
  assert.ok(r.comfortInterpretation.length > 0);
  assert.ok(typeof r.lyricDraft === 'string');
  assert.ok(r.lyricDraft.length > 0);
  assert.ok(typeof r.songPrompt === 'string');
  assert.ok(r.songPrompt.length > 0);
  assert.ok(typeof r.safetyNotes === 'string');
  assert.ok(r.safetyNotes.length > 0);
  // fallback 文案应含歌词结构标记
  assert.ok(r.lyricDraft.includes('【主歌】'));
  assert.ok(r.lyricDraft.includes('【副歌】'));
  assert.ok(r.lyricDraft.includes('【尾声】'));
});

await test('22. 4 种 targetStyle 均返回对应 songPrompt', () => {
  var styles = ['gentle_pop', 'ambient_ballad', 'acoustic_warm', 'soft_piano'];
  styles.forEach(function (s) {
    var r = localFallback('x', s);
    assert.ok(r.songPrompt.length > 0, 'songPrompt 不应为空: ' + s);
  });

  // 验证每种风格的 songPrompt 不相同
  var prompts = styles.map(function (s) {
    return localFallback('x', s).songPrompt;
  });
  assert.notStrictEqual(prompts[0], prompts[1]);
  assert.notStrictEqual(prompts[0], prompts[2]);
  assert.notStrictEqual(prompts[0], prompts[3]);
});

// ─── 额外：fallback 文案规范检查 ────────────────────────────
console.log('─ fallback 文案规范 ─');

await test('23. fallback 文案不含医疗化词汇', () => {
  var banned = [
    '治疗焦虑',
    '治疗失眠',
    '治好你的焦虑',
    '治愈你的',
    '疗法',
    '疗效',
  ];
  var r = localFallback('x', 'gentle_pop');
  banned.forEach(function (w) {
    assert.ok(
      !r.comfortInterpretation.includes(w),
      'comfortInterpretation 不应含: ' + w,
    );
    assert.ok(!r.lyricDraft.includes(w), 'lyricDraft 不应含: ' + w);
  });
});

await test('24. fallback 文案不含玄学化词汇', () => {
  var banned = ['命中注定', '天意', '神的安排', '算准', '神谕', '命运注定'];
  var r = localFallback('x', 'gentle_pop');
  banned.forEach(function (w) {
    assert.ok(
      !r.comfortInterpretation.includes(w),
      'comfortInterpretation 不应含: ' + w,
    );
    assert.ok(!r.lyricDraft.includes(w), 'lyricDraft 不应含: ' + w);
  });
});

await test('25. fallback songPrompt 不含医疗化英文词汇', () => {
  var r = localFallback('x', 'gentle_pop');
  var lower = r.songPrompt.toLowerCase();
  assert.ok(!lower.includes('heal'), 'songPrompt 不应含 heal');
  assert.ok(!lower.includes('cure'), 'songPrompt 不应含 cure');
  assert.ok(!lower.includes('treatment'), 'songPrompt 不应含 treatment');
  assert.ok(!lower.includes('therapy'), 'songPrompt 不应含 therapy');
});

// ─── 结果汇总 ───────────────────────────────────────────────
console.log('\n────────────────────────────────');
console.log('✅ 通过: ' + passed + ' / ❌ 失败: ' + failed);
console.log('────────────────────────────────\n');

if (failed > 0) {
  process.exit(1);
}
