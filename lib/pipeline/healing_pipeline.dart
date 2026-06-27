import 'dart:math';

import 'package:xinxian_healing_music/models/audio_post_process_config.dart';
import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/models/processed_audio.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_plan_meta_resolver.dart';
import 'package:xinxian_healing_music/pipeline/ports/audio_generation_port.dart';
import 'package:xinxian_healing_music/pipeline/ports/audio_post_processor_port.dart';
import 'package:xinxian_healing_music/pipeline/ports/experiment_assigner.dart';
import 'package:xinxian_healing_music/pipeline/ports/mood_analyzer_port.dart';
import 'package:xinxian_healing_music/pipeline/ports/music_feature_extractor_port.dart';

/// 疗愈音乐 Pipeline 编排器。
///
/// 串联 Translation Pipeline 各阶段，单向流转：
/// ```
/// MoodInput
///   →[ExperimentAssigner]→ ExperimentVariant
///   →[MoodAnalyzer]→ MoodProfile
///   →[FeatureExtractor]→ MusicFeatureTags
///   →[AudioGenerator]→ GeneratedAudio
///   →[PostProcessor]→ ProcessedAudio
///   →[PlanMetaResolver]→ (templateName, durationMinutes, guidance)
///   → HealingMusicPlan（聚合根）
/// ```
///
/// Pipeline 只负责生成 plan 与传递 sessionId，不承担持久化职责；
/// 会话生命周期记录由 ListeningSessionRecorder 在 UI 层调用。
///
/// 具体实现（mock / 真实）在 [mock_pipeline_factory] 装配时注入，
/// UI 层只依赖 [run] 的输入输出。
class HealingPipeline {
  final MoodAnalyzerPort moodAnalyzer;
  final MusicFeatureExtractorPort featureExtractor;
  final AudioGenerationPort audioGenerator;
  final AudioPostProcessorPort postProcessor;
  final ExperimentAssigner experimentAssigner;
  final MockPlanMetaResolver planMetaResolver;

  const HealingPipeline({
    required this.moodAnalyzer,
    required this.featureExtractor,
    required this.audioGenerator,
    required this.postProcessor,
    required this.experimentAssigner,
    required this.planMetaResolver,
  });

  /// 会话 ID 生成器（无第三方依赖：时间戳 + 随机后缀）。
  static final Random _rand = Random();

  /// 运行完整 Pipeline，返回疗愈音乐方案。
  Future<HealingMusicPlan> run(String text) async {
    // 会话 ID 在入口生成，贯穿 MoodInput → HealingMusicPlan，
    // 后续 ExperimentAssigner 也可基于其做确定性分组。
    final sessionId = _generateSessionId();
    final input = MoodInput(
      sessionId: sessionId,
      text: text,
      timestamp: DateTime.now(),
    );

    final ExperimentVariant variant = experimentAssigner.assign(input);
    final MoodProfile profile = await moodAnalyzer.analyze(input);
    final MusicFeatureTags features = await featureExtractor.extract(profile);
    final generated = await audioGenerator.generate(
      features,
      AudioGenerationOptions(variant: variant),
    );
    final ProcessedAudio audio = await postProcessor.process(
      generated,
      const AudioPostProcessConfig(),
    );
    final meta = planMetaResolver.resolve(profile);

    return HealingMusicPlan(
      sessionId: sessionId,
      templateName: meta.templateName,
      mood: profile,
      features: features,
      audio: audio,
      postProcess: const AudioPostProcessConfig(),
      variant: variant,
      durationMinutes: meta.durationMinutes,
      guidance: meta.guidance,
    );
  }

  String _generateSessionId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final r = _rand.nextInt(0xffffff).toRadixString(36).padLeft(4, '0');
    return 'sess-$ts-$r';
  }
}
