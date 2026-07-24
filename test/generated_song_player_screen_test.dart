import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/screens/generated_song_player_screen.dart';

/// GeneratedSongPlayerScreen 页面测试（P4-playback-experience-2）。
///
/// 测试范围：
/// - 静态 UI 渲染：歌曲标题 / 副文案 / "给现在的你" / 歌词 / 返回按钮 / AppBar 标题
/// - 不暴露 API Key / 不出现医疗化文案
///
/// 说明：Flutter 测试环境无真实音频后端。just_audio 的 AudioPlayer 在测试环境
/// 下 EventChannel / 平台通道无法正常完成，[AudioPlayer.setAudioSource] 的 Future
/// 不会可靠地 settle，因此 [GeneratedSongPlayerScreen._initAudio] 的 _loading → _error
/// 状态机无法在 widget 测试中稳定断言（与项目内 player_screen.dart 不做 widget
/// 测试的原因一致）。本测试只覆盖「首帧即渲染、不依赖音频加载完成」的静态 UI，
/// 错误态 / 播放控制 / 进度拖动等依赖真实音频后端的行为由手动验收覆盖（见任务
/// 手动验收步骤 5）。
///
/// 渲染策略：用 [tester.pump]（单帧）而非 [tester.pumpAndSettle]，因为 pumpAndSettle
/// 会因 just_audio 内部的 EventChannel / 周期定时器一直有帧待调度而超时。静态元素
/// 在 build() 中无条件渲染，首帧即可断言。
void main() {
  /// 构造一个最小可用的 [GeneratedSongMeta]。
  GeneratedSongMeta buildMeta({
    String playableUrl = 'https://example.invalid/test.mp3',
    String title = '夜里的一盏灯',
    String comfortInterpretation = '你现在不需要立刻好起来，先慢慢听一遍这首歌。',
    String lyricDraft = '【主歌】\n风很轻\n【副歌】\n你不用那么坚强',
    String targetState = 'soothe',
  }) {
    return GeneratedSongMeta(
      playableUrl: playableUrl,
      title: title,
      comfortInterpretation: comfortInterpretation,
      lyricDraft: lyricDraft,
      targetState: targetState,
    );
  }

  /// 渲染播放页首帧（不 pumpAndSettle，避免音频后端超时）。
  Future<void> pumpPlayer(
    WidgetTester tester, {
    GeneratedSongMeta? meta,
  }) async {
    await tester.pumpWidget(
      MaterialApp(home: GeneratedSongPlayerScreen(meta: meta ?? buildMeta())),
    );
    // 首帧：build() 中所有静态元素已渲染。_initAudio 在 addPostFrameCallback 中
    // 异步执行，不影响首帧静态 UI。
    await tester.pump();
  }

  testWidgets('P4-playback-experience-2：渲染歌曲标题与副文案', (tester) async {
    await pumpPlayer(tester, meta: buildMeta(title: '夜里的一盏灯'));

    expect(find.text('夜里的一盏灯'), findsOneWidget);
    expect(find.textContaining('根据你刚才写下的内容生成'), findsOneWidget);
  });

  testWidgets('P4-playback-experience-2：渲染「给现在的你」与歌词小节', (tester) async {
    await pumpPlayer(tester);

    expect(find.text('给现在的你'), findsOneWidget);
    expect(find.text('歌词'), findsOneWidget);
    // 温和解惑文案与歌词内容可见（SelectableText）
    expect(find.text('你现在不需要立刻好起来，先慢慢听一遍这首歌。'), findsOneWidget);
    expect(find.textContaining('风很轻'), findsOneWidget);
  });

  testWidgets('P4-playback-experience-2：渲染返回歌词页按钮', (tester) async {
    await pumpPlayer(tester);

    expect(find.text('返回歌词页'), findsOneWidget);
  });

  testWidgets('P4-playback-experience-2：AppBar 标题为「AI 生成歌曲」', (tester) async {
    await pumpPlayer(tester);

    expect(find.text('AI 生成歌曲'), findsOneWidget);
  });

  testWidgets('P4-playback-experience-2：标题文案来自 meta.title（参数化）', (
    tester,
  ) async {
    await pumpPlayer(tester, meta: buildMeta(title: '清晨的微光'));

    expect(find.text('清晨的微光'), findsOneWidget);
    expect(find.text('夜里的一盏灯'), findsNothing);
  });

  testWidgets('P4-playback-experience-2：歌词内容来自 meta.lyricDraft（参数化）', (
    tester,
  ) async {
    await pumpPlayer(tester, meta: buildMeta(lyricDraft: '【主歌】\n独特的歌词XYZ123'));

    expect(find.textContaining('独特的歌词XYZ123'), findsOneWidget);
  });

  testWidgets(
    'P4-playback-experience-2：「给现在的你」内容来自 meta.comfortInterpretation',
    (tester) async {
      await pumpPlayer(
        tester,
        meta: buildMeta(comfortInterpretation: '这是给现在的你的独特温和话语ABC'),
      );

      expect(find.text('这是给现在的你的独特温和话语ABC'), findsOneWidget);
    },
  );

  testWidgets('P4-playback-experience-2：首帧渲染加载指示器（_loading 初始态）', (
    tester,
  ) async {
    await pumpPlayer(tester);

    // _loading=true 时播放按钮位置显示 CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('P4-playback-experience-2：不暴露 API Key / Secret / 模型名', (
    tester,
  ) async {
    await pumpPlayer(tester);

    expect(find.textContaining('MiniMax'), findsNothing);
    expect(find.textContaining('Mureka'), findsNothing);
    expect(find.textContaining('API'), findsNothing);
    expect(find.textContaining('Key'), findsNothing);
    expect(find.textContaining('Secret'), findsNothing);
  });

  testWidgets('P4-playback-experience-2：不出现医疗化文案', (tester) async {
    await pumpPlayer(tester);

    expect(find.textContaining('治疗'), findsNothing);
    expect(find.textContaining('治愈'), findsNothing);
    expect(find.textContaining('失眠'), findsNothing);
    expect(find.textContaining('焦虑症'), findsNothing);
  });
}
