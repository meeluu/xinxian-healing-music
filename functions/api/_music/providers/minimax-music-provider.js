// 心弦 · MiniMaxMusicProvider（P4.4-5 真实调用测试骨架）
//
// 基于 MiniMax Music-2.0 模型。
// 本批实现真实调用分支，但受双重开关保护：
//   1) MUSIC_GENERATION_REAL_CALLS_ENABLED === "true"（wrangler.toml 管理，默认 false）
//   2) 请求体 manualTest === true（手动 curl 测试时显式传入）
// 只有两者同时为 true 时才真实调用 MiniMax API。
//
// 环境变量：
// - MINIMAX_API_KEY：MiniMax API Key（Cloudflare Secret，不写入 wrangler.toml / 代码 / README）
// - MUSIC_GENERATION_REAL_CALLS_ENABLED：真实调用总开关（"true" / "false"，wrangler.toml 管理）
// - MINIMAX_MUSIC_MODEL：模型名（默认 "music-2.0"，wrangler.toml 管理）
// - MUSIC_GENERATION_MAX_DURATION_SECONDS：单次目标时长上限（默认 120，wrangler.toml 管理）
//
// 行为矩阵：
// REAL_CALLS | Key    | manualTest | 本批行为
// ───────────┼────────┼────────────┼──────────────────────────────────────────────
// false      | —      | —          | 返回 provider_disabled + fallback（不发请求）
// true       | 缺失   | —          | ProviderFactory 已降级 MockProvider（不会进入本实例）
// true       | 有值   | false/未传 | 返回 manual_test_required + fallback（不发请求）
// true       | 有值   | true       | 真实 POST /v1/music_generation，返回 ok:true + 元数据
//
// 返回结果处理（真实调用成功时）：
// - 返回 ok:true / provider:"minimax_music" / status:"succeeded"
// - 返回 audioHexLength（不返回完整 hex，避免巨大响应）
// - 返回 musicDuration / traceId / fallbackTrack
// - 不返回 audioPreviewBase64（避免巨大响应）
// - 日志只记录 audioHexLength / musicDuration / traceId，不记录完整 hex
//
// 安全：
// - 不打印 API Key 值，只打印 apiKeyConfigured: true/false
// - 不泄露 MiniMax 原始错误细节，统一映射为内部 errorCode
// - 不保存生成音频到长期存储（D1 / R2 / 文件系统）
//
// 时长控制：
// - MiniMax Music-2.0 API 本身不强制 duration 参数
// - 通过短 prompt + 不传 lyrics 控制目标时长 < 2 分钟
// - MUSIC_GENERATION_MAX_DURATION_SECONDS 仅作内部约束，不发送给 API

import { getFallbackTrack } from '../music-generation-utils.js';

var MINIMAX_API_ENDPOINT = 'https://api.minimax.chat/v1/music_generation';
var DEFAULT_MUSIC_MODEL = 'music-2.0';
var DEFAULT_MAX_DURATION = 120;
var REQUEST_TIMEOUT_MS = 55000; // Cloudflare Pages Function 限制（60s 留 5s 缓冲）

// 按 targetState 预置短 prompt（非医疗化表达，纯音乐，控制时长）
var PROMPTS_BY_TARGET_STATE = {
  sleep: 'Soft ambient piano with slow tempo, gentle pads, no vocals, calming atmosphere for relaxation',
  regulate: 'Calm instrumental with steady rhythm, gentle acoustic guitar, peaceful mood, no vocals',
  soothe: 'Warm gentle melodies, soft strings, comforting atmosphere, slow tempo, no vocals',
  focus: 'Steady instrumental with clear rhythm, minimal melody, concentration aid, no vocals',
  energize: 'Light uplifting instrumental with warm tone, gentle rhythm, positive mood, no vocals',
};

