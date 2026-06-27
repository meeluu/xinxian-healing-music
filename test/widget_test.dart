import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xinxian_healing_music/main.dart';
import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_listening_session_recorder.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_mood_analyzer.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_pipeline_factory.dart';

void main() {
  testWidgets('首页可输入心境并跳转解析页', (WidgetTester tester) async {
    // 测试默认 800x600 视口不足以容纳首页全部内容，放大测试视口
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const XinXianApp());
    // 首页有呼吸光晕循环动画，不能用 pumpAndSettle；用 pump 推进一帧即可
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 首页标题存在
    expect(find.text('心弦'), findsOneWidget);

    // 输入示例心境
    await tester.enterText(find.byType(TextField), '备考压力大，晚上睡不着，脑子停不下来');
    await tester.pump();

    // 主按钮可点击并触发跳转
    expect(find.text('生成专属疗愈方案'), findsOneWidget);
    await tester.tap(find.text('生成专属疗愈方案'));
    // 推进分析页的 Future.delayed 链（总 ~2.25s）并触发导航到方案页
    await tester.pump(const Duration(milliseconds: 2500));
    // 方案页无循环动画，pumpAndSettle 可完成 stagger 入场动效
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 解析后应进入方案页，出现音乐参数关键字
    expect(find.text('音乐参数'), findsOneWidget);
    expect(find.text('BPM'), findsWidgets);
    expect(find.text('432Hz'), findsWidgets);
  });

  test('MockMoodAnalyzer 关键词匹配命中"高压焦虑型"画像', () async {
    final profile = await const MockMoodAnalyzer().analyze(
      MoodInput(
        sessionId: 'test-anxiety',
        text: '最近备考压力很大，焦虑得睡不着',
        timestamp: DateTime.now(),
      ),
    );
    // 高压焦虑型 tags 含"焦虑"，valence=-0.4，arousal=0.8
    expect(profile.tags, contains('焦虑'));
    expect(profile.valence, -0.4);
    expect(profile.arousal, 0.8);
  });

  test('MockMoodAnalyzer 无命中时回退到"平衡调和型"画像', () async {
    final profile = await const MockMoodAnalyzer().analyze(
      MoodInput(
        sessionId: 'test-balanced',
        text: '今天天气不错',
        timestamp: DateTime.now(),
      ),
    );
    // 平衡调和型 valence=0.2，arousal=0.4
    expect(profile.valence, 0.2);
    expect(profile.arousal, 0.4);
  });

  test('MockListeningSessionRecorder 记录完整会话生命周期', () async {
    final recorder = MockListeningSessionRecorder();
    // 用真实 mockPipeline 产出一个 plan，再模拟 UI 三步生命周期
    final plan = await mockPipeline.run('最近备考压力很大，焦虑得睡不着');

    // 1) AnalysisScreen：plan 产出 → begin
    recorder.begin(
      sessionId: plan.sessionId,
      moodText: '最近备考压力很大',
      plan: plan,
    );
    // 2) PlayerScreen：dispose → updateListening
    recorder.updateListening(plan.sessionId, const Duration(seconds: 30));
    // 3) FeedbackScreen：提交 → attachFeedback
    final fb = FeedbackRecord(
      sessionId: plan.sessionId,
      rating: 4,
      tensionBefore: 0.7,
      tensionAfter: 0.3,
      note: '放松',
      completed: false,
      createdAt: DateTime.now(),
    );
    recorder.attachFeedback(plan.sessionId, fb);

    // 验证：sessionId 三处一致 + 会话字段完整
    final session = recorder.get(plan.sessionId);
    expect(session, isNotNull);
    expect(session!.sessionId, plan.sessionId);
    expect(session.moodText, '最近备考压力很大');
    expect(session.plan, same(plan));
    expect(session.variant, ExperimentVariant.custom);
    expect(session.listenedDuration, const Duration(seconds: 30));
    expect(session.feedback, isNotNull);
    expect(session.feedback!.sessionId, plan.sessionId);
    expect(session.feedback!.rating, 4);
    expect(session.completedAt, isNotNull);
    expect(recorder.all(), hasLength(1));
  });
}
