import 'package:xinxian_healing_music/models/mood_profile.dart';

/// 疗愈音乐方案。
///
/// 由情绪画像映射出的一组音乐参数 + 本地音频素材路径。
/// Demo 阶段不接真实音乐生成模型，参数由模板给出。
class HealingMusicPlan {
  /// 模板名称，例如 "高压焦虑型"
  final String templateName;

  /// 对应的情绪画像
  final MoodProfile mood;

  /// 推荐节拍 BPM
  final int bpm;

  /// 基准频率，例如 "432Hz" / "440Hz"
  final String frequency;

  /// 脑波倾向，例如 "Alpha 助松"
  final String brainwave;

  /// 推荐乐器
  final List<String> instruments;

  /// 和声色彩，例如 "小调 → 缓和过渡"
  final String harmony;

  /// 噪声层，例如 "粉噪" / "雨声"
  final String noiseLayer;

  /// 推荐时长（分钟）
  final int durationMinutes;

  /// 疗愈引导语
  final String guidance;

  /// 本地音频资源路径（assets key）
  final String audioAsset;

  const HealingMusicPlan({
    required this.templateName,
    required this.mood,
    required this.bpm,
    required this.frequency,
    required this.brainwave,
    required this.instruments,
    required this.harmony,
    required this.noiseLayer,
    required this.durationMinutes,
    required this.guidance,
    required this.audioAsset,
  });
}
