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
// ── P4 MiniMax 真实生成链路受控测试（P4-minimax-real-test-1）新增 ──
// 47. MiniMax 真实调用成功返回 audioUrl 字段（mock 返回 audio_url）
// 48. MiniMax 真实调用成功返回 taskId 字段（mock 返回 data.data.task_id）
// 49. MiniMax 真实调用成功返回 requestId 字段（mock 返回 request_id）
// 50. MiniMax HTTP 错误 errorMessage 不泄露 errText 内容
// 51. MiniMax 业务错误 errorMessage 不泄露 status_msg 内容
// 52. MiniMax fetch 异常 errorMessage 不泄露 err.message 内容
// 53. MiniMax fallback 响应包含 taskId/traceId/requestId 字段（值为 null）
// ── P4 生成音频落地播放链路（P4-generated-audio-playback-1）新增 ──
// 54. MiniMax 真实调用成功 + R2 已配置 → 上传到 R2 + 返回 storageProvider=r2
// 55. MiniMax 真实调用成功 + R2 未配置 → storageWarning=r2_not_configured
// 56. MiniMax 真实调用成功 + R2 上传失败 → storageWarning=r2_upload_failed
// 57. MiniMax 真实调用成功 + 直接返回 audioUrl → storageProvider=minimax_direct
// 58. storageKey 格式正确（generated-music/{yyyyMMdd}/{sessionId}-{traceId}.mp3）
// 59. 响应不包含完整 audioHex（避免长期暴露）
// 60. _hexToBytes 正确转换 hex 为 bytes（通过 R2 上传的 bodyLength 验证）
// 61. _buildStorageKey 边界处理 - traceId 为空时仍生成合法 key
// 62. health buildDiagnostics 返回 hasR2Bucket 字段（不泄露 bucket 名）
// 63. buildLabel 已更新为 P4-generated-audio-playback-1
// ── P4 临时音频播放闭环（P4-temp-audio-playback-1）新增/调整 ──
// 64. R2 未配置 + 有 audioHex → 返回 audioDataUrl（不再 storageWarning=r2_not_configured）
// 65. R2 上传失败 + 有 audioHex → 返回 audioDataUrl 兜底 + storageWarning=r2_upload_failed
// 66. R2 上传成功 → 不返回 audioDataUrl（节省响应体，只用 generatedAudioUrl）
// 67. MiniMax 直接返回 audioUrl → 不返回 audioDataUrl（已有可播放 URL）
// 68. audioDataUrl 格式正确（data:audio/mpeg;base64,...）
// 69. 响应包含 contentType=audio/mpeg + audioBase64Length 字段
// 70. _bytesToBase64 正确转换（通过 audioBase64Length 验证：hex "deadbeef" → 4 字节 → 8 字符 base64）
// 71. buildLabel 已更新为 P4-temp-audio-playback-1
// 注：实际测试用例编号通过 await test() 调用顺序自动递增，
//     注释编号仅作说明用途，以实际运行结果为准。

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
  // P4-minimax-real-test-1：errorCode 与 reason 一致，便于前端识别
  assert.strictEqual(resp.errorCode, 'provider_disabled');
  assert.strictEqual(resp.errorMessage, 'minimax_real_calls_disabled');
  assert.strictEqual(resp.status, 'fallback');
  assert.ok(resp.fallbackTrack, '应有 fallbackTrack');
  assert.strictEqual(resp.jobId, null);
  // P4-minimax-real-test-1：fallback 响应应包含 taskId/traceId/requestId 字段（值为 null）
  assert.strictEqual(resp.taskId, null);
  assert.strictEqual(resp.traceId, null);
  assert.strictEqual(resp.requestId, null);

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
  // P4-minimax-real-test-1：errorCode 与 reason 一致 + errorMessage 安全映射
  assert.strictEqual(resp.errorCode, 'manual_test_required');
  assert.strictEqual(resp.errorMessage, 'manual_test_required');
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
  // P4-minimax-real-test-1：补齐 audioUrl / taskId / requestId 字段（mock 未返回则为 null）
  assert.strictEqual(resp.audioUrl, null, 'mock 未返回 audio_url 时应为 null');
  assert.strictEqual(resp.audioUrlLength, 0);
  assert.strictEqual(resp.taskId, null, 'mock 未返回 task_id 时应为 null');
  assert.strictEqual(resp.requestId, null, 'mock 未返回 request_id 时应为 null');
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
  // P4-minimax-real-test-1：errorMessage 安全映射，不泄露 errText 内容
  assert.strictEqual(resp.errorMessage, 'minimax_http_error');
  assert.strictEqual(resp.errorCode, 'http_error_401');

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
  // P4-minimax-real-test-1：errorMessage 安全映射，不泄露 status_msg 内容
  assert.strictEqual(resp.errorMessage, 'minimax_business_error');
  assert.strictEqual(resp.errorCode, 'minimax_error_1001');

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
  // P4-minimax-real-test-1：errorMessage 安全映射，不泄露 err.message 内容
  assert.strictEqual(resp.errorMessage, 'minimax_request_failed');
  assert.strictEqual(resp.errorCode, 'request_failed');

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

