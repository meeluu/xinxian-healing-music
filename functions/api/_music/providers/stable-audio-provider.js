// 心弦 · StableAudioProvider 骨架（P4.4-2 provider adapter）
//
// 本批只实现骨架，不调用真实 Stable Audio API：
// - 有 API Key 时：返回 provider_disabled + fallback，明确日志
// - 无 API Key 时：ProviderFactory 不会创建本实例（降级到 MockProvider）
//
// P4.4-3 将实现真实 API 调用：
// - createJob → POST /v2/audio/stable-audio-3.0
// - getStatus → GET /v2/results/{task_id}
// - 下载音频 → 上传 R2
// - 返回 R2 audioUrl

import { getFallbackTrack } from '../music-generation-utils.js';

export class StableAudioProvider {
  constructor(env) {
    this.env = env || {};
    this.apiKey = this.env.STABLE_AUDIO_API_KEY || '';
    this.apiBase = this.env.STABLE_AUDIO_API_BASE || 'https://api.stability.ai';
    // P4.4-2 骨架阶段：明确标记未启用真实调用
    this._realCallEnabled = false;
  }

  get providerName() {
    return 'stable_audio_disabled';
  }

  /// 创建生成任务（骨架，不发真实请求）
  /// P4.4-3 将实现真实 Stability API 调用
  createJob(validated) {
    console.log('[stable-audio] createJob 骨架：真实 API 调用未启用，返回 fallback', {
      targetState: validated.targetState,
      provider: this.providerName,
      apiKeyConfigured: !!this.apiKey,
    });

    var fallbackTrack = getFallbackTrack(validated.targetState);
    return {
      ok: false,
      reason: 'provider_disabled',
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
  /// P4.4-3 将实现真实 Stability API 任务查询
  getStatus(jobId, targetState) {
    console.log('[stable-audio] getStatus 骨架：真实 API 调用未启用，返回 fallback', {
      jobId: jobId,
      targetState: targetState,
      provider: this.providerName,
    });

    var fallbackTrack = getFallbackTrack(targetState);
    return {
      ok: false,
      reason: 'provider_disabled',
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
