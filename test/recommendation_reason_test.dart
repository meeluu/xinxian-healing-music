import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/models/audio_post_process_config.dart';
import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_feature_tags.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/models/music_profile.dart';
import 'package:xinxian_healing_music/models/processed_audio.dart';
import 'package:xinxian_healing_music/utils/recommendation_reason.dart';

/// P5-music-metadata-foundation-1：per-asset 元数据展示 helper 测试。
///
/// 覆盖：
/// 1. formatAssetDuration：秒数 → 友好时长文案（含 0 / 负数兜底）
/// 2. buildSoundCharacteristics：MusicProfile → 声音特征串（含 null 兜底）
/// 3. buildListeningSuggestion：各 targetState 非空且不含医疗化表达
/// 4. buildPreliminaryNote：preliminary / calibrated / null
/// 5. AssetMetadataView.fromPlan：混合回退策略（per-asset → plan.audio → 待补充）
void main() {
  group('formatAssetDuration', () {
    test('0 或负数 → 时长待补充', () {
      expect(formatAssetDuration(0), '时长待补充');
      expect(formatAssetDuration(-5), '时长待补充');
    });

    test('211 秒 → 约 3 分 31 秒', () {
      expect(formatAssetDuration(211), '约 3 分 31 秒');
    });

    test('65 秒 → 约 1 分 5 秒', () {
      expect(formatAssetDuration(65), '约 1 分 5 秒');
    });

    test('120 秒 → 约 2 分（整分钟不带秒）', () {
      expect(formatAssetDuration(120), '约 2 分');
    });

    test('45 秒 → 约 45 秒（不足 1 分钟）', () {
      expect(formatAssetDuration(45), '约 45 秒');
    });
  });

  group('buildSoundCharacteristics', () {
    test('null profile → 参数待补充', () {
      expect(buildSoundCharacteristics(null), '参数待补充');
    });

    test('正常 profile → 含 texture / energyCurve / tempo 短语', () {
      const profile = MusicProfile(
        tempo: '慢速',
        texture: '低频 Pad 与柔和钢琴铺底',
        energyCurve: '低起伏',
        suitableScene: '睡前舒缓',
      );
      final result = buildSoundCharacteristics(profile);
      expect(result, contains('低频 Pad 与柔和钢琴铺底'));
      expect(result, contains('低起伏'));
      expect(result, contains('节奏较慢'));
      expect(result, isNot('参数待补充'));
    });

    test('tempo 映射为「节奏…」短语', () {
      const profile = MusicProfile(
        tempo: '稳定中速',
        texture: '极简钢琴',
        energyCurve: '低起伏、节奏稳定',
        suitableScene: '专注陪伴',
      );
      expect(buildSoundCharacteristics(profile), contains('节奏稳定'));
    });

    test('全空字段 → 参数待补充', () {
      const profile = MusicProfile(
        tempo: '',
        texture: '',
        energyCurve: '',
        suitableScene: '',
      );
      expect(buildSoundCharacteristics(profile), '参数待补充');
    });
  });

  group('buildListeningSuggestion', () {
    test('各 targetState 均返回非空文案', () {
      for (final ts in TargetState.values) {
        expect(
          buildListeningSuggestion(ts),
          isNotEmpty,
          reason: '${ts.name} 的建议文案不应为空',
        );
      }
    });

    test('sleep → 提到定时关闭 / 循环播放', () {
      final s = buildListeningSuggestion(TargetState.sleep);
      expect(s, anyOf(contains('定时关闭'), contains('循环播放')));
    });

    test('所有建议文案不含医疗化表达', () {
      const forbidden = ['治疗', '治愈', '疗效', '诊断', '疗法'];
      for (final ts in TargetState.values) {
        final s = buildListeningSuggestion(ts);
        for (final word in forbidden) {
          expect(
            s,
            isNot(contains(word)),
            reason: '${ts.name} 建议文案不应含 $word',
          );
        }
      }
    });
  });

  group('buildPreliminaryNote', () {
    test('preliminary → 初步版本注记', () {
      expect(
        buildPreliminaryNote(MusicParameterStatus.preliminary),
        '（初步版本，参数待校准）',
      );
    });

    test('calibrated → 空串', () {
      expect(buildPreliminaryNote(MusicParameterStatus.calibrated), '');
    });

    test('null → 空串', () {
      expect(buildPreliminaryNote(null), '');
    });
  });

  group('AssetMetadataView.fromPlan（混合回退策略）', () {
    test('已注册 assetPath → 使用 per-asset 时长与声音特征', () {
      final plan = _buildPlan(assetPath: 'music/sleep_01.mp3');
      final view = AssetMetadataView.fromPlan(plan);
      expect(view.hasAssetMetadata, isTrue);
      expect(view.hasSoundProfile, isTrue);
      // sleep_01.mp3 真实时长 211 秒 → 约 3 分 31 秒
      expect(view.durationLabel, '约 3 分 31 秒');
      expect(view.soundCharacteristics, isNot('参数待补充'));
      expect(view.preliminaryNote, isNotEmpty);
      expect(view.listeningSuggestion, isNotEmpty);
    });

    test('regulate_01 → 约 4 分 3 秒（243 秒）', () {
      final plan = _buildPlan(
        assetPath: 'music/regulate_01.mp3',
        targetState: TargetState.regulate,
      );
      expect(AssetMetadataView.fromPlan(plan).durationLabel, '约 4 分 3 秒');
    });

    test('未注册 assetPath + audio.durationSeconds>0 → 回退 plan.audio 时长', () {
      final plan = _buildPlan(
        assetPath: 'music/not_registered.mp3',
        audioDurationSeconds: 100,
      );
      final view = AssetMetadataView.fromPlan(plan);
      expect(view.hasAssetMetadata, isFalse);
      expect(view.hasSoundProfile, isFalse);
      expect(view.durationLabel, '约 1 分 40 秒');
      expect(view.soundCharacteristics, '参数待补充');
      expect(view.preliminaryNote, '');
    });

    test('未注册 assetPath + audio.durationSeconds=0 → 时长待补充', () {
      final plan = _buildPlan(
        assetPath: 'music/not_registered.mp3',
        audioDurationSeconds: 0,
      );
      final view = AssetMetadataView.fromPlan(plan);
      expect(view.durationLabel, '时长待补充');
    });

    test('空 assetPath → 不报错，时长待补充', () {
      final plan = _buildPlan(assetPath: '', audioDurationSeconds: 0);
      final view = AssetMetadataView.fromPlan(plan);
      expect(view.hasAssetMetadata, isFalse);
      expect(view.durationLabel, '时长待补充');
    });
  });
}

