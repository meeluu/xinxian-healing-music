// 心弦 · MiniMaxMusicProvider（P4 第四批：MiniMax 歌曲生成灰度接入）
//
// 基于 MiniMax Music-2.0 模型。
// 本批实现真实调用分支，但受三重门保护：
//   1) MUSIC_GENERATION_REAL_CALLS_ENABLED === "true"（wrangler.toml 管理，默认 false）
//   2) MINIMAX_API_KEY 存在（Cloudflare Secret，缺失则 factory 降级 MockProvider）
//   3) 请求体 manualTest === true（手动 curl 测试时显式传入）
// 只有三者同时为 true 时才真实调用 MiniMax API。
//
// P4 第四批新增：请求体支持 lyrics + songPrompt 透传
// - lyrics：用户编辑后的歌词（来自前端 _editedLyric ?? result.lyricDraft）
// - songPrompt：LLM 生成的英文风格提示（来自前端 result.songPrompt）
// - 不传用户原始困惑全文（storyText 不进入 MiniMax 请求）
// - 日志只记录 lyricsLength / songPromptLength，不打印完整内容
// - 不返回完整 audioHex 到前端日志
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
// 真实调用请求体（P4 第四批）：
// - model: music-2.0
// - prompt: 优先用 validated.songPrompt（LLM 生成的英文风格提示），回退到 PROMPTS_BY_TARGET_STATE
// - lyrics: 如果 validated.lyrics 存在则传入（用户编辑后的歌词）
// - audio_setting: mp3 / 44100 / 256000
// - 不传用户原始困惑全文（storyText 不进入请求）
// - 时长 < 2 分钟（通过短 prompt + lyrics 长度控制，不显式传 duration）
//
// 返回结果处理（真实调用成功时）：
// - 返回 ok:true / provider:"minimax_music" / status:"succeeded"
// - 返回 audioHexLength（不返回完整 hex，避免巨大响应）
// - 返回 musicDuration / traceId / fallbackTrack
// - 不返回 audioPreviewBase64（避免巨大响应）
// - 日志只记录 audioHexLength / musicDuration / traceId / lyricsLength / songPromptLength
//
// 安全：
// - 不打印 API Key 值，只打印 apiKeyConfigured: true/false
// - 不打印完整歌词 / songPrompt 内容，只打印长度
// - 不泄露 MiniMax 原始错误细节，统一映射为内部 errorCode
// - 不保存生成音频到长期存储（D1 / R2 / 文件系统）

import { getFallbackTrack } from '../music-generation-utils.js';

var MINIMAX_API_ENDPOINT = 'https://api.minimax.chat/v1/music_generation';
var DEFAULT_MUSIC_MODEL = 'music-2.0';
var DEFAULT_MAX_DURATION = 120;
var REQUEST_TIMEOUT_MS = 55000; // Cloudflare Pages Function 限制（60s 留 5s 缓冲）

// 按 targetState 预置短 prompt（非医疗化表达，纯音乐，控制时长）
// 仅在 validated.songPrompt 缺失时作为回退使用
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
    // P4 第四批：真实调用已实现，受 realCallsEnabled + apiKey + manualTest 三重保护
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
  /// 受 realCallsEnabled + apiKey + manualTest 三重保护
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
      // P4 第四批：只打印长度，不打印歌词/songPrompt 内容
      lyricsLength: (validated.lyrics || '').length,
      songPromptLength: (validated.songPrompt || '').length,
    });

    return await this._callMiniMax(validated);
  }

  /// 真实调用 MiniMax /v1/music_generation
  /// P4 第四批：使用 validated.lyrics + validated.songPrompt（如果传入）
  async _callMiniMax(validated) {
    var prompt = this._buildPrompt(validated);
    var lyrics = validated.lyrics || '';

    var requestBody = {
      model: this.musicModel,
      prompt: prompt,
      audio_setting: {
        format: 'mp3',
        sample_rate: 44100,
        bitrate: 256000,
      },
    };
    // P4 第四批：如果传入用户编辑后的歌词，加入 lyrics 字段
    // 不传用户原始困惑全文（storyText 不进入请求）
    if (lyrics.length > 0) {
      requestBody.lyrics = lyrics;
    }

    var controller = new AbortController();
    var timeoutId = setTimeout(function () { controller.abort(); }, REQUEST_TIMEOUT_MS);

    try {
      console.log('[minimax-music] POST ' + MINIMAX_API_ENDPOINT, {
        model: requestBody.model,
        promptLength: prompt.length,
        // P4 第四批：只打印长度，不打印歌词/songPrompt 内容
        lyricsLength: lyrics.length,
        hasLyrics: lyrics.length > 0,
        songPromptSource: (validated.songPrompt && validated.songPrompt.length > 0) ? 'user_song_prompt' : 'preset_by_target_state',
        audioFormat: requestBody.audio_setting.format,
        sampleRate: requestBody.audio_setting.sample_rate,
        bitrate: requestBody.audio_setting.bitrate,
        // 不打印 apiKey / prompt 内容 / lyrics 内容
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
        // P4 第四批：不打印完整 audioHex / 不打印歌词内容
        lyricsLength: lyrics.length,
      });

      return {
        ok: true,
        provider: 'minimax_music',
        status: 'succeeded',
        jobId: null,
        audioHexLength: audioHex.length,
        musicDuration: musicDuration,
        traceId: traceId,
        // P4 第四批：返回请求摘要字段，便于排查
        lyricsLength: lyrics.length,
        songPromptSource: (validated.songPrompt && validated.songPrompt.length > 0) ? 'user_song_prompt' : 'preset_by_target_state',
        fallbackTrack: getFallbackTrack(validated.targetState),
        estimatedSeconds: Math.round(musicDuration) || 0,
        createdAt: new Date().toISOString(),
        // 不返回完整 audioHex，避免巨大响应
        // 不返回 audioPreviewBase64，避免巨大响应
        // 不返回完整 lyrics / songPrompt 内容
        // 不保存到 D1 / R2 / 文件系统
      };
    } catch (err) {
      clearTimeout(timeoutId);
      var errName = (err && err.name) || 'Error';
      var errMessage = (err && err.message) || 'unknown';
      console.error('[minimax-music] 调用异常', {
        errorName: errName,
        errorMessage: errMessage,
        // 不打印 apiKey / 不打印歌词内容
      });
      if (errName === 'AbortError') {
        return this._fallbackResponse(validated, 'request_timeout', 'minimax_music_timeout');
      }
      return this._fallbackResponse(validated, 'request_failed', 'minimax_music_request_failed');
    }
  }

  /// 构建请求 prompt（P4 第四批：优先用 validated.songPrompt，回退到 PROMPTS_BY_TARGET_STATE）
  /// 不传用户原始困惑全文
  _buildPrompt(validated) {
    // 优先使用 LLM 生成的英文 songPrompt（来自前端 result.songPrompt）
    if (validated.songPrompt && validated.songPrompt.length > 0) {
      return validated.songPrompt;
    }
    // 回退：按 targetState 预置短 prompt（非医疗化表达）
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
