import 'package:xinxian_healing_music/models/generated_audio.dart';

/// 后处理后的最终音频，作为 Player 的输入。
///
/// M6 新增 [title] / [durationSeconds] 字段，用于 UI 展示音频名。
/// 旧历史记录缺此字段时 fromJson 回退默认值，向后兼容。
class ProcessedAudio {
  /// 本地音频资源路径（assets key）
  final String assetPath;

  /// 音频来源类型
  final AudioSourceType sourceType;

  /// 已应用的处理链（按顺序），例如 ['passthrough'] 或 ['eq', 'noise-mix', 'fade']
  final List<String> processingChain;

  /// 音频展示名（M6 新增），例如 '夜色舒缓 · Theta 入眠'
  ///
  /// 向后兼容：旧历史记录缺此字段时回退空字符串，UI 不展示音频名。
  final String title;

  /// 音频时长（秒，M6 新增），0 表示未知
  ///
  /// 向后兼容：旧历史记录缺此字段时回退 0。
  final int durationSeconds;

  const ProcessedAudio({
    required this.assetPath,
    this.sourceType = AudioSourceType.stock,
    this.processingChain = const [],
    this.title = '',
    this.durationSeconds = 0,
  });

  /// 序列化为 JSON 友好的 Map（供 shared_preferences 持久化）。
  Map<String, dynamic> toJson() => {
    'assetPath': assetPath,
    'sourceType': sourceType.name,
    'processingChain': processingChain,
    'title': title,
    'durationSeconds': durationSeconds,
  };

  /// 从 Map 反序列化；缺字段用默认值，保证旧版本数据兼容。
  static ProcessedAudio fromJson(Map<String, dynamic> json) => ProcessedAudio(
    assetPath: json['assetPath'] as String? ?? '',
    sourceType: AudioSourceType.fromName(json['sourceType'] as String?),
    processingChain:
        (json['processingChain'] as List?)?.cast<String>() ?? const [],
    title: json['title'] as String? ?? '',
    durationSeconds: json['durationSeconds'] as int? ?? 0,
  );
}
