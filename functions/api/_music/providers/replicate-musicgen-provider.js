// 心弦 · ReplicateMusicGenProvider 骨架（P4.4-3 provider adapter）
//
// 基于 Replicate 的 MusicGen 模型（facebook/musicgen-small 等）。
// 本批只实现骨架，不调用真实 Replicate API：
//
// 环境变量：
// - REPLICATE_API_TOKEN：Replicate API Token（Cloudflare Secret）
// - MUSIC_GENERATION_REAL_CALLS_ENABLED：真实调用开关（"true" / "false"）
//
// 行为矩阵：
// Token | REAL_CALLS | 本批行为
// ──────┼────────────┼──────────────────────────────────────
// 缺失  | —          | ProviderFactory 降级到 MockProvider
// 有值  | false      | 返回 provider_disabled + fallback
// 有值  | true       | 返回 not_implemented + fallback（骨架阶段，仍不发请求）
//
// P4.4-4 将实现真实 API 调用：
// - createJob → POST https://api.replicate.com/v1/predictions
// - getStatus → GET https://api.replicate.com/v1/predictions/{id}
// - 下载音频 → 上传 R2
//
// 安全：
// - 不打印 token 值，只打印是否存在
// - 不泄露 provider 原始错误

import { getFallbackTrack } from '../music-generation-utils.js';

export class ReplicateMusicGenProvider {
  constructor(env) {
    this.env = env || {};
    this.apiToken = this.env.REPLICATE_API_TOKEN || '';
    this.realCallsEnabled = this.env.MUSIC_GENERATION_REAL_CALLS_ENABLED === 'true';
    // P4.4-3 骨架阶段：即使 realCallsEnabled=true 也不真实调用
    this._realCallImplemented = false;
  }

  get providerName() {
    if (!this.apiToken) {
      return 'replicate_musicgen_unavailable';
    }
    if (!this.realCallsEnabled) {
      return 'replicate_musicgen_disabled';
    }
    // realCallsEnabled=true 但本批未实现真实调用
    return 'replicate_musicgen_not_implemented';
  }

  /// 创建生成任务（骨架，不发真实请求）
  /// P4.4-4 将实现真实 Replicate API 调用
  createJob(validated) {
    console.log('[replicate-musicgen] createJob 骨架：真实 API 调用未启用，返回 fallback', {
      targetState: validated.targetState,
      provider: this.providerName,
      apiTokenConfigured: !!this.apiToken,
      realCallsEnabled: this.realCallsEnabled,
      // 不打印 token 值
    });

    var fallbackTrack = getFallbackTrack(validated.targetState);
    var reason = 'provider_disabled';
    if (this.realCallsEnabled) {
      reason = 'not_implemented';
    }

    return {
      ok: false,
      reason: reason,
      errorCode: 'not_implemented',
      jobId: null,
      status: 'fallback',
      fallbackTrack: fallbackTrack,
      estimatedSeconds: 0,
      provider: this.providerName,
      createdAt: new Date().toISOString(),
    };
  }

  /// 查询任务状态（骨架，不发真实请求）
  /// P4.4-4 将实现真实 Replicate API 任务查询
  getStatus(jobId, targetState) {
    console.log('[replicate-musicgen] getStatus 骨架：真实 API 调用未启用，返回 fallback', {
      jobId: jobId,
      targetState: targetState,
      provider: this.providerName,
      // 不打印 token 值
    });

    var fallbackTrack = getFallbackTrack(targetState);
    var reason = 'provider_disabled';
    if (this.realCallsEnabled) {
      reason = 'not_implemented';
    }

    return {
      ok: false,
      reason: reason,
      errorCode: 'not_implemented',
      jobId: jobId,
      status: 'fallback',
      audioUrl: null,
      fallbackTrack: fallbackTrack,
      progress: 0,
      elapsedSeconds: 0,
      provider: this.providerName,
    };
  }
}
