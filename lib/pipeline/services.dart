import 'package:xinxian_healing_music/pipeline/mock/mock_feedback_repository.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_listening_session_recorder.dart';
import 'package:xinxian_healing_music/pipeline/ports/feedback_repository.dart';
import 'package:xinxian_healing_music/pipeline/ports/listening_session_recorder.dart';

/// 全局共享的会话记录器单例。
///
/// 默认指向内存态 mock 实现（保证 `runApp` 前可用）；
/// `main.dart` 启动时会尝试装配 shared_preferences 本地持久化实现，
/// 失败时（隐私模式 / 平台不支持）保持 mock，Demo 仍可用。
///
/// UI 调用点只依赖此抽象 [ListeningSessionRecorder]，不关心具体实现，
/// 未来切换到云端实现时同样只需在此替换。
ListeningSessionRecorder sessionRecorder = MockListeningSessionRecorder();

/// 全局共享的反馈仓储单例（语义同 [sessionRecorder]）。
FeedbackRepository feedbackRepository = MockFeedbackRepository();
