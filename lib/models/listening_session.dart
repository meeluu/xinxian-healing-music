import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';

/// 一次完整的聆听会话聚合。
///
/// 由 [ListeningSessionRecorder] 在 UI 层装配：会话开始（plan 产出）→
/// 聆听进度更新（播放页 dispose）→ 反馈关联（反馈页提交）。
/// M2 阶段为内存态，重启丢失；后续可替换为数据库持久化，UI 代码无需改动。
class ListeningSession {
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
}
