# P4-conversation-song-flow-1 实施计划

## 一、当前状态分析

前一会话已完成以下工作（经探索核实）：

| 工作项 | 状态 | 证据 |
|--------|------|------|
| ComfortLyricsScreen 多轮对话流程（input→followUp→done，3 轮追问 + 跳过 + state 字段） | ✅ 已完成 | L139-L207 状态字段、L305-L374 方法、L467-L485 按钮「开始理解」、L489 followUp 分支、L498-L505 done 分支、L542-L762 _buildFollowUpCard |
| ComfortLyricsService.generate() 接收多轮上下文 | ✅ 已完成 | L43-L66 签名含 followUpAnswers/desiredFeeling/comfortDirection |
| functions/api/comfort-lyrics.js 多轮上下文校验 + LLM prompt 增强 | ✅ 已完成 | L192-L222 校验、callLlm 融入上下文、SYSTEM_PROMPT 含歌词结构要求 |
| plan_screen.dart 删除「生成专属音乐（实验）」入口 | ✅ 已完成 | L348-L350 注释说明已下线 |
| music_generation_screen.dart 及测试文件删除 | ✅ 已完成 | Test-Path 确认 DELETED |
| ComfortLyricsScreen import sleep_timer_button.dart | ⚠️ 已 import 但文件不存在 | L13 `import '...sleep_timer_button.dart';` → **当前代码无法编译** |

**待完成工作（本计划范围）**：

1. 新建 `lib/widgets/sleep_timer_button.dart`（**阻塞项，最高优先级**）
2. PlayerScreen 接入 SleepTimerButton
3. ComfortLyricsScreen AI 生成歌曲播放区接入 SleepTimerButton
4. ComfortLyricsScreen AI 歌曲结果区追加「快速舒缓一下」CTA
5. 版本号同步（app_version.dart + health.js + verify-provider-adapter.mjs）
6. 更新 test/comfort_lyrics_screen_test.dart 适配多轮流程
7. 更新 README.md + docs/ROADMAP.md
8. 运行验证命令

## 二、关键设计决策

### 决策 1：CTA「快速舒缓一下」点击后跳转目标

用户原话："点击后进入现有'快速舒缓一下'本地音乐流程或直接推荐一首本地纯音乐"。

**采用方案 A：跳转 AnalysisScreen，带默认心境文本**。

理由：
- 复用现有完整流程（AnalysisScreen → PlanScreen → PlayerScreen），代码改动最小
- AnalysisScreen 已有完整错误处理 + 加载动画 + 重试机制
- 走 LLM 情绪分析（用户明确说"可以保留情绪分析/推荐逻辑"），推荐更贴合的本地纯音乐
- 最终播放的是本地音频（AudioAssetCatalog 匹配），不触发 MiniMax，不扣额度
- LLM 失败有 mock fallback，不影响体验

心境文本构造：根据用户在多轮对话中选择的 `desiredFeeling` / `comfortDirection` 拼接，如 `"听完这首歌，想再安静一会儿，慢慢平静下来"`；无选择时用 `"听完这首歌，想再安静一会儿"`。

### 决策 2：SleepTimerButton 组件设计

自包含 StatefulWidget，接收 `AudioPlayer` 实例，封装全部定时逻辑：
- 定时选项：关闭、5/10/15/30 分钟、播放完当前音频
- 5/10/15/30 分钟：用 `Timer` 倒计时，到时调用 `player.pause()`
- 「播放完当前音频」：监听 `player.processingStateStream`，检测到 `ProcessingState.completed` 时不再自动重播（PlayerScreen 现有逻辑会在 completed 后显示重播按钮，定时关闭只需确保不自动 play）
- 定时状态文本显示：「定时关闭：10 分钟」「本曲结束后关闭」「关闭」
- dispose 清理 Timer 和 StreamSubscription
- UI 轻量：一个 OutlinedButton.icon + PopupMenuButton（小图标），不挤压播放按钮

### 决策 3：定时关闭「播放完当前音频」的实现

