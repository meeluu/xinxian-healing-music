import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/screens/player_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/widgets/app_card.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';
import 'package:xinxian_healing_music/widgets/fade_slide_item.dart';
import 'package:xinxian_healing_music/widgets/param_chip.dart';

/// 方案展示页：情绪画像 + 音乐参数 + 引导语 + 进入播放。
/// 卡片以 stagger 方式依次淡入。
class PlanScreen extends StatelessWidget {
  final String moodText;
  final HealingMusicPlan plan;

  const PlanScreen({super.key, required this.moodText, required this.plan});

  @override
  Widget build(BuildContext context) {
    return CenteredPageScaffold(
      appBar: AppBar(title: const Text('疗愈方案')),
      animateEnter: false,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideItem(
            delayMs: 0,
            child: _SectionCard(
              title: '你的心境',
              icon: Icons.format_quote_rounded,
              child: Text(
                '"$moodText"',
                style: const TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          FadeSlideItem(
            delayMs: 70,
            child: _SectionCard(
              title: '情绪画像 · ${plan.templateName}',
              icon: Icons.psychology_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.mood.summary,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in plan.mood.tags)
                        Chip(
                          label: Text(tag),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            color: AppColors.tealDeep,
                          ),
                          backgroundColor: const Color(0xFFE7F4EF),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          FadeSlideItem(
            delayMs: 140,
            child: _SectionCard(
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
                  const Text(
                    '推荐乐器',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
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
          ),
          const SizedBox(height: 14),

          FadeSlideItem(
            delayMs: 210,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF4C7A1), Color(0xFFF8DDC4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.spa_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      plan.guidance,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),
          FadeSlideItem(
            delayMs: 280,
            child: FilledButton.icon(
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
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
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
