import 'package:xinxian_healing_music/data/audio_asset_catalog.dart';
import 'package:xinxian_healing_music/models/generated_audio.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/pipeline/ports/audio_generation_port.dart';

/// 本地素材音频生成器（M6 重构）。
///
/// M1-M5：恒返回 `MockTemplateRegistry.defaultAudio`（`music/music_01.mp3`），
/// 所有情绪方案共用同一首音频。
///
/// M6：改为调用 [AudioAssetCatalog.match]，根据 [MusicFeatureTags.targetRegulationState]
/// / `brainwave` / `noiseLayer` / `instruments` 匹配不同音频：
/// - sleep → music/sleep_01.mp3
/// - regulate → music/regulate_01.mp3
/// - soothe → music/soothe_01.mp3
/// - focus → music/focus_01.mp3
/// - energize → music/energize_01.mp3
///
/// 匹配失败时 fallback 到 `AudioAssetCatalog.fallback`，绝不抛异常。
/// 仍不接真实生成模型，generationParams 透传 generationPrompt / explanation。
class StockAudioGenerator implements AudioGenerationPort {
  const StockAudioGenerator();

  @override
  Future<GeneratedAudio> generate(
    MusicFeatureTags features,
    AudioGenerationOptions options,
  ) async {
    // 调用 AudioAssetCatalog 匹配音频
    final asset = AudioAssetCatalog.match(
      targetState: features.targetRegulationState,
      brainwave: features.brainwave,
      noiseTags: _splitTags(features.noiseLayer),
      instruments: features.instruments,
    );

    return GeneratedAudio(
      assetPath: asset.assetPath,
      sourceType: AudioSourceType.stock,
      title: asset.title,
      durationSeconds: asset.durationSeconds,
      generationParams: {
        'bpm': features.bpm,
        'bpmRange': features.bpmRange,
        'frequency': features.frequency,
        'durationMinutes': features.durationMinutes,
        'variant': options.variant.name,
        'generationPrompt': features.generationPrompt,
        'explanation': features.explanation,
        'title': features.title,
        'brainwave': features.brainwave,
        'instruments': features.instruments,
        'harmony': features.harmony,
        'noiseLayer': features.noiseLayer,
        // M6 新增：音频资产元信息
        'audioAssetId': asset.id,
        'audioAssetTitle': asset.title,
        'audioAssetIsFallback': asset.isFallback,
      },
    );
  }

  /// 把噪音层字符串拆分为关键词列表。
  ///
  /// 例如 '雨声 / 粉红噪音 / 低频环境音' → ['雨声', '粉红噪音', '低频环境音']
  static List<String> _splitTags(String noiseLayer) {
    if (noiseLayer.isEmpty) return const [];
    return noiseLayer
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