/// 构造一个最小可用的 [HealingMusicPlan] 用于测试 [AssetMetadataView.fromPlan]。
///
/// 仅填充 fromPlan 读取的字段（audio.assetPath / audio.durationSeconds /
/// mood.targetState），其余用默认值，避免测试被无关字段绑死。
HealingMusicPlan _buildPlan({
  required String assetPath,
  TargetState targetState = TargetState.sleep,
  int audioDurationSeconds = 0,
}) {
  return HealingMusicPlan(
    sessionId: 'test-session',
    templateName: 'test-template',
    mood: MoodProfile(
      tags: const ['test'],
      valence: 0.0,
      arousal: 0.4,
      summary: 'test summary',
      targetState: targetState,
    ),
    features: const MusicFeatureTags(
      bpm: 60,
      frequency: '432Hz',
      brainwave: 'Theta',
      instruments: ['低频 Pad'],
      harmony: '模糊大调',
      noiseLayer: '雨声',
      durationMinutes: 12,
    ),
    audio: ProcessedAudio(
      assetPath: assetPath,
      durationSeconds: audioDurationSeconds,
    ),
    postProcess: const AudioPostProcessConfig(),
    variant: ExperimentVariant.custom,
    durationMinutes: 12,
    guidance: 'test guidance',
  );
}
