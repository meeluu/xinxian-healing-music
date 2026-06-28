import 'package:xinxian_healing_music/models/generated_audio.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_template_registry.dart';
import 'package:xinxian_healing_music/pipeline/ports/audio_generation_port.dart';

/// 本地素材音频生成器（M5 增强）。
///
/// M1-M4：恒返回 [MockTemplateRegistry.defaultAudio]，generationParams 仅透传
/// bpm / frequency / durationMinutes / variant。
///
/// M5：generationParams 新增 [MusicFeatureTags.generationPrompt] 和
/// [MusicFeatureTags.explanation]，便于后续真实生成模型对齐，也为
/// UI 展示"生成提示词"和"方案解释"预留数据通道。
///
/// 仍不接真实生成模型，assetPath 恒为本地预置素材。
class StockAudioGenerator implements AudioGenerationPort {
  const StockAudioGenerator();

  @override
  Future<GeneratedAudio> generate(
    MusicFeatureTags features,
    AudioGenerationOptions options,
  ) async {
    return GeneratedAudio(
      assetPath: MockTemplateRegistry.defaultAudio,
      sourceType: AudioSourceType.stock,
      generationParams: {
        'bpm': features.bpm,
        'bpmRange': features.bpmRange,
        'frequency': features.frequency,
        'durationMinutes': features.durationMinutes,
        'variant': options.variant.name,
        // M5 新增：生成提示词与方案解释（仅文本，不接真实模型）
        'generationPrompt': features.generationPrompt,
        'explanation': features.explanation,
        'title': features.title,
        'brainwave': features.brainwave,
        'instruments': features.instruments,
        'harmony': features.harmony,
        'noiseLayer': features.noiseLayer,
      },
    );
  }
}
