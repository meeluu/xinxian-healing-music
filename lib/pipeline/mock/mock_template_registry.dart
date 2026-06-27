import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';

/// 6 套预置情绪→疗愈音乐方案模板的中央 registry。
///
/// 供 [MockMoodAnalyzer] / [RuleBasedFeatureExtractor] / [MockPlanMetaResolver]
/// 共同反查，保证 templateName / guidance / duration / features 文案逐字一致。
///
/// 6 模板的 (valence, arousal) 二元组两两不同，可确定性命中。
class MockTemplateRegistry {
  MockTemplateRegistry._();

  /// 默认音频素材（assets key 与 pubspec 中 `music/` 目录对应）
  static const String defaultAudio = 'music/music_01.mp3';

  static const List<_Bundle> _bundles = [
    _Bundle(
      key: 'highPressure',
      templateName: '高压焦虑型',
      moodTags: ['焦虑', '紧绷', '高压', '思绪过载'],
      valence: -0.4,
      arousal: 0.8,
      intensity: 0.8,
      targetState: TargetState.regulate,
      dominantNeed: '情绪降温',
      moodSummary: '你正承受较大压力，思绪难以停歇',
      bpm: 60,
      frequency: '432Hz',
      brainwave: 'Alpha 助松',
      instruments: ['钢琴', '大提琴'],
      harmony: '小调 → 缓和过渡',
      noiseLayer: '粉噪',
      durationMinutes: 20,
      guidance: '让呼吸跟着琴声慢下来，把焦虑交给旋律。',
    ),
    _Bundle(
      key: 'insomnia',
      templateName: '入睡困难型',
      moodTags: ['失眠', '思绪纷扰', '难以入眠'],
      valence: -0.2,
      arousal: 0.6,
      intensity: 0.7,
      targetState: TargetState.sleep,
      dominantNeed: '快速入眠',
      moodSummary: '夜晚思绪难止，身体难以松弛',
      bpm: 48,
      frequency: '432Hz',
      brainwave: 'Theta / Delta 助眠',
      instruments: ['手碟', '氛围 Pad'],
      harmony: '模糊大调',
      noiseLayer: '雨声',
      durationMinutes: 30,
      guidance: '跟随雨声与手碟，让意识慢慢沉入夜色。',
    ),
    _Bundle(
      key: 'lowMood',
      templateName: '情绪低落型',
      moodTags: ['低落', '失落', '沉重'],
      valence: -0.6,
      arousal: 0.3,
      intensity: 0.6,
      targetState: TargetState.company,
      dominantNeed: '被温柔接住',
      moodSummary: '情绪有些下沉，需要被温柔接住',
      bpm: 56,
      frequency: '440Hz',
      brainwave: 'Alpha 舒缓',
      instruments: ['大提琴', '竖琴'],
      harmony: '小调转大调',
      noiseLayer: '粉噪',
      durationMinutes: 22,
      guidance: '允许自己难过，琴声会陪你慢慢回暖。',
    ),
    _Bundle(
      key: 'agitated',
      templateName: '情绪激越型',
      moodTags: ['愤怒', '烦躁', '激越'],
      valence: -0.5,
      arousal: 0.9,
      intensity: 0.9,
      targetState: TargetState.regulate,
      dominantNeed: '情绪降温',
      moodSummary: '情绪强烈翻涌，需要先被稳住',
      bpm: 58,
      frequency: '432Hz',
      brainwave: 'Alpha 降频',
      instruments: ['古琴', '尺八'],
      harmony: '五声调式',
      noiseLayer: '白噪',
      durationMinutes: 18,
      guidance: '先让情绪流淌，再随古琴一点点归于平静。',
    ),
    _Bundle(
      key: 'exhausted',
      templateName: '身心疲惫型',
      moodTags: ['疲惫', '耗竭', '空虚'],
      valence: -0.3,
      arousal: 0.2,
      intensity: 0.6,
      targetState: TargetState.company,
      dominantNeed: '温柔充能',
      moodSummary: '能量近乎耗尽，需要被温柔充能',
      bpm: 52,
      frequency: '432Hz',
      brainwave: 'Theta 深养',
      instruments: ['颂钵', '氛围 Pad'],
      harmony: '模糊大调',
      noiseLayer: '海浪',
      durationMinutes: 25,
      guidance: '把重量交给颂钵，让自己被声音托起。',
    ),
    _Bundle(
      key: 'balanced',
      templateName: '平衡调和型',
      moodTags: ['调和', '平衡', '温和'],
      valence: 0.2,
      arousal: 0.4,
      intensity: 0.3,
      targetState: TargetState.relax,
      dominantNeed: null,
      moodSummary: '状态相对平稳，做一次温和调频',
      bpm: 64,
      frequency: '432Hz',
      brainwave: 'Alpha 维稳',
      instruments: ['钢琴', '长笛'],
      harmony: '大调',
      noiseLayer: '粉噪',
      durationMinutes: 15,
      guidance: '在均衡的声场里，给自己一段留白。',
    ),
  ];

