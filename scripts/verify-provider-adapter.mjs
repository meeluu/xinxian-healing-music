// 心弦 · Provider Adapter 验证脚本（P4 第四批：MiniMax 歌曲生成灰度接入）
//
// 用途：验证 provider factory + mock/stable_audio/replicate_musicgen/minimax_music provider 的选择逻辑和返回结构。
// 不依赖 Cloudflare 运行时，可在 Node.js 18+ 直接运行。
//
// 运行方式：
//   node scripts/verify-provider-adapter.mjs
//
// 验证内容（含 P4 第四批新增）：
// 1.  Provider factory 默认返回 mock
// 2.  MUSIC_GENERATION_PROVIDER=mock → MockProvider
// 3.  stable_audio 无 API Key → 降级 MockProvider
// 4.  stable_audio 有 API Key → StableAudioProvider 骨架
// 5.  replicate_musicgen 无 Token → 降级 MockProvider
// 6.  replicate_musicgen 有 Token + REAL_CALLS=false → disabled
// 7.  replicate_musicgen 有 Token + REAL_CALLS=true → not_implemented
// 8.  replicate_musicgen 有 Token + REAL_CALLS 未设置 → disabled
// 9.  minimax_music 无 Key → 降级 MockProvider（provider=mock 根因）
// 10. minimax_music 有 Key + REAL_CALLS=false → disabled（不发请求）
// 11. minimax_music 有 Key + REAL_CALLS=true + 无 manualTest → manual_test_required（不发请求）
// 12. minimax_music 有 Key + REAL_CALLS=true + manualTest=true → 真实调用分支（mock fetch 注入）
// 13. minimax_music 有 Key + REAL_CALLS 未设置 → disabled
// 14. 未知 provider → MockProvider
// 15. MockProvider 输入校验通过
// 16. MockProvider createJob 返回结构兼容
// 17. MockProvider getStatus 返回结构兼容
// 18. StableAudioProvider createJob 返回 fallback
// 19. StableAudioProvider getStatus 返回 fallback
// 20. ReplicateMusicGenProvider createJob 返回 fallback（disabled）
// 21. ReplicateMusicGenProvider getStatus 返回 fallback（disabled）
// 22. ReplicateMusicGenProvider createJob 返回 fallback（not_implemented）
// 23. ReplicateMusicGenProvider getStatus 返回 fallback（not_implemented）
// 24. MiniMaxMusicProvider createJob 返回 fallback（disabled，不发请求）
// 25. MiniMaxMusicProvider createJob 返回 fallback（manual_test_required，不发请求）
// 26. MiniMaxMusicProvider createJob 真实调用成功（mock fetch，验证 ok:true + 元数据）
// 27. MiniMaxMusicProvider createJob 真实调用 HTTP 错误（mock fetch，验证 fallback）
// 28. MiniMaxMusicProvider createJob 真实调用 MiniMax 业务错误（mock fetch，验证 fallback）
// 29. MiniMaxMusicProvider createJob 真实调用 fetch 异常（mock fetch，验证 fallback）
// 30. MiniMaxMusicProvider getStatus 返回 fallback
// 31. MiniMaxMusicProvider 不打印 API Key（日志扫描）
// 32. 真实调用分支 fetch URL 为 MiniMax endpoint
// ── P4 第四批新增 ──
// 33. validateInput 解析 lyrics 字段（用户编辑后的歌词）
// 34. validateInput 解析 songPrompt 字段（LLM 生成的英文风格提示）
// 35. validateInput lyrics 超长截断（>2000 字符）
// 36. validateInput lyrics 含禁止关键词 → invalid_lyrics
// 37. MiniMax 真实调用透传 lyrics 到 requestBody（mock fetch 验证 body.lyrics）
// 38. MiniMax 真实调用透传 songPrompt 到 requestBody.prompt（mock fetch 验证 body.prompt）
// 39. MiniMax 真实调用缺 lyrics 时 requestBody 不含 lyrics 字段
// 40. MiniMax 真实调用缺 songPrompt 时回退到 PROMPTS_BY_TARGET_STATE
// 41. MiniMax 真实调用不传用户原始困惑全文（requestBody 不含 storyText）
// 42. MiniMax 真实调用日志不打印完整歌词（日志扫描）
// 43. MiniMax 真实调用不调用 Mureka（fetch URL 不含 mureka）
// 44. health buildDiagnostics 返回 hasMinimaxKey: true/false（不泄露 Key 值）
// 45. health buildDiagnostics 返回 musicProvider / realCallsEnabled / buildLabel
// 46. health buildDiagnostics 不包含任何 Key 值（日志扫描）

