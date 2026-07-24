import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xinxian_healing_music/models/comfort_lyrics_result.dart';
import 'package:xinxian_healing_music/models/follow_up_result.dart';
import 'package:xinxian_healing_music/pipeline/llm/comfort_lyrics_service.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/screens/analysis_screen.dart';
import 'package:xinxian_healing_music/screens/generated_song_player_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// 「把困惑写成一首歌」页面（P4 新方向第一/二/三批 + P4 生成音频落地播放 + P4 临时音频播放闭环）。
///
/// 流程：
/// 1. 用户输入一段困惑/事件/情绪描述
/// 2. 选择期望曲风（4 选 1，默认 gentle_pop）
/// 3. 点击「生成」→ 调用 [ComfortLyricsService] 请求 /api/comfort-lyrics
/// 4. 显示：
///    - 温和解惑文本（comfortInterpretation）
///    - 歌词草稿（lyricDraft，含主歌/副歌/尾声标记）
///    - 后续提示：`下一步可以生成专属歌曲`
/// 5. P4 第三批：用户可「编辑歌词」并保存/取消
/// 6. P4-generated-audio-playback-1 + P4-temp-audio-playback-1：「生成这首歌」受控实验入口
///    - 文案为「生成这首歌（实验）」
///    - 点击前必须确认"会发起一次 AI 音乐生成，可能产生调用费用"
///    - 调用 /api/generate-music（带 manualTest=true，受后端三重门保护）
///    - P4-playback-experience-2：成功拿到可播放 URL 后跳转到独立播放页
///      [GeneratedSongPlayerScreen]，不在歌词页内嵌播放。歌词页保留轻量入口
///      卡片，支持返回后重新进入播放页。
///    - P4-temp-audio-playback-1：不依赖 R2，audioDataUrl 临时播放闭环已线上验证通过
///    - 既无 URL 也无 audioDataUrl 时提示"音乐已经生成，但暂时无法播放，请稍后再试"
///    - 失败时显示"生成没有完成，请稍后再试"
///    - 不影响"快速舒缓一下"固定曲库播放链路
///
/// 任何失败都返回 fallback，不让用户卡死。
///
/// 文案规范：不使用医疗化 / 玄学化 / 空话 / 说教表达。
class ComfortLyricsScreen extends StatefulWidget {
  const ComfortLyricsScreen({super.key});

  @override
  State<ComfortLyricsScreen> createState() => _ComfortLyricsScreenState();
}

class _ComfortLyricsScreenState extends State<ComfortLyricsScreen> {
  final TextEditingController _storyController = TextEditingController();
  final FocusNode _storyFocus = FocusNode();
  final ComfortLyricsService _service = const ComfortLyricsService();

  /// 当前选择的曲风。
  String _targetStyle = 'gentle_pop';

  /// 是否正在请求 LLM。
  bool _loading = false;

  /// 最近一次生成结果（null 表示尚未生成）。
  ComfortLyricsResult? _result;

  /// 最近一次错误提示（仅用于 UI 显示，不暴露内部异常）。
  String? _errorHint;

  /// songPrompt 是否展开（P4 第二批：折叠弱化，默认收起）。
  bool _songPromptExpanded = false;

  /// P4 第三批：歌词编辑状态。
  ///
  /// 状态管理规则：
  /// - 生成结果后才能编辑歌词（_result != null）
  /// - 编辑时不能重复点击「生成解惑与歌词草稿」（生成按钮 disabled）
  /// - 保存后 [_editedLyric] 使用编辑后的内容，[songPrompt] 保持原结果不变
  /// - 点击「再写一首」后清空编辑状态（_isEditing=false, _editedLyric=null）
  bool _isEditing = false;

  /// 歌词编辑控制器（仅编辑态使用）。
  final TextEditingController _editingController = TextEditingController();

  /// 歌词编辑焦点（进入编辑态时自动聚焦）。
  final FocusNode _editingFocus = FocusNode();

  /// 用户保存后的歌词（null 表示未编辑过，展示时回退到 result.lyricDraft）。
  String? _editedLyric;

  // ─── P4-generated-audio-playback-1：AI 生成歌曲受控实验入口状态 ───
  //
  // 状态管理规则：
  // - 只有生成歌词草稿后（_result != null）才允许点击「生成这首歌（实验）」
  // - 编辑态时禁用（避免与歌词编辑冲突）
  // - 调用 /api/generate-music 期间 _generatingMusic=true，按钮显示 loading
  // - P4-playback-experience-2：成功拿到可播放 URL 后构造 [_generatedSongMeta]，
  //   跳转到 [GeneratedSongPlayerScreen] 独立播放页，不在歌词页内嵌播放。
  //   歌词页保留 [_generatedSongMeta] 缓存，支持返回后重新进入播放页。
  // - 拿到 storageKey 但无 URL（storageWarning=r2_not_configured）时显示已保存提示
  // - 失败时显示友好错误，不影响其他流程
  // - 点击「再写一首」时清空 [_generatedSongMeta]（播放器已在独立页管理）

  /// 是否正在调用 /api/generate-music 生成 AI 歌曲。
  bool _generatingMusic = false;

  /// AI 生成歌曲的元数据缓存（playableUrl / title / comfortInterpretation /
  /// lyricDraft / targetState）。
  ///
  /// 非 null 表示已成功生成过歌曲，歌词页显示轻量入口卡片，点击可重新进入
  /// [GeneratedSongPlayerScreen]。播放器生命周期由独立播放页管理，歌词页不持有。
  GeneratedSongMeta? _generatedSongMeta;

  /// AI 生成歌曲的存储警告（r2_not_configured / r2_upload_failed）。
  /// 用于区分"已生成保存但无 URL"和"完全失败"两种情况。
  String? _storageWarning;

  /// AI 生成歌曲的错误提示（仅用于 UI 显示，不暴露内部异常）。
  String? _musicErrorHint;

  // ─── P6-quota-guard-1：本地每日生成额度保护状态 ───
  //
  // 今日剩余可成功生成次数：
  // - null  → 额度服务未装配（存储全不可用），降级：不限制、不显示提示
  // - 0     → 今日体验次数已用完，禁用「生成这首歌（实验）」+「重新生成」
  // - >0    → 还可生成，按钮可用
  //
  // 仅约束 AI 生成歌曲入口；不影响「快速舒缓一下」固定曲库。
  // 计数规则：只有 /api/generate-music 返回成功且拿到可播放音频时才计数（_callGenerateMusicApi 成功分支）。
  int? _quotaRemaining;

