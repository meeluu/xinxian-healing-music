import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/pipeline/llm/llm_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_mood_analyzer.dart';
import 'package:xinxian_healing_music/pipeline/ports/mood_analyzer_port.dart';

/// 情绪解析网关：组合 LLM + Mock，按同意状态自动 fallback。
///
/// 决策逻辑：
/// - 同意状态 = accepted → 调用 LLM analyzer
///   - 成功 → [lastSource] = 'llm'
///   - 失败 → fallback MockMoodAnalyzer，[lastSource] = 'fallback'
/// - 同意状态 = unknown / declined → 直接用 MockMoodAnalyzer，[lastSource] = 'mock'
///
/// [lastSource] / [currentSource] 供 HealingPipeline 写入
/// HealingMusicPlan.analyzerSource。
///
/// 注：[llmAnalyzer] 用 [MoodAnalyzerPort] 类型而非 [LlmMoodAnalyzer] 具体类型，
/// 方便测试时注入 fake analyzer。
class MoodAnalyzerGateway implements MoodAnalyzerPort {
  final MoodAnalyzerPort llmAnalyzer;
  final MockMoodAnalyzer mockAnalyzer;
  final LlmConsentService consentService;

  String _lastSource = 'mock';

  MoodAnalyzerGateway({
    required this.llmAnalyzer,
    required this.mockAnalyzer,
    required this.consentService,
  });

  /// 最近一次解析的来源：'mock' / 'llm' / 'fallback'。
  String get lastSource => _lastSource;

  @override
  String get currentSource => _lastSource;

  @override
  Future<MoodProfile> analyze(MoodInput input) async {
    // 未同意或已拒绝 → 直接走本地解析
    if (!consentService.isAccepted) {
      _lastSource = 'mock';
      return mockAnalyzer.analyze(input);
    }

    // 已同意 → 尝试 LLM，失败静默 fallback
    try {
      final profile = await llmAnalyzer.analyze(input);
      _lastSource = 'llm';
      return profile;
    } catch (_) {
      // 任何 LLM 错误都不中断主流程，自动降级到本地解析
      _lastSource = 'fallback';
      return mockAnalyzer.analyze(input);
    }
  }
}
