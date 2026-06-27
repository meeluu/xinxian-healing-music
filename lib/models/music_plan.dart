import 'package:xinxian_healing_music/models/audio_post_process_config.dart';
import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/models/processed_audio.dart';

/// 疗愈音乐方案（聚合根）。
///
/// 由 [HealingPipeline] 编排各阶段产出，聚合 Translation Pipeline 末端产物：
/// - [mood] 情绪画像（MoodAnalyzer 阶段产出）
/// - [features] 音乐特征标签（FeatureExtractor 阶段产出，含展示型 + 标准化字段）
/// - [audio] 后处理后的最终音频（PostProcessor 阶段产出，Player 直接消费）
/// - [postProcess] 已应用的后处理配置
/// - [variant] 实验分组（ExperimentAssigner 阶段产出）
/// - [templateName] / [durationMinutes] / [guidance] 方案元信息（PlanMetaResolver 反查）
///
/// UI 直接通过 `plan.features.*` / `plan.audio.assetPath` 访问展示字段。
class HealingMusicPlan {
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
    required this.templateName,
    required this.mood,
    required this.features,
    required this.audio,
    required this.postProcess,
    required this.variant,
    required this.durationMinutes,
    required this.guidance,
  });
}
