import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/listening_session.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/pipeline/local/local_feedback_repository.dart';
import 'package:xinxian_healing_music/pipeline/local/local_listening_session_recorder.dart';
import 'package:xinxian_healing_music/pipeline/local/preferences_port.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_pipeline_factory.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_template_registry.dart';

void main() {
  // 所有测试前重置 shared_preferences mock，避免互相污染
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('toJson / fromJson 往返一致', () {
    test('FeedbackRecord toJson → fromJson 字段全部相等', () {
      final original = FeedbackRecord(
        sessionId: 'sess-test-1',
        rating: 4,
        tensionBefore: 0.7,
        tensionAfter: 0.3,
        note: '放松',
        completed: false,
        createdAt: DateTime(2026, 6, 27, 10, 0, 0),
      );
      final restored = FeedbackRecord.fromJson(original.toJson());
      expect(restored.sessionId, original.sessionId);
      expect(restored.rating, original.rating);
      expect(restored.tensionBefore, original.tensionBefore);
      expect(restored.tensionAfter, original.tensionAfter);
      expect(restored.note, original.note);
      expect(restored.completed, original.completed);
      expect(restored.createdAt, original.createdAt);
    });

    test(
      'ListeningSession toJson → fromJson 字段全部相等（含 plan 快照 + feedback）',
      () async {
        final plan = await mockPipeline.run('最近备考压力很大，焦虑得睡不着');
        final feedback = FeedbackRecord(
          sessionId: plan.sessionId,
          rating: 5,
          tensionBefore: 0.8,
          tensionAfter: 0.2,
          note: '很放松',
          completed: false,
          createdAt: DateTime(2026, 6, 27, 10, 5, 0),
        );
        final original = ListeningSession(
          sessionId: plan.sessionId,
          moodText: '最近备考压力很大',
          startedAt: DateTime(2026, 6, 27, 10, 0, 0),
          plan: plan,
          listenedDuration: const Duration(seconds: 45),
          feedback: feedback,
          completedAt: DateTime(2026, 6, 27, 10, 5, 0),
        );
        final restored = ListeningSession.fromJson(original.toJson());

        expect(restored.sessionId, original.sessionId);
        expect(restored.moodText, original.moodText);
        expect(restored.startedAt, original.startedAt);
        expect(restored.listenedDuration, original.listenedDuration);
        expect(restored.completedAt, original.completedAt);
        // plan 快照字段
        expect(restored.plan.sessionId, plan.sessionId);
        expect(restored.plan.templateName, plan.templateName);
        expect(restored.plan.variant, ExperimentVariant.custom);
        expect(restored.plan.features.bpm, plan.features.bpm);
        expect(restored.plan.features.frequency, plan.features.frequency);
        expect(restored.plan.audio.assetPath, plan.audio.assetPath);
        // M4A：analyzerSource 默认 mock，toJson/fromJson 往返一致
        expect(restored.plan.analyzerSource, 'mock');
        expect(restored.plan.analyzerSource, plan.analyzerSource);
        // feedback 字段
        expect(restored.feedback, isNotNull);
        expect(restored.feedback!.sessionId, feedback.sessionId);
        expect(restored.feedback!.rating, feedback.rating);
      },
    );

    test('ListeningSession 容错：损坏字段不崩溃，回退默认值', () {
      final restored = ListeningSession.fromJson({
        'sessionId': 'sess-broken',
        // 故意缺 moodText / startedAt / plan
      });
      expect(restored.sessionId, 'sess-broken');
      expect(restored.moodText, '');
      expect(restored.plan.templateName, '');
      expect(restored.listenedDuration, Duration.zero);
      expect(restored.feedback, isNull);
      // M4A：缺 analyzerSource 字段时回退 mock，不崩溃
      expect(restored.plan.analyzerSource, 'mock');
    });
  });

  group('LocalListeningSessionRecorder', () {
    test('完整生命周期 + 重新加载后数据一致（模拟重启）', () async {
      final prefs = await SharedPreferences.getInstance();
      final plan = await mockPipeline.run('备考压力大，睡不着');

      // 第一次启动：begin → updateListening → attachFeedback
      final recorder1 = await LocalListeningSessionRecorder.create(
        SharedPrefsAdapter(prefs),
      );
      recorder1.begin(sessionId: plan.sessionId, moodText: '备考压力大', plan: plan);
      recorder1.updateListening(plan.sessionId, const Duration(seconds: 30));

      final feedback = FeedbackRecord(
        sessionId: plan.sessionId,
        rating: 4,
        tensionBefore: 0.7,
        tensionAfter: 0.3,
        note: '放松',
        completed: false,
        createdAt: DateTime.now(),
      );
      recorder1.attachFeedback(plan.sessionId, feedback);

      // 验证内存态正确
      final s1 = recorder1.get(plan.sessionId);
      expect(s1, isNotNull);
      expect(s1!.moodText, '备考压力大');
      expect(s1.listenedDuration, const Duration(seconds: 30));
      expect(s1.feedback, isNotNull);
      expect(s1.feedback!.rating, 4);
      expect(s1.completedAt, isNotNull);
      expect(s1.variant, ExperimentVariant.custom);

      // 模拟重启：重新 create 从磁盘加载
      final recorder2 = await LocalListeningSessionRecorder.create(
        SharedPrefsAdapter(prefs),
      );
      final s2 = recorder2.get(plan.sessionId);
      expect(s2, isNotNull);
      expect(s2!.sessionId, plan.sessionId);
      expect(s2.moodText, '备考压力大');
      expect(s2.listenedDuration, const Duration(seconds: 30));
      expect(s2.feedback, isNotNull);
      expect(s2.feedback!.rating, 4);
      expect(s2.plan.templateName, plan.templateName);
      // sessionId 三处一致
      expect(s2.sessionId, s2.plan.sessionId);
      expect(s2.feedback!.sessionId, s2.sessionId);
      // M4A：analyzerSource 持久化后重启仍为 mock
      expect(s2.plan.analyzerSource, 'mock');
    });

    test('最多保留 100 条，超出按最旧裁剪', () async {
      final prefs = await SharedPreferences.getInstance();
      final recorder = await LocalListeningSessionRecorder.create(
        SharedPrefsAdapter(prefs),
      );
      final plan = await mockPipeline.run('test');

      // 插入 105 条
      for (var i = 0; i < 105; i++) {
        recorder.begin(sessionId: 'sess-$i', moodText: 'mood $i', plan: plan);
        // 确保 startedAt 单调递增（begin 用 DateTime.now()，循环太快可能同毫秒）
        await Future.delayed(const Duration(milliseconds: 2));
      }

      final all = recorder.all();
      expect(all.length, 100);
      // 最旧的 5 条（sess-0 ~ sess-4）应被裁剪
      expect(recorder.get('sess-0'), isNull);
      expect(recorder.get('sess-4'), isNull);
      expect(recorder.get('sess-5'), isNotNull);
      expect(recorder.get('sess-104'), isNotNull);
    });

    test('delete 删除单条 + clear 清空全部', () async {
      final prefs = await SharedPreferences.getInstance();
      final recorder = await LocalListeningSessionRecorder.create(
        SharedPrefsAdapter(prefs),
      );
      final plan = await mockPipeline.run('test');

      recorder.begin(sessionId: 's1', moodText: 'm1', plan: plan);
      recorder.begin(sessionId: 's2', moodText: 'm2', plan: plan);
      recorder.begin(sessionId: 's3', moodText: 'm3', plan: plan);
      expect(recorder.all().length, 3);

      await recorder.delete('s2');
      expect(recorder.all().length, 2);
      expect(recorder.get('s2'), isNull);

      await recorder.clear();
      expect(recorder.all().length, 0);

      // 重启后也是空
      final recorder2 = await LocalListeningSessionRecorder.create(
        SharedPrefsAdapter(prefs),
      );
      expect(recorder2.all().length, 0);
    });

    test('损坏 JSON 不崩溃，返回空缓存', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalListeningSessionRecorder.key, '{broken json');
      final recorder = await LocalListeningSessionRecorder.create(
        SharedPrefsAdapter(prefs),
      );
      expect(recorder.all().length, 0);
    });

    test('restore 恢复已删除会话时保留原始 startedAt', () async {
      final prefs = await SharedPreferences.getInstance();
      final recorder = await LocalListeningSessionRecorder.create(
        SharedPrefsAdapter(prefs),
      );
      final plan = await mockPipeline.run('test restore');

      // begin 记录原始 startedAt
      recorder.begin(
        sessionId: plan.sessionId,
        moodText: '原始心境',
        plan: plan,
      );
      recorder.updateListening(plan.sessionId, const Duration(seconds: 42));
      final original = recorder.get(plan.sessionId)!;
      final originalStartedAt = original.startedAt;

      // 等待一小段时间，确保 DateTime.now() 会不同
      await Future.delayed(const Duration(milliseconds: 50));

      // 删除后 restore
      await recorder.delete(plan.sessionId);
      expect(recorder.get(plan.sessionId), isNull);
      recorder.restore(original);

      // 验证 startedAt 未变
      final restored = recorder.get(plan.sessionId)!;
      expect(restored.startedAt, originalStartedAt);
      expect(restored.moodText, '原始心境');
      expect(restored.listenedDuration, const Duration(seconds: 42));

      // 重启后 startedAt 仍不变
      final recorder2 = await LocalListeningSessionRecorder.create(
        SharedPrefsAdapter(prefs),
      );
      final afterRestart = recorder2.get(plan.sessionId)!;
      expect(afterRestart.startedAt, originalStartedAt);
    });
  });

  group('LocalFeedbackRepository', () {
    test('save upsert 语义：同 sessionId 两次 save 只保留一条', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = await LocalFeedbackRepository.create(
        SharedPrefsAdapter(prefs),
      );

      final f1 = FeedbackRecord(
        sessionId: 's1',
        rating: 3,
        tensionBefore: 0.7,
        tensionAfter: 0.5,
        createdAt: DateTime.now(),
      );
      final f2 = FeedbackRecord(
        sessionId: 's1',
        rating: 5,
        tensionBefore: 0.7,
        tensionAfter: 0.2,
        createdAt: DateTime.now(),
      );
      await repo.save(f1);
      await repo.save(f2);

      final all = await repo.all();
      expect(all.length, 1);
      expect(all.first.rating, 5);
    });

    test('重新加载后数据一致 + delete + clear', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo1 = await LocalFeedbackRepository.create(
        SharedPrefsAdapter(prefs),
      );

      await repo1.save(
        FeedbackRecord(
          sessionId: 's1',
          rating: 4,
          tensionBefore: 0.7,
          tensionAfter: 0.3,
          note: 'note1',
          createdAt: DateTime(2026, 6, 27, 10, 0),
        ),
      );
      await repo1.save(
        FeedbackRecord(
          sessionId: 's2',
          rating: 5,
          tensionBefore: 0.6,
          tensionAfter: 0.2,
          createdAt: DateTime(2026, 6, 27, 11, 0),
        ),
      );

      // 重启
      final repo2 = await LocalFeedbackRepository.create(
        SharedPrefsAdapter(prefs),
      );
      final all = await repo2.all();
      expect(all.length, 2);
      // 按 createdAt 倒序
      expect(all.first.sessionId, 's2');

      await repo2.delete('s1');
      expect((await repo2.all()).length, 1);

      await repo2.clear();
      expect((await repo2.all()).length, 0);
    });

    test('最多保留 100 条', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = await LocalFeedbackRepository.create(
        SharedPrefsAdapter(prefs),
      );
      for (var i = 0; i < 105; i++) {
        await repo.save(
          FeedbackRecord(
            sessionId: 's$i',
            rating: 3,
            tensionBefore: 0.5,
            tensionAfter: 0.5,
            createdAt: DateTime(2026, 1, 1, 0, i ~/ 60, i % 60),
          ),
        );
      }
      expect((await repo.all()).length, 100);
    });
  });

  group('M4A analyzerSource', () {
    test('HealingMusicPlan.toJson 包含 analyzerSource', () async {
      final plan = await mockPipeline.run('备考压力');
      final json = plan.toJson();
      expect(json.containsKey('analyzerSource'), isTrue);
      expect(json['analyzerSource'], 'mock');
    });

    test('HealingMusicPlan.fromJson 缺 analyzerSource 回退 mock', () {
      // 模拟 M3 旧数据：JSON 中无 analyzerSource 字段
      final restored = HealingMusicPlan.fromJson({
        'sessionId': 'sess-old',
        'templateName': '高压焦虑型',
        'variant': 'custom',
        'durationMinutes': 20,
        'guidance': 'test',
        // 故意不写 analyzerSource
      });
      expect(restored.analyzerSource, 'mock');
    });

    test('HealingMusicPlan.fromJson 显式 llm 值可读出', () {
      final restored = HealingMusicPlan.fromJson({
        'sessionId': 'sess-llm',
        'templateName': 'test',
        'variant': 'custom',
        'durationMinutes': 12,
        'guidance': '',
        'analyzerSource': 'llm',
      });
      expect(restored.analyzerSource, 'llm');
    });

    test('mockPipeline.run 返回 analyzerSource=mock', () async {
      final plan = await mockPipeline.run('失眠睡不着');
      expect(plan.analyzerSource, 'mock');
    });
  });

  group('M4A 最近邻匹配', () {
    test('精确值命中同一模板（行为与旧版一致）', () {
      // highPressure 模板 (valence=-0.4, arousal=0.8)，bpm=60
      final features = MockTemplateRegistry.featuresForValenceArousal(
        -0.4,
        0.8,
      );
      expect(features.bpm, 60);
      final meta = MockTemplateRegistry.metaForValenceArousal(-0.4, 0.8);
      expect(meta.templateName, '高压焦虑型');
    });

    test('连续值匹配最近模板（highPressure 附近）', () {
      // LLM 可能产出 valence=-0.35, arousal=0.72
      // 到 highPressure(-0.4, 0.8): 0.0025 + 0.0064 = 0.0089
      // 到 insomnia(-0.2, 0.6): 0.0225 + 0.0144 = 0.0369
      // → 命中 highPressure
      final features = MockTemplateRegistry.featuresForValenceArousal(
        -0.35,
        0.72,
      );
      expect(features.bpm, 60);
    });

    test('任意输入不再抛 StateError', () {
      // 旧版精确匹配遇到未命中值会 throw StateError
      // 最近邻版本应始终返回有效结果
      expect(
        () => MockTemplateRegistry.featuresForValenceArousal(0.99, 0.99),
        returnsNormally,
      );
      expect(
        () => MockTemplateRegistry.metaForValenceArousal(-0.99, 0.01),
        returnsNormally,
      );
    });

    test('6 套模板精确值全部命中自身', () {
      // 验证当前 mock 流程的 6 个 (valence, arousal) 点位仍各自命中
      final points = <(double, double, String)>[
        (-0.4, 0.8, '高压焦虑型'),
        (-0.2, 0.6, '入睡困难型'),
        (-0.6, 0.3, '情绪低落型'),
        (-0.5, 0.9, '情绪激越型'),
        (-0.3, 0.2, '身心疲惫型'),
        (0.2, 0.4, '平衡调和型'),
      ];
      for (final (v, a, name) in points) {
        final meta = MockTemplateRegistry.metaForValenceArousal(v, a);
        expect(meta.templateName, name, reason: '($v, $a) 应命中 $name');
      }
    });
  });
}
