import 'package:xinxian_healing_music/models/feedback_record.dart';

/// 反馈仓储 Port。
///
/// M1 阶段 mock 实现使用内存 List；M3 起提供 shared_preferences 本地持久化实现；
/// 后续可替换为真实数据库 / 远端服务。
abstract class FeedbackRepository {
  /// 保存（upsert 语义：同 sessionId 覆盖更新）。
  Future<void> save(FeedbackRecord record);

  /// 全部反馈（按 createdAt 倒序）。
  Future<List<FeedbackRecord>> all();

  /// M3 新增：删除单条反馈（按 sessionId）。
  Future<void> delete(String sessionId);

  /// M3 新增：清空全部反馈。
  Future<void> clear();
}