// ─── P4 MiniMax 真实生成链路受控测试（P4-minimax-real-test-1）──
// 验证 audioUrl / taskId / requestId 解析 + errorMessage 安全映射
console.log('\nP4 MiniMax 真实生成链路受控测试（audioUrl/taskId/requestId/errorMessage）:');

// 测试 47: MiniMax 真实调用成功返回 audioUrl 字段（mock 返回 audio_url）
await test('MiniMax 真实调用成功返回 audioUrl 字段（mock 返回 audio_url）', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: {
        audio: '',
        audio_url: 'https://cdn.minimax.chat/audio/test-audio-001.mp3',
        music_duration: 60,
      },
      trace_id: 'audio-url-trace',
    }),
  }));

  const resp = await minimaxReal.createJob(validatedManual);
  assert.strictEqual(resp.ok, true);
  assert.strictEqual(resp.status, 'succeeded');
  assert.strictEqual(resp.audioUrl, 'https://cdn.minimax.chat/audio/test-audio-001.mp3');
  assert.strictEqual(resp.audioUrlLength, 'https://cdn.minimax.chat/audio/test-audio-001.mp3'.length);
  assert.strictEqual(resp.audioHexLength, 0, 'audio 为空时 audioHexLength 应为 0');
  assert.strictEqual(resp.musicDuration, 60);

  restoreFetch();
});

// 测试 48: MiniMax 真实调用成功返回 taskId 字段（mock 返回 data.data.task_id）
await test('MiniMax 真实调用成功返回 taskId 字段（mock 返回 data.data.task_id）', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: {
        audio: 'deadbeef',
        music_duration: 45,
        task_id: 'task-xyz-001',
      },
      trace_id: 'task-id-trace',
    }),
  }));

  const resp = await minimaxReal.createJob(validatedManual);
  assert.strictEqual(resp.ok, true);
  assert.strictEqual(resp.taskId, 'task-xyz-001');
  assert.strictEqual(resp.traceId, 'task-id-trace');

  restoreFetch();
});

// 测试 49: MiniMax 真实调用成功返回 requestId 字段（mock 返回 request_id）
await test('MiniMax 真实调用成功返回 requestId 字段（mock 返回 request_id）', async () => {
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'req-trace',
      request_id: 'req-abc-002',
    }),
  }));

  const resp = await minimaxReal.createJob(validatedManual);
  assert.strictEqual(resp.ok, true);
  assert.strictEqual(resp.requestId, 'req-abc-002');
  assert.strictEqual(resp.traceId, 'req-trace');

  restoreFetch();
});

