import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinxian_healing_music/models/audio_post_process_config.dart';
import 'package:xinxian_healing_music/models/cloud_feedback_payload.dart';
import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/feedback_record.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/models/processed_audio.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_pipeline_factory.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CloudFeedbackPayload.fromFeedback 字段映射', () {
    test('基础字段从 record + plan 正确映射', () async {
      final plan = await mockPipeline.run('备考压力大，焦虑得睡不着');
      final record = FeedbackRecord(
        sessionId: plan.sessionId,
        rating: 4,
        tensionBefore: 0.8,
        tensionAfter: 0.3,
        note: '听完很放松',
        completed: false,
        createdAt: DateTime(2026, 6, 28, 10, 0, 0),
      );

      final payload = CloudFeedbackPayload.fromFeedback(
        record: record,
        plan: plan,
        clientVersion: 'v0.7.0',
        userAgent: 'TestUA/1.0',
      );

      // 会话 ID 一致
      expect(payload.sessionId, plan.sessionId);
      expect(payload.listeningSessionId, plan.sessionId);
      expect(payload.listeningSessionId, payload.sessionId);

      // 时间戳 ISO8601
      expect(payload.createdAt, record.createdAt.toIso8601String());

      // 评分映射
      expect(payload.relaxationScore, 4);

      // calmnessScore = (1 - tensionAfter) * 100 = (1 - 0.3) * 100 = 70
      expect(payload.calmnessScore, 70);

      // 文字反馈原样传递（剥离由 uploader 处理）
      expect(payload.freeTextFeedback, '听完很放松');

      // 实验分组
      expect(payload.experimentVariant, plan.variant.name);

      // 解析来源
      expect(payload.analyzerMode, plan.analyzerSource);

      // 目标状态
      expect(payload.targetState, plan.mood.targetState.name);

      // 情绪标签
      expect(payload.emotionTags, equals(plan.mood.tags));

      // 效价 / 唤醒度 / 强度
      expect(payload.valence, plan.mood.valence);
      expect(payload.arousal, plan.mood.arousal);
      expect(payload.intensity, plan.mood.intensity);

      // M7.0 不收集的字段
      expect(payload.emotionMatchScore, isNull);
      expect(payload.willingToContinue, isNull);

      // 版本与平台
      expect(payload.clientVersion, 'v0.7.0');
      expect(payload.userAgent, 'TestUA/1.0');
      expect(payload.source, 'web');
      expect(payload.schemaVersion, 1);
    });

    test('calmnessScore 边界值：tensionAfter=0 → 100，tensionAfter=1 → 0', () async {
      final plan = await mockPipeline.run('test');

      // tensionAfter = 0.0 → calmnessScore = 100
      final r1 = FeedbackRecord(
        sessionId: plan.sessionId,
        rating: 5,
        tensionBefore: 0.7,
        tensionAfter: 0.0,
        createdAt: DateTime.now(),
      );
      final p1 = CloudFeedbackPayload.fromFeedback(
        record: r1,
        plan: plan,
        clientVersion: 'v0.7.0',
      );
      expect(p1.calmnessScore, 100);

      // tensionAfter = 1.0 → calmnessScore = 0
      final r2 = FeedbackRecord(
        sessionId: plan.sessionId,
        rating: 1,
        tensionBefore: 0.7,
        tensionAfter: 1.0,
        createdAt: DateTime.now(),
      );
      final p2 = CloudFeedbackPayload.fromFeedback(
        record: r2,
        plan: plan,
        clientVersion: 'v0.7.0',
      );
      expect(p2.calmnessScore, 0);

      // tensionAfter = 0.5 → calmnessScore = 50
      final r3 = FeedbackRecord(
        sessionId: plan.sessionId,
        rating: 3,
        tensionBefore: 0.7,
        tensionAfter: 0.5,
        createdAt: DateTime.now(),
      );
      final p3 = CloudFeedbackPayload.fromFeedback(
        record: r3,
        plan: plan,
        clientVersion: 'v0.7.0',
      );
      expect(p3.calmnessScore, 50);
    });

    test('audioAssetId 脱敏：从 assetPath 提取文件名', () async {
      final plan = await mockPipeline.run('test');
      final record = FeedbackRecord(
        sessionId: plan.sessionId,
        rating: 3,
        tensionBefore: 0.5,
        tensionAfter: 0.5,
        createdAt: DateTime.now(),
      );
      final payload = CloudFeedbackPayload.fromFeedback(
        record: record,
        plan: plan,
        clientVersion: 'v0.7.0',
      );

      // plan.audio.assetPath 形如 'assets/music/sleep_01.mp3' 或 'sleep_01.mp3'
      final assetPath = plan.audio.assetPath;
      if (assetPath.isNotEmpty) {
        final expected = assetPath.replaceAll('\\', '/').split('/').last;
        expect(payload.audioAssetId, expected);
        expect(payload.audioAssetId!.contains('/'), isFalse);
        expect(payload.audioAssetId!.contains('\\'), isFalse);
      }
    });

    test('note 为 null 时 freeTextFeedback 为 null', () async {
      final plan = await mockPipeline.run('test');
      final record = FeedbackRecord(
        sessionId: plan.sessionId,
        rating: 3,
        tensionBefore: 0.5,
        tensionAfter: 0.5,
        note: null,
        createdAt: DateTime.now(),
      );
      final payload = CloudFeedbackPayload.fromFeedback(
        record: record,
        plan: plan,
        clientVersion: 'v0.7.0',
      );
      expect(payload.freeTextFeedback, isNull);
    });

    test('空 title / brainwave / noiseLayer → 对应字段为 null', () {
      // 构造一个 features 全空的 plan
      final plan = HealingMusicPlan(
        sessionId: 'test-empty',
        templateName: '',
        mood: const MoodProfile(
          tags: ['焦虑'],
          valence: -0.4,
          arousal: 0.8,
          summary: '',
          intensity: 0.7,
          targetState: TargetState.sleep,
        ),
        features: const MusicFeatureTags(
          bpm: 60,
          frequency: '432Hz',
          brainwave: '',
          instruments: [],
          harmony: '',
          noiseLayer: '',
          durationMinutes: 12,
          title: '',
        ),
        audio: const ProcessedAudio(assetPath: ''),
        postProcess: const AudioPostProcessConfig(),
        variant: ExperimentVariant.custom,
        durationMinutes: 12,
        guidance: '',
        analyzerSource: 'mock',
      );

      final record = FeedbackRecord(
        sessionId: 'test-empty',
        rating: 3,
        tensionBefore: 0.5,
        tensionAfter: 0.5,
        createdAt: DateTime.now(),
      );
      final payload = CloudFeedbackPayload.fromFeedback(
        record: record,
        plan: plan,
        clientVersion: 'v0.7.0',
      );

      expect(payload.musicTitle, isNull);
      expect(payload.brainwaveTarget, isNull);
      expect(payload.noiseLayer, isNull);
      expect(payload.audioAssetId, isNull);
      expect(payload.audioAssetTitle, isNull);
    });
  });

  group('CloudFeedbackPayload.toJson 序列化', () {
    test('非 null 字段出现在 JSON 中', () async {
      final plan = await mockPipeline.run('备考压力');
      final record = FeedbackRecord(
        sessionId: plan.sessionId,
        rating: 5,
        tensionBefore: 0.8,
        tensionAfter: 0.2,
        note: '很放松',
        createdAt: DateTime(2026, 6, 28, 10, 0, 0),
      );
      final payload = CloudFeedbackPayload.fromFeedback(
        record: record,
        plan: plan,
        clientVersion: 'v0.7.0',
        userAgent: 'TestUA',
      );
      final json = payload.toJson();

      // 必填字段
      expect(json['sessionId'], plan.sessionId);
      expect(json['listeningSessionId'], plan.sessionId);
      expect(json['createdAt'], isNotNull);
      expect(json['emotionTags'], isA<List>());
      expect(json['source'], 'web');
      expect(json['schemaVersion'], 1);

      // 非 null 可选字段
      expect(json.containsKey('relaxationScore'), isTrue);
      expect(json.containsKey('calmnessScore'), isTrue);
      expect(json.containsKey('freeTextFeedback'), isTrue);
      expect(json.containsKey('experimentVariant'), isTrue);
    });

    test('null 字段不出现在 JSON 中', () async {
      final plan = await mockPipeline.run('test');
      final record = FeedbackRecord(
        sessionId: plan.sessionId,
        rating: 3,
        tensionBefore: 0.5,
        tensionAfter: 0.5,
        note: null,
        createdAt: DateTime.now(),
      );
      final payload = CloudFeedbackPayload.fromFeedback(
        record: record,
        plan: plan,
        clientVersion: 'v0.7.0',
      );
      final json = payload.toJson();

      // freeTextFeedback 为 null，不应出现在 JSON 中
      expect(json.containsKey('freeTextFeedback'), isFalse);
      // emotionMatchScore / willingToContinue 始终为 null
      expect(json.containsKey('emotionMatchScore'), isFalse);
      expect(json.containsKey('willingToContinue'), isFalse);
    });

    test('emotionTags 序列化为 List<String>', () async {
      final plan = await mockPipeline.run('焦虑紧绷');
      final record = FeedbackRecord(
        sessionId: plan.sessionId,
        rating: 3,
        tensionBefore: 0.5,
        tensionAfter: 0.5,
        createdAt: DateTime.now(),
      );
      final payload = CloudFeedbackPayload.fromFeedback(
        record: record,
        plan: plan,
        clientVersion: 'v0.7.0',
      );
      final json = payload.toJson();

      expect(json['emotionTags'], isA<List>());
      expect((json['emotionTags'] as List).every((e) => e is String), isTrue);
    });
  });
}