PlayerScreen 现有 `_toggle()` 在 `processingState == completed` 时会 seek(0)+play 重播。定时关闭「本曲结束后关闭」需要：
- 在 SleepTimerButton 内监听 `processingStateStream`
- 检测到 completed 时调用 `player.pause()`（覆盖重播）
- 但 PlayerScreen 的 `_toggle` 是用户主动点击才触发，不会自动重播
- 所以「本曲结束后关闭」实际只需：音频自然播完后，不引导用户重播，显示「已按定时关闭」

简化实现：监听 processingStateStream，completed 时暂停 + 更新状态文本为「已关闭」。

## 三、具体修改清单

### 3.1 新建 `lib/widgets/sleep_timer_button.dart`（最高优先级，阻塞编译）

**为什么**：ComfortLyricsScreen L13 已 import 此文件，不创建则整个项目无法编译。

**实现**：

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

/// 定时关闭按钮（P4-conversation-song-flow-1）。
///
/// 自包含 StatefulWidget，接收 [AudioPlayer] 实例，封装全部定时逻辑。
/// 支持：关闭、5/10/15/30 分钟、播放完当前音频。
/// 到时间自动暂停播放；UI 轻量，不挤压播放按钮。
///
/// 定时只控制播放，不影响生成；不新增后台任务；dispose 清理 timer。
class SleepTimerButton extends StatefulWidget {
  final AudioPlayer player;

  const SleepTimerButton({super.key, required this.player});

  @override
  State<SleepTimerButton> createState() => _SleepTimerButtonState();
}

/// 定时模式。
enum _SleepTimerMode {
  off,
  min5,
  min10,
  min15,
  min30,
  endOfTrack,
}

class _SleepTimerButtonState extends State<SleepTimerButton> {
  _SleepTimerMode _mode = _SleepTimerMode.off;
  Timer? _timer;
  StreamSubscription<PlayerState>? _stateSub;

  /// 剩余秒数（仅 minute 模式有效），用于显示倒计时。
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  void _setMode(_SleepTimerMode mode) {
    _timer?.cancel();
    _stateSub?.cancel();
    setState(() {
      _mode = mode;
      _remainingSeconds = 0;
    });
    switch (mode) {
      case _SleepTimerMode.off:
        break;
      case _SleepTimerMode.min5:
        _startCountdown(5 * 60);
        break;
      case _SleepTimerMode.min10:
        _startCountdown(10 * 60);
        break;
      case _SleepTimerMode.min15:
        _startCountdown(15 * 60);
        break;
      case _SleepTimerMode.min30:
        _startCountdown(30 * 60);
        break;
      case _SleepTimerMode.endOfTrack:
        _listenEndOfTrack();
        break;
    }
  }

