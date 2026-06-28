import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/pipeline/mapper/emotion_to_music_plan_mapper.dart';
import 'package:xinxian_healing_music/pipeline/mock/rule_based_feature_extractor.dart';

/// M5 EmotionToMusicPlanMapper 测试。
///
/// 覆盖：
/// 1. 5 类 targetState（sleep / regulate / soothe / focus / energize）基础映射
/// 2. arousal 对 BPM 的影响（arousal 越高 BPM 越低）
/// 3. intensity 对动态描述的影响
/// 4. valence 对和声色彩的影响
/// 5. tags 关键词修正 targetState
/// 6. LLM 异常 / 字段缺失时 fallback 不崩溃
/// 7. mock 与 LLM 复用同一映射逻辑（通过 RuleBasedFeatureExtractor 验证）
void main() {
  const mapper = EmotionToMusicPlanMapper.instance;
  const extractor = RuleBasedFeatureExtractor();

  group('EmotionToMusicPlanMapper - 5 类 targetState 基础映射', () {
    test('sleep：BPM 45-60，Theta/Delta 入睡倾向，雨声/粉红噪音', () {
      final profile = MoodProfile(
        tags: const ['失眠', '睡不着'],
        valence: -0.2,
        arousal: 0.6,
        intensity: 0.7,
        summary: '夜晚思绪难止',
        targetState: TargetState.sleep,
        dominantNeed: '快速入眠',
      );
      final draft = mapper.map(profile);

      expect(draft.targetState, TargetState.sleep);
      expect(draft.bpmRange, '45-60');
      expect(draft.bpm, inInclusiveRange(45, 60));
      expect(draft.baseFrequency, '432Hz');
      expect(draft.brainwaveTarget, contains('Theta'));
      expect(draft.brainwaveTarget, contains('Delta'));
      expect(draft.noiseLayer, contains('雨声'));
      expect(draft.instruments, containsAll(['低频 Pad', '手碟', '柔和钢琴']));
      expect(draft.durationMinutes, 30);
      expect(draft.title, contains('睡前舒缓'));
      expect(draft.audioAssetPath, 'music/music_01.mp3');
    });

    test('regulate：BPM 55-70，Alpha 放松倾向，粉红噪音/轻白噪', () {
      final profile = MoodProfile(
        tags: const ['焦虑', '压力'],
        valence: -0.4,
        arousal: 0.8,
        intensity: 0.8,
        summary: '承受较大压力',
        targetState: TargetState.regulate,
        dominantNeed: '情绪降温',
      );
      final draft = mapper.map(profile);

      expect(draft.targetState, TargetState.regulate);
      expect(draft.bpmRange, '55-70');
      expect(draft.bpm, inInclusiveRange(55, 70));
      expect(draft.brainwaveTarget, contains('Alpha'));
      expect(draft.noiseLayer, contains('粉红噪音'));
      expect(draft.instruments, containsAll(['柔和钢琴', '弦乐', 'Pad']));
      expect(draft.durationMinutes, 20);
      expect(draft.title, contains('情绪调节'));
    });

    test('soothe：BPM 50-68，Alpha 情绪安抚，海浪/风声/粉红噪音', () {
      final profile = MoodProfile(
        tags: const ['低落', '失落'],
        valence: -0.6,
        arousal: 0.3,
        intensity: 0.6,
        summary: '情绪有些下沉',
        targetState: TargetState.soothe,
        dominantNeed: '被温柔接住',
      );
      final draft = mapper.map(profile);

      expect(draft.targetState, TargetState.soothe);
      expect(draft.bpmRange, '50-68');
      expect(draft.bpm, inInclusiveRange(50, 68));
      expect(draft.brainwaveTarget, contains('Alpha'));
      expect(draft.noiseLayer, contains('海浪'));
      expect(draft.instruments, containsAll(['竖琴', '大提琴', '柔和钢琴']));
      expect(draft.durationMinutes, 22);
      expect(draft.title, contains('正念陪伴'));
    });

    test('focus：BPM 65-85，Alpha / Low Beta 稳定专注，棕噪/轻环境音', () {
      final profile = MoodProfile(
        tags: const ['分心', '无法专注'],
        valence: 0.0,
        arousal: 0.5,
        intensity: 0.4,
        summary: '注意力难以集中',
        targetState: TargetState.focus,
        dominantNeed: '恢复专注',
      );
      final draft = mapper.map(profile);

      expect(draft.targetState, TargetState.focus);
      expect(draft.bpmRange, '65-85');
      expect(draft.bpm, inInclusiveRange(65, 85));
      expect(draft.brainwaveTarget, contains('Low Beta'));
      expect(draft.noiseLayer, contains('棕噪'));
      expect(draft.instruments, containsAll(['极简钢琴', 'Marimba', '轻 Pad']));
      expect(draft.durationMinutes, 25);
      expect(draft.title, contains('专注恢复'));
    });

    test('energize：BPM 72-92，Alpha uplift，森林环境音/轻自然音', () {
      final profile = MoodProfile(
        tags: const ['疲惫', '耗尽'],
        valence: 0.0,
        arousal: 0.2,
        intensity: 0.5,
        summary: '能量耗尽',
        targetState: TargetState.energize,
        dominantNeed: '温柔充能',
      );
      final draft = mapper.map(profile);

      expect(draft.targetState, TargetState.energize);
      expect(draft.bpmRange, '72-92');
      expect(draft.bpm, inInclusiveRange(72, 92));
      expect(draft.brainwaveTarget, contains('Alpha uplift'));
      expect(draft.noiseLayer, contains('森林'));
      expect(draft.instruments, containsAll(['木吉他', '长笛', '轻打击']));
      expect(draft.durationMinutes, 18);
      expect(draft.title, contains('温和充能'));
    });
  });

  group('arousal 对 BPM 的影响（arousal 越高 BPM 越低）', () {
    test('相同 sleep targetState，arousal 1.0 比 0.0 BPM 更低', () {
      final highArousal = mapper.map(
        const MoodProfile(
          tags: ['失眠'],
          valence: -0.2,
          arousal: 1.0,
          summary: '极度清醒',
          targetState: TargetState.sleep,
        ),
      );
      final lowArousal = mapper.map(
        const MoodProfile(
          tags: ['失眠'],
          valence: -0.2,
          arousal: 0.0,
          summary: '微微困倦',
          targetState: TargetState.sleep,
        ),
      );
      // arousal=1.0 → BPM=45（范围下限）；arousal=0.0 → BPM=60（范围上限）
      expect(highArousal.bpm, lessThanOrEqualTo(lowArousal.bpm));
      expect(highArousal.bpm, 45);
      expect(lowArousal.bpm, 60);
    });

    test('相同 regulate targetState，arousal 越高 BPM 越低', () {
      final high = mapper.map(
        const MoodProfile(
          tags: ['焦虑'],
          valence: -0.4,
          arousal: 0.9,
          summary: '高度焦虑',
          targetState: TargetState.regulate,
        ),
      );
      final low = mapper.map(
        const MoodProfile(
          tags: ['焦虑'],
          valence: -0.4,
          arousal: 0.1,
          summary: '轻度紧张',
          targetState: TargetState.regulate,
        ),
      );
      expect(high.bpm, lessThan(low.bpm));
    });
  });

  group('intensity 对动态描述的影响', () {
    test('intensity >= 0.7 时 generationPrompt 含"稳定低动态"', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['焦虑'],
          valence: -0.4,
          arousal: 0.8,
          intensity: 0.9,
          summary: '高强度焦虑',
          targetState: TargetState.regulate,
        ),
      );
      expect(draft.generationPrompt, contains('稳定低动态'));
    });

    test('intensity 0.4-0.7 时 generationPrompt 含"温和中动态"', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['焦虑'],
          valence: -0.4,
          arousal: 0.5,
          intensity: 0.5,
          summary: '中度焦虑',
          targetState: TargetState.regulate,
        ),
      );
      expect(draft.generationPrompt, contains('温和中动态'));
    });

    test('intensity < 0.4 时 generationPrompt 含"自然流动"', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['分心'],
          valence: 0.0,
          arousal: 0.4,
          intensity: 0.2,
          summary: '轻度分心',
          targetState: TargetState.focus,
        ),
      );
      expect(draft.generationPrompt, contains('自然流动'));
    });
  });

  group('valence 对和声色彩的影响', () {
    test('valence <= -0.5 时和声为"低明度小调"', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['低落'],
          valence: -0.7,
          arousal: 0.3,
          summary: '极度低落',
          targetState: TargetState.soothe,
        ),
      );
      expect(draft.harmonyColor, '低明度小调');
    });

    test('valence >= 0.3 时和声为"温暖大调"', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['疲惫'],
          valence: 0.4,
          arousal: 0.2,
          summary: '需要充能',
          targetState: TargetState.energize,
        ),
      );
      expect(draft.harmonyColor, '温暖大调');
    });

    test('valence 中间区间保留 baseHarmony', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['焦虑'],
          valence: -0.3,
          arousal: 0.6,
          summary: '中等焦虑',
          targetState: TargetState.regulate,
        ),
      );
      // regulate 的 baseHarmony 是 "小调 → 缓和过渡"
      expect(draft.harmonyColor, '小调 → 缓和过渡');
    });
  });

  group('tags 关键词修正 targetState', () {
    test('tags 含"失眠"优先映射到 sleep（即使 LLM 返回 focus）', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['失眠', '睡不着'],
          valence: 0.0,
          arousal: 0.5,
          summary: '夜晚睡不着',
          targetState: TargetState.focus, // LLM 返回 focus
        ),
      );
      expect(draft.targetState, TargetState.sleep);
    });

    test('tags 含"焦虑"+ arousal 高 → regulate', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['焦虑', '压力'],
          valence: -0.4,
          arousal: 0.8,
          summary: '焦虑',
          targetState: TargetState.relax,
        ),
      );
      expect(draft.targetState, TargetState.regulate);
    });

    test('tags 含"焦虑" → regulate（M6.1：不再按 arousal 区分 sleep/regulate）', () {
      // M5 原逻辑：焦虑 + arousal 低 → sleep
      // M6.1 改为：焦虑 → regulate（固定），因为焦虑更偏情绪降温
      // 睡眠意图由 sleep 关键词（失眠/睡不着/想睡）单独识别
      final draft = mapper.map(
        const MoodProfile(
          tags: ['焦虑'],
          valence: -0.4,
          arousal: 0.3,
          summary: '夜间焦虑',
          targetState: TargetState.relax,
        ),
      );
      expect(draft.targetState, TargetState.regulate);
    });

    test('tags 含"烦躁" → regulate', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['烦躁', '静不下心'],
          valence: -0.5,
          arousal: 0.9,
          summary: '烦躁',
          targetState: TargetState.relax,
        ),
      );
      expect(draft.targetState, TargetState.regulate);
    });

    test('tags 含"疲惫" → energize（M6.1：不再按 valence 区分 soothe/energize）', () {
      // M5 原逻辑：疲惫 + valence 低 → soothe
      // M6.1 改为：疲惫 → energize（固定），因为疲惫更偏低能量恢复
      // 悲伤安抚由 soothe 关键词（难过/低落/孤独）单独识别
      final draft = mapper.map(
        const MoodProfile(
          tags: ['疲惫', '内耗'],
          valence: -0.5,
          arousal: 0.2,
          summary: '耗竭',
          targetState: TargetState.relax,
        ),
      );
      expect(draft.targetState, TargetState.energize);
    });

    test('tags 含"疲惫"+ valence 中 → energize', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['疲惫'],
          valence: 0.0,
          arousal: 0.2,
          summary: '需要充能',
          targetState: TargetState.relax,
        ),
      );
      expect(draft.targetState, TargetState.energize);
    });

    test('tags 含"低落" → soothe', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['低落', '难过'],
          valence: -0.6,
          arousal: 0.3,
          summary: '低落',
          targetState: TargetState.relax,
        ),
      );
      expect(draft.targetState, TargetState.soothe);
    });

    test('无强信号 tags 时信任 LLM 返回的 targetState', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['复杂心情'],
          valence: 0.0,
          arousal: 0.5,
          summary: '说不清',
          targetState: TargetState.focus,
        ),
      );
      expect(draft.targetState, TargetState.focus);
    });
  });

  group('向后兼容：relax / company 旧值', () {
    test('targetState.relax 当作 regulate 处理', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['调和'],
          valence: 0.2,
          arousal: 0.4,
          summary: '平稳',
          targetState: TargetState.relax,
        ),
      );
      expect(draft.targetState, TargetState.regulate);
      expect(draft.bpmRange, '55-70');
    });

    test('targetState.company 当作 soothe 处理', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['温和'],
          valence: 0.1,
          arousal: 0.3,
          summary: '需要陪伴',
          targetState: TargetState.company,
        ),
      );
      expect(draft.targetState, TargetState.soothe);
      expect(draft.bpmRange, '50-68');
    });
  });

  group('LLM 异常 / 字段缺失时 fallback 不崩溃', () {
    test('空 tags + 默认 valence/arousal 不崩溃', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: [],
          valence: 0.0,
          arousal: 0.4,
          summary: '',
          targetState: TargetState.relax,
        ),
      );
      expect(draft.targetState, TargetState.regulate);
      expect(draft.bpm, inInclusiveRange(55, 70));
      expect(draft.title, isNotEmpty);
      expect(draft.generationPrompt, isNotEmpty);
      expect(draft.explanation, isNotEmpty);
    });

    test('arousal 超出 0-1 范围不崩溃（自动 clamp）', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['焦虑'],
          valence: -0.4,
          arousal: 5.0, // 异常值
          intensity: 0.8,
          summary: '极度焦虑',
          targetState: TargetState.regulate,
        ),
      );
      expect(draft.bpm, inInclusiveRange(55, 70));
    });

    test('valence 超出 -1..1 范围不崩溃', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['低落'],
          valence: -5.0, // 异常值
          arousal: 0.3,
          summary: '极度低落',
          targetState: TargetState.soothe,
        ),
      );
      expect(draft.harmonyColor, '低明度小调');
    });

    test('intensity 超出 0-1 范围不崩溃', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['焦虑'],
          valence: -0.4,
          arousal: 0.8,
          intensity: 99.0, // 异常值
          summary: '异常强度',
          targetState: TargetState.regulate,
        ),
      );
      expect(draft.generationPrompt, contains('稳定低动态'));
    });

    test('dominantNeed 为 null 时 guidance 不含"主导需求"', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['失眠'],
          valence: -0.2,
          arousal: 0.6,
          summary: '失眠',
          targetState: TargetState.sleep,
          // dominantNeed 不传
        ),
      );
      expect(draft.guidance, isNot(contains('主导需求')));
      expect(draft.guidance, isNotEmpty);
    });

    test('summary 为空时 explanation 仍能生成（使用兜底文案）', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['失眠'],
          valence: -0.2,
          arousal: 0.6,
          summary: '',
          targetState: TargetState.sleep,
        ),
      );
      expect(draft.explanation, isNotEmpty);
      expect(draft.explanation, contains('音乐陪伴'));
    });
  });

  group('文案不夸大医疗效果', () {
    test('explanation 不包含"治疗"字样', () {
      final profiles = [
        MoodProfile(
          tags: const ['失眠'],
          valence: -0.2,
          arousal: 0.6,
          summary: '失眠',
          targetState: TargetState.sleep,
        ),
        MoodProfile(
          tags: const ['焦虑'],
          valence: -0.4,
          arousal: 0.8,
          summary: '焦虑',
          targetState: TargetState.regulate,
        ),
        MoodProfile(
          tags: const ['低落'],
          valence: -0.6,
          arousal: 0.3,
          summary: '低落',
          targetState: TargetState.soothe,
        ),
      ];
      for (final p in profiles) {
        final draft = mapper.map(p);
        expect(draft.explanation, isNot(contains('治疗')));
        expect(draft.explanation, isNot(contains('治愈')));
        expect(draft.guidance, isNot(contains('治疗')));
      }
    });

    test('explanation 包含"辅助放松"或"情绪调节"等温和措辞', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['焦虑'],
          valence: -0.4,
          arousal: 0.8,
          summary: '焦虑',
          targetState: TargetState.regulate,
        ),
      );
      expect(
        draft.explanation,
        anyOf(
          contains('辅助放松'),
          contains('情绪调节'),
          contains('睡前舒缓'),
          contains('正念陪伴'),
        ),
      );
    });
  });

  group('RuleBasedFeatureExtractor 复用同一映射逻辑', () {
    test('extractor 输出与 mapper 输出字段一致', () async {
      final profile = MoodProfile(
        tags: const ['失眠', '睡不着'],
        valence: -0.2,
        arousal: 0.6,
        intensity: 0.7,
        summary: '夜晚思绪难止',
        targetState: TargetState.sleep,
        dominantNeed: '快速入眠',
      );
      final draft = mapper.map(profile);
      final features = await extractor.extract(profile);

      expect(features.bpm, draft.bpm);
      expect(features.bpmRange, draft.bpmRange);
      expect(features.frequency, draft.baseFrequency);
      expect(features.brainwave, draft.brainwaveTarget);
      expect(features.instruments, draft.instruments);
      expect(features.harmony, draft.harmonyColor);
      expect(features.noiseLayer, draft.noiseLayer);
      expect(features.durationMinutes, draft.durationMinutes);
      expect(features.title, draft.title);
      expect(features.generationPrompt, draft.generationPrompt);
      expect(features.explanation, draft.explanation);
      expect(features.targetRegulationState, draft.targetState);
      expect(features.intensity, draft.intensity);
      expect(features.arousal, draft.arousal);
      expect(features.valence, draft.valence);
    });

    test('Mock 解析与 LLM 解析复用同一 extractor（保证映射一致性）', () async {
      // 模拟 MockMoodAnalyzer 返回的 profile
      final mockProfile = MoodProfile(
        tags: const ['焦虑', '紧绷', '高压'],
        valence: -0.4,
        arousal: 0.8,
        intensity: 0.8,
        summary: '高压焦虑',
        targetState: TargetState.regulate,
        dominantNeed: '情绪降温',
      );
      // 模拟 LLM 返回的 profile（同语义）
      final llmProfile = MoodProfile(
        tags: const ['焦虑', '紧绷', '高压'],
        valence: -0.4,
        arousal: 0.8,
        intensity: 0.8,
        summary: '高压焦虑',
        targetState: TargetState.regulate,
        dominantNeed: '情绪降温',
      );

      final mockFeatures = await extractor.extract(mockProfile);
      final llmFeatures = await extractor.extract(llmProfile);

      // 同输入同输出，证明映射逻辑一致
      expect(mockFeatures.bpm, llmFeatures.bpm);
      expect(mockFeatures.title, llmFeatures.title);
      expect(mockFeatures.generationPrompt, llmFeatures.generationPrompt);
    });
  });

  group('MusicPlanDraft 完整性', () {
    test('所有字段非空（除 dominantNeed 可空）', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['失眠'],
          valence: -0.2,
          arousal: 0.6,
          intensity: 0.7,
          summary: '失眠',
          targetState: TargetState.sleep,
          dominantNeed: '快速入眠',
        ),
      );
      expect(draft.title, isNotEmpty);
      expect(draft.templateName, isNotEmpty);
      expect(draft.bpmRange, isNotEmpty);
      expect(draft.baseFrequency, isNotEmpty);
      expect(draft.brainwaveTarget, isNotEmpty);
      expect(draft.instruments, isNotEmpty);
      expect(draft.noiseLayer, isNotEmpty);
      expect(draft.harmonyColor, isNotEmpty);
      expect(draft.generationPrompt, isNotEmpty);
      expect(draft.explanation, isNotEmpty);
      expect(draft.guidance, isNotEmpty);
      expect(draft.audioAssetPath, isNotEmpty);
      expect(draft.durationMinutes, greaterThan(0));
    });

    test('generationPrompt 包含 BPM / 频率 / 脑波 / 乐器 / 噪音 / 和声 / 动态', () {
      final draft = mapper.map(
        const MoodProfile(
          tags: ['失眠'],
          valence: -0.2,
          arousal: 0.6,
          intensity: 0.7,
          summary: '失眠',
          targetState: TargetState.sleep,
          dominantNeed: '快速入眠',
        ),
      );
      final prompt = draft.generationPrompt;
      expect(prompt, contains('BPM'));
      expect(prompt, contains('432Hz'));
      expect(prompt, contains('Theta'));
      expect(prompt, contains('Pad'));
      expect(prompt, contains('雨声'));
      expect(prompt, contains('动态'));
      expect(prompt, contains('主导需求：快速入眠'));
    });
  });
}
