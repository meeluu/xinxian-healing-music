import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/listening_session.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';

/// 聆听会话记录器 Port。
///
/// 负责一次完整会话（输入 → 解析 → 方案 → 播放 → 反馈）的生命周期记录，
/// 供后续消融实验与用户反馈数据库使用。
///
/// M2 阶段 mock 实现使用内存 Map，重启丢失；后续可替换为真实数据库实现，
/// UI 调用点（AnalysisScreen / PlayerScreen / FeedbackScreen）无需改动。
abstract class ListeningSessionRecorder {
  /// 会话开始：plan 产出后调用，记录 moodText 与 plan 快照。
  void begin({
    required String sessionId,
    required String moodText,
    required HealingMusicPlan plan,
  });

  /// 更新聆听进度（由播放页在 dispose 等时机上报）。
  void updateListening(String sessionId, Duration listened);

  /// 关联反馈记录并标记会话完成时间。
  void attachFeedback(String sessionId, FeedbackRecord record);

  /// 获取单个会话（不存在返回 null）。
  ListeningSession? get(String sessionId);

  /// 全部会话（按开始时间倒序）。
  List<ListeningSession> all();
}
