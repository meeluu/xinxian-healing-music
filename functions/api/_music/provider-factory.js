// 心弦 · Provider 工厂（P4.4-2 provider adapter）
//
// 根据环境变量选择 music generation provider：
//
// MUSIC_GENERATION_PROVIDER | STABLE_AUDIO_API_KEY | 实际 provider
// ──────────────────────────┼──────────────────────┼──────────────────────
// 未设置 / "mock"           | —                    | MockProvider
// "stable_audio"            | 缺失                 | MockProvider（降级）
// "stable_audio"            | 有值                 | StableAudioProvider（骨架，不发真实请求）
// 未知值                     | —                    | MockProvider + warning
//
// 安全：
// - 不打印 API Key 值，只打印是否存在
// - 降级时打印日志，便于排查

import { MockProvider } from './providers/mock-provider.js';
import { StableAudioProvider } from './providers/stable-audio-provider.js';

export function createProvider(env) {
  env = env || {};
  var providerName = env.MUSIC_GENERATION_PROVIDER || 'mock';
  var hasApiKey = !!env.STABLE_AUDIO_API_KEY;

  if (providerName === 'mock') {
    return new MockProvider(env);
  }

  if (providerName === 'stable_audio') {
    if (!hasApiKey) {
      // API Key 缺失，降级到 mock
      console.log('[provider-factory] stable_audio 请求但 STABLE_AUDIO_API_KEY 缺失，降级到 mock');
      return new MockProvider(env);
    }
    // 有 API Key 但本批仍不真实调用（骨架阶段）
    console.log('[provider-factory] stable_audio + API Key 已配置，但真实调用未启用（骨架阶段），返回 StableAudioProvider 骨架');
    return new StableAudioProvider(env);
  }

  // 未知 provider，降级到 mock
  console.log('[provider-factory] 未知 provider: ' + providerName + '，降级到 mock');
  return new MockProvider(env);
}
