import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';

/// 一次完整的聆听会话聚合。
///
/// 由 [ListeningSessionRecorder] 在 UI 层装配：会话开始（plan 产出）→
/// 聆听进度更新（播放页 dispose）→ 反馈关联（反馈页提交）。
/// M3 起支持 shared_preferences 本地持久化（最多 100 条），刷新页面或重开浏览器后保留。
class ListeningSession {
  /// 当前数据结构版本，用于未来字段迁移
  static const int currentSchemaVersion = 1;

  /// 会话 ID（与 MoodInput.sessionId / HealingMusicPlan.sessionId / FeedbackRecord.sessionId 一致）
  final String sessionId;

  /// 用户输入的心境原文
  final String moodText;

  /// 会话开始时间（plan 产出时刻）
  final DateTime startedAt;

  /// 疗愈方案快照（含 mood / features / audio / variant）
  final HealingMusicPlan plan;

  /// 已聆听时长
  final Duration listenedDuration;

  /// 关联的用户反馈（未提交时为 null）
  final FeedbackRecord? feedback;

  /// 会话完成时间（反馈提交时标记）
  final DateTime? completedAt;

  const ListeningSession({
    required this.sessionId,
    required this.moodText,
    required this.startedAt,
    required this.plan,
    this.listenedDuration = Duration.zero,
    this.feedback,
    this.completedAt,
  });

  /// 实验分组（来自 plan.variant，供后续消融分析按分组筛选）
  ExperimentVariant get variant => plan.variant;

  /// 不可变更新：便于 Local 实现直接更新字段而无需中间态。
  ListeningSession copyWith({
    Duration? listenedDuration,
    FeedbackRecord? feedback,
    DateTime? completedAt,
  }) => ListeningSession(
    sessionId: sessionId,
    moodText: moodText,
    startedAt: startedAt,
    plan: plan,
    listenedDuration: listenedDuration ?? this.listenedDuration,
    feedback: feedback ?? this.feedback,
    completedAt: completedAt ?? this.completedAt,
  );

  /// 序列化为 JSON 友好的 Map（供 shared_preferences 持久化）。
  Map<String, dynamic> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'sessionId': sessionId,
    'moodText': moodText,
    'startedAt': startedAt.toIso8601String(),
    'plan': plan.toJson(),
    'listenedDurationMs': listenedDuration.inMilliseconds,
    'feedback': feedback?.toJson(),
    'completedAt': completedAt?.toIso8601String(),
  };

  /// 从 Map 反序列化；缺字段用默认值，保证旧版本数据兼容。
  static ListeningSession fromJson(Map<String, dynamic> json) =>
      ListeningSession(
        sessionId: json['sessionId'] as String? ?? '',
        moodText: json['moodText'] as String? ?? '',
        startedAt: json['startedAt'] is String
            ? DateTime.tryParse(json['startedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        plan: json['plan'] is Map<String, dynamic>
            ? HealingMusicPlan.fromJson(json['plan'] as Map<String, dynamic>)
            : HealingMusicPlan.fromJson(const {}),
        listenedDuration: Duration(
          milliseconds: (json['listenedDurationMs'] as num?)?.toInt() ?? 0,
        ),
        feedback: json['feedback'] is Map
            ? FeedbackRecord.fromJson(json['feedback'] as Map<String, dynamic>)
            : null,
        completedAt: json['completedAt'] is String
            ? DateTime.tryParse(json['completedAt'] as String)
            : null,
      );
}
