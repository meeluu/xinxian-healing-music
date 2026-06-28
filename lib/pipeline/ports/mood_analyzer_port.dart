import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';

/// 情绪解析 Port：自然语言 → 情绪画像。
///
/// UI 层只依赖此抽象，具体实现（mock / 真实 LLM）在 Pipeline 装配时注入。
abstract class MoodAnalyzerPort {
  Future<MoodProfile> analyze(MoodInput input);

  /// 最近一次解析的来源标识：'mock' / 'llm' / 'fallback'。
  /// 供 HealingPipeline 写入 HealingMusicPlan.analyzerSource 持久化。
  /// 默认 'mock'，[MoodAnalyzerGateway] 会按实际路径覆盖。
  String get currentSource => 'mock';
}
