import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
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
Future<void> showLeaderboardSheet(BuildContext context, {required int sessionId, String? title}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.bgCard,
    builder: (_) => _LeaderboardSheet(sessionId: sessionId, title: title),
  );
}

class _LeaderboardSheet extends ConsumerWidget {
  const _LeaderboardSheet({required this.sessionId, this.title});

  final int sessionId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final myId = ref.watch(currentUserProvider)?.id;
    final data = ref.watch(sessionLeaderboardProvider(sessionId));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reyting',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary)),
                  if (title != null)
                    Text(title!, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                ],
              ),
            ),
            Flexible(
              child: data.when(
                loading: () => const SizedBox(height: 160, child: LoadingView()),
                error: (e, _) => SizedBox(
                  height: 240,
                  child: ErrorView(
                    message: ApiException.from(e).message,
                    onRetry: () => ref.invalidate(sessionLeaderboardProvider(sessionId)),
                  ),
                ),
                data: (entries) => entries.isEmpty
                    ? const SizedBox(
                        height: 200,
                        child: EmptyView(
                            icon: Icons.leaderboard_outlined, title: "Ishtirokchilar yo'q"),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => LeaderboardRow(
                          entry: entries[i],
                          highlighted: entries[i].userId == myId,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One leaderboard row: rank (medal for top 3), avatar, name, score and time.
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? c.accentMuted : c.bgInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlighted ? c.accentBorder : c.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              entry.rank == 0 ? '—' : (_medals[entry.rank] ?? '#${entry.rank}'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          UserAvatar(name: entry.fullName, imageUrl: entry.profileImage, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  highlighted ? '${entry.fullName} (siz)' : entry.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary),
                ),
                Text(
                  finished
                      ? "${entry.score}/${entry.totalQuestions ?? '?'} to'g'ri · ${formatSeconds(entry.spendSeconds)}"
                      : 'Yakunlamagan',
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ),
          if (finished)
            Text(
              formatPercent(entry.percent),
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.brandLight),
            ),
        ],
      ),
    );
  }
}
