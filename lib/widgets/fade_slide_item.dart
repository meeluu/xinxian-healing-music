import 'dart:async';
import 'package:flutter/material.dart';

/// 单元素的淡入动效，用于方案页卡片的依次出现（stagger）。
///
/// - [delayMs] 起始延迟，控制依次进入的节奏。
/// - 仅做 opacity 渐变，不做位移，避免正文/按钮上下浮动。
class FadeSlideItem extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const FadeSlideItem({super.key, required this.child, this.delayMs = 0});

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
        return Opacity(opacity: _anim.value, child: child);
      },
      child: widget.child,
    );
  }
}
