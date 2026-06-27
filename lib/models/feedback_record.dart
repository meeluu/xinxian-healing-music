/// 用户反馈记录。
class FeedbackRecord {
  /// 会话 ID
  final String sessionId;

  /// 整体体验评分（1..5）
  final int rating;

  /// 体验前紧绷度（0..1）
  final double tensionBefore;

  /// 体验后紧绷度（0..1）
  final double tensionAfter;

  /// 文字反馈（可空）
  final String? note;

  /// 是否完整听完
  final bool completed;

  /// 提交时间
  final DateTime createdAt;

  const FeedbackRecord({
    required this.sessionId,
    required this.rating,
    required this.tensionBefore,
    required this.tensionAfter,
    this.note,
    this.completed = false,
    required this.createdAt,
  });
}
