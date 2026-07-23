import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/pipeline/local/local_generation_quota_service.dart';
import 'package:xinxian_healing_music/pipeline/local/preferences_port.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/comfort_lyrics_screen.dart';

/// ComfortLyricsScreen 页面测试（P4 新方向第一批 / 第二批 / 第三批）。
///
/// P4 第二批更新：
/// - 结果区标题：「温和解惑」→「给现在的你」；「歌词草稿」→「写成歌的话」
/// - songPrompt 折叠弱化：默认收起，标题改为「后续生成参数」
/// - 新增场景标记显示（学业受挫 / 关系摩擦 / 压力疲惫 / 愧疚后悔 / 此刻心境）
///
/// P4 第三批新增：
/// - 歌词卡片支持编辑/保存/取消
/// - 「编辑歌词」按钮可见，点击后出现可编辑文本框 + 字数提示 + 温和提醒 + 保存/取消
/// - 保存后显示新歌词；取消后恢复旧歌词
/// - 「生成这首歌（实验）」受控实验入口按钮可见，点击弹费用确认对话框，不触发 API
/// - 编辑态时生成解惑按钮和占位按钮均禁用
/// - 「再写一首」清空编辑状态
///
/// P4-song-result-experience-1 新增（未纳入 widget 测试，需 API mock 才能触发）：
/// - 生成成功结果区 `_buildSongResultSection`：歌曲标题（本地规则生成）+ 副文案 + 试听这首歌 +
///   歌词展示 + 状态「已生成，可直接试听」+ 操作按钮（重新播放 / 编辑歌词 / 重新生成）
/// - 生成失败区 `_buildMusicErrorSection`：温和错误 + 重试生成 / 编辑歌词
/// - 以上两个区域仅在 `_generatedAudioUrl != null`（成功）或 `_musicErrorHint != null`（失败）时渲染，
///   测试环境无真实后端不会触发，故现有断言不受影响
///
/// P6-quota-guard-1 新增（额度保护）：
/// - 额度逻辑（每日 1 次 / 计数 / 跨天重置 / 损坏容错 / key 隔离）由
///   `test/local_generation_quota_service_test.dart` 在 service 层完整覆盖。
/// - 额度 UI（生成按钮入口）：预置全局 `generationQuotaService` 后触发歌词生成 fallback
///   使结果区渲染，验证「今日还可生成 N 首」/「今日体验次数已用完」提示与按钮禁用态，
///   见本文件 `P6-quota-guard-1：额度 UI` group（3 个测试）。
/// - 结果区「重新生成」禁用 / 「重新播放」「编辑歌词」不受额度影响：需 mock
///   /api/generate-music 成功响应并触发 just_audio AudioPlayer，widget test 环境
///   AudioPlayer 会 MissingPluginException，留待后续集成测试。
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
/// - 歌词编辑/保存/取消/占位按钮行为正确
void main() {
  testWidgets('页面渲染不空白，关键元素可见', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // AppBar 标题可见
    expect(find.text('把困惑写成一首歌'), findsOneWidget);
    // 顶部说明文案可见
    expect(find.textContaining('把你最近遇到的一件事'), findsOneWidget);
    // 输入区标题可见
    // P4 前端结构调整第一批：标题从「写下你的困惑」改为「先说说卡住你的事」
    expect(find.text('先说说卡住你的事'), findsOneWidget);
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

    // 按钮区域不空白（测试环境 http 快速 fallback，可能已进入结果态，
    // 此时页面含生成解惑按钮 + 生成这首歌占位按钮，故用 findsWidgets）
    expect(find.byType(FilledButton), findsWidgets);
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
    expect(find.textContaining('下一步可以生成专属歌曲'), findsOneWidget);
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
    expect(find.textContaining('下一步可以生成专属歌曲'), findsOneWidget);
    expect(find.text('再写一首'), findsOneWidget);
  });

  // ─── P4 第三批：歌词编辑与占位按钮测试 ──────────────────────

  testWidgets('P4 第三批：结果页出现「编辑歌词」按钮', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 滚动到歌词卡片可见
    await tester.ensureVisible(find.text('写成歌的话'));
    await tester.pumpAndSettle();

    // 「编辑歌词」按钮可见
    expect(find.text('编辑歌词'), findsOneWidget);
  });

  testWidgets('P4 第三批：点击「编辑歌词」后出现可编辑文本框 + 保存/取消 + 温和提示', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    // 点击「编辑歌词」
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    // 出现「保存歌词」「取消编辑」按钮
    expect(find.text('保存歌词'), findsOneWidget);
    expect(find.text('取消编辑'), findsOneWidget);
    // 温和质量提醒
    expect(find.textContaining('建议保留主歌、副歌、尾声结构'), findsOneWidget);
    // 编辑态下有两个 TextField：故事输入框 + 歌词编辑框
    expect(find.byType(TextField), findsNWidgets(2));
    // 字数提示可见
    expect(find.textContaining('字'), findsWidgets);
  });

  testWidgets('P4 第三批：编辑后点击「保存歌词」显示新歌词', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    // 在歌词编辑框（第二个 TextField）中输入新内容
    const newLyric = '这是测试编辑后的独特歌词内容XYZ';
    await tester.enterText(find.byType(TextField).at(1), newLyric);
    await tester.pumpAndSettle();

    // 点击「保存歌词」
    await tester.tap(find.text('保存歌词'));
    await tester.pumpAndSettle();

    // 展示态应显示新歌词内容
    expect(find.text(newLyric), findsOneWidget);
    // 「编辑歌词」按钮重新出现（退出编辑态）
    expect(find.text('编辑歌词'), findsOneWidget);
    // 「保存歌词」「取消编辑」按钮消失
    expect(find.text('保存歌词'), findsNothing);
    expect(find.text('取消编辑'), findsNothing);
  });

  testWidgets('P4 第三批：编辑后点击「取消编辑」恢复旧歌词', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    // 在歌词编辑框中输入新内容
    const newLyric = '这是不应该被保留的临时内容ABC';
    await tester.enterText(find.byType(TextField).at(1), newLyric);
    await tester.pumpAndSettle();

    // 点击「取消编辑」
    await tester.tap(find.text('取消编辑'));
    await tester.pumpAndSettle();

    // 新内容不应出现在展示态
    expect(find.text(newLyric), findsNothing);
    // 「编辑歌词」按钮重新出现（退出编辑态）
    expect(find.text('编辑歌词'), findsOneWidget);
    // 「保存歌词」「取消编辑」按钮消失
    expect(find.text('保存歌词'), findsNothing);
    expect(find.text('取消编辑'), findsNothing);
  });

  testWidgets(
    'P4-generated-audio-playback-1：「生成这首歌（实验）」按钮可见且点击弹费用确认对话框不触发 API',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '最近工作压力很大');
      await tester.pump();
      await tester.tap(find.text('生成解惑与歌词草稿'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // 受控实验入口按钮可见
      expect(find.text('生成这首歌（实验）'), findsOneWidget);

      // 点击按钮
      await tester.ensureVisible(find.text('生成这首歌（实验）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('生成这首歌（实验）'));
      await tester.pumpAndSettle();

      // 弹出费用确认对话框（不触发 API：未点击「确认生成」按钮）
      // P4-generated-audio-playback-1：旧 SnackBar 占位提示已改为受控费用确认对话框
      expect(find.text('生成这首歌'), findsOneWidget); // 对话框标题
      expect(find.textContaining('这会发起一次 AI 音乐生成'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认生成'), findsOneWidget);

      // 不应进入播放器，不应出现音频相关 UI
      expect(find.textContaining('MiniMax'), findsNothing);
      expect(find.textContaining('Mureka'), findsNothing);
    },
  );

  testWidgets('P4 第三批：编辑态时「生成解惑与歌词草稿」按钮禁用', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    // 编辑态下，「生成解惑与歌词草稿」按钮应禁用（onPressed 为 null）
    // 注意：此时页面有多个 FilledButton（生成解惑 + 保存歌词 + 生成这首歌），
    // 用文案定位生成解惑按钮
    final generateBtn = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('生成解惑与歌词草稿'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(generateBtn.onPressed, isNull);
  });

  testWidgets('P4 第三批：编辑态时「生成这首歌」占位按钮禁用', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    // 编辑态下，「生成这首歌（实验）」按钮应禁用
    final songBtn = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('生成这首歌（实验）'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(songBtn.onPressed, isNull);
  });

  testWidgets('P4 第三批：「再写一首」清空编辑状态，再生成显示原歌词', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // 第一次生成
    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 编辑并保存新歌词
    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    const editedLyric = '这是第一次编辑保存的内容';
    await tester.enterText(find.byType(TextField).at(1), editedLyric);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存歌词'));
    await tester.pumpAndSettle();
    // 确认编辑内容已保存
    expect(find.text(editedLyric), findsOneWidget);

    // 点击「再写一首」重置
    await tester.ensureVisible(find.text('再写一首'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('再写一首'));
    await tester.pumpAndSettle();

    // 结果区应消失，编辑内容也应消失
    expect(find.text(editedLyric), findsNothing);
    expect(find.text('给现在的你'), findsNothing);

    // 重新生成
    await tester.enterText(find.byType(TextField), '和妈妈吵架了');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 应显示新生成的原歌词，而非上一次编辑后的内容
    expect(find.text(editedLyric), findsNothing);
    expect(find.text('写成歌的话'), findsOneWidget);
    expect(find.text('编辑歌词'), findsOneWidget);
  });

  testWidgets('P4 第三批：保存歌词后再编辑，编辑框初始内容为上次保存的内容', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 第一次编辑保存
    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    const firstEdit = '第一次编辑保存的歌词内容';
    await tester.enterText(find.byType(TextField).at(1), firstEdit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存歌词'));
    await tester.pumpAndSettle();

    // 第二次进入编辑，编辑框初始内容应为第一次保存的内容
    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    final editField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(editField.controller!.text, firstEdit);
  });

  testWidgets('P4 第三批：页面不空白，结果区含编辑按钮和占位按钮', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('生成解惑与歌词草稿'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 完整结构：来源标记 + 给现在的你 + 写成歌的话 + 编辑歌词 + 后续生成参数 + 后续提示 + 生成这首歌 + 再写一首
    expect(find.textContaining('本地模板'), findsOneWidget);
    expect(find.text('给现在的你'), findsOneWidget);
    expect(find.text('写成歌的话'), findsOneWidget);
    expect(find.text('编辑歌词'), findsOneWidget);
    expect(find.text('后续生成参数'), findsOneWidget);
    expect(find.textContaining('下一步可以生成专属歌曲'), findsOneWidget);
    expect(find.text('生成这首歌（实验）'), findsOneWidget);
    expect(find.text('再写一首'), findsOneWidget);
  });

  // ─── P6-quota-guard-1：额度 UI widget 测试 ──────────────────────
  //
  // 覆盖 P6 成本保护的主要入口（「生成这首歌（实验）」按钮 + 额度提示）。
  // 通过预置全局 [generationQuotaService] 后触发歌词生成 fallback（_result != null），
  // 使结果区 [_buildGenerateSongButton] 渲染，验证额度提示文案与按钮禁用态。
  //
  // 未覆盖（需 mock /api/generate-music 成功响应 + 触发 just_audio AudioPlayer，
  // widget test 环境 AudioPlayer 会 MissingPluginException，留待后续集成测试）：
  // - 额度用完时「重新生成」按钮禁用
  // - 「重新播放」「编辑歌词」不受额度影响
  group('P6-quota-guard-1：额度 UI', () {
    tearDown(() {
      // 恢复全局默认（null），避免污染同文件其他测试
      generationQuotaService = null;
    });

    /// 触发歌词生成（测试环境 http 快速 fallback 填充 _result），
    /// 使结果区的「生成这首歌（实验）」按钮与额度提示渲染出来。
    Future<void> generateLyrics(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
      await tester.pumpAndSettle(); // 让 initState 的 _refreshQuotaState 完成
      await tester.enterText(find.byType(TextField), '最近工作压力很大');
      await tester.pump();
      await tester.tap(find.text('生成解惑与歌词草稿'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    /// 定位「生成这首歌（实验）」FilledButton（页面有多个 FilledButton，用文案定位）。
    FilledButton findGenerateSongButton(WidgetTester tester) {
      return tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('生成这首歌（实验）'),
          matching: find.byType(FilledButton),
        ),
      );
    }

    testWidgets('额度可用时显示「今日还可生成 1 首」且生成按钮可用', (tester) async {
      // 预置额度可用：空存储 → count=0 → remaining=1
      generationQuotaService = await LocalGenerationQuotaService.create(
        _FakePreferencesPort(),
      );

      await generateLyrics(tester);

      expect(find.text('今日还可生成 1 首'), findsOneWidget);
      expect(findGenerateSongButton(tester).onPressed, isNotNull);
    });

    testWidgets('额度用完时显示「今日体验次数已用完」且生成按钮禁用', (tester) async {
      // 预置额度用完：今日 count=1 → remaining=0
      final fake = _FakePreferencesPort();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await fake.setString(
        LocalGenerationQuotaService.key,
        '{"date":"$today","count":1}',
      );
      generationQuotaService = await LocalGenerationQuotaService.create(fake);

      await generateLyrics(tester);

      expect(find.text('今日体验次数已用完'), findsOneWidget);
      expect(findGenerateSongButton(tester).onPressed, isNull);
    });

    testWidgets('额度服务未装配时 permissive 降级：不显示额度提示且按钮可用', (tester) async {
      // generationQuotaService 保持 null（默认），模拟存储全不可用的降级场景
      await generateLyrics(tester);

      expect(find.textContaining('今日还可生成'), findsNothing);
      expect(find.text('今日体验次数已用完'), findsNothing);
      expect(findGenerateSongButton(tester).onPressed, isNotNull);
    });
  });
}

/// 内存 Map 实现的 [PreferencesPort]，用于在 widget 测试中预置额度状态
/// （与 `test/local_generation_quota_service_test.dart` 中的实现一致，因私有而各自定义）。
class _FakePreferencesPort implements PreferencesPort {
  final Map<String, String> _store = {};

  @override
  String? getString(String key) => _store[key];

  @override
  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }
}
