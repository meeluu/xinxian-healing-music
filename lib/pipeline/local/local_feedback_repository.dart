import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/pipeline/ports/feedback_repository.dart';

/// shared_preferences 本地持久化版反馈仓储。
///
/// - save 采用 upsert 语义（按 sessionId 覆盖更新），与 MockFeedbackRepository 一致。
/// - 最多保留 [_maxRecords] 条，超出按 createdAt 最旧的裁剪。
/// - 损坏 JSON 容错：[create] 不崩溃，返回空缓存起步。
class LocalFeedbackRepository implements FeedbackRepository {
  static const String key = 'xinxian.feedback';
  static const int _maxRecords = 100;

  final SharedPreferences _prefs;
  final Map<String, FeedbackRecord> _cache;

  LocalFeedbackRepository._(this._prefs, this._cache);

  /// 异步工厂：从磁盘加载缓存。损坏数据会被忽略，返回空缓存。
  static Future<LocalFeedbackRepository> create(
    SharedPreferences prefs,
  ) async {
    final cache = <String, FeedbackRecord>{};
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final f = FeedbackRecord.fromJson(item);
            cache[f.sessionId] = f;
          }
        }
      } catch (_) {
        // 损坏 JSON：忽略，空缓存起步
      }
    }
    return LocalFeedbackRepository._(prefs, cache);
  }

  @override
  Future<void> save(FeedbackRecord record) async {
    _cache[record.sessionId] = record;
    _trim();
    await _persist();
  }

  @override
  Future<List<FeedbackRecord>> all() async {
    final list = _cache.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  @override
  Future<void> delete(String sessionId) async {
    if (_cache.remove(sessionId) == null) return;
    await _persist();
  }

  @override
  Future<void> clear() async {
    _cache.clear();
    await _prefs.remove(key);
  }

  void _trim() {
    if (_cache.length <= _maxRecords) return;
    final sorted = _cache.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final f in sorted.skip(_maxRecords)) {
      _cache.remove(f.sessionId);
    }
  }

  Future<void> _persist() async {
    try {
      final list = _cache.values
          .map((f) => f.toJson())
          .toList()
        ..sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
      await _prefs.setString(key, jsonEncode(list));
    } catch (_) {
      // 落盘失败：忽略，内存缓存仍可用
    }
  }
}