  void _startCountdown(int seconds) {
    _remainingSeconds = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remainingSeconds -= 1);
      if (_remainingSeconds <= 0) {
        t.cancel();
        _onTimerFired();
      }
    });
  }

  void _listenEndOfTrack() {
    _stateSub = widget.player.processingStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (!mounted) return;
        _onTimerFired();
      }
    });
  }

  void _onTimerFired() {
    try {
      widget.player.pause();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _mode = _SleepTimerMode.off;
      _remainingSeconds = 0;
    });
  }

  String get _statusText {
    switch (_mode) {
      case _SleepTimerMode.off:
        return '定时关闭';
      case _SleepTimerMode.min5:
      case _SleepTimerMode.min10:
      case _SleepTimerMode.min15:
      case _SleepTimerMode.min30:
        final m = (_remainingSeconds / 60).ceil();
        return '定时关闭：$m 分钟';
      case _SleepTimerMode.endOfTrack:
        return '本曲结束后关闭';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SleepTimerMode>(
      onSelected: _setMode,
      itemBuilder: (context) => [
        const PopupMenuItem(value: _SleepTimerMode.off, child: Text('关闭')),
        const PopupMenuItem(value: _SleepTimerMode.min5, child: Text('5 分钟')),
        const PopupMenuItem(value: _SleepTimerMode.min10, child: Text('10 分钟')),
        const PopupMenuItem(value: _SleepTimerMode.min15, child: Text('15 分钟')),
        const PopupMenuItem(value: _SleepTimerMode.min30, child: Text('30 分钟')),
        const PopupMenuItem(value: _SleepTimerMode.endOfTrack, child: Text('播放完当前音频')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _mode == _SleepTimerMode.off
              ? const Color(0xFFE6F1F9)
              : AppColors.lavender.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _mode == _SleepTimerMode.off
                ? Colors.transparent
                : AppColors.lavender.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 14,
              color: _mode == _SleepTimerMode.off
                  ? AppColors.primary
                  : AppColors.lavender,
            ),
            const SizedBox(width: 4),
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 11,
                color: _mode == _SleepTimerMode.off
                    ? AppColors.primaryDeep
                    : AppColors.lavender,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3.2 修改 `lib/screens/player_screen.dart` 接入 SleepTimerButton

**位置**：在 `_ProgressSection` 之后、目标标签之前（L283 附近），插入一行 SleepTimerButton。

**修改**：
- L10 后新增 import：`import 'package:xinxian_healing_music/widgets/sleep_timer_button.dart';`
- L283 `const SizedBox(height: 28);` 之前插入：
  ```dart
  // P4-conversation-song-flow-1：定时关闭（轻量，不挤压播放按钮）
  if (!_error) ...[
    const SizedBox(height: 8),
    Center(child: SleepTimerButton(player: _player)),
  ],
  ```

### 3.3 修改 `lib/screens/comfort_lyrics_screen.dart` AI 生成歌曲播放区接入 SleepTimerButton

**位置**：AI 生成歌曲结果区 `_buildSongResultSection` 内的播放控件附近。

**查找**：搜索 `_generatedAudioPlayer` 的播放控件 UI（包含 _isPlayingGenerated 切换按钮的位置），在播放控件行追加 SleepTimerButton。

**修改**：在 AI 生成歌曲的播放控制行（包含「重新播放」按钮的那一行）旁边或下方，插入：
```dart
SleepTimerButton(player: _generatedAudioPlayer!),
```
仅在 `_generatedAudioPlayer != null` 时显示。

### 3.4 修改 `lib/screens/comfort_lyrics_screen.dart` 追加「快速舒缓一下」CTA

**位置**：`_buildSongResultSection` 末尾（操作按钮之后）追加一个温和 CTA 卡片。

**实现**：新增方法 `_buildSootheCta()`：
```dart
/// P4-conversation-song-flow-1：AI 歌曲后引导纯音乐 CTA。
///
/// 文案温和，引导用户进入本地纯音乐舒缓（不触发 MiniMax，不扣额度）。
/// 点击后跳转 AnalysisScreen，带默认心境文本，走现有「快速舒缓一下」流程。
Widget _buildSootheCta() {
  return Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgBlue,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: const [
            Icon(Icons.spa_rounded, size: 16, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              '还想再安静一会儿吗？',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '可以听一段不带歌词的纯音乐，让情绪慢慢落下来。',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _goToSoothe,
          icon: const Icon(Icons.music_note_rounded, size: 16),
          label: const Text('快速舒缓一下', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(42),
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );
}
```

**新增导航方法 `_goToSoothe()`**：
```dart
/// P4-conversation-song-flow-1：跳转本地纯音乐舒缓流程。
///
/// 根据用户多轮对话中选择的 desiredFeeling / comfortDirection 构造温和心境文本，
/// 跳转 AnalysisScreen 走现有「快速舒缓一下」流程。
/// 不触发 MiniMax，不扣额度（额度只约束 AI 歌曲生成）。
void _goToSoothe() {
  // 停止 AI 生成歌曲播放，避免两路音频叠加
  _generatedAudioPlayer?.pause();
  final parts = <String>['听完这首歌，想再安静一会儿'];
  if (_comfortDirection.isNotEmpty) {
    parts.add(_comfortDirection);
  } else if (_desiredFeeling.isNotEmpty) {
    parts.add('想要一点$_desiredFeeling');
  }
  final moodText = parts.join('，');
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AnalysisScreen(moodText: moodText),
    ),
  );
}
```

**需要新增 import**：`import 'package:xinxian_healing_music/screens/analysis_screen.dart';`（如未导入）

**接入点**：在 `_buildSongResultSection` 的 return Column children 末尾（操作按钮 Row 之后）追加 `_buildSootheCta()`。

### 3.5 版本号同步

#### `lib/config/app_version.dart`
- L21: `static const String milestone = 'P6-Quota-v1.0';` → `'P4-AI-Music-v1.0';`
- L57: `static const String buildLabel = 'P6-quota-guard-1';` → `'P4-conversation-song-flow-1';`
- L60: `static const String buildDate = '2026-07-23';` → 保持 `'2026-07-23'`（用户指定）

#### `functions/api/health.js`
- 找到 `BUILD_LABEL` 常量，值从 `'P6-quota-guard-1'` 改为 `'P4-conversation-song-flow-1'`
- 找到 `milestone` 常量（如有），值从 `'P6-Quota-v1.0'` 改为 `'P4-AI-Music-v1.0'`

#### `scripts/verify-provider-adapter.mjs`
- 找到所有断言 `buildLabel` 为 `P6-quota-guard-1` 的地方（探索显示 L1434-L1438），改为断言 `P4-conversation-song-flow-1`
- 同步断言 `indexOf('P4-') === 0`（如果之前改成 P6 需改回 P4）

### 3.6 更新 `test/comfort_lyrics_screen_test.dart`

**核心问题**：
1. 按钮文案从「生成解惑与歌词草稿」改为「开始理解」
2. 点击「开始理解」后不再直接生成结果，而是进入 followUp 阶段
3. 要得到结果，需要：点击「开始理解」→ 在 followUp 阶段点击「跳过追问，直接生成」或回答完 3 轮

**修改策略**：

**a) 更新所有文案断言**：`'生成解惑与歌词草稿'` → `'开始理解'`

**b) 抽取触发生成的辅助函数**（在 main 函数内顶部定义）：
```dart
/// P4-conversation-song-flow-1：触发生成的完整流程。
/// input 阶段输入困惑 → 点击「开始理解」→ followUp 阶段点击「跳过追问，直接生成」→ 等待 fallback 完成。
Future<void> generateLyrics(WidgetTester tester, {String story = '最近工作压力很大'}) async {
  await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), story);
  await tester.pump();
  await tester.tap(find.text('开始理解'));
  await tester.pumpAndSettle();
  // followUp 阶段：点击「跳过追问，直接生成」
  await tester.ensureVisible(find.text('跳过追问，直接生成'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('跳过追问，直接生成'));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}
```

**c) 更新所有测试用例**：将原来的 `tap('生成解惑与歌词草稿')` 替换为调用 `generateLyrics(tester)`

**d) 新增多轮对话测试**：
```dart
testWidgets('P4-conversation-song-flow-1：input 阶段显示「开始理解」按钮，点击进入 followUp', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
  await tester.pumpAndSettle();
  expect(find.text('开始理解'), findsOneWidget);
  await tester.enterText(find.byType(TextField), '最近工作压力很大');
  await tester.pump();
  await tester.tap(find.text('开始理解'));
  await tester.pumpAndSettle();
  // 进入 followUp 阶段：显示第 1 个追问
  expect(find.textContaining('最让你放不下'), findsOneWidget);
  expect(find.text('跳过追问，直接生成'), findsOneWidget);
});

testWidgets('P4-conversation-song-flow-1：followUp 阶段可跳过直接生成', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '最近工作压力很大');
  await tester.pump();
  await tester.tap(find.text('开始理解'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('跳过追问，直接生成'));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  expect(find.text('给现在的你'), findsOneWidget);
});

testWidgets('P4-conversation-song-flow-1：followUp 阶段回答 3 轮后自动生成', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: ComfortLyricsScreen()));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '最近工作压力很大');
  await tester.pump();
  await tester.tap(find.text('开始理解'));
  await tester.pumpAndSettle();
  // Q1
  await tester.enterText(find.byType(TextField), '最放不下的是没发出去的消息');
  await tester.pumpAndSettle();
  await tester.tap(find.text('继续'));
  await tester.pumpAndSettle();
  // Q2
  await tester.tap(find.text('安慰').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('继续'));
  await tester.pumpAndSettle();
  // Q3
  await tester.tap(find.text('想慢慢平静下来').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('生成'));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  expect(find.text('给现在的你'), findsOneWidget);
});
```

