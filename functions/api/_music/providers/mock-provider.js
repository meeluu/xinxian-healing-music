// 心弦 · MockProvider（P4.4-2 provider adapter）
//
// 从 P4.3 generate-music.js / music-status.js 抽出的 mock 逻辑。
// 无状态，不依赖 D1 / R2 / 外部 API。
//
// 状态机：
// - 0-4s   → generating（进度 10-95%）
// - ≥4s    → 90% succeeded / 10% failed（jobId 随机部分做种子）
// - succeeded 时 audioUrl 返回预置音频路径（mock 阶段与 fallback 相同）

import {
  generateJobId,
  parseJobTimestamp,
  estimateProgress,
  getFallbackTrack,
} from '../music-generation-utils.js';

export class MockProvider {
  constructor(env) {
    this.env = env || {};
  }

  get providerName() {
    return 'mock';
  }

  /// 创建 mock 生成任务
  /// 输入：validated = { sessionId, targetState, prompt, durationSeconds }
  /// 返回：{ ok, jobId, status, fallbackTrack, estimatedSeconds, provider }
  createJob(validated) {
    var jobId = generateJobId();
    var fallbackTrack = getFallbackTrack(validated.targetState);
    return {
      ok: true,
      jobId: jobId,
      status: 'queued',
      fallbackTrack: fallbackTrack,
      estimatedSeconds: 5,
      provider: 'mock',
      createdAt: new Date().toISOString(),
    };
  }

  /// 查询 mock 任务状态
  /// 输入：jobId, targetState
  /// 返回：{ ok, jobId, status, audioUrl, fallbackTrack, progress, elapsedSeconds, provider, errorCode }
  getStatus(jobId, targetState) {
    var createdAt = parseJobTimestamp(jobId);
    if (!createdAt) {
      return {
        ok: false,
        reason: 'invalid_job_id',
        fallbackTrack: getFallbackTrack(targetState),
      };
    }

    var elapsedMs = Date.now() - createdAt;
    var elapsedSeconds = Math.max(0, Math.round(elapsedMs / 1000));
    var progress = estimateProgress(elapsedMs);
    var fallbackTrack = getFallbackTrack(targetState);

    if (elapsedMs < 4000) {
      return {
        ok: true,
        jobId: jobId,
        status: 'generating',
        audioUrl: null,
        fallbackTrack: fallbackTrack,
        errorCode: null,
        progress: progress,
        elapsedSeconds: elapsedSeconds,
        provider: 'mock',
      };
    }

    // 4s 后：90% succeeded / 10% failed（jobId 随机部分做种子，保证一致性）
    var randomPart = jobId.split('_')[2] || '0';
    var seed = 0;
    for (var i = 0; i < randomPart.length; i++) {
      seed = (seed * 31 + randomPart.charCodeAt(i)) % 100;
    }
    var isSuccess = seed >= 10;

    if (isSuccess) {
      return {
        ok: true,
        jobId: jobId,
        status: 'succeeded',
        audioUrl: fallbackTrack.audioUrl,
        fallbackTrack: fallbackTrack,
        errorCode: null,
        progress: 100,
        elapsedSeconds: elapsedSeconds,
        provider: 'mock',
      };
    } else {
      return {
        ok: true,
        jobId: jobId,
        status: 'failed',
        audioUrl: null,
        fallbackTrack: fallbackTrack,
        errorCode: 'mock_random_failure',
        progress: progress,
        elapsedSeconds: elapsedSeconds,
        provider: 'mock',
      };
    }
  }
}
