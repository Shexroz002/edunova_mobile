import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
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
      appBar: const PageAppBar(title: Text('Test natijasi'), showThemeToggle: false),
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
    final c = context.colors;
    final grade = Grade.of(r.percent);
    final topics = [...r.topics]..sort((a, b) => a.percent.compareTo(b.percent));
    final weak = topics.where((t) => t.percent < 50).toList();
    final shown = _filter == _TopicFilter.weak ? weak : topics;

    final summary = AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ScoreRing(percent: r.percent, size: 140),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.tint(grade.color),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.tint(grade.color, 0x55)),
            ),
            child: Text(
              grade.label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: grade.color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "${r.correctAnswers} / ${r.totalQuestions} to'g'ri javob",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            "Yakunlandi: ${r.correctAnswers} ta to'g'ri, ${r.wrongAnswers} ta xato, ${r.skipped} ta javobsiz",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat(label: "To'g'ri", value: '${r.correctAnswers}', color: AppColors.success),
              _Stat(label: 'Xato', value: '${r.wrongAnswers}', color: AppColors.error),
              _Stat(label: 'Javobsiz', value: '${r.skipped}', color: c.textMuted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Vaqt', value: formatSeconds(r.spendSeconds), color: AppColors.sky),
              _Stat(
                  label: 'Aniqlik', value: formatPercent(r.accuracy), color: AppColors.brandLight),
              _Stat(label: 'Baho', value: grade.letter, color: grade.color),
            ],
          ),
        ],
      ),
    );

    final topicsCard = AppCard(
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
                child: Icon(Icons.insights_rounded, size: 17, color: c.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mavzular tahlili',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      '${topics.length} ta mavzu',
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilterChips<_TopicFilter>(
            options: [
              FilterOption(_TopicFilter.all, 'Barchasi (${topics.length})'),
              FilterOption(_TopicFilter.weak, 'Zaif (${weak.length})'),
            ],
            selected: _filter,
            onSelected: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Text(
              _filter == _TopicFilter.weak
                  ? "Zaif mavzular yo'q — ajoyib!"
                  : "Mavzular bo'yicha ma'lumot yo'q",
              style: TextStyle(color: c.textMuted),
            ),
          for (final topic in shown) _TopicRow(topic: topic),
          if (weak.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.accentMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.accentBorder),
              ),
              child: Text(
                'Takrorlash tavsiya etiladi: ${weak.take(3).map((t) => t.name).join(', ')}',
                style: TextStyle(fontSize: 13, color: c.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientButton(
          label: 'Xatolar tahlilini boshlash',
          icon: Icons.fact_check_outlined,
          onPressed: () => context.push('/session/${r.sessionId}/review'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () => context.push('/tests'),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Yangi test yechish'),
        ),
      ],
    );

    return ListView(
      padding: EdgeInsets.all(context.pagePadding),
      children: [
        ContentConstraint(
          child: context.isTablet
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [summary, const SizedBox(height: 16), actions],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: topicsCard),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: 16),
                    topicsCard,
                    const SizedBox(height: 16),
                    actions
                  ],
                ),
        ),
      ],
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
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
        ],
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
    final color = Grade.of(topic.percent).color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  topic.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${topic.correct}/${topic.total} · ${formatPercent(topic.percent)}",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: topic.total == 0 ? 0.0 : topic.correct / topic.total,
              minHeight: 6,
              backgroundColor: c.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
