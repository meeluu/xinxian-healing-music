import 'package:xinxian_healing_music/models/mood_profile.dart';

/// 用户意图 → [TargetState] 的规则引擎（M6.1 新增）。
///
/// 解决 M5/M6 的意图识别精度问题：
/// - M5 的 [EmotionToMusicPlanMapper._resolveTargetState] 只看 `profile.tags`，
///   看不到用户原文，无法识别"专注学习""不想睡"等信号。
/// - M6 的 [AudioAssetCatalog] 只依赖最终 targetState，targetState 不准则音频不匹配。
///
/// 本模块把"原文 + tags + valence/arousal + LLM/mock 返回的 targetState"
/// 统一规约为最终 targetState，供 MockMoodAnalyzer 和 mapper 复用。
///
/// 设计原则：
/// 1. 纯函数无状态，多次调用结果一致
/// 2. 不抛异常，任何输入都返回合理的 targetState
/// 3. 优先级从高到低，高优先级规则一旦命中就返回
/// 4. 否定/反向意图最优先（避免"不想睡"被 sleep 规则捕获）
/// 5. 睡眠强信号（失眠/睡不着）优先于任务目标（学习/工作），
///    因为"备考压力大，晚上睡不着"应归 sleep
/// 6. 低能量信号（强信号 + 原文 mild 信号）优先于悲伤安抚，
///    因为"运动后很空""我很疲惫"应归 energize 而非 soothe。
///    注意：原文 mild 信号只看原文不看 tags，避免 exhausted 模板 tags 里的
///    "空虚"污染判断（"空虚"也是 soothe 关键词）。
/// 7. fallback：信任 LLM/mock 返回的 targetState（向后兼容 relax/company）
class TargetStateResolver {
  const TargetStateResolver._();

  // ─────────────────────────────────────────────────────────────────────
  // 关键词表（按优先级分组）
  // ─────────────────────────────────────────────────────────────────────

  /// 第 1 优先级：否定/反向意图。
  ///
  /// "不想睡 / 不能睡 / 保持清醒"等不能归为 sleep，应偏 focus 或 energize。
  static const List<String> _negationSleepKeywords = [
    '不想睡',
    '不能睡',
    '别睡',
    '别让我睡',
    '保持清醒',
    '不想入睡',
    '不要睡',
    '不能入睡',
    '不想睡觉',
    '不能睡觉',
  ];

  /// 否定意图中，若同时含"提神/恢复/充能"信号 → energize，否则 → focus。
  static const List<String> _energizeInNegationKeywords = [
    '提神',
    '恢复',
    '充能',
    '提神醒脑',
  ];

  /// 第 2 优先级：睡眠强信号（失眠类），优先于任务目标。
  ///
  /// "备考压力大，晚上睡不着"应归 sleep，因为有强睡眠问题。
  static const List<String> _sleepStrongKeywords = [
    '睡不着',
    '失眠',
    '辗转',
    '夜醒',
    '入睡困难',
    '难以入眠',
    '夜里醒',
    '半夜醒',
  ];

  /// 第 3 优先级：明确任务目标 → focus。
  static const List<String> _focusKeywords = [
    '学习',
    '工作',
    '写论文',
    '写代码',
    '码代码',
    '编程',
    '专注',
    '集中注意力',
    '注意力',
    '备考',
    '看书',
    '复习',
    '考试',
    '解题',
    '进入状态',
    '学习状态',
    '进入学习',
    '稳定下来',
    '分心',
  ];

  /// 第 4 优先级：明确睡眠目标（温和睡眠意图）→ sleep。
  static const List<String> _sleepMildKeywords = [
    '想睡',
    '睡觉',
    '入睡',
    '睡前',
    '准备睡',
    '我要睡',
    '入眠',
    '睡眠',
    '想快速入眠',
  ];

  /// 第 5 优先级：强烈情绪激活 → regulate。
  static const List<String> _regulateKeywords = [
    '焦虑',
    '压力',
    '紧张',
    '慌',
    '烦躁',
    '愤怒',
    '火大',
    '生气',
    '气死',
    '吵架',
    '冲突',
    '委屈',
    '激动',
    '静不下心',
    '静不下来',
    '焦躁',
    '紧绷',
    '思绪过载',
    'deadline',
    'kpi',
    '加班',
    '高压',
    '想冷静',
    '情绪激动',
    '心里很慌',
    '压力大',
  ];

  /// 第 6 优先级：低能量强信号 → energize（在 soothe 之前，避免"运动后很空"误判）。
  static const List<String> _energizeStrongKeywords = [
    '运动后',
    '没状态',
    '没劲',
    '提不起劲',
    '提不起',
    '没精神',
    '醒来没状态',
    '充能',
    '恢复能量',
    '恢复一点能量',
    '低能量',
    '早上醒来',
    '刚睡醒',
    '睡醒后',
  ];

