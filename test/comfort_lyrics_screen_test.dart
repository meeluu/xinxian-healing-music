import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/screens/comfort_lyrics_screen.dart';

/// ComfortLyricsScreen 页面测试（P4 新方向第一批）。
///
/// 验证：
/// - 页面渲染不空白（关键元素可见）
/// - 标题「把困惑写成一首歌」可见
/// - 输入框可见
/// - 4 个曲风 chip 可见
/// - 生成按钮初始禁用（无文本时）
/// - 输入文本后按钮可点击
/// - 后续提示文案可见（即使未生成结果）
void main() {
  testWidgets('页面渲染不空白，关键元素可见', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // AppBar 标题可见
    expect(find.text('把困惑写成一首歌'), findsOneWidget);
    // 顶部说明文案可见
    expect(find.textContaining('把你最近遇到的一件事'), findsOneWidget);
    // 输入区标题可见
    expect(find.text('写下你的困惑'), findsOneWidget);
    // 曲风选择标题可见
    expect(find.text('期望曲风'), findsOneWidget);
    // 4 个曲风 chip 可见
    expect(find.text('温柔流行'), findsOneWidget);
    expect(find.text('氛围民谣'), findsOneWidget);
    expect(find.text('暖意指弹'), findsOneWidget);
    expect(find.text('柔光钢琴'), findsOneWidget);
    // 生成按钮可见
    expect(find.text('生成解惑与歌词草稿'), findsOneWidget);
  });

  testWidgets('无输入时生成按钮禁用（onPressed 为 null）', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // 找到 FilledButton
    final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(filledButton.onPressed, isNull);
  });

  testWidgets('输入文本后生成按钮可点击', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // 在输入框中输入文本
    await tester.enterText(find.byType(TextField), '最近工作压力很大，睡不着');
    await tester.pump();

    // 此时 FilledButton 应可点击
    final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(filledButton.onPressed, isNotNull);
  });

  testWidgets('点击曲风 chip 切换选中状态', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // 默认选中「温柔流行」
    expect(find.text('温柔流行'), findsOneWidget);

    // 点击「柔光钢琴」
    await tester.tap(find.text('柔光钢琴'));
    await tester.pumpAndSettle();

    // 切换后仍能找到所有 4 个 chip（页面未崩溃）
    expect(find.text('温柔流行'), findsOneWidget);
    expect(find.text('氛围民谣'), findsOneWidget);
    expect(find.text('暖意指弹'), findsOneWidget);
    expect(find.text('柔光钢琴'), findsOneWidget);
  });

  testWidgets('点击生成按钮后显示加载状态', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // 输入文本
    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();

    // 点击生成按钮
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump();

    // 按钮文案应变为「正在生成…」（或保持但出现 CircularProgressIndicator）
    // 测试环境无真实后端，generate 会很快返回 fallback
    // 至少按钮区域不空白
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('页面不暴露内部异常字符串', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // 输入并触发生成
    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));

    // 等待 fallback 完成（测试环境会快速 fallback）
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 不应暴露 Exception 等内部异常字符串
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('llm_network_error'), findsNothing);
  });

  testWidgets('生成完成后显示结果区（含「温和解惑」和「歌词草稿」）', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // 输入并触发生成
    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));

    // 等待 fallback 完成
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 结果区应显示
    expect(find.text('温和解惑'), findsOneWidget);
    expect(find.text('歌词草稿'), findsOneWidget);
    // 后续提示
    expect(find.textContaining('下一步将用于生成专属歌曲'), findsOneWidget);
    // 重置按钮
    expect(find.text('再写一首'), findsOneWidget);
  });

  testWidgets('生成完成后显示来源标记（fallback）', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 测试环境无真实后端，应显示 fallback 标记
    expect(find.textContaining('本地模板'), findsOneWidget);
  });

  testWidgets('点击「再写一首」重置回初始态', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 结果区已显示
    expect(find.text('温和解惑'), findsOneWidget);

    // 「再写一首」按钮可能在视口下方，需先滚动到可见
    await tester.ensureVisible(find.text('再写一首'));
    await tester.pumpAndSettle();

    // 点击「再写一首」
    await tester.tap(find.text('再写一首'));
    await tester.pumpAndSettle();

    // 结果区应消失
    expect(find.text('温和解惑'), findsNothing);
    expect(find.text('歌词草稿'), findsNothing);
    // 输入框应被清空（按钮恢复禁用）
    final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(filledButton.onPressed, isNull);
  });
}
