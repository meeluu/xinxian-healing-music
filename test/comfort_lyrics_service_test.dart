import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/models/comfort_lyrics_result.dart';
import 'package:xinxian_healing_music/pipeline/llm/comfort_lyrics_service.dart';

/// ComfortLyricsService 测试（P4 新方向第一批 / 第二批 / fix1）。
///
/// P4 第二批更新：
/// - fallback 改为按场景识别（detectScene）选择模板，不再按 targetStyle
/// - 新增 5 场景 fallback 验证（学业/关系/工作/愧疚/默认）
/// - 新增说教类禁用词检测（你必须/你应该/这说明你/你需要治疗）
/// - 新增玄学类禁用词检测（命运安排/宇宙告诉你/上天告诉你/神明告诉你）
///
/// P4-conversation-song-flow-1-fix1 新增：
/// - fetchFollowUpQuestions 本地兜底分类测试（6 分类：lowEnergy/eventConflict/anxietyStress/guiltRegret/loneliness/unknown）
/// - 低能量输入（提不起劲/疲惫/很空）的兜底问题不包含「这件事」措辞
/// - eventConflict 允许事件导向措辞，anxietyStress/guiltRegret/loneliness 各有特征词
/// - 兜底问题不含医疗化词汇
///
/// 验证：
/// - 网络失败时返回 fallback（不抛异常）
/// - fallback 文案符合规范（含歌词结构、不含医疗化/玄学化/说教词汇）
/// - 5 场景识别正确，每个场景有独立模板
/// - songPrompt 为英文且含 vocal/tempo/instrumentation 要素
/// - fix1：fetchFollowUpQuestions 网络失败时返回本地 6 分类兜底问题
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
      expect(
        result.comfortInterpretation.runes.any(
          (r) => r >= 0x4E00 && r <= 0x9FFF,
        ),
        isTrue,
      );
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

    test('fallback songPrompt 不为空且为英文', () async {
      final result = await service.generate(
        storyText: '我最近心情很低落',
        targetStyle: 'gentle_pop',
      );

      expect(result.songPrompt, isNotEmpty);
      expect(result.songPrompt.length, greaterThan(10));
      // songPrompt 应为纯英文（不含中文字符）
      expect(
        RegExp(r'[\u4E00-\u9FFF]').hasMatch(result.songPrompt),
        isFalse,
        reason: 'songPrompt 应为纯英文风格描述',
      );
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

  group('ComfortLyricsService - 场景识别（P4 第二批）', () {
    /// P4 第二批：fallback 按 detectScene 选择模板，5 场景应有独立文案。
    test('学业场景（考研/挂科）返回 academic_failure 模板', () async {
      final result = await service.generate(
        storyText: '我考研没考上，感觉努力都白费了',
        targetStyle: 'gentle_pop',
      );

      // scene 字段应为 academic_failure
      expect(result.scene, 'academic_failure');
      // comfortInterpretation 应含学业场景特征词
      expect(
        result.comfortInterpretation.contains('考试') ||
            result.comfortInterpretation.contains('学业') ||
            result.comfortInterpretation.contains('卷子'),
        isTrue,
        reason: '学业场景模板应含学业相关意象',
      );
    });

    test('关系场景（吵架/分手）返回 relationship_conflict 模板', () async {
      final result = await service.generate(
        storyText: '和妈妈大吵一架，她已读不回我',
        targetStyle: 'gentle_pop',
      );

      expect(result.scene, 'relationship_conflict');
      // 关系场景特征词
      expect(
        result.comfortInterpretation.contains('关系') ||
            result.comfortInterpretation.contains('争吵') ||
            result.comfortInterpretation.contains('听懂'),
        isTrue,
        reason: '关系场景模板应含关系相关意象',
      );
    });

    test('工作场景（加班/压力）返回 work_pressure 模板', () async {
      final result = await service.generate(
        storyText: '工作压力太大，天天加班到深夜',
        targetStyle: 'gentle_pop',
      );

      expect(result.scene, 'work_pressure');
      // 工作场景特征词
      expect(
        result.comfortInterpretation.contains('累') ||
            result.comfortInterpretation.contains('撑') ||
            result.comfortInterpretation.contains('项目'),
        isTrue,
        reason: '工作场景模板应含工作相关意象',
      );
    });

    test('愧疚场景（对不起/后悔）返回 guilt_regret 模板', () async {
      final result = await service.generate(
        storyText: '我对不起他，当时不该说那些话',
        targetStyle: 'gentle_pop',
      );

      expect(result.scene, 'guilt_regret');
      // 愧疚场景特征词
      expect(
        result.comfortInterpretation.contains('愧疚') ||
            result.comfortInterpretation.contains('错了') ||
            result.comfortInterpretation.contains('责怪'),
        isTrue,
        reason: '愧疚场景模板应含愧疚相关意象',
      );
    });

    test('默认场景（迷茫/低落）返回 default 模板', () async {
      final result = await service.generate(
        storyText: '今晚睡不着，脑子里停不下来',
        targetStyle: 'gentle_pop',
      );

      expect(result.scene, 'default');
    });

    test('不同场景返回不同 comfortInterpretation', () async {
      final academicResult = await service.generate(
        storyText: '考研没考上',
        targetStyle: 'gentle_pop',
      );
      final relationshipResult = await service.generate(
        storyText: '和妈妈吵架',
        targetStyle: 'gentle_pop',
      );
      final workResult = await service.generate(
        storyText: '工作压力太大',
        targetStyle: 'gentle_pop',
      );

      expect(
        academicResult.comfortInterpretation,
        isNot(equals(relationshipResult.comfortInterpretation)),
      );
      expect(
        academicResult.comfortInterpretation,
        isNot(equals(workResult.comfortInterpretation)),
      );
      expect(
        relationshipResult.comfortInterpretation,
        isNot(equals(workResult.comfortInterpretation)),
      );
    });

    test('5 场景 songPrompt 均含 vocal/tempo 要素', () async {
      final stories = ['考研没考上', '和妈妈吵架', '工作压力太大', '我对不起他', '今晚睡不着'];
      for (final story in stories) {
        final result = await service.generate(
          storyText: story,
          targetStyle: 'gentle_pop',
        );
        final lower = result.songPrompt.toLowerCase();
        expect(
          lower.contains('vocal'),
          isTrue,
          reason: 'songPrompt 应含 vocal: $story',
        );
        expect(
          lower.contains('tempo'),
          isTrue,
          reason: 'songPrompt 应含 tempo: $story',
        );
      }
    });
  });

  group('ComfortLyricsService - 文案规范（P4 第二批扩展）', () {
    /// P4 第二批扩展禁用词清单：新增说教类 + 玄学类补充。
    final bannedMedicalWords = ['治疗焦虑', '治疗失眠', '治好你的焦虑', '治愈你的', '疗法', '疗效'];
    final bannedMysticWords = [
      '命中注定',
      '天意',
      '神的安排',
      '神谕',
      '命运注定',
      '命运安排',
      '宇宙告诉你',
      '上天告诉你',
      '神明告诉你',
    ];
    final bannedEmptyTalkWords = ['一切都会好的', '你是最棒的', '会好起来的', '一定会好'];
    // P4 第二批新增：说教类禁用词
    final bannedLecturingWords = ['你必须', '你应该', '你需要治疗', '这说明你'];

    /// 对多个场景的 fallback 都做禁用词检测，确保所有场景模板都符合规范。
    final testStories = ['考研没考上，很难过', '和妈妈吵架了', '工作压力太大', '我对不起他', '今晚睡不着，很迷茫'];

    test('fallback 解惑文本不含医疗化词汇', () async {
      for (final story in testStories) {
        final result = await service.generate(
          storyText: story,
          targetStyle: 'gentle_pop',
        );
        for (final w in bannedMedicalWords) {
          expect(
            result.comfortInterpretation.contains(w),
            isFalse,
            reason: 'fallback 解惑文本不应包含医疗化词汇: $w (story: $story)',
          );
        }
      }
    });

    test('fallback 解惑文本不含玄学化词汇', () async {
      for (final story in testStories) {
        final result = await service.generate(
          storyText: story,
          targetStyle: 'gentle_pop',
        );
        for (final w in bannedMysticWords) {
          expect(
            result.comfortInterpretation.contains(w),
            isFalse,
            reason: 'fallback 解惑文本不应包含玄学化词汇: $w (story: $story)',
          );
        }
      }
    });

    test('fallback 解惑文本不含空话词汇', () async {
      for (final story in testStories) {
        final result = await service.generate(
          storyText: story,
          targetStyle: 'gentle_pop',
        );
        for (final w in bannedEmptyTalkWords) {
          expect(
            result.comfortInterpretation.contains(w),
            isFalse,
            reason: 'fallback 解惑文本不应包含空话词汇: $w (story: $story)',
          );
        }
      }
    });

    test('fallback 解惑文本不含说教词汇（P4 第二批新增）', () async {
      for (final story in testStories) {
        final result = await service.generate(
          storyText: story,
          targetStyle: 'gentle_pop',
        );
        for (final w in bannedLecturingWords) {
          expect(
            result.comfortInterpretation.contains(w),
            isFalse,
            reason: 'fallback 解惑文本不应包含说教词汇: $w (story: $story)',
          );
        }
      }
    });

    test('fallback 歌词草稿不含任何禁用词汇', () async {
      final allBanned = [
        ...bannedMedicalWords,
        ...bannedMysticWords,
        ...bannedEmptyTalkWords,
        ...bannedLecturingWords,
      ];
      for (final story in testStories) {
        final result = await service.generate(
          storyText: story,
          targetStyle: 'gentle_pop',
        );
        for (final w in allBanned) {
          expect(
            result.lyricDraft.contains(w),
            isFalse,
            reason: 'fallback 歌词草稿不应包含禁用词汇: $w (story: $story)',
          );
        }
      }
    });

    test('fallback songPrompt 不含医疗化英文词汇', () async {
      for (final story in testStories) {
        final result = await service.generate(
          storyText: story,
          targetStyle: 'gentle_pop',
        );
        // songPrompt 应为纯音乐风格描述，不含 heal/cure/treatment/therapy
        final lowerPrompt = result.songPrompt.toLowerCase();
        expect(lowerPrompt.contains('heal'), isFalse);
        expect(lowerPrompt.contains('cure'), isFalse);
        expect(lowerPrompt.contains('treatment'), isFalse);
        expect(lowerPrompt.contains('therapy'), isFalse);
      }
    });

    test('fallback songPrompt 不含用户隐私原句', () async {
      // songPrompt 是英文风格描述，不应包含用户中文原文片段
      final result = await service.generate(
        storyText: '我考研没考上，和妈妈吵架了',
        targetStyle: 'gentle_pop',
      );
      final sensitiveFragments = ['考研', '妈妈', '吵架'];
      for (final frag in sensitiveFragments) {
        expect(
          result.songPrompt.contains(frag),
          isFalse,
          reason: 'songPrompt 不应含用户隐私原句: $frag',
        );
      }
    });
  });

  // ─── P4-conversation-song-flow-1-fix1：fetchFollowUpQuestions + 本地兜底分类 ───
  //
  // 测试环境无真实后端，fetchFollowUpQuestions 的 HTTP 调用必然失败，
  // 走 _localFollowUpFallback → _classifyConcern 的 6 分类关键词匹配。
  // 验证：低能量输入不出现「这件事」、eventConflict 允许事件导向措辞、问题数量 2-3 条。
  group('fix1：fetchFollowUpQuestions 本地兜底分类', () {
    test('网络失败时返回本地兜底问题，不抛异常', () async {
      final questions = await service.fetchFollowUpQuestions(
        storyText: '最近工作压力很大',
      );

      expect(questions, isA<List<String>>());
      expect(questions.length, greaterThanOrEqualTo(2));
      expect(questions.length, lessThanOrEqualTo(3));
    });

    test('低能量输入（提不起劲/疲惫/很空）返回 lowEnergy 兜底问题', () async {
      final questions = await service.fetchFollowUpQuestions(
        storyText: '最近总是提不起劲，感觉很疲惫、很空',
      );

      expect(questions.length, 3);
      // lowEnergy 兜底第 1 问应包含「没力气」
      expect(questions.first, contains('没力气'));
    });

    test('低能量兜底问题不包含「这件事」措辞', () async {
      final lowEnergyInputs = [
        '最近总是提不起劲，感觉很疲惫、很空',
        '什么都不想做，很累，没动力',
        '感觉麻木，空的，没精神',
      ];
      for (final input in lowEnergyInputs) {
        final questions = await service.fetchFollowUpQuestions(
          storyText: input,
        );
        for (final q in questions) {
          expect(
            q.contains('这件事'),
            isFalse,
            reason: '低能量输入的兜底问题不应包含「这件事」: $q (input: $input)',
          );
        }
      }
    });

    test('事件冲突输入（和妈妈吵架了）返回 eventConflict 兜底问题', () async {
      final questions = await service.fetchFollowUpQuestions(
        storyText: '和妈妈吵架了',
      );

      expect(questions.length, 3);
      // eventConflict 兜底第 1 问应包含「最让你难受」
      expect(questions.first, contains('最让你难受'));
    });

    test('焦虑压力输入（焦虑/睡不着）返回 anxietyStress 兜底问题', () async {
      final questions = await service.fetchFollowUpQuestions(
        storyText: '最近很焦虑，睡不着',
      );

      expect(questions.length, 3);
      // anxietyStress 兜底第 1 问应包含「最担心」
      expect(questions.first, contains('最担心'));
    });

    test('愧疚后悔输入（后悔/愧疚）返回 guiltRegret 兜底问题', () async {
      final questions = await service.fetchFollowUpQuestions(
        storyText: '我很后悔，当时不该那样做',
      );

      expect(questions.length, 3);
      // guiltRegret 兜底第 1 问应包含「放不下」
      expect(questions.first, contains('放不下'));
    });

    test('孤独输入（孤独/没人理解）返回 loneliness 兜底问题', () async {
      final questions = await service.fetchFollowUpQuestions(
        storyText: '感觉很孤独，没人理解我',
      );

      expect(questions.length, 3);
      // loneliness 兜底第 1 问应包含「有人陪」
      expect(questions.first, contains('有人陪'));
    });

    test('兜底问题不含医疗化词汇', () async {
      final testInputs = [
        '提不起劲，很疲惫',
        '和妈妈吵架了',
        '很焦虑，睡不着',
        '我很后悔',
        '感觉很孤独',
        '今天心情不太好',
      ];
      final bannedWords = ['治疗', '治愈', '疗法', '疗效', '症状', '抑郁', '焦虑症'];
      for (final input in testInputs) {
        final questions = await service.fetchFollowUpQuestions(
          storyText: input,
        );
        for (final q in questions) {
          for (final w in bannedWords) {
            expect(
              q.contains(w),
              isFalse,
              reason: '兜底问题不应包含医疗化词汇: $w (q: $q, input: $input)',
            );
          }
        }
      }
    });
  });
}