import assert from 'assert';
import { createProvider } from '../functions/api/_music/provider-factory.js';
import { validateInput } from '../functions/api/_music/music-generation-utils.js';
import { buildDiagnostics } from '../functions/api/health.js';

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

console.log('\n🔍 Provider Adapter 验证\n');

// ─── mock fetch 注入工具 ───────────────────────────────────
// 测试脚本绝不真实调用 MiniMax API，避免产生费用
// 通过注入 global.fetch 模拟响应，验证真实调用分支逻辑
var originalFetch = global.fetch;
var lastFetchArgs = null;

function injectMockFetch(responder) {
  lastFetchArgs = null;
  global.fetch = function (...args) {
    lastFetchArgs = args;
    return Promise.resolve(responder(args));
  };
}

function restoreFetch() {
  global.fetch = originalFetch;
  // 注意：不清空 lastFetchArgs，测试可能需要在 restoreFetch 后验证 fetch 调用参数
}

// ─── 日志捕获工具（用于验证不打印 API Key）─────────────────
var originalLog = console.log;
var originalError = console.error;
var capturedLogs = [];

function captureLogs() {
  capturedLogs = [];
  console.log = function (...args) {
    capturedLogs.push(args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))));
    originalLog.apply(console, args);
  };
  console.error = function (...args) {
    capturedLogs.push(args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))));
    originalError.apply(console, args);
  };
}

function restoreLogs() {
  console.log = originalLog;
  console.error = originalError;
}

// ─── Provider Factory 测试 ──────────────────────────────────
console.log('Provider Factory:');

await test('默认（无环境变量）返回 mock', () => {
  const p = createProvider({});
  assert.strictEqual(p.providerName, 'mock');
});

await test('MUSIC_GENERATION_PROVIDER=mock → MockProvider', () => {
  const p = createProvider({ MUSIC_GENERATION_PROVIDER: 'mock' });
  assert.strictEqual(p.providerName, 'mock');
});

await test('stable_audio 无 API Key → 降级 MockProvider', () => {
  const p = createProvider({ MUSIC_GENERATION_PROVIDER: 'stable_audio' });
  assert.strictEqual(p.providerName, 'mock');
});

await test('stable_audio 有 API Key → StableAudioProvider 骨架', () => {
  const p = createProvider({
    MUSIC_GENERATION_PROVIDER: 'stable_audio',
    STABLE_AUDIO_API_KEY: 'sk-test',
  });
  assert.strictEqual(p.providerName, 'stable_audio_disabled');
});

await test('replicate_musicgen 无 Token → 降级 MockProvider', () => {
  const p = createProvider({ MUSIC_GENERATION_PROVIDER: 'replicate_musicgen' });
  assert.strictEqual(p.providerName, 'mock');
});

await test('replicate_musicgen 有 Token + REAL_CALLS=false → disabled', () => {
  const p = createProvider({
    MUSIC_GENERATION_PROVIDER: 'replicate_musicgen',
    REPLICATE_API_TOKEN: 'r8-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'false',
  });
  assert.strictEqual(p.providerName, 'replicate_musicgen_disabled');
});

await test('replicate_musicgen 有 Token + REAL_CALLS=true → not_implemented', () => {
  const p = createProvider({
    MUSIC_GENERATION_PROVIDER: 'replicate_musicgen',
    REPLICATE_API_TOKEN: 'r8-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
  });
  assert.strictEqual(p.providerName, 'replicate_musicgen_not_implemented');
});

await test('replicate_musicgen 有 Token + REAL_CALLS 未设置 → disabled', () => {
  const p = createProvider({
    MUSIC_GENERATION_PROVIDER: 'replicate_musicgen',
    REPLICATE_API_TOKEN: 'r8-test',
  });
  assert.strictEqual(p.providerName, 'replicate_musicgen_disabled');
});

await test('minimax_music 无 Key → 降级 MockProvider', () => {
  const p = createProvider({ MUSIC_GENERATION_PROVIDER: 'minimax_music' });
  assert.strictEqual(p.providerName, 'mock');
});

await test('minimax_music 有 Key + REAL_CALLS=false → disabled（不发请求）', () => {
  const p = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'false',
  });
  assert.strictEqual(p.providerName, 'minimax_music_disabled');
});

