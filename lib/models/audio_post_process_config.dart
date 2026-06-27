/// 音频后处理配置（EQ / 噪声层 / 淡入淡出等）。
///
/// M1 阶段 [PassthroughPostProcessor] 直通，不真正应用任何处理；
/// 该模型保留是为对齐正式 Pipeline 结构，便于后续接入真实后处理。
class AudioPostProcessConfig {
  /// 噪声类型，例如 'pink' / 'white' / 'rain' / 'ocean'
  final String? noiseType;

  /// 噪声混合电平（0..1，0 表示不混合）
  final double noiseLevel;

  /// 淡入时长（秒）
  final double fadeIn;

  /// 淡出时长（秒）
  final double fadeOut;

  /// EQ 频段配置
  final List<EqBand> eqBands;

  const AudioPostProcessConfig({
    this.noiseType,
    this.noiseLevel = 0.0,
    this.fadeIn = 0.0,
    this.fadeOut = 0.0,
    this.eqBands = const [],
  });
}

/// EQ 频段配置。
class EqBand {
  /// 中心频率（Hz）
  final double freqHz;

  /// 增益（dB）
  final double gainDb;

  /// Q 值
  final double q;

  const EqBand({required this.freqHz, this.gainDb = 0.0, this.q = 0.7});
}
