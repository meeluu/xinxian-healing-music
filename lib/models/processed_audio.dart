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
}