await test('minimax_music 有 Key + REAL_CALLS=true + 无 manualTest → manual_test_required（不发请求）', async () => {
  // 注入 mock fetch，验证未被调用
  var fetchCalled = false;
  injectMockFetch(() => { fetchCalled = true; return { ok: true, json: async () => ({}) }; });

  const p = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
  });
  assert.strictEqual(p.providerName, 'minimax_music');

  const validated = validateInput({
    sessionId: 'test-session',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 300,
    // 不传 manualTest
  });
  const resp = await p.createJob(validated);
  assert.strictEqual(fetchCalled, false, 'fetch 不应被调用');
  assert.strictEqual(resp.ok, false);
  assert.strictEqual(resp.reason, 'manual_test_required');
  assert.strictEqual(resp.provider, 'minimax_music_manual_test_required');
  assert.strictEqual(resp.status, 'fallback');
  assert.ok(resp.fallbackTrack, '应有 fallbackTrack');

  restoreFetch();
});

await test('minimax_music 有 Key + REAL_CALLS 未设置 → disabled', () => {
  const p = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
  });
  assert.strictEqual(p.providerName, 'minimax_music_disabled');
});

await test('未知 provider → MockProvider', () => {
  const p = createProvider({ MUSIC_GENERATION_PROVIDER: 'unknown_provider' });
  assert.strictEqual(p.providerName, 'mock');
});

// ─── MockProvider 测试 ─────────────────────────────────────
console.log('\nMockProvider:');

const mock = createProvider({});
const validated = validateInput({
  sessionId: 'test-session',
  targetState: 'sleep',
  generationPrompt: 'ambient sleep music, instrumental, no vocals, slow tempo',
  durationSeconds: 300,
});

await test('输入校验通过', () => {
  assert.ok(validated.ok, '校验应通过');
  assert.strictEqual(validated.targetState, 'sleep');
  assert.strictEqual(validated.manualTest, false, '默认 manualTest 应为 false');
});

const jobResp = mock.createJob(validated);

await test('createJob 返回结构兼容', () => {
  assert.strictEqual(jobResp.ok, true);
  assert.ok(jobResp.jobId, '应有 jobId');
  assert.strictEqual(jobResp.status, 'queued');
  assert.strictEqual(jobResp.provider, 'mock');
  assert.ok(jobResp.fallbackTrack, '应有 fallbackTrack');
  assert.ok(jobResp.fallbackTrack.audioAssetId, 'fallbackTrack 应有 audioAssetId');
  assert.ok(jobResp.fallbackTrack.audioUrl, 'fallbackTrack 应有 audioUrl');
  assert.strictEqual(typeof jobResp.estimatedSeconds, 'number');
});

const statusResp = mock.getStatus(jobResp.jobId, 'sleep');

await test('getStatus 返回结构兼容', () => {
  assert.strictEqual(statusResp.ok, true);
  assert.ok(statusResp.jobId);
  assert.ok(['generating', 'succeeded', 'failed'].includes(statusResp.status));
  assert.strictEqual(statusResp.provider, 'mock');
  assert.ok(statusResp.fallbackTrack);
  assert.strictEqual(typeof statusResp.progress, 'number');
  assert.strictEqual(typeof statusResp.elapsedSeconds, 'number');
});

// ─── StableAudioProvider 骨架测试 ──────────────────────────
console.log('\nStableAudioProvider 骨架:');

const stable = createProvider({
  MUSIC_GENERATION_PROVIDER: 'stable_audio',
  STABLE_AUDIO_API_KEY: 'sk-test',
});

const stableJobResp = stable.createJob(validated);

await test('createJob 返回 fallback（不发真实请求）', () => {
  assert.strictEqual(stableJobResp.ok, false);
  assert.strictEqual(stableJobResp.provider, 'stable_audio_disabled');
  assert.strictEqual(stableJobResp.errorCode, 'not_implemented');
  assert.ok(stableJobResp.fallbackTrack, '应有 fallbackTrack');
  assert.strictEqual(stableJobResp.jobId, null);
  assert.strictEqual(stableJobResp.status, 'fallback');
});

const stableStatusResp = stable.getStatus('job_test', 'sleep');

await test('getStatus 返回 fallback（不发真实请求）', () => {
  assert.strictEqual(stableStatusResp.ok, false);
  assert.strictEqual(stableStatusResp.provider, 'stable_audio_disabled');
  assert.strictEqual(stableStatusResp.errorCode, 'not_implemented');
  assert.ok(stableStatusResp.fallbackTrack);
  assert.strictEqual(stableStatusResp.status, 'fallback');
});

// ─── ReplicateMusicGenProvider 骨架测试（disabled）─────────
console.log('\nReplicateMusicGenProvider 骨架（REAL_CALLS=false）:');

