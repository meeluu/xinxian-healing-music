import 'package:xinxian_healing_music/data/audio_asset_catalog.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/models/music_profile.dart';

/// P2-Web-v1.0 第二批 fix1：推荐理由生成器。
///
/// 优先结合用户原始输入 / mood.summary / tags / dominantNeed 按场景关键词
/// 生成更贴合的文案；未命中具体场景时 fallback 到 targetState 静态模板。
///
/// 方案页与播放页共用此 helper，保证两页说法一致。
///
/// 合规约束：不使用"治疗焦虑 / 治疗失眠 / 治愈"等医疗化表达，
/// 保持"平静下来 / 缓冲 / 放松 / 睡前舒缓 / 专注陪伴 / 提振状态"等措辞。

/// 根据用户输入与情绪画像生成推荐理由。
///
/// [plan] 完整方案（含 mood / features）
/// [moodText] 用户原始输入文本（plan 本身不存储 inputText，由 UI 层传入）
String buildRecommendationReason(HealingMusicPlan plan, String moodText) {
  // 合并所有可用文本信号，用于场景关键词匹配。
  final buffer = StringBuffer()
    ..write(moodText)
    ..write(' ')
    ..write(plan.mood.summary)
    ..write(' ')
    ..write(plan.mood.tags.join(' '));
  if (plan.mood.dominantNeed != null && plan.mood.dominantNeed!.isNotEmpty) {
    buffer
      ..write(' ')
      ..write(plan.mood.dominantNeed!);
  }
  final text = buffer.toString().toLowerCase();

  // 按优先级匹配场景关键词。
  // 优先级：睡眠 > 专注 > 低能量 > 冲突 > 疲惫放松
  // 理由：目标导向（睡眠/专注/提振）比情绪事件（冲突）更明确；
  //       "备考睡不着"应优先命中睡眠而非专注。

  // 1. 睡眠场景
  if (_containsAny(text, [
    '睡不着',
    '失眠',
    '脑子停不下来',
    '入睡',
    '难以入眠',
    '安眠',
    '翻来覆去',
    '睡不着觉',
    '睡不好',
  ])) {
    return '你现在更需要从持续转动的思绪里慢慢退出来，这段音乐节奏更慢、层次更柔和，适合睡前安静下来。';
  }

  // 2. 专注场景
  if (_containsAny(text, [
    '专注',
    '学习',
    '工作',
    '写论文',
    '注意力',
    '集中',
    '效率',
    '备考',
    '看书',
    '写代码',
    '复习',
    '办公',
    '任务',
  ])) {
    return '你需要的是低干扰的陪伴声，这段音乐减少了突兀变化，适合帮助注意力保持在当前任务上。';
  }

  // 3. 低能量场景（需要提振）
  if (_containsAny(text, [
    '没精神',
    '低能量',
    '提不起劲',
    '没动力',
    '刚睡醒',
    '困',
    '提不起',
    '没力气',
    '没干劲',
    '想提振',
    '打不起精神',
  ])) {
    return '你现在需要一点轻柔的带动感，这段音乐节奏更明亮，适合在低能量时慢慢提起状态。';
  }

  // 4. 冲突 / 情绪波动场景
  if (_containsAny(text, [
    '吵架',
    '吵完架',
    '和人吵',
    '冲突',
    '生气',
    '烦躁',
    '心乱',
    '心里乱',
    '心里很乱',
    '心烦意乱',
    '愤怒',
    '发火',
    '刚吵',
    '吵过',
    '吵了一架',
    '吵架了',
    '发脾气',
    '闹矛盾',
    '闹别扭',
  ])) {
    return '你刚经历了一段让人心里发乱的冲突，这段音乐会尽量减少突兀变化，先给情绪一个缓冲，再慢慢把注意力带回更平稳的状态。';
  }

  // 5. 疲惫 / 想放松场景
  if (_containsAny(text, [
    '有点累',
    '太累了',
    '好累',
    '疲惫',
    '疲倦',
    '想放松',
    '安静放松',
    '放松一下',
    '松弛',
    '休息',
    '累,', // 保守匹配单字"累"容易误命中（如"累计"），改为匹配更明确的短语
    '累。',
    '累，',
    '累 ',
  ])) {
    return '你现在像是需要一段不打扰的休息，这段音乐整体更平稳，适合给身心留出一个安静的缓冲。';
  }

  // 6. fallback：未命中具体场景，按 targetState 返回静态模板
  return _fallbackByTargetState(plan.mood.targetState);
}

