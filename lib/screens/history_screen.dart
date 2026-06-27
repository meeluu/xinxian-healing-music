import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/models/experiment_variant.dart';
import 'package:xinxian_healing_music/models/listening_session.dart';
import 'package:xinxian_healing_music/pipeline/services.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// 历史记录页：展示本地持久化的 ListeningSession 列表。
///
/// - 列表按 startedAt 倒序（最新在上）
/// - 单条支持滑动删除 / 点击删除按钮，并提供 SnackBar 撤销
/// - 右上角"清空"按钮带二次确认对话框
/// - 默认显示心境文本前 24 字摘要，点击卡片展开全文
///
/// 数据全部来自本地 shared_preferences，不上传任何服务器。
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ListeningSession> _sessions = const [];
  // 已展开心境全文的 sessionId 集合
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final all = sessionRecorder.all();
    debugPrint(
      '[M3] history _reload: recorder type=${sessionRecorder.runtimeType}, '
      'all().length=${all.length}',
    );
    setState(() {
      _sessions = all;
    });
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _variantLabel(ExperimentVariant v) {
    switch (v) {
      case ExperimentVariant.custom:
        return '个性化';
      case ExperimentVariant.generic:
        return '通用';
      case ExperimentVariant.control:
        return '对照';
    }
  }

  String _moodSummary(String text) {
    if (text.length <= 24) return text;
    return '${text.substring(0, 24)}…';
  }

  Future<void> _deleteOne(ListeningSession session) async {
    // 先从内存缓存移除并刷新 UI，再异步落盘
    await sessionRecorder.delete(session.sessionId);
    await feedbackRepository.delete(session.sessionId);
    if (!mounted) return;
    _reload();

    // 提供 5 秒撤销窗口：把刚删除的 session 完整写回
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已删除该条记录'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            // 重新 begin 还原 session（plan 快照已保留）
            sessionRecorder.begin(
              sessionId: session.sessionId,
              moodText: session.moodText,
              plan: session.plan,
            );
            // 还原聆听时长与反馈
            sessionRecorder.updateListening(
              session.sessionId,
              session.listenedDuration,
            );
            if (session.feedback != null) {
              await feedbackRepository.save(session.feedback!);
              sessionRecorder.attachFeedback(
                session.sessionId,
                session.feedback!,
              );
            }
            if (!mounted) return;
            _reload();
          },
        ),
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    if (_sessions.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部历史记录'),
        content: const Text('所有心境文本、方案与反馈将从本设备永久删除，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await sessionRecorder.clear();
    await feedbackRepository.clear();
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return CenteredPageScaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              tooltip: '清空全部',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: _sessions.isEmpty
          ? _buildEmpty()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    '仅保存在本设备 · 可随时删除',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                for (final s in _sessions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SessionCard(
                      session: s,
                      expanded: _expanded.contains(s.sessionId),
                      fmtTime: _fmtTime,
                      fmtDuration: _fmtDuration,
                      variantLabel: _variantLabel,
                      moodSummary: _moodSummary,
                      onToggleExpand: () {
                        setState(() {
                          if (_expanded.contains(s.sessionId)) {
                            _expanded.remove(s.sessionId);
                          } else {
                            _expanded.add(s.sessionId);
                          }
                        });
                      },
                      onDelete: () => _deleteOne(s),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.history_rounded, size: 64, color: AppColors.textMuted),
        SizedBox(height: 16),
        Text(
          '还没有历史记录',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '你的每一次体验都会安全地保存在本设备',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// 单条历史记录卡片。
class _SessionCard extends StatelessWidget {
  final ListeningSession session;
  final bool expanded;
  final String Function(DateTime) fmtTime;
  final String Function(Duration) fmtDuration;
  final String Function(ExperimentVariant) variantLabel;
  final String Function(String) moodSummary;
  final VoidCallback onToggleExpand;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.expanded,
    required this.fmtTime,
    required this.fmtDuration,
    required this.variantLabel,
    required this.moodSummary,
    required this.onToggleExpand,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Dismissible(
      key: ValueKey('session-${s.sessionId}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE07A6B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFE07A6B),
        ),
      ),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onToggleExpand,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：时间 + variant 标签
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      fmtTime(s.startedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    _VariantChip(label: variantLabel(s.variant)),
                  ],
                ),
                const SizedBox(height: 10),

                // 第二行：心境文本（摘要 / 全文）
                Text(
                  expanded ? s.moodText : moodSummary(s.moodText),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                if (s.moodText.length > 24)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      expanded ? '收起' : '展开全文',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // 第三行：方案名 + 聆听时长 + 评分
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        s.plan.templateName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.chipLabelText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.headphones_rounded,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      s.listenedDuration > Duration.zero
                          ? fmtDuration(s.listenedDuration)
                          : '--:--',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (s.feedback != null) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: const Color(0xFFE7A86A),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${s.feedback!.rating}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // 第四行：删除按钮
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    label: const Text(
                      '删除',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// variant 小标签 chip。
class _VariantChip extends StatelessWidget {
  final String label;
  const _VariantChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.primaryDeep),
      ),
    );
  }
}
