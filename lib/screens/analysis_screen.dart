import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/screens/plan_screen.dart';
import 'package:xinxian_healing_music/services/mood_analyzer.dart';

/// 解析动画页：模拟 1.8s 情绪解析后跳转方案页。
class AnalysisScreen extends StatefulWidget {
  final String moodText;
  const AnalysisScreen({super.key, required this.moodText});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  final List<String> _lines = ['正在聆听你的心声…', '解析情绪画像…', '匹配音乐参数…', '生成疗愈方案…'];
  int _lineIndex = 0;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    Future(() async {
      for (var i = 0; i < _lines.length; i++) {
        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        setState(() => _lineIndex = i);
      }
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      final plan = const MoodAnalyzer().analyze(widget.moodText);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PlanScreen(moodText: widget.moodText, plan: plan),
        ),
      );
    });
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.25),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _breath,
                builder: (context, child) {
                  final scale = 0.85 + _breath.value * 0.45;
                  return Opacity(
                    opacity: 0.5 + _breath.value * 0.5,
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.spa_rounded,
                    size: 60,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _lines[_lineIndex],
                  key: ValueKey(_lineIndex),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
