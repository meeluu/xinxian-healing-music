import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/models/audio_post_process_config.dart';
import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/models/processed_audio.dart';
import 'package:xinxian_healing_music/screens/music_generation_screen.dart';

/// P4-mock-1-fix2 widget test
///
/// 验证 MusicGenerationScreen 的关键交互：
/// 1. 初始渲染立刻显示生成中文案，不空白
/// 2. 关闭按钮存在
/// 3. 3 秒 mock 完成后显示「播放这段音乐」按钮
void main() {
  HealingMusicPlan testPlan() => HealingMusicPlan(
    sessionId: 'test-session',
    templateName: 'test-template',
    mood: const MoodProfile(
      tags: ['测试'],
      valence: -0.3,
      arousal: 0.5,
      summary: '测试心境',
      intensity: 0.6,
      targetState: TargetState.soothe,
    ),
    features: const MusicFeatureTags(
      bpm: 60,
      frequency: '432Hz',
      brainwave: 'theta',
      instruments: [],
      harmony: 'C major',
      noiseLayer: '',
      durationMinutes: 10,
      title: '测试音频',
    ),
    audio: const ProcessedAudio(assetPath: 'music/soothe_01.mp3'),
    postProcess: const AudioPostProcessConfig(),
    variant: ExperimentVariant.custom,
    durationMinutes: 10,
    guidance: '测试引导文案',
  );

  testWidgets('初始渲染立刻显示生成中文案和关闭按钮，不空白', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MusicGenerationScreen(plan: testPlan(), moodText: '测试心境'),
      ),
    );

    // 首帧
    await tester.pump();

    // 页面标题
    expect(find.text('生成专属音乐'), findsOneWidget);

    // 生成中主文案
    expect(find.text('正在准备专属音乐片段'), findsOneWidget);

    // 实验功能副文案
    expect(find.text('这是实验功能，当前使用 mock 生成流程'), findsOneWidget);

    // 关闭按钮存在且 onPressed 不为 null（永远可点击）
    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.onPressed, isNotNull);

    // 推进 3 秒让 Future.delayed timer 完成，避免 pending timer 断言失败
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3 秒 mock 完成后显示「播放这段音乐」按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MusicGenerationScreen(plan: testPlan(), moodText: '测试心境'),
      ),
    );

    // 首帧
    await tester.pump();

    // 初始不应有播放按钮
    expect(find.text('播放这段音乐'), findsNothing);

    // 推进 3 秒（Future.delayed 的时长）
    await tester.pump(const Duration(seconds: 3));
    // 等一帧让 setState 生效
    await tester.pump();

    // 成功后应显示按钮
    expect(find.text('专属音乐片段已准备好'), findsOneWidget);
    expect(find.text('播放这段音乐'), findsOneWidget);
    expect(find.text('改用预置音乐'), findsOneWidget);
  });

  testWidgets('点击关闭按钮可以 pop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MusicGenerationScreen(
                      plan: testPlan(),
                      moodText: '测试心境',
                    ),
                  ),
                );
              },
              child: const Text('push'),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('push'));
    // 用 pump 代替 pumpAndSettle，因为 AnimationController.repeat 永不完成
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 进入生成页
    expect(find.text('正在准备专属音乐片段'), findsOneWidget);

    // 点击关闭按钮
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    // 推进 3 秒让 Future.delayed timer 完成，避免 pending timer 断言失败
    await tester.pump(const Duration(seconds: 3));

    // 应回到首页
    expect(find.text('push'), findsOneWidget);
  });
}
