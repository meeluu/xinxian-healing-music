import 'package:xinxian_healing_music/models/mood_profile.dart';

/// AI 音乐生成请求（P4.3 mock 阶段）。
///
/// 由前端 PlanScreen 构造，发送给 `POST /api/generate-music`。
/// 不包含用户心境原文（moodText），只传脱敏的 [generationPrompt]。
class MusicGenerationRequest {
  /// 心弦会话 ID（与 HealingMusicPlan.sessionId 一致）
  final String sessionId;

  /// 目标状态（sleep / regulate / soothe / focus / energize）
  final String targetState;

  /// 英文生成提示词（M5 EmotionToMusicPlanMapper 生成的 generationPrompt）
  final String generationPrompt;

  /// 推荐时长（秒），范围 60-600
  final int durationSeconds;

  /// 客户端版本号
  final String? clientVersion;

  const MusicGenerationRequest({
    required this.sessionId,
    required this.targetState,
    required this.generationPrompt,
    required this.durationSeconds,
    this.clientVersion,
  });

  /// 序列化为 JSON（发送给后端）
  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'targetState': targetState,
        'generationPrompt': generationPrompt,
        'durationSeconds': durationSeconds,
        if (clientVersion != null) 'clientVersion': clientVersion,
      };

  /// 从 HealingMusicPlan 构造请求
  factory MusicGenerationRequest.fromPlan({
    required String sessionId,
    required TargetState targetState,
    required String generationPrompt,
    required int durationMinutes,
    String? clientVersion,
  }) {
    return MusicGenerationRequest(
      sessionId: sessionId,
      targetState: targetState.name,
      generationPrompt: generationPrompt,
      durationSeconds: durationMinutes * 60,
      clientVersion: clientVersion,
    );
  }
}

/// 预置音频信息（fallbackTrack）。
///
/// generate-music 和 music-status 响应中都包含此字段，
/// 前端在任何情况下都能立即播放预置音频，保证零中断。
class FallbackTrack {
  /// 预置音频 ID（如 sleep_01）
  final String audioAssetId;

  /// 预置音频标题
  final String audioAssetTitle;

  /// 预置音频 URL（如 /assets/music/sleep_01.mp3）
  final String audioUrl;

  const FallbackTrack({
    required this.audioAssetId,
    required this.audioAssetTitle,
    required this.audioUrl,
  });

  factory FallbackTrack.fromJson(Map<String, dynamic> json) => FallbackTrack(
        audioAssetId: json['audioAssetId'] as String? ?? '',
        audioAssetTitle: json['audioAssetTitle'] as String? ?? '',
        audioUrl: json['audioUrl'] as String? ?? '',
      );
}

/// generate-music 响应。
class GenerateMusicResponse {
  /// 是否成功创建任务
  final bool ok;

  /// 任务 ID（成功时）
  final String? jobId;

  /// 初始状态（固定为 'queued'）
  final String? status;

  /// 预置音频信息（始终返回，失败时前端直接播放）
  final FallbackTrack fallbackTrack;

  /// 预计生成耗时（秒）
  final int estimatedSeconds;

  /// 供应商标识（P4.3 阶段为 'mock'）
  final String? provider;

  /// 创建时间（ISO8601）
  final String? createdAt;

  /// 失败原因（ok=false 时）
  final String? reason;

  const GenerateMusicResponse({
    required this.ok,
    required this.fallbackTrack,
    this.estimatedSeconds = 5,
    this.jobId,
    this.status,
    this.provider,
    this.createdAt,
    this.reason,
  });

  factory GenerateMusicResponse.fromJson(Map<String, dynamic> json) {
    return GenerateMusicResponse(
      ok: json['ok'] == true,
      jobId: json['jobId'] as String?,
      status: json['status'] as String?,
      fallbackTrack: json['fallbackTrack'] is Map<String, dynamic>
          ? FallbackTrack.fromJson(json['fallbackTrack'] as Map<String, dynamic>)
          : const FallbackTrack(
              audioAssetId: '',
              audioAssetTitle: '',
              audioUrl: '',
            ),
      estimatedSeconds: (json['estimatedSeconds'] as num?)?.toInt() ?? 5,
      provider: json['provider'] as String?,
      createdAt: json['createdAt'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

/// music-status 响应。
class MusicStatusResponse {
  /// 查询是否成功
  final bool ok;

  /// 任务 ID
  final String? jobId;

  /// 任务状态：queued / generating / succeeded / failed / fallback
  final String status;

  /// 生成成功后的音频 URL（仅 succeeded 时有值）
  final String? audioUrl;

  /// 预置音频信息（始终返回）
  final FallbackTrack fallbackTrack;

  /// 失败时的错误码
  final String? errorCode;

  /// 进度百分比（0-100）
  final int progress;

  /// 已耗时（秒）
  final int elapsedSeconds;

  /// 供应商标识
  final String? provider;

  /// 查询失败原因（ok=false 时）
  final String? reason;

  const MusicStatusResponse({
    required this.ok,
    required this.status,
    required this.fallbackTrack,
    this.progress = 0,
    this.elapsedSeconds = 0,
    this.jobId,
    this.audioUrl,
    this.errorCode,
    this.provider,
    this.reason,
  });

  factory MusicStatusResponse.fromJson(Map<String, dynamic> json) {
    return MusicStatusResponse(
      ok: json['ok'] == true,
      jobId: json['jobId'] as String?,
      status: json['status'] as String? ?? 'failed',
      audioUrl: json['audioUrl'] as String?,
      fallbackTrack: json['fallbackTrack'] is Map<String, dynamic>
          ? FallbackTrack.fromJson(json['fallbackTrack'] as Map<String, dynamic>)
          : const FallbackTrack(
              audioAssetId: '',
              audioAssetTitle: '',
              audioUrl: '',
            ),
      errorCode: json['errorCode'] as String?,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      provider: json['provider'] as String?,
      reason: json['reason'] as String?,
    );
  }

  /// 是否为终态（succeeded / failed / fallback）
  bool get isTerminal =>
      status == 'succeeded' || status == 'failed' || status == 'fallback';

  /// 是否成功
  bool get isSucceeded => status == 'succeeded';

  /// 是否需要 fallback
  bool get needsFallback => status == 'failed' || status == 'fallback' || !ok;
}

/// 音乐生成任务状态枚举（供 UI 展示）。
enum MusicGenerationPhase {
  /// 已入队
  queued('已加入生成队列'),

  /// 正在生成
  generating('正在为这次心境整理音乐方向'),

  /// 即将完成
  storing('正在准备专属音乐片段'),

  /// 生成成功
  succeeded('专属音乐已生成'),

  /// 生成失败
  failed('这次专属生成没有完成，已为你切换到合适的预置音乐'),

  /// 降级到预置
  fallback('正在播放预置音乐');

  final String displayText;
  const MusicGenerationPhase(this.displayText);

  /// 从后端 status 字符串映射
  static MusicGenerationPhase fromStatus(String status) {
    switch (status) {
      case 'queued':
        return MusicGenerationPhase.queued;
      case 'generating':
        return MusicGenerationPhase.generating;
      case 'storing':
        return MusicGenerationPhase.storing;
      case 'succeeded':
        return MusicGenerationPhase.succeeded;
      case 'failed':
        return MusicGenerationPhase.failed;
      case 'fallback':
        return MusicGenerationPhase.fallback;
      default:
        return MusicGenerationPhase.fallback;
    }
  }
}
