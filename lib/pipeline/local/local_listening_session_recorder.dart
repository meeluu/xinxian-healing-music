import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/listening_session.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/pipeline/local/preferences_port.dart';
import 'package:xinxian_healing_music/pipeline/ports/listening_session_recorder.dart';

/// 本地持久化版会话记录器。
///
/// 设计要点：
/// - M2 同步方法（begin / updateListening / attachFeedback / get / all）保持不变，
///   内部维护内存缓存 + 异步落盘（fire-and-forget），UI 调用点零改动。
/// - 启动时通过 [create] 异步从磁盘加载缓存；运行时读写直接命中缓存，
///   落盘失败不影响 Demo 可用性（下次启动从最近一次成功落盘的数据恢复）。
/// - 最多保留 [_maxRecords] 条，超出按 startedAt 最旧的裁剪。
/// - 损坏 JSON 容错：[create] 不崩溃，返回空缓存起步。
///
/// 底层存储由 [PreferencesPort] 抽象，正常运行时是 [SharedPrefsAdapter]
/// （包装 SharedPreferences），Web 端 SharedPreferences 插件失败时
/// 自动切换为 [WebLocalStoragePrefs]（直接用 window.localStorage）。
class LocalListeningSessionRecorder implements ListeningSessionRecorder {
  static const String key = 'xinxian.sessions';
  static const int _maxRecords = 100;

  final PreferencesPort _prefs;
  final Map<String, ListeningSession> _cache;

  LocalListeningSessionRecorder._(this._prefs, this._cache);

  /// 异步工厂：从磁盘加载缓存。损坏数据会被忽略，返回空缓存。
  static Future<LocalListeningSessionRecorder> create(
    PreferencesPort prefs,
  ) async {
    final cache = <String, ListeningSession>{};
    final raw = prefs.getString(key);
    debugPrint(
      '[M3] LocalSession.create: raw is ${raw == null ? "null" : "${raw.length} chars"}',
    );
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final s = ListeningSession.fromJson(item);
            cache[s.sessionId] = s;
          }
        }
        debugPrint('[M3] LocalSession.create: parsed ${cache.length} sessions');
      } catch (e, st) {
        debugPrint('[M3] LocalSession.create: JSON 解析失败，空缓存起步: $e');
        debugPrint('$st');
      }
    }
    return LocalListeningSessionRecorder._(prefs, cache);
  }

  // ─── M2 同步方法（保持 Port 兼容）─────────────────────────────

  @override
  void begin({
    required String sessionId,
    required String moodText,
    required HealingMusicPlan plan,
  }) {
    debugPrint(
      '[M3] LocalSession.begin: sessionId=$sessionId, cache before=${_cache.length}',
    );
    _upsert(
      ListeningSession(
        sessionId: sessionId,
        moodText: moodText,
        startedAt: DateTime.now(),
        plan: plan,
        listenedDuration: Duration.zero,
        feedback: null,
        completedAt: null,
      ),
    );
  }

  @override
  void updateListening(String sessionId, Duration listened) {
    final old = _cache[sessionId];
    if (old == null) return;
    _upsert(old.copyWith(listenedDuration: listened));
  }

  @override
  void attachFeedback(String sessionId, FeedbackRecord record) {
    final old = _cache[sessionId];
    if (old == null) return;
    _upsert(old.copyWith(feedback: record, completedAt: DateTime.now()));
  }

  @override
  ListeningSession? get(String sessionId) => _cache[sessionId];

  @override
  List<ListeningSession> all() {
    final list = _cache.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return List.unmodifiable(list);
  }

  // ─── M3 新增：删除 / 清空 ─────────────────────────────────────

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

  // ─── 内部：更新缓存 + 裁剪 + 异步落盘 ─────────────────────────

  void _upsert(ListeningSession session) {
    _cache[session.sessionId] = session;
    _trim();
    _persist(); // fire-and-forget
  }

  void _trim() {
    if (_cache.length <= _maxRecords) return;
    final sorted = _cache.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    for (final s in sorted.skip(_maxRecords)) {
      _cache.remove(s.sessionId);
    }
  }

  Future<void> _persist() async {
    try {
      final list = all().map((s) => s.toJson()).toList();
      final encoded = jsonEncode(list);
      debugPrint(
        '[M3] LocalSession._persist: 写入 ${list.length} 条, JSON ${encoded.length} chars, key=$key',
      );
      await _prefs.setString(key, encoded);
      debugPrint('[M3] LocalSession._persist: setString 完成');
    } catch (e, st) {
      debugPrint('[M3] LocalSession._persist: 落盘失败: $e');
      debugPrint('$st');
    }
  }
}