// 测试 50: MiniMax HTTP 错误 errorMessage 不泄露 errText 内容
await test('MiniMax HTTP 错误 errorMessage 不泄露 errText 内容', async () => {
  var sensitiveErrText = 'UNIQUE_ERR_TEXT_MARKER_FOR_TEST_2026';
  injectMockFetch(() => ({
    ok: false,
    status: 500,
    statusText: 'Internal Server Error',
    text: async () => sensitiveErrText,
  }));

  const resp = await minimaxReal.createJob(validatedManual);
  assert.strictEqual(resp.ok, false);
  assert.strictEqual(resp.errorMessage, 'minimax_http_error');
  // errorMessage 不应包含 errText 原始内容
  assert.strictEqual(JSON.stringify(resp).indexOf(sensitiveErrText), -1, '响应不应包含 errText 原始内容');

  restoreFetch();
});

// 测试 51: MiniMax 业务错误 errorMessage 不泄露 status_msg 内容
await test('MiniMax 业务错误 errorMessage 不泄露 status_msg 内容', async () => {
  var sensitiveStatusMsg = 'UNIQUE_STATUS_MSG_MARKER_FOR_TEST_2026';
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 1002, status_msg: sensitiveStatusMsg },
      trace_id: 'leak-trace',
    }),
  }));

  const resp = await minimaxReal.createJob(validatedManual);
  assert.strictEqual(resp.ok, false);
  assert.strictEqual(resp.errorMessage, 'minimax_business_error');
  // errorMessage 不应包含 status_msg 原始内容
  assert.strictEqual(JSON.stringify(resp).indexOf(sensitiveStatusMsg), -1, '响应不应包含 status_msg 原始内容');

  restoreFetch();
});

// 测试 52: MiniMax fetch 异常 errorMessage 不泄露 err.message 内容
await test('MiniMax fetch 异常 errorMessage 不泄露 err.message 内容', async () => {
  var sensitiveErrMsg = 'UNIQUE_NETWORK_ERROR_MARKER_FOR_TEST_2026';
  injectMockFetch(() => {
    throw new Error(sensitiveErrMsg);
  });

  const resp = await minimaxReal.createJob(validatedManual);
  assert.strictEqual(resp.ok, false);
  assert.strictEqual(resp.errorMessage, 'minimax_request_failed');
  // errorMessage 不应包含 err.message 原始内容
  assert.strictEqual(JSON.stringify(resp).indexOf(sensitiveErrMsg), -1, '响应不应包含 err.message 原始内容');

  restoreFetch();
});

// 测试 53: MiniMax fallback 响应包含 taskId/traceId/requestId 字段（值为 null）
await test('MiniMax fallback 响应包含 taskId/traceId/requestId 字段（值为 null）', async () => {
  // manual_test_required fallback 路径
  const validatedNoManual = validateInput({
    sessionId: 'test-session-fallback',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    // 不传 manualTest
  });
  const resp = await minimaxRealNoManual.createJob(validatedNoManual);
  assert.strictEqual(resp.ok, false);
  assert.strictEqual(resp.taskId, null);
  assert.strictEqual(resp.traceId, null);
  assert.strictEqual(resp.requestId, null);
  assert.strictEqual(resp.errorMessage, 'manual_test_required');
});

// ─── P4 生成音频落地播放链路（P4-generated-audio-playback-1）──
// 验证 R2 落地 + storageKey + generatedAudioUrl + storageWarning + hexToBytes
console.log('\nP4 生成音频落地播放链路（R2 落地 + storageKey + generatedAudioUrl）:');

/// 创建 mock R2 bucket（记录 put / get 调用，便于断言）
function createMockR2Bucket() {
  var puts = [];
  var gets = [];
  return {
    put: async function (key, body, options) {
      puts.push({ key: key, bodyLength: body && body.length, options: options });
      return { ok: true };
    },
    get: async function (key) {
      gets.push({ key: key });
      return null;
    },
    _puts: puts,
    _gets: gets,
  };
}

