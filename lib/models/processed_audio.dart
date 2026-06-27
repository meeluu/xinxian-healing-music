import 'package:xinxian_healing_music/models/generated_audio.dart';

/// 后处理后的最终音频，作为 Player 的输入。
class ProcessedAudio {
  /// 本地音频资源路径（assets key）
  final String assetPath;

  /// 音频来源类型
  final AudioSourceType sourceType;

  /// 已应用的处理链（按顺序），例如 ['passthrough'] 或 ['eq', 'noise-mix', 'fade']
  final List<String> processingChain;

  const ProcessedAudio({
    required this.assetPath,
    this.sourceType = AudioSourceType.stock,
    this.processingChain = const [],
  });

  /// 序列化为 JSON 友好的 Map（供 shared_preferences 持久化）。
  Map<String, dynamic> toJson() => {
    'assetPath': assetPath,
    'sourceType': sourceType.name,
    'processingChain': processingChain,
  };

  /// 从 Map 反序列化；缺字段用默认值，保证旧版本数据兼容。
  static ProcessedAudio fromJson(Map<String, dynamic> json) => ProcessedAudio(
    assetPath: json['assetPath'] as String? ?? '',
    sourceType: AudioSourceType.fromName(json['sourceType'] as String?),
    processingChain:
        (json['processingChain'] as List?)?.cast<String>() ?? const [],
  );
}