  /// 按 key 取情绪画像。
  static MoodProfile moodForKey(String key) {
    final b = _bundles.firstWhere((e) => e.key == key);
    return MoodProfile(
      tags: b.moodTags,
      valence: b.valence,
      arousal: b.arousal,
      intensity: b.intensity,
      targetState: b.targetState,
      dominantNeed: b.dominantNeed,
      summary: b.moodSummary,
    );
  }

  /// 按 (valence, arousal) 反查音乐特征标签。
  static MusicFeatureTags featuresForValenceArousal(
    double valence,
    double arousal,
  ) {
    final b = _findByValenceArousal(valence, arousal);
    return MusicFeatureTags(
      bpm: b.bpm,
      frequency: b.frequency,
      brainwave: b.brainwave,
      instruments: b.instruments,
      harmony: b.harmony,
      noiseLayer: b.noiseLayer,
      durationMinutes: b.durationMinutes,
      intensity: b.intensity,
      arousal: b.arousal,
      valence: b.valence,
      targetRegulationState: b.targetState,
    );
  }

  /// 按 (valence, arousal) 反查方案元信息（模板名 / 时长 / 引导语）。
  static PlanMeta metaForValenceArousal(double valence, double arousal) {
    final b = _findByValenceArousal(valence, arousal);
    return PlanMeta(
      templateName: b.templateName,
      durationMinutes: b.durationMinutes,
      guidance: b.guidance,
    );
  }

  static _Bundle _findByValenceArousal(double valence, double arousal) {
    for (final b in _bundles) {
      if (b.valence == valence && b.arousal == arousal) return b;
    }
    throw StateError(
      'No mock template matches (valence=$valence, arousal=$arousal)',
    );
  }
}

/// 方案元信息（模板名 / 推荐时长 / 引导语）。
class PlanMeta {
  final String templateName;
  final int durationMinutes;
  final String guidance;

  const PlanMeta({
    required this.templateName,
    required this.durationMinutes,
    required this.guidance,
  });
}

class _Bundle {
  final String key;
  final String templateName;
  final List<String> moodTags;
  final double valence;
  final double arousal;
  final double intensity;
  final TargetState targetState;
  final String? dominantNeed;
  final String moodSummary;
  final int bpm;
  final String frequency;
  final String brainwave;
  final List<String> instruments;
  final String harmony;
  final String noiseLayer;
  final int durationMinutes;
  final String guidance;

  const _Bundle({
    required this.key,
    required this.templateName,
    required this.moodTags,
    required this.valence,
    required this.arousal,
    required this.intensity,
    required this.targetState,
    this.dominantNeed,
    required this.moodSummary,
    required this.bpm,
    required this.frequency,
    required this.brainwave,
    required this.instruments,
    required this.harmony,
    required this.noiseLayer,
    required this.durationMinutes,
    required this.guidance,
  });
}
