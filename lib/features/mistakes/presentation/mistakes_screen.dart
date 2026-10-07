import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../data/mistakes_repository.dart';
import 'widgets/due_card.dart';
import 'widgets/subject_row.dart';

/// The mistake bank: every question the student has got wrong, on a schedule.
///
/// The bank is filled by the server from the student's own answer history, so
/// this screen has nothing to seed — it opens full on the first visit.
class MistakesScreen extends ConsumerWidget {
  const MistakesScreen({super.key});

  Future<void> _review(BuildContext context, WidgetRef ref, {String? subject}) async {
    await context.push(
      subject == null
          ? Routes.mistakeReview
          : '${Routes.mistakeReview}?subject=${Uri.encodeComponent(subject)}',
    );
    // The review changes what is due, so the counts are re-read on return.
    ref.invalidate(mistakeOverviewProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(mistakeOverviewProvider);

    return Scaffold(
      appBar: const PageAppBar(title: Text('Xatolarim'), showFriends: false),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(mistakeOverviewProvider),
          child: overview.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: ApiException.from(error).message,
              onRetry: () => ref.invalidate(mistakeOverviewProvider),
            ),
            data: (data) => data.isEmpty
                ? _NeverMissed(onStart: () => context.go(Routes.home))
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (data.due > 0)
                              DueCard(
                                overview: data,
                                onStart: () => _review(context, ref),
                              )
                            else
                              _NothingDue(nextDueAt: data.nextDueAt, total: data.total),
                            const SizedBox(height: 14),
                            _SectionHead(total: data.total),
                            for (final subject in data.subjects) ...[
                              const SizedBox(height: 9),
                              MistakeSubjectRow(
                                subject: subject,
                                onTap: () =>
                                    _review(context, ref, subject: subject.subject),
                              ),
                            ],
                            if (data.clearedLast30Days > 0) ...[
                              const SizedBox(height: 14),
                              _Cleared(
                                cleared: data.clearedLast30Days,
                                open: data.total,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      children: [
        Expanded(
          child: Text(
            'BARCHA SAVOLLAR',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: c.textMuted,
            ),
          ),
        ),
        Text(
          '$total',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: c.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Today's queue is empty, but the bank is not.
///
/// There is no "practise anyway": waiting out the interval is what makes the
/// interval work, and a student who wants more practice can take a test.
class _NothingDue extends StatelessWidget {
  const _NothingDue({required this.nextDueAt, required this.total});

  final DateTime? nextDueAt;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final success = context.readable(AppColors.success);
    final next = nextDueAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.success, 0x24),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.check_rounded, size: 28, color: success),
          ),
          const SizedBox(height: 12),
          Text(
            'Bugungi takror tugadi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            next == null
                ? '$total ta savol takrorlashda qoldi.'
                : '$total ta savol takrorlashda qoldi.\n'
                    'Keyingisi ${formatUntil(next)} qaytadi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Progress that is worth seeing: questions that left the bank for good.
class _Cleared extends StatelessWidget {
  const _Cleared({required this.cleared, required this.open});

  final int cleared;
  final int open;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final success = context.readable(AppColors.success);
    final share = (cleared + open) == 0 ? 0.0 : cleared / (cleared + open);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'O‘tgan 30 kunda yopilgan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary,
                  ),
                ),
              ),
              Text(
                '$cleared',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: success),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: share.clamp(0, 1),
              minHeight: 6,
              backgroundColor: c.bgInner,
              valueColor: AlwaysStoppedAnimation(success),
            ),
          ),
        ],
      ),
    );
  }
}

/// No mistake has ever been recorded, so there is nothing to practise yet.
class _NeverMissed extends StatelessWidget {
  const _NeverMissed({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      children: [
        EmptyView(
          icon: Icons.refresh_rounded,
          title: 'Xatolaringiz yo‘q',
          subtitle: 'Test ishlang — xato qilgan savollaringiz shu yerda '
              'to‘planadi va takrorlash uchun qaytadi.',
          actionLabel: 'Test ishlash',
          onAction: onStart,
        ),
      ],
    );
  }
}
