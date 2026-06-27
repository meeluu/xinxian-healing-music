import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';

/// 推荐乐器展示芯片：浅青绿底 + 青绿图标，用于方案页"推荐乐器"区。
///
/// 尺寸与 [ParamChip] 一致（minWidth 112 / minHeight 48），
/// 保证同组 chip 高度与宽度协调，避免长短不一。
/// 文字一律实色，不做渐变 / 透明遮罩。
class InstrumentChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const InstrumentChip({
    super.key,
    required this.label,
    this.icon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112, minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgMint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppColors.tealDeep),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.chipLabelText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
