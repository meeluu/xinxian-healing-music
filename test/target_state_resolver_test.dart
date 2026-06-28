import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_pipeline_factory.dart';

/// M6.1 TargetStateResolver 端到端测试。
///
/// 通过 mockPipeline.run(text) 走完整 Pipeline：
///   MockMoodAnalyzer（模板匹配 + resolver 修正）→ mapper（resolver 再次修正）
///   → StockAudioGenerator（AudioAssetCatalog 匹配）→ plan
///
/// 每条断言：
/// 1. plan.features.targetRegulationState（最终 targetState）
/// 2. plan.features.brainwave（脑波倾向，与 targetState 匹配）
/// 3. plan.audio.assetPath（音频资源路径）
///
/// 覆盖：
/// - 5 类 targetState 各 5 条典型输入（共 25 条）
/// - 6 条冲突意图测试（否定 / 多信号优先级）
void main() {
  /// 端到端断言 helper：运行 pipeline 并校验三要素。
  Future<void> expectPlanMatches(
    String text, {
    required TargetState expectedState,
    required String expectedBrainwaveContains,
    required String expectedAudioPath,
  }) async {
    final plan = await mockPipeline.run(text);
    expect(
      plan.features.targetRegulationState,
      expectedState,
      reason: '输入「$text」的 targetState 应为 ${expectedState.name}',
    );
    expect(
      plan.features.brainwave,
      contains(expectedBrainwaveContains),
      reason:
          '输入「$text」的脑波倾向应包含 "$expectedBrainwaveContains"，'
          '实际为 "${plan.features.brainwave}"',
    );
    expect(
      plan.audio.assetPath,
      expectedAudioPath,
      reason:
          '输入「$text」的音频路径应为 $expectedAudioPath，'
          '实际为 "${plan.audio.assetPath}"',
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // sleep：睡前舒缓 / 入睡（5 条）
  // 期望：targetState=sleep, brainwave 含 Theta, audio=sleep_01.mp3
  // ─────────────────────────────────────────────────────────────────────
  group('sleep 意图识别（睡前舒缓 / 入睡）', () {
    test('我想睡觉 → sleep', () async {
      await expectPlanMatches(
        '我想睡觉',
        expectedState: TargetState.sleep,
        expectedBrainwaveContains: 'Theta',
        expectedAudioPath: 'music/sleep_01.mp3',
      );
    });
    test('准备睡觉 → sleep', () async {
      await expectPlanMatches(
        '准备睡觉',
        expectedState: TargetState.sleep,
        expectedBrainwaveContains: 'Theta',
        expectedAudioPath: 'music/sleep_01.mp3',
      );
    });
    test('晚上睡不着 → sleep', () async {
      await expectPlanMatches(
        '晚上睡不着',
        expectedState: TargetState.sleep,
        expectedBrainwaveContains: 'Theta',
        expectedAudioPath: 'music/sleep_01.mp3',
      );
    });
    test('失眠 → sleep', () async {
      await expectPlanMatches(
        '失眠',
        expectedState: TargetState.sleep,
        expectedBrainwaveContains: 'Theta',
        expectedAudioPath: 'music/sleep_01.mp3',
      );
    });
    test('脑子停不下来，想入睡 → sleep', () async {
      await expectPlanMatches(
        '脑子停不下来，想入睡',
        expectedState: TargetState.sleep,
        expectedBrainwaveContains: 'Theta',
        expectedAudioPath: 'music/sleep_01.mp3',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // regulate：焦虑压力 / 紧张烦躁 / 情绪降温（5 条）
  // 期望：targetState=regulate, brainwave 含 Alpha 放松, audio=regulate_01.mp3
  // ─────────────────────────────────────────────────────────────────────
  group('regulate 意图识别（焦虑压力 / 情绪降温）', () {
    test('我很焦虑 → regulate', () async {
      await expectPlanMatches(
        '我很焦虑',
        expectedState: TargetState.regulate,
        expectedBrainwaveContains: 'Alpha 放松',
        expectedAudioPath: 'music/regulate_01.mp3',
      );
    });
    test('压力很大 → regulate', () async {
      await expectPlanMatches(
        '压力很大',
        expectedState: TargetState.regulate,
        expectedBrainwaveContains: 'Alpha 放松',
        expectedAudioPath: 'music/regulate_01.mp3',
      );
    });
    test('心里很慌 → regulate', () async {
      await expectPlanMatches(
        '心里很慌',
        expectedState: TargetState.regulate,
        expectedBrainwaveContains: 'Alpha 放松',
        expectedAudioPath: 'music/regulate_01.mp3',
      );
    });
    test('烦躁，静不下来 → regulate', () async {
      await expectPlanMatches(
        '烦躁，静不下来',
        expectedState: TargetState.regulate,
        expectedBrainwaveContains: 'Alpha 放松',
        expectedAudioPath: 'music/regulate_01.mp3',
      );
    });
    test('和别人吵架后很生气 → regulate', () async {
      await expectPlanMatches(
        '和别人吵架后很生气',
        expectedState: TargetState.regulate,
        expectedBrainwaveContains: 'Alpha 放松',
        expectedAudioPath: 'music/regulate_01.mp3',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // soothe：低落悲伤 / 需要安抚 / 情绪陪伴（5 条）
  // 期望：targetState=soothe, brainwave 含 Alpha 情绪安抚, audio=soothe_01.mp3
  // ─────────────────────────────────────────────────────────────────────
  group('soothe 意图识别（低落悲伤 / 情绪安抚）', () {
    test('我很难过 → soothe', () async {
      await expectPlanMatches(
        '我很难过',
        expectedState: TargetState.soothe,
        expectedBrainwaveContains: 'Alpha 情绪安抚',
        expectedAudioPath: 'music/soothe_01.mp3',
      );
    });
    test('最近很低落 → soothe', () async {
      await expectPlanMatches(
        '最近很低落',
        expectedState: TargetState.soothe,
        expectedBrainwaveContains: 'Alpha 情绪安抚',
        expectedAudioPath: 'music/soothe_01.mp3',
      );
    });
    test('失恋了，很伤心 → soothe', () async {
      await expectPlanMatches(
        '失恋了，很伤心',
        expectedState: TargetState.soothe,
        expectedBrainwaveContains: 'Alpha 情绪安抚',
        expectedAudioPath: 'music/soothe_01.mp3',
      );
    });
    test('想被安慰 → soothe', () async {
      await expectPlanMatches(
        '想被安慰',
        expectedState: TargetState.soothe,
        expectedBrainwaveContains: 'Alpha 情绪安抚',
        expectedAudioPath: 'music/soothe_01.mp3',
      );
    });
    test('很孤独 → soothe', () async {
      await expectPlanMatches(
        '很孤独',
        expectedState: TargetState.soothe,
        expectedBrainwaveContains: 'Alpha 情绪安抚',
        expectedAudioPath: 'music/soothe_01.mp3',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // focus：专注学习 / 工作 / 备考 / 稳定注意力（5 条）
  // 期望：targetState=focus, brainwave 含 Low Beta, audio=focus_01.mp3
  // ─────────────────────────────────────────────────────────────────────
  group('focus 意图识别（专注学习 / 稳定注意力）', () {
    test('我想专注学习 → focus', () async {
      await expectPlanMatches(
        '我想专注学习',
        expectedState: TargetState.focus,
        expectedBrainwaveContains: 'Low Beta',
        expectedAudioPath: 'music/focus_01.mp3',
      );
    });
    test('想进入学习状态 → focus', () async {
      await expectPlanMatches(
        '想进入学习状态',
        expectedState: TargetState.focus,
        expectedBrainwaveContains: 'Low Beta',
        expectedAudioPath: 'music/focus_01.mp3',
      );
    });
    test('工作时想提高专注 → focus', () async {
      await expectPlanMatches(
        '工作时想提高专注',
        expectedState: TargetState.focus,
        expectedBrainwaveContains: 'Low Beta',
        expectedAudioPath: 'music/focus_01.mp3',
      );
    });
    test('备考需要集中注意力 → focus', () async {
      await expectPlanMatches(
        '备考需要集中注意力',
        expectedState: TargetState.focus,
        expectedBrainwaveContains: 'Low Beta',
        expectedAudioPath: 'music/focus_01.mp3',
      );
    });
    test('想写代码 → focus', () async {
      await expectPlanMatches(
        '想写代码',
        expectedState: TargetState.focus,
        expectedBrainwaveContains: 'Low Beta',
        expectedAudioPath: 'music/focus_01.mp3',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // energize：疲惫低能量 / 温和恢复（5 条）
  // 期望：targetState=energize, brainwave 含 uplift, audio=energize_01.mp3
  // ─────────────────────────────────────────────────────────────────────
  group('energize 意图识别（疲惫低能量 / 温和恢复）', () {
    test('我很疲惫 → energize', () async {
      await expectPlanMatches(
        '我很疲惫',
        expectedState: TargetState.energize,
        expectedBrainwaveContains: 'uplift',
        expectedAudioPath: 'music/energize_01.mp3',
      );
    });
    test('提不起劲 → energize', () async {
      await expectPlanMatches(
        '提不起劲',
        expectedState: TargetState.energize,
        expectedBrainwaveContains: 'uplift',
        expectedAudioPath: 'music/energize_01.mp3',
      );
    });
    test('没精神 → energize', () async {
      await expectPlanMatches(
        '没精神',
        expectedState: TargetState.energize,
        expectedBrainwaveContains: 'uplift',
        expectedAudioPath: 'music/energize_01.mp3',
      );
    });
    test('想恢复一点能量 → energize', () async {
      await expectPlanMatches(
        '想恢复一点能量',
        expectedState: TargetState.energize,
        expectedBrainwaveContains: 'uplift',
        expectedAudioPath: 'music/energize_01.mp3',
      );
    });
    test('早上醒来没状态 → energize', () async {
      await expectPlanMatches(
        '早上醒来没状态',
        expectedState: TargetState.energize,
        expectedBrainwaveContains: 'uplift',
        expectedAudioPath: 'music/energize_01.mp3',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 冲突意图测试（6 条）：验证多信号优先级
  // ─────────────────────────────────────────────────────────────────────
  group('冲突意图优先级', () {
    test('「备考压力大，晚上睡不着」→ sleep（睡眠强信号优先于任务目标）', () async {
      // 含"备考"（focus 信号）+ "睡不着"（sleep 强信号）
      // 第 2 优先级 sleep 强信号 > 第 3 优先级 任务目标
      await expectPlanMatches(
        '备考压力大，晚上睡不着',
        expectedState: TargetState.sleep,
        expectedBrainwaveContains: 'Theta',
        expectedAudioPath: 'music/sleep_01.mp3',
      );
    });

    test('「备考压力大，想专注学习」→ focus（明确任务目标）', () async {
      // 含"备考"（focus）+ "压力大"（regulate 信号）
      // 第 3 优先级 任务目标 > 第 5 优先级 情绪激活
      await expectPlanMatches(
        '备考压力大，想专注学习',
        expectedState: TargetState.focus,
        expectedBrainwaveContains: 'Low Beta',
        expectedAudioPath: 'music/focus_01.mp3',
      );
    });

    test('「我现在不能睡，想保持清醒学习」→ focus（否定意图最优先）', () async {
      // 含"不能睡"（否定 sleep）+ "保持清醒" + "学习"（focus）
      // 第 1 优先级 否定意图 → focus
      await expectPlanMatches(
        '我现在不能睡，想保持清醒学习',
        expectedState: TargetState.focus,
        expectedBrainwaveContains: 'Low Beta',
        expectedAudioPath: 'music/focus_01.mp3',
      );
    });

    test('「刚睡醒但没精神」→ energize（低能量强信号，非 sleep）', () async {
      // 含"刚睡醒"（energize 强信号）+ "没精神"（energize）
      // "刚睡醒"不是"想睡"，不归 sleep
      await expectPlanMatches(
        '刚睡醒但没精神',
        expectedState: TargetState.energize,
        expectedBrainwaveContains: 'uplift',
        expectedAudioPath: 'music/energize_01.mp3',
      );
    });

    test('「很累但想睡觉」→ sleep（明确睡眠目标优先于低能量）', () async {
      // 含"累"（energize 信号）+ "想睡觉"（sleep 目标）
      // 第 4 优先级 睡眠目标 > 第 8 优先级 低能量
      await expectPlanMatches(
        '很累但想睡觉',
        expectedState: TargetState.sleep,
        expectedBrainwaveContains: 'Theta',
        expectedAudioPath: 'music/sleep_01.mp3',
      );
    });

    test('「焦虑但要继续写论文」→ focus（任务目标优先于情绪激活）', () async {
      // 含"焦虑"（regulate 信号）+ "写论文"（focus 信号）
      // 第 3 优先级 任务目标 > 第 5 优先级 情绪激活
      await expectPlanMatches(
        '焦虑但要继续写论文',
        expectedState: TargetState.focus,
        expectedBrainwaveContains: 'Low Beta',
        expectedAudioPath: 'music/focus_01.mp3',
      );
    });
  });
}
