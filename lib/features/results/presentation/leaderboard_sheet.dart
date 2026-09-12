import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/grade.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../session/data/session_repository.dart';
import '../../session/domain/session_models.dart';

/// Ranked participants of a session.
final sessionLeaderboardProvider = FutureProvider.autoDispose.family<List<LeaderboardEntry>, int>(
  (ref, sessionId) => ref.watch(sessionRepositoryProvider).fetchLeaderboard(sessionId),
);

/// Opens the session leaderboard in a bottom sheet.
Future<void> showLeaderboardSheet(
  BuildContext context, {
  required int sessionId,
  String? title,
  DateTime? date,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    backgroundColor: context.colors.bgCard,
    // No fixed height: the sheet takes the height of its content and only
    // starts scrolling once the list is longer than the screen. A fixed size
    // left a solo participant floating above a screenful of empty sheet.
    builder: (_) => _LeaderboardSheet(sessionId: sessionId, title: title, date: date),
  );
}

/// Session leaderboard, laid out like the web's "Reyting" modal: the quiz
/// title, meta chips, the student's own score, then the ranked list.
class _LeaderboardSheet extends ConsumerWidget {
  const _LeaderboardSheet({required this.sessionId, this.title, this.date});

  final int sessionId;
  final String? title;
  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final myId = ref.watch(currentUserProvider)?.id;
    final data = ref.watch(sessionLeaderboardProvider(sessionId));

    return SafeArea(
      top: false,
      child: data.when(
        loading: () => const SizedBox(height: 200, child: LoadingView()),
        error: (e, _) => SizedBox(
          height: 260,
          child: ErrorView(
            message: ApiException.from(e).message,
            onRetry: () => ref.invalidate(sessionLeaderboardProvider(sessionId)),
          ),
        ),
        data: (entries) {
          final me = entries.where((e) => e.userId == myId).firstOrNull;
          final questions = entries
              .map((e) => e.totalQuestions)
              .whereType<int>()
              .fold<int>(0, (max, value) => value > max ? value : max);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title ?? 'Reyting',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(
                      icon: Icons.groups_outlined,
                      label: '${entries.length} ishtirokchi',
                      color: AppColors.brand,
                    ),
                    if (date != null)
                      _MetaChip(
                        icon: Icons.calendar_today_rounded,
                        label: formatDateTime(date!),
                        color: AppColors.warning,
                      ),
                    if (questions > 0)
                      _MetaChip(
                        icon: Icons.help_outline_rounded,
                        label: '$questions ta savol',
                        color: AppColors.success,
                      ),
                  ],
                ),
                if (me != null) ...[
                  const SizedBox(height: 14),
                  _MyScore(entry: me),
                ],
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  const EmptyView(icon: Icons.leaderboard_outlined, title: "Ishtirokchilar yo'q")
                else
                  for (final entry in entries) ...[
                    LeaderboardRow(entry: entry, highlighted: entry.userId == myId),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Small tinted chip in the sheet header.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tint(color, dark ? 0x1F : 0x14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.tint(color, dark ? 0x40 : 0x33)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// "Mening natijam" strip above the list.
class _MyScore extends StatelessWidget {
  const _MyScore({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = Grade.of(entry.percent).color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.accentMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.accentBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_outlined, size: 16, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Mening natijam',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatPercent(entry.percent),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _ScoreBar(percent: entry.percent, color: color),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ScoreCount(entry: entry, showPercent: false),
        ],
      ),
    );
  }
}

/// Thin rounded progress bar used by the strip and every row.
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.percent, required this.color});

  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: (percent / 100).clamp(0, 1),
        minHeight: 4,
        backgroundColor: context.colors.bgInner,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

/// "correct / total" stacked over the percentage, as on the web.
class _ScoreCount extends StatelessWidget {
  const _ScoreCount({required this.entry, this.showPercent = true});

  final LeaderboardEntry entry;

  /// "Mening natijam" already carries the percentage in its own header, so it
  /// asks for the count alone — the web shows it once, not twice.
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = entry.totalQuestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.score ?? 0}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary),
            ),
            if (total != null)
              Text(
                ' /$total',
                style: TextStyle(fontSize: 11, color: c.textMuted),
              ),
          ],
        ),
        if (showPercent)
          Text(
            formatPercent(entry.percent),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Grade.of(entry.percent).color,
            ),
          ),
      ],
    );
  }
}

/// One leaderboard row: medal or rank, avatar, name, score bar and counts.
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({super.key, required this.entry, this.highlighted = false});

  final LeaderboardEntry entry;
  final bool highlighted;

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final finished = entry.score != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? c.accentMuted : c.bgInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlighted ? c.accentBorder : c.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              entry.rank == 0 ? '—' : (_medals[entry.rank] ?? '${entry.rank}'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 6),
          UserAvatar(name: entry.fullName, imageUrl: entry.profileImage, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: highlighted ? c.accent : c.textPrimary,
                        ),
                      ),
                    ),
                    if (highlighted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.accentMuted,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: c.accentBorder),
                        ),
                        child: Text(
                          'Siz',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: c.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (finished)
                  _ScoreBar(percent: entry.percent, color: Grade.of(entry.percent).color)
                else
                  Text(
                    'Yakunlamagan',
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (finished) _ScoreCount(entry: entry),
        ],
      ),
    );
  }
}
