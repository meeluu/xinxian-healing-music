/// 音乐参数校准状态（P5-music-metadata-foundation-1）。
enum MusicParameterStatus {
  /// 初步占位推断，待后续用真实音乐参数校准。
  ///
  /// 当前阶段 AudioAsset 的声音特征描述基于已有 brainwaveTag / noiseTags /
  /// instruments 推断，不是音频分析得出的精确结论，统一标为 preliminary，
  /// 后续逐首接入真实参数后改为 [calibrated]。
  preliminary,

  /// 已校准（后续真实参数接入后使用）。
  calibrated,
}

/// 单首本地音乐的声音特征元数据（P5-music-metadata-foundation-1）。
///
/// 与 `AudioAsset` 绑定，供方案页「为什么推荐这段音乐」展示 per-asset 声音特征，
/// 替代之前写死的统一时长 / 算法派生参数。
///
/// 当前值为基于已有元信息的初步推断，[parameterStatus] 标为
/// [MusicParameterStatus.preliminary]，后续逐首校准。
///
/// 合规约束：字段文案不使用「治疗 / 治愈 / 疗效」等医疗化表达，
/// 保持「舒缓 / 陪伴 / 放松 / 睡前聆听 / 情绪调节」等措辞。
class MusicProfile {
  /// 节奏描述，例如 '慢速' / '稳定中速' / '轻快中速'。
  final String tempo;

  /// 声音特征，例如 '低频 Pad 与柔和钢琴铺底'。
  final String texture;

  /// 起伏描述，例如 '低起伏' / '温和上升'。
  final String energyCurve;

  /// 适合场景，例如 '睡前舒缓' / '专注陪伴'。
  final String suitableScene;

  /// 参数校准状态（preliminary / calibrated）。
  final MusicParameterStatus parameterStatus;

  const MusicProfile({
    required this.tempo,
    required this.texture,
    required this.energyCurve,
    required this.suitableScene,
    this.parameterStatus = MusicParameterStatus.preliminary,
  });
}
