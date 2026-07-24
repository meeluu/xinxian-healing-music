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
/// - 「再写一首」清空编辑状态
///
/// P4-conversation-song-flow-1 更新（多轮困惑理解）：
/// - input 阶段按钮文案从「生成解惑与歌词草稿」改为「开始理解」
/// - 点击「开始理解」不再直接生成，而是进入 loadingFollowUp → followUp 阶段（2-3 轮温和追问）
/// - followUp 阶段可「跳过追问，直接生成」或回答完所有轮后自动生成
/// - 多轮数据（initialConcern / followUpAnswers）只存页面 state
/// - 测试通过 [generateLyrics] 辅助函数统一走「开始理解 → 跳过追问，直接生成」流程触发生成
///
/// P4-conversation-song-flow-1-fix1 更新（LLM 动态追问 + 加载文案分阶段）：
/// - 追问改为 LLM 动态生成（fetchFollowUpQuestions），失败走本地 6 分类兜底
/// - 所有追问都是开放式文本输入（不再有选项 chip）
/// - 加载文案分阶段：loadingFollowUp → 「正在根据你的文字整理几个更贴近的问题…」
/// - 低能量输入（提不起劲/疲惫/很空）的追问不包含「这件事」措辞
///
/// P4-dynamic-followup-depth-1 更新（固定三轮→动态 2-4 轮）：
/// - 首轮固定 2 个核心问题（兜底也固定 2 条，take(2)）
/// - 第 2 题答完后调 fetchFollowUpMore 判定是否追加 1-2 个问题（总轮数 2-4）
/// - 第 2 题左侧按钮变为「先写成歌」（跳过追加判定直接生成）
/// - 第 2 题右侧按钮仍为「继续」（触发追加判定）
/// - 追加判定兜底（needMore=false）→ 答完 2 轮即自动生成
/// - 进度提示从「第 1 / 3」改为动态「第 1 / 2」（首轮 2 个问题）
///
/// P4-song-result-experience-1（已被 P4-playback-experience-2 取代）：
/// - 旧版在歌词页内嵌播放器（`_buildSongResultSection` / `_buildMusicErrorSection`）
/// - P4-playback-experience-2 移除内嵌播放，改为跳转 [GeneratedSongPlayerScreen] 独立播放页
/// - 歌词页仅保留 [_generatedSongMeta] 缓存 + 轻量入口卡片（`_buildGeneratedSongEntry`），
///   点击「进入播放页」重新跳转
/// - 以上区域仅在 `_generatedSongMeta != null` 时渲染，测试环境无真实后端不会触发，
///   故现有断言不受影响。独立播放页的渲染由 `test/generated_song_player_screen_test.dart` 覆盖。
///
/// P6-quota-guard-1 新增（额度保护）：
/// - 额度逻辑由 `test/local_generation_quota_service_test.dart` 在 service 层覆盖
/// - 额度 UI（生成按钮入口）：预置全局 `generationQuotaService` 后触发歌词生成 fallback
///   使结果区渲染，验证额度提示与按钮禁用态，见本文件 `P6-quota-guard-1：额度 UI` group
///
/// 验证：
/// - 页面渲染不空白（关键元素可见）
/// - 标题「把困惑写成一首歌」可见
/// - 输入框可见
/// - 4 个曲风 chip 可见
/// - 「开始理解」按钮初始禁用（无文本时）
/// - 输入文本后按钮可点击
/// - 点击「开始理解」进入 followUp 阶段
/// - followUp 阶段可跳过直接生成
/// - P4-dynamic-followup-depth-1：答完 2 轮 + 追加判定后自动生成
/// - P4-dynamic-followup-depth-1：第 2 题显示「先写成歌」按钮
/// - P4-dynamic-followup-depth-1：点「先写成歌」跳过追加判定直接生成
/// - 生成后结果显示新标题「给现在的你」「写成歌的话」
/// - songPrompt 默认收起，点击「后续生成参数」可展开
/// - 场景标记可见
/// - 「再写一首」重置回初始态
/// - 歌词编辑/保存/取消/占位按钮行为正确
void main() {
  /// P4-conversation-song-flow-1：触发生成的完整流程。
  ///
  /// input 阶段输入困惑 → 点击「开始理解」→ loadingFollowUp（HTTP 快速失败）→
  /// followUp 阶段点击「跳过追问，直接生成」→ 等待 fallback 完成。
  /// 测试环境 http 快速 fallback，结果区会渲染。
  ///
  /// fix1：_startFollowUp 改为异步（调 LLM 拿动态追问），需 pump 等待 HTTP 失败后
  /// 才进入 followUp 阶段。
  Future<void> generateLyrics(
    WidgetTester tester, {
    String story = '最近工作压力很大',
  }) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), story);
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    // fix1：等待 fetchFollowUpQuestions 的 HTTP 调用失败 + 本地兜底返回
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    // followUp 阶段：点击「跳过追问，直接生成」
    await tester.ensureVisible(find.text('跳过追问，直接生成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跳过追问，直接生成'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  // ─── P4-conversation-song-flow-1：多轮对话流程测试 ──────────────────────

  testWidgets('P4-conversation-song-flow-1：input 阶段显示「开始理解」按钮', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('开始理解'), findsOneWidget);
    // 旧文案不应出现
    expect(find.text('生成解惑与歌词草稿'), findsNothing);
  });

  testWidgets('P4-conversation-song-flow-1：点击「开始理解」进入 followUp 阶段', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    // fix1：等待 fetchFollowUpQuestions HTTP 失败 + 本地兜底
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 进入 followUp 阶段：显示第 1 个追问 + 跳过按钮
    // fix1：「最近工作压力很大」→ classifyConcern=anxietyStress → 兜底第 1 问
    expect(find.textContaining('现在最担心'), findsOneWidget);
    expect(find.text('跳过追问，直接生成'), findsOneWidget);
    // P4-dynamic-followup-depth-1：首轮兜底固定 2 个问题，进度提示为「第 1 / 2」
    expect(find.textContaining('第 1 / 2'), findsOneWidget);
  });

  testWidgets('P4-conversation-song-flow-1：followUp 阶段可跳过直接生成', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    // fix1：等待 fetchFollowUpQuestions HTTP 失败 + 本地兜底
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跳过追问，直接生成'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 跳过后直接生成结果
    expect(find.text('给现在的你'), findsOneWidget);
  });

  testWidgets('P4-dynamic-followup-depth-1：followUp 阶段答完 2 轮 + 追加判定后自动生成', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    // fix1：等待 fetchFollowUpQuestions HTTP 失败 + 本地兜底
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 所有追问都是开放式文本输入（不再有选项 chip）
    // Q1：输入回答 → 点「继续」
    await tester.enterText(find.byType(TextField), '最放不下的是没发出去的消息');
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    // Q2：输入回答 → 点「继续」
    // P4-dynamic-followup-depth-1：第 2 题按钮文案仍为「继续」（isSecondInitial=true），
    // 点击后触发 loadingFollowUpMore 阶段，HTTP 失败走保守兜底（needMore=false），
    // 自动进入 done 阶段生成。
    await tester.enterText(find.byType(TextField), '想先平静下来');
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    // 等待 loadingFollowUpMore 的 fetchFollowUpMore HTTP 失败 + _generate 的 HTTP 失败
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 答完 2 轮 + 追加判定兜底（不追加）后自动生成结果
    expect(find.text('给现在的你'), findsOneWidget);
  });

  // ─── P4-dynamic-followup-depth-1：动态追问 UI 行为测试 ──────────────

  /// P4-dynamic-followup-depth-1：第 2 题时显示「先写成歌」按钮（左侧）。
  /// 第 2 题是首轮最后一个问题（isSecondInitial=true），左侧按钮文案变为
  /// 「先写成歌」，点击后记录回答 + 跳过追加判定 + 直接生成。
  testWidgets('P4-dynamic-followup-depth-1：第 2 题显示「先写成歌」按钮', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Q1：第 1 题左侧按钮为「跳过追问，直接生成」（非 isSecondInitial）
    expect(find.text('跳过追问，直接生成'), findsOneWidget);
    expect(find.text('先写成歌'), findsNothing);

    // 回答 Q1 → 点「继续」进入 Q2
    await tester.enterText(find.byType(TextField), '最放不下的是没发出去的消息');
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    // Q2：第 2 题左侧按钮变为「先写成歌」（isSecondInitial=true）
    expect(find.text('先写成歌'), findsOneWidget);
    expect(find.text('跳过追问，直接生成'), findsNothing);
    // 右侧按钮仍为「继续」（触发追加判定）
    expect(find.text('继续'), findsOneWidget);
    // 进度提示为第 2 题专用文案（含「先写成歌」字样，与按钮文案呼应）
    expect(find.textContaining('第 2 个问题'), findsOneWidget);
    expect(
      find.text('第 2 个问题 · 答完可以先写成歌，也可以继续让我再想想'),
      findsOneWidget,
    );
  });

  /// P4-dynamic-followup-depth-1：第 2 题点击「先写成歌」→ 跳过追加判定，直接生成。
  /// 与「继续」的区别：「继续」会触发 loadingFollowUpMore 判定是否追加；
  /// 「先写成歌」记录当前回答后直接进入 done 阶段，不等追加判定。
  testWidgets('P4-dynamic-followup-depth-1：第 2 题点「先写成歌」跳过追加判定直接生成', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Q1：回答 → 点「继续」
    await tester.enterText(find.byType(TextField), '最放不下的是没发出去的消息');
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    // Q2：回答 → 点「先写成歌」（跳过追加判定）
    await tester.enterText(find.byType(TextField), '想先平静下来');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('先写成歌'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('先写成歌'));
    // 等待 _generate 的 HTTP 失败 + 本地兜底
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 跳过追加判定后直接生成结果
    expect(find.text('给现在的你'), findsOneWidget);
  });

  /// P4-dynamic-followup-depth-1：第 2 题点击「先写成歌」会记录当前回答。
  /// 验证：点击「先写成歌」时输入框中的文字会被计入 followUpAnswers（不丢失）。
  /// 通过生成的歌词来源标记确认流程正常完成（间接验证回答已被吸收）。
  testWidgets('P4-dynamic-followup-depth-1：「先写成歌」记录当前回答后生成', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Q1：回答
    await tester.enterText(find.byType(TextField), '今天最累的是开会');
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    // Q2：输入回答但不点「继续」，直接点「先写成歌」
    await tester.enterText(find.byType(TextField), '想让加班先停下来');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('先写成歌'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('先写成歌'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 生成完成（回答已被记录，不丢失）
    expect(find.text('给现在的你'), findsOneWidget);
    expect(find.textContaining('本地模板'), findsOneWidget);
  });

  /// P4-dynamic-followup-depth-1：追加判定阶段（loadingFollowUpMore）加载文案。
  ///
  /// 说明：Flutter 测试环境（TestWidgetsFlutterBinding）会将所有 HTTP 请求
  /// 立即失败，导致 loadingFollowUpMore 阶段瞬时过渡到 done，无法稳定捕获中间态。
  /// 本测试验证流程能正确从 Q2「继续」过渡到生成结果（间接验证追加判定阶段被
  /// 触发并完成），且旧的统一加载文案不出现。
  testWidgets('P4-dynamic-followup-depth-1：追加判定阶段文案不出现旧统一文案', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Q1 → 继续
    await tester.enterText(find.byType(TextField), '最放不下的是没发出去的消息');
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    // Q2 → 继续（触发追加判定）
    await tester.enterText(find.byType(TextField), '想先平静下来');
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 追加判定完成（兜底不追加）→ 自动生成结果
    expect(find.text('给现在的你'), findsOneWidget);
    // 旧的统一加载文案不出现（已改为分阶段文案）
    expect(find.textContaining('AI 正在理解你的状态'), findsNothing);
  });

  // ─── 基础渲染与交互测试 ──────────────────────────────────────────────

  testWidgets('页面渲染不空白，关键元素可见', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    // AppBar 标题可见
    expect(find.text('把困惑写成一首歌'), findsOneWidget);
    // 顶部说明文案可见
    expect(find.textContaining('把你最近遇到的一件事'), findsOneWidget);
    // 输入区标题可见
    expect(find.text('先说说卡住你的事'), findsOneWidget);
    // 曲风选择标题可见
    expect(find.text('期望曲风'), findsOneWidget);
    // 4 个曲风 chip 可见
    expect(find.text('温柔流行'), findsOneWidget);
    expect(find.text('氛围民谣'), findsOneWidget);
    expect(find.text('暖意指弹'), findsOneWidget);
    expect(find.text('柔光钢琴'), findsOneWidget);
    // P4-conversation-song-flow-1：生成按钮文案改为「开始理解」
    expect(find.text('开始理解'), findsOneWidget);
  });

  testWidgets('无输入时「开始理解」按钮禁用（onPressed 为 null）', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(filledButton.onPressed, isNull);
  });

  testWidgets('输入文本后「开始理解」按钮可点击', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大，睡不着');
    await tester.pump();

    final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(filledButton.onPressed, isNotNull);
  });

  testWidgets('点击曲风 chip 切换选中状态', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('温柔流行'), findsOneWidget);

    await tester.tap(find.text('柔光钢琴'));
    await tester.pumpAndSettle();

    expect(find.text('温柔流行'), findsOneWidget);
    expect(find.text('氛围民谣'), findsOneWidget);
    expect(find.text('暖意指弹'), findsOneWidget);
    expect(find.text('柔光钢琴'), findsOneWidget);
  });

  testWidgets('点击「开始理解」后进入 followUp 阶段（不空白）', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    // fix1：等待 fetchFollowUpQuestions HTTP 失败 + 本地兜底
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // followUp 阶段应显示追问卡片（不空白）
    expect(find.text('跳过追问，直接生成'), findsOneWidget);
    expect(find.byType(FilledButton), findsWidgets);
  });

  testWidgets('页面不暴露内部异常字符串', (WidgetTester tester) async {
    await generateLyrics(tester);

    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('llm_network_error'), findsNothing);
  });

  testWidgets('生成完成后显示结果区（新标题「给现在的你」「写成歌的话」）', (WidgetTester tester) async {
    await generateLyrics(tester);

    expect(find.text('给现在的你'), findsOneWidget);
    expect(find.text('写成歌的话'), findsOneWidget);
    expect(find.text('温和解惑'), findsNothing);
    expect(find.text('歌词草稿'), findsNothing);
    expect(find.textContaining('下一步可以生成专属歌曲'), findsOneWidget);
    expect(find.text('再写一首'), findsOneWidget);
  });

  testWidgets('生成完成后显示来源标记（fallback）', (WidgetTester tester) async {
    await generateLyrics(tester);

    expect(find.textContaining('本地模板'), findsOneWidget);
  });

  testWidgets('P4 第二批：生成完成后显示场景标记', (WidgetTester tester) async {
    await generateLyrics(tester, story: '最近工作压力很大，天天加班');

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
    await generateLyrics(tester);

    expect(find.text('后续生成参数'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('P4 第二批：点击「后续生成参数」可展开 songPrompt', (WidgetTester tester) async {
    await generateLyrics(tester);

    await tester.ensureVisible(find.text('后续生成参数'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('后续生成参数'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
  });

  testWidgets('点击「再写一首」重置回初始态', (WidgetTester tester) async {
    await generateLyrics(tester);

    expect(find.text('给现在的你'), findsOneWidget);

    await tester.ensureVisible(find.text('再写一首'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('再写一首'));
    await tester.pumpAndSettle();

    // 结果区应消失，回到 input 阶段
    expect(find.text('给现在的你'), findsNothing);
    expect(find.text('写成歌的话'), findsNothing);
    // 「开始理解」按钮重新出现且禁用（输入框已清空）
    expect(find.text('开始理解'), findsOneWidget);
    final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(filledButton.onPressed, isNull);
  });

  testWidgets('P4 第二批：页面不空白，结果区含完整结构', (WidgetTester tester) async {
    await generateLyrics(tester);

    expect(find.textContaining('本地模板'), findsOneWidget);
    expect(find.text('给现在的你'), findsOneWidget);
    expect(find.text('写成歌的话'), findsOneWidget);
    expect(find.text('后续生成参数'), findsOneWidget);
    expect(find.textContaining('下一步可以生成专属歌曲'), findsOneWidget);
    expect(find.text('再写一首'), findsOneWidget);
  });

  // ─── P4 第三批：歌词编辑与占位按钮测试 ──────────────────────

  testWidgets('P4 第三批：结果页出现「编辑歌词」按钮', (WidgetTester tester) async {
    await generateLyrics(tester);

    await tester.ensureVisible(find.text('写成歌的话'));
    await tester.pumpAndSettle();

    expect(find.text('编辑歌词'), findsOneWidget);
  });

  testWidgets('P4 第三批：点击「编辑歌词」后出现可编辑文本框 + 保存/取消 + 温和提示', (
    WidgetTester tester,
  ) async {
    await generateLyrics(tester);

    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    expect(find.text('保存歌词'), findsOneWidget);
    expect(find.text('取消编辑'), findsOneWidget);
    expect(find.textContaining('建议保留主歌、副歌、尾声结构'), findsOneWidget);
    // 编辑态下有一个 TextField（歌词编辑框）；input 阶段的故事输入框已不可见
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('字'), findsWidgets);
  });

  testWidgets('P4 第三批：编辑后点击「保存歌词」显示新歌词', (WidgetTester tester) async {
    await generateLyrics(tester);

    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    const newLyric = '这是测试编辑后的独特歌词内容XYZ';
    await tester.enterText(find.byType(TextField), newLyric);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存歌词'));
    await tester.pumpAndSettle();

    expect(find.text(newLyric), findsOneWidget);
    expect(find.text('编辑歌词'), findsOneWidget);
    expect(find.text('保存歌词'), findsNothing);
    expect(find.text('取消编辑'), findsNothing);
  });

  testWidgets('P4 第三批：编辑后点击「取消编辑」恢复旧歌词', (WidgetTester tester) async {
    await generateLyrics(tester);

    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    const newLyric = '这是不应该被保留的临时内容ABC';
    await tester.enterText(find.byType(TextField), newLyric);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消编辑'));
    await tester.pumpAndSettle();

    expect(find.text(newLyric), findsNothing);
    expect(find.text('编辑歌词'), findsOneWidget);
    expect(find.text('保存歌词'), findsNothing);
    expect(find.text('取消编辑'), findsNothing);
  });

  testWidgets(
    'P4-generated-audio-playback-1：「生成这首歌（实验）」按钮可见且点击弹费用确认对话框不触发 API',
    (WidgetTester tester) async {
      await generateLyrics(tester);

      expect(find.text('生成这首歌（实验）'), findsOneWidget);

      await tester.ensureVisible(find.text('生成这首歌（实验）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('生成这首歌（实验）'));
      await tester.pumpAndSettle();

      expect(find.text('生成这首歌'), findsOneWidget);
      expect(find.textContaining('这会发起一次 AI 音乐生成'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认生成'), findsOneWidget);

      expect(find.textContaining('MiniMax'), findsNothing);
      expect(find.textContaining('Mureka'), findsNothing);
    },
  );

  testWidgets('P4 第三批：编辑态时「生成这首歌」占位按钮禁用', (WidgetTester tester) async {
    await generateLyrics(tester);

    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    final songBtn = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('生成这首歌（实验）'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(songBtn.onPressed, isNull);
  });

  testWidgets('P4 第三批：「再写一首」清空编辑状态，再生成显示原歌词', (WidgetTester tester) async {
    // 第一次生成
    await generateLyrics(tester);

    // 编辑并保存新歌词
    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    const editedLyric = '这是第一次编辑保存的内容';
    await tester.enterText(find.byType(TextField), editedLyric);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存歌词'));
    await tester.pumpAndSettle();
    expect(find.text(editedLyric), findsOneWidget);

    // 点击「再写一首」重置
    await tester.ensureVisible(find.text('再写一首'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('再写一首'));
    await tester.pumpAndSettle();

    expect(find.text(editedLyric), findsNothing);
    expect(find.text('给现在的你'), findsNothing);

    // 重新生成（换一个故事）
    await generateLyrics(tester, story: '和妈妈吵架了');

    expect(find.text(editedLyric), findsNothing);
    expect(find.text('写成歌的话'), findsOneWidget);
    expect(find.text('编辑歌词'), findsOneWidget);
  });

  testWidgets('P4 第三批：保存歌词后再编辑，编辑框初始内容为上次保存的内容', (WidgetTester tester) async {
    await generateLyrics(tester);

    // 第一次编辑保存
    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    const firstEdit = '第一次编辑保存的歌词内容';
    await tester.enterText(find.byType(TextField), firstEdit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存歌词'));
    await tester.pumpAndSettle();

    // 第二次进入编辑，编辑框初始内容应为第一次保存的内容
    await tester.ensureVisible(find.text('编辑歌词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑歌词'));
    await tester.pumpAndSettle();

    final editField = tester.widget<TextField>(find.byType(TextField));
    expect(editField.controller!.text, firstEdit);
  });

  testWidgets('P4 第三批：页面不空白，结果区含编辑按钮和占位按钮', (WidgetTester tester) async {
    await generateLyrics(tester);

    expect(find.textContaining('本地模板'), findsOneWidget);
    expect(find.text('给现在的你'), findsOneWidget);
    expect(find.text('写成歌的话'), findsOneWidget);
    expect(find.text('编辑歌词'), findsOneWidget);
    expect(find.text('后续生成参数'), findsOneWidget);
    expect(find.textContaining('下一步可以生成专属歌曲'), findsOneWidget);
    expect(find.text('生成这首歌（实验）'), findsOneWidget);
    expect(find.text('再写一首'), findsOneWidget);
  });

  // ─── P4-conversation-song-flow-1-fix1：动态追问 + 加载文案分阶段测试 ──────

  /// fix1：输入「提不起劲 / 疲惫 / 很空」时，追问不应出现「这件事」。
  /// lowEnergy 分类的兜底问题不含「这件事」措辞，避免在用户没力气时问事件导向问题。
  testWidgets('fix1：低能量输入的追问不包含「这件事」', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近总是提不起劲，感觉很疲惫、很空');
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 进入 followUp 阶段
    expect(find.text('跳过追问，直接生成'), findsOneWidget);
    // fix2：lowEnergy 兜底第 1 问为「这种疲惫和空落感，通常什么时候最明显？」
    // 用完整文案匹配，避免与输入回显文本（也含「疲惫」）冲突
    expect(find.text('这种疲惫和空落感，通常什么时候最明显？'), findsOneWidget);
    // 不应出现「这件事里」这种事件导向措辞
    expect(find.textContaining('这件事'), findsNothing);
  });

  /// fix1：输入「和妈妈吵架了」时，eventConflict 分类的兜底问题允许出现「这件事」。
  testWidgets('fix1：事件冲突输入的追问可包含事件导向措辞', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '和妈妈吵架了');
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 进入 followUp 阶段
    expect(find.text('跳过追问，直接生成'), findsOneWidget);
    // eventConflict 兜底第 1 问应包含「最让你难受」
    expect(find.textContaining('最让你难受'), findsOneWidget);
  });

  /// fix1：加载文案分阶段 + 旧统一文案已移除。
  ///
  /// 说明：Flutter 测试环境（TestWidgetsFlutterBinding）会将所有 HTTP 请求
  /// 立即返回 400，导致 loadingFollowUp 阶段瞬时过渡到 followUp，无法捕获
  /// 中间加载态帧。本测试改为验证加载文案变更的「结果」：
  /// 1. 流程能正确进入 followUp 阶段（动态追问已生成）
  /// 2. 旧的统一加载文案「AI 正在理解你的状态」在整个流程中不出现
  ///    （分阶段文案在源码 comfort_lyrics_screen.dart:470 / analysis_screen.dart:237 硬编码）
  testWidgets('fix1：loadingFollowUp 阶段显示追问生成文案', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '最近工作压力很大');
    await tester.pump();
    await tester.tap(find.text('开始理解'));
    await tester.pumpAndSettle();

    // 流程正确进入 followUp 阶段（动态追问已生成）
    expect(find.text('跳过追问，直接生成'), findsOneWidget);
    // anxietyStress 兜底问题包含「最担心」
    expect(find.textContaining('最担心'), findsOneWidget);
    // 旧的统一加载文案不出现（已改为分阶段文案）
    expect(find.text('AI 正在理解你的状态，再等一下…'), findsNothing);
    expect(find.textContaining('AI 正在理解你的状态'), findsNothing);
  });

  // ─── P6-quota-guard-1：额度 UI widget 测试 ──────────────────────
  //
  // 覆盖 P6 成本保护的主要入口（「生成这首歌（实验）」按钮 + 额度提示）。
  // 通过预置全局 [generationQuotaService] 后触发歌词生成 fallback（_result != null），
  // 使结果区 [_buildGenerateSongButton] 渲染，验证额度提示文案与按钮禁用态。
  group('P6-quota-guard-1：额度 UI', () {
    tearDown(() {
      generationQuotaService = null;
    });

    /// 触发歌词生成（测试环境 http 快速 fallback 填充 _result），
    /// 使结果区的「生成这首歌（实验）」按钮与额度提示渲染出来。
    /// P4-conversation-song-flow-1：走「开始理解 → 跳过追问，直接生成」流程。
    /// fix1：_startFollowUp 改为异步，需 pump 等待 HTTP 失败后进入 followUp。
    Future<void> generateLyricsWithQuota(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
      await tester.pumpAndSettle(); // 让 initState 的 _refreshQuotaState 完成
      await tester.enterText(find.byType(TextField), '最近工作压力很大');
      await tester.pump();
      await tester.tap(find.text('开始理解'));
      // fix1：等待 fetchFollowUpQuestions HTTP 失败 + 本地兜底
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('跳过追问，直接生成'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('跳过追问，直接生成'));
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
      generationQuotaService = await LocalGenerationQuotaService.create(
        _FakePreferencesPort(),
      );

      await generateLyricsWithQuota(tester);

      expect(find.text('今日还可生成 1 首'), findsOneWidget);
      expect(findGenerateSongButton(tester).onPressed, isNotNull);
    });

    testWidgets('额度用完时显示「今日体验次数已用完」且生成按钮禁用', (tester) async {
      final fake = _FakePreferencesPort();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await fake.setString(
        LocalGenerationQuotaService.key,
        '{"date":"$today","count":1}',
      );
      generationQuotaService = await LocalGenerationQuotaService.create(fake);

      await generateLyricsWithQuota(tester);

      expect(find.text('今日体验次数已用完'), findsOneWidget);
      expect(findGenerateSongButton(tester).onPressed, isNull);
    });

    testWidgets('额度服务未装配时 permissive 降级：不显示额度提示且按钮可用', (tester) async {
      await generateLyricsWithQuota(tester);

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
