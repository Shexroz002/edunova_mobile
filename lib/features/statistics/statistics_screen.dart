import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/subject_style.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/page_app_bar.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/state_views.dart';
import '../analytics/data/analytics_repository.dart';
import '../analytics/domain/analytics_models.dart';
import '../analytics/presentation/subject_list.dart';
import '../tests/presentation/start_test_sheet.dart';
import 'widgets/advice_block.dart';
import 'widgets/weekly_chart.dart';

/// Student statistics: the three totals, the week, the subjects and the advice.
///
/// Two of the web's numbers are invented: `Jami XP` is `sessions × 39`, and the
/// weekly chart is the literal array `[4,7,3,8,5,2,6]`. The XP card is dropped
/// and the chart is computed from the session history instead
/// (`CLAUDE.md` default decisions 1 and 3).
///
/// The page used to state each fact several times — a subject's score as
/// `✓59% ✗41%`, a two-tone bar and "22 to'g'ri · 15 xato · 37 jami javob" — and
/// nothing on it could be acted on: it named the weakest subject and left the
/// student to go back to the home page to practise it. Now every subject row
/// starts a test in its own subject, as on the home page.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  /// Opens the start sheet filtered to [subject], then the play screen.
  static Future<void> _practise(BuildContext context, String subject) async {
    final sessionId = await showStartTestSheet(context, subject: subject);
    if (sessionId != null && context.mounted) context.push('/session/$sessionId/play');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectStatsProvider);
    final rows = SubjectList.ordered(subjects.valueOrNull ?? const []);
    final blank = subjects.hasValue && rows.isEmpty;

    return Scaffold(
      appBar: const PageAppBar(title: Text('Statistika')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(overallStatsProvider);
            ref.invalidate(subjectStatsProvider);
            ref.invalidate(recommendationProvider);
            ref.invalidate(weeklyActivityProvider);
          },
          child: blank
              ? const _Blank()
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding,
                    12,
                    context.pagePadding,
                    28,
                  ),
                  children: [
                    ContentConstraint(
                      maxWidth: 760,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Totals(),
                          const SizedBox(height: 10),
                          const _Week(),
                          const SizedBox(height: 10),
                          _Subjects(subjects: subjects, rows: rows),
                          const SizedBox(height: 10),
                          _Advice(weakest: rows.isEmpty ? null : rows.first.subject),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The three real numbers from `analytics/overall/cards`.
class _Totals extends ConsumerWidget {
  const _Totals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(overallStatsProvider);
    final value = stats.valueOrNull ?? OverallStats.empty;
    final loading = stats.isLoading;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Tile(
              value: formatPercent(value.averagePercent),
              label: "O‘rtacha ball",
              loading: loading,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _Tile(
              value: '${value.totalSessions}',
              // "Jami testlar" counted sessions the student walked away from
              // as well, which the weekly chart now separates out.
              label: 'Sessiya',
              loading: loading,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _Tile(
              value: '${value.correctAnswers}',
              label: "To‘g‘ri javob",
              loading: loading,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, required this.loading});

  final String value;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loading ? '—' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, height: 1.2, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Week extends ConsumerWidget {
  const _Week();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(weeklyActivityProvider);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
      child: activity.when(
        loading: () => const SizedBox(
          height: 150,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => ErrorBanner(ApiException.from(e).message),
        data: (days) => WeeklyChart(days: days),
      ),
    );
  }
}

class _Subjects extends StatelessWidget {
  const _Subjects({required this.subjects, required this.rows});

  final AsyncValue<List<SubjectStats>> subjects;
  final List<SubjectStats> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Fanlar bo‘yicha',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Eng past ko‘rsatkichdan boshlab',
            style: TextStyle(fontSize: 11.5, color: c.textMuted),
          ),
          const SizedBox(height: 9),
          subjects.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorBanner(ApiException.from(e).message),
            data: (_) => SubjectList(
              subjects: rows,
              showCounts: true,
              tint: c.bgInner,
              onPractise: (subject) => StatisticsScreen._practise(context, subject),
            ),
          ),
        ],
      ),
    );
  }
}

/// Study advice, each block clamped until it is opened.
class _Advice extends ConsumerWidget {
  const _Advice({required this.weakest});

  /// Subject the "improvement" and "next goal" blocks talk about.
  final String? weakest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final advice = ref.watch(recommendationProvider);
    final data = advice.valueOrNull;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    final subject = weakest;
    final practise = subject == null
        ? null
        : () => StatisticsScreen._practise(context, subject);
    final name = SubjectStyle.displayName(subject);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            data.title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: c.textPrimary,
            ),
          ),
          if (data.subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              data.subtitle,
              style: TextStyle(fontSize: 11.5, color: c.textMuted),
            ),
          ],
          const SizedBox(height: 9),
          if (data.strongSides != null)
            AdviceBlock(
              block: data.strongSides!,
              color: AppColors.success,
              icon: Icons.thumb_up_alt_outlined,
            ),
          if (data.improvement != null) ...[
            const SizedBox(height: 9),
            AdviceBlock(
              block: data.improvement!,
              color: AppColors.warning,
              icon: Icons.trending_up_rounded,
              // The advice names a subject; sending the student to the whole
              // test list made them find it again themselves.
              actionLabel: practise == null ? null : '$name bo‘yicha mashq qilish',
              onAction: practise,
            ),
          ],
          if (data.nextGoal != null) ...[
            const SizedBox(height: 9),
            AdviceBlock(
              block: data.nextGoal!,
              color: AppColors.brandLight,
              icon: Icons.flag_outlined,
              actionLabel: practise == null ? null : 'Testni boshlash',
              onAction: practise,
            ),
          ],
        ],
      ),
    );
  }
}

/// Nothing has been answered yet, so every block on the page would be empty.
class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      children: [
        EmptyView(
          icon: Icons.bar_chart_rounded,
          title: 'Statistika hali bo‘sh',
          subtitle: 'Birinchi testni ishlang — haftalik faolligingiz, fanlar '
              'bo‘yicha natijalar va tavsiyalar shundan keyin paydo bo‘ladi.',
          actionLabel: 'Test ishlash',
          onAction: () => StatisticsScreen._practise(context, ''),
        ),
      ],
    );
  }
}
