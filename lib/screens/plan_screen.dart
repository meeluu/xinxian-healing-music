import 'package:flutter/material.dart';
import 'package:xinxian_healing_music/models/music_plan.dart';
import 'package:xinxian_healing_music/screens/music_generation_screen.dart';
import 'package:xinxian_healing_music/screens/player_screen.dart';
import 'package:xinxian_healing_music/theme/app_colors.dart';
import 'package:xinxian_healing_music/utils/recommendation_reason.dart';
import 'package:xinxian_healing_music/widgets/app_card.dart';
import 'package:xinxian_healing_music/widgets/centered_page.dart';
import 'package:xinxian_healing_music/widgets/fade_slide_item.dart';
import 'package:xinxian_healing_music/widgets/instrument_chip.dart';
import 'package:xinxian_healing_music/widgets/param_chip.dart';

/// 方案展示页：情绪画像 + 推荐理由 + 音乐参数（默认折叠） + 引导语 + 进入播放。
///
/// P2-Web-v1.0 第二批：
/// - 默认只展示推荐音频标题、推荐时长、推荐理由、主要音乐目标
/// - 技术参数（BPM / 频率 / 脑波 / 和声 / 噪声 / 乐器）折叠到"查看音乐参数"
/// - 卡片以 stagger 方式依次淡入
class PlanScreen extends StatefulWidget {
  final String moodText;
  final HealingMusicPlan plan;

  const PlanScreen({super.key, required this.moodText, required this.plan});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  /// 技术参数默认折叠。用户点击"查看音乐参数"后展开。
  bool _showParams = false;

  HealingMusicPlan get _plan => widget.plan;

  /// P2-Web-v1.0 第二批 fix1：推荐理由优先结合用户原始输入 / summary / tags /
  /// dominantNeed 按场景关键词生成，未命中再 fallback 到 targetState 模板。
  /// 详见 lib/utils/recommendation_reason.dart。
  String get _reasonText => buildRecommendationReason(_plan, widget.moodText);

  /// 主要音乐目标的简短标签，与播放页共用 goalLabelFor 保持一致。
  String get _goalLabel => goalLabelFor(_plan.mood.targetState);

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
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
                '"${widget.moodText}"',
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
              title: '情绪画像',
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

          // P2-Web-v1.0 第二批：新增"为什么推荐这段音乐"卡片
          // 默认展示推荐理由 + 主要音乐目标 + 推荐时长 + 匹配音频标题
          FadeSlideItem(
            delayMs: 140,
            child: _SectionCard(
              title: '为什么推荐这段音乐',
              icon: Icons.recommend_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _reasonText,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetaTag(icon: Icons.spa_rounded, label: _goalLabel),
                      _MetaTag(
                        icon: Icons.timer_rounded,
                        label: '${plan.durationMinutes} 分钟',
                      ),
                    ],
                  ),
                  if (plan.audio.title.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.music_note_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '推荐音频：',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            plan.audio.title,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // P2-Web-v1.0 第二批：技术参数默认折叠
          // 用户点击"查看音乐参数"后展开 BPM / 频率 / 脑波 / 和声 / 噪声 / 乐器
          FadeSlideItem(
            delayMs: 210,
            child: _SectionCard(
              title: '音乐参数',
              icon: Icons.tune_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() => _showParams = !_showParams);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showParams
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showParams ? '收起音乐参数' : '查看音乐参数',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    crossFadeState: _showParams
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ParamChip(
                                label: 'BPM',
                                value: '${plan.features.bpm}',
                                icon: Icons.favorite_rounded,
                              ),
                              ParamChip(
                                label: '基准频率',
                                value: plan.features.frequency,
                                icon: Icons.graphic_eq_rounded,
                              ),
                              ParamChip(
                                label: '脑波倾向',
                                value: plan.features.brainwave,
                                icon: Icons.waves_rounded,
                              ),
                              ParamChip(
                                label: '和声色彩',
                                value: plan.features.harmony,
                                icon: Icons.music_note_rounded,
                              ),
                              ParamChip(
                                label: '噪声层',
                                value: plan.features.noiseLayer,
                                icon: Icons.cloud_rounded,
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
                              for (final ins in plan.features.instruments)
                                InstrumentChip(label: ins),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          FadeSlideItem(
            delayMs: 280,
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
            delayMs: 350,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PlayerScreen(plan: plan, moodText: widget.moodText),
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
          const SizedBox(height: 12),
          // P4.3 新增：AI 音乐生成实验入口（默认折叠，不阻塞预置音频体验）
          FadeSlideItem(
            delayMs: 420,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MusicGenerationScreen(
                      plan: plan,
                      moodText: widget.moodText,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(
                '生成专属音乐（实验）',
                style: TextStyle(fontSize: 14, letterSpacing: 0.5),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDeep,
                minimumSize: const Size.fromHeight(44),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
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

/// 推荐理由区的元信息标签（音乐目标 / 推荐时长）。
/// 比 ParamChip 更轻量，不带"参数"语义。
class _MetaTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F1F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primaryDeep,
              fontWeight: FontWeight.w500,
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
