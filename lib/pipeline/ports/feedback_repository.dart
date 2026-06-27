import 'package:xinxian_healing_music/models/feedback_record.dart';

/// 反馈仓储 Port。
///
/// M1 阶段 mock 实现使用内存 List；后续可替换为真实数据库 / 远端服务。
abstract class FeedbackRepository {
  Future<void> save(FeedbackRecord record);

  Future<List<FeedbackRecord>> all();
}
