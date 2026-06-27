/// 音频生成器输出的中间产物。
///
/// M1 阶段由 [StockAudioGenerator] 恒返回固定本地素材 `music/music_01.mp3`，
/// 不接真实生成模型。
class GeneratedAudio {
  /// 本地音频资源路径（assets key）
  final String assetPath;

  /// 音频来源类型
  final AudioSourceType sourceType;

  /// 生成参数（透传 features 的标准化字段，便于后续真实模型对齐）
  final Map<String, dynamic> generationParams;

  /// 生成模型 ID（mock 阶段固定为 'mock-stock-v1'）
  final String modelId;

  const GeneratedAudio({
    required this.assetPath,
    this.sourceType = AudioSourceType.stock,
    this.generationParams = const {},
    this.modelId = 'mock-stock-v1',
  });
}

/// 音频来源类型。
enum AudioSourceType {
  /// 本地预置素材
  stock,

  /// 真实生成（M1 未启用）
  generated,

  /// 外部流式
  streamed,
}
