import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/data/audio_asset_catalog.dart';
import 'package:xinxian_healing_music/models/generated_audio.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/models/processed_audio.dart';
import 'package:xinxian_healing_music/pipeline/mock/mock_pipeline_factory.dart';
import 'package:xinxian_healing_music/pipeline/mock/stock_audio_generator.dart';
import 'package:xinxian_healing_music/pipeline/ports/audio_generation_port.dart';

/// M6 AudioAssetCatalog 测试。
///
/// 覆盖：
/// 1. 5 类 targetState 精确匹配（sleep / regulate / soothe / focus / energize）
/// 2. brainwave 匹配
/// 3. noise / instruments 关键词打分
/// 4. fallback 默认音频
/// 5. findById / assets 完整性
/// 6. StockAudioGenerator 集成（5 类 targetState 各生成对应音频）
/// 7. 向后兼容（旧 GeneratedAudio / ProcessedAudio fromJson 缺 title 不崩溃）
void main() {
  group('AudioAssetCatalog - 5 类 targetState 精确匹配', () {
    test('sleep → sleep_01.mp3', () {
      final asset = AudioAssetCatalog.match(
        targetState: TargetState.sleep,
        brainwave: 'Theta / Delta 入睡倾向',
        noiseTags: ['雨声', '粉红噪音'],
        instruments: ['低频 Pad', '手碟'],
      );
      expect(asset.id, 'sleep_01');
      expect(asset.assetPath, 'music/sleep_01.mp3');
      expect(asset.title, contains('Theta 入眠'));
      expect(asset.isFallback, isFalse);
    });

    test('regulate → regulate_01.mp3', () {
      final asset = AudioAssetCatalog.match(
        targetState: TargetState.regulate,
        brainwave: 'Alpha 放松倾向',
        noiseTags: ['粉红噪音', '轻白噪'],
        instruments: ['柔和钢琴', '弦乐'],
      );
      expect(asset.id, 'regulate_01');
      expect(asset.assetPath, 'music/regulate_01.mp3');
      expect(asset.title, contains('降频调节'));
      expect(asset.isFallback, isFalse);
    });

    test('soothe → soothe_01.mp3', () {
      final asset = AudioAssetCatalog.match(
        targetState: TargetState.soothe,
        brainwave: 'Alpha 情绪安抚',
        noiseTags: ['海浪', '风声'],
        instruments: ['竖琴', '大提琴'],
      );
      expect(asset.id, 'soothe_01');
      expect(asset.assetPath, 'music/soothe_01.mp3');
      expect(asset.title, contains('温柔安抚'));
      expect(asset.isFallback, isFalse);
    });

    test('focus → focus_01.mp3', () {
      final asset = AudioAssetCatalog.match(
        targetState: TargetState.focus,
        brainwave: 'Alpha / Low Beta 稳定专注',
        noiseTags: ['棕噪'],
        instruments: ['极简钢琴', 'Marimba'],
      );
      expect(asset.id, 'focus_01');
      expect(asset.assetPath, 'music/focus_01.mp3');
      expect(asset.title, contains('稳定聚焦'));
      expect(asset.isFallback, isFalse);
    });

    test('energize → energize_01.mp3', () {
      final asset = AudioAssetCatalog.match(
        targetState: TargetState.energize,
        brainwave: 'Alpha uplift',
        noiseTags: ['森林环境音'],
        instruments: ['木吉他', '长笛'],
      );
      expect(asset.id, 'energize_01');
      expect(asset.assetPath, 'music/energize_01.mp3');
      expect(asset.title, contains('温和充能'));
      expect(asset.isFallback, isFalse);
    });
  });

  group('brainwave 关键词匹配（targetState 未直接命中时）', () {
    test('brainwave=Theta 匹配到 sleep_01', () {
      // relax 在 catalog 中没有专属条目，会走 brainwave 匹配
      final asset = AudioAssetCatalog.match(
        targetState: TargetState.relax,
        brainwave: 'Theta / Delta 入睡倾向',
      );
      expect(asset.id, 'sleep_01');
    });

    test('brainwave=Low Beta 匹配到 focus_01', () {
      final asset = AudioAssetCatalog.match(
        targetState: TargetState.relax,
        brainwave: 'Low Beta 稳定专注',
      );
      expect(asset.id, 'focus_01');
    });
  });

  group('noise / instruments 关键词打分', () {
    test('雨声 + 手碟 打分命中 sleep_01', () {
      final asset = AudioAssetCatalog.match(
        targetState: TargetState.relax,
        brainwave: '', // 不走 brainwave 匹配
        noiseTags: ['雨声', '粉红噪音'],
        instruments: ['手碟', '低频 Pad'],
      );
      expect(asset.id, 'sleep_01');
    });

    test('海浪 + 竖琴 打分命中 soothe_01', () {
      final asset = AudioAssetCatalog.match(
        targetState: TargetState.relax,
        brainwave: '',
        noiseTags: ['海浪', '风声'],
        instruments: ['竖琴', '大提琴'],
      );
      expect(asset.id, 'soothe_01');
    });
  });

  group('fallback 默认音频', () {
    test('无任何匹配时返回 fallback', () {
      final asset = AudioAssetCatalog.match(
        targetState: TargetState.relax,
        brainwave: '',
        noiseTags: [],
        instruments: [],
      );
      expect(asset.isFallback, isTrue);
      expect(asset.assetPath, isNotEmpty);
    });

    test('fallback assetPath 非空', () {
      expect(AudioAssetCatalog.fallback.assetPath, isNotEmpty);
      expect(AudioAssetCatalog.fallback.title, isNotEmpty);
    });
  });

  group('findById / assets 完整性', () {
    test('findById 能找到 5 类专属 + fallback', () {
      expect(AudioAssetCatalog.findById('sleep_01'), isNotNull);
      expect(AudioAssetCatalog.findById('regulate_01'), isNotNull);
      expect(AudioAssetCatalog.findById('soothe_01'), isNotNull);
      expect(AudioAssetCatalog.findById('focus_01'), isNotNull);
      expect(AudioAssetCatalog.findById('energize_01'), isNotNull);
    });

    test('assets 包含 5 个非 fallback 条目', () {
      final nonFallback = AudioAssetCatalog.assets
          .where((a) => !a.isFallback)
          .toList();
      expect(nonFallback.length, 5);
    });

    test('每个专属条目 assetPath 都指向 music/ 目录', () {
      for (final asset in AudioAssetCatalog.assets) {
        expect(asset.assetPath, startsWith('music/'));
        expect(asset.assetPath, endsWith('.mp3'));
      }
    });

    test('每个专属条目 title 非空', () {
      for (final asset in AudioAssetCatalog.assets) {
        expect(asset.title, isNotEmpty);
      }
    });

    test('catalog 不使用 music_01.mp3', () {
      for (final asset in AudioAssetCatalog.assets) {
        expect(
          asset.assetPath,
          isNot('music/music_01.mp3'),
          reason: '${asset.id} 不应使用 music_01.mp3',
        );
      }
    });
  });

  group('StockAudioGenerator 集成（5 类 targetState 各生成对应音频）', () {
    final generator = const StockAudioGenerator();

    test('sleep targetState 生成 sleep_01.mp3 音频', () async {
      final plan = await mockPipeline.run('失眠睡不着');
      // plan.features.targetRegulationState 应为 sleep
      expect(plan.features.targetRegulationState, TargetState.sleep);
      // plan.audio.assetPath 应为 sleep_01.mp3
      expect(plan.audio.assetPath, 'music/sleep_01.mp3');
      expect(plan.audio.title, contains('Theta 入眠'));
    });

    test('regulate targetState 生成 regulate_01.mp3 音频', () async {
      final plan = await mockPipeline.run('焦虑压力大');
      expect(plan.features.targetRegulationState, TargetState.regulate);
      expect(plan.audio.assetPath, 'music/regulate_01.mp3');
      expect(plan.audio.title, contains('降频调节'));
    });

    test('soothe targetState 生成 soothe_01.mp3 音频', () async {
      final plan = await mockPipeline.run('低落难过想哭');
      expect(plan.features.targetRegulationState, TargetState.soothe);
      expect(plan.audio.assetPath, 'music/soothe_01.mp3');
      expect(plan.audio.title, contains('温柔安抚'));
    });

    test('focus targetState 生成 focus_01.mp3 音频', () async {
      // 注：MockMoodAnalyzer 暂未覆盖"专注/分心"关键词，
      // mockPipeline.run 无法直接产生 focus targetState（这是 M5 mock 数据债务）。
      // 这里直接调用 generator.generate 验证 StockAudioGenerator 对 focus 的匹配，
      // 与下方"generate 返回的 GeneratedAudio assetPath 非空"用例同模式。
      final audio = await generator.generate(
        _fakeFeatures(TargetState.focus),
        const AudioGenerationOptions(),
      );
      expect(audio.assetPath, 'music/focus_01.mp3');
      expect(audio.title, contains('稳定聚焦'));
    });

    test('energize targetState 生成 energize_01.mp3 音频', () async {
      final plan = await mockPipeline.run('疲惫空虚');
      expect(plan.features.targetRegulationState, TargetState.energize);
      expect(plan.audio.assetPath, 'music/energize_01.mp3');
      expect(plan.audio.title, contains('温和充能'));
    });

    test('generate 返回的 GeneratedAudio assetPath 非空', () async {
      // 直接调用 generate，传入 sleep 的 features
      final audio = await generator.generate(
        _fakeFeatures(TargetState.sleep),
        const AudioGenerationOptions(),
      );
      expect(audio.assetPath, isNotEmpty);
      expect(audio.title, isNotEmpty);
      expect(audio.assetPath, 'music/sleep_01.mp3');
    });
  });

  group('向后兼容（旧历史记录缺新字段不崩溃）', () {
    test('GeneratedAudio.fromJson 缺 title / durationSeconds 不崩溃', () {
      final audio = GeneratedAudio.fromJson({
        'assetPath': 'music/music_01.mp3',
        'sourceType': 'stock',
        // 缺 title / durationSeconds / generationParams / modelId
      });
      expect(audio.assetPath, 'music/music_01.mp3');
      expect(audio.title, '');
      expect(audio.durationSeconds, 0);
    });

    test('ProcessedAudio.fromJson 缺 title / durationSeconds 不崩溃', () {
      final audio = ProcessedAudio.fromJson({
        'assetPath': 'music/music_01.mp3',
        'sourceType': 'stock',
        'processingChain': ['passthrough'],
        // 缺 title / durationSeconds
      });
      expect(audio.assetPath, 'music/music_01.mp3');
      expect(audio.title, '');
      expect(audio.durationSeconds, 0);
    });

    test('旧历史记录 assetPath=music_01.mp3 仍能正常构造', () {
      // 模拟 M5 之前的旧历史记录
      final audio = ProcessedAudio.fromJson({
        'assetPath': 'music/music_01.mp3',
        'sourceType': 'stock',
        'processingChain': ['passthrough'],
      });
      expect(audio.assetPath, 'music/music_01.mp3');
      expect(audio.title, ''); // 旧记录无 title，UI 不展示音频名
    });

    test('GeneratedAudio.toJson → fromJson 往返一致（含 M6 新字段）', () {
      final original = GeneratedAudio(
        assetPath: 'music/sleep_01.mp3',
        title: '夜色舒缓 · Theta 入眠',
        durationSeconds: 1800,
        generationParams: {'bpm': 48},
      );
      final json = original.toJson();
      final restored = GeneratedAudio.fromJson(json);
      expect(restored.assetPath, original.assetPath);
      expect(restored.title, original.title);
      expect(restored.durationSeconds, original.durationSeconds);
    });

    test('ProcessedAudio.toJson → fromJson 往返一致（含 M6 新字段）', () {
      final original = const ProcessedAudio(
        assetPath: 'music/soothe_01.mp3',
        title: '温柔安抚 · 情绪陪伴',
        durationSeconds: 1320,
        processingChain: ['passthrough'],
      );
      final json = original.toJson();
      final restored = ProcessedAudio.fromJson(json);
      expect(restored.assetPath, original.assetPath);
      expect(restored.title, original.title);
      expect(restored.durationSeconds, original.durationSeconds);
    });
  });

  group('文案不夸大医疗效果', () {
    test('所有 AudioAsset.description 不包含"治疗"字样', () {
      for (final asset in AudioAssetCatalog.assets) {
        expect(asset.description, isNot(contains('治疗')));
        expect(asset.description, isNot(contains('治愈')));
        expect(asset.title, isNot(contains('治疗')));
      }
    });

    test('fallback description 包含温和措辞', () {
      expect(
        AudioAssetCatalog.fallback.description,
        anyOf(
          contains('辅助放松'),
          contains('情绪调节'),
          contains('睡前舒缓'),
          contains('正念陪伴'),
        ),
      );
    });
  });
}