const replicateDisabled = createProvider({
  MUSIC_GENERATION_PROVIDER: 'replicate_musicgen',
  REPLICATE_API_TOKEN: 'r8-test',
  MUSIC_GENERATION_REAL_CALLS_ENABLED: 'false',
});

const replDisabledJobResp = replicateDisabled.createJob(validated);

await test('createJob 返回 fallback（disabled，不发真实请求）', () => {
  assert.strictEqual(replDisabledJobResp.ok, false);
  assert.strictEqual(replDisabledJobResp.provider, 'replicate_musicgen_disabled');
  assert.strictEqual(replDisabledJobResp.errorCode, 'not_implemented');
  assert.strictEqual(replDisabledJobResp.reason, 'provider_disabled');
  assert.ok(replDisabledJobResp.fallbackTrack, '应有 fallbackTrack');
  assert.strictEqual(replDisabledJobResp.jobId, null);
  assert.strictEqual(replDisabledJobResp.status, 'fallback');
});

const replDisabledStatusResp = replicateDisabled.getStatus('job_test', 'sleep');

await test('getStatus 返回 fallback（disabled，不发真实请求）', () => {
  assert.strictEqual(replDisabledStatusResp.ok, false);
  assert.strictEqual(replDisabledStatusResp.provider, 'replicate_musicgen_disabled');
  assert.strictEqual(replDisabledStatusResp.errorCode, 'not_implemented');
  assert.ok(replDisabledStatusResp.fallbackTrack);
  assert.strictEqual(replDisabledStatusResp.status, 'fallback');
});

// ─── ReplicateMusicGenProvider 骨架测试（not_implemented）──
console.log('\nReplicateMusicGenProvider 骨架（REAL_CALLS=true）:');

const replicateNotImpl = createProvider({
  MUSIC_GENERATION_PROVIDER: 'replicate_musicgen',
  REPLICATE_API_TOKEN: 'r8-test',
  MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
});

const replNotImplJobResp = replicateNotImpl.createJob(validated);

await test('createJob 返回 fallback（not_implemented，仍不发真实请求）', () => {
  assert.strictEqual(replNotImplJobResp.ok, false);
  assert.strictEqual(replNotImplJobResp.provider, 'replicate_musicgen_not_implemented');
  assert.strictEqual(replNotImplJobResp.errorCode, 'not_implemented');
  assert.strictEqual(replNotImplJobResp.reason, 'not_implemented');
  assert.ok(replNotImplJobResp.fallbackTrack, '应有 fallbackTrack');
  assert.strictEqual(replNotImplJobResp.jobId, null);
  assert.strictEqual(replNotImplJobResp.status, 'fallback');
});

const replNotImplStatusResp = replicateNotImpl.getStatus('job_test', 'sleep');

await test('getStatus 返回 fallback（not_implemented，仍不发真实请求）', () => {
  assert.strictEqual(replNotImplStatusResp.ok, false);
  assert.strictEqual(replNotImplStatusResp.provider, 'replicate_musicgen_not_implemented');
  assert.strictEqual(replNotImplStatusResp.errorCode, 'not_implemented');
  assert.ok(replNotImplStatusResp.fallbackTrack);
  assert.strictEqual(replNotImplStatusResp.status, 'fallback');
});

// ─── MiniMaxMusicProvider 测试（disabled，不发请求）────────
console.log('\nMiniMaxMusicProvider（REAL_CALLS=false，不发请求）:');

const minimaxDisabled = createProvider({
  MUSIC_GENERATION_PROVIDER: 'minimax_music',
  MINIMAX_API_KEY: 'mm-test',
  MUSIC_GENERATION_REAL_CALLS_ENABLED: 'false',
});

await test('createJob 返回 fallback（disabled，不发请求）', async () => {
  var fetchCalled = false;
  injectMockFetch(() => { fetchCalled = true; return { ok: true, json: async () => ({}) }; });

  const resp = await minimaxDisabled.createJob(validated);
  assert.strictEqual(fetchCalled, false, 'fetch 不应被调用');
  assert.strictEqual(resp.ok, false);
  assert.strictEqual(resp.provider, 'minimax_music_disabled');
  assert.strictEqual(resp.reason, 'provider_disabled');
  assert.strictEqual(resp.errorCode, 'not_implemented');
  assert.strictEqual(resp.status, 'fallback');
  assert.ok(resp.fallbackTrack, '应有 fallbackTrack');
  assert.strictEqual(resp.jobId, null);

  restoreFetch();
});

