import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/media_url.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../session/domain/session_models.dart';
import '../data/groups_repository.dart';
import '../data/session_result_pdf.dart';
import '../domain/group_models.dart';

/// Everything one group session result needs, fetched together.
class _SessionBundle {
  const _SessionBundle({
    required this.group,
    required this.result,
    required this.leaderboard,
    required this.accuracy,
  });

  final StudentGroup group;
  final GroupSessionResult result;
  final List<LeaderboardEntry> leaderboard;
  final List<QuestionAccuracy> accuracy;
}

/// Loads the header, ranking and question accuracy of one group session.
final _sessionBundleProvider =
    FutureProvider.autoDispose.family<_SessionBundle, (int, int)>((ref, ids) async {
  final (groupId, sessionId) = ids;
  final repo = ref.watch(groupsRepositoryProvider);
  final group = await repo.fetchGroup(groupId);
  final result = await repo.fetchSessionResult(groupId, sessionId);
  final leaderboard = await repo.fetchLeaderboard(groupId, sessionId);
  final accuracy = await repo.fetchQuestionAccuracy(groupId, sessionId);
  return _SessionBundle(
    group: group,
    result: result,
    leaderboard: leaderboard,
    accuracy: accuracy,
  );
});

/// Result of one group session: summary numbers, the ranking, per-question
/// accuracy, the student table and a PDF export — the sections of the web
/// `StudentSessionResultPage.tsx`.
///
/// Both ids come from the route; the web reads `groupId` from router state and
/// breaks on reload (web bug #2).
class GroupSessionResultScreen extends ConsumerStatefulWidget {
  const GroupSessionResultScreen({super.key, required this.groupId, required this.sessionId});

  final int groupId;
  final int sessionId;

  @override
  ConsumerState<GroupSessionResultScreen> createState() => _GroupSessionResultScreenState();
}

class _GroupSessionResultScreenState extends ConsumerState<GroupSessionResultScreen> {
  bool _exporting = false;