export class MiniMaxMusicProvider {
  constructor(env) {
    this.env = env || {};
    this.apiKey = this.env.MINIMAX_API_KEY || '';
    this.realCallsEnabled = this.env.MUSIC_GENERATION_REAL_CALLS_ENABLED === 'true';
    this.musicModel = this.env.MINIMAX_MUSIC_MODEL || DEFAULT_MUSIC_MODEL;
    this.maxDurationSeconds = parseInt(this.env.MUSIC_GENERATION_MAX_DURATION_SECONDS, 10) || DEFAULT_MAX_DURATION;
    // P4.4-5：真实调用已实现，受 realCallsEnabled + manualTest 双重保护
    this._realCallImplemented = true;
  }

  get providerName() {
    if (!this.apiKey) return 'minimax_music_unavailable';
    if (!this.realCallsEnabled) return 'minimax_music_disabled';
    // realCallsEnabled=true 时返回 minimax_music（真实调用分支标识）
    // 是否真实调用还取决于 manualTest，但 providerName 反映 provider 已就绪
    return 'minimax_music';
  }

  /// 创建生成任务
  /// 受 realCallsEnabled + manualTest 双重保护
  async createJob(validated) {
    // 第 1 道保护：总开关
    if (!this.realCallsEnabled) {
      console.log('[minimax-music] createJob：REAL_CALLS_ENABLED=false，返回 disabled + fallback', {
        targetState: validated.targetState,
        provider: 'minimax_music_disabled',
        apiKeyConfigured: !!this.apiKey,
      });
      return this._fallbackResponse(validated, 'provider_disabled', 'minimax_music_disabled');
    }

    // 第 2 道保护：API Key（理论上 factory 已降级，此处防御性检查）
    if (!this.apiKey) {
      console.log('[minimax-music] createJob：MINIMAX_API_KEY 缺失，返回 fallback', {
        targetState: validated.targetState,
      });
      return this._fallbackResponse(validated, 'api_key_missing', 'minimax_music_unavailable');
    }

    // 第 3 道保护：manualTest 标志
    if (!validated || validated.manualTest !== true) {
      console.log('[minimax-music] createJob：manualTest 未启用，返回 manual_test_required + fallback', {
        targetState: validated ? validated.targetState : null,
        provider: 'minimax_music_manual_test_required',
        apiKeyConfigured: true,
        realCallsEnabled: true,
      });
      return this._fallbackResponse(validated, 'manual_test_required', 'minimax_music_manual_test_required');
    }

    // 三道保护全部通过 → 真实调用
    console.log('[minimax-music] createJob：进入真实调用分支', {
      targetState: validated.targetState,
      model: this.musicModel,
      maxDurationSeconds: this.maxDurationSeconds,
      apiKeyConfigured: true,
      realCallsEnabled: true,
      manualTest: true,
    });

    return await this._callMiniMax(validated);
  }

