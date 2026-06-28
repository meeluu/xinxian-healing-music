/// 音频生成器输出的中间产物。
///
/// M1-M5：恒返回固定本地素材 `music/music_01.mp3`。
/// M6：由 [StockAudioGenerator] 调用 [AudioAssetCatalog] 匹配，
/// 根据 [TargetState] / 脑波 / 噪音 / 乐器 选择不同音频，并透传 [title]。
class GeneratedAudio {
  /// 本地音频资源路径（assets key）
  final String assetPath;

  /// 音频来源类型
  final AudioSourceType sourceType;

  /// 生成参数（透传 features 的标准化字段，便于后续真实模型对齐）
  final Map<String, dynamic> generationParams;

  /// 生成模型 ID（mock 阶段固定为 'mock-stock-v1'）
  final String modelId;

  /// 音频展示名（M6 新增），例如 '夜色舒缓 · Theta 入眠'
  ///
  /// 向后兼容：旧历史记录缺此字段时回退空字符串，UI 不展示音频名。
  final String title;

  /// 音频时长（秒，M6 新增），0 表示未知
  ///
  /// 向后兼容：旧历史记录缺此字段时回退 0。
  final int durationSeconds;

  const GeneratedAudio({
    required this.assetPath,
    this.sourceType = AudioSourceType.stock,
    this.generationParams = const {},
    this.modelId = 'mock-stock-v1',
    this.title = '',
    this.durationSeconds = 0,
  });

  /// 序列化为 JSON 友好的 Map（供 shared_preferences 持久化）。
  Map<String, dynamic> toJson() => {
    'assetPath': assetPath,
    'sourceType': sourceType.name,
    'generationParams': generationParams,
    'modelId': modelId,
    'title': title,
    'durationSeconds': durationSeconds,
  };

  /// 从 Map 反序列化；缺字段用默认值，保证旧版本数据兼容。
  static GeneratedAudio fromJson(Map<String, dynamic> json) => GeneratedAudio(
    assetPath: json['assetPath'] as String? ?? '',
    sourceType: AudioSourceType.fromName(json['sourceType'] as String?),
    generationParams: json['generationParams'] is Map<String, dynamic>
        ? json['generationParams'] as Map<String, dynamic>
        : const {},
    modelId: json['modelId'] as String? ?? 'mock-stock-v1',
    title: json['title'] as String? ?? '',
    durationSeconds: json['durationSeconds'] as int? ?? 0,
  );
}

/// 音频来源类型。
enum AudioSourceType {
  /// 本地预置素材
  stock,

  /// 真实生成（M1 未启用）
  generated,

  /// 外部流式
  streamed;

  /// 按 name 反序列化；未知值回退到 [stock]。
  static AudioSourceType fromName(String? name) {
    for (final v in AudioSourceType.values) {
      if (v.name == name) return v;
    }
    return AudioSourceType.stock;
  }
}