// 测试 54: MiniMax 真实调用成功 + R2 已配置 → 上传到 R2 + 返回 storageProvider/storageKey/generatedAudioUrl
await test('MiniMax 真实调用成功 + R2 已配置 → 上传到 R2 + 返回 storageProvider=r2', async () => {
  var mockBucket = createMockR2Bucket();
  var provider = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    GENERATED_MUSIC_BUCKET: mockBucket,
  });
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeefcafebabe', music_duration: 45 },
      trace_id: 'r2-upload-trace',
    }),
  }));

  var v = validateInput({
    sessionId: 'r2-test-session',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
  });
  var resp = await provider.createJob(v);
  restoreFetch();

  assert.strictEqual(resp.ok, true);
  assert.strictEqual(resp.provider, 'minimax_music');
  assert.strictEqual(resp.status, 'succeeded');
  assert.strictEqual(resp.storageProvider, 'r2');
  assert.ok(resp.storageKey, 'storageKey 不应为空');
  assert.ok(resp.storageKey.indexOf('generated-music/') === 0, 'storageKey 应以 generated-music/ 开头');
  assert.ok(resp.storageKey.indexOf('.mp3') !== -1, 'storageKey 应以 .mp3 结尾');
  assert.ok(resp.generatedAudioUrl, 'generatedAudioUrl 不应为空');
  assert.ok(resp.generatedAudioUrl.indexOf('/api/generated-music?key=') === 0, 'generatedAudioUrl 应为 /api/generated-music?key= 形式');
  assert.strictEqual(resp.storageWarning, null);
  // P4-temp-audio-playback-1：R2 上传成功时不返回 audioDataUrl（节省响应体，只用 generatedAudioUrl）
  assert.strictEqual(resp.audioDataUrl, null, 'R2 上传成功时不应返回 audioDataUrl');
  assert.strictEqual(resp.audioBase64Length, 0, 'audioBase64Length 应为 0');
  // R2 put 应被调用 1 次
  assert.strictEqual(mockBucket._puts.length, 1, 'R2 put 应被调用 1 次');
  // content-type 应为 audio/mpeg
  assert.strictEqual(mockBucket._puts[0].options.httpMetadata.contentType, 'audio/mpeg');
});

// 测试 55: MiniMax 真实调用成功 + R2 未配置 → 返回 audioDataUrl（P4-temp-audio-playback-1 调整）
// P4-temp-audio-playback-1：R2 未配置不再视为错误，回退到 audioDataUrl 临时播放
await test('MiniMax 真实调用成功 + R2 未配置 → 返回 audioDataUrl（不依赖 R2）', async () => {
  var provider = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    // 不配置 GENERATED_MUSIC_BUCKET
  });
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'no-r2-trace',
    }),
  }));

  var resp = await provider.createJob(validatedManual);
  restoreFetch();

  assert.strictEqual(resp.ok, true);
  assert.strictEqual(resp.storageProvider, 'none');
  assert.strictEqual(resp.storageKey, null);
  assert.strictEqual(resp.generatedAudioUrl, null);
  // P4-temp-audio-playback-1：不再返回 storageWarning="r2_not_configured"
  assert.strictEqual(resp.storageWarning, null, 'R2 未配置不应返回 storageWarning');
  // 应返回 audioDataUrl 作为临时播放方案
  assert.ok(resp.audioDataUrl, 'audioDataUrl 不应为空（R2 未配置时回退到 dataUrl）');
  assert.ok(resp.audioDataUrl.indexOf('data:audio/mpeg;base64,') === 0, 'audioDataUrl 应为 data:audio/mpeg;base64, 形式');
  assert.ok(resp.audioBase64Length > 0, 'audioBase64Length 应 > 0');
  assert.strictEqual(resp.contentType, 'audio/mpeg');
});

