import 'package:xinxian_healing_music/pipeline/experiment/hash_experiment_assigner.dart';
import 'package:xinxian_healing_music/pipeline/healing_pipeline.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_mood_analyzer.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_plan_meta_resolver.dart';
import 'package:xinxian_healing_music/pipeline/mock/passthrough_post_processor.dart';
import 'package:xinxian_healing_music/pipeline/mock/rule_based_feature_extractor.dart';
import 'package:xinxian_healing_music/pipeline/mock/stock_audio_generator.dart';
import 'package:xinxian_healing_music/pipeline/ports/mood_analyzer_port.dart';

/// M8.1：是否启用消融实验分组（编译期常量，零依赖）。
///
/// 启用方式：
/// ```
/// flutter build web --release --dart-define=ENABLE_EXPERIMENT=true
/// ```
///
/// 默认 `false`，线上不传 `--dart-define` 时：
/// - [HashExperimentAssigner] 恒返回 [ExperimentVariant.custom]
/// - 用户体验与 M8 完全一致，不改变推荐结果
/// - 仅当显式传 `ENABLE_EXPERIMENT=true` 时，新会话才会按 sessionId hash
///   稳定分流到 custom / generic / control 三组（写入 D1 experimentVariant 字段）
///
/// 注意：M8.1 保守 MVP 阶段，generic / control 组仍走 custom 的完整推荐
/// 流程（不改变 [StockAudioGenerator] 与 [HealingPipeline] 推荐逻辑），
/// 真正的音频旁路留到 M8.2。
const bool experimentEnabled = bool.fromEnvironment(
  'ENABLE_EXPERIMENT',
  defaultValue: false,
);

/// 组装 mock 版 Pipeline 单例。
///
/// UI 层通过 [mockPipeline] 获取编排器；后续接入真实实现时，
/// 替换此 factory 即可热切换到真实链路，UI 代码无需改动。
///
/// 注：全局共享的 [sessionRecorder] / [feedbackRepository] 已迁移到
/// `lib/pipeline/services.dart`，由 main.dart 启动时装配 Local 或 Mock 实现。
final HealingPipeline mockPipeline = const HealingPipeline(
  moodAnalyzer: MockMoodAnalyzer(),
  featureExtractor: RuleBasedFeatureExtractor(),
  audioGenerator: StockAudioGenerator(),
  postProcessor: PassthroughPostProcessor(),
  experimentAssigner: HashExperimentAssigner(enabled: experimentEnabled),
  planMetaResolver: MockPlanMetaResolver(),
);

/// 实际运行时使用的 Pipeline。
///
/// 默认指向 [mockPipeline]（保证 `runApp` 前可用、测试无需初始化）；
/// `main.dart` 启动时会替换为带 [MoodAnalyzerGateway] 的版本，
/// 实现 LLM 解析 + 自动 fallback。
///
/// UI 层（AnalysisScreen 等）应调用 `activePipeline.run(...)`，
/// 而非直接用 [mockPipeline]，这样才能在运行时享受 LLM 网关。
HealingPipeline activePipeline = mockPipeline;

/// 用指定 analyzer 构建完整 Pipeline（其余组件保持 mock）。
///
/// 供 `main.dart` 在装配好 [MoodAnalyzerGateway] 后调用：
/// ```dart
/// activePipeline = buildPipelineWith(gateway);
/// ```
HealingPipeline buildPipelineWith(MoodAnalyzerPort analyzer) => HealingPipeline(
  moodAnalyzer: analyzer,
  featureExtractor: RuleBasedFeatureExtractor(),
  audioGenerator: StockAudioGenerator(),
  postProcessor: PassthroughPostProcessor(),
  experimentAssigner: const HashExperimentAssigner(enabled: experimentEnabled),
  planMetaResolver: MockPlanMetaResolver(),
);
