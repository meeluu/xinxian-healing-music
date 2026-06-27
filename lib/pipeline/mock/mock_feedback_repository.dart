import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/pipeline/ports/feedback_repository.dart';

/// 内存版反馈仓储：保存到内存 Map，重启后丢失。
///
/// M1 阶段使用；M3 起作为本地持久化失败时的降级回退实现。
/// save 采用 upsert 语义（按 sessionId 覆盖更新），与 LocalFeedbackRepository 一致。
class MockFeedbackRepository implements FeedbackRepository {
  final Map<String, FeedbackRecord> _store = {};

  @override
  Future<void> save(FeedbackRecord record) async {
    _store[record.sessionId] = record;
  }

  @override
  Future<List<FeedbackRecord>> all() async {
    final list = _store.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  @override
  Future<void> delete(String sessionId) async {
    _store.remove(sessionId);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }
}
