import 'package:xinxian_healing_music/models/mood_profile.dart';

/// LLM 情绪画像 → 音乐方案的中间聚合草稿（M5 新增）。
///
/// 由 [EmotionToMusicPlanMapper] 根据完整 [MoodProfile] 生成，
/// 携带音乐方案的全部展示型字段与生成提示词。
///
/// Pipeline 各阶段从本草稿提取所需字段：
/// - [RuleBasedFeatureExtractor] → [MusicFeatureTags]
/// - [MockPlanMetaResolver] → [PlanMeta]
/// - [StockAudioGenerator] → [GeneratedAudio.generationParams]
///
/// 本草稿不直接持久化（持久化通过 [MusicFeatureTags.toJson] 完成），
/// 也不直接被 UI 引用（UI 通过 [HealingMusicPlan] 聚合根访问）。
class MusicPlanDraft {
  /// 方案标题，例如 "睡前舒缓 · Theta 入眠方案"
  final String title;

  /// 模板名（兼容旧字段，与 [title] 语义可重合）
  final String templateName;

  /// BPM 范围字符串，例如 "45-60"
  final String bpmRange;

  /// 基准 BPM（已根据 arousal 调整后的具体值）
  final int bpm;

  /// 基准频率，例如 "432Hz"
  final String baseFrequency;

  /// 脑波倾向，例如 "Theta / Delta 入睡倾向"
  final String brainwaveTarget;

  /// 推荐乐器列表
  final List<String> instruments;

  /// 噪音层，例如 "雨声 / 粉红噪音"
  final String noiseLayer;

  /// 和声色彩，例如 "低明度小调 → 温暖大调"
  final String harmonyColor;

  /// 生成模型提示词（M5 仅文本，不接真实生成模型）
  final String generationPrompt;

  /// 面向用户的方案解释文案
  final String explanation;

  /// 引导语（沿用旧字段语义，供 UI 展示）
  final String guidance;

  /// 本地音频素材路径（M5 仍用预置素材，M6 可扩展多音频）
  final String audioAssetPath;

  /// 推荐时长（分钟）
  final int durationMinutes;

  /// 标准化字段：情绪强度
  final double intensity;

  /// 标准化字段：唤醒度
  final double arousal;

  /// 标准化字段：效价
  final double valence;

  /// 标准化字段：目标调节状态
  final TargetState targetState;

  const MusicPlanDraft({
    required this.title,
    required this.templateName,
    required this.bpmRange,
    required this.bpm,
    required this.baseFrequency,
    required this.brainwaveTarget,
    required this.instruments,
    required this.noiseLayer,
    required this.harmonyColor,
    required this.generationPrompt,
    required this.explanation,
    required this.guidance,
    required this.audioAssetPath,
    required this.durationMinutes,
    required this.intensity,
    required this.arousal,
    required this.valence,
    required this.targetState,
  });
}