// ─── MiniMaxMusicProvider 测试（manual_test_required，不发请求）──
console.log('\nMiniMaxMusicProvider（REAL_CALLS=true + 无 manualTest，不发请求）:');

const minimaxRealNoManual = createProvider({
  MUSIC_GENERATION_PROVIDER: 'minimax_music',
  MINIMAX_API_KEY: 'mm-test',
  MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
});

await test('createJob 返回 fallback（manual_test_required，不发请求）', async () => {
  var fetchCalled = false;
  injectMockFetch(() => { fetchCalled = true; return { ok: true, json: async () => ({}) }; });

  const validatedNoManual = validateInput({
    sessionId: 'test-session',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 300,
    // 不传 manualTest
  });
  const resp = await minimaxRealNoManual.createJob(validatedNoManual);
  assert.strictEqual(fetchCalled, false, 'fetch 不应被调用');
  assert.strictEqual(resp.ok, false);
  assert.strictEqual(resp.provider, 'minimax_music_manual_test_required');
  assert.strictEqual(resp.reason, 'manual_test_required');
  assert.strictEqual(resp.status, 'fallback');
  assert.ok(resp.fallbackTrack, '应有 fallbackTrack');

  restoreFetch();
});

// ─── MiniMaxMusicProvider 真实调用测试（mock fetch 注入）────
console.log('\nMiniMaxMusicProvider（REAL_CALLS=true + manualTest=true，mock fetch 注入）:');

const minimaxReal = createProvider({
  MUSIC_GENERATION_PROVIDER: 'minimax_music',
  MINIMAX_API_KEY: 'mm-test',
  MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
  MINIMAX_MUSIC_MODEL: 'music-2.0',
  MUSIC_GENERATION_MAX_DURATION_SECONDS: '120',
});

const validatedManual = validateInput({
  sessionId: 'test-session-manual',
  targetState: 'sleep',
  generationPrompt: 'ambient sleep music, instrumental, no vocals',
  durationSeconds: 120,
  manualTest: true,
});

await test('createJob 真实调用成功（mock fetch，验证 ok:true + 元数据）', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeefcafebabe', music_duration: 45.5 },
      trace_id: 'test-trace-id-123',
    }),
  }));

  const resp = await minimaxReal.createJob(validatedManual);
  assert.strictEqual(resp.ok, true);
  assert.strictEqual(resp.provider, 'minimax_music');
  assert.strictEqual(resp.status, 'succeeded');
  assert.strictEqual(resp.audioHexLength, 16);
  assert.strictEqual(resp.musicDuration, 45.5);
  assert.strictEqual(resp.traceId, 'test-trace-id-123');
  assert.ok(resp.fallbackTrack, '应有 fallbackTrack');
  assert.strictEqual(resp.estimatedSeconds, 46);
  // 不应返回完整 audioHex
  assert.strictEqual(resp.audioHex, undefined, '不应返回完整 audioHex');
  assert.strictEqual(resp.audioPreviewBase64, undefined, '不应返回 audioPreviewBase64');

  restoreFetch();
});

await test('createJob 真实调用 HTTP 错误（mock fetch，验证 fallback）', async () => {
  injectMockFetch(() => ({
    ok: false,
    status: 401,
    statusText: 'Unauthorized',
    text: async () => 'invalid api key',
  }));

  const resp = await minimaxReal.createJob(validatedManual);
  assert.strictEqual(resp.ok, false);
  assert.strictEqual(resp.provider, 'minimax_music_http_error');
  assert.strictEqual(resp.reason, 'http_error_401');
  assert.strictEqual(resp.status, 'fallback');
  assert.ok(resp.fallbackTrack, '应有 fallbackTrack');

  restoreFetch();
});

await test('createJob 真实调用 MiniMax 业务错误（mock fetch，验证 fallback）', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 1001, status_msg: 'invalid parameter' },
      trace_id: 'err-trace',
    }),
  }));

  const resp = await minimaxReal.createJob(validatedManual);
  assert.strictEqual(resp.ok, false);
  assert.strictEqual(resp.provider, 'minimax_music_api_error');
  assert.strictEqual(resp.reason, 'minimax_error_1001');
  assert.strictEqual(resp.status, 'fallback');
  assert.ok(resp.fallbackTrack, '应有 fallbackTrack');

  restoreFetch();
});