**e) 更新 P6 额度 UI group 的 `generateLyrics` 辅助函数**：同样改为「开始理解」→「跳过追问，直接生成」流程。

**f) 更新文件顶部注释**：说明 P4-conversation-song-flow-1 的多轮流程对测试的影响。

### 3.7 更新 `README.md`

新增 P4-conversation-song-flow-1 章节，内容：
- 「把困惑写成一首歌」改为多轮理解流程（input → 2-3 轮温和追问 → done）
- 「给现在的你」保留当前定位，使用多轮上下文
- 歌词基于多轮上下文增强（第一段承接困境、第二段温和转念、副歌给陪伴话、结尾回到平静）
- 多轮数据只存页面 state，不做长期保存
- 「快速舒缓一下」只使用本地纯音乐库，不再做 AI 纯音乐生成
- AI 歌曲生成后可引导进入本地纯音乐舒缓（不触发 MiniMax，不扣额度）
- 新增定时关闭（关闭/5/10/15/30 分钟/播放完当前音频）
- 版本号：milestone=P4-AI-Music-v1.0，buildLabel=P4-conversation-song-flow-1
- 本批不做：R2、历史歌曲、分享链接、付费、用户系统、4090 部署、真实 MiniMax 测试

### 3.8 更新 `docs/ROADMAP.md`

