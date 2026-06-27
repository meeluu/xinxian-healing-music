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

  /// 序列化为 JSON 友好的 Map（供 shared_preferences 持久化）。
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'rating': rating,
    'tensionBefore': tensionBefore,
    'tensionAfter': tensionAfter,
    if (note != null) 'note': note,
    'completed': completed,
    'createdAt': createdAt.toIso8601String(),
  };

  /// 从 Map 反序列化；缺字段用默认值，保证旧版本数据兼容。
  static FeedbackRecord fromJson(Map<String, dynamic> json) => FeedbackRecord(
    sessionId: json['sessionId'] as String? ?? '',
    rating: (json['rating'] as num?)?.toInt() ?? 0,
    tensionBefore: (json['tensionBefore'] as num?)?.toDouble() ?? 0.5,
    tensionAfter: (json['tensionAfter'] as num?)?.toDouble() ?? 0.5,
    note: json['note'] as String?,
    completed: json['completed'] as bool? ?? false,
    createdAt: json['createdAt'] is String
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
}
