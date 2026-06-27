import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';

/// 6 套预置情绪→疗愈音乐方案模板。
///
/// Demo 阶段所有模板共用同一份本地音频 `music/music_01.mp3`，
/// 后续若新增音频，把各模板的 `audioAsset` 改成对应文件即可。
class MockTemplates {
  MockTemplates._();

  /// 默认音频素材（assets key 与 pubspec 中 `music/` 目录对应）
  static const String defaultAudio = 'music/music_01.mp3';

  static const HealingMusicPlan highPressure = HealingMusicPlan(
    templateName: '高压焦虑型',
    mood: MoodProfile(
      tags: ['焦虑', '紧绷', '高压', '思绪过载'],
      valence: -0.4,
      arousal: 0.8,
      summary: '你正承受较大压力，思绪难以停歇',
    ),
    bpm: 60,
    frequency: '432Hz',
    brainwave: 'Alpha 助松',
    instruments: ['钢琴', '大提琴'],
    harmony: '小调 → 缓和过渡',
    noiseLayer: '粉噪',
    durationMinutes: 20,
    guidance: '让呼吸跟着琴声慢下来，把焦虑交给旋律。',
    audioAsset: defaultAudio,
  );

  static const HealingMusicPlan insomnia = HealingMusicPlan(
    templateName: '入睡困难型',
    mood: MoodProfile(
      tags: ['失眠', '思绪纷扰', '难以入眠'],
      valence: -0.2,
      arousal: 0.6,
      summary: '夜晚思绪难止，身体难以松弛',
    ),
    bpm: 48,
    frequency: '432Hz',
    brainwave: 'Theta / Delta 助眠',
    instruments: ['手碟', '氛围 Pad'],
    harmony: '模糊大调',
    noiseLayer: '雨声',
    durationMinutes: 30,
    guidance: '跟随雨声与手碟，让意识慢慢沉入夜色。',
    audioAsset: defaultAudio,
  );

  static const HealingMusicPlan lowMood = HealingMusicPlan(
    templateName: '情绪低落型',
    mood: MoodProfile(
      tags: ['低落', '失落', '沉重'],
      valence: -0.6,
      arousal: 0.3,
      summary: '情绪有些下沉，需要被温柔接住',
    ),
    bpm: 56,
    frequency: '440Hz',
    brainwave: 'Alpha 舒缓',
    instruments: ['大提琴', '竖琴'],
    harmony: '小调转大调',
    noiseLayer: '粉噪',
    durationMinutes: 22,
    guidance: '允许自己难过，琴声会陪你慢慢回暖。',
    audioAsset: defaultAudio,
  );

  static const HealingMusicPlan agitated = HealingMusicPlan(
    templateName: '情绪激越型',
    mood: MoodProfile(
      tags: ['愤怒', '烦躁', '激越'],
      valence: -0.5,
      arousal: 0.9,
      summary: '情绪强烈翻涌，需要先被稳住',
    ),
    bpm: 58,
    frequency: '432Hz',
    brainwave: 'Alpha 降频',
    instruments: ['古琴', '尺八'],
    harmony: '五声调式',
    noiseLayer: '白噪',
    durationMinutes: 18,
    guidance: '先让情绪流淌，再随古琴一点点归于平静。',
    audioAsset: defaultAudio,
  );

  static const HealingMusicPlan exhausted = HealingMusicPlan(
    templateName: '身心疲惫型',
    mood: MoodProfile(
      tags: ['疲惫', '耗竭', '空虚'],
      valence: -0.3,
      arousal: 0.2,
      summary: '能量近乎耗尽，需要被温柔充能',
    ),
    bpm: 52,
    frequency: '432Hz',
    brainwave: 'Theta 深养',
    instruments: ['颂钵', '氛围 Pad'],
    harmony: '模糊大调',
    noiseLayer: '海浪',
    durationMinutes: 25,
    guidance: '把重量交给颂钵，让自己被声音托起。',
    audioAsset: defaultAudio,
  );

  static const HealingMusicPlan balanced = HealingMusicPlan(
    templateName: '平衡调和型',
    mood: MoodProfile(
      tags: ['调和', '平衡', '温和'],
      valence: 0.2,
      arousal: 0.4,
      summary: '状态相对平稳，做一次温和调频',
    ),
    bpm: 64,
    frequency: '432Hz',
    brainwave: 'Alpha 维稳',
    instruments: ['钢琴', '长笛'],
    harmony: '大调',
    noiseLayer: '粉噪',
    durationMinutes: 15,
    guidance: '在均衡的声场里，给自己一段留白。',
    audioAsset: defaultAudio,
  );
}
