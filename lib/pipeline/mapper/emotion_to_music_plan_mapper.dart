import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_plan_draft.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_template_registry.dart';

/// LLM 情绪画像 → 音乐方案的核心映射层（M5 新增）。
///
/// 取代 M1-M4 的"最近邻模板匹配"，让 LLM 返回的完整 [MoodProfile]
/// （含 [MoodProfile.targetState] / [MoodProfile.intensity] /
/// [MoodProfile.arousal] / [MoodProfile.valence] / [MoodProfile.tags] /
/// [MoodProfile.dominantNeed]）真正参与音乐方案生成。
///
/// 设计原则：
/// 1. UI 不直接调用本映射层（由 Pipeline 各 Port 内部调用）
/// 2. Mock 解析与 LLM 解析复用同一套映射逻辑（输入 MoodProfile 即可）
/// 3. 纯函数无副作用，多次调用结果一致
/// 4. 任何字段缺失/异常都不抛异常，自动 fallback 到默认方案
/// 5. 不接真实 AI 音乐生成模型，[MusicPlanDraft.generationPrompt] 仅生成文本
/// 6. 不夸大医疗效果，统一使用"辅助放松 / 情绪调节 / 睡前舒缓 / 正念陪伴"
///
/// 映射规则概述：
/// - 第 1 步：按 [MoodProfile.tags] 关键词修正 [TargetState]（失眠→sleep，焦虑→regulate/sleep，等）
/// - 第 2 步：按修正后的 targetState 取 5 套基础音乐参数（BPM 范围 / 脑波 / 乐器 / 噪音 / 和声）
/// - 第 3 步：按 [MoodProfile.arousal] 在 BPM 范围内插值（arousal 越高 BPM 越低）
/// - 第 4 步：按 [MoodProfile.valence] 调整和声色彩（越低越偏小调）
/// - 第 5 步：按 [MoodProfile.intensity] 调整动态描述（越高动态变化越少）
/// - 第 6 步：组合 [MusicPlanDraft.generationPrompt] 与 [MusicPlanDraft.explanation]
class EmotionToMusicPlanMapper {
  const EmotionToMusicPlanMapper();

  /// 单例无状态，可直接复用。
  static const EmotionToMusicPlanMapper instance = EmotionToMusicPlanMapper();

