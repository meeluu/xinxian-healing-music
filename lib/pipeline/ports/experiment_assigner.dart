import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/mood_input.dart';

/// 实验分组分配 Port：根据输入决定本次会话的实验分组。
abstract class ExperimentAssigner {
  ExperimentVariant assign(MoodInput input);
}
