import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/grade.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/filter_chips.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/quiz/badges.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../data/session_repository.dart';
import '../domain/session_models.dart';

/// Result of a session rebuilt from the review endpoint (when no finish response is at hand).
final reviewResultProvider =
    FutureProvider.autoDispose.family<FinishResult, int>((ref, sessionId) async {
  final items = await ref.watch(sessionRepositoryProvider).fetchReview(sessionId);
  return FinishResult.fromReview(sessionId, items);
});

/// Score summary after finishing a test.
///
/// Uses the finish response passed via the route; if missing (deep link,
/// history), rebuilds it from the review endpoint.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.sessionId, this.initial});

  final int sessionId;
  final FinishResult? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = initial;
    return Scaffold(
      appBar: const PageAppBar(title: Text('Test natijasi'), showFriends: false),
      // A full-screen route has no bottom bar of its own, so without this the
      // last action sits under the system navigation bar and cannot be tapped.
      body: SafeArea(
        top: false,
        child: ready != null
            ? _ResultBody(result: ready)
            : ref.watch(reviewResultProvider(sessionId)).when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorView(
                    message: ApiException.from(e).message,
                    onRetry: () => ref.invalidate(reviewResultProvider(sessionId)),
                  ),
                  data: (result) => _ResultBody(result: result),
                ),
      ),
    );
  }
}

enum _TopicFilter { all, weak }

class _ResultBody extends StatefulWidget {
  const _ResultBody({required this.result});

  final FinishResult result;

  @override
  State<_ResultBody> createState() => _ResultBodyState();
}

class _ResultBodyState extends State<_ResultBody> {
  _TopicFilter _filter = _TopicFilter.all;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final topics = [...r.topics]..sort((a, b) => a.percent.compareTo(b.percent));
    final weak = topics.where((t) => t.percent < 50).toList();
    final shown = _filter == _TopicFilter.weak ? weak : topics;

    // One topic can only repeat the ring: it holds every question, so its
    // percentage is the overall score under another name — and a quiz whose
    // questions carry no topic gets exactly that, a single row called
    // "Umumiy". The section earns its place from two topics on.
    final hasTopics = topics.length >= 2;

    final summary = _Summary(result: r);
    final review = GradientButton(
      label: 'Xatolar tahlili',
      icon: Icons.fact_check_outlined,
      onPressed: () => context.push('/session/${r.sessionId}/review'),
    );
    final again = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      onPressed: () => context.push(Routes.tests),
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Yangi test yechish'),
    );

    final topicsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopicsHeader(
          total: topics.length,
          weak: weak.length,
          filter: _filter,
          onFilter: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (shown.isEmpty)
                Text(
                  // Not an empty state: the student asked for weak topics and
                  // this is the answer.
                  "Zaif mavzular yo‘q — ajoyib!",
                  style: TextStyle(fontSize: 12.5, color: context.colors.textMuted),
                ),
              for (final topic in shown) _TopicRow(topic: topic),
              if (weak.isNotEmpty) _RepeatTip(weak: weak),
            ],
          ),
        ),
      ],
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(context.pagePadding, 12, context.pagePadding, 28),
      children: [
        ContentConstraint(
          child: context.isTablet
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          summary,
                          const SizedBox(height: 12),
                          review,
                          const SizedBox(height: 10),
                          again,
                        ],
                      ),
                    ),
                    if (hasTopics) ...[
                      const SizedBox(width: 16),
                      Expanded(child: topicsSection),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: 12),
                    // The review used to sit below the whole topic list, about
                    // 760 dp down: the page's main action, off the first screen.
                    review,
                    if (hasTopics) ...[
                      const SizedBox(height: 16),
                      topicsSection,
                    ],
                    const SizedBox(height: 16),
                    again,
                  ],
                ),
        ),
      ],
    );
  }
}

/// The score, said once.
///
/// The card used to say it six times: the ring, the grade pill, "8 / 10 to'g'ri
/// javob", a "Yakunlandi: 8 ta to'g'ri, 1 ta xato, 1 ta javobsiz" sentence, the
/// same three numbers as tiles, and then "Aniqlik" and "Baho" — which repeat
/// the ring and the pill. Only the time was new.
///
/// "Aniqlik" also confused: it is `correctAnswers / answeredQuestions`, while
/// the ring is `correctAnswers / totalQuestions`, so a test with skipped
/// questions showed two different percentages and explained neither. Skipped
/// questions are named in words now instead.
class _Summary extends StatelessWidget {
  const _Summary({required this.result});

  final FinishResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = result;
    final grade = Grade.of(r.percent);
    final tone = context.readable(grade.color);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        children: [
          ScoreRing(percent: r.percent, size: 116),
          const SizedBox(height: 10),
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: AppColors.tint(grade.color, 0x24),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.tint(grade.color, 0x57)),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                grade.label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: tone),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${r.totalQuestions} ta savoldan ${r.correctAnswers} tasi to‘g‘ri',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textSecondary),
          ),
          if (r.skipped > 0) ...[
            const SizedBox(height: 5),
            Text(
              '${r.skipped} ta savolga javob bermadingiz',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: context.readable(AppColors.warning)),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: 'To‘g‘ri', value: '${r.correctAnswers}', color: AppColors.success),
              const SizedBox(width: 8),
              _Stat(label: 'Xato', value: '${r.wrongAnswers}', color: AppColors.error),
              if (r.skipped > 0) ...[
                const SizedBox(width: 8),
                _Stat(label: 'Javobsiz', value: '${r.skipped}', color: c.textMuted),
              ],
              const SizedBox(width: 8),
              // The only fact on this card the ring does not already carry.
              _Stat(label: 'Vaqt', value: formatSeconds(r.spendSeconds), color: AppColors.sky),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section label and the two filters, on one line.
class _TopicsHeader extends StatelessWidget {
  const _TopicsHeader({
    required this.total,
    required this.weak,
    required this.filter,
    required this.onFilter,
  });

  final int total;
  final int weak;
  final _TopicFilter filter;
  final ValueChanged<_TopicFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'MAVZULAR TAHLILI',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: context.colors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilterChips<_TopicFilter>(
          options: [
            FilterOption(_TopicFilter.all, 'Barchasi $total'),
            FilterOption(_TopicFilter.weak, 'Zaif $weak'),
          ],
          selected: filter,
          onSelected: onFilter,
        ),
      ],
    );
  }
}

/// What to go over again, named.
class _RepeatTip extends StatelessWidget {
  const _RepeatTip({required this.weak});

  final List<TopicStat> weak;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.tint(AppColors.brand, 0x1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.tint(AppColors.brand, 0x3D)),
        ),
        child: Text(
          'Takrorlash tavsiya etiladi: ${weak.take(3).map((t) => t.name).join(', ')}',
          style: TextStyle(fontSize: 11.5, height: 1.45, color: c.textSecondary),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        decoration: BoxDecoration(
          color: c.bgInner,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: context.readable(color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final TopicStat topic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = context.readable(Grade.of(topic.percent).color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              topic.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: topic.total == 0 ? 0.0 : topic.correct / topic.total,
                minHeight: 5,
                backgroundColor: c.bgInner,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              formatPercent(topic.percent),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
