import 'package:xinxian_healing_music/pipeline/llm/llm_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/llm/mood_analyzer_gateway.dart';
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

/// M4B: LLM 同意状态服务。
///
/// 默认 null（保证 `runApp` 前可用）；`main.dart` 启动时装配
/// shared_preferences 持久化实现。UI 层应判空后使用。
LlmConsentService? llmConsentService;

/// M4B: 情绪解析网关单例。
///
/// 默认 null（保证 `runApp` 前可用）；`main.dart` 启动时装配
/// LLM + Mock 组合实现。UI 层一般不直接调用，由 [activePipeline] 持有。
MoodAnalyzerGateway? moodAnalyzerGateway;

/// 启动自检状态：SharedPreferences 是否装配成功。
///
/// 由 `main.dart` 的 `bootstrapServices()` 写入，UI 层只读。
/// 用于"关于"对话框展示当前运行时存储状态。null 表示尚未启动装配。
bool? sharedPrefsReady;

/// 启动自检状态：是否启用了 Web localStorage fallback。
///
/// 由 `main.dart` 的 `bootstrapServices()` 写入，UI 层只读。
/// true 表示 SharedPreferences 失败后回退到 dart:html window.localStorage。
bool? webLocalStorageFallback;