  /// 第 7 优先级：悲伤安抚 → soothe。
  static const List<String> _sootheKeywords = [
    '难过',
    '低落',
    '失落',
    '想哭',
    '沮丧',
    'emo',
    '抑郁',
    '孤独',
    '悲伤',
    '失恋',
    '伤心',
    '想被安慰',
    '安慰',
    '胸口闷',
    '很闷',
    '空虚',
    '很空',
    '感到空',
    '心里空',
    '沉重',
    '难受',
  ];

  /// 第 8 优先级：低能量（一般）→ energize。
  static const List<String> _energizeMildKeywords = [
    '疲惫',
    '累',
    '耗尽',
    '无力',
    '倦',
    '透支',
    '麻木',
    '精疲力',
    '虚',
  ];

  // ─────────────────────────────────────────────────────────────────────
  // 入口
  // ─────────────────────────────────────────────────────────────────────

  /// 根据 text + tags + valence/arousal + llmTargetState 修正 targetState。
  ///
  /// - [text]：用户原文（可为空，旧历史记录或 LLM 未传时）
  /// - [tags]：情绪标签（来自模板或 LLM）
  /// - [llmTargetState]：LLM/mock 返回的 targetState（作为 fallback）
  ///
  /// 返回修正后的 [TargetState]，保证非 null。
  static TargetState resolve({
    required String text,
    required List<String> tags,
    required double valence,
    required double arousal,
    required TargetState llmTargetState,
  }) {
    // 合并 text + tags 作为信号源（统一小写，中文不受影响）
    final lowerText = text.toLowerCase();
    final tagsText = tags.join(' ').toLowerCase();
    final signal = '$lowerText $tagsText';

    // 第 1 优先级：否定/反向意图
    if (_anyMatch(lowerText, _negationSleepKeywords)) {
      // 含"提神/恢复/充能"信号 → energize，否则 → focus
      if (_anyMatch(lowerText, _energizeInNegationKeywords)) {
        return TargetState.energize;
      }
      return TargetState.focus;
    }

    // 第 2 优先级：睡眠强信号（失眠类），优先于任务目标
    if (_anyMatch(signal, _sleepStrongKeywords)) {
      return TargetState.sleep;
    }

    // 第 3 优先级：明确任务目标 → focus
    if (_anyMatch(signal, _focusKeywords)) {
      return TargetState.focus;
    }

    // 第 4 优先级：明确睡眠目标（温和睡眠意图）→ sleep
    if (_anyMatch(signal, _sleepMildKeywords)) {
      return TargetState.sleep;
    }

    // 第 5 优先级：强烈情绪激活 → regulate
    if (_anyMatch(signal, _regulateKeywords)) {
      return TargetState.regulate;
    }

    // 第 6 优先级：低能量强信号 → energize（在 soothe 之前）
    if (_anyMatch(signal, _energizeStrongKeywords)) {
      return TargetState.energize;
    }

    // 第 7 优先级：原文含低能量 mild 信号 → energize（在 soothe 之前）。
    //
    // 为什么只看原文不看 tags：exhausted 模板的 tags 含"空虚"，而"空虚"也是
    // soothe 关键词。若混在一起判断，"我很疲惫"会因 tags 的"空虚"被 soothe 误捕获。
    // 只看原文能避免 tags 污染，让"我很疲惫""我很累"正确归 energize。
    if (_anyMatch(lowerText, _energizeMildKeywords)) {
      return TargetState.energize;
    }

    // 第 8 优先级：悲伤安抚 → soothe
    if (_anyMatch(signal, _sootheKeywords)) {
      return TargetState.soothe;
    }

    // 第 9 优先级：tags 含低能量 mild 信号 → energize（补充，原文无信号时）
    if (_anyMatch(tagsText, _energizeMildKeywords)) {
      return TargetState.energize;
    }

    // fallback：信任 LLM/mock 返回的 targetState
    // 向后兼容：relax 当作 regulate，company 当作 soothe
    switch (llmTargetState) {
      case TargetState.sleep:
        return TargetState.sleep;
      case TargetState.focus:
        return TargetState.focus;
      case TargetState.regulate:
        return TargetState.regulate;
      case TargetState.soothe:
        return TargetState.soothe;
      case TargetState.energize:
        return TargetState.energize;
      case TargetState.relax:
        return TargetState.regulate;
      case TargetState.company:
        return TargetState.soothe;
    }
  }

  /// 判断 [text] 是否包含 [keywords] 中任一关键词。
  static bool _anyMatch(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }
}
