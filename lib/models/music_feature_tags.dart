import 'package:xinxian_healing_music/models/mood_profile.dart';

/// 音乐特征标签集合。
///
/// 承载两层数据：
/// - 展示型字段（中文字符串，供 UI 直接显示）
/// - 标准化字段（[intensity] / [arousal] / [valence] / [targetRegulationState]，
///   供下游模型/实验使用，M1 阶段 UI 不渲染这些字段）
class MusicFeatureTags {
  /// 推荐节拍 BPM
  final int bpm;

  /// 基准频率，例如 '432Hz'
  final String frequency;

  /// 脑波倾向，例如 'Alpha 助松'
  final String brainwave;

  /// 推荐乐器
  final List<String> instruments;

  /// 和声色彩，例如 '小调 → 缓和过渡'
  final String harmony;

  /// 噪声层，例如 '粉噪' / '雨声'
  final String noiseLayer;

  /// 推荐时长（分钟）
  final int durationMinutes;

  /// 标准化：情绪强度（0..1）
  final double intensity;

  /// 标准化：唤醒度（0..1）
  final double arousal;

  /// 标准化：效价（-1..1）
  final double valence;

  /// 标准化：目标调节状态
  final TargetState targetRegulationState;

  const MusicFeatureTags({
    required this.bpm,
    required this.frequency,
    required this.brainwave,
    required this.instruments,
    required this.harmony,
    required this.noiseLayer,
    required this.durationMinutes,
    this.intensity = 0.5,
    this.arousal = 0.4,
    this.valence = 0.0,
    this.targetRegulationState = TargetState.relax,
  });

  /// 序列化为 JSON 友好的 Map（供 shared_preferences 持久化）。
  Map<String, dynamic> toJson() => {
    'bpm': bpm,
    'frequency': frequency,
    'brainwave': brainwave,
    'instruments': instruments,
    'harmony': harmony,
    'noiseLayer': noiseLayer,
    'durationMinutes': durationMinutes,
    'intensity': intensity,
    'arousal': arousal,
    'valence': valence,
    'targetRegulationState': targetRegulationState.name,
  };

  /// 从 Map 反序列化；缺字段用默认值，保证旧版本数据兼容。
  static MusicFeatureTags fromJson(Map<String, dynamic> json) =>
      MusicFeatureTags(
        bpm: json['bpm'] as int? ?? 60,
        frequency: json['frequency'] as String? ?? '432Hz',
        brainwave: json['brainwave'] as String? ?? '',
        instruments: (json['instruments'] as List?)?.cast<String>() ?? const [],
        harmony: json['harmony'] as String? ?? '',
        noiseLayer: json['noiseLayer'] as String? ?? '',
        durationMinutes: json['durationMinutes'] as int? ?? 12,
        intensity: (json['intensity'] as num?)?.toDouble() ?? 0.5,
        arousal: (json['arousal'] as num?)?.toDouble() ?? 0.4,
        valence: (json['valence'] as num?)?.toDouble() ?? 0.0,
        targetRegulationState: TargetState.fromName(
          json['targetRegulationState'] as String?,
        ),
      );
}
