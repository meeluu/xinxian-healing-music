import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';

/// 云端反馈上传 payload（M7 新增）。
///
/// 字段与 D1 `feedback` 表一一对应，由 [CloudFeedbackUploader] 上传到
/// `/api/submit-feedback`。所有字段允许 null（除必填字段），保证 schema 演进容错。
///
/// 隐私要点：
/// - **不上传** `moodText`（用户心境原文）
/// - 只上传结构化情绪标签和参数（`emotionTags` / `valence` / `arousal` / `intensity` / `targetState`）
/// - `freeTextFeedback` 受独立同意开关控制，由 uploader 在发送前决定是否剥离
/// - `audioAssetId` 脱敏为文件名（如 `sleep_01.mp3`），不含路径前缀
class CloudFeedbackPayload {
  /// 会话 ID（与 listeningSessionId 相同，冗余存一份方便查询）。
  final String sessionId;

  /// 聆听会话 ID（主键，upsert 语义）。
  final String listeningSessionId;

  /// 提交时间（ISO8601）。
  final String createdAt;

  /// 实验分组：custom / generic / control。
  final String? experimentVariant;

  /// 解析来源：mock / llm / fallback。
  final String? analyzerMode;

  /// 目标状态：sleep / regulate / soothe / focus / energize。
  final String? targetState;

  /// 情绪标签 JSON 数组（如 `["焦虑","紧绷"]`）。
  final List<String> emotionTags;

  /// 效价 -1.0..1.0。
  final double? valence;

  /// 唤醒度 0.0..1.0。
  final double? arousal;

  /// 情绪强度 0.0..1.0。
  final double? intensity;

  /// 方案标题。
  final String? musicTitle;

  /// 音频标识（脱敏文件名，如 `sleep_01.mp3`）。
  final String? audioAssetId;

  /// 音频展示名。
  final String? audioAssetTitle;

  /// 节拍 BPM。
  final int? bpm;

  /// 脑波目标。
  final String? brainwaveTarget;

  /// 噪音层。
  final String? noiseLayer;

  /// 放松度评分（M7.0 从 rating 映射，1-5）。
  final int? relaxationScore;

  /// 情绪匹配度（M7.0 留空，M7.1 扩展 UI 后填充）。
  final int? emotionMatchScore;

  /// 平静度评分（M7.0 从 1-tensionAfter 映射，0-100）。
  final int? calmnessScore;

  /// 继续使用意愿（M7.0 留空，M7.1 扩展 UI 后填充）。
  final int? willingToContinue;

  /// 文字反馈（可为 null，受独立同意开关控制）。
  final String? freeTextFeedback;

  /// 客户端版本（如 `v0.7.0/M7-dev`）。
  final String? clientVersion;

  /// 浏览器 UA（可选，仅用于区分设备类型）。
  final String? userAgent;

  /// 来源平台（固定 `web`）。
  final String source;

  /// Schema 版本（未来迁移用）。
  final int schemaVersion;

  const CloudFeedbackPayload({
    required this.sessionId,
    required this.listeningSessionId,
    required this.createdAt,
    required this.emotionTags,
    required this.source,
    this.experimentVariant,
    this.analyzerMode,
    this.targetState,
    this.valence,
    this.arousal,
    this.intensity,
    this.musicTitle,
    this.audioAssetId,
    this.audioAssetTitle,
    this.bpm,
    this.brainwaveTarget,
    this.noiseLayer,
    this.relaxationScore,
    this.emotionMatchScore,
    this.calmnessScore,
    this.willingToContinue,
    this.freeTextFeedback,
    this.clientVersion,
    this.userAgent,
    this.schemaVersion = 1,
  });

