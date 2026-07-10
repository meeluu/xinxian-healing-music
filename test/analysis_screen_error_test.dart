import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_pipeline_factory.dart';
import 'package:xinxian_healing_music/pipeline/ports/mood_analyzer_port.dart';
import 'package:xinxian_healing_music/screens/analysis_screen.dart';

/// 始终抛异常的情绪解析器，用于测试 AnalysisScreen 错误态。
class _ThrowingAnalyzer implements MoodAnalyzerPort {
  @override
  Future<MoodProfile> analyze(MoodInput input) async {
    throw Exception('test pipeline failure');
  }

  @override
  String get currentSource => 'mock';
}

void main() {
  testWidgets(
      'AnalysisScreen pipeline 失败时显示友好错误态并提供重试/返回首页',
      (WidgetTester tester) async {
    // 保存原始 pipeline，测试后恢复，避免污染其他测试
    final original = activePipeline;
    activePipeline = buildPipelineWith(_ThrowingAnalyzer());
    addTearDown(() => activePipeline = original);

    await tester.pumpWidget(
      const MaterialApp(home: AnalysisScreen(moodText: '测试心境')),
    );

    // 推进动画（4 行 × 450ms + 1 × 450ms = 2250ms）+ 微任务处理
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 100));

    // 错误态 UI 应出现
    expect(find.text('生成方案失败，请稍后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('返回首页'), findsOneWidget);

    // 不应暴露内部异常字符串
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('test pipeline failure'), findsNothing);
  });

  testWidgets('AnalysisScreen 点击重试后重新走流程并再次进入错误态',
      (WidgetTester tester) async {
    final original = activePipeline;
    activePipeline = buildPipelineWith(_ThrowingAnalyzer());
    addTearDown(() => activePipeline = original);

    await tester.pumpWidget(
      const MaterialApp(home: AnalysisScreen(moodText: '测试心境')),
    );
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('生成方案失败，请稍后重试'), findsOneWidget);

    // 点击重试
    await tester.tap(find.text('重试'));
    await tester.pump();
    // 重试后回到动画态（错误态文案应消失）
    expect(find.text('生成方案失败，请稍后重试'), findsNothing);

    // 再次推进动画 + 等待失败
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('生成方案失败，请稍后重试'), findsOneWidget);
  });
}
