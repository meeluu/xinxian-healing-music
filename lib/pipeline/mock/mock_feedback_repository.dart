import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/pipeline/ports/feedback_repository.dart';

/// 内存版反馈仓储：保存到内存 List，重启后丢失。
///
/// M1 阶段使用；后续可替换为真实数据库 / 远端服务实现。
class MockFeedbackRepository implements FeedbackRepository {
  final List<FeedbackRecord> _store = [];

  @override
  Future<void> save(FeedbackRecord record) async {
    _store.add(record);
  }

  @override
  Future<List<FeedbackRecord>> all() async {
    return List.unmodifiable(_store);
  }
}
