import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xinxian_healing_music/models/comfort_lyrics_result.dart';
import 'package:xinxian_healing_music/models/follow_up_result.dart';

/// 困惑解惑 + 歌词生成 Service（P4 新方向第一批 / 第二批）。
///
/// 职责：调用同域 Cloudflare Pages Function `/api/comfort-lyrics`，
/// 返回 [ComfortLyricsResult]。
///
/// - 不持有任何 API Key / Base URL / 模型名（全部由后端 Function 管理）。
/// - 任何失败（网络、超时、非 200、JSON 解析失败）都返回本地 fallback，
///   不抛异常，不让前端卡死（与 [LlmMoodAnalyzer] 不同：后者失败由
///   [MoodAnalyzerGateway] catch 并 fallback 到 Mock）。
/// - 后端 `ok: false`（fallback）时也正常返回 [ComfortLyricsResult]，
///   [ComfortLyricsResult.source] = 'fallback'，前端可据此显示"本地模板"提示。
///
/// P4 第二批优化：前端本地 fallback 同步后端 5 场景模板
/// （academic_failure / relationship_conflict / work_pressure / guilt_regret / default）。
///
/// 本批不调用 MiniMax / Mureka，不生成真实音频。
class ComfortLyricsService {
  const ComfortLyricsService();

  /// 解析接口的完整 URL。
  /// Web 环境下 `Uri.base` 是当前页面地址，resolve 出同域 `/api/comfort-lyrics`。
  Uri _endpoint() => Uri.base.resolve('/api/comfort-lyrics');

