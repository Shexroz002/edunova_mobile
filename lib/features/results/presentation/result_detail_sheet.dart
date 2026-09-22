import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/subject_style.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../session/domain/session_models.dart';
import '../../session/presentation/result_screen.dart';
import 'leaderboard_sheet.dart';
import 'widgets/result_row.dart';

/// Everything one result has to say, in one place.
///
/// A result used to have three destinations. Tapping the card opened
/// `/session/{id}/result`, which fetches the review and adds a per-topic
/// breakdown; the "Ko'rish" button inside the same card opened *this* sheet,
/// built from the history row with no request; "Reyting" opened a third. The
/// first two showed nearly the same numbers and both ended at the same review
/// page.
///
/// So the row opens this sheet alone: the header and the figures are on screen
/// immediately, because the history row already carries them, and the topics
/// load underneath. `/session/{id}/result` stays what it is — the screen after
/// finishing a test, where "Yangi test yechish" still makes sense.
Future<void> showResultDetailSheet(BuildContext context, {required HistoryItem item}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.bgCard,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      // An abandoned test has no score, no topics and two rows of figures;
      // opening it at the full height left most of the sheet blank.
      initialChildSize: item.isComplete ? 0.78 : 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => _ResultDetailSheet(item: item, scrollController: controller),
    ),
  );
}

class _ResultDetailSheet extends ConsumerWidget {
  const _ResultDetailSheet({required this.item, required this.scrollController});

  final HistoryItem item;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final style = SubjectStyle.of(item.subject);
    final date = item.finishedAt ?? item.createdAt;
    final minutes = item.durationMinutes;
    final tone = ResultRow.scoreColor(context, item.percent);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tint(style.color, 0x2B),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(style.icon, size: 20, color: context.readable(style.color)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title ?? 'Test',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      SubjectStyle.displayName(item.subject),
                      if (date != null) formatDateTime(date),
                    ].where((p) => p.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: c.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        _Divider(),
        if (item.isComplete)
          _Score(item: item, tone: tone)
        else
          const _Unfinished(),
        _Divider(),
        _Row(label: 'Savollar', value: '${item.totalQuestions ?? 0} ta'),
        if (!item.isComplete)
          _Row(
            label: 'Javob berilgan',
            value: '${item.answered} / ${item.totalQuestions ?? 0}',
          ),
        if (item.isComplete)
          _Row(
            label: "To'g'ri javoblar",
            value: '${item.correctAnswers ?? 0} / ${item.totalQuestions ?? 0}',
          ),
        if (minutes != null && minutes > 0)
          _Row(label: 'Sarflangan vaqt', value: formatMinutes(minutes)),
        if (date != null) _Row(label: 'Sana', value: formatDate(date)),
        if (item.isMultiplayer) ...[
          _Row(label: 'Ishtirokchilar', value: '${item.participantCount} kishi'),
          _Row(label: 'O‘rningiz', value: '${item.rank} / ${item.participantCount}'),
        ],
        if (item.isComplete) _Topics(sessionId: item.sessionId),
        const SizedBox(height: 18),
        Row(
          children: [
            if (item.isMultiplayer) ...[
              Expanded(
                child: _Secondary(
                  icon: Icons.emoji_events_rounded,
                  label: 'Reyting',
                  onTap: () {
                    Navigator.of(context).pop();
                    showLeaderboardSheet(
                      context,
                      sessionId: item.sessionId,
                      title: item.title,
                      date: date,
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: item.isMultiplayer ? 1 : 2,
              child: GradientButton(
                label: item.isComplete ? 'Xatolar tahlili' : 'Testni ko‘rish',
                icon: Icons.fact_check_outlined,
                height: 48,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/session/${item.sessionId}/review');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The score, once and large.
class _Score extends StatelessWidget {
  const _Score({required this.item, required this.tone});

  final HistoryItem item;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        Text(
          formatPercent(item.percent),
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.4,
            height: 1,
            color: tone,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${item.totalQuestions ?? 0} ta savoldan '
          '${item.correctAnswers ?? 0} tasi to‘g‘ri',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: c.textMuted),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (item.percent / 100).clamp(0, 1),
            minHeight: 6,
            backgroundColor: c.bgInner,
            valueColor: AlwaysStoppedAnimation(tone),
          ),
        ),
      ],
    );
  }
}

/// An abandoned test has no score to show, so it says what happened instead.
class _Unfinished extends StatelessWidget {
  const _Unfinished();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        Icon(Icons.pause_circle_outline_rounded, size: 34, color: c.textMuted),
        const SizedBox(height: 8),
        Text(
          'Bu test tugallanmagan',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Javob berilgan savollarni ko‘rishingiz mumkin.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: c.textMuted),
        ),
      ],
    );
  }
}

/// Per-topic accuracy, loaded after the sheet is already on screen.
///
/// It comes from `single-player-error-analysis`, so a competition may have
/// nothing to show; an empty or failed load simply leaves the section out
/// rather than putting an error in front of a result the student asked for.
class _Topics extends ConsumerWidget {
  const _Topics({required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final result = ref.watch(reviewResultProvider(sessionId));

    final topics = result.valueOrNull?.topics ?? const <TopicStat>[];
    if (result.hasError || (result.hasValue && topics.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Divider(),
        Text(
          'MAVZULAR BO‘YICHA',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: c.textMuted,
          ),
        ),
        const SizedBox(height: 9),
        if (result.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else
          for (final topic in [...topics]..sort((a, b) => a.percent.compareTo(b.percent)))
            _TopicRow(topic: topic),
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final TopicStat topic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = ResultRow.scoreColor(context, topic.percent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
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
            width: 74,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (topic.percent / 100).clamp(0, 1),
                minHeight: 5,
                backgroundColor: c.bgInner,
                valueColor: AlwaysStoppedAnimation(tone),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              formatPercent(topic.percent),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.textMuted))),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = context.readable(AppColors.brand);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: brand),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: brand),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(height: 1, color: context.colors.border),
    );
  }
}
