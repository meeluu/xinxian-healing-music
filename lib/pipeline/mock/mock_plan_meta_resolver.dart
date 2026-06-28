import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/pipeline/mapper/emotion_to_music_plan_mapper.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_template_registry.dart';

/// 方案元信息解析器（M5 重构）。
///
/// M1-M4：用 (valence, arousal) 反查 [MockTemplateRegistry] 命中模板，
/// 返回方案元信息（模板名 / 推荐时长 / 引导语）。
///
/// M5：改为调用 [EmotionToMusicPlanMapper]，让完整 [MoodProfile] 参与
/// 方案元信息生成。templateName / guidance / durationMinutes 由 mapper
/// 根据 targetState + tags + dominantNeed 生成，不再依赖最近邻模板匹配。
///
/// 仍返回 M1-M4 的 [PlanMeta] 类型，保持 Pipeline 接口向后兼容。
class MockPlanMetaResolver {
  final EmotionToMusicPlanMapper _mapper;

  const MockPlanMetaResolver({
    this._mapper = EmotionToMusicPlanMapper.instance,
  });

  PlanMeta resolve(MoodProfile profile) {
    final draft = _mapper.map(profile);
    return PlanMeta(
      templateName: draft.templateName,
      durationMinutes: draft.durationMinutes,
      guidance: draft.guidance,
    );
  }
}