String _fallbackByTargetState(TargetState ts) {
  switch (ts) {
    case TargetState.sleep:
      return '这段音乐节奏更慢、层次更柔和，适合在睡前把注意力从紧绷的思绪里慢慢移开。';
    case TargetState.regulate:
    case TargetState.relax:
      return '这段音乐会先承接你的紧张感，再逐渐把节奏带回更稳定的状态。';
    case TargetState.focus:
      return '这段音乐减少了突兀变化，适合作为低干扰的专注陪伴。';
    case TargetState.soothe:
    case TargetState.company:
      return '这段音乐整体更平稳，适合在疲惫或烦躁时做一段安静的缓冲。';
    case TargetState.energize:
      return '这段音乐节奏更明亮，适合在低能量时轻轻提振状态。';
  }
}

/// 根据 targetState 生成主要音乐目标的简短标签。
/// 方案页 _MetaTag 与播放页胶囊共用此函数，保持两页一致。
String goalLabelFor(TargetState ts) {
  switch (ts) {
    case TargetState.sleep:
      return '睡前舒缓';
    case TargetState.regulate:
    case TargetState.relax:
      return '情绪调节';
    case TargetState.focus:
      return '专注陪伴';
    case TargetState.soothe:
    case TargetState.company:
      return '安静放松';
    case TargetState.energize:
      return '提振状态';
  }
}

bool _containsAny(String text, List<String> keywords) {
  for (final kw in keywords) {
    if (text.contains(kw)) return true;
  }
  return false;
}

// ─── P5-music-metadata-foundation-1：per-asset 元数据展示 helper ───────
//
// 以下纯函数把「为什么推荐这段音乐」区域从写死的统一时长 / 算法派生参数，
// 改为优先读取当前推荐 AudioAsset 的 per-asset 元数据（durationSeconds /
// MusicProfile），缺失时回退到 plan.audio / plan.features，再缺失用温和兜底文案。
//
// 所有文案保持非医疗化表达（舒缓 / 陪伴 / 放松 / 睡前聆听 / 情绪调节），
// 当前参数统一标为 preliminary / 待校准，后续逐首接入真实参数后改 calibrated。

/// 把秒数格式化为友好时长文案。
///
/// - 0 或负数 → '时长待补充'（温和兜底，不报错）
/// - 例：200 → '约 3 分 20 秒'；65 → '约 1 分 5 秒'；185 → '约 3 分 5 秒'
String formatAssetDuration(int durationSeconds) {
  if (durationSeconds <= 0) return '时长待补充';
  final minutes = durationSeconds ~/ 60;
  final seconds = durationSeconds % 60;
  if (minutes == 0) return '约 $seconds 秒';
  if (seconds == 0) return '约 $minutes 分';
  return '约 $minutes 分 $seconds 秒';
}

/// 把 [MusicProfile.tempo] 映射为「节奏…」短语，让声音特征更像产品说明。
///
/// 已含「节奏」则原样返回；空串返回空串。
String _tempoToPhrase(String tempo) {
  if (tempo.isEmpty) return '';
  if (tempo.contains('节奏')) return tempo;
  switch (tempo) {
    case '慢速':
      return '节奏较慢';
    case '中慢速':
      return '节奏偏慢';
    case '稳定中速':
      return '节奏稳定';
    case '轻快中速':
      return '节奏轻快';
    default:
      return '节奏$tempo';
  }
}

/// 生成声音特征文案（逗号分隔的短描述串）。
///
/// 优先使用 per-asset [MusicProfile]（texture + energyCurve + tempo）；
/// profile 为 null 或全空时返回 '参数待补充'。
///
/// 例：texture='低频 Pad 与柔和钢琴铺底', energyCurve='低起伏', tempo='慢速'
///     → '低频 Pad 与柔和钢琴铺底、低起伏、节奏较慢'
String buildSoundCharacteristics(MusicProfile? profile) {
  if (profile == null) return '参数待补充';
  final parts = <String>[];
  if (profile.texture.isNotEmpty) parts.add(profile.texture);
  if (profile.energyCurve.isNotEmpty) parts.add(profile.energyCurve);
  final tempoPhrase = _tempoToPhrase(profile.tempo);
  if (tempoPhrase.isNotEmpty) parts.add(tempoPhrase);
  final joined = parts.join('、');
  return joined.isEmpty ? '参数待补充' : joined;
}

