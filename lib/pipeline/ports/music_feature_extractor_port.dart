import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';

/// 音乐特征提取 Port：情绪画像 → 音乐特征标签。
abstract class MusicFeatureExtractorPort {
  Future<MusicFeatureTags> extract(MoodProfile profile);
}
