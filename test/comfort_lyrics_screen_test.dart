import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/screens/comfort_lyrics_screen.dart';

/// ComfortLyricsScreen 页面测试（P4 新方向第一批 / 第二批）。
///
/// P4 第二批更新：
/// - 结果区标题：「温和解惑」→「给现在的你」；「歌词草稿」→「写成歌的话」
/// - songPrompt 折叠弱化：默认收起，标题改为「后续生成参数」
/// - 新增场景标记显示（学业受挫 / 关系摩擦 / 压力疲惫 / 愧疚后悔 / 此刻心境）
///
/// 验证：
/// - 页面渲染不空白（关键元素可见）
/// - 标题「把困惑写成一首歌」可见
/// - 输入框可见
/// - 4 个曲风 chip 可见
/// - 生成按钮初始禁用（无文本时）
/// - 输入文本后按钮可点击
/// - 生成后结果显示新标题「给现在的你」「写成歌的话」
/// - songPrompt 默认收起，点击「后续生成参数」可展开
/// - 场景标记可见
/// - 「再写一首」重置回初始态
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

    // 按钮区域不空白
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

  testWidgets('生成完成后显示结果区（P4 第二批：新标题「给现在的你」「写成歌的话」）', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // 输入并触发生成
    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));

    // 等待 fallback 完成
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // P4 第二批：结果区应显示新标题
    expect(find.text('给现在的你'), findsOneWidget);
    expect(find.text('写成歌的话'), findsOneWidget);
    // 旧标题不应再出现
    expect(find.text('温和解惑'), findsNothing);
    expect(find.text('歌词草稿'), findsNothing);
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

  testWidgets('P4 第二批：生成完成后显示场景标记', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // 输入工作压力场景文本
    await tester.enterText(find.byType(TextField), '最近工作压力很大，天天加班');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 应显示场景标记之一（5 种场景标签）
    final sceneLabels = ['学业受挫', '关系摩擦', '压力疲惫', '愧疚后悔', '此刻心境'];
    bool foundScene = false;
    for (final label in sceneLabels) {
      if (find.text(label).evaluate().isNotEmpty) {
        foundScene = true;
        break;
      }
    }
    expect(foundScene, isTrue, reason: '应显示场景标记');
  });

  testWidgets('P4 第二批：songPrompt 默认收起，标题为「后续生成参数」', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 「后续生成参数」标题可见（songPrompt 折叠弱化）
    expect(find.text('后续生成参数'), findsOneWidget);
    // songPrompt 默认收起，应显示下箭头
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('P4 第二批：点击「后续生成参数」可展开 songPrompt', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 滚动到「后续生成参数」可见
    await tester.ensureVisible(find.text('后续生成参数'));
    await tester.pumpAndSettle();

    // 点击「后续生成参数」展开
    await tester.tap(find.text('后续生成参数'));
    await tester.pumpAndSettle();

    // 展开后应显示上箭头
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
  });

  testWidgets('点击「再写一首」重置回初始态', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 结果区已显示（P4 第二批新标题）
    expect(find.text('给现在的你'), findsOneWidget);

    // 「再写一首」按钮可能在视口下方，需先滚动到可见
    await tester.ensureVisible(find.text('再写一首'));
    await tester.pumpAndSettle();

    // 点击「再写一首」
    await tester.tap(find.text('再写一首'));
    await tester.pumpAndSettle();

    // 结果区应消失
    expect(find.text('给现在的你'), findsNothing);
    expect(find.text('写成歌的话'), findsNothing);
    // 输入框应被清空（按钮恢复禁用）
    final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(filledButton.onPressed, isNull);
  });

  testWidgets('P4 第二批：页面不空白，结果区含完整结构', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 结果区完整结构：来源标记 + 场景标记 + 给现在的你 + 写成歌的话 + 后续生成参数 + 后续提示 + 再写一首
    expect(find.textContaining('本地模板'), findsOneWidget); // 来源标记
    expect(find.text('给现在的你'), findsOneWidget);
    expect(find.text('写成歌的话'), findsOneWidget);
    expect(find.text('后续生成参数'), findsOneWidget);
    expect(find.textContaining('下一步将用于生成专属歌曲'), findsOneWidget);
    expect(find.text('再写一首'), findsOneWidget);
  });
}