  Future<void> _export(_SessionBundle bundle) async {
    setState(() => _exporting = true);
    try {
      final bytes = await SessionResultPdf.build(
        groupName: bundle.group.name,
        result: bundle.result,
        leaderboard: bundle.leaderboard,
        accuracy: bundle.accuracy,
      );
      final name = '${bundle.result.quizName}-natija.pdf'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
      await Printing.sharePdf(bytes: bytes, filename: name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF tayyorlanmadi: ${ApiException.from(e).message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _sessionBundleProvider((widget.groupId, widget.sessionId));
    final bundle = ref.watch(provider);

    return Scaffold(
      body: SafeArea(
        child: bundle.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: ApiException.from(e).message,
            onRetry: () => ref.invalidate(provider),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(provider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(context.pagePadding, 8, context.pagePadding, 28),
              children: [
                ContentConstraint(
                  maxWidth: 860,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeader(
                        title: 'Sessiya natijalari',
                        subtitle: data.group.name,
                        titleMaxLines: 1,
                      ),
                      const SizedBox(height: 16),
                      _HeaderCard(
                        result: data.result,
                        exporting: _exporting,
                        onExport: () => _export(data),
                      ),
                      const SizedBox(height: 16),
                      _SummaryGrid(result: data.result),
                      const SizedBox(height: 16),
                      _RankingCard(entries: data.leaderboard),
                      const SizedBox(height: 16),
                      _AccuracyCard(accuracy: data.accuracy),
                      const SizedBox(height: 16),
                      _StudentTableCard(entries: data.leaderboard),
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

/// Quiz name, status, meta row and the download button.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.result,
    required this.exporting,
    required this.onExport,
  });

  final GroupSessionResult result;
  final bool exporting;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.quizName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.success),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result.statusLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (result.date != null)
                // The web prints this as "2026 M09 11 18:30" (web bug #3).
                _Meta(icon: Icons.event_outlined, text: formatDateTime(result.date!)),
              _Meta(
                icon: Icons.people_alt_outlined,
                text: "${result.participantsCount} ta o'quvchi",
              ),
              _Meta(
                icon: Icons.schedule_rounded,
                text: '${formatMinutes(result.durationMinutes)} davomiylik',
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: exporting ? null : onExport,
            icon: exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(exporting ? 'Tayyorlanmoqda...' : 'Yuklab olish'),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.textMuted),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, color: c.textSecondary)),
      ],
    );
  }
}

/// The four headline numbers of the session.
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.result});

  final GroupSessionResult result;

  @override
  Widget build(BuildContext context) {
    final hardest = result.hardestQuestionNumber;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: "O'rtacha ball",
                value: formatPercent(result.averageScore),
                color: AppColors.brandLight,
                icon: Icons.track_changes_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                label: 'Eng yuqori ball',
                value: formatPercent(result.highestScore),
                color: AppColors.success,
                icon: Icons.trending_up_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: 'Eng past ball',
                value: formatPercent(result.lowestScore),
                color: AppColors.error,
                icon: Icons.trending_down_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                label: 'Qiyin savol',
                value: hardest == null
                    ? '—'
                    : 'Q$hardest'
                        '${result.hardestQuestionAccuracy == null ? '' : ' (${formatPercent(result.hardestQuestionAccuracy!)})'}',
                color: AppColors.warning,
                icon: Icons.help_outline_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/// Ranking of this session, best first.
class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.entries});

  final List<LeaderboardEntry> entries;

  static const _medals = [Color(0xFFFBBF24), Color(0xFF94A3B8), Color(0xFFB45309)];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return _Card(
      title: 'Reyting jadvali',
      subtitle: 'Shu sessiyaning eng yaxshi natijalari',
      child: entries.isEmpty
          ? Text("Natija yo'q", style: TextStyle(fontSize: 13, color: c.textMuted))
          : Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  _RankRow(
                    entry: entries[i],
                    color: i < _medals.length ? _medals[i] : c.textMuted,
                  ),
                  if (i < entries.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.color});

  final LeaderboardEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
          ),
          const SizedBox(width: 8),
          UserAvatar(
            name: entry.fullName,
            imageUrl: MediaUrl.resolve(entry.profileImage),
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.tint(color, 0x24),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              formatPercent(entry.percent),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-question accuracy bars with the web's legend.
class _AccuracyCard extends StatelessWidget {
  const _AccuracyCard({required this.accuracy});

  final List<QuestionAccuracy> accuracy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return _Card(
      title: 'Savol aniqligi',
      subtitle: "To'g'ri javob bergan o'quvchilar foizi",
      child: accuracy.isEmpty
          ? Text(
              "Savollar bo'yicha ma'lumot yo'q",
              style: TextStyle(fontSize: 13, color: c.textMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final question in accuracy) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          'Q${question.number}',
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (question.accuracyPercent / 100).clamp(0, 1),
                            minHeight: 9,
                            backgroundColor: c.bgInner,
                            valueColor: AlwaysStoppedAnimation(question.band.color),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 46,
                        child: Text(
                          formatPercent(question.accuracyPercent),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: question.band.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
                const Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _LegendItem(color: AppColors.success, label: '≥75% Oson'),
                    _LegendItem(color: AppColors.warning, label: "50–74% O'rta"),
                    _LegendItem(color: AppColors.error, label: '<50% Qiyin'),
                  ],
                ),
              ],
            ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
      ],
    );
  }
}

/// Ball / To'g'ri / Vaqt per student.
///
/// The web shows a table; on a phone each student becomes a row of three
/// labelled values so nothing has to scroll sideways.
class _StudentTableCard extends StatelessWidget {
  const _StudentTableCard({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return _Card(
      title: "O'quvchi natijalari",
      subtitle: '${entries.length} ta o‘quvchi · tartib: ball',
      child: entries.isEmpty
          ? Text("Natija yo'q", style: TextStyle(fontSize: 13, color: c.textMuted))
          : Column(
              children: [
                for (final entry in entries) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.bgInner,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            UserAvatar(
                              name: entry.fullName,
                              imageUrl: MediaUrl.resolve(entry.profileImage),
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _Cell(label: 'Ball', value: formatPercent(entry.percent)),
                            ),
                            Expanded(
                              child: _Cell(
                                label: "To'g'ri",
                                value: '${entry.score ?? 0}/${entry.totalQuestions ?? 0}',
                              ),
                            ),
                            Expanded(
                              child: _Cell(
                                label: 'Vaqt',
                                value: formatSeconds(entry.spendSeconds),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 13, color: c.textMuted)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