await test('createJob 真实调用 fetch 异常（mock fetch，验证 fallback）', async () => {
  injectMockFetch(() => {
    throw new Error('network failure');
  });

  const resp = await minimaxReal.createJob(validatedManual);
  assert.strictEqual(resp.ok, false);
  assert.strictEqual(resp.provider, 'minimax_music_request_failed');
  assert.strictEqual(resp.reason, 'request_failed');
  assert.strictEqual(resp.status, 'fallback');
  assert.ok(resp.fallbackTrack, '应有 fallbackTrack');

  restoreFetch();
});

// ─── MiniMaxMusicProvider getStatus 测试 ──────────────────
console.log('\nMiniMaxMusicProvider getStatus:');

await test('getStatus 返回 fallback（本批不实现轮询）', () => {
  const resp = minimaxReal.getStatus('job_test', 'sleep');
  assert.strictEqual(resp.ok, false);
  assert.strictEqual(resp.provider, 'minimax_music');
  assert.strictEqual(resp.reason, 'not_implemented');
  assert.strictEqual(resp.status, 'fallback');
  assert.ok(resp.fallbackTrack, '应有 fallbackTrack');
});

// ─── 不打印 API Key 验证 ────────────────────────────────────
console.log('\n安全验证:');

await test('不打印 API Key 值（日志扫描）', async () => {
  captureLogs();

  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'safe-trace',
    }),
  }));

  await minimaxReal.createJob(validatedManual);
  restoreFetch();

  // 扫描所有捕获的日志，确保不包含 'mm-test' API Key 值
  var keyLeaked = false;
  for (var i = 0; i < capturedLogs.length; i++) {
    var line = capturedLogs[i];
    if (line.indexOf('mm-test') !== -1) {
      keyLeaked = true;
      break;
    }
  }
  restoreLogs();
  assert.strictEqual(keyLeaked, false, '日志中不应包含 API Key 值');
});

await test('真实调用分支 fetch URL 为 MiniMax endpoint', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'url-trace',
    }),
  }));

  await minimaxReal.createJob(validatedManual);
  restoreFetch();

  assert.ok(lastFetchArgs, 'fetch 应被调用');
  assert.strictEqual(lastFetchArgs[0], 'https://api.minimax.chat/v1/music_generation');
  assert.strictEqual(lastFetchArgs[1].method, 'POST');
  assert.ok(lastFetchArgs[1].headers['Authorization'].indexOf('Bearer ') === 0, '应使用 Bearer 鉴权');
  // 不验证 Authorization 具体值（避免测试脚本中出现 key）
});

// ─── P4 第四批新增测试 ─────────────────────────────────────
// 验证 lyrics + songPrompt 透传 / 不传困惑全文 / 不调用 Mureka / health 诊断不泄露 key
console.log('\nP4 第四批：lyrics + songPrompt 透传与诊断:');

// 测试 33: validateInput 解析 lyrics 字段
await test('validateInput 解析 lyrics 字段（用户编辑后的歌词）', () => {
  const v = validateInput({
    sessionId: 'test-session',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
    lyrics: '【主歌】\n夜色慢慢盖下来\n【副歌】\n想哭也没关系，我在听',
  });
  assert.ok(v.ok, '校验应通过');
  assert.strictEqual(v.lyrics, '【主歌】\n夜色慢慢盖下来\n【副歌】\n想哭也没关系，我在听');
  assert.strictEqual(v.manualTest, true);
});

// 测试 34: validateInput 解析 songPrompt 字段
await test('validateInput 解析 songPrompt 字段（LLM 生成的英文风格提示）', () => {
  const v = validateInput({
    sessionId: 'test-session',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
    songPrompt: 'gentle mandarin ballad, soft breathy vocal, fingerstyle guitar, slow tempo',
  });
  assert.ok(v.ok, '校验应通过');
  assert.strictEqual(v.songPrompt, 'gentle mandarin ballad, soft breathy vocal, fingerstyle guitar, slow tempo');
});

// 测试 35: validateInput lyrics 超长截断
await test('validateInput lyrics 超长截断（>2000 字符）', () => {
  var longLyrics = 'a'.repeat(2500);
  const v = validateInput({
    sessionId: 'test-session',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
    lyrics: longLyrics,
  });
  assert.ok(v.ok, '校验应通过');
  assert.strictEqual(v.lyrics.length, 2000, 'lyrics 应被截断到 2000 字符');
});

// 测试 36: validateInput lyrics 含禁止关键词 → invalid_lyrics
await test('validateInput lyrics 含禁止关键词 → invalid_lyrics', () => {
  const v = validateInput({
    sessionId: 'test-session',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
    lyrics: 'this song will cure your pain and treat insomnia',
  });
  assert.strictEqual(v.ok, false);
  assert.strictEqual(v.reason, 'invalid_lyrics');
});

