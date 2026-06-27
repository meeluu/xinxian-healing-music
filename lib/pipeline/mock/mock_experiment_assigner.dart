import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/pipeline/ports/experiment_assigner.dart';

/// Mock 实验分组分配器：恒返回 [ExperimentVariant.custom]。
///
/// M1 阶段不启用消融实验；后续真实分配会按策略（随机 / 分层）分组。
class MockExperimentAssigner implements ExperimentAssigner {
  const MockExperimentAssigner();

  @override
  ExperimentVariant assign(MoodInput input) => ExperimentVariant.custom;
}
