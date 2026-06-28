import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/pipeline/intent/target_state_resolver.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_template_registry.dart';
import 'package:xinxian_healing_music/pipeline/ports/mood_analyzer_port.dart';

/// Mock 情绪解析器。
///
/// 用关键词命中数选模板，命中最多者胜出；无命中则走"平衡调和型"。
/// 逻辑迁自旧 `services/mood_analyzer.dart`，输出由 [HealingMusicPlan]
/// 收窄为 [MoodProfile]，对齐 Translation Pipeline 分层。
///
/// M6.1：模板匹配后，调用 [TargetStateResolver] 用用户原文修正 targetState，
/// 解决"专注学习""不想睡""运动后很空"等模板无法覆盖的意图。
/// valence/arousal/tags/summary 仍来自模板（保证 M5 行为一致）。
class MockMoodAnalyzer implements MoodAnalyzerPort {
  const MockMoodAnalyzer();

  @override
  String get currentSource => 'mock';

  @override
  Future<MoodProfile> analyze(MoodInput input) async {
    final rules = <(List<String>, String)>[
      (
        const [
          '备考',
          '压力',
          '焦虑',
          '紧张',
          '焦躁',
          'deadline',
          '考试',
          '压力大',
          'kpi',
          '加班',
        ],
        'highPressure',
      ),
      (
        const ['失眠', '睡不着', '停不下来', '入睡', '睡眠', '辗转', '脑子', '胡思乱想', '夜醒'],
        'insomnia',
      ),
      (
        const ['悲伤', '低落', '失落', '难过', '想哭', '沮丧', 'emo', '抑郁', '孤独', '空虚'],
        'lowMood',
      ),
      (
        const ['愤怒', '烦躁', '火大', '生气', '气死', '烦', '暴', '吵架', '冲突', '委屈'],
        'agitated',
      ),
      (const ['疲惫', '累', '耗尽', '无力', '精疲力', '虚', '倦', '透支', '麻木'], 'exhausted'),
    ];

    String bestKey = 'balanced';
    int bestHits = 0;
    for (final (keywords, key) in rules) {
      int hits = 0;
      for (final kw in keywords) {
        if (input.text.contains(kw)) hits++;
      }
      if (hits > bestHits) {
        bestHits = hits;
        bestKey = key;
      }
    }

    final template = MockTemplateRegistry.moodForKey(bestKey);

    // M6.1：用原文 + tags 修正 targetState，覆盖模板的原始 targetState
    final resolvedTarget = TargetStateResolver.resolve(
      text: input.text,
      tags: template.tags,
      valence: template.valence,
      arousal: template.arousal,
      llmTargetState: template.targetState,
    );

    return MoodProfile(
      tags: template.tags,
      valence: template.valence,
      arousal: template.arousal,
      summary: template.summary,
      intensity: template.intensity,
      targetState: resolvedTarget,
      dominantNeed: template.dominantNeed,
      sourceText: input.text,
    );
  }
}
