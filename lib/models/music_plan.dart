import 'package:xinxian_healing_music/models/audio_post_process_config.dart';
import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/models/processed_audio.dart';

/// 疗愈音乐方案（聚合根）。
///
/// 由 [HealingPipeline] 编排各阶段产出，聚合 Translation Pipeline 末端产物：
/// - [sessionId] 会话 ID（与 MoodInput.sessionId 一致，贯穿会话生命周期）
/// - [mood] 情绪画像（MoodAnalyzer 阶段产出）
/// - [features] 音乐特征标签（FeatureExtractor 阶段产出，含展示型 + 标准化字段）
/// - [audio] 后处理后的最终音频（PostProcessor 阶段产出，Player 直接消费）
/// - [postProcess] 已应用的后处理配置
/// - [variant] 实验分组（ExperimentAssigner 阶段产出）
/// - [templateName] / [durationMinutes] / [guidance] 方案元信息（PlanMetaResolver 反查）
///
/// UI 直接通过 `plan.features.*` / `plan.audio.assetPath` 访问展示字段。
class HealingMusicPlan {
  /// 会话 ID（由 HealingPipeline.run 生成，与 MoodInput.sessionId 一致）
  final String sessionId;

  /// 模板名称，例如 "高压焦虑型"
  final String templateName;

  /// 对应的情绪画像
  final MoodProfile mood;

  /// 音乐特征标签（bpm / frequency / brainwave / instruments / harmony / noiseLayer 等）
  final MusicFeatureTags features;

  /// 后处理后的最终音频（含 assetPath）
  final ProcessedAudio audio;

  /// 已应用的后处理配置
  final AudioPostProcessConfig postProcess;

  /// 实验分组
  final ExperimentVariant variant;

  /// 推荐时长（分钟）
  final int durationMinutes;

  /// 疗愈引导语
  final String guidance;

  const HealingMusicPlan({
    required this.sessionId,
    required this.templateName,
    required this.mood,
    required this.features,
    required this.audio,
    required this.postProcess,
    required this.variant,
    required this.durationMinutes,
    required this.guidance,
  });

  /// 序列化为 JSON 友好的 Map（供 shared_preferences 持久化）。
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'templateName': templateName,
    'mood': mood.toJson(),
    'features': features.toJson(),
    'audio': audio.toJson(),
    'postProcess': postProcess.toJson(),
    'variant': variant.name,
    'durationMinutes': durationMinutes,
    'guidance': guidance,
  };

  /// 从 Map 反序列化；缺字段用默认值，保证旧版本数据兼容。
  static HealingMusicPlan fromJson(Map<String, dynamic> json) =>
      HealingMusicPlan(
        sessionId: json['sessionId'] as String? ?? '',
        templateName: json['templateName'] as String? ?? '',
        mood: json['mood'] is Map<String, dynamic>
            ? MoodProfile.fromJson(json['mood'] as Map<String, dynamic>)
            : MoodProfile.fromJson(const {}),
        features: json['features'] is Map<String, dynamic>
            ? MusicFeatureTags.fromJson(
                json['features'] as Map<String, dynamic>,
              )
            : MusicFeatureTags.fromJson(const {}),
        audio: json['audio'] is Map<String, dynamic>
            ? ProcessedAudio.fromJson(json['audio'] as Map<String, dynamic>)
            : ProcessedAudio.fromJson(const {}),
        postProcess: json['postProcess'] is Map<String, dynamic>
            ? AudioPostProcessConfig.fromJson(
                json['postProcess'] as Map<String, dynamic>,
              )
            : AudioPostProcessConfig.fromJson(const {}),
        variant: ExperimentVariant.fromName(json['variant'] as String?),
        durationMinutes: json['durationMinutes'] as int? ?? 12,
        guidance: json['guidance'] as String? ?? '',
      );
}
