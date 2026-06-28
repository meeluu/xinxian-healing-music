import 'package:xinxian_healing_music/pipeline/healing_pipeline.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_experiment_assigner.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_mood_analyzer.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_plan_meta_resolver.dart';
import 'package:xinxian_healing_music/pipeline/mock/passthrough_post_processor.dart';
import 'package:xinxian_healing_music/pipeline/mock/rule_based_feature_extractor.dart';
import 'package:xinxian_healing_music/pipeline/mock/stock_audio_generator.dart';
import 'package:xinxian_healing_music/pipeline/ports/mood_analyzer_port.dart';

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
  experimentAssigner: MockExperimentAssigner(),
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
  experimentAssigner: MockExperimentAssigner(),
  planMetaResolver: MockPlanMetaResolver(),
);
