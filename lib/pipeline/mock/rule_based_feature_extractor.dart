import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/pipeline/mapper/emotion_to_music_plan_mapper.dart';
import 'package:xinxian_healing_music/pipeline/ports/music_feature_extractor_port.dart';

/// 基于规则的音乐特征提取器（M5 重构）。
///
/// M1-M4：用 (valence, arousal) 反查 [MockTemplateRegistry] 命中模板，
/// 返回该模板的展示型 + 标准化音乐特征。
///
/// M5：改为调用 [EmotionToMusicPlanMapper]，让完整 [MoodProfile]
/// （含 targetState / intensity / arousal / valence / tags / dominantNeed）
/// 真正参与音乐参数生成。Mock 解析与 LLM 解析复用同一套映射逻辑。
///
/// 任何字段异常都不抛异常，保证 LLM 异常时仍能 fallback。
class RuleBasedFeatureExtractor implements MusicFeatureExtractorPort {
  final EmotionToMusicPlanMapper _mapper;

  const RuleBasedFeatureExtractor({
    this._mapper = EmotionToMusicPlanMapper.instance,
  });

  @override
  Future<MusicFeatureTags> extract(MoodProfile profile) async {
    final draft = _mapper.map(profile);
    return MusicFeatureTags(
      bpm: draft.bpm,
      bpmRange: draft.bpmRange,
      frequency: draft.baseFrequency,
      brainwave: draft.brainwaveTarget,
      instruments: draft.instruments,
      harmony: draft.harmonyColor,
      noiseLayer: draft.noiseLayer,
      durationMinutes: draft.durationMinutes,
      title: draft.title,
      generationPrompt: draft.generationPrompt,
      explanation: draft.explanation,
      intensity: draft.intensity,
      arousal: draft.arousal,
      valence: draft.valence,
      targetRegulationState: draft.targetState,
    );
  }
}