  /// 入口：将 [MoodProfile] 映射为 [MusicPlanDraft]。
  ///
  /// 任何字段异常都不抛异常，保证 LLM 异常时仍能 fallback。
  MusicPlanDraft map(MoodProfile profile) {
    // 第 1 步：按 tags 修正 targetState
    final effectiveState = _resolveTargetState(profile);

    // 第 2 步：取基础参数
    final base = _baseConfigFor(effectiveState);

    // 第 3 步：arousal 越高，BPM 越低（在范围内插值）
    final arousalClamped = profile.arousal.clamp(0.0, 1.0);
    final bpm = _bpmInRange(base.bpmLow, base.bpmHigh, arousalClamped);

    // 第 4 步：valence 越低，和声越偏小调
    final harmony = _harmonyForValence(profile.valence, base.baseHarmony);

    // 第 5 步：intensity 越高，动态越少
    final dynamicDesc = _dynamicForIntensity(profile.intensity);

    // 第 6 步：组合文案
    final title = _buildTitle(effectiveState);
    final guidance = _buildGuidance(effectiveState, profile);
    final explanation = _buildExplanation(
      effectiveState: effectiveState,
      profile: profile,
      bpm: bpm,
      brainwave: base.brainwave,
      instruments: base.instruments,
      noiseLayer: base.noiseLayer,
      harmony: harmony,
    );
    final generationPrompt = _buildGenerationPrompt(
      bpm: bpm,
      bpmRange: base.bpmRangeLabel,
      frequency: base.frequency,
      brainwave: base.brainwave,
      instruments: base.instruments,
      noiseLayer: base.noiseLayer,
      harmony: harmony,
      dynamicDesc: dynamicDesc,
      targetState: effectiveState,
      dominantNeed: profile.dominantNeed,
    );

    return MusicPlanDraft(
      title: title,
      templateName: title,
      bpmRange: base.bpmRangeLabel,
      bpm: bpm,
      baseFrequency: base.frequency,
      brainwaveTarget: base.brainwave,
      instruments: base.instruments,
      noiseLayer: base.noiseLayer,
      harmonyColor: harmony,
      generationPrompt: generationPrompt,
      explanation: explanation,
      guidance: guidance,
      audioAssetPath: MockTemplateRegistry.defaultAudio,
      durationMinutes: base.durationMinutes,
      intensity: profile.intensity,
      arousal: profile.arousal,
      valence: profile.valence,
      targetState: effectiveState,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // 第 1 步：按 tags 关键词修正 targetState
  // ───────────────────────────────────────────────────────────────────────

  /// 按 tags 关键词修正 targetState。
  ///
  /// 优先级：tags 强信号 > LLM 返回的 targetState > 默认 regulate。
  /// - 失眠 / 睡不着 / 夜晚 → sleep
  /// - 焦虑 / 压力 / 紧张 / 思绪过载 → regulate（arousal 高时）或 sleep（arousal 中低时）
  /// - 疲惫 / 空 / 内耗 → soothe（valence 低）或 energize（valence 中）
  /// - 烦躁 / 愤怒 / 静不下心 → regulate
  TargetState _resolveTargetState(MoodProfile profile) {
    final tags = profile.tags.map((e) => e.toLowerCase()).toList();
    final text = tags.join(' ');

    // 失眠类强信号
    const sleepKeywords = ['失眠', '睡不着', '夜晚', '夜里', '夜醒', '入睡', '辗转', '睡眠'];
    if (sleepKeywords.any((kw) => text.contains(kw))) {
      return TargetState.sleep;
    }

    // 烦躁 / 愤怒类
    const agitatedKeywords = ['烦躁', '愤怒', '火大', '生气', '气死', '静不下心', '吵架'];
    if (agitatedKeywords.any((kw) => text.contains(kw))) {
      return TargetState.regulate;
    }

    // 焦虑 / 压力 / 紧张类
    const anxietyKeywords = [
      '焦虑',
      '压力',
      '紧张',
      '紧绷',
      '思绪过载',
      '焦躁',
      'deadline',
      'kpi',
      '加班',
    ];
    if (anxietyKeywords.any((kw) => text.contains(kw))) {
      // arousal 高 → regulate（情绪降温）；arousal 中低 → sleep（睡前舒缓）
      return profile.arousal >= 0.6 ? TargetState.regulate : TargetState.sleep;
    }

    // 疲惫 / 空 / 内耗类
    const exhaustionKeywords = [
      '疲惫',
      '累',
      '耗尽',
      '无力',
      '空虚',
      '内耗',
      '麻木',
      '倦',
      '透支',
    ];
    if (exhaustionKeywords.any((kw) => text.contains(kw))) {
      // valence 低 → soothe（自我安抚）；valence 中 → energize（温和充能）
      return profile.valence < -0.3 ? TargetState.soothe : TargetState.energize;
    }

    // 低落 / 悲伤类
    const lowMoodKeywords = [
      '低落',
      '失落',
      '难过',
      '想哭',
      '沮丧',
      'emo',
      '抑郁',
      '孤独',
      '悲伤',
    ];
    if (lowMoodKeywords.any((kw) => text.contains(kw))) {
      return TargetState.soothe;
    }

    // 无强信号时，信任 LLM 返回的 targetState
    // 向后兼容：relax 当作 regulate，company 当作 soothe
    switch (profile.targetState) {
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

  // ───────────────────────────────────────────────────────────────────────
  // 第 2 步：5 套基础音乐参数
  // ───────────────────────────────────────────────────────────────────────

  _BaseMusicConfig _baseConfigFor(TargetState state) {
    switch (state) {
      case TargetState.sleep:
        return const _BaseMusicConfig(
          bpmLow: 45,
          bpmHigh: 60,
          bpmRangeLabel: '45-60',
          frequency: '432Hz',
          brainwave: 'Theta / Delta 入睡倾向',
          instruments: ['低频 Pad', '手碟', '柔和钢琴'],
          noiseLayer: '雨声 / 粉红噪音 / 低频环境音',
          baseHarmony: '模糊大调',
          durationMinutes: 30,
          goal: '睡前舒缓、降低唤醒度',
        );
      case TargetState.regulate:
        return const _BaseMusicConfig(
          bpmLow: 55,
          bpmHigh: 70,
          bpmRangeLabel: '55-70',
          frequency: '432Hz',
          brainwave: 'Alpha 放松倾向',
          instruments: ['柔和钢琴', '弦乐', 'Pad'],
          noiseLayer: '粉红噪音 / 轻白噪',
          baseHarmony: '小调 → 缓和过渡',
          durationMinutes: 20,
          goal: '缓解紧张、平复思绪',
        );
      case TargetState.soothe:
        return const _BaseMusicConfig(
          bpmLow: 50,
          bpmHigh: 68,
          bpmRangeLabel: '50-68',
          frequency: '432Hz',
          brainwave: 'Alpha 情绪安抚',
          instruments: ['竖琴', '大提琴', '柔和钢琴'],
          noiseLayer: '海浪 / 风声 / 粉红噪音',
          baseHarmony: '小调转大调',
          durationMinutes: 22,
          goal: '自我安抚、情绪陪伴',
        );
      case TargetState.focus:
        return const _BaseMusicConfig(
          bpmLow: 65,
          bpmHigh: 85,
          bpmRangeLabel: '65-85',
          frequency: '432Hz',
          brainwave: 'Alpha / Low Beta 稳定专注',
          instruments: ['极简钢琴', 'Marimba', '轻 Pad'],
          noiseLayer: '棕噪 / 轻环境音',
          baseHarmony: '中性大调',
          durationMinutes: 25,
          goal: '恢复专注和稳定节奏',
        );
      case TargetState.energize:
        return const _BaseMusicConfig(
          bpmLow: 72,
          bpmHigh: 92,
          bpmRangeLabel: '72-92',
          frequency: '432Hz',
          brainwave: 'Alpha uplift',
          instruments: ['木吉他', '长笛', '轻打击'],
          noiseLayer: '森林环境音 / 轻自然音',
          baseHarmony: '温暖大调',
          durationMinutes: 18,
          goal: '温和恢复能量，不做强刺激',
        );
      // relax / company 已在 _resolveTargetState 中映射到 5 类，
      // 此处仅为枚举穷尽性兜底
      case TargetState.relax:
        return _baseConfigFor(TargetState.regulate);
      case TargetState.company:
        return _baseConfigFor(TargetState.soothe);
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // 第 3 步：arousal 越高，BPM 越低
  // ───────────────────────────────────────────────────────────────────────

  /// 在 [low, high] 范围内根据 arousal 插值。
  /// arousal=1.0 → 取 low（最平稳）；arousal=0.0 → 取 high。
  /// 公式：bpm = low + (1 - arousal) * (high - low)
  int _bpmInRange(int low, int high, double arousal) {
    final raw = low + (1.0 - arousal) * (high - low);
    return raw.round().clamp(low, high);
  }

  // ───────────────────────────────────────────────────────────────────────
  // 第 4 步：valence 越低，和声越偏小调
  // ───────────────────────────────────────────────────────────────────────

  /// 根据效价调整和声色彩。
  /// - valence < -0.5：低明度小调
  /// - valence -0.5 ~ -0.2：小调 → 缓和过渡（保留 baseHarmony）
  /// - valence -0.2 ~ 0.2：中性 / 模糊大调（保留 baseHarmony）
  /// - valence > 0.2：温暖大调
  String _harmonyForValence(double valence, String baseHarmony) {
    if (valence <= -0.5) {
      return '低明度小调';
    }
    if (valence >= 0.3) {
      return '温暖大调';
    }
    // 中间区间保留 baseHarmony（已由 5 套基础配置决定）
    return baseHarmony;
  }

  // ───────────────────────────────────────────────────────────────────────
  // 第 5 步：intensity 越高，动态变化越少
  // ───────────────────────────────────────────────────────────────────────

  /// 根据情绪强度返回动态描述（用于 generationPrompt）。
  String _dynamicForIntensity(double intensity) {
    if (intensity >= 0.7) {
      return '稳定低动态，避免突然起伏';
    }
    if (intensity >= 0.4) {
      return '温和中动态，缓慢起伏';
    }
    return '自然流动，允许轻柔起伏';
  }

  // ───────────────────────────────────────────────────────────────────────
  // 第 6 步：组合文案
  // ───────────────────────────────────────────────────────────────────────

  String _buildTitle(TargetState state) {
    switch (state) {
      case TargetState.sleep:
        return '睡前舒缓 · Theta 入眠方案';
      case TargetState.regulate:
        return '情绪调节 · Alpha 降频方案';
      case TargetState.soothe:
        return '正念陪伴 · 情绪安抚方案';
      case TargetState.focus:
        return '专注恢复 · 稳定节奏方案';
      case TargetState.energize:
        return '温和充能 · 自然回暖方案';
      case TargetState.relax:
        return _buildTitle(TargetState.regulate);
      case TargetState.company:
        return _buildTitle(TargetState.soothe);
    }
  }

  String _buildGuidance(TargetState state, MoodProfile profile) {
    final need = profile.dominantNeed;
    switch (state) {
      case TargetState.sleep:
        return need != null
            ? '跟随雨声与低频 Pad，让意识慢慢沉入夜色。主导需求：$need。'
            : '跟随雨声与低频 Pad，让意识慢慢沉入夜色。';
      case TargetState.regulate:
        return need != null
            ? '让呼吸跟着琴声慢下来，把紧张交给旋律。主导需求：$need。'
            : '让呼吸跟着琴声慢下来，把紧张交给旋律。';
      case TargetState.soothe:
        return need != null
            ? '允许自己此刻的感受，琴声会陪你慢慢回暖。主导需求：$need。'
            : '允许自己此刻的感受，琴声会陪你慢慢回暖。';
      case TargetState.focus:
        return need != null
            ? '在简洁的节奏里找回呼吸，让注意力一点点归位。主导需求：$need。'
            : '在简洁的节奏里找回呼吸，让注意力一点点归位。';
      case TargetState.energize:
        return need != null
            ? '让自然声与木吉他轻轻托起你，温和恢复能量。主导需求：$need。'
            : '让自然声与木吉他轻轻托起你，温和恢复能量。';
      case TargetState.relax:
        return _buildGuidance(TargetState.regulate, profile);
      case TargetState.company:
        return _buildGuidance(TargetState.soothe, profile);
    }
  }

  String _buildExplanation({
    required TargetState effectiveState,
    required MoodProfile profile,
    required int bpm,
    required String brainwave,
    required List<String> instruments,
    required String noiseLayer,
    required String harmony,
  }) {
    final summary = profile.summary.isNotEmpty ? profile.summary : '你描述的状态';
    final instrumentsText = instruments.take(2).join('与');
    final stateLabel = _stateLabel(effectiveState);

    return '根据"$summary"，方案选择 $brainwave 配合 $instrumentsText 与 $noiseLayer，'
        'BPM 约 $bpm、和声 $harmony，用于$stateLabel。'
        '这是一段音乐陪伴，不是医疗手段，帮助你进行辅助放松与情绪调节。';
  }

  String _stateLabel(TargetState state) {
    switch (state) {
      case TargetState.sleep:
        return '睡前舒缓、降低唤醒度';
      case TargetState.regulate:
        return '情绪调节、缓解紧张';
      case TargetState.soothe:
        return '正念陪伴、自我安抚';
      case TargetState.focus:
        return '恢复专注、稳定节奏';
      case TargetState.energize:
        return '温和恢复能量';
      case TargetState.relax:
        return _stateLabel(TargetState.regulate);
      case TargetState.company:
        return _stateLabel(TargetState.soothe);
    }
  }

  String _buildGenerationPrompt({
    required int bpm,
    required String bpmRange,
    required String frequency,
    required String brainwave,
    required List<String> instruments,
    required String noiseLayer,
    required String harmony,
    required String dynamicDesc,
    required TargetState targetState,
    String? dominantNeed,
  }) {
    final instrumentsText = instruments.join(' / ');
    final needClause = dominantNeed != null && dominantNeed.isNotEmpty
        ? '；主导需求：$dominantNeed'
        : '';
    return 'BPM $bpm（范围 $bpmRange），$frequency，$brainwave，'
        '乐器：$instrumentsText，噪音层：$noiseLayer，和声：$harmony，'
        '$dynamicDesc。目标：${_stateLabel(targetState)}$needClause。';
  }
}

/// 内部：5 套基础音乐参数配置。
class _BaseMusicConfig {
  final int bpmLow;
  final int bpmHigh;
  final String bpmRangeLabel;
  final String frequency;
  final String brainwave;
  final List<String> instruments;
  final String noiseLayer;
  final String baseHarmony;
  final int durationMinutes;
  final String goal;

  const _BaseMusicConfig({
    required this.bpmLow,
    required this.bpmHigh,
    required this.bpmRangeLabel,
    required this.frequency,
    required this.brainwave,
    required this.instruments,
    required this.noiseLayer,
    required this.baseHarmony,
    required this.durationMinutes,
    required this.goal,
  });
}
