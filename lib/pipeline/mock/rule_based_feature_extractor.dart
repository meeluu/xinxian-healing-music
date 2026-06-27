import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_template_registry.dart';
import 'package:xinxian_healing_music/pipeline/ports/music_feature_extractor_port.dart';

/// 基于规则的音乐特征提取器。
///
/// 用 (valence, arousal) 反查 [MockTemplateRegistry] 命中模板，
/// 返回该模板的展示型 + 标准化音乐特征。6 模板 (valence, arousal)
/// 二元组两两不同，故可确定性命中，保证展示值与原 Demo 逐字一致。
class RuleBasedFeatureExtractor implements MusicFeatureExtractorPort {
  const RuleBasedFeatureExtractor();

  @override
  Future<MusicFeatureTags> extract(MoodProfile profile) async {
    return MockTemplateRegistry.featuresForValenceArousal(
      profile.valence,
      profile.arousal,
    );
  }
}
