// 心弦 · Provider Adapter 验证脚本（P4.4-2）
//
// 用途：验证 provider factory + mock/stable_audio provider 的选择逻辑和返回结构。
// 不依赖 Cloudflare 运行时，可在 Node.js 18+ 直接运行。
//
// 运行方式：
//   node scripts/verify-provider-adapter.mjs
//
// 验证内容：
// 1. Provider factory 默认返回 mock
// 2. MUSIC_GENERATION_PROVIDER=mock → MockProvider
// 3. stable_audio 无 API Key → 降级 MockProvider
// 4. stable_audio 有 API Key → StableAudioProvider 骨架
// 5. 未知 provider → MockProvider
// 6. MockProvider createJob 返回结构兼容
// 7. MockProvider getStatus 返回结构兼容
// 8. StableAudioProvider createJob 返回 fallback
// 9. StableAudioProvider getStatus 返回 fallback

import assert from 'assert';
import { createProvider } from '../functions/api/_music/provider-factory.js';
import { validateInput } from '../functions/api/_music/music-generation-utils.js';

var passed = 0;
var failed = 0;

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log('  ✅ ' + name);
  } catch (err) {
    failed++;
    console.log('  ❌ ' + name);
    console.log('     ' + err.message);
  }
}

console.log('\n🔍 Provider Adapter 验证\n');

// ─── Provider Factory 测试 ──────────────────────────────────
console.log('Provider Factory:');

test('默认（无环境变量）返回 mock', () => {
  const p = createProvider({});
  assert.strictEqual(p.providerName, 'mock');
});

test('MUSIC_GENERATION_PROVIDER=mock → MockProvider', () => {
  const p = createProvider({ MUSIC_GENERATION_PROVIDER: 'mock' });
  assert.strictEqual(p.providerName, 'mock');
});

test('stable_audio 无 API Key → 降级 MockProvider', () => {
  const p = createProvider({ MUSIC_GENERATION_PROVIDER: 'stable_audio' });
  assert.strictEqual(p.providerName, 'mock');
});

test('stable_audio 有 API Key → StableAudioProvider 骨架', () => {
  const p = createProvider({
    MUSIC_GENERATION_PROVIDER: 'stable_audio',
    STABLE_AUDIO_API_KEY: 'sk-test',
  });
  assert.strictEqual(p.providerName, 'stable_audio_disabled');
});

test('未知 provider → MockProvider', () => {
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

test('输入校验通过', () => {
  assert.ok(validated.ok, '校验应通过');
  assert.strictEqual(validated.targetState, 'sleep');
});

const jobResp = mock.createJob(validated);

test('createJob 返回结构兼容', () => {
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

test('getStatus 返回结构兼容', () => {
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

test('createJob 返回 fallback（不发真实请求）', () => {
  assert.strictEqual(stableJobResp.ok, false);
  assert.strictEqual(stableJobResp.provider, 'stable_audio_disabled');
  assert.strictEqual(stableJobResp.errorCode, 'not_implemented');
  assert.ok(stableJobResp.fallbackTrack, '应有 fallbackTrack');
  assert.strictEqual(stableJobResp.jobId, null);
  assert.strictEqual(stableJobResp.status, 'fallback');
});

const stableStatusResp = stable.getStatus('job_test', 'sleep');

test('getStatus 返回 fallback（不发真实请求）', () => {
  assert.strictEqual(stableStatusResp.ok, false);
  assert.strictEqual(stableStatusResp.provider, 'stable_audio_disabled');
  assert.strictEqual(stableStatusResp.errorCode, 'not_implemented');
  assert.ok(stableStatusResp.fallbackTrack);
  assert.strictEqual(stableStatusResp.status, 'fallback');
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
