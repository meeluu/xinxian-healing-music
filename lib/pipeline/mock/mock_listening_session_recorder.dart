import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/listening_session.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/pipeline/ports/listening_session_recorder.dart';

/// 内存版会话记录器：保存到内存 Map，重启后丢失。
///
/// M2 阶段使用；后续可替换为真实数据库 / 远端服务实现。
class MockListeningSessionRecorder implements ListeningSessionRecorder {
  final Map<String, _State> _store = {};

  @override
  void begin({
    required String sessionId,
    required String moodText,
    required HealingMusicPlan plan,
  }) {
    _store[sessionId] = _State(
      sessionId: sessionId,
      moodText: moodText,
      startedAt: DateTime.now(),
      plan: plan,
      listenedDuration: Duration.zero,
      feedback: null,
      completedAt: null,
    );
  }

  @override
  void updateListening(String sessionId, Duration listened) {
    final s = _store[sessionId];
    if (s == null) return;
    _store[sessionId] = s.copyWith(listenedDuration: listened);
  }

  @override
  void attachFeedback(String sessionId, FeedbackRecord record) {
    final s = _store[sessionId];
    if (s == null) return;
    _store[sessionId] = s.copyWith(
      feedback: record,
      completedAt: DateTime.now(),
    );
  }

  @override
  ListeningSession? get(String sessionId) => _store[sessionId]?.toSession();

  @override
  List<ListeningSession> all() {
    final list = _store.values.map((s) => s.toSession()).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return List.unmodifiable(list);
  }
}

/// 可变中间态：get / all 时构造不可变 [ListeningSession]。
class _State {
  final String sessionId;
  final String moodText;
  final DateTime startedAt;
  final HealingMusicPlan plan;
  final Duration listenedDuration;
  final FeedbackRecord? feedback;
  final DateTime? completedAt;

  const _State({
    required this.sessionId,
    required this.moodText,
    required this.startedAt,
    required this.plan,
    required this.listenedDuration,
    this.feedback,
    this.completedAt,
  });

  _State copyWith({
    Duration? listenedDuration,
    FeedbackRecord? feedback,
    DateTime? completedAt,
  }) {
    return _State(
      sessionId: sessionId,
      moodText: moodText,
      startedAt: startedAt,
      plan: plan,
      listenedDuration: listenedDuration ?? this.listenedDuration,
      feedback: feedback ?? this.feedback,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  ListeningSession toSession() => ListeningSession(
        sessionId: sessionId,
        moodText: moodText,
        startedAt: startedAt,
        plan: plan,
        listenedDuration: listenedDuration,
        feedback: feedback,
        completedAt: completedAt,
      );
}
