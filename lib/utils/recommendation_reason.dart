import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';

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