// 测试 56: MiniMax 真实调用成功 + R2 上传失败 → storageWarning=r2_upload_failed + audioDataUrl 兜底
// P4-temp-audio-playback-1：R2 上传失败时回退到 audioDataUrl，保证前端仍可播放
await test('MiniMax 真实调用成功 + R2 上传失败 → storageWarning=r2_upload_failed + audioDataUrl 兜底', async () => {
  var failingBucket = {
    put: async function () { throw new Error('R2 put failed'); },
    get: async function () { return null; },
  };
  var provider = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    GENERATED_MUSIC_BUCKET: failingBucket,
  });
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'r2-fail-trace',
    }),
  }));

  var resp = await provider.createJob(validatedManual);
  restoreFetch();

  assert.strictEqual(resp.ok, true, 'MiniMax 调用本身成功，ok 应为 true');
  assert.strictEqual(resp.storageProvider, 'none');
  assert.strictEqual(resp.storageKey, null);
  assert.strictEqual(resp.generatedAudioUrl, null);
  assert.strictEqual(resp.storageWarning, 'r2_upload_failed');
  // P4-temp-audio-playback-1：R2 上传失败时应回退到 audioDataUrl
  assert.ok(resp.audioDataUrl, 'audioDataUrl 不应为空（R2 上传失败时回退到 dataUrl）');
  assert.ok(resp.audioDataUrl.indexOf('data:audio/mpeg;base64,') === 0, 'audioDataUrl 应为 data:audio/mpeg;base64, 形式');
});

// 测试 57: MiniMax 真实调用成功 + 直接返回 audioUrl → storageProvider=minimax_direct
await test('MiniMax 真实调用成功 + 直接返回 audioUrl → storageProvider=minimax_direct', async () => {
  var mockBucket = createMockR2Bucket();
  var provider = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    GENERATED_MUSIC_BUCKET: mockBucket,
  });
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: {
        audio: '',
        audio_url: 'https://cdn.minimax.chat/audio/direct-001.mp3',
        music_duration: 60,
      },
      trace_id: 'direct-url-trace',
    }),
  }));

  var resp = await provider.createJob(validatedManual);
  restoreFetch();

  assert.strictEqual(resp.ok, true);
  assert.strictEqual(resp.storageProvider, 'minimax_direct');
  assert.strictEqual(resp.generatedAudioUrl, 'https://cdn.minimax.chat/audio/direct-001.mp3');
  assert.strictEqual(resp.storageWarning, null);
  // P4-temp-audio-playback-1：MiniMax 直接返回 audioUrl 时不需要 audioDataUrl
  assert.strictEqual(resp.audioDataUrl, null, 'MiniMax 直接返回 audioUrl 时不应返回 audioDataUrl');
  // R2 put 不应被调用（MiniMax 直接返回 URL 时无需上传）
  assert.strictEqual(mockBucket._puts.length, 0, 'R2 put 不应被调用');
});

// 测试 58: storageKey 格式正确（generated-music/{yyyyMMdd}/{sessionId}-{traceId}.mp3）
await test('storageKey 格式正确（generated-music/{yyyyMMdd}/{sessionId}-{traceId}.mp3）', async () => {
  var mockBucket = createMockR2Bucket();
  var provider = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    GENERATED_MUSIC_BUCKET: mockBucket,
  });
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'format-check-trace',
    }),
  }));

  var v = validateInput({
    sessionId: 'my-session-id',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
  });
  var resp = await provider.createJob(v);
  restoreFetch();

  // storageKey 格式：generated-music/{yyyyMMdd}/{sessionId}-{traceId}.mp3
  var key = resp.storageKey;
  assert.ok(key, 'storageKey 不应为空');
  var parts = key.split('/');
  assert.strictEqual(parts.length, 3, 'storageKey 应有 3 段（generated-music / date / file）');
  assert.strictEqual(parts[0], 'generated-music');
  // 第 2 段是 yyyyMMdd（8 位数字）
  assert.ok(/^\d{8}$/.test(parts[1]), '第 2 段应为 8 位数字日期');
  // 第 3 段应包含 sessionId 和 traceId
  assert.ok(parts[2].indexOf('my-session-id') !== -1, 'storageKey 应包含 sessionId');
  assert.ok(parts[2].indexOf('format-check-trace') !== -1, 'storageKey 应包含 traceId');
  assert.ok(parts[2].endsWith('.mp3'), 'storageKey 文件名应以 .mp3 结尾');
});