// 测试 37: MiniMax 真实调用透传 lyrics 到 requestBody
await test('MiniMax 真实调用透传 lyrics 到 requestBody（mock fetch 验证 body.lyrics）', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 45 },
      trace_id: 'lyrics-trace',
    }),
  }));

  const v = validateInput({
    sessionId: 'test-session-lyrics',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
    lyrics: '【主歌】\n夜色慢慢盖下来\n【副歌】\n想哭也没关系，我在听',
    songPrompt: 'gentle mandarin ballad, soft breathy vocal, slow tempo',
  });
  await minimaxReal.createJob(v);
  restoreFetch();

  assert.ok(lastFetchArgs, 'fetch 应被调用');
  var body = JSON.parse(lastFetchArgs[1].body);
  assert.strictEqual(body.lyrics, '【主歌】\n夜色慢慢盖下来\n【副歌】\n想哭也没关系，我在听', 'requestBody 应包含用户编辑后的歌词');
});

// 测试 38: MiniMax 真实调用透传 songPrompt 到 requestBody.prompt
await test('MiniMax 真实调用透传 songPrompt 到 requestBody.prompt（mock fetch 验证 body.prompt）', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 45 },
      trace_id: 'songprompt-trace',
    }),
  }));

  const v = validateInput({
    sessionId: 'test-session-songprompt',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
    lyrics: '歌词内容',
    songPrompt: 'gentle mandarin ballad, soft breathy vocal, slow tempo',
  });
  await minimaxReal.createJob(v);
  restoreFetch();

  var body = JSON.parse(lastFetchArgs[1].body);
  assert.strictEqual(body.prompt, 'gentle mandarin ballad, soft breathy vocal, slow tempo', 'requestBody.prompt 应使用 songPrompt');
});

// 测试 39: MiniMax 真实调用缺 lyrics 时 requestBody 不含 lyrics 字段
await test('MiniMax 真实调用缺 lyrics 时 requestBody 不含 lyrics 字段', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'no-lyrics-trace',
    }),
  }));

  const v = validateInput({
    sessionId: 'test-session-no-lyrics',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
    // 不传 lyrics
  });
  await minimaxReal.createJob(v);
  restoreFetch();

  var body = JSON.parse(lastFetchArgs[1].body);
  assert.strictEqual(body.lyrics, undefined, '缺 lyrics 时 requestBody 不应包含 lyrics 字段');
});

// 测试 40: MiniMax 真实调用缺 songPrompt 时回退到 PROMPTS_BY_TARGET_STATE
await test('MiniMax 真实调用缺 songPrompt 时回退到 PROMPTS_BY_TARGET_STATE', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'preset-trace',
    }),
  }));

  const v = validateInput({
    sessionId: 'test-session-preset',
    targetState: 'soothe',
    generationPrompt: 'warm gentle melodies, no vocals',
    durationSeconds: 120,
    manualTest: true,
    // 不传 songPrompt
  });
  await minimaxReal.createJob(v);
  restoreFetch();

  var body = JSON.parse(lastFetchArgs[1].body);
  // soothe 对应的预置 prompt
  assert.strictEqual(body.prompt, 'Warm gentle melodies, soft strings, comforting atmosphere, slow tempo, no vocals', '缺 songPrompt 时应回退到 PROMPTS_BY_TARGET_STATE.soothe');
});

// 测试 41: MiniMax 真实调用不传用户原始困惑全文
await test('MiniMax 真实调用不传用户原始困惑全文（requestBody 不含 storyText）', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'no-story-trace',
    }),
  }));

  const v = validateInput({
    sessionId: 'test-session-no-story',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
    lyrics: '歌词内容',
    songPrompt: 'gentle ballad, slow tempo',
    // 即使前端误传 storyText，validateInput 也不会透传
    storyText: '用户原始困惑全文应该被丢弃',
  });
  await minimaxReal.createJob(v);
  restoreFetch();

  var body = JSON.parse(lastFetchArgs[1].body);
  assert.strictEqual(body.storyText, undefined, 'requestBody 不应包含 storyText');
  assert.ok(body.lyrics.indexOf('用户原始困惑全文') === -1, 'lyrics 不应包含用户原始困惑全文');
});

