import 'package:xinxian_healing_music/models/audio_post_process_config.dart';
import 'package:xinxian_healing_music/models/generated_audio.dart';
import 'package:xinxian_healing_music/models/processed_audio.dart';
import 'package:xinxian_healing_music/pipeline/ports/audio_post_processor_port.dart';

/// 直通后处理器。
///
/// M1 阶段不应用任何真实处理，仅透传音频路径并记录处理链为 ['passthrough']。
/// 保留此节点是为对齐正式 Pipeline 结构，便于后续接入 EQ / 噪声层 / 淡入淡出。
class PassthroughPostProcessor implements AudioPostProcessorPort {
  const PassthroughPostProcessor();

  @override
  Future<ProcessedAudio> process(
    GeneratedAudio audio,
    AudioPostProcessConfig config,
  ) async {
    return ProcessedAudio(
      assetPath: audio.assetPath,
      sourceType: audio.sourceType,
      processingChain: const ['passthrough'],
    );
  }
}