  /// 调用后端生成解惑 + 歌词草稿。
  ///
  /// - [storyText]：用户输入的困惑/事件/情绪描述（≤1000 字）
  /// - [sessionId]：会话 ID（可选，后端会兜底空串）
  /// - [targetStyle]：期望曲风（gentle_pop / ambient_ballad / acoustic_warm / soft_piano）
  /// - [language]：语言（默认 zh-CN）
  /// - [followUpAnswers]：多轮追问的回答（P4-conversation-song-flow-1 新增，可选）
  /// - [desiredFeeling]：希望这首歌带来的感觉（安慰/释怀/力量，可选）
  /// - [comfortDirection]：此刻更想被理解还是平静下来（可选）
  ///
  /// 多轮上下文仅传给后端 LLM 路径用于歌词增强；本地 fallback 不依赖这些字段，
  /// 保证网络不可达时仍有兜底文案。
  ///
  /// 任何异常都返回本地 fallback，绝不抛异常。
  Future<ComfortLyricsResult> generate({
    required String storyText,
    String sessionId = '',
    String targetStyle = 'gentle_pop',
    String language = 'zh-CN',
    List<String> followUpAnswers = const [],
    String desiredFeeling = '',
    String comfortDirection = '',
  }) async {
    final http.Response resp;
    try {
      resp = await http
          .post(
            _endpoint(),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'storyText': storyText,
              'sessionId': sessionId,
              'targetStyle': targetStyle,
              'language': language,
              'followUpAnswers': followUpAnswers,
              'desiredFeeling': desiredFeeling,
              'comfortDirection': comfortDirection,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // 网络错误 / 超时 / CORS —— 不让用户卡死，返回前端本地 fallback
      return _localFallback(storyText);
    }

    if (resp.statusCode != 200) {
      return _localFallback(storyText);
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return _localFallback(storyText);
    }

    // 后端返回 ok:false（fallback）时也正常返回，前端可显示来源标记
    final comfort = body['comfortInterpretation'] as String?;
    final lyric = body['lyricDraft'] as String?;
    if (comfort == null || comfort.isEmpty || lyric == null || lyric.isEmpty) {
      return _localFallback(storyText);
    }

    return ComfortLyricsResult.fromJson(body);
  }

  // ─── P4-conversation-song-flow-1-fix1 / P4-dynamic-followup-depth-1：LLM 动态追问 ──
  //
  // 调用后端 mode='follow_up_questions' 分支，按 stage 分两步：
  // - [fetchFollowUpQuestions]（stage='initial'，缺省）：首轮生成 2 个核心追问
  //   + 建议轮数（suggestedQuestionCount / canGenerateAfter）。
  // - [fetchFollowUpMore]（stage='more'）：用户答完 2 个问题后，判定是否追加
  //   1-2 个问题。needMore=true 时 questions 非空，needMore=false 时为空。
  //
  // 总轮数控制在 2-4：首轮固定 2 个，追加判定最多再加 2 个。
  // 任何失败都走本地兜底，绝不抛异常，不让前端卡死。
  // 与 generate() 的区别：只拉追问列表，不生成歌词；超时更短（12s）。

  /// 拉取首轮 LLM 动态追问问题（stage='initial'）。
  ///
  /// 返回 [FollowUpInitialResult]，含 2 个核心问题 + 建议轮数。
  /// 失败时（网络、非 200、JSON 解析失败、questions 不足 2 条）调用
  /// [_localFollowUpInitialFallback] 返回本地兜底问题，绝不抛异常。
  Future<FollowUpInitialResult> fetchFollowUpQuestions({
    required String storyText,
    String sessionId = '',
    String language = 'zh-CN',
  }) async {
    final http.Response resp;
    try {
      resp = await http
          .post(
            _endpoint(),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'storyText': storyText,
              'sessionId': sessionId,
              'language': language,
              'mode': 'follow_up_questions',
              'stage': 'initial',
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      return _localFollowUpInitialFallback(storyText);
    }

    if (resp.statusCode != 200) {
      return _localFollowUpInitialFallback(storyText);
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return _localFollowUpInitialFallback(storyText);
    }

    final result = FollowUpInitialResult.fromJson(body);
    // questions 不足 2 条 → 走兜底（与后端 normalizeFollowUpQuestions 一致）
    if (result.questions.length < 2) {
      return _localFollowUpInitialFallback(storyText);
    }
    // 保证返回恰好 2 条（前端只展示前 2 条）
    final questions = result.questions.take(2).toList();
    return FollowUpInitialResult(
      questions: questions,
      suggestedQuestionCount: result.suggestedQuestionCount,
      canGenerateAfter: result.canGenerateAfter,
      source: result.source,
      category: result.category,
    );
  }

  /// P4-dynamic-followup-depth-1：拉取追加判定（stage='more'）。
  ///
  /// 在用户答完首轮 2 个问题后调用一次。返回 [FollowUpMoreResult]：
  /// - needMore=true：仍需追问，[questions] 含 1-2 条追加问题。
  /// - needMore=false：不再追问，[questions] 为空，用户可直接进入生成。
  ///
  /// 失败时（网络、非 200、JSON 解析失败）调用 [_localFollowUpMoreFallback]
  /// 返回保守兜底（needMore=false，保证用户在 2 轮后即可生成），绝不抛异常。
  Future<FollowUpMoreResult> fetchFollowUpMore({
    required String storyText,
    required List<String> answers,
    String sessionId = '',
    String language = 'zh-CN',
  }) async {
    final http.Response resp;
    try {
      resp = await http
          .post(
            _endpoint(),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'storyText': storyText,
              'sessionId': sessionId,
              'language': language,
              'mode': 'follow_up_questions',
              'stage': 'more',
              'answers': answers.take(2).toList(),
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      return _localFollowUpMoreFallback();
    }

    if (resp.statusCode != 200) {
      return _localFollowUpMoreFallback();
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return _localFollowUpMoreFallback();
    }

    return FollowUpMoreResult.fromJson(body);
  }

  /// 首轮追问本地兜底（LLM 不可达 / 返回无效时使用）。
  ///
  /// 与后端 `localFollowUpFallback(stage='initial')` 一致：取该分类前 2 条。
  /// 通过 [_classifyConcern] 关键词匹配选择对应问题。lowEnergy 优先级最高，
  /// 避免在用户没力气时问"这件事里"。
  FollowUpInitialResult _localFollowUpInitialFallback(String storyText) {
    final category = _classifyConcern(storyText);
    final full = _followUpFallbackQuestions[category] ??
        _followUpFallbackQuestions['unknown']!;
    return FollowUpInitialResult(
      questions: full.take(2).toList(),
      suggestedQuestionCount: 2,
      canGenerateAfter: 2,
      source: 'fallback',
      category: category,
    );
  }

  /// 追加判定本地兜底（LLM 不可达 / 返回无效时使用）。
  ///
  /// 与后端 `localFollowUpMoreFallback` 一致：恒定 needMore=false + 空 questions，
  /// 保证用户在 2 轮后即可进入生成，不阻塞流程。
  FollowUpMoreResult _localFollowUpMoreFallback() {
    return const FollowUpMoreResult(
      needMore: false,
      questions: [],
      source: 'fallback',
    );
  }

  /// 根据 storyText 关键词识别追问分类（与后端 `classifyConcern` 一致）。
  ///
  /// 6 类：lowEnergy / eventConflict / anxietyStress / guiltRegret /
  /// loneliness / unknown。lowEnergy 优先级最高。
  static String _classifyConcern(String storyText) {
    if (storyText.isEmpty) return 'unknown';

    // lowEnergy：提不起劲 / 疲惫 / 空 / 没动力（优先级最高）
    const lowEnergyKeywords = [
      '提不起劲',
      '疲惫',
      '很累',
      '好累',
      '太累了',
      '很空',
      '空的',
      '空落',
      '麻木',
      '没动力',
      '不想动',
      '没力气',
      '什么都不想做',
      '没意思',
      '没劲儿',
      '提不起精神',
      '没精神',
    ];
    for (final k in lowEnergyKeywords) {
      if (storyText.contains(k)) return 'lowEnergy';
    }

    // eventConflict：争吵 / 分手 / 被批评 / 失败 / 人际冲突
    const eventConflictKeywords = [
      '争吵',
      '吵架',
      '分手',
      '被批评',
      '失败',
      '考试',
      '挂科',
      '冷战',
      '已读不回',
      '妈妈',
      '爸爸',
      '朋友',
      '同事',
      '室友',
      '老板',
      '上司',
      '伴侣',
      '对象',
      '男朋友',
      '女朋友',
      '骂',
      '冲突',
      '闹翻',
    ];
    for (final k in eventConflictKeywords) {
      if (storyText.contains(k)) return 'eventConflict';
    }

    // anxietyStress：焦虑 / 紧张 / 压力 / 心慌 / 睡不着
    const anxietyStressKeywords = [
      '焦虑',
      '紧张',
      '压力',
      '心慌',
      '担心',
      '睡不着',
      '失眠',
      '喘不过气',
      '心跳快',
      '害怕',
      '恐惧',
    ];
    for (final k in anxietyStressKeywords) {
      if (storyText.contains(k)) return 'anxietyStress';
    }

    // guiltRegret：后悔 / 愧疚 / 责备自己 / 做错事
    const guiltRegretKeywords = [
      '后悔',
      '愧疚',
      '责备自己',
      '做错事',
      '对不起',
      '我害了',
      '都是我的错',
      '自责',
      '内疚',
      '辜负',
    ];
    for (final k in guiltRegretKeywords) {
      if (storyText.contains(k)) return 'guiltRegret';
    }

    // loneliness：孤独 / 没人理解 / 想有人陪
    const lonelinessKeywords = [
      '孤独',
      '没人理解',
      '想有人陪',
      '一个人',
      '没人懂',
      '没人陪',
      '孤零零',
      '孤单',
    ];
    for (final k in lonelinessKeywords) {
      if (storyText.contains(k)) return 'loneliness';
    }

    return 'unknown';
  }

  /// 6 分类追问兜底问题（与后端 `FOLLOW_UP_FALLBACK_QUESTIONS` 一致）。
  ///
  /// 全部低压力、不医疗化；lowEnergy / unknown 不带"这件事里"措辞。
  static const Map<String, List<String>> _followUpFallbackQuestions = {
    'lowEnergy': [
      '这种疲惫和空落感，通常什么时候最明显？',
      '你更像是身体累，还是心里没力气？',
      '想让这首歌陪你慢慢休息，还是给你一点重新开始的力气？',
    ],
    'eventConflict': ['最让你难受的是哪一句？', '现在更想被理解，还是想先平静下来？', '有想跟对方说、但没说出口的话吗？'],
    'anxietyStress': ['现在最担心的是哪件事？', '有没有哪一段想法，一直绕着不走？', '想先停一下，还是想找个人说一说？'],
    'guiltRegret': ['最放不下的是当时的哪一句话？', '现在更想先原谅自己，还是先想清楚？', '有想跟对方说、但还没说出口的吗？'],
    'loneliness': ['今天最想有人陪的时刻是哪一段？', '现在更想要安静，还是想被听见？', '有没有谁，是你想了一下但没联系的？'],
    'unknown': ['今天最重的是哪一段心情？', '现在更想被理解，还是想先平静下来？', '有想先放一放的事吗？'],
  };

  /// 前端本地 fallback（网络完全不可达时使用）。
  ///
  /// P4 第二批：与后端 `localFallback` 的 5 场景模板保持一致，
  /// 通过 [_detectScene] 关键词匹配选择对应模板。
  /// 双层 fallback 确保用户在任何情况下都能看到一段贴近场景的温和解惑 + 歌词草稿。
  ComfortLyricsResult _localFallback(String storyText) {
    final scene = _detectScene(storyText);
    final tpl = _fallbackTemplates[scene] ?? _fallbackTemplates['default']!;

    return ComfortLyricsResult(
      comfortInterpretation: tpl['comfortInterpretation'] as String,
      lyricDraft: tpl['lyricDraft'] as String,
      songPrompt: tpl['songPrompt'] as String,
      safetyNotes: 'fallback_mode（$scene，前端本地场景模板）',
      source: 'fallback',
      scene: scene,
    );
  }

  /// 根据 storyText 关键词识别场景（与后端 `detectScene` 一致）。
  ///
  /// 6 类：academic_failure / relationship_conflict / work_pressure /
  /// guilt_regret / low_energy / default
  /// P4-conversation-song-flow-1-fix2：新增 low_energy，避免低能量输入
  /// 落入 default 模板的「夜色/窗」泛化意象。
  static String _detectScene(String storyText) {
    if (storyText.isEmpty) return 'default';
    final lower = storyText.toLowerCase();

    // 学业/失败
    const academicKeywords = [
      '考试',
      '挂科',
      '成绩',
      '考研',
      '高考',
      '学业',
      '录取',
      '复习',
      '模拟卷',
      '落榜',
      '没考上',
      '挂了',
      '学分',
      '毕业论文',
      '答辩',
    ];
    for (final k in academicKeywords) {
      if (storyText.contains(k)) return 'academic_failure';
    }

    // 关系/争吵
    const relationshipKeywords = [
      '吵架',
      '分手',
      '亲人',
      '父母',
      '妈妈',
      '爸爸',
      '朋友',
      '冷战',
      '关系',
      '男朋友',
      '女朋友',
      '对象',
      '伴侣',
      '恋人',
      '室友',
      '已读不回',
      '没回消息',
      '说了重话',
    ];
    for (final k in relationshipKeywords) {
      if (storyText.contains(k)) return 'relationship_conflict';
    }

    // 工作压力
    const workKeywords = [
      '工作',
      '加班',
      '压力',
      '项目',
      'deadline',
      '截止',
      '老板',
      '上司',
      '同事',
      'kpi',
      '绩效',
      '996',
      '通勤',
      '任务',
      '开会',
    ];
    for (final k in workKeywords) {
      if (lower.contains(k) || storyText.contains(k)) return 'work_pressure';
    }

    // 愧疚/后悔
    const guiltKeywords = [
      '对不起',
      '后悔',
      '愧疚',
      '错了',
      '伤害',
      '辜负',
      '没能',
      '没做到',
      '我害了',
      '都是我的错',
      '自责',
      '内疚',
    ];
    for (final k in guiltKeywords) {
      if (storyText.contains(k)) return 'guilt_regret';
    }

    // P4-conversation-song-flow-1-fix2：低能量 / 疲惫 / 空 / 提不起劲
    // 与 _classifyConcern 的 lowEnergy 关键词一致，优先级在具体事件场景之后、default 之前。
    const lowEnergyKeywords = [
      '提不起劲',
      '疲惫',
      '很累',
      '好累',
      '太累了',
      '很空',
      '空的',
      '空落',
      '麻木',
      '没动力',
      '不想动',
      '没力气',
      '什么都不想做',
      '没意思',
      '没劲儿',
      '提不起精神',
      '没精神',
    ];
    for (final k in lowEnergyKeywords) {
      if (storyText.contains(k)) return 'low_energy';
    }

    return 'default';
  }

  /// 6 场景 fallback 模板（与后端 `FALLBACK_TEMPLATES` 一致）。
  ///
  /// 每个 scene 的 comfortInterpretation 严格按 4 段结构
  /// （复述 / 重新框架 / 小行动 / 过渡到歌）。
  /// lyricDraft 含「主歌」「副歌」「尾声」+ 具象画面 + 重复 hook。
  /// songPrompt 为英文，明确 vocal / mood / tempo / instrumentation。
  static const Map<String, Map<String, String>> _fallbackTemplates = {
    'academic_failure': {
      'comfortInterpretation':
          '听起来你正在为一场没考好的试、或者一个没达到的学业目标难过。那种感觉不只是「失分」，更像突然不太确定自己之前那些努力去了哪里。\n\n'
          '也许这件事最重的地方不是分数本身，而是你把它当成了对自己整个人的评价。一张卷子没办法替你下结论，你也从来没被一次考试完整定义过。\n\n'
          '可以先把目标放小一点。今晚不要去想下学期怎么补、要不要重修，先把今天没吃完的饭吃完，把没睡够的觉补一段。\n\n'
          '这首歌不急着推你往前，只先陪你站稳一点。',
      'lyricDraft':
          '【主歌】\n走廊的灯还没关\n模拟卷摊在桌上没人收\n你写错的那一题\n其实不重要，重要的是你太累了\n\n'
          '【副歌】\n不是所有跌倒，都要马上给出答案\n今晚先别赶路，让风替你轻轻说完\n不是所有跌倒，都要马上给出答案\n错的不是你这个人，是这一次的卷面\n\n'
          '【尾声】\n明天的复习计划，明天再写。',
      'songPrompt':
          'gentle mandarin ballad, warm vocal melody, soft piano and acoustic guitar, slow tempo, intimate and comforting mood, clean arrangement',
    },
    'relationship_conflict': {
      'comfortInterpretation':
          '听起来你正在一段关系里难过。可能是一次争吵，也可能是没说出口的话堵在胸口，让你一边生气一边又觉得委屈。\n\n'
          '也许这件事最重的地方不是谁对谁错，而是你们之间有些东西还没被听懂。吵出来的话往往是冰山一角，水面下藏着没说出口的在乎。\n\n'
          '可以先把目标放小一点。今晚不用逼自己立刻原谅谁、或者想清楚怎么说。可以先给自己倒一杯水，把那条没发出去的消息先存草稿。\n\n'
          '这首歌不急着推你往前，只先陪你站稳一点。',
      'lyricDraft':
          '【主歌】\n消息框亮了又暗\n已读两个字比沉默更难\n你关上门，又回头看了一眼\n其实你不是想赢，是想被听见\n\n'
          '【副歌】\n我把没说完的话，放进慢慢亮起的窗\n今晚先别赶路，让风替你轻轻说完\n我把没说完的话，放进慢慢亮起的窗\n不是不爱你，是先让自己喘一段\n\n'
          '【尾声】\n那条没发的消息，今晚先不发。',
      'songPrompt':
          'gentle mandarin ballad, breathy vocal, fingerstyle guitar and soft pads, slow tempo, bittersweet and tender mood, minimal arrangement',
    },
    'work_pressure': {
      'comfortInterpretation':
          '听起来你正在被一件事压着，可能是项目，可能是 deadline，可能是加班太久之后的那种钝钝的累。你说不清哪里最难受，但全身都在说「停一下」。\n\n'
          '也许这件事最重的地方不是任务本身，而是你把「我必须撑住」当成了唯一选项。累不是因为你不够强，是因为你撑得太久没让自己歇。\n\n'
          '可以先把目标放小一点。今晚不用把所有未读邮件清完，不用把明天的会议预演第三遍。可以先把屏幕调暗一格，把手机放远一点。\n\n'
          '这首歌不急着推你往前，只先陪你站稳一点。',
      'lyricDraft':
          '【主歌】\n屏幕的光映在你脸上\n末班车开走了你也没看\n桌面上的杯子早就凉了\n你还在等一个不会来的「现在可以走了」\n\n'
          '【副歌】\n今晚先别赶路，让风替你轻轻说完\n累不是因为你不够强，是你撑得太长\n今晚先别赶路，让风替你轻轻说完\n不是所有事，都要今晚做完\n\n'
          '【尾声】\n明天的事，明天再认得它。',
      'songPrompt':
          'warm mandarin ballad, soft male or female vocal, gentle piano with subtle synth pads, slow tempo, late night comforting mood, spacious arrangement',
    },
    'guilt_regret': {
      'comfortInterpretation':
          '听起来你正在为一件已经过去的事责怪自己。可能是说错的话、没做到的承诺、或者一个你以为可以做得更好的选择。愧疚一直绕着你转，不肯走。\n\n'
          '也许这件事最重的地方不是「我错了」，而是「我在乎」。会愧疚，恰恰说明你对那个人、那件事有过真心。做错了不等于你是错的。\n\n'
          '可以先把目标放小一点。今晚不用逼自己立刻原谅自己，也不用现在就去找对方道歉。可以先承认「我那时候没做好」，然后允许自己停在这里一会儿。\n\n'
          '这首歌不急着推你往前，只先陪你站稳一点。',
      'lyricDraft':
          '【主歌】\n昨天那句话又回来了\n想拨的电话停在拨号界面\n你没寄出的道歉\n和没改掉的昨天并排躺着\n\n'
          '【副歌】\n不是所有跌倒，都要马上给出答案\n做错了不等于你是错的，只是这一次没做好\n不是所有跌倒，都要马上给出答案\n今晚先别赶路，让风替你轻轻说完\n\n'
          '【尾声】\n想道歉的人，明天再练习开口。',
      'songPrompt':
          'gentle mandarin ballad, soft intimate vocal, acoustic guitar and warm piano, slow tempo, reflective and forgiving mood, sparse arrangement',
    },
    // P4-conversation-song-flow-1-fix2：低能量 / 疲惫 / 空 / 提不起劲
    // 不用「夜色/窗/城市」泛化意象，直接承接低能量状态。
    'low_energy': {
      'comfortInterpretation':
          '听起来你最近提不起劲，整个人像是被抽空了一点。不是哪一件事压着你，而是什么都没力气去做，连解释都觉得累。\n\n'
          '也许这种感觉最重的地方不是「我怎么了」，而是「你已经撑了很久，现在真的没电了」。空空的不是因为你不好，是身体和心都在说「先停一下」。\n\n'
          '可以先把目标放小一点。今天不用变好，不用打起精神，不用逼自己振作。可以先允许自己什么都不做，就只是坐着，或者躺一会儿。\n\n'
          '这首歌不急着推你往前，只想陪你慢慢待着。',
      'lyricDraft':
          '【主歌】\n什么都不想做的一天\n力气不知道去了哪里\n你不是偷懒，是真的空了\n今天先不用变好也没关系\n\n'
          '【副歌】\n慢一点也可以，我在这里\n今天先不用变好，先不用撑\n慢一点也可以，我在这里\n空空的也没关系，允许自己停\n\n'
          '【尾声】\n明天的事，等有了力气再认得它。',
      'songPrompt':
          'gentle mandarin ballad, soft breathy vocal, minimal piano with warm pads, very slow tempo, low energy and comforting mood, spacious and quiet arrangement',
    },
    'default': {
      'comfortInterpretation':
          '听起来你正在一段说不太清楚的状态里。没有具体的事，但就是有点沉、有点空、有点停不下来地想这想那。这种说不清的低落，本身就已经够重了。\n\n'
          '也许这件事最重的地方不是「我哪里不对」，而是「我现在确实需要停一下」。不是所有不舒服都需要立刻被解释清楚，有些时候只是累了，不是错了。\n\n'
          '可以先把目标放小一点。今晚不用想清楚人生方向，不用复盘今天每一句话。可以先关掉一盏灯，把窗户打开一条缝，让外面的声音替你想一会儿。\n\n'
          '这首歌不急着推你往前，只先陪你站稳一点。',
      'lyricDraft':
          '【主歌】\n夜色慢慢盖下来\n没亮的窗和还没醒的城市\n你坐在那里没说话\n风把心事吹得有些远\n\n'
          '【副歌】\n想哭也没关系，我在听\n今晚先别赶路，让风替你轻轻说完\n想哭也没关系，我在听\n不用急着好起来，这首歌想陪你看见自己\n\n'
          '【尾声】\n天快亮了，你不用一个人。',
      'songPrompt':
          'gentle mandarin ballad, soft breathy vocal, fingerstyle guitar and warm pads, slow tempo, late night intimate mood, clean arrangement',
    },
  };
}
