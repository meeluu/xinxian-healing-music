/// 情绪画像模型。
///
/// 由 [MoodAnalyzerPort] 输出，作为后续 [MusicFeatureExtractorPort] 的输入。
/// Demo 用本地 mock：由关键词匹配推得，不接真实 LLM。
class MoodProfile {
  /// 情绪标签，例如 ["焦虑", "紧绷", "思绪过载"]
  final List<String> tags;

  /// 效价（valence）：-1.0 偏消极 .. 1.0 偏积极
  final double valence;

  /// 唤醒度（arousal）：0.0 偏平静 .. 1.0 偏激越
  final double arousal;

  /// 一句话情绪摘要
  final String summary;

  /// 情绪强度（0..1），表示当前情绪的强烈程度
  final double intensity;

  /// 期望调节到的目标状态
  final TargetState targetState;

  /// 主导需求（自然语言描述，可空），例如 "快速入眠"、"情绪降温"
  final String? dominantNeed;

  const MoodProfile({
    required this.tags,
    required this.valence,
    required this.arousal,
    required this.summary,
    this.intensity = 0.5,
    this.targetState = TargetState.relax,
    this.dominantNeed,
  });

  /// 序列化为 JSON 友好的 Map（供 shared_preferences 持久化）。
  Map<String, dynamic> toJson() => {
    'tags': tags,
    'valence': valence,
    'arousal': arousal,
    'summary': summary,
    'intensity': intensity,
    'targetState': targetState.name,
    if (dominantNeed != null) 'dominantNeed': dominantNeed,
  };

  /// 从 Map 反序列化；缺字段用默认值，保证旧版本数据兼容。
  static MoodProfile fromJson(Map<String, dynamic> json) => MoodProfile(
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    valence: (json['valence'] as num?)?.toDouble() ?? 0.0,
    arousal: (json['arousal'] as num?)?.toDouble() ?? 0.4,
    summary: json['summary'] as String? ?? '',
    intensity: (json['intensity'] as num?)?.toDouble() ?? 0.5,
    targetState: TargetState.fromName(json['targetState'] as String?),
    dominantNeed: json['dominantNeed'] as String?,
  );
}

/// 期望调节到的目标状态。
enum TargetState {
  /// 辅助放松（M1-M4 旧值，向后兼容；M5 mapper 内部当作 regulate 处理）
  relax,

  /// 睡前舒缓
  sleep,

  /// 专注聚焦
  focus,

  /// 正念陪伴（M1-M4 旧值，向后兼容；M5 mapper 内部当作 soothe 处理）
  company,

  /// 情绪调节
  regulate,

  /// 自我安抚、情绪陪伴（M5 新增）
  soothe,

  /// 温和恢复能量（M5 新增）
  energize;

  /// 按 name 反序列化；未知值回退到 [relax]。
  static TargetState fromName(String? name) {
    for (final v in TargetState.values) {
      if (v.name == name) return v;
    }
    return TargetState.relax;
  }
}
