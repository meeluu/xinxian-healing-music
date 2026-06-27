import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

/// 多行心境输入框，浅色温柔风格。
class MoodInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const MoodInputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: 4,
      maxLines: 8,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 16,
        color: AppColors.textPrimary,
        height: 1.6,
      ),
      decoration: InputDecoration(
        hintText: '试着描述你此刻的心境……\n例如：备考压力大，晚上睡不着，脑子停不下来',
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          height: 1.6,
        ),
        alignLabelWithHint: true,
        filled: true,
        fillColor: AppColors.cardBg,
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
