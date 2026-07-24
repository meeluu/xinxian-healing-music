import 'package:xinxian_healing_music/models/mood_profile.dart';
import 'package:xinxian_healing_music/models/music_profile.dart';

/// 单个本地音频资产的元信息（M6 新增，P5-music-metadata-foundation-1 扩展）。
///
/// 每个音频资产绑定一个或多个 [TargetState]，并标注脑波倾向、噪音层、
/// 推荐乐器等关键词，供 [AudioAssetCatalog.match] 做多级匹配。
///
/// UI 只展示 [title] / [description]，不暴露 [assetPath] 给普通用户。
///
/// P5-music-metadata-foundation-1：
/// - [durationSeconds] 填入真实测量的 mp3 文件时长（非占位）。
/// - [musicProfile] 新增 per-asset 声音特征元数据，供方案页展示与具体音频绑定的
///   时长 / 声音特征 / 建议聆听方式，替代之前写死的统一时长与算法派生参数。
///   当前 musicProfile 为初步推断，[MusicParameterStatus.preliminary]，后续逐首校准。
class AudioAsset {
  /// 唯一标识，例如 'sleep_01'
  final String id;

  /// 本地音频资源路径（assets key），例如 'music/sleep_01.mp3'
  final String assetPath;

  /// 展示名，例如 '夜色舒缓 · Theta 入眠'
  final String title;

  /// 适配的目标状态列表（可多选）
  final List<TargetState> targetStates;

  /// 脑波倾向关键词，例如 'Theta' / 'Alpha' / 'Low Beta'（用于二次匹配）
  final String? brainwaveTag;

  /// 噪音层关键词，例如 ['雨声', '粉红噪音']
  final List<String> noiseTags;

  /// 推荐乐器关键词，例如 ['低频 Pad', '手碟']
  final List<String> instruments;

  /// 音频时长（秒），0 表示未知。
  ///
  /// P5-music-metadata-foundation-1：5 首音频已填入真实测量的 mp3 文件时长
  /// （sleep_01=211 / regulate_01=243 / soothe_01=185 / focus_01=188 /
  /// energize_01=169），fallback=sleep_01.mp3 → 211。
  final int durationSeconds;

  /// 面向用户的简短描述（不夸大医疗效果）
  final String description;

  /// 是否为默认兜底音频（无任何匹配时使用）
  final bool isFallback;

  /// per-asset 声音特征元数据（P5-music-metadata-foundation-1）。
  ///
  /// 可空：旧资产或未校准资产可能没有。方案页展示时缺失则用温和兜底文案。
  final MusicProfile? musicProfile;

  const AudioAsset({
    required this.id,
    required this.assetPath,
    required this.title,
    required this.targetStates,
    this.brainwaveTag,
    this.noiseTags = const [],
    this.instruments = const [],
    this.durationSeconds = 0,
    this.description = '',
    this.isFallback = false,
    this.musicProfile,
  });
}

/// 本地音频资产目录（M6 新增）。
///
/// 按 [TargetState] / 脑波 / 噪音 / 乐器 多级匹配，让不同情绪画像播放不同音频。
///
/// 匹配优先级：
/// 1. targetState 精确匹配
/// 2. brainwave 关键词匹配
/// 3. noise / instruments 关键词重叠打分
/// 4. fallback 默认音频
///
/// 当前已接入 5 类 targetState 专属音频（sleep_01 / regulate_01 / soothe_01 /
/// focus_01 / energize_01），每类绑定一个真实 mp3 文件。
class AudioAssetCatalog {
  AudioAssetCatalog._();