// 测试 59: 响应不包含完整 audioHex（避免长期暴露）
await test('响应不包含完整 audioHex（避免长期暴露）', async () => {
  var mockBucket = createMockR2Bucket();
  var provider = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    GENERATED_MUSIC_BUCKET: mockBucket,
  });
  var fullHex = 'deadbeefcafebabe1234567890abcdef';
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: fullHex, music_duration: 30 },
      trace_id: 'no-hex-trace',
    }),
  }));

  var resp = await provider.createJob(validatedManual);
  restoreFetch();

  // 应返回 audioHexLength，但不返回完整 audioHex
  assert.strictEqual(resp.audioHexLength, fullHex.length);
  assert.strictEqual(resp.audioHex, undefined, '响应不应包含完整 audioHex 字段');
  // 响应 JSON 字符串中不应出现完整 hex 值
  assert.strictEqual(JSON.stringify(resp).indexOf(fullHex), -1, '响应 JSON 不应包含完整 audioHex 值');
});

// 测试 60: _hexToBytes 正确转换 hex 为 bytes
await test('_hexToBytes 正确转换 hex 为 bytes（通过 R2 上传的 bodyLength 验证）', async () => {
  var mockBucket = createMockR2Bucket();
  var provider = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    GENERATED_MUSIC_BUCKET: mockBucket,
  });
  // hex: "deadbeef" → 4 字节 [0xde, 0xad, 0xbe, 0xef]
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'hex-bytes-trace',
    }),
  }));

  await provider.createJob(validatedManual);
  restoreFetch();

  // R2 put 应被调用，bodyLength 应为 4 字节（"deadbeef" → 4 字节）
  assert.strictEqual(mockBucket._puts.length, 1);
  assert.strictEqual(mockBucket._puts[0].bodyLength, 4, 'hex "deadbeef" 应转换为 4 字节');
});

// 测试 61: _buildStorageKey 边界处理 - traceId 为空时仍生成合法 key
await test('_buildStorageKey 边界处理 - traceId 为空时仍生成合法 key', async () => {
  var mockBucket = createMockR2Bucket();
  var provider = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    GENERATED_MUSIC_BUCKET: mockBucket,
  });
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      // 不返回 trace_id
    }),
  }));

  var v = validateInput({
    sessionId: 'empty-trace-session',
    targetState: 'sleep',
    generationPrompt: 'ambient sleep music, instrumental, no vocals',
    durationSeconds: 120,
    manualTest: true,
  });
  var resp = await provider.createJob(v);
  restoreFetch();

  assert.strictEqual(resp.ok, true);
  assert.ok(resp.storageKey, '即使 traceId 为空，storageKey 也不应为空');
  assert.ok(resp.storageKey.indexOf('no-trace-') !== -1, 'traceId 为空时 storageKey 应包含 no-trace- 占位');
  assert.ok(resp.storageKey.endsWith('.mp3'), 'storageKey 仍应以 .mp3 结尾');
});

// 测试 62: health buildDiagnostics 返回 hasR2Bucket 字段（不泄露 bucket 名）
await test('health buildDiagnostics 返回 hasR2Bucket 字段（不泄露 bucket 名）', () => {
  // 有 R2 binding（mock bucket 对象）
  var d1 = buildDiagnostics({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    GENERATED_MUSIC_BUCKET: { put: function () { }, get: function () { } },
  });
  assert.strictEqual(d1.hasR2Bucket, true);

  // 无 R2binding
  var d2 = buildDiagnostics({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
  });
  assert.strictEqual(d2.hasR2Bucket, false);

  // 不应泄露 bucket 名（如果传入字符串名而非 binding 对象，hasR2Bucket 仍为 true，但响应中只有 true/false）
  var d3 = buildDiagnostics({
    GENERATED_MUSIC_BUCKET: 'xinxian-generated-music',
  });
  assert.strictEqual(d3.hasR2Bucket, true);
  assert.strictEqual(JSON.stringify(d3).indexOf('xinxian-generated-music'), -1, '诊断 JSON 不应包含 bucket 名');
});

