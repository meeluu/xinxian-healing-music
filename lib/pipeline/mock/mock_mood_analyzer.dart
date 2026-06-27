import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_template_registry.dart';
import 'package:xinxian_healing_music/pipeline/ports/mood_analyzer_port.dart';

/// Mock 情绪解析器。
///
/// 用关键词命中数选模板，命中最多者胜出；无命中则走"平衡调和型"。
/// 逻辑迁自旧 `services/mood_analyzer.dart`，输出由 [HealingMusicPlan]
/// 收窄为 [MoodProfile]，对齐 Translation Pipeline 分层。
class MockMoodAnalyzer implements MoodAnalyzerPort {
  const MockMoodAnalyzer();

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
        const [
          '失眠',
          '睡不着',
          '停不下来',
          '入睡',
          '睡眠',
          '辗转',
          '脑子',
          '胡思乱想',
          '夜醒',
        ],
        'insomnia',
      ),
      (
        const [
          '悲伤',
          '低落',
          '失落',
          '难过',
          '想哭',
          '沮丧',
          'emo',
          '抑郁',
          '孤独',
          '空虚',
        ],
        'lowMood',
      ),
      (
        const [
          '愤怒',
          '烦躁',
          '火大',
          '生气',
          '气死',
          '烦',
          '暴',
          '吵架',
          '冲突',
          '委屈',
        ],
        'agitated',
      ),
      (
        const [
          '疲惫',
          '累',
          '耗尽',
          '无力',
          '精疲力',
          '虚',
          '倦',
          '透支',
          '麻木',
        ],
        'exhausted',
      ),
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
    return MockTemplateRegistry.moodForKey(bestKey);
  }
}
