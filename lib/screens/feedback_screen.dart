import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/screens/home_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';

/// 反馈表单页：评分 + 紧绷度前后 + 文字反馈 → 柔和淡入感谢页 → 回首页。
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
    return CenteredPageScaffold(
      appBar: AppBar(
        title: const Text('体验反馈'),
        automaticallyImplyLeading: !_submitted,
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      // 提交后切换内容时用柔和淡入，关闭顶层入场动效避免重复
      animateEnter: !_submitted,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 480),
        switchInCurve: Curves.easeOutCubic,
        child: _submitted
            ? _buildThanks(Key('thanks'))
            : _buildForm(Key('form')),
      ),
    );
  }

  Widget _buildForm(Key key) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '方案：${widget.plan.templateName}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),

        // 评分
        const Text(
          '整体体验评分',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
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
                    ? const Color(0xFFE7A86A)
                    : const Color(0xFFCBD5E1),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // 紧绷度前后
        const Text(
          '感受一下你的紧绷度变化',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '拖动两条滑块，记录体验前后的状态',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _TensionSlider(
          label: '体验前',
          value: _before,
          activeColor: const Color(0xFFE7A86A),
          onChanged: (v) => setState(() => _before = v),
          textLabel: _tensionLabel(_before),
        ),
        const SizedBox(height: 12),
        _TensionSlider(
          label: '体验后',
          value: _after,
          activeColor: AppColors.teal,
          onChanged: (v) => setState(() => _after = v),
          textLabel: _tensionLabel(_after),
        ),
        const SizedBox(height: 24),

        // 文字反馈
        const Text(
          '想说点什么（可选）',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: '这段旋律让你想到了什么？身体有什么感受？',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.4,
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
          icon: const Icon(Icons.send_rounded, size: 20),
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
        const Text(
          'Demo 版本 · 反馈仅保存在内存，不会上传任何服务器',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildThanks(Key key) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.teal.withValues(alpha: 0.15),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 56,
            color: AppColors.teal,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '感谢你的反馈',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '你的感受已被听见。\n愿这一段旋律，陪你慢慢回到自己。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 40),
        FilledButton(
          onPressed: () {
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
  final Color activeColor;
  final ValueChanged<double> onChanged;
  final String textLabel;

  const _TensionSlider({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
    required this.textLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              textLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: activeColor,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
          inactiveColor: AppColors.cardBorder,
          min: 0.0,
          max: 1.0,
        ),
      ],
    );
  }
}