  /// 从 [FeedbackRecord] + [HealingMusicPlan] 组装 payload。
  ///
  /// 字段映射策略：
  /// - `relaxationScore` ← `record.rating`（1-5）
  /// - `calmnessScore` ← `((1 - record.tensionAfter) * 100).round()`（0-100）
  /// - `emotionMatchScore` / `willingToContinue` ← null（M7.0 不收集）
  /// - `audioAssetId` ← 从 `plan.audio.assetPath` 提取文件名（脱敏）
  /// - `freeTextFeedback` ← `record.note`（uploader 会根据独立同意决定是否剥离）
  /// - `emotionTags` ← `plan.mood.tags`
  factory CloudFeedbackPayload.fromFeedback({
    required FeedbackRecord record,
    required HealingMusicPlan plan,
    required String clientVersion,
    String? userAgent,
  }) {
    return CloudFeedbackPayload(
      sessionId: record.sessionId,
      listeningSessionId: record.sessionId,
      createdAt: record.createdAt.toIso8601String(),
      experimentVariant: plan.variant.name,
      analyzerMode: plan.analyzerSource,
      targetState: plan.mood.targetState.name,
      emotionTags: List<String>.from(plan.mood.tags),
      valence: plan.mood.valence,
      arousal: plan.mood.arousal,
      intensity: plan.mood.intensity,
      musicTitle: plan.features.title.isEmpty ? null : plan.features.title,
      audioAssetId: _sanitizeAudioAssetId(plan.audio.assetPath),
      audioAssetTitle: plan.audio.title.isEmpty ? null : plan.audio.title,
      bpm: plan.features.bpm,
      brainwaveTarget: plan.features.brainwave.isEmpty ? null : plan.features.brainwave,
      noiseLayer: plan.features.noiseLayer.isEmpty ? null : plan.features.noiseLayer,
      relaxationScore: record.rating,
      emotionMatchScore: null,
      calmnessScore: ((1.0 - record.tensionAfter).clamp(0.0, 1.0) * 100).round(),
      willingToContinue: null,
      freeTextFeedback: record.note,
      clientVersion: clientVersion,
      userAgent: userAgent,
      source: 'web',
      schemaVersion: 1,
    );
  }

  /// 序列化为请求体 JSON（上传到 /api/submit-feedback）。
  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'listeningSessionId': listeningSessionId,
        'createdAt': createdAt,
        if (experimentVariant != null) 'experimentVariant': experimentVariant,
        if (analyzerMode != null) 'analyzerMode': analyzerMode,
        if (targetState != null) 'targetState': targetState,
        'emotionTags': emotionTags,
        if (valence != null) 'valence': valence,
        if (arousal != null) 'arousal': arousal,
        if (intensity != null) 'intensity': intensity,
        if (musicTitle != null) 'musicTitle': musicTitle,
        if (audioAssetId != null) 'audioAssetId': audioAssetId,
        if (audioAssetTitle != null) 'audioAssetTitle': audioAssetTitle,
        if (bpm != null) 'bpm': bpm,
        if (brainwaveTarget != null) 'brainwaveTarget': brainwaveTarget,
        if (noiseLayer != null) 'noiseLayer': noiseLayer,
        if (relaxationScore != null) 'relaxationScore': relaxationScore,
        if (emotionMatchScore != null) 'emotionMatchScore': emotionMatchScore,
        if (calmnessScore != null) 'calmnessScore': calmnessScore,
        if (willingToContinue != null) 'willingToContinue': willingToContinue,
        if (freeTextFeedback != null) 'freeTextFeedback': freeTextFeedback,
        if (clientVersion != null) 'clientVersion': clientVersion,
        if (userAgent != null) 'userAgent': userAgent,
        'source': source,
        'schemaVersion': schemaVersion,
      };

  /// 从 assetPath 提取脱敏文件名。
  ///
  /// 输入 `assets/music/sleep_01.mp3` → 输出 `sleep_01.mp3`
  /// 输入 `sleep_01.mp3` → 输出 `sleep_01.mp3`
  /// 输入空字符串 → 输出 null
  static String? _sanitizeAudioAssetId(String assetPath) {
    if (assetPath.isEmpty) return null;
    final normalized = assetPath.replaceAll('\\', '/');
    final lastSlash = normalized.lastIndexOf('/');
    final fileName = lastSlash >= 0 ? normalized.substring(lastSlash + 1) : normalized;
    return fileName.isEmpty ? null : fileName;
  }
}