/// 按 targetState 生成「建议聆听方式」文案。
///
/// 不使用医疗化表达，保持「舒缓 / 陪伴 / 放松 / 睡前聆听」等措辞。
String buildListeningSuggestion(TargetState ts) {
  switch (ts) {
    case TargetState.sleep:
      return '可以配合定时关闭，循环播放到设定时间。';
    case TargetState.regulate:
    case TargetState.relax:
      return '可以闭上眼睛慢慢呼吸，让音乐陪你把状态平复下来。';
    case TargetState.focus:
      return '建议调低音量，作为低干扰的背景陪伴当前任务。';
    case TargetState.soothe:
    case TargetState.company:
      return '可以找个安静的角落，允许自己慢下来一会儿。';
    case TargetState.energize:
      return '建议跟着呼吸轻轻活动，让状态自然回暖。';
  }
}

/// 根据 [MusicParameterStatus] 生成「初步版本」注记。
///
/// - preliminary → '（初步版本，参数待校准）'
/// - calibrated / null → ''（已校准或未知状态不显示注记）
String buildPreliminaryNote(MusicParameterStatus? status) {
  if (status == MusicParameterStatus.preliminary) {
    return '（初步版本，参数待校准）';
  }
  return '';
}

/// 单首音乐 per-asset 元数据的展示视图（P5-music-metadata-foundation-1）。
///
/// 把「为什么推荐这段音乐」区域需要的展示字段一次性算好，供 [PlanScreen]
/// 直接渲染，避免 UI 层散落时长 / 声音特征 / 建议的拼装逻辑。
///
/// 混合策略：
/// - 时长：优先 AudioAsset.durationSeconds → 回退 plan.audio.durationSeconds → '时长待补充'
/// - 声音特征：优先 AudioAsset.musicProfile → 缺失回退 '参数待补充'
/// - 建议：按 plan.mood.targetState 生成
/// - 初步注记：按 musicProfile.parameterStatus 生成
class AssetMetadataView {
  /// 「时长：约 3 分 20 秒」中的时长部分（不含「时长：」前缀）。
  final String durationLabel;

  /// 声音特征正文（不含「声音特征：」前缀）。
  final String soundCharacteristics;

  /// 建议聆听方式正文（不含「建议：」前缀）。
  final String listeningSuggestion;

  /// 初步版本注记，可能为空串。
  final String preliminaryNote;

  /// 是否成功反查到 per-asset 元数据（用于决定是否显示 per-asset 区块）。
  final bool hasAssetMetadata;

  /// per-asset 声音特征是否可用（musicProfile 存在且非全空）。
  final bool hasSoundProfile;

  const AssetMetadataView({
    required this.durationLabel,
    required this.soundCharacteristics,
    required this.listeningSuggestion,
    required this.preliminaryNote,
    required this.hasAssetMetadata,
    required this.hasSoundProfile,
  });

  /// 从方案聚合根构建：通过 plan.audio.assetPath 反查 [AudioAssetCatalog]。
  factory AssetMetadataView.fromPlan(HealingMusicPlan plan) {
    final asset = AudioAssetCatalog.findByAssetPath(plan.audio.assetPath);
    final profile = asset?.musicProfile;

    // 时长混合回退：per-asset → plan.audio → 待补充
    // 直接用 `asset != null` 判断以触发类型提升，避免多余的 `!`。
    String durationLabel;
    if (asset != null && asset.durationSeconds > 0) {
      durationLabel = formatAssetDuration(asset.durationSeconds);
    } else if (plan.audio.durationSeconds > 0) {
      durationLabel = formatAssetDuration(plan.audio.durationSeconds);
    } else {
      durationLabel = '时长待补充';
    }

    final characteristics = buildSoundCharacteristics(profile);
    final hasProfile = profile != null && characteristics != '参数待补充';

    return AssetMetadataView(
      durationLabel: durationLabel,
      soundCharacteristics: characteristics,
      listeningSuggestion: buildListeningSuggestion(plan.mood.targetState),
      preliminaryNote: buildPreliminaryNote(profile?.parameterStatus),
      hasAssetMetadata: asset != null,
      hasSoundProfile: hasProfile,
    );
  }
}
