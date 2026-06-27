import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xinxian_healing_music/main.dart';
import 'package:xinxian_healing_music/services/mood_analyzer.dart';

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

  test('MoodAnalyzer 关键词匹配命中"高压焦虑型"', () {
    final plan = const MoodAnalyzer().analyze('最近备考压力很大，焦虑得睡不着');
    expect(plan.templateName, '高压焦虑型');
    expect(plan.frequency, '432Hz');
  });

  test('MoodAnalyzer 无命中时回退到"平衡调和型"', () {
    final plan = const MoodAnalyzer().analyze('今天天气不错');
    expect(plan.templateName, '平衡调和型');
  });
}