  // ─── P4-conversation-song-flow-1 / P4-dynamic-followup-depth-1：多轮困惑理解状态 ───
  //
  // 流程：input（输入困惑+选曲风）→ loadingFollowUp（首轮 2 个核心追问）→
  //       followUp（第 1/2 个问题）→ loadingFollowUpMore（判定是否追加）→
  //       followUp（第 3/4 个追加问题，如 needMore=true）→ done（生成结果）
  //
  // P4-dynamic-followup-depth-1：追问轮数动态 2-4 轮。
  // - 首轮固定 2 个核心问题（_dynamicQuestions 前 2 条）。
  // - 第 2 个问题答完后调一次 fetchFollowUpMore，判定是否追加 1-2 个问题。
  // - needMore=true：把追加问题拼到 _dynamicQuestions 末尾，继续 followUp 阶段。
  // - needMore=false：直接进入 done 阶段生成。
  // - 第 2 个问题答完后，用户也可主动点击「先写成歌」跳过追加判定。
  //
  // 多轮数据只存在页面 state，不做长期保存（_reset 清空，不写入本地存储/云端）。
  // fix1：追问改为 LLM 动态生成（fetchFollowUpQuestions），失败走本地 6 分类兜底。
  // 不再用固定 _followUpQuestions 常量；所有回答统一计入 _followUpAnswers。
  _ConversationPhase _phase = _ConversationPhase.input;

  /// 当前追问轮次 0.._dynamicQuestions.length-1。
  int _followUpIndex = 0;

  /// 追问输入控制器。
  final TextEditingController _followUpController = TextEditingController();

  /// 追问输入焦点。
  final FocusNode _followUpFocus = FocusNode();

  /// 原始困惑（input 阶段填入，done 阶段作为 storyText 传给 service）。
  String _initialConcern = '';

  /// 动态追问回答列表（每轮一个条目，统一计入，不再区分 desiredFeeling/comfortDirection）。
  List<String> _followUpAnswers = [];

  /// 当前动态问题列表（来自 LLM 或本地兜底）。空列表表示尚未加载。
  ///
  /// P4-dynamic-followup-depth-1：首轮 2 条；如追加判定 needMore=true，
  /// 会把追加问题拼到末尾，长度可能变为 3 或 4。
  List<String> _dynamicQuestions = [];

  /// P4-dynamic-followup-depth-1：第几个问题答完后允许「先写成歌」（始终为 2）。
  ///
  /// 用于驱动 [isSecondInitial] 判定：当 `_followUpIndex == _canGenerateAfter - 1`
  /// 且 `_dynamicQuestions.length == _canGenerateAfter` 时，显示「先写成歌」按钮。
  int _canGenerateAfter = 2;

  /// P4-dynamic-followup-depth-1：追加判定是否正在进行（防并发）。
  ///
  /// 用户答完第 2 个问题后触发 fetchFollowUpMore，期间置 true，
  /// 避免 UI 重复触发或用户连续点击导致状态混乱。
  bool _moreInFlight = false;

  /// 4 种曲风选项。
  static const List<_StyleOption> _styleOptions = [
    _StyleOption(
      value: 'gentle_pop',
      label: '温柔流行',
      description: '木吉他 + 慢板 + 温暖',
    ),
    _StyleOption(
      value: 'ambient_ballad',
      label: '氛围民谣',
      description: '柔和合成 + 缓慢 + 安静',
    ),
    _StyleOption(
      value: 'acoustic_warm',
      label: '暖意指弹',
      description: '指弹吉他 + 缓慢 + 陪伴',
    ),
    _StyleOption(
      value: 'soft_piano',
      label: '柔光钢琴',
      description: '钢琴 + 缓慢 + 平和',
    ),
  ];

