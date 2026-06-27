import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/listening_session.dart';
import 'package:xinxian_healing_music/pipeline/local/local_feedback_repository.dart';
import 'package:xinxian_healing_music/pipeline/local/local_listening_session_recorder.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_pipeline_factory.dart';

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

    test('ListeningSession toJson → fromJson 字段全部相等（含 plan 快照 + feedback）', () async {
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
      // feedback 字段
      expect(restored.feedback, isNotNull);
      expect(restored.feedback!.sessionId, feedback.sessionId);
      expect(restored.feedback!.rating, feedback.rating);
    });

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
    });
  });

  group('LocalListeningSessionRecorder', () {
    test('完整生命周期 + 重新加载后数据一致（模拟重启）', () async {
      final prefs = await SharedPreferences.getInstance();
      final plan = await mockPipeline.run('备考压力大，睡不着');

      // 第一次启动：begin → updateListening → attachFeedback
      final recorder1 = await LocalListeningSessionRecorder.create(prefs);
      recorder1.begin(
        sessionId: plan.sessionId,
        moodText: '备考压力大',
        plan: plan,
      );
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
      final recorder2 = await LocalListeningSessionRecorder.create(prefs);
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
    });

    test('最多保留 100 条，超出按最旧裁剪', () async {
      final prefs = await SharedPreferences.getInstance();
      final recorder = await LocalListeningSessionRecorder.create(prefs);
      final plan = await mockPipeline.run('test');

      // 插入 105 条
      for (var i = 0; i < 105; i++) {
        recorder.begin(
          sessionId: 'sess-$i',
          moodText: 'mood $i',
          plan: plan,
        );
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
      final recorder = await LocalListeningSessionRecorder.create(prefs);
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
      final recorder2 = await LocalListeningSessionRecorder.create(prefs);
      expect(recorder2.all().length, 0);
    });

    test('损坏 JSON 不崩溃，返回空缓存', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalListeningSessionRecorder.key, '{broken json');
      final recorder = await LocalListeningSessionRecorder.create(prefs);
      expect(recorder.all().length, 0);
    });
  });

  group('LocalFeedbackRepository', () {
    test('save upsert 语义：同 sessionId 两次 save 只保留一条', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = await LocalFeedbackRepository.create(prefs);

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
      final repo1 = await LocalFeedbackRepository.create(prefs);

      await repo1.save(FeedbackRecord(
        sessionId: 's1',
        rating: 4,
        tensionBefore: 0.7,
        tensionAfter: 0.3,
        note: 'note1',
        createdAt: DateTime(2026, 6, 27, 10, 0),
      ));
      await repo1.save(FeedbackRecord(
        sessionId: 's2',
        rating: 5,
        tensionBefore: 0.6,
        tensionAfter: 0.2,
        createdAt: DateTime(2026, 6, 27, 11, 0),
      ));

      // 重启
      final repo2 = await LocalFeedbackRepository.create(prefs);
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
      final repo = await LocalFeedbackRepository.create(prefs);
      for (var i = 0; i < 105; i++) {
        await repo.save(FeedbackRecord(
          sessionId: 's$i',
          rating: 3,
          tensionBefore: 0.5,
          tensionAfter: 0.5,
          createdAt: DateTime(2026, 1, 1, 0, i ~/ 60, i % 60),
        ));
      }
      expect((await repo.all()).length, 100);
    });
  });
}