  /// 默认兜底音频（不再使用 music_01.mp3，改为 sleep_01 作为最温和的兜底）
  static const AudioAsset fallback = AudioAsset(
    id: 'fallback',
    assetPath: 'music/sleep_01.mp3',
    title: '心弦疗愈音频',
    targetStates: [],
    brainwaveTag: 'Alpha',
    noiseTags: ['粉红噪音'],
    instruments: ['柔和钢琴'],
    // fallback 复用 sleep_01.mp3，故时长同 sleep_01（真实测量值）
    durationSeconds: 211,
    description: '一段温和的疗愈音频，用于辅助放松与情绪调节。',
    isFallback: true,
    musicProfile: MusicProfile(
      tempo: '慢速',
      texture: '柔和钢琴铺底',
      energyCurve: '低起伏',
      suitableScene: '放松陪伴',
      parameterStatus: MusicParameterStatus.preliminary,
    ),
  );

  /// 全部音频资产（5 类 targetState 专属 + 1 个兜底）
  static const List<AudioAsset> assets = [
    AudioAsset(
      id: 'sleep_01',
      assetPath: 'music/sleep_01.mp3',
      title: '夜色舒缓 · Theta 入眠',
      targetStates: [TargetState.sleep],
      brainwaveTag: 'Theta',
      noiseTags: ['雨声', '粉红噪音', '低频环境音'],
      instruments: ['低频 Pad', '手碟', '柔和钢琴'],
      durationSeconds: 211,
      description: '雨声与低频 Pad 配合，辅助睡前舒缓、降低唤醒度。',
      musicProfile: MusicProfile(
        tempo: '慢速',
        texture: '低频 Pad 与柔和钢琴铺底',
        energyCurve: '低起伏',
        suitableScene: '睡前舒缓',
        parameterStatus: MusicParameterStatus.preliminary,
      ),
    ),
    AudioAsset(
      id: 'regulate_01',
      assetPath: 'music/regulate_01.mp3',
      title: '降频调节 · Alpha 平复',
      targetStates: [TargetState.regulate],
      brainwaveTag: 'Alpha',
      noiseTags: ['粉红噪音', '轻白噪'],
      instruments: ['柔和钢琴', '弦乐', 'Pad'],
      durationSeconds: 243,
      description: '柔和钢琴与弦乐配合粉红噪音，缓解紧张、平复思绪。',
      musicProfile: MusicProfile(
        tempo: '中慢速',
        texture: '柔和钢琴与弦乐铺底',
        energyCurve: '平稳过渡',
        suitableScene: '情绪调节',
        parameterStatus: MusicParameterStatus.preliminary,
      ),
    ),
    AudioAsset(
      id: 'soothe_01',
      assetPath: 'music/soothe_01.mp3',
      title: '温柔安抚 · 情绪陪伴',
      targetStates: [TargetState.soothe],
      brainwaveTag: 'Alpha',
      noiseTags: ['海浪', '风声', '粉红噪音'],
      instruments: ['竖琴', '大提琴', '柔和钢琴'],
      durationSeconds: 185,
      description: '竖琴与大提琴配合海浪声，用于自我安抚、情绪陪伴。',
      musicProfile: MusicProfile(
        tempo: '慢速',
        texture: '竖琴与大提琴铺底',
        energyCurve: '低起伏',
        suitableScene: '安静放松、情绪陪伴',
        parameterStatus: MusicParameterStatus.preliminary,
      ),
    ),
    AudioAsset(
      id: 'focus_01',
      assetPath: 'music/focus_01.mp3',
      title: '稳定聚焦 · Low Beta 节奏',
      targetStates: [TargetState.focus],
      brainwaveTag: 'Low Beta',
      noiseTags: ['棕噪', '轻环境音'],
      instruments: ['极简钢琴', 'Marimba', '轻 Pad'],
      durationSeconds: 188,
      description: '极简钢琴与 Marimba 配合棕噪，恢复专注和稳定节奏。',
      musicProfile: MusicProfile(
        tempo: '稳定中速',
        texture: '极简钢琴与 Marimba',
        energyCurve: '低起伏、节奏稳定',
        suitableScene: '专注陪伴',
        parameterStatus: MusicParameterStatus.preliminary,
      ),
    ),
    AudioAsset(
      id: 'energize_01',
      assetPath: 'music/energize_01.mp3',
      title: '温和充能 · 自然回暖',
      targetStates: [TargetState.energize],
      brainwaveTag: 'Alpha uplift',
      noiseTags: ['森林环境音', '轻自然音'],
      instruments: ['木吉他', '长笛', '轻打击'],
      durationSeconds: 169,
      description: '木吉他与长笛配合森林环境音，温和恢复能量，不做强刺激。',
      musicProfile: MusicProfile(
        tempo: '轻快中速',
        texture: '木吉他与长笛',
        energyCurve: '温和上升',
        suitableScene: '温和充能',
        parameterStatus: MusicParameterStatus.preliminary,
      ),
    ),
  ];

