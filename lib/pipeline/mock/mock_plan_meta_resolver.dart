import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_template_registry.dart';

/// 方案元信息解析器。
///
/// 用 (valence, arousal) 反查 [MockTemplateRegistry]，返回方案元信息
/// （模板名 / 推荐时长 / 引导语），保证 templateName / guidance / duration
/// 与原 Demo 逐字一致——这些字段无法从 profile 纯规则推导（targetState 有碰撞），
/// 故必须反查 registry。
class MockPlanMetaResolver {
  const MockPlanMetaResolver();

  PlanMeta resolve(MoodProfile profile) {
    return MockTemplateRegistry.metaForValenceArousal(
      profile.valence,
      profile.arousal,
    );
  }
}
