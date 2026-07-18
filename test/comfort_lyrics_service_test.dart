import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/models/comfort_lyrics_result.dart';
import 'package:xinxian_healing_music/pipeline/llm/comfort_lyrics_service.dart';

/// ComfortLyricsService 测试（P4 新方向第一批）。
///
/// 验证：
/// - 网络失败时返回 fallback（不抛异常）
/// - fallback 文案符合规范（含歌词结构、不含医疗化词汇）
/// - 不同 targetStyle 返回不同 songPrompt
/// - 不依赖真实后端（测试环境无网络，必然走 fallback）
void main() {
  const service = ComfortLyricsService();

  group('ComfortLyricsService.generate - 网络失败 fallback', () {
    test('网络不可达时返回 fallback，不抛异常', () async {
      // 测试环境无真实后端，http.post 会失败
      final result = await service.generate(
        storyText: '最近工作压力很大，睡不着',
        targetStyle: 'gentle_pop',
      );

      expect(result, isA<ComfortLyricsResult>());
      expect(result.source, 'fallback');
      expect(result.isFallback, isTrue);
    });

    test('fallback 解惑文本不为空且含中文', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'gentle_pop',
      );

      expect(result.comfortInterpretation, isNotEmpty);
      expect(result.comfortInterpretation.length, greaterThan(20));
      // 含中文
      expect(result.comfortInterpretation.runes.any((r) => r >= 0x4E00 && r <= 0x9FFF), isTrue);
    });

    test('fallback 歌词草稿含主歌/副歌/尾声结构', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'gentle_pop',
      );

      expect(result.lyricDraft, contains('【主歌】'));
      expect(result.lyricDraft, contains('【副歌】'));
      expect(result.lyricDraft, contains('【尾声】'));
    });

    test('fallback songPrompt 不为空', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'gentle_pop',
      );

      expect(result.songPrompt, isNotEmpty);
      // songPrompt 是英文风格描述
      expect(result.songPrompt.length, greaterThan(10));
    });

    test('fallback safetyNotes 不为空', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'gentle_pop',
      );

      expect(result.safetyNotes, isNotEmpty);
      expect(result.safetyNotes, contains('fallback'));
    });
  });

  group('ComfortLyricsService - targetStyle 切换', () {
    test('gentle_pop 返回对应的 songPrompt', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'gentle_pop',
      );

      expect(result.songPrompt, contains('gentle pop'));
      expect(result.songPrompt, contains('acoustic guitar'));
    });

    test('ambient_ballad 返回对应的 songPrompt', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'ambient_ballad',
      );

      expect(result.songPrompt, contains('ambient ballad'));
      expect(result.songPrompt, contains('soft pads'));
    });

    test('acoustic_warm 返回对应的 songPrompt', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'acoustic_warm',
      );

      expect(result.songPrompt, contains('warm acoustic'));
      expect(result.songPrompt, contains('fingerstyle guitar'));
    });

    test('soft_piano 返回对应的 songPrompt', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'soft_piano',
      );

      expect(result.songPrompt, contains('soft piano'));
      expect(result.songPrompt, contains('gentle melody'));
    });

    test('未知 targetStyle 回退到 gentle_pop', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'unknown_style',
      );

      // 未知风格回退到 gentle_pop
      expect(result.songPrompt, contains('gentle pop'));
    });
  });

  group('ComfortLyricsService - 文案规范', () {
    /// 验证 fallback 文案不含医疗化/玄学化/空话词汇。
    final bannedWords = [
      '治疗焦虑',
      '治疗失眠',
      '治好你的焦虑',
      '治愈你的',
      '疗法',
      '疗效',
      '命中注定',
      '天意',
      '神的安排',
      '神谕',
      '命运注定',
      '一切都会好的',
      '你是最棒的',
      '会好起来的',
    ];

    test('fallback 解惑文本不含任何禁用词汇', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'gentle_pop',
      );

      for (final w in bannedWords) {
        expect(
          result.comfortInterpretation.contains(w),
          isFalse,
          reason: 'fallback 解惑文本不应包含禁用词汇: $w',
        );
      }
    });

    test('fallback 歌词草稿不含任何禁用词汇', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'gentle_pop',
      );

      for (final w in bannedWords) {
        expect(
          result.lyricDraft.contains(w),
          isFalse,
          reason: 'fallback 歌词草稿不应包含禁用词汇: $w',
        );
      }
    });

    test('fallback songPrompt 不含医疗化英文词汇', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'gentle_pop',
      );

      // songPrompt 应为纯音乐风格描述，不含 heal/cure/treatment/therapy
      final lowerPrompt = result.songPrompt.toLowerCase();
      expect(lowerPrompt.contains('heal'), isFalse);
      expect(lowerPrompt.contains('cure'), isFalse);
      expect(lowerPrompt.contains('treatment'), isFalse);
      expect(lowerPrompt.contains('therapy'), isFalse);
    });
  });
}
