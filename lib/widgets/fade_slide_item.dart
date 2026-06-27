import 'dart:async';
import 'package:flutter/material.dart';

/// 单元素的淡入 + 轻微上移动效，用于方案页卡片的依次出现（stagger）。
///
/// - [delayMs] 起始延迟，控制依次进入的节奏。
/// - 位移很小，曲线 easeOutCubic，不影响布局（仅 paint-time 变换）。
class FadeSlideItem extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double slidePx;

  const FadeSlideItem({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.slidePx = 10,
  });

  @override
  State<FadeSlideItem> createState() => _FadeSlideItemState();
}

class _FadeSlideItemState extends State<FadeSlideItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final Animation<double> _anim = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Opacity(
          opacity: _anim.value,
          child: Transform.translate(
            offset: Offset(0, widget.slidePx * (1 - _anim.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
