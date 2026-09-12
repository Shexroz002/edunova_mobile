import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/page_app_bar.dart';
import '../../core/widgets/responsive.dart';
import '../analytics/data/analytics_repository.dart';
import '../analytics/domain/analytics_models.dart';

/// Student statistics, laid out like the web `StudentStatisticsPage.tsx`:
/// stat cards, a weekly activity chart, per-subject results and the study
/// advice.
///
/// Two of the web's numbers are invented: `Jami XP` is `sessions × 39`, and the
/// weekly chart is the literal array `[4,7,3,8,5,2,6]`. The XP card is dropped
/// and the chart is computed from the session history instead
/// (`CLAUDE.md` default decisions 1 and 3).
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return Scaffold(
      appBar: const PageAppBar(title: Text('Statistika')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(overallStatsProvider);
          ref.invalidate(subjectStatsProvider);
          ref.invalidate(recommendationProvider);
          ref.invalidate(weeklyActivityProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(context.pagePadding, 0, context.pagePadding, 28),
          children: [
            ContentConstraint(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "O'z natijalaringizni kuzating",
                    style: TextStyle(fontSize: 13, color: c.textMuted),
                  ),
                  const SizedBox(height: 14),
                  const _StatCards(),
                  const SizedBox(height: 16),
                  const _WeeklyChart(),
                  const SizedBox(height: 16),
                  const _SubjectResults(),
                  const SizedBox(height: 16),
                  const _RecommendationCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three real cards; the web's fourth is fabricated XP.
class _StatCards extends ConsumerWidget {
  const _StatCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(overallStatsProvider);
    final value = stats.valueOrNull ?? OverallStats.empty;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline_rounded,
            value: '${value.totalSessions}',
            label: 'Jami testlar',
            color: AppColors.brandLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.track_changes_rounded,
            value: formatPercent(value.averagePercent),
            label: "O'rtacha ball",
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.task_alt_rounded,
            value: '${value.correctAnswers}',
            label: "To'g'ri javoblar",
            color: AppColors.sky,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.tint(color),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Sessions started per day over the last week.
class _WeeklyChart extends ConsumerWidget {
  const _WeeklyChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final activity = ref.watch(weeklyActivityProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, size: 17, color: c.accent),
              const SizedBox(width: 8),
              Text(
                'Haftalik faollik',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Said plainly: history records when a session started, nothing finer.
          Text(
            "Oxirgi 7 kunda boshlangan sessiyalar",
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: activity.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  ApiException.from(e).message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ),
              data: (days) => _ActivityBars(days: days),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityBars extends StatelessWidget {
  const _ActivityBars({required this.days});

  final List<DailyActivity> days;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxCount = days.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    // At most five labels on the left, so tall weeks do not print 0..11, and a
    // top that is a whole number of steps, so the axis ends on a round label.
    final step = (maxCount / 4).ceil().clamp(1, 100).toDouble();
    final rounded = (maxCount / step).ceil() * step;
    final top = rounded <= maxCount ? rounded + step : rounded;

    if (maxCount == 0) {
      return Center(
        child: Text(
          "Oxirgi 7 kunda sessiya bo'lmagan",
          style: TextStyle(fontSize: 13, color: c.textMuted),
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: top,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => c.bgInner,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${days[group.x].label}: ${rod.toY.round()} ta',
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: step,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}',
                style: TextStyle(fontSize: 10, color: c.textMuted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    days[index].label,
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].count.toDouble(),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.brand, Color(0xFF818CF8)],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Correct / wrong split per subject.
class _SubjectResults extends ConsumerWidget {
  const _SubjectResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final subjects = ref.watch(subjectStatsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Fanlar bo'yicha natija",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 14),
          subjects.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text(
              ApiException.from(e).message,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            data: (items) => items.isEmpty
                ? Text(
                    "Hali fan bo'yicha natija yo'q",
                    style: TextStyle(fontSize: 13, color: c.textMuted),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        _SubjectRow(stats: items[i]),
                        if (i < items.length - 1) const SizedBox(height: 14),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.stats});

  final SubjectStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final correctShare = stats.total == 0 ? 0.0 : stats.correct / stats.total;
    final wrongPercent = stats.total == 0 ? 0.0 : stats.wrong * 100 / stats.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stats.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
            ),
            Text(
              '✓ ${formatPercent(stats.percent)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '✗ ${formatPercent(wrongPercent)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(
            children: [
              Expanded(
                flex: (correctShare * 1000).round().clamp(1, 1000),
                child: Container(height: 7, color: AppColors.success),
              ),
              Expanded(
                flex: ((1 - correctShare) * 1000).round().clamp(1, 1000),
                child: Container(height: 7, color: AppColors.tint(AppColors.error, 0x66)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${stats.correct} to‘g‘ri · ${stats.wrong} xato · ${stats.total} jami javob',
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
      ],
    );
  }
}

/// Rule-based study advice with its three blocks.
class _RecommendationCard extends ConsumerWidget {
  const _RecommendationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final recommendation = ref.watch(recommendationProvider);

    return recommendation.when(
      loading: () => const AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (e, _) => AppCard(
        child: Text(
          ApiException.from(e).message,
          style: TextStyle(fontSize: 13, color: c.textSecondary),
        ),
      ),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.accentMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, size: 17, color: c.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                          ),
                        ),
                        if (data.subtitle.isNotEmpty)
                          Text(
                            data.subtitle,
                            style: TextStyle(fontSize: 12, color: c.textMuted),
                          ),
                      ],
                    ),
                  ),
                  if (data.badge != null && data.badge!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.accentMuted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        data.badge!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.accent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (data.strongSides != null)
                _AdviceBlock(
                  block: data.strongSides!,
                  color: AppColors.success,
                  icon: Icons.thumb_up_alt_outlined,
                  action: 'Davom etish',
                  onTap: () => context.push('/tests'),
                ),
              if (data.improvement != null) ...[
                const SizedBox(height: 10),
                _AdviceBlock(
                  block: data.improvement!,
                  color: AppColors.warning,
                  icon: Icons.trending_up_rounded,
                  action: 'Mashq qilish',
                  onTap: () => context.push('/tests'),
                ),
              ],
              if (data.nextGoal != null) ...[
                const SizedBox(height: 10),
                _AdviceBlock(
                  block: data.nextGoal!,
                  color: AppColors.brandLight,
                  icon: Icons.flag_outlined,
                  action: 'Testni boshlash',
                  onTap: () => context.push('/tests'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AdviceBlock extends StatelessWidget {
  const _AdviceBlock({
    required this.block,
    required this.color,
    required this.icon,
    required this.action,
    required this.onTap,
  });

  final RecommendationBlock block;
  final Color color;
  final IconData icon;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0x0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tint(color, 0x33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            block.text,
            style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: color,
              ),
              child: Text(action),
            ),
          ),
        ],
      ),
    );
  }
}
