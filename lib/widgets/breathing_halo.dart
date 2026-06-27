import 'package:flutter/material.dart';

/// 极轻的呼吸光晕：缓慢缩放 + 透明度起伏。
///
/// 用于首页品牌区域，营造"被陪伴"的呼吸氛围。
/// 周期默认 4s，颜色透明度很低，不会闪烁或抢戏。
///
/// 布局解耦：外层用固定尺寸 [SizedBox] 占位，内部所有动画都用
/// `Transform.scale` / 固定尺寸 Container（paint-time 变换），
/// 绝不改变 width/height，因此不会挤压父布局、不会让下方文字上下浮动。
class BreathingHalo extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const BreathingHalo({
    super.key,
    required this.color,
    this.size = 170,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<BreathingHalo> createState() => _BreathingHaloState();
}

class _BreathingHaloState extends State<BreathingHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 固定布局尺寸：父级只会看到这个固定的 size×size 占位，
    // 内部动画全部用 Transform.scale（paint-time），不会改变布局。
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value; // 0..1..0
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 外层柔光：Transform.scale 缩放（不影响布局）
              Transform.scale(
                scale: 0.85 + t * 0.3,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.06 + t * 0.07),
                  ),
                ),
              ),
              // 内层底色（固定尺寸）
              Container(
                width: widget.size * 0.62,
                height: widget.size * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.05),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
