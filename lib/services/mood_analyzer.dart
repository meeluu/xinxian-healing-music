import 'package:xinxian_healing_music/data/mock_templates.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';

/// Mock 情绪解析器。
///
/// 用关键词命中数选模板，命中最多者胜出；无命中则走"平衡调和型"。
/// Demo 用，不接真实 LLM。
class MoodAnalyzer {
  const MoodAnalyzer();

  HealingMusicPlan analyze(String text) {
    final rules = <(List<String>, HealingMusicPlan)>[
      (
        ['备考', '压力', '焦虑', '紧张', '焦躁', 'deadline', '考试', '压力大', 'kpi', '加班'],
        MockTemplates.highPressure,
      ),
      (
        ['失眠', '睡不着', '停不下来', '入睡', '睡眠', '辗转', '脑子', '胡思乱想', '夜醒'],
        MockTemplates.insomnia,
      ),
      (
        ['悲伤', '低落', '失落', '难过', '想哭', '沮丧', 'emo', '抑郁', '孤独', '空虚'],
        MockTemplates.lowMood,
      ),
      (
        ['愤怒', '烦躁', '火大', '生气', '气死', '烦', '暴', '吵架', '冲突', '委屈'],
        MockTemplates.agitated,
      ),
      (
        ['疲惫', '累', '耗尽', '无力', '精疲力', '虚', '倦', '透支', '麻木'],
        MockTemplates.exhausted,
      ),
    ];

    HealingMusicPlan? best;
    int bestHits = 0;
    for (final (keywords, plan) in rules) {
      int hits = 0;
      for (final kw in keywords) {
        if (text.contains(kw)) hits++;
      }
      if (hits > bestHits) {
        bestHits = hits;
        best = plan;
      }
    }

    return best ?? MockTemplates.balanced;
  }
}
