import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/screens/player_screen.dart';
import 'package:xinxian_healing_music/widgets/param_chip.dart';

/// 方案展示页：情绪画像 + 音乐参数 + 引导语 + 进入播放。
class PlanScreen extends StatelessWidget {
  final String moodText;
  final HealingMusicPlan plan;

  const PlanScreen({super.key, required this.moodText, required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('疗愈方案'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 原始心境
              _SectionCard(
                theme: theme,
                title: '你的心境',
                icon: Icons.format_quote_rounded,
                child: Text(
                  '"$moodText"',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 情绪画像
              _SectionCard(
                theme: theme,
                title: '情绪画像 · ${plan.templateName}',
                icon: Icons.psychology_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.mood.summary, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in plan.mood.tags)
                          Chip(
                            label: Text(tag),
                            labelStyle: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                            backgroundColor: theme
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.7),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 音乐参数
              _SectionCard(
                theme: theme,
                title: '音乐参数',
                icon: Icons.tune_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ParamChip(
                          label: 'BPM',
                          value: '${plan.bpm}',
                          icon: Icons.favorite_rounded,
                        ),
                        ParamChip(
                          label: '基准频率',
                          value: plan.frequency,
                          icon: Icons.graphic_eq_rounded,
                        ),
                        ParamChip(
                          label: '脑波倾向',
                          value: plan.brainwave,
                          icon: Icons.waves_rounded,
                        ),
                        ParamChip(
                          label: '和声色彩',
                          value: plan.harmony,
                          icon: Icons.music_note_rounded,
                        ),
                        ParamChip(
                          label: '噪声层',
                          value: plan.noiseLayer,
                          icon: Icons.cloud_rounded,
                        ),
                        ParamChip(
                          label: '推荐时长',
                          value: '${plan.durationMinutes} 分钟',
                          icon: Icons.timer_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('推荐乐器', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ins in plan.instruments)
                          Chip(
                            label: Text(ins),
                            avatar: const Icon(Icons.music_note, size: 16),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 引导语
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.18),
                      theme.colorScheme.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.spa_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        plan.guidance,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PlayerScreen(plan: plan, moodText: moodText),
                    ),
                  );
                },
                icon: const Icon(Icons.play_circle_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '进入疗愈播放',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.theme,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
