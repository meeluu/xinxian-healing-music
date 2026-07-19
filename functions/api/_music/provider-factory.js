// 心弦 · Provider 工厂（P4 第四批：MiniMax 歌曲生成灰度接入）
//
// 根据环境变量选择 music generation provider：
//
// MUSIC_GENERATION_PROVIDER | 凭证状态              | REAL_CALLS | 实际 provider
// ──────────────────────────┼───────────────────────┼────────────┼──────────────────────────
// 未设置 / "mock"           | —                     | —          | MockProvider
// "stable_audio"            | STABLE_AUDIO_API_KEY 缺失 | —       | MockProvider（降级）
// "stable_audio"            | 有 Key                | —          | StableAudioProvider 骨架
// "replicate_musicgen"      | REPLICATE_API_TOKEN 缺失 | —       | MockProvider（降级）
// "replicate_musicgen"      | 有 Token              | false      | ReplicateMusicGenProvider 骨架（disabled）
// "replicate_musicgen"      | 有 Token              | true       | ReplicateMusicGenProvider 骨架（not_implemented）
// "minimax_music"           | MINIMAX_API_KEY 缺失  | —          | MockProvider（降级）← provider=mock 根因
// "minimax_music"           | 有 Key                | false      | MiniMaxMusicProvider（disabled，不发请求）
// "minimax_music"           | 有 Key                | true       | MiniMaxMusicProvider（受 manualTest 第 3 道保护）
// 未知值                     | —                     | —          | MockProvider + warning
//
// P4 第四批 MiniMax 真实调用三重门保护：
// 门1: MUSIC_GENERATION_PROVIDER = "minimax_music"（wrangler.toml）
// 门2: MUSIC_GENERATION_REAL_CALLS_ENABLED === "true"（wrangler.toml，默认 false）
// 门3: 请求体 manualTest === true（curl 手动传入，前端默认不传）
// 另：MINIMAX_API_KEY 必须在 Cloudflare Production Secret 配置，否则 factory 降级 MockProvider
// 四者同时满足才真实调用 MiniMax API，避免误扣费。
//
// P4 第四批请求体新增字段（仅 manualTest=true 真实调用分支使用）：
// - lyrics：用户编辑后的歌词（来自前端 _editedLyric ?? result.lyricDraft）
// - songPrompt：LLM 生成的英文风格提示（来自前端 result.songPrompt）
// - 不传用户原始困惑全文（storyText 不进入 MiniMax 请求）
//
// 环境变量管理：
// - 非敏感变量（MUSIC_GENERATION_PROVIDER / MUSIC_GENERATION_REAL_CALLS_ENABLED / MINIMAX_MUSIC_MODEL / MUSIC_GENERATION_MAX_DURATION_SECONDS）→ wrangler.toml [vars]
// - 敏感凭证（MINIMAX_API_KEY / REPLICATE_API_TOKEN / STABLE_AUDIO_API_KEY）→ Cloudflare Dashboard Secret
//
// 安全：
// - 不打印 API Key / Token 值，只打印是否存在
// - 降级时打印日志，便于排查
// - /api/health diagnostics 返回 hasMinimaxKey: true/false（不返回 Key 值）

import { MockProvider } from './providers/mock-provider.js';
import { StableAudioProvider } from './providers/stable-audio-provider.js';
import { ReplicateMusicGenProvider } from './providers/replicate-musicgen-provider.js';
import { MiniMaxMusicProvider } from './providers/minimax-music-provider.js';

export function createProvider(env) {
  env = env || {};
  var providerName = env.MUSIC_GENERATION_PROVIDER || 'mock';
  var hasStableAudioKey = !!env.STABLE_AUDIO_API_KEY;
  var hasReplicateToken = !!env.REPLICATE_API_TOKEN;
  var hasMinimaxKey = !!env.MINIMAX_API_KEY;
  var realCalls = env.MUSIC_GENERATION_REAL_CALLS_ENABLED === 'true';

  if (providerName === 'mock') {
    return new MockProvider(env);
  }

  if (providerName === 'stable_audio') {
    if (!hasStableAudioKey) {
      console.log('[provider-factory] stable_audio 请求但 STABLE_AUDIO_API_KEY 缺失，降级到 mock');
      return new MockProvider(env);
    }
    console.log('[provider-factory] stable_audio + API Key 已配置，但真实调用未启用（骨架阶段），返回 StableAudioProvider 骨架');
    return new StableAudioProvider(env);
  }

  if (providerName === 'replicate_musicgen') {
    if (!hasReplicateToken) {
      console.log('[provider-factory] replicate_musicgen 请求但 REPLICATE_API_TOKEN 缺失，降级到 mock');
      return new MockProvider(env);
    }
    if (!realCalls) {
      console.log('[provider-factory] replicate_musicgen + Token 已配置，但 MUSIC_GENERATION_REAL_CALLS_ENABLED≠true，返回 ReplicateMusicGenProvider 骨架（disabled）');
    } else {
      console.log('[provider-factory] replicate_musicgen + Token + REAL_CALLS=true，但本批骨架阶段未实现真实调用，返回 not_implemented + fallback');
    }
    return new ReplicateMusicGenProvider(env);
  }

  if (providerName === 'minimax_music') {
    if (!hasMinimaxKey) {
      console.log('[provider-factory] minimax_music 请求但 MINIMAX_API_KEY 缺失，降级到 mock（provider=mock 根因）', {
        hint: '请在 Cloudflare Dashboard → Pages → Settings → Environment variables 中配置 MINIMAX_API_KEY 为 Secret',
        realCallsEnabled: realCalls,
      });
      return new MockProvider(env);
    }
    if (!realCalls) {
      console.log('[provider-factory] minimax_music + Key 已配置，但 MUSIC_GENERATION_REAL_CALLS_ENABLED≠true，返回 MiniMaxMusicProvider（disabled，不发请求）', {
        hint: '手动测试时临时将 wrangler.toml 中 MUSIC_GENERATION_REAL_CALLS_ENABLED 改为 "true" 并传 manualTest=true',
      });
    } else {
      console.log('[provider-factory] minimax_music + Key + REAL_CALLS=true，已启用真实调用分支（仍受 manualTest 第 3 道保护，无 manualTest 不发请求）');
    }
    return new MiniMaxMusicProvider(env);
  }

  // 未知 provider，降级到 mock
  console.log('[provider-factory] 未知 provider: ' + providerName + '，降级到 mock');
  return new MockProvider(env);
}