  /// 真实调用 MiniMax /v1/music_generation
  async _callMiniMax(validated) {
    var prompt = this._buildPrompt(validated);

    var requestBody = {
      model: this.musicModel,
      prompt: prompt,
      audio_setting: {
        format: 'mp3',
        sample_rate: 44100,
        bitrate: 256000,
      },
    };
    // 不传 lyrics：Music-2.0 lyrics 可选；为控制时长 < 2 分钟，不传歌词
    // requestBody.lyrics = ...（不设置）

    var controller = new AbortController();
    var timeoutId = setTimeout(function () { controller.abort(); }, REQUEST_TIMEOUT_MS);

    try {
      console.log('[minimax-music] POST ' + MINIMAX_API_ENDPOINT, {
        model: requestBody.model,
        promptLength: prompt.length,
        audioFormat: requestBody.audio_setting.format,
        sampleRate: requestBody.audio_setting.sample_rate,
        bitrate: requestBody.audio_setting.bitrate,
        // 不打印 apiKey
      });

      var resp = await fetch(MINIMAX_API_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer ' + this.apiKey,
        },
        body: JSON.stringify(requestBody),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!resp.ok) {
        var errText = '';
        try { errText = await resp.text(); } catch (_) { }
        console.error('[minimax-music] HTTP 错误', {
          status: resp.status,
          statusText: resp.statusText,
          errTextLength: errText.length,
          // 不打印 errText 内容，可能含敏感信息
        });
        return this._fallbackResponse(validated, 'http_error_' + resp.status, 'minimax_music_http_error');
      }

      var data = await resp.json();
      var baseResp = data.base_resp || {};

      if (baseResp.status_code !== 0) {
        console.error('[minimax-music] MiniMax 业务错误', {
          statusCode: baseResp.status_code,
          statusMsg: baseResp.status_msg,
          traceId: data.trace_id,
        });
        return this._fallbackResponse(validated, 'minimax_error_' + baseResp.status_code, 'minimax_music_api_error');
      }

      var audioHex = (data.data && data.data.audio) || '';
      var musicDuration = (data.data && data.data.music_duration) || 0;
      var traceId = data.trace_id || '';

      console.log('[minimax-music] 调用成功', {
        audioHexLength: audioHex.length,
        musicDuration: musicDuration,
        traceId: traceId,
        maxDurationSeconds: this.maxDurationSeconds,
        withinDurationLimit: musicDuration <= this.maxDurationSeconds,
        // 不打印完整 audioHex
      });

      return {
        ok: true,
        provider: 'minimax_music',
        status: 'succeeded',
        jobId: null,
        audioHexLength: audioHex.length,
        musicDuration: musicDuration,
        traceId: traceId,
        fallbackTrack: getFallbackTrack(validated.targetState),
        estimatedSeconds: Math.round(musicDuration) || 0,
        createdAt: new Date().toISOString(),
        // 不返回完整 audioHex，避免巨大响应
        // 不返回 audioPreviewBase64，避免巨大响应
        // 不保存到 D1 / R2 / 文件系统
      };
    } catch (err) {
      clearTimeout(timeoutId);
      var errName = (err && err.name) || 'Error';
      var errMessage = (err && err.message) || 'unknown';
      console.error('[minimax-music] 调用异常', {
        errorName: errName,
        errorMessage: errMessage,
        // 不打印 apiKey
      });
      if (errName === 'AbortError') {
        return this._fallbackResponse(validated, 'request_timeout', 'minimax_music_timeout');
      }
      return this._fallbackResponse(validated, 'request_failed', 'minimax_music_request_failed');
    }
  }

  /// 按 targetState 构建短 prompt（非医疗化表达）
  _buildPrompt(validated) {
    return PROMPTS_BY_TARGET_STATE[validated.targetState] || PROMPTS_BY_TARGET_STATE.sleep;
  }

  /// 构造 fallback 响应
  _fallbackResponse(validated, reason, providerName) {
    var targetState = (validated && validated.targetState) || 'sleep';
    return {
      ok: false,
      reason: reason,
      errorCode: 'not_implemented',
      jobId: null,
      status: 'fallback',
      fallbackTrack: getFallbackTrack(targetState),
      estimatedSeconds: 0,
      provider: providerName,
      createdAt: new Date().toISOString(),
    };
  }

  /// 查询任务状态（本批不实现轮询，返回 fallback）
  /// P4.4-5 真实调用为同步接口（POST 一次拿到 audio），无需轮询
  /// 如果未来切换异步任务接口，再实现轮询逻辑
  getStatus(jobId, targetState) {
    console.log('[minimax-music] getStatus：本批同步调用无需轮询，返回 fallback', {
      jobId: jobId,
      targetState: targetState,
      provider: 'minimax_music',
    });
    var fallbackTrack = getFallbackTrack(targetState);
    return {
      ok: false,
      reason: 'not_implemented',
      errorCode: 'not_implemented',
      jobId: jobId,
      status: 'fallback',
      audioUrl: null,
      fallbackTrack: fallbackTrack,
      progress: 0,
      elapsedSeconds: 0,
      provider: 'minimax_music',
    };
  }
}
