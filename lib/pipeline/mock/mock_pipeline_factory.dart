import 'package:xinxian_healing_music/pipeline/healing_pipeline.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_experiment_assigner.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_feedback_repository.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_mood_analyzer.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_plan_meta_resolver.dart';
import 'package:xinxian_healing_music/pipeline/mock/passthrough_post_processor.dart';
import 'package:xinxian_healing_music/pipeline/mock/rule_based_feature_extractor.dart';
import 'package:xinxian_healing_music/pipeline/mock/stock_audio_generator.dart';

/// 组装 mock 版 Pipeline 单例。
///
/// UI 层通过 [mockPipeline] 获取编排器；后续接入真实实现时，
/// 替换此 factory 即可热切换到真实链路，UI 代码无需改动。
final HealingPipeline mockPipeline = const HealingPipeline(
  moodAnalyzer: MockMoodAnalyzer(),
  featureExtractor: RuleBasedFeatureExtractor(),
  audioGenerator: StockAudioGenerator(),
  postProcessor: PassthroughPostProcessor(),
  experimentAssigner: MockExperimentAssigner(),
  planMetaResolver: MockPlanMetaResolver(),
);

/// 全局共享的反馈仓储单例（供 FeedbackScreen 写入）。
final MockFeedbackRepository mockFeedbackRepository = MockFeedbackRepository();
