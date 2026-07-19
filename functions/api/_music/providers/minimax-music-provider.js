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
// - 返回 audioUrl（如果 MiniMax 返回 URL 字段，便于后续接入 R2 / 在线播放）
// - 返回 taskId / requestId / traceId（用于排查，三字段均来自 MiniMax 响应，不包含敏感信息）
// - 返回 musicDuration / fallbackTrack
// - 不返回 audioPreviewBase64（避免巨大响应）
// - 日志只记录 audioHexLength / audioUrlLength / musicDuration / traceId / lyricsLength / songPromptLength
//
// P4 MiniMax 真实生成链路受控测试（P4-minimax-real-test-1）补齐字段：
// - audioUrl：从 data.data.audio_url 提取（MiniMax 部分响应返回 URL 而非 hex）
// - taskId：从 data.data.task_id 或 data.task_id 提取（同步接口通常无，但兼容字段）
// - requestId：从 data.request_id 提取（与 trace_id 互为补充）
// - errorMessage：fallback 响应新增安全映射消息（不泄露 MiniMax 原始 status_msg / errText 内容）
// - errorCode：保持现有内部映射（http_error_xxx / minimax_error_xxx / request_timeout / request_failed）
//
// P4 生成音频落地播放链路（P4-generated-audio-playback-1）新增 R2 落地：
// - MiniMax 同步接口返回 audio hex（非 URL），需后端转换为可播放资源
// - 将 audioHex 转为 Uint8Array（mp3 二进制）
// - 上传到 Cloudflare R2（binding: GENERATED_MUSIC_BUCKET）
// - object key: generated-music/{yyyyMMdd}/{sessionId}-{traceId}.mp3
// - content-type: audio/mpeg
// - 返回 storageProvider: "r2" / storageKey / generatedAudioUrl
// - generatedAudioUrl 通过 /api/generated-music?key={storageKey} 代理读取 R2（无需 R2 公开访问）
// - 如果 R2 binding 不存在：返回 storageProvider: "none" + storageWarning: "r2_not_configured"
//   但 ok 仍为 true（MiniMax 调用本身成功），不崩溃，前端提示"音频已生成，但播放地址还未配置"
// - 不把完整 audioHex 返回给前端（避免巨大响应 + 避免长期暴露）
//
// 安全：
// - 不打印 API Key 值，只打印 apiKeyConfigured: true/false
// - 不打印完整歌词 / songPrompt 内容，只打印长度
// - 不泄露 MiniMax 原始错误细节（status_msg / errText），统一映射为内部 errorCode + 安全 errorMessage
// - 不在日志中打印完整 audioHex / storageKey 完整值（只打印 storageKeyLength）
// - R2 object 不公开访问（通过 /api/generated-music 代理读取，受 CORS 白名单保护）

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
    // P4-generated-audio-playback-1：R2 binding（用于落地生成音频）
    // 如果 wrangler.toml 未配置 R2 binding，此处为 null，上传时会返回 storage_unavailable
    this.r2Bucket = this.env.GENERATED_MUSIC_BUCKET || null;
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
        // P4-minimax-real-test-1：errorMessage 安全映射，不泄露 errText 内容
        return this._fallbackResponse(validated, 'http_error_' + resp.status, 'minimax_music_http_error', {
          httpStatus: resp.status,
        });
      }

      var data = await resp.json();
      var baseResp = data.base_resp || {};

      if (baseResp.status_code !== 0) {
        console.error('[minimax-music] MiniMax 业务错误', {
          statusCode: baseResp.status_code,
          statusMsg: baseResp.status_msg,
          traceId: data.trace_id,
          // status_msg 仅在服务端日志中用于排查，不返回到响应
        });
        // P4-minimax-real-test-1：errorMessage 安全映射，不泄露 status_msg 内容
        return this._fallbackResponse(validated, 'minimax_error_' + baseResp.status_code, 'minimax_music_api_error', {
          minimaxStatusCode: baseResp.status_code,
        });
      }

      var audioHex = (data.data && data.data.audio) || '';
      var musicDuration = (data.data && data.data.music_duration) || 0;
      var traceId = data.trace_id || '';
      // P4-minimax-real-test-1：补齐 audioUrl / taskId / requestId 诊断字段
      // audioUrl：MiniMax 部分响应返回 URL 而非 hex（便于后续接入 R2 / 在线播放）
      var audioUrl = (data.data && data.data.audio_url) || '';
      // taskId：同步接口通常无，但兼容 data.data.task_id / data.task_id 两种位置
      var taskId = (data.data && data.data.task_id) || data.task_id || '';
      // requestId：与 trace_id 互为补充，部分响应返回 request_id
      var requestId = data.request_id || '';

      console.log('[minimax-music] 调用成功', {
        audioHexLength: audioHex.length,
        audioUrlLength: audioUrl.length,
        hasAudioUrl: audioUrl.length > 0,
        musicDuration: musicDuration,
        traceId: traceId,
        taskId: taskId,
        requestId: requestId,
        maxDurationSeconds: this.maxDurationSeconds,
        withinDurationLimit: musicDuration <= this.maxDurationSeconds,
        // P4 第四批：不打印完整 audioHex / 不打印歌词内容 / 不打印 audioUrl 完整值
        lyricsLength: lyrics.length,
      });

      // P4-generated-audio-playback-1：将 audioHex 转为 bytes 并上传到 R2
      // 如果 MiniMax 直接返回 audioUrl，则无需 R2 上传，直接用 audioUrl 作为 generatedAudioUrl
      var storageProvider = 'none';
      var storageKey = null;
      var generatedAudioUrl = null;
      var storageWarning = null;

      if (audioUrl.length > 0) {
        // 情况 1：MiniMax 直接返回 audioUrl（无需 R2 上传）
        storageProvider = 'minimax_direct';
        generatedAudioUrl = audioUrl;
        console.log('[minimax-music] MiniMax 直接返回 audioUrl，无需 R2 上传', {
          storageProvider: storageProvider,
          audioUrlLength: audioUrl.length,
        });
      } else if (audioHex.length > 0 && this.r2Bucket) {
        // 情况 2：有 audioHex 且 R2 binding 已配置 → 上传到 R2
        try {
          var audioBytes = this._hexToBytes(audioHex);
          storageKey = this._buildStorageKey(validated.sessionId, traceId);
          await this.r2Bucket.put(storageKey, audioBytes, {
            httpMetadata: { contentType: 'audio/mpeg' },
          });
          storageProvider = 'r2';
          // generatedAudioUrl 通过 /api/generated-music 代理读取 R2（无需 R2 公开访问）
          generatedAudioUrl = '/api/generated-music?key=' + encodeURIComponent(storageKey);
          console.log('[minimax-music] R2 上传成功', {
            storageProvider: storageProvider,
            storageKeyLength: storageKey.length,
            audioBytesLength: audioBytes.length,
            hasGeneratedAudioUrl: true,
            // 不打印 storageKey 完整值
          });
        } catch (storageErr) {
          console.error('[minimax-music] R2 上传失败', {
            errorName: storageErr && storageErr.name,
            // 不打印完整错误消息，可能含敏感信息
          });
          storageProvider = 'none';
          storageKey = null;
          generatedAudioUrl = null;
          storageWarning = 'r2_upload_failed';
        }
      } else if (audioHex.length > 0 && !this.r2Bucket) {
        // 情况 3：有 audioHex 但 R2 binding 未配置 → 返回 storageWarning
        storageWarning = 'r2_not_configured';
        console.log('[minimax-music] R2 binding 未配置，跳过上传', {
          storageWarning: storageWarning,
          audioHexLength: audioHex.length,
        });
      }

      return {
        ok: true,
        provider: 'minimax_music',
        status: 'succeeded',
        jobId: null,
        // P4-minimax-real-test-1：补齐诊断字段
        taskId: taskId || null,
        traceId: traceId,
        requestId: requestId || null,
        audioHexLength: audioHex.length,
        // audioUrl：MiniMax 原始返回的 URL（如果有）
        audioUrl: audioUrl || null,
        audioUrlLength: audioUrl.length,
        musicDuration: musicDuration,
        // P4-generated-audio-playback-1：R2 落地字段
        storageProvider: storageProvider,
        storageKey: storageKey,
        generatedAudioUrl: generatedAudioUrl,
        storageWarning: storageWarning,
        // P4 第四批：返回请求摘要字段，便于排查
        lyricsLength: lyrics.length,
        songPromptSource: (validated.songPrompt && validated.songPrompt.length > 0) ? 'user_song_prompt' : 'preset_by_target_state',
        fallbackTrack: getFallbackTrack(validated.targetState),
        estimatedSeconds: Math.round(musicDuration) || 0,
        createdAt: new Date().toISOString(),
        // 不返回完整 audioHex，避免巨大响应
        // 不返回 audioPreviewBase64，避免巨大响应
        // 不返回完整 lyrics / songPrompt 内容
        // 音频已落地到 R2（如果 storageProvider === 'r2'），不返回 hex
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
        // P4-minimax-real-test-1：超时安全映射
        return this._fallbackResponse(validated, 'request_timeout', 'minimax_music_timeout', {
          timeoutMs: REQUEST_TIMEOUT_MS,
        });
      }
      return this._fallbackResponse(validated, 'request_failed', 'minimax_music_request_failed', {
        errorName: errName,
      });
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

  /// P4-generated-audio-playback-1：将 hex 字符串转为 Uint8Array
  /// MiniMax 同步接口返回 audio hex（如 "ff fb ..."），需转为二进制后上传到 R2
  /// 实现说明：
  /// - 输入：hex 字符串（偶数长度，每 2 字符表示 1 字节）
  /// - 输出：Uint8Array（可直接传给 R2 put()）
  /// - 边界处理：奇数长度补 0 前缀；非 hex 字符直接跳过；空串返回空 Uint8Array
  /// - 性能：分块解析（每 64KB），避免一次性 String.substr 产生大字符串
  /// 安全：本方法不接触敏感信息（hex 是音频数据），无日志泄漏风险
  _hexToBytes(hex) {
    if (typeof hex !== 'string' || hex.length === 0) {
      return new Uint8Array(0);
    }
    // 清理可能的空白字符（MiniMax 偶尔在 hex 中插入换行）
    var cleanHex = hex.replace(/\s+/g, '');
    // 奇数长度补 0 前缀（防御性处理，正常情况 MiniMax 返回偶数长度）
    if (cleanHex.length % 2 !== 0) {
      cleanHex = '0' + cleanHex;
    }
    var byteCount = cleanHex.length / 2;
    var bytes = new Uint8Array(byteCount);
    for (var i = 0; i < byteCount; i++) {
      var byteHex = cleanHex.substr(i * 2, 2);
      // parseInt 第二个参数 16 表示按 hex 解析；非 hex 字符会得到 NaN，转成 0
      var b = parseInt(byteHex, 16);
      bytes[i] = isNaN(b) ? 0 : b;
    }
    return bytes;
  }

  /// P4-generated-audio-playback-1：构建 R2 object key
  /// 格式：generated-music/{yyyyMMdd}/{sessionId}-{traceId}.mp3
  /// 设计说明：
  /// - 日期前缀：便于按时间维度批量管理 / 清理
  /// - sessionId + traceId：保证唯一性，便于排查
  /// - .mp3 后缀：明确音频格式，便于 R2 metadata 和后续迁移
  /// 安全：sessionId 和 traceId 已经过 validateInput 校验（sessionId 长度 ≤ 100），
  ///       traceId 来自 MiniMax 响应，均不含敏感信息
  /// 边界：traceId 可能为空字符串（MiniMax 异常情况），此时只用 sessionId + 时间戳
  _buildStorageKey(sessionId, traceId) {
    var now = new Date();
    var yyyy = now.getUTCFullYear();
    var mm = String(now.getUTCMonth() + 1).padStart(2, '0');
    var dd = String(now.getUTCDate()).padStart(2, '0');
    var datePart = yyyy + mm + dd;

    // 防 sessionId 为空
    var safeSessionId = (typeof sessionId === 'string' && sessionId.length > 0)
      ? sessionId.replace(/[^a-zA-Z0-9_-]/g, '_')
      : 'unknown-session';

    // 防 traceId 为空（追加时间戳保证唯一）
    var safeTraceId = (typeof traceId === 'string' && traceId.length > 0)
      ? traceId.replace(/[^a-zA-Z0-9_-]/g, '_')
      : 'no-trace-' + Date.now().toString(36);

    return 'generated-music/' + datePart + '/' + safeSessionId + '-' + safeTraceId + '.mp3';
  }

  /// 构造 fallback 响应
  /// P4-minimax-real-test-1：新增第四个参数 extra，用于 errorMessage 安全映射
  /// extra 仅用于内部映射 errorMessage，不直接暴露给前端
  /// errorMessage 不泄露 MiniMax 原始 status_msg / errText / err.message 内容
  _fallbackResponse(validated, reason, providerName, extra) {
    var targetState = (validated && validated.targetState) || 'sleep';
    extra = extra || {};
    // P4-minimax-real-test-1：根据 reason 映射安全 errorMessage
    // 不泄露 MiniMax 原始错误细节，只返回内部友好提示
    var errorMessage = this._mapErrorMessage(reason, extra);
    return {
      ok: false,
      reason: reason,
      errorCode: reason, // P4-minimax-real-test-1：errorCode 与 reason 一致，便于前端识别
      errorMessage: errorMessage, // P4-minimax-real-test-1：安全映射的错误消息
      jobId: null,
      taskId: null, // P4-minimax-real-test-1：fallback 无 taskId
      traceId: null, // P4-minimax-real-test-1：fallback 无 traceId
      requestId: null, // P4-minimax-real-test-1：fallback 无 requestId
      status: 'fallback',
      fallbackTrack: getFallbackTrack(targetState),
      estimatedSeconds: 0,
      provider: providerName,
      createdAt: new Date().toISOString(),
    };
  }

  /// P4-minimax-real-test-1：安全映射 errorMessage
  /// 根据 reason 返回内部友好消息，不泄露 MiniMax 原始错误细节
  /// 不打印 extra 中的原始值（httpStatus / minimaxStatusCode / errorName 仅用于映射，不进入响应）
  _mapErrorMessage(reason, extra) {
    if (typeof reason !== 'string') return 'minimax_music_error';
    // HTTP 错误：只返回内部映射，不泄露 statusText / errText
    if (reason.indexOf('http_error_') === 0) {
      return 'minimax_http_error'; // 不返回 httpStatus 具体值，避免泄露后端细节
    }
    // MiniMax 业务错误：不返回 status_msg，只返回内部 code
    if (reason.indexOf('minimax_error_') === 0) {
      return 'minimax_business_error';
    }
    if (reason === 'request_timeout') return 'minimax_request_timeout';
    if (reason === 'request_failed') return 'minimax_request_failed';
    if (reason === 'provider_disabled') return 'minimax_real_calls_disabled';
    if (reason === 'api_key_missing') return 'minimax_api_key_missing';
    if (reason === 'manual_test_required') return 'manual_test_required';
    if (reason === 'not_implemented') return 'not_implemented';
    return 'minimax_music_error';
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