新增 P4-conversation-song-flow-1 条目，同步上述功能说明与不做清单。

## 四、验证步骤

按顺序运行：

1. `flutter analyze` — 确认无编译错误（特别是 sleep_timer_button.dart 创建后）
2. `flutter test` — 确认更新后的测试通过
3. `flutter build web --release` — 确认 Web 构建成功
4. `node scripts/verify-provider-adapter.mjs` — 确认版本号断言通过

## 五、完成汇报项

完成后向用户汇报：
- 多轮对话流程如何工作（input → 3 轮追问 → done，可跳过）
- 歌词如何更贴合用户困境（吸收多轮回答具体细节 + 结构化歌词要求）
- 「给现在的你」是否保持原结构（是，仅使用多轮上下文，不大改）
- 纯音乐 AI 生成入口是否已删除/隐藏（是，plan_screen 入口已删，music_generation_screen 已删）
- 快速舒缓是否只使用本地音乐（是，跳转 AnalysisScreen 走本地 AudioAssetCatalog）
- AI 歌曲后如何引导纯音乐（结果区末尾 CTA「还想再安静一会儿吗？」→ 跳转 AnalysisScreen）
- 定时关闭支持哪些选项（关闭/5/10/15/30 分钟/播放完当前音频）
- P6 额度保护是否仍保留（是，未改动 LocalGenerationQuotaService）
- realCallsEnabled 是否仍为 false（是，未改动 wrangler.toml）
- 版本号最终显示什么（milestone=P4-AI-Music-v1.0，buildLabel=P4-conversation-song-flow-1，buildDate=2026-07-23）
- 验证命令是否通过（逐项报告）

## 六、不改动清单（硬约束）

- `wrangler.toml` 中 `MUSIC_GENERATION_REAL_CALLS_ENABLED` 保持 `"false"`
- 不移除 `manualTest=true` 保护
- 不新增任何自动调用 MiniMax 的逻辑
- 不调用 Mureka API
- 不部署真实试听
- 不改动 LocalGenerationQuotaService（P6 额度保护）
- 不新增第三方依赖
- 不使用医疗化表达
- ComfortLyricsService 的 fallback 不使用多轮字段（保持 fallback 稳定）
