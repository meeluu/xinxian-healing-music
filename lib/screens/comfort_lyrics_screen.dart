import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:xinxian_healing_music/models/comfort_lyrics_result.dart';
import 'package:xinxian_healing_music/pipeline/llm/comfort_lyrics_service.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// 「把困惑写成一首歌」页面（P4 新方向第一/二/三批 + P4 生成音频落地播放）。
///
/// 流程：
/// 1. 用户输入一段困惑/事件/情绪描述
/// 2. 选择期望曲风（4 选 1，默认 gentle_pop）
/// 3. 点击「生成」→ 调用 [ComfortLyricsService] 请求 /api/comfort-lyrics
/// 4. 显示：
///    - 温和解惑文本（comfortInterpretation）
///    - 歌词草稿（lyricDraft，含主歌/副歌/尾声标记）
///    - 后续提示：`下一步将用于生成专属歌曲`（本批不接真实音乐生成）
/// 5. P4 第三批：用户可「编辑歌词」并保存/取消；底部新增「生成这首歌（即将开放）」占位按钮
/// 6. P4-generated-audio-playback-1：「生成这首歌」改为受控实验入口
///    - 文案改为「生成这首歌（实验）」
///    - 点击前必须确认"会发起一次 AI 音乐生成，可能产生调用费用"
///    - 调用 /api/generate-music（带 manualTest=true，受后端三重门保护）
///    - 成功拿到 generatedAudioUrl 后在页面内嵌简洁播放区
///    - 拿到 storageKey 但无 URL 时提示"音乐已生成并保存，播放地址配置后可试听"
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
  // - 成功拿到 generatedAudioUrl 后初始化 _generatedAudioPlayer，显示播放区
  // - 拿到 storageKey 但无 URL（storageWarning=r2_not_configured）时显示已保存提示
  // - 失败时显示友好错误，不影响其他流程
  // - 点击「再写一首」时清空所有生成歌曲状态（停止播放 + 释放播放器）

  /// 是否正在调用 /api/generate-music 生成 AI 歌曲。
  bool _generatingMusic = false;

  /// AI 生成歌曲的可播放 URL（来自后端 generatedAudioUrl 字段，相对路径如 /api/generated-music?key=...）。
  /// null 表示尚未生成或生成失败。
  String? _generatedAudioUrl;

  /// AI 生成歌曲的存储警告（r2_not_configured / r2_upload_failed）。
  /// 用于区分"已生成保存但无 URL"和"完全失败"两种情况。
  String? _storageWarning;

  /// AI 生成歌曲的错误提示（仅用于 UI 显示，不暴露内部异常）。
  String? _musicErrorHint;

  /// AI 生成歌曲的简短元信息（如"AI 生成 · soothe"），显示在播放区。
  String? _generatedMusicMeta;

  /// AI 生成歌曲播放器（懒加载，仅在拿到 generatedAudioUrl 后初始化）。
  AudioPlayer? _generatedAudioPlayer;

  /// 播放器状态订阅（用于驱动 UI 刷新播放/暂停按钮）。
  StreamSubscription<PlayerState>? _generatedPlayerStateSub;

  /// 播放器当前是否正在播放（驱动 UI 刷新）。
  bool _isPlayingGenerated = false;

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
  }

  @override
  void dispose() {
    _storyController.dispose();
    _storyFocus.dispose();
    _editingController.dispose();
    _editingFocus.dispose();
    // P4-generated-audio-playback-1：释放 AI 生成歌曲播放器
    _generatedPlayerStateSub?.cancel();
    _generatedAudioPlayer?.dispose();
    super.dispose();
  }

  /// 触发生成：调用 [ComfortLyricsService]。
  ///
  /// 任何异常都被 Service 兜底为 fallback，前端不会再 catch 到异常。
  /// 这里仍用 try/catch + _errorHint 作为最后保险，避免任何边界情况导致页面卡死。
  Future<void> _generate() async {
    final story = _storyController.text.trim();
    // 编辑态时不允许重复生成，避免覆盖用户正在编辑的歌词
    if (story.isEmpty || _loading || _isEditing) return;
    FocusScope.of(context).unfocus();

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

  /// 重置：清空输入和结果，回到初始态。
  ///
  /// P4 第三批：同时清空编辑状态（_isEditing / _editedLyric / 编辑控制器）。
  /// P4-generated-audio-playback-1：同时清空 AI 生成歌曲状态（停止播放 + 释放播放器）。
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
      _generatedAudioUrl = null;
      _storageWarning = null;
      _musicErrorHint = null;
      _generatedMusicMeta = null;
      _isPlayingGenerated = false;
    });
    // 停止并释放上一首生成歌曲的播放器（异步清理，不阻塞 UI）
    _generatedPlayerStateSub?.cancel();
    _generatedPlayerStateSub = null;
    _generatedAudioPlayer?.stop();
    _generatedAudioPlayer?.dispose();
    _generatedAudioPlayer = null;
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
          // 顶部说明
          const Text(
            '把你最近遇到的一件事、一个困惑，或者一段心情写下来。\n心弦会陪你把它重新看一遍，并写成一首属于你的歌。',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 20),

          // 输入区
          // P4 前端结构调整第一批：标题从「写下你的困惑」改为「先说说卡住你的事」，
          // 更温和、更像产品体验，不像技术说明。
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

          // 生成按钮（P4 第三批：编辑态时禁用，避免覆盖正在编辑的歌词）
          FilledButton.icon(
            onPressed: (_hasStory && !_loading && !_isEditing)
                ? _generate
                : null,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 20),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _loading ? '正在生成…' : '生成解惑与歌词草稿',
                style: const TextStyle(fontSize: 16, letterSpacing: 1),
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // 错误态
          if (_errorHint != null) ...[
            const SizedBox(height: 16),
            _buildErrorHint(),
          ],

          // 结果区
          if (_result != null) ...[
            const SizedBox(height: 28),
            _buildResult(_result!),
          ],
        ],
      ),
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

        // P4-generated-audio-playback-1：生成这首歌受控实验入口
        _buildGenerateSongButton(),
        const SizedBox(height: 14),

        // P4-generated-audio-playback-1：AI 生成歌曲播放区 / 状态提示
        if (_musicErrorHint != null) ...[
          _buildMusicErrorHint(),
          const SizedBox(height: 14),
        ],
        if (_storageWarning != null && _generatedAudioUrl == null) ...[
          _buildStorageWarningHint(),
          const SizedBox(height: 14),
        ],
        if (_generatedAudioUrl != null) ...[
          _buildGeneratedSongPlayer(),
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
  Widget _buildGenerateSongButton() {
    final disabled = _isEditing || _generatingMusic;
    return FilledButton.icon(
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
          _generatingMusic ? '正在生成这首歌…' : '生成这首歌（实验）',
          style: const TextStyle(fontSize: 15, letterSpacing: 0.5),
        ),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: AppColors.lavender.withValues(alpha: 0.85),
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.lavender.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  /// 响应处理：
  /// - ok:true + generatedAudioUrl → 初始化播放器，显示播放区
  /// - ok:true + storageWarning=r2_not_configured → 显示"音乐已生成并保存，播放地址配置后可试听"
  /// - ok:false → 显示"生成没有完成，请稍后再试"
  /// - 网络异常 → 显示"生成没有完成，请稍后再试"
  Future<void> _callGenerateMusicApi() async {
    final result = _result!;
    final lyrics = (_editedLyric ?? result.lyricDraft);
    final songPrompt = result.songPrompt;

    setState(() {
      _generatingMusic = true;
      _musicErrorHint = null;
      _storageWarning = null;
      _generatedAudioUrl = null;
      _generatedMusicMeta = null;
      _isPlayingGenerated = false;
    });

    // 清理上一首播放器（如果有）
    _generatedPlayerStateSub?.cancel();
    _generatedPlayerStateSub = null;
    _generatedAudioPlayer?.stop();
    _generatedAudioPlayer?.dispose();
    _generatedAudioPlayer = null;

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
      final storageWarning = body['storageWarning'] as String?;
      final provider = body['provider'] as String?;

      if (!ok) {
        // 后端返回 fallback（realCallsEnabled=false 或 manualTest 未通过或 MiniMax 调用失败）
        setState(() {
          _generatingMusic = false;
          _musicErrorHint = '生成没有完成，请稍后再试';
        });
        return;
      }

      // ok=true：MiniMax 真实调用成功
      if (generatedAudioUrl != null && generatedAudioUrl.isNotEmpty) {
        // 拿到可播放 URL → 初始化播放器
        await _initGeneratedAudioPlayer(
          generatedAudioUrl,
          provider ?? 'minimax_music',
        );
        if (!mounted) return;
        setState(() {
          _generatingMusic = false;
          _generatedAudioUrl = generatedAudioUrl;
          _generatedMusicMeta = 'AI 生成 · $targetState';
          _storageWarning = null;
          _musicErrorHint = null;
        });
      } else if (storageWarning != null) {
        // 拿到 storageKey 但无 URL（R2 未配置 / 上传失败）
        setState(() {
          _generatingMusic = false;
          _storageWarning = storageWarning;
          _generatedMusicMeta = 'AI 生成 · $targetState';
          _generatedAudioUrl = null;
          _musicErrorHint = null;
        });
      } else {
        // 既无 URL 也无 storageWarning → 边界情况，显示通用提示
        setState(() {
          _generatingMusic = false;
          _musicErrorHint = '生成没有完成，请稍后再试';
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

  /// 初始化 AI 生成歌曲播放器。
  ///
  /// generatedAudioUrl 是相对路径（如 /api/generated-music?key=...），
  /// Web 端通过 Uri.base.resolve() 解析为绝对 URL。
  /// 使用 just_audio 的 AudioSource.uri 加载（支持任意 HTTP URL）。
  Future<void> _initGeneratedAudioPlayer(
    String generatedAudioUrl,
    String provider,
  ) async {
    _generatedAudioPlayer = AudioPlayer();
    try {
      final absoluteUrl = Uri.base.resolve(generatedAudioUrl);
      await _generatedAudioPlayer!.setAudioSource(AudioSource.uri(absoluteUrl));
      _generatedPlayerStateSub = _generatedAudioPlayer!.playerStateStream
          .listen((state) {
            if (!mounted) return;
            setState(() {
              _isPlayingGenerated = state.playing;
            });
          });
    } catch (_) {
      // 加载失败：释放播放器，显示错误
      _generatedAudioPlayer?.dispose();
      _generatedAudioPlayer = null;
      if (!mounted) return;
      setState(() {
        _musicErrorHint = '音频已生成，但加载失败，请稍后再试';
      });
    }
  }

  /// 切换 AI 生成歌曲播放/暂停。
  Future<void> _toggleGeneratedAudio() async {
    final player = _generatedAudioPlayer;
    if (player == null) return;
    try {
      if (_isPlayingGenerated) {
        await player.pause();
      } else {
        // 如果播放已完成（completed），先 seek 到开头
        if (player.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
        }
        await player.play();
      }
    } catch (_) {
      // 忽略单次操作异常，不打断用户
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

  /// AI 生成歌曲播放区（P4-generated-audio-playback-1）。
  ///
  /// 简洁内嵌播放区，不进入 PlayerScreen（避免构造完整 HealingMusicPlan）。
  /// 包含：
  /// - 标题行：图标 + "你的 AI 生成歌曲" + 元信息
  /// - 播放/暂停按钮（圆形大按钮）
  /// - 简短说明：这是 AI 实验生成的歌曲
  Widget _buildGeneratedSongPlayer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lavender.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                size: 18,
                color: AppColors.lavender,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '你的 AI 生成歌曲',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_generatedMusicMeta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _generatedMusicMeta!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.lavender.withValues(alpha: 0.9),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Material(
                color: AppColors.lavender,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _toggleGeneratedAudio,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _isPlayingGenerated
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _isPlayingGenerated ? '正在播放…' : '点击播放，听一下这首属于你的歌',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// AI 生成歌曲错误提示卡片。
  Widget _buildMusicErrorHint() {
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
              _musicErrorHint!,
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

  /// 存储警告提示卡片：音乐已生成保存但播放地址未配置。
  ///
  /// 触发条件：后端返回 storageWarning=r2_not_configured 或 r2_upload_failed。
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
              '音乐已生成并保存，播放地址配置后可试听。',
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
