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

  /// 序列化为 JSON 友好的 Map（供 shared_preferences 持久化）。
  Map<String, dynamic> toJson() => {
    if (noiseType != null) 'noiseType': noiseType,
    'noiseLevel': noiseLevel,
    'fadeIn': fadeIn,
    'fadeOut': fadeOut,
    'eqBands': eqBands.map((b) => b.toJson()).toList(),
  };

  /// 从 Map 反序列化；缺字段用默认值，保证旧版本数据兼容。
  static AudioPostProcessConfig fromJson(Map<String, dynamic> json) =>
      AudioPostProcessConfig(
        noiseType: json['noiseType'] as String?,
        noiseLevel: (json['noiseLevel'] as num?)?.toDouble() ?? 0.0,
        fadeIn: (json['fadeIn'] as num?)?.toDouble() ?? 0.0,
        fadeOut: (json['fadeOut'] as num?)?.toDouble() ?? 0.0,
        eqBands:
            (json['eqBands'] as List?)
                ?.map((b) => EqBand.fromJson(b as Map<String, dynamic>))
                .toList() ??
            const [],
      );
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

  Map<String, dynamic> toJson() => {'freqHz': freqHz, 'gainDb': gainDb, 'q': q};

  static EqBand fromJson(Map<String, dynamic> json) => EqBand(
    freqHz: (json['freqHz'] as num?)?.toDouble() ?? 0.0,
    gainDb: (json['gainDb'] as num?)?.toDouble() ?? 0.0,
    q: (json['q'] as num?)?.toDouble() ?? 0.7,
  );
}
