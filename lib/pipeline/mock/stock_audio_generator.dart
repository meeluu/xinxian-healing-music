import 'package:xinxian_healing_music/models/generated_audio.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_template_registry.dart';
import 'package:xinxian_healing_music/pipeline/ports/audio_generation_port.dart';

/// 本地素材音频生成器。
///
/// M1 阶段忽略 features 与 options，恒返回 [MockTemplateRegistry.defaultAudio]，
/// 不接真实生成模型。generationParams 透传 features 关键字段，便于后续真实模型对齐。
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
        'frequency': features.frequency,
        'durationMinutes': features.durationMinutes,
        'variant': options.variant.name,
      },
    );
  }
}
