import 'package:xinxian_healing_music/models/audio_post_process_config.dart';
import 'package:xinxian_healing_music/models/generated_audio.dart';
import 'package:xinxian_healing_music/models/processed_audio.dart';

/// 音频后处理 Port：对生成音频做 EQ / 噪声层 / 淡入淡出等处理。
abstract class AudioPostProcessorPort {
  Future<ProcessedAudio> process(
    GeneratedAudio audio,
    AudioPostProcessConfig config,
  );
}
