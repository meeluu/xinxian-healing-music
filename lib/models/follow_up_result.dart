/// P4-dynamic-followup-depth-1：动态追问结果模型。
///
/// 对应后端 `functions/api/comfort-lyrics.js` 的 `mode='follow_up_questions'`
/// 两个 stage 的响应：
/// - [FollowUpInitialResult]：首轮（stage='initial'），生成 2 个核心追问 + 建议轮数。
/// - [FollowUpMoreResult]：追加判定（stage='more'），判断是否再问 1-2 个问题。
///
/// 设计原则：
/// - 总追问轮数允许 2、3、4 轮；不少于 2 轮，不超过 4 轮。
/// - [FollowUpInitialResult.canGenerateAfter] 始终为 2（第 2 个问题答完后即可生成）。
/// - [FollowUpInitialResult.suggestedQuestionCount] 仅供前端参考展示，实际是否追加
///   由 [FollowUpMoreResult.needMore] 决定（基于已有回答的二次判定）。
/// - 任何失败都返回结构化兜底（source='fallback'），前端不抛异常。
class FollowUpInitialResult {
  /// 首轮生成的核心追问列表（固定 2 条）。
  final List<String> questions;

  /// 建议总追问轮数（含本轮 2 个），取值 2 / 3 / 4。
  ///
  /// 仅供前端展示进度提示参考；实际追加与否由 [FollowUpMoreResult] 决定。
  final int suggestedQuestionCount;

  /// 第几个问题答完后允许用户点击「先写成歌」（始终为 2）。
  final int canGenerateAfter;

  /// 来源：'llm' / 'fallback'。
  final String source;

  /// 本地兜底分类（仅 source='fallback' 时有意义）：
  /// lowEnergy / eventConflict / anxietyStress / guiltRegret / loneliness / unknown。
  final String? category;

  /// 是否来自 fallback（本地模板，非 LLM）。
  bool get isFallback => source != 'llm';

  const FollowUpInitialResult({
    required this.questions,
    this.suggestedQuestionCount = 3,
    this.canGenerateAfter = 2,
    this.source = 'fallback',
    this.category,
  });

  /// 从后端 JSON 响应构造（stage='initial'）。
  ///
  /// 兼容两种情况：
  /// - `ok: true, source: 'llm'` —— LLM 成功，含 suggestedQuestionCount / canGenerateAfter
  /// - `ok: false, source: 'fallback'` —— LLM 失败，后端已返回本地兜底问题
  factory FollowUpInitialResult.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    List<String> questions = const [];
    if (rawQuestions is List) {
      questions = rawQuestions
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(2)
          .toList();
    }

    // suggestedQuestionCount：合法范围 [2, 4]，缺省 3
    int suggested = 3;
    final rawSuggested = json['suggestedQuestionCount'];
    if (rawSuggested is num) {
      suggested = rawSuggested.toInt();
      if (suggested < 2) suggested = 2;
      if (suggested > 4) suggested = 4;
    }

    // canGenerateAfter：始终为 2（第 2 个问题答完后即可生成）
    int canGenerateAfter = 2;
    final rawCanGenerate = json['canGenerateAfter'];
    if (rawCanGenerate is num) {
      canGenerateAfter = rawCanGenerate.toInt();
      if (canGenerateAfter < 2) canGenerateAfter = 2;
      if (canGenerateAfter > 2) canGenerateAfter = 2;
    }

    return FollowUpInitialResult(
      questions: questions,
      suggestedQuestionCount: suggested,
      canGenerateAfter: canGenerateAfter,
      source: (json['source'] as String?) ?? 'fallback',
      category: json['category'] as String?,
    );
  }
}

/// P4-dynamic-followup-depth-1：追加判定结果（stage='more'）。
///
/// 在用户答完首轮 2 个问题后调用一次，判断是否还需追加 1-2 个问题。
/// - [needMore]=true：仍需追问，[questions] 含 1-2 条追加问题。
/// - [needMore]=false：不再追问，[questions] 为空数组，用户可直接进入生成。
class FollowUpMoreResult {
  /// 是否还需要追加问题。
  final bool needMore;

  /// 追加问题列表（needMore=true 时 1-2 条；needMore=false 时为空）。
  final List<String> questions;

  /// 来源：'llm' / 'fallback'。
  final String source;

  /// 是否来自 fallback（本地模板，非 LLM）。
  bool get isFallback => source != 'llm';

  const FollowUpMoreResult({
    required this.needMore,
    this.questions = const [],
    this.source = 'fallback',
  });

  /// 从后端 JSON 响应构造（stage='more'）。
  ///
  /// 一致性约束（与后端 `normalizeFollowUpMore` 一致）：
  /// - needMore=true 但 questions 为空 → 强制 needMore=false
  /// - needMore=false → 强制 questions=[]
  factory FollowUpMoreResult.fromJson(Map<String, dynamic> json) {
    final needMore = json['needMore'] == true;
    final rawQuestions = json['questions'];
    List<String> questions = const [];
    if (rawQuestions is List) {
      questions = rawQuestions
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(2)
          .toList();
    }

    // 一致性约束
    if (!needMore) {
      questions = const [];
    } else if (questions.isEmpty) {
      // needMore=true 但无可用问题 → 视为不再追加
      return FollowUpMoreResult(
        needMore: false,
        questions: const [],
        source: (json['source'] as String?) ?? 'fallback',
      );
    }

    return FollowUpMoreResult(
      needMore: needMore,
      questions: questions,
      source: (json['source'] as String?) ?? 'fallback',
    );
  }
}
