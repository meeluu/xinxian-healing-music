import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/models/comfort_lyrics_result.dart';

/// 困惑解惑 + 歌词生成结果数据模型测试（P4 新方向第一批）。
///
/// 验证：
/// - fromJson 正确解析所有字段
/// - 缺失字段时使用默认值（不抛异常）
/// - isFallback 标记正确
/// - 医疗化/玄学化词汇检测（约束：禁用「治疗/治愈/命中注定」等表达）
void main() {
  group('ComfortLyricsResult.fromJson', () {
    test('正确解析完整 LLM 响应', () {
      final json = {
        'ok': true,
        'source': 'llm',
        'comfortInterpretation': '听起来你最近压力很大。\n\n也许你不需要立刻找到答案。',
        'lyricDraft': '【主歌】\n你站在夜色里没说话\n\n【副歌】\n也许明天先把杯子洗干净',
        'songPrompt': 'gentle pop, acoustic guitar, slow tempo, warm mood',
        'safetyNotes': '未检测到风险线索',
      };

      final r = ComfortLyricsResult.fromJson(json);

      expect(r.source, 'llm');
      expect(r.isFallback, isFalse);
      expect(r.comfortInterpretation, contains('听起来你最近压力很大'));
      expect(r.lyricDraft, contains('【主歌】'));
      expect(r.lyricDraft, contains('【副歌】'));
      expect(r.songPrompt, contains('gentle pop'));
      expect(r.safetyNotes, '未检测到风险线索');
    });

    test('正确解析 fallback 响应（ok:false, source:fallback）', () {
      final json = {
        'ok': false,
        'source': 'fallback',
        'reason': 'llm_disabled',
        'comfortInterpretation': '听起来你最近承受了一些不容易的事。',
        'lyricDraft': '【主歌】\n你站在夜色里没说话',
        'songPrompt': 'gentle pop, acoustic guitar, slow tempo',
        'safetyNotes': 'fallback_mode',
      };

      final r = ComfortLyricsResult.fromJson(json);

      expect(r.source, 'fallback');
      expect(r.isFallback, isTrue);
      expect(r.comfortInterpretation, isNotEmpty);
      expect(r.lyricDraft, isNotEmpty);
    });

    test('缺失字段时不抛异常，使用默认空值', () {
      final json = <String, dynamic>{'ok': false};

      final r = ComfortLyricsResult.fromJson(json);

      expect(r.comfortInterpretation, '');
      expect(r.lyricDraft, '');
      expect(r.songPrompt, '');
      expect(r.safetyNotes, '');
      // source 缺失时默认 fallback
      expect(r.source, 'fallback');
      expect(r.isFallback, isTrue);
    });

    test('source 为非 llm 时 isFallback 返回 true', () {
      for (final s in ['fallback', 'mock', 'error', '']) {
        final r = ComfortLyricsResult.fromJson({
          'source': s,
          'comfortInterpretation': 'x',
          'lyricDraft': 'y',
        });
        expect(r.isFallback, isTrue, reason: 'source="$s" 应视为 fallback');
      }
    });

    test('source=llm 时 isFallback 返回 false', () {
      final r = ComfortLyricsResult.fromJson({
        'source': 'llm',
        'comfortInterpretation': 'x',
        'lyricDraft': 'y',
      });
      expect(r.isFallback, isFalse);
    });

    test('P4 第二批：正确解析 scene 字段', () {
      final scenes = [
        'academic_failure',
        'relationship_conflict',
        'work_pressure',
        'guilt_regret',
        'default',
      ];
      for (final scene in scenes) {
        final r = ComfortLyricsResult.fromJson({
          'source': 'llm',
          'comfortInterpretation': 'x',
          'lyricDraft': 'y',
          'scene': scene,
        });
        expect(r.scene, scene, reason: 'scene 应正确解析: $scene');
      }
    });

    test('P4 第二批：scene 缺失时默认 default', () {
      final r = ComfortLyricsResult.fromJson({
        'source': 'llm',
        'comfortInterpretation': 'x',
        'lyricDraft': 'y',
      });
      expect(r.scene, 'default');
    });

    test('P4 第二批：构造函数 scene 默认 default', () {
      final r = ComfortLyricsResult(
        comfortInterpretation: 'x',
        lyricDraft: 'y',
        songPrompt: 'p',
        safetyNotes: 's',
        source: 'llm',
      );
      expect(r.scene, 'default');
    });
  });

  group('文案规范 - 医疗化 / 玄学化词汇检测', () {
    /// 验证：约束规定禁用「治疗/治愈/治疗焦虑/治疗失眠/命中注定/神谕/加油/你是最棒」等表达。
    /// 这里收集一组"理想 LLM 输出"和"违规 LLM 输出"对照，
    /// 提醒后端 sanitizeText 应过滤违规词汇（实际过滤逻辑在 functions/api/comfort-lyrics.js）。
    final bannedMedicalPatterns = [
      '治疗焦虑',
      '治疗失眠',
      '治好你的焦虑',
      '治愈你的',
      '疗法',
      '疗效',
    ];
    final bannedMysticPatterns = ['命中注定', '天意', '神的安排', '算准', '神谕', '命运注定'];
    final bannedEmptyTalkPatterns = ['一切都会好的', '加油哦', '你是最棒的', '会好起来的'];

    /// 理想的 fallback / 本地模板文本（必须不含任何禁用词汇）。
    final idealFallbackComfort =
        '听起来你最近承受了一些不容易的事，谢谢你愿意把它说出来。'
        '也许现在的你不需要立刻找到答案，也不需要把所有事都理清楚。先允许自己停一下，就停在这里。'
        '可以试着给自己倒一杯水，或者把窗户打开透透气。很小的一步，就够了。';

    final idealFallbackLyric =
        '【主歌】\n你站在夜色里没说话\n风把心事吹得有些远\n想哭也没关系，我在听\n\n'
        '【副歌】\n也许明天先把杯子洗干净\n也许今晚试着把手机放远一点\n不用急着好起来\n这首歌想陪你看见自己\n\n'
        '【尾声】\n天快亮了，你不用一个人。';

    test('fallback 解惑文本不含医疗化词汇', () {
      for (final p in bannedMedicalPatterns) {
        expect(
          idealFallbackComfort.contains(p),
          isFalse,
          reason: 'fallback 文案不应包含医疗化词汇: $p',
        );
      }
    });

    test('fallback 解惑文本不含玄学化词汇', () {
      for (final p in bannedMysticPatterns) {
        expect(
          idealFallbackComfort.contains(p),
          isFalse,
          reason: 'fallback 文案不应包含玄学化词汇: $p',
        );
      }
    });

    test('fallback 解惑文本不含空话词汇', () {
      for (final p in bannedEmptyTalkPatterns) {
        expect(
          idealFallbackComfort.contains(p),
          isFalse,
          reason: 'fallback 文案不应包含空话词汇: $p',
        );
      }
    });

    test('fallback 歌词草稿不含任何禁用词汇', () {
      for (final p in [
        ...bannedMedicalPatterns,
        ...bannedMysticPatterns,
        ...bannedEmptyTalkPatterns,
      ]) {
        expect(
          idealFallbackLyric.contains(p),
          isFalse,
          reason: 'fallback 歌词不应包含禁用词汇: $p',
        );
      }
    });

    test('禁用词汇清单本身非空（防止误删检测项）', () {
      expect(bannedMedicalPatterns, isNotEmpty);
      expect(bannedMysticPatterns, isNotEmpty);
      expect(bannedEmptyTalkPatterns, isNotEmpty);
    });
  });

  group('歌词结构字段检查', () {
    /// 验证：歌词草稿应含「主歌」「副歌」「尾声」结构标记。
    /// 这些是后端 SYSTEM_PROMPT 强制要求的结构。
    final sampleLyric =
        '【主歌】\n你站在夜色里没说话\n风把心事吹得有些远\n想哭也没关系，我在听\n\n'
        '【副歌】\n也许明天先把杯子洗干净\n也许今晚试着把手机放远一点\n不用急着好起来\n这首歌想陪你看见自己\n\n'
        '【尾声】\n天快亮了，你不用一个人。';

    test('歌词草稿包含主歌标记', () {
      expect(sampleLyric.contains('【主歌】'), isTrue);
    });

    test('歌词草稿包含副歌标记', () {
      expect(sampleLyric.contains('【副歌】'), isTrue);
    });

    test('歌词草稿包含尾声标记', () {
      expect(sampleLyric.contains('【尾声】'), isTrue);
    });

    test('ComfortLyricsResult 可承载带结构的歌词草稿', () {
      final r = ComfortLyricsResult(
        comfortInterpretation: '听起来你最近不容易。',
        lyricDraft: sampleLyric,
        songPrompt: 'gentle pop',
        safetyNotes: '未检测到风险线索',
        source: 'llm',
      );
      expect(r.lyricDraft, contains('【主歌】'));
      expect(r.lyricDraft, contains('【副歌】'));
      expect(r.lyricDraft, contains('【尾声】'));
    });
  });
}
