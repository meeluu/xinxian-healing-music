import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/screens/analysis_screen.dart';
import 'package:xinxian_healing_music/widgets/mood_input_field.dart';

/// 首页：输入当前心境描述。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  static const List<String> _examples = [
    '备考压力大，晚上睡不着，脑子停不下来',
    '最近总是提不起劲，感觉很疲惫、很空',
    '和亲人吵架后很烦躁，静不下心',
  ];

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _goAnalyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AnalysisScreen(moodText: text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.18),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  // 品牌标识
                  Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.7),
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 44,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '心弦',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w300,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '自然语言驱动的定制化疗愈音乐',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // 输入区
                  Text(
                    '描述你此刻的心境',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  MoodInputField(controller: _controller, focusNode: _focus),

                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final ex in _examples)
                        ActionChip(
                          label: Text(ex),
                          labelStyle: theme.textTheme.labelSmall,
                          onPressed: () {
                            _controller.text = ex;
                            _controller.selection = TextSelection.collapsed(
                              offset: ex.length,
                            );
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _hasText ? _goAnalyze : null,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '生成专属疗愈方案',
                        style: TextStyle(fontSize: 16, letterSpacing: 1),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Demo 版本 · 全部参数由本地模板生成，不接真实 AI',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
