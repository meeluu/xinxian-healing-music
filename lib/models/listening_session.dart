import 'package:xinxian_healing_music/models/feedback_record.dart';

/// 一次完整的聆听会话聚合（M3 阶段使用，M1 仅声明占位，对齐 Pipeline 末端）。
class ListeningSession {
  /// 会话 ID
  final String sessionId;

  /// 用户输入的心境原文
  final String moodText;

  /// 命中的方案模板名称
  final String planTemplateName;

  /// 最终播放的音频资源路径
  final String audioAssetPath;

  /// 已聆听时长（可空，未完成时为 null）
  final Duration? listenedDuration;

  /// 关联的用户反馈（可空，未提交时为 null）
  final FeedbackRecord? feedback;

  const ListeningSession({
    required this.sessionId,
    required this.moodText,
    required this.planTemplateName,
    required this.audioAssetPath,
    this.listenedDuration,
    this.feedback,
  });
}