  bool get _hasStory => _storyController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _storyController.addListener(() => setState(() {}));
    // P6-quota-guard-1：加载今日额度状态（异步，不阻塞首帧）
    _refreshQuotaState();
  }

  @override
  void dispose() {
    _storyController.dispose();
    _storyFocus.dispose();
    _editingController.dispose();
    _editingFocus.dispose();
    // P4-conversation-song-flow-1：释放追问控制器
    _followUpController.dispose();
    _followUpFocus.dispose();
    // P4-playback-experience-2：AI 生成歌曲播放器由 GeneratedSongPlayerScreen
    // 独立管理生命周期，歌词页不持有播放器，无需在此释放。
    super.dispose();
  }

  /// P6-quota-guard-1：刷新今日额度状态。
  ///
  /// - 服务未装配（generationQuotaService == null）→ [_quotaRemaining] = null（降级：不限制）
  /// - 否则先跨天重置，再读取 todayRemaining
  ///
  /// 在 initState、生成成功后调用，驱动额度提示与按钮禁用态刷新。
  Future<void> _refreshQuotaState() async {
    final svc = generationQuotaService;
    if (svc == null) {
      if (!mounted) return;
      setState(() => _quotaRemaining = null);
      return;
    }
    try {
      await svc.resetIfNewDay();
    } catch (_) {
      // 跨天重置失败不影响读取当前额度
    }
    if (!mounted) return;
    setState(() => _quotaRemaining = svc.todayRemaining);
  }

  /// 触发生成：调用 [ComfortLyricsService]。
  ///
  /// P4-conversation-song-flow-1：storyText 改为 [_initialConcern]（input 阶段填入），
  /// 并传入多轮对话上下文（followUpAnswers），让后端 LLM 生成更贴合用户困境的歌词。
  /// fix1：desiredFeeling / comfortDirection 已移除，所有回答统一计入 followUpAnswers。
  ///
  /// 任何异常都被 Service 兜底为 fallback，前端不会再 catch 到异常。
  /// 这里仍用 try/catch + _errorHint 作为最后保险，避免任何边界情况导致页面卡死。
  Future<void> _generate() async {
    final story = _initialConcern;
    if (story.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _errorHint = null;
      _result = null;
      // 清空上一次的编辑状态
      _isEditing = false;
      _editedLyric = null;
      _songPromptExpanded = false;
    });

    try {
      final result = await _service.generate(
        storyText: story,
        targetStyle: _targetStyle,
        followUpAnswers: _followUpAnswers,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (_) {
      // 任何意外异常都不让用户卡死：显示友好错误态
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorHint = '生成失败，请稍后再试';
      });
    }
  }

  /// fix1 / P4-dynamic-followup-depth-1：从 input 阶段进入 loadingFollowUp，
  /// 调 LLM 拿首轮 2 个核心追问。
  ///
  /// 记录原始困惑为 [_initialConcern]，切到 loadingFollowUp 阶段，
  /// 调 [_service.fetchFollowUpQuestions] 拿 [FollowUpInitialResult]；
  /// 失败走本地 6 分类兜底（service 内部已处理）。
  /// 拿到问题后切到 followUp 阶段，进入第 0 个追问。
  Future<void> _startFollowUp() async {
    final story = _storyController.text.trim();
    if (story.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _initialConcern = story;
      _phase = _ConversationPhase.loadingFollowUp;
      _followUpIndex = 0;
      _followUpAnswers = [];
      _dynamicQuestions = [];
      _canGenerateAfter = 2;
      _moreInFlight = false;
      _followUpController.clear();
      _errorHint = null;
      _result = null;
      _isEditing = false;
      _editedLyric = null;
      _songPromptExpanded = false;
    });

    FollowUpInitialResult result;
    try {
      result = await _service.fetchFollowUpQuestions(storyText: story);
    } catch (_) {
      // service 内部已 fallback，这里再兜一层防意外
      result = FollowUpInitialResult(
        questions: const [
          '今天最重的是哪一段心情？',
          '现在更想被理解，还是想先平静下来？',
        ],
        suggestedQuestionCount: 2,
        canGenerateAfter: 2,
        source: 'fallback',
      );
    }
    if (!mounted) return;

    // 防御性兜底：service 内部已 fallback，这里再检查空列表
    var questions = result.questions;
    if (questions.length < 2) {
      questions = const [
        '今天最重的是哪一段心情？',
        '现在更想被理解，还是想先平静下来？',
      ];
    }

    setState(() {
      _dynamicQuestions = questions;
      _canGenerateAfter = result.canGenerateAfter;
      _phase = _ConversationPhase.followUp;
    });

    // 自动聚焦到追问输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _followUpFocus.requestFocus();
    });
  }

  /// P4-dynamic-followup-depth-1：记录当前追问回答并推进到下一轮 / 追加判定 / 生成。
  ///
  /// 推进逻辑（总轮数动态 2-4）：
  /// - 记录回答到 [_followUpAnswers]。
  /// - 若还有未答的题（_followUpIndex < lastIndex）→ 推进到下一题。
  /// - 若已答完当前所有题：
  ///   · 若刚答完第 2 个问题（index==1）且未触发过追加判定（!_moreInFlight）
  ///     且总轮数尚未达 4 → 触发 [_triggerFollowUpMore] 判定是否追加。
  ///   · 否则（追加判定已完成 needMore=false，或已达 4 轮上限）→ 进入 done 生成。
  ///
  /// 所有回答统一计入 [_followUpAnswers]（不再区分 desiredFeeling/comfortDirection）。
  void _recordAnswerAndAdvance(String answer) {
    FocusScope.of(context).unfocus();
    final lastIndex = _dynamicQuestions.length - 1;
    final answeredCount = _followUpAnswers.length + 1; // 含本次回答

    setState(() {
      _followUpAnswers = [..._followUpAnswers, answer];
      _followUpController.clear();
      if (_followUpIndex < lastIndex) {
        // 还有未答的题 → 推进到下一题
        _followUpIndex += 1;
      } else if (answeredCount == 2 &&
          !_moreInFlight &&
          _dynamicQuestions.length < 4) {
        // 刚答完第 2 个问题，且未触发过追加判定，且未达 4 轮上限 → 触发追加判定
        _phase = _ConversationPhase.loadingFollowUpMore;
        _moreInFlight = true;
      } else {
        // 追加判定已完成（needMore=false）或已达 4 轮上限 → 进入生成
        _phase = _ConversationPhase.done;
      }
    });

    if (_phase == _ConversationPhase.loadingFollowUpMore) {
      _triggerFollowUpMore();
    } else if (_phase == _ConversationPhase.done) {
      _generate();
    } else {
      // 聚焦下一题输入框
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _followUpFocus.requestFocus();
      });
    }
  }

  /// P4-dynamic-followup-depth-1：触发追加判定（stage='more'）。
  ///
  /// 在用户答完首轮 2 个问题后调用一次 [_service.fetchFollowUpMore]。
  /// - needMore=true 且有可用问题 → 把追加问题拼到 [_dynamicQuestions] 末尾，
  ///   推进 [_followUpIndex] 到第一个追加问题，回到 followUp 阶段。
  /// - needMore=false 或无可用问题 → 直接进入 done 阶段生成。
  ///
  /// 任何异常都走保守兜底（不追加，直接生成），绝不阻塞流程。
  /// [_moreInFlight] 在调用前已置 true，调用结束后置 false（无论成功失败）。
  Future<void> _triggerFollowUpMore() async {
    FollowUpMoreResult result;
    try {
      result = await _service.fetchFollowUpMore(
        storyText: _initialConcern,
        answers: _followUpAnswers,
      );
    } catch (_) {
      // service 内部已 fallback，这里再兜一层防意外
      result = const FollowUpMoreResult(
        needMore: false,
        questions: [],
        source: 'fallback',
      );
    }
    if (!mounted) return;

    setState(() {
      _moreInFlight = false;
      if (result.needMore && result.questions.isNotEmpty) {
        // 把追加问题拼到末尾，但总轮数不超过 4
        final remainingSlots = 4 - _dynamicQuestions.length;
        final additional = result.questions.take(remainingSlots).toList();
        if (additional.isEmpty) {
          // 无可用追加问题（已被 4 轮上限截断）→ 直接生成
          _phase = _ConversationPhase.done;
        } else {
          _dynamicQuestions = [..._dynamicQuestions, ...additional];
          _followUpIndex = _dynamicQuestions.length - additional.length;
          _phase = _ConversationPhase.followUp;
        }
      } else {
        // needMore=false 或无可用问题 → 直接生成
        _phase = _ConversationPhase.done;
      }
    });

    if (_phase == _ConversationPhase.done) {
      _generate();
    } else {
      // 聚焦追加问题输入框
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _followUpFocus.requestFocus();
      });
    }
  }

  /// P4-dynamic-followup-depth-1：第 2 个问题时，用户主动点击「先写成歌」。
  ///
  /// 记录当前回答（如果非空）后跳过追加判定，直接进入 done 阶段生成。
  /// 与 [_skipAndGenerate] 区别：
  /// - [_skipMoreAndGenerate]：记录当前回答后再生成（不丢用户输入），仅在第 2 题显示。
  /// - [_skipAndGenerate]：不记录当前回答，适用于任意轮次的低压力出口。
  void _skipMoreAndGenerate() {
    FocusScope.of(context).unfocus();
    final answer = _followUpController.text.trim();
    setState(() {
      if (answer.isNotEmpty) {
        _followUpAnswers = [..._followUpAnswers, answer];
      }
      _moreInFlight = false;
      _phase = _ConversationPhase.done;
      _followUpController.clear();
    });
    _generate();
  }

  /// P4-conversation-song-flow-1：跳过追问，直接进入 done 阶段生成。
  ///
  /// 已收集的回答保留，未回答的字段保持空串。低压力出口，始终可用。
  void _skipAndGenerate() {
    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _ConversationPhase.done;
      _followUpController.clear();
    });
    _generate();
  }

  /// 重置：清空输入和结果，回到初始态。
  ///
  /// P4 第三批：同时清空编辑状态（_isEditing / _editedLyric / 编辑控制器）。
  /// P4-playback-experience-2：清空 [_generatedSongMeta] 缓存（播放器由独立页管理，
  /// 歌词页不持有，无需停止/释放）。
  void _reset() {
    setState(() {
      _storyController.clear();
      _result = null;
      _errorHint = null;
      _loading = false;
      _songPromptExpanded = false;
      // 清空编辑状态
      _isEditing = false;
      _editedLyric = null;
      _editingController.clear();
      // 清空 AI 生成歌曲状态
      _generatingMusic = false;
      _generatedSongMeta = null;
      _storageWarning = null;
      _musicErrorHint = null;
      // P4-conversation-song-flow-1 / P4-dynamic-followup-depth-1：清空多轮对话状态，回到 input 阶段
      _phase = _ConversationPhase.input;
      _followUpIndex = 0;
      _initialConcern = '';
      _followUpAnswers = [];
      _dynamicQuestions = [];
      _canGenerateAfter = 2;
      _moreInFlight = false;
      _followUpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CenteredPageScaffold(
      appBar: AppBar(
        title: const Text('把困惑写成一首歌'),
        automaticallyImplyLeading: true,
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部说明（followUp / loadingFollowUpMore 阶段隐藏，避免与追问卡片视觉冲突）
          if (_phase != _ConversationPhase.followUp &&
              _phase != _ConversationPhase.loadingFollowUpMore) ...[
            const Text(
              '把你最近遇到的一件事、一个困惑，或者一段心情写下来。\n心弦会陪你把它重新看一遍，并写成一首属于你的歌。',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── input 阶段：故事输入 + 曲风 + 开始理解 ──
          if (_phase == _ConversationPhase.input) ...[
            // P4 前端结构调整第一批：标题从「写下你的困惑」改为「先说说卡住你的事」
            const Text(
              '先说说卡住你的事',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _StoryInputField(
              controller: _storyController,
              focusNode: _storyFocus,
            ),
            const SizedBox(height: 18),
            // 曲风选择
            const Text(
              '期望曲风',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildStyleSelector(),
            const SizedBox(height: 24),
            // P4-conversation-song-flow-1：生成按钮文案改为「开始理解」，
            // 点击后进入多轮追问，不立即调用 LLM。
            FilledButton.icon(
              onPressed: (_hasStory && !_loading) ? _startFollowUp : null,
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '开始理解',
                  style: TextStyle(fontSize: 16, letterSpacing: 1),
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],

          // ── loadingFollowUp 阶段：首轮 LLM 动态追问生成中 ──
          if (_phase == _ConversationPhase.loadingFollowUp) ...[
            _buildLoadingHint('正在根据你的文字整理几个更贴近的问题…'),
          ],

          // ── loadingFollowUpMore 阶段：追加判定中 ──
          // P4-dynamic-followup-depth-1：用户答完第 2 个问题后，正在判定是否追加。
          if (_phase == _ConversationPhase.loadingFollowUpMore) ...[
            _buildLoadingHint('正在想想还要不要再问你一个问题…'),
          ],

          // ── followUp 阶段：多轮追问卡片 ──
          if (_phase == _ConversationPhase.followUp) ...[_buildFollowUpCard()],

          // 错误态
          if (_errorHint != null) ...[
            const SizedBox(height: 16),
            _buildErrorHint(),
          ],

          // ── done 阶段：加载中 / 结果区 ──
          if (_phase == _ConversationPhase.done) ...[
            if (_loading)
              _buildLoadingHint()
            else if (_result != null) ...[
              const SizedBox(height: 28),
              _buildResult(_result!),
            ],
          ],
        ],
      ),
    );
  }

  /// P4-conversation-song-flow-1：分阶段加载提示。
  ///
  /// fix1：根据不同阶段显示不同文案，不再所有阶段都用同一句。
  /// - loadingFollowUp 阶段：正在根据你的文字整理几个更贴近的问题…
  /// - done 阶段（生成歌词）：正在整理你的文字，写成一首更贴近你的歌…
  /// 文案温和、不医疗化，不暗示已完成治疗效果。
  Widget _buildLoadingHint([String? message]) {
    final text = message ?? '正在整理你的文字，写成一首更贴近你的歌…';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// P4-conversation-song-flow-1 / P4-dynamic-followup-depth-1：多轮追问卡片。
  ///
  /// fix1：问题改为 LLM 动态生成（[_dynamicQuestions]），不再使用固定模板。
  /// P4-dynamic-followup-depth-1：追问轮数动态 2-4 轮。
  ///
  /// 结构：
  /// - 原始困惑回显（compact，让用户感到"被听见"）
  /// - 进度提示（第 N 个问题；第 2 题答完可「先写成歌」或「继续」让系统判断是否追加）
  /// - 问题卡片：问题文案 + 输入框 + 跳过/继续按钮
  ///
  /// 按钮逻辑（P4-dynamic-followup-depth-1）：
  /// - 第 1 题：左「跳过追问，直接生成」+ 右「继续」
  /// - 第 2 题（首轮最后一个，尚未触发追加判定）：
  ///   左「先写成歌」（记录回答后直接生成，跳过追加判定）+
  ///   右「继续」（记录回答后触发追加判定，可能追加 1-2 个问题）
  /// - 第 3/4 题（追加问题）：左「跳过追问，直接生成」+ 右「生成歌词」
  ///
  /// 文案短、自然、低压力，不像心理测评问卷。用户可随时跳过直接生成。
  Widget _buildFollowUpCard() {
    final prompt = _dynamicQuestions[_followUpIndex];
    final isLast = _followUpIndex == _dynamicQuestions.length - 1;
    // P4-dynamic-followup-depth-1：第 2 题（首轮最后一个，尚未触发追加判定）
    // 此时 _dynamicQuestions.length == _canGenerateAfter(2)，_followUpIndex == 1。
    // 触发追加判定后若 needMore=true，length 会变为 3/4，index 推进到 2/3。
    final isSecondInitial =
        _followUpIndex == _canGenerateAfter - 1 &&
        _dynamicQuestions.length == _canGenerateAfter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 原始困惑回显
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.format_quote_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '你刚才说',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _initialConcern,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // 进度提示
        // P4-dynamic-followup-depth-1：第 2 题时总轮数尚未确定，用不同文案提示。
        Text(
          isSecondInitial
              ? '第 2 个问题 · 答完可以先写成歌，也可以继续让我再想想'
              : '第 ${_followUpIndex + 1} / ${_dynamicQuestions.length} 个问题 · 可以只写几个字，也可以跳过',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        // 问题卡片
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.lavender.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.hearing_rounded,
                    size: 18,
                    color: AppColors.lavender,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prompt,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '写几个字就好，也可以不写',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              // 追问输入框
              TextField(
                controller: _followUpController,
                focusNode: _followUpFocus,
                minLines: 2,
                maxLines: 5,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText: '写几个字就好，也可以不写',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.6,
                  ),
                  filled: true,
                  fillColor: AppColors.bgBlue,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              // 左按钮 + 右按钮
              // P4-dynamic-followup-depth-1：第 2 题显示「先写成歌」，其余显示「跳过追问，直接生成」。
              Row(
                children: [
                  Expanded(
                    child: isSecondInitial
                        ? OutlinedButton.icon(
                            onPressed: _skipMoreAndGenerate,
                            icon: const Icon(Icons.music_note_rounded, size: 16),
                            label: const Text(
                              '先写成歌',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(42),
                              foregroundColor: AppColors.lavender,
                              side: BorderSide(
                                color: AppColors.lavender.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: _skipAndGenerate,
                            icon: const Icon(Icons.skip_next_rounded, size: 16),
                            label: const Text(
                              '跳过追问，直接生成',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(42),
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.cardBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _recordAnswerAndAdvance(
                        _followUpController.text.trim(),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(
                        (isLast && !isSecondInitial) ? '生成歌词' : '继续',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        backgroundColor: AppColors.lavender.withValues(
                          alpha: 0.9,
                        ),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 曲风选择器：4 选 1，横向 Wrap 布局。
  Widget _buildStyleSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final opt in _styleOptions)
          _StyleChip(
            option: opt,
            selected: _targetStyle == opt.value,
            onTap: () => setState(() => _targetStyle = opt.value),
          ),
      ],
    );
  }

  /// 错误提示卡片。
  Widget _buildErrorHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.apricot.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.apricotDeep.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: AppColors.apricotDeep,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorHint!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.apricotDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 结果区：来源标记 + 解惑卡片 + 歌词卡片（可编辑）+ songPrompt + 后续提示 + 生成这首歌占位 + 重置按钮。
  ///
  /// P4 第二批优化：
  /// - 「温和解惑」→「给现在的你」（更像产品而非分析报告）
  /// - 「歌词草稿」→「写成歌的话」（更温柔、更产品化）
  /// - songPrompt 折叠弱化（默认收起，标题改为「后续生成参数」）
  /// - 显示场景标记（让用户感到"被听懂"）
  ///
  /// P4 第三批新增：
  /// - 歌词卡片支持编辑/保存/取消（[_buildLyricCard]）
  /// - 底部新增「生成这首歌（即将开放）」占位按钮（[_buildGenerateSongButton]）
  Widget _buildResult(ComfortLyricsResult result) {
    // 展示歌词优先用用户编辑后保存的内容，否则用原始 result.lyricDraft
    final displayLyric = _editedLyric ?? result.lyricDraft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 来源 + 场景标记
        _buildBadges(result.source, result.scene),
        const SizedBox(height: 14),

        // 给现在的你（温和解惑）
        _SectionCard(
          icon: Icons.favorite_border_rounded,
          title: '给现在的你',
          child: SelectableText(
            result.comfortInterpretation,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.75,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 写成歌的话（歌词草稿，P4 第三批：可编辑）
        _buildLyricCard(displayLyric),
        const SizedBox(height: 14),

        // songPrompt 折叠弱化（默认收起）
        _buildSongPromptCard(result.songPrompt),
        const SizedBox(height: 18),

        // 后续提示
        _buildNextStepHint(),
        const SizedBox(height: 18),

        // P4-song-result-experience-1 + P4-playback-experience-2：
        // 生成成功 → 显示轻量入口卡片（点击进入独立播放页）
        // 生成失败 → 显示失败区（错误提示+重试/编辑按钮）
        // 存储警告 → 极端边界提示
        // 未生成 / 生成中 → 显示入口按钮（生成中为 loading 态）
        if (_generatedSongMeta != null) ...[
          _buildGeneratedSongEntry(),
          const SizedBox(height: 14),
        ] else if (_musicErrorHint != null) ...[
          _buildMusicErrorSection(),
          const SizedBox(height: 14),
        ] else if (_storageWarning != null) ...[
          _buildStorageWarningHint(),
          const SizedBox(height: 14),
        ] else ...[
          _buildGenerateSongButton(),
          const SizedBox(height: 14),
        ],

        // 重置按钮
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('再写一首', style: TextStyle(fontSize: 14)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  /// 歌词卡片（P4 第三批：支持展示 / 编辑两种模式）。
  ///
  /// - 展示模式：SelectableText + 右上角「编辑歌词」按钮
  /// - 编辑模式：多行 TextField + 字数提示 + 温和质量提醒 + 「保存歌词」/「取消编辑」
  ///
  /// 编辑态下歌词可被用户修改；保存后 [_editedLyric] 更新，取消则恢复编辑前内容。
  /// [songPrompt] 保持原结果不变，不受歌词编辑影响。
  Widget _buildLyricCard(String lyric) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：图标 + 「写成歌的话」 + 编辑按钮（仅展示态显示）
          Row(
            children: [
              const Icon(
                Icons.music_note_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                '写成歌的话',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (!_isEditing)
                TextButton.icon(
                  onPressed: () => _startEdit(lyric),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('编辑歌词', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 内容区：展示态 vs 编辑态
          if (_isEditing) ...[
            // 编辑态：多行 TextField
            TextField(
              controller: _editingController,
              focusNode: _editingFocus,
              minLines: 6,
              maxLines: 14,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.85,
                letterSpacing: 0.2,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgBlue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.4,
                  ),
                ),
                contentPadding: const EdgeInsets.all(14),
                isDense: false,
              ),
            ),
            const SizedBox(height: 8),

            // 字数提示（实时显示当前字数，不强制限制）
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _editingController,
              builder: (context, value, _) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${value.text.length} 字',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // 温和质量提醒：建议保留主歌/副歌/尾声结构
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.lavender.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.lavender.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: AppColors.lavender.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '建议保留主歌、副歌、尾声结构，后续更适合生成歌曲。',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 保存 / 取消 按钮
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveEdit,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('保存歌词', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelEdit,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('取消编辑', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(
                        color: AppColors.cardBorder,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            // 展示态：SelectableText
            SelectableText(
              lyric,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.85,
                letterSpacing: 0.2,
              ),
            ),
        ],
      ),
    );
  }

  /// 进入编辑态：把当前展示的歌词填入编辑控制器，并自动聚焦。
  void _startEdit(String currentLyric) {
    setState(() {
      _isEditing = true;
      _editingController.text = currentLyric;
      _editingController.selection = TextSelection.fromPosition(
        TextPosition(offset: currentLyric.length),
      );
    });
    // 自动聚焦到编辑框（下一帧，避免 build 期间 requestFocus 报错）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editingFocus.requestFocus();
    });
  }

  /// 保存编辑：把编辑控制器内容写入 [_editedLyric]，退出编辑态。
  /// [songPrompt] 保持原结果不变，不受歌词编辑影响。
  void _saveEdit() {
    final text = _editingController.text;
    setState(() {
      _editedLyric = text;
      _isEditing = false;
    });
    _editingFocus.unfocus();
  }

  /// 取消编辑：退出编辑态，不修改 [_editedLyric]（恢复编辑前展示内容）。
  void _cancelEdit() {
    setState(() {
      _isEditing = false;
    });
    _editingFocus.unfocus();
  }

  /// 「生成这首歌（实验）」受控实验入口按钮（P4-generated-audio-playback-1）。
  ///
  /// P4-generated-audio-playback-1 状态：
  /// - 后端已具备三重门真实调用能力（PROVIDER + REAL_CALLS + manualTest + Key）
  /// - 前端按钮本批改为受控实验入口：点击 → 弹出费用确认 → 调用 /api/generate-music
  /// - 请求体携带 manualTest=true（受后端三重门保护，realCallsEnabled=false 时仍返回 fallback）
  /// - 成功拿到 generatedAudioUrl 后显示内嵌播放区
  /// - 拿到 storageKey 但无 URL 时提示"音乐已生成并保存"
  /// - 失败时显示友好错误，不影响其他流程
  ///
  /// 安全：
  /// - 不暴露 API Key（前端不持有任何凭证）
  /// - 不允许跳过费用确认（_showGenerateSongConfirmDialog 必须返回 true 才调用）
  /// - 编辑态 / 生成中禁用按钮
  /// - P6-quota-guard-1：今日体验次数已用完时禁用按钮 + 显示额度提示
  Widget _buildGenerateSongButton() {
    final quotaExhausted = _quotaRemaining == 0;
    final disabled = _isEditing || _generatingMusic || quotaExhausted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // P6-quota-guard-1：额度提示（服务未装配时不显示）
        if (_quotaRemaining != null) ...[
          _buildQuotaHint(),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          onPressed: disabled ? null : _onGenerateSongPressed,
          icon: _generatingMusic
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.music_note_rounded, size: 18),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _generatingMusic ? '正在生成这首歌，请保持页面打开…' : '生成这首歌（实验）',
              style: const TextStyle(fontSize: 15, letterSpacing: 0.5),
            ),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: AppColors.lavender.withValues(alpha: 0.85),
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.lavender.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  /// P6-quota-guard-1：额度提示 widget（仅在额度服务装配后由调用方显示）。
  ///
  /// - remaining > 0：`今日还可生成 N 首`（弱化小字）
  /// - remaining == 0：`今日体验次数已用完` + 副提示「今天的 AI 生成体验次数已用完，
  ///   可以先继续编辑歌词，明天再生成。」
  Widget _buildQuotaHint() {
    final remaining = _quotaRemaining;
    if (remaining == null) return const SizedBox.shrink();
    if (remaining > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            const Icon(Icons.spa_rounded, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              '今日还可生成 $remaining 首',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    // 已用完：温和卡片提示，引导用户先编辑歌词、明天再生成
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '今日体验次数已用完',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '今天的 AI 生成体验次数已用完，可以先继续编辑歌词，明天再生成。',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 点击「生成这首歌（实验）」入口：先弹费用确认对话框，确认后才调用 API。
  ///
  /// P4-generated-audio-playback-1：受控实验入口的核心保护点。
  /// - 用户必须明确确认"会发起一次 AI 音乐生成，可能产生调用费用"才能继续
  /// - 不允许跳过确认（防止误触扣费）
  /// - 确认后调用 [_callGenerateMusicApi]
  Future<void> _onGenerateSongPressed() async {
    if (_isEditing || _generatingMusic || _result == null) return;
    // P6-quota-guard-1：今日体验次数已用完则不再发起（按钮已禁用，此处双保险）
    if (_quotaRemaining == 0) return;
    FocusScope.of(context).unfocus();

    final confirmed = await _showGenerateSongConfirmDialog();
    if (!confirmed || !mounted) return;

    await _callGenerateMusicApi();
  }

  /// 费用确认对话框：明确告知用户这会发起一次 AI 音乐生成，可能产生调用费用。
  ///
  /// 返回 true 表示用户已确认，false 表示用户取消。
  /// 文案面向用户友好，不暴露内部技术细节（如 MiniMax / R2 / manualTest）。
  Future<bool> _showGenerateSongConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: AppColors.lavender,
            ),
            SizedBox(width: 8),
            Text(
              '生成这首歌',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: const Text(
          '这会发起一次 AI 音乐生成，可能产生调用费用。\n\n'
          '生成大约需要 30–60 秒，请保持页面打开。',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '取消',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('确认生成'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 调用 /api/generate-music 生成 AI 歌曲。
  ///
  /// 请求体：
  /// - sessionId：基于时间戳生成（避免暴露用户身份）
  /// - targetState：根据曲风映射（gentle_pop/soft_piano → soothe，ambient_ballad → sleep，
  ///   acoustic_warm → regulate，focus/energize 暂未在前端曲风选项中）
  /// - generationPrompt：使用 result.songPrompt（LLM 生成的英文风格提示）
  /// - lyrics：使用 _editedLyric ?? result.lyricDraft（用户编辑后的歌词优先）
  /// - songPrompt：透传 result.songPrompt
  /// - durationSeconds：120（与后端 maxDurationSeconds 一致）
  /// - manualTest: true（受三重门保护，realCallsEnabled=false 时仍返回 fallback）
  ///
  /// 响应处理（P4-temp-audio-playback-1：支持 audioDataUrl 临时播放）：
  /// - ok:false → 显示"生成没有完成，请稍后再试"
  /// - ok:true + 可播放 URL → 构造 [_generatedSongMeta]，跳转 [GeneratedSongPlayerScreen]
  /// - ok:true + 既无 generatedAudioUrl 也无 audioDataUrl → 显示"音乐已经生成，但暂时无法播放"
  /// - 网络异常 → 显示"生成没有完成，请稍后再试"
  ///
  /// P4-playback-experience-2：成功后不再在歌词页内嵌播放，而是跳转到独立播放页。
  /// 歌词页缓存 [_generatedSongMeta]，用户返回后可重新进入播放页。
  Future<void> _callGenerateMusicApi() async {
    final result = _result!;
    final lyrics = (_editedLyric ?? result.lyricDraft);
    final songPrompt = result.songPrompt;

    setState(() {
      _generatingMusic = true;
      _musicErrorHint = null;
      _storageWarning = null;
      _generatedSongMeta = null;
    });

    final sessionId =
        'web-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final targetState = _mapStyleToTargetState(_targetStyle);

    try {
      final resp = await http
          .post(
            Uri.base.resolve('/api/generate-music'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: _encodeGenerateMusicBody(
              sessionId: sessionId,
              targetState: targetState,
              songPrompt: songPrompt,
              lyrics: lyrics,
            ),
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (resp.statusCode != 200) {
        setState(() {
          _generatingMusic = false;
          _musicErrorHint = '生成没有完成，请稍后再试';
        });
        return;
      }

      final body = _decodeJson(resp.body);
      if (body == null) {
        setState(() {
          _generatingMusic = false;
          _musicErrorHint = '生成没有完成，请稍后再试';
        });
        return;
      }

      final ok = body['ok'] == true;
      final generatedAudioUrl = body['generatedAudioUrl'] as String?;
      // P4-temp-audio-playback-1：新增 audioDataUrl 字段（base64 dataUrl 临时播放）
      final audioDataUrl = body['audioDataUrl'] as String?;
      final storageWarning = body['storageWarning'] as String?;

      if (!ok) {
        // 后端返回 fallback（realCallsEnabled=false 或 manualTest 未通过或 MiniMax 调用失败）
        setState(() {
          _generatingMusic = false;
          _musicErrorHint = '生成没有完成，请稍后再试';
        });
        return;
      }

      // ok=true：MiniMax 真实调用成功
      // P4-temp-audio-playback-1：优先用 generatedAudioUrl（R2 路径或 MiniMax 直返 URL），
      // 回退到 audioDataUrl（base64 dataUrl 临时播放，不依赖 R2）
      final playableUrl =
          (generatedAudioUrl != null && generatedAudioUrl.isNotEmpty)
          ? generatedAudioUrl
          : ((audioDataUrl != null && audioDataUrl.isNotEmpty)
                ? audioDataUrl
                : null);

      if (playableUrl != null) {
        // P4-playback-experience-2：拿到可播放音频 → 构造 meta 缓存 + 跳转独立播放页
        final meta = GeneratedSongMeta(
          playableUrl: playableUrl,
          title: _generateSongTitle(targetState),
          comfortInterpretation: result.comfortInterpretation,
          lyricDraft: lyrics,
          targetState: targetState,
        );
        // P6-quota-guard-1：仅当成功且拿到可播放音频时才计数 + 刷新额度状态。
        // 失败 / 取消 / 无可播放音频 / 网络异常都不计数。
        await generationQuotaService?.recordSuccessfulGeneration();
        await _refreshQuotaState();
        if (!mounted) return;
        setState(() {
          _generatingMusic = false;
          _generatedSongMeta = meta;
          // 有可播放音频时清空 storageWarning，避免显示"无法播放"提示
          _storageWarning = null;
          _musicErrorHint = null;
        });
        // 跳转到独立播放页（不在歌词页内嵌播放）
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GeneratedSongPlayerScreen(meta: meta),
          ),
        );
      } else {
        // 既无 generatedAudioUrl 也无 audioDataUrl → 无法播放
        // 保留 storageWarning（如有），UI 会显示"音乐已生成并保存"提示；
        // 否则显示通用错误
        setState(() {
          _generatingMusic = false;
          _generatedSongMeta = null;
          _storageWarning = storageWarning;
          _musicErrorHint = (storageWarning != null)
              ? null
              : '音乐已经生成，但暂时无法播放，请稍后再试';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generatingMusic = false;
        _musicErrorHint = '生成没有完成，请稍后再试';
      });
    }
  }

  /// 曲风 → targetState 映射（用于 /api/generate-music 请求体）。
  ///
  /// gentle_pop / soft_piano → soothe（温柔安抚）
  /// ambient_ballad → sleep（夜色舒缓）
  /// acoustic_warm → regulate（降频调节）
  /// 兜底 → soothe
  String _mapStyleToTargetState(String style) {
    switch (style) {
      case 'ambient_ballad':
        return 'sleep';
      case 'acoustic_warm':
        return 'regulate';
      case 'gentle_pop':
      case 'soft_piano':
      default:
        return 'soothe';
    }
  }

  /// P4-song-result-experience-1：根据 targetState 本地生成歌曲标题。
  ///
  /// 不新增 LLM 调用，用简单规则生成温和、非医疗化的标题。
  /// 后续可以让 LLM 返回 title 字段替换此规则。
  String _generateSongTitle(String targetState) {
    switch (targetState) {
      case 'sleep':
        return '今晚先慢下来';
      case 'soothe':
        return '把心放轻一点';
      case 'focus':
        return '慢慢回到这里';
      case 'regulate':
        return '让心绪落下来';
      default:
        return '写给现在的你';
    }
  }

  /// P4-song-result-experience-1：返回编辑歌词（不丢失当前歌词）。
  ///
  /// 进入编辑态，编辑控制器初始化为当前展示的歌词。
  /// 不清空生成歌曲状态（用户可以编辑后再重新生成）。
  void _returnToEditLyrics() {
    final currentLyric = _editedLyric ?? _result?.lyricDraft ?? '';
    _editingController.text = currentLyric;
    setState(() {
      _isEditing = true;
    });
    // 自动聚焦到编辑框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editingFocus.requestFocus();
    });
  }

  /// P4-song-result-experience-1：重新生成 / 重试生成（需再次费用确认）。
  ///
  /// 无论上次成功还是失败，重新生成都必须再次弹出费用确认对话框，
  /// 因为会真实调用 MiniMax API 并可能产生费用。
  /// 不允许跳过确认（防止误触扣费）。
  Future<void> _onRegenerateSongPressed() async {
    if (_isEditing || _generatingMusic || _result == null) return;
    // P6-quota-guard-1：今日体验次数已用完则不再发起（按钮已禁用，此处双保险）
    if (_quotaRemaining == 0) return;
    FocusScope.of(context).unfocus();

    final confirmed = await _showGenerateSongConfirmDialog();
    if (!confirmed || !mounted) return;

    await _callGenerateMusicApi();
  }

  /// 编码 /api/generate-music 请求体（不依赖 dart:convert 顶层 import 以避免增加依赖）。
  ///
  /// 字段说明：
  /// - sessionId：会话标识（不暴露用户身份）
  /// - targetState：目标状态（5 选 1）
  /// - generationPrompt：英文风格提示（result.songPrompt）
  /// - lyrics：用户编辑后的歌词（_editedLyric ?? result.lyricDraft）
  /// - songPrompt：与 generationPrompt 一致（透传给 MiniMax provider）
  /// - durationSeconds：120（与后端 maxDurationSeconds 一致）
  /// - manualTest: true（受三重门保护，realCallsEnabled=false 时仍返回 fallback）
  String _encodeGenerateMusicBody({
    required String sessionId,
    required String targetState,
    required String songPrompt,
    required String lyrics,
  }) {
    // 使用 dart:convert 的 jsonEncode（已通过 http 间接依赖）
    return _jsonEncode({
      'sessionId': sessionId,
      'targetState': targetState,
      'generationPrompt': songPrompt,
      'lyrics': lyrics,
      'songPrompt': songPrompt,
      'durationSeconds': 120,
      'manualTest': true,
    });
  }

  /// P4-playback-experience-2：生成歌曲成功后的轻量入口卡片。
  ///
  /// 替换原内嵌播放区（P4-song-result-experience-1 已移除）。歌词页不再直接播放，
  /// 而是提供一个入口卡片，引导用户进入 [GeneratedSongPlayerScreen] 独立播放页。
  ///
  /// 包含：
  /// - 状态标题：这首歌已经生成好了
  /// - 副文案：点击进入播放页，可以播放、看歌词、定时关闭
  /// - 主按钮：进入播放页（跳转 [GeneratedSongPlayerScreen]）
  /// - 次按钮：编辑歌词 / 重新生成（需费用确认）
  /// - [_buildSootheCta]：引导本地纯音乐舒缓
  ///
  /// 播放器生命周期由独立播放页管理，歌词页只缓存 [_generatedSongMeta]。
  Widget _buildGeneratedSongEntry() {
    final meta = _generatedSongMeta;
    if (meta == null) return const SizedBox.shrink();
    final quotaExhausted = _quotaRemaining == 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lavender.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 状态标题
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: AppColors.lavender.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '这首歌已经生成好了',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 副文案
          const Text(
            '点击下面按钮进入播放页，可以播放、看歌词、定时关闭。',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),

          // 主按钮：进入播放页
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GeneratedSongPlayerScreen(meta: meta),
                ),
              );
            },
            icon: const Icon(Icons.play_circle_rounded, size: 18),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('进入播放页', style: TextStyle(fontSize: 15)),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppColors.lavender.withValues(alpha: 0.85),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 次按钮：编辑歌词 + 重新生成
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _returnToEditLyrics,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('编辑歌词', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  // P6-quota-guard-1：额度用完时禁用「重新生成」
                  onPressed: quotaExhausted ? null : _onRegenerateSongPressed,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('重新生成', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    foregroundColor: AppColors.apricotDeep,
                    side: BorderSide(
                      color: AppColors.apricotDeep.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // P4-conversation-song-flow-1：AI 歌曲后引导纯音乐舒缓 CTA
          _buildSootheCta(),
        ],
      ),
    );
  }

  /// P4-conversation-song-flow-1：AI 歌曲后引导纯音乐 CTA。
  ///
  /// 文案温和，引导用户进入本地纯音乐舒缓（不触发 MiniMax，不扣额度）。
  /// 点击后跳转 AnalysisScreen，带默认心境文本，走现有「快速舒缓一下」流程。
  Widget _buildSootheCta() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.spa_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                '还想再安静一会儿吗？',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '可以听一段不带歌词的纯音乐，让情绪慢慢落下来。',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _goToSoothe,
            icon: const Icon(Icons.music_note_rounded, size: 16),
            label: const Text('快速舒缓一下', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// P4-conversation-song-flow-1：跳转本地纯音乐舒缓流程。
  ///
  /// fix1：不再依赖 desiredFeeling / comfortDirection（已移除），使用静态温和文案。
  /// 跳转 AnalysisScreen 走现有「快速舒缓一下」流程，只用本地 assets 音乐。
  /// 不触发 MiniMax，不扣额度（额度只约束 AI 歌曲生成）。
  ///
  /// P4-playback-experience-2：AI 生成歌曲播放器由独立播放页管理，
  /// 返回歌词页时独立页已 dispose，无需在此停止播放器。
  void _goToSoothe() {
    const moodText = '听完这首歌，想再安静一会儿';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AnalysisScreen(moodText: moodText),
      ),
    );
  }

  /// P4-song-result-experience-1：生成失败区（含温和错误提示 + 操作按钮）。
  ///
  /// 失败时不白屏，保留歌词，提供：
  /// - 错误标题：这次音乐没有顺利生成
  /// - 错误副文案：你可以稍后再试，或者先调整一下歌词。
  /// - 操作按钮：重试生成（需费用确认）/ 返回编辑歌词
  Widget _buildMusicErrorSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.apricot.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.apricotDeep.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 18,
                color: AppColors.apricotDeep,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '这次音乐没有顺利生成',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.apricotDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _musicErrorHint ?? '你可以稍后再试，或者先调整一下歌词。',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          // 操作按钮：重试生成 + 返回编辑歌词
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _onRegenerateSongPressed,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('重试生成', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    backgroundColor: AppColors.apricotDeep.withValues(
                      alpha: 0.85,
                    ),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _returnToEditLyrics,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('编辑歌词', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 存储警告提示卡片：音乐已生成但暂时无法播放。
  ///
  /// P4-temp-audio-playback-1 调整：R2 未配置不再触发此卡片（走 audioDataUrl 临时播放）。
  /// 当前触发条件：R2 上传失败（r2_upload_failed）且 audioDataUrl 也未生成（极端边界情况）。
  /// 文案面向用户友好，不暴露 R2 / storageKey 等技术细节。
  Widget _buildStorageWarningHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '音乐已生成，但暂时无法播放，请稍后再试。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 场景标签文案（P4 第二批）。
  static const Map<String, String> _sceneLabels = {
    'academic_failure': '学业受挫',
    'relationship_conflict': '关系摩擦',
    'work_pressure': '压力疲惫',
    'guilt_regret': '愧疚后悔',
    'default': '此刻心境',
  };

  /// 来源 + 场景标记（P4 第二批：组合显示）。
  Widget _buildBadges(String source, String scene) {
    final isLlm = source == 'llm';
    final sourceLabel = isLlm ? 'AI 生成' : '本地模板';
    final sourceColor = isLlm ? AppColors.tealDeep : AppColors.textMuted;
    final sceneLabel = _sceneLabels[scene] ?? '此刻心境';

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          // 来源标记
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: sourceColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sourceColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              sourceLabel,
              style: TextStyle(
                fontSize: 11,
                color: sourceColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
          // 场景标记（让用户感到"被听懂"）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lavender.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.lavender.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              sceneLabel,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.lavender.withValues(alpha: 0.9),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// songPrompt 卡片（P4 第二批：折叠弱化，默认收起）。
  /// 标题改为「后续生成参数」，避免显得像开发调试工具。
  Widget _buildSongPromptCard(String songPrompt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () =>
                  setState(() => _songPromptExpanded = !_songPromptExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '后续生成参数',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Icon(
                      _songPromptExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 默认收起；点击展开后显示 songPrompt
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _songPromptExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(height: 0, width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SelectableText(
                songPrompt,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 后续提示：告知用户可以点击「生成这首歌（实验）」生成 AI 歌曲。
  ///
  /// P4-generated-audio-playback-1：文案更新，明确告知已可生成 AI 歌曲，
  /// 但仍保留"实验"措辞，让用户理解这是受控开放的功能。
  Widget _buildNextStepHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '下一步可以生成专属歌曲。\n点击下方「生成这首歌（实验）」会发起一次 AI 音乐生成，可能产生调用费用。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// P4-generated-audio-playback-1：JSON 编码辅助函数。
///
/// 使用 dart:convert 的 jsonEncode 编码请求体。
/// 不直接 import dart:convert 是为了在文件顶部统一管理 import，
/// 但为了简洁这里直接使用 dart:convert。
String _jsonEncode(Map<String, dynamic> data) {
  return jsonEncode(data);
}

/// P4-generated-audio-playback-1：JSON 解码辅助函数。
///
/// 解析失败时返回 null（不抛异常，调用方负责处理）。
Map<String, dynamic>? _decodeJson(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  } catch (_) {
    return null;
  }
}

/// 困惑输入框（多行，浅色温柔风格，与 [MoodInputField] 视觉一致）。
class _StoryInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _StoryInputField({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: 4,
      maxLines: 8,
      maxLength: 1000,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
        height: 1.6,
      ),
      decoration: InputDecoration(
        hintText:
            '试着写下你最近遇到的一件事、一个困惑，或者一段心情……\n例如：最近工作压力很大，每天回家都很累，但躺在床上又开始想明天的事，停不下来。',
        hintStyle: const TextStyle(color: AppColors.textMuted, height: 1.6),
        alignLabelWithHint: true,
        filled: true,
        fillColor: AppColors.cardBg,
        counterStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}

/// P4-conversation-song-flow-1 / P4-dynamic-followup-depth-1：多轮对话阶段。
/// fix1：新增 loadingFollowUp 阶段（首轮 LLM 动态追问生成中）。
/// P4-dynamic-followup-depth-1：新增 loadingFollowUpMore 阶段
/// （第 2 个问题答完后，判定是否追加 1-2 个问题）。
enum _ConversationPhase {
  input,
  loadingFollowUp,
  followUp,
  loadingFollowUpMore,
  done,
}

/// 曲风选项数据。
class _StyleOption {
  final String value;
  final String label;
  final String description;

  const _StyleOption({
    required this.value,
    required this.label,
    required this.description,
  });
}

/// 曲风选择 chip。
class _StyleChip extends StatelessWidget {
  final _StyleOption option;
  final bool selected;
  final VoidCallback onTap;

  const _StyleChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.cardBorder;
    final bg = selected
        ? AppColors.primary.withValues(alpha: 0.08)
        : AppColors.cardBg;
    final labelColor = selected ? AppColors.primary : AppColors.chipLabelText;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: selected ? 1.4 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                option.description,
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.7)
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 区块卡片：图标 + 标题 + 内容（用于解惑 / 歌词 / songPrompt）。
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
