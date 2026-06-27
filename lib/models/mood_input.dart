/// 自然语言输入的封装，作为 Translation Pipeline 的入口参数。
class MoodInput {
  /// 会话 ID（由 HealingPipeline.run 入口生成，贯穿整个会话生命周期）
  final String sessionId;

  /// 用户描述的心境原文
  final String text;

  /// 输入时间戳
  final DateTime timestamp;

  const MoodInput({
    required this.sessionId,
    required this.text,
    required this.timestamp,
  });
}