// 测试 42: MiniMax 真实调用日志不打印完整歌词
await test('MiniMax 真实调用日志不打印完整歌词（日志扫描）', async () => {
  captureLogs();

  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'no-lyric-leak-trace',
    }),
  }));

  const sensitiveLyricContent = '这是一段非常独特的歌词内容UNIQUE_LYRIC_MARKER_2026';
  const v = validateInput({
    sessionId: 'test-session-leak',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
    lyrics: sensitiveLyricContent,
    songPrompt: 'gentle ballad, slow tempo',
  });
  await minimaxReal.createJob(v);
  restoreFetch();
  restoreLogs();

  var lyricLeaked = false;
  for (var i = 0; i < capturedLogs.length; i++) {
    if (capturedLogs[i].indexOf('UNIQUE_LYRIC_MARKER_2026') !== -1) {
      lyricLeaked = true;
      break;
    }
  }
  assert.strictEqual(lyricLeaked, false, '日志中不应包含完整歌词内容');
});

// 测试 43: MiniMax 真实调用不调用 Mureka
await test('MiniMax 真实调用不调用 Mureka（fetch URL 不含 mureka）', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'no-mureka-trace',
    }),
  }));

  const v = validateInput({
    sessionId: 'test-session-mureka',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
    lyrics: '歌词',
  });
  await minimaxReal.createJob(v);
  restoreFetch();

  assert.ok(lastFetchArgs, 'fetch 应被调用');
  var fetchUrl = String(lastFetchArgs[0]);
  assert.ok(fetchUrl.indexOf('mureka') === -1, 'fetch URL 不应包含 mureka');
  assert.ok(fetchUrl.indexOf('minimax.chat') !== -1, 'fetch URL 应为 minimax.chat');
});

// ─── health buildDiagnostics 诊断字段测试 ───────────────────
console.log('\nP4 第四批：health 诊断字段（不泄露 Key）:');

// 测试 44: buildDiagnostics 返回 hasMinimaxKey: true/false
await test('health buildDiagnostics 返回 hasMinimaxKey: true/false（不泄露 Key 值）', () => {
  // 有 Key
  const d1 = buildDiagnostics({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-super-secret-key-12345',
  });
  assert.strictEqual(d1.hasMinimaxKey, true);

  // 无 Key
  const d2 = buildDiagnostics({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
  });
  assert.strictEqual(d2.hasMinimaxKey, false);
});

// 测试 45: buildDiagnostics 返回 musicProvider / realCallsEnabled / buildLabel
await test('health buildDiagnostics 返回 musicProvider / realCallsEnabled / buildLabel', () => {
  const d = buildDiagnostics({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    MINIMAX_API_KEY: 'mm-test',
  });
  assert.strictEqual(d.musicProvider, 'minimax_music');
  assert.strictEqual(d.realCallsEnabled, true);
  assert.strictEqual(typeof d.buildLabel, 'string');
  assert.ok(d.buildLabel.length > 0, 'buildLabel 不应为空');
  assert.ok(d.buildLabel.indexOf('P4-') === 0, 'buildLabel 应以 P4- 开头');

  // 默认值
  const dEmpty = buildDiagnostics({});
  assert.strictEqual(dEmpty.musicProvider, 'mock', '默认 musicProvider 应为 mock');
  assert.strictEqual(dEmpty.realCallsEnabled, false, '默认 realCallsEnabled 应为 false');
});

// 测试 46: buildDiagnostics 不包含任何 Key 值
await test('health buildDiagnostics 不包含任何 Key 值（日志扫描）', () => {
  const secretKey = 'mm-super-secret-key-UNIQUE_MARKER_2026';
  const d = buildDiagnostics({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    MINIMAX_API_KEY: secretKey,
    REPLICATE_API_TOKEN: 'r8-another-secret-UNIQUE_MARKER_2026',
    STABLE_AUDIO_API_KEY: 'sa-third-secret-UNIQUE_MARKER_2026',
  });
  const json = JSON.stringify(d);
  assert.strictEqual(json.indexOf('UNIQUE_MARKER_2026'), -1, '诊断 JSON 不应包含任何 API Key 值');
  assert.strictEqual(json.indexOf(secretKey), -1, '诊断 JSON 不应包含 MINIMAX_API_KEY 原值');
  // 只应包含 hasXxxKey: true/false
  assert.strictEqual(d.hasMinimaxKey, true);
  assert.strictEqual(d.hasReplicateToken, true);
  assert.strictEqual(d.hasStableAudioKey, true);
});

// ─── 总结 ─────────────────────────────────────────────────
console.log('\n────────────────────────────────');
console.log('结果：' + passed + ' passed, ' + failed + ' failed');
console.log('');

if (failed > 0) {
  console.error('❌ 验证失败');
  process.exit(1);
} else {
  console.log('✅ All provider adapter tests passed');
}
