import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/models/comfort_lyrics_result.dart';
import 'package:xinxian_healing_music/pipeline/llm/comfort_lyrics_service.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// 「把困惑写成一首歌」页面（P4 新方向第一批）。
///
/// 流程：
/// 1. 用户输入一段困惑/事件/情绪描述
/// 2. 选择期望曲风（4 选 1，默认 gentle_pop）
/// 3. 点击「生成」→ 调用 [ComfortLyricsService] 请求 /api/comfort-lyrics
/// 4. 显示：
///    - 温和解惑文本（comfortInterpretation）
///    - 歌词草稿（lyricDraft，含主歌/副歌/尾声标记）
///    - 后续提示：`下一步将用于生成专属歌曲`（本批不接真实音乐生成）
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
    super.dispose();
  }

  /// 触发生成：调用 [ComfortLyricsService]。
  ///
  /// 任何异常都被 Service 兜底为 fallback，前端不会再 catch 到异常。
  /// 这里仍用 try/catch + _errorHint 作为最后保险，避免任何边界情况导致页面卡死。
  Future<void> _generate() async {
    final story = _storyController.text.trim();
    if (story.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorHint = null;
      _result = null;
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
  void _reset() {
    setState(() {
      _storyController.clear();
      _result = null;
      _errorHint = null;
      _loading = false;
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
          const Text(
            '写下你的困惑',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _StoryInputField(controller: _storyController, focusNode: _storyFocus),

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

          // 生成按钮
          FilledButton.icon(
            onPressed: (_hasStory && !_loading) ? _generate : null,
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

  /// 结果区：来源标记 + 解惑卡片 + 歌词卡片 + 后续提示 + 重置按钮。
  Widget _buildResult(ComfortLyricsResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 来源标记（llm / fallback）
        _buildSourceBadge(result.source),
        const SizedBox(height: 14),

        // 温和解惑
        _SectionCard(
          icon: Icons.favorite_border_rounded,
          title: '温和解惑',
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

        // 歌词草稿
        _SectionCard(
          icon: Icons.music_note_rounded,
          title: '歌词草稿',
          child: SelectableText(
            result.lyricDraft,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.85,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // songPrompt（折叠，作为后续音乐生成的风格提示）
        _buildSongPromptCard(result.songPrompt),
        const SizedBox(height: 18),

        // 后续提示
        _buildNextStepHint(),
        const SizedBox(height: 18),

        // 重置按钮
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text(
            '再写一首',
            style: TextStyle(fontSize: 14),
          ),
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

  /// 来源标记：llm / fallback。
  Widget _buildSourceBadge(String source) {
    final isLlm = source == 'llm';
    final label = isLlm ? 'AI 生成' : '本地模板（AI 暂不可用）';
    final color = isLlm ? AppColors.tealDeep : AppColors.textMuted;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: color, letterSpacing: 0.3),
        ),
      ),
    );
  }

  /// songPrompt 卡片（折叠展开）。
  Widget _buildSongPromptCard(String songPrompt) {
    return _SectionCard(
      icon: Icons.graphic_eq_rounded,
      title: '曲风提示（用于后续歌曲生成）',
      child: SelectableText(
        songPrompt,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.6,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  /// 后续提示：明确告知用户本批不生成真实音频。
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
              '下一步将用于生成专属歌曲。\n当前版本仅生成歌词草稿，暂不调用真实 AI 音乐生成。',
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

/// 困惑输入框（多行，浅色温柔风格，与 [MoodInputField] 视觉一致）。
class _StoryInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _StoryInputField({
    required this.controller,
    required this.focusNode,
  });

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
        hintText: '试着写下你最近遇到的一件事、一个困惑，或者一段心情……\n例如：最近工作压力很大，每天回家都很累，但躺在床上又开始想明天的事，停不下来。',
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          height: 1.6,
        ),
        alignLabelWithHint: true,
        filled: true,
        fillColor: AppColors.cardBg,
        counterStyle: const TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
        ),
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
