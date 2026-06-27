import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/generated_audio.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';

/// 音频生成 Port：音乐特征 → 生成的音频。
abstract class AudioGenerationPort {
  Future<GeneratedAudio> generate(
    MusicFeatureTags features,
    AudioGenerationOptions options,
  );
}

/// 音频生成选项。
class AudioGenerationOptions {
  /// 目标时长（可空表示由 features 决定）
  final Duration? duration;

  /// 是否允许使用本地素材兜底
  final bool allowStockFallback;

  /// 实验分组（影响生成策略）
  final ExperimentVariant variant;

  const AudioGenerationOptions({
    this.duration,
    this.allowStockFallback = true,
    this.variant = ExperimentVariant.custom,
  });
}
