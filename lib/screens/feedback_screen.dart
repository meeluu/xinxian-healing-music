import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/screens/home_screen.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// 反馈表单页：评分 + 紧绷度前后 + 文字反馈 → 感谢页 → 回首页。
class FeedbackScreen extends StatefulWidget {
  final HealingMusicPlan plan;
  const FeedbackScreen({super.key, required this.plan});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 0;
  double _before = 0.7;
  double _after = 0.4;
  final TextEditingController _note = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _tensionLabel(double v) {
    if (v < 0.2) return '很放松';
    if (v < 0.45) return '较放松';
    if (v < 0.65) return '一般';
    if (v < 0.85) return '较紧绷';
    return '很紧绷';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CenteredPageScaffold(
      appBar: AppBar(
        title: const Text('体验反馈'),
        centerTitle: true,
        automaticallyImplyLeading: !_submitted,
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: _submitted ? _buildThanks(theme) : _buildForm(theme),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '方案：${widget.plan.templateName}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        // 评分
        Text('整体体验评分', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () => setState(() => _rating = i),
                icon: Icon(
                  i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 40,
                ),
                color: i <= _rating
                    ? const Color(0xFFE8B547)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // 紧绷度前后
        Text('感受一下你的紧绷度变化', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '拖动两条滑块，记录体验前后的状态',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 16),
        _TensionSlider(
          label: '体验前',
          value: _before,
          color: const Color(0xFFE07A6B),
          onChanged: (v) => setState(() => _before = v),
          textLabel: _tensionLabel(_before),
        ),
        const SizedBox(height: 12),
        _TensionSlider(
          label: '体验后',
          value: _after,
          color: theme.colorScheme.primary,
          onChanged: (v) => setState(() => _after = v),
          textLabel: _tensionLabel(_after),
        ),
        const SizedBox(height: 24),

        // 文字反馈
        Text('想说点什么（可选）', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: '这段旋律让你想到了什么？身体有什么感受？',
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 28),

        FilledButton.icon(
          onPressed: _rating == 0
              ? null
              : () => setState(() => _submitted = true),
          icon: const Icon(Icons.send_rounded),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('提交反馈'),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Demo 版本 · 反馈仅保存在内存，不会上传任何服务器',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildThanks(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '感谢你的反馈',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '你的感受已被听见。\n愿这一段旋律，陪你慢慢回到自己。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),
        FilledButton(
          onPressed: () {
            // 回到首页并清空栈
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('回到首页'),
        ),
      ],
    );
  }
}

class _TensionSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;
  final String textLabel;

  const _TensionSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
    required this.textLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              textLabel,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          min: 0.0,
          max: 1.0,
        ),
      ],
    );
  }
}