// 测试 63: buildLabel 已更新为 P4-conversation-song-flow-1
// P4-conversation-song-flow-1：多轮困惑理解 + 更贴合困境的歌词 + 纯音乐本地舒缓 + 定时关闭（realCallsEnabled 保持 false）
await test('buildLabel 已更新为 P4-conversation-song-flow-1', () => {
  var d = buildDiagnostics({});
  assert.strictEqual(d.buildLabel, 'P4-conversation-song-flow-1');
});

// ─── P4 临时音频播放闭环（P4-temp-audio-playback-1）新增测试 ──
console.log('\nP4 临时音频播放闭环（audioDataUrl + _bytesToBase64）:');

// 测试 64: _bytesToBase64 正确转换（hex "deadbeef" → 4 字节 → base64 "3q2+7w=="）
// 验证 audioBase64Length 与预期一致，并验证 audioDataUrl 解码后能还原原始 bytes
await test('_bytesToBase64 正确转换 hex → bytes → base64（通过 audioDataUrl 验证）', async () => {
  var provider = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    // 不配置 R2，强制走 audioDataUrl 路径
  });
  // hex "deadbeef" → 4 字节 [0xde, 0xad, 0xbe, 0xef]
  // base64("Þ­¾ï") = "3q2+7w==" （长度 8）
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: 'deadbeef', music_duration: 30 },
      trace_id: 'base64-verify-trace',
    }),
  }));

  var resp = await provider.createJob(validatedManual);
  restoreFetch();

  assert.strictEqual(resp.ok, true);
  assert.ok(resp.audioDataUrl, 'audioDataUrl 不应为空');
  // base64 部分："3q2+7w=="（8 字符）
  assert.strictEqual(resp.audioBase64Length, 8, 'hex "deadbeef" → 4 字节 → 8 字符 base64');
  // 验证 audioDataUrl 格式
  assert.ok(resp.audioDataUrl.indexOf('data:audio/mpeg;base64,3q2+7w==') === 0, 'audioDataUrl 应为 data:audio/mpeg;base64,3q2+7w==');
  // 验证 contentType
  assert.strictEqual(resp.contentType, 'audio/mpeg');
});

// 测试 65: audioDataUrl 不包含完整 audioHex 原文（避免 hex 长期暴露）
await test('audioDataUrl 路径下响应不包含完整 audioHex 原文', async () => {
  var provider = createProvider({
    MUSIC_GENERATION_PROVIDER: 'minimax_music',
    MINIMAX_API_KEY: 'mm-test',
    MUSIC_GENERATION_REAL_CALLS_ENABLED: 'true',
    // 不配置 R2，走 audioDataUrl 路径
  });
  var fullHex = 'deadbeefcafebabe1234567890abcdef';
  injectMockFetch(() => ({
    ok: true,
    json: async () => ({
      base_resp: { status_code: 0, status_msg: 'success' },
      data: { audio: fullHex, music_duration: 30 },
      trace_id: 'no-hex-leak-trace',
    }),
  }));

  var resp = await provider.createJob(validatedManual);
  restoreFetch();

  // 应返回 audioHexLength，但不返回完整 audioHex 字段
  assert.strictEqual(resp.audioHexLength, fullHex.length);
  assert.strictEqual(resp.audioHex, undefined, '响应不应包含完整 audioHex 字段');
  // 响应 JSON 字符串中不应出现完整 hex 原文（base64 编码后 hex 字符串不应原样出现）
  assert.strictEqual(JSON.stringify(resp).indexOf(fullHex), -1, '响应 JSON 不应包含完整 audioHex 原文');
  // 但 audioDataUrl 应该存在（base64 编码后的形式）
  assert.ok(resp.audioDataUrl, 'audioDataUrl 不应为空');
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