/// 构造一个最小 MusicFeatureTags 用于直接测试 StockAudioGenerator。
MusicFeatureTags _fakeFeatures(TargetState state) {
  switch (state) {
    case TargetState.sleep:
      return const MusicFeatureTags(
        bpm: 48,
        frequency: '432Hz',
        brainwave: 'Theta / Delta 入睡倾向',
        instruments: ['低频 Pad', '手碟'],
        harmony: '模糊大调',
        noiseLayer: '雨声 / 粉红噪音 / 低频环境音',
        durationMinutes: 30,
        targetRegulationState: TargetState.sleep,
      );
    case TargetState.regulate:
      return const MusicFeatureTags(
        bpm: 58,
        frequency: '432Hz',
        brainwave: 'Alpha 放松倾向',
        instruments: ['柔和钢琴', '弦乐'],
        harmony: '小调 → 缓和过渡',
        noiseLayer: '粉红噪音 / 轻白噪',
        durationMinutes: 20,
        targetRegulationState: TargetState.regulate,
      );
    case TargetState.soothe:
      return const MusicFeatureTags(
        bpm: 56,
        frequency: '432Hz',
        brainwave: 'Alpha 情绪安抚',
        instruments: ['竖琴', '大提琴'],
        harmony: '小调转大调',
        noiseLayer: '海浪 / 风声 / 粉红噪音',
        durationMinutes: 22,
        targetRegulationState: TargetState.soothe,
      );
    case TargetState.focus:
      return const MusicFeatureTags(
        bpm: 75,
        frequency: '432Hz',
        brainwave: 'Alpha / Low Beta 稳定专注',
        instruments: ['极简钢琴', 'Marimba'],
        harmony: '中性大调',
        noiseLayer: '棕噪 / 轻环境音',
        durationMinutes: 25,
        targetRegulationState: TargetState.focus,
      );
    case TargetState.energize:
      return const MusicFeatureTags(
        bpm: 82,
        frequency: '432Hz',
        brainwave: 'Alpha uplift',
        instruments: ['木吉他', '长笛'],
        harmony: '温暖大调',
        noiseLayer: '森林环境音 / 轻自然音',
        durationMinutes: 18,
        targetRegulationState: TargetState.energize,
      );
    case TargetState.relax:
    case TargetState.company:
      return _fakeFeatures(TargetState.regulate);
  }
}