  /// 按 targetState 精确匹配 → brainwave → noise/instruments 打分 → fallback
  static AudioAsset match({
    required TargetState targetState,
    String? brainwave,
    List<String>? noiseTags,
    List<String>? instruments,
  }) {
    // 第 1 步：targetState 精确匹配
    final stateMatches = assets
        .where((a) => a.targetStates.contains(targetState))
        .toList();
    if (stateMatches.isNotEmpty) {
      if (stateMatches.length == 1) {
        return stateMatches.first;
      }
      // 多个命中 → 按 brainwave 二次筛选
      if (brainwave != null && brainwave.isNotEmpty) {
        final brainwaveMatch = stateMatches
            .where((a) =>
                a.brainwaveTag != null &&
                brainwave.contains(a.brainwaveTag!))
            .toList();
        if (brainwaveMatch.isNotEmpty) {
          return brainwaveMatch.first;
        }
      }
      return stateMatches.first;
    }

    // 第 2 步：brainwave 关键词匹配（在所有非 fallback 条目中）
    if (brainwave != null && brainwave.isNotEmpty) {
      final brainwaveMatch = assets
          .where((a) =>
              a.brainwaveTag != null &&
              brainwave.contains(a.brainwaveTag!))
          .toList();
      if (brainwaveMatch.isNotEmpty) {
        return brainwaveMatch.first;
      }
    }

    // 第 3 步：noise / instruments 关键词重叠打分
    final inputTags = <String>{
      ...?noiseTags,
      ...?instruments,
    };
    if (inputTags.isNotEmpty) {
      AudioAsset? best;
      int bestScore = 0;
      for (final asset in assets) {
        final assetTags = <String>{
          ...asset.noiseTags,
          ...asset.instruments,
        };
        // 计算重叠词数（忽略大小写）
        int score = 0;
        for (final tag in inputTags) {
          for (final assetTag in assetTags) {
            if (tag.toLowerCase().contains(assetTag.toLowerCase()) ||
                assetTag.toLowerCase().contains(tag.toLowerCase())) {
              score++;
              break;
            }
          }
        }
        if (score > bestScore) {
          bestScore = score;
          best = asset;
        }
      }
      if (best != null && bestScore > 0) {
        return best;
      }
    }

    // 第 4 步：fallback
    return fallback;
  }

  /// 按 id 查找（供测试与调试用）
  static AudioAsset? findById(String id) {
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// 按 assetPath 查找（P5-music-metadata-foundation-1）。
  ///
  /// 方案页 / 播放页通过 `plan.audio.assetPath`（ProcessedAudio）反查对应的
  /// [AudioAsset]，从而读取该音频的 per-asset 元数据（时长 / musicProfile）。
  ///
  /// assets 列表中不包含 fallback，但 fallback 的 assetPath 与 sleep_01 相同，
  /// 因此 sleep_01.mp3 会被命中。其他未注册的 assetPath 返回 null，
  /// 由调用方用温和兜底文案处理。
  static AudioAsset? findByAssetPath(String assetPath) {
    if (assetPath.isEmpty) return null;
    for (final a in assets) {
      if (a.assetPath == assetPath) return a;
    }
    return null;
  }
}
