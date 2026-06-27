/// 情绪画像模型。
///
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

  const MoodProfile({
    required this.tags,
    required this.valence,
    required this.arousal,
    required this.summary,
  });
}
