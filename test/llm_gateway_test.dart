import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinxian_healing_music/main.dart' show bootstrapServices;
import 'package:xinxian_healing_music/models/mood_input.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/pipeline/healing_pipeline.dart';
import 'package:xinxian_healing_music/pipeline/llm/llm_consent_service.dart';
import 'package:xinxian_healing_music/pipeline/llm/mood_analyzer_gateway.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_mood_analyzer.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_pipeline_factory.dart';
import 'package:xinxian_healing_music/pipeline/ports/mood_analyzer_port.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MoodAnalyzerGateway', () {
    test('未同意（unknown）时 source=mock，走 MockMoodAnalyzer', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      // status 默认 unknown
      expect(consent.status, LlmConsentStatus.unknown);

      final gateway = MoodAnalyzerGateway(
        llmAnalyzer: _FakeLlmAnalyzer(profile: _fakeLlmProfile),
        mockAnalyzer: const MockMoodAnalyzer(),
        consentService: consent,
      );

      final profile = await gateway.analyze(_input('今天天气不错'));
      expect(gateway.currentSource, 'mock');
      expect(gateway.lastSource, 'mock');
      // MockMoodAnalyzer 对"今天天气不错"返回平衡调和型
      expect(profile.valence, 0.2);
      expect(profile.arousal, 0.4);
    });

    test('拒绝（declined）后 source=mock', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      await consent.setStatus(LlmConsentStatus.declined);

      final gateway = MoodAnalyzerGateway(
        llmAnalyzer: _FakeLlmAnalyzer(profile: _fakeLlmProfile),
        mockAnalyzer: const MockMoodAnalyzer(),
        consentService: consent,
      );

      await gateway.analyze(_input('今天天气不错'));
      expect(gateway.currentSource, 'mock');
    });

    test('同意（accepted）后 LLM 成功 source=llm', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      await consent.setStatus(LlmConsentStatus.accepted);

      final gateway = MoodAnalyzerGateway(
        llmAnalyzer: _FakeLlmAnalyzer(profile: _fakeLlmProfile),
        mockAnalyzer: const MockMoodAnalyzer(),
        consentService: consent,
      );

      final profile = await gateway.analyze(_input('备考压力大'));
      expect(gateway.currentSource, 'llm');
      expect(gateway.lastSource, 'llm');
      // 返回的应是 fake LLM 的 profile，不是 MockMoodAnalyzer 的
      expect(profile.tags, _fakeLlmProfile.tags);
      expect(profile.valence, _fakeLlmProfile.valence);
    });

    test('同意后 LLM 失败 → fallback 到 mock，source=fallback', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      await consent.setStatus(LlmConsentStatus.accepted);

      final gateway = MoodAnalyzerGateway(
        llmAnalyzer: _FakeLlmAnalyzer(throwsException: true),
        mockAnalyzer: const MockMoodAnalyzer(),
        consentService: consent,
      );

      final profile = await gateway.analyze(_input('备考压力大'));
      expect(gateway.currentSource, 'fallback');
      expect(gateway.lastSource, 'fallback');
      // 应返回 MockMoodAnalyzer 的结果（含"焦虑"标签），不是 fake LLM 的
      expect(profile.tags, contains('焦虑'));
    });

    test('同意状态切换后 gateway 立即生效', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      // 初始 unknown → mock
      var gateway = MoodAnalyzerGateway(
        llmAnalyzer: _FakeLlmAnalyzer(profile: _fakeLlmProfile),
        mockAnalyzer: const MockMoodAnalyzer(),
        consentService: consent,
      );
      await gateway.analyze(_input('test'));
      expect(gateway.currentSource, 'mock');

      // 切换到 accepted → llm
      await consent.setStatus(LlmConsentStatus.accepted);
      await gateway.analyze(_input('test'));
      expect(gateway.currentSource, 'llm');

      // 切换回 declined → mock
      await consent.setStatus(LlmConsentStatus.declined);
      await gateway.analyze(_input('test'));
      expect(gateway.currentSource, 'mock');
    });
  });

  group('LlmConsentService', () {
    test('默认状态为 unknown', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      expect(consent.status, LlmConsentStatus.unknown);
      expect(consent.isAccepted, isFalse);
      expect(consent.needsPrompt, isTrue);
    });

    test('切换到 accepted 后持久化 + 重启保留', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent1 = await LlmConsentService.create(prefs);
      await consent1.setStatus(LlmConsentStatus.accepted);
      expect(prefs.getString(LlmConsentService.key), 'accepted');
      expect(consent1.isAccepted, isTrue);
      expect(consent1.needsPrompt, isFalse);

      // 模拟重启
      final consent2 = await LlmConsentService.create(prefs);
      expect(consent2.status, LlmConsentStatus.accepted);
      expect(consent2.isAccepted, isTrue);
    });

    test('切换到 declined 后持久化 + 重启保留', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent1 = await LlmConsentService.create(prefs);
      await consent1.setStatus(LlmConsentStatus.declined);
      expect(prefs.getString(LlmConsentService.key), 'declined');

      final consent2 = await LlmConsentService.create(prefs);
      expect(consent2.status, LlmConsentStatus.declined);
      expect(consent2.isAccepted, isFalse);
    });

    test('损坏的存储值回退 unknown', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LlmConsentService.key, 'garbage_value');
      final consent = await LlmConsentService.create(prefs);
      expect(consent.status, LlmConsentStatus.unknown);
      expect(consent.needsPrompt, isTrue);
    });
  });

  group('Pipeline analyzerSource 传递', () {
    test('mockPipeline 仍返回 analyzerSource=mock（向后兼容）', () async {
      final plan = await mockPipeline.run('备考压力');
      expect(plan.analyzerSource, 'mock');
    });

    test('buildPipelineWith(gateway) 正确传递 llm source', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      await consent.setStatus(LlmConsentStatus.accepted);

      final gateway = MoodAnalyzerGateway(
        llmAnalyzer: _FakeLlmAnalyzer(profile: _fakeLlmProfile),
        mockAnalyzer: const MockMoodAnalyzer(),
        consentService: consent,
      );
      final pipeline = buildPipelineWith(gateway);

      final plan = await pipeline.run('备考压力大');
      expect(plan.analyzerSource, 'llm');
      expect(plan.mood.tags, _fakeLlmProfile.tags);
    });

    test('buildPipelineWith(gateway) LLM 失败时传递 fallback source', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      await consent.setStatus(LlmConsentStatus.accepted);

      final gateway = MoodAnalyzerGateway(
        llmAnalyzer: _FakeLlmAnalyzer(throwsException: true),
        mockAnalyzer: const MockMoodAnalyzer(),
        consentService: consent,
      );
      final pipeline = buildPipelineWith(gateway);

      final plan = await pipeline.run('备考压力大');
      expect(plan.analyzerSource, 'fallback');
      // mood 应来自 MockMoodAnalyzer
      expect(plan.mood.tags, contains('焦虑'));
    });

    test('buildPipelineWith(gateway) 未同意时传递 mock source', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      // status = unknown

      final gateway = MoodAnalyzerGateway(
        llmAnalyzer: _FakeLlmAnalyzer(profile: _fakeLlmProfile),
        mockAnalyzer: const MockMoodAnalyzer(),
        consentService: consent,
      );
      final pipeline = buildPipelineWith(gateway);

      final plan = await pipeline.run('备考压力大');
      expect(plan.analyzerSource, 'mock');
    });

    test('analyzerSource 持久化到 plan.toJson 并可从 fromJson 恢复', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      await consent.setStatus(LlmConsentStatus.accepted);

      final gateway = MoodAnalyzerGateway(
        llmAnalyzer: _FakeLlmAnalyzer(profile: _fakeLlmProfile),
        mockAnalyzer: const MockMoodAnalyzer(),
        consentService: consent,
      );
      final pipeline = buildPipelineWith(gateway);

      final plan = await pipeline.run('备考压力大');
      final json = plan.toJson();
      expect(json['analyzerSource'], 'llm');

      // 模拟从持久化恢复
      final restored = HealingMusicPlan.fromJson(json);
      expect(restored.analyzerSource, 'llm');
    });
  });

  group('consent 双向切换（解析设置弹窗）', () {
    // 这组测试验证：无论当前状态是 declined 还是 accepted，
    // 用户都能通过"解析设置"弹窗切换到另一个状态。
    // HomeScreen._showConsentDialog 不检查当前状态，直接弹窗让用户选择，
    // 所以这里只验证 LlmConsentService.setStatus 的双向切换语义。

    test('declined 状态下仍可切换到 accepted', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      await consent.setStatus(LlmConsentStatus.declined);
      expect(consent.status, LlmConsentStatus.declined);
      expect(consent.isAccepted, isFalse);

      // 模拟用户在"解析设置"弹窗中点"同意 AI 解析"
      await consent.setStatus(LlmConsentStatus.accepted);
      expect(consent.status, LlmConsentStatus.accepted);
      expect(consent.isAccepted, isTrue);

      // 重启后仍是 accepted
      final consent2 = await LlmConsentService.create(prefs);
      expect(consent2.status, LlmConsentStatus.accepted);
      expect(consent2.isAccepted, isTrue);
    });

    test('accepted 状态下仍可切换到 declined', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      await consent.setStatus(LlmConsentStatus.accepted);
      expect(consent.isAccepted, isTrue);

      // 模拟用户在"解析设置"弹窗中点"仅使用本地解析"
      await consent.setStatus(LlmConsentStatus.declined);
      expect(consent.status, LlmConsentStatus.declined);
      expect(consent.isAccepted, isFalse);

      // 重启后仍是 declined
      final consent2 = await LlmConsentService.create(prefs);
      expect(consent2.status, LlmConsentStatus.declined);
      expect(consent2.isAccepted, isFalse);
    });

    test('unknown → accepted → declined → accepted 多次切换均持久化', () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await LlmConsentService.create(prefs);
      expect(consent.status, LlmConsentStatus.unknown);

      await consent.setStatus(LlmConsentStatus.accepted);
      expect(
        (await LlmConsentService.create(prefs)).status,
        LlmConsentStatus.accepted,
      );

      await consent.setStatus(LlmConsentStatus.declined);
      expect(
        (await LlmConsentService.create(prefs)).status,
        LlmConsentStatus.declined,
      );

      await consent.setStatus(LlmConsentStatus.accepted);
      expect(
        (await LlmConsentService.create(prefs)).status,
        LlmConsentStatus.accepted,
      );
    });
  });

  group('bootstrapServices 装配（main.dart 初始化）', () {
    // 保存默认全局变量，测试后恢复，避免污染其他测试。
    // 用普通可空变量（非 late final），否则多次 setUp 会报 LateInitializationError。
    HealingPipeline? defaultPipeline;
    dynamic defaultRecorder;
    dynamic defaultFeedback;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      defaultPipeline = activePipeline;
      defaultRecorder = sessionRecorder;
      defaultFeedback = feedbackRepository;
    });

    tearDown(() {
      // 恢复默认 mock 实现
      activePipeline = defaultPipeline ?? mockPipeline;
      sessionRecorder = defaultRecorder;
      feedbackRepository = defaultFeedback;
      llmConsentService = null;
      moodAnalyzerGateway = null;
    });

    test('bootstrapServices 后 activePipeline 不是纯 mockPipeline', () async {
      await bootstrapServices();

      // activePipeline 应被替换为带 gateway 的新实例，不再是默认 mockPipeline
      expect(identical(activePipeline, mockPipeline), isFalse);
      expect(moodAnalyzerGateway, isNotNull);
      expect(llmConsentService, isNotNull);
    });

    test('bootstrapServices 后 llmConsentService 状态为 unknown（首次）', () async {
      await bootstrapServices();
      expect(llmConsentService, isNotNull);
      expect(llmConsentService!.status, LlmConsentStatus.unknown);
      expect(llmConsentService!.needsPrompt, isTrue);
    });

    test('bootstrapServices 后 consent 持久化能读回', () async {
      // 第一次启动：用户同意
      await bootstrapServices();
      await llmConsentService!.setStatus(LlmConsentStatus.accepted);

      // 模拟刷新页面：重新 bootstrapServices
      // 先重置全局变量（模拟页面刷新后的初始状态）
      llmConsentService = null;
      moodAnalyzerGateway = null;
      activePipeline = mockPipeline;
      await bootstrapServices();

      // consent 状态应从 shared_preferences 读回
      expect(llmConsentService, isNotNull);
      expect(llmConsentService!.status, LlmConsentStatus.accepted);
      expect(llmConsentService!.isAccepted, isTrue);
    });

    test(
      'bootstrapServices 后 gateway 与 activePipeline 共享同一 consentService',
      () async {
        await bootstrapServices();
        expect(moodAnalyzerGateway, isNotNull);
        expect(
          identical(moodAnalyzerGateway!.consentService, llmConsentService),
          isTrue,
        );
      },
    );
  });
}

// ─── 测试辅助 ──────────────────────────────────────────────────

MoodInput _input(String text) => MoodInput(
  sessionId: 'test-${DateTime.now().microsecondsSinceEpoch}',
  text: text,
  timestamp: DateTime.now(),
);

/// 可控的 fake LLM profile，与 MockMoodAnalyzer 输出明显不同。
final MoodProfile _fakeLlmProfile = MoodProfile(
  tags: ['LLM测试标签'],
  valence: -0.9,
  arousal: 0.95,
  intensity: 0.88,
  summary: 'LLM 测试摘要',
  targetState: TargetState.regulate,
  dominantNeed: 'LLM 测试需求',
);

/// 可控的 fake LLM analyzer：可指定返回的 profile 或让它抛异常。
class _FakeLlmAnalyzer implements MoodAnalyzerPort {
  final MoodProfile? profile;
  final bool throwsException;

  _FakeLlmAnalyzer({this.profile, this.throwsException = false});

  @override
  String get currentSource => 'llm';

  @override
  Future<MoodProfile> analyze(MoodInput input) async {
    if (throwsException) throw Exception('fake_llm_error');
    return profile!;
  }
}
